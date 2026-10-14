# Remove the redundant Home quick-actions row

The Home screen carried four overlapping entry points for the same two jobs: a FAB speed-dial and a `_QuickActionsRow` of Expense/Income/Transfer pills both added transactions, while a `_SmsAttentionCard` and a fourth "SMS" pill both opened the SMS review flow. This change deletes `_QuickActionsRow` entirely — its usage in the build layout, the wrapping `FadeSlideIn`, and the trailing spacer — leaving exactly one path to add a transaction (the FAB) and one to review SMS (the attention card). Only `home_screen.dart` is touched; the FAB and the SMS card are untouched. The functional edit is a clean deletion, but it arrives inside a large `dart format` reflow of the rest of the file.

**Watch for:** the diff is dominated by whitespace-only `dart format` line-rewrapping across the hero card, month strip, and budget rows (confirmed) — the behavioral change is a small subset of it, so review the deletion, not the churn.

**Verdict**: APPROVED

## High-level view

The deletion is complete and self-consistent. The `_QuickActionsRow` class, its `_actionPill` helper, and its single call site are all gone, and a repo-wide search finds no surviving reference to either symbol (confirmed). The empty-state "Add expense" action and the `_SmsAttentionCard` still carry the add-transaction and SMS-review paths respectively, so no capability is stranded.

The layout reflows cleanly. With the row removed, the SMS attention card keeps its own trailing 14px gap and is followed directly by the month strip, then the existing 24px gap before Budgets — a single gap, not a doubled or missing one (confirmed). No new unbounded or competing-constraint layout was introduced, so there is no fresh overflow risk.

The `FadeSlideIn` stagger survives untouched. The hero group (hero card, SMS card, month strip) all share `index: 1`, and the removed row was also at `index: 1`, so the later sections stay at 2/3/4/5 in order (confirmed). Nothing needed renumbering.

Imports are correct: nothing was removed, and the three plausibly-orphaned imports (`AddTransactionScreen`, `SmsReviewScreen`, `Pressable`) are each still referenced elsewhere in the file (confirmed).

The one thing to be aware of is scope presentation: a large formatter reflow is bundled with the one-concept deletion, inflating the diff. It is behaviorally inert but makes the change harder to read than it needs to be.

<details>
<summary>Issues (1)</summary>

1. **Formatter reflow bundled with the deletion** — the diff mixes a whole-file `dart format` rewrap with the surgical removal, inflating the change and obscuring the one behavioral edit. Non-blocking and behaviorally inert; worth a mention in the commit message so a future reader knows the churn is formatting, not logic.

</details>

<details>
<summary>Details</summary>

### The deletion is whole, with no stranded capability

`_QuickActionsRow` is removed in full — the class declaration, the `_actionPill` builder, and the `Row` of four pills — along with its one call site and the `const SizedBox(height: 14)` that trailed it. A repo-wide grep for `_QuickActionsRow|_actionPill` returns nothing, so no dangling reference survives (confirmed).

The removed pills duplicated paths that still exist. Expense/Income/Transfer were shortcuts into `AddTransactionScreen`, which the FAB speed-dial still provides and which the Recent-transactions empty state still invokes with `initialType: 'expense'`. The SMS pill opened `SmsReviewScreen`, which `_SmsAttentionCard` still opens on tap. So removing the row collapses duplicate entry points without removing the underlying features — the stated UX intent.

One discoverability note, not a defect: Transfer no longer has a labelled surface on Home at all. It now lives only in the FAB speed-dial. That is the agreed design (one way in), and the FAB is the canonical add path, so this is expected rather than a regression — flagging it only so it is a conscious trade-off (confirmed).

### Spacing between the SMS card and month strip

```
hero card
  SizedBox(height: 14)
if (smsCount > 0) [
  FadeSlideIn(index: 1, _SmsAttentionCard)
  SizedBox(height: 14)
]
FadeSlideIn(index: 1, _ThisMonthStrip)
  SizedBox(height: 24)
Budgets ...
```

The SMS card owns its own trailing 14px, so when it renders, the card-to-strip gap is a single 14px — the same gap that previously separated the card from the now-deleted row. When `smsCount == 0` the card and its spacer both drop out and the hero's trailing 14px feeds straight into the month strip. Either way there is one gap, no doubled or missing space (confirmed). The deletion removed a sibling in an already-bounded `Column`, so no new `RenderFlex` or overflow surface appears.

### FadeSlideIn stagger is intact

The remaining indices read 1 (hero), 1 (SMS card), 1 (month strip), 2 (Budgets), 3 (Recent), 4 (Recurring), 5 (Insights). The deleted row sat at `index: 1` alongside the other hero-group members, so its removal leaves the group and the sequential tail unchanged — no renumbering was required and none was done (confirmed).

### Imports left as-is, correctly

No import lines were touched. The three that could look orphaned after the deletion are all still live: `AddTransactionScreen` (empty-state "Add expense"), `SmsReviewScreen` (`_SmsAttentionCard` tap), and `Pressable` (the SMS card's control and the hero card's per-account edit). Removing any of them would break the build, so leaving them is right (confirmed).

### The formatter churn around the surgical edit

Most of the diff is `dart format` rewrapping unrelated code — the hero card's `fold`, border and text styles, the month strip's `.when(...)` chain, and several budget/recent `onAction` closures are re-indented with no behavioral change (confirmed). It is inert, but it means a reviewer scrolling the raw diff sees far more than the one deletion that matters. Isolating formatting into its own commit, or at least calling it out in the message, keeps the behavioral change legible. Non-blocking.

### Verification evidence

The coder's `verification.md` records `flutter analyze` on the file as clean, `dart format` as a no-op (already formatted), and the dangling-reference grep as empty. I independently re-ran only the grep (empty, confirmed) and read the final layout and import usage directly; I did not re-run the analyzer or the suite, per instruction. The evidence is specific and matches what the code shows — no articulable doubt remains, so no further spot-check was warranted.

</details>

<details>
<summary>File map</summary>

- `lib/presentation/screens/home/home_screen.dart` — removed `_QuickActionsRow` (class, `_actionPill`, call site, trailing spacer); remainder is `dart format` reflow.

Full diff: `git diff HEAD -- lib/presentation/screens/home/home_screen.dart`

</details>
