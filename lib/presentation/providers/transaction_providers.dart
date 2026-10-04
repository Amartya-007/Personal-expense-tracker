import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging/app_logger.dart';
import '../../data/models/transaction_model.dart';
import '../../data/repositories/transaction_repository.dart';
import 'account_providers.dart';
import 'insights_providers.dart';

final transactionRepositoryProvider = Provider(
  (ref) => TransactionRepository(),
);

class TransactionState {
  final List<TransactionModel> transactions;
  final bool isLoading;
  final bool hasMore;
  final String? searchQuery;
  final String? type;
  final String? categoryId;
  final String? accountId;
  final String? paymentMethod;
  final DateTimeRange? dateRange;

  TransactionState({
    this.transactions = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.searchQuery,
    this.type,
    this.categoryId,
    this.accountId,
    this.paymentMethod,
    this.dateRange,
  });

  TransactionState copyWith({
    List<TransactionModel>? transactions,
    bool? isLoading,
    bool? hasMore,
    String? searchQuery,
    String? type,
    String? categoryId,
    String? accountId,
    String? paymentMethod,
    DateTimeRange? dateRange,
    bool clearSearch = false,
    bool clearFilters = false,
  }) {
    return TransactionState(
      transactions: transactions ?? this.transactions,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      searchQuery: clearSearch ? null : (searchQuery ?? this.searchQuery),
      type: clearFilters ? null : (type ?? this.type),
      categoryId: clearFilters ? null : (categoryId ?? this.categoryId),
      accountId: clearFilters ? null : (accountId ?? this.accountId),
      paymentMethod: clearFilters ? null : (paymentMethod ?? this.paymentMethod),
      dateRange: clearFilters ? null : (dateRange ?? this.dateRange),
    );
  }
}

class TransactionListNotifier extends StateNotifier<TransactionState> {
  final TransactionRepository _repository;
  final Ref _ref;

  TransactionListNotifier(this._repository, this._ref)
      : super(TransactionState()) {
    fetchInitial();
  }

  Future<void> fetchInitial() async {
    state = state.copyWith(isLoading: true, transactions: []);
    try {
      final txs = await _repository.getTransactionsPaged(
        limit: 30,
        offset: 0,
        type: state.type,
        accountId: state.accountId,
        categoryId: state.categoryId,
        paymentMethod: state.paymentMethod,
        searchQuery: state.searchQuery,
        startDate: state.dateRange?.start,
        endDate: state.dateRange?.end,
      );

      state = state.copyWith(
        transactions: txs,
        isLoading: false,
        hasMore: txs.length >= 30,
      );
    } catch (e, st) {
      await AppLogger.e('fetchInitial failed', error: e, stackTrace: st);
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> fetchMore() async {
    if (state.isLoading || !state.hasMore) return;

    try {
      final lastTx = state.transactions.isNotEmpty
          ? state.transactions.last
          : null;

      final newTxs = await _repository.getTransactionsPaged(
        limit: 30,
        cursorDate: lastTx?.date,
        cursorId: lastTx?.id,
        type: state.type,
        accountId: state.accountId,
        categoryId: state.categoryId,
        paymentMethod: state.paymentMethod,
        searchQuery: state.searchQuery,
        startDate: state.dateRange?.start,
        endDate: state.dateRange?.end,
      );
      state = state.copyWith(
        transactions: [...state.transactions, ...newTxs],
        hasMore: newTxs.length >= 30,
      );
    } catch (e, st) {
      await AppLogger.e('fetchMore failed', error: e, stackTrace: st);
    }
  }

  void setSearchQuery(String? query) {
    state = state.copyWith(searchQuery: query);
    fetchInitial();
  }

  void setFilters({
    String? type,
    String? categoryId,
    String? accountId,
    String? paymentMethod,
    DateTimeRange? dateRange,
  }) {
    state = state.copyWith(
      type: type,
      categoryId: categoryId,
      accountId: accountId,
      paymentMethod: paymentMethod,
      dateRange: dateRange,
    );
    fetchInitial();
  }

  void clearFilters() {
    state = state.copyWith(clearFilters: true, clearSearch: true);
    fetchInitial();
  }

  // BUG FIX: all mutation methods now rethrow so the UI can catch and show
  // proper error messages, while also refreshing account balances on success.
  Future<void> createTransaction(TransactionModel tx) async {
    await _repository.createTransaction(tx);
    await fetchInitial();
    _ref.read(accountListProvider.notifier).loadAccounts();
    _ref.invalidate(recentTransactionsProvider);
    _ref.invalidate(homeInsightsProvider);
    _ref.invalidate(analyticsSummaryProvider);
  }

  Future<void> updateTransaction(TransactionModel tx) async {
    await _repository.updateTransaction(tx);
    await fetchInitial();
    _ref.read(accountListProvider.notifier).loadAccounts();
    _ref.invalidate(recentTransactionsProvider);
    _ref.invalidate(homeInsightsProvider);
    _ref.invalidate(analyticsSummaryProvider);
  }

  Future<void> softDeleteTransaction(String id) async {
    await _repository.softDeleteTransaction(id);
    await fetchInitial();
    _ref.read(accountListProvider.notifier).loadAccounts();
    _ref.invalidate(recentTransactionsProvider);
    _ref.invalidate(homeInsightsProvider);
    _ref.invalidate(analyticsSummaryProvider);
  }

  Future<void> restoreTransaction(String id) async {
    await _repository.restoreTransaction(id);
    await fetchInitial();
    _ref.read(accountListProvider.notifier).loadAccounts();
    _ref.invalidate(recentTransactionsProvider);
    _ref.invalidate(homeInsightsProvider);
    _ref.invalidate(analyticsSummaryProvider);
  }

  /// Permanently removes an already soft-deleted transaction. Soft-deleted
  /// items are not in the visible list, so only the "recently deleted" view
  /// needs refreshing.
  Future<void> permanentlyDeleteTransaction(String id) async {
    await _repository.permanentlyDeleteTransaction(id);
    _ref.invalidate(recentlyDeletedTransactionsProvider);
  }
}

final transactionListProvider =
    StateNotifierProvider<TransactionListNotifier, TransactionState>((ref) {
      final repo = ref.watch(transactionRepositoryProvider);
      return TransactionListNotifier(repo, ref);
    });

final recentTransactionsProvider = FutureProvider<List<TransactionModel>>((
  ref,
) async {
  final repo = ref.watch(transactionRepositoryProvider);
  return await repo.getTransactionsPaged(limit: 5, offset: 0);
});

final recentlyDeletedTransactionsProvider =
    FutureProvider<List<TransactionModel>>((ref) async {
      final repo = ref.watch(transactionRepositoryProvider);
      return await repo.getSoftDeletedTransactions();
    });
