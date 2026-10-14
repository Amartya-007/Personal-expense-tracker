# MyKhata 2.0 — Phase 2 Implementation Plan

Scope: Phase 2 ONLY of the UX redesign — six items. Branch `redesign/mykhata-2.0`
(Phase 1 committed as `e317fcd`). No worktree, no new branch, no push.

Toolchain (grounded in `pubspec.yaml` SDK `^3.13.4`, `analysis_options.yaml` present,
tests under `test/` with `sqflite_common_ffi`):
- Analyze: `flutter analyze`
- Test: `flutter test`
- Format/fix (touched files only): `dart format <files>`, `dart fix --dry-run` then
  `dart fix --apply` if safe.

The brief's constraints are honored throughout: no change to design tokens
(colors/radii/shadows — Phase 3); no nav / FAB / speed-dial restructuring; reuse the
existing shared widgets (`AppCard`, `Pressable`, `AppText`, `SegmentedTabs`,
`PillChips`, `AppDropdown`, `MultiSelectField`, `showFieldsSheet`/`AppBottomSheet`,
`PrimaryButton`, `AppMotion`, `AppHaptics`, `CurrencyFormatter`); every existing test
must still pass.

---

## Design decisions (made during exploration, grounded in code)

- **D1 — "Add details" disclosure is UI-only (item 1).** `add_transaction_screen.dart`
  already renders Note/Tags/Location/Receipt unconditionally (a `...[ ]` spread after
  the Date row — Phase 1 removed the `_type=='expense'` gate) and Payment method +
  Account inside `if (_type != 'transfer')`. The disclosure must wrap **Payment method
  (+ Account), Note, Tags, Location, Receipt** in a single collapsible region without
  moving them out of their current conditionals (Account still hides on Cash; Payment
  still hidden for transfer). State is a single `bool _detailsExpanded`, initialized in
  `initState` to `widget.editTransaction != null` (expanded when editing, collapsed for
  new). Collapsing only hides widgets — controllers/selections (`_selectedPaymentMethod`
  default `'UPI'`, `_noteController`, `_selectedTags`, `_receipts`, `_locationResult`)
  are untouched, so nothing resets and `_saveTransaction` is unchanged. **Reuse pattern:**
  the SMS card's own `AnimatedSize(duration: AppMotion.fast, curve: AppMotion.enter)` +
  a `GestureDetector`/`Pressable` header row (see `_SmsCardState._showOriginal` in
  `sms_review_screen.dart`) is the in-repo precedent; mirror it for consistency with a
  "Add details" header (chevron that flips) built from `Pressable` + `AppText` + palette.
  For transfer, Payment/Account are already absent, so the disclosure body holds
  Note/Tags/Location/Receipt only — still correct.

- **D2 — SMS single-confirm routes through the shared form via an optional prefill
  (item 2).** Add an immutable value object `SmsPrefill` and an optional
  `AddTransactionScreen({SmsPrefill? smsPrefill})` parameter. In `initState`, **only when
  `editTransaction == null && smsPrefill != null`**, seed `_type`, `_amountController`,
  `_descriptionController`, `_selectedPaymentMethod='UPI'`, `_selectedDate`, and remember
  the SMS linkage fields (`source='sms'`, `smsMessageId`, `externalReference`) plus the
  best-match account id to resolve against `accountListProvider` in `_effectiveAccount`.
  Existing callers (`initialType`, `editTransaction`) are untouched because the new param
  defaults to null and all new behavior is gated behind `smsPrefill != null`. In
  `_saveTransaction`, when a prefill is present and not editing, pass
  `source: 'sms'`, `smsMessageId:`, `externalReference:` onto the built `TransactionModel`
  (today these default to `'manual'`/null). The SMS card's `_confirm` is replaced for the
  **single** path by opening `AppRoutes.pushModal(AddTransactionScreen(smsPrefill: …))`
  and awaiting a result; the SMS is marked `'added'` **only when the form reports a
  successful save** — implemented by having the form pop with a truthy result on save
  and the SMS card calling `updateStatus(sms.id,'added')` only if that result is truthy
  (cancel/back ⇒ no status change). The batch flow (item 3) keeps building the
  `TransactionModel` inline and never opens the form.

  Save-result signalling: `_saveTransaction` currently does `Navigator.pop(context)`.
  Change to `Navigator.pop(context, true)`. This is backward compatible — all other
  callers (`pushModal`, edit) ignore the return value.

