@Timeout(Duration(seconds: 60))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mykhata/core/database/database_helper.dart';
import 'package:mykhata/core/database/database_migrations.dart';
import 'package:mykhata/data/models/account_model.dart';
import 'package:mykhata/data/repositories/account_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

AccountModel _account(String id, {bool primary = false, double balance = 100}) {
  final now = DateTime.now();
  return AccountModel(
    id: id,
    name: 'Account $id',
    currentBalance: balance,
    initialBalance: balance,
    isPrimary: primary,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('Primary account', () {
    final repo = AccountRepository();

    setUp(() async {
      await DatabaseHelper.instance.close();
      final db = await DatabaseHelper.instance.database;
      await db.delete('transaction_tags');
      await db.delete('receipts');
      await db.delete('transactions');
      await db.delete('balance_adjustments');
      await db.delete('accounts');
    });

    Future<int> primaryCount() async {
      final db = await DatabaseHelper.instance.database;
      final rows = await db.query('accounts', where: 'is_primary = 1');
      return rows.length;
    }

    test('no primary account by default', () async {
      await repo.createAccount(_account('a'));
      expect(await repo.getPrimaryAccount(), isNull);
    });

    test('an account can be created as primary', () async {
      await repo.createAccount(_account('a', primary: true));
      final primary = await repo.getPrimaryAccount();
      expect(primary?.id, 'a');
      expect(primary?.isPrimary, isTrue);
    });

    test('creating another primary account clears the previous one', () async {
      await repo.createAccount(_account('a', primary: true));
      await repo.createAccount(_account('b', primary: true));

      expect((await repo.getPrimaryAccount())?.id, 'b');
      expect(await primaryCount(), 1);
      expect((await repo.getAccountById('a'))?.isPrimary, isFalse);
    });

    test('setPrimaryAccount moves the flag; only one primary at a time', () async {
      await repo.createAccount(_account('a', primary: true));
      await repo.createAccount(_account('b'));

      await repo.setPrimaryAccount('b');

      expect((await repo.getPrimaryAccount())?.id, 'b');
      expect(await primaryCount(), 1);
    });

    test('clearPrimaryAccount leaves no primary', () async {
      await repo.createAccount(_account('a', primary: true));
      await repo.clearPrimaryAccount();
      expect(await repo.getPrimaryAccount(), isNull);
      expect(await primaryCount(), 0);
    });

    test('deleting the primary account clears the primary setting', () async {
      await repo.createAccount(_account('a', primary: true));
      await repo.createAccount(_account('b'));

      await repo.deleteAccount('a');

      expect(await repo.getPrimaryAccount(), isNull);
      expect(await primaryCount(), 0);
      // The other account is not promoted automatically.
      expect((await repo.getAccountById('b'))?.isPrimary, isFalse);
    });

    test('deleting a non-primary account keeps the primary', () async {
      await repo.createAccount(_account('a', primary: true));
      await repo.createAccount(_account('b'));

      await repo.deleteAccount('b');

      expect((await repo.getPrimaryAccount())?.id, 'a');
    });

    test('a missing or removed account cannot become primary', () async {
      await repo.createAccount(_account('a', primary: true));
      await repo.createAccount(_account('b'));
      await repo.deleteAccount('b');

      await expectLater(repo.setPrimaryAccount('nope'), throwsException);
      await expectLater(repo.setPrimaryAccount('b'), throwsException);

      // Failed attempts must not disturb the current primary.
      expect((await repo.getPrimaryAccount())?.id, 'a');
    });

    test('editing an account never changes the primary flag', () async {
      await repo.createAccount(_account('a', primary: true));
      await repo.createAccount(_account('b'));

      // An edit carrying a stale/incorrect flag must not create a second
      // primary or clear the real one.
      await repo.updateAccount(_account('b', primary: true, balance: 500));
      await repo.updateAccount(_account('a', primary: false, balance: 700));

      expect((await repo.getPrimaryAccount())?.id, 'a');
      expect(await primaryCount(), 1);
      expect((await repo.getAccountById('b'))?.currentBalance, 500);
    });

    test('the database itself rejects two primary accounts', () async {
      await repo.createAccount(_account('a', primary: true));
      await repo.createAccount(_account('b'));
      final db = await DatabaseHelper.instance.database;

      await expectLater(
        db.update('accounts', {'is_primary': 1}, where: 'id = ?', whereArgs: ['b']),
        throwsA(isA<DatabaseException>()),
      );
    });

    test('changing the primary account does not touch existing transactions', () async {
      await repo.createAccount(_account('a', primary: true));
      await repo.createAccount(_account('b'));
      final db = await DatabaseHelper.instance.database;
      final now = DateTime.now().millisecondsSinceEpoch;
      await db.insert('transactions', {
        'id': 'tx1',
        'type': 'expense',
        'amount': 25.0,
        'description': 'Tea',
        'payment_method': 'UPI',
        'account_id': 'a',
        'date': now,
        'created_at': now,
        'updated_at': now,
      });

      await repo.setPrimaryAccount('b');

      final rows = await db.query('transactions', where: 'id = ?', whereArgs: ['tx1']);
      expect(rows.single['account_id'], 'a');
      expect(rows.single['updated_at'], now);
    });
  });

  group('Migration v1 -> v2', () {
    Future<Database> openV1() {
      return databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(
          version: 1,
          onCreate: (db, _) async {
            // The accounts table exactly as it was before this feature.
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
            await db.insert('accounts', {
              'id': 'old1',
              'name': 'HDFC',
              'current_balance': 1234.5,
              'initial_balance': 1000.0,
              'is_active': 1,
              'created_at': 1,
              'updated_at': 2,
            });
          },
        ),
      );
    }

    test('adds the column, keeps existing data, no account becomes primary', () async {
      final db = await openV1();
      addTearDown(db.close);

      await DatabaseMigrations.migrate(db, 1, 2);

      final rows = await db.query('accounts');
      expect(rows, hasLength(1));
      expect(rows.single['name'], 'HDFC');
      expect(rows.single['current_balance'], 1234.5);
      expect(rows.single['is_primary'], 0);
      expect(AccountModel.fromMap(rows.single).isPrimary, isFalse);
    });

    test('is safe to run twice', () async {
      final db = await openV1();
      addTearDown(db.close);

      await DatabaseMigrations.migrate(db, 1, 2);
      await DatabaseMigrations.migrate(db, 1, 2);

      final columns = await db.rawQuery('PRAGMA table_info(accounts)');
      expect(columns.where((c) => c['name'] == 'is_primary'), hasLength(1));
    });

    test('migrated database enforces a single primary account', () async {
      final db = await openV1();
      addTearDown(db.close);
      await DatabaseMigrations.migrate(db, 1, 2);
      await db.insert('accounts', {
        'id': 'old2',
        'name': 'SBI',
        'current_balance': 0.0,
        'initial_balance': 0.0,
        'created_at': 1,
        'updated_at': 1,
      });

      await db.update('accounts', {'is_primary': 1}, where: 'id = ?', whereArgs: ['old1']);
      await expectLater(
        db.update('accounts', {'is_primary': 1}, where: 'id = ?', whereArgs: ['old2']),
        throwsA(isA<DatabaseException>()),
      );
    });
  });
}
