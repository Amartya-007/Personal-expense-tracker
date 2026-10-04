import 'dart:async';
import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../constants/app_constants.dart';
import '../constants/default_categories.dart';
import '../logging/app_logger.dart';
import 'database_migrations.dart';
import 'database_tables.dart';

class DatabaseHelper {
  static final String _dbName = AppConstants.dbFileName;
  static const int _dbVersion = 1;

  static final DatabaseHelper instance = DatabaseHelper._internal();
  static Database? _database;

  DatabaseHelper._internal();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path;
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      path = join(docsDir.path, _dbName);
    } catch (_) {
      path = join(Directory.systemTemp.path, _dbName);
    }

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
      onUpgrade: DatabaseMigrations.migrate,
      // Prevent a crash when the user installs an older app version over a newer one.
      onDowngrade: (db, oldVersion, newVersion) async {
        await AppLogger.e(
          'Database downgrade detected (v$oldVersion → v$newVersion). '
          'Resetting database to avoid schema corruption.',
        );
        // Drop all known tables then recreate from scratch.
        await _dropAllTables(db);
        await _onCreate(db, newVersion);
      },
    );
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
    // ── 1. Core schema (one batch) ────────────────────────────────────────
    final schemaBatch = db.batch();
    schemaBatch.execute(DatabaseTables.createAccountsTable);
    schemaBatch.execute(DatabaseTables.createCategoriesTable);
    schemaBatch.execute(DatabaseTables.createCategoryRulesTable);
    schemaBatch.execute(DatabaseTables.createTagsTable);
    schemaBatch.execute(DatabaseTables.createTransactionsTable);
    schemaBatch.execute(DatabaseTables.createTransactionTagsTable);
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

    const defaultTags = [
      {'id': 'tag_college', 'name': 'College'},
      {'id': 'tag_personal', 'name': 'Personal'},
      {'id': 'tag_important', 'name': 'Important'},
      {'id': 'tag_travel', 'name': 'Travel'},
      {'id': 'tag_monthly', 'name': 'Monthly'},
      {'id': 'tag_office', 'name': 'Office'},
      {'id': 'tag_family', 'name': 'Family'},
      {'id': 'tag_tea','name':'Tea'}
    ];
    for (final tag in defaultTags) {
      seedBatch.insert('tags', {
        'id': tag['id'],
        'name': tag['name'],
      });
    }

    const defaultRules = [
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

    for (final rule in defaultRules) {
      seedBatch.insert('category_rules', {
        'id': rule['id'],
        'keyword': rule['keyword'],
        'category_id': rule['category_id'],
        'created_at': now,
      });
    }

    await seedBatch.commit(noResult: true);
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
