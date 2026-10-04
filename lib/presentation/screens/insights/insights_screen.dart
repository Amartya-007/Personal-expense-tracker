import 'dart:math' as math;
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../providers/budget_providers.dart';
import '../../providers/insights_providers.dart';

class InsightsScreen extends ConsumerWidget {
  const InsightsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rangeType = ref.watch(selectedDateRangeProvider);
    final analyticsAsync = ref.watch(analyticsSummaryProvider);
    final spendingTrendAsync = ref.watch(spendingTrendProvider);
    final budgetsAsync = ref.watch(budgetListProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(18, 16, 18, MediaQuery.of(context).padding.bottom + 130),
          children: [
            // Title
            Text(
              'Insights',
              style: GoogleFonts.sora(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
              ),
            ),
            const SizedBox(height: 16),

            // Date Range Filter Chips
            SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _buildChip('Today', rangeType == DateTimeRangeType.today, () {
                    ref.read(selectedDateRangeProvider.notifier).state = DateTimeRangeType.today;
                  }, isDark),
                  _buildChip('This Week', rangeType == DateTimeRangeType.thisWeek, () {
                    ref.read(selectedDateRangeProvider.notifier).state = DateTimeRangeType.thisWeek;
                  }, isDark),
                  _buildChip('This Month', rangeType == DateTimeRangeType.thisMonth, () {
                    ref.read(selectedDateRangeProvider.notifier).state = DateTimeRangeType.thisMonth;
                  }, isDark),
                  _buildChip('Last Month', rangeType == DateTimeRangeType.lastMonth, () {
                    ref.read(selectedDateRangeProvider.notifier).state = DateTimeRangeType.lastMonth;
                  }, isDark),
                ],
              ),
            ),
            const SizedBox(height: 16),

            analyticsAsync.when(
              data: (data) {
                final categoryBreakdown = data.categoryBreakdown;
                final totalExpense = data.totalExpense;
                final totalIncome = data.totalIncome;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Spending by Category Card
                    Container(
                      padding: const EdgeInsets.all(18),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Spending by category',
                            style: GoogleFonts.sora(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                            ),
                          ),
                          const SizedBox(height: 14),

                          if (categoryBreakdown.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 24.0),
                              child: Center(
                                child: Text(
                                  'No expenses for this period.',
                                  style: GoogleFonts.sora(
                                    fontSize: 12.5,
                                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                  ),
                                ),
                              ),
                            )
                          else
                            Row(
                              children: [
                                // Donut Chart with center label
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
                                          sections: categoryBreakdown.asMap().entries.map((entry) {
                                            final idx = entry.key;
                                            final item = entry.value;
                                            final color = idx < AppColors.categoryPalette.length
                                                ? AppColors.categoryPalette[idx]
                                                : Color(item.categoryColor);

                                            return PieChartSectionData(
                                              value: item.totalAmount,
                                              color: color,
                                              radius: 20,
                                              showTitle: false,
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                      Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Spent',
                                            style: GoogleFonts.sora(
                                              fontSize: 10,
                                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                            ),
                                          ),
                                          Text(
                                            CurrencyFormatter.format(totalExpense),
                                            style: GoogleFonts.sora(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w800,
                                              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 16),

                                // Category Legend
                                Expanded(
                                  child: Column(
                                    children: categoryBreakdown.asMap().entries.map((entry) {
                                      final idx = entry.key;
                                      final item = entry.value;
                                      final color = idx < AppColors.categoryPalette.length
                                          ? AppColors.categoryPalette[idx]
                                          : Color(item.categoryColor);

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
                                                item.categoryName,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.sora(
                                                  fontSize: 12,
                                                  color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                                ),
                                              ),
                                            ),
                                            Text(
                                              CurrencyFormatter.format(item.totalAmount),
                                              style: GoogleFonts.sora(
                                                fontSize: 12,
                                                fontWeight: FontWeight.w700,
                                                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                              ),
                                            ),
                                          ],
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 2. Income vs Expense Card
                    _buildSectionHeader('Income vs expense', isDark),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(18),
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
                      child: Column(
                        children: [
                          // Income
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Income',
                                style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                CurrencyFormatter.format(totalIncome),
                                style: GoogleFonts.sora(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? AppColors.incomeDark : AppColors.income,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: LinearProgressIndicator(
                              value: totalIncome > 0 ? 1.0 : 0.0,
                              backgroundColor: isDark ? AppColors.surface2Dark : AppColors.surface2Light,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isDark ? AppColors.incomeDark : AppColors.income,
                              ),
                              minHeight: 8,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Expense
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Expense',
                                style: GoogleFonts.sora(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                              Text(
                                CurrencyFormatter.format(totalExpense),
                                style: GoogleFonts.sora(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: isDark ? AppColors.expenseDark : AppColors.expense,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(5),
                            child: LinearProgressIndicator(
                              value: totalIncome > 0
                                  ? (totalExpense / totalIncome).clamp(0.0, 1.0)
                                  : (totalExpense > 0 ? 1.0 : 0.0),
                              backgroundColor: isDark ? AppColors.surface2Dark : AppColors.surface2Light,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                isDark ? AppColors.expenseDark : AppColors.expense,
                              ),
                              minHeight: 8,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 3. Spending Trend Sparkline Chart (Real Data)
                    _buildSectionHeader('Spending trend', isDark),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 14),
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
                      child: spendingTrendAsync.when(
                        data: (spots) {
                          final maxY = spots.isEmpty ? 100.0 : spots.map((s) => s.y).reduce(math.max);
                          return Column(
                            children: [
                              SizedBox(
                                height: 100,
                                child: LineChart(
                                  LineChartData(
                                    gridData: const FlGridData(show: false),
                                    titlesData: const FlTitlesData(show: false),
                                    borderData: FlBorderData(show: false),
                                    minX: 0,
                                    maxX: spots.isNotEmpty ? (spots.length - 1).toDouble() : 7.0,
                                    minY: 0,
                                    maxY: maxY > 0 ? maxY * 1.2 : 100.0,
                                    lineBarsData: [
                                      LineChartBarData(
                                        spots: spots.isEmpty ? [const FlSpot(0, 0)] : spots,
                                        isCurved: true,
                                        color: isDark ? AppColors.primaryDark : AppColors.primary,
                                        barWidth: 3.5,
                                        isStrokeCapRound: true,
                                        dotData: const FlDotData(show: false),
                                        belowBarData: BarAreaData(
                                          show: true,
                                          color: (isDark ? AppColors.primaryDark : AppColors.primary).withValues(alpha: 0.1),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Start',
                                    style: GoogleFonts.sora(
                                      fontSize: 11,
                                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                    ),
                                  ),
                                  Text(
                                    'End',
                                    style: GoogleFonts.sora(
                                      fontSize: 11,
                                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          );
                        },
                        loading: () => const SizedBox(height: 100, child: Center(child: CircularProgressIndicator())),
                        error: (_, __) => const SizedBox(height: 100, child: Center(child: Text('Could not load trend'))),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // 4. By Payment Method Vertical Columns
                    _buildSectionHeader('By payment method', isDark),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(18),
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
                      child: data.paymentMethodBreakdown.isEmpty
                          ? Center(
                              child: Text(
                                'No payment method records.',
                                style: GoogleFonts.sora(
                                  fontSize: 12,
                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                ),
                              ),
                            )
                          : SizedBox(
                              height: 120,
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: data.paymentMethodBreakdown.map((pm) {
                                  final double total = data.paymentMethodBreakdown.fold(0.0, (s, e) => s + e.totalAmount);
                                  final double pct = total > 0 ? (pm.totalAmount / total) : 0.3;
                                  final barHeight = (pct * 80).clamp(16.0, 80.0);

                                  return Expanded(
                                    child: Column(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        Container(
                                          width: 32,
                                          height: barHeight,
                                          decoration: BoxDecoration(
                                            color: isDark ? AppColors.primaryDark : AppColors.primary,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          pm.paymentMethod,
                                          style: GoogleFonts.sora(
                                            fontSize: 11,
                                            fontWeight: FontWeight.w600,
                                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                          ),
                                        ),
                                        Text(
                                          '${(pct * 100).round()}%',
                                          style: GoogleFonts.sora(
                                            fontSize: 10,
                                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                    ),

                    const SizedBox(height: 24),

                    // 5. By Account Breakdown
                    _buildSectionHeader('By account', isDark),
                    const SizedBox(height: 8),
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
                      child: data.accountBreakdown.isEmpty
                          ? Padding(
                              padding: const EdgeInsets.all(18.0),
                              child: Center(
                                child: Text(
                                  'No account records.',
                                  style: GoogleFonts.sora(
                                    fontSize: 12,
                                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                  ),
                                ),
                              ),
                            )
                          : Column(
                              children: List.generate(data.accountBreakdown.length, (index) {
                                final acc = data.accountBreakdown[index];
                                final isLast = index == data.accountBreakdown.length - 1;

                                return Column(
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            acc.accountName,
                                            style: GoogleFonts.sora(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w600,
                                              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                            ),
                                          ),
                                          Text(
                                            CurrencyFormatter.format(acc.totalAmount),
                                            style: GoogleFonts.sora(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (!isLast)
                                      Divider(
                                        color: isDark ? AppColors.borderDark : AppColors.borderLight,
                                        height: 1,
                                      ),
                                  ],
                                );
                              }),
                            ),
                    ),

                    const SizedBox(height: 24),

                    // 6. Budget Utilization Card
                    _buildSectionHeader('Budget utilization', isDark),
                    const SizedBox(height: 8),
                    budgetsAsync.when(
                      data: (budgets) {
                        if (budgets.isEmpty) {
                          return Container(
                            padding: const EdgeInsets.all(18),
                            decoration: BoxDecoration(
                              color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isDark ? AppColors.borderDark : AppColors.borderLight,
                              ),
                            ),
                            child: Center(
                              child: Text(
                                'No budgets active.',
                                style: GoogleFonts.sora(
                                  fontSize: 12,
                                  color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                ),
                              ),
                            ),
                          );
                        }

                        return Container(
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
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                          child: Column(
                            children: List.generate(budgets.length, (index) {
                              final b = budgets[index];
                              final isLast = index == budgets.length - 1;
                              final percent = (b.percentage * 100).round();
                              Color barColor = isDark ? AppColors.primaryDark : AppColors.primary;
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
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              '${AppColors.getCategoryEmoji(b.categoryName)} ${b.categoryName ?? 'Budget'}',
                                              style: GoogleFonts.sora(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                              ),
                                            ),
                                            Text(
                                              '${CurrencyFormatter.format(b.spentAmount)} / ${CurrencyFormatter.format(b.amount)}',
                                              style: GoogleFonts.sora(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        ClipRRect(
                                          borderRadius: BorderRadius.circular(5),
                                          child: LinearProgressIndicator(
                                            value: b.percentage.clamp(0.0, 1.0),
                                            backgroundColor: isDark ? AppColors.surface2Dark : AppColors.surface2Light,
                                            valueColor: AlwaysStoppedAnimation<Color>(barColor),
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
                                            color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  if (!isLast)
                                    Divider(
                                      color: isDark ? AppColors.borderDark : AppColors.borderLight,
                                      height: 1,
                                    ),
                                ],
                              );
                            }),
                          ),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChip(String label, bool isSelected, VoidCallback onTap, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
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
              label,
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
