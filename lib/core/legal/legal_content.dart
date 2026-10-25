import '../constants/app_constants.dart';

/// Centralized source of truth for MyKhata's Legal & Privacy documentation.
///
/// Keeps legal content consistent across Settings, About, and Onboarding screens.
/// All statements are strictly based on the app's verified 100% local, offline architecture.
class LegalContent {
  LegalContent._();

  static const String appVersion = AppConstants.appVersion;
  static const String appName = AppConstants.appName;

  // ───────────────────────────────────────────────────────────────────────────
  // PRIVACY POLICY
  // ───────────────────────────────────────────────────────────────────────────

  static const String privacyPolicyLastUpdated = 'October 2026';

  static const List<({String title, String body})> privacyPolicySections = [
    (
      title: '1. Local-First & Offline Architecture',
      body:
          'MyKhata is designed as a 100% local, offline-first personal finance application. '
          'All your financial data—including accounts, transactions, category rules, budgets, tags, '
          'and receipts—is stored exclusively in a local SQLite database on your device ($appName database). '
          'MyKhata does not operate remote servers, cloud databases, user tracking systems, or background telemetries. '
          'Your financial information never leaves your phone unless you manually export a backup or spreadsheet file yourself.',
    ),
    (
      title: '2. Information Stored on Your Device',
      body:
          '• Transactions & Balances: Custom descriptions, amounts, timestamps, payment methods, categories, and tags you create.\n'
          '• Bank Accounts: Account names and current balance figures entered during setup or management.\n'
          '• Receipts & Images: Photo attachments saved in private application storage on your internal device disk.\n'
          '• App Settings & Preferences: UI theme selections, haptic feedback toggles, biometric lock preference, and display preferences.\n'
          '• Diagnostic Logs: Local event and error logs stored in SQLite to help troubleshoot issues on your phone.',
    ),
    (
      title: '3. Bank SMS Message Processing',
      body:
          'If you grant SMS permission, MyKhata inspects incoming bank messages locally on your device to extract '
          'transaction amounts and account details into a review queue. SMS parsing occurs entirely on-device '
          'using local regular expression rules. Messages are never sent to external servers, and no transaction is added '
          'to your permanent ledger until you explicitly review and confirm it.',
    ),
    (
      title: '4. Location Information',
      body:
          'If you enable location capture, MyKhata records your approximate geographical coordinates '
          'only at the exact moment you save an expense or income transaction. Location data is saved locally '
          'with the transaction record. You can disable location capture at any time in App Settings.',
    ),
    (
      title: '5. Biometric Lock & Security',
      body:
          'When enabled, biometric authentication (fingerprint, face recognition, or device PIN) uses your Android device’s '
          'native system authentication APIs (local_auth). Your biometric templates remain securely stored inside your device’s '
          'Hardware Security Module (HSM) / Secure Enclave and are never accessible to or stored by MyKhata.',
    ),
    (
      title: '6. Backups, Exports & Data Transfer',
      body:
          'When you create a ZIP backup or export CSV/PDF reports, the file is created locally on your device and saved '
          'to the directory you select (such as your Downloads folder). You retain full ownership and control over these files. '
          'We recommend storing your backup files securely.',
    ),
    (
      title: '7. Analytics & Third-Party Sharing',
      body:
          'MyKhata does not include third-party analytics SDKs, advertising networks, tracking pixels, or remote telemetry tools. '
          'We do not collect, sell, rent, or monetize your personal or financial data in any way.',
    ),
    (
      title: '8. Data Control & Deletion',
      body:
          'You hold complete control over your data. You can delete individual transactions, edit accounts, or perform a complete data reset '
          'via "Delete All Data" in Settings. Performing a complete data reset permanently purges all local SQLite records and cached receipts '
          'from your device after creating an optional local safety backup.',
    ),
  ];

  // ───────────────────────────────────────────────────────────────────────────
  // TERMS & CONDITIONS
  // ───────────────────────────────────────────────────────────────────────────

  static const String termsLastUpdated = 'October 2026';

  static const List<({String title, String body})> termsSections = [
    (
      title: '1. Acceptance of Terms & Intended Use',
      body:
          'By installing and using MyKhata, you agree to these Terms & Conditions. '
          'MyKhata is provided as a personal expense-tracking and financial organization utility for individual, non-commercial use. '
          'You agree to use the app in accordance with applicable local laws and regulations.',
    ),
    (
      title: '2. Non-Financial & Non-Professional Advice Disclaimer',
      body:
          'MyKhata is an informational record-keeping software tool. Calculations, budget alerts, and spending trend analytics '
          'are generated automatically based on user-entered data and preset rules. '
          'MyKhata DOES NOT provide professional financial, investment, accounting, tax, or legal advice. '
          'You should independently verify figures before making financial or business decisions.',
    ),
    (
      title: '3. Data Security & Backup Responsibility',
      body:
          'Because MyKhata stores all records locally on your device without cloud synchronization: '
          '• You are responsible for securing your physical device using a screen lock, PIN, or biometric lock.\n'
          '• You are responsible for regularly exporting local backups via Settings to protect against device loss, damage, or reset.\n'
          'MyKhata is not liable for data loss resulting from device hardware failure, uninstallation, operating system updates, or unbacked-up resets.',
    ),
    (
      title: '4. Accuracy of Calculations & Bank SMS Parsing',
      body:
          'SMS parsing rules and automated spending calculations are provided to assist manual tracking. '
          'Different financial institutions format messages differently, and parsing may occasionally misinterpret amounts or account names. '
          'You are encouraged to review detected messages before confirming them into your ledger.',
    ),
    (
      title: '5. Limitation of Liability',
      body:
          'MyKhata is provided "AS IS" and "AS AVAILABLE" without warranties of any kind, express or implied. '
          'To the maximum extent permitted by law, the developer shall not be liable for any direct, indirect, incidental, '
          'or consequential damages resulting from the use or inability to use this application.',
    ),
    (
      title: '6. Modifications & Updates',
      body:
          'These terms may be updated from time to time to reflect changes in app features or legal standards. '
          'Continued use of MyKhata after updates constitutes acceptance of the revised terms.',
    ),
  ];
}
