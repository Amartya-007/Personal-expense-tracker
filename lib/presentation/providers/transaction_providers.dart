import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging/app_logger.dart';
import '../../core/utils/date_filters.dart';
import '../../data/models/transaction_model.dart';
import '../../data/repositories/transaction_repository.dart';
import '../../services/notifications/budget_alert_service.dart';
import 'account_providers.dart';
import 'budget_providers.dart';
import 'insights_providers.dart';
import 'receipt_providers.dart';
import 'tag_providers.dart';

final transactionRepositoryProvider = Provider(
  (ref) => TransactionRepository(),
);

enum TransactionSortOption {
  dateDesc, // Newest first
  dateAsc, // Oldest first
  amountDesc, // Highest amount first
  amountAsc, // Lowest amount first
  titleAsc, // Description A to Z
  titleDesc, // Description Z to A
}

class TransactionFilter {
  final String? searchQuery;
  final String? type; // 'expense', 'income', 'transfer' or null
  final String? datePeriod; // 'Today', 'This Month', etc. or 'Custom' or null
  final DateTimeRange? customDateRange;
  final double? minAmount;
  final double? maxAmount;
  final List<String> categoryIds; // includes 'uncategorized'
  final List<String> tagIds;
  final List<String> accountIds; // includes 'primary'
  final List<String> paymentMethods;
  final bool? hasReceipt;
  final bool? isRecurring;
  final bool? hasNote;
  final bool? hasLocation;
  final TransactionSortOption sortBy;

  const TransactionFilter({
    this.searchQuery,
    this.type,
    this.datePeriod,
    this.customDateRange,
    this.minAmount,
    this.maxAmount,
    this.categoryIds = const [],
    this.tagIds = const [],
    this.accountIds = const [],
    this.paymentMethods = const [],
    this.hasReceipt,
    this.isRecurring,
    this.hasNote,
    this.hasLocation,
    this.sortBy = TransactionSortOption.dateDesc,
  });

  bool get hasSearch => searchQuery != null && searchQuery!.trim().isNotEmpty;

  bool get hasAdvancedFilters =>
      (type != null && type!.isNotEmpty) ||
      (datePeriod != null && datePeriod!.isNotEmpty && datePeriod != DateFilters.all) ||
      customDateRange != null ||
      minAmount != null ||
      maxAmount != null ||
      categoryIds.isNotEmpty ||
      tagIds.isNotEmpty ||
      accountIds.isNotEmpty ||
      paymentMethods.isNotEmpty ||
      hasReceipt != null ||
      isRecurring != null ||
      hasNote != null ||
      hasLocation != null ||
      sortBy != TransactionSortOption.dateDesc;

  bool get hasAnyFilter => hasSearch || hasAdvancedFilters;

  int get activeFilterCount {
    int count = 0;
    if (type != null && type!.isNotEmpty) count++;
    if (datePeriod != null && datePeriod!.isNotEmpty && datePeriod != DateFilters.all) count++;
    if (minAmount != null || maxAmount != null) count++;
    if (categoryIds.isNotEmpty) count++;
    if (tagIds.isNotEmpty) count++;
    if (accountIds.isNotEmpty) count++;
    if (paymentMethods.isNotEmpty) count++;
    if (hasReceipt != null) count++;
    if (isRecurring != null) count++;
    if (hasNote != null) count++;
    if (hasLocation != null) count++;
    if (sortBy != TransactionSortOption.dateDesc) count++;
    return count;
  }

  DateTimeRange? get effectiveDateRange {
    return DateFilters.rangeFor(datePeriod, customRange: customDateRange);
  }

