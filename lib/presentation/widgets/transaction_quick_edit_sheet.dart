import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_haptics.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/amount_input.dart';
import '../../data/models/category_model.dart';
import '../../data/models/transaction_model.dart';
import '../providers/category_providers.dart';
import '../providers/transaction_providers.dart';
import 'app_dropdown.dart';
import 'app_sheets.dart';

/// Opens a lightweight sheet to change a transaction's category and amount,
/// then persists via [TransactionListNotifier.updateTransaction].
///
/// Used by the Transactions history list's swipe-right action. Note that
/// [TransactionModel.copyWith] cannot null `categoryId`, so quick-edit only
/// sets a non-null category.
Future<void> showTransactionQuickEditSheet(
  BuildContext context,
  WidgetRef ref,
  TransactionModel tx,
) {
  return AppBottomSheet.show<void>(
    context,
    title: 'Quick edit',
    builder: (_) => _QuickEditForm(tx: tx, ref: ref),
  );
}

class _QuickEditForm extends StatefulWidget {
  final TransactionModel tx;
  final WidgetRef ref;

  const _QuickEditForm({required this.tx, required this.ref});

  @override
  State<_QuickEditForm> createState() => _QuickEditFormState();
}

class _QuickEditFormState extends State<_QuickEditForm> {
  late final TextEditingController _amountController;
  CategoryModel? _category;
  String? _amountErrorText;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.tx.amount.toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  void _save() {
    final err = AmountInput.validateAmount(
      _amountController.text,
      allowZero: false,
    );
    if (err != null) {
      setState(() => _amountErrorText = err);
      return;
    }
    final amount = AmountInput.parseAmount(_amountController.text)!;
    final picked = _category;
    final updated = widget.tx.copyWith(
      categoryId: picked?.id,
      categoryName: picked?.name,
      amount: amount,
    );
    widget.ref
        .read(transactionListProvider.notifier)
        .updateTransaction(updated);
    AppHaptics.success();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final categoriesAsync = widget.tx.isIncome
        ? widget.ref.watch(incomeCategoriesProvider)
        : widget.ref.watch(expenseCategoriesProvider);
    final categories = categoriesAsync.value ?? const <CategoryModel>[];

    // Preselect the transaction's current category once the list is available.
    _category ??= categories.cast<CategoryModel?>().firstWhere(
      (c) => c?.id == widget.tx.categoryId,
      orElse: () => null,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Category', style: AppText.caption(p.muted)),
        const SizedBox(height: 8),
        AppDropdown<CategoryModel>(
          hint: 'Select category',
          sheetTitle: 'Choose category',
          value: _category,
          items: categories,
          labelOf: (c) => c.name,
          emojiOf: (c) => c.icon,
          keyOf: (c) => c.id,
          onChanged: (c) => setState(() => _category = c),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _amountController,
          autofocus: false,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: AmountInput.amountFormatters(),
          textInputAction: TextInputAction.done,
          // Live validation on every keystroke.
          onChanged: (val) => setState(
            () => _amountErrorText = AmountInput.validateAmount(
              val,
              allowZero: false,
            ),
          ),
          onSubmitted: (_) => _save(),
          decoration: InputDecoration(
            labelText: 'Amount (₹)',
            errorText: _amountErrorText,
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
