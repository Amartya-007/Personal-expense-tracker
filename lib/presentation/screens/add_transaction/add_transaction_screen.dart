import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_haptics.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/account_model.dart';
import '../../../data/models/category_model.dart';
import '../../../data/models/receipt_model.dart';
import '../../../data/models/tag_model.dart';
import '../../../data/models/transaction_model.dart';
import '../../../services/location/location_service.dart';
import '../../../services/receipts/receipt_storage_service.dart';
import '../../providers/account_providers.dart';
import '../../providers/category_providers.dart';
import '../../providers/tag_providers.dart';
import '../../widgets/app_dropdown.dart';
import '../../widgets/app_sheets.dart';
import '../../widgets/field_decoration.dart';
import '../../widgets/multi_select_field.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/segmented_tabs.dart';
import '../../providers/settings_providers.dart';
import '../../providers/transaction_providers.dart';

class AddTransactionScreen extends ConsumerStatefulWidget {
  final String initialType;
  final TransactionModel? editTransaction;

  const AddTransactionScreen({
    super.key,
    this.initialType = 'expense',
    this.editTransaction,
  });

  @override
  ConsumerState<AddTransactionScreen> createState() =>
      _AddTransactionScreenState();
}

class _AddTransactionScreenState extends ConsumerState<AddTransactionScreen> {
  late String _type; // 'expense', 'income', 'transfer'
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();

  final FocusNode _amountFocusNode = FocusNode();
  final FocusNode _descriptionFocusNode = FocusNode();

  CategoryModel? _selectedCategory;
  String _selectedPaymentMethod = 'UPI';
  AccountModel? _selectedAccount;
  AccountModel? _selectedDestinationAccount;
  DateTime _selectedDate = DateTime.now();

  final List<TagModel> _selectedTags = [];
  final List<ReceiptModel> _receipts = [];

  LocationResult? _locationResult;
  bool _isSaving = false;
  String? _suggestedCategoryName;

  final Uuid _uuid = const Uuid();
  final ReceiptStorageService _receiptService = ReceiptStorageService();
  final LocationService _locationService = LocationService();

  static const Map<String, String> _keywordRules = {
    'momos': 'Food',
    'pizza': 'Food',
    'burger': 'Food',
    'chinese': 'Food',
    'swiggy': 'Food',
    'zomato': 'Food',
    'pen': 'Stationery',
    'notebook': 'Stationery',
    'books': 'Education',
    'charger': 'Electronics',
    'earphones': 'Electronics',
    'screen guard': 'Electronics',
  };

  @override
  void initState() {
    super.initState();
    _type =
        widget.editTransaction?.type.toLowerCase() ??
        widget.initialType.toLowerCase();

    if (widget.editTransaction != null) {
      final tx = widget.editTransaction!;
      _amountController.text = tx.amount.toStringAsFixed(
        tx.amount.truncateToDouble() == tx.amount ? 0 : 2,
      );
      _descriptionController.text = tx.description;
      _selectedPaymentMethod = tx.paymentMethod;
      _selectedDate = tx.date;
      _noteController.text = tx.note ?? '';
      _selectedTags.addAll(tx.tags);
      _receipts.addAll(tx.receipts);
    }

    _captureLocation();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.editTransaction == null) {
        _amountFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    _noteController.dispose();
    _amountFocusNode.dispose();
    _descriptionFocusNode.dispose();
    super.dispose();
  }

  Future<void> _captureLocation() async {
    // BUG FIX: wrap in try/catch — location is optional and must never crash the screen.
    try {
      final res = await _locationService.getCurrentLocation();
      if (mounted && res != null) {
        setState(() => _locationResult = res);
      }
    } catch (_) {
      // Location unavailable — silently ignore.
    }
  }

  void _onDescriptionChanged(String text, List<CategoryModel> categories) {
    if (_type != 'expense') {
      setState(() => _suggestedCategoryName = null);
      return;
    }
    // BUG FIX: guard against empty categories list to prevent RangeError on .first
    if (categories.isEmpty) return;

    final lower = text.toLowerCase().trim();
    String? matchedCategory;

    for (final entry in _keywordRules.entries) {
      if (lower.contains(entry.key)) {
        matchedCategory = entry.value;
        break;
      }
    }

    if (matchedCategory != null) {
      final match = categories.firstWhere(
        (c) => c.name.toLowerCase() == matchedCategory!.toLowerCase(),
        orElse: () => categories.first,
      );
      setState(() {
        _selectedCategory = match;
        _suggestedCategoryName = matchedCategory;
      });
    } else {
      if (_suggestedCategoryName != null) {
        setState(() => _suggestedCategoryName = null);
      }
    }
  }

