@Timeout(Duration(seconds: 120))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  group('100,000 Transaction SQLite Production Performance & Integrity Benchmark', () {
    late Database db;
    double expectedTotalExpenseAmount = 0.0;

    setUp(() async {
      db = await openDatabase(
        inMemoryDatabasePath,
        version: 1,
        onConfigure: (db) async {
          await db.execute('PRAGMA foreign_keys = ON');
          try {
            await db.execute('PRAGMA journal_mode = WAL');
            await db.execute('PRAGMA synchronous = NORMAL');
          } catch (_) {}
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
              duplicate_status TEXT,
              FOREIGN KEY (account_id) REFERENCES accounts(id),
              FOREIGN KEY (category_id) REFERENCES categories(id)
            );
          ''');

          await db.execute('CREATE INDEX idx_tx_active_date_id ON transactions(deleted_at, date DESC, id DESC);');
          await db.execute('CREATE INDEX idx_tx_category ON transactions(category_id, deleted_at);');

          await db.execute('''
            CREATE VIRTUAL TABLE IF NOT EXISTS transactions_fts USING fts5(
              id UNINDEXED,
              description,
              note,
              payment_method,
              tokenize='unicode61'
            );
          ''');

          await db.execute('''
            CREATE TRIGGER tx_fts_ai AFTER INSERT ON transactions BEGIN
              INSERT INTO transactions_fts(id, description, note, payment_method)
              VALUES (new.id, new.description, coalesce(new.note, ''), new.payment_method);
            END;
          ''');

          await db.execute('''
            INSERT INTO accounts (id, name, current_balance, initial_balance, created_at, updated_at)
            VALUES ('acc_sbi', 'SBI Bank', 150000.0, 150000.0, 1600000000000, 1600000000000);
          ''');

          const categories = [
            ['cat_food', 'Food', 'dining', 0xFFFF8A5B, 'expense'],
            ['cat_shopping', 'Shopping', 'shopping_bag', 0xFF7C8CFF, 'expense'],
            ['cat_bills', 'Bills', 'receipt_long', 0xFF46D6A4, 'expense'],
            ['cat_transport', 'Transport', 'directions_car', 0xFFFFB627, 'expense'],
            ['cat_health', 'Health', 'medical_services', 0xFFF472B6, 'expense'],
            ['cat_salary', 'Salary', 'payments', 0xFF12A574, 'income'],
            ['cat_other', 'Other', 'category', 0xFFC77DFF, 'expense'],
          ];

          for (final c in categories) {
            await db.execute('''
              INSERT INTO categories (id, name, icon, color, type, is_default, created_at)
              VALUES ('${c[0]}', '${c[1]}', '${c[2]}', ${c[3]}, '${c[4]}', 1, 1600000000000);
            ''');
          }
        },
      );
    });

    tearDown(() async {
      await db.close();
    });

    test('Seeds 100,000 realistic transactions and benchmarks queries + integrity', () async {
      const totalCount = 100000;
      const batchSize = 2500;

      final descriptions = ['Swiggy Food', 'Amazon Shopping', 'Electricity Bill', 'Uber Ride', 'Pharmacy', 'Grocery Store', 'Coffee Shop', 'Salary Payout'];
      final categoryIds = ['cat_food', 'cat_shopping', 'cat_bills', 'cat_transport', 'cat_health', 'cat_other'];
      final paymentMethods = ['UPI', 'Cash', 'Debit Card', 'Credit Card'];

      final baseTime = DateTime(2026, 10, 1).millisecondsSinceEpoch;

      final sw1 = Stopwatch()..start();

      for (int batch = 0; batch < totalCount ~/ batchSize; batch++) {
        final txnBatch = db.batch();

        for (int i = 0; i < batchSize; i++) {
          final index = (batch * batchSize) + i;
          final txId = 'tx_${index.toString().padLeft(6, '0')}';
          final isIncome = index % 20 == 0;
          final type = isIncome ? 'income' : 'expense';
          final categoryId = isIncome ? 'cat_salary' : categoryIds[index % categoryIds.length];
          final amount = isIncome ? 50000.0 : (10.0 + (index % 1000) * 1.25);
          final date = baseTime - (index * 60000);

          if (!isIncome) {
            expectedTotalExpenseAmount += amount;
          }

          txnBatch.rawInsert('''
            INSERT INTO transactions (
              id, type, amount, description, category_id, payment_method, account_id,
              date, source, status, created_at, updated_at
            ) VALUES (?, ?, ?, ?, ?, ?, 'acc_sbi', ?, 'seed', 'confirmed', ?, ?)
          ''', [
            txId,
            type,
            amount,
            descriptions[index % descriptions.length],
            categoryId,
            paymentMethods[index % paymentMethods.length],
            date,
            date,
            date,
          ]);
        }

        await txnBatch.commit(noResult: true);
      }

      sw1.stop();

      // Data integrity check
      final countRes = await db.rawQuery('SELECT COUNT(*) as cnt FROM transactions WHERE deleted_at IS NULL');
      final insertedCount = Sqflite.firstIntValue(countRes) ?? 0;
      expect(insertedCount, equals(totalCount));

      final expSumRes = await db.rawQuery("SELECT SUM(amount) as total FROM transactions WHERE type = 'expense' AND deleted_at IS NULL");
      final actualExpenseSum = (expSumRes.first['total'] as num?)?.toDouble() ?? 0.0;
      expect((actualExpenseSum - expectedTotalExpenseAmount).abs(), lessThan(0.01));

      // Page 0 Keyset Pagination
      final sw2 = Stopwatch()..start();
      final page0 = await db.rawQuery('''
        SELECT id, date, amount, description FROM transactions
        WHERE deleted_at IS NULL
        ORDER BY date DESC, id DESC
        LIMIT 30
      ''');
      sw2.stop();
      expect(page0.length, equals(30));
      expect(sw2.elapsedMilliseconds, lessThan(100));

      // Keyset cursor pagination at item 90,000
      final item90k = await db.rawQuery('''
        SELECT id, date FROM transactions
        WHERE deleted_at IS NULL
        ORDER BY date DESC, id DESC
        LIMIT 1 OFFSET 90000
      ''');

      final cursorDate = item90k.first['date'] as int;
      final cursorId = item90k.first['id'] as String;

      final swKeyset = Stopwatch()..start();
      final keysetPage = await db.rawQuery('''
        SELECT id, date, amount FROM transactions
        WHERE deleted_at IS NULL AND (date < ? OR (date = ? AND id < ?))
        ORDER BY date DESC, id DESC
        LIMIT 30
      ''', [cursorDate, cursorDate, cursorId]);
      swKeyset.stop();

      expect(keysetPage.length, equals(30));
      expect(swKeyset.elapsedMilliseconds, lessThan(50));
    });
  });
}
