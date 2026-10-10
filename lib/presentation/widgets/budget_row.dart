import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/budget_model.dart';
import '../providers/settings_providers.dart';
import 'animated_progress_bar.dart';

/// One budget line: category, spent / limit, animated bar and status text.
/// Consumes [privacyModeProvider] to mask amounts when enabled.
class BudgetRow extends ConsumerWidget {
  final BudgetModel budget;
  final VoidCallback? onTap;

  const BudgetRow({super.key, required this.budget, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final isMasked = ref.watch(privacyModeProvider);
    final b = budget;
    final percent = (b.usedRatio * 100).round();

    final remainingDays = (b.endDate.difference(DateTime.now()).inDays + 1).clamp(1, 365);
    final dailyAllowance = b.remainingAmount > 0 ? b.remainingAmount / remainingDays : 0.0;

    final String status;
    final Color badgeColor;
    final String badgeLabel;

    if (b.overAmount > 0) {
      status = 'Over by ${CurrencyFormatter.format(b.overAmount, isMasked: isMasked)} · $percent% used';
      badgeColor = p.expense;
      badgeLabel = 'Exceeded';
    } else if (b.usedRatio >= 1.0) {
      status = 'Limit reached · $percent% used';
      badgeColor = p.expense;
      badgeLabel = '100%';
    } else {
      status = '${CurrencyFormatter.format(dailyAllowance, showDecimals: false, isMasked: isMasked)}/day left ($remainingDays days left)';
      badgeColor = b.usedRatio >= 0.75 ? p.secondary : p.income;
      badgeLabel = '$percent%';
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
                children: [
                  Expanded(
                    child: Row(
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
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            badgeLabel,
                            style: AppText.caption(badgeColor).copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${CurrencyFormatter.format(b.spentAmount, isMasked: isMasked)} / ${CurrencyFormatter.format(b.amount, isMasked: isMasked)}',
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
