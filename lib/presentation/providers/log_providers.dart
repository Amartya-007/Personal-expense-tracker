import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_constants.dart';
import '../../core/logging/app_logger.dart';
import '../../core/logging/log_category.dart';
import '../../core/logging/log_entry.dart';
import '../../core/logging/log_filter.dart';
import '../../core/logging/log_level.dart';
import '../../data/repositories/log_repository.dart';
import '../../services/export/log_export_service.dart';

final logRepositoryProvider = Provider<LogRepository>((ref) => LogRepository());

final logExportServiceProvider = Provider<LogExportService>(
  (ref) => LogExportService(repository: ref.watch(logRepositoryProvider)),
);

class LogListState {
  final List<AppLogEntry> entries;
  final LogFilter filter;

  /// Matches for [filter] in the whole log (not just the loaded pages).
  final int totalCount;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final Object? error;

  const LogListState({
    this.entries = const [],
    this.filter = const LogFilter(),
    this.totalCount = 0,
    this.isLoading = true,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.error,
  });

  LogListState copyWith({
    List<AppLogEntry>? entries,
    LogFilter? filter,
    int? totalCount,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    Object? error,
    bool clearError = false,
  }) => LogListState(
    entries: entries ?? this.entries,
    filter: filter ?? this.filter,
    totalCount: totalCount ?? this.totalCount,
    isLoading: isLoading ?? this.isLoading,
    isLoadingMore: isLoadingMore ?? this.isLoadingMore,
    hasMore: hasMore ?? this.hasMore,
    error: clearError ? null : (error ?? this.error),
  );
}

/// Pages through the stored logs, newest first. Filtering and paging happen
/// in SQL; only the visible pages are held in memory.
class LogListNotifier extends StateNotifier<LogListState> {
  final LogRepository _repository;

  // Bumped by every (re)load so a slow, older response never overwrites a
  // newer one (typing in the search box starts many loads).
  int _generation = 0;

  LogListNotifier(this._repository) : super(const LogListState()) {
    load();
  }

  Future<void> load() async {
    final generation = ++_generation;
    final filter = state.filter;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      // Entries are written in the background; make sure the ones logged a
      // moment ago are in the table before reading it.
      await AppLogger.flush();
      final page = await _repository.getLogs(filter: filter);
      final total = await _repository.count(filter: filter);
      if (!mounted || generation != _generation) return;
      state = state.copyWith(
        entries: page,
        totalCount: total,
        isLoading: false,
        isLoadingMore: false,
        hasMore: page.length == AppConstants.logPageSize,
      );
    } catch (e) {
      if (!mounted || generation != _generation) return;
      state = state.copyWith(isLoading: false, isLoadingMore: false, error: e);
    }
  }

  Future<void> loadMore() async {
    if (state.isLoading || state.isLoadingMore || !state.hasMore) return;
    final generation = _generation;
    state = state.copyWith(isLoadingMore: true);
    try {
      final page = await _repository.getLogs(
        filter: state.filter,
        offset: state.entries.length,
      );
      if (!mounted || generation != _generation) return;
      state = state.copyWith(
        entries: [...state.entries, ...page],
        isLoadingMore: false,
        hasMore: page.length == AppConstants.logPageSize,
      );
    } catch (e) {
      if (!mounted || generation != _generation) return;
      state = state.copyWith(isLoadingMore: false, hasMore: false, error: e);
    }
  }

  Future<void> setQuery(String? query) {
    final next = state.filter.copyWith(
      query: query,
      clearQuery: query == null || query.trim().isEmpty,
    );
    return _applyFilter(next);
  }

  Future<void> setLevel(LogLevel? level) => _applyFilter(
    state.filter.copyWith(level: level, clearLevel: level == null),
  );

  Future<void> setCategory(LogCategory? category) => _applyFilter(
    state.filter.copyWith(category: category, clearCategory: category == null),
  );

  Future<void> clearFilters() => _applyFilter(const LogFilter());

  Future<void> _applyFilter(LogFilter next) {
    if (next == state.filter) return Future.value();
    state = state.copyWith(filter: next);
    return load();
  }

  /// Deletes every stored log, then reloads so the screen shows the empty
  /// state. Returns how many logs were removed.
  Future<int> clearAll() async {
    final removed = await _repository.clearAll();
    // Deliberately not logged: a "cleared" entry would put a row straight
    // back and the screen would not show the empty state.
    await load();
    return removed;
  }
}

final logListProvider =
    StateNotifierProvider.autoDispose<LogListNotifier, LogListState>((ref) {
      return LogListNotifier(ref.watch(logRepositoryProvider));
    });
