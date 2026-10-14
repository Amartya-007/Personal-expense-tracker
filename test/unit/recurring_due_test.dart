import 'package:flutter_test/flutter_test.dart';
import 'package:mykhata/data/models/recurring_payment_model.dart';
import 'package:mykhata/presentation/providers/recurring_providers.dart';

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

void main() {
  // Fixed "now" with a non-midnight time so the start-of-today boundary is
  // genuinely exercised.
  final now = DateTime(2024, 6, 10, 14, 30);
  final startOfToday = DateTime(2024, 6, 10);

  group('dueWithinDays', () {
    test('empty list returns 0', () {
      expect(dueWithinDays(const [], now: now), 0);
    });

    test('a rule due today counts (even earlier in the day than now)', () {
      final items = [_rule(id: 'today', nextDueDate: startOfToday)];
      expect(dueWithinDays(items, now: now), 1);
    });

    test('a rule due in exactly 7 days counts', () {
      final items = [
        _rule(id: '+7', nextDueDate: startOfToday.add(const Duration(days: 7))),
      ];
      expect(dueWithinDays(items, now: now), 1);
    });

    test('a rule due in 8 days is excluded', () {
      final items = [
        _rule(id: '+8', nextDueDate: startOfToday.add(const Duration(days: 8))),
      ];
      expect(dueWithinDays(items, now: now), 0);
    });

    test('a rule due yesterday is excluded', () {
      final items = [
        _rule(
          id: '-1',
          nextDueDate: startOfToday.subtract(const Duration(days: 1)),
        ),
      ];
      expect(dueWithinDays(items, now: now), 0);
    });

    test('an inactive rule due this week is excluded', () {
      final items = [
        _rule(
          id: 'inactive',
          nextDueDate: startOfToday.add(const Duration(days: 2)),
          isActive: false,
        ),
      ];
      expect(dueWithinDays(items, now: now), 0);
    });

    test('counts only the matching rules in a mixed list', () {
      final items = [
        _rule(id: 'today', nextDueDate: startOfToday),
        _rule(id: '+7', nextDueDate: startOfToday.add(const Duration(days: 7))),
        _rule(id: '+8', nextDueDate: startOfToday.add(const Duration(days: 8))),
        _rule(
          id: '-1',
          nextDueDate: startOfToday.subtract(const Duration(days: 1)),
        ),
        _rule(
          id: 'inactive',
          nextDueDate: startOfToday.add(const Duration(days: 1)),
          isActive: false,
        ),
      ];
      expect(dueWithinDays(items, now: now), 2);
      expect(dueWithinDaysList(items, now: now).map((r) => r.id).toList(), [
        'today',
        '+7',
      ]);
    });
  });
}
