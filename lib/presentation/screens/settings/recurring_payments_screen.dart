import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/account_model.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/recurring_payment_model.dart';
import '../../providers/account_providers.dart';
import '../../providers/category_providers.dart';
import '../../providers/recurring_providers.dart';
import '../../widgets/app_dropdown.dart';
import '../../widgets/app_sheets.dart';
import '../../widgets/field_decoration.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/segmented_tabs.dart';
import '../../widgets/list_widgets.dart';

class RecurringPaymentsScreen extends ConsumerWidget {
  const RecurringPaymentsScreen({super.key});

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final accounts = ref.read(accountListProvider).value ?? [];
    final categories = await ref.read(expenseCategoriesProvider.future);
    if (!context.mounted) return;

    // Previously the form just did nothing when these were empty.
    if (accounts.isEmpty || categories.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Add an account and an expense category first.'),
        ),
      );
      return;
    }

    final rule = await AppBottomSheet.show<RecurringPaymentModel>(
      context,
      title: 'Add recurring payment',
      builder: (_) => _RecurringForm(accounts: accounts, categories: categories),
    );
    if (rule == null) return;

    await ref.read(recurringListProvider.notifier).createRecurringPayment(rule);
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    RecurringPaymentModel rule,
  ) async {
    final ok = await confirmDestructive(
      context,
      title: 'Delete ${rule.name}?',
      message: 'It will no longer appear on Home.',
    );
    if (!ok) return;
    await ref
        .read(recurringListProvider.notifier)
        .deleteRecurringPayment(rule.id);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final dateFormat = DateFormat('d MMM yyyy');

    return ManagementScaffold<RecurringPaymentModel>(
      title: 'Recurring payments',
      items: ref.watch(recurringListProvider),
      emptyEmoji: '🔁',
      emptyTitle: 'Nothing recurring',
      emptyMessage:
          'Add rent, subscriptions or EMIs and mark them paid from Home when due.',
      addLabel: 'Add payment',
      onAdd: () => _add(context, ref),
      rowBuilder: (context, r) => ListRowTile(
        emoji: '🔁',
        title: r.name,
        subtitle:
            'Due ${dateFormat.format(r.nextDueDate)} · ${_label(r.frequency)}',
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              CurrencyFormatter.format(r.amount),
              style: AppText.bodyStrong(p.expense),
            ),
            IconButton(
              tooltip: 'Delete',
              icon: Icon(Icons.delete_outline_rounded, color: p.expense),
              onPressed: () => _delete(context, ref, r),
            ),
          ],
        ),
      ),
    );
  }

  static String _label(String frequency) {
    if (frequency.isEmpty) return frequency;
    return frequency[0].toUpperCase() + frequency.substring(1);
  }
}

class _RecurringForm extends StatefulWidget {
  final List<AccountModel> accounts;
  final List<CategoryModel> categories;

  const _RecurringForm({required this.accounts, required this.categories});

  @override
  State<_RecurringForm> createState() => _RecurringFormState();
}

class _RecurringFormState extends State<_RecurringForm> {
  final TextEditingController _name = TextEditingController();
  final TextEditingController _amount = TextEditingController();
  String _frequency = 'monthly';
  late String _accountId = widget.accounts.first.id;
  late String _categoryId = widget.categories.first.id;
  late DateTime _firstDue = _defaultDue('monthly');
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  /// First due date one cycle from today. This used to be a flat 30 days for
  /// every frequency, so a weekly rule's first reminder was a month away.
  static DateTime _defaultDue(String frequency) {
    final now = DateTime.now();
    switch (frequency) {
      case 'weekly':
        return now.add(const Duration(days: 7));
      case 'yearly':
        return DateTime(now.year + 1, now.month, now.day);
      case 'monthly':
      default:
        final month = now.month == 12 ? 1 : now.month + 1;
        final year = now.month == 12 ? now.year + 1 : now.year;
        final lastDay = DateTime(year, month + 1, 0).day;
        return DateTime(year, month, now.day > lastDay ? lastDay : now.day);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _firstDue,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) setState(() => _firstDue = picked);
  }

  void _submit() {
    final name = _name.text.trim();
    final amount = double.tryParse(_amount.text.trim()) ?? 0;
    if (name.isEmpty) {
      setState(() => _error = 'Give this payment a name.');
      return;
    }
    if (amount <= 0) {
      setState(() => _error = 'Enter an amount greater than zero.');
      return;
    }

    Navigator.pop(
      context,
      RecurringPaymentModel(
        id: const Uuid().v4(),
        name: name,
        amount: amount,
        categoryId: _categoryId,
        accountId: _accountId,
        paymentMethod: 'UPI',
        frequency: _frequency,
        nextDueDate: _firstDue,
        createdAt: DateTime.now(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _name,
          autofocus: true,
          textInputAction: TextInputAction.next,
          onChanged: (_) => setState(() => _error = null),
          decoration: appFieldDecoration(
            p,
            hint: 'e.g. Netflix, Rent',
          ).copyWith(labelText: 'Name'),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() => _error = null),
          decoration: appFieldDecoration(p).copyWith(labelText: 'Amount (₹)'),
        ),
        const SizedBox(height: 14),
        Text('Repeats', style: AppText.section(p.muted)),
        const SizedBox(height: 8),
        SegmentedTabs(
          options: const ['Weekly', 'Monthly', 'Yearly'],
          selected: _frequency[0].toUpperCase() + _frequency.substring(1),
          onSelected: (label) => setState(() {
            _frequency = label.toLowerCase();
            _firstDue = _defaultDue(_frequency);
          }),
        ),
        const SizedBox(height: 14),
        AppDropdown<AccountModel>(
          label: 'Pay from',
          value: widget.accounts.firstWhere((a) => a.id == _accountId),
          items: widget.accounts,
          keyOf: (a) => a.id,
          labelOf: (a) => a.name,
          subtitleOf: (a) => CurrencyFormatter.format(a.currentBalance),
          emojiOf: (a) => a.isPrimary ? '⭐' : '🏦',
          onChanged: (a) => setState(() => _accountId = a.id),
        ),
        const SizedBox(height: 12),
        AppDropdown<CategoryModel>(
          label: 'Category',
          value: widget.categories.firstWhere((c) => c.id == _categoryId),
          items: widget.categories,
          keyOf: (c) => c.id,
          labelOf: (c) => c.name,
          emojiOf: (c) => AppColors.getCategoryEmoji(c.name),
          onChanged: (c) => setState(() => _categoryId = c.id),
        ),
        const SizedBox(height: 12),
        InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _pickDate,
          child: InputDecorator(
            isEmpty: false,
            decoration: appFieldDecoration(p).copyWith(
              labelText: 'First due',
              suffixIcon: Icon(Icons.event_rounded, color: p.muted),
            ),
            child: Text(
              DateFormat('d MMM yyyy').format(_firstDue),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: p.ink,
              ),
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: AppText.caption(p.expense)),
        ],
        const SizedBox(height: 16),
        PrimaryButton(label: 'Add payment', onPressed: _submit),
      ],
    );
  }
}
