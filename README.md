# MyKhata

A fully local, offline-first personal expense and finance tracker for Android, built with Flutter.

MyKhata keeps all of your money data on your own device — no account, no cloud, no ads, no tracking. It tracks expenses, income and transfers across multiple bank accounts, reads bank SMS to suggest transactions, watches your budgets, and turns it all into clear insights.

> Package: `mykhata` · Version: `1.0.0+1` · Dart SDK: `^3.13.4` · Primary target: **Android**

---

## Highlights

- **Local-first & private.** Everything lives in an on-device SQLite database. No login, no server, no network dependency for core features. Currency is INR (₹).
- **Fast transaction entry.** A single gold **+** action adds an Expense, Income, or Transfer. The common case is a few taps — amount, category, save — with everything optional tucked behind an **Add details** section.
- **Bank SMS detection.** MyKhata reads bank/UPI SMS (with permission) and queues suggested transactions for you to review, confirm, or ignore — individually (via the pre-filled add form) or in a batch.
- **Budgets that think ahead.** Per-category budgets with weekly/monthly/yearly periods, live progress, a "₹X/day left" allowance, threshold alerts (75% / 90% / 100%), suggested limits from your past spending, and lightweight history.
- **Insights.** Spending-by-category donut, income-vs-expense, spending trend, breakdowns by payment method and account — scoped to the range you pick.
- **Calm, consistent UI.** A Material 3 design system (teal brand, gold primary action, true-green income / red expense, the Sora typeface) with a shared card/row/sheet language, a floating glass navigation pill, and motion that communicates state rather than decorates.

---

## Features

### Money
- **Expenses, Income, and Transfers** between accounts, all through one add-transaction flow.
- **Multiple accounts** with balances, a primary/default account, and recorded **balance adjustments** (not silent edits).
- **Categories** (with inferred emoji) and **Tags**.
- **Notes, receipts (camera/gallery), and location** attachable to any transaction type.
- **Recurring payments & reminders** with Paid / Later / Delete actions and local notifications.

### Finding & reviewing
- **Search** (merchant, note, amount, category) with debounced results.
- **Deep filtering**: type, date period + custom range, amount range, categories, tags, accounts, payment methods, has-receipt, has-note, has-location, recurring, plus sort options.
- **Quick-filter chips** for the most common views, and per-day running totals in the ledger.
- **Swipe to delete** (with undo) and **swipe to quick-edit** category/amount.
- **Recently deleted** recovery and a **soft-delete + undo** safety net.

### Bank SMS
- Automatic background detection (permission-gated), **Scan inbox**, and **Paste message** ingestion.
- A review queue (Detected / Added / Ignored) with best-effort bank→account matching.
- Confirmed SMS transactions keep their provenance ("Detected from SMS").

### Data & safety
- **Full backup & restore**, plus **CSV / PDF export** and **CSV import**.
- **Biometric / PIN lock** and a **privacy mask** that hides amounts.
- **Delete all data** with an automatic safety backup taken first.
- Light / Dark / System theme, and a global haptics toggle.

---

## Tech stack

- **Flutter** (Material 3), **Dart `^3.13.4`**
- **State management:** `flutter_riverpod`
- **Local database:** `sqflite` / `sqflite_common_ffi`
- **Auth / security:** `local_auth`
- **Media & files:** `image_picker`, `image`, `file_picker`, `path_provider`, `archive`
- **Location:** `geolocator`, `geocoding`
- **Notifications:** `flutter_local_notifications`
- **Charts:** `fl_chart`
- **Export/import:** `csv`, `pdf`
- **Misc:** `permission_handler`, `shared_preferences`, `intl`, `uuid`, `crypto`, `google_fonts`

---

## Project structure

The app follows a layered architecture (UI → providers → repositories/services → data).

```
lib/
├── main.dart
├── core/
│   ├── constants/      # app colors, shared constants
│   ├── database/       # SQLite setup
│   ├── logging/
│   ├── navigation/     # AppRoutes, page transitions
│   ├── permissions/
│   ├── security/
│   ├── theme/          # AppPalette, AppText, AppMotion, AppTheme, AppSpacing, AppRadius
│   └── utils/          # formatters, date filters, keyboard helpers
├── data/
│   ├── models/         # TransactionModel, AccountModel, BudgetModel, etc.
│   └── repositories/   # data access over SQLite
├── services/
│   ├── analytics/      # insights & summaries
│   ├── backup/ export/ import/
│   ├── location/
│   ├── notifications/
│   ├── receipts/
│   └── sms/            # SMS parsing & detection
└── presentation/
    ├── providers/      # Riverpod providers (incl. composed homeOverviewProvider)
    ├── screens/        # home, transactions, add_transaction, budgets,
    │                   # insights, sms_review, settings, accounts, recurring,
    │                   # onboarding, lock, main (nav shell)
    └── widgets/        # shared UI: AppCard, Pressable, SegmentedTabs, PillChips,
                        # IconSquareButton, EmptyState, AsyncSection, Skeleton, …
```

### Design system (quick reference)
- **Brand:** teal (`#0F766E` / dark `#2DD4BF`). **Primary action accent:** warm gold (`#FFB627`), reserved for the add FAB.
- **Status:** income green (`#15803D`), expense red (`#D92D3A`) — deliberately distinct from the teal brand.
- **Type:** Sora, with tabular figures for money so amounts align.
- **Tokens:** `AppSpacing`, `AppRadius`, three shadow elevations, and theme-aware colors via `context.palette`. Content cards use a single edge signal (border *or* shadow, no gradient); floating chrome (nav pill, FAB, sheets) keeps elevation.

---

## Getting started

### Prerequisites
- Flutter SDK (Dart `^3.13.4` or compatible) — run `flutter doctor` to verify your setup.
- An Android device or emulator (API 21+).

### Run
```bash
flutter pub get
flutter run
```

### Build a release APK
```bash
flutter build apk --release
```

### App launcher icons
After changing the logo in `assets/logo/`, regenerate icons:
```bash
dart run flutter_launcher_icons
```

---

## Permissions

MyKhata requests permissions only for the features you enable:

- **SMS** — to detect bank/UPI messages and suggest transactions (optional; you can paste messages instead).
- **Location** — to optionally tag transactions with where they happened.
- **Camera / storage** — to attach receipts.
- **Notifications** — for recurring-payment reminders.
- **Biometrics** — for the optional app lock.

All processing happens on-device.

---

## Development

### Static analysis
```bash
flutter analyze
```

### Tests
```bash
flutter test
```

### Coverage
```bash
flutter test --coverage
```

Lints are configured via `flutter_lints` (see `analysis_options.yaml`).

---

## Privacy

MyKhata is designed to be **completely local**. Your transactions, accounts, budgets, receipts, and SMS data never leave your device. There is no analytics SDK, no remote backend, and no login. Backups are files you control and store wherever you choose.


---

## License

Released under the [MIT License](LICENSE) © 2026 Amartya Vishwakarma.
