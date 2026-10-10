class SpendingForecastModel {
  final double actualSpentSoFar;
  final double projectedTotalSpend;
  final double dailyRunRate;
  final double monthlyBudgetLimit;
  final int daysElapsed;
  final int totalDaysInMonth;
  final double remainingRecurringDue;

  SpendingForecastModel({
    required this.actualSpentSoFar,
    required this.projectedTotalSpend,
    required this.dailyRunRate,
    required this.monthlyBudgetLimit,
    required this.daysElapsed,
    required this.totalDaysInMonth,
    required this.remainingRecurringDue,
  });

  bool get isOverBudget => monthlyBudgetLimit > 0 && projectedTotalSpend > monthlyBudgetLimit;
  double get varianceFromBudget => projectedTotalSpend - monthlyBudgetLimit;
}
