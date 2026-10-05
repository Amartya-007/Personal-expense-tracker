import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/budget_model.dart';
import '../../data/repositories/budget_repository.dart';

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
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> createBudget(BudgetModel budget) async {
    await _repository.createBudget(budget);
    await loadBudgets();
  }

  Future<void> updateBudget(BudgetModel budget) async {
    await _repository.updateBudget(budget);
    await loadBudgets();
  }

  Future<void> deleteBudget(String id) async {
    await _repository.deleteBudget(id);
    await loadBudgets();
  }
}

final budgetListProvider = StateNotifierProvider<BudgetListNotifier, AsyncValue<List<BudgetModel>>>((ref) {
  final repo = ref.watch(budgetRepositoryProvider);
  return BudgetListNotifier(repo);
});
