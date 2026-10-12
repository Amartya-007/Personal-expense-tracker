@Timeout(Duration(minutes: 3))
library;

import 'dart:io';
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mykhata/core/database/database_helper.dart';
import 'package:mykhata/data/models/account_model.dart';
import 'package:mykhata/data/models/transaction_model.dart';
import 'package:mykhata/data/repositories/account_repository.dart';
import 'package:mykhata/data/repositories/transaction_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Unlike `financial_invariant_stress_test.dart` (which re-implements the
/// balance rules in its own SQL and so never touches production code), this
/// test calls the REAL `TransactionRepository` and `AccountRepository`.
///
/// The expected values come from [_Ledger], a deliberately naive reference
/// written from the accounting rules, not from the repository's code:
///   * income adds to its account (any payment method)
///   * expense subtracts, except Cash (Cash does not touch an account)
///   * transfer subtracts from the source and adds to the destination
///   * a soft-deleted transaction counts for nothing
///   * a direct balance edit shifts the balance by (target - current)

class _TempIO extends IOOverrides {
  final Directory dir;
  _TempIO(this.dir);

  @override
  Directory getSystemTempDirectory() => dir;
}

class _Event {
  String id;
  String type;
  double amount;
  String method;
  String from;
  String? to;
  bool active;

  _Event(this.id, this.type, this.amount, this.method, this.from, this.to,
      {this.active = true});
}

class _Ledger {
  final Map<String, double> opening;
  final Map<String, double> offset = {};
  final List<_Event> events = [];

  _Ledger(this.opening);

  double balance(String account) {
    var b = opening[account]! + (offset[account] ?? 0);
    for (final e in events) {
      if (!e.active) continue;
      switch (e.type) {
        case 'income':
          if (e.from == account) b += e.amount;
        case 'expense':
          if (e.from == account && e.method != 'Cash') b -= e.amount;
        case 'transfer':
          if (e.from == account) b -= e.amount;
          if (e.to == account) b += e.amount;
      }
    }
    return b;
  }

  void directEdit(String account, double target) {
    offset[account] = (offset[account] ?? 0) + (target - balance(account));
  }
}

TransactionModel _tx(
  String id,
  String type,
  double amount,
  String method,
  String from, {
  String? to,
  DateTime? deletedAt,
}) {
  final now = DateTime(2026, 1, 15, 12);
  return TransactionModel(
    id: id,
    type: type,
    amount: amount,
    description: 'T $id',
    paymentMethod: method,
    accountId: from,
    destinationAccountId: to,
    date: now,
    createdAt: now,
    updatedAt: now,
    deletedAt: deletedAt,
  );
}

