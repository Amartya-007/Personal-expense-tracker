import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_haptics.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/utils/currency_formatter.dart';
import '../../../../data/models/account_model.dart';
import '../../../../data/models/khata_person_model.dart';
import '../../../providers/account_providers.dart';
import '../../../providers/khata_providers.dart';
import '../../../widgets/app_sheets.dart';
import '../../../widgets/field_decoration.dart';
import '../../../widgets/primary_button.dart';

class SettleUpSheet extends ConsumerStatefulWidget {
  final KhataPersonModel person;

  const SettleUpSheet({super.key, required this.person});

  static Future<bool?> show(
    BuildContext context, {
    required KhataPersonModel person,
  }) {
    return AppBottomSheet.show<bool?>(
      context,
      title: 'Settle Balance with ${person.name}',
      builder: (_) => SettleUpSheet(person: person),
    );
  }

  @override
  ConsumerState<SettleUpSheet> createState() => _SettleUpSheetState();
}

class _SettleUpSheetState extends ConsumerState<SettleUpSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;
  String? _selectedAccountId;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
      text: widget.person.absoluteBalance.toStringAsFixed(2),
    );
    _notesController = TextEditingController(
      text: 'Settlement with ${widget.person.name}',
    );
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _setAmount(double amt) {
    AppHaptics.select();
    _amountController.text = amt.toStringAsFixed(2);
  }

  Future<void> _handleSubmit() async {
    if (_isSubmitting) return;
    if (!_formKey.currentState!.validate()) {
      AppHaptics.warning();
      return;
    }

    final amt = double.tryParse(_amountController.text.trim());
    if (amt == null || amt <= 0) {
      AppHaptics.warning();
      return;
    }

    setState(() => _isSubmitting = true);
    AppHaptics.tap();

    try {
      final success = await ref
          .read(khataControllerProvider.notifier)
          .settlePerson(
            widget.person.id,
            amount: amt,
            accountId: _selectedAccountId,
            notes: _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
          );

      if (mounted) {
        if (success) {
          Navigator.of(context).pop(true);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to process settlement')),
          );
        }
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final person = widget.person;
    final accounts = ref.watch(accountListProvider).value ?? <AccountModel>[];

    final isReceivable = person.isReceivable;
    final totalDue = person.absoluteBalance;

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: (isReceivable ? p.primary : p.expense).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: (isReceivable ? p.primary : p.expense).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    isReceivable ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
                    color: isReceivable ? p.primary : p.expense,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      isReceivable
                          ? '${person.name} owes you ${CurrencyFormatter.format(totalDue)}'
                          : 'You owe ${person.name} ${CurrencyFormatter.format(totalDue)}',
                      style: AppText.body(p.ink).copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Amount field
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              style: AppText.display(p.ink).copyWith(fontSize: 28),
              decoration: appFieldDecoration(p, hint: '0.00').copyWith(
                labelText: 'Settlement Amount (₹) *',
                prefixIcon: const Icon(Icons.currency_rupee_rounded),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Please enter settlement amount';
                }
                final parsed = double.tryParse(val.trim());
                if (parsed == null || parsed <= 0) {
                  return 'Amount must be greater than zero';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.sm),

            // Quick settlement chips (Full vs Half)
            Wrap(
              spacing: 8,
              children: [
                ActionChip(
                  label: Text('Full (${CurrencyFormatter.format(totalDue)})'),
                  onPressed: () => _setAmount(totalDue),
                ),
                if (totalDue > 1)
                  ActionChip(
                    label: Text('Half (${CurrencyFormatter.format(totalDue / 2)})'),
                    onPressed: () => _setAmount(totalDue / 2),
                  ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Account selection
            DropdownButtonFormField<String?>(
              initialValue: _selectedAccountId,
              decoration: appFieldDecoration(p).copyWith(
                labelText: isReceivable
                    ? 'Deposit Into Account (Optional)'
                    : 'Pay From Account (Optional)',
                prefixIcon: const Icon(Icons.account_balance_wallet_outlined),
                helperText: _selectedAccountId == null
                    ? 'Records ledger only. No cash account affected.'
                    : 'Atomically updates balance without affecting income/expense reports.',
              ),
              dropdownColor: p.surface,
              style: AppText.body(p.ink),
              items: [
                DropdownMenuItem<String?>(
                  value: null,
                  child: Text('None (Ledger only)', style: AppText.body(p.muted)),
                ),
                ...accounts.map(
                  (a) => DropdownMenuItem<String?>(
                    value: a.id,
                    child: Text('${a.name} (₹${a.currentBalance.toStringAsFixed(2)})'),
                  ),
                ),
              ],
              onChanged: (val) => setState(() => _selectedAccountId = val),
            ),
            const SizedBox(height: AppSpacing.md),

            // Notes field
            TextFormField(
              controller: _notesController,
              style: AppText.body(p.ink),
              decoration: appFieldDecoration(p, hint: 'Settlement note').copyWith(
                labelText: 'Settlement Note',
                prefixIcon: const Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            PrimaryButton(
              label: 'Confirm Settlement',
              loading: _isSubmitting,
              icon: Icons.done_all_rounded,
              onPressed: _handleSubmit,
            ),
          ],
        ),
      ),
    );
  }
}
