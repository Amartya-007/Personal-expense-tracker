# MyKhata 2.0 — Phase 3 Implementation Plan (calm by default)

Branch: `redesign/mykhata-2.0` (HEAD `2df1e40`). Do NOT create a worktree/branch. Do NOT push.
Commit at END of phase: one well-scoped commit (or one per logical change) staging ONLY changed `lib/` files. Never `git add -A`; never stage `.agents/` or `skills-lock.json`.

## Ground-truth values read from current code (so nothing changes visually)

Radii actually in use (verified):
- Theme `app_theme.dart`: Card `20`, FAB `20`, ElevatedButton `18`, inputs (`inputDecorationTheme`) `16`, chips `20`, bottom sheet top `28`, dialog `24`, snackbar `16`.
- `app_card.dart` AppCard default `radius: 20`.
- `field_decoration.dart appFieldDecoration`: `16`.
- Home hero `_HeroCard`: `radius: 28` (and inner sheen `DecoratedBox` `28`); hero account chips `16`; privacy-eye is a **circle** (`BoxShape.circle`), NOT a square.
- Settings profile card: `radius: 26`. Settings "About" sheet logo tile: `24`.
- Transactions `_SquareButton`: `size > 44 ? 16 : 14` (Filter button uses `size: 52` → `16`); search container `16`; `_SummaryBanner` `14`; `_RemovableChip` `20`; hero/avatar circle.
- Budgets inline square `+` button: `14`. Budget attention/alert icon chips (`_BudgetAlertCard`, `_SmsAttentionCard`): `14`.

