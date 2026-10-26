import '../constants/app_constants.dart';

/// Centralized source of truth for MyKhata's Legal & Privacy documentation.
///
/// Keeps legal content consistent across Settings, About, and Onboarding screens.
/// Legal statements reflect the app's actual local-first implementation and applicable law.
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
      title: '1. Scope & Local-First Architecture',
      body:
          'MyKhata is a personal expense and finance tracking application designed '
          'to operate entirely on your device (Local-First architecture). It does '
          'not require an online user account or a developer-operated remote server '
          'backend for its core functionality. All financial records are stored '
          'securely in a local SQLite database on your device.\n\n'
          'MyKhata does not transmit your financial data, transaction history, or '
          'personal records to developer-controlled servers. However, operating '
          'system functions, cloud backup services you independently configure, '
          'or third-party file destinations may process data under their own terms. '
          'This Policy governs solely how information is handled within the application.',
    ),
    (
      title: '2. Information Stored & Processed Locally',
      body:
          'Depending on the features you actively use, MyKhata stores and processes '
          'the following information exclusively on your device:\n\n'
          '• Transactions: Amounts, dates, descriptions, categories, tags, and payment methods.\n'
          '• Accounts & Budgets: Account names, balances, budget thresholds, and spending analytics.\n'
          '• Split Participants & Groups: Names and optional phone numbers entered manually '
          'or selected via device contacts for expense splitting.\n'
          '• Receipts & Attachments: Images or files associated with specific transactions.\n'
          '• Bank Messages: Transaction details extracted from supported SMS messages '
          'via local parsing algorithms.\n'
          '• App Preferences: Settings, display themes, and local diagnostic logs.\n\n'
          'MyKhata does not collect highly sensitive credentials such as passwords, '
          'PINs, or full payment-card numbers. Avoid entering such details into free-text fields.',
    ),
    (
      title: '3. Bank SMS Processing & Permissions',
      body:
          'To automate expense tracking, MyKhata may request permission to read bank or UPI '
          'notification/SMS messages (READ_SMS). When granted, message processing occurs '
          'entirely on-device to suggest transaction entries for your review.\n\n'
          '• You maintain absolute control over this permission via Android system settings.\n'
          '• Revoking SMS permission disables automated detection; manual entry remains fully available.\n'
          '• Automatically detected entries are suggestions only and do not replace official bank statements.\n'
          '• SMS data is never uploaded to external servers or shared with third parties.',
    ),
    (
      title: '4. Location Permission',
      body:
          'Location permission is strictly optional and requested only if you enable '
          'features that tag transactions with geographic coordinates. If granted, '
          'location data is saved locally alongside the relevant transaction record. '
          'You may revoke this permission at any time through your device settings without '
          'affecting core tracking features.',
    ),
    (
      title: '5. Contact Access & Expense Splitting',
      body:
          'MyKhata requests read-only contact permission (READ_CONTACTS) solely to simplify '
          'selecting participants for split expenses and groups.\n\n'
          '• Optional Access: Declining or revoking contact access does not restrict app usage.\n'
          '• Manual Entry: You can type participant names and numbers manually at any time.\n'
          '• No Address Book Upload: MyKhata never uploads, syncs, or copies your address book '
          'to any server. Contacts are read dynamically from your OS when picker dialogs open.\n'
          '• Saved Data: Only names and phone numbers of participants you explicitly select or '
          'save are stored in your local database.',
    ),
    (
      title: '6. Camera, Files & Device Authentication',
      body:
          '• Camera & Storage: Used exclusively for capturing receipt images, exporting CSV/JSON '
          'reports, and managing local backup files.\n'
          '• Device Authentication: If enabled, MyKhata integrates with device biometrics (fingerprint/PIN) '
          'for app-lock security. Biometric templates are processed entirely by your OS hardware '
          'and are never accessed or stored by MyKhata.',
    ),
    (
      title: '7. Backups, Exports & Sharing',
      body:
          'You control your data through local backup, restore, and export functions. '
          'Exported files (such as database backups or spreadsheets) saved outside the app\'s '
          'private directory are subject to the security practices of the storage destination '
          'or sharing app you choose. You are responsible for securing exported files against '
          'unauthorized access.',
    ),
    (
      title: '8. Third-Party Services & Analytics',
      body:
          'MyKhata contains no embedded advertising networks, user-tracking SDKs, or remote '
          'analytics collectors. The application does not monetize your financial data.',
    ),
    (
      title: '9. Data Retention, Deletion & User Control',
      body:
          'Your data remains on your device until you delete specific entries, use the "Delete All Data" '
          'utility in Settings, or uninstall the application. Uninstalling the app or clearing '
          'app storage permanently deletes the local SQLite database and all associated attachments. '
          'Because storage is local, you are solely responsible for maintaining external backups.',
    ),
    (
      title: '10. Children\'s Privacy',
      body:
          'MyKhata is a personal productivity utility intended for users of legal age of majority. '
          'Minors should use the application only under the supervision of a parent or legal guardian.',
    ),
    (
      title: '11. Policy Updates',
      body:
          'This Privacy Policy may be updated periodically to reflect software enhancements or '
          'regulatory changes. Continued use of the app after updates constitutes acceptance '
          'of the revised terms.',
    ),
  ];

  // ───────────────────────────────────────────────────────────────────────────
  // TERMS & CONDITIONS
  // ───────────────────────────────────────────────────────────────────────────

  static const String termsLastUpdated = 'October 2026';

  static const List<({String title, String body})> termsSections = [
    (
      title: '1. Acceptance of Terms',
      body:
          'By downloading, installing, or using MyKhata, you agree to be bound by these Terms '
          '& Conditions. If you do not agree, you must immediately uninstall and discontinue '
          'use of the application.',
    ),
    (
      title: '2. Nature of Service & No Financial Advice',
      body:
          'MyKhata is an offline-first record-keeping and budgeting tool. It is not a bank, '
          'financial institution, tax advisory firm, investment broker, or legal counsel. '
          'Calculations, summaries, and budget insights are provided for informational '
          'purposes only and do not constitute professional financial or legal advice.',
    ),
    (
      title: '3. User Responsibilities & Lawful Use',
      body:
          'You are solely responsible for the accuracy of all data entered, imported, or '
          'managed within MyKhata. You agree not to use the application for any unlawful '
          'purpose, unauthorized financial tracking, or infringement of third-party rights.',
    ),
    (
      title: '4. Automated Detection & Calculation Disclaimers',
      body:
          'Automated SMS parsing, category tagging, and balance calculations are assistive '
          'features subject to occasional formatting errors or missed messages. You must '
          'independently verify financial figures against official bank records before making '
          'financial decisions.',
    ),
    (
      title: '5. Local Storage & Data Loss Disclaimer',
      body:
          'Because MyKhata operates locally without developer cloud sync, you are solely responsible '
          'for securing your device and maintaining regular app backups. The developer is not '
          'liable for data loss resulting from device damage, theft, factory resets, uninstalled '
          'updates, or corrupted backup files.',
    ),
    (
      title: '6. Permissions',
      body:
          'App features require specific device permissions (SMS, Contacts, Camera, Storage, Biometrics). '
          'Granting permissions is voluntary, though disabling essential permissions may limit '
          'associated app functionality.',
    ),
    (
      title: '7. Intellectual Property & Open Source Licensing',
      body:
          'The application name, UI layout, and branding are the property of the developer. '
          'MyKhata is distributed under the MIT License as specified in the project repository. '
          'Third-party libraries retain their respective open-source licenses.',
    ),
    (
      title: '8. Warranty Disclaimer',
      body:
          'To the maximum extent permitted by applicable law, MyKhata is provided on an "AS IS" '
          'and "AS AVAILABLE" basis without warranties of any kind, whether express or implied, '
          'including fitness for a particular purpose or error-free operation.',
    ),
    (
      title: '9. Limitation of Liability',
      body:
          'To the maximum extent permitted by law, the developer shall not be liable for any '
          'indirect, incidental, special, or consequential damages, including loss of data, '
          'profits, or anticipated savings, arising out of or related to your use of MyKhata.',
    ),
    (
      title: '10. Modifications & Termination',
      body:
          'The developer reserves the right to modify, suspend, or discontinue MyKhata or '
          'these Terms at any time without prior notice, subject to applicable legal requirements.',
    ),
    (
      title: '11. Governing Law & Dispute Resolution',
      body:
          'These Terms shall be governed by and construed in accordance with the laws of India. '
          'Any legal disputes arising from or relating to these Terms shall be subject to the '
          'exclusive jurisdiction of the courts located in Jabalpur, Madhya Pradesh, India.',
    ),
    (
      title: '12. Severability',
      body:
          'If any provision of these Terms is found to be invalid or unenforceable, the remaining '
          'provisions shall continue in full force and effect.',
    ),
  ];
}