- **D3 — Batch "Confirm all high-confidence" (item 3).** "High-confidence" = the
  existing `_SmsCardState._match(accounts)` returns a non-null unique bank→account match
  (reuse that exact logic, lifted to a top-level/providers helper so both the card and
  the batch action share one implementation). Add a summary-area action on the Detected
  tab ("Add all N" where N = count of detected messages with a confident match). It
  iterates those messages, builds the same `source:'sms'` `TransactionModel` the inline
  `_confirm` builds, calls `createTransaction`, marks each `'added'`, fires ONE
  `AppHaptics.success()` and shows ONE snackbar ("Added N transactions"). Messages with
  no confident match stay `'detected'` for manual single-confirm (now the item-2 form).
  Guard against double-run with a processing flag held in a small `StateProvider<bool>`
  (so it survives rebuilds) or local state on a new stateful summary widget. Undo is
  best-effort/optional per brief: a summary snackbar satisfies the minimum. (If undo is
  cheap, soft-delete the created ids and move the SMS back to `'detected'`; otherwise a
  plain summary snackbar is acceptable.)

- **D4 — Quick-filter chips reuse the existing filter path; per-day totals already
  exist (item 4).** The quick-filter chips call the EXISTING
  `transactionListProvider.notifier.updateFilter((f) => f.copyWith(...))`:
  - **This month** ⇒ `datePeriod: 'This Month'` (exact `DateFilters` string); clearing ⇒
    `copyWith(clearDatePeriod: true, clearCustomDateRange: true)`.
  - **Expenses** ⇒ `type: 'expense'`; **Income** ⇒ `type: 'income'`; clearing ⇒
    `copyWith(clearType: true)`.
  - **Top categories** (optional, only if cheap): first 1–2 of
    `categoriesListProvider` already watched by `_ActiveFilterChips`; chip ⇒
    `copyWith(categoryIds: [id])`, clear ⇒ `copyWith(categoryIds: const [])`.
  A chip renders "active" when the current `filter` already carries exactly that value
  (e.g. `filter.datePeriod == 'This Month'`, `filter.type == 'expense'`), so it stays in
  sync with the existing `_ActiveFilterChips`. Tapping an active chip clears it. Reuse
  `PillChips`/`PillChip` for the visual; place the row directly below the search/filter
  `Row` and above `_ActiveFilterChips`.
  **Per-day running totals ALREADY EXIST:** `_DayHeader` shows
  `Spent <CurrencyFormatter.format(spent)>` where `spent` is the day's expense sum
  (computed in `_buildBody`). Decision: do NOT add a second total. Verify legibility only
  (it already uses `AppText.caption(p.muted)`), and the lone, conservative fix if needed:
  honor privacy masking (the rest of the app masks via
  `CurrencyFormatter.format(..., isMasked:)` and `privacyModeProvider`) so the day total
  does not leak amounts while balances are hidden. This is the only behavioral tweak to
  the existing header and is in keeping with app-wide masking.

- **D5 — Swipe-right quick-edit is scoped to the history list (item 5).** The shared
  `TransactionListCard` is used by both Home recent and Transactions history. Adding a
  two-direction `Dismissible` on the shared row risks confirm/undo semantics on Home.
  Decision: add an opt-in flag `onQuickEdit` (a `void Function(TransactionModel)?`) to
  `TransactionListCard`/`TransactionRow`. Only the history screen passes it; Home passes
  nothing, so Home rows are byte-for-byte unaffected. When `onQuickEdit != null`, the
  `Dismissible` gains `direction: DismissDirection.horizontal`, a right-swipe
  (`startToEnd`) teal "Edit" background, and `confirmDismiss` returns `false` for the
  edit direction after invoking `onQuickEdit` (so the row is NOT dismissed — it opens a
  sheet), while `endToStart` keeps today's delete+undo exactly. The history screen's
  `onQuickEdit` opens a lightweight bottom sheet (reuse `AppBottomSheet.show`) with
  category (reuse the add-form quick chip grid or `AppDropdown`) + amount
  (`showFieldsSheet`-style field) and saves via
  `transactionListProvider.notifier.updateTransaction(tx.copyWith(categoryId:, amount:))`
  (which already refetches dependents). Haptics via `AppHaptics`. New shared sheet widget
  goes in `lib/presentation/widgets/`.

  **copyWith caveat (grounded):** `TransactionModel.copyWith` uses `field ?? this.field`,
  so it cannot set `categoryId` to null. Quick-edit only ever sets a non-null category
  (changing to "Uncategorized" is out of scope for the minimal quick-edit), so this is
  safe. Document this limit in the sheet.

