import 'package:sqflite/sqflite.dart';

import 'database_tables.dart';

class DatabaseMigrations {
  /// Runs while the database is being opened, so it must not call
  /// [AppLogger] (which writes to this same database and would wait for the
  /// open to finish). Every step is safe to run twice.
  static Future<void> migrate(Database db, int oldVersion, int newVersion) async {
    // v2: primary account.
    if (oldVersion < 2) {
      final columns = await db.rawQuery('PRAGMA table_info(accounts)');
      final hasColumn = columns.any((c) => c['name'] == 'is_primary');
      if (!hasColumn) {
        await db.execute(
          'ALTER TABLE accounts ADD COLUMN is_primary INTEGER NOT NULL DEFAULT 0',
        );
      }
      await db.execute(DatabaseTables.createPrimaryAccountIndex);
    }

    // v3: transaction splits.
    if (oldVersion < 3) {
      await db.execute('''
        CREATE TABLE IF NOT EXISTS transaction_splits (
          id TEXT PRIMARY KEY,
          transaction_id TEXT NOT NULL,
          category_id TEXT NOT NULL,
          amount REAL NOT NULL,
          note TEXT,
          FOREIGN KEY (transaction_id) REFERENCES transactions(id) ON DELETE CASCADE,
          FOREIGN KEY (category_id) REFERENCES categories(id)
        );
      ''');
      await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_tx_splits_tx ON transaction_splits(transaction_id);',
      );
    }

    // v4: structured diagnostic logs (category, error, stack trace).
    if (oldVersion < 4) {
      final columns = await db.rawQuery('PRAGMA table_info(app_logs)');
      if (columns.isEmpty) {
        await db.execute(DatabaseTables.createAppLogsTable);
      } else {
        final names = {for (final c in columns) c['name']};
        if (!names.contains('category')) {
          await db.execute(
            "ALTER TABLE app_logs ADD COLUMN category TEXT NOT NULL DEFAULT 'app'",
          );
          // Rows from before this version were free text that could include
          // transaction descriptions, amounts and account names. They were
          // never visible in the app, and must not surface in Logs or in an
          // exported log file, so they are discarded once, here.
          await db.delete('app_logs');
        }
        if (!names.contains('error')) {
          await db.execute('ALTER TABLE app_logs ADD COLUMN error TEXT');
        }
        if (!names.contains('stack_trace')) {
          await db.execute('ALTER TABLE app_logs ADD COLUMN stack_trace TEXT');
        }
      }
      for (final sql in DatabaseTables.createAppLogIndexes) {
        await db.execute(sql);
      }
    }
  }
}
