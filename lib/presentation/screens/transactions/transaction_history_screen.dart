import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_filters.dart';
import '../../../core/utils/text_sanitizer.dart';
import '../../../data/models/account_model.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/tag_model.dart';
import '../../../data/models/transaction_model.dart';
import '../../providers/account_providers.dart';
import '../../providers/category_providers.dart';
import '../../providers/settings_providers.dart';
import '../../providers/tag_providers.dart';
import '../../providers/transaction_providers.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/fade_slide_in.dart';
import '../../widgets/field_decoration.dart';
import '../../widgets/filter_bottom_sheet.dart';
import '../../widgets/icon_square_button.dart';
import '../../widgets/pill_chips.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/transaction_quick_edit_sheet.dart';
import '../../widgets/transaction_row.dart';
import '../../widgets/undo_snackbar.dart';
import '../add_transaction/add_transaction_screen.dart';
import 'transaction_detail_screen.dart';

class TransactionHistoryScreen extends ConsumerStatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  ConsumerState<TransactionHistoryScreen> createState() =>
      _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState
    extends ConsumerState<TransactionHistoryScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 200) {
      ref.read(transactionListProvider.notifier).fetchMore();
    }
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      final cleaned = TextSanitizer.singleLine(query);
      ref
          .read(transactionListProvider.notifier)
          .setSearchQuery(cleaned.isEmpty ? null : cleaned);
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    ref.read(transactionListProvider.notifier).setSearchQuery(null);
  }

  Future<void> _openFilterSheet() async {
    final currentFilter = ref.read(transactionListProvider).filter;
    final categories = await ref.read(categoriesListProvider.future);
    final accounts = ref.read(accountListProvider).value ?? const [];
    final tags = await ref.read(tagsListProvider.future);

    if (!mounted) return;
    final newFilter = await FilterSheet.show(
      context,
      categories: categories,
      accounts: accounts,
      tags: tags,
      initialFilter: currentFilter,
    );

    if (newFilter == null) return;
    ref.read(transactionListProvider.notifier).setFilter(newFilter);
  }

  void _clearAll() {
    _debounce?.cancel();
    _searchController.clear();
    ref.read(transactionListProvider.notifier).clearFilters();
  }

  void _delete(TransactionModel tx) {
    final notifier = ref.read(transactionListProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);

    notifier.softDeleteTransaction(tx.id).catchError((Object _) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not delete that transaction.')),
      );
    });

    UndoSnackbar.show(
      context,
      message: 'Transaction deleted',
      onUndo: () => notifier.restoreTransaction(tx.id),
    );
  }

  List<List<TransactionModel>> _groupByDay(List<TransactionModel> txs) {
    final groups = <String, List<TransactionModel>>{};
    for (final tx in txs) {
      final d = tx.date;
      groups.putIfAbsent('${d.year}-${d.month}-${d.day}', () => []).add(tx);
    }
    return groups.values.toList();
  }

  String _dayLabel(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Yesterday';
    return DateFormat(dt.year == now.year ? 'd MMM' : 'd MMM yyyy').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final state = ref.watch(transactionListProvider);
    final filter = state.filter;
    final activeCount = filter.activeFilterCount;
    final groups = _groupByDay(state.transactions);
    final bottom = MediaQuery.of(context).padding.bottom;
    final isMasked = ref.watch(privacyModeProvider);

    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Title (Recently deleted lives in Settings → Data).
            Padding(
              padding: const EdgeInsets.fromLTRB(
                18,
                AppSpacing.lg,
                18,
                AppSpacing.md,
              ),
              child: Row(
                children: [Text('Transactions', style: AppText.display(p.ink))],
              ),
            ),

            // Search bar + Filter button with active count badge
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  Expanded(
                    child: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _searchController,
                      builder: (context, value, _) => TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        textInputAction: TextInputAction.search,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(100),
                        ],
                        style: AppText.body(p.ink),
                        decoration:
                            appFieldDecoration(
                              p,
                              hint:
                                  'Search merchant, note, amount, category...',
                            ).copyWith(
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 15,
                              ),
                              prefixIcon: Icon(
                                Icons.search_rounded,
                                color: p.muted,
                              ),
                              suffixIcon: value.text.isNotEmpty
                                  ? IconButton(
                                      tooltip: 'Clear search',
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        size: 18,
                                      ),
                                      onPressed: _clearSearch,
                                    )
                                  : null,
                            ),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  IconSquareButton(
                    icon: Icons.tune_rounded,
                    iconSize: 20,
                    size: 52,
                    onTap: _openFilterSheet,
                    semanticLabel: 'Filters',
                    badge: activeCount > 0
                        ? Positioned(
                            right: 2,
                            top: 2,
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: p.secondary,
                                shape: BoxShape.circle,
                              ),
                              constraints: const BoxConstraints(
                                minWidth: 18,
                                minHeight: 18,
                              ),
                              alignment: Alignment.center,
                              child: Text(
                                '$activeCount',
                                style: AppText.caption(p.onPrimary).copyWith(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          )
                        : null,
                  ),
                ],
              ),
            ),

            // Quick-filter chips (independent toggles via the existing filter path)
            _QuickFilterChips(filter: filter),

            // Active Removable Filter Chips
            if (filter.hasAnyFilter)
              _ActiveFilterChips(
                filter: filter,
                searchController: _searchController,
                onClearAll: _clearAll,
              ),

            // Summary Banner
            if (!state.isLoading || state.transactions.isNotEmpty)
              _SummaryBanner(
                count: state.totalCount,
                totalExpense: state.totalExpense,
                totalIncome: state.totalIncome,
              ),

            // List
            Expanded(
              child: _buildBody(
                context,
                p,
                state,
                groups,
                filter.hasAnyFilter,
                bottom,
                isMasked,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppPalette p,
    TransactionState state,
    List<List<TransactionModel>> groups,
    bool filtered,
    double bottom,
    bool isMasked,
  ) {
    if (state.isLoading && state.transactions.isEmpty) {
      return ListView(
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        children: const [
          SkeletonCard(height: 150),
          SizedBox(height: 14),
          SkeletonCard(height: 150),
        ],
      );
    }

    if (state.transactions.isEmpty) {
      return EmptyState(
        emoji: filtered ? '🔍' : '🧾',
        title: filtered ? 'No transactions match' : 'No transactions yet',
        message: filtered
            ? 'Try adjusting your search or clearing the filters.'
            : 'Tap + to record your first one.',
        actionLabel: filtered ? 'Clear all filters' : 'Add expense',
        onAction: filtered
            ? _clearAll
            : () => AppRoutes.pushModal(
                context,
                const AddTransactionScreen(initialType: 'expense'),
              ),
      );
    }

    return RefreshIndicator(
      color: p.primary,
      onRefresh: () =>
          ref.read(transactionListProvider.notifier).fetchInitial(),
      child: ListView(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(18, 0, 18, bottom + 130),
        children: [
          for (var i = 0; i < groups.length; i++)
            FadeSlideIn(
              key: ValueKey(
                '${groups[i].first.date.year}-${groups[i].first.date.month}-${groups[i].first.date.day}',
              ),
              index: i % 5,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _DayHeader(
                    label: _dayLabel(groups[i].first.date),
                    spent: groups[i]
                        .where((t) => t.isExpense)
                        .fold<double>(0.0, (sum, t) => sum + t.amount),
                    isMasked: isMasked,
                  ),
                  TransactionListCard(
                    transactions: groups[i],
                    onTap: (tx) => AppRoutes.push(
                      context,
                      TransactionDetailScreen(transactionId: tx.id),
                    ),
                    onDelete: _delete,
                    onQuickEdit: (tx) =>
                        showTransactionQuickEditSheet(context, ref, tx),
                  ),
                ],
              ),
            ),
          if (state.hasMore)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}

/// A row of independent quick-filter toggles above the active-filter chips.
/// Each chip reflects the current [filter] and applies/clears exactly one
/// filter via the existing updateFilter path, staying in sync with
/// [_ActiveFilterChips].
class _QuickFilterChips extends ConsumerWidget {
  final TransactionFilter filter;

  const _QuickFilterChips({required this.filter});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(transactionListProvider.notifier);
    final categories = ref.watch(categoriesListProvider).value ?? const [];

    final thisMonthActive = filter.datePeriod == 'This Month';
    final expensesActive = filter.type == 'expense';
    final incomeActive = filter.type == 'income';

    final chips = <Widget>[
      PillChip(
        label: 'This month',
        selected: thisMonthActive,
        onTap: () => notifier.updateFilter(
          (f) => thisMonthActive
              ? f.copyWith(clearDatePeriod: true, clearCustomDateRange: true)
              : f.copyWith(datePeriod: 'This Month'),
        ),
      ),
      PillChip(
        label: 'Expenses',
        selected: expensesActive,
        onTap: () => notifier.updateFilter(
          (f) => expensesActive
              ? f.copyWith(clearType: true)
              : f.copyWith(type: 'expense'),
        ),
      ),
      PillChip(
        label: 'Income',
        selected: incomeActive,
        onTap: () => notifier.updateFilter(
          (f) => incomeActive
              ? f.copyWith(clearType: true)
              : f.copyWith(type: 'income'),
        ),
      ),
    ];

    // Optionally offer the top 1-2 categories as quick toggles.
    for (final cat in categories.take(2)) {
      final active = filter.categoryIds.contains(cat.id);
      chips.add(
        PillChip(
          label: cat.name,
          selected: active,
          onTap: () => notifier.updateFilter(
            (f) => active
                ? f.copyWith(categoryIds: const [])
                : f.copyWith(categoryIds: [cat.id]),
          ),
        ),
      );
    }

    // Each PillChip is at least kMinInteractiveDimension tall; the list adds
    // 8+4=12px of vertical padding. A hard kMinInteractiveDimension box can't
    // hold both and overflows the bottom (~8px, worse at larger text scale).
    // Size the box to the chip height plus the list padding, scaled with the
    // system text size.
    const listVerticalPadding = 8 + 4;
    final scale = MediaQuery.textScalerOf(context);
    final height = scale.scale(kMinInteractiveDimension) + listVerticalPadding;

    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(18, 8, 18, 4),
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) => Center(child: chips[i]),
      ),
    );
  }
}