- **D6 — Align the two time-range controls on styling, do not merge (item 6).** Budgets
  uses `SegmentedTabs [Weekly/Monthly/Yearly]` (period-type); Insights uses
  `PillChips [Today/This Week/This Month/Last Month]` (date-range). They are semantically
  different and MUST NOT merge. Lowest-risk consistency: standardize BOTH on `PillChips`
  (Insights already uses it; `PillChips` is a drop-in with the same
  `options/selected/onSelected` contract as `SegmentedTabs`). Swapping Budgets'
  `SegmentedTabs` for `PillChips` changes zero options and zero semantics — the
  `onSelected`/`selected` wiring is identical — and makes the two screens visually one
  family. This is preferred over hand-tuning `SegmentedTabs` styling (which risks the
  shared control used by type/payment/appearance pickers elsewhere). Preserve the exact
  period strings and filtering. (If, during implementation, the `PillChips` swap on
  Budgets is found to subtly change behavior, fall back to the documented conservative
  alternative: leave both widgets as-is and only reconcile height/radius/selected-state —
  but the swap is expected to be clean.)

---

# Implementation Plan

- [ ] 1. **Add-transaction "Add details" disclosure (item 1).**
      In `add_transaction_screen.dart`, add `bool _detailsExpanded` initialized in
      `initState` to `widget.editTransaction != null`. Wrap the Payment-method block
      (`if (_type != 'transfer') ...[ Payment method + Account ]`) and the optional
      Note/Tags/Location/Receipt spread in a single collapsible region: a tappable
      "Add details" header row (`Pressable` + `AppText` + chevron that flips on expand,
      using `context.palette`) followed by an `AnimatedSize(duration: AppMotion.fast,
      curve: AppMotion.enter)` whose child is the fields when `_detailsExpanded` else a
      zero-height `SizedBox` (mirror the existing `_SmsCard` "View original message"
      pattern). Keep the existing conditionals inside the body (Payment hidden for
      transfer, Account hidden on Cash). Do NOT move save logic; collapsing must not
      reset `_selectedPaymentMethod` (stays `'UPI'`), note, tags, receipts, or location.
      Amount, type, description/From, category/To, account(for the fast path keep Account
      inside details per brief — Payment method + Account go behind the disclosure),
      and Date stay always-visible. Preserve autofocus-amount-on-new,
      keyword→category suggestion, transfer From/To, validation, edit prefill, save guard.
      Files: lib/presentation/screens/add_transaction/add_transaction_screen.dart
      Verify: `flutter analyze` clean for the file; `flutter test` passes (smoke test
      still renders). Manual note: new Add opens collapsed; editing opens expanded;
      expanding then saving produces identical data to before.

