# MyKhata 2.0 — Phase 4 Implementation Plan

Branch: `redesign/mykhata-2.0` (HEAD d78d508). Do NOT create a worktree/branch. Do NOT push.
Build/verify command: `flutter test` (Flutter project; sqflite_common_ffi is already a dependency for DB-backed tests).
Static analysis: `flutter analyze`.
Formatting: committed Dart is not dart-format-clean; the editor reflows on save. After editing a file, run `dart format` on it — the reflow is ACCEPTED, do not fight it.

## Ground-truth facts established during exploration

- `IconSquareButton` already exists (`lib/presentation/widgets/icon_square_button.dart`) and is used in `budget_list_screen.dart`. The findings report calling it "missing" is stale; reuse it.
- Balance adjustment seam: `homeControllerProvider` (`lib/presentation/providers/home_controller.dart`) `updateAccountBalance(accountId, newBalance)` → `accountListProvider.notifier.updateAccountBalanceDirect(...)` → `AccountRepository.updateAccountBalanceDirect(id, newBalance, reason:)`. This is the method that RECORDS an adjustment. Home's `_editBalance` (in `home_screen.dart`) is the existing `showFieldsSheet`-based flow that calls it.
- Recurring: `recurringListProvider` (`recurring_providers.dart`) exposes `AsyncValue<List<RecurringPaymentModel>>`; model has `nextDueDate` (DateTime) and `isActive` (bool). No new fields needed for "due this week".
- Home attention zone order today (in `home_screen.dart` `build`): SMS card (if `smsCount > 0`) → budget-exceeded card (inline `...()` block over `budgetsAsync`) → `_ThisMonthStrip`. Spacing uses `AppSpacing` and literal `const SizedBox(height: 14)`.
- Summary numbers seam: `homeMonthSummaryProvider` (`insights_providers.dart`) returns `AnalyticsSummaryModel` (totalIncome/totalExpense/netSavings). Total balance is derived in `_HeroCard` by folding `accountListProvider`. Attention inputs today: `smsQueueProvider('detected')` length, budget-exceeded derived inline from `budgetListProvider`.
- Analytics seam for budgets: `AnalyticsService.getAnalytics(startDate, endDate)` (`services/analytics/analytics_service.dart`) returns `categoryBreakdown: List<CategorySpending>` with per-category `categoryId` + `totalAmount`, correctly accounting for splits and deletes. This covers suggested-limit AND history with NO new SQL/schema.
- Period windows: `BudgetRepository.currentWindow(period, storedStart, storedEnd, {now})` (static) returns the calendar-aligned `(start, end)` for weekly/monthly/yearly for a given `now`. Shift `now` back to get a previous period window — reuse this, do not re-derive date math.
- Tests live in `test/` mirroring `lib/`, use `package:flutter_test`. Existing unit tests under `test/unit/`. Current suite is green at d78d508.

## No-migration guarantee

All four features are achievable with EXISTING persisted fields and EXISTING query methods (`getAnalytics`, `currentWindow`, `recurringListProvider`, `updateAccountBalanceDirect`). No feature below requires a new column, table, or migration. If any implementer discovers a case that seems to need one, STOP and `send_message` severity `warning` with the needed change + the no-migration alternative BEFORE writing a migration.

---

# Ordered plan

Order rationale: Items 1–3 all touch Home/providers and share the attention zone; building the attention input (bills-due) before the composed provider lets the composed provider absorb it. Item 1 (Accounts balance) is independent but small, done first. Items 7–8 (budgets) are isolated to the budgets feature and come last.

## Feature A — Home & Accounts (items 1–6)

- [ ] 1. Extract the "Edit balance" flow into a shared helper so both Home and Accounts call identical logic.
      Create a top-level helper `editAccountBalance(BuildContext, WidgetRef, AccountModel)` that runs the existing `showFieldsSheet` ("Edit {name} balance" / "Save balance" / initial = `currentBalance.toStringAsFixed(2)`), parses the amount, and calls `ref.read(homeControllerProvider.notifier).updateAccountBalance(account.id, newBalance)` with the same snackbar messaging ("Adjustment recorded for {name}" / "Could not update {name} balance"). Place it in a new small file `lib/presentation/screens/settings/account_balance_actions.dart` (or `lib/presentation/widgets/account_balance_sheet.dart`) so both screens import it. Do NOT duplicate the adjustment math — it stays inside `homeControllerProvider.updateAccountBalance`.
      Files: new `lib/presentation/screens/settings/account_balance_actions.dart`; `lib/presentation/screens/home/home_screen.dart` (replace `_editBalance` body with a call to the helper, keep the account-chip wiring).
      Verify: `flutter analyze` clean on both files; `flutter test` still green.

