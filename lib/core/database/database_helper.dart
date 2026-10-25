import 'dart:async';
import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../constants/app_constants.dart';
import '../constants/default_categories.dart';
import '../../data/repositories/log_repository.dart';
import '../logging/app_logger.dart';
import '../logging/log_category.dart';
import 'database_migrations.dart';
import 'database_tables.dart';

class DatabaseHelper {
  static final String _dbName = AppConstants.dbFileName;
  static const int _dbVersion = 4;

  // Seed data created on first run. Shared with [deleteAllUserData] so that a
  // reset returns to exactly this state.
  static const List<Map<String, String>> _defaultTags = [
    {'id': 'tag_college', 'name': 'College'},
    {'id': 'tag_personal', 'name': 'Personal'},
    {'id': 'tag_important', 'name': 'Important'},
    {'id': 'tag_travel', 'name': 'Travel'},
    {'id': 'tag_monthly', 'name': 'Monthly'},
    {'id': 'tag_office', 'name': 'Office'},
    {'id': 'tag_family', 'name': 'Family'},
    {'id': 'tag_tea','name':'Tea'}
  ];

  static const List<Map<String, String>> _defaultRules = [
    {'id': 'rule_momos', 'keyword': 'momos', 'category_id': 'cat_food'},
    {'id': 'rule_swiggy', 'keyword': 'swiggy', 'category_id': 'cat_food'},
    {'id': 'rule_zomato', 'keyword': 'zomato', 'category_id': 'cat_food'},
    {'id': 'rule_pizza', 'keyword': 'pizza', 'category_id': 'cat_food'},
    {'id': 'rule_burger', 'keyword': 'burger', 'category_id': 'cat_food'},
    {'id': 'rule_chinese', 'keyword': 'chinese', 'category_id': 'cat_food'},
    {'id': 'rule_pen', 'keyword': 'pen', 'category_id': 'cat_stationery'},
    {
      'id': 'rule_notebook',
      'keyword': 'notebook',
      'category_id': 'cat_stationery',
    },
    {'id': 'rule_books', 'keyword': 'books', 'category_id': 'cat_stationery'},
    {
      'id': 'rule_screenguard',
      'keyword': 'screen guard',
      'category_id': 'cat_electronics',
    },
    {
      'id': 'rule_screenprot',
      'keyword': 'screen protector',
      'category_id': 'cat_electronics',
    },
    {
      'id': 'rule_charger',
      'keyword': 'charger',
      'category_id': 'cat_electronics',
    },
    {
      'id': 'rule_earphones',
      'keyword': 'earphones',
      'category_id': 'cat_electronics',
    },
    {
      'id': 'rule_recharge',
      'keyword': 'recharge',
      'category_id': 'cat_bills',
    },
    {
      'id': 'rule_electricity',
      'keyword': 'electricity',
      'category_id': 'cat_bills',
    },
    {'id': 'rule_uber', 'keyword': 'uber', 'category_id': 'cat_transport'},
    {'id': 'rule_ola', 'keyword': 'ola', 'category_id': 'cat_transport'},
    {
      'id': 'rule_rapido',
      'keyword': 'rapido',
      'category_id': 'cat_transport',
    },
    {
      'id': 'rule_petrol',
      'keyword': 'petrol',
      'category_id': 'cat_transport',
    },
    {'id': 'rule_amazon', 'keyword': 'amazon', 'category_id': 'cat_shopping'},
    {
      'id': 'rule_flipkart',
      'keyword': 'flipkart',
      'category_id': 'cat_shopping',
    },
  ];

  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;
  static String? _customDatabasePath;

  DatabaseHelper._internal() {
    // The logger persists into this database. Registered here so every path
    // that touches the database also has working logs.
    AppLogger.sink ??= LogRepository();
  }

  // Report a failing open once only: the logger's own writes retry the open.
  static bool _loggedInitFailure = false;

  /// Allows tests or custom configurations to specify an isolated database path.
  static void setCustomDatabasePath(String? path) {
    if (_database != null && _database!.isOpen) {
      AppLogger.holdWrites();
      _database!.close();
    }
    _database = null;
    _opening = null;
    _customDatabasePath = path;
  }

  static String? get customDatabasePath => _customDatabasePath;
  String? get activeCustomPath => _customDatabasePath;

