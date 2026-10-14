# Phase 3 "calm by default" — spacing/radius scales + single edge signal on cards

Phase 3 introduces two const token classes (`AppRadius`, `AppSpacing`) and a shared `IconSquareButton`, then uses them to collapse the app's doubled card edge-signal (border + shadow) down to a single hairline border, dial two gradients closer to flat, and replace two hand-rolled square buttons plus the Transactions search field. The change is committed as `d78d508` on `redesign/mykhata-2.0` off base `2df1e40`. The design intent is purely visual-calming and consistency; the explicit guardrail is that no radius or palette value shifts (every new constant equals the literal it replaced) and nav/FAB/speed-dial structure is untouched.

Watch for: the one deliberate visual change the author flagged — square buttons lose their `cardShadow` and the two gradient surfaces (Home hero, Settings profile) soften — all intentional and documented (confirmed). The Transactions search field drops its fixed `height: 52` and now sizes from `contentPadding`; row alignment with the 52px filter button relies on `Row` center-alignment rather than equal heights (possible, worth a visual glance but not blocking).

**Verdict**: APPROVED

## High-level view

The decorative-layering rule is enforced in exactly one place: `AppCard`'s `boxShadow` switch now maps `flat/low/medium → null` and only `high → shadowSm`. Because every content card uses the default `medium`, they all flip from border+`shadowMd` to border-only in a single edit with zero call-site churn, which is the cleanest possible way to land this. `shadowMd`/`shadowLg` are no longer referenced by any `AppCard` and remain reserved for floating chrome (nav pill, FAB, sheets, dialogs) that lives outside the widget.

Radii and spacing are now named constants whose values are byte-equal to the prior literals, so routing the theme, `appFieldDecoration`, `AppCard`, and the touched screens through them is a pure consistency move with no visual delta. The author kept `26` (profile) and `24` (dialog) as distinct named steps rather than snapping them, correctly avoiding a visual change. Spacing adoption was confined to literals that already equalled a token in Home, Transactions, and Budgets — no repo-wide replace.

The two gradients were softened by introducing a new `heroGradientSoft` token (light + dark) rather than editing the existing `heroGradient`; the original hero/profile gradient hex values are untouched and the base teal/gold/green/red palette is byte-for-byte unchanged. The soft variant keeps the same lighter start stop and lifts the darker end stop closer to it, so the surface reads flatter while staying teal and keeping white-on-teal legible.

`IconSquareButton` consolidates the two per-screen square buttons; it bakes in `Pressable` (matching the old call-site wrapping, so no double-wrap), preserves each button's icon, size, badge, semantics, and tap, and drops the old `cardShadow` to match the calm rule — a small, consistent, documented simplification. The Transactions search field is now routed through the shared `appFieldDecoration`, preserving the 250 ms debounce, clear suffix, prefix icon, hint, and `TextInputAction.search`.

<details>
<summary>Issues (2)</summary>

1. **Search field height no longer pinned** — the old search was a fixed `height: 52` container; the new `TextField` sizes from `appFieldDecoration` + `contentPadding(vertical: 15)` and relies on `Row` default center-alignment against the 52px filter button. Likely visually fine but not height-matched by construction; worth one visual glance. (possible, non-blocking)
2. **Verification evidence is self-reported** — `flutter analyze` / `flutter test` (~103) results come from the coder's note, not re-run here per the brief. No articulable doubt warranted a spot-check, so none was run. (informational)

</details>

<details>
<summary>Details</summary>

### Decorative layering centralized in AppCard

The core change lives entirely in `app_card.dart`'s `build`. The `boxShadow` switch previously resolved `low → shadowSm`, `medium → shadowMd`, `high → shadowLg`; it now resolves `flat/low/medium → null` and `high → p.shadowSm`. Since `AppCard`'s default `elevation` is `CardElevation.medium` and `shadow` defaults `true`, every content card that didn't opt out — `SettingsGroup`, `TransactionListCard`, Insights cards, `_ThisMonthStrip`, `_SmsAttentionCard`, `_BudgetAlertCard`, the Budgets overview card, transaction-detail info/location cards, the Danger-zone card — drops its `shadowMd` and keeps only the hairline `Border.all(p.border)`. That is the doubled edge signal (border + shadow) reduced to one, applied without touching any call site. The `border` logic (`gradient == null ? Border.all(p.border) : null`), the `surfaceRaised` fill for `high`, the `shadow` flag, and gradient handling are all intact, so a caller passing `shadow: false` stays shadowless and gradient cards still draw no border (confirmed by reading the full widget).

