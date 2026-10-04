import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/recurring_payment_model.dart';
import 'account_providers.dart';
import 'budget_providers.dart';
import 'recurring_providers.dart';
import 'transaction_providers.dart';

class HomeController extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;

  HomeController(this._ref) : super(const AsyncValue.data(null));

  Future<bool> updateAccountBalance(String accountId, double newBalance) async {
    state = const AsyncValue.loading();
    try {
      await _ref.read(accountListProvider.notifier).updateAccountBalanceDirect(accountId, newBalance);
      _ref.invalidate(accountListProvider);
      _ref.invalidate(recentTransactionsProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }

  Future<bool> processPaymentAction(RecurringPaymentModel item, String action) async {
    state = const AsyncValue.loading();
    try {
      final repo = _ref.read(recurringPaymentRepositoryProvider);
      await repo.processPaymentAction(item, action);
      _ref.invalidate(recurringListProvider);
      _ref.invalidate(accountListProvider);
      _ref.invalidate(recentTransactionsProvider);
      _ref.invalidate(budgetListProvider);
      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

final homeControllerProvider = StateNotifierProvider<HomeController, AsyncValue<void>>((ref) {
  return HomeController(ref);
});
