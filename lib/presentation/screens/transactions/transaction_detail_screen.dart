import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/transaction_model.dart';
import '../../providers/transaction_providers.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_sheets.dart';
import '../../widgets/fade_slide_in.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/receipt_viewer.dart';
import '../../widgets/section_header.dart';
import '../../widgets/undo_snackbar.dart';
import '../add_transaction/add_transaction_screen.dart';

class TransactionDetailScreen extends ConsumerWidget {
  final String transactionId;

  const TransactionDetailScreen({super.key, required this.transactionId});

  Future<void> _edit(BuildContext context, TransactionModel tx) {
    // push (not replace) so saving returns to this page, which reloads and
    // shows the change.
    return AppRoutes.push(
      context,
      AddTransactionScreen(initialType: tx.type, editTransaction: tx),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final ok = await confirmDestructive(
      context,
      title: 'Delete transaction?',
      message: 'It moves to Recently Deleted, where you can restore it.',
    );
    if (!ok || !context.mounted) return;

    final notifier = ref.read(transactionListProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    try {
      await notifier.softDeleteTransaction(transactionId);
    } catch (e) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not delete that transaction.')),
      );
      return;
    }
    if (!context.mounted) return;
    navigator.pop();
    UndoSnackbar.show(
      context,
      message: 'Transaction deleted',
      onUndo: () => notifier.restoreTransaction(transactionId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(title: Text('Details', style: AppText.title(p.ink))),
      body: ref
          .watch(transactionDetailProvider(transactionId))
          .when(
            skipLoadingOnReload: true,
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Text(
                'Could not load this transaction.',
                style: AppText.body(p.muted),
              ),
            ),
            data: (tx) {
              if (tx == null) {
                return Center(
                  child: Text(
                    'Transaction not found.',
                    style: AppText.body(p.muted),
                  ),
                );
              }
              return _DetailBody(
                tx: tx,
                onEdit: () => _edit(context, tx),
                onDelete: () => _delete(context, ref),
              );
            },
          ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  final TransactionModel tx;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _DetailBody({
    required this.tx,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final bottom = MediaQuery.of(context).padding.bottom;
    final isTransfer = tx.isTransfer;
    final categoryName =
        tx.categoryName ??
        (isTransfer ? 'Transfer' : (tx.isIncome ? 'Income' : 'General'));
    final prefix = tx.isIncome ? '+' : (isTransfer ? '' : '−');
    final typeLabel = tx.isIncome
        ? 'Income'
        : (isTransfer ? 'Transfer' : 'Expense');
    final amountColor = isTransfer
        ? p.ink
        : p.amount(isIncome: tx.isIncome, isExpense: tx.isExpense);
    final hasLocation = tx.locationName != null || tx.latitude != null;
    final fromSms = tx.smsMessageId != null || tx.source == 'sms';

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(18, 8, 18, bottom + 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeSlideIn(
            child: Center(
              child: Column(
                children: [
                  Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      color: p.surface2,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      AppColors.getCategoryEmoji(categoryName),
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                  const SizedBox(height: 10),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '$prefix${CurrencyFormatter.format(tx.amount)}',
                      style: AppText.display(amountColor).copyWith(fontSize: 36),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    tx.description,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.title(p.ink),
                  ),
                  const SizedBox(height: 8),
                  _Pill(label: typeLabel, color: amountColor),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          FadeSlideIn(
            index: 1,
            child: AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Column(
                children: [
                  _InfoRow(label: 'Category', value: categoryName),
                  _InfoRow(label: 'Payment method', value: tx.paymentMethod),
                  _InfoRow(
                    label: isTransfer ? 'From account' : 'Account',
                    value: tx.accountName ?? tx.accountId,
                  ),
                  if (isTransfer && tx.destinationAccountName != null)
                    _InfoRow(
                      label: 'To account',
                      value: tx.destinationAccountName!,
                    ),
                  _InfoRow(
                    label: 'Date',
                    value: DateFormat('d MMM yyyy').format(tx.date),
                  ),
                  _InfoRow(
                    label: 'Source',
                    value: fromSms ? 'Detected from SMS' : 'Added manually',
                  ),
                  if (tx.note != null && tx.note!.isNotEmpty)
                    _InfoRow(label: 'Note', value: tx.note!),
                  _InfoRow(
                    label: 'Created',
                    value: DateFormat('d MMM, h:mm a').format(tx.createdAt),
                    isLast: true,
                  ),
                ],
              ),
            ),
          ),
          if (tx.tags.isNotEmpty) ...[
            const SizedBox(height: 22),
            const SectionHeader(title: 'Tags'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in tx.tags)
                  _Pill(label: '#${tag.name}', color: p.primary),
              ],
            ),
          ],
          if (hasLocation) ...[
            const SizedBox(height: 22),
            const SectionHeader(title: 'Location'),
            AppCard(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Text('📍', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      tx.locationName ??
                          '${tx.latitude!.toStringAsFixed(4)}, ${tx.longitude!.toStringAsFixed(4)}',
                      style: AppText.body(p.ink),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (tx.receipts.isNotEmpty) ...[
            const SizedBox(height: 22),
            const SectionHeader(title: 'Receipts'),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final receipt in tx.receipts)
                  GestureDetector(
                    onTap: () => AppRoutes.push(
                      context,
                      ReceiptViewer(receipt: receipt),
                    ),
                    child: Hero(
                      tag: 'receipt-${receipt.id}',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Image.file(
                          File(receipt.filePath),
                          width: 76,
                          height: 76,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            width: 76,
                            height: 76,
                            color: p.surface2,
                            child: Icon(
                              Icons.broken_image_outlined,
                              color: p.muted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 28),
          PrimaryButton(
            label: 'Edit',
            icon: Icons.edit_rounded,
            onPressed: onEdit,
          ),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: TextButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded),
              label: Text('Delete', style: AppText.button(p.expense)),
              style: TextButton.styleFrom(
                foregroundColor: p.expense,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLast;

  const _InfoRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: p.border)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: AppText.caption(p.muted)),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: AppText.bodyStrong(p.ink),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;

  const _Pill({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppText.caption(color).copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}
