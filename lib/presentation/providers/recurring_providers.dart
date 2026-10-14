import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/recurring_payment_model.dart';
import '../../data/repositories/recurring_payment_repository.dart';

final recurringPaymentRepositoryProvider = Provider(
  (ref) => RecurringPaymentRepository(),
);

/// Active recurring rules whose [RecurringPaymentModel.nextDueDate] falls
/// within `[startOfToday, startOfToday + days]` (inclusive of today and of the
/// final day). Pure and widget-free so it can be unit-tested and reused by the
/// composed Home-overview snapshot. [now] defaults to `DateTime.now()`.
List<RecurringPaymentModel> dueWithinDaysList(
  List<RecurringPaymentModel> items, {
  int days = 7,
  DateTime? now,
}) {
  final n = now ?? DateTime.now();
  final startOfToday = DateTime(n.year, n.month, n.day);
  final end = startOfToday.add(Duration(days: days));
  return items
      .where(
        (r) =>
            r.isActive &&
            !r.nextDueDate.isBefore(startOfToday) &&
            !r.nextDueDate.isAfter(end),
      )
      .toList();
}

/// Count of active recurring rules due within the next [days] days (see
/// [dueWithinDaysList]).
int dueWithinDays(
  List<RecurringPaymentModel> items, {
  int days = 7,
  DateTime? now,
}) => dueWithinDaysList(items, days: days, now: now).length;

class RecurringListNotifier
    extends StateNotifier<AsyncValue<List<RecurringPaymentModel>>> {
  final RecurringPaymentRepository _repository;

  RecurringListNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadRecurringPayments();
  }

  Future<void> loadRecurringPayments() async {
    // Keep showing existing data while reloading so lists don't blink.
    if (!state.hasValue) state = const AsyncValue.loading();
    try {
      final list = await _repository.getAllRecurringPayments();
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createRecurringPayment(RecurringPaymentModel item) async {
    await _repository.createRecurringPayment(item);
    await loadRecurringPayments();
  }

  Future<void> processPaymentAction(
    RecurringPaymentModel item,
    String action,
  ) async {
    await _repository.processPaymentAction(item, action);
    await loadRecurringPayments();
  }

  Future<void> deleteRecurringPayment(String id) async {
    await _repository.deleteRecurringPayment(id);
    await loadRecurringPayments();
  }
}

final recurringListProvider =
    StateNotifierProvider<
      RecurringListNotifier,
      AsyncValue<List<RecurringPaymentModel>>
    >((ref) {
      final repo = ref.watch(recurringPaymentRepositoryProvider);
      return RecurringListNotifier(repo);
    });
