import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mykhata/presentation/providers/settings_providers.dart'; //do not remove by OWNER

import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_haptics.dart';
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
import '../../widgets/budget_row.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_sheets.dart';
import '../../widgets/async_section.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/fade_slide_in.dart';
import '../../widgets/list_widgets.dart';
import '../../widgets/pressable.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/section_header.dart';
import '../../widgets/skeleton.dart';
import '../../widgets/transaction_row.dart';
import '../add_transaction/add_transaction_screen.dart';
import '../settings/recurring_payments_screen.dart';
import '../sms_review/sms_review_screen.dart';
import '../transactions/transaction_detail_screen.dart';

/// Tab indexes used by the "See all" links.
const int _transactionsTab = 1;
const int _budgetsTab = 2;
const int _insightsTab = 3;

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
                  message: 'It will no longer appear on Home.',
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

    // Reload in place (keeps what is on screen) rather than invalidating the
    // notifier-backed providers, which would blink every section.
    Future<void> refresh() async {
      ref.invalidate(recentTransactionsProvider);
      ref.invalidate(homeInsightsProvider);
      ref.invalidate(homeMonthSummaryProvider);
      await Future.wait([
        ref.read(accountListProvider.notifier).loadAccounts(),
        ref.read(budgetListProvider.notifier).loadBudgets(),
        ref.read(recurringListProvider.notifier).loadRecurringPayments(),
      ]);
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
              // 1. Header: who this is for, and the time of day.
              FadeSlideIn(
                child: Row(
                  children: [
                    _Avatar(name: userName),
                    const SizedBox(width: 12),
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
                  onRetry: () => ref.read(accountListProvider.notifier).loadAccounts(),
                  builder: (accounts) => _HeroCard(
                    accounts: accounts,
                    onEditAccount: (acc) => _editBalance(context, ref, acc),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 2a. Bank messages waiting: one clear call to action (this
              // used to be a header pill AND a badge on a quick action).
              if (smsCount > 0) ...[
                FadeSlideIn(
                  index: 1,
                  child: _SmsAttentionCard(count: smsCount),
                ),
                const SizedBox(height: 14),
              ],

              // 2b. This month at a glance (always this month, whatever range
              // Insights is showing).
              const FadeSlideIn(
                index: 1,
                child: _ThisMonthStrip(),
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
                      onRetry: () => ref.read(budgetListProvider.notifier).loadBudgets(),
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
                              BudgetRow(
                                budget: b,
                                onTap: () => ref
                                    .read(mainTabProvider.notifier)
                                    .state = _budgetsTab,
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
                      onRetry: () => ref
                          .read(recurringListProvider.notifier)
                          .loadRecurringPayments(),
                      builder: (list) {
                        if (list.isEmpty) {
                          return EmptyState(
                            compact: true,
                            emoji: '🔁',
                            title: 'No recurring payments',
                            message: 'Add rent or subscriptions to keep track of what is due.',
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

/// This month's income, spending and net, labelled with the month. Uses its
/// own provider, so it never shows another range by mistake; tapping opens
/// Insights on the same month.
class _ThisMonthStrip extends ConsumerWidget {
  const _ThisMonthStrip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final isMasked = ref.watch(privacyModeProvider);

    return ref.watch(homeMonthSummaryProvider).when(
      // Keep the figures on screen while they refresh.
      skipLoadingOnReload: true,
      loading: () => const Skeleton(height: 92, radius: 20),
      error: (_, __) => AppCard(
        onTap: () => ref.invalidate(homeMonthSummaryProvider),
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(Icons.refresh_rounded, color: p.muted, size: 20),
            const SizedBox(width: 10),
            Text(
              "Couldn't load this month. Tap to retry.",
              style: AppText.caption(p.muted),
            ),
          ],
        ),
      ),
      data: (data) {
        final net = data.totalIncome - data.totalExpense;
        final positive = net >= 0;
        return AppCard(
          onTap: () {
            ref.read(selectedDateRangeProvider.notifier).state =
                DateTimeRangeType.thisMonth;
            ref.read(mainTabProvider.notifier).state = _insightsTab;
          },
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('THIS MONTH', style: AppText.overline(p.muted)),
                  const Spacer(),
                  Text(
                    DateFormat('MMMM').format(DateTime.now()),
                    style: AppText.caption(p.muted),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 18, color: p.muted),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _MonthFigure(
                    icon: Icons.south_west_rounded,
                    label: 'Income',
                    value: CurrencyFormatter.format(
                      data.totalIncome,
                      isMasked: isMasked,
                    ),
                    color: p.income,
                  ),
                  _MonthFigure(
                    icon: Icons.north_east_rounded,
                    label: 'Spent',
                    value: CurrencyFormatter.format(
                      data.totalExpense,
                      isMasked: isMasked,
                    ),
                    color: p.expense,
                  ),
                  _MonthFigure(
                    icon: positive
                        ? Icons.trending_up_rounded
                        : Icons.trending_down_rounded,
                    label: positive ? 'Saved' : 'Over by',
                    value: CurrencyFormatter.format(
                      net.abs(),
                      isMasked: isMasked,
                    ),
                    color: positive ? p.income : p.expense,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MonthFigure extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _MonthFigure({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(label, style: AppText.caption(p.muted)),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.amount(color, size: 16),
          ),
        ],
      ),
    );
  }
}

/// Initial in a soft circle: puts a person on the screen without needing a photo.
class _Avatar extends StatelessWidget {
  final String name;

  const _Avatar({required this.name});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final initial = name.trim().isEmpty
        ? null
        : String.fromCharCodes([name.trim().runes.first]).toUpperCase();
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: p.primarySoft,
        shape: BoxShape.circle,
        border: Border.all(color: p.primary.withValues(alpha: 0.2)),
      ),
      alignment: Alignment.center,
      child: initial == null
          ? Icon(Icons.person_rounded, color: p.primary, size: 24)
          : Text(
              initial,
              style: AppText.title(p.primary),
            ),
    );
  }
}

/// Shown only while bank messages are waiting: the one place Home points at
/// the SMS review screen.
class _SmsAttentionCard extends StatelessWidget {
  final int count;

  const _SmsAttentionCard({required this.count});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppCard(
      onTap: () => AppRoutes.push(context, const SmsReviewScreen()),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: p.secondary.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: const Text('💬', style: TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count bank ${count == 1 ? 'message' : 'messages'} to review',
                  style: AppText.bodyStrong(p.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  'Confirm them to add to your records',
                  style: AppText.caption(p.muted),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: p.primarySoft,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Review',
              style: AppText.caption(p.primary).copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Gradient total-balance card with privacy mode toggle.
class _HeroCard extends ConsumerWidget {
  final List<AccountModel> accounts;
  final ValueChanged<AccountModel> onEditAccount;

  const _HeroCard({required this.accounts, required this.onEditAccount});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final isMasked = ref.watch(privacyModeProvider);
    final total = accounts.fold<double>(0.0, (sum, a) => sum + a.currentBalance);

    return AppCard(
      gradient: p.heroGradient,
      radius: 28,
      elevation: CardElevation.high,
      child: Stack(
        children: [
          // Depth: two translucent discs, a top-left sheen, and a hairline
          // edge so the card reads as a lit, glassy object.
          Positioned(
            right: -44,
            top: -44,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.08),
              ),
            ),
          ),
          Positioned(
            left: -30,
            bottom: -56,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withValues(alpha: 0.10),
              ),
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(28),
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.16),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                    begin: Alignment.topLeft,
                    end: const Alignment(0.2, 0.1),
                  ),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Total tracked balance',
                      style: AppText.caption(Colors.white.withValues(alpha: 0.9))
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                    Pressable(
                      onTap: () {
                        AppHaptics.tap();
                        ref.read(privacyModeProvider.notifier).set(!isMasked);
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
                        ),
                        child: Icon(
                          isMasked
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          size: 16,
                          color: Colors.white.withValues(alpha: 0.9),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: total),
                  duration: const Duration(milliseconds: 900),
                  curve: AppMotion.enter,
                  builder: (context, value, _) => FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      CurrencyFormatter.format(value, isMasked: isMasked),
                      style: AppText.display(Colors.white).copyWith(
                        fontSize: 36,
                        letterSpacing: -1.0,
                      ),
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
                                // Darker, not lighter, than the card: white
                                // text keeps AA contrast on it.
                                decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: Colors.white.withValues(alpha: 0.12),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (acc.isPrimary) ...[
                                          Icon(
                                            Icons.star_rounded,
                                            size: 13,
                                            color: p.secondary,
                                          ),
                                          const SizedBox(width: 3),
                                        ],
                                        Text(
                                          acc.name,
                                          style: AppText.caption(
                                            Colors.white.withValues(alpha: 0.9),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      CurrencyFormatter.format(acc.currentBalance, isMasked: isMasked),
                                      style: AppText.amount(Colors.white),
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
