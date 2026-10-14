# Verification — home-action-hierarchy-cleanup

Branch: `home-action-hierarchy-cleanup` (worked in place, no new branch/commit/push).
Iteration: first (no `review.json` present).

## What was removed

Single file touched: `lib/presentation/screens/home/home_screen.dart`.

1. Removed the quick-actions row usage from the `build` layout. The block was:

   ```dart
   // 2b. Quick Action Buttons
   FadeSlideIn(
     index: 1,
     child: const _QuickActionsRow(),
   ),
   const SizedBox(height: 14),
   ```

   It sat between the `_SmsAttentionCard` (section 2a) and `_ThisMonthStrip` (now
   section 2b). Removed the `FadeSlideIn` + its trailing `SizedBox(height: 14)`.

2. Deleted the entire `_QuickActionsRow` class, including its `_actionPill`
   helper and `build` method (the Expense / Income / Transfer / SMS pills).

## Layout reflow / spacing

After removal, the SMS attention card (`if (smsCount > 0) ...`) is followed by
its own `SizedBox(height: 14)`, then `_ThisMonthStrip`, then
`SizedBox(height: 24)` before the Budgets section. No doubled or missing gap —
the spacing between the SMS card and the month strip is a single 14px gap, which
matches the spacing that previously separated the card from the quick-actions
row. Confirmed by reading the final build layout.

## FadeSlideIn index adjustments

None required. The hero group of Home sections all share `index: 1`
(hero balance card, SMS attention card, and `_ThisMonthStrip`). The removed
`_QuickActionsRow` also used `index: 1`, so deleting it leaves the index-1
group intact and the later sections continue sequentially (Budgets = 2,
Recent = 3, Recurring = 4, Insights = 5). The staggered sequence does not break,
so no index was changed.

## Imports

No imports removed. The three imports flagged as candidates are all still used
elsewhere in the file, so removing them would break the build:

- `../add_transaction/add_transaction_screen.dart` (`AddTransactionScreen`) —
  used by the empty-state "Add expense" action in the Recent transactions section.
- `../sms_review/sms_review_screen.dart` (`SmsReviewScreen`) — used by
  `_SmsAttentionCard`.
- `../../widgets/pressable.dart` (`Pressable`) — used in `_SmsAttentionCard`'s
  dismiss action and in the hero card's edit-account control.

`flutter analyze` reports no unused-import warnings, confirming all imports are
still referenced.

## Not touched

- The FAB / speed-dial in `lib/presentation/screens/main/main_navigation_screen.dart`.
- The `_SmsAttentionCard` class and its usage.
- Any other screen.

## Commands run and output

1. Static analysis (compile gate):

   ```
   > flutter analyze lib/presentation/screens/home/home_screen.dart
   Analyzing home_screen.dart...
   No issues found! (ran in 54.1s)
   ```

2. Formatting:

   ```
   > dart format lib/presentation/screens/home/home_screen.dart
   Formatted 1 file (0 changed) in 0.05 seconds.
   ```

3. Grep for dangling references across all `*.dart`:

   ```
   > query: _QuickActionsRow|_actionPill
   No matches found.
   ```

`flutter build apk` was intentionally NOT run; `flutter analyze` is the compile gate.

## Result

Analyzer clean, no new issues, no dangling references, SMS card and FAB
untouched, imports correct. Change is minimal and single-file.