- [ ] 2. **Route SMS single-confirm through the shared add form (item 2).**
      Add an immutable `SmsPrefill` class (fields: `type`, `amount`, `description`,
      `paymentMethod` default 'UPI', `date`, `accountId` best-match, `source`='sms',
      `smsMessageId`, `externalReference`) — place it in
      `add_transaction_screen.dart` (or a small file beside it) and add an optional
      `SmsPrefill? smsPrefill` constructor param to `AddTransactionScreen`. In `initState`
      seed controllers/selections ONLY when `editTransaction == null && smsPrefill != null`.
      In `_saveTransaction`, when a prefill is active and not editing, set `source: 'sms'`,
      `smsMessageId:`, `externalReference:` on the built `TransactionModel`; change the
      success `Navigator.pop(context)` to `Navigator.pop(context, true)`.
      In `sms_review_screen.dart`, change `_SmsCardState._confirm` for the SINGLE path to
      `final saved = await AppRoutes.pushModal<bool>(context, AddTransactionScreen(
      smsPrefill: SmsPrefill(...from sms + resolved account...)));` and only call
      `updateStatus(sms.id,'added')` when `saved == true`. Keep the double-tap `_busy`
      guard. Do NOT change the batch path.
      Files: lib/presentation/screens/add_transaction/add_transaction_screen.dart,
      lib/presentation/screens/sms_review/sms_review_screen.dart
      Verify: `flutter analyze` clean; `flutter test` passes. Manual note: confirming an
      SMS opens the prefilled form; saving marks it added; cancelling leaves it detected;
      created tx keeps `source='sms'`/`smsMessageId`/`externalReference`.

- [ ] 3. **SMS batch "Add all N high-confidence" (item 3).**
      Lift `_SmsCardState._match` into a shared top-level helper (e.g.
      `smsBestMatchAccount(sms, accounts)` in `sms_review_providers.dart` or a small util)
      and have `_SmsCard` call it (behavior-preserving refactor). In the Detected-tab
      summary card (`_MessageList`, `tab == 'detected'`), add an "Add all N" action where
      N = count of detected items whose `smsBestMatchAccount` is non-null. On tap: guard
      with a processing flag (a `StateProvider<bool>` so re-taps during the run are
      ignored), iterate those messages building the same `source:'sms'`
      `TransactionModel` the inline `_confirm` builds, `createTransaction` each, mark each
      `'added'`, then ONE `AppHaptics.success()` + ONE snackbar "Added N transactions".
      Messages without a confident match stay detected. Do not open the form in this path.
      Files: lib/presentation/screens/sms_review/sms_review_screen.dart,
      lib/presentation/providers/sms_review_providers.dart
      Verify: `flutter analyze` clean; `flutter test` passes (incl. `sms_parser_test`,
      `sms_dedupe_test`). Manual note: batch adds only confidently-matched messages,
      leaves ambiguous ones for single-confirm, cannot double-run.

- [ ] 4. **Transactions quick-filter chips + verify per-day totals (item 4).**
      In `transaction_history_screen.dart`, add a `PillChips`-based quick-filter row
      directly below the search/filter `Row` and above `_ActiveFilterChips`. Chips:
      [This month]→`copyWith(datePeriod:'This Month')`, [Expenses]→`copyWith(type:'expense')`,
      [Income]→`copyWith(type:'income')`, optionally top 1–2 categories from
      `categoriesListProvider`→`copyWith(categoryIds:[id])`. Each applies via the existing
      `transactionListProvider.notifier.updateFilter(...)`; tapping an already-active chip
      clears that dimension (`clearType:true` / `clearDatePeriod:true,
      clearCustomDateRange:true` / `categoryIds: const []`). Active state is derived from
      the current `filter` so it stays in sync with `_ActiveFilterChips`.
      Per-day totals: `_DayHeader` already renders "Spent …". Do NOT duplicate. Only make
      the existing day total honor privacy masking: thread `isMasked` (from
      `privacyModeProvider`) into its `CurrencyFormatter.format(..., isMasked:)` call,
      matching app-wide masking. No other change to the header.
      Files: lib/presentation/screens/transactions/transaction_history_screen.dart
      Verify: `flutter analyze` clean; `flutter test` passes (incl. `transaction_filter_test`).
      Manual note: chips toggle the right single filter, reflect active state, and clear on
      re-tap; day totals mask when privacy mode is on.

