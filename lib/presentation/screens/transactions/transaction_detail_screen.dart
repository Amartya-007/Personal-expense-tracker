import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/transaction_model.dart';
import '../../providers/transaction_providers.dart';
import '../add_transaction/add_transaction_screen.dart';

class TransactionDetailScreen extends ConsumerWidget {
  final String transactionId;

  const TransactionDetailScreen({
    super.key,
    required this.transactionId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark ? AppColors.darkSurface : AppColors.surface;
    final surface2Color = isDark ? AppColors.darkSurface2 : AppColors.surface2;
    final linesColor = isDark ? AppColors.darkLines : AppColors.lines;
    final inkColor = isDark ? AppColors.darkInk : AppColors.ink;
    final mutedColor = isDark ? AppColors.darkMuted : AppColors.muted;

    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Center(
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Icon(Icons.arrow_back_ios_new, size: 18, color: inkColor),
              ),
            ),
          ),
        ),
        title: Text('Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: inkColor)),
        centerTitle: false,
      ),
      body: ref.watch(transactionDetailProvider(transactionId)).when(
        skipLoadingOnReload: true,
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text('Could not load this transaction.', style: TextStyle(color: mutedColor)),
        ),
        data: (tx) {
          if (tx == null) {
            return Center(
              child: Text('Transaction not found.', style: TextStyle(color: mutedColor)),
            );
          }

          final isIncome = tx.isIncome;
          final isTransfer = tx.isTransfer;
          final categoryName = tx.categoryName ?? (isTransfer ? 'Transfer' : (isIncome ? 'Income' : 'General'));
          final emoji = AppColors.getCategoryEmoji(categoryName);
          final amountColor = isIncome
              ? AppColors.income
              : (isTransfer ? (isDark ? AppColors.darkInk : AppColors.ink) : AppColors.expense);

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Hero Squircle + Amount
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: surface2Color,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Center(
                          child: Text(emoji, style: const TextStyle(fontSize: 30)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${isIncome ? '+' : (isTransfer ? '' : '−')}${CurrencyFormatter.format(tx.amount)}',
                        style: TextStyle(
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                          color: amountColor,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        tx.description,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: inkColor,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Metadata Card
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _buildRow(
                        label: 'Category',
                        value: categoryName,
                        linesColor: linesColor,
                        mutedColor: mutedColor,
                        inkColor: inkColor,
                      ),
                      _buildRow(
                        label: 'Payment method',
                        value: tx.paymentMethod,
                        linesColor: linesColor,
                        mutedColor: mutedColor,
                        inkColor: inkColor,
                      ),
                      _buildRow(
                        label: isTransfer ? 'From Account' : 'Account',
                        value: tx.accountName ?? tx.accountId,
                        linesColor: linesColor,
                        mutedColor: mutedColor,
                        inkColor: inkColor,
                      ),
                      if (isTransfer && tx.destinationAccountName != null)
                        _buildRow(
                          label: 'To Account',
                          value: tx.destinationAccountName!,
                          linesColor: linesColor,
                          mutedColor: mutedColor,
                          inkColor: inkColor,
                        ),
                      _buildRow(
                        label: 'Date',
                        value: '${tx.date.day} ${_getMonthName(tx.date.month)} ${tx.date.year}',
                        linesColor: linesColor,
                        mutedColor: mutedColor,
                        inkColor: inkColor,
                      ),
                      _buildRow(
                        label: 'Source',
                        value: (tx.smsMessageId != null || tx.source == 'sms') ? 'Detected from SMS' : 'Added manually',
                        linesColor: linesColor,
                        mutedColor: mutedColor,
                        inkColor: inkColor,
                      ),
                      if (tx.note != null && tx.note!.isNotEmpty)
                        _buildRow(
                          label: 'Note',
                          value: tx.note!,
                          linesColor: linesColor,
                          mutedColor: mutedColor,
                          inkColor: inkColor,
                        ),
                      _buildRow(
                        label: 'Created',
                        value: '${tx.createdAt.day} ${_getMonthName(tx.createdAt.month)}, ${_formatTime(tx.createdAt)}',
                        linesColor: linesColor,
                        mutedColor: mutedColor,
                        inkColor: inkColor,
                        isLast: true,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Location Header & Map Preview
                Text(
                  'Location',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: inkColor),
                ),
                const SizedBox(height: 10),
                GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          tx.locationName != null
                              ? 'Location: ${tx.locationName}'
                              : (tx.latitude != null
                                  ? 'Coordinates: ${tx.latitude!.toStringAsFixed(4)}, ${tx.longitude!.toStringAsFixed(4)}'
                                  : 'Opening your maps app'),
                        ),
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                    );
                  },
                  child: Container(
                    height: 110,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: surface2Color,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: linesColor),
                    ),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('📍', style: TextStyle(fontSize: 28)),
                          const SizedBox(height: 6),
                          Text(
                            tx.locationName ??
                                (tx.latitude != null
                                    ? '${tx.latitude!.toStringAsFixed(4)}, ${tx.longitude!.toStringAsFixed(4)}'
                                    : 'Saved location'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: mutedColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Receipts (if any)
                if (tx.receipts.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Receipts',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: inkColor),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: tx.receipts.map((r) {
                      return GestureDetector(
                        onTap: () => _showReceiptViewer(context, r.filePath),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(
                            File(r.filePath),
                            width: 68,
                            height: 68,
                            fit: BoxFit.cover,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ],

                const SizedBox(height: 28),

                // Action Buttons: Edit and Delete
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () {
                            // push (not replace) so saving returns to this page,
                            // which reloads and shows the change.
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => AddTransactionScreen(
                                  initialType: tx.type,
                                  editTransaction: tx,
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: surface2Color,
                            foregroundColor: inkColor,
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          ),
                          child: const Text('Edit', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 50,
                        child: TextButton(
                          onPressed: () async {
                            final confirm = await showDialog<bool>(
                              context: context,
                              builder: (ctx) => AlertDialog(
                                title: const Text('Delete Transaction', style: TextStyle(fontWeight: FontWeight.w800)),
                                content: const Text('Move this transaction to Recently Deleted?'),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(ctx, false),
                                    child: Text('Cancel', style: TextStyle(color: mutedColor)),
                                  ),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.expense,
                                      foregroundColor: Colors.white,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    ),
                                    onPressed: () => Navigator.pop(ctx, true),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );

                            if (confirm == true) {
                              await ref.read(transactionListProvider.notifier).softDeleteTransaction(transactionId);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text('Transaction deleted'),
                                    behavior: SnackBarBehavior.floating,
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                    action: SnackBarAction(
                                      label: 'UNDO',
                                      textColor: AppColors.secondary,
                                      onPressed: () {
                                        ref.read(transactionListProvider.notifier).restoreTransaction(transactionId);
                                      },
                                    ),
                                  ),
                                );
                                Navigator.pop(context);
                              }
                            }
                          },
                          style: TextButton.styleFrom(
                            foregroundColor: AppColors.expense,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          ),
                          child: const Text('Delete', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildRow({
    required String label,
    required String value,
    required Color linesColor,
    required Color mutedColor,
    required Color inkColor,
    bool isLast = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: linesColor)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: TextStyle(fontSize: 12.5, color: mutedColor, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: inkColor),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  void _showReceiptViewer(BuildContext context, String path) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                const SizedBox(height: 18),
                ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Image.file(
                    File(path),
                    fit: BoxFit.contain,
                    width: double.infinity,
                    height: 360,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  String _formatTime(DateTime dt) {
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final period = dt.hour >= 12 ? 'pm' : 'am';
    final minute = dt.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }
}
