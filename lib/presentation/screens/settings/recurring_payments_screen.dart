import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/recurring_payment_model.dart';
import '../../providers/account_providers.dart';
import '../../providers/category_providers.dart';
import '../../providers/recurring_providers.dart';

class RecurringPaymentsScreen extends ConsumerWidget {
  const RecurringPaymentsScreen({super.key});

  void _showAddDialog(BuildContext context, WidgetRef ref) {
    final nameCtrl = TextEditingController();
    final amtCtrl = TextEditingController();
    String frequency = 'monthly';

    showDialog(
      context: context,
      builder: (ctx) => Consumer(
        builder: (context, ref, _) {
          final categories = ref.watch(expenseCategoriesProvider).value ?? [];
          final accounts = ref.watch(accountListProvider).value ?? [];

          return AlertDialog(
            title: const Text('Add Recurring Rule'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: nameCtrl, decoration: const InputDecoration(labelText: 'Name (e.g., Netflix)')),
                  const SizedBox(height: 8),
                  TextField(controller: amtCtrl, keyboardType: const TextInputType.numberWithOptions(decimal: true), decoration: const InputDecoration(labelText: 'Amount (₹)')),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: frequency,
                    decoration: const InputDecoration(labelText: 'Frequency'),
                    items: const [
                      DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                      DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                      DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
                    ],
                    onChanged: (val) => frequency = val ?? 'monthly',
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () {
                  final name = nameCtrl.text.trim();
                  final amt = double.tryParse(amtCtrl.text.trim()) ?? 0.0;
                  if (name.isEmpty || amt <= 0 || categories.isEmpty || accounts.isEmpty) return;

                  final rule = RecurringPaymentModel(
                    id: const Uuid().v4(),
                    name: name,
                    amount: amt,
                    categoryId: categories.first.id,
                    accountId: accounts.first.id,
                    paymentMethod: 'UPI',
                    frequency: frequency,
                    nextDueDate: DateTime.now().add(const Duration(days: 30)),
                    createdAt: DateTime.now(),
                  );

                  ref.read(recurringListProvider.notifier).createRecurringPayment(rule);
                  Navigator.pop(ctx);
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recurringAsync = ref.watch(recurringListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Recurring Payments'),
      ),
      body: recurringAsync.when(
        data: (list) {
          if (list.isEmpty) return const Center(child: Text('No recurring payments set up.'));
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, index) {
              final r = list[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                child: ListTile(
                  title: Text(r.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Due: ${r.nextDueDate.day}/${r.nextDueDate.month}/${r.nextDueDate.year} (${r.frequency})'),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(CurrencyFormatter.format(r.amount), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.expense)),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, color: Colors.red),
                        onPressed: () {
                          ref.read(recurringListProvider.notifier).deleteRecurringPayment(r.id);
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(context, ref),
        child: const Icon(Icons.add),
      ),
    );
  }
}
