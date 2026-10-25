import 'log_category.dart';
import 'log_level.dart';

/// Which log entries the Logs screen (and the repository query) should return.
class LogFilter {
  /// Free text matched against the message and category.
  final String? query;
  final LogLevel? level;
  final LogCategory? category;

  const LogFilter({this.query, this.level, this.category});

  /// The trimmed query, or null when there is nothing to search for.
  String? get normalizedQuery {
    final q = query?.trim();
    return (q == null || q.isEmpty) ? null : q;
  }

  bool get isActive =>
      normalizedQuery != null || level != null || category != null;

  /// Pass `clearX: true` to reset a field to "no filter" (a plain null means
  /// "keep the current value").
  LogFilter copyWith({
    String? query,
    LogLevel? level,
    LogCategory? category,
    bool clearQuery = false,
    bool clearLevel = false,
    bool clearCategory = false,
  }) => LogFilter(
    query: clearQuery ? null : (query ?? this.query),
    level: clearLevel ? null : (level ?? this.level),
    category: clearCategory ? null : (category ?? this.category),
  );

  @override
  bool operator ==(Object other) =>
      other is LogFilter &&
      other.normalizedQuery == normalizedQuery &&
      other.level == level &&
      other.category == category;

  @override
  int get hashCode => Object.hash(normalizedQuery, level, category);
}
