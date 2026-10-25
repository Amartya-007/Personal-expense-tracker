import 'dart:math' as math;

import '../../core/database/database_helper.dart';
import '../../core/logging/app_logger.dart';
import '../../core/logging/log_category.dart';
import '../../core/utils/currency_formatter.dart';
import '../../data/models/analytics_summary_model.dart';
import '../../data/models/spending_forecast_model.dart';

class AnalyticsService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<AnalyticsSummaryModel> getAnalytics({
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final db = await _dbHelper.database;
      final startMs = startDate.millisecondsSinceEpoch;
      final endMs = endDate.millisecondsSinceEpoch;

      final incRes = await db.rawQuery(
        '''
        SELECT SUM(amount) as total FROM transactions
        WHERE type = 'income' AND date >= ? AND date <= ? AND deleted_at IS NULL
      ''',
        [startMs, endMs],
      );
      final totalIncome = (incRes.first['total'] as num?)?.toDouble() ?? 0.0;

      final expRes = await db.rawQuery(
        '''
        SELECT SUM(amount) as total FROM transactions
        WHERE type = 'expense' AND date >= ? AND date <= ? AND deleted_at IS NULL
      ''',
        [startMs, endMs],
      );
      final totalExpense = (expRes.first['total'] as num?)?.toDouble() ?? 0.0;
      final netSavings = totalIncome - totalExpense;

      // Category breakdown including transaction splits
      final catRes = await db.rawQuery(
        '''
        SELECT 
          cat.id as category_id,
          cat.name as category_name,
          cat.icon as category_icon,
          cat.color as category_color,
          SUM(sub.amount) as total_amount
        FROM (
          SELECT category_id, amount FROM transactions
          WHERE type = 'expense' AND date >= ? AND date <= ? AND deleted_at IS NULL
            AND id NOT IN (SELECT transaction_id FROM transaction_splits)
          UNION ALL
          SELECT s.category_id, s.amount FROM transaction_splits s
          INNER JOIN transactions t ON s.transaction_id = t.id
          WHERE t.type = 'expense' AND t.date >= ? AND t.date <= ? AND t.deleted_at IS NULL
        ) sub
        INNER JOIN categories cat ON sub.category_id = cat.id
        GROUP BY cat.id
        ORDER BY total_amount DESC
      ''',
        [startMs, endMs, startMs, endMs],
      );

      final categoryBreakdown = <CategorySpending>[];
      for (final row in catRes) {
        final amt = (row['total_amount'] as num).toDouble();
        final pct = totalExpense > 0 ? (amt / totalExpense) : 0.0;
        categoryBreakdown.add(
          CategorySpending(
            categoryId: row['category_id'] as String,
            categoryName: row['category_name'] as String,
            categoryIcon: (row['category_icon'] as String?) ?? 'category',
            categoryColor: (row['category_color'] as int?) ?? 0xFF9E9E9E,
            totalAmount: amt,
            percentage: pct,
          ),
        );
      }

      final pmRes = await db.rawQuery(
        '''
        SELECT payment_method, SUM(amount) as total_amount
        FROM transactions
        WHERE type = 'expense' AND date >= ? AND date <= ? AND deleted_at IS NULL
        GROUP BY payment_method
        ORDER BY total_amount DESC
      ''',
        [startMs, endMs],
      );

      final paymentMethodBreakdown = pmRes
          .map(
            (r) => PaymentMethodSpending(
              paymentMethod: (r['payment_method'] as String?) ?? 'Unknown',
              totalAmount: (r['total_amount'] as num).toDouble(),
            ),
          )
          .toList();

      final accRes = await db.rawQuery(
        '''
        SELECT a.id as account_id, a.name as account_name, SUM(t.amount) as total_amount
        FROM transactions t
        INNER JOIN accounts a ON t.account_id = a.id
        WHERE t.type = 'expense' AND t.date >= ? AND t.date <= ? AND deleted_at IS NULL
        GROUP BY a.id
        ORDER BY total_amount DESC
      ''',
        [startMs, endMs],
      );

      final accountBreakdown = accRes
          .map(
            (r) => AccountSpending(
              accountId: r['account_id'] as String,
              accountName: r['account_name'] as String,
              totalAmount: (r['total_amount'] as num).toDouble(),
            ),
          )
          .toList();

      return AnalyticsSummaryModel(
        totalIncome: totalIncome,
        totalExpense: totalExpense,
        netSavings: netSavings,
        categoryBreakdown: categoryBreakdown,
        paymentMethodBreakdown: paymentMethodBreakdown,
        accountBreakdown: accountBreakdown,
      );
    } catch (e, stack) {
      await AppLogger.error('getAnalytics failed', error: e, stackTrace: stack, category: LogCategory.app);
      return AnalyticsSummaryModel(
        totalIncome: 0,
        totalExpense: 0,
        netSavings: 0,
        categoryBreakdown: [],
        paymentMethodBreakdown: [],
        accountBreakdown: [],
      );
    }
  }

  Future<SpendingForecastModel> calculateMonthEndForecast() async {
    try {
      final db = await _dbHelper.database;
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1);
      final monthEnd = DateTime(now.year, now.month + 1, 0, 23, 59, 59, 999);
      final startMs = monthStart.millisecondsSinceEpoch;
      final endMs = monthEnd.millisecondsSinceEpoch;
      final todayMs = now.millisecondsSinceEpoch;

      final expRes = await db.rawQuery(
        '''
        SELECT SUM(amount) as total FROM transactions
        WHERE type = 'expense' AND date >= ? AND date <= ? AND deleted_at IS NULL
      ''',
        [startMs, todayMs],
      );
      final actualSpentSoFar = (expRes.first['total'] as num?)?.toDouble() ?? 0.0;

      final budgetRes = await db.rawQuery(
        '''
        SELECT SUM(amount) as total FROM budgets
        WHERE period = 'monthly'
      ''',
      );
      final monthlyBudgetLimit = (budgetRes.first['total'] as num?)?.toDouble() ?? 0.0;

      final daysElapsed = math.max(1, now.day);
      final totalDaysInMonth = monthEnd.day;
      final dailyRunRate = actualSpentSoFar / daysElapsed;
      final remainingDays = math.max(0, totalDaysInMonth - daysElapsed);

      final recurringRes = await db.rawQuery(
        '''
        SELECT SUM(amount) as total FROM recurring_payments
        WHERE is_active = 1 AND next_due_date >= ? AND next_due_date <= ?
      ''',
        [todayMs, endMs],
      );
      final remainingRecurringDue = (recurringRes.first['total'] as num?)?.toDouble() ?? 0.0;

      final projectedTotalSpend = actualSpentSoFar + (dailyRunRate * remainingDays) + remainingRecurringDue;

      return SpendingForecastModel(
        actualSpentSoFar: actualSpentSoFar,
        projectedTotalSpend: projectedTotalSpend,
        dailyRunRate: dailyRunRate,
        monthlyBudgetLimit: monthlyBudgetLimit,
        daysElapsed: daysElapsed,
        totalDaysInMonth: totalDaysInMonth,
        remainingRecurringDue: remainingRecurringDue,
      );
    } catch (_) {
      return SpendingForecastModel(
        actualSpentSoFar: 0,
        projectedTotalSpend: 0,
        dailyRunRate: 0,
        monthlyBudgetLimit: 0,
        daysElapsed: 1,
        totalDaysInMonth: 30,
        remainingRecurringDue: 0,
      );
    }
  }

  Future<List<double>> getDailySpendingTrend({
    required DateTime startDate,
    required DateTime endDate,
    int dataPoints = 8,
  }) async {
    try {
      final db = await _dbHelper.database;
      final startMs = startDate.millisecondsSinceEpoch;
      final endMs = endDate.millisecondsSinceEpoch;
      final duration = endMs - startMs;
      final step = duration > 0 ? duration ~/ dataPoints : 1;

      final spots = <double>[];
      for (int i = 0; i < dataPoints; i++) {
        final chunkStart = startMs + (i * step);
        final chunkEnd = (i == dataPoints - 1) ? endMs : (chunkStart + step);

        final res = await db.rawQuery(
          '''
          SELECT SUM(amount) as total FROM transactions
          WHERE type = 'expense' AND date >= ? AND date < ? AND deleted_at IS NULL
        ''',
          [chunkStart, chunkEnd],
        );

        final sum = (res.first['total'] as num?)?.toDouble() ?? 0.0;
        spots.add(sum);
      }
      return spots;
    } catch (_) {
      return List.filled(dataPoints, 0.0);
    }
  }

  Future<List<String>> getHomeInsights() async {
    try {
      final now = DateTime.now();
      final weekStart = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: now.weekday - 1));

      final db = await _dbHelper.database;

      final foodRes = await db.rawQuery(
        '''
        SELECT SUM(t.amount) as total
        FROM transactions t
        INNER JOIN categories c ON t.category_id = c.id
        WHERE LOWER(c.name) LIKE '%food%'
          AND t.type = 'expense'
          AND t.date >= ?
          AND t.deleted_at IS NULL
      ''',
        [weekStart.millisecondsSinceEpoch],
      );

      final foodAmt = (foodRes.first['total'] as num?)?.toDouble() ?? 0.0;

      final forecast = await calculateMonthEndForecast();

      final insights = <String>[];
      if (foodAmt > 0) {
        insights.add(
          'You spent ${CurrencyFormatter.format(foodAmt)} on Food this week.',
        );
      }
      if (forecast.monthlyBudgetLimit > 0) {
        if (forecast.isOverBudget) {
          insights.add(
            '⚠️ Projected to exceed monthly budget by ${CurrencyFormatter.format(forecast.varianceFromBudget)}.',
          );
        } else {
          insights.add(
            '✅ On track for month-end (projected spend: ${CurrencyFormatter.format(forecast.projectedTotalSpend)}).',
          );
        }
      }

      if (insights.isEmpty) {
        insights.add('Log your expenses to unlock personalized spending forecasts.');
      }

      return insights;
    } catch (e, stack) {
      await AppLogger.error('getHomeInsights failed', error: e, stackTrace: stack, category: LogCategory.app);
      return ['Unable to load insights right now.'];
    }
  }
}