  TransactionFilter copyWith({
    String? searchQuery,
    bool clearSearch = false,
    String? type,
    bool clearType = false,
    String? datePeriod,
    bool clearDatePeriod = false,
    DateTimeRange? customDateRange,
    bool clearCustomDateRange = false,
    double? minAmount,
    bool clearMinAmount = false,
    double? maxAmount,
    bool clearMaxAmount = false,
    List<String>? categoryIds,
    List<String>? tagIds,
    List<String>? accountIds,
    List<String>? paymentMethods,
    bool? hasReceipt,
    bool clearReceipt = false,
    bool? isRecurring,
    bool clearRecurring = false,
    bool? hasNote,
    bool clearNote = false,
    bool? hasLocation,
    bool clearLocation = false,
    TransactionSortOption? sortBy,
  }) {
    return TransactionFilter(
      searchQuery: clearSearch ? null : (searchQuery ?? this.searchQuery),
      type: clearType ? null : (type ?? this.type),
      datePeriod: clearDatePeriod ? null : (datePeriod ?? this.datePeriod),
      customDateRange: clearCustomDateRange ? null : (customDateRange ?? this.customDateRange),
      minAmount: clearMinAmount ? null : (minAmount ?? this.minAmount),
      maxAmount: clearMaxAmount ? null : (maxAmount ?? this.maxAmount),
      categoryIds: categoryIds ?? this.categoryIds,
      tagIds: tagIds ?? this.tagIds,
      accountIds: accountIds ?? this.accountIds,
      paymentMethods: paymentMethods ?? this.paymentMethods,
      hasReceipt: clearReceipt ? null : (hasReceipt ?? this.hasReceipt),
      isRecurring: clearRecurring ? null : (isRecurring ?? this.isRecurring),
      hasNote: clearNote ? null : (hasNote ?? this.hasNote),
      hasLocation: clearLocation ? null : (hasLocation ?? this.hasLocation),
      sortBy: sortBy ?? this.sortBy,
    );
  }

  TransactionFilter clearAll() => const TransactionFilter();
}

class TransactionState {
  final List<TransactionModel> transactions;
  final bool isLoading;
  final bool hasMore;
  final TransactionFilter filter;
  final int totalCount;
  final double totalExpense;
  final double totalIncome;

  TransactionState({
    this.transactions = const [],
    this.isLoading = false,
    this.hasMore = true,
    this.filter = const TransactionFilter(),
    this.totalCount = 0,
    this.totalExpense = 0.0,
    this.totalIncome = 0.0,
  });

  // Legacy getters for backward compatibility
  String? get searchQuery => filter.searchQuery;
  String? get type => filter.type;
  String? get categoryId => filter.categoryIds.isNotEmpty ? filter.categoryIds.first : null;
  String? get accountId => filter.accountIds.isNotEmpty ? filter.accountIds.first : null;
  String? get paymentMethod => filter.paymentMethods.isNotEmpty ? filter.paymentMethods.first : null;
  DateTimeRange? get dateRange => filter.effectiveDateRange;

