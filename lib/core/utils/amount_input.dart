import 'package:flutter/services.dart';

import 'currency_formatter.dart';

/// Hard cap for every stored monetary amount: ₹999,999,999,999 (~1e12).
///
/// Chosen as a single, named upper bound that stays safely within the range
/// where an IEEE-754 double represents integers exactly (2^53 ≈ 9.0e15) and
/// is far above any realistic personal-finance value. Every amount field and
/// the "cannot exceed" message share this constant.
const double kMaxAmount = 999999999999;

/// Default number of decimal places allowed for an amount.
const int kAmountDecimals = 2;

/// Shared amount input helpers: a reusable [TextInputFormatter] list that
/// bounds what can be typed OR pasted into a numeric field, plus pure
/// validation/parsing used by every amount field at the UI and save boundary.
///
/// Keyboard type is not validation (the user can paste), so the formatters run
/// on every edit (including paste) and the validators re-check the final value.
class AmountInput {
  AmountInput._();

  /// Formatters for a numeric amount field. Allow only digits, a single
  /// decimal separator, up to [decimals] fractional digits, and an optional
  /// single leading `-` when [allowNegative]. Runs on paste too.
  static List<TextInputFormatter> amountFormatters({
    int decimals = kAmountDecimals,
    bool allowNegative = false,
  }) {
    return [
      FilteringTextInputFormatter.allow(RegExp(r'[0-9.\-]')),
      _DecimalLimitFormatter(decimals: decimals, allowNegative: allowNegative),
    ];
  }

  /// Validates a raw amount string, returning a specific error message or null
  /// when the value is acceptable. The order of checks matters so the most
  /// useful message surfaces first.
  static String? validateAmount(
    String raw, {
    bool allowZero = false,
    double? max = kMaxAmount,
    bool allowNegative = false,
  }) {
    final trimmed = raw.trim().replaceAll(',', '');
    if (trimmed.isEmpty) return 'Enter a valid amount.';

    // Only digits, an optional leading '-', and a single '.' are acceptable.
    // This rejects scientific notation ('12e9'), stray symbols, etc. even if a
    // field's formatters are bypassed (paste/save boundary).
    if (!RegExp(r'^-?\d*\.?\d*$').hasMatch(trimmed)) {
      return 'Enter a valid amount.';
    }

    // Too many decimal places.
    final dot = trimmed.indexOf('.');
    if (dot != -1 && trimmed.length - dot - 1 > kAmountDecimals) {
      return 'Enter a valid amount.';
    }

    final value = double.tryParse(trimmed);
    if (value == null || value.isNaN || value.isInfinite) {
      return 'Enter a valid amount.';
    }
    if (!allowNegative && value < 0) return 'Enter a valid amount.';
    if (!allowZero && value == 0) return 'Enter an amount greater than zero.';
    if (max != null && value.abs() > max) {
      return 'Amount cannot exceed ${CurrencyFormatter.format(max, showDecimals: false)}.';
    }
    return null;
  }

  /// The single safe parse used by callers after [validateAmount] passes.
  /// Returns the value, or null for junk / NaN / Infinity / over-cap / an
  /// unexpected negative.
  static double? parseAmount(String raw, {bool allowNegative = false}) {
    final trimmed = raw.trim().replaceAll(',', '');
    if (trimmed.isEmpty) return null;
    if (!RegExp(r'^-?\d*\.?\d*$').hasMatch(trimmed)) return null;
    final value = double.tryParse(trimmed);
    if (value == null || value.isNaN || value.isInfinite) return null;
    if (!allowNegative && value < 0) return null;
    if (value.abs() > kMaxAmount) return null;
    return value;
  }
}

/// Rejects an edit (keeps the old value) when the candidate would have more
/// than one `.`, more than one `-`, a `-` anywhere but position 0, a `-` when
/// negatives are disallowed, or more than [decimals] fractional digits.
class _DecimalLimitFormatter extends TextInputFormatter {
  final int decimals;
  final bool allowNegative;

  const _DecimalLimitFormatter({
    required this.decimals,
    required this.allowNegative,
  });

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final text = newValue.text;
    if (text.isEmpty) return newValue;

    if ('.'.allMatches(text).length > 1) return oldValue;

    final minusCount = '-'.allMatches(text).length;
    if (minusCount > 1) return oldValue;
    if (minusCount == 1 && (!allowNegative || text.indexOf('-') != 0)) {
      return oldValue;
    }

    final dot = text.indexOf('.');
    if (dot != -1 && text.length - dot - 1 > decimals) return oldValue;

    return newValue;
  }
}
