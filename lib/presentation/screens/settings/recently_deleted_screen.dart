import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/transaction_model.dart';
import '../../providers/transaction_providers.dart';
import '../../widgets/app_sheets.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/fade_slide_in.dart';
import '../../widgets/list_widgets.dart';

class RecentlyDeletedScreen extends ConsumerWidget {
  const RecentlyDeletedScreen({super.key});

  Future<void> _restore(
    BuildContext context,
    WidgetRef ref,
    TransactionModel tx,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(transactionListProvider.notifier).restoreTransaction(tx.id);
    ref.invalidate(recentlyDeletedTransactionsProvider);
    messenger.showSnackBar(const SnackBar(content: Text('Transaction restored')));
  }

  Future<void> _deleteForever(
    BuildContext context,
    WidgetRef ref,
    TransactionModel tx,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await confirmDestructive(
      context,
      title: 'Delete forever?',
      message:
          '"${tx.description}" and its receipts will be permanently removed. This cannot be undone.',
      confirmLabel: 'Delete forever',
    );
    if (!ok) return;
    await ref
        .read(transactionListProvider.notifier)
        .permanentlyDeleteTransaction(tx.id);
    messenger.showSnackBar(const SnackBar(content: Text('Deleted permanently')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final deletedAsync = ref.watch(recentlyDeletedTransactionsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Recently deleted')),
      body: deletedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => EmptyState(
          emoji: '⚠️',
          title: 'Could not load',
          message: '$err',
        ),
        data: (txs) {
          if (txs.isEmpty) {
            return const EmptyState(
              emoji: '🗑',
              title: 'Nothing deleted',
              message:
                  'Transactions you delete show up here so you can restore them.',
            );
          }
          return ListView(
            padding: EdgeInsets.fromLTRB(
              18,
              8,
              18,
              MediaQuery.of(context).padding.bottom + 24,
            ),
            children: [
              FadeSlideIn(
                child: SettingsGroup(
                  children: [
                    for (final tx in txs)
                      ListRowTile(
                        emoji: AppColors.getCategoryEmoji(tx.categoryName),
                        title: tx.description,
                        subtitle: CurrencyFormatter.format(tx.amount),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            TextButton(
                              onPressed: () => _restore(context, ref, tx),
                              child: const Text('Restore'),
                            ),
                            IconButton(
                              tooltip: 'Delete forever',
                              icon: Icon(
                                Icons.delete_forever_rounded,
                                color: p.expense,
                              ),
                              onPressed: () => _deleteForever(context, ref, tx),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