I verified `shadowMd`/`shadowLg` are no longer referenced by any `AppCard` content path — only `high → shadowSm` remains, used by the hero. The heavier shadows stay available for the floating chrome (nav pill, FAB, bottom sheets, dialogs), none of which route through `AppCard`, so the "shadowMd/Lg reserved for floating chrome" obligation holds (confirmed).

Dark-mode separation after removing content shadows rests on `Border.all(p.border)` (`#21383C`) between `background #071214` / `surface #0E1D20` / `surfaceRaised #132428`. Content cards always draw that border when non-gradient, and no palette value changed, so the surfaces stay distinguishable without the removed shadow — the one place removing a shadow could have flattened the UI, and it does not (confirmed against the ground-truth palette).

### Radius and spacing tokens equal prior literals

`AppRadius` (`sm=14, md=16, button=18, card=20, dialog=24, profile=26, lg=28`) and `AppSpacing` (`xs=4, sm=8, md=12, lg=16, xl=24, xxl=32`) are plain const classes matching the project's `AppColors`/`AppText` style, each with `///` docs. The theme's radius literals (`Card 20`, `FAB 20`, `ElevatedButton 18`, three input borders `16`, chip `20`, bottom-sheet `28`, dialog `24`, snackbar `16`), `appFieldDecoration`'s `16`, `AppCard`'s default `20`, the Home hero `28`/account-chip `16`, and the Settings profile `26`/About-tile `24` were each swapped for the matching constant. Every substitution is value-equal, so no radius shifts — including `profile=26` and `dialog=24`, which the author kept as distinct named steps rather than snapping them (correct, since snapping would be a visual change). No one-off/typo radius was found or introduced (confirmed).

Spacing adoption was limited to literals already equal to a token, in Home (`ListView` top pad `16→lg`, avatar gap `12→md`, section gaps `16→lg`/`24→xl`), Transactions (title pad `16/12→lg/md`, search-row gap `8→sm`), and Budgets (`ListView` top pad `16→lg`, two section gaps `16→lg`). The horizontal `18`, the `+130` nav reserve, and odd steps like `14` were left literal. No mechanical repo-wide replace (confirmed against the diff).

### Softened gradients via a new token, palette hues intact

`heroGradientSoftLight` (`#0D756B → #0B5E60`) and `heroGradientSoftDark` (`#0D6B65 → #0A3C42`) are new `AppColors` constants plumbed through `AppPalette.heroGradientSoft`. The existing `heroGradientLight` (`#0D756B → #0A4A52`) and `heroGradientDark` (`#0D6B65 → #082F36`) are unchanged, and the base teal `#0F766E`/`#2DD4BF`, gold `#FFB627`, green `#15803D`, red `#D92D3A` are untouched — so no palette hue changed (confirmed by reading `app_colors.dart`). The soft variant reuses the lighter start stop and lifts the darker end stop toward it, shrinking the top-left→bottom-right delta while staying teal.

Home `_HeroCard` now passes `heroGradientSoft` and keeps `CardElevation.high`, so via the layering change it loses `shadowLg` and keeps a subtle `shadowSm` — "dialed near-flat, still a hero," matching the brief. White text sits on dark-teal stops (lightest is `#0D756B`), which keeps white comfortably above AA 4.5:1 in both themes; the privacy eye stays a circle (correctly left out of the square-button consolidation). Settings profile switched to the same `heroGradientSoft` with `radius: AppRadius.profile`; its gradient branch draws no border and no shadow, leaving exactly one signal (gradient). The About-sheet logo tile keeps `heroGradient` and only tokenised its radius — fine, it is a decorative tile, not a content card.

### IconSquareButton consolidation

