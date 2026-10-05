import 'package:flutter/material.dart';

/// Named date ranges used by the Transactions quick chips and filter sheet.
///
/// Ranges end at the *last millisecond* of the final day. The repository
/// filters with `date <= end`, so the old midnight end dates silently dropped
/// everything recorded during the last day of "Last Month" (and any time
/// after "now" today).
class DateFilters {
  DateFilters._();

  static const String all = 'All';
  static const List<String> options = [
    all,
    'Today',
    'This Week',
    'This Month',
    'Last Month',
  ];

  static DateTime _endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  /// The range for [filter], or null for "All"/unknown (meaning no filter).
  static DateTimeRange? rangeFor(String? filter, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);

    switch (filter) {
      case 'Today':
        return DateTimeRange(start: today, end: _endOfDay(today));
      case 'This Week':
        final monday = DateTime(today.year, today.month, today.day - (today.weekday - 1));
        return DateTimeRange(start: monday, end: _endOfDay(today));
      case 'This Month':
        return DateTimeRange(
          start: DateTime(n.year, n.month, 1),
          end: _endOfDay(today),
        );
      case 'Last Month':
        return DateTimeRange(
          start: DateTime(n.year, n.month - 1, 1),
          end: _endOfDay(DateTime(n.year, n.month, 0)),
        );
      default:
        return null;
    }
  }
}
