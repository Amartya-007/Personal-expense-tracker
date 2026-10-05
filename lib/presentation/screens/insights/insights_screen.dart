import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/analytics_summary_model.dart';
import '../../providers/budget_providers.dart';
import '../../providers/insights_providers.dart';
import '../../providers/settings_providers.dart';
import '../../widgets/animated_progress_bar.dart';
import '../../widgets/app_card.dart';
import '../../widgets/async_section.dart';
import '../../widgets/budget_row.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/fade_slide_in.dart';
import '../../widgets/list_widgets.dart';
import '../../widgets/pill_chips.dart';
import '../../widgets/section_header.dart';
import '../../widgets/skeleton.dart';

const Map<DateTimeRangeType, String> _rangeLabels = {
  DateTimeRangeType.today: 'Today',
  DateTimeRangeType.thisWeek: 'This Week',
  DateTimeRangeType.thisMonth: 'This Month',
  DateTimeRangeType.lastMonth: 'Last Month',
};

/// How many categories get their own legend row before the rest are folded
/// into "Other" (the legend used to overflow with many categories).
const int _maxLegendRows = 5;

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final rangeType = ref.watch(selectedDateRangeProvider);
    final analyticsAsync = ref.watch(analyticsSummaryProvider);
    final budgetsAsync = ref.watch(budgetListProvider);

    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: p.primary,
          onRefresh: () async {
            ref.invalidate(analyticsSummaryProvider);
            ref.invalidate(spendingTrendProvider);
            await ref.read(budgetListProvider.notifier).loadBudgets();
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              18,
              16,
              18,
              MediaQuery.of(context).padding.bottom + 130,
            ),
            children: [
              FadeSlideIn(child: Text('Insights', style: AppText.display(p.ink))),
              const SizedBox(height: 16),
              FadeSlideIn(
                index: 1,
                child: PillChips(
                  options: _rangeLabels.values.toList(),
                  selected: _rangeLabels[rangeType]!,
                  onSelected: (label) {
                    ref.read(selectedDateRangeProvider.notifier).state =
                        _rangeLabels.entries
                            .firstWhere((e) => e.value == label)
                            .key;
                  },
                ),
              ),
              const SizedBox(height: 16),
              AsyncSection<AnalyticsSummaryModel>(
                value: analyticsAsync,
                skeletonHeight: 180,
                errorLabel: 'Could not load insights',
                onRetry: () => ref.invalidate(analyticsSummaryProvider),
                builder: (data) => _AnalyticsBody(data: data),
              ),
              const SizedBox(height: 24),
              FadeSlideIn(
                index: 5,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SectionHeader(
                      title: 'Budget progress',
                      actionLabel: 'See all',
                      onAction: () =>
                          ref.read(mainTabProvider.notifier).state = 2,
                    ),
                    AsyncSection(
                      value: budgetsAsync,
                      errorLabel: 'Could not load budgets',
                      onRetry: () =>
                          ref.read(budgetListProvider.notifier).loadBudgets(),
                      builder: (budgets) {
                        if (budgets.isEmpty) {
                          return const EmptyState(
                            compact: true,
                            emoji: '🎯',
                            title: 'No budgets yet',
                            message: 'Create one from the Budgets tab.',
                          );
                        }
                        return SettingsGroup(
                          children: [
                            for (final b in budgets.take(4)) BudgetRow(budget: b),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AnalyticsBody extends ConsumerWidget {
  final AnalyticsSummaryModel data;

  const _AnalyticsBody({required this.data});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        FadeSlideIn(index: 2, child: _CategoryCard(data: data)),
        const SizedBox(height: 24),
        FadeSlideIn(
          index: 3,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'Income vs expense'),
              _IncomeExpenseCard(data: data),
            ],
          ),
        ),
        const SizedBox(height: 24),
        FadeSlideIn(
          index: 4,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionHeader(title: 'Spending trend'),
              const _TrendCard(),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'By payment method'),
            if (data.paymentMethodBreakdown.isEmpty)
              const EmptyState(
                compact: true,
                emoji: '💳',
                title: 'No payments in this period',
              )
            else
              _PaymentBars(items: data.paymentMethodBreakdown),
          ],
        ),
        const SizedBox(height: 24),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionHeader(title: 'By account'),
            if (data.accountBreakdown.isEmpty)
              const EmptyState(
                compact: true,
                emoji: '🏦',
                title: 'No account activity in this period',
              )
            else
              SettingsGroup(
                children: [
                  for (final acc in data.accountBreakdown)
                    ListRowTile(
                      emoji: '🏦',
                      title: acc.accountName,
                      trailing: Text(
                        CurrencyFormatter.format(acc.totalAmount),
                        style: AppText.bodyStrong(p.ink),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _CategoryCard extends StatelessWidget {
  final AnalyticsSummaryModel data;

  const _CategoryCard({required this.data});

  Color _color(int idx, CategorySpending item) => idx < AppColors.categoryPalette.length
      ? AppColors.categoryPalette[idx]
      : Color(item.categoryColor);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final items = data.categoryBreakdown;

    if (items.isEmpty) {
      return const EmptyState(
        compact: true,
        emoji: '🧾',
        title: 'No expenses in this period',
        message: 'Spending by category will appear here.',
      );
    }

    final shown = items.take(_maxLegendRows).toList();
    final rest = items.skip(_maxLegendRows).toList();
    final otherTotal = rest.fold<double>(0.0, (s, e) => s + e.totalAmount);
    final total = data.totalExpense;

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Spending by category', style: AppText.bodyStrong(p.ink)),
          const SizedBox(height: 14),
          Row(
            children: [
              SizedBox(
                width: 130,
                height: 130,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    PieChart(
                      PieChartData(
                        sectionsSpace: 2,
                        centerSpaceRadius: 40,
                        startDegreeOffset: -90,
                        sections: [
                          for (var i = 0; i < items.length; i++)
                            PieChartSectionData(
                              value: items[i].totalAmount,
                              color: _color(i, items[i]),
                              radius: 20,
                              showTitle: false,
                            ),
                        ],
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Spent', style: AppText.caption(p.muted).copyWith(fontSize: 10)),
                        Text(
                          CurrencyFormatter.format(total),
                          style: AppText.bodyStrong(p.ink),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  children: [
                    for (var i = 0; i < shown.length; i++)
                      _LegendRow(
                        color: _color(i, shown[i]),
                        name: shown[i].categoryName,
                        amount: shown[i].totalAmount,
                        share: total > 0 ? shown[i].totalAmount / total : 0,
                      ),
                    if (rest.isNotEmpty)
                      _LegendRow(
                        color: p.muted,
                        name: 'Other (${rest.length})',
                        amount: otherTotal,
                        share: total > 0 ? otherTotal / total : 0,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LegendRow extends StatelessWidget {
  final Color color;
  final String name;
  final double amount;
  final double share;

  const _LegendRow({
    required this.color,
    required this.name,
    required this.amount,
    required this.share,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption(p.ink),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${(share * 100).round()}%',
            style: AppText.caption(p.muted).copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _IncomeExpenseCard extends StatelessWidget {
  final AnalyticsSummaryModel data;

  const _IncomeExpenseCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final income = data.totalIncome;
    final expense = data.totalExpense;
    final net = income - expense;

    Widget line(String label, double value, double fill, Color color) => Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(label, style: AppText.body(p.ink)),
                Text(CurrencyFormatter.format(value), style: AppText.bodyStrong(color)),
              ],
            ),
            const SizedBox(height: 8),
            AnimatedProgressBar(value: fill, color: color),
          ],
        );

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          line('Income', income, income > 0 ? 1.0 : 0.0, p.income),
          const SizedBox(height: 16),
          line(
            'Expense',
            expense,
            income > 0 ? (expense / income).clamp(0.0, 1.0) : (expense > 0 ? 1.0 : 0.0),
            p.expense,
          ),
          const SizedBox(height: 14),
          Divider(color: p.border, height: 1),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(net >= 0 ? 'Saved' : 'Overspent', style: AppText.body(p.muted)),
              Text(
                CurrencyFormatter.format(net.abs()),
                style: AppText.bodyStrong(net >= 0 ? p.income : p.expense),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrendCard extends ConsumerWidget {
  const _TrendCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final trendAsync = ref.watch(spendingTrendProvider);
    final range = insightsRange(ref.watch(selectedDateRangeProvider));
    final fmt = DateFormat('d MMM');

    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
      child: trendAsync.when(
        skipLoadingOnReload: true,
        loading: () => const SizedBox(
          height: 120,
          child: Center(child: Skeleton(height: 90)),
        ),
        error: (_, __) => SizedBox(
          height: 100,
          child: Center(
            child: Text('Could not load trend', style: AppText.caption(p.muted)),
          ),
        ),
        data: (spots) {
          // A single point has no width to draw a line across (Today).
          if (spots.length < 2) {
            return SizedBox(
              height: 100,
              child: Center(
                child: Text(
                  'A trend appears once the period spans more than one day.',
                  textAlign: TextAlign.center,
                  style: AppText.caption(p.muted),
                ),
              ),
            );
          }
          final maxY = spots.map((s) => s.y).reduce(math.max);
          return Column(
            children: [
              SizedBox(
                height: 100,
                child: LineChart(
                  LineChartData(
                    gridData: const FlGridData(show: false),
                    titlesData: const FlTitlesData(show: false),
                    borderData: FlBorderData(show: false),
                    lineTouchData: const LineTouchData(enabled: false),
                    minX: 0,
                    maxX: (spots.length - 1).toDouble(),
                    minY: 0,
                    maxY: maxY > 0 ? maxY * 1.2 : 100.0,
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        color: p.primary,
                        barWidth: 3.5,
                        isStrokeCapRound: true,
                        dotData: const FlDotData(show: false),
                        belowBarData: BarAreaData(
                          show: true,
                          color: p.primary.withValues(alpha: 0.1),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Real dates instead of the old "Start" / "End" placeholders.
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(fmt.format(range.start), style: AppText.caption(p.muted).copyWith(fontSize: 11)),
                  Text(fmt.format(range.end), style: AppText.caption(p.muted).copyWith(fontSize: 11)),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PaymentBars extends StatelessWidget {
  final List<PaymentMethodSpending> items;

  const _PaymentBars({required this.items});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final total = items.fold<double>(0.0, (s, e) => s + e.totalAmount);

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: SizedBox(
        height: 130,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            for (final pm in items)
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(
                        begin: 0,
                        end: total > 0
                            ? ((pm.totalAmount / total) * 80).clamp(16.0, 80.0)
                            : 16.0,
                      ),
                      duration: AppMotion.slow,
                      curve: AppMotion.enter,
                      builder: (context, h, _) => Container(
                        width: 32,
                        height: h,
                        decoration: BoxDecoration(
                          color: p.primary,
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      pm.paymentMethod,
                      style: AppText.caption(p.muted).copyWith(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      '${total > 0 ? (pm.totalAmount / total * 100).round() : 0}%',
                      style: AppText.caption(p.muted).copyWith(fontSize: 10),
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
