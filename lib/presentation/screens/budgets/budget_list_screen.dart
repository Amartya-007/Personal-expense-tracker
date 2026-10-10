import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_motion.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/budget_model.dart';
import '../../providers/budget_providers.dart';
import '../../providers/category_providers.dart';
import '../../widgets/animated_progress_bar.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_sheets.dart';
import '../../widgets/async_section.dart';
import '../../widgets/budget_row.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/fade_slide_in.dart';
import '../../widgets/list_widgets.dart';
import '../../widgets/pressable.dart';
import '../../widgets/section_header.dart';
import '../../widgets/segmented_tabs.dart';
import '../../widgets/undo_snackbar.dart';
import 'budget_form.dart';

const Map<String, String> _periodNoun = {
  'weekly': 'week',
  'monthly': 'month',
  'yearly': 'year',
};

class BudgetListScreen extends ConsumerStatefulWidget {
  const BudgetListScreen({super.key});

  @override
  ConsumerState<BudgetListScreen> createState() => _BudgetListScreenState();
}

class _BudgetListScreenState extends ConsumerState<BudgetListScreen> {
  // This selector used to be decorative: it never filtered anything, so
  // weekly, monthly and yearly budgets were all mixed into one total.
  String _period = 'monthly';

  Future<void> _createBudget(List<BudgetModel> existing) async {
    final messenger = ScaffoldMessenger.of(context);
    final categories = await ref.read(expenseCategoriesProvider.future);
    if (!mounted) return;
    if (categories.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Add an expense category first.')),
      );
      return;
    }

    final budget = await AppBottomSheet.show<BudgetModel>(
      context,
      title: 'Create budget',
      builder: (_) => BudgetForm(
        categories: categories,
        existing: existing,
        initialPeriod: _period,
      ),
    );
    if (budget == null) return;