- [ ] 5. **Swipe-right quick-edit on history rows (item 5).**
      In `transaction_row.dart`, add an optional `void Function(TransactionModel)?
      onQuickEdit` to `TransactionListCard` (threaded into `_buildRow`). When non-null,
      make the `Dismissible` `direction: DismissDirection.horizontal` with a teal "Edit"
      `startToEnd` background; use `confirmDismiss` to return `false` for `startToEnd`
      after calling `onQuickEdit(tx)` (row is not dismissed), and keep `endToStart` =>
      delete+undo exactly as today (`onDismissed`/`onDelete`). When `onQuickEdit == null`
      (Home), behavior is byte-for-byte the current endToStart-only delete.
      Add a new shared quick-edit sheet widget in `lib/presentation/widgets/` (e.g.
      `transaction_quick_edit_sheet.dart`) opened via `AppBottomSheet.show`, letting the
      user change category (reuse the add-form 6-chip grid or `AppDropdown` fed by
      `expense/incomeCategoriesProvider` by tx type) and amount, saving via
      `transactionListProvider.notifier.updateTransaction(tx.copyWith(categoryId:,
      amount:))` with `AppHaptics.success()`. Wire the history screen's
      `TransactionListCard(onQuickEdit: ...)`; leave Home's usage unchanged.
      Files: lib/presentation/widgets/transaction_row.dart,
      lib/presentation/widgets/transaction_quick_edit_sheet.dart (new),
      lib/presentation/screens/transactions/transaction_history_screen.dart
      Verify: `flutter analyze` clean; `flutter test` passes. Manual note: swipe-left
      delete+undo still works everywhere; swipe-right opens quick-edit only on the
      Transactions list; Home rows unaffected.

- [ ] 6. **Unify the time-range control visual (item 6).**
      In `budget_list_screen.dart`, replace the period `SegmentedTabs
      ['Weekly','Monthly','Yearly']` with `PillChips` using the SAME options and the SAME
      `selected`/`onSelected` wiring (`_period[0].toUpperCase()+...`,
      `onSelected: (label)=>setState(()=>_period=label.toLowerCase())`). Remove the now-
      unused `segmented_tabs.dart` import if nothing else in the file uses it; add the
      `pill_chips.dart` import. Do not change options, defaults, or the
      `budgets.where((b)=>b.period==_period)` filtering. Insights already uses `PillChips`;
      leave it as-is so the two now share one visual family.
      Files: lib/presentation/screens/budgets/budget_list_screen.dart
      Verify: `flutter analyze` clean (no unused-import warning); `flutter test` passes.
      Manual note: Budgets period switching still filters correctly and now visually
      matches Insights' range chips.

- [ ] 7. **Full static analysis + test pass, format, single commit.**
      Run `dart fix --dry-run` and apply only safe in-scope fixes; `dart format` the
      touched files; run `flutter analyze` and `flutter test` and resolve any Phase-2
      diagnostics. Commit ONLY the files changed above (stage by name, no `git add -A`;
      do not commit `.agents/` or `skills-lock.json`). No push.
      Files: (verification + commit only)
      Verify: `flutter analyze` exits clean; `flutter test` all green.

---

## Risk callouts (per brief)

- **`AddTransactionScreen` callers:** `initialType` and `editTransaction` must keep
  working. The new `smsPrefill` param defaults to null and ALL new behavior is gated by
  `editTransaction == null && smsPrefill != null`. Changing the save pop to
  `pop(context, true)` is backward-compatible (other callers ignore the result).
- **`TransactionListCard` shared by Home recent + Transactions history:** swipe-right is
  opt-in via `onQuickEdit`; Home passes nothing and is unaffected. Swipe-left delete+undo
  is preserved in both.
- **`TransactionModel.copyWith` cannot null `categoryId`:** quick-edit only sets non-null
  categories, so this is safe; documented in the sheet.
- **`PillChips` swap on Budgets (item 6):** same `options/selected/onSelected` contract as
  `SegmentedTabs`; expected clean. Fallback documented in D6 if any behavior shift appears.
- **Privacy masking on day totals (item 4):** the only behavioral tweak to `_DayHeader`,
  bringing it in line with app-wide masking; no new total added.

## Guardrails honored

- No design-token changes (Phase 3). No nav/FAB/speed-dial changes. Reuse of existing
  shared widgets only; the one genuinely new widget (quick-edit sheet) lives in
  `lib/presentation/widgets/`. Every existing test must still pass.
