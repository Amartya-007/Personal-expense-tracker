# MyKhata 2.0 — Phase 1 UX review

Phase 1 of the five-phase redesign landed as a single commit (`e317fcd`) on `redesign/mykhata-2.0`, touching exactly the three intended files: the add/edit transaction form, the Home screen, and the Transactions history screen. The change removes two kinds of friction — an expense-only gate on optional fields, and a redundant Recently-deleted entry point — and converts the always-on Home Budgets preview into an attention-only alert. The large line counts in the diff stat (542 insertions / 340 deletions across 3 files) are dominated by `dart format` re-wrapping of long expression lines; the actual behavioral surface is small and matches the plan.

**Watch for:** nothing blocking. The diff is noisy because an on-save reformat re-flowed many untouched lines, which makes the behavioral delta harder to eyeball but does not change behavior (confirmed by reading the resulting source, not just the diff).

**Verdict**: APPROVED

## Area 1 — Optional fields for all transaction types

The requirement was that Note, Tags, Location, and Receipt render for Expense, Income, AND Transfer, and that the save path actually persist them for income and transfer rather than silently dropping them.

The UI gate is gone (confirmed). The block that was `// 6. Expense-Only Sections ... if (_type == 'expense') ...[ ... ]` is now `// 6. Optional details ... ...[ ... ]` — an unconditional spread, so the four fields render for every type in their existing position between the Date row and the Save button. Category/`To` visibility is untouched and still switches on `_type == 'transfer'` earlier in the tree, so Transfer keeps category hidden (confirmed).

The save path persists the fields for all types (confirmed). `_saveTransaction` builds `TransactionModel` with `note`, `latitude`, `longitude`, `locationName`, `tags: _selectedTags`, and `receipts: _receipts` with no `_type` branch; `categoryId` is forced `null` only for transfer. `TransactionModel.toMap()` emits the `note`, `latitude`, `longitude`, and `location_name` columns, and `TransactionRepository.createTransaction`/`updateTransaction` loop over `tx.tags` and `tx.receipts` unconditionally — no type check anywhere in the write path. The only type branching in the repository is `_applyBalanceImpact` (balance math), which is pre-existing and correct. So income and transfer entries now both show and store these fields.

One subtlety worth recording (not a concern): `createTransaction` calls `learnCategoryRule` only when `tx.categoryId != null`, so transfers — which carry a null category — correctly skip category-rule learning. That is the right behavior, not a dropped field.

Location auto-capture is preserved (confirmed). `_captureLocation()` still runs in `initState` for every type, the Location card remains read-only ("Captured automatically when you save"), and the diff makes no edit to the capture method or its gating (the `autoLocationCaptureProvider` + permission check lives inside `LocationService.getCurrentLocation()`, which is untouched). The keyword→category suggestion stays guarded by `_type == 'expense'` in `_onDescriptionChanged`, so it is not leaking into income/transfer.

## Area 2 — Home budgets become alert-only

The always-visible Budgets preview (`SectionHeader('Budgets', 'See all')`, the `AsyncSection` with the "No budgets yet / Create a budget" empty state, and the `budgets.take(3)` `BudgetRow` list) is removed, along with its trailing `SizedBox(height: 24)` (confirmed).

In its place, a compact `_BudgetAlertCard` renders in the attention zone immediately after the SMS attention card and before the This-month strip, shown only when at least one budget has `overAmount > 0 || usedRatio >= 1.0` — computed inline from `budgetsAsync.value ?? const <BudgetModel>[]`, reusing the already-watched `budgetListProvider` with no new provider (confirmed). Tapping sets `mainTabProvider` to `_budgetsTab`, matching the existing "See all" mechanism. Copy is correct: single exceeded budget names the category and over-amount (or "at its limit / Limit reached" when `usedRatio >= 1.0` but `overAmount == 0`); multiple shows "N budgets over limit". The over-amount honors `privacyModeProvider` via `CurrencyFormatter.format(..., isMasked:)`, consistent with the rest of Home.

Layout is safe: the title/subtitle are wrapped in `Expanded` with `maxLines: 1` + `TextOverflow.ellipsis`, so long category names cannot overflow, and the alert is a plain `AppCard` inside the Home `ListView` with bounded width. No new component pattern or design token. Spacing reflow is clean: the SMS block and the alert block each emit their own trailing 14px gap (the alert's only when shown), then the This-month strip follows with one 24px gap — so there is exactly one gap between the attention zone and the strip whether or not the alert appears. The `budget_row` import is dropped (no longer referenced on Home), `budget_model` added for the type; pull-to-refresh still reloads budgets.

All other Home sections (hero, SMS card, This-month strip, Recent transactions, Upcoming recurring, Insights) are unchanged apart from format re-wrapping.

## Area 3 — Trim the Transactions-header trash shortcut

The header `Row` previously held the "Transactions" title plus a `Pressable` → `Semantics` → `_SquareButton('🗑')` opening `RecentlyDeletedScreen`. The trash control and its `recently_deleted_screen.dart` import are removed; the `Row` now holds only the title (confirmed). `_SquareButton` is retained because the Filter button still uses it, and the `app_routes.dart` import stays because `AppRoutes.push`/`pushModal` are still used for row tap and the empty-state add action. SMS review and Recurring entry points are untouched. Recently-deleted remains reachable via Settings → Data, which is the canonical path.

## Scope and guardrails

Only the three intended files changed (commit stat confirms 3 files). No navigation, FAB, speed-dial, or bottom-nav restructuring; no design-token (color/radius/shadow) edits; no new shared widgets. No features were removed — budgets remain fully available on the Budgets tab and in Insights; the two removals eliminate duplication (trash shortcut) and asymmetry (expense-only fields). This all stays within Phase 1.

## Verification evidence

Per the brief, the recorded toolchain evidence was read rather than re-run. The commit message records `flutter analyze: No issues found` (a `dart fix --apply` resolved one `curly_braces` lint surfaced by the on-save reformat), `dart format` applied to the three files, and `flutter test: All tests passed (103)` including the "App renders without crashing" smoke test. The evidence is present and specific, and nothing in the diff raises an articulable doubt that would justify a spot-check — the behavioral changes are UI-visibility toggles and a widget swap that the smoke test plus the clean analyzer run adequately cover.

<details>
<summary>Issues (0)</summary>

No blocking or non-blocking issues found.

</details>

<details>
<summary>File map</summary>

- `lib/presentation/screens/add_transaction/add_transaction_screen.dart` — removed the `if (_type == 'expense')` gate around the Note/Tags/Location/Receipt block so it renders for all types; save path and location capture unchanged. Remainder is format reflow.
- `lib/presentation/screens/home/home_screen.dart` — removed the always-on Budgets preview section; added `_BudgetAlertCard` in the attention zone (shown only on over/at-limit budgets, taps to Budgets tab); dropped `budget_row` import, added `budget_model` import; reflowed spacing.
- `lib/presentation/screens/transactions/transaction_history_screen.dart` — removed the header 🗑 Recently-deleted button and its `recently_deleted_screen` import; kept `_SquareButton` (Filter) and `AppRoutes`. Remainder is format reflow.

Full diff: `git diff HEAD~1 HEAD` on `redesign/mykhata-2.0`.

</details>