void main() {
  late Directory tmp;
  final accounts = AccountRepository();
  final txs = TransactionRepository();
  const ids = ['a', 'b', 'c'];

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    // Private database file, so parallel test files can't clobber each other.
    tmp = Directory.systemTemp.createTempSync('mykhata_invariants_');
    IOOverrides.global = _TempIO(tmp);
  });

  tearDownAll(() async {
    await DatabaseHelper.instance.close();
    IOOverrides.global = null;
    try {
      tmp.deleteSync(recursive: true);
    } catch (_) {}
  });

  setUp(() async {
    await DatabaseHelper.instance.close();
    final db = await DatabaseHelper.instance.database;
    for (final table in [
      'transaction_tags',
      'receipts',
      'transaction_splits',
      'transactions',
      'balance_adjustments',
      'accounts',
    ]) {
      await db.delete(table);
    }
    final now = DateTime(2026, 1, 1);
    for (final id in ids) {
      await accounts.createAccount(
        AccountModel(
          id: id,
          name: 'Account $id',
          currentBalance: 100000,
          initialBalance: 100000,
          createdAt: now,
          updatedAt: now,
        ),
      );
    }
  });

  Future<double> stored(String id) async =>
      (await accounts.getAccountById(id))!.currentBalance;

  group('Edge cases that used to double-apply a transaction', () {
    test('restoring an active transaction changes nothing', () async {
      await txs.createTransaction(_tx('t1', 'expense', 100, 'UPI', 'a'));
      expect(await stored('a'), 99900);

      await txs.restoreTransaction('t1'); // not deleted: must be a no-op
      await txs.restoreTransaction('t1');

      expect(await stored('a'), 99900);
      expect((await accounts.reconcileAccount('a')).isMatch, isTrue);
    });

    test('deleting twice reverses once; restoring twice applies once', () async {
      await txs.createTransaction(_tx('t1', 'income', 500, 'UPI', 'a'));
      expect(await stored('a'), 100500);

      await txs.softDeleteTransaction('t1');
      await txs.softDeleteTransaction('t1');
      expect(await stored('a'), 100000);

      await txs.restoreTransaction('t1');
      await txs.restoreTransaction('t1');
      expect(await stored('a'), 100500);
    });

    test('editing a deleted transaction does not move the balance', () async {
      await txs.createTransaction(_tx('t1', 'expense', 100, 'UPI', 'a'));
      await txs.softDeleteTransaction('t1');
      expect(await stored('a'), 100000);

      // Still deleted, new amount: nothing should change yet.
      await txs.updateTransaction(
        _tx('t1', 'expense', 150, 'UPI', 'a', deletedAt: DateTime(2026, 2, 1)),
      );
      expect(await stored('a'), 100000);

      // Restoring applies the edited amount exactly once.
      await txs.restoreTransaction('t1');
      expect(await stored('a'), 99850);
      expect((await accounts.reconcileAccount('a')).isMatch, isTrue);
    });

    test('transfers never inflate income or expense totals', () async {
      await txs.createTransaction(
        _tx('t1', 'transfer', 1000, 'UPI', 'a', to: 'b'),
      );
      expect(await stored('a'), 99000);
      expect(await stored('b'), 101000);
      expect(await stored('c'), 100000);

      final db = await DatabaseHelper.instance.database;
      final rows = await db.rawQuery(
        "SELECT COUNT(*) AS n FROM transactions "
        "WHERE type IN ('income','expense') AND deleted_at IS NULL",
      );
      expect(rows.first['n'], 0);
    });
  });

  group('Reconciliation', () {
    test('a correct ledger reconciles, including manual balance edits', () async {
      await txs.createTransaction(_tx('t1', 'expense', 100, 'UPI', 'a'));
      await accounts.updateAccountBalanceDirect('a', 80000);

      final result = await accounts.reconcileAccount('a');
      expect(result.isMatch, isTrue);
      expect(result.actualBalance, 80000);
    });

    test('drift is detected, explained, and corrected only when approved',
        () async {
      await txs.createTransaction(_tx('t1', 'expense', 100, 'UPI', 'a'));
      final db = await DatabaseHelper.instance.database;
      // Simulate a defect: the stored balance no longer matches the ledger.
      await db.update('accounts', {'current_balance': 99950},
          where: 'id = ?', whereArgs: ['a']);

      final before = await accounts.reconcileAccount('a');
      expect(before.isMatch, isFalse);
      expect(before.expectedBalance, 99900);
      expect(before.actualBalance, 99950);
      expect(before.drift, closeTo(50, 0.001));

      // A correction based on a stale view must not apply.
      expect(
        await accounts.correctBalanceToLedger('a', seenBalance: 12345),
        isFalse,
      );
      expect(await stored('a'), 99950);

      // The approved correction fixes it and the account then reconciles.
      expect(
        await accounts.correctBalanceToLedger('a', seenBalance: 99950),
        isTrue,
      );
      expect(await stored('a'), 99900);
      expect((await accounts.reconcileAccount('a')).isMatch, isTrue);

      // The fix is not recorded as ledger activity (that would re-create the
      // drift), and an account that already matches is left alone.
      final adj = await db.rawQuery(
        'SELECT COUNT(*) AS n FROM balance_adjustments WHERE account_id = ?',
        ['a'],
      );
      expect(adj.first['n'], 0);
      expect(
        await accounts.correctBalanceToLedger('a', seenBalance: 99900),
        isFalse,
      );
    });
  });

  group('Randomized sequences against the reference ledger', () {
    for (final seed in [1, 7, 42]) {
      test('seed $seed: 300 mixed operations stay consistent', () async {
        final rnd = Random(seed);
        final ledger = _Ledger({for (final id in ids) id: 100000});
        var counter = 0;

        _Event pick() => ledger.events[rnd.nextInt(ledger.events.length)];

        String other(String not) {
          final options = ids.where((i) => i != not).toList();
          return options[rnd.nextInt(options.length)];
        }

        Future<void> expectConsistent(int op, String what) async {
          for (final id in ids) {
            expect(
              await stored(id),
              closeTo(ledger.balance(id), 0.005),
              reason: 'seed $seed, op $op ($what): stored balance of $id',
            );
            final r = await accounts.reconcileAccount(id);
            expect(
              r.isMatch,
              isTrue,
              reason: 'seed $seed, op $op ($what): reconcile of $id '
                  'drifted by ${r.drift}',
            );
          }
        }

        for (var op = 0; op < 300; op++) {
          final roll = rnd.nextInt(100);
          String what;

          if (roll < 35 || ledger.events.isEmpty) {
            what = 'create';
            final type = ['expense', 'income', 'transfer'][rnd.nextInt(3)];
            final method = ['UPI', 'Cash', 'Debit Card'][rnd.nextInt(3)];
            final from = ids[rnd.nextInt(ids.length)];
            final to = type == 'transfer' ? other(from) : null;
            final amount = (rnd.nextInt(500) + 1).toDouble();
            final id = 't${counter++}';
            await txs.createTransaction(
              _tx(id, type, amount, method, from, to: to),
            );
            ledger.events.add(_Event(id, type, amount, method, from, to));
          } else if (roll < 50) {
            what = 'update';
            final e = pick();
            final type = ['expense', 'income', 'transfer'][rnd.nextInt(3)];
            final method = ['UPI', 'Cash', 'Debit Card'][rnd.nextInt(3)];
            final from = ids[rnd.nextInt(ids.length)];
            final to = type == 'transfer' ? other(from) : null;
            final amount = (rnd.nextInt(500) + 1).toDouble();
            await txs.updateTransaction(
              _tx(
                e.id,
                type,
                amount,
                method,
                from,
                to: to,
                // An edit never changes whether a transaction is deleted.
                deletedAt: e.active ? null : DateTime(2026, 2, 1),
              ),
            );
            e
              ..type = type
              ..amount = amount
              ..method = method
              ..from = from
              ..to = to;
          } else if (roll < 65) {
            what = 'soft delete';
            final e = pick();
            await txs.softDeleteTransaction(e.id);
            e.active = false;
          } else if (roll < 80) {
            what = 'restore';
            final e = pick();
            await txs.restoreTransaction(e.id);
            e.active = true;
          } else if (roll < 90) {
            what = 'permanent delete';
            final e = pick();
            await txs.permanentlyDeleteTransaction(e.id);
            ledger.events.remove(e);
          } else {
            what = 'direct balance edit';
            final id = ids[rnd.nextInt(ids.length)];
            final target = (rnd.nextInt(200000)).toDouble();
            await accounts.updateAccountBalanceDirect(id, target);
            ledger.directEdit(id, target);
          }

          await expectConsistent(op, what);
        }
      });
    }
  });
}
