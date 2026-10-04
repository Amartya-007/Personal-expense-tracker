import 'package:flutter_test/flutter_test.dart';
import 'package:mykhata/core/utils/currency_formatter.dart';
import 'package:mykhata/data/models/account_model.dart';
import 'package:mykhata/data/models/budget_model.dart';

void main() {
  group('CurrencyFormatter Tests', () {
    test('formats standard INR amounts correctly', () {
      expect(CurrencyFormatter.format(450.0), '₹450.00');
      expect(CurrencyFormatter.format(1299.50), '₹1,299.50');
      expect(CurrencyFormatter.format(50000.0), '₹50,000.00');
    });

    test('formats compact INR amounts correctly', () {
      expect(CurrencyFormatter.formatCompact(1500.0), '₹1.5 k');
      expect(CurrencyFormatter.formatCompact(250000.0), '₹2.50 L');
    });
  });

  group('AccountModel Tests', () {
    test('toMap and fromMap preserves data integrity', () {
      final now = DateTime.now();
      final acc = AccountModel(
        id: 'acc_123',
        name: 'SBI Bank',
        currentBalance: 42500.0,
        initialBalance: 50000.0,
        createdAt: now,
        updatedAt: now,
      );

      final map = acc.toMap();
      final restored = AccountModel.fromMap(map);

      expect(restored.id, 'acc_123');
      expect(restored.name, 'SBI Bank');
      expect(restored.currentBalance, 42500.0);
    });
  });

  group('BudgetModel Tests', () {
    test('calculates remaining amount and percentage correctly', () {
      final now = DateTime.now();
      final budget = BudgetModel(
        id: 'b_1',
        categoryId: 'cat_food',
        period: 'monthly',
        amount: 5000.0,
        spentAmount: 4200.0,
        startDate: now,
        endDate: now,
        createdAt: now,
      );

      expect(budget.remainingAmount, 800.0);
      expect(budget.percentage, closeTo(0.84, 0.01));
    });
  });
}
