import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mykhata/core/database/database_helper.dart';
import 'package:mykhata/core/database/database_migrations.dart';
import 'package:mykhata/data/models/khata_entry_model.dart';
import 'package:mykhata/data/repositories/khata_repository.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  Directory? tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    tempDir = await Directory.systemTemp.createTemp('mykhata_khata_mig_');
  });

  tearDownAll(() async {
    await DatabaseHelper.instance.close();
    DatabaseHelper.setCustomDatabasePath(null);
    try {
      if (tempDir != null && await tempDir!.exists()) {
        await tempDir!.delete(recursive: true);
      }
    } catch (_) {}
  });

  group('Khata Forward Migration & Persistence Tests', () {
    test('Migrates existing v4 database to v5 without resetting or losing data', () async {
      final dbPath = p.join(tempDir!.path, 'v4_to_v5_test.db');

      // 1. Manually open a database at version 4 and seed legacy data
      final legacyDb = await openDatabase(
        dbPath,
        version: 4,
        onCreate: (db, version) async {
          await db.execute('''
            CREATE TABLE accounts (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              current_balance REAL NOT NULL,
              initial_balance REAL NOT NULL,
              is_active INTEGER NOT NULL DEFAULT 1,
              is_primary INTEGER NOT NULL DEFAULT 0,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            );
          ''');
          await db.execute('''
            CREATE TABLE app_logs (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              timestamp INTEGER NOT NULL,
              level TEXT NOT NULL,
              category TEXT NOT NULL DEFAULT 'app',
              message TEXT NOT NULL,
              details TEXT,
              error TEXT,
              stack_trace TEXT
            );
          ''');
        },
      );

      final now = DateTime.now().millisecondsSinceEpoch;
      await legacyDb.insert('accounts', {
        'id': 'acc-legacy-1',
        'name': 'Existing Account',
        'current_balance': 5000.0,
        'initial_balance': 5000.0,
        'is_active': 1,
        'is_primary': 1,
        'created_at': now,
        'updated_at': now,
      });

      await legacyDb.close();

      // 2. Perform migration using DatabaseMigrations.migrate
      final migratedDb = await openDatabase(
        dbPath,
        version: 5,
        onUpgrade: (db, oldVersion, newVersion) async {
          await DatabaseMigrations.migrate(db, oldVersion, newVersion);
        },
      );

      // Verify legacy data preserved
      final accounts = await migratedDb.query('accounts');
      expect(accounts.length, equals(1));
      expect(accounts.first['name'], equals('Existing Account'));

      // Verify new Khata tables exist
      final tables = await migratedDb.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('khata_people', 'khata_entries')",
      );
      final tableNames = tables.map((t) => t['name'] as String).toSet();
      expect(tableNames.contains('khata_people'), isTrue);
      expect(tableNames.contains('khata_entries'), isTrue);

      // Verify Khata indexes exist
      final indexes = await migratedDb.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index' AND name LIKE 'idx_khata%'",
      );
      expect(indexes.length, greaterThanOrEqualTo(3));

      await migratedDb.close();

      // 3. Reopening the database via DatabaseHelper and performing operations
      DatabaseHelper.setCustomDatabasePath(dbPath);
      final repo = KhataRepository();

      final person = await repo.createPerson(name: 'Migration User');
      await repo.addEntry(
        personId: person.id,
        type: KhataEntryType.lent,
        amount: 350.0,
        date: DateTime.now(),
      );

      final fetched = await repo.getPersonById(person.id);
      expect(fetched?.netBalance, equals(350.0));
      expect(fetched?.isReceivable, isTrue);

      await DatabaseHelper.instance.close();
      DatabaseHelper.setCustomDatabasePath(null);
    });
  });
}
