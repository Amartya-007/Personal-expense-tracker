import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/recurring_payment_model.dart';
import '../../data/repositories/recurring_payment_repository.dart';

final recurringPaymentRepositoryProvider = Provider((ref) => RecurringPaymentRepository());

class RecurringListNotifier extends StateNotifier<AsyncValue<List<RecurringPaymentModel>>> {
  final RecurringPaymentRepository _repository;

  RecurringListNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadRecurringPayments();
  }

  Future<void> loadRecurringPayments() async {
    state = const AsyncValue.loading();
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

  Future<void> processPaymentAction(RecurringPaymentModel item, String action) async {
    await _repository.processPaymentAction(item, action);
    await loadRecurringPayments();
  }

  Future<void> deleteRecurringPayment(String id) async {
    await _repository.deleteRecurringPayment(id);
    await loadRecurringPayments();
  }
}

final recurringListProvider = StateNotifierProvider<RecurringListNotifier, AsyncValue<List<RecurringPaymentModel>>>((ref) {
  final repo = ref.watch(recurringPaymentRepositoryProvider);
  return RecurringListNotifier(repo);
});
