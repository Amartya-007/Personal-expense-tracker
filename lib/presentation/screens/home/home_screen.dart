import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mykhata/presentation/providers/settings_providers.dart'; //do not remove by OWNER

import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/recurring_payment_model.dart';
import '../../providers/account_providers.dart';
import '../../providers/budget_providers.dart';
import '../../providers/home_controller.dart';
import '../../providers/insights_providers.dart';
import '../../providers/recurring_providers.dart';
import '../../providers/sms_review_providers.dart';
import '../../providers/transaction_providers.dart';
import '../sms_review/sms_review_screen.dart';
import '../transactions/transaction_detail_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  void _showEditBalanceDialog(
    BuildContext context,
    WidgetRef ref,
    String accountId,
    String accountName,
    double currentBalance,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final controller = TextEditingController(
      text: currentBalance.toStringAsFixed(2),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: EdgeInsets.fromLTRB(
          20,
          14,
          20,
          MediaQuery.of(ctx).viewInsets.bottom + 28,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Edit $accountName balance',
              style: GoogleFonts.sora(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Updates account balance and records an auditable reconciliation entry.',
              style: GoogleFonts.sora(
                fontSize: 12,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              autofocus: true,
              style: GoogleFonts.sora(
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
              decoration: InputDecoration(
                prefixText: '₹ ',
                prefixStyle: GoogleFonts.sora(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                ),
                fillColor: isDark
                    ? AppColors.surface2Dark
                    : AppColors.surface2Light,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: () async {
                  final newBal =
                      double.tryParse(controller.text.trim()) ?? currentBalance;
                  final messenger = ScaffoldMessenger.of(context);
                  final nav = Navigator.of(ctx);

                  // FIX: Proper error handling (no silent failure / false success)
                  final success = await ref
                      .read(homeControllerProvider.notifier)
                      .updateAccountBalance(accountId, newBal);

                  if (success) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Adjustment recorded for $accountName'),
                      ),
                    );
                    nav.pop();
                  } else {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Could not update $accountName balance'),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Text(
                  'Save balance',
                  style: GoogleFonts.sora(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showRecurringActionSheet(
    BuildContext context,
    WidgetRef ref,
    RecurringPaymentModel item,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 36),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              item.name,
              style: GoogleFonts.sora(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: isDark
                    ? AppColors.textPrimaryDark
                    : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Due ${item.nextDueDate.day}/${item.nextDueDate.month}/${item.nextDueDate.year} · ${CurrencyFormatter.format(item.amount)}',
              style: GoogleFonts.sora(
                fontSize: 12.5,
                color: isDark
                    ? AppColors.textSecondaryDark
                    : AppColors.textSecondaryLight,
              ),
            ),
            const SizedBox(height: 20),

            // 1. Paid
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final messenger = ScaffoldMessenger.of(context);
                  final success = await ref
                      .read(homeControllerProvider.notifier)
                      .processPaymentAction(item, 'Paid');

                  if (success) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Recorded payment for ${item.name}'),
                      ),
                    );
                  } else {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Failed to record payment for ${item.name}'),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Mark as paid',
                  style: GoogleFonts.sora(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // 2. Later (Snooze)
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final messenger = ScaffoldMessenger.of(context);
                  final success = await ref
                      .read(homeControllerProvider.notifier)
                      .processPaymentAction(item, 'Later');

                  if (success) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Snoozed ${item.name} by 1 day'),
                      ),
                    );
                  } else {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Could not snooze reminder')),
                    );
                  }
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Remind me later',
                  style: GoogleFonts.sora(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: isDark
                        ? AppColors.textPrimaryDark
                        : AppColors.textPrimaryLight,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 4),

            // 3. Delete Rule
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () async {
                  Navigator.pop(ctx);
                  final messenger = ScaffoldMessenger.of(context);
                  final success = await ref
                      .read(homeControllerProvider.notifier)
                      .processPaymentAction(item, 'Delete');

                  if (success) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Removed recurring rule ${item.name}'),
                      ),
                    );
                  } else {
                    messenger.showSnackBar(
                      const SnackBar(content: Text('Could not remove rule')),
                    );
                  }
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Text(
                  'Delete recurring rule',
                  style: GoogleFonts.sora(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.expense,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountListProvider);
    final recentTxsAsync = ref.watch(recentTransactionsProvider);
    final budgetsAsync = ref.watch(budgetListProvider);
    final recurringAsync = ref.watch(recurringListProvider);
    final homeInsightsAsync = ref.watch(homeInsightsProvider);
    final smsQueueAsync = ref.watch(smsQueueProvider('detected'));
    final userName = ref.watch(userNameProvider);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? AppColors.backgroundDark
          : AppColors.backgroundLight,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(accountListProvider);
            ref.invalidate(recentTransactionsProvider);
            ref.invalidate(budgetListProvider);
            ref.invalidate(recurringListProvider);
            ref.invalidate(homeInsightsProvider);
          },
          child: ListView(
            padding: EdgeInsets.fromLTRB(
              18,
              16,
              18,
              MediaQuery.of(context).padding.bottom + 130,
            ),
            children: [
              // 1. Greeting
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getGreeting(),
                        style: GoogleFonts.sora(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isDark
                              ? AppColors.textSecondaryDark
                              : AppColors.textSecondaryLight,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        userName,
                        style: GoogleFonts.sora(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5,
                          color: isDark
                              ? AppColors.textPrimaryDark
                              : AppColors.textPrimaryLight,
                        ),
                      ),
                    ],
                  ),
                  smsQueueAsync.when(
                    data: (items) {
                      if (items.isEmpty) return const SizedBox.shrink();
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SmsReviewScreen(),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.expense.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: AppColors.expense.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('💬', style: TextStyle(fontSize: 14)),
                              const SizedBox(width: 6),
                              Text(
                                '${items.length} new',
                                style: GoogleFonts.sora(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.expense,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 2. Purple Gradient Hero Card
              accountsAsync.when(
                data: (accounts) {
                  final totalBalance = accounts.fold<double>(
                    0.0,
                    (sum, acc) => sum + acc.currentBalance,
                  );
                  return Container(
                    decoration: BoxDecoration(
                      gradient: isDark
                          ? AppColors.heroGradientDark
                          : AppColors.heroGradientLight,
                      borderRadius: BorderRadius.circular(26),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF5B3DF5).withValues(alpha: 0.3),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Stack(
                      children: [
                        Positioned(
                          right: -40,
                          top: -40,
                          child: Container(
                            width: 150,
                            height: 150,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white.withValues(alpha: 0.08),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(22.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total tracked balance',
                                style: GoogleFonts.sora(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white.withValues(alpha: 0.75),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                CurrencyFormatter.format(totalBalance),
                                style: GoogleFonts.sora(
                                  fontSize: 36,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: -1.0,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 14),
                              if (accounts.isNotEmpty)
                                SingleChildScrollView(
                                  scrollDirection: Axis.horizontal,
                                  child: Row(
                                    children: accounts.map((acc) {
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          right: 10,
                                        ),
                                        child: Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: () => _showEditBalanceDialog(
                                              context,
                                              ref,
                                              acc.id,
                                              acc.name,
                                              acc.currentBalance,
                                            ),
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            child: Container(
                                              constraints: const BoxConstraints(
                                                minWidth: 132,
                                              ),
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 13,
                                                    vertical: 11,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.white.withValues(
                                                  alpha: 0.14,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    acc.name,
                                                    style: GoogleFonts.sora(
                                                      fontSize: 12,
                                                      color: Colors.white
                                                          .withValues(
                                                            alpha: 0.8,
                                                          ),
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  Text(
                                                    CurrencyFormatter.format(
                                                      acc.currentBalance,
                                                    ),
                                                    style: GoogleFonts.sora(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w700,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Could not load accounts: $err', style: const TextStyle(color: AppColors.expense)),
                ),
              ),

              const SizedBox(height: 24),

              // 3. Budgets Card
              _buildSectionHeader('Budgets', isDark),
              const SizedBox(height: 8),
              budgetsAsync.when(
                data: (budgets) {
                  if (budgets.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.surfaceDark
                            : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark
                              ? AppColors.borderDark
                              : AppColors.borderLight,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'No budgets created yet.',
                          style: GoogleFonts.sora(
                            fontSize: 12.5,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ),
                    );
                  }
                  return Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.surfaceDark
                          : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        isDark
                            ? AppColors.cardShadowDark
                            : AppColors.cardShadowLight,
                      ],
                      border: Border.all(
                        color: isDark
                            ? AppColors.borderDark
                            : AppColors.borderLight,
                        width: 1.0,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: Column(
                      children: List.generate(budgets.length, (index) {
                        final b = budgets[index];
                        final isLast = index == budgets.length - 1;
                        final percent = (b.percentage * 100).round();
                        Color barColor = isDark
                            ? AppColors.primaryDark
                            : AppColors.primary;
                        if (b.percentage >= 1.0) {
                          barColor = AppColors.expense;
                        } else if (b.percentage >= 0.75) {
                          barColor = AppColors.secondary;
                        }

                        return Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        '${AppColors.getCategoryEmoji(b.categoryName)} ${b.categoryName ?? 'Budget'}',
                                        style: GoogleFonts.sora(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? AppColors.textPrimaryDark
                                              : AppColors.textPrimaryLight,
                                        ),
                                      ),
                                      Text(
                                        '${CurrencyFormatter.format(b.spentAmount)} / ${CurrencyFormatter.format(b.amount)}',
                                        style: GoogleFonts.sora(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: isDark
                                              ? AppColors.textPrimaryDark
                                              : AppColors.textPrimaryLight,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(5),
                                    child: LinearProgressIndicator(
                                      value: b.percentage.clamp(0.0, 1.0),
                                      backgroundColor: isDark
                                          ? AppColors.surface2Dark
                                          : AppColors.surface2Light,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        barColor,
                                      ),
                                      minHeight: 8,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    b.percentage >= 1.0
                                        ? 'Limit reached · $percent% used'
                                        : '${CurrencyFormatter.format(b.remainingAmount)} left · $percent% used',
                                    style: GoogleFonts.sora(
                                      fontSize: 12,
                                      color: isDark
                                          ? AppColors.textSecondaryDark
                                          : AppColors.textSecondaryLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (!isLast)
                              Divider(
                                color: isDark
                                    ? AppColors.borderDark
                                    : AppColors.borderLight,
                                height: 1,
                              ),
                          ],
                        );
                      }),
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Could not load budgets: $err', style: const TextStyle(color: AppColors.expense)),
                ),
              ),

              const SizedBox(height: 24),

              // 4. Recent Transactions Card
              _buildSectionHeader('Recent transactions', isDark),
              const SizedBox(height: 8),
              recentTxsAsync.when(
                data: (txs) {
                  if (txs.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.surfaceDark
                            : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark
                              ? AppColors.borderDark
                              : AppColors.borderLight,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'No transactions yet. Tap + to add your first expense.',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.sora(
                            fontSize: 12.5,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ),
                    );
                  }
                  return Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.surfaceDark
                          : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        isDark
                            ? AppColors.cardShadowDark
                            : AppColors.cardShadowLight,
                      ],
                      border: Border.all(
                        color: isDark
                            ? AppColors.borderDark
                            : AppColors.borderLight,
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
                            ? (isDark
                                ? AppColors.incomeDark
                                : AppColors.income)
                            : isExpense
                                ? (isDark
                                    ? AppColors.expenseDark
                                    : AppColors.expense)
                                : (isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight);
                        final prefix = isIncome
                            ? '+'
                            : isExpense
                                ? '−'
                                : '';

                        return Column(
                          children: [
                            InkWell(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => TransactionDetailScreen(
                                      transactionId: tx.id,
                                    ),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 13,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? AppColors.surface2Dark
                                            : AppColors.surface2Light,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Center(
                                        child: Text(
                                          AppColors.getCategoryEmoji(
                                            tx.categoryName,
                                          ),
                                          style: const TextStyle(fontSize: 19),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            tx.description,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.sora(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: isDark
                                                  ? AppColors.textPrimaryDark
                                                  : AppColors.textPrimaryLight,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            '${tx.categoryName ?? 'General'} · ${tx.paymentMethod}',
                                            style: GoogleFonts.sora(
                                              fontSize: 12,
                                              color: isDark
                                                  ? AppColors.textSecondaryDark
                                                  : AppColors.textSecondaryLight,
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
                                color: isDark
                                    ? AppColors.borderDark
                                    : AppColors.borderLight,
                                height: 1,
                              ),
                          ],
                        );
                      }),
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Could not load recent transactions: $err', style: const TextStyle(color: AppColors.expense)),
                ),
              ),

              const SizedBox(height: 24),

              // 5. Upcoming Recurring Payments Card
              _buildSectionHeader('Upcoming recurring', isDark),
              const SizedBox(height: 8),
              recurringAsync.when(
                data: (list) {
                  if (list.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isDark
                            ? AppColors.surfaceDark
                            : AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark
                              ? AppColors.borderDark
                              : AppColors.borderLight,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          'No upcoming recurring payments.',
                          style: GoogleFonts.sora(
                            fontSize: 12.5,
                            color: isDark
                                ? AppColors.textSecondaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ),
                    );
                  }
                  return Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.surfaceDark
                          : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        isDark
                            ? AppColors.cardShadowDark
                            : AppColors.cardShadowLight,
                      ],
                      border: Border.all(
                        color: isDark
                            ? AppColors.borderDark
                            : AppColors.borderLight,
                        width: 1.0,
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: Column(
                      children: List.generate(list.take(3).length, (index) {
                        final r = list[index];
                        final isLast = index == list.take(3).length - 1;

                        return Column(
                          children: [
                            InkWell(
                              onTap: () => _showRecurringActionSheet(
                                context,
                                ref,
                                r,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 42,
                                      height: 42,
                                      decoration: BoxDecoration(
                                        color: isDark
                                            ? AppColors.surface2Dark
                                            : AppColors.surface2Light,
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: const Center(
                                        child: Text(
                                          '🔁',
                                          style: TextStyle(fontSize: 18),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            r.name,
                                            style: GoogleFonts.sora(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: isDark
                                                  ? AppColors.textPrimaryDark
                                                  : AppColors.textPrimaryLight,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Due ${r.nextDueDate.day}/${r.nextDueDate.month}/${r.nextDueDate.year} · ${r.frequency}',
                                            style: GoogleFonts.sora(
                                              fontSize: 12,
                                              color: isDark
                                                  ? AppColors.textSecondaryDark
                                                  : AppColors.textSecondaryLight,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Text(
                                      CurrencyFormatter.format(r.amount),
                                      style: GoogleFonts.sora(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.expense,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (!isLast)
                              Divider(
                                color: isDark
                                    ? AppColors.borderDark
                                    : AppColors.borderLight,
                                height: 1,
                              ),
                          ],
                        );
                      }),
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Could not load recurring payments: $err', style: const TextStyle(color: AppColors.expense)),
                ),
              ),

              const SizedBox(height: 24),

              // 6. Home Insights Card
              _buildSectionHeader('Insights', isDark),
              const SizedBox(height: 8),
              homeInsightsAsync.when(
                data: (insights) {
                  return Container(
                    decoration: BoxDecoration(
                      color: isDark
                          ? AppColors.surfaceDark
                          : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        isDark
                            ? AppColors.cardShadowDark
                            : AppColors.cardShadowLight,
                      ],
                      border: Border.all(
                        color: isDark
                            ? AppColors.borderDark
                            : AppColors.borderLight,
                        width: 1.0,
                      ),
                    ),
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Text('💡', style: TextStyle(fontSize: 16)),
                            const SizedBox(width: 8),
                            Text(
                              'Smart observation',
                              style: GoogleFonts.sora(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: isDark
                                    ? AppColors.textPrimaryDark
                                    : AppColors.textPrimaryLight,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        ...insights.map(
                          (msg) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              msg,
                              style: GoogleFonts.sora(
                                fontSize: 13,
                                color: isDark
                                    ? AppColors.textSecondaryDark
                                    : AppColors.textSecondaryLight,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text('Could not load insights: $err', style: const TextStyle(color: AppColors.expense)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Text(
      title,
      style: GoogleFonts.sora(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
      ),
    );
  }
}
