import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mykhata/core/constants/app_constants.dart';
import 'package:mykhata/core/database/database_helper.dart';
import 'package:mykhata/core/database/database_migrations.dart';
import 'package:mykhata/core/database/database_tables.dart';
import 'package:mykhata/core/logging/app_logger.dart';
import 'package:mykhata/core/logging/log_category.dart';
import 'package:mykhata/core/logging/log_entry.dart';
import 'package:mykhata/core/logging/log_filter.dart';
import 'package:mykhata/core/logging/log_level.dart';
import 'package:mykhata/data/repositories/log_repository.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

AppLogEntry _entry(
  String message, {
  LogLevel level = LogLevel.info,
  LogCategory category = LogCategory.app,
  int atMs = 1000,
  String? details,
  String? error,
  String? stackTrace,
}) => AppLogEntry(
  timestamp: DateTime.fromMillisecondsSinceEpoch(atMs),
  level: level,
  category: category,
  message: message,
  details: details,
  error: error,
  stackTrace: stackTrace,
);

void main() {
  Directory? tempDir;
  final repo = LogRepository();

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    tempDir = await Directory.systemTemp.createTemp('mykhata_test_logs_');
    DatabaseHelper.setCustomDatabasePath(p.join(tempDir!.path, 'logs.db'));
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

  setUp(() async {
    AppLogger.echoToConsole = false;
    await DatabaseHelper.instance.database;
    // Let the logger's own "database opened" entry land, then start empty.
    await AppLogger.flush();
    await repo.clearAll();
  });

  group('LogRepository: create and read', () {
    test('stores and reads back every field', () async {
      await repo.insert(
        _entry(
          'Backup failed',
          level: LogLevel.error,
          category: LogCategory.backup,
          atMs: 5000,
          details: 'step 3',
          error: 'Bad state: disk full',
          stackTrace: '#0 main (x.dart:1:1)',
        ),
      );

      final all = await repo.getLogs();
      expect(all, hasLength(1));
      final e = all.single;
      expect(e.id, isNotNull);
      expect(e.timestamp.millisecondsSinceEpoch, 5000);
      expect(e.level, LogLevel.error);
      expect(e.category, LogCategory.backup);
      expect(e.message, 'Backup failed');
      expect(e.details, 'step 3');
      expect(e.error, 'Bad state: disk full');
      expect(e.stackTrace, '#0 main (x.dart:1:1)');
    });

    test('optional fields stay null when absent', () async {
      await repo.insert(_entry('plain'));
      final e = (await repo.getLogs()).single;
      expect(e.details, isNull);
      expect(e.error, isNull);
      expect(e.stackTrace, isNull);
    });

    test('getById returns the entry, or null when it does not exist', () async {
      await repo.insert(_entry('one'));
      final id = (await repo.getLogs()).single.id!;
      expect((await repo.getById(id))!.message, 'one');
      expect(await repo.getById(id + 999), isNull);
    });

    test('writeBatch keeps the order of the entries it is given', () async {
      await repo.writeBatch([
        _entry('a', atMs: 1),
        _entry('b', atMs: 1),
        _entry('c', atMs: 1),
      ]);
      // Same timestamp: the later insert is "newer".
      expect((await repo.getLogs()).map((e) => e.message), ['c', 'b', 'a']);
    });
  });

  group('LogRepository: ordering and paging', () {
    test('returns newest first regardless of insertion order', () async {
      await repo.insert(_entry('middle', atMs: 2000));
      await repo.insert(_entry('newest', atMs: 3000));
      await repo.insert(_entry('oldest', atMs: 1000));

      expect((await repo.getLogs()).map((e) => e.message), [
        'newest',
        'middle',
        'oldest',
      ]);
    });

    test('limit and offset page through the log without overlap', () async {
      for (var i = 0; i < 25; i++) {
        await repo.insert(_entry('m$i', atMs: 1000 + i));
      }
      final page1 = await repo.getLogs(limit: 10);
      final page2 = await repo.getLogs(limit: 10, offset: 10);
      final page3 = await repo.getLogs(limit: 10, offset: 20);

      expect(page1.first.message, 'm24');
      expect(page1, hasLength(10));
      expect(page2.first.message, 'm14');
      expect(page3, hasLength(5));
      expect(page3.last.message, 'm0');
      final all = [...page1, ...page2, ...page3].map((e) => e.id).toSet();
      expect(all, hasLength(25));
    });

    test('count matches the stored rows', () async {
      expect(await repo.count(), 0);
      await repo.insert(_entry('a'));
      await repo.insert(_entry('b'));
      expect(await repo.count(), 2);
    });
  });

  group('LogRepository: filtering and search', () {
    setUp(() async {
      await repo.writeBatch([
        _entry('Database opened', category: LogCategory.database, atMs: 1),
        _entry(
          'Backup failed',
          level: LogLevel.error,
          category: LogCategory.backup,
          atMs: 2,
        ),
        _entry(
          'Restore rejected',
          level: LogLevel.warning,
          category: LogCategory.restore,
          atMs: 3,
        ),
        _entry('SMS scan completed', category: LogCategory.sms, atMs: 4),
        _entry(
          'Migration failed',
          level: LogLevel.error,
          category: LogCategory.database,
          atMs: 5,
        ),
      ]);
    });

    Future<List<String>> messages(LogFilter f) async =>
        (await repo.getLogs(filter: f)).map((e) => e.message).toList();

    test('filters by level', () async {
      expect(await messages(const LogFilter(level: LogLevel.error)), [
        'Migration failed',
        'Backup failed',
      ]);
      expect(await messages(const LogFilter(level: LogLevel.warning)), [
        'Restore rejected',
      ]);
      expect(await messages(const LogFilter(level: LogLevel.debug)), isEmpty);
    });

    test('filters by category', () async {
      expect(await messages(const LogFilter(category: LogCategory.database)), [
        'Migration failed',
        'Database opened',
      ]);
    });

    test('combines level, category and search', () async {
      expect(
        await messages(
          const LogFilter(
            level: LogLevel.error,
            category: LogCategory.database,
            query: 'migration',
          ),
        ),
        ['Migration failed'],
      );
      expect(
        await messages(
          const LogFilter(level: LogLevel.warning, category: LogCategory.sms),
        ),
        isEmpty,
      );
    });

    test('searches the message, case-insensitively', () async {
      expect(await messages(const LogFilter(query: 'FAILED')), [
        'Migration failed',
        'Backup failed',
      ]);
    });

    test('searches the category too', () async {
      expect(await messages(const LogFilter(query: 'restore')), [
        'Restore rejected',
      ]);
      expect(await messages(const LogFilter(query: 'sms')), [
        'SMS scan completed',
      ]);
    });

    test('a blank query means no search', () async {
      expect(
        await repo.getLogs(filter: const LogFilter(query: '   ')),
        hasLength(5),
      );
    });

    test('count honours the filter', () async {
      expect(
        await repo.count(filter: const LogFilter(level: LogLevel.error)),
        2,
      );
      expect(
        await repo.count(filter: const LogFilter(query: 'nothing here')),
        0,
      );
    });

    test(
      '% and _ in the search text match themselves, not as wildcards',
      () async {
        await repo.insert(_entry('progress 100% done', atMs: 10));
        await repo.insert(_entry('progress 1000 done', atMs: 11));
        await repo.insert(_entry('snake_case name', atMs: 12));
        await repo.insert(_entry('snakeXcase name', atMs: 13));

        expect(await messages(const LogFilter(query: '100%')), [
          'progress 100% done',
        ]);
        expect(await messages(const LogFilter(query: 'snake_case')), [
          'snake_case name',
        ]);
      },
    );
  });

  group('LogRepository: delete and clear', () {
    test('deleteById removes only that entry', () async {
      await repo.insert(_entry('keep', atMs: 1));
      await repo.insert(_entry('drop', atMs: 2));
      final drop = (await repo.getLogs()).firstWhere(
        (e) => e.message == 'drop',
      );

      expect(await repo.deleteById(drop.id!), 1);
      expect((await repo.getLogs()).map((e) => e.message), ['keep']);
      expect(await repo.deleteById(drop.id!), 0);
    });

    test('clearAll removes everything and reports how many', () async {
      await repo.insert(_entry('a'));
      await repo.insert(_entry('b'));
      await repo.insert(_entry('c'));

      expect(await repo.clearAll(), 3);
      expect(await repo.getLogs(), isEmpty);
      expect(await repo.count(), 0);
      expect(await repo.clearAll(), 0);
    });
  });

  group('LogRepository: retention', () {
    test('trim keeps only the newest entries', () async {
      for (var i = 0; i < 12; i++) {
        await repo.insert(_entry('m$i', atMs: 1000 + i));
      }
      await repo.trim(5);

      final left = (await repo.getLogs()).map((e) => e.message).toList();
      expect(left, ['m11', 'm10', 'm9', 'm8', 'm7']);
    });

    test('trim does nothing while under the limit', () async {
      for (var i = 0; i < 4; i++) {
        await repo.insert(_entry('m$i'));
      }
      await repo.trim(10);
      expect(await repo.count(), 4);
      await repo.trim(4);
      expect(await repo.count(), 4);
    });

    test('the default limit is the configured maximum', () {
      expect(AppConstants.maxLogEntries, 5000);
    });

    test('a normal write leaves entries alone while under the limit', () async {
      // The logger trims with AppConstants.maxLogEntries after writing.
      await repo.insert(_entry('existing', atMs: 1));
      AppLogger.info('new entry', category: LogCategory.settings);
      await AppLogger.flush();
      expect(await repo.count(), 2);
    });
  });

  group('AppLogger with the SQLite sink', () {
    test('an error log is stored with its error and stack trace', () async {
      AppLogger.error(
        'Database initialization failed',
        category: LogCategory.database,
        error: StateError('cannot open'),
        stackTrace: StackTrace.current,
      );
      await AppLogger.flush();

      final e = (await repo.getLogs(
        filter: const LogFilter(level: LogLevel.error),
      )).single;
      expect(e.category, LogCategory.database);
      expect(e.message, 'Database initialization failed');
      expect(e.error, contains('cannot open'));
      expect(e.stackTrace, isNotNull);
    });

    test('sensitive text is masked before it is stored', () async {
      AppLogger.info(
        'Debited account 12345678901234',
        category: LogCategory.transactions,
        details: 'amount ₹2,500.00 password: secret1',
      );
      await AppLogger.flush();

      final e = (await repo.getLogs()).single;
      final stored = '${e.message} ${e.details}';
      expect(stored, isNot(contains('12345678901234')));
      expect(stored, isNot(contains('2,500')));
      expect(stored, isNot(contains('secret1')));
      expect(stored, contains('****1234'));
    });

    test('a failing log write does not throw or break later logging', () async {
      final db = await DatabaseHelper.instance.database;
      await db.execute('DROP TABLE app_logs');
      try {
        AppLogger.error('this write fails', error: Exception('x'));
        await AppLogger.flush(); // must complete without throwing
      } finally {
        await db.execute(DatabaseTables.createAppLogsTable);
      }

      AppLogger.info('after the failure');
      await AppLogger.flush();
      expect((await repo.getLogs()).map((e) => e.message), [
        'after the failure',
      ]);
    });
  });

  group('Database migration to schema v4', () {
    Future<Database> openLegacy() => databaseFactory.openDatabase(
      inMemoryDatabasePath,
      options: OpenDatabaseOptions(
        singleInstance: false,
        onCreate: (db, v) async {
          // The log table exactly as it was before this version.
          await db.execute('''
            CREATE TABLE app_logs (
              id INTEGER PRIMARY KEY AUTOINCREMENT,
              timestamp INTEGER NOT NULL,
              level TEXT NOT NULL,
              message TEXT NOT NULL,
              details TEXT
            )
          ''');
          await db.insert('app_logs', {
            'timestamp': 1,
            'level': 'INFO',
            'message': 'Created transaction: Momos (₹120.0)',
          });
        },
        version: 1,
      ),
    );

    Future<Set<Object?>> columns(Database db) async => {
      for (final c in await db.rawQuery('PRAGMA table_info(app_logs)'))
        c['name'],
    };

    test('adds the new columns and discards free-text legacy rows', () async {
      final db = await openLegacy();
      addTearDown(db.close);

      await DatabaseMigrations.migrate(db, 3, 4);

      final cols = await columns(db);
      expect(cols, containsAll(<String>['category', 'error', 'stack_trace']));
      // Old rows held names/amounts and are never shown or exported.
      expect(await db.query('app_logs'), isEmpty);

      // New-style rows work, and a row without a category defaults to 'app'.
      await db.insert('app_logs', {
        'timestamp': 2,
        'level': 'info',
        'message': 'x',
      });
      expect((await db.query('app_logs')).single['category'], 'app');
    });

    test('creates the indexes and is safe to run twice', () async {
      final db = await openLegacy();
      addTearDown(db.close);

      await DatabaseMigrations.migrate(db, 3, 4);
      await db.insert('app_logs', {
        'timestamp': 2,
        'level': 'info',
        'category': 'backup',
        'message': 'kept',
      });
      await DatabaseMigrations.migrate(db, 3, 4);

      final idx = (await db.rawQuery("PRAGMA index_list('app_logs')"))
          .map((r) => r['name'])
          .toSet();
      expect(
        idx,
        containsAll(<String>[
          'idx_app_logs_time',
          'idx_app_logs_level',
          'idx_app_logs_category',
        ]),
      );
      // The second run found the columns already there and kept the row.
      expect((await db.query('app_logs')).single['message'], 'kept');
    });

    test('creates the table when it does not exist yet', () async {
      final db = await databaseFactory.openDatabase(
        inMemoryDatabasePath,
        options: OpenDatabaseOptions(singleInstance: false),
      );
      addTearDown(db.close);

      await DatabaseMigrations.migrate(db, 3, 4);
      expect(
        await columns(db),
        containsAll(<String>['category', 'stack_trace']),
      );
    });
  });
}
