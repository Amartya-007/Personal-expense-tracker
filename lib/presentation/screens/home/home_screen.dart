import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mykhata/presentation/providers/settings_providers.dart'; //do not remove by OWNER

import '../../../core/constants/app_colors.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/account_model.dart';
import '../../../data/models/recurring_payment_model.dart';
import '../../providers/account_providers.dart';
import '../../providers/budget_providers.dart';
import '../../providers/home_controller.dart';
import '../../providers/insights_providers.dart';
import '../../providers/recurring_providers.dart';
import '../../providers/sms_review_providers.dart';
import '../../providers/transaction_providers.dart';
import '../../widgets/animated_progress_bar.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_sheets.dart';
import '../../widgets/async_section.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/fade_slide_in.dart';
import '../../widgets/list_widgets.dart';
import '../../widgets/pressable.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/section_header.dart';
import '../../widgets/transaction_row.dart';
import '../add_transaction/add_transaction_screen.dart';
import '../settings/recurring_payments_screen.dart';
import '../sms_review/sms_review_screen.dart';
import '../transactions/transaction_detail_screen.dart';

/// Tab indexes used by the "See all" links.
const int _transactionsTab = 1;
const int _budgetsTab = 2;

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  Future<void> _editBalance(
    BuildContext context,
    WidgetRef ref,
    AccountModel account,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final values = await showFieldsSheet(
      context,
      title: 'Edit ${account.name} balance',
      submitLabel: 'Save balance',
      fields: [
        FieldSpec(
          label: 'Balance (₹)',
          numeric: true,
          required: true,
          initial: account.currentBalance.toStringAsFixed(2),
        ),
      ],
    );
    if (values == null) return;

    final newBalance = double.tryParse(values[0].replaceAll(',', ''));
    if (newBalance == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Enter a valid amount.')),
      );
      return;
    }

    final success = await ref
        .read(homeControllerProvider.notifier)
        .updateAccountBalance(account.id, newBalance);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Adjustment recorded for ${account.name}'
              : 'Could not update ${account.name} balance',
        ),
      ),
    );
  }

  Future<void> _recurringAction(
    BuildContext context,
    WidgetRef ref,
    RecurringPaymentModel item,
    String action, {
    required String successMessage,
    required String failureMessage,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final success = await ref
        .read(homeControllerProvider.notifier)
        .processPaymentAction(item, action);
    messenger.showSnackBar(
      SnackBar(content: Text(success ? successMessage : failureMessage)),
    );
  }

  void _showRecurringActionSheet(
    BuildContext context,
    WidgetRef ref,
    RecurringPaymentModel item,
  ) {
    AppBottomSheet.show<void>(
      context,
      title: item.name,
      builder: (ctx) {
        final p = ctx.palette;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Due ${DateFormat('d MMM yyyy').format(item.nextDueDate)} · ${CurrencyFormatter.format(item.amount)}',
              style: AppText.caption(p.muted),
            ),
            const SizedBox(height: 18),
            PrimaryButton(
              label: 'Mark as paid',
              onPressed: () {
                Navigator.pop(ctx);
                _recurringAction(
                  context,
                  ref,
                  item,
                  'Paid',
                  successMessage: 'Recorded payment for ${item.name}',
                  failureMessage: 'Failed to record payment for ${item.name}',
                );
              },
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _recurringAction(
                  context,
                  ref,
                  item,
                  'Later',
                  successMessage: 'Snoozed ${item.name} by 1 day',
                  failureMessage: 'Could not snooze reminder',
                );
              },
              style: TextButton.styleFrom(foregroundColor: p.ink),
              child: const Text('Remind me later'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(ctx);
                // Deleting a rule used to happen on a single tap.
                final ok = await confirmDestructive(
                  context,
                  title: 'Delete ${item.name}?',
                  message: 'Future reminders for this payment will stop.',
                );
                if (!ok || !context.mounted) return;
                await _recurringAction(
                  context,
                  ref,
                  item,
                  'Delete',
                  successMessage: 'Removed ${item.name}',
                  failureMessage: 'Could not remove rule',
                );
              },
              style: TextButton.styleFrom(foregroundColor: p.expense),
              child: const Text('Delete recurring rule'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final accountsAsync = ref.watch(accountListProvider);
    final recentTxsAsync = ref.watch(recentTransactionsProvider);
    final budgetsAsync = ref.watch(budgetListProvider);
    final recurringAsync = ref.watch(recurringListProvider);
    final homeInsightsAsync = ref.watch(homeInsightsProvider);
    final smsCount = ref.watch(smsQueueProvider('detected')).value?.length ?? 0;
    final userName = ref.watch(userNameProvider);

    Future<void> refresh() async {
      ref.invalidate(accountListProvider);
      ref.invalidate(recentTransactionsProvider);
      ref.invalidate(budgetListProvider);
      ref.invalidate(recurringListProvider);
      ref.invalidate(homeInsightsProvider);
    }

    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: p.primary,
          onRefresh: refresh,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              18,
              16,
              18,
              MediaQuery.of(context).padding.bottom + 130,
            ),
            children: [
              // 1. Greeting
              FadeSlideIn(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _getGreeting(),
                            style: AppText.caption(p.muted).copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            // The name is empty until the user sets one.
                            userName.isEmpty ? 'Welcome back' : userName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.display(p.ink),
                          ),
                        ],
                      ),
                    ),
                    if (smsCount > 0)
                      Pressable(
                        onTap: () =>
                            AppRoutes.push(context, const SmsReviewScreen()),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: p.expense.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: p.expense.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('💬', style: TextStyle(fontSize: 14)),
                              const SizedBox(width: 6),
                              Text(
                                '$smsCount new',
                                style: AppText.caption(p.expense).copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // 2. Hero balance card
              FadeSlideIn(
                index: 1,
                child: AsyncSection<List<AccountModel>>(
                  value: accountsAsync,
                  skeletonHeight: 150,
                  errorLabel: 'Could not load accounts',
                  onRetry: () => ref.invalidate(accountListProvider),
                  builder: (accounts) => _HeroCard(
                    accounts: accounts,
                    onEditAccount: (acc) => _editBalance(context, ref, acc),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 3. Budgets
              FadeSlideIn(
                index: 2,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                      title: 'Budgets',
                      actionLabel: 'See all',
                      onAction: () =>
                          ref.read(mainTabProvider.notifier).state = _budgetsTab,
                    ),
                    AsyncSection(
                      value: budgetsAsync,
                      errorLabel: 'Could not load budgets',
                      onRetry: () => ref.invalidate(budgetListProvider),
                      builder: (budgets) {
                        if (budgets.isEmpty) {
                          return EmptyState(
                            compact: true,
                            emoji: '🎯',
                            title: 'No budgets yet',
                            message: 'Set a limit and get warned before you cross it.',
                            actionLabel: 'Create a budget',
                            onAction: () => ref
                                .read(mainTabProvider.notifier)
                                .state = _budgetsTab,
                          );
                        }
                        final shown = budgets.take(3).toList();
                        return SettingsGroup(
                          children: [
                            for (final b in shown)
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Flexible(
                                          child: Text(
                                            '${AppColors.getCategoryEmoji(b.categoryName)} ${b.categoryName ?? 'Budget'}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: AppText.body(p.ink),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${CurrencyFormatter.format(b.spentAmount)} / ${CurrencyFormatter.format(b.amount)}',
                                          style: AppText.body(p.ink),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    AnimatedProgressBar(
                                      value: b.percentage,
                                      color: budgetProgressColor(p, b.percentage),
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      b.percentage >= 1.0
                                          ? 'Limit reached · ${(b.percentage * 100).round()}% used'
                                          : '${CurrencyFormatter.format(b.remainingAmount)} left · ${(b.percentage * 100).round()}% used',
                                      style: AppText.caption(p.muted),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 4. Recent transactions
              FadeSlideIn(
                index: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                      title: 'Recent transactions',
                      actionLabel: 'See all',
                      onAction: () => ref
                          .read(mainTabProvider.notifier)
                          .state = _transactionsTab,
                    ),
                    AsyncSection(
                      value: recentTxsAsync,
                      skeletonHeight: 150,
                      errorLabel: 'Could not load recent transactions',
                      onRetry: () => ref.invalidate(recentTransactionsProvider),
                      builder: (txs) {
                        if (txs.isEmpty) {
                          return EmptyState(
                            compact: true,
                            emoji: '🧾',
                            title: 'No transactions yet',
                            message: 'Record your first expense to see it here.',
                            actionLabel: 'Add expense',
                            onAction: () => AppRoutes.pushModal(
                              context,
                              const AddTransactionScreen(initialType: 'expense'),
                            ),
                          );
                        }
                        return TransactionListCard(
                          transactions: txs,
                          onTap: (tx) => AppRoutes.push(
                            context,
                            TransactionDetailScreen(transactionId: tx.id),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // 5. Upcoming recurring
              FadeSlideIn(
                index: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                      title: 'Upcoming recurring',
                      actionLabel: 'Manage',
                      onAction: () => AppRoutes.push(
                        context,
                        const RecurringPaymentsScreen(),
                      ),
                    ),
                    AsyncSection(
                      value: recurringAsync,
                      errorLabel: 'Could not load recurring payments',
                      onRetry: () => ref.invalidate(recurringListProvider),
                      builder: (list) {
                        if (list.isEmpty) {
                          return EmptyState(
                            compact: true,
                            emoji: '🔁',
                            title: 'No recurring payments',
                            message: 'Add rent or subscriptions to get reminded.',
                            actionLabel: 'Add one',
                            onAction: () => AppRoutes.push(
                              context,
                              const RecurringPaymentsScreen(),
                            ),
                          );
                        }
                        final dateFormat = DateFormat('d MMM');
                        return SettingsGroup(
                          children: [
                            for (final r in list.take(3))
                              ListRowTile(
                                emoji: '🔁',
                                title: r.name,
                                subtitle:
                                    'Due ${dateFormat.format(r.nextDueDate)} · ${r.frequency}',
                                trailing: Text(
                                  CurrencyFormatter.format(r.amount),
                                  style: AppText.bodyStrong(p.expense),
                                ),
                                onTap: () =>
                                    _showRecurringActionSheet(context, ref, r),
                              ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),

              // 6. Insights (hidden when there is nothing to say)
              ...homeInsightsAsync.maybeWhen(
                data: (insights) => insights.isEmpty
                    ? const <Widget>[]
                    : <Widget>[
                        const SizedBox(height: 24),
                        FadeSlideIn(
                          index: 5,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SectionHeader(title: 'Insights'),
                              AppCard(
                                padding: const EdgeInsets.all(18),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        const Text(
                                          '💡',
                                          style: TextStyle(fontSize: 16),
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          'Smart observation',
                                          style: AppText.bodyStrong(p.ink),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),
                                    for (final msg in insights)
                                      Padding(
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 4,
                                        ),
                                        child: Text(
                                          msg,
                                          style: AppText.caption(p.muted)
                                              .copyWith(fontSize: 13),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                orElse: () => const <Widget>[],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Gradient total-balance card. The total counts up to its value and each
/// account chip opens the balance editor.
class _HeroCard extends StatelessWidget {
  final List<AccountModel> accounts;
  final ValueChanged<AccountModel> onEditAccount;

  const _HeroCard({required this.accounts, required this.onEditAccount});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final total = accounts.fold<double>(0.0, (sum, a) => sum + a.currentBalance);

    return AppCard(
      gradient: p.heroGradient,
      radius: 26,
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
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total tracked balance',
                  style: AppText.caption(Colors.white.withValues(alpha: 0.75))
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: total),
                  duration: const Duration(milliseconds: 900),
                  curve: AppMotion.enter,
                  builder: (context, value, _) => Text(
                    CurrencyFormatter.format(value),
                    style: AppText.display(Colors.white).copyWith(
                      fontSize: 36,
                      letterSpacing: -1.0,
                    ),
                  ),
                ),
                if (accounts.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final acc in accounts)
                          Padding(
                            padding: const EdgeInsets.only(right: 10),
                            child: Pressable(
                              onTap: () => onEditAccount(acc),
                              child: Container(
                                constraints: const BoxConstraints(minWidth: 132),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 13,
                                  vertical: 11,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      acc.name,
                                      style: AppText.caption(
                                        Colors.white.withValues(alpha: 0.8),
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      CurrencyFormatter.format(acc.currentBalance),
                                      style: AppText.bodyStrong(Colors.white),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
