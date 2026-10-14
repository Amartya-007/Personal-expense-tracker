/// Shared text-sanitisation rules used by every text field so single-line and
/// multi-line handling stay consistent and testable.
class TextSanitizer {
  TextSanitizer._();

  /// For single-line fields (names, descriptions, search): trim the ends and
  /// collapse every run of whitespace — including newlines and tabs pasted in
  /// — down to a single space.
  static String singleLine(String raw) {
    return raw.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// For multi-line fields (note, SMS paste): trim leading/trailing whitespace
  /// but keep the user's internal newlines and spacing intact.
  static String multiLine(String raw) {
    return raw.trim();
  }
}