  // Callers that arrive while the database is opening share that one open.
  static Future<Database>? _opening;

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) return _database!;
    return _opening ??= _initDatabase()
        .then((db) {
          _database = db;
          return db;
        })
        .whenComplete(() => _opening = null);
  }

  Future<Database> _initDatabase() async {
    // Log writes would need this database before it is ready; they queue in
    // memory and are written once it is open.
    AppLogger.holdWrites();
    try {
      final path = _customDatabasePath ?? await _defaultDatabasePath();
      final db = await _openDatabaseWithPath(path);
      AppLogger.info(
        'Database opened',
        category: LogCategory.database,
        details: 'schema version $_dbVersion',
      );
      return db;
    } catch (e, st) {
      if (!_loggedInitFailure) {
        _loggedInitFailure = true;
        AppLogger.error(
          'Database initialization failed',
          category: LogCategory.database,
          error: e,
          stackTrace: st,
        );
      }
      rethrow;
    } finally {
      AppLogger.releaseWrites();
    }
  }

  static Future<String> _defaultDatabasePath() async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      return join(docsDir.path, _dbName);
    } catch (_) {
      return join(
        Directory.systemTemp.path,
        'mykhata_test_${pid}_${identityHashCode(DatabaseHelper.instance)}.db',
      );
    }
  }

  Future<Database> _openDatabaseWithPath(String path) async {
    return await openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
        try {
          await db.execute('PRAGMA journal_mode = WAL');
          await db.execute('PRAGMA synchronous = NORMAL');
        } catch (_) {}
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
      // Prevent a crash when the user installs an older app version over a newer one.
      onDowngrade: (db, oldVersion, newVersion) async {
        AppLogger.error(
          'Database downgrade detected; resetting database to avoid schema '
          'corruption',
          category: LogCategory.database,
          details: 'v$oldVersion → v$newVersion',
        );
        // Drop all known tables then recreate from scratch.
        await _dropAllTables(db);
        await _onCreate(db, newVersion);
      },
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    AppLogger.info(
      'Database migration started',
      category: LogCategory.database,
      details: 'v$oldVersion → v$newVersion',
    );
    try {
      await DatabaseMigrations.migrate(db, oldVersion, newVersion);
      AppLogger.info(
        'Database migration completed',
        category: LogCategory.database,
        details: 'v$oldVersion → v$newVersion',
      );
    } catch (e, st) {
      AppLogger.error(
        'Database migration failed',
        category: LogCategory.database,
        details: 'v$oldVersion → v$newVersion',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Drops all application tables so `_onCreate` can recreate them cleanly
  /// after a version downgrade.
  Future<void> _dropAllTables(Database db) async {
    const tables = [
      'transactions_fts',
      'app_logs',
      'balance_adjustments',
      'sms_review_queue',
      'recurring_payments',
      'budgets',
      'receipts',
      'transaction_splits',
      'transaction_tags',
      'transactions',
      'category_rules',
      'tags',
      'categories',
      'accounts',
    ];
    for (final table in tables) {
      try {
        await db.execute('DROP TABLE IF EXISTS $table');
      } catch (_) {}
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    AppLogger.info(
      'Database created',
      category: LogCategory.database,
      details: 'schema version $version',
    );
    // ── 1. Core schema (one batch) ────────────────────────────────────────
    final schemaBatch = db.batch();
    schemaBatch.execute(DatabaseTables.createAccountsTable);
    schemaBatch.execute(DatabaseTables.createCategoriesTable);
    schemaBatch.execute(DatabaseTables.createCategoryRulesTable);
    schemaBatch.execute(DatabaseTables.createTagsTable);
    schemaBatch.execute(DatabaseTables.createTransactionsTable);
    schemaBatch.execute(DatabaseTables.createTransactionTagsTable);
    schemaBatch.execute(DatabaseTables.createTransactionSplitsTable);
    schemaBatch.execute(DatabaseTables.createReceiptsTable);
    schemaBatch.execute(DatabaseTables.createBudgetsTable);
    schemaBatch.execute(DatabaseTables.createRecurringPaymentsTable);
    schemaBatch.execute(DatabaseTables.createSmsReviewQueueTable);
    schemaBatch.execute(DatabaseTables.createBalanceAdjustmentsTable);
    schemaBatch.execute(DatabaseTables.createAppLogsTable);
    await schemaBatch.commit(noResult: true);

    // ── 2. FTS (separate batch — failure is non-fatal) ────────────────────
    // batch.execute() only queues SQL; committing outside the try would let
    // errors escape. Using a dedicated batch committed inside the try ensures
    // any FTS failure is truly swallowed.
    try {
      final ftsBatch = db.batch();
      ftsBatch.execute(DatabaseTables.createFtsTable);
      ftsBatch.execute(DatabaseTables.createFtsTriggerInsert);
      ftsBatch.execute(DatabaseTables.createFtsTriggerDelete);
      ftsBatch.execute(DatabaseTables.createFtsTriggerUpdate);
      await ftsBatch.commit(noResult: true);
    } catch (_) {
      // FTS5 unavailable on this SQLite build — search falls back to LIKE.
    }

    // ── 3. Indexes ─────────────────────────────────────────────────────────
    final indexBatch = db.batch();
    for (final sql in DatabaseTables.createIndexes) {
      indexBatch.execute(sql);
    }
    await indexBatch.commit(noResult: true);

    // ── 4. Seed data ───────────────────────────────────────────────────────
    final seedBatch = db.batch();
    final now = DateTime.now().millisecondsSinceEpoch;

    for (final cat in DefaultCategories.list) {
      seedBatch.insert('categories', {
        'id': cat.id,
        'name': cat.name,
        'icon': cat.icon,
        'color': cat.color,
        'type': cat.type,
        'is_default': 1,
        'created_at': now,
      });
    }

    for (final tag in _defaultTags) {
      seedBatch.insert('tags', {
        'id': tag['id'],
        'name': tag['name'],
      });
    }


    for (final rule in _defaultRules) {
      seedBatch.insert('category_rules', {
        'id': rule['id'],
        'keyword': rule['keyword'],
        'category_id': rule['category_id'],
        'created_at': now,
      });
    }

    await seedBatch.commit(noResult: true);
  }

  /// Permanently deletes everything the user created, in ONE transaction:
  /// either all of it is removed or, if anything fails, none of it is.
  ///
  /// Kept: the schema, default categories, and the default tags and
  /// categorisation rules (any of those the user had deleted are put back), so
  /// the database ends up in the same state as a fresh install.
  ///
  /// No logging inside the transaction: [AppLogger] writes to this same
  /// database and would wait for the transaction to finish.
  Future<void> deleteAllUserData() async {
    final db = await database;

    await db.transaction((txn) async {
      // Children before parents: foreign keys are enforced.
      const userTables = [
        'transaction_splits',
        'transaction_tags',
        'receipts',
        'transactions',
        'balance_adjustments',
        'recurring_payments',
        'budgets',
        'sms_review_queue',
        'app_logs',
        'accounts',
      ];
      for (final table in userTables) {
        await txn.delete(table);
      }

      // User-created categories only. Their rules go with them (ON DELETE CASCADE).
      await txn.delete('categories', where: 'is_default = 0');

      // Tags and rules the app does not seed.
      final tagIds = [for (final t in _defaultTags) t['id']!];
      await txn.delete(
        'tags',
        where: 'id NOT IN (${List.filled(tagIds.length, '?').join(',')})',
        whereArgs: tagIds,
      );
      final ruleIds = [for (final r in _defaultRules) r['id']!];
      await txn.delete(
        'category_rules',
        where: 'id NOT IN (${List.filled(ruleIds.length, '?').join(',')})',
        whereArgs: ruleIds,
      );

      // Put back any default category, tag, or rule the user had removed.
      final now = DateTime.now().millisecondsSinceEpoch;
      for (final cat in DefaultCategories.list) {
        await txn.insert(
          'categories',
          {
            'id': cat.id,
            'name': cat.name,
            'icon': cat.icon,
            'color': cat.color,
            'type': cat.type,
            'is_default': 1,
            'created_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      for (final tag in _defaultTags) {
        await txn.insert(
          'tags',
          {'id': tag['id'], 'name': tag['name']},
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
      for (final rule in _defaultRules) {
        await txn.insert(
          'category_rules',
          {
            'id': rule['id'],
            'keyword': rule['keyword'],
            'category_id': rule['category_id'],
            'created_at': now,
          },
          conflictAlgorithm: ConflictAlgorithm.ignore,
        );
      }
    });

    // Deleted rows otherwise linger in free pages and the WAL file. Not part of
    // the transaction (VACUUM cannot run inside one); failure is harmless.
    try {
      await db.execute('PRAGMA wal_checkpoint(TRUNCATE)');
    } catch (_) {}
    try {
      await db.execute('VACUUM');
    } catch (_) {}
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      // Write what is queued while the connection still exists, then keep
      // later log writes from reopening the file while it is closed (a
      // restore replaces it). Writing resumes when the database is reopened.
      await AppLogger.flush();
      AppLogger.holdWrites();
      await db.close();
      _database = null;
    }
  }
}
