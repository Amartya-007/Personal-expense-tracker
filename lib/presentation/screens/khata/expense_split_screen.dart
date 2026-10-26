import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_haptics.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/expense_group_model.dart';
import '../../../data/models/expense_split_model.dart';
import '../../../data/models/khata_person_model.dart';
import '../../../data/models/split_participant_model.dart';
import '../../../domain/splits/split_calculator.dart';
import '../../providers/account_providers.dart';
import '../../providers/expense_group_providers.dart';
import '../../providers/expense_split_providers.dart';
import '../../widgets/app_card.dart';
import '../../widgets/field_decoration.dart';
import '../../widgets/primary_button.dart';
import 'widgets/person_selector_sheet.dart';

class _ParticipantEntry {
  final String key;
  final String name;
  final String? phone;
  final String? personId;
  final bool isUser;
  bool isIncluded;
  final TextEditingController inputController;

  _ParticipantEntry({
    required this.key,
    required this.name,
    this.phone,
    this.personId,
    this.isUser = false,
    this.isIncluded = true,
    String initialText = '',
  }) : inputController = TextEditingController(text: initialText);

  void dispose() {
    inputController.dispose();
  }
}

class ExpenseSplitScreen extends ConsumerStatefulWidget {
  final ExpenseGroupModel? preselectedGroup;
  final double? initialAmount;
  final String? initialTitle;
  final String? initialTransactionId;

  const ExpenseSplitScreen({
    super.key,
    this.preselectedGroup,
    this.initialAmount,
    this.initialTitle,
    this.initialTransactionId,
  });

  @override
  ConsumerState<ExpenseSplitScreen> createState() => _ExpenseSplitScreenState();
}

