import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/transaction_model.dart';
import '../../providers/transaction_providers.dart';
import '../../widgets/filter_bottom_sheet.dart';
import '../../widgets/undo_snackbar.dart';
import '../settings/recently_deleted_screen.dart';
import 'transaction_detail_screen.dart';

class TransactionHistoryScreen extends ConsumerStatefulWidget {
  const TransactionHistoryScreen({super.key});

  @override
  ConsumerState<TransactionHistoryScreen> createState() => _TransactionHistoryScreenState();
}

class _TransactionHistoryScreenState extends ConsumerState<TransactionHistoryScreen> {
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();
  Timer? _debounce;
  String _selectedDateChip = 'All';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      ref.read(transactionListProvider.notifier).fetchMore();
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () {
      ref.read(transactionListProvider.notifier).setSearchQuery(query.isEmpty ? null : query);
    });
  }

  void _setDateFilter(String filter) {
    setState(() => _selectedDateChip = filter);
    final now = DateTime.now();
    DateTimeRange? range;

    if (filter == 'This Week') {
      final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
      range = DateTimeRange(
        start: DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day),
        end: now,
      );
    } else if (filter == 'This Month') {
      range = DateTimeRange(
        start: DateTime(now.year, now.month, 1),
        end: now,
      );
    } else if (filter == 'Last Month') {
      final prevMonth = DateTime(now.year, now.month - 1, 1);
      final lastDayOfPrevMonth = DateTime(now.year, now.month, 0);
      range = DateTimeRange(
        start: prevMonth,
        end: lastDayOfPrevMonth,
      );
    }

    ref.read(transactionListProvider.notifier).setFilters(dateRange: range);
  }

  String _formatDayHeader(DateTime dt) {
    final now = DateTime.now();
    if (dt.year == now.year && dt.month == now.month && dt.day == now.day) {
      return 'Today';
    }
    final yesterday = now.subtract(const Duration(days: 1));
    if (dt.year == yesterday.year && dt.month == yesterday.month && dt.day == yesterday.day) {
      return 'Yesterday';
    }
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${dt.day} ${months[dt.month - 1]}';
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transactionListProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasActiveFilters = state.type != null || state.paymentMethod != null || state.dateRange != null;

    // Group transactions by formatted date string
    final Map<String, List<TransactionModel>> groupedTransactions = {};
    for (final tx in state.transactions) {
      final key = _formatDayHeader(tx.date);
      groupedTransactions.putIfAbsent(key, () => []).add(tx);
    }

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top Bar: Title & Trash icon
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Transactions',
                    style: GoogleFonts.sora(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const RecentlyDeletedScreen()),
                      );
                    },
                    child: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          isDark ? AppColors.cardShadowDark : AppColors.cardShadowLight,
                        ],
                        border: Border.all(
                          color: isDark ? AppColors.borderDark : AppColors.borderLight,
                          width: 1.0,
                        ),
                      ),
                      child: const Center(
                        child: Text('🗑', style: TextStyle(fontSize: 18)),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Search Bar & Filter Button
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18.0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? AppColors.borderDark : AppColors.borderLight,
                          width: 1.0,
                        ),
                      ),
                      child: TextField(
                        controller: _searchController,
                        onChanged: _onSearchChanged,
                        style: GoogleFonts.sora(
                          fontSize: 14,
                          color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                        ),
                        decoration: InputDecoration(
                          hintText: 'Search anything',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                          prefixIcon: Icon(
                            Icons.search_rounded,
                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, size: 18),
                                  onPressed: () {
                                    _searchController.clear();
                                    ref.read(transactionListProvider.notifier).setSearchQuery(null);
                                  },
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Filter Button with dot indicator
                  GestureDetector(
                    onTap: () {
                      showModalBottomSheet(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.transparent,
                        builder: (_) => FilterBottomSheet(
                          initialType: state.type,
                          initialPaymentMethod: state.paymentMethod,
                          onApply: ({type, paymentMethod, dateFilter}) {
                            if (dateFilter != null) {
                              _setDateFilter(dateFilter);
                            }
                            ref.read(transactionListProvider.notifier).setFilters(
                              type: type,
                              paymentMethod: paymentMethod,
                            );
                          },
                          onReset: () {
                            setState(() => _selectedDateChip = 'All');
                            ref.read(transactionListProvider.notifier).clearFilters();
                          },
                        ),
                      );
                    },
                    child: Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark ? AppColors.borderDark : AppColors.borderLight,
                          width: 1.0,
                        ),
                        boxShadow: [
                          isDark ? AppColors.cardShadowDark : AppColors.cardShadowLight,
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            Icons.tune_rounded,
                            size: 20,
                            color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                          ),
                          if (hasActiveFilters)
                            Positioned(
                              right: 10,
                              top: 10,
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: AppColors.secondary,
                                  shape: BoxShape.circle,
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

            // Date Quick Filter Chips
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                children: ['All', 'This Week', 'This Month', 'Last Month'].map((chip) {
                  final isSelected = _selectedDateChip == chip;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => _setDateFilter(chip),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark ? AppColors.primaryDark : AppColors.primary)
                              : (isDark ? AppColors.surfaceDark : AppColors.surfaceLight),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected
                                ? Colors.transparent
                                : (isDark ? AppColors.borderDark : AppColors.borderLight),
                          ),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: (isDark ? AppColors.primaryDark : AppColors.primary).withValues(alpha: 0.3),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            chip,
                            style: GoogleFonts.sora(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? (isDark ? const Color(0xFF12102E) : Colors.white)
                                  : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            const SizedBox(height: 12),

            // Transactions List grouped by Day
            Expanded(
              child: state.isLoading && state.transactions.isEmpty
                  ? const Center(child: CircularProgressIndicator())
                  : state.transactions.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(40.0),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'No transactions match.',
                                  style: GoogleFonts.sora(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700,
                                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Change a filter or tap + on Home to add one.',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.sora(
                                    fontSize: 12,
                                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : ListView(
                          controller: _scrollController,
                          padding: EdgeInsets.fromLTRB(18, 0, 18, MediaQuery.of(context).padding.bottom + 130),
                          children: [
                            ...groupedTransactions.entries.map((entry) {
                              final dayHeader = entry.key;
                              final txs = entry.value;

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.only(top: 18, bottom: 6),
                                    child: Text(
                                      dayHeader,
                                      style: GoogleFonts.sora(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w700,
                                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                      ),
                                    ),
                                  ),
                                  Container(
                                    decoration: BoxDecoration(
                                      color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        isDark ? AppColors.cardShadowDark : AppColors.cardShadowLight,
                                      ],
                                      border: Border.all(
                                        color: isDark ? AppColors.borderDark : AppColors.borderLight,
                                        width: 1.0,
                                      ),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: Column(
                                      children: List.generate(txs.length, (index) {
                                        final tx = txs[index];
                                        final isLast = index == txs.length - 1;
                                        final isExpense = tx.isExpense;
                                        final isIncome = tx.isIncome;
                                        final amountColor = isIncome
                                            ? (isDark ? AppColors.incomeDark : AppColors.income)
                                            : isExpense
                                                ? (isDark ? AppColors.expenseDark : AppColors.expense)
                                                : (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight);
                                        final prefix = isIncome ? '+' : isExpense ? '−' : '';

                                        return Dismissible(
                                          key: Key(tx.id),
                                          direction: DismissDirection.endToStart,
                                          background: Container(
                                            color: AppColors.expense,
                                            alignment: Alignment.centerRight,
                                            padding: const EdgeInsets.only(right: 20),
                                            child: const Text('Delete 🗑', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                          ),
                                          onDismissed: (_) {
                                            ref.read(transactionListProvider.notifier).softDeleteTransaction(tx.id);
                                            UndoSnackbar.show(
                                              context,
                                              message: 'Transaction deleted',
                                              onUndo: () {
                                                ref.read(transactionListProvider.notifier).restoreTransaction(tx.id);
                                              },
                                            );
                                          },
                                          child: Column(
                                            children: [
                                              InkWell(
                                                onTap: () {
                                                  Navigator.push(
                                                    context,
                                                    MaterialPageRoute(builder: (_) => TransactionDetailScreen(transactionId: tx.id)),
                                                  );
                                                },
                                                child: Padding(
                                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                                                  child: Row(
                                                    children: [
                                                      Container(
                                                        width: 42,
                                                        height: 42,
                                                        decoration: BoxDecoration(
                                                          color: isDark ? AppColors.surface2Dark : AppColors.surface2Light,
                                                          borderRadius: BorderRadius.circular(14),
                                                        ),
                                                        child: Center(
                                                          child: Text(
                                                            AppColors.getCategoryEmoji(tx.categoryName),
                                                            style: const TextStyle(fontSize: 19),
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Text(
                                                              tx.description,
                                                              maxLines: 1,
                                                              overflow: TextOverflow.ellipsis,
                                                              style: GoogleFonts.sora(
                                                                fontSize: 14,
                                                                fontWeight: FontWeight.w600,
                                                                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                                              ),
                                                            ),
                                                            const SizedBox(height: 2),
                                                            Text(
                                                              '${tx.categoryName ?? 'General'} · ${tx.paymentMethod}',
                                                              style: GoogleFonts.sora(
                                                                fontSize: 12,
                                                                color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      Text(
                                                        '$prefix${CurrencyFormatter.format(tx.amount)}',
                                                        style: GoogleFonts.sora(
                                                          fontSize: 14,
                                                          fontWeight: FontWeight.w700,
                                                          color: amountColor,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                              if (!isLast)
                                                Divider(
                                                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                                                  height: 1,
                                                ),
                                            ],
                                          ),
                                        );
                                      }),
                                    ),
                                  ),
                                ],
                              );
                            }),
                            if (state.hasMore)
                              const Padding(
                                padding: EdgeInsets.all(16.0),
                                child: Center(child: CircularProgressIndicator()),
                              ),
                          ],
                        ),
            ),
          ],
        ),
      ),
    );
  }
}

