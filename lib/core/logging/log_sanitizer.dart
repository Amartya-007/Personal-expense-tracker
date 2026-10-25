/// Removes sensitive data from text before it is stored in the local log.
///
/// Call sites are expected not to pass sensitive data in the first place;
/// this is the safety net for what slips through (exception messages that
/// echo input, SQL errors that list bound values, and so on).
class LogSanitizer {
  LogSanitizer._();

  static const int maxMessageLength = 500;
  static const int maxDetailsLength = 4000;
  static const int maxErrorLength = 1500;
  static const int maxStackTraceLength = 8000;

  /// `password: x`, `"token": "x"`, `otp=123456` ...
  static final RegExp _secretPair = RegExp(
    r'''\b(password|passwd|pwd|pin|otp|cvv|cvc|token|secret|api[_-]?key|auth(?:orization)?)\b(["']?\s*[:=]\s*)("[^"]*"|'[^']*'|[^\s,;&]+)''',
    caseSensitive: false,
  );
  static final RegExp _bearer = RegExp(
    r'\bBearer\s+[A-Za-z0-9._~+/=-]+',
    caseSensitive: false,
  );
  static final RegExp _jwt = RegExp(
    r'\beyJ[A-Za-z0-9_-]{5,}\.[A-Za-z0-9_-]{5,}\.[A-Za-z0-9_-]*',
  );
  // Bound SQL arguments: sqflite exceptions print `args [..values..]`.
  static final RegExp _boundArgs = RegExp(
    r'\b(args|arguments|params|parameters)\s*[:=]?\s*\[[^\n]*',
    caseSensitive: false,
  );
  // Emails and UPI ids (name@bank).
  static final RegExp _email = RegExp(r'[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+');
  static final RegExp _amount = RegExp(
    r'(?:₹|Rs\.?|INR)\s*\d[\d,]*(?:\.\d+)?',
    caseSensitive: false,
  );
  // Indian mobile numbers.
  static final RegExp _phone = RegExp(
    r'(?<!\d)(?:\+91[ -]?|0)?[6-9]\d{4}[ -]?\d{5}(?!\d)',
  );
  // Card-style groups of four digits.
  static final RegExp _groupedDigits = RegExp(
    r'(?<!\d)\d{4}(?:[ -]\d{4}){2,4}(?!\d)',
  );
  // Any other run of 9-19 digits (account / card numbers).
  static final RegExp _longDigits = RegExp(r'(?<!\d)\d{9,19}(?!\d)');
  // Very long unbroken tokens (API keys, access tokens). UUIDs are 36 chars.
  static final RegExp _longToken = RegExp(r'\b[A-Za-z0-9_-]{40,}\b');

  /// `12345678901234` -> `****1234`. Use for account / card references.
  static String maskIdentifier(String? value, {int visible = 4}) {
    final digits = (value ?? '').replaceAll(RegExp(r'\s+'), '');
    if (digits.isEmpty) return '****';
    if (digits.length <= visible) return '****';
    return '****${digits.substring(digits.length - visible)}';
  }

  /// Redacts sensitive patterns and caps the length at [maxLength].
  static String sanitize(String input, {int maxLength = maxDetailsLength}) {
    var s = input;
    s = s.replaceAllMapped(_secretPair, (m) => '${m[1]}${m[2]}[redacted]');
    s = s.replaceAll(_bearer, 'Bearer [redacted]');
    s = s.replaceAll(_jwt, '[token]');
    s = s.replaceAllMapped(_boundArgs, (m) => '${m[1]} [redacted]');
    s = s.replaceAll(_email, '[email]');
    s = s.replaceAll(_amount, '[amount]');
    s = s.replaceAll(_phone, '[phone]');
    s = s.replaceAllMapped(_groupedDigits, (m) => _lastFour(m[0]!));
    s = s.replaceAllMapped(_longDigits, (m) => _lastFour(m[0]!));
    s = s.replaceAll(_longToken, '[redacted]');
    if (s.length > maxLength) {
      final dropped = s.length - maxLength;
      s = '${s.substring(0, maxLength)}… [truncated $dropped chars]';
    }
    return s;
  }

  static String? sanitizeNullable(String? input, {required int maxLength}) {
    if (input == null || input.trim().isEmpty) return null;
    return sanitize(input, maxLength: maxLength);
  }

  /// Text for an error object. A [FormatException] normally echoes the text
  /// it failed to parse (e.g. part of an imported file), so only its message
  /// and offset are kept.
  static String describeError(Object error) {
    if (error is FormatException) {
      final offset = error.offset;
      return 'FormatException: ${error.message}'
          '${offset != null ? ' (at offset $offset)' : ''}';
    }
    return error.toString();
  }

  static String _lastFour(String digitsWithSeparators) {
    final digits = digitsWithSeparators.replaceAll(RegExp(r'[^0-9]'), '');
    return '****${digits.substring(digits.length - 4)}';
  }
}
