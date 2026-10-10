import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants/app_colors.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/transaction_model.dart';
import '../providers/settings_providers.dart';
import 'app_card.dart';

/// One transaction line. Consumes [privacyModeProvider] to mask amounts when enabled.
class TransactionRow extends ConsumerWidget {
  final TransactionModel transaction;
  final VoidCallback? onTap;
  final bool showDivider;

  const TransactionRow({
    super.key,
    required this.transaction,
    this.onTap,
    this.showDivider = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final isMasked = ref.watch(privacyModeProvider);
    final tx = transaction;
    final prefix = tx.isIncome ? '+' : (tx.isExpense ? '−' : '');

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: p.surface2,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      AppColors.getCategoryEmoji(tx.categoryName),
                      style: const TextStyle(fontSize: 19),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                tx.description,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.body(p.ink),
                              ),
                            ),
                            if (tx.receipts.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              const Text('🧾', style: TextStyle(fontSize: 11)),
                            ],
                            if (tx.note != null && tx.note!.isNotEmpty) ...[
                              const SizedBox(width: 4),
                              const Text('📝', style: TextStyle(fontSize: 11)),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${tx.categoryName ?? 'General'} · ${tx.paymentMethod}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.caption(p.muted),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isMasked ? '••••••' : '$prefix${CurrencyFormatter.format(tx.amount)}',
                    style: AppText.amount(
                      p.amount(isIncome: tx.isIncome, isExpense: tx.isExpense),
                      size: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (showDivider) Divider(color: p.border, height: 1),
      ],
    );
  }
}

/// A card of transactions. Pass [onDelete] to enable swipe-to-delete.
class TransactionListCard extends StatelessWidget {
  final List<TransactionModel> transactions;
  final void Function(TransactionModel tx) onTap;
  final void Function(TransactionModel tx)? onDelete;

  const TransactionListCard({
    super.key,
    required this.transactions,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return AppCard(
      child: Column(
        children: [
          for (var i = 0; i < transactions.length; i++)
            _buildRow(p, transactions[i], i == transactions.length - 1),
        ],
      ),
    );
  }

  Widget _buildRow(AppPalette p, TransactionModel tx, bool isLast) {
    final row = TransactionRow(
      transaction: tx,
      showDivider: !isLast,
      onTap: () => onTap(tx),
    );

    if (onDelete == null) return row;

    return Dismissible(
      key: ValueKey(tx.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: p.expense,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 22),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.delete_outline_rounded, color: Colors.white),
            SizedBox(width: 6),
            Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      onDismissed: (_) => onDelete!(tx),
      child: row,
    );
  }
}
