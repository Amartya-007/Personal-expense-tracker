import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/amount_input.dart';
import '../../core/utils/date_filters.dart';
import '../../data/models/account_model.dart';
import '../../data/models/category_model.dart';
import '../../data/models/tag_model.dart';
import '../providers/transaction_providers.dart';
import 'app_sheets.dart';
import 'field_decoration.dart';

class FilterSheet {
  FilterSheet._();

  static Future<TransactionFilter?> show(
    BuildContext context, {
    required List<CategoryModel> categories,
    required List<AccountModel> accounts,
    required List<TagModel> tags,
    required TransactionFilter initialFilter,
  }) {
    return AppBottomSheet.show<TransactionFilter>(
      context,
      title: 'Advanced Filters',
      builder: (_) => _FilterForm(
        categories: categories,
        accounts: accounts,
        tags: tags,
        initialFilter: initialFilter,
      ),
    );
  }
}

class _FilterForm extends StatefulWidget {
  final List<CategoryModel> categories;
  final List<AccountModel> accounts;
  final List<TagModel> tags;
  final TransactionFilter initialFilter;

  const _FilterForm({
    required this.categories,
    required this.accounts,
    required this.tags,
    required this.initialFilter,
  });

  @override
  State<_FilterForm> createState() => _FilterFormState();
}

class _FilterFormState extends State<_FilterForm> {
  static const List<String> _types = ['All', 'Expense', 'Income', 'Transfer'];
  static const List<String> _payments = AppConstants.paymentMethods;

  late String _type = _labelForType(widget.initialFilter.type);
  late String _datePeriod = widget.initialFilter.datePeriod ?? DateFilters.all;
  late DateTimeRange? _customRange = widget.initialFilter.customDateRange;

  late final TextEditingController _minAmountController = TextEditingController(
    text: widget.initialFilter.minAmount?.toStringAsFixed(0) ?? '',
  );
  late final TextEditingController _maxAmountController = TextEditingController(
    text: widget.initialFilter.maxAmount?.toStringAsFixed(0) ?? '',
  );

  late final TextEditingController _categorySearchController =
      TextEditingController();
  late String _categorySearch = '';

  late final Set<String> _selectedCategoryIds = {
    ...widget.initialFilter.categoryIds,
  };
  late final Set<String> _selectedTagIds = {...widget.initialFilter.tagIds};
  late final Set<String> _selectedAccountIds = {
    ...widget.initialFilter.accountIds,
  };
  late final Set<String> _selectedPayments = {
    ...widget.initialFilter.paymentMethods,
  };

  late bool? _hasReceipt = widget.initialFilter.hasReceipt;
  late bool? _isRecurring = widget.initialFilter.isRecurring;
  late bool? _hasNote = widget.initialFilter.hasNote;
  late bool? _hasLocation = widget.initialFilter.hasLocation;
  late TransactionSortOption _sortBy = widget.initialFilter.sortBy;

  String? _amountError;

  @override
  void initState() {
    super.initState();
    _minAmountController.addListener(_validateAmountRange);
    _maxAmountController.addListener(_validateAmountRange);
  }

  @override
  void dispose() {
    _minAmountController.dispose();
    _maxAmountController.dispose();
    _categorySearchController.dispose();
    super.dispose();
  }

  static String _labelForType(String? type) {
    if (type == null || type.isEmpty) return 'All';
    return type[0].toUpperCase() + type.substring(1);
  }

  void _validateAmountRange() {
    final minVal = double.tryParse(_minAmountController.text.trim());
    final maxVal = double.tryParse(_maxAmountController.text.trim());
    setState(() {
      if (minVal != null && maxVal != null && minVal > maxVal) {
        _amountError = 'Minimum cannot be greater than maximum';
      } else {
        _amountError = null;
      }
    });
  }

