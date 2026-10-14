import '../../data/repositories/budget_repository.dart';

/// A single prior period's spend-vs-limit result for a budget.
///
/// [percent] is NOT clamped: a value above 100 means the category went over
/// the limit that period, which the history row is meant to surface.
class BudgetPeriodUsage {
  final String label;
  final double percent;

  const BudgetPeriodUsage({required this.label, required this.percent});
}

/// Shift [now] back [periodsBack] whole periods of [period]
/// ('weekly'/'monthly'/'yearly'), so [BudgetRepository.currentWindow] can be
/// re-used to produce the calendar-aligned window of a past period.
///
/// Pure date math (no DB), so it is unit-testable on its own.
DateTime shiftNowBack(String period, int periodsBack, DateTime now) {
  switch (period) {
    case 'weekly':
      return now.subtract(Duration(days: 7 * periodsBack));
    case 'monthly':
      return DateTime(now.year, now.month - periodsBack, now.day);
    case 'yearly':
      return DateTime(now.year - periodsBack, now.month, now.day);
    default:
      return now.subtract(Duration(days: 7 * periodsBack));
  }
}

/// Build the used-% history labels/values from already-fetched per-period
/// spends and the budget's current [limit].
///
/// [spends] is ordered most-recent-first (index 0 is the most recent completed
/// period). [labels] is parallel to [spends]. The percentage is `spend / limit
/// * 100` and is intentionally left unclamped so over-limit periods read above
/// 100%. When [limit] is zero (or negative) the percent is reported as 0 to
/// avoid a divide-by-zero.
///
/// Pure: inputs -> outputs, no DB, so it is unit-testable.
List<BudgetPeriodUsage> budgetHistory({
  required List<double> spends,
  required List<String> labels,
  required double limit,
}) {
  final usage = <BudgetPeriodUsage>[];
  for (var i = 0; i < spends.length; i++) {
    final percent = limit > 0 ? (spends[i] / limit) * 100 : 0.0;
    final label = i < labels.length ? labels[i] : '';
    usage.add(BudgetPeriodUsage(label: label, percent: percent));
  }
  return usage;
}

/// Format a usage percent as a whole-number string, e.g. 92.4 -> "92%".
/// Unclamped, so values above 100 are preserved.
String formatUsagePercent(double percent) => '${percent.round()}%';
