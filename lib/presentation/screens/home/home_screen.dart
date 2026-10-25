import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mykhata/presentation/providers/settings_providers.dart'; //do not remove by OWNER

import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_haptics.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_radius.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/account_model.dart';
import '../../../data/models/budget_model.dart';
import '../../../data/models/recurring_payment_model.dart';
import '../../providers/account_providers.dart';
import '../../providers/budget_providers.dart';
import '../../providers/home_controller.dart';
import '../../providers/home_overview_provider.dart';
import '../../providers/insights_providers.dart';
import '../../providers/recurring_providers.dart';
import '../../providers/transaction_providers.dart';
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
import '../settings/account_balance_actions.dart';
import '../settings/recurring_payments_screen.dart';
import '../sms_review/sms_review_screen.dart';
import '../transactions/transaction_detail_screen.dart';

/// Tab indexes used by the "See all" links.
const int _transactionsTab = 1;
const int _budgetsTab = 2;
const int _insightsTab = 3;

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;

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
              AppSpacing.lg,
              18,
              MediaQuery.of(context).padding.bottom + 130,
            ),
            children: const [
              _HeaderSection(),
              SizedBox(height: AppSpacing.lg),
              _HeroCardSection(),
              SizedBox(height: 14),
              _AttentionZone(),
              _ThisMonthStrip(),
              SizedBox(height: AppSpacing.xl),
              _RecentTransactionsSection(),
              SizedBox(height: AppSpacing.xl),
              _UpcomingRecurringSection(),
              _InsightsSection(),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderSection extends ConsumerWidget {
  const _HeaderSection();

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final userName = ref.watch(userNameProvider);

    return FadeSlideIn(
      child: Row(
        children: [
          _Avatar(name: userName),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getGreeting(),
                  style: AppText.caption(p.muted)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
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
    );
  }
}

class _HeroCardSection extends ConsumerWidget {
  const _HeroCardSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountListProvider);
    final overview = ref.watch(homeOverviewProvider);

    return FadeSlideIn(
      index: 1,
      child: AsyncSection<List<AccountModel>>(
        value: accountsAsync,
        skeletonHeight: 150,
        errorLabel: 'Could not load accounts',
        onRetry: () => ref.read(accountListProvider.notifier).loadAccounts(),
        builder: (accounts) => _HeroCard(
          accounts: accounts,
          total: overview.totalBalance,
          onEditAccount: (acc) => editAccountBalance(context, ref, acc),
        ),
      ),
    );
  }
}

class _AttentionZone extends ConsumerWidget {
  const _AttentionZone();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(homeOverviewProvider);
    final smsCount = overview.pendingSmsCount;
    final billsDue = overview.billsDueCount;
    final exceededBudgets = overview.exceededBudgets;

