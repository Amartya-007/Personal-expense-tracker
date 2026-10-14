# MyKhata 2.0 — Phase 3 Verification Note (calm by default)

Branch: `redesign/mykhata-2.0` (started from HEAD `2df1e40`). First iteration (no `review.json` present). Worked directly on the branch; no worktree/new branch; not pushed.

## New shared primitives

- **`lib/core/theme/app_radius.dart`** — `AppRadius` const class. Values equal today's radii (zero visual change):
  `sm=14, md=16, button=18, card=20, dialog=24, profile=26, lg=28`.
- **`lib/core/theme/app_spacing.dart`** — `AppSpacing` const class:
  `xs=4, sm=8, md=12, lg=16, xl=24, xxl=32`.
- **`lib/presentation/widgets/icon_square_button.dart`** — `IconSquareButton`: surface fill + hairline border, **no shadow** (calm rule), bakes in `Pressable` (scale + haptic). Radius mirrors the old `_SquareButton`: `size > 44 ? AppRadius.md : AppRadius.sm`. Optional `badge` overlay and `semanticLabel`.

All three carry `///` docs per `dart-write-documentation`; `IconSquareButton` uses a primary constructor per `dart-use-primary-constructors`.

## Item 2 — radii routed through AppRadius (no value change)

- `app_card.dart`: default `radius: 20` → `AppRadius.card`.
- `app_theme.dart`: Card `20`→`card`, FAB `20`→`card`, ElevatedButton `18`→`button`, the three input borders `16`→`md`, chip `20`→`card`, bottomSheet top `28`→`lg`, dialog `24`→`dialog`, snackbar `16`→`md`.
- `field_decoration.dart`: `appFieldDecoration` `16`→`md`.
- `home_screen.dart` hero: card `28`→`lg`, inner sheen `DecoratedBox` `28`→`lg`, account chips `16`→`md`.
- `settings_screen.dart`: profile card `26`→`profile`, About logo tile `24`→`dialog`.

No one-off/typo radii found (nothing like `19`); `26` (profile) and `24` (dialog) kept as distinct named steps rather than snapped, to avoid any visual change.

## Item 3 — decorative-layering rule (the core change)

Centralised in `app_card.dart`. The `boxShadow` switch now resolves:

```
flat   -> null
low    -> null         (was shadowSm)
medium -> null         (was shadowMd)   // default; flips every content card to border-only
high   -> p.shadowSm    (was shadowLg)   // hero only; subtle, not a banner
```

`border`, `surfaceRaised`, gradient and the `shadow` flag logic are unchanged, so a caller passing `shadow: false` stays shadowless and gradient cards still draw no border. Net rule per content card: **at most one of {border, shadow}, and no gradient.**

Card types flipped from border+shadow to border-only in one edit (no call-site churn):
SettingsGroup, `TransactionListCard`, Insights card, `_ThisMonthStrip`, `_SmsAttentionCard`, `_BudgetAlertCard`, Budgets overview, transaction-detail info/location cards, Settings Danger-zone card.

`shadowMd`/`shadowLg` are no longer referenced by any content `AppCard` — reserved for floating chrome (nav pill, FAB, sheets, dialogs), which live outside `AppCard` and are untouched.

## Items 4 & 5 — hero + profile gradient dialed down

Added `heroGradientSoft` (light + dark) in `app_colors.dart` and plumbed it through `AppPalette`:
- Light: `#0D756B → #0B5E60` (was `#0D756B → #0A4A52`) — smaller top-left→bottom-right delta, still teal.
- Dark: `#0D6B65 → #0A3C42` (was `#0D6B65 → #082F36`).

- Home `_HeroCard` now uses `p.heroGradientSoft` and `CardElevation.high`, so (via item 3) it loses `shadowLg` and keeps only a subtle `shadowSm`. White text, privacy eye (a **circle**, left as-is), count-up, and account chips preserved.
- Settings profile `AppCard` switched to `p.heroGradientSoft` — now the calmest it has been, consistent with the hero. The gradient branch draws no border and (after item 3) no shadow → one signal (gradient) only.
- The About-sheet logo tile still uses `p.heroGradient` (tiny decorative tile, not a content card); only its radius was tokenised.