  Future<void> _pickReceipt(ImageSource source) async {
    final txId = widget.editTransaction?.id ?? _uuid.v4();
    final receipt = await _receiptService.captureAndSaveReceipt(source, txId);
    if (receipt != null && mounted) {
      setState(() {
        _receipts.add(receipt);
      });
    }
  }

  Future<void> _saveTransaction() async {
    if (_isSaving) return;

    final amountStr = _amountController.text.trim();
    final descriptionStr = _descriptionController.text.trim();

    final amount = double.tryParse(amountStr) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid amount.')),
      );
      _amountFocusNode.requestFocus();
      return;
    }

    if (_type != 'transfer' && descriptionStr.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter "What\'s it for?".')),
      );
      _descriptionFocusNode.requestFocus();
      return;
    }

    final accounts = ref.read(accountListProvider).value ?? [];
    if (accounts.isEmpty && _selectedPaymentMethod != 'Cash') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please create a bank account first.')),
      );
      return;
    }

    final account = _effectiveAccount(accounts);
    final destination = _effectiveDestination(accounts);
    if (_type == 'transfer') {
      if (account == null || destination == null || account.id == destination.id) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choose two different accounts.')),
        );
        return;
      }
    }

    final categories = ref
            .read(
              _type == 'income'
                  ? incomeCategoriesProvider
                  : expenseCategoriesProvider,
            )
            .value ??
        const <CategoryModel>[];
    final original = widget.editTransaction;
    final category = _effectiveCategory(categories);
    // An edited transaction keeps its own category unless the user picked
    // another one (even if that category is no longer in the list).
    final categoryId = _type == 'transfer'
        ? null
        : (category?.id ??
            (original != null && original.type.toLowerCase() == _type
                ? original.categoryId
                : null));

    setState(() => _isSaving = true);

    final txId = widget.editTransaction?.id ?? _uuid.v4();
    final finalDesc = _type == 'transfer'
        ? '${account?.name ?? "Account"} → ${destination?.name ?? "Account"}'
        : descriptionStr;

    final tx = TransactionModel(
      id: txId,
      type: _type,
      amount: amount,
      description: finalDesc,
      categoryId: categoryId,
      paymentMethod: _type == 'transfer' ? 'Bank' : _selectedPaymentMethod,
      accountId:
          account?.id ??
          original?.accountId ??
          (accounts.isNotEmpty ? accounts.first.id : ''),
      destinationAccountId: _type == 'transfer' ? destination?.id : null,
      date: _selectedDate,
      note: _noteController.text.trim().isNotEmpty
          ? _noteController.text.trim()
          : null,
      latitude: _locationResult?.latitude ?? widget.editTransaction?.latitude,
      longitude:
          _locationResult?.longitude ?? widget.editTransaction?.longitude,
      locationName:
          _locationResult?.locationName ?? widget.editTransaction?.locationName,
      tags: _selectedTags,
      receipts: _receipts,
      createdAt: widget.editTransaction?.createdAt ?? DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // BUG FIX: try/catch/finally ensures _isSaving always resets, even on DB error.
    try {
      if (widget.editTransaction != null) {
        await ref.read(transactionListProvider.notifier).updateTransaction(tx);
      } else {
        await ref.read(transactionListProvider.notifier).createTransaction(tx);
      }

      if (mounted) {
        AppHaptics.success();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${_type.toUpperCase()} recorded successfully!'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save transaction: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final isDark = p.isDark;
    final surfaceColor = p.surface;
    final linesColor = p.border;
    final inkColor = p.ink;
    final mutedColor = p.muted;
    final amountColor = _type == 'expense'
        ? p.expense
        : _type == 'income'
        ? p.income
        : p.primary;

    final accounts = ref.watch(accountListProvider).value ?? [];
    final savedTags = ref.watch(tagsListProvider).value ?? const <TagModel>[];
    // Every saved tag, plus any tag this transaction already carries that is
    // not in the list, so nothing it has is hidden or impossible to remove.
    final tagNames = <String>[
      for (final tag in savedTags) tag.name,
      for (final tag in _selectedTags)
        if (!savedTags.any((s) => s.name.toLowerCase() == tag.name.toLowerCase()))
          tag.name,
    ];
    final categoriesAsync = ref.watch(
      _type == 'income' ? incomeCategoriesProvider : expenseCategoriesProvider,
    );

    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.only(left: 12),
          child: Center(
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: surfaceColor,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(
                        alpha: isDark ? 0.2 : 0.05,
                      ),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ],
                ),
                child: Icon(Icons.close, size: 20, color: inkColor),
              ),
            ),
          ),
        ),
        title: Text(
          widget.editTransaction != null
              ? 'Edit Transaction'
              : 'New transaction',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: inkColor,
          ),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Transaction type
              SegmentedTabs(
                options: const ['Expense', 'Income', 'Transfer'],
                selected: _type[0].toUpperCase() + _type.substring(1),
                onSelected: (label) {
                  setState(() {
                    _type = label.toLowerCase();
                    _suggestedCategoryName = null;
                  });
                  if (widget.editTransaction == null) {
                    _amountFocusNode.requestFocus();
                  }
                },
              ),

              const SizedBox(height: 24),

              // 1. Amount Field (44px bold, borderless bottom-line style)
              Text(
                'Amount',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: mutedColor,
                ),
              ),
              TextField(
                controller: _amountController,
                focusNode: _amountFocusNode,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                textInputAction: TextInputAction.next,
                style: TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                  color: amountColor,
                ),
                decoration: InputDecoration(
                  prefixText: '₹',
                  prefixStyle: TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w800,
                    color: amountColor,
                  ),
                  hintText: '0',
                  hintStyle: TextStyle(
                    fontSize: 44,
                    fontWeight: FontWeight.w800,
                    color: mutedColor.withValues(alpha: 0.4),
                  ),
                  filled: false,
                  border: UnderlineInputBorder(
                    borderSide: BorderSide(color: linesColor, width: 3),
                  ),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: linesColor, width: 3),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: p.primary, width: 3),
                  ),
                  contentPadding: const EdgeInsets.symmetric(vertical: 6),
                ),
                onSubmitted: (_) {
                  FocusScope.of(context).requestFocus(_descriptionFocusNode);
                },
              ),

              const SizedBox(height: 20),

              // 2. What's it for? / From
              categoriesAsync.when(
                data: (categories) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _type == 'transfer'
                            ? 'From'
                            : _type == 'income'
                            ? 'Description'
                            : "What's it for?",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: mutedColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (_type == 'transfer')
                        _buildAccountDropdown(
                          value: _effectiveAccount(accounts),
                          accounts: accounts,
                          onChanged: (acc) =>
                              setState(() => _selectedAccount = acc),
                        )
                      else ...[
                        TextField(
                          controller: _descriptionController,
                          focusNode: _descriptionFocusNode,
                          textInputAction: TextInputAction.next,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: inkColor,
                          ),
                          decoration: appFieldDecoration(p, hint: _type == 'income' ? 'Salary, freelance…' : 'Momos, charger, pen…'),
                          onChanged: (val) =>
                              _onDescriptionChanged(val, categories),
                        ),
                        if (_suggestedCategoryName != null &&
                            _type == 'expense')
                          Padding(
                            padding: const EdgeInsets.only(top: 6, left: 4),
                            child: Text(
                              '✨ Suggested: $_suggestedCategoryName · tap category to change',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: p.primary,
                              ),
                            ),
                          ),
                      ],

                      const SizedBox(height: 18),

                      // 3. Category / To
                      Text(
                        _type == 'transfer' ? 'To' : 'Category',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: mutedColor,
                        ),
                      ),
                      const SizedBox(height: 6),
                      if (_type == 'transfer')
                        _buildAccountDropdown(
                          value: _effectiveDestination(accounts),
                          accounts: accounts,
                          onChanged: (acc) =>
                              setState(() => _selectedDestinationAccount = acc),
                        )
                      else ...[
                        if (categories.isEmpty)
                          Text(
                            'No categories available.',
                            style: TextStyle(color: mutedColor),
                          )
                        else ...[
                          AppDropdown<CategoryModel>(
                            hint: 'Uncategorized',
                            sheetTitle: 'Category',
                            value: _effectiveCategory(categories),
                            items: categories,
                            keyOf: (c) => c.id,
                            labelOf: (c) => c.name,
                            emojiOf: (c) => AppColors.getCategoryEmoji(c.name),
                            onChanged: (c) => setState(() {
                              _selectedCategory = c;
                              _suggestedCategoryName = null;
                            }),
                          ),
                        ],
                      ],
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error: $e'),
              ),

              const SizedBox(height: 18),

              // 4. Payment method (if not transfer)
              if (_type != 'transfer') ...[
                Text(
                  'Payment method',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: mutedColor,
                  ),
                ),
                const SizedBox(height: 6),
                SegmentedTabs(
                  options: const ['UPI', 'Cash', 'Debit Card'],
                  selected: _selectedPaymentMethod,
                  onSelected: (method) =>
                      setState(() => _selectedPaymentMethod = method),
                ),
                const SizedBox(height: 18),

                // Account field (hidden if Cash is selected, matching HTML: $('#acf').style.display=APM==='Cash'?'none':'')
                if (_selectedPaymentMethod != 'Cash') ...[
                  Text(
                    'Account',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: mutedColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  _buildAccountDropdown(
                    value: _effectiveAccount(accounts),
                    accounts: accounts,
                    onChanged: (acc) => setState(() => _selectedAccount = acc),
                  ),
                  const SizedBox(height: 18),
                ],
              ],

              // 5. Date
              Text(
                'Date',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: mutedColor,
                ),
              ),
              const SizedBox(height: 6),
              InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => _selectedDate = picked);
                },
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: linesColor),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_selectedDate.day} ${_getMonthName(_selectedDate.month)} ${_selectedDate.year}',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: inkColor,
                        ),
                      ),
                      Icon(Icons.calendar_today, size: 18, color: mutedColor),
                    ],
                  ),
                ),
              ),

              // 6. Expense-Only Sections (Note, Tags, Location, Receipts)
              if (_type == 'expense') ...[
                const SizedBox(height: 18),
                Text(
                  'Note',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: mutedColor,
                  ),
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: _noteController,
                  style: TextStyle(fontSize: 15, color: inkColor),
                  decoration: appFieldDecoration(p, hint: 'Optional'),
                ),

                const SizedBox(height: 18),
                Text(
                  'Tags',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: mutedColor,
                  ),
                ),
                const SizedBox(height: 6),
                MultiSelectField(
                  hint: 'Select tags',
                  sheetTitle: 'Tags',
                  emptyMessage: 'No tags yet. Add some in Settings → Tags.',
                  options: tagNames,
                  selected: [
                    for (final name in tagNames)
                      if (_hasTag(name)) name,
                  ],
                  onChanged: (names) => _setTags(names, savedTags),
                ),

                const SizedBox(height: 18),
                Text(
                  'Location',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: mutedColor,
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: surfaceColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: linesColor),
                  ),
                  child: Row(
                    children: [
                      const Text('📍', style: TextStyle(fontSize: 18)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _locationResult?.locationName ??
                              'Captured automatically when you save',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: _locationResult != null
                                ? inkColor
                                : mutedColor,
                            fontWeight: _locationResult != null
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),
                Text(
                  'Receipt',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: mutedColor,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ..._receipts.map((rcpt) {
                      return Stack(
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.file(
                              File(rcpt.thumbnailPath),
                              width: 68,
                              height: 68,
                              fit: BoxFit.cover,
                            ),
                          ),
                          Positioned(
                            right: 4,
                            top: 4,
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _receipts.remove(rcpt)),
                              child: Container(
                                padding: const EdgeInsets.all(3),
                                decoration: const BoxDecoration(
                                  color: Colors.black54,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.close,
                                  size: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }),
                    InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => _showReceiptSourceSheet(context),
                      child: Container(
                        width: 68,
                        height: 68,
                        decoration: BoxDecoration(
                          color: surfaceColor,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: linesColor,
                            style: BorderStyle.solid,
                            width: 2,
                          ),
                        ),
                        child: Icon(Icons.add, size: 26, color: mutedColor),
                      ),
                    ),
                  ],
                ),
              ],

              const SizedBox(height: 32),

              // Save Button
              PrimaryButton(
                label: widget.editTransaction != null
                    ? 'Save changes'
                    : 'Save $_type',
                loading: _isSaving,
                onPressed: _saveTransaction,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The account a brand-new expense should start on: the primary account, if
  /// one is set. `null` means "no primary account, keep the usual behaviour".
  ///
  /// Deliberately not used for transfers (the source/destination must be
  /// chosen), income, Cash (no account involved) or when editing an existing
  /// transaction (which must keep its own account).
  AccountModel? _primaryDefault(List<AccountModel> accounts) {
    if (widget.editTransaction != null ||
        _type != 'expense' ||
        _selectedPaymentMethod == 'Cash') {
      return null;
    }
    for (final account in accounts) {
      if (account.isPrimary) return account;
    }
    return null;
  }

  AccountModel? _accountById(List<AccountModel> accounts, String? id) {
    if (id == null) return null;
    for (final account in accounts) {
      if (account.id == id) return account;
    }
    return null;
  }

  /// The account the screen shows AND the one that gets saved, so the two can
  /// never disagree. Order: what the user picked; when editing, the
  /// transaction's own account (`null` if that account was removed); primary
  /// account (new expense only); default UPI account; first account.
  AccountModel? _effectiveAccount(List<AccountModel> accounts) {
    final picked = _accountById(accounts, _selectedAccount?.id);
    if (picked != null) return picked;
    final original = widget.editTransaction;
    if (original != null) return _accountById(accounts, original.accountId);
    if (accounts.isEmpty) return null;
    return _primaryDefault(accounts) ??
        _accountById(accounts, ref.read(defaultUpiAccountProvider)) ??
        accounts.first;
  }

  /// Transfer destination, resolved the same way as [_effectiveAccount]. New
  /// transfers default to the first account that is not the source.
  AccountModel? _effectiveDestination(List<AccountModel> accounts) {
    final picked = _accountById(accounts, _selectedDestinationAccount?.id);
    if (picked != null) return picked;
    final original = widget.editTransaction;
    if (original != null && original.isTransfer) {
      return _accountById(accounts, original.destinationAccountId);
    }
    if (accounts.isEmpty) return null;
    final sourceId = _effectiveAccount(accounts)?.id;
    for (final account in accounts) {
      if (account.id != sourceId) return account;
    }
    return accounts.first;
  }

  /// Category shown and saved. When editing a transaction of the same type it
  /// is the transaction's own category (`null` if it had none), so saving
  /// without touching the dropdown no longer wipes or swaps it.
  CategoryModel? _effectiveCategory(List<CategoryModel> categories) {
    for (final category in categories) {
      if (category.id == _selectedCategory?.id) return category;
    }
    final original = widget.editTransaction;
    if (original != null && original.type.toLowerCase() == _type) {
      for (final category in categories) {
        if (category.id == original.categoryId) return category;
      }
      return null;
    }
    return categories.isEmpty ? null : categories.first;
  }

  bool _hasTag(String name) => _selectedTags.any(
        (t) => t.name.toLowerCase() == name.toLowerCase(),
      );

  /// Applies the chosen tag names. Tags the transaction already has keep
  /// their identity, a saved tag is reused (same id), and unknown names become
  /// new tags.
  void _setTags(List<String> names, List<TagModel> saved) {
    TagModel? find(Iterable<TagModel> tags, String lower) =>
        tags.where((t) => t.name.toLowerCase() == lower).firstOrNull;

    setState(() {
      final next = <TagModel>[
        for (final name in names)
          find(_selectedTags, name.toLowerCase()) ??
              find(saved, name.toLowerCase()) ??
              TagModel(id: _uuid.v4(), name: name),
      ];
      _selectedTags
        ..clear()
        ..addAll(next);
    });
  }

  Widget _buildAccountDropdown({
    required AccountModel? value,
    required List<AccountModel> accounts,
    required ValueChanged<AccountModel?> onChanged,
  }) {
    return AppDropdown<AccountModel>(
      // `value` is null only when editing a transaction whose account was
      // removed.
      hint: 'Account removed - pick one',
      emptyMessage: 'No accounts created.',
      sheetTitle: 'Account',
      value: value,
      items: accounts,
      keyOf: (a) => a.id,
      labelOf: (a) => a.name,
      subtitleOf: (a) => CurrencyFormatter.format(a.currentBalance),
      emojiOf: (a) => a.isPrimary ? '⭐' : '🏦',
      onChanged: onChanged,
    );
  }

  void _showReceiptSourceSheet(BuildContext context) {
    AppBottomSheet.show<void>(
      context,
      title: 'Attach receipt',
      builder: (ctx) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(Icons.camera_alt_rounded, color: ctx.palette.primary),
            title: const Text('Take photo'),
            onTap: () {
              Navigator.pop(ctx);
              _pickReceipt(ImageSource.camera);
            },
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              Icons.photo_library_rounded,
              color: ctx.palette.primary,
            ),
            title: const Text('Choose from gallery'),
            onTap: () {
              Navigator.pop(ctx);
              _pickReceipt(ImageSource.gallery);
            },
          ),
        ],
      ),
    );
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }
}
