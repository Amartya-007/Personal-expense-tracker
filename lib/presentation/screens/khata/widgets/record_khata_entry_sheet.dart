import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_haptics.dart';
import '../../../../core/theme/app_palette.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../data/models/account_model.dart';
import '../../../../data/models/khata_entry_model.dart';
import '../../../../data/models/khata_person_model.dart';
import '../../../providers/account_providers.dart';
import '../../../providers/khata_providers.dart';
import '../../../widgets/app_sheets.dart';
import '../../../widgets/field_decoration.dart';
import '../../../widgets/primary_button.dart';

class RecordKhataEntrySheet extends ConsumerStatefulWidget {
  final KhataPersonModel person;
  final KhataEntryType initialType;

  const RecordKhataEntrySheet({
    super.key,
    required this.person,
    this.initialType = KhataEntryType.lent,
  });

  static Future<bool?> show(
    BuildContext context, {
    required KhataPersonModel person,
    KhataEntryType initialType = KhataEntryType.lent,
  }) {
    return AppBottomSheet.show<bool?>(
      context,
      title: 'Record with ${person.name}',
      builder: (_) => RecordKhataEntrySheet(
        person: person,
        initialType: initialType,
      ),
    );
  }

  @override
  ConsumerState<RecordKhataEntrySheet> createState() =>
      _RecordKhataEntrySheetState();
}

class _RecordKhataEntrySheetState extends ConsumerState<RecordKhataEntrySheet> {
  final _formKey = GlobalKey<FormState>();
  late KhataEntryType _selectedType;
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;
  DateTime _selectedDate = DateTime.now();
  DateTime? _selectedDueDate;
  String? _selectedAccountId;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _selectedType = widget.initialType;
    _amountController = TextEditingController();
    _notesController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isDueDate) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: isDueDate ? (_selectedDueDate ?? DateTime.now().add(const Duration(days: 7))) : _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() {
        if (isDueDate) {
          _selectedDueDate = picked;
        } else {
          _selectedDate = picked;
        }
      });
    }
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
          .addEntry(
            personId: widget.person.id,
            type: _selectedType,
            amount: amt,
            date: _selectedDate,
            dueDate: _selectedDueDate,
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
            const SnackBar(content: Text('Failed to record Khata entry')),
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
    final accounts = ref.watch(accountListProvider).value ?? <AccountModel>[];

    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Type Segment Selector
            Container(
              decoration: BoxDecoration(
                color: p.surface2,
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(4),
              child: Row(
                children: [
                  _TypeTab(
                    label: 'You Lent',
                    isSelected: _selectedType == KhataEntryType.lent,
                    color: p.primary,
                    onTap: () => setState(() => _selectedType = KhataEntryType.lent),
                  ),
                  _TypeTab(
                    label: 'You Borrowed',
                    isSelected: _selectedType == KhataEntryType.borrowed,
                    color: p.expense,
                    onTap: () => setState(() => _selectedType = KhataEntryType.borrowed),
                  ),
                  _TypeTab(
                    label: 'Got Repaid',
                    isSelected: _selectedType == KhataEntryType.repaymentReceived,
                    color: p.primary,
                    onTap: () => setState(() => _selectedType = KhataEntryType.repaymentReceived),
                  ),
                  _TypeTab(
                    label: 'Repaid Them',
                    isSelected: _selectedType == KhataEntryType.repaymentMade,
                    color: p.expense,
                    onTap: () => setState(() => _selectedType = KhataEntryType.repaymentMade),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Amount Field
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
              ],
              style: AppText.display(p.ink).copyWith(fontSize: 28),
              decoration: appFieldDecoration(p, hint: '0.00').copyWith(
                labelText: 'Amount (₹) *',
                prefixIcon: const Icon(Icons.currency_rupee_rounded),
              ),
              validator: (val) {
                if (val == null || val.trim().isEmpty) {
                  return 'Please enter an amount';
                }
                final parsed = double.tryParse(val.trim());
                if (parsed == null || parsed <= 0) {
                  return 'Amount must be greater than zero';
                }
                return null;
              },
            ),
            const SizedBox(height: AppSpacing.md),

            // Date & Due Date Row
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _pickDate(false),
                    borderRadius: BorderRadius.circular(16),
                    child: InputDecorator(
                      decoration: appFieldDecoration(p).copyWith(
                        labelText: 'Date',
                        prefixIcon: const Icon(Icons.calendar_today_rounded, size: 20),
                      ),
                      child: Text(
                        DateFormat('dd MMM yyyy').format(_selectedDate),
                        style: AppText.body(p.ink),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: InkWell(
                    onTap: () => _pickDate(true),
                    borderRadius: BorderRadius.circular(16),
                    child: InputDecorator(
                      decoration: appFieldDecoration(p).copyWith(
                        labelText: 'Due Date',
                        prefixIcon: const Icon(Icons.event_available_rounded, size: 20),
                      ),
                      child: Text(
                        _selectedDueDate != null
                            ? DateFormat('dd MMM yyyy').format(_selectedDueDate!)
                            : 'None',
                        style: AppText.body(_selectedDueDate != null ? p.ink : p.muted),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),

            // Optional Account Selector
            DropdownButtonFormField<String?>(
              initialValue: _selectedAccountId,
              decoration: appFieldDecoration(p).copyWith(
                labelText: 'Adjust Account Balance (Optional)',
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

            // Notes Field
            TextFormField(
              controller: _notesController,
              style: AppText.body(p.ink),
              decoration: appFieldDecoration(p, hint: 'e.g., Dinner bill split, Emergency cash').copyWith(
                labelText: 'Note / Reason (Optional)',
                prefixIcon: const Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            PrimaryButton(
              label: 'Save Entry',
              loading: _isSubmitting,
              icon: Icons.check_circle_outline_rounded,
              onPressed: _handleSubmit,
            ),
          ],
        ),
      ),
    );
  }
}

class _TypeTab extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Color color;
  final VoidCallback onTap;

  const _TypeTab({
    required this.label,
    required this.isSelected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          AppHaptics.select();
          onTap();
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? p.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppText.caption(isSelected ? color : p.muted).copyWith(
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              fontSize: 11,
            ),
          ),
        ),
      ),
    );
  }
}
