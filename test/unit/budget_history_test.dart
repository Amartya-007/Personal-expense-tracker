import 'package:flutter_test/flutter_test.dart';
import 'package:mykhata/services/analytics/budget_history.dart';

void main() {
  group('budgetHistory', () {
    test('computes used-% per period from spends and limit', () {
      final result = budgetHistory(
        spends: const [920, 780, 1100],
        labels: const ['Oct', 'Sep', 'Aug'],
        limit: 1000,
      );

      expect(result.map((h) => formatUsagePercent(h.percent)).toList(), [
        '92%',
        '78%',
        '110%',
      ]);
    });

    test('leaves over-limit percentages above 100 (unclamped)', () {
      final result = budgetHistory(
        spends: const [1500],
        labels: const ['Oct'],
        limit: 1000,
      );

      expect(result.single.percent, 150.0);
      expect(formatUsagePercent(result.single.percent), '150%');
    });

    test('carries labels through parallel to spends', () {
      final result = budgetHistory(
        spends: const [500, 250],
        labels: const ['Oct', 'Sep'],
        limit: 1000,
      );

      expect(result[0].label, 'Oct');
      expect(result[0].percent, 50.0);
      expect(result[1].label, 'Sep');
      expect(result[1].percent, 25.0);
    });

    test('reports 0% when the limit is zero (no divide-by-zero)', () {
      final result = budgetHistory(
        spends: const [920],
        labels: const ['Oct'],
        limit: 0,
      );

      expect(result.single.percent, 0.0);
      expect(formatUsagePercent(result.single.percent), '0%');
    });

    test('empty spends yields empty history', () {
      final result = budgetHistory(
        spends: const [],
        labels: const [],
        limit: 1000,
      );

      expect(result, isEmpty);
    });
  });

  group('shiftNowBack', () {
    test('weekly shifts back whole weeks', () {
      final now = DateTime(2024, 10, 15);
      expect(shiftNowBack('weekly', 1, now), DateTime(2024, 10, 8));
      expect(shiftNowBack('weekly', 3, now), DateTime(2024, 9, 24));
    });

    test('monthly shifts back whole months', () {
      final now = DateTime(2024, 3, 10);
      expect(shiftNowBack('monthly', 1, now), DateTime(2024, 2, 10));
      // Crosses a year boundary and normalizes the month.
      expect(shiftNowBack('monthly', 3, now), DateTime(2023, 12, 10));
    });

    test('yearly shifts back whole years', () {
      final now = DateTime(2024, 6, 20);
      expect(shiftNowBack('yearly', 1, now), DateTime(2023, 6, 20));
      expect(shiftNowBack('yearly', 2, now), DateTime(2022, 6, 20));
    });
  });
}