    await ref.read(budgetListProvider.notifier).createBudget(budget);
    if (mounted) setState(() => _period = budget.period);
  }

  Future<void> _editLimit(BudgetModel budget) async {
    final messenger = ScaffoldMessenger.of(context);
    final values = await showFieldsSheet(
      context,
      title: 'Edit ${budget.categoryName ?? 'budget'} limit',
      submitLabel: 'Save limit',
      fields: [
        FieldSpec(
          label: 'Limit (₹)',
          numeric: true,
          required: true,
          initial: budget.amount.toStringAsFixed(0),
        ),
      ],
    );
    if (values == null) return;

    final amount = double.tryParse(values[0].replaceAll(',', ''));
    if (amount == null || amount <= 0) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Enter a limit greater than zero.')),
      );
      return;
    }
    await ref
        .read(budgetListProvider.notifier)
        .updateBudget(budget.copyWith(amount: amount));
  }

  Future<void> _delete(BudgetModel budget) async {
    final notifier = ref.read(budgetListProvider.notifier);
    await notifier.deleteBudget(budget.id);
    if (!mounted) return;
    UndoSnackbar.show(
      context,
      message: 'Budget deleted',
      onUndo: () => notifier.createBudget(budget),
    );
  }

  void _showBudgetDetail(BudgetModel budget) {
    final dateFormat = DateFormat('d MMM');

    AppBottomSheet.show<void>(
      context,
      title: '${budget.categoryName ?? 'Category'} budget',
      builder: (ctx) {
        final p = ctx.palette;
        final noun = _periodNoun[budget.period] ?? 'period';
        final percent = (budget.usedRatio * 100).round();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppCard(
              shadow: false,
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    budget.overAmount > 0
                        ? 'Over by ${CurrencyFormatter.format(budget.overAmount)}'
                        : CurrencyFormatter.format(budget.remainingAmount),
                    style: AppText.display(
                      budget.overAmount > 0 ? p.expense : p.ink,
                    ).copyWith(fontSize: 30),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    budget.overAmount > 0
                        ? 'spent ${CurrencyFormatter.format(budget.spentAmount)} of ${CurrencyFormatter.format(budget.amount)} this $noun'
                        : 'left of ${CurrencyFormatter.format(budget.amount)} this $noun',
                    style: AppText.caption(p.muted),
                  ),
                  const SizedBox(height: 14),
                  AnimatedProgressBar(
                    value: budget.percentage,
                    color: budgetProgressColor(p, budget.usedRatio),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${dateFormat.format(budget.startDate)} – ${dateFormat.format(budget.endDate)} · $percent% used',
                    style: AppText.caption(p.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Text('ALERTS', style: AppText.section(p.muted)),
            const SizedBox(height: 8),
            SettingsGroup(
              children: [
                for (final threshold in const [75, 90, 100])
                  ListRowTile(
                    leading: Text(
                      percent >= threshold ? '✅' : '⏳',
                      style: const TextStyle(fontSize: 18),
                    ),
                    title: '$threshold% reached',
                    subtitle: percent >= threshold
                        ? 'Notified once this $noun'
                        : 'You will be notified when you get there',
                  ),
              ],
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                _editLimit(budget);
              },
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: const Text('Edit limit'),
              style: OutlinedButton.styleFrom(
                foregroundColor: p.ink,
                side: BorderSide(color: p.border),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                _delete(budget);
              },
              style: TextButton.styleFrom(foregroundColor: p.expense),
              child: const Text('Delete budget'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final budgetsAsync = ref.watch(budgetListProvider);
    final all = budgetsAsync.value ?? const <BudgetModel>[];
    final noun = _periodNoun[_period] ?? 'month';

    return Scaffold(
      backgroundColor: p.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: p.primary,
          onRefresh: () => ref.read(budgetListProvider.notifier).loadBudgets(),
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              18,
              16,
              18,
              MediaQuery.of(context).padding.bottom + 130,
            ),
            children: [
              FadeSlideIn(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Budgets', style: AppText.display(p.ink)),
                    Pressable(
                      onTap: () => _createBudget(all),
                      child: Semantics(
                        button: true,
                        label: 'Create budget',
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: p.surface,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [p.cardShadow],
                            border: Border.all(color: p.border),
                          ),
                          child: Icon(Icons.add, size: 22, color: p.ink),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FadeSlideIn(
                index: 1,
                child: SegmentedTabs(
                  options: const ['Weekly', 'Monthly', 'Yearly'],
                  selected: _period[0].toUpperCase() + _period.substring(1),
                  onSelected: (label) =>
                      setState(() => _period = label.toLowerCase()),
                ),
              ),
              const SizedBox(height: 16),
              FadeSlideIn(
                index: 2,
                child: AsyncSection<List<BudgetModel>>(
                  value: budgetsAsync,
                  skeletonHeight: 150,
                  errorLabel: 'Could not load budgets',
                  onRetry: () =>
                      ref.read(budgetListProvider.notifier).loadBudgets(),
                  builder: (budgets) {
                    final list =
                        budgets.where((b) => b.period == _period).toList();
                    return _buildContent(p, list, budgets, noun);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(
    AppPalette p,
    List<BudgetModel> list,
    List<BudgetModel> all,
    String noun,
  ) {
    if (list.isEmpty) {
      return EmptyState(
        compact: true,
        emoji: '🎯',
        title: 'No $_period budgets',
        message:
            'Set a limit for a category and get a nudge as you approach it.',
        actionLabel: 'Create budget',
        onAction: () => _createBudget(all),
      );
    }

    final totalSpent = list.fold<double>(0.0, (s, b) => s + b.spentAmount);
    final totalLimit = list.fold<double>(0.0, (s, b) => s + b.amount);
    final totalLeft = math.max(0.0, totalLimit - totalSpent);
    final ratio = totalLimit > 0 ? totalSpent / totalLimit : 0.0;
    final over = totalSpent > totalLimit;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppCard(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
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
                        color: p.surface2,
                      ),
                    ),
                    TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: ratio.clamp(0.0, 1.0)),
                      duration: AppMotion.slow,
                      curve: AppMotion.enter,
                      builder: (context, v, _) => SizedBox(
                        width: 90,
                        height: 90,
                        child: CircularProgressIndicator(
                          value: v,
                          strokeWidth: 10,
                          strokeCap: StrokeCap.round,
                          color: budgetProgressColor(p, ratio),
                        ),
                      ),
                    ),
                    Text(
                      '${(ratio * 100).round()}%',
                      style: AppText.title(p.ink),
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
                      over ? 'Over this $noun by' : 'Left this $noun',
                      style: AppText.caption(p.muted),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      CurrencyFormatter.format(
                        over ? totalSpent - totalLimit : totalLeft,
                      ),
                      style: AppText.display(over ? p.expense : p.ink),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'of ${CurrencyFormatter.format(totalLimit)} budgeted',
                      style: AppText.caption(p.muted),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const SectionHeader(title: 'Categories'),
        SettingsGroup(
          children: [
            for (final b in list)
              BudgetRow(budget: b, onTap: () => _showBudgetDetail(b)),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'You get a notification at 75%, 90% and 100% of each limit, once per $noun.',
          style: AppText.caption(p.muted),
        ),
      ],
    );
  }
}