class _ActiveFilterChips extends ConsumerWidget {
  final TransactionFilter filter;
  final TextEditingController searchController;
  final VoidCallback onClearAll;

  const _ActiveFilterChips({
    required this.filter,
    required this.searchController,
    required this.onClearAll,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final categories = ref.watch(categoriesListProvider).value ?? const [];
    final accounts = ref.watch(accountListProvider).value ?? const [];
    final tags = ref.watch(tagsListProvider).value ?? const [];

    final chips = <Widget>[];

    // Search chip
    if (filter.hasSearch) {
      chips.add(
        _RemovableChip(
          label: 'Search: "${filter.searchQuery}"',
          onRemove: () {
            searchController.clear();
            ref.read(transactionListProvider.notifier).setSearchQuery(null);
          },
        ),
      );
    }

    // Type chip
    if (filter.type != null && filter.type!.isNotEmpty) {
      final label = filter.type![0].toUpperCase() + filter.type!.substring(1);
      chips.add(
        _RemovableChip(
          label: 'Type: $label',
          onRemove: () {
            ref
                .read(transactionListProvider.notifier)
                .updateFilter((f) => f.copyWith(clearType: true));
          },
        ),
      );
    }

    // Date chip
    if (filter.datePeriod != null &&
        filter.datePeriod!.isNotEmpty &&
        filter.datePeriod != DateFilters.all) {
      String dateLabel = 'Date: ${filter.datePeriod}';
      if (filter.datePeriod == 'Custom' && filter.customDateRange != null) {
        final start = filter.customDateRange!.start;
        final end = filter.customDateRange!.end;
        dateLabel =
            'Date: ${start.day}/${start.month} - ${end.day}/${end.month}';
      }
      chips.add(
        _RemovableChip(
          label: dateLabel,
          onRemove: () {
            ref
                .read(transactionListProvider.notifier)
                .updateFilter(
                  (f) => f.copyWith(
                    clearDatePeriod: true,
                    clearCustomDateRange: true,
                  ),
                );
          },
        ),
      );
    }

    // Amount chip
    if (filter.minAmount != null || filter.maxAmount != null) {
      String amtLabel = 'Amount: ';
      if (filter.minAmount != null && filter.maxAmount != null) {
        amtLabel +=
            '₹${filter.minAmount!.toStringAsFixed(0)} - ₹${filter.maxAmount!.toStringAsFixed(0)}';
      } else if (filter.minAmount != null) {
        amtLabel += '> ₹${filter.minAmount!.toStringAsFixed(0)}';
      } else {
        amtLabel += '< ₹${filter.maxAmount!.toStringAsFixed(0)}';
      }
      chips.add(
        _RemovableChip(
          label: amtLabel,
          onRemove: () {
            ref
                .read(transactionListProvider.notifier)
                .updateFilter(
                  (f) => f.copyWith(clearMinAmount: true, clearMaxAmount: true),
                );
          },
        ),
      );
    }

    // Categories chip
    if (filter.categoryIds.isNotEmpty) {
      final firstId = filter.categoryIds.first;
      final catMatch = categories.cast<CategoryModel?>().firstWhere(
        (c) => c?.id == firstId,
        orElse: () => null,
      );
      String name = firstId == 'uncategorized'
          ? 'Uncategorized'
          : (catMatch?.name ?? 'Category');
      if (filter.categoryIds.length > 1) {
        name += ' (+${filter.categoryIds.length - 1})';
      }
      chips.add(
        _RemovableChip(
          label: 'Category: $name',
          onRemove: () {
            ref
                .read(transactionListProvider.notifier)
                .updateFilter((f) => f.copyWith(categoryIds: const []));
          },
        ),
      );
    }

    // Tags chip
    if (filter.tagIds.isNotEmpty) {
      final firstId = filter.tagIds.first;
      final tagMatch = tags.cast<TagModel?>().firstWhere(
        (t) => t?.id == firstId,
        orElse: () => null,
      );
      String name = '#${tagMatch?.name ?? 'tag'}';
      if (filter.tagIds.length > 1) {
        name += ' (+${filter.tagIds.length - 1})';
      }
      chips.add(
        _RemovableChip(
          label: 'Tag: $name',
          onRemove: () {
            ref
                .read(transactionListProvider.notifier)
                .updateFilter((f) => f.copyWith(tagIds: const []));
          },
        ),
      );
    }

    // Accounts chip
    if (filter.accountIds.isNotEmpty) {
      final firstId = filter.accountIds.first;
      final accMatch = accounts.cast<AccountModel?>().firstWhere(
        (a) => a?.id == firstId,
        orElse: () => null,
      );
      String name = firstId == 'primary'
          ? 'Primary Account'
          : (accMatch?.name ?? 'Account');
      if (filter.accountIds.length > 1) {
        name += ' (+${filter.accountIds.length - 1})';
      }
      chips.add(
        _RemovableChip(
          label: 'Account: $name',
          onRemove: () {
            ref
                .read(transactionListProvider.notifier)
                .updateFilter((f) => f.copyWith(accountIds: const []));
          },
        ),
      );
    }

    // Payment methods chip
    if (filter.paymentMethods.isNotEmpty) {
      String name = filter.paymentMethods.first;
      if (filter.paymentMethods.length > 1) {
        name += ' (+${filter.paymentMethods.length - 1})';
      }
      chips.add(
        _RemovableChip(
          label: 'Payment: $name',
          onRemove: () {
            ref
                .read(transactionListProvider.notifier)
                .updateFilter((f) => f.copyWith(paymentMethods: const []));
          },
        ),
      );
    }

    // Additional Filter chips
    if (filter.hasReceipt != null) {
      chips.add(
        _RemovableChip(
          label: filter.hasReceipt! ? 'With Receipt' : 'Without Receipt',
          onRemove: () {
            ref
                .read(transactionListProvider.notifier)
                .updateFilter((f) => f.copyWith(clearReceipt: true));
          },
        ),
      );
    }

    if (filter.isRecurring != null) {
      chips.add(
        _RemovableChip(
          label: filter.isRecurring! ? 'Recurring Only' : 'Non-Recurring',
          onRemove: () {
            ref
                .read(transactionListProvider.notifier)
                .updateFilter((f) => f.copyWith(clearRecurring: true));
          },
        ),
      );
    }

    if (filter.hasNote != null) {
      chips.add(
        _RemovableChip(
          label: 'With Note',
          onRemove: () {
            ref
                .read(transactionListProvider.notifier)
                .updateFilter((f) => f.copyWith(clearNote: true));
          },
        ),
      );
    }

    if (filter.hasLocation != null) {
      chips.add(
        _RemovableChip(
          label: 'With Location',
          onRemove: () {
            ref
                .read(transactionListProvider.notifier)
                .updateFilter((f) => f.copyWith(clearLocation: true));
          },
        ),
      );
    }

    // Sort option chip
    if (filter.sortBy != TransactionSortOption.dateDesc) {
      String sortName = 'Newest';
      switch (filter.sortBy) {
        case TransactionSortOption.dateAsc:
          sortName = 'Oldest First';
          break;
        case TransactionSortOption.amountDesc:
          sortName = 'Highest Amount';
          break;
        case TransactionSortOption.amountAsc:
          sortName = 'Lowest Amount';
          break;
        case TransactionSortOption.titleAsc:
          sortName = 'Title A-Z';
          break;
        case TransactionSortOption.titleDesc:
          sortName = 'Title Z-A';
          break;
        case TransactionSortOption.dateDesc:
          break;
      }
      chips.add(
        _RemovableChip(
          label: 'Sort: $sortName',
          onRemove: () {
            ref
                .read(transactionListProvider.notifier)
                .updateFilter(
                  (f) => f.copyWith(sortBy: TransactionSortOption.dateDesc),
                );
          },
        ),
      );
    }

    if (chips.isEmpty) return const SizedBox.shrink();

    // Scale the fixed row height with the system text size so chips don't clip
    // vertically at larger scales.
    final scale = MediaQuery.textScalerOf(context);
    final rowHeight = scale.scale(38);

    return Container(
      height: rowHeight,
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        itemCount: chips.length + 1,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == chips.length) {
            return Center(
              child: InkWell(
                onTap: onClearAll,
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Text(
                    'Clear All',
                    style: AppText.caption(p.primary)
                        .copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
              ),
            );
          }
          return chips[index];
        },
      ),
    );
  }
}

