class CategorySpending {
  final String categoryId;
  final String categoryName;
  final String categoryIcon;
  final int categoryColor;
  final double totalAmount;
  final double percentage;

  CategorySpending({
    required this.categoryId,
    required this.categoryName,
    required this.categoryIcon,
    required this.categoryColor,
    required this.totalAmount,
    required this.percentage,
  });
}

class PaymentMethodSpending {
  final String paymentMethod;
  final double totalAmount;

  PaymentMethodSpending({
    required this.paymentMethod,
    required this.totalAmount,
  });
}

class AccountSpending {
  final String accountId;
  final String accountName;
  final double totalAmount;

  AccountSpending({
    required this.accountId,
    required this.accountName,
    required this.totalAmount,
  });
}

class AnalyticsSummaryModel {
  final double totalIncome;
  final double totalExpense;
  final double netSavings;
  final List<CategorySpending> categoryBreakdown;
  final List<PaymentMethodSpending> paymentMethodBreakdown;
  final List<AccountSpending> accountBreakdown;

  AnalyticsSummaryModel({
    required this.totalIncome,
    required this.totalExpense,
    required this.netSavings,
    required this.categoryBreakdown,
    required this.paymentMethodBreakdown,
    required this.accountBreakdown,
  });

  /// Savings rate as a percentage of income.
  ///
  /// Formula: `(totalIncome - totalExpense) / totalIncome × 100`.
  ///
  /// Returns `null` when there is no income in the period—a percentage would
  /// be meaningless. Negative values indicate overspending.
  ///
  /// Transfers between the user's own accounts are already excluded because
  /// the analytics query only aggregates rows with `type = 'income'` and
  /// `type = 'expense'` (transfers have `type = 'transfer'`). Soft-deleted
  /// transactions are also excluded (`deleted_at IS NULL`).
  double? get savingsRate =>
      totalIncome > 0 ? (netSavings / totalIncome) * 100 : null;

  /// A short, non-judgmental label describing the savings situation.
  ///
  /// Used in the Insights card so the user always sees an understandable
  /// explanation rather than a bare number.
  String get savingsHealthLabel {
    final rate = savingsRate;
    if (rate == null) return 'No income recorded';
    if (rate >= 30) return 'Strong savings';
    if (rate >= 10) return 'Healthy savings';
    if (rate >= 0) return 'Spending most income';
    return 'Spending exceeds income';
  }

  /// Icon hint for the savings health state.
  String get savingsHealthEmoji {
    final rate = savingsRate;
    if (rate == null) return '📊';
    if (rate >= 30) return '🟢';
    if (rate >= 10) return '🔵';
    if (rate >= 0) return '🟡';
    return '🔴';
  }
}
