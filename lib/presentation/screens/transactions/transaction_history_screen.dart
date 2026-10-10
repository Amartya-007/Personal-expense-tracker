import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../core/utils/date_filters.dart';
import '../../../data/models/transaction_model.dart';
import '../../providers/account_providers.dart';
import '../../providers/category_providers.dart';
import '../../providers/transaction_providers.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/fade_slide_in.dart';
import '../../widgets/filter_bottom_sheet.dart';
import '../../widgets/pill_chips.dart';
import '../../widgets/pressable.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/transaction_row.dart';
import '../../widgets/undo_snackbar.dart';
import '../add_transaction/add_transaction_screen.dart';
import '../settings/recently_deleted_screen.dart';
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
  String _dateFilter = DateFilters.all;

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
      ref
          .read(transactionListProvider.notifier)
          .setSearchQuery(query.trim().isEmpty ? null : query.trim());
    });
  }

  void _clearSearch() {
    _debounce?.cancel();
    _searchController.clear();
    ref.read(transactionListProvider.notifier).setSearchQuery(null);
  }

  /// Applies a complete filter set (null = no filter). This is the single
  /// path used by both the chips and the filter sheet.
  void _applyFilters({
    String? type,
    String? paymentMethod,
    String? dateFilter,
    String? categoryId,
    String? accountId,
  }) {
    setState(() => _dateFilter = dateFilter ?? DateFilters.all);
    ref.read(transactionListProvider.notifier).setFilters(
          type: type,
          paymentMethod: paymentMethod,
          categoryId: categoryId,
          accountId: accountId,
          dateRange: DateFilters.rangeFor(dateFilter),
        );
  }

  void _selectDateChip(String chip) {
    final current = ref.read(transactionListProvider);
    _applyFilters(
      type: current.type,
      paymentMethod: current.paymentMethod,
      categoryId: current.categoryId,
      accountId: current.accountId,
      dateFilter: chip == DateFilters.all ? null : chip,
    );
  }

  Future<void> _openFilterSheet() async {
    final current = ref.read(transactionListProvider);
    final categories = await ref.read(categoriesListProvider.future);
    if (!mounted) return;
    final result = await FilterSheet.show(
      context,
      categories: categories,
      accounts: ref.read(accountListProvider).value ?? const [],
      type: current.type,
      paymentMethod: current.paymentMethod,
      categoryId: current.categoryId,
      accountId: current.accountId,
      dateFilter: _dateFilter == DateFilters.all ? null : _dateFilter,
    );
    if (result == null) return;
    _applyFilters(
      type: result.type,
      paymentMethod: result.paymentMethod,
      categoryId: result.categoryId,
      accountId: result.accountId,
      dateFilter: result.dateFilter,
    );
  }

  void _clearAll() {
    _debounce?.cancel();
    _searchController.clear();
    setState(() => _dateFilter = DateFilters.all);
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

  /// Groups by calendar day. The old key was just "1 Oct", so the same
  /// day/month from different years was merged under one header.
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
    final hasFilters = state.type != null ||
        state.paymentMethod != null ||
        state.categoryId != null ||
        state.accountId != null ||
        state.dateRange != null;
    final hasSearch = (state.searchQuery ?? '').isNotEmpty;
    final groups = _groupByDay(state.transactions);
    final bottom = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Title and shortcut to Recently deleted
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Transactions', style: AppText.display(p.ink)),
                  Pressable(
                    onTap: () =>
                        AppRoutes.push(context, const RecentlyDeletedScreen()),
                    child: Semantics(
                      button: true,
                      label: 'Recently deleted',
                      child: _SquareButton(
                        child: const Text('🗑', style: TextStyle(fontSize: 18)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Search + filter button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: p.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: p.border),
                      ),
                      child: ValueListenableBuilder<TextEditingValue>(
                        valueListenable: _searchController,
                        builder: (context, value, _) => TextField(
                          controller: _searchController,
                          onChanged: _onSearchChanged,
                          textInputAction: TextInputAction.search,
                          style: AppText.body(p.ink),
                          decoration: InputDecoration(
                            hintText: 'Search anything',
                            filled: false,
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
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
                                    icon: const Icon(Icons.close_rounded, size: 18),
                                    onPressed: _clearSearch,
                                  )
                                : null,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Pressable(
                    onTap: _openFilterSheet,
                    child: Semantics(
                      button: true,
                      label: 'Filters',
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          _SquareButton(
                            size: 52,
                            child: Icon(Icons.tune_rounded, size: 20, color: p.ink),
                          ),
                          Positioned(
                            right: 8,
                            top: 8,
                            child: AnimatedScale(
                              scale: hasFilters ? 1 : 0,
                              duration: const Duration(milliseconds: 200),
                              child: Container(
                                width: 9,
                                height: 9,
                                decoration: BoxDecoration(
                                  color: p.secondary,
                                  shape: BoxShape.circle,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Quick date chips
            PillChips(
              options: DateFilters.options.where((o) => o != 'Today').toList(),
              selected: _dateFilter == 'Today' ? '' : _dateFilter,
              onSelected: _selectDateChip,
              padding: const EdgeInsets.symmetric(horizontal: 18),
            ),
            const SizedBox(height: 12),

            // List
            Expanded(
              child: _buildBody(
                context,
                p,
                state,
                groups,
                hasFilters || hasSearch,
                bottom,
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
            ? 'Try a different search or clear the filters.'
            : 'Tap + to record your first one.',
        actionLabel: filtered ? 'Clear filters' : 'Add expense',
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
                  ),
                  TransactionListCard(
                    transactions: groups[i],
                    onTap: (tx) => AppRoutes.push(
                      context,
                      TransactionDetailScreen(transactionId: tx.id),
                    ),
                    onDelete: _delete,
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

class _DayHeader extends StatelessWidget {
  final String label;
  final double spent;

  const _DayHeader({required this.label, required this.spent});

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
              'Spent ${CurrencyFormatter.format(spent)}',
              style: AppText.caption(p.muted),
            ),
        ],
      ),
    );
  }
}

class _SquareButton extends StatelessWidget {
  final Widget child;
  final double size;

  const _SquareButton({required this.child, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(size > 44 ? 16 : 14),
        boxShadow: [p.cardShadow],
        border: Border.all(color: p.border),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }
}