class _ExpenseSplitScreenState extends ConsumerState<ExpenseSplitScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _amountController;
  late final TextEditingController _notesController;

  final DateTime _selectedDate = DateTime.now();
  ExpenseGroupModel? _selectedGroup;
  SplitMode _splitMode = SplitMode.equal;

  // Payer: 'user' or personId
  String _payerKey = 'user';
  bool _payerOwesShare = true;
  bool _recordInKhataLedger = true;
  String? _selectedAccountId;

  final List<_ParticipantEntry> _participants = [];
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.initialTitle ?? '');
    _amountController = TextEditingController(
      text: widget.initialAmount != null && widget.initialAmount! > 0
          ? widget.initialAmount!.toStringAsFixed(2)
          : '',
    );
    _notesController = TextEditingController();
    _selectedGroup = widget.preselectedGroup;

    // Default: User is always an initial participant
    _participants.add(
      _ParticipantEntry(
        key: 'user',
        name: 'You',
        isUser: true,
        isIncluded: true,
        initialText: '1',
      ),
    );

    // If preselected group has members, populate them
    if (widget.preselectedGroup != null) {
      for (final m in widget.preselectedGroup!.members) {
        _participants.add(
          _ParticipantEntry(
            key: m.id,
            name: m.name,
            phone: m.phone,
            personId: m.id,
            isUser: false,
            isIncluded: true,
            initialText: '1',
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    for (final p in _participants) {
      p.dispose();
    }
    super.dispose();
  }

  double get _totalAmount =>
      double.tryParse(_amountController.text.trim()) ?? 0.0;

  List<_ParticipantEntry> get _activeParticipants {
    return _participants.where((p) {
      if (!p.isIncluded) return false;
      if (!_payerOwesShare && p.key == _payerKey) return false;
      return true;
    }).toList();
  }

  SplitCalculationResult _calculateCurrentSplit() {
    final active = _activeParticipants;
    final total = _totalAmount;

    final inputs = active.map((p) {
      final textVal = double.tryParse(p.inputController.text.trim()) ?? 0.0;
      return ParticipantCalculationInput(
        key: p.key,
        name: p.name,
        isUser: p.isUser,
        isPayer: p.key == _payerKey,
        customAmount: _splitMode == SplitMode.custom ? textVal : null,
        percentage: _splitMode == SplitMode.percentage ? textVal : null,
        shares: _splitMode == SplitMode.shares ? textVal : null,
      );
    }).toList();

    switch (_splitMode) {
      case SplitMode.equal:
        return SplitCalculator.calculateEqualSplit(
          totalAmount: total,
          participants: inputs,
        );
      case SplitMode.percentage:
        return SplitCalculator.calculatePercentageSplit(
          totalAmount: total,
          participants: inputs,
        );
      case SplitMode.shares:
        return SplitCalculator.calculateSharesSplit(
          totalAmount: total,
          participants: inputs,
        );
      case SplitMode.custom:
        return SplitCalculator.calculateCustomSplit(
          totalAmount: total,
          participants: inputs,
        );
    }
  }

  void _onSplitModeChanged(SplitMode newMode) {
    AppHaptics.select();
    setState(() {
      _splitMode = newMode;
      final active = _activeParticipants;
      if (active.isEmpty) return;

      if (newMode == SplitMode.percentage) {
        final equalPct = (100.0 / active.length);
        for (final p in _participants) {
          p.inputController.text = equalPct.toStringAsFixed(1);
        }
      } else if (newMode == SplitMode.shares) {
        for (final p in _participants) {
          p.inputController.text = '1';
        }
      } else if (newMode == SplitMode.custom) {
        final split = SplitCalculator.calculateEqualSplit(
          totalAmount: _totalAmount,
          participants: active.map((p) => ParticipantCalculationInput(
            key: p.key,
            name: p.name,
          )).toList(),
        );
        for (final s in split.shares) {
          final found = _participants.firstWhere((p) => p.key == s.key);
          found.inputController.text = s.allocatedAmount.toStringAsFixed(2);
        }
      }
    });
  }

  Future<void> _addPeople() async {
    final existingPeople = _participants
        .where((p) => p.personId != null)
        .map((p) => KhataPersonModel(
              id: p.personId!,
              name: p.name,
              phone: p.phone,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ))
        .toList();

    final selected = await PersonSelectorSheet.show(
      context,
      initialSelected: existingPeople,
      multiSelect: true,
      title: 'Add People to Split',
    );

    if (selected != null && mounted) {
      setState(() {
        for (final p in selected) {
          final exists = _participants.any((x) => x.personId == p.id);
          if (!exists) {
            _participants.add(
              _ParticipantEntry(
                key: p.id,
                name: p.name,
                phone: p.phone,
                personId: p.id,
                isUser: false,
                isIncluded: true,
                initialText: '1',
              ),
            );
          }
        }
      });
    }
  }

  void _onGroupSelected(ExpenseGroupModel? group) {
    AppHaptics.select();
    setState(() {
      _selectedGroup = group;
      if (group != null) {
        for (final m in group.members) {
          final exists = _participants.any((p) => p.personId == m.id);
          if (!exists) {
            _participants.add(
              _ParticipantEntry(
                key: m.id,
                name: m.name,
                phone: m.phone,
                personId: m.id,
                isUser: false,
                isIncluded: true,
                initialText: '1',
              ),
            );
          }
        }
      }
    });
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) {
      AppHaptics.warning();
      return;
    }

    final total = _totalAmount;
    if (total <= 0) {
      AppHaptics.warning();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an amount greater than 0')),
      );
      return;
    }

    final calcResult = _calculateCurrentSplit();
    if (!calcResult.isValid) {
      AppHaptics.warning();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(calcResult.errorMessage ?? 'Please fix split allocation amounts'),
        ),
      );
      return;
    }

    setState(() => _isSaving = true);
    AppHaptics.tap();

    try {
      final title = _titleController.text.trim().isEmpty
          ? 'Split on ${DateFormat('dd MMM').format(_selectedDate)}'
          : _titleController.text.trim();

      final isUserPayer = _payerKey == 'user';
      final payerParticipant = _participants.firstWhere((p) => p.key == _payerKey);

      final splitModel = ExpenseSplitModel(
        id: '',
        title: title,
        totalAmount: total,
        payerType: isUserPayer ? 'user' : 'person',
        payerPersonId: isUserPayer ? null : payerParticipant.personId,
        groupId: _selectedGroup?.id,
        splitMode: _splitMode,
        date: _selectedDate,
        transactionId: widget.initialTransactionId,
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      final participantsList = <SplitParticipantModel>[];
      for (final s in calcResult.shares) {
        final original = _participants.firstWhere((p) => p.key == s.key);
        participantsList.add(
          SplitParticipantModel(
            id: '',
            splitId: '',
            personId: original.personId,
            isPayer: original.key == _payerKey,
            isUser: original.isUser,
            personName: original.name,
            personPhone: original.phone,
            shareValue: s.shareValue,
            allocatedAmount: s.allocatedAmount,
            isSettled: original.key == _payerKey,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
      }

      final created = await ref
          .read(expenseSplitControllerProvider.notifier)
          .createSplit(
            split: splitModel,
            participants: participantsList,
            recordInKhataLedger: _recordInKhataLedger,
            accountId: _selectedAccountId,
          );

      if (mounted && created != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved split: "$title"'),
            behavior: SnackBarBehavior.floating,
          ),
        );
        Navigator.of(context).pop(created);
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _shareSummary(SplitCalculationResult calc) {
    AppHaptics.tap();
    final payerName = _payerKey == 'user'
        ? 'You'
        : _participants.firstWhere((p) => p.key == _payerKey).name;

    final buffer = StringBuffer();
    buffer.writeln('📋 Expense Split: ${_titleController.text.trim().isEmpty ? 'Shared Expense' : _titleController.text.trim()}');
    buffer.writeln('Total: ${CurrencyFormatter.format(_totalAmount)}');
    buffer.writeln('Paid by: $payerName');
    buffer.writeln('Date: ${DateFormat('dd MMM yyyy').format(_selectedDate)}');
    buffer.writeln('\nAllocations:');
    for (final s in calc.shares) {
      buffer.writeln('• ${s.name}: ${CurrencyFormatter.format(s.allocatedAmount)}');
    }

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Split summary copied to clipboard! Ready to share.'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final groupsAsync = ref.watch(expenseGroupListProvider);
    final accountsAsync = ref.watch(accountListProvider);
    final calcResult = _calculateCurrentSplit();

    return Scaffold(
      backgroundColor: p.background,
      appBar: AppBar(
        backgroundColor: p.background,
        elevation: 0,
        title: Text('Split Expense', style: AppText.title(p.ink)),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            tooltip: 'Copy shareable summary',
            onPressed: calcResult.isValid ? () => _shareSummary(calcResult) : null,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            MediaQuery.of(context).padding.bottom + 100,
          ),
          children: [
            // Amount & Title
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Total Expense Amount', style: AppText.caption(p.muted)),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    style: AppText.amount(p.primary, size: 28),
                    decoration: appFieldDecoration(p, hint: '0.00').copyWith(
                      prefixText: '₹ ',
                      prefixStyle: AppText.amount(p.primary, size: 28),
                    ),
                    onChanged: (_) => setState(() {}),
                    validator: (val) {
                      final n = double.tryParse(val ?? '');
                      if (n == null || n <= 0) return 'Enter a valid amount';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _titleController,
                    textCapitalization: TextCapitalization.sentences,
                    style: AppText.body(p.ink),
                    decoration: appFieldDecoration(
                      p,
                      hint: 'Description (e.g. Dinner, Grocery, Airbnb)',
                    ).copyWith(
                      prefixIcon: const Icon(Icons.receipt_long_outlined),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Group & Payer selection
            AppCard(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Group selector
                  Row(
                    children: [
                      Icon(Icons.groups_outlined, size: 20, color: p.primary),
                      const SizedBox(width: 8),
                      Text('Group', style: AppText.bodyStrong(p.ink)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: groupsAsync.when(
                          data: (groups) {
                            return DropdownButton<String?>(
                              value: _selectedGroup?.id,
                              isExpanded: true,
                              isDense: true,
                              alignment: AlignmentDirectional.centerEnd,
                              underline: const SizedBox.shrink(),
                              hint: Align(
                                alignment: Alignment.centerRight,
                                child: Text('No Group (Ad-hoc)',
                                    style: AppText.caption(p.muted),
                                    overflow: TextOverflow.ellipsis),
                              ),
                              items: [
                                DropdownMenuItem<String?>(
                                  value: null,
                                  alignment: AlignmentDirectional.centerEnd,
                                  child: Text('No Group (Ad-hoc)',
                                      style: AppText.body(p.ink),
                                      overflow: TextOverflow.ellipsis),
                                ),
                                ...groups.map((g) => DropdownMenuItem<String?>(
                                      value: g.id,
                                      alignment: AlignmentDirectional.centerEnd,
                                      child: Text(
                                        '${g.icon ?? '👥'} ${g.name}',
                                        style: AppText.body(p.ink),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    )),
                              ],
                              onChanged: (id) {
                                if (id == null) {
                                  _onGroupSelected(null);
                                } else {
                                  final g = groups.firstWhere((x) => x.id == id);
                                  _onGroupSelected(g);
                                }
                              },
                            );
                          },
                          loading: () => const SizedBox.shrink(),
                          error: (_, __) => const SizedBox.shrink(),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // Who Paid selector
                  Row(
                    children: [
                      Icon(Icons.payment_outlined, size: 20, color: p.primary),
                      const SizedBox(width: 8),
                      Text('Who Paid?', style: AppText.bodyStrong(p.ink)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButton<String>(
                          value: _payerKey,
                          isExpanded: true,
                          isDense: true,
                          alignment: AlignmentDirectional.centerEnd,
                          underline: const SizedBox.shrink(),
                          items: _participants.map((part) {
                            return DropdownMenuItem<String>(
                              value: part.key,
                              alignment: AlignmentDirectional.centerEnd,
                              child: Text(
                                part.name,
                                style: AppText.body(p.ink),
                                overflow: TextOverflow.ellipsis,
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _payerKey = val);
                          },
                        ),
                      ),
                    ],
                  ),

                  // Include payer in split toggle
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Payer owes their share',
                      style: AppText.body(p.ink),
                    ),
                    subtitle: Text(
                      _payerOwesShare
                          ? 'Payer is included in the split calculation'
                          : 'Payer paid 100% for others without owing a share',
                      style: AppText.caption(p.muted),
                    ),
                    value: _payerOwesShare,
                    activeColor: p.primary,
                    onChanged: (val) => setState(() => _payerOwesShare = val ?? true),
                  ),

                  // Optional Sync with Khata peer ledger
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Sync with Khata ledger',
                      style: AppText.body(p.ink),
                    ),
                    subtitle: Text(
                      'Records what friends owe in your offline debt ledger',
                      style: AppText.caption(p.muted),
                    ),
                    value: _recordInKhataLedger,
                    activeColor: p.primary,
                    onChanged: (val) =>
                        setState(() => _recordInKhataLedger = val ?? true),
                  ),

                  if (_recordInKhataLedger && _payerKey == 'user')
                    accountsAsync.when(
                      data: (accounts) {
                        return Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: DropdownButtonFormField<String?>(
                            isExpanded: true,
                            initialValue: _selectedAccountId,
                            decoration: appFieldDecoration(
                              p,
                              hint: 'Select account (optional)',
                            ),
                            items: [
                              DropdownMenuItem<String?>(
                                value: null,
                                child: Text(
                                  'No Account (Ledger Only)',
                                  style: AppText.body(p.ink),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              ...accounts.map((a) => DropdownMenuItem<String?>(
                                    value: a.id,
                                    child: Text(
                                      a.name,
                                      style: AppText.body(p.ink),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  )),
                            ],
                            onChanged: (val) =>
                                setState(() => _selectedAccountId = val),
                          ),
                        );
                      },
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => const SizedBox.shrink(),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Split Mode Tabs
            Text('Split Method', style: AppText.bodyStrong(p.ink)),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: p.surface2,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: p.border),
              ),
              child: Row(
                children: SplitMode.values.map((mode) {
                  final isSelected = _splitMode == mode;
                  return Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: () => _onSplitModeChanged(mode),
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: isSelected ? p.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          mode.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isSelected ? p.onPrimary : p.ink,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            // Participants Header & Add People
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Participants (${_activeParticipants.length})',
                    style: AppText.bodyStrong(p.ink),
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.person_add_rounded, size: 18),
                  label: const Text('Add People'),
                  onPressed: _addPeople,
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Participants Allocation Cards
            for (final pEntry in _participants) ...[
              _buildParticipantRow(p, pEntry, calcResult),
              const SizedBox(height: 8),
            ],

            const SizedBox(height: AppSpacing.md),

            // Live Calculation Summary Card
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: calcResult.isValid
                    ? p.surface2
                    : p.expense.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: calcResult.isValid
                      ? p.border
                      : p.expense.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Text('Total Allocated:', style: AppText.body(p.ink)),
                      const Spacer(),
                      Text(
                        CurrencyFormatter.format(
                          calcResult.shares.fold<double>(
                            0.0,
                            (sum, s) => sum + s.allocatedAmount,
                          ),
                        ),
                        style: AppText.bodyStrong(p.ink),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        calcResult.remainingAmount >= 0 ? 'Remaining:' : 'Exceeded by:',
                        style: AppText.caption(
                          calcResult.isExact ? p.muted : p.expense,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        CurrencyFormatter.format(calcResult.remainingAmount.abs()),
                        style: AppText.caption(
                          calcResult.isExact ? p.primary : p.expense,
                        ).copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  if (calcResult.errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      calcResult.errorMessage!,
                      style: AppText.caption(p.expense),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            PrimaryButton(
              label: 'Save Split',
              loading: _isSaving,
              icon: Icons.check_circle_outline_rounded,
              onPressed: _handleSave,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParticipantRow(
    AppPalette p,
    _ParticipantEntry entry,
    SplitCalculationResult calcResult,
  ) {
    CalculatedParticipantShare? share;
    try {
      share = calcResult.shares.firstWhere((s) => s.key == entry.key);
    } catch (_) {}

    final isPayer = entry.key == _payerKey;

    return AppCard(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      child: Row(
        children: [
          Checkbox(
            value: entry.isIncluded,
            activeColor: p.primary,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            onChanged: (val) {
              setState(() => entry.isIncluded = val ?? true);
            },
          ),
          const SizedBox(width: 4),
          CircleAvatar(
            radius: 16,
            backgroundColor: isPayer
                ? p.primary.withValues(alpha: 0.2)
                : p.surface2,
            child: Text(
              entry.name.isNotEmpty ? entry.name[0].toUpperCase() : '?',
              style: AppText.bodyStrong(isPayer ? p.primary : p.ink),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        entry.name,
                        style: AppText.bodyStrong(p.ink),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isPayer) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: p.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Payer',
                          style: AppText.caption(p.primary)
                              .copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                if (share != null && entry.isIncluded) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Share: ${CurrencyFormatter.format(share.allocatedAmount)}',
                    style: AppText.caption(p.muted),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),

          // Input field for custom, percentage, or shares
          if (_splitMode != SplitMode.equal && entry.isIncluded) ...[
            const SizedBox(width: 8),
            SizedBox(
              width: 76,
              child: TextFormField(
                controller: entry.inputController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                textAlign: TextAlign.end,
                style: AppText.bodyStrong(p.ink),
                decoration: InputDecoration(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
                  isDense: true,
                  suffixText: _splitMode == SplitMode.percentage
                      ? '%'
                      : _splitMode == SplitMode.shares
                          ? 'sh'
                          : '',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: BorderSide(color: p.border),
                  ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
          ] else if (share != null && entry.isIncluded) ...[
            const SizedBox(width: 6),
            Text(
              CurrencyFormatter.format(share.allocatedAmount),
              style: AppText.amount(p.ink, size: 14),
            ),
          ],

          if (!entry.isUser) ...[
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              color: p.muted,
              tooltip: 'Remove',
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              padding: EdgeInsets.zero,
              onPressed: () {
                AppHaptics.select();
                setState(() => _participants.remove(entry));
              },
            ),
          ],
        ],
      ),
    );
  }
}
