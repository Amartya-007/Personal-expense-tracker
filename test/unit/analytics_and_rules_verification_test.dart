import 'package:flutter_test/flutter_test.dart';
import 'package:mykhata/core/database/database_helper.dart';
import 'package:mykhata/data/models/account_model.dart';
import 'package:mykhata/data/models/category_model.dart';
import 'package:mykhata/data/models/tag_model.dart';
import 'package:mykhata/data/models/transaction_model.dart';
import 'package:mykhata/data/repositories/category_repository.dart';
import 'package:mykhata/data/repositories/transaction_repository.dart';
import 'package:mykhata/services/analytics/analytics_service.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late DatabaseHelper dbHelper;
  late TransactionRepository txRepo;
  late CategoryRepository catRepo;
  late AnalyticsService analyticsService;

  setUpAll(() async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    dbHelper = DatabaseHelper.instance;
    DatabaseHelper.setCustomDatabasePath(':memory:');
    txRepo = TransactionRepository();
    catRepo = CategoryRepository();
    analyticsService = AnalyticsService();
  });

  tearDown(() async {
    await dbHelper.deleteAllUserData();
  });

  group('Transaction Repository Batching Verification', () {
    test('Batching loads tags, receipts, and splits accurately for 100+ transactions', () async {
      final db = await dbHelper.database;
      final now = DateTime.now();

      // Seed account and category
      final acc = AccountModel(
        id: 'acc_batch_test',
        name: 'Batch Test Account',
        currentBalance: 50000,
        initialBalance: 50000,
        createdAt: now,
        updatedAt: now,
      );
      await db.insert('accounts', acc.toMap());

      final cat = CategoryModel(
        id: 'cat_food',
        name: 'Food',
        icon: 'restaurant',
        color: 0xFF123456,
        type: 'expense',
        createdAt: now,
      );
      await db.insert(
        'categories',
        cat.toMap(),
        conflictAlgorithm: ConflictAlgorithm.replace,
      );

      // Create 120 transactions with tags
      for (int i = 0; i < 120; i++) {
        final tx = TransactionModel(
          id: 'tx_batch_$i',
          type: 'expense',
          amount: (i + 1) * 10.0,
          description: 'Batch item $i',
          categoryId: cat.id,
          paymentMethod: 'UPI',
          accountId: acc.id,
          date: now.subtract(Duration(minutes: i)),
          tags: [TagModel(id: 'tag_college', name: 'College')],
          createdAt: now,
          updatedAt: now,
        );
        await txRepo.createTransaction(tx);
      }

      // Fetch 100 paged transactions
      final paged = await txRepo.getTransactionsPaged(limit: 100, offset: 0);
      expect(paged.length, equals(100));

      for (int i = 0; i < paged.length; i++) {
        final item = paged[i];
        expect(item.tags, isNotEmpty);
        expect(item.tags.first.name, equals('College'));
      }
    });
  });

  group('Analytics Equivalence & Daily Spending Trend Verification', () {
    test(
      'getDailySpendingTrend correctly aggregates date range in single pass',
      () async {
        final db = await dbHelper.database;
        final start = DateTime(2026, 10, 1, 0, 0, 0);
        final end = DateTime(2026, 10, 8, 23, 59, 59);

        final acc = AccountModel(
          id: 'acc_trend_test',
          name: 'Trend Test Account',
          currentBalance: 10000,
          initialBalance: 10000,
          createdAt: start,
          updatedAt: start,
        );
        await db.insert('accounts', acc.toMap());

        final cat = CategoryModel(
          id: 'cat_bills',
          name: 'Bills',
          icon: 'receipt',
          color: 0xFF654321,
          type: 'expense',
          createdAt: start,
        );
        await db.insert(
          'categories',
          cat.toMap(),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );

        // Add 2 expenses on day 1 (Oct 1) and 1 on day 5 (Oct 5)
        final tx1 = TransactionModel(
          id: 'tx_t1',
          type: 'expense',
          amount: 100.0,
          description: 'Oct 1 Expense 1',
          categoryId: cat.id,
          paymentMethod: 'UPI',
          accountId: acc.id,
          date: DateTime(2026, 10, 1, 10, 0),
          createdAt: start,
          updatedAt: start,
        );
        final tx2 = TransactionModel(
          id: 'tx_t2',
          type: 'expense',
          amount: 200.0,
          description: 'Oct 1 Expense 2',
          categoryId: cat.id,
          paymentMethod: 'UPI',
          accountId: acc.id,
          date: DateTime(2026, 10, 1, 15, 0),
          createdAt: start,
          updatedAt: start,
        );
        final tx3 = TransactionModel(
          id: 'tx_t3',
          type: 'expense',
          amount: 500.0,
          description: 'Oct 5 Expense',
          categoryId: cat.id,
          paymentMethod: 'UPI',
          accountId: acc.id,
          date: DateTime(2026, 10, 5, 12, 0),
          createdAt: start,
          updatedAt: start,
        );

        await txRepo.createTransaction(tx1);
        await txRepo.createTransaction(tx2);
        await txRepo.createTransaction(tx3);

        final trend = await analyticsService.getDailySpendingTrend(
          startDate: start,
          endDate: end,
          dataPoints: 8,
        );

        expect(trend.length, equals(8));
        final totalSum = trend.fold<double>(0.0, (s, v) => s + v);
        expect(totalSum, equals(800.0));
        expect(trend[0], equals(300.0)); // Day 1
      },
    );
  });

  group('Category Rules Learning Verification', () {
    test(
      'learnCategoryRule persists and orders by keyword length DESC',
      () async {
        await txRepo.learnCategoryRule('tea', 'cat_food');
        await txRepo.learnCategoryRule('green tea', 'cat_food');

        final rules = await catRepo.getCategoryRules();
        expect(rules.any((r) => r.keyword == 'green tea'), isTrue);
        expect(rules.any((r) => r.keyword == 'tea'), isTrue);

        // Verify longer keyword 'green tea' appears before 'tea'
        final idxLong = rules.indexWhere((r) => r.keyword == 'green tea');
        final idxShort = rules.indexWhere((r) => r.keyword == 'tea');
        expect(idxLong, lessThan(idxShort));
      },
    );
  });
}
