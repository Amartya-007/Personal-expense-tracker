# MyKhata — Current-State UI/UX Findings

A factual map of the existing implementation, read-only. Written for a lead product designer who will author a full redesign proposal. Every claim below is grounded in the files cited; where a path and symbol are named, that is where the behavior lives. No code was modified.

---

## Summary (read this first)

MyKhata is a Flutter + Riverpod, local-first (SQLite) personal finance app. The UI layer lives under `lib/presentation/` and is already more coherent than a typical first draft: it has a real design-system foundation (`AppPalette`, `AppText`, `AppMotion`, `AppCard`, `Pressable`, `FadeSlideIn`), a shared navigation helper (`AppRoutes`), and a themed single-source `AppTheme`. There is clear evidence of a recent consolidation pass — code comments explicitly note removed duplication (e.g. the Home quick-actions row, a duplicated SMS badge, a decorative budget period selector that didn't filter).

The app shell is a 5-tab floating glass pill nav (Home, Transactions, Budgets, Insights, Settings) with a gold speed-dial FAB (Expense / Income / Transfer) shown only on Home and Transactions. Secondary/infrequent features (Accounts, Categories, Tags, Recurring, Receipts, Backup, Recently deleted, SMS review) live under Settings or are reached contextually.

Key strengths: consistent card/row/sheet language, tabular-figure money styling, staggered entrance animations, centralized haptics, privacy-mask mode wired across screens, a genuinely deep transaction filter model, and sensible defaults in the add-transaction flow (primary account default, amount autofocus, quick-add chips).

Key friction points found (detail in §14): the add-transaction form shows Note/Tags/Location/Receipt **only for Expense** (Income/Transfer can't attach them); several destinations are reachable from 2–3 entry points (SMS review from 3 places; Recurring from Home + Settings; Recently deleted from Transactions header + Settings); the Transactions screen uses hand-rolled square buttons and a bespoke search bar instead of the shared components; and the `_ThisMonthStrip` / Insights / Budgets numbers come from several independent providers that can momentarily disagree.

---

## 1. Navigation & app shell

**File:** `lib/presentation/screens/main/main_navigation_screen.dart`

- **Bottom nav items & order** (`_navItems`, lines ~335–343): `Home` (home_rounded), `Transactions` (receipt_long_rounded), `Budgets` (pie_chart_rounded), `Insights` (bar_chart_rounded), `Settings` (settings_rounded). Each `_NavItem` carries a filled + outlined icon; the selected tab uses the filled icon, scaled 1.12× with a bounce curve, plus a bold 10px label.
- **Nav pill styling** (`_FloatingNavBar`): a floating rounded pill (`borderRadius 26`, height `_navHeight = 66`), positioned `left/right: 14`, `bottom: max(12, safeArea.bottom)`. It is **glass**: `BackdropFilter` blur 18, fill `p.glass`, hairline `p.glassBorder`, `shadowMd`. A soft teal "indicator" pill (`p.primarySoft`) slides between tabs via `AnimatedPositioned` (duration `AppMotion.slow`, curve `AppMotion.emphasized`).
- **Tab state** is held in `mainTabProvider` (a `StateProvider<int>` in `settings_providers.dart`), so any screen can switch tabs (Home's "See all" links do this). Tab switching fires `AppHaptics.select()`.
- **Tab body** (`_AnimatedTabBody`): NOT an `IndexedStack`. It lazily builds each tab on first visit (`_visited` set), keeps visited tabs alive via `Offstage` + `TickerMode`, and cross-fades + lifts the newly selected tab (`FadeTransition` + `SlideTransition`, 280ms). Honors `disableAnimations`.
- **FAB** (`_buildFab`): gold gradient rounded-square (58×58, radius 20), gold glow shadow, white hairline border. The `+` icon rotates 0→135° when the speed-dial opens (`_fabRotation`). FAB is shown only on tabs in `_fabTabs = {0, 1}` (Home, Transactions) and animates in/out with `AnimatedScale`+`AnimatedOpacity` as tabs change.
- **Speed-dial** (`_buildSpeedDialOption`): three options rising above the FAB — **Transfer** (swap_horiz, teal), **Income** (south_west, green), **Expense** (north_east, red). Each is a surface card with a colored icon chip; they scale-in with staggered `Interval(0.1*index, …, bounce)`. Opening the dial drops a frosted scrim (`BackdropFilter` blur 6 + `AppColors.overlay`) that closes on tap.
- **Back behavior** (`PopScope`): back closes the speed-dial first, then returns to Home (tab 0), then exits the app. `canPop` only when on Home with dial closed.
- **Android intent handling** (`_intentChannel` = `com.MyKhata.mykhata/intent`): supports `ACTION_ADD_EXPENSE` (opens add-expense modal) and `ACTION_VIEW_BUDGETS` (jumps to Budgets tab) — i.e. home-screen app shortcuts.
- **Snackbar lift**: the whole shell is wrapped in a `Theme` that raises `snackBarTheme.insetPadding` above the nav pill / FAB so floating snackbars don't sit under the chrome.

**Routing abstraction** — `lib/core/navigation/app_routes.dart`:
- `AppRoutes.push` — standard themed push (slide-from-right + fade, via `AppPageTransitionsBuilder` applied through `ThemeData.pageTransitionsTheme`).
- `AppRoutes.pushModal` — **slide-up** full-screen task flows (used for Add Transaction).
- `AppRoutes.fadeReplace` / `fadeResetTo` — cross-fade replacement (onboarding ↔ app; used after "delete all data").
- `AppPageTransitionsBuilder` makes the incoming page fade+slide from the right while the page beneath drifts left 6%.

---

## 2. Home screen

**File:** `lib/presentation/screens/home/home_screen.dart` (a `ConsumerWidget`; a `RefreshIndicator` wrapping a single `ListView`). Sections top→bottom, each wrapped in `FadeSlideIn` with an increasing `index` for a staggered entrance:

1. **Header row** — `_Avatar` (initial-in-circle, uses `userNameProvider`) + greeting (`_getGreeting()` by hour) + name (`AppText.display`). Not tappable.
2. **Hero balance card** — `_HeroCard`, fed by `accountListProvider`. Gradient card (`p.heroGradient`, radius 28, `CardElevation.high`) with two translucent discs + sheen for depth. Shows **total tracked balance** (sum of `currentBalance` across accounts) counting up via `TweenAnimationBuilder` (900ms). A privacy eye toggles `privacyModeProvider`. Below the total, a horizontal strip of per-account chips (name, star if primary, balance); **tapping a chip opens the "Edit balance" sheet** (`_editBalance` → `showFieldsSheet` → `homeControllerProvider.updateAccountBalance`, which records a balance adjustment).
3. **SMS attention card** — `_SmsAttentionCard`, shown **only when** `smsQueueProvider('detected').length > 0`. Tapping → `AppRoutes.push(SmsReviewScreen())`. This is the only Home surface pointing at SMS review (comment notes it replaced a former header pill + badge).
4. **This-month strip** — `_ThisMonthStrip`, fed by its own `homeMonthSummaryProvider` (always current month). Three figures: Income (green), Spent (red), Saved/Over (green/red). **Tapping sets `selectedDateRangeProvider = thisMonth` and jumps to Insights tab (3).**
5. **Budgets** — `SectionHeader('Budgets', action 'See all' → Budgets tab 2)`, fed by `budgetListProvider`. Shows up to **3** `BudgetRow`s; empty state offers "Create a budget" (jumps to Budgets tab). Each row tap → Budgets tab.
6. **Recent transactions** — `SectionHeader('Recent transactions', 'See all' → Transactions tab 1)`, fed by `recentTransactionsProvider` (last 5). Renders `TransactionListCard`; tapping a row → `AppRoutes.push(TransactionDetailScreen)`. Empty state offers "Add expense" (`pushModal` add-expense).
7. **Upcoming recurring** — `SectionHeader('Upcoming recurring', 'Manage' → push `RecurringPaymentsScreen`)`, fed by `recurringListProvider`. Up to 3 `ListRowTile`s; tapping a row opens `_showRecurringActionSheet` (Mark as paid / Remind me later / Delete rule). Empty state offers "Add one".
8. **Insights** — rendered **only when** `homeInsightsProvider` returns non-empty "smart observation" strings; a single `AppCard` of bullet lines. No tap target.

Scroll padding reserves `safeArea.bottom + 130` for the floating nav. Pull-to-refresh invalidates recent/insights/month providers and reloads accounts/budgets/recurring in place.

---

## 3. Transactions

**Files:** `lib/presentation/screens/transactions/transaction_history_screen.dart`, `transaction_detail_screen.dart`; provider `transaction_providers.dart`; filter UI `widgets/filter_bottom_sheet.dart`.

### History screen (`TransactionHistoryScreen`, `ConsumerStatefulWidget`)
- **Header**: "Transactions" title (`AppText.display`) + a `_SquareButton` 🗑 opening `RecentlyDeletedScreen` (`AppRoutes.push`).
- **Search**: a bespoke 52px rounded container (NOT the themed input) with a `TextField`; 250ms debounce → `setSearchQuery`. Hint: "Search merchant, note, amount, category...". Clear (✕) when non-empty.
- **Filter button**: `_SquareButton` with `tune_rounded`; a gold badge shows `filter.activeFilterCount`. Opens `FilterSheet.show` (advanced filter bottom sheet).
- **Active filter chips** (`_ActiveFilterChips`): a horizontal strip of removable chips reflecting each active dimension, plus a "Clear All".
- **Summary banner** (`_SummaryBanner`): count + total expense/income for the current filter (from `getFilteredSummary`).
- **List**: grouped by day (`_groupByDay`), each group under a `_DayHeader` (Today/Yesterday/d MMM + "Spent …" for that day). Rows render via `TransactionListCard` with swipe-to-delete enabled. Infinite scroll (`_onScroll` → `fetchMore`, 30/page). Pull-to-refresh → `fetchInitial`.
- **States**: initial loading → two `SkeletonCard`s; empty → `EmptyState` (differs for filtered vs not: filtered shows 🔍 + "Clear all filters", unfiltered shows 🧾 + "Add expense"); error path logs but shows the empty list.
- **Delete + undo** (`_delete`): optimistic `softDeleteTransaction` + `UndoSnackbar.show` with an Undo that calls `restoreTransaction`. Deletes are **soft** (go to Recently deleted).
- Row tap → `TransactionDetailScreen`.

### Filter model (`TransactionFilter` in `transaction_providers.dart`)
Filter dimensions (all present): **searchQuery**, **type** (expense/income/transfer), **datePeriod** (named presets or Custom `DateTimeRange`), **minAmount/maxAmount**, **categoryIds** (incl. `'uncategorized'`), **tagIds**, **accountIds** (incl. `'primary'`), **paymentMethods**, **hasReceipt**, **isRecurring**, **hasNote**, **hasLocation**, and **sortBy** (`TransactionSortOption`: dateDesc/dateAsc/amountDesc/amountAsc/titleAsc/titleDesc). The filter sheet (`_FilterForm`) exposes type pills, date presets + custom range, amount min/max with presets + validation, a searchable multi-select category list, tag/account/payment multi-selects, the boolean toggles, and sort options. There is **no explicit "merchant" or "SMS source" filter dimension** (merchant is covered by free-text search; SMS source is not a filter — it's only shown on the detail screen).

### Detail screen (`TransactionDetailScreen`)
Fed by `transactionDetailProvider(id)`. Centered emoji + signed amount (counts via `FittedBox`) + description + type pill. An info `AppCard` of rows: Category, Payment method, Account (or From/To for transfers), Date, **Source** ("Detected from SMS" vs "Added manually"), Note, Created timestamp. Optional **Tags** (pills), **Location** card, **Receipts** (thumbnails → `ReceiptViewer` with Hero). Actions: **Edit** (`PrimaryButton` → push Add screen in edit mode) and **Delete** (confirm dialog → soft delete + undo snackbar, then pop).

---

## 4. Add transaction flow

**File:** `lib/presentation/screens/add_transaction/add_transaction_screen.dart` (`AddTransactionScreen(initialType, editTransaction?)`, `ConsumerStatefulWidget`). Opened via `pushModal` (slide-up). Form fields in order:

1. **Type** — `SegmentedTabs` [Expense, Income, Transfer]. Switching type refocuses the amount for a fresh entry.
2. **Amount** — large 44px borderless underline `TextField`, color-coded (expense red / income green / transfer teal), **autofocused on open** (new entries only). Below it: quick-add chips **+₹100 / +₹500 / +₹1000 / +₹2000** and a **Clear**. Required (> 0, else snackbar + refocus).
3. **"What's it for?" / Description / From** — for expense/income a free-text field (`appFieldDecoration`); for transfer, the **From account** dropdown. Expense description runs a keyword→category suggestion (`_keywordRules`, e.g. "swiggy"→Food) shown as "✨ Suggested: …". Required for non-transfer.
4. **Category / To** — for expense/income: a **quick 1-tap chip grid of the first 6 categories** (emoji + name, selected = teal) plus an `AppDropdown` ("Uncategorized" fallback) listing all. For transfer: the **To account** dropdown. Categories come from `incomeCategoriesProvider` / `expenseCategoriesProvider` by type.
5. **Payment method** (not transfer) — `SegmentedTabs` [UPI, Cash, Debit Card]. Default **UPI**.
6. **Account** (not transfer, hidden when Cash) — `AppDropdown` of accounts (balance subtitle, ⭐ for primary).
7. **Date** — three inline buttons: **Today** / **Yesterday** / a date-picker button (default = today). `firstDate 2020`, `lastDate` = now (no future dates).
8. **Expense-only block** (`if (_type == 'expense')`): **Note** (optional text), **Tags** (`MultiSelectField` from `tagsListProvider`), **Location** (read-only card; captured automatically on save via `LocationService`, shown as "Captured automatically when you save"), **Receipt** (thumbnail grid + add tile → camera/gallery sheet via `ReceiptStorageService`).
9. **Save** — `PrimaryButton` ("Save expense/income/transfer" or "Save changes"); shows loading; haptic success; snackbar; pops.

**Defaults & resolution logic** (`_effectiveAccount`, `_effectiveDestination`, `_effectiveCategory`, `_primaryDefault`): a brand-new **expense** defaults its account to the **primary account** (else `defaultUpiAccountProvider`, else first account). Transfers default destination to the first account that isn't the source. Editing keeps the transaction's own account/category even if removed from the list. Transfer description is auto-composed as "Source → Destination".

**Validation**: amount > 0; non-transfer requires a description; non-Cash requires at least one account to exist; transfer requires two **different** accounts. Save is guarded against double-submit (`_isSaving`) with try/catch/finally.

**Edit vs create**: same screen; `editTransaction` prefills amount/description/payment/date/note/tags/receipts and keeps `id`/`createdAt`. On create, `createTransaction`; on edit, `updateTransaction`; both trigger `BudgetAlertService.evaluate()` for expenses and refresh dependents.

**SMS-generated transactions do NOT reuse this screen.** They are confirmed inline on the SMS review card (`_SmsCard._confirm`), which builds a `TransactionModel` directly (type by debit/credit, `paymentMethod: 'UPI'`, `source: 'sms'`, `smsMessageId`, `externalReference`) — the add-transaction form is not opened. (See §8.)

> **Notable gap:** Note, Tags, Location, and Receipt are gated behind `_type == 'expense'`. Income and Transfer entries cannot attach any of them.

---

## 5. Accounts

**File:** `lib/presentation/screens/settings/accounts_management_screen.dart` (reached from **Settings → Manage → Accounts**; not a bottom-nav tab). Built on the shared `ManagementScaffold<AccountModel>` (`list_widgets.dart`) which provides AppBar, empty state, grouped list, and an **extended FAB "Add account"**.

- **Account model fields** (from usage): `id`, `name`, `currentBalance`, `initialBalance`, `isPrimary`, `createdAt`, `updatedAt`. (No explicit bank-type/color field surfaced in UI; emoji is ⭐ for primary else 🏦.)
- **Add** (`_add`): `showFieldsSheet` with "Account name" (required) + "Current balance" (numeric, default 0) + a switch "Use as primary account". Creates via `accountListProvider.createAccount`.
- **Primary concept** (`_togglePrimary`): star icon per row toggles primary (`setPrimaryAccount` / `clearPrimaryAccount`). Primary is used as the default account for new expenses and shown with ⭐ throughout.
- **Delete** (`_delete`): blocked if only one account remains ("Keep at least one account"); otherwise `confirmDestructive` (hides account, keeps existing transactions; warns if it was primary). Soft/hide semantics.
- **Balance adjustment** happens on **Home** (tap an account chip → `_editBalance` → `homeControllerProvider.updateAccountBalance`), which records an adjustment rather than editing silently. There is no balance-edit affordance on the accounts management screen itself.

---

## 6. Budgets

**Files:** `lib/presentation/screens/budgets/budget_list_screen.dart`, `budgets/budget_form.dart`, `widgets/budget_row.dart`; provider `budget_providers.dart`.

- **Screen**: title + a **+** square button (`_createBudget`) and a **period `SegmentedTabs` [Weekly, Monthly, Yearly]** that genuinely filters (`list.where((b) => b.period == _period)`; a comment notes it used to be decorative).
- **Overview card** (when non-empty): a `CircularProgressIndicator` ring showing total used-% for the period, with "Left this month / Over this month by" + "of ₹X budgeted". Ring + figures animate.
- **Rows**: `BudgetRow` per budget inside a `SettingsGroup`. Each row shows category emoji + name, a status **badge** (percent, or "Exceeded"/"100%"), spent/limit, an `AnimatedProgressBar` colored by `budgetProgressColor(p, usedRatio)`, and a status line (either "Over by …", "Limit reached", or a **daily allowance** "₹X/day left (N days left)").
- **Create** (`BudgetForm`): requires at least one expense category; produces a `BudgetModel`. Period types: weekly/monthly/yearly.
- **Detail sheet** (`_showBudgetDetail`): big remaining/over figure, pace tip ("₹X/day for remaining N days"), progress bar, date range + "% used", an **ALERTS** group showing 75% / 90% / 100% thresholds (✅ reached vs ⏳), and **Edit limit** / **Delete budget** (delete has undo).
- **Model fields used**: `period`, `amount`, `spentAmount`, `remainingAmount`, `overAmount`, `usedRatio`, `percentage`, `startDate`, `endDate`, `categoryName`.
- **On Home**: top 3 budgets as `BudgetRow`s (read-only, tap → Budgets tab). **In Insights**: a "Budget progress" section shows up to 4 `BudgetRow`s. So budgets surface in **three** places (Budgets, Home, Insights) with the same row widget.
- Footer note: "You get a notification at 75%, 90% and 100% of each limit, once per period."

---

## 7. Insights

**File:** `lib/presentation/screens/insights/insights_screen.dart` (`ConsumerWidget`); providers `insights_providers.dart`. Uses `fl_chart`.

- **Range selector**: `PillChips` [Today, This Week, This Month, Last Month] bound to `selectedDateRangeProvider` (`DateTimeRangeType`). This is the provider Home's month-strip sets to `thisMonth` before jumping here.
- **Analytics body** (`analyticsSummaryProvider` → `AnalyticsSummaryModel`):
  - **Spending by category** (`_CategoryCard`): donut `PieChart` with center "Spent ₹…", legend of up to 5 categories + folded "Other (N)", each with % share. Colors from `AppColors.categoryPalette`.
  - **Income vs expense** (`_IncomeExpenseCard`): two `AnimatedProgressBar`s + net "Saved/Overspent".
  - **Spending trend** (`_TrendCard`, `spendingTrendProvider`): a curved `LineChart` with area fill + touch tooltips, real start/end date labels; falls back to a message when the period is a single day.
  - **By payment method** (`_PaymentBars`): simple animated bar chart with % labels.
  - **By account** (`accountBreakdown`): `ListRowTile`s with totals.
- **Budget progress** section (bottom): up to 4 `BudgetRow`s, "See all" → Budgets tab.
- Each section has its own empty state (no expenses / no payments / no account activity).

---

## 8. SMS review

**Files:** `lib/presentation/screens/sms_review/sms_review_screen.dart`; provider `sms_review_providers.dart`; model `SmsReviewModel`.

- **Queue model**: `smsQueueProvider.family<String>` keyed by **status**. Three statuses/tabs: **`detected`**, **`added`**, **`ignored`** (`SegmentedTabs`). The "Detected" tab label carries a count badge ("Detected · N"). `smsQueueStatusTabProvider` holds the active tab.
- **How messages arrive**: `SmsQueueNotifier.loadQueue` runs `processPendingMessages` + `collapseDuplicateDetected` then loads by status. Three ingestion paths: automatic (background detection, gated by `autoSmsDetectionProvider` + permission), **Scan inbox** (`scanInbox` → `scanInboxAndQueue`), and **Paste message** (`addPasted` → `queueManualMessages`, no permission needed; returns added/duplicate/unrecognized counts). The two tool buttons (`_ToolButton` Scan / Paste) sit at the top of the screen.
- **Permission banner**: when `smsPermissionProvider` is false, a 🔒 card ("SMS access is off") opens `showSmsPermissionHelp` (with a "paste instead" path). Re-checks on app resume.
- **Detected summary** (`_MessageList`, detected tab only): a card with "TO REVIEW / N messages" + Spent/Received totals. Messages are grouped under day headers.
- **Message card** (`_SmsCard`): icon + merchant + "bank · cardRef · time" + signed amount; a collapsible **"View original message"** (raw SMS). On the **detected** tab: an "Add to account" `AppDropdown` (only when >1 account; best-effort bank→account match via `_match`) and **Ignore** / **Confirm & add** buttons. Confirm builds the transaction directly (`source: 'sms'`), marks the SMS `added`, haptic success. Guarded against double-tap. On the **ignored** tab: a "Move back to detected" action.
- **Surfaced from**: Home SMS attention card (only when count > 0), **Settings → Automation → "Review detected messages"** (shows "N waiting"), and the permission-help "paste" shortcut. That's **three entry points** to the same screen.

---

## 9. Recurring payments & reminders

**File:** `lib/presentation/screens/settings/recurring_payments_screen.dart`; provider `recurring_providers.dart`; model `RecurringPaymentModel`.

- Built on `ManagementScaffold<RecurringPaymentModel>` (reached from Settings → Manage, from Home's "Upcoming recurring → Manage", and from Home empty-state actions).
- **Create** (`_RecurringForm`): requires at least one account + one expense category. Fields: Name, Amount, **Repeats** `SegmentedTabs` [Weekly/Monthly/Yearly], **Pay from** account dropdown, **Category** dropdown, **First due** date picker. `nextDueDate` defaults one cycle out (`_defaultDue`). Produces a rule with `paymentMethod: 'UPI'`.
- **Row**: 🔁 emoji, name, "Due {date} · {Frequency}", amount in expense color, delete icon.
- **Reminders / generating transactions**: handled on **Home** via `_showRecurringActionSheet` → `homeControllerProvider.processPaymentAction(item, action)` with actions **"Paid"** (records a payment / posts the transaction and advances the due date), **"Later"** (snooze 1 day), **"Delete"**. Model fields seen: `id`, `name`, `amount`, `categoryId`, `accountId`, `paymentMethod`, `frequency`, `nextDueDate`, `createdAt`.

---

## 10. Settings

**File:** `lib/presentation/screens/settings/settings_screen.dart` (`ConsumerWidget`). Sections (each `SectionHeader` + `SettingsGroup`):

- **Profile card** (gradient) — shows/edits saved name (`userNameProvider` via `showFieldsSheet`); subtitle "Local profile · INR · No account needed".
- **Manage**: Accounts (`AccountsManagementScreen`, subtitle shows primary), Categories (`CategoriesManagementScreen`), Tags (`TagsManagementScreen`), Recurring payments (`RecurringPaymentsScreen`), Receipts (`ReceiptGalleryScreen`).
- **Automation**: "Detect bank SMS" switch (requests SMS permission, with `showSmsPermissionHelp` on denial), "Review detected messages" (→ `SmsReviewScreen`, "N waiting"), "Save location with expenses" switch (requests location permission).
- **Data**: "Backup & data" (→ `BackupRestoreScreen`), "Recently deleted" (→ `RecentlyDeletedScreen`).
- **App**: "Biometric lock" switch (`authProvider.toggleBiometrics`), "Hide balances & amounts" switch (`privacyModeProvider`), "Haptic feedback" switch (`hapticsEnabledProvider`), "Appearance" (sheet with Light/Dark `SegmentedTabs`, `themeModeProvider`), "About" (sheet: version/offline/no-ads/no-login).
- **Danger zone**: "Delete All Data" (`_deleteAllData`) — `confirmDestructive`, blocking progress dialog, auto safety backup first (abort if backup fails), then clears state and resets to `OnboardingScreen`.

**Backup/restore mechanism** (`backup_restore_screen.dart` + `services/backup`, `services/export`, `services/import`): one screen consolidates **full backup/restore** (`BackupService`), **CSV/PDF export** (`ExportService`), and **CSV import** (`ImportService`). Operations run through `_run` (busy guard + progress), and `_announceSaved` keeps a dismissible message describing where the file was saved (handles Android's opaque document URIs via `BackupService.describeSavedLocation`).

---

## 11. Supporting features

- **Receipts**: capture via `ReceiptStorageService` in the add-expense form (camera/gallery sheet); view via `widgets/receipt_viewer.dart` (Hero-tagged full image from the detail screen) and browse via `settings/receipt_gallery_screen.dart` (`receiptGalleryProvider`). Model: `ReceiptModel` with `filePath`, `thumbnailPath`, `id`.
- **Tags**: `TagModel(id, name)`; managed in `settings/tags_management_screen.dart`; selected in add-expense via `MultiSelectField`; shown as pills on detail; filterable in Transactions. `tagProviders.dart` / `tagsListProvider`.
- **Location**: captured on save (expense only) via `LocationService` (`latitude`, `longitude`, `locationName`); shown on detail; filterable (`hasLocation`); gated by `autoLocationCaptureProvider` + permission.
- **Audit/history**: balance edits are recorded as **adjustments** (`updateAccountBalance`), and transactions carry `createdAt`/`updatedAt` (Created shown on detail). No dedicated audit-log screen was found.
- **Recently deleted (soft delete)**: `settings/recently_deleted_screen.dart` + `recentlyDeletedTransactionsProvider`; transactions soft-delete (restore via undo snackbar or this screen) and can be permanently deleted (`permanentlyDeleteTransaction`).
- **Privacy/mask mode**: `privacyModeProvider` (persisted). Masking is read in Home hero, month strip, budgets, insights, transaction rows, SMS totals — broad coverage. `CurrencyFormatter.format(..., isMasked:)` is the single masking seam.
- **Lock screen**: `screens/lock/lock_screen.dart` + `auth_guard.dart` + `authProvider` (biometrics/PIN gate on open; toggled in Settings).
- **Onboarding**: `screens/onboarding/onboarding_screen.dart` (first run; creates the first account; returned to after "delete all data").

---

## 12. Design system

**Color palette** — `lib/core/constants/app_colors.dart` resolved via `lib/core/theme/app_palette.dart` (`context.palette`, theme-aware):
- **Primary**: teal — light `#0F766E` (teal-700), dark `#2DD4BF` (teal-400). `onPrimary` white / near-black-teal.
- **Secondary**: warm gold — `#FFB627` / `#FFC247` (used *only* for the one primary action: the add FAB, badges). FAB text/icon `#2A1D00`.
- **Expense**: red `#D92D3A` / `#FF7A82`. **Income**: true green `#15803D` / `#5BE29A` (deliberately not teal, to avoid confusion with brand). **Transfer**: teal `#0F766E`. **Pending**: gold `#FFB627`.
- **Surfaces/neutrals**: light bg `#F2F6F6`, surface white, surface2 `#E6EEEE`, border `#D9E4E4`, ink `#0B1F24`, muted `#52696E`. Dark bg `#071214`, surface `#0E1D20`, surface2 `#16292D`, border `#21383C`, ink `#E8F3F2`, muted `#8FA9AC`.
- **Depth tokens** (palette getters): `primarySoft`, `surfaceRaised`, `glass` + `glassBorder` (for the blurred nav), `primaryGlow`, and three shadow elevations `shadowSm/shadowMd/shadowLg` (each a soft ambient + tighter key layer).
- **Gradients**: `heroGradientLight/Dark` (deep teal → near-black teal), used on the Home hero and Settings profile card. The FAB uses its own gold gradient. Comment-stated principle: gradients are reserved for hero surfaces, not scattered.
- **Category chart palette**: 7 distinct hues (`categoryPalette`). Category **emoji** are inferred from name via `AppColors.getCategoryEmoji`.

**Typography** — `lib/core/theme/app_text.dart`, font **Sora** (Google Fonts). Scale: `display` (26/800, tabular), `amount` (15/800, tabular figures), `overline` (11/700 caps), `title` (18/800), `section` (12/700), `body` (14/600), `bodyStrong` (14/700), `caption` (12/500), `button` (15/800). Money styles use **tabular figures** so amounts align and don't jitter while counting.

**Shape & spacing**: corner radii cluster around 14 (small controls), 16 (inputs/sheets inner), 18–20 (cards/buttons), 26–28 (hero/nav/dialogs/bottom-sheets). Screen padding is typically `18` horizontal; bottom padding reserves `safeArea.bottom + 130` for the nav pill. No formal numeric spacing scale constant — spacing is literal `SizedBox` values (common steps 2/4/6/8/10/12/14/16/18/22/24).

**Motion** — `lib/core/theme/app_motion.dart`: durations `instant 90 / fast 180 / medium 280 / slow 420`; curves `enter easeOutCubic`, `exit easeInCubic`, `standard easeInOutCubic`, `bounce easeOutBack`, `emphasized Cubic(0.2,0,0,1)`; a `stagger(index)` helper (capped at 8 steps).

**Theme** — `lib/core/theme/app_theme.dart`: single `_build(palette, brightness)` for both light/dark (M3, `ColorScheme.fromSeed`). Themes AppBar (flat, no tint, Sora 22/800), Card (radius 20, hairline border, 0 elevation), FAB (gold, radius 20), ElevatedButton (primary, radius 18), inputs (filled surface, radius 16, 2px focus), chips, dividers, bottom sheets (radius 28 top), dialogs (radius 24), snackbars (floating, ink bg). Page transitions use `AppPageTransitionsBuilder` app-wide.

**Haptics** — `lib/core/theme/app_haptics.dart`: `tap` (light), `select` (selection click), `success` (medium), `warning` (heavy); globally toggled by `AppHaptics.enabled` (bound to `hapticsEnabledProvider`).

---

## 13. Reusable components (catalogue)

In `lib/presentation/widgets/`:
- `app_card.dart` — **AppCard** + `CardElevation {flat, low, medium, high}`. The single card surface (color/border/shadow by elevation, optional gradient, optional `onTap` via InkWell). Used nearly everywhere.
- `pressable.dart` — **Pressable** (scale-down + dim + haptic on tap). The standard tap wrapper for non-button surfaces.
- `fade_slide_in.dart` — **FadeSlideIn** (staggered entrance by `index`; honors reduce-motion).
- `list_widgets.dart` — **SettingsGroup** (auto-divided row stack), **ListRowTile** (emoji/leading + title + subtitle + trailing/chevron), **ManagementScaffold<T>** (shared "manage a list" shell: AppBar + extended FAB + loading/error/empty + grouped list). Backbone of Settings, Accounts, Tags, Categories, Recurring.
- `transaction_row.dart` — **TransactionRow** + **TransactionListCard** (card of rows; swipe-to-delete via `Dismissible` when `onDelete` supplied). Shared by Home and Transactions.
- `budget_row.dart` — **BudgetRow** (shared by Budgets, Home, Insights).
- `empty_state.dart` — **EmptyState** (emoji + title + message + optional action; `compact` variant).
- `async_section.dart` — **AsyncSection<T>** (skeleton loading / error-with-retry / data). Used to render Riverpod `AsyncValue`s consistently.
- `skeleton.dart` — **Skeleton** / **SkeletonCard** loading placeholders.
- `app_sheets.dart` — **AppBottomSheet.show**, **showFieldsSheet** (`FieldSpec` driven generic form sheet, optional switch), **confirmDestructive** (shared confirm dialog). Central to add/edit/confirm flows.
- `app_dropdown.dart` — **AppDropdown<T>** (bottom-sheet-style picker: key/label/subtitle/emoji). Used for accounts/categories.
- `multi_select_field.dart` — **MultiSelectField** (tag/multi picking).
- `segmented_tabs.dart` — **SegmentedTabs** (the pill segmented control for type/period/payment).
- `pill_chips.dart` — **PillChips** (single-select chip row; Insights range selector).
- `primary_button.dart` — **PrimaryButton** (loading state + optional icon).
- `animated_progress_bar.dart` — **AnimatedProgressBar** + `budgetProgressColor` / `budgetProgressColor` helpers.
- `undo_snackbar.dart` — **UndoSnackbar.show** (delete + undo pattern).
- `filter_bottom_sheet.dart` — **FilterSheet** / `_FilterForm` (the advanced transaction filter).
- `section_header.dart` — **SectionHeader** (title + optional action link).
- `field_decoration.dart` — **appFieldDecoration** (shared input decoration).
- `receipt_viewer.dart`, `sms_permission_help.dart` — feature-specific shared widgets.

**Inconsistencies noted** (candidates for consolidation):
- **Square icon buttons** are hand-rolled per screen: `_SquareButton` in Transactions, an inline 40×40 container in Budgets, the hero privacy toggle, etc. — no shared `IconSquareButton`.
- **Search field** on Transactions is a bespoke container rather than the themed `InputDecoration`/`appFieldDecoration`.
- **Add affordances differ by screen**: Transactions/Home use the gold speed-dial FAB; Budgets/Accounts/Recurring use plain square **+** buttons or the M3 extended FAB from `ManagementScaffold`. Three different "add" visual patterns.
- **Period `SegmentedTabs` [Weekly/Monthly/Yearly]** appears in both Budgets and the recurring form; Insights uses a *different* range control (`PillChips` with Today/Week/Month/Last Month). Two different time-range controls in the same app.

---

## 14. Cross-screen workflows & duplication

**Multiple entry points to the same destination:**
- **SMS review** — reachable from (1) Home attention card (conditional), (2) Settings → Automation → "Review detected messages", (3) the SMS-permission help "paste" shortcut. The home card and the settings row both lead to the identical screen.
- **Recurring payments** — reachable from Home "Upcoming recurring → Manage", Home empty-state "Add one", and Settings → Manage → Recurring payments.
- **Recently deleted** — reachable from the Transactions header 🗑 button **and** Settings → Data → Recently deleted.
- **Add expense** — reachable from the speed-dial (Home/Transactions), Home/Transactions empty-state buttons, and the Android app-shortcut intent. (These are intentional and consistent — all go through `pushModal(AddTransactionScreen)`.)
- **Budgets** surface in three places (Budgets tab, Home preview, Insights "Budget progress") via the same `BudgetRow`.

**Data-flow fragmentation (visual-consistency risk):** Home's `_ThisMonthStrip` (`homeMonthSummaryProvider`), the Budgets preview (`budgetListProvider`), recent transactions (`recentTransactionsProvider`), and Insights (`analyticsSummaryProvider`) are independent providers. After a mutation, `TransactionListNotifier._refreshDependents()` invalidates most of them, but they resolve independently, so Home sections can briefly show stale/mismatched numbers during a refresh. (`skipLoadingOnReload: true` mitigates blinking but not momentary disagreement.)

**Interaction-pattern inconsistencies:**
- **Account balance editing** lives on Home (tap chip), not on the Accounts management screen where a user would expect it.
- **Transfer/Income can't carry Note/Tags/Location/Receipt** (expense-only block in the add form) — an asymmetry a redesign should resolve or justify.
- **Delete + undo** is consistent for transactions and budgets (good), but recurring/account deletes use plain confirm dialogs without undo.
- **"Add" visual language** is inconsistent across tabs (speed-dial vs square + vs extended FAB) as noted in §13.
- **Edit flows** differ: budgets/accounts edit via `showFieldsSheet` sheets; transactions edit via a full pushed form. Reasonable given complexity, but worth a conscious design decision.

**Things that are already well-consolidated (preserve in redesign):** single themed card/row/sheet/button system; one palette + one text scale + one motion spec; privacy masking through a single formatter seam; `AppRoutes` as the only navigation entry; comments throughout document prior de-duplication (removed Home quick-actions row, merged backup+export+import into one screen, replaced decorative controls).

---

## Conclusions & recommendations (for the designer — not implemented)

1. **Resolve the add-form asymmetry.** Decide deliberately whether Income/Transfer can carry note/tags/location/receipt. The current expense-only gating is almost certainly incidental, not a product decision.
2. **Rationalize entry points.** SMS review (3), Recurring (3), Recently deleted (2) each have redundant doorways. Keep the contextual one (Home card / "Manage") and the canonical one (Settings), and consider dropping the extras to reduce the "everything everywhere" feel the brief warns against.
3. **Unify the "add" affordance and the time-range control.** One add pattern (the speed-dial is the strongest) and one range control (`SegmentedTabs` vs `PillChips`) across Budgets/Insights/Recurring.
4. **Introduce a shared `IconSquareButton`** and route the Transactions search through the themed input to kill the per-screen reimplementations.
5. **Consider a single composed "home/overview" summary provider** so the hero, month strip, budgets and recent list derive from one consistent snapshot, removing momentary disagreement after mutations.
6. **Move balance adjustment onto the Accounts screen** (or make it reachable from both) so it lives where users manage accounts.
7. **Preserve the design-system foundation.** The palette, type scale, motion spec, card/row/sheet components, haptics, and privacy-mask seam are strong, coherent, and should anchor the redesign rather than be rebuilt.

*Scope note: this report maps the UI/UX implementation as written in `lib/presentation/` and `lib/core/theme`. It does not evaluate the data/repository or services layers beyond how screens call them, and no builds or tests were run.*
