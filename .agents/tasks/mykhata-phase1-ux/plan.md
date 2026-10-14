# MyKhata 2.0 — Phase 1 Implementation Plan

Scope: Phase 1 ONLY of the five-phase UX redesign. Three low-risk, high-impact changes.
Branch: `redesign/mykhata-2.0` (already checked out). No worktree, no new branch, no push.

## Design decisions (made during exploration, grounded in code)

- **Add-form asymmetry is a UI-only gate, not a data limitation.** The save path in
  `add_transaction_screen.dart::_saveTransaction` builds `TransactionModel` with
  `note`, `latitude`/`longitude`/`locationName`, `tags`, and `receipts` populated
  **unconditionally for every type** (there is no `if (_type == 'expense')` around the
  model construction). `TransactionModel.toMap()` persists note/location columns, and
  `TransactionRepository.createTransaction`/`updateTransaction` write tags and receipts
  with **no type check**. Therefore the fix is purely to stop hiding the fields in the
  UI — moving the Note/Tags/Location/Receipt block out of the `if (_type == 'expense')`
  wrapper. No model, repository, or provider change is required or wanted. Decision:
  show the block for all types; keep `category` hidden for transfer (already the case:
  `categoryId` is forced `null` for transfer in `_saveTransaction`).
- **Keep auto-location behavior unchanged.** `_captureLocation()` already runs in
  `initState` for every type and is gated by the LocationService/permission + the
  settings toggle. The Location card is read-only ("Captured automatically when you
  save"). Decision: only unhide the card; do not add manual entry or re-gate capture.
- **Home budgets become alert-only.** Reuse `budgetListProvider` (already watched on
  Home) and compute exceeded budgets from `BudgetModel.overAmount` (> 0) or
  `usedRatio >= 1.0` — both already exist on the model. Decision: render a single
  compact `AppCard` in the attention zone (right after the SMS card, before the
  This-month strip) only when ≥1 budget is exceeded; tapping jumps to the Budgets tab
  via `ref.read(mainTabProvider.notifier).state = _budgetsTab`, matching the current
  "See all" mechanism. Single-budget copy names the category and over-amount; multiple
  shows a count. No new component pattern — `AppCard` + `AppText` + existing palette.
- **Recently-deleted entry point.** Settings → Data → Recently deleted is canonical and
  stays. Decision: remove only the Transactions-header 🗑 `_SquareButton` and its
  `Pressable`/`Semantics` wrapper; leave the `RecentlyDeletedScreen` import if still
  referenced, otherwise remove it to avoid an unused-import analyzer warning.

Verification commands for every item below use the project's real toolchain
(Flutter 3.47.5 / Dart 3.13.4): `flutter analyze` and `flutter test`.

---

# Implementation Plan

- [ ] 1. Unhide the optional fields (Note, Tags, Location, Receipt) for all transaction types in the Add/Edit form.
      In `add_transaction_screen.dart`, change the section currently wrapped as
      `// 6. Expense-Only Sections ... if (_type == 'expense') ...[ ... ]` so the Note,
      Tags, Location, and Receipt widgets render for Expense, Income, AND Transfer.
      Concretely: remove the `if (_type == 'expense')` guard around that spread block
      (convert the `...[ ]` collection-if into an always-included `...[ ]` spread, or
      inline the children directly) so the four fields always appear in their existing
      positions between the Date row and the Save button. Do NOT touch category
      visibility (category/`To` already correctly switches on `_type == 'transfer'`
      earlier in the tree) and do NOT change `_saveTransaction`, `TransactionModel`,
      the repository, or any provider — the save path already persists these fields for
      all types. Keep the keyword→category suggestion still guarded by
      `_type == 'expense'` (it is separate, in `_onDescriptionChanged` and the
      `_suggestedCategoryName != null && _type == 'expense'` block). Leave the fields
      optional (no new required validation).
      Files: lib/presentation/screens/add_transaction/add_transaction_screen.dart
      Verify: `flutter analyze` reports no new errors/warnings for this file; `flutter test`
      passes (the existing `App renders without crashing` smoke test still passes).
      Manual check to note for the implementer: open Add → Income and Add → Transfer and
      confirm Note/Tags/Location/Receipt are visible and category stays hidden for Transfer.

- [ ] 2. Confirm the non-expense save path persists the newly-exposed fields (verification-only, no code change expected).
      Re-read `_saveTransaction` in the same file and confirm `note`, `latitude`,
      `longitude`, `locationName`, `tags`, and `receipts` are assigned on the
      `TransactionModel` for income and transfer (they are built from `_noteController`,
      `_locationResult`, `_selectedTags`, `_receipts` with no `_type` branch) and that
      `categoryId` is `null` for transfer. If — and only if — a type gate is found that
      drops any of these for income/transfer, remove that gate so the fields pass
      through; otherwise make no change. This item exists to satisfy the brief's
      "verify the save path" requirement and must not introduce behavioral changes
      beyond item 1.
      Files: lib/presentation/screens/add_transaction/add_transaction_screen.dart (read; edit only if a gate is found)
      Verify: `flutter analyze` clean; `flutter test` passes. Document in the commit/PR
      that save-path audit confirmed note/tags/location/receipt already persist for
      income and transfer via `TransactionModel` → `toMap()` → repository.

- [ ] 3. Replace the Home always-on Budgets preview with an alert-only budget card in the attention zone.
      In `home_screen.dart`, REMOVE the section labeled `// 3. Budgets` — the
      `FadeSlideIn(index: 2, ...)` containing `SectionHeader('Budgets', 'See all')`, the
      `AsyncSection(value: budgetsAsync, ...)` with the empty-state `EmptyState('No
      budgets yet' / 'Create a budget')` and the `budgets.take(3)` `BudgetRow` list — and
      its trailing `const SizedBox(height: 24)`. INSTEAD, in the attention zone render a
      compact alert: immediately AFTER the existing SMS attention card block
      (`if (smsCount > 0) ...[ _SmsAttentionCard ... SizedBox(height:14) ]`) and BEFORE
      the `_ThisMonthStrip` block, add a conditional `FadeSlideIn` wrapping a new private
      `_BudgetAlertCard` (an `AppCard` with `onTap`) that is shown only when
      `budgetsAsync.value` has ≥1 budget with `overAmount > 0 || usedRatio >= 1.0`.
      Compute the exceeded list from `budgetsAsync.value ?? const []` (do not add a new
      provider; `budgetListProvider` is already watched as `budgetsAsync`). Copy: for a
      single exceeded budget show e.g. `'<categoryName> budget exceeded — over by
      ₹<overAmount>'` (use `CurrencyFormatter.format`, honoring `privacyModeProvider`
      like the rest of Home); for multiple show `'<n> budgets over limit'`. Tapping sets
      `ref.read(mainTabProvider.notifier).state = _budgetsTab`. Build `_BudgetAlertCard`
      from existing primitives only (`AppCard`, `AppText`, `context.palette`,
      `CurrencyFormatter`) — no new design tokens, no new shared widget. KEEP the SMS
      attention card, hero card, This-month strip, Recent transactions, Upcoming
      recurring, and Insights sections unchanged except for spacing reflow. Fix the
      spacing so there are no doubled or missing gaps: ensure exactly one gap between the
      attention cards and the This-month strip whether or not the budget alert shows
      (e.g. the alert block emits its own trailing `SizedBox(height: 14)`, matching the
      SMS card), and remove the now-orphaned `SizedBox(height: 24)` that followed the old
      Budgets section. Keep the `budgetRow.dart` import only if still used elsewhere in
      the file; if `BudgetRow` is no longer referenced, remove the unused import to keep
      `flutter analyze` clean (the `budget_providers.dart` import stays — the provider is
      still used).
      Files: lib/presentation/screens/home/home_screen.dart
      Verify: `flutter analyze` reports no new errors/warnings (specifically no
      unused-import or unused-element diagnostics from the removed section); `flutter test`
      passes. Manual check to note: with no exceeded budget, Home shows no budget block and
      spacing flows cleanly; with an exceeded budget, the alert appears in the attention
      zone and tapping switches to the Budgets tab.

- [ ] 4. Remove the redundant Recently-deleted entry point from the Transactions header.
      In `transaction_history_screen.dart`, in the title `Row` under the
      `// Title and shortcut to Recently deleted` padding, remove the trailing
      `Pressable(onTap: ... RecentlyDeletedScreen ...)` with its `Semantics` +
      `_SquareButton('🗑')` child, leaving just the `Text('Transactions', ...)` title.
      Change the `Row`'s `mainAxisAlignment` as needed (the single title no longer needs
      `spaceBetween`; a plain left-aligned title is fine, or keep the Row with just the
      title). Then remove the now-unused `import '../settings/recently_deleted_screen.dart';`
      and the `AppRoutes` import ONLY if `AppRoutes` is no longer referenced elsewhere in
      the file (it is still used for `AppRoutes.push`/`AppRoutes.pushModal` on row tap and
      empty state, so the `app_routes.dart` import stays). Do NOT remove `_SquareButton`
      if it is still used by the Filter button (it is — keep the class). Make NO change to
      SMS review entry points or Recurring.
      Files: lib/presentation/screens/transactions/transaction_history_screen.dart
      Verify: `flutter analyze` clean (no unused-import warning for recently_deleted_screen);
      `flutter test` passes. Manual check to note: the Transactions header shows only the
      title and the Filter button; Settings → Data → Recently deleted still works.

