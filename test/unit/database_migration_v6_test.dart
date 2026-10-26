import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mykhata/core/database/database_helper.dart';
import 'package:mykhata/core/database/database_migrations.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  Directory? tempDir;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    tempDir = await Directory.systemTemp.createTemp('mykhata_v6_mig_');
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

  group('Database Migration v5 to v6 Tests', () {
    test('Migrates existing v5 database to v6, preserving legacy data and creating expense split tables', () async {
      final dbPath = p.join(tempDir!.path, 'v5_to_v6_test.db');

      // 1. Setup a v5 database with existing accounts, transactions, and khata_people
      final v5Db = await openDatabase(
        dbPath,
        version: 5,
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
            CREATE TABLE khata_people (
              id TEXT PRIMARY KEY,
              name TEXT NOT NULL,
              phone TEXT,
              notes TEXT,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            );
          ''');
          await db.execute('''
            CREATE TABLE khata_entries (
              id TEXT PRIMARY KEY,
              person_id TEXT NOT NULL,
              type TEXT NOT NULL,
              amount REAL NOT NULL,
              notes TEXT,
              date INTEGER NOT NULL,
              is_settled INTEGER NOT NULL DEFAULT 0,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            );
          ''');
        },
      );

      final now = DateTime.now().millisecondsSinceEpoch;
      await v5Db.insert('accounts', {
        'id': 'acc-1',
        'name': 'HDFC Bank',
        'current_balance': 25000.0,
        'initial_balance': 25000.0,
        'is_active': 1,
        'is_primary': 1,
        'created_at': now,
        'updated_at': now,
      });

      await v5Db.insert('khata_people', {
        'id': 'person-legacy-1',
        'name': 'Rahul Sharma',
        'phone': '9876543210',
        'notes': 'Colleague',
        'created_at': now,
        'updated_at': now,
      });

      await v5Db.close();

      // 2. Perform migration to version 6
      final v6Db = await openDatabase(
        dbPath,
        version: 6,
        onUpgrade: (db, oldVersion, newVersion) async {
          await DatabaseMigrations.migrate(db, oldVersion, newVersion);
        },
      );

      // Verify existing data remains perfectly intact
      final accounts = await v6Db.query('accounts');
      expect(accounts.length, equals(1));
      expect(accounts.first['name'], equals('HDFC Bank'));

      final people = await v6Db.query('khata_people');
      expect(people.length, equals(1));
      expect(people.first['name'], equals('Rahul Sharma'));
      // Verify newly added columns exist on khata_people
      expect(people.first.containsKey('contact_id'), isTrue);
      expect(people.first.containsKey('source'), isTrue);

      // Verify newly created expense split and group tables exist
      final tables = await v6Db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name IN ('expense_groups', 'group_members', 'expense_splits', 'split_participants')",
      );
      final tableNames = tables.map((t) => t['name'] as String).toSet();
      expect(tableNames, contains('expense_groups'));
      expect(tableNames, contains('group_members'));
      expect(tableNames, contains('expense_splits'));
      expect(tableNames, contains('split_participants'));

      // Test inserting into the new tables
      await v6Db.insert('expense_groups', {
        'id': 'grp-1',
        'name': 'Goa Trip 2026',
        'description': 'Vacation with friends',
        'icon': '🌴',
        'color': '#0D9488',
        'is_archived': 0,
        'created_at': now,
        'updated_at': now,
      });

      await v6Db.insert('group_members', {
        'id': 'gm-1',
        'group_id': 'grp-1',
        'person_id': 'person-legacy-1',
        'created_at': now,
      });

      final groups = await v6Db.query('expense_groups');
      expect(groups.length, equals(1));
      expect(groups.first['name'], equals('Goa Trip 2026'));

      final members = await v6Db.query('group_members');
      expect(members.length, equals(1));

      await v6Db.close();
    });
  });
}
