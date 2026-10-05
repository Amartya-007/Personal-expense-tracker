import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/budget_model.dart';
import 'animated_progress_bar.dart';

/// One budget line: category, spent / limit, animated bar and status text.
/// Shared by Home and the Budgets screen (it was duplicated inline in both).
class BudgetRow extends StatelessWidget {
  final BudgetModel budget;
  final VoidCallback? onTap;

  const BudgetRow({super.key, required this.budget, this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final b = budget;
    final percent = (b.usedRatio * 100).round();

    final String status;
    if (b.overAmount > 0) {
      status = 'Over by ${CurrencyFormatter.format(b.overAmount)} · $percent% used';
    } else if (b.usedRatio >= 1.0) {
      status = 'Limit reached · $percent% used';
    } else {
      status = '${CurrencyFormatter.format(b.remainingAmount)} left · $percent% used';
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                color: budgetProgressColor(p, b.usedRatio),
              ),
              const SizedBox(height: 6),
              Text(
                status,
                style: AppText.caption(b.overAmount > 0 ? p.expense : p.muted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