class _RemovableChip extends StatelessWidget {
  final String label;
  final VoidCallback onRemove;

  const _RemovableChip({required this.label, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 4, 4, 4),
      decoration: BoxDecoration(
        color: p.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Cap the label so a very long search term truncates instead of
          // producing a chip only reachable by long horizontal scrolling.
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 220),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption(p.primary)
                  .copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 2),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onRemove,
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(Icons.close_rounded, size: 15, color: p.primary),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryBanner extends StatelessWidget {
  final int count;
  final double totalExpense;
  final double totalIncome;

  const _SummaryBanner({
    required this.count,
    required this.totalExpense,
    required this.totalIncome,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      margin: const EdgeInsets.fromLTRB(18, 8, 18, 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Flexible(
            child: Text(
              '$count ${count == 1 ? 'Transaction' : 'Transactions'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption(p.ink)
                  .copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (totalExpense > 0) ...[
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Exp: ${CurrencyFormatter.format(totalExpense)}',
                        maxLines: 1,
                        style: AppText.caption(p.expense)
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  if (totalIncome > 0) const SizedBox(width: 8),
                ],
                if (totalIncome > 0)
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        'Inc: ${CurrencyFormatter.format(totalIncome)}',
                        maxLines: 1,
                        style: AppText.caption(p.income)
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DayHeader extends StatelessWidget {
  final String label;
  final double spent;
  final bool isMasked;

  const _DayHeader({
    required this.label,
    required this.spent,
    this.isMasked = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: AppText.bodyStrong(p.ink)),
          if (spent > 0)
            Text(
              'Spent ${CurrencyFormatter.format(spent, isMasked: isMasked)}',
              style: AppText.caption(p.muted),
            ),
        ],
      ),
    );
  }
}
