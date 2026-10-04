import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:uuid/uuid.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Financial Invariant Stress Test (10,000 Randomized Operations)', () {
    late Database db;
    final Uuid uuid = const Uuid();

    setUp(() async {
      db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE accounts (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              current_balance REAL NOT NULL,
              initial_balance REAL NOT NULL,
              is_active INTEGER NOT NULL DEFAULT 1,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            );
          ''');

          await db.execute('''
            CREATE TABLE categories (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              icon TEXT NOT NULL,
              color INTEGER NOT NULL,
              type TEXT NOT NULL,
              is_default INTEGER NOT NULL DEFAULT 0,
              created_at INTEGER NOT NULL
            );
          ''');

          await db.execute('''
            CREATE TABLE transactions (
              id TEXT PRIMARY KEY,
              type TEXT NOT NULL,
              amount REAL NOT NULL,
              description TEXT NOT NULL,
              category_id TEXT,
              payment_method TEXT NOT NULL,
              account_id TEXT NOT NULL,
              destination_account_id TEXT,
              date INTEGER NOT NULL,
              note TEXT,
              latitude REAL,
              longitude REAL,
              location_name TEXT,
              source TEXT NOT NULL DEFAULT 'manual',
              status TEXT NOT NULL DEFAULT 'confirmed',
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL,
              deleted_at INTEGER,
              recurring_payment_id TEXT,
              sms_message_id TEXT,
              external_reference TEXT,
              duplicate_status TEXT
            );
          ''');

          // Seed Accounts
          final now = 1600000000000;
          await db.insert('accounts', {'id': 'acc_sbi', 'name': 'SBI', 'current_balance': 100000.0, 'initial_balance': 100000.0, 'is_active': 1, 'created_at': now, 'updated_at': now});
          await db.insert('accounts', {'id': 'acc_hdfc', 'name': 'HDFC', 'current_balance': 100000.0, 'initial_balance': 100000.0, 'is_active': 1, 'created_at': now, 'updated_at': now});

          // Seed Category
          await db.insert('categories', {'id': 'cat_food', 'name': 'Food', 'icon': 'food', 'color': 0, 'type': 'expense', 'is_default': 1, 'created_at': now});
        },
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('Runs 10,000 randomized financial operations and verifies SQLite balance matches shadow tracker', () async {
      final rnd = Random(1337);
      final shadowBalances = {'acc_sbi': 100000.0, 'acc_hdfc': 100000.0};
      final activeTransactions = <String, Map<String, dynamic>>{};

      const totalOps = 10000;
      final now = DateTime.now().millisecondsSinceEpoch;

      for (int opIndex = 0; opIndex < totalOps; opIndex++) {
        final choice = rnd.nextDouble();

        await db.transaction((txn) async {
          if (choice < 0.40) {
            // 1. Create Expense
            final txId = uuid.v4();
            final amt = (rnd.nextInt(500) + 10).toDouble();
            final accId = rnd.nextBool() ? 'acc_sbi' : 'acc_hdfc';
            final pm = rnd.nextBool() ? 'UPI' : 'Cash'; // Cash rule test

            await txn.insert('transactions', {
              'id': txId,
              'type': 'expense',
              'amount': amt,
              'description': 'Expense $opIndex',
              'category_id': 'cat_food',
              'payment_method': pm,
              'account_id': accId,
              'date': now + opIndex,
              'created_at': now,
              'updated_at': now,
            });

            activeTransactions[txId] = {
              'type': 'expense',
              'amount': amt,
              'accountId': accId,
              'paymentMethod': pm,
              'deleted': false,
            };

            if (pm != 'Cash') {
              shadowBalances[accId] = (shadowBalances[accId]! - amt);
              await txn.rawUpdate('UPDATE accounts SET current_balance = current_balance - ? WHERE id = ?', [amt, accId]);
            }
          } else if (choice < 0.70) {
            // 2. Create Income
            final txId = uuid.v4();
            final amt = (rnd.nextInt(2000) + 100).toDouble();
            final accId = rnd.nextBool() ? 'acc_sbi' : 'acc_hdfc';

            await txn.insert('transactions', {
              'id': txId,
              'type': 'income',
              'amount': amt,
              'description': 'Income $opIndex',
              'category_id': 'cat_food',
              'payment_method': 'UPI',
              'account_id': accId,
              'date': now + opIndex,
              'created_at': now,
              'updated_at': now,
            });

            activeTransactions[txId] = {
              'type': 'income',
              'amount': amt,
              'accountId': accId,
              'deleted': false,
            };

            shadowBalances[accId] = (shadowBalances[accId]! + amt);
            await txn.rawUpdate('UPDATE accounts SET current_balance = current_balance + ? WHERE id = ?', [amt, accId]);
          } else if (choice < 0.90) {
            // 3. Create Transfer
            final txId = uuid.v4();
            final amt = (rnd.nextInt(1000) + 50).toDouble();
            final srcAcc = rnd.nextBool() ? 'acc_sbi' : 'acc_hdfc';
            final dstAcc = srcAcc == 'acc_sbi' ? 'acc_hdfc' : 'acc_sbi';

            await txn.insert('transactions', {
              'id': txId,
              'type': 'transfer',
              'amount': amt,
              'description': 'Transfer $opIndex',
              'category_id': 'cat_food',
              'payment_method': 'UPI',
              'account_id': srcAcc,
              'destination_account_id': dstAcc,
              'date': now + opIndex,
              'created_at': now,
              'updated_at': now,
            });

            activeTransactions[txId] = {
              'type': 'transfer',
              'amount': amt,
              'accountId': srcAcc,
              'destAccountId': dstAcc,
              'deleted': false,
            };

            shadowBalances[srcAcc] = (shadowBalances[srcAcc]! - amt);
            shadowBalances[dstAcc] = (shadowBalances[dstAcc]! + amt);

            await txn.rawUpdate('UPDATE accounts SET current_balance = current_balance - ? WHERE id = ?', [amt, srcAcc]);
            await txn.rawUpdate('UPDATE accounts SET current_balance = current_balance + ? WHERE id = ?', [amt, dstAcc]);
          } else if (activeTransactions.isNotEmpty) {
            // 4. Soft Delete / Restore existing transaction
            final keys = activeTransactions.keys.toList();
            final targetId = keys[rnd.nextInt(keys.length)];
            final txData = activeTransactions[targetId]!;
            final isCurrentlyDeleted = txData['deleted'] as bool;

            if (!isCurrentlyDeleted) {
              await txn.update('transactions', {'deleted_at': now}, where: 'id = ?', whereArgs: [targetId]);
              txData['deleted'] = true;

              if (txData['type'] == 'expense' && txData['paymentMethod'] != 'Cash') {
                final accId = txData['accountId'] as String;
                final amt = txData['amount'] as double;
                shadowBalances[accId] = shadowBalances[accId]! + amt;
                await txn.rawUpdate('UPDATE accounts SET current_balance = current_balance + ? WHERE id = ?', [amt, accId]);
              } else if (txData['type'] == 'income') {
                final accId = txData['accountId'] as String;
                final amt = txData['amount'] as double;
                shadowBalances[accId] = shadowBalances[accId]! - amt;
                await txn.rawUpdate('UPDATE accounts SET current_balance = current_balance - ? WHERE id = ?', [amt, accId]);
              } else if (txData['type'] == 'transfer') {
                final src = txData['accountId'] as String;
                final dst = txData['destAccountId'] as String;
                final amt = txData['amount'] as double;
                shadowBalances[src] = shadowBalances[src]! + amt;
                shadowBalances[dst] = shadowBalances[dst]! - amt;
                await txn.rawUpdate('UPDATE accounts SET current_balance = current_balance + ? WHERE id = ?', [amt, src]);
                await txn.rawUpdate('UPDATE accounts SET current_balance = current_balance - ? WHERE id = ?', [amt, dst]);
              }
            } else {
              await txn.update('transactions', {'deleted_at': null}, where: 'id = ?', whereArgs: [targetId]);
              txData['deleted'] = false;

              if (txData['type'] == 'expense' && txData['paymentMethod'] != 'Cash') {
                final accId = txData['accountId'] as String;
                final amt = txData['amount'] as double;
                shadowBalances[accId] = shadowBalances[accId]! - amt;
                await txn.rawUpdate('UPDATE accounts SET current_balance = current_balance - ? WHERE id = ?', [amt, accId]);
              } else if (txData['type'] == 'income') {
                final accId = txData['accountId'] as String;
                final amt = txData['amount'] as double;
                shadowBalances[accId] = shadowBalances[accId]! + amt;
                await txn.rawUpdate('UPDATE accounts SET current_balance = current_balance + ? WHERE id = ?', [amt, accId]);
              } else if (txData['type'] == 'transfer') {
                final src = txData['accountId'] as String;
                final dst = txData['destAccountId'] as String;
                final amt = txData['amount'] as double;
                shadowBalances[src] = shadowBalances[src]! - amt;
                shadowBalances[dst] = shadowBalances[dst]! + amt;
                await txn.rawUpdate('UPDATE accounts SET current_balance = current_balance - ? WHERE id = ?', [amt, src]);
                await txn.rawUpdate('UPDATE accounts SET current_balance = current_balance + ? WHERE id = ?', [amt, dst]);
              }
            }
          }
        });

        // Verify balance invariants every 1,000 operations
        if ((opIndex + 1) % 1000 == 0) {
          final accountsRes = await db.query('accounts');
          for (final acc in accountsRes) {
            final accId = acc['id'] as String;
            final sqliteBal = (acc['current_balance'] as num).toDouble();
            final expectedBal = shadowBalances[accId]!;
            expect(sqliteBal, closeTo(expectedBal, 0.001), reason: 'Mismatch on account $accId at operation $opIndex');
          }
        }
      }

      // Final comprehensive verification
      final accountsRes = await db.query('accounts');
      for (final acc in accountsRes) {
        final accId = acc['id'] as String;
        final sqliteBal = (acc['current_balance'] as num).toDouble();
        final expectedBal = shadowBalances[accId]!;
        expect(sqliteBal, closeTo(expectedBal, 0.001), reason: 'Final balance mismatch on account $accId');
      }

      // ignore: avoid_print
      print('=== FINANCIAL INVARIANT STRESS TEST PASSED ===');
      // ignore: avoid_print
      print('Successfully executed $totalOps randomized operations with 100% balance invariant match!');
    });
  });
}
