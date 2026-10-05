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

  // Guards against out-of-order responses (e.g. typing in search quickly) and
  // against firing fetchMore repeatedly while one is already running.
  int _requestId = 0;
  bool _fetchingMore = false;

  Future<void> fetchInitial() async {
    final requestId = ++_requestId;
    // Keep the current rows visible while reloading. Clearing them made the
    // list blink and jump back to the top on every refresh.
    state = state.copyWith(isLoading: true);
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

      if (requestId != _requestId || !mounted) return; // superseded
      state = state.copyWith(
        transactions: txs,
        isLoading: false,
        hasMore: txs.length >= 30,
      );
    } catch (e, st) {
      await AppLogger.e('fetchInitial failed', error: e, stackTrace: st);
      if (requestId == _requestId && mounted) {
        state = state.copyWith(isLoading: false);
      }
    }
  }

  Future<void> fetchMore() async {
    // Scrolling fires this many times per second; without the guard the same
    // page was appended repeatedly (duplicate rows).
    if (state.isLoading || _fetchingMore || !state.hasMore) return;
    _fetchingMore = true;
    final requestId = _requestId;

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
      // Filters changed while this page was loading: drop it.
      if (requestId != _requestId || !mounted) return;
      state = state.copyWith(
        transactions: [...state.transactions, ...newTxs],
        hasMore: newTxs.length >= 30,
      );
    } catch (e, st) {
      await AppLogger.e('fetchMore failed', error: e, stackTrace: st);
    } finally {
      _fetchingMore = false;
    }
  }

  void setSearchQuery(String? query) {
    // copyWith keeps the old value for null, so clearing must be explicit
    // (the search box used to stay filtered after its text was deleted).
    state = state.copyWith(searchQuery: query, clearSearch: query == null);
    fetchInitial();
  }

  /// Replaces the whole filter set; a null argument means "no filter".
  /// (Previously null meant "leave unchanged", so choosing "All" for a type,
  /// payment method or date range could never remove that filter.) The search
  /// text is not a filter here and is kept.
  void setFilters({
    String? type,
    String? categoryId,
    String? accountId,
    String? paymentMethod,
    DateTimeRange? dateRange,
  }) {
    state = TransactionState(
      transactions: state.transactions,
      isLoading: state.isLoading,
      hasMore: state.hasMore,
      searchQuery: state.searchQuery,
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
    // Remove the row synchronously. A swiped Dismissible must leave the tree
    // as soon as onDismissed fires (Flutter asserts otherwise), and the list
    // no longer blanks itself while reloading.
    state = state.copyWith(
      transactions: state.transactions.where((t) => t.id != id).toList(),
    );
    try {
      await _repository.softDeleteTransaction(id);
    } catch (_) {
      await fetchInitial(); // put the row back, then let the caller report it
      rethrow;
    }
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
