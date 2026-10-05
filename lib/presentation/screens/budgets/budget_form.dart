import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text.dart';
import '../../../data/models/budget_model.dart';
import '../../../data/models/category_model.dart';
import '../../../data/repositories/budget_repository.dart';

/// Create-budget form (shown in a bottom sheet). Resolves to the new
/// [BudgetModel], or null if dismissed.
///
/// Fixes over the old dialog: the period now actually controls the date range
/// (it always used the current calendar month), invalid input shows a message
/// instead of silently doing nothing, duplicate category/period budgets are
/// blocked, and the amount controller is disposed.
class BudgetForm extends StatefulWidget {
  final List<CategoryModel> categories;
  final List<BudgetModel> existing;
  final String initialPeriod;

  const BudgetForm({
    super.key,
    required this.categories,
    required this.existing,
    this.initialPeriod = 'monthly',
  });

  @override
  State<BudgetForm> createState() => _BudgetFormState();
}

class _BudgetFormState extends State<BudgetForm> {
  final TextEditingController _amount = TextEditingController();
  final Uuid _uuid = const Uuid();
  late String _period = widget.initialPeriod;
  late CategoryModel _category = _firstFreeCategory();
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  bool _hasBudget(CategoryModel c, String period) => widget.existing.any(
        (b) => b.categoryId == c.id && b.period == period,
      );

  /// Prefer a category that does not have a budget yet for this period.
  CategoryModel _firstFreeCategory() {
    for (final c in widget.categories) {
      if (!_hasBudget(c, _period)) return c;
    }
    return widget.categories.first;
  }

  void _submit() {
    final amount = double.tryParse(_amount.text.trim().replaceAll(',', '')) ?? 0;
    if (amount <= 0) {
      setState(() => _error = 'Enter a limit greater than zero.');
      return;
    }
    if (_hasBudget(_category, _period)) {
      setState(
        () => _error = 'You already have a $_period budget for ${_category.name}.',
      );
      return;
    }

    final now = DateTime.now();
    final window = BudgetRepository.currentWindow(_period, now, now, now: now);
    Navigator.pop(
      context,
      BudgetModel(
        id: _uuid.v4(),
        categoryId: _category.id,
        period: _period,
        amount: amount,
        startDate: window.start,
        endDate: window.end,
        createdAt: now,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Repeats', style: AppText.section(p.muted)),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          showSelectedIcon: false,
          segments: const [
            ButtonSegment(value: 'weekly', label: Text('Weekly')),
            ButtonSegment(value: 'monthly', label: Text('Monthly')),
            ButtonSegment(value: 'yearly', label: Text('Yearly')),
          ],
          selected: {_period},
          onSelectionChanged: (s) => setState(() {
            _period = s.first;
            _error = null;
          }),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<CategoryModel>(
          initialValue: _category,
          decoration: const InputDecoration(labelText: 'Category'),
          items: [
            for (final c in widget.categories)
              DropdownMenuItem(value: c, child: Text(c.name)),
          ],
          onChanged: (c) => setState(() {
            _category = c ?? _category;
            _error = null;
          }),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _amount,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) {
            if (_error != null) setState(() => _error = null);
          },
          onSubmitted: (_) => _submit(),
          decoration: const InputDecoration(
            labelText: 'Limit (₹)',
            hintText: 'e.g. 5000',
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: AppText.caption(p.expense)),
        ],
        const SizedBox(height: 16),
        ElevatedButton(onPressed: _submit, child: const Text('Create budget')),
      ],
    );
  }
}
