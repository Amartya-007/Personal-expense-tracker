import 'package:shared_preferences/shared_preferences.dart';

import '../../core/logging/app_logger.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/repositories/budget_repository.dart';
import 'notification_service.dart';

/// Sends a local notification when a budget crosses 75%, 90% or 100% of its
/// limit, once per threshold per period.
///
/// The app promised these alerts (onboarding, Budgets screen) but nothing
/// ever sent them: `NotificationService` was initialised and never called.
class BudgetAlertService {
  BudgetAlertService._();

  static const List<int> thresholds = [75, 90, 100];

  /// Call after an expense is saved or changed. Never throws.
  static Future<void> evaluate() async {
    try {
      final budgets = await BudgetRepository().getActiveBudgets();
      final prefs = await SharedPreferences.getInstance();

      for (final b in budgets) {
        if (b.amount <= 0) continue;

        final percent = b.usedRatio * 100;
        var crossed = 0;
        for (final t in thresholds) {
          if (percent >= t) crossed = t;
        }
        if (crossed == 0) continue;

        // One record per budget per period (the period start changes when it
        // rolls over, which re-arms the alerts).
        final key =
            'budget_alert_${b.id}_${b.startDate.millisecondsSinceEpoch}';
        final lastNotified = prefs.getInt(key) ?? 0;
        if (crossed <= lastNotified) continue;
        await prefs.setInt(key, crossed);

        final name = b.categoryName ?? 'Budget';
        final reachedLimit = crossed >= 100;
        await NotificationService.showNotification(
          id: (b.id.hashCode ^ crossed) & 0x7fffffff,
          title: reachedLimit
              ? '$name budget reached'
              : '$name budget at $crossed%',
          body: reachedLimit
              ? 'You have spent ${CurrencyFormatter.format(b.spentAmount)} of ${CurrencyFormatter.format(b.amount)}.'
              : '${CurrencyFormatter.format(b.remainingAmount)} left of ${CurrencyFormatter.format(b.amount)}.',
        );
      }
    } catch (e) {
      await AppLogger.w('Budget alert check skipped: $e');
    }
  }
}