`IconSquareButton` is a new `StatelessWidget` with a const primary constructor and `///` docs. It renders a `size`×`size` surface fill with `Border.all(p.border)`, radius `size > 44 ? AppRadius.md : AppRadius.sm` (mirroring the old `_SquareButton`'s `16/14` rule exactly), centered icon, optional `badge` overlay via `Stack`, optional `semanticLabel` via `Semantics(button: true)`, and bakes in `Pressable`. The old `_SquareButton` was wrapped in `Pressable` at its call site, so baking it in avoids a double-wrap (confirmed in the diff).

In Transactions, the Filter button (`tune_rounded`, `iconSize: 20`, `size: 52`, gold active-count badge, `_openFilterSheet` tap) is reproduced faithfully, and the now-unused `_SquareButton` class and `pressable.dart` import were removed. In Budgets, the inline 40×40 `+` container (`BorderRadius.circular(14)` + `cardShadow`) became `IconSquareButton(icon: Icons.add, size: 40, semanticLabel: 'Create budget')` with its tap preserved and the `pressable.dart` import dropped. `ManagementScaffold`'s extended FAB and the global speed-dial were not touched (confirmed). The dropped `cardShadow` on both buttons is the one intentional, documented visual simplification consistent with the calm rule.

### Transactions search routed through themed input

The bespoke 52px search `Container` was replaced with a `TextField` whose decoration is `appFieldDecoration(p, hint: ...)` `.copyWith(...)` to re-attach the search prefix, the clear suffix, and `contentPadding(horizontal: 16, vertical: 15)`. The 250 ms debounce (`_onSearchChanged`), the `ValueListenableBuilder`-driven clear (✕) suffix, the hint, and `TextInputAction.search` are all preserved, and the field stays inside `Expanded` so the row won't overflow against the fixed-size filter button (confirmed in the diff). The one behavioral delta worth a glance: the field no longer pins its own height (the old container forced `52`); it now sizes from `contentPadding`, and vertical alignment with the 52px filter button relies on the `Row`'s default center cross-alignment. This is very likely fine but is not height-matched by construction — a quick visual check on the Transactions header would close it. Not blocking.

### Guardrails and verification

No nav/FAB/speed-dial structural change, no palette hue change, no blind repo-wide replace, dark-mode surface separation preserved via the always-present border, and the existing design system was reused (tokens and a shared widget, not a parallel system) — all confirmed from the diff. The coder's note records `flutter analyze` clean and `flutter test` at `+103` all passing, plus a `dart format` reflow and a mechanical `dart fix` on `getCategoryEmoji` (the large but behavior-preserving curly-brace churn visible in the `app_colors.dart` diff). Per the brief I did not re-run the suites and found no specific, articulable doubt that would justify a narrow spot-check: the diff is internally consistent with the note, imports of removed widgets are cleaned up, and no new public symbol is undocumented. Verification evidence is present, so this is accepted as self-reported rather than independently re-executed.

</details>

<details>
<summary>File map</summary>

- `lib/core/theme/app_radius.dart` (new) — `AppRadius` const token class.
- `lib/core/theme/app_spacing.dart` (new) — `AppSpacing` const token class.
- `lib/presentation/widgets/icon_square_button.dart` (new) — shared square icon button, border-only, bakes in `Pressable`.
- `lib/presentation/widgets/app_card.dart` — shadow switch flipped to border-only for content, `high → shadowSm`; default radius via `AppRadius.card`; doc updated.
- `lib/core/theme/app_theme.dart` — radius literals routed through `AppRadius` (plus formatter reflow).
- `lib/presentation/widgets/field_decoration.dart` — `appFieldDecoration` radius `16 → AppRadius.md`.
- `lib/core/constants/app_colors.dart` — new `heroGradientSoftLight/Dark`; `getCategoryEmoji` reflowed by `dart format`/`dart fix` (behavior-preserving).
- `lib/core/theme/app_palette.dart` — `heroGradientSoft` field wired for light/dark (plus formatter reflow of shadow getters).
- `lib/presentation/screens/home/home_screen.dart` — hero uses `heroGradientSoft`, radii/spacing tokenised.
- `lib/presentation/screens/settings/settings_screen.dart` — profile card uses `heroGradientSoft`, radii tokenised (plus formatter reflow).
- `lib/presentation/screens/transactions/transaction_history_screen.dart` — Filter button → `IconSquareButton`, search → `appFieldDecoration`, `_SquareButton` removed, spacing tokenised.
- `lib/presentation/screens/budgets/budget_list_screen.dart` — inline `+` button → `IconSquareButton`, spacing tokenised.

Full diff: `git diff 2df1e40 d78d508`.

</details>
