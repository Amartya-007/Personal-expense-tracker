import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart' show DateTimeRange;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/date_filters.dart';
import '../../data/models/analytics_summary_model.dart';
import '../../services/analytics/analytics_service.dart';

final analyticsServiceProvider = Provider((ref) => AnalyticsService());

final selectedDateRangeProvider = StateProvider<DateTimeRangeType>((ref) => DateTimeRangeType.thisMonth);

enum DateTimeRangeType { today, thisWeek, thisMonth, lastMonth }

/// The date range for an Insights period, shared by the summary and trend
/// providers (and the chart labels). It used to be copy-pasted in both.
DateTimeRange insightsRange(DateTimeRangeType type) {
  final label = switch (type) {
    DateTimeRangeType.today => 'Today',
    DateTimeRangeType.thisWeek => 'This Week',
    DateTimeRangeType.thisMonth => 'This Month',
    DateTimeRangeType.lastMonth => 'Last Month',
  };
  return DateFilters.rangeFor(label)!;
}

final analyticsSummaryProvider = FutureProvider<AnalyticsSummaryModel>((ref) async {
  final service = ref.watch(analyticsServiceProvider);
  final rangeType = ref.watch(selectedDateRangeProvider);

  final range = insightsRange(rangeType);
  final start = range.start;
  final end = range.end;

  return await service.getAnalytics(startDate: start, endDate: end);
});

final spendingTrendProvider = FutureProvider<List<FlSpot>>((ref) async {
  final service = ref.watch(analyticsServiceProvider);
  final rangeType = ref.watch(selectedDateRangeProvider);

  final range = insightsRange(rangeType);
  final start = range.start;
  final end = range.end;

  final values = await service.getDailySpendingTrend(startDate: start, endDate: end);
  return List.generate(values.length, (i) => FlSpot(i.toDouble(), values[i]));
});

final homeInsightsProvider = FutureProvider<List<String>>((ref) async {
  final service = ref.watch(analyticsServiceProvider);
  return await service.getHomeInsights();
});