Decision — named radius scale (values chosen to equal today's values; purely a single source of truth, zero visual change):
```
AppRadius.sm   = 14   // small square controls, summary banner, small icon chips
AppRadius.md   = 16   // inputs, search field, hero account chips, snackbar
AppRadius.button = 18 // ElevatedButton
AppRadius.card = 20   // AppCard / Card theme / chips
AppRadius.dialog = 24 // dialog, About logo tile
AppRadius.profile = 26 // Settings profile card
AppRadius.lg   = 28   // hero, bottom sheet top, nav pill (nav is out of scope but shares the value)
```
Note the one-off `26` (Settings profile) and `24` (dialog/About): these are legitimate distinct steps already in the design report's 26–28 band and the dialog 24. Keep them as named constants (`profile`, `dialog`) rather than snapping to `lg`/each other — snapping would be a visual change, which the brief forbids. No clear typo radii found (nothing like `19`), so every value is preserved exactly.

Spacing literals seen (report + code): 2/4/6/8/10/12/14/16/18/22/24. Decision — named scale that covers the common steps; apply ONLY in files touched this phase:
```
AppSpacing.xs=4, sm=8, md=12, lg=16, xl=24, xxl=32
```
(2/6/10/14/18/22 are intentionally not forced into the scale; leave odd one-offs literal rather than shifting them and changing layout. Convert a literal to a token ONLY when the literal already equals a token value, so spacing never visually shifts.)

### Core finding driving item 3 (decorative layering)
`AppCard` defaults to `elevation: CardElevation.medium` + `shadow: true`. In `app_card.dart build`, a non-gradient card draws **`Border.all(color: p.border)` AND `boxShadow: p.shadowMd`** simultaneously. So every default `AppCard` (SettingsGroup via `list_widgets.dart`, `TransactionListCard` via `transaction_row.dart`, Insights cards, `_ThisMonthStrip`, `_SmsAttentionCard`, `_BudgetAlertCard`, Budgets detail overview `AppCard`, settings Danger-zone card, transaction detail info/location cards) carries border + shadow at once — exactly the doubled edge signal to remove. Cards that already pass `shadow: false` (empty_state compact, async_section, skeleton, sms_permission_help, budgets period-overview `AppCard(shadow:false)`) are already calm.

Decision — centralized layering rule, applied in `app_card.dart` so it is one source of truth:
- **Content cards = hairline border + NO shadow** (flat/calm). Implement by making `CardElevation.medium` (the default) resolve to NO shadow in `AppCard` — i.e. medium becomes border-only. `low` also → no shadow (rows inside lists). This flips content cards from "border+shadowMd" to "border only" without touching a single call site.
- **Floating chrome keeps shadow**: only `CardElevation.high` keeps a shadow, and it maps to `shadowSm` for the hero (subtle), while true floating chrome (nav pill, FAB, bottom sheets, dialogs — all OUTSIDE AppCard, in their own widgets/theme) is untouched and keeps `shadowMd/shadowLg`. Reserve `shadowMd/shadowLg` strictly for that floating chrome.
- **Gradient cards** already draw no border (existing `border: gradient == null ? ... : null`). We additionally drop their shadow (see hero/profile below).
- Net rule enforced per content card: AT MOST ONE of {border, shadow}, and NO gradient. Hero is the one allowed subtle exception (flattened gradient + hairline, no heavy shadow).

Exact `AppCard` shadow mapping AFTER change:
```
flat   -> null
low    -> null            (was shadowSm)
medium -> null            (was shadowMd)  <-- default; makes all content cards border-only
high   -> p.shadowSm      (was shadowLg)  <-- hero only; subtle, not a banner
```
Dark-mode safety: with shadows removed, separation relies on `p.border` (dark `#21383C`) between `background #071214` / `surface #0E1D20` / `surfaceRaised #132428`. These differ enough that the hairline border keeps cards legible in dark. The self-check (step 9) must confirm this on the Home/Transactions/Insights/Settings surfaces.

---

## Skill applicability
- `dart-use-primary-constructors`: apply to NEW widgets (`IconSquareButton`) and when editing existing widget constructors — use declaring/initializing params per the skill (Dart SDK is `^3.13.4`, primary constructors enabled). Keep existing `const` constructors.
- `dart-write-documentation`: every NEW public symbol (`AppSpacing`, `AppRadius`, `IconSquareButton`) gets `///` docs — first line a single summary sentence, noun phrase for fields, no `@param`/`@return` tags, `[identifier]` links.
- `flutter-apply-architecture-best-practices`: keep changes in the UI layer only (`lib/presentation`, `lib/core/theme`); no data/service edits; shared widgets stay lean and reusable (consolidate, don't fork).
- `dart-run-static-analysis`: after each item run `flutter analyze`; use `dart fix --dry-run` then `--apply` only for mechanical lints; `dart format` changed files (reformat-on-save is ACCEPTED — do not fight it).
- `flutter-fix-layout-issues`: relevant to item 4 (search field moving into a themed `InputDecoration` inside a `Row` → keep it inside `Expanded`; `IconSquareButton` must keep fixed size so the `Row` doesn't overflow).

## Verification commands (project real commands)
- Analyze: `flutter analyze` (expect: no new errors/warnings in changed files).
- Tests: `flutter test` (expect: all existing tests pass; suite under `test/` incl. `test/widgets/`, `test/unit/`, `test/providers/`).
- Format: `dart format lib` on changed files (accepted reflow).
- Visual self-check: static reasoning against the rule (no device run required), documented in the plan's step 9.

Order is by dependency: foundations (1,2) → centralized layering (3) → the two hero/profile gradient edits (4,5) → shared button widget (6) → consume it + search field (7) → spacing adoption (8) → self-check (9) → verify+commit (10).

---

# Implementation Plan

- [ ] 1. Create the radius scale constants.
      Create `AppRadius` with the named constants listed above (sm=14, md=16, button=18, card=20, dialog=24, profile=26, lg=28), each a `static const double`, matching the existing `AppColors`/`AppText` const-class style. Add `///` docs (summary sentence + per-field noun phrase) per `dart-write-documentation`. Do NOT yet change any call site.
      Files: `lib/core/theme/app_radius.dart` (new)
      Verify: `flutter analyze lib/core/theme/app_radius.dart` — no errors.

- [ ] 2. Create the spacing scale constants.
      Create `AppSpacing` with `static const double xs=4, sm=8, md=12, lg=16, xl=24, xxl=32` in the same const-class style, with `///` docs. Do NOT do a repo-wide replace; adoption happens in step 8 only where already editing + Home/Transactions padding.
      Files: `lib/core/theme/app_spacing.dart` (new)
      Verify: `flutter analyze lib/core/theme/app_spacing.dart` — no errors.

- [ ] 3. Centralize the decorative-layering rule in AppCard and route it + the theme through AppRadius.
      In `app_card.dart`: change the `boxShadow` switch so content elevations carry NO shadow and only `high` keeps a subtle shadow — map `flat/low/medium -> null`, `high -> p.shadowSm` (was `low->shadowSm, medium->shadowMd, high->shadowLg`). Leave the `border`, `surfaceRaised`, gradient, and `shadow` flag logic intact (a caller passing `shadow:false` stays shadowless; the `high` hero still works). Replace the literal default `this.radius = 20` with `AppRadius.card`. Update the class doc comment to state the new rule (content = hairline border, no shadow; `high` = subtle shadow for the one hero). In `app_theme.dart`, replace the radius literals with `AppRadius` constants: Card `20`→`AppRadius.card`, FAB `20`→`AppRadius.card`, ElevatedButton `18`→`AppRadius.button`, inputDecoration borders `16`→`AppRadius.md`, chip `20`→`AppRadius.card`, bottomSheet `28`→`AppRadius.lg`, dialog `24`→`AppRadius.dialog`, snackbar `16`→`AppRadius.md`. In `field_decoration.dart`, replace `appFieldDecoration`'s `16`→`AppRadius.md`. This flips ALL default content cards (SettingsGroup, TransactionListCard, Insights cards, _ThisMonthStrip, _SmsAttentionCard, _BudgetAlertCard, Budgets overview, transaction detail cards, Danger-zone card) from border+shadow to border-only in one edit — no call-site churn.
      Files: `lib/presentation/widgets/app_card.dart`, `lib/core/theme/app_theme.dart`, `lib/presentation/widgets/field_decoration.dart`
      Verify: `flutter analyze` (changed files) clean; `flutter test test/widgets` passes (keyboard/focus widget tests unaffected). Visually (static): every default `AppCard` now shows exactly one edge signal (border), radii unchanged because constants equal prior literals.

- [ ] 4. Flatten the Home hero gradient and drop its heavy shadow.
      In `home_screen.dart _HeroCard`: keep it a teal surface but reduce contrast so it reads informational, not like a banner. Replace `gradient: p.heroGradient` with a flatter gradient — either (a) a near-flat two-stop teal using the hero's lighter stop twice-ish, or (b) a new palette getter (see note). The AppCard already becomes `shadowSm` via step 3's `CardElevation.high` mapping, so the hero loses `shadowLg` automatically — keep `elevation: CardElevation.high`. Keep `radius: 28`→`AppRadius.lg`; keep the inner sheen `DecoratedBox` radius `28`→`AppRadius.lg`; keep the hairline white edge, the privacy eye (circle — leave as-is, it is NOT a square so item 4 does not touch it), the count-up, and account chips (`16`→`AppRadius.md`). Decision for the flatter gradient: add `AppPalette.heroGradientSoft` (light + dark) in `app_palette.dart`/`app_colors.dart` using the existing hero end colors brought closer together (e.g. light `#0D756B`→`#0B5E60`-ish instead of `#0A4A52`; dark `#0D6B65`→`#0A3C42`) so the top-left→bottom-right delta is visibly smaller while staying teal. Keep white text + white-alpha chips exactly. This localizes the gradient change to one named token rather than editing hero + settings inline.
      Files: `lib/core/constants/app_colors.dart`, `lib/core/theme/app_palette.dart`, `lib/presentation/screens/home/home_screen.dart`
      Verify: `flutter analyze` clean. Visual (static): white `#FFFFFF` title/amount on the flattened teal must stay ≥ 4.5:1 contrast — the chosen soft stops keep luminance low (teal ~#0B5E60/#0A3C42), so white passes AA; confirm the two translucent discs + sheen still read. Confirm legibility in BOTH light and dark hero gradients.

- [ ] 5. Soften the Settings profile gradient to match the calmer hero.
      In `settings_screen.dart` profile `AppCard`: switch `gradient: p.heroGradient` → `p.heroGradientSoft` (same token from step 4) so the profile card is consistent with the dialed-down hero and no longer the loudest surface in Settings. Keep `radius: 26`→`AppRadius.profile`, keep the white circle avatar, white text, and edit affordance. The gradient branch already draws no border and (after step 3) no shadow, so the card carries gradient only — one signal. Leave the "About" sheet logo tile gradient (`p.heroGradient`, radius `24`→`AppRadius.dialog`) as-is except the radius token; it's a tiny decorative tile, not a content card.
      Files: `lib/presentation/screens/settings/settings_screen.dart`
      Verify: `flutter analyze` clean. Visual (static): white text on softened profile gradient still ≥ 4.5:1 in light and dark.

- [ ] 6. Create the shared IconSquareButton widget.
      Create `IconSquareButton` modeling the common small square icon-button pattern (surface fill, `AppRadius.sm`/`md` by size, hairline border, optional shadow OFF by default to match the calm rule, centered child/icon, fixed `size`). Use a primary constructor per `dart-use-primary-constructors` with declaring/initializing params (`required this.icon` or `required this.child`, `this.size = 40`, `this.onTap`, optional `semanticLabel`, `tooltip`). Wrap tap in the existing `Pressable` for the standard scale+haptic (matching current `_SquareButton` usage which is wrapped in `Pressable` at call sites — bake `Pressable` inside so call sites don't double-wrap). Radius rule mirrors current `_SquareButton`: `size > 44 ? AppRadius.md : AppRadius.sm`. Add `///` docs. Do NOT add a shadow by default (old `_SquareButton`/budgets button used `cardShadow`; per the calm rule, drop it to border-only — note this as an intentional, consistent small visual simplification applied uniformly to all square buttons).
      Files: `lib/presentation/widgets/icon_square_button.dart` (new)
      Verify: `flutter analyze lib/presentation/widgets/icon_square_button.dart` — no errors.

- [ ] 7. Replace per-screen square buttons and route the Transactions search through the themed input.
      (a) In `transaction_history_screen.dart`: replace the private `_SquareButton` (Filter button, `size: 52`, `tune_rounded`) with `IconSquareButton`, preserving the gold active-count badge `Stack`, the `Semantics(button, label:'Filters')`, icon, size 52, and `_openFilterSheet` tap. Remove the now-unused `_SquareButton` class and its `cardShadow` usage. Replace the bespoke 52px search `Container` with a themed `TextField` using `appFieldDecoration(p, hint: 'Search merchant, note, amount, category...')` (or an `InputDecoration` from theme) — keep it inside `Expanded` (layout-issues skill), keep the 250ms debounce (`_onSearchChanged`), the clear (✕) suffix via `ValueListenableBuilder`, the search prefix icon, `textInputAction.search`, and `_clearSearch`. Match height to the Filter button (the field's content padding/height so the row stays aligned at ~52).
      (b) In `budget_list_screen.dart`: replace the inline 40×40 `Container` `+` button (`BorderRadius.circular(14)`, `cardShadow`) with `IconSquareButton(icon: Icons.add, size: 40, onTap: () => _createBudget(all), semanticLabel: 'Create budget')`, preserving the existing `Semantics`/`Pressable` behavior (remove outer `Pressable` if `IconSquareButton` bakes it in). Do NOT touch `ManagementScaffold` extended-FAB or the global speed-dial.
      (c) Home hero privacy-eye: LEAVE AS-IS — it is a circle (`BoxShape.circle`), visually distinct, not the square pattern; the brief says leave it if distinct.
      Files: `lib/presentation/screens/transactions/transaction_history_screen.dart`, `lib/presentation/screens/budgets/budget_list_screen.dart`
      Verify: `flutter analyze` clean (no unused `_SquareButton`); `flutter test` passes (`test/widgets/keyboard_focus_test.dart` still green — search field still focusable with debounce+clear). Visual (static): Filter badge still shows count; search matches app input look; no `Row` overflow (field in `Expanded`, button fixed-size).

- [ ] 8. Adopt AppSpacing in the high-traffic files already touched (Home, Transactions) + the shared cards/rows edited this phase.
      Convert ONLY literals that already equal a token (4→xs, 8→sm, 12→md, 16→lg, 24→xl, 32→xxl) in: `home_screen.dart` (ListView `padding: fromLTRB(18,16,18,...)` — convert the `16`→`AppSpacing.lg`; the `18` horizontal stays literal as it has no token; section gaps `SizedBox(height: 16)`→`lg`, `24`→`xl`, `12`→`md`, `8`→`sm`, `4`→`xs`), `transaction_history_screen.dart` (search/filter row gap `SizedBox(width: 8)`→`sm`, list `fromLTRB(18,0,18,bottom+130)` bottom stays, title padding `16`/`12`→`lg`/`md`), and the widgets edited in steps 3/6/7 (`app_card.dart` has no spacing; `icon_square_button.dart` internal; `budget_list_screen.dart` the row gap `SizedBox(height:16)`→`lg`). Leave `18` (screen horizontal), `2/6/10/14/22`, and the `+130` nav reserve as literals — no token forced. Document the converted files in the commit message. Do NOT touch other screens' spacing.
      Files: `lib/presentation/screens/home/home_screen.dart`, `lib/presentation/screens/transactions/transaction_history_screen.dart`, `lib/presentation/screens/budgets/budget_list_screen.dart`
      Verify: `flutter analyze` clean; `flutter test` passes. Visual (static): values are byte-equal substitutions (token == old literal) so no layout shift.

- [ ] 9. Static visual self-check (document findings inline in the commit / PR body; no code unless a violation is found).
      Confirm each obligation and fix any violation by adjusting the step that introduced it:
      - Every CONTENT card (SettingsGroup, TransactionListCard, Insights cards, _ThisMonthStrip, _SmsAttentionCard, _BudgetAlertCard, Budgets overview, transaction detail info/location cards, Danger-zone card) now shows AT MOST ONE of {border, shadow} and NO gradient. (After step 3: default = border only, shadow null.)
      - Floating chrome unchanged: nav pill (`main_navigation_screen.dart _FloatingNavBar` glass + shadowMd), gold FAB, bottom sheets, dialogs still carry their elevation/shadow (none routed through AppCard content elevations). Confirm `shadowMd`/`shadowLg` are no longer used by any content `AppCard` — only chrome + hero(`shadowSm`).
      - Radii unchanged everywhere: each `AppRadius` constant equals the literal it replaced.
      - Hero + Settings profile: white text ≥ 4.5:1 on the flattened teal in BOTH light and dark.
      - Dark-mode separation: with content shadows removed, `p.border` keeps `background/surface/surfaceRaised` distinguishable; if any surface looks flat/indistinct in dark, bump nothing in the palette — instead confirm the border is present (content cards always draw `Border.all(p.border)` when non-gradient).
      Files: none (unless a violation requires a targeted fix in the owning step's file)
      Verify: `flutter analyze` clean; `flutter test` all pass.

- [ ] 10. Format, final analyze/test, and commit.
      Run `dart format lib` (accept reflow of changed files). Run `flutter analyze` (no new issues) and `flutter test` (all pass). Stage ONLY the changed `lib/` files (new: `app_radius.dart`, `app_spacing.dart`, `icon_square_button.dart`; modified: `app_card.dart`, `app_theme.dart`, `app_palette.dart`, `app_colors.dart`, `field_decoration.dart`, `home_screen.dart`, `settings_screen.dart`, `transaction_history_screen.dart`, `budget_list_screen.dart`). Never `git add -A`; never stage `.agents/` or `skills-lock.json`. Commit on `redesign/mykhata-2.0` with a message summarizing the four Phase-3 items and listing the spacing-converted files. Do NOT push.
      Files: (all above)
      Verify: `git status` shows only intended `lib/` files staged; `flutter analyze` + `flutter test` green; `git log --oneline -1` shows the new Phase 3 commit on the branch.

## Assumptions / gaps noted
- The brief's suggested `AppRadius` names (sm/md/card/lg) are extended to `button/dialog/profile` because the real theme uses 18/24/26 as distinct, intentional values; snapping them would be a visual change, which is forbidden. If the implementer prefers fewer names, keep 18/24/26 as literals rather than merging them — do NOT change the values.
- Flatter hero gradient target stops are a reasonable starting point; the implementer should pick stops that keep white text ≥ 4.5:1 and still read as teal. If a device check later shows the gradient is now too flat to read as a "hero," nudge the delta up slightly — but never back to the old banner contrast.
- `IconSquareButton` drops the old `cardShadow` on square buttons by design (calm rule). This is a small, intentional, consistent visual simplification, not an accidental regression; noted here so review expects it.
