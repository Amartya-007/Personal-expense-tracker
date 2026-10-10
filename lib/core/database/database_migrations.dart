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
  }
}
