import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mykhata/core/database/database_helper.dart';
import 'package:mykhata/core/utils/date_filters.dart';
import 'package:mykhata/data/models/tag_model.dart';
import 'package:mykhata/data/models/transaction_model.dart';
import 'package:mykhata/data/repositories/transaction_repository.dart';
import 'package:mykhata/presentation/providers/transaction_providers.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  Directory? tempDir;
  late TransactionRepository repository;
  late DatabaseHelper dbHelper;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    tempDir = await Directory.systemTemp.createTemp('mykhata_test_filter_');
    DatabaseHelper.setCustomDatabasePath(p.join(tempDir!.path, 'mykhata_filter.db'));

    dbHelper = DatabaseHelper.instance;
    await dbHelper.database;
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
    final db = await dbHelper.database;
    await db.execute('PRAGMA foreign_keys = OFF;');
    await dbHelper.deleteAllUserData();
    await db.execute('PRAGMA foreign_keys = ON;');
    repository = TransactionRepository();
  });

  group('Transaction Universal Search & Advanced Filtering Tests', () {
    test('Universal search finds transactions by merchant, note, location, category, tag, account, and amount', () async {
      final now = DateTime.now();

      // Seed Account
      final db = await dbHelper.database;
      await db.insert('accounts', {
        'id': 'acc_sbi',
        'name': 'SBI Bank Account',
        'current_balance': 50000.0,
        'initial_balance': 50000.0,
        'is_active': 1,
        'is_primary': 1,
        'created_at': now.millisecondsSinceEpoch,
        'updated_at': now.millisecondsSinceEpoch,
      });

      // Seed Category
      await db.insert('categories', {
        'id': 'cat_groceries',
        'name': 'Groceries & Supermarket',
        'icon': 'shopping_cart',
        'color': 0xFF4CAF50,
        'type': 'expense',
        'is_default': 1,
        'created_at': now.millisecondsSinceEpoch,
      }, conflictAlgorithm: ConflictAlgorithm.replace);

      // Seed Tag
      await db.insert('tags', {
        'id': 'tag_home',
        'name': 'HomeExpenses',
      });

      // Transaction 1: Amazon Groceries with Tag
      final tx1 = TransactionModel(
        id: 'tx_1',
        type: 'expense',
        amount: 1499.0,
        description: 'Amazon Fresh Order #1024',
        categoryId: 'cat_groceries',
        paymentMethod: 'UPI',
        accountId: 'acc_sbi',
        date: now.subtract(const Duration(hours: 2)),
        note: 'Weekly vegetable restocking',
        locationName: 'Bangalore West',
        createdAt: now,
        updatedAt: now,
        tags: [TagModel(id: 'tag_home', name: 'HomeExpenses')],
      );

      // Transaction 2: Swiggy Dinner
      final tx2 = TransactionModel(
        id: 'tx_2',
        type: 'expense',
        amount: 450.0,
        description: 'Swiggy Dinner Biryani',
        paymentMethod: 'Credit Card',
        accountId: 'acc_sbi',
        date: now.subtract(const Duration(days: 1)),
        note: 'Paid via Amazon Pay ICICI',
        locationName: 'Indiranagar',
        createdAt: now,
        updatedAt: now,
      );

      // Transaction 3: Salary Income
      final tx3 = TransactionModel(
        id: 'tx_3',
        type: 'income',
        amount: 85000.0,
        description: 'Monthly Salary TechCorp',
        paymentMethod: 'Net Banking',
        accountId: 'acc_sbi',
        date: now.subtract(const Duration(days: 5)),
        note: 'October Salary Direct Deposit',
        createdAt: now,
        updatedAt: now,
      );

      await repository.createTransaction(tx1);
      await repository.createTransaction(tx2);
      await repository.createTransaction(tx3);

      // 1. Search partial merchant/description "Amazon" -> matches tx1 and tx2 (note contains Amazon Pay)
      final searchAmazon = await repository.getTransactionsPaged(searchQuery: 'amazon');
      expect(searchAmazon.length, equals(2));
      expect(searchAmazon.map((t) => t.id), containsAll(['tx_1', 'tx_2']));

      // 2. Search category "Groceries" -> matches tx1
      final searchCat = await repository.getTransactionsPaged(searchQuery: 'groceries');
      expect(searchCat.length, equals(1));
      expect(searchCat.first.id, equals('tx_1'));

      // 3. Search note "vegetable" -> matches tx1
      final searchNote = await repository.getTransactionsPaged(searchQuery: 'vegetable');
      expect(searchNote.length, equals(1));
      expect(searchNote.first.id, equals('tx_1'));

      // 4. Search tag "HomeExpenses" -> matches tx1
      final searchTag = await repository.getTransactionsPaged(searchQuery: 'HomeExpenses');
      expect(searchTag.length, equals(1));
      expect(searchTag.first.id, equals('tx_1'));

      // 5. Search account "SBI" -> matches tx1, tx2, tx3
      final searchAcc = await repository.getTransactionsPaged(searchQuery: 'SBI');
      expect(searchAcc.length, equals(3));

      // 6. Search location "Indiranagar" -> matches tx2
      final searchLoc = await repository.getTransactionsPaged(searchQuery: 'Indiranagar');
      expect(searchLoc.length, equals(1));
      expect(searchLoc.first.id, equals('tx_2'));

      // 7. Search numeric amount "1499" or "450"
      final searchAmount = await repository.getTransactionsPaged(searchQuery: '450');
      expect(searchAmount.length, equals(1));
      expect(searchAmount.first.id, equals('tx_2'));

      // 8. Search amount condition "above 50000" -> matches tx3 (85000)
      final searchAbove = await repository.getTransactionsPaged(searchQuery: 'above 50000');
      expect(searchAbove.length, equals(1));
      expect(searchAbove.first.id, equals('tx_3'));
    });

    test('Filtered summary correctly totals expenses and income while excluding transfers', () async {
      final now = DateTime.now();

      final db = await dbHelper.database;
      await db.insert('accounts', {
        'id': 'acc_1',
        'name': 'Primary Bank',
        'current_balance': 100000.0,
        'initial_balance': 100000.0,
        'is_active': 1,
        'is_primary': 1,
        'created_at': now.millisecondsSinceEpoch,
        'updated_at': now.millisecondsSinceEpoch,
      });

      final txExpense1 = TransactionModel(
        id: 't_exp1',
        type: 'expense',
        amount: 2000.0,
        description: 'Rent Part 1',
        paymentMethod: 'UPI',
        accountId: 'acc_1',
        date: now,
        createdAt: now,
        updatedAt: now,
      );

      final txExpense2 = TransactionModel(
        id: 't_exp2',
        type: 'expense',
        amount: 1500.0,
        description: 'Shopping',
        paymentMethod: 'UPI',
        accountId: 'acc_1',
        date: now,
        createdAt: now,
        updatedAt: now,
      );

      final txIncome = TransactionModel(
        id: 't_inc',
        type: 'income',
        amount: 10000.0,
        description: 'Freelance Payout',
        paymentMethod: 'UPI',
        accountId: 'acc_1',
        date: now,
        createdAt: now,
        updatedAt: now,
      );

      final txTransfer = TransactionModel(
        id: 't_trf',
        type: 'transfer',
        amount: 5000.0,
        description: 'Transfer to Savings',
        paymentMethod: 'Net Banking',
        accountId: 'acc_1',
        destinationAccountId: 'acc_1',
        date: now,
        createdAt: now,
        updatedAt: now,
      );

      await repository.createTransaction(txExpense1);
      await repository.createTransaction(txExpense2);
      await repository.createTransaction(txIncome);
      await repository.createTransaction(txTransfer);

      final summary = await repository.getFilteredSummary();

      expect(summary.count, equals(4));
      expect(summary.totalExpense, equals(3500.0)); // 2000 + 1500
      expect(summary.totalIncome, equals(10000.0)); // 10000
      // Transfer (5000) is NOT added to expenses or income!
    });

    test('TransactionFilter state and DateFilters periods work as expected', () {
      final now = DateTime(2026, 10, 12, 11, 30);

      // DateFilters range tests
      final todayRange = DateFilters.rangeFor('Today', now: now);
      expect(todayRange, isNotNull);
      expect(todayRange!.start, equals(DateTime(2026, 10, 12, 0, 0, 0, 0)));
      expect(todayRange.end, equals(DateTime(2026, 10, 12, 23, 59, 59, 999)));

      final lastMonthRange = DateFilters.rangeFor('Last Month', now: now);
      expect(lastMonthRange, isNotNull);
      expect(lastMonthRange!.start, equals(DateTime(2026, 9, 1, 0, 0, 0, 0)));
      expect(lastMonthRange.end, equals(DateTime(2026, 9, 30, 23, 59, 59, 999)));

      // TransactionFilter active count test
      const defaultFilter = TransactionFilter();
      expect(defaultFilter.hasAnyFilter, isFalse);
      expect(defaultFilter.activeFilterCount, equals(0));

      final activeFilter = defaultFilter.copyWith(
        type: 'expense',
        datePeriod: 'This Month',
        minAmount: 100.0,
        categoryIds: ['cat_food'],
        paymentMethods: ['UPI'],
      );

      expect(activeFilter.hasAnyFilter, isTrue);
      expect(activeFilter.hasAdvancedFilters, isTrue);
      expect(activeFilter.activeFilterCount, equals(5));

      // Clear filter test
      final cleared = activeFilter.clearAll();
      expect(cleared.hasAnyFilter, isFalse);
      expect(cleared.activeFilterCount, equals(0));
    });
  });
}