    if (smsCount == 0 && billsDue == 0 && exceededBudgets.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (smsCount > 0) ...[
          FadeSlideIn(index: 1, child: _SmsAttentionCard(count: smsCount)),
          const SizedBox(height: 14),
        ],
        if (billsDue > 0) ...[
          FadeSlideIn(index: 1, child: _BillsDueAttentionCard(count: billsDue)),
          const SizedBox(height: 14),
        ],
        if (exceededBudgets.isNotEmpty) ...[
          FadeSlideIn(
            index: 1,
            child: _BudgetAlertCard(
              exceeded: exceededBudgets,
              onTap: () =>
                  ref.read(mainTabProvider.notifier).state = _budgetsTab,
            ),
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _RecentTransactionsSection extends ConsumerWidget {
  const _RecentTransactionsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recentTxsAsync = ref.watch(recentTransactionsProvider);

    return FadeSlideIn(
      index: 3,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Recent transactions',
            actionLabel: 'See all',
            onAction: () =>
                ref.read(mainTabProvider.notifier).state = _transactionsTab,
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
    );
  }
}

class _UpcomingRecurringSection extends ConsumerWidget {
  const _UpcomingRecurringSection();

  static Future<void> _recurringAction(
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

  static void _showRecurringActionSheet(
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
                final ok = await confirmDestructive(
                  context,
                  title: 'Delete ${item.name}?',
                  message: 'This payment rule will be permanently deleted. Past transactions it created are kept.',
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
    final recurringAsync = ref.watch(recurringListProvider);

    return FadeSlideIn(
      index: 4,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(
            title: 'Upcoming recurring',
            actionLabel: 'Manage',
            onAction: () =>
                AppRoutes.push(context, const RecurringPaymentsScreen()),
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
                  message:
                      'Add rent or subscriptions to keep track of what is due.',
                  actionLabel: 'Add one',
                  onAction: () =>
                      AppRoutes.push(context, const RecurringPaymentsScreen()),
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
                      onTap: () => _showRecurringActionSheet(context, ref, r),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _InsightsSection extends ConsumerWidget {
  const _InsightsSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final homeInsightsAsync = ref.watch(homeInsightsProvider);

    return homeInsightsAsync.maybeWhen(
      data: (insights) => insights.isEmpty
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xl),
              child: FadeSlideIn(
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
                              const Text('💡', style: TextStyle(fontSize: 16)),
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
                              padding: const EdgeInsets.symmetric(vertical: 4),
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
            ),
      orElse: () => const SizedBox.shrink(),
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

    return ref
        .watch(homeMonthSummaryProvider)
        .when(
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
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: p.muted,
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _MonthFigure(
                        icon: Icons.south_west_rounded,
                        label: 'Income',
                        amount: data.totalIncome,
                        isMasked: isMasked,
                        color: p.income,
                      ),
                      _MonthFigure(
                        icon: Icons.north_east_rounded,
                        label: 'Spent',
                        amount: data.totalExpense,
                        isMasked: isMasked,
                        color: p.expense,
                      ),
                      _MonthFigure(
                        icon: positive
                            ? Icons.trending_up_rounded
                            : Icons.trending_down_rounded,
                        label: positive ? 'Saved' : 'Over by',
                        amount: net.abs(),
                        isMasked: isMasked,
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
  final double amount;
  final bool isMasked;
  final Color color;

  const _MonthFigure({
    required this.icon,
    required this.label,
    required this.amount,
    required this.isMasked,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    // Below a lakh, show the full figure at the normal size-16 look. From a
    // lakh up, switch to the compact "₹2.05 L" / "₹1.00 Cr" form so a crore
    // value stays readable in its ~1/3-of-card slot instead of ellipsising to
    // a stub. FittedBox then scales down only if even that is too wide, with a
    // floor so it never becomes unreadable.
    final text = isMasked
        ? '••••••'
        : (amount >= 100000
              ? CurrencyFormatter.formatCompact(amount)
              : CurrencyFormatter.format(amount));
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption(p.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              text,
              maxLines: 1,
              style: AppText.amount(color, size: 16),
            ),
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
          : Text(initial, style: AppText.title(p.primary)),
    );
  }
}

/// Shown only when at least one budget has reached or crossed its limit: a
/// compact alert in the attention zone that jumps to the Budgets tab. Budgets
/// are no longer previewed on Home — only flagged when they need attention.
class _BudgetAlertCard extends ConsumerWidget {
  final List<BudgetModel> exceeded;
  final VoidCallback onTap;

  const _BudgetAlertCard({required this.exceeded, required this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final isMasked = ref.watch(privacyModeProvider);

    final String title;
    final String subtitle;
    if (exceeded.length == 1) {
      final b = exceeded.first;
      final name = b.categoryName ?? 'Budget';
      if (b.overAmount > 0) {
        title = '$name budget exceeded';
        subtitle =
            'Over by ${CurrencyFormatter.format(b.overAmount, isMasked: isMasked)}';
      } else {
        title = '$name budget at its limit';
        subtitle = 'Limit reached';
      }
    } else {
      title = '${exceeded.length} budgets over limit';
      subtitle = 'Tap to review your budgets';
    }

    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: p.expense.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: const Text('🎯', style: TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodyStrong(p.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption(p.expense),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded, size: 18, color: p.muted),
        ],
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
              style: AppText.caption(p.primary)
                  .copyWith(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown only while at least one active recurring rule is due within the next
/// seven days: a compact tappable card in the attention zone that opens the
/// recurring payments screen. Modelled on [_SmsAttentionCard]/[_BudgetAlertCard].
class _BillsDueAttentionCard extends StatelessWidget {
  final int count;

  const _BillsDueAttentionCard({required this.count});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return AppCard(
      onTap: () => AppRoutes.push(context, const RecurringPaymentsScreen()),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: p.primary.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: const Text('🔁', style: TextStyle(fontSize: 20)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$count ${count == 1 ? 'bill' : 'bills'} due this week',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodyStrong(p.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  'Tap to review upcoming payments',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.caption(p.muted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Icon(Icons.chevron_right_rounded, size: 18, color: p.muted),
        ],
      ),
    );
  }
}

/// Gradient total-balance card with privacy mode toggle.
class _HeroCard extends ConsumerWidget {
  final List<AccountModel> accounts;

  /// Total tracked balance from the composed [homeOverviewProvider] snapshot,
  /// so the hero never disagrees with the rest of Home's top region.
  final double total;
  final ValueChanged<AccountModel> onEditAccount;

  const _HeroCard({
    required this.accounts,
    required this.total,
    required this.onEditAccount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final isMasked = ref.watch(privacyModeProvider);

    return AppCard(
      gradient: p.heroGradientSoft,
      radius: AppRadius.lg,
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
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withValues(alpha: 0.16),
                      Colors.white.withValues(alpha: 0.0),
                    ],
                    begin: Alignment.topLeft,
                    end: const Alignment(0.2, 0.1),
                  ),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.14),
                  ),
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
                      style: AppText.caption(
                        Colors.white.withValues(alpha: 0.9),
                      ).copyWith(fontWeight: FontWeight.w600),
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
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                          ),
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
                      style: AppText.display(Colors.white)
                          .copyWith(fontSize: 36, letterSpacing: -1.0),
                    ),
                  ),
                ),
                if (accounts.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _AccountChips(
                    accounts: accounts,
                    isMasked: isMasked,
                    onEditAccount: onEditAccount,
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

/// The per-account chips under the hero total.
///
/// Lays the chips out responsively: when they all fit the card width they
/// wrap onto centred rows (so e.g. three accounts read as two side-by-side
/// with the third centred beneath, instead of hiding off-screen), and when
/// they don't fit they scroll horizontally with a right-edge fade cue so the
/// user can see there is more to swipe to.
class _AccountChips extends StatelessWidget {
  final List<AccountModel> accounts;
  final bool isMasked;
  final ValueChanged<AccountModel> onEditAccount;

  const _AccountChips({
    required this.accounts,
    required this.isMasked,
    required this.onEditAccount,
  });

  static const double _chipMinWidth = 132;
  static const double _chipGap = 10;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final chips = [for (final acc in accounts) _chip(context, p, acc)];

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxW = constraints.maxWidth;
        // Would the chips fit on a single row at their minimum width? If so,
        // a wrap keeps everything visible (no hidden off-screen cards); the
        // last row centres, giving the 2-up + 1-centred "tree" layout for
        // three accounts.
        final neededForOneRow =
            accounts.length * _chipMinWidth + (accounts.length - 1) * _chipGap;

        if (neededForOneRow <= maxW) {
          return Wrap(
            spacing: _chipGap,
            runSpacing: _chipGap,
            alignment: WrapAlignment.center,
            children: chips,
          );
        }

        // Too many / too wide to fit: scroll horizontally, with a fade on the
        // right edge so it is obvious more cards are off-screen.
        return ShaderMask(
          shaderCallback: (rect) => const LinearGradient(
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
            colors: [Colors.white, Colors.white, Colors.transparent],
            stops: [0.0, 0.9, 1.0],
          ).createShader(rect),
          blendMode: BlendMode.dstIn,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            // Pad the right so the last chip can clear the fade.
            padding: const EdgeInsets.only(right: 24),
            child: Row(
              children: [
                for (var i = 0; i < chips.length; i++) ...[
                  if (i > 0) const SizedBox(width: _chipGap),
                  chips[i],
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _chip(BuildContext context, AppPalette p, AccountModel acc) {
    return Pressable(
      onTap: () => onEditAccount(acc),
      child: Container(
        constraints: const BoxConstraints(minWidth: _chipMinWidth),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        // Darker, not lighter, than the card: white text keeps AA contrast.
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(AppRadius.md),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (acc.isPrimary) ...[
                  Icon(Icons.star_rounded, size: 13, color: p.secondary),
                  const SizedBox(width: 3),
                ],
                // Cap the name width so a very long account name truncates
                // instead of stretching the chip arbitrarily wide (the
                // minWidth above stays the floor).
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Text(
                    acc.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.caption(Colors.white.withValues(alpha: 0.9)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                CurrencyFormatter.format(
                  acc.currentBalance,
                  isMasked: isMasked,
                ),
                maxLines: 1,
                style: AppText.amount(Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
