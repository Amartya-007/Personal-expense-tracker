import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'account_providers.dart';
import 'budget_providers.dart';
import 'category_providers.dart';
import 'insights_providers.dart';
import 'receipt_providers.dart';
import 'recurring_providers.dart';
import 'sms_review_providers.dart';
import 'tag_providers.dart';
import 'transaction_providers.dart';

/// Reloads everything that is read from the database. Call it after an
/// operation that replaces data wholesale (restore, import, delete all), so
/// screens show the new data without restarting the app.
Future<void> refreshAllAppData(WidgetRef ref) async {
  ref.invalidate(recentTransactionsProvider);
  ref.invalidate(recentlyDeletedTransactionsProvider);
  ref.invalidate(homeInsightsProvider);
  ref.invalidate(analyticsSummaryProvider);
  ref.invalidate(spendingTrendProvider);
  ref.invalidate(categoriesListProvider);
  ref.invalidate(expenseCategoriesProvider);
  ref.invalidate(incomeCategoriesProvider);
  ref.invalidate(tagsListProvider);
  ref.invalidate(receiptGalleryProvider);
  // The SMS review queue is stored in the same database. Invalidating the
  // whole family only drops the in-memory copies; they reload on next use.
  ref.invalidate(smsQueueProvider);

  await Future.wait([
    ref.read(transactionListProvider.notifier).fetchInitial(),
    ref.read(accountListProvider.notifier).loadAccounts(),
    ref.read(budgetListProvider.notifier).loadBudgets(),
    ref.read(recurringListProvider.notifier).loadRecurringPayments(),
  ]);
}
