import 'package:flutter_test/flutter_test.dart';

import 'package:mykhata/data/models/analytics_summary_model.dart';

AnalyticsSummaryModel _summary({
  double income = 0,
  double expense = 0,
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
  group('AnalyticsSummaryModel.savingsRate', () {
    test('normal month — 50 000 income, 30 000 expense → 40%', () {
      final s = _summary(income: 50000, expense: 30000);
      expect(s.savingsRate, closeTo(40.0, 0.001));
      expect(s.savingsHealthLabel, 'Strong savings');
      expect(s.savingsHealthEmoji, '🟢');
    });

    test('healthy range — 20% savings rate', () {
      final s = _summary(income: 10000, expense: 8000);
      expect(s.savingsRate, closeTo(20.0, 0.001));
      expect(s.savingsHealthLabel, 'Healthy savings');
      expect(s.savingsHealthEmoji, '🔵');
    });

    test('low savings — 5% rate', () {
      final s = _summary(income: 10000, expense: 9500);
      expect(s.savingsRate, closeTo(5.0, 0.001));
      expect(s.savingsHealthLabel, 'Spending most income');
      expect(s.savingsHealthEmoji, '🟡');
    });

    test('zero income → savingsRate is null, label says "No income recorded"', () {
      final s = _summary(income: 0, expense: 500);
      expect(s.savingsRate, isNull);
      expect(s.savingsHealthLabel, 'No income recorded');
      expect(s.savingsHealthEmoji, '📊');
    });

    test('zero income and zero expense → null', () {
      final s = _summary(income: 0, expense: 0);
      expect(s.savingsRate, isNull);
    });

    test('negative savings (overspent) → negative rate', () {
      final s = _summary(income: 10000, expense: 15000);
      expect(s.savingsRate, closeTo(-50.0, 0.001));
      expect(s.savingsHealthLabel, 'Spending exceeds income');
      expect(s.savingsHealthEmoji, '🔴');
    });

    test('exact breakeven — 0% savings rate', () {
      final s = _summary(income: 10000, expense: 10000);
      expect(s.savingsRate, closeTo(0.0, 0.001));
      expect(s.savingsHealthLabel, 'Spending most income');
      expect(s.savingsHealthEmoji, '🟡');
    });

    test('all income saved — 100%', () {
      final s = _summary(income: 20000, expense: 0);
      expect(s.savingsRate, closeTo(100.0, 0.001));
      expect(s.savingsHealthLabel, 'Strong savings');
    });

    test('boundary at 30% → Strong savings', () {
      final s = _summary(income: 10000, expense: 7000);
      expect(s.savingsRate, closeTo(30.0, 0.001));
      expect(s.savingsHealthLabel, 'Strong savings');
    });

    test('boundary at 10% → Healthy savings', () {
      final s = _summary(income: 10000, expense: 9000);
      expect(s.savingsRate, closeTo(10.0, 0.001));
      expect(s.savingsHealthLabel, 'Healthy savings');
    });

    test('netSavings is consistent with formula', () {
      final s = _summary(income: 42000, expense: 31500);
      expect(s.netSavings, closeTo(10500, 0.001));
      expect(s.savingsRate, closeTo(25.0, 0.001));
    });
  });

  group('Transfers excluded by design', () {
    // Transfers have type='transfer', so they are never aggregated into
    // totalIncome or totalExpense by the analytics SQL query. This test
    // documents the semantic contract: the model does not need to filter
    // them because the query already does.
    test('model uses only income/expense totals, not transfer amounts', () {
      // If someone were to incorrectly add transfer amounts into income,
      // the rate would be wrong. This test ensures the formula relies only
      // on the totals as supplied.
      final s = _summary(income: 10000, expense: 4000);
      expect(s.savingsRate, closeTo(60.0, 0.001));
      // The model has no concept of transfers — that is correct.
    });
  });
}
