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
    'Yesterday',
    'This Week',
    'Last 7 Days',
    'This Month',
    'Last Month',
    'Last 30 Days',
    'Last 90 Days',
    'This Year',
    'Custom',
  ];

  static DateTime _startOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 0, 0, 0, 0);

  static DateTime _endOfDay(DateTime d) =>
      DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  /// The range for [filter], or null for "All"/unknown (meaning no filter).
  static DateTimeRange? rangeFor(
    String? filter, {
    DateTimeRange? customRange,
    DateTime? now,
  }) {
    if (filter == null || filter == all) return null;
    final n = now ?? DateTime.now();
    final today = _startOfDay(n);

    switch (filter) {
      case 'Today':
        return DateTimeRange(start: today, end: _endOfDay(today));
      case 'Yesterday':
        final yday = today.subtract(const Duration(days: 1));
        return DateTimeRange(start: yday, end: _endOfDay(yday));
      case 'This Week':
        final monday = today.subtract(Duration(days: today.weekday - 1));
        return DateTimeRange(start: monday, end: _endOfDay(today));
      case 'Last 7 Days':
        final start = today.subtract(const Duration(days: 6));
        return DateTimeRange(start: start, end: _endOfDay(today));
      case 'This Month':
        return DateTimeRange(
          start: DateTime(n.year, n.month, 1),
          end: _endOfDay(today),
        );
      case 'Last Month':
        final firstOfThisMonth = DateTime(n.year, n.month, 1);
        final lastOfLastMonth = firstOfThisMonth.subtract(const Duration(days: 1));
        final firstOfLastMonth = DateTime(lastOfLastMonth.year, lastOfLastMonth.month, 1);
        return DateTimeRange(
          start: firstOfLastMonth,
          end: _endOfDay(lastOfLastMonth),
        );
      case 'Last 30 Days':
        final start = today.subtract(const Duration(days: 29));
        return DateTimeRange(start: start, end: _endOfDay(today));
      case 'Last 90 Days':
        final start = today.subtract(const Duration(days: 89));
        return DateTimeRange(start: start, end: _endOfDay(today));
      case 'This Year':
        return DateTimeRange(
          start: DateTime(n.year, 1, 1),
          end: _endOfDay(today),
        );
      case 'Custom':
        if (customRange != null) {
          return DateTimeRange(
            start: _startOfDay(customRange.start),
            end: _endOfDay(customRange.end),
          );
        }
        return null;
      default:
        return customRange;
    }
  }
}
