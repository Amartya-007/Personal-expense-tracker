import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_palette.dart';
import '../../core/theme/app_text.dart';
import '../../core/utils/date_filters.dart';
import '../../data/models/account_model.dart';
import '../../data/models/category_model.dart';
import 'app_dropdown.dart';
import 'app_sheets.dart';
import 'pill_chips.dart';

/// Result of the filter sheet. Null fields mean "no filter" (the user picked
/// All).
typedef FilterSelection = ({
  String? type,
  String? paymentMethod,
  String? dateFilter,
  String? categoryId,
  String? accountId,
});

class FilterSheet {
  FilterSheet._();

  /// Opens the sheet pre-filled with the *current* filters (the date used to
  /// always reopen on "All", which then cleared the active date filter).
  /// Resolves to the new selection, or null if dismissed. Reset resolves to a
  /// selection with every field null.
  static Future<FilterSelection?> show(
    BuildContext context, {
    required List<CategoryModel> categories,
    required List<AccountModel> accounts,
    String? type,
    String? paymentMethod,
    String? dateFilter,
    String? categoryId,
    String? accountId,
  }) {
    return AppBottomSheet.show<FilterSelection>(
      context,
      title: 'Filters',
      builder: (_) => _FilterForm(
        categories: categories,
        accounts: accounts,
        initialType: type,
        initialPaymentMethod: paymentMethod,
        initialDateFilter: dateFilter,
        initialCategoryId: categoryId,
        initialAccountId: accountId,
      ),
    );
  }
}

class _FilterForm extends StatefulWidget {
  final List<CategoryModel> categories;
  final List<AccountModel> accounts;
  final String? initialType;
  final String? initialPaymentMethod;
  final String? initialDateFilter;
  final String? initialCategoryId;
  final String? initialAccountId;

  const _FilterForm({
    required this.categories,
    required this.accounts,
    this.initialType,
    this.initialPaymentMethod,
    this.initialDateFilter,
    this.initialCategoryId,
    this.initialAccountId,
  });

  @override
  State<_FilterForm> createState() => _FilterFormState();
}

class _FilterFormState extends State<_FilterForm> {
  static const List<String> _types = ['All', 'Expense', 'Income', 'Transfer'];
  static const List<String> _payments = ['All', ...AppConstants.paymentMethods];

  late String _date = widget.initialDateFilter ?? DateFilters.all;
  late String _payment = widget.initialPaymentMethod ?? 'All';
  late String _type = _labelForType(widget.initialType);

  /// Empty string means "all" (no filter).
  /// A saved filter whose category/account has since been removed falls back
  /// to "all" instead of breaking the sheet.
  late String _categoryId =
      widget.categories.any((c) => c.id == widget.initialCategoryId)
          ? widget.initialCategoryId!
          : '';
  late String _accountId =
      widget.accounts.any((a) => a.id == widget.initialAccountId)
          ? widget.initialAccountId!
          : '';

  static String _labelForType(String? type) {
    if (type == null || type.isEmpty) return 'All';
    return type[0].toUpperCase() + type.substring(1);
  }

  Widget _section(String title, List<String> options, String selected,
      ValueChanged<String> onSelected) {
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppText.bodyStrong(p.ink)),
        const SizedBox(height: 8),
        PillChips(
          wrap: true,
          options: options,
          selected: selected,
          onSelected: onSelected,
        ),
        const SizedBox(height: 18),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _section('Date', DateFilters.options, _date,
            (v) => setState(() => _date = v)),
        _section('Payment', _payments, _payment,
            (v) => setState(() => _payment = v)),
        _section('Type', _types, _type, (v) => setState(() => _type = v)),
        AppDropdown<String>(
          label: 'Category',
          value: _categoryId,
          items: ['', ...widget.categories.map((c) => c.id)],
          labelOf: (id) => id.isEmpty
              ? 'All categories'
              : widget.categories.firstWhere((c) => c.id == id).name,
          emojiOf: (id) => id.isEmpty
              ? '🗂️'
              : AppColors.getCategoryEmoji(
                  widget.categories.firstWhere((c) => c.id == id).name,
                ),
          onChanged: (id) => setState(() => _categoryId = id),
        ),
        const SizedBox(height: 12),
        AppDropdown<String>(
          label: 'Account',
          value: _accountId,
          items: ['', ...widget.accounts.map((a) => a.id)],
          labelOf: (id) => id.isEmpty
              ? 'All accounts'
              : widget.accounts.firstWhere((a) => a.id == id).name,
          emojiOf: (id) => id.isEmpty ? '🗂️' : '🏦',
          onChanged: (id) => setState(() => _accountId = id),
        ),
        const SizedBox(height: 18),
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
                onPressed: () => Navigator.pop<FilterSelection>(
                  context,
                  (
                    type: null,
                    paymentMethod: null,
                    dateFilter: null,
                    categoryId: null,
                    accountId: null,
                  ),
                ),
                child: Text('Reset', style: AppText.button(p.ink)),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: () => Navigator.pop<FilterSelection>(
                  context,
                  (
                    type: _type == 'All' ? null : _type.toLowerCase(),
                    paymentMethod: _payment == 'All' ? null : _payment,
                    dateFilter: _date == DateFilters.all ? null : _date,
                    categoryId: _categoryId.isEmpty ? null : _categoryId,
                    accountId: _accountId.isEmpty ? null : _accountId,
                  ),
                ),
                child: const Text('Show results'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
