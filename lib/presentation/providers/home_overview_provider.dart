import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/account_model.dart';
import '../../data/models/analytics_summary_model.dart';
import '../../data/models/budget_model.dart';
import '../../data/models/recurring_payment_model.dart';
import 'account_providers.dart';
import 'budget_providers.dart';
import 'insights_providers.dart';
import 'recurring_providers.dart';
import 'sms_review_providers.dart';

/// One consistent snapshot of everything Home's top region shows: the hero
/// total, the "this month" strip figures, and the three attention signals.
///
/// It is built by [homeOverviewProvider] from EXISTING providers (no new SQL),
/// so the hero total, month strip, and attention zone always derive from a
/// single read and can never momentarily disagree.
class HomeOverview {
  final double totalBalance;
  final double monthIncome;
  final double monthExpense;
  final double monthNet;
  final int pendingSmsCount;
  final int billsDueCount;
  final List<BudgetModel> exceededBudgets;

  const HomeOverview({
    required this.totalBalance,
    required this.monthIncome,
    required this.monthExpense,
    required this.monthNet,
    required this.pendingSmsCount,
    required this.billsDueCount,
    required this.exceededBudgets,
  });
}

/// Pure combine step: given the already-resolved inputs, build the snapshot.
/// Kept widget- and Riverpod-free so it is unit-testable without a DB.
///
/// - `totalBalance` folds account balances.
/// - month figures come straight from the this-month analytics summary.
/// - `exceededBudgets` keeps the same predicate Home used inline
///   (`overAmount > 0 || usedRatio >= 1.0`).
/// - `billsDueCount` counts active rules due within the next 7 days.
HomeOverview combineHomeOverview({
  required List<AccountModel> accounts,
  required AnalyticsSummaryModel monthSummary,
  required int pendingSmsCount,
  required List<RecurringPaymentModel> recurring,
  required List<BudgetModel> budgets,
  DateTime? now,
}) {
  final totalBalance = accounts.fold<double>(
    0.0,
    (sum, a) => sum + a.currentBalance,
  );
  final exceeded = budgets
      .where((b) => b.overAmount > 0 || b.usedRatio >= 1.0)
      .toList();
  return HomeOverview(
    totalBalance: totalBalance,
    monthIncome: monthSummary.totalIncome,
    monthExpense: monthSummary.totalExpense,
    monthNet: monthSummary.totalIncome - monthSummary.totalExpense,
    pendingSmsCount: pendingSmsCount,
    billsDueCount: dueWithinDays(recurring, now: now),
    exceededBudgets: exceeded,
  );
}

/// Composed Home snapshot. Watches the existing providers and folds them into
/// one [HomeOverview] via [combineHomeOverview]; while any source is still
/// loading its values fall back to empty/zero (the hero and attention zone
/// read this), while the month strip keeps its own [AsyncValue] through
/// [homeMonthSummaryProvider] to preserve skipLoadingOnReload no-flicker.
final homeOverviewProvider = Provider<HomeOverview>((ref) {
  final accounts =
      ref.watch(accountListProvider).value ?? const <AccountModel>[];
  final monthSummary = ref.watch(homeMonthSummaryProvider).value;
  final pendingSmsCount =
      ref.watch(smsQueueProvider('detected')).value?.length ?? 0;
  final recurring =
      ref.watch(recurringListProvider).value ?? const <RecurringPaymentModel>[];
  final budgets = ref.watch(budgetListProvider).value ?? const <BudgetModel>[];

  return combineHomeOverview(
    accounts: accounts,
    monthSummary:
        monthSummary ??
        AnalyticsSummaryModel(
          totalIncome: 0,
          totalExpense: 0,
          netSavings: 0,
          categoryBreakdown: const [],
          paymentMethodBreakdown: const [],
          accountBreakdown: const [],
        ),
    pendingSmsCount: pendingSmsCount,
    recurring: recurring,
    budgets: budgets,
    now: DateTime.now(),
  );
});
