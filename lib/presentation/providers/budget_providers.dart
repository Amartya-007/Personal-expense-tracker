import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/logging/app_logger.dart';
import '../../core/logging/log_category.dart';
import '../../data/models/budget_model.dart';
import '../../data/repositories/budget_repository.dart';
import '../../services/analytics/budget_history.dart';
import 'insights_providers.dart';

final budgetRepositoryProvider = Provider((ref) => BudgetRepository());

class BudgetListNotifier extends StateNotifier<AsyncValue<List<BudgetModel>>> {
  final BudgetRepository _repository;

  BudgetListNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadBudgets();
  }

  Future<void> loadBudgets() async {
    // Keep showing existing data while reloading so lists don't blink.
    if (!state.hasValue) state = const AsyncValue.loading();
    try {
      final list = await _repository.getActiveBudgets();
      state = AsyncValue.data(list);
    } catch (e, st) {
      // Covers the spent-amount calculation done while loading budgets.
      await AppLogger.error(
        'Budget calculation failed',
        category: LogCategory.budgets,
        error: e,
        stackTrace: st,
      );
      state = AsyncValue.error(e, st);
    }
  }

  /// Runs a budget write; logs and rethrows if it fails.
  Future<void> _logFailure(String action, Future<void> Function() run) async {
    try {
      await run();
    } catch (e, st) {
      await AppLogger.error(
        'Budget $action failed',
        category: LogCategory.budgets,
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  Future<void> createBudget(BudgetModel budget) async {
    await _logFailure('create', () => _repository.createBudget(budget));
    await loadBudgets();
  }

  Future<void> updateBudget(BudgetModel budget) async {
    await _logFailure('update', () => _repository.updateBudget(budget));
    await loadBudgets();
  }

  Future<void> deleteBudget(String id) async {
    await _logFailure('delete', () => _repository.deleteBudget(id));
    await loadBudgets();
  }
}

final budgetListProvider =
    StateNotifierProvider<BudgetListNotifier, AsyncValue<List<BudgetModel>>>((
      ref,
    ) {
      final repo = ref.watch(budgetRepositoryProvider);
      return BudgetListNotifier(repo);
    });

/// Key for [suggestedBudgetLimitProvider]: the category and the period
/// ('weekly'/'monthly'/'yearly') the user is creating a budget for.
typedef BudgetSuggestionKey = ({String categoryId, String period});

/// The selected category's ACTUAL spend in the PREVIOUS period of the same
/// type, used to seed the "Suggested limit" hint on the budget form.
///
/// Reuses existing infra only (no new SQL/schema): it shifts `now` back one
/// whole period, re-derives the calendar-aligned window via
/// [BudgetRepository.currentWindow], then reads that category's total from
/// [AnalyticsService.getAnalytics].categoryBreakdown (0.0 when the category had
/// no spend in that window).
final suggestedBudgetLimitProvider =
    FutureProvider.family<double, BudgetSuggestionKey>((ref, key) async {
      final now = DateTime.now();
      final shifted = shiftNowBack(key.period, 1, now);
      final window = BudgetRepository.currentWindow(
        key.period,
        now,
        now,
        now: shifted,
      );
      final analytics = await ref
          .watch(analyticsServiceProvider)
          .getAnalytics(startDate: window.start, endDate: window.end);
      for (final c in analytics.categoryBreakdown) {
        if (c.categoryId == key.categoryId) return c.totalAmount;
      }
      return 0.0;
    });

/// Key for [budgetHistoryProvider].
typedef BudgetHistoryKey = ({String categoryId, String period, double limit});

/// The last [_historyPeriods] completed periods' used-% for a budget,
/// recomputed from existing data (no new SQL/schema). Most-recent-first.
///
/// For each of the last N windows it shifts `now` back k periods (via
/// [shiftNowBack]), re-derives the calendar-aligned window with
/// [BudgetRepository.currentWindow], reads the category's spend from
/// [AnalyticsService.getAnalytics], and defers the percentage/label math to the
/// pure [budgetHistory] helper.
const int _historyPeriods = 3;

final budgetHistoryProvider =
    FutureProvider.family<List<BudgetPeriodUsage>, BudgetHistoryKey>((
      ref,
      key,
    ) async {
      final now = DateTime.now();
      final service = ref.watch(analyticsServiceProvider);
      final monthLabel = DateFormat('MMM');

      final spends = <double>[];
      final labels = <String>[];
      for (var k = 1; k <= _historyPeriods; k++) {
        final shifted = shiftNowBack(key.period, k, now);
        final window = BudgetRepository.currentWindow(
          key.period,
          now,
          now,
          now: shifted,
        );
        final analytics = await service.getAnalytics(
          startDate: window.start,
          endDate: window.end,
        );
        var spend = 0.0;
        for (final c in analytics.categoryBreakdown) {
          if (c.categoryId == key.categoryId) {
            spend = c.totalAmount;
            break;
          }
        }
        spends.add(spend);
        labels.add(_historyLabel(key.period, window.start, monthLabel));
      }

      return budgetHistory(spends: spends, labels: labels, limit: key.limit);
    });

/// Compact label for a past window: month name for monthly, a short date for
/// weekly, and the year for yearly.
String _historyLabel(String period, DateTime start, DateFormat monthLabel) {
  switch (period) {
    case 'weekly':
      return DateFormat('d MMM').format(start);
    case 'yearly':
      return '${start.year}';
    case 'monthly':
    default:
      return monthLabel.format(start);
  }
}
