import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../providers/transaction_providers.dart';

class RecentlyDeletedScreen extends ConsumerWidget {
  const RecentlyDeletedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deletedAsync = ref.watch(recentlyDeletedTransactionsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recently Deleted'),
      ),
      body: deletedAsync.when(
        data: (txs) {
          if (txs.isEmpty) {
            return const Center(child: Text('No recently deleted transactions.'));
          }
          return ListView.builder(
            itemCount: txs.length,
            itemBuilder: (context, index) {
              final tx = txs[index];
              return ListTile(
                title: Text(tx.description, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(CurrencyFormatter.format(tx.amount)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.restore, color: AppColors.income),
                      tooltip: 'Restore',
                      onPressed: () async {
                        await ref.read(transactionListProvider.notifier).restoreTransaction(tx.id);
                        ref.invalidate(recentlyDeletedTransactionsProvider);
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_forever, color: AppColors.expense),
                      tooltip: 'Permanently Delete',
                      onPressed: () async {
                        final repo = ref.read(transactionRepositoryProvider);
                        await repo.permanentlyDeleteTransaction(tx.id);
                        ref.invalidate(recentlyDeletedTransactionsProvider);
                      },
                    ),
                  ],
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
