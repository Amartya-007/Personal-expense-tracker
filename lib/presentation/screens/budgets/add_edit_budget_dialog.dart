import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../data/models/budget_model.dart';
import '../../../data/models/category_model.dart';
import '../../providers/budget_providers.dart';
import '../../providers/category_providers.dart';

class AddEditBudgetDialog extends ConsumerStatefulWidget {
  const AddEditBudgetDialog({super.key});

  @override
  ConsumerState<AddEditBudgetDialog> createState() => _AddEditBudgetDialogState();
}

class _AddEditBudgetDialogState extends ConsumerState<AddEditBudgetDialog> {
  final TextEditingController _amountController = TextEditingController();
  CategoryModel? _selectedCategory;
  String _period = 'monthly';
  final Uuid _uuid = const Uuid();

  @override
  Widget build(BuildContext context) {
    final categoriesAsync = ref.watch(expenseCategoriesProvider);

    return AlertDialog(
      title: const Text('Create Budget'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            categoriesAsync.when(
              data: (cats) {
                if (cats.isEmpty) return const Text('No expense categories.');
                _selectedCategory ??= cats.first;
                return DropdownButtonFormField<CategoryModel>(
                  initialValue: _selectedCategory,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: cats.map((c) => DropdownMenuItem<CategoryModel>(value: c, child: Text(c.name))).toList(),
                  onChanged: (val) => setState(() => _selectedCategory = val),
                );
              },
              loading: () => const CircularProgressIndicator(),
              error: (_, __) => const SizedBox.shrink(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Budget Amount (₹)'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _period,
              decoration: const InputDecoration(labelText: 'Period'),
              items: const [
                DropdownMenuItem(value: 'weekly', child: Text('Weekly')),
                DropdownMenuItem(value: 'monthly', child: Text('Monthly')),
                DropdownMenuItem(value: 'yearly', child: Text('Yearly')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _period = val);
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: () {
            final amt = double.tryParse(_amountController.text.trim()) ?? 0.0;
            if (amt <= 0 || _selectedCategory == null) return;

            final now = DateTime.now();
            final startDate = DateTime(now.year, now.month, 1);
            final endDate = DateTime(now.year, now.month + 1, 0, 23, 59, 59);

            final budget = BudgetModel(
              id: _uuid.v4(),
              categoryId: _selectedCategory!.id,
              period: _period,
              amount: amt,
              startDate: startDate,
              endDate: endDate,
              createdAt: now,
            );

            ref.read(budgetListProvider.notifier).createBudget(budget);
            Navigator.pop(context);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