  TransactionState copyWith({
    List<TransactionModel>? transactions,
    bool? isLoading,
    bool? hasMore,
    TransactionFilter? filter,
    int? totalCount,
    double? totalExpense,
    double? totalIncome,
  }) {
    return TransactionState(
      transactions: transactions ?? this.transactions,
      isLoading: isLoading ?? this.isLoading,
      hasMore: hasMore ?? this.hasMore,
      filter: filter ?? this.filter,
      totalCount: totalCount ?? this.totalCount,
      totalExpense: totalExpense ?? this.totalExpense,
      totalIncome: totalIncome ?? this.totalIncome,
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

  int _requestId = 0;
  bool _fetchingMore = false;

  Future<void> fetchInitial() async {
    final requestId = ++_requestId;
    state = state.copyWith(isLoading: true);
    try {
      final dateRange = state.filter.effectiveDateRange;

      final results = await Future.wait([
        _repository.getTransactionsPaged(
          limit: 30,
          offset: 0,
          type: state.filter.type,
          categoryIds: state.filter.categoryIds,
          tagIds: state.filter.tagIds,
          accountIds: state.filter.accountIds,
          paymentMethods: state.filter.paymentMethods,
          startDate: dateRange?.start,
          endDate: dateRange?.end,
          minAmount: state.filter.minAmount,
          maxAmount: state.filter.maxAmount,
          hasReceipt: state.filter.hasReceipt,
          isRecurring: state.filter.isRecurring,
          hasNote: state.filter.hasNote,
          hasLocation: state.filter.hasLocation,
          searchQuery: state.filter.searchQuery,
          sortBy: state.filter.sortBy.name,
        ),
        _repository.getFilteredSummary(
          type: state.filter.type,
          categoryIds: state.filter.categoryIds,
          tagIds: state.filter.tagIds,
          accountIds: state.filter.accountIds,
          paymentMethods: state.filter.paymentMethods,
          startDate: dateRange?.start,
          endDate: dateRange?.end,
          minAmount: state.filter.minAmount,
          maxAmount: state.filter.maxAmount,
          hasReceipt: state.filter.hasReceipt,
          isRecurring: state.filter.isRecurring,
          hasNote: state.filter.hasNote,
          hasLocation: state.filter.hasLocation,
          searchQuery: state.filter.searchQuery,
        ),
      ]);

      if (requestId != _requestId || !mounted) return;
      final txs = results[0] as List<TransactionModel>;
      final summary = results[1] as ({int count, double totalExpense, double totalIncome});

      state = state.copyWith(
        transactions: txs,
        totalCount: summary.count,
        totalExpense: summary.totalExpense,
        totalIncome: summary.totalIncome,
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
    if (state.isLoading || _fetchingMore || !state.hasMore) return;
    _fetchingMore = true;
    final requestId = _requestId;

    try {
      final dateRange = state.filter.effectiveDateRange;
      final newTxs = await _repository.getTransactionsPaged(
        limit: 30,
        offset: state.transactions.length,
        type: state.filter.type,
        categoryIds: state.filter.categoryIds,
        tagIds: state.filter.tagIds,
        accountIds: state.filter.accountIds,
        paymentMethods: state.filter.paymentMethods,
        startDate: dateRange?.start,
        endDate: dateRange?.end,
        minAmount: state.filter.minAmount,
        maxAmount: state.filter.maxAmount,
        hasReceipt: state.filter.hasReceipt,
        isRecurring: state.filter.isRecurring,
        hasNote: state.filter.hasNote,
        hasLocation: state.filter.hasLocation,
        searchQuery: state.filter.searchQuery,
        sortBy: state.filter.sortBy.name,
      );

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
    state = state.copyWith(
      filter: state.filter.copyWith(
        searchQuery: query,
        clearSearch: query == null || query.trim().isEmpty,
      ),
    );
    fetchInitial();
  }

  void setFilter(TransactionFilter filter) {
    state = state.copyWith(filter: filter);
    fetchInitial();
  }

  void updateFilter(TransactionFilter Function(TransactionFilter) updateFn) {
    state = state.copyWith(filter: updateFn(state.filter));
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
      filter: state.filter.copyWith(
        type: type,
        clearType: type == null,
        categoryIds: categoryId != null ? [categoryId] : const [],
        accountIds: accountId != null ? [accountId] : const [],
        paymentMethods: paymentMethod != null ? [paymentMethod] : const [],
        customDateRange: dateRange,
        clearCustomDateRange: dateRange == null,
      ),
    );
    fetchInitial();
  }

  void clearFilters() {
    state = state.copyWith(filter: const TransactionFilter());
    fetchInitial();
  }

  void _refreshDependents() {
    _ref.read(accountListProvider.notifier).loadAccounts();
    _ref.read(budgetListProvider.notifier).loadBudgets();
    _ref.invalidate(recentTransactionsProvider);
    _ref.invalidate(recentlyDeletedTransactionsProvider);
    _ref.invalidate(transactionDetailProvider);
    _ref.invalidate(homeInsightsProvider);
    _ref.invalidate(analyticsSummaryProvider);
    _ref.invalidate(spendingTrendProvider);
    _ref.invalidate(tagsListProvider);
    _ref.invalidate(receiptGalleryProvider);
  }

  Future<void> reloadAll() async {
    await fetchInitial();
    _refreshDependents();
  }

  Future<void> createTransaction(TransactionModel tx) async {
    await _repository.createTransaction(tx);
    if (tx.isExpense) unawaited(BudgetAlertService.evaluate());
    await fetchInitial();
    _refreshDependents();
  }

  Future<void> updateTransaction(TransactionModel tx) async {
    await _repository.updateTransaction(tx);
    if (tx.isExpense) unawaited(BudgetAlertService.evaluate());
    await fetchInitial();
    _refreshDependents();
  }

  Future<void> softDeleteTransaction(String id) async {
    state = state.copyWith(
      transactions: state.transactions.where((t) => t.id != id).toList(),
    );
    try {
      await _repository.softDeleteTransaction(id);
    } catch (_) {
      await fetchInitial();
      rethrow;
    }
    await fetchInitial();
    _refreshDependents();
  }

  Future<void> restoreTransaction(String id) async {
    await _repository.restoreTransaction(id);
    await fetchInitial();
    _refreshDependents();
  }

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

final transactionDetailProvider = FutureProvider.autoDispose
    .family<TransactionModel?, String>((ref, id) async {
      final repo = ref.watch(transactionRepositoryProvider);
      return await repo.getTransactionById(id);
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