- [ ] 2. Add an "Adjust balance" affordance to each row on the Accounts management screen.
      In `accounts_management_screen.dart`, give each `ListRowTile` an `onTap` that calls the shared `editAccountBalance(context, ref, acc)` from item 1, OR add a trailing `IconButton` (tooltip "Adjust balance", icon `Icons.tune_rounded` or `Icons.edit_rounded`) alongside the existing star/delete buttons. Prefer row `onTap` (simplest, discoverable) and keep the star + delete trailing buttons. This records an adjustment via the SAME provider path the Home chip uses — the audit/adjustment record is created identically.
      Files: `lib/presentation/screens/settings/accounts_management_screen.dart`.
      Verify: `flutter analyze` clean; `flutter test` green. Home account-chip adjustment path is unchanged (still calls the shared helper).

- [ ] 3. Add a pure "bills due this week" selector usable by Home and by the composed provider (item 5).
      Add a small pure function (testable, no widgets) that, given a `List<RecurringPaymentModel>` and a `now`, returns the count/list of active rules whose `nextDueDate` is within `[startOfToday, startOfToday + 7 days]` (inclusive of today, next 7 days). Put it next to recurring state: add `int dueWithinDays(List<RecurringPaymentModel> items, {int days = 7, DateTime? now})` (filter `isActive && !nextDueDate.isBefore(startOfToday) && !nextDueDate.isAfter(startOfToday.add(Duration(days: days)))`) in `lib/presentation/providers/recurring_providers.dart` as a top-level function (or a `recurring_due.dart` helper imported by it). Do NOT add persisted fields.
      Files: `lib/presentation/providers/recurring_providers.dart` (or new `lib/presentation/providers/recurring_due.dart`).
      Verify: new unit test (item 4) passes.

- [ ] 4. Unit-test the bills-due selector.
      Add `test/unit/recurring_due_test.dart` covering: a rule due today counts; due in exactly 7 days counts; due in 8 days excluded; due yesterday excluded; inactive rule excluded; empty list → 0. Build `RecurringPaymentModel`s inline (constructor only, no DB). Follow the pattern in `test/unit/transaction_calculation_test.dart` (`package:flutter_test`, `group`/`test`/`expect`).
      Files: new `test/unit/recurring_due_test.dart`.
      Verify: `flutter test test/unit/recurring_due_test.dart` passes; full `flutter test` green.

- [ ] 5. Add the "N bills due this week" attention item to Home's attention zone.
      In `home_screen.dart` `build`, read `recurringListProvider` (already watched as `recurringAsync`) and compute `billsDue = dueWithinDays(recurringAsync.value ?? const [], now: DateTime.now())`. When `billsDue > 0`, render a compact tappable `_BillsDueAttentionCard` modeled on `_SmsAttentionCard`/`_BudgetAlertCard` (same `AppCard`, 44×44 leading chip, title "N bills due this week" / subtitle "Tap to review upcoming payments", chevron). Behavior on tap: navigate to `RecurringPaymentsScreen` via `AppRoutes.push(context, const RecurringPaymentsScreen())` — chosen as the simplest correct behavior (the "Upcoming recurring" section stays as the on-Home detail; no scroll-targeting plumbing needed). Order the attention items: SMS to review → bills due → budget exceeded. Keep spacing consistent with the existing `const SizedBox(height: 14)` separators, and ensure each item (including the new one) is only emitted when its condition holds so the zone still collapses to nothing when all three are clear.
      Keep the existing "Upcoming recurring" section exactly as-is.
      Files: `lib/presentation/screens/home/home_screen.dart`.
      Verify: `flutter analyze` clean; `flutter test` green. Manual reasoning check: with zero SMS, zero over-budgets, zero due-soon, no attention cards render and the month strip sits directly under the hero.

