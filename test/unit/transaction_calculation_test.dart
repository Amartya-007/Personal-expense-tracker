import 'package:flutter_test/flutter_test.dart';
import 'package:mykhata/core/utils/amount_input.dart';
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

    // Phase-C regression cases (added, existing assertions preserved).
    // These pin the REAL extreme outputs so a crore figure never silently
    // degrades to a bare ellipsised stub (A-2) and the amount rows/cap message
    // keep their exact strings (A-13/A-14, B-3b).

    test('formats a crore value with Indian grouping and decimals', () {
      // Exactly what a crore `_MonthFigure`/TransactionRow renders via format().
      expect(CurrencyFormatter.format(99999999.0), '₹9,99,99,999.00');
    });

    test('keeps the sign on a negative value', () {
      expect(CurrencyFormatter.format(-1299.50), '-₹1,299.50');
    });

    test('masks the value regardless of path', () {
      expect(CurrencyFormatter.format(50000.0, isMasked: true), '••••••');
      expect(
        CurrencyFormatter.formatCompact(50000.0, isMasked: true),
        '••••••',
      );
    });

    test('drops decimals when showDecimals is false', () {
      expect(
        CurrencyFormatter.format(99999999.0, showDecimals: false),
        '₹9,99,99,999',
      );
    });

    test('formatCompact pins the lakh and crore boundaries', () {
      expect(CurrencyFormatter.formatCompact(100000.0), '₹1.00 L');
      expect(CurrencyFormatter.formatCompact(10000000.0), '₹1.00 Cr');
      // The brief's crore figure: this exact value is what the compact Home
      // "This Month" figure renders (A-2 non-stub proof).
      expect(CurrencyFormatter.formatCompact(99999999.0), '₹10.00 Cr');
    });

    test('formats the amount cap for the validateAmount message', () {
      // Underpins the "Amount cannot exceed ₹9,99,99,99,99,999." message the
      // over-cap field test asserts; the trailing dot comes from the message,
      // not the formatter.
      expect(
        CurrencyFormatter.format(kMaxAmount, showDecimals: false),
        '₹9,99,99,99,99,999',
      );
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
