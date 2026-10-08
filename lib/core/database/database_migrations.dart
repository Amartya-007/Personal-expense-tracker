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
  }
}
