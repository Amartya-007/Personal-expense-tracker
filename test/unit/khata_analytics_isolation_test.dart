import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mykhata/core/database/database_helper.dart';
import 'package:mykhata/data/models/account_model.dart';
import 'package:mykhata/data/models/budget_model.dart';
import 'package:mykhata/data/models/category_model.dart';
import 'package:mykhata/data/models/khata_entry_model.dart';
import 'package:mykhata/data/models/transaction_model.dart';
import 'package:mykhata/data/repositories/budget_repository.dart';
import 'package:mykhata/data/repositories/category_repository.dart';
import 'package:mykhata/data/repositories/khata_repository.dart';
import 'package:mykhata/data/repositories/transaction_repository.dart';
import 'package:mykhata/services/analytics/analytics_service.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  Directory? tempDir;
  late AnalyticsService analyticsService;
  late BudgetRepository budgetRepo;
  late TransactionRepository transactionRepo;
  late CategoryRepository categoryRepo;
  late KhataRepository khataRepo;

  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;

    tempDir = await Directory.systemTemp.createTemp('mykhata_khata_analytics_');
    DatabaseHelper.setCustomDatabasePath(p.join(tempDir!.path, 'isolation_test.db'));

    analyticsService = AnalyticsService();
    budgetRepo = BudgetRepository();
    transactionRepo = TransactionRepository();
    categoryRepo = CategoryRepository();
    khataRepo = KhataRepository();
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

  group('Khata Analytics & Budget Isolation Invariants', () {
    test('Khata lending, borrowing, and settlements never distort income, expense, or savings rate', () async {
      final now = DateTime.now();
      final startDate = DateTime(now.year, now.month, 1);
      final endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

      final db = await DatabaseHelper.instance.database;

      // 1. Setup primary account & categories
      final acc = AccountModel(
        id: 'acc-main',
        name: 'Salary Account',
        currentBalance: 50000.0,
        initialBalance: 50000.0,
        createdAt: now,
        updatedAt: now,
      );
      await db.insert('accounts', acc.toMap());

      final catIncome = CategoryModel(
        id: 'cat-sal',
        name: 'Salary',
        icon: 'work',
        color: 0xFF4CAF50,
        type: 'income',
        createdAt: now,
      );
      await categoryRepo.createCategory(catIncome);

      final catExpense = CategoryModel(
        id: 'cat-food',
        name: 'Groceries',
        icon: 'restaurant',
        color: 0xFFFF9800,
        type: 'expense',
        createdAt: now,
      );
      await categoryRepo.createCategory(catExpense);

      // 2. Record authentic personal income (₹40,000) and expense (₹10,000)
      await transactionRepo.createTransaction(
        TransactionModel(
          id: 'tx-inc-1',
          type: 'income',
          amount: 40000.0,
          description: 'Monthly Salary',
          categoryId: catIncome.id,
          paymentMethod: 'Bank',
          accountId: acc.id,
          date: now,
          createdAt: now,
          updatedAt: now,
        ),
      );

      await transactionRepo.createTransaction(
        TransactionModel(
          id: 'tx-exp-1',
          type: 'expense',
          amount: 10000.0,
          description: 'Supermarket bill',
          categoryId: catExpense.id,
          paymentMethod: 'UPI',
          accountId: acc.id,
          date: now,
          createdAt: now,
          updatedAt: now,
        ),
      );

      // Baseline analytics:
      // Income = 40,000, Expense = 10,000, Net Savings = 30,000, Savings Rate = 75.0%
      var baseAnalytics = await analyticsService.getAnalytics(
        startDate: startDate,
        endDate: endDate,
      );
      expect(baseAnalytics.totalIncome, equals(40000.0));
      expect(baseAnalytics.totalExpense, equals(10000.0));
      expect(baseAnalytics.netSavings, equals(30000.0));
      expect(baseAnalytics.savingsRate, equals(75.0));

      final budget = BudgetModel(
        id: 'b-groceries',
        categoryId: catExpense.id,
        period: 'monthly',
        amount: 15000.0,
        startDate: startDate,
        endDate: endDate,
        createdAt: now,
      );
      await budgetRepo.createBudget(budget);

      var baseBudgets = await budgetRepo.getActiveBudgets();
      expect(baseBudgets.first.spentAmount, equals(10000.0));

      // 3. Perform large Khata operations:
      // - Lend ₹25,000 to John
      // - Borrow ₹15,000 from Mary
      // - Collect ₹10,000 repayment from John
      // - Settle ₹15,000 with Mary
      final personJohn = await khataRepo.createPerson(name: 'John Doe');
      final personMary = await khataRepo.createPerson(name: 'Mary Smith');

      await khataRepo.addEntry(
        personId: personJohn.id,
        type: KhataEntryType.lent,
        amount: 25000.0,
        date: now,
        accountId: acc.id,
        notes: 'Car downpayment loan',
      );

      await khataRepo.addEntry(
        personId: personMary.id,
        type: KhataEntryType.borrowed,
        amount: 15000.0,
        date: now,
        accountId: acc.id,
        notes: 'Emergency medical loan',
      );

      await khataRepo.addEntry(
        personId: personJohn.id,
        type: KhataEntryType.repaymentReceived,
        amount: 10000.0,
        date: now,
        accountId: acc.id,
      );

      await khataRepo.settlePerson(
        personMary.id,
        amount: 15000.0,
        accountId: acc.id,
      );

      // 4. Assert: Analytics MUST REMAIN EXACTLY UNCHANGED!
      var postAnalytics = await analyticsService.getAnalytics(
        startDate: startDate,
        endDate: endDate,
      );

      expect(
        postAnalytics.totalIncome,
        equals(40000.0),
        reason: 'Khata borrowing & repayments must not inflate conventional income',
      );
      expect(
        postAnalytics.totalExpense,
        equals(10000.0),
        reason: 'Khata lending & settlements must not inflate conventional expense',
      );
      expect(postAnalytics.netSavings, equals(30000.0));
      expect(postAnalytics.savingsRate, equals(75.0));

      // 5. Assert: Category budget spending MUST REMAIN EXACTLY UNCHANGED!
      var postBudgets = await budgetRepo.getActiveBudgets();
      expect(postBudgets.first.spentAmount, equals(10000.0));
    });
  });
}
