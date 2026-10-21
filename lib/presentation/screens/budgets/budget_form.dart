import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/utils/amount_input.dart';
import '../../../core/utils/currency_formatter.dart';
import '../../../data/models/budget_model.dart';
import '../../../data/models/category_model.dart';
import '../../../data/repositories/budget_repository.dart';
import '../../widgets/app_dropdown.dart';
import '../../widgets/field_decoration.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/segmented_tabs.dart';

/// Fetches the suggested limit for a category + period (its actual spend in the
/// previous same-type period). The caller owns the provider plumbing so the
/// form stays free of Riverpod.
typedef BudgetSuggestionFetcher = Future<double> Function(
  String categoryId,
  String period,
);

const Map<String, String> _periodNoun = {
  'weekly': 'week',
  'monthly': 'month',
  'yearly': 'year',
};

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

  /// Optional: fetches the previous-period spend for the selected
  /// category/period. When provided, an accept-or-overwrite "Suggested" hint is
  /// shown under the Limit field.
  final BudgetSuggestionFetcher? onFetchSuggestion;

  const BudgetForm({
    super.key,
    required this.categories,
    required this.existing,
    this.initialPeriod = 'monthly',
    this.onFetchSuggestion,
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

  /// The latest fetched suggestion (null while loading or when there is no
  /// prior-period spend to suggest). Guarded by [_suggestionToken] so a stale
  /// in-flight fetch can't overwrite a newer selection.
  double? _suggestion;
  int _suggestionToken = 0;

  @override
  void initState() {
    super.initState();
    _refreshSuggestion();
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  bool _hasBudget(CategoryModel c, String period) =>
      widget.existing.any((b) => b.categoryId == c.id && b.period == period);

  /// Prefer a category that does not have a budget yet for this period.
  CategoryModel _firstFreeCategory() {
    for (final c in widget.categories) {
      if (!_hasBudget(c, _period)) return c;
    }
    return widget.categories.first;
  }

  Future<void> _refreshSuggestion() async {
    final fetch = widget.onFetchSuggestion;
    if (fetch == null) return;
    final token = ++_suggestionToken;
    setState(() => _suggestion = null);
    final value = await fetch(_category.id, _period);
    // Ignore if a newer selection superseded this fetch or the sheet closed.
    if (!mounted || token != _suggestionToken) return;
    setState(() => _suggestion = value > 0 ? value : null);
  }

  void _acceptSuggestion(double value) {
    _amount.text = value.toStringAsFixed(0);
    _amount.selection = TextSelection.collapsed(offset: _amount.text.length);
    setState(() => _error = _liveError(checkAmount: true));
  }

  /// Live error for the form: a duplicate category/period budget is reported
  /// as soon as it is selected; the amount is checked on every keystroke
  /// (only once the user has typed, so a fresh form isn't born red).
  String? _liveError({required bool checkAmount}) {
    if (_hasBudget(_category, _period)) {
      return 'You already have a $_period budget for ${_category.name}.';
    }
    if (!checkAmount) return null;
    return AmountInput.validateAmount(_amount.text, allowZero: false);
  }

  void _submit() {
    final err = AmountInput.validateAmount(_amount.text, allowZero: false);
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    final amount = AmountInput.parseAmount(_amount.text)!;
    if (_hasBudget(_category, _period)) {
      setState(
        () => _error =
            'You already have a $_period budget for ${_category.name}.',
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
        SegmentedTabs(
          options: const ['Weekly', 'Monthly', 'Yearly'],
          selected: _period[0].toUpperCase() + _period.substring(1),
          onSelected: (label) {
            setState(() {
              _period = label.toLowerCase();
              _error = _liveError(checkAmount: _amount.text.isNotEmpty);
            });
            _refreshSuggestion();
          },
        ),
        const SizedBox(height: 14),
        AppDropdown<CategoryModel>(
          label: 'Category',
          value: _category,
          items: widget.categories,
          keyOf: (c) => c.id,
          labelOf: (c) => c.name,
          emojiOf: (c) => AppColors.getCategoryEmoji(c.name),
          subtitleOf: (c) =>
              _hasBudget(c, _period) ? 'Already has a $_period budget' : null,
          onChanged: (c) {
            setState(() {
              _category = c;
              _error = _liveError(checkAmount: _amount.text.isNotEmpty);
            });
            _refreshSuggestion();
          },
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: AmountInput.amountFormatters(),
          onChanged: (_) =>
              setState(() => _error = _liveError(checkAmount: true)),
          onSubmitted: (_) => _submit(),
          decoration: appFieldDecoration(
            p,
            hint: 'e.g. 5000',
          ).copyWith(labelText: 'Limit (₹)'),
        ),
        if (_suggestion != null) ...[
          const SizedBox(height: 8),
          _SuggestionHint(
            amount: _suggestion!,
            periodNoun: _periodNoun[_period] ?? 'period',
            onAccept: () => _acceptSuggestion(_suggestion!),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 10),
          Text(_error!, style: AppText.caption(p.expense)),
        ],
        const SizedBox(height: 16),
        PrimaryButton(label: 'Create budget', onPressed: _submit),
      ],
    );
  }
}

/// Accept-or-overwrite hint under the Limit field. Tapping it prefills the
/// amount; it never clobbers a value the user has already typed on its own.
class _SuggestionHint extends StatelessWidget {
  final double amount;
  final String periodNoun;
  final VoidCallback onAccept;

  const _SuggestionHint({
    required this.amount,
    required this.periodNoun,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return InkWell(
      onTap: onAccept,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(Icons.lightbulb_outline_rounded, size: 16, color: p.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'Suggested: ${CurrencyFormatter.format(amount, showDecimals: false)} based on last $periodNoun',
                style: AppText.caption(p.primary)
                    .copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Text('Use', style: AppText.caption(p.primary)),
          ],
        ),
      ),
    );
  }
}