  void _applyPresetAmount(double? min, double? max) {
    setState(() {
      _minAmountController.text = min != null ? min.toStringAsFixed(0) : '';
      _maxAmountController.text = max != null ? max.toStringAsFixed(0) : '';
    });
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      initialDateRange:
          _customRange ??
          DateTimeRange(start: DateTime(now.year, now.month, 1), end: now),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        final p = context.palette;
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: p.primary,
              onPrimary: p.onPrimary,
              surface: p.surface,
              onSurface: p.ink,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        _datePeriod = 'Custom';
        _customRange = picked;
      });
    }
  }

  Widget _sectionHeader(String title) {
    final p = context.palette;
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Text(title, style: AppText.bodyStrong(p.ink)),
    );
  }

  Widget _buildChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
    String? emoji,
  }) {
    final p = context.palette;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? p.primary : p.surface2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? p.primary : p.border, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (emoji != null && emoji.isNotEmpty) ...[
              Text(emoji, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 5),
            ],
            Text(
              label,
              style: AppText.caption(selected ? p.onPrimary : p.ink).copyWith(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _resetAll() {
    setState(() {
      _type = 'All';
      _datePeriod = DateFilters.all;
      _customRange = null;
      _minAmountController.clear();
      _maxAmountController.clear();
      _selectedCategoryIds.clear();
      _selectedTagIds.clear();
      _selectedAccountIds.clear();
      _selectedPayments.clear();
      _hasReceipt = null;
      _isRecurring = null;
      _hasNote = null;
      _hasLocation = null;
      _sortBy = TransactionSortOption.dateDesc;
      _amountError = null;
    });
  }

  void _submit() {
    if (_amountError != null) return;

    final minAmt = double.tryParse(_minAmountController.text.trim());
    final maxAmt = double.tryParse(_maxAmountController.text.trim());

    final newFilter = widget.initialFilter.copyWith(
      type: _type == 'All' ? '' : _type.toLowerCase(),
      clearType: _type == 'All',
      datePeriod: _datePeriod == DateFilters.all ? '' : _datePeriod,
      clearDatePeriod: _datePeriod == DateFilters.all,
      customDateRange: _datePeriod == 'Custom' ? _customRange : null,
      clearCustomDateRange: _datePeriod != 'Custom' || _customRange == null,
      minAmount: minAmt,
      clearMinAmount: minAmt == null,
      maxAmount: maxAmt,
      clearMaxAmount: maxAmt == null,
      categoryIds: _selectedCategoryIds.toList(),
      tagIds: _selectedTagIds.toList(),
      accountIds: _selectedAccountIds.toList(),
      paymentMethods: _selectedPayments.toList(),
      hasReceipt: _hasReceipt,
      clearReceipt: _hasReceipt == null,
      isRecurring: _isRecurring,
      clearRecurring: _isRecurring == null,
      hasNote: _hasNote,
      clearNote: _hasNote == null,
      hasLocation: _hasLocation,
      clearLocation: _hasLocation == null,
      sortBy: _sortBy,
    );

    Navigator.pop(context, newFilter);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    final filteredCategories = widget.categories
        .where(
          (c) =>
              _categorySearch.isEmpty ||
              c.name.toLowerCase().contains(_categorySearch.toLowerCase()),
        )
        .toList();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Sort By
          _sectionHeader('Sort By'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildChip(
                label: 'Newest First',
                selected: _sortBy == TransactionSortOption.dateDesc,
                onTap: () =>
                    setState(() => _sortBy = TransactionSortOption.dateDesc),
              ),
              _buildChip(
                label: 'Oldest First',
                selected: _sortBy == TransactionSortOption.dateAsc,
                onTap: () =>
                    setState(() => _sortBy = TransactionSortOption.dateAsc),
              ),
              _buildChip(
                label: 'Highest Amount',
                selected: _sortBy == TransactionSortOption.amountDesc,
                onTap: () =>
                    setState(() => _sortBy = TransactionSortOption.amountDesc),
              ),
              _buildChip(
                label: 'Lowest Amount',
                selected: _sortBy == TransactionSortOption.amountAsc,
                onTap: () =>
                    setState(() => _sortBy = TransactionSortOption.amountAsc),
              ),
              _buildChip(
                label: 'Title A-Z',
                selected: _sortBy == TransactionSortOption.titleAsc,
                onTap: () =>
                    setState(() => _sortBy = TransactionSortOption.titleAsc),
              ),
              _buildChip(
                label: 'Title Z-A',
                selected: _sortBy == TransactionSortOption.titleDesc,
                onTap: () =>
                    setState(() => _sortBy = TransactionSortOption.titleDesc),
              ),
            ],
          ),

          // Transaction Type
          _sectionHeader('Transaction Type'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in _types)
                _buildChip(
                  label: t,
                  selected: _type == t,
                  onTap: () => setState(() => _type = t),
                ),
            ],
          ),

          // Date & Period
          _sectionHeader('Date & Period'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final opt in DateFilters.options)
                _buildChip(
                  label: opt,
                  selected: _datePeriod == opt,
                  onTap: () {
                    if (opt == 'Custom') {
                      _pickDateRange();
                    } else {
                      setState(() {
                        _datePeriod = opt;
                        _customRange = null;
                      });
                    }
                  },
                ),
            ],
          ),
          if (_datePeriod == 'Custom') ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDateRange,
                    icon: Icon(
                      Icons.calendar_month_rounded,
                      size: 16,
                      color: p.primary,
                    ),
                    label: Text(
                      _customRange != null
                          ? '${_customRange!.start.day}/${_customRange!.start.month}/${_customRange!.start.year} - ${_customRange!.end.day}/${_customRange!.end.month}/${_customRange!.end.year}'
                          : 'Select Custom Date Range',
                      style: AppText.caption(p.ink),
                    ),
                  ),
                ),
              ],
            ),
          ],

          // Amount Range
          _sectionHeader('Amount Range (₹)'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildChip(
                label: '< ₹500',
                selected:
                    _maxAmountController.text == '500' &&
                    _minAmountController.text.isEmpty,
                onTap: () => _applyPresetAmount(null, 500),
              ),
              _buildChip(
                label: '₹500 - ₹2,000',
                selected:
                    _minAmountController.text == '500' &&
                    _maxAmountController.text == '2000',
                onTap: () => _applyPresetAmount(500, 2000),
              ),
              _buildChip(
                label: '₹2,000 - ₹10,000',
                selected:
                    _minAmountController.text == '2000' &&
                    _maxAmountController.text == '10000',
                onTap: () => _applyPresetAmount(2000, 10000),
              ),
              _buildChip(
                label: '> ₹10,000',
                selected:
                    _minAmountController.text == '10000' &&
                    _maxAmountController.text.isEmpty,
                onTap: () => _applyPresetAmount(10000, null),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _minAmountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: AmountInput.amountFormatters(),
                  style: AppText.body(p.ink),
                  decoration: appFieldDecoration(p).copyWith(
                    hintText: 'Min Amount',
                    prefixText: '₹ ',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _maxAmountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: AmountInput.amountFormatters(),
                  style: AppText.body(p.ink),
                  decoration: appFieldDecoration(p).copyWith(
                    hintText: 'Max Amount',
                    prefixText: '₹ ',
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_amountError != null) ...[
            const SizedBox(height: 6),
            Text(
              _amountError!,
              style: TextStyle(
                color: p.expense,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],

          // Categories
          _sectionHeader('Categories'),
          TextField(
            controller: _categorySearchController,
            onChanged: (val) => setState(() => _categorySearch = val),
            style: AppText.body(p.ink),
            decoration: appFieldDecoration(p).copyWith(
              hintText: 'Search categories...',
              prefixIcon: Icon(Icons.search_rounded, size: 18, color: p.muted),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildChip(
                label: 'Uncategorized',
                emoji: '❓',
                selected: _selectedCategoryIds.contains('uncategorized'),
                onTap: () {
                  setState(() {
                    if (_selectedCategoryIds.contains('uncategorized')) {
                      _selectedCategoryIds.remove('uncategorized');
                    } else {
                      _selectedCategoryIds.add('uncategorized');
                    }
                  });
                },
              ),
              for (final cat in filteredCategories)
                _buildChip(
                  label: cat.name,
                  emoji: AppColors.getCategoryEmoji(cat.name),
                  selected: _selectedCategoryIds.contains(cat.id),
                  onTap: () {
                    setState(() {
                      if (_selectedCategoryIds.contains(cat.id)) {
                        _selectedCategoryIds.remove(cat.id);
                      } else {
                        _selectedCategoryIds.add(cat.id);
                      }
                    });
                  },
                ),
            ],
          ),

          // Tags
          if (widget.tags.isNotEmpty) ...[
            _sectionHeader('Tags'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final tag in widget.tags)
                  _buildChip(
                    label: '#${tag.name}',
                    selected: _selectedTagIds.contains(tag.id),
                    onTap: () {
                      setState(() {
                        if (_selectedTagIds.contains(tag.id)) {
                          _selectedTagIds.remove(tag.id);
                        } else {
                          _selectedTagIds.add(tag.id);
                        }
                      });
                    },
                  ),
              ],
            ),
          ],

          // Accounts
          if (widget.accounts.isNotEmpty) ...[
            _sectionHeader('Accounts'),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildChip(
                  label: 'Primary Account',
                  emoji: '⭐',
                  selected: _selectedAccountIds.contains('primary'),
                  onTap: () {
                    setState(() {
                      if (_selectedAccountIds.contains('primary')) {
                        _selectedAccountIds.remove('primary');
                      } else {
                        _selectedAccountIds.add('primary');
                      }
                    });
                  },
                ),
                for (final acc in widget.accounts)
                  _buildChip(
                    label: acc.name,
                    emoji: acc.isPrimary ? '⭐' : '🏦',
                    selected: _selectedAccountIds.contains(acc.id),
                    onTap: () {
                      setState(() {
                        if (_selectedAccountIds.contains(acc.id)) {
                          _selectedAccountIds.remove(acc.id);
                        } else {
                          _selectedAccountIds.add(acc.id);
                        }
                      });
                    },
                  ),
              ],
            ),
          ],

          // Payment Methods
          _sectionHeader('Payment Methods'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final pm in _payments)
                _buildChip(
                  label: pm,
                  selected: _selectedPayments.contains(pm),
                  onTap: () {
                    setState(() {
                      if (_selectedPayments.contains(pm)) {
                        _selectedPayments.remove(pm);
                      } else {
                        _selectedPayments.add(pm);
                      }
                    });
                  },
                ),
            ],
          ),

          // Additional Filters
          _sectionHeader('Additional Filters'),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildChip(
                label: 'With Receipt',
                emoji: '🧾',
                selected: _hasReceipt == true,
                onTap: () => setState(
                  () => _hasReceipt = _hasReceipt == true ? null : true,
                ),
              ),
              _buildChip(
                label: 'Without Receipt',
                selected: _hasReceipt == false,
                onTap: () => setState(
                  () => _hasReceipt = _hasReceipt == false ? null : false,
                ),
              ),
              _buildChip(
                label: 'Recurring Only',
                emoji: '🔄',
                selected: _isRecurring == true,
                onTap: () => setState(
                  () => _isRecurring = _isRecurring == true ? null : true,
                ),
              ),
              _buildChip(
                label: 'Non-Recurring',
                selected: _isRecurring == false,
                onTap: () => setState(
                  () => _isRecurring = _isRecurring == false ? null : false,
                ),
              ),
              _buildChip(
                label: 'With Note',
                emoji: '📝',
                selected: _hasNote == true,
                onTap: () =>
                    setState(() => _hasNote = _hasNote == true ? null : true),
              ),
              _buildChip(
                label: 'With Location',
                emoji: '📍',
                selected: _hasLocation == true,
                onTap: () => setState(
                  () => _hasLocation = _hasLocation == true ? null : true,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Bottom Action Row
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: p.ink,
                    backgroundColor: p.surface2,
                    side: BorderSide.none,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: _resetAll,
                  child: Text('Clear All', style: AppText.button(p.ink)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: p.primary,
                    foregroundColor: p.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                  ),
                  onPressed: _submit,
                  child: const Text('Show Results'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}
