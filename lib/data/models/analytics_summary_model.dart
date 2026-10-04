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
}
