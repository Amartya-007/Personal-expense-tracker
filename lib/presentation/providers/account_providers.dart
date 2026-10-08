import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging/app_logger.dart';
import '../../data/models/account_model.dart';
import '../../data/repositories/account_repository.dart';

final accountRepositoryProvider = Provider((ref) => AccountRepository());

class AccountListNotifier
    extends StateNotifier<AsyncValue<List<AccountModel>>> {
  final AccountRepository _repository;

  AccountListNotifier(this._repository) : super(const AsyncValue.loading()) {
    loadAccounts();
  }

  Future<void> loadAccounts() async {
    // Keep showing existing data while reloading so lists don't blink.
    if (!state.hasValue) state = const AsyncValue.loading();
    try {
      final accounts = await _repository.getActiveAccounts();
      state = AsyncValue.data(accounts);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  // BUG FIX: all mutation methods now rethrow on error so callers can show
  // feedback, while still reloading the list on success.
  Future<void> createAccount(AccountModel account) async {
    try {
      await _repository.createAccount(account);
      await loadAccounts();
    } catch (e, st) {
      await AppLogger.e('createAccount failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> updateAccountBalanceDirect(
    String accountId,
    double newBalance, {
    String? reason,
  }) async {
    try {
      await _repository.updateAccountBalanceDirect(
        accountId,
        newBalance,
        reason: reason,
      );
      await loadAccounts();
    } catch (e, st) {
      await AppLogger.e(
        'updateAccountBalanceDirect failed',
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }

  /// Makes [accountId] the primary account (any previous primary is cleared).
  Future<void> setPrimaryAccount(String accountId) async {
    try {
      await _repository.setPrimaryAccount(accountId);
      await loadAccounts();
    } catch (e, st) {
      await AppLogger.e('setPrimaryAccount failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> clearPrimaryAccount() async {
    try {
      await _repository.clearPrimaryAccount();
      await loadAccounts();
    } catch (e, st) {
      await AppLogger.e('clearPrimaryAccount failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  Future<void> deleteAccount(String accountId) async {
    try {
      await _repository.deleteAccount(accountId);
      await loadAccounts();
    } catch (e, st) {
      await AppLogger.e('deleteAccount failed', error: e, stackTrace: st);
      rethrow;
    }
  }
}

final accountListProvider =
    StateNotifierProvider<AccountListNotifier, AsyncValue<List<AccountModel>>>((
      ref,
    ) {
      final repo = ref.watch(accountRepositoryProvider);
      return AccountListNotifier(repo);
    });
