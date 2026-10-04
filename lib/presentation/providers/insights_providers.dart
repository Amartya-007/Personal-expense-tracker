import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/analytics_summary_model.dart';
import '../../services/analytics/analytics_service.dart';

final analyticsServiceProvider = Provider((ref) => AnalyticsService());

final selectedDateRangeProvider = StateProvider<DateTimeRangeType>((ref) => DateTimeRangeType.thisMonth);

enum DateTimeRangeType { today, thisWeek, thisMonth, lastMonth }

final analyticsSummaryProvider = FutureProvider<AnalyticsSummaryModel>((ref) async {
  final service = ref.watch(analyticsServiceProvider);
  final rangeType = ref.watch(selectedDateRangeProvider);

  final now = DateTime.now();
  late DateTime start;
  late DateTime end;

  switch (rangeType) {
    case DateTimeRangeType.today:
      start = DateTime(now.year, now.month, now.day);
      end = DateTime(now.year, now.month, now.day, 23, 59, 59);
      break;
    case DateTimeRangeType.thisWeek:
      start = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
      end = DateTime(now.year, now.month, now.day, 23, 59, 59);
      break;
    case DateTimeRangeType.thisMonth:
      start = DateTime(now.year, now.month, 1);
      end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      break;
    case DateTimeRangeType.lastMonth:
      start = DateTime(now.year, now.month - 1, 1);
      end = DateTime(now.year, now.month, 0, 23, 59, 59);
      break;
  }

  return await service.getAnalytics(startDate: start, endDate: end);
});

final spendingTrendProvider = FutureProvider<List<FlSpot>>((ref) async {
  final service = ref.watch(analyticsServiceProvider);
  final rangeType = ref.watch(selectedDateRangeProvider);

  final now = DateTime.now();
  late DateTime start;
  late DateTime end;

  switch (rangeType) {
    case DateTimeRangeType.today:
      start = DateTime(now.year, now.month, now.day);
      end = DateTime(now.year, now.month, now.day, 23, 59, 59);
      break;
    case DateTimeRangeType.thisWeek:
      start = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
      end = DateTime(now.year, now.month, now.day, 23, 59, 59);
      break;
    case DateTimeRangeType.thisMonth:
      start = DateTime(now.year, now.month, 1);
      end = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
      break;
    case DateTimeRangeType.lastMonth:
      start = DateTime(now.year, now.month - 1, 1);
      end = DateTime(now.year, now.month, 0, 23, 59, 59);
      break;
  }

  final values = await service.getDailySpendingTrend(startDate: start, endDate: end);
  return List.generate(values.length, (i) => FlSpot(i.toDouble(), values[i]));
});

final homeInsightsProvider = FutureProvider<List<String>>((ref) async {
  final service = ref.watch(analyticsServiceProvider);
  return await service.getHomeInsights();
});