- [ ] 6. Introduce a single composed Home-overview snapshot provider and read it from Home's top region.
      Create `lib/presentation/providers/home_overview_provider.dart` exposing an immutable `HomeOverview` snapshot class (fields: `double totalBalance`, `double monthIncome`, `double monthExpense`, `double monthNet`, `int pendingSmsCount`, `int billsDueCount`, `List<BudgetModel> exceededBudgets`) and a `homeOverviewProvider` that COMPOSES existing providers — it must NOT run new SQL:
        - `totalBalance` = fold of `accountListProvider` balances;
        - `monthIncome/Expense/Net` from `homeMonthSummaryProvider`;
        - `pendingSmsCount` from `smsQueueProvider('detected')` length;
        - `billsDueCount` = `dueWithinDays(recurringListProvider value)` (item 3);
        - `exceededBudgets` = `budgetListProvider` filtered by `overAmount > 0 || usedRatio >= 1.0` (same predicate used inline on Home today).
      Implement as a `Provider<HomeOverview>` (or `FutureProvider`) that `ref.watch`es those providers and builds one snapshot, so the hero total + month strip + attention zone derive from ONE consistent read and update together when dependencies refresh. Do NOT change any number's meaning or calculation — composition only. Preserve the no-flicker behavior: `_ThisMonthStrip` currently uses `.when(skipLoadingOnReload: true, ...)`; keep that behavior (either keep reading `homeMonthSummaryProvider` inside the strip through the composed snapshot, or carry the `AsyncValue` state so loading-on-reload is skipped). After a transaction mutation the existing `_refreshDependents()` already invalidates `accountListProvider`/`homeMonthSummaryProvider`/`budgetListProvider`/etc., which will recompute the composed provider — no new invalidation wiring required, but confirm Home's `refresh()` and `_refreshDependents()` still cover every input.
      Rewire Home: the attention zone (SMS/bills/budget), `_HeroCard` total, and `_ThisMonthStrip` figures read from `homeOverviewProvider` instead of each watching its own provider directly. Keep widgets dumb (just read the snapshot); the composition lives in the provider layer per flutter-apply-architecture-best-practices. Recent-transactions list and the full recurring section MAY stay on their own providers (composing them is disproportionate — scope is the small flickering summary numbers).
      Files: new `lib/presentation/providers/home_overview_provider.dart`; `lib/presentation/screens/home/home_screen.dart`.
      Verify: `flutter analyze` clean; `flutter test` green. Add `test/unit/home_overview_test.dart` asserting the `HomeOverview`/snapshot composition logic that is pure (e.g. the exceeded-budget predicate and bills-due count given fixture lists). If the composition is a thin `ref.watch` with no pure core, extract the pure combine step into a top-level function and test that.
      DECISION NOTE: composed provider depends on existing providers; it does not re-query the DB. Rationale: eliminates the momentary disagreement the findings report flags (§14 "Data-flow fragmentation") without changing analytics.

## Feature B — Budget enhancements (items 7–9)

- [ ] 7. Add a per-category previous-period spend reader for the suggested limit.
      Add a provider/helper that, given a `categoryId` and a `period` ('weekly'/'monthly'/'yearly'), returns that category's actual spend in the PREVIOUS period of the same type. Reuse existing infra: compute the previous window with `BudgetRepository.currentWindow(period, now, now, now: <nowShiftedBackOnePeriod>)` (weekly → now-7d; monthly → first day of last month; yearly → now-1y; use the same shifting the window helper already encodes), then call `AnalyticsService.getAnalytics(startDate: window.start, endDate: window.end)` and read `categoryBreakdown.firstWhere((c) => c.categoryId == categoryId).totalAmount` (0.0 if absent). Expose as `suggestedBudgetLimitProvider` family keyed by `(categoryId, period)` in `budget_providers.dart`, OR a method on a small `BudgetSuggestionService`. Do NOT add schema; this is a read over existing data.
      Files: `lib/presentation/providers/budget_providers.dart` (add the provider) and/or new `lib/services/analytics/` reuse — prefer provider that calls existing `analyticsServiceProvider`.
      Verify: `flutter analyze` clean. Unit test in item 9. If previous-period-per-category genuinely cannot be read this way, STOP and `send_message` warning, then ship items 1–6 + 8 without the suggestion.