## Item 4 (consistency) — kill per-screen reimplementations

- `transaction_history_screen.dart`:
  - `_SquareButton` (Filter button, size 52, `tune_rounded`) removed; replaced with `IconSquareButton(..., size: 52, badge: <gold active-count badge>, semanticLabel: 'Filters')`. Count badge, tap (`_openFilterSheet`), icon and size preserved.
  - Bespoke 52px search `Container` replaced with a `TextField` using `appFieldDecoration(p, hint: ...)` (+ `.copyWith` for the search prefix, clear suffix, content padding). Kept inside `Expanded`. 250 ms debounce (`_onSearchChanged`), clear button via `ValueListenableBuilder`, hint text, and `TextInputAction.search` all preserved.
  - Dropped the now-unused `pressable.dart` import (IconSquareButton bakes `Pressable` in).
- `budget_list_screen.dart`: inline 40×40 `Container` `+` button (radius 14 + `cardShadow`) replaced with `IconSquareButton(icon: Icons.add, size: 40, semanticLabel: 'Create budget')`. Tap behaviour preserved; `pressable.dart` import dropped. `ManagementScaffold` extended-FAB and the global speed-dial were NOT touched.

Intentional, uniform simplification (noted in the plan): square buttons no longer carry `cardShadow` — they are now border-only, matching the calm rule.

## Item 1 (spacing adoption) — files converted

Only literals that already equal a token were swapped (byte-equal, no layout shift):
- `home_screen.dart`: ListView top padding `16`→`AppSpacing.lg`; header avatar gap `12`→`md`; post-header gap `16`→`lg`; three section gaps `24`→`xl`. (`14`, `18`, `2`, `+130` left literal — no token.)
- `transaction_history_screen.dart`: title padding `16`/`12`→`lg`/`md`; search↔filter row gap `8`→`sm`.
- `budget_list_screen.dart`: ListView top padding `16`→`lg`; two section gaps `16`→`lg`.

No repo-wide mechanical replace was performed.

## Static visual self-check

- **Content cards**: every default `AppCard` now draws border only (shadow `null`), no gradient. Confirmed one edge signal each.
- **Floating chrome unchanged**: nav pill / FAB / sheets / dialogs are outside `AppCard`; `shadowMd`/`shadowLg` no longer used by any content card.
- **Radii**: each `AppRadius` constant equals the literal it replaced → no visual change.
- **Hero contrast**: white (`#FFFFFF`) text sits on dark-teal stops (light `#0D756B`/`#0B5E60`, dark `#0D6B65`/`#0A3C42`). All stops are dark enough that white text stays well above the 4.5:1 AA threshold in both themes; the two translucent discs and the top-left sheen still read. Account chips use a `black @ 0.2` fill over the teal, so white text on them stays legible.
- **Search field**: now uses the themed `appFieldDecoration`, so it carries a hairline `p.border` (enabled) and a `p.primary` focus ring — matches the rest of the app's inputs and is not a borderless-on-same-colour risk.
- **Dark-mode separation**: with content shadows removed, separation relies on `p.border` (`#21383C`) between `background #071214` / `surface #0E1D20` / `surfaceRaised #132428`. Content cards always draw `Border.all(p.border)` when non-gradient, so surfaces remain distinguishable without the removed shadow. No palette values were changed.

## Commands run (real output)

- `dart format` on the 12 changed `lib/` files — reformatted (accepted reflow; `getCategoryEmoji` in `app_colors.dart` reflowed to multi-line).
- `dart fix --apply lib/core/constants/app_colors.dart` — 11 mechanical `curly_braces_in_flow_control_structures` fixes in `getCategoryEmoji` (surfaced only because the formatter reflowed those one-liners; behaviour-preserving).
- `flutter analyze` — **No issues found!**
- `flutter test` — **All tests passed!** (`00:08 +103: All tests passed!`).
