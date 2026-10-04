import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/budget_model.dart';
import '../../providers/budget_providers.dart';
import '../../widgets/undo_snackbar.dart';
import 'add_edit_budget_dialog.dart';

class BudgetListScreen extends ConsumerStatefulWidget {
  const BudgetListScreen({super.key});

  @override
  ConsumerState<BudgetListScreen> createState() => _BudgetListScreenState();
}

class _BudgetListScreenState extends ConsumerState<BudgetListScreen> {
  String _selectedPeriod = 'Monthly';

  void _showBudgetDetail(BuildContext context, BudgetModel budget, double percentage) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final percent = (percentage * 100).round();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
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
              '${budget.categoryName ?? 'Category'} budget',
              style: GoogleFonts.sora(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 14),

            // Top Status Card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surface2Dark : AppColors.surface2Light,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    CurrencyFormatter.format(budget.remainingAmount),
                    style: GoogleFonts.sora(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'left of ${CurrencyFormatter.format(budget.amount)} this month',
                    style: GoogleFonts.sora(
                      fontSize: 12,
                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 14),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(5),
                    child: LinearProgressIndicator(
                      value: percentage.clamp(0.0, 1.0),
                      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
                      valueColor: AlwaysStoppedAnimation<Color>(
                        percentage >= 1.0
                            ? AppColors.expense
                            : percentage >= 0.75
                                ? AppColors.secondary
                                : (isDark ? AppColors.primaryDark : AppColors.primary),
                      ),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),
            Text(
              'Alerts',
              style: GoogleFonts.sora(fontSize: 14, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),

            Container(
              decoration: BoxDecoration(
                color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isDark ? AppColors.borderDark : AppColors.borderLight,
                  width: 1.0,
                ),
              ),
              child: Column(
                children: [75, 90, 100].map((threshold) {
                  final isReached = percent >= threshold;
                  final isLast = threshold == 100;
                  return Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            Text(
                              isReached ? '✅' : '⏳',
                              style: const TextStyle(fontSize: 16),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$threshold% reached',
                                    style: GoogleFonts.sora(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                    ),
                                  ),
                                  Text(
                                    isReached ? 'Notified once this period' : 'Not triggered yet',
                                    style: GoogleFonts.sora(
                                      fontSize: 12,
                                      color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                    ),
                                  ),
                                ],
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
                }).toList(),
              ),
            ),

            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  ref.read(budgetListProvider.notifier).deleteBudget(budget.id);
                  UndoSnackbar.show(
                    context,
                    message: 'Budget deleted',
                    onUndo: () {
                      ref.read(budgetListProvider.notifier).createBudget(budget);
                    },
                  );
                },
                child: Text(
                  'Delete budget',
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
  Widget build(BuildContext context) {
    final budgetsAsync = ref.watch(budgetListProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.backgroundDark : AppColors.backgroundLight,
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(18, 16, 18, MediaQuery.of(context).padding.bottom + 130),
          children: [
            // Top Bar: Title & + button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Budgets',
                  style: GoogleFonts.sora(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (_) => const AddEditBudgetDialog(),
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
                    child: Center(
                      child: Icon(
                        Icons.add,
                        size: 22,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Segmented Period Selector
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: isDark ? AppColors.surface2Dark : AppColors.surface2Light,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: ['Weekly', 'Monthly', 'Yearly', 'Custom'].map((period) {
                  final isSelected = _selectedPeriod == period;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedPeriod = period),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 9),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? (isDark ? AppColors.surfaceDark : AppColors.surfaceLight)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(11),
                          boxShadow: isSelected
                              ? [
                                  isDark ? AppColors.cardShadowDark : AppColors.cardShadowLight,
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            period,
                            style: GoogleFonts.sora(
                              fontSize: 12,
                              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                              color: isSelected
                                  ? (isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight)
                                  : (isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 16),

            // Big Circular Donut Card
            budgetsAsync.when(
              data: (budgets) {
                final totalSpent = budgets.fold<double>(0.0, (sum, b) => sum + b.spentAmount);
                final totalLimit = budgets.fold<double>(0.0, (sum, b) => sum + b.amount);
                final totalLeft = math.max(0.0, totalLimit - totalSpent);
                final overallPercent = totalLimit > 0 ? (totalSpent / totalLimit).clamp(0.0, 1.0) : 0.0;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                      child: Row(
                        children: [
                          // Circular Donut Progress
                          SizedBox(
                            width: 100,
                            height: 100,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                SizedBox(
                                  width: 90,
                                  height: 90,
                                  child: CircularProgressIndicator(
                                    value: 1.0,
                                    strokeWidth: 10,
                                    color: isDark ? AppColors.surface2Dark : AppColors.surface2Light,
                                  ),
                                ),
                                SizedBox(
                                  width: 90,
                                  height: 90,
                                  child: CircularProgressIndicator(
                                    value: overallPercent,
                                    strokeWidth: 10,
                                    strokeCap: StrokeCap.round,
                                    color: overallPercent >= 1.0
                                        ? AppColors.expense
                                        : (isDark ? AppColors.primaryDark : AppColors.primary),
                                  ),
                                ),
                                Text(
                                  '${(overallPercent * 100).round()}%',
                                  style: GoogleFonts.sora(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w800,
                                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Left this month',
                                  style: GoogleFonts.sora(
                                    fontSize: 12,
                                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  CurrencyFormatter.format(totalLeft),
                                  style: GoogleFonts.sora(
                                    fontSize: 26,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                    color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'of ${CurrencyFormatter.format(totalLimit)} budgeted',
                                  style: GoogleFonts.sora(
                                    fontSize: 12,
                                    color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Categories Header
                    Text(
                      'Categories',
                      style: GoogleFonts.sora(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Category Budgets Card
                    if (budgets.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.surfaceDark : AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isDark ? AppColors.borderDark : AppColors.borderLight,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'No budgets yet. Create a budget to start tracking spending.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.sora(
                              fontSize: 12.5,
                              color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                            ),
                          ),
                        ),
                      )
                    else
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
                                InkWell(
                                  onTap: () => _showBudgetDetail(context, b, b.percentage),
                                  child: Padding(
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

                    const SizedBox(height: 14),
                    Text(
                      'Alerts fire at 75%, 90% and 100%, once per period.',
                      style: GoogleFonts.sora(
                        fontSize: 12,
                        color: isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight,
                      ),
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
}