- [ ] 8. Wire the suggested limit into the budget creation form.
      In `budget_form.dart`, when the selected category/period changes (and on first build), fetch the suggested limit (item 7) and show it as an accept-or-overwrite hint under the Limit field: e.g. a tappable chip/text "Suggested: ₹X based on last {period noun}" that, when tapped, prefills `_amount` with X. Do NOT auto-overwrite a value the user has already typed; only prefill when the field is empty or on explicit tap. `BudgetForm` is a `StatefulWidget` without a `WidgetRef`; convert it to `ConsumerStatefulWidget` (it is created inside `AppBottomSheet.show` from `budget_list_screen.dart`, which already has Riverpod in scope) OR pass the suggestion in from the caller which has `ref`. Prefer passing a `Future<double> Function(String categoryId, String period)` suggestion callback from `budget_list_screen.dart` (which has `ref`) into `BudgetForm` to keep the form widget free of provider plumbing — cleaner per architecture guide. Period noun map already exists in `budget_list_screen.dart` (`_periodNoun`); reuse the pattern.
      Files: `lib/presentation/screens/budgets/budget_form.dart`, `lib/presentation/screens/budgets/budget_list_screen.dart`.
      Verify: `flutter analyze` clean; `flutter test` green. Manual check: opening Create budget for a category with prior-period spend shows the suggestion; tapping it fills the limit; typing a value is not clobbered.

- [ ] 9. Add lightweight per-budget history to the budget detail sheet, with a unit test for the history computation.
      Add a pure helper `budgetHistory(...)` that, for a given category + period, computes the used-% (or spent-vs-limit) for the last N (3) periods by: for each of the last N windows (shift `now` back k periods, `BudgetRepository.currentWindow(period, now, now, now: shifted)`), call `AnalyticsService.getAnalytics` for that window and read the category's `totalAmount`, dividing by the budget's current `amount`. Put the window-shifting + percentage math in a pure function (inputs: list of per-period spends + limit → list of percentages/labels) so it is unit-testable without a DB. In `_showBudgetDetail` (`budget_list_screen.dart`) render a compact history row BELOW the progress bar: a small list/row like "Oct: 92% · Sep: 78% · Aug: 110%" using `AppText.caption`, or a simple bar row (fl_chart is already a dependency and MAY be reused for a sparkline, but a plain bar/text row is sufficient and preferred for calm visuals). Keep Phase-3 calm: no new gradients/shadows, use `AppSpacing`/`AppText`, single edge signal.
      Files: new helper (co-locate with item 7, e.g. `lib/presentation/providers/budget_providers.dart` or `lib/services/analytics/budget_history.dart`); `lib/presentation/screens/budgets/budget_list_screen.dart`; `test/unit/budget_history_test.dart`.
      Verify: `flutter test test/unit/budget_history_test.dart` passes (pure percentage/label computation: e.g. spend [920,780,1100] with limit 1000 → ["92%","78%","110%"], and over-limit stays >100%); full `flutter test` green. If prior-period recomputation is not feasible with existing data, STOP and `send_message` warning, then skip just this sub-item (ship 1–8).

## Final verification (whole phase)

- [ ] 10. Run the full suite and static analysis; format changed files.
      Commands: `flutter analyze` (expect no new errors), `flutter test` (all ~103 existing tests + new tests green), `dart format lib/presentation/screens/home/home_screen.dart lib/presentation/screens/settings/accounts_management_screen.dart lib/presentation/screens/budgets/budget_form.dart lib/presentation/screens/budgets/budget_list_screen.dart lib/presentation/providers/home_overview_provider.dart lib/presentation/providers/recurring_providers.dart lib/presentation/providers/budget_providers.dart` (and any new files). Reflow is accepted.
      Verify: both commands succeed; working tree contains only intended Phase-4 changes.

## Constraints reminder (apply to every item)

- Prefer existing model fields and providers; reuse adjustment/recurring/budget/analytics logic — never duplicate business logic in widgets.
- NO silent DB migrations/schema changes — raise a `warning` first with a no-migration alternative.
- Preserve Phase-3 visual calm: no new gradients/heavy shadows; use `AppSpacing`/`AppRadius`/`IconSquareButton`; content cards keep a single edge signal.
- Do NOT restructure navigation, bottom nav, or the FAB/speed-dial.
- Keep all functionality and the full test suite passing.
