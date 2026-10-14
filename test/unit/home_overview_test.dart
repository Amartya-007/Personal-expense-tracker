import 'package:flutter_test/flutter_test.dart';
import 'package:mykhata/data/models/account_model.dart';
import 'package:mykhata/data/models/analytics_summary_model.dart';
import 'package:mykhata/data/models/budget_model.dart';
import 'package:mykhata/data/models/recurring_payment_model.dart';
import 'package:mykhata/presentation/providers/home_overview_provider.dart';

AccountModel _account(String id, double balance) {
  final now = DateTime(2024, 1, 1);
  return AccountModel(
    id: id,
    name: 'Acc $id',
    currentBalance: balance,
    initialBalance: balance,
    createdAt: now,
    updatedAt: now,
  );
}

BudgetModel _budget({
  required String id,
  required double amount,
  required double spent,
}) {
  final now = DateTime(2024, 1, 1);
  return BudgetModel(
    id: id,
    categoryId: 'cat_$id',
    period: 'monthly',
    amount: amount,
    spentAmount: spent,
    startDate: now,
    endDate: now,
    createdAt: now,
  );
}

RecurringPaymentModel _rule({
  required String id,
  required DateTime nextDueDate,
  bool isActive = true,
}) {
  return RecurringPaymentModel(
    id: id,
    name: 'Rule $id',
    amount: 100.0,
    categoryId: 'cat',
    accountId: 'acc',
    paymentMethod: 'cash',
    frequency: 'monthly',
    nextDueDate: nextDueDate,
    isActive: isActive,
    createdAt: DateTime(2024, 1, 1),
  );
}

AnalyticsSummaryModel _summary({
  required double income,
  required double expense,
}) {
  return AnalyticsSummaryModel(
    totalIncome: income,
    totalExpense: expense,
    netSavings: income - expense,
    categoryBreakdown: const [],
    paymentMethodBreakdown: const [],
    accountBreakdown: const [],
  );
}

void main() {
  final now = DateTime(2024, 6, 10, 9, 0);
  final startOfToday = DateTime(2024, 6, 10);

  group('combineHomeOverview', () {
    test('folds account balances into totalBalance', () {
      final overview = combineHomeOverview(
        accounts: [_account('a', 1000.0), _account('b', 250.5)],
        monthSummary: _summary(income: 0, expense: 0),
        pendingSmsCount: 0,
        recurring: const [],
        budgets: const [],
        now: now,
      );
      expect(overview.totalBalance, 1250.5);
    });

    test('carries month income/expense and computes net', () {
      final overview = combineHomeOverview(
        accounts: const [],
        monthSummary: _summary(income: 5000, expense: 3200),
        pendingSmsCount: 0,
        recurring: const [],
        budgets: const [],
        now: now,
      );
      expect(overview.monthIncome, 5000);
      expect(overview.monthExpense, 3200);
      expect(overview.monthNet, 1800);
    });

    test('exceeded-budget predicate keeps over and at-limit budgets', () {
      final under = _budget(id: 'under', amount: 1000, spent: 500);
      final atLimit = _budget(id: 'at', amount: 1000, spent: 1000);
      final over = _budget(id: 'over', amount: 1000, spent: 1300);
      final overview = combineHomeOverview(
        accounts: const [],
        monthSummary: _summary(income: 0, expense: 0),
        pendingSmsCount: 0,
        recurring: const [],
        budgets: [under, atLimit, over],
        now: now,
      );
      expect(overview.exceededBudgets.map((b) => b.id).toList(), [
        'at',
        'over',
      ]);
    });

    test('billsDueCount counts active rules within the next 7 days', () {
      final overview = combineHomeOverview(
        accounts: const [],
        monthSummary: _summary(income: 0, expense: 0),
        pendingSmsCount: 0,
        recurring: [
          _rule(id: 'today', nextDueDate: startOfToday),
          _rule(
            id: '+7',
            nextDueDate: startOfToday.add(const Duration(days: 7)),
          ),
          _rule(
            id: '+8',
            nextDueDate: startOfToday.add(const Duration(days: 8)),
          ),
          _rule(
            id: 'inactive',
            nextDueDate: startOfToday.add(const Duration(days: 1)),
            isActive: false,
          ),
        ],
        budgets: const [],
        now: now,
      );
      expect(overview.billsDueCount, 2);
    });

    test('passes pendingSmsCount through unchanged', () {
      final overview = combineHomeOverview(
        accounts: const [],
        monthSummary: _summary(income: 0, expense: 0),
        pendingSmsCount: 4,
        recurring: const [],
        budgets: const [],
        now: now,
      );
      expect(overview.pendingSmsCount, 4);
    });
  });
}