- [ ] 5. Final full-project static analysis and test pass, then one commit.
      Run `dart fix --dry-run` to preview any mechanical fixes; apply with `dart fix --apply`
      only if the suggestions are safe and in-scope (e.g. import ordering on the files
      touched above), then `dart format` the three changed files. Run `flutter analyze`
      across the project and resolve any remaining diagnostics introduced by the Phase 1
      edits. Run `flutter test` and confirm all tests pass. The phase ends with ONE commit
      containing ONLY the specifically changed files — i.e. up to:
      `lib/presentation/screens/add_transaction/add_transaction_screen.dart`,
      `lib/presentation/screens/home/home_screen.dart`,
      `lib/presentation/screens/transactions/transaction_history_screen.dart`
      (the implementer handles the git mechanics; stage these files by name, do not use
      `git add -A`). Do not commit unrelated files.
      Files: (verification + commit only — no further source edits unless analysis requires)
      Verify: `flutter analyze` exits clean; `flutter test` reports all tests passing.

---

## Guardrails honored (do NOT violate)

- No navigation / FAB / speed-dial / bottom-nav restructuring (Phase 2+).
- No change to visual design tokens — colors, radius, shadows (Phase 3).
- Reuse existing shared widgets (`AppCard`, `Pressable`, `SectionHeader`, `BudgetRow`,
  `AppText`, `CurrencyFormatter`); introduce no new component patterns.
- Keep all existing functionality working: this phase removes duplication (Transactions
  🗑) and asymmetry (expense-only fields) and converts the Home budgets preview to an
  alert — it removes no features. Budgets remain fully available on the Budgets tab and
  in Insights.
- Layout safety (per flutter-fix-layout-issues skill): the new `_BudgetAlertCard` lives
  inside the Home `ListView` like the SMS card, so it has a bounded width and no
  unbounded-constraint risk; use `Expanded`/`Flexible` + `maxLines`/`TextOverflow.ellipsis`
  on the alert text to avoid any `RenderFlex overflowed`. Removing the Budgets block only
  deletes widgets, so it cannot introduce overflow; just reflow the surrounding gaps.
- Architecture (per flutter-apply-architecture-best-practices skill): keep all data in
  providers (`budgetListProvider`, `mainTabProvider`); the new alert widget stays a lean
  presentation widget that reads already-watched state and derives the exceeded list in
  the build method — no business logic moved into the View, no new provider needed.
