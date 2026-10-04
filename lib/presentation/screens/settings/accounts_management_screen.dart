import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/account_model.dart';
import '../../providers/account_providers.dart';

class AccountsManagementScreen extends ConsumerWidget {
  const AccountsManagementScreen({super.key});

  void _showAddAccountDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final balCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Bank Account'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameCtrl,
              decoration: const InputDecoration(labelText: 'Account Name (e.g., HDFC)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: balCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Initial Balance (₹)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              final name = nameCtrl.text.trim();
              final bal = double.tryParse(balCtrl.text.trim()) ?? 0.0;
              if (name.isEmpty) return;

              final acc = AccountModel(
                id: const Uuid().v4(),
                name: name,
                currentBalance: bal,
                initialBalance: bal,
                createdAt: DateTime.now(),
                updatedAt: DateTime.now(),
              );

              ref.read(accountListProvider.notifier).createAccount(acc);
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accountsAsync = ref.watch(accountListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bank Accounts'),
      ),
      body: accountsAsync.when(
        data: (accounts) {
          if (accounts.isEmpty) {
            return const Center(child: Text('No active bank accounts.'));
          }
          return ListView.builder(
            itemCount: accounts.length,
            itemBuilder: (context, index) {
              final acc = accounts[index];
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.account_balance)),
                title: Text(acc.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('Balance: ${CurrencyFormatter.format(acc.currentBalance)}'),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline, color: AppColors.expense),
                  onPressed: () {
                    ref.read(accountListProvider.notifier).deleteAccount(acc.id);
                  },
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddAccountDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }
}
