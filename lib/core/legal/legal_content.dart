import '../constants/app_constants.dart';

/// Centralized source of truth for MyKhata's Legal & Privacy documentation.
///
/// Keeps legal content consistent across Settings, About, and Onboarding screens.
/// Legal statements should reflect the app's actual implementation and applicable law.
/// Review this content whenever app functionality, permissions, or legal requirements change.
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
          'to operate primarily on your device without requiring an account or a '
          'remote application backend for its core functionality. Financial records '
          'are maintained in a local SQLite database, and supported processing is '
          'intended to take place on your device.\n\n'
          'MyKhata does not intentionally transmit your financial records to a '
          'developer-operated cloud service as part of its ordinary core operation. '
          'However, your device operating system, enabled integrations, third-party '
          'libraries, file-sharing destinations, or other software may perform '
          'separate processing where applicable. You should review the relevant '
          'platform and service policies where those features are used.\n\n'
          'This Policy explains how information is handled by the application. '
          'It does not override applicable law or the privacy terms of third-party '
          'services.',
    ),
    (
      title: '2. Information Stored & Processed',
      body:
          'Depending on the features you use, MyKhata may store or process the '
          'following information locally on your device:\n\n'
          '• Transactions: Amounts, dates, descriptions, transaction types, '
          'categories, tags, payment methods, and other details you enter or confirm.\n'
          '• Accounts: Account names, recorded balances, and balance adjustments.\n'
          '• Budgets & Insights: Budget limits, spending records, and information '
          'derived from your recorded transactions.\n'
          '• Receipts & Images: Images or attachments you choose to associate '
          'with a transaction.\n'
          '• Location: Location information if you enable and use a location-related '
          'feature and the application obtains that information.\n'
          '• Bank Messages: Relevant message content or extracted transaction '
          'details processed through supported SMS features, subject to the '
          'permissions granted and the actual implementation.\n'
          '• Preferences & Diagnostics: Application settings, operational events, '
          'warnings, and errors used to support local troubleshooting.\n\n'
          'The precise information stored depends on your actions, enabled '
          'permissions, and the features available in your installed version. '
          'You should avoid entering passwords, PINs, full payment-card credentials, '
          'or other highly sensitive information into free-text fields unless '
          'strictly necessary.',
    ),
    (
      title: '3. Bank SMS Processing & Permission',
      body:
          'MyKhata may request SMS-related permission to support its bank '
          'message detection feature. Where you grant the required permission '
          'and the feature is available, the application processes supported '
          'banking or UPI-related messages to identify possible transaction '
          'details and present suggestions for your review.\n\n'
          'SMS processing is intended to occur locally on your device in '
          'accordance with the application’s implementation. You remain in '
          'control of whether to grant or revoke the relevant device permission, '
          'subject to Android system controls. If permission is denied or '
          'revoked, SMS-dependent functionality may be unavailable or limited. '
          'Manual entry or message pasting may be available as an alternative.\n\n'
          'Detected transaction details may be incomplete or inaccurate. '
          'Review the amount, date, account, and other details before confirming '
          'a suggested transaction. A detected message is not an official bank '
          'statement or independent verification of a payment.\n\n'
          'You should access or process messages only where you have the '
          'necessary rights and authority. Granting permission does not waive '
          'applicable privacy rights, legal requirements, or platform rules. '
          'SMS access and use remain subject to applicable law and the policies '
          'of the distribution platform.',
    ),
    (
      title: '4. Location Permission & Information',
      body:
          'MyKhata may request location permission to provide location-related '
          'transaction features. If you grant the required permission and use '
          'a feature that captures location, the application may obtain and '
          'save location information with the relevant record, as supported '
          'by your device and the application’s implementation.\n\n'
          'You may deny or revoke location permission through your device '
          'settings. Doing so may limit location-related functionality. '
          'Revoking permission does not necessarily delete location information '
          'already saved with existing transactions.\n\n'
          'Location information can be sensitive. Enable this permission only '
          'if you want to use the associated functionality, and review saved '
          'records when sharing or exporting your data.',
    ),
    (
      title: '5. Camera, Files & Device Authentication',
      body:
          'MyKhata may request camera or file and media access to support '
          'receipt capture, image attachments, backups, imports, or exports, '
          'depending on the feature used and the permissions required by '
          'your Android version.\n\n'
          'If you grant the relevant permission or select a file through a '
          'system-provided picker, the application may process the selected '
          'image or file for the requested function. Denying or revoking '
          'permission may limit the associated feature. Files already exported '
          'or shared may remain outside the application’s control.\n\n'
          'If you enable the application lock, MyKhata may use supported '
          'device authentication mechanisms. Authentication is handled through '
          'the relevant device facilities. MyKhata is not intended to collect '
          'or store biometric templates. The application lock should not be '
          'understood as a guarantee that every database, attachment, backup, '
          'or exported file is separately encrypted.\n\n'
          'Permission grants and device authentication do not eliminate all '
          'security risks. Protect your device and any financial files you '
          'create or share.',
    ),
    (
      title: '6. Backups, Exports, Imports & Sharing',
      body:
          'MyKhata provides supported backup, restore, import, and export '
          'functions so that you can manage your financial records. Where the '
          'relevant function operates locally, the application prepares or reads '
          'the selected file on your device.\n\n'
          'Depending on the function and destination you choose, a file may be '
          'saved to a location outside the application’s private storage or '
          'shared with another application or service. Once a file is exported, '
          'copied, uploaded, emailed, or otherwise shared, its handling may be '
          'outside MyKhata’s control and may be governed by the recipient’s '
          'policies and security practices.\n\n'
          'Exports and backups may contain sensitive financial information. '
          'Check the destination, protect files against unauthorized access, '
          'and verify that a backup can be restored before relying on it. '
          'Importing an untrusted or incompatible file may cause incorrect '
          'records, data conflicts, or other problems.',
    ),
    (
      title: '7. Analytics, Advertising & Third-Party Services',
      body:
          'MyKhata is designed without an application-operated advertising '
          'business, user-tracking system, or remote analytics service as part '
          'of its core functionality. The application is not intended to sell '
          'your financial records or use them for targeted advertising.\n\n'
          'This statement describes the intended application architecture and '
          'must remain consistent with the actual release build, dependencies, '
          'permissions, and integrations. Operating-system services, app '
          'distribution platforms, third-party libraries, or applications you '
          'choose to use may process technical or other information under their '
          'own terms. This Policy does not make representations on behalf of '
          'those independent providers.',
    ),
    (
      title: '8. Retention, Deletion & User Control',
      body:
          'Your records are generally retained locally until you delete them, '
          'reset application data, uninstall the application, or the relevant '
          'data is otherwise removed through the device or application’s '
          'operation. The precise effect depends on the type of record, storage '
          'location, operating-system behaviour, and the application version.\n\n'
          'Where supported, you can edit or delete individual records and use '
          'the Delete All Data function in Settings. The application may create '
          'a local safety backup before a full reset. You should review the '
          'confirmation and backup options before proceeding.\n\n'
          'Deleting records from the application does not necessarily delete '
          'separate exported files, copies in shared folders, files held by '
          'other applications, or backups you created elsewhere. If you no '
          'longer need those copies, you must manage them separately.\n\n'
          'Because MyKhata is designed primarily for local storage, you are '
          'responsible for maintaining any backups you wish to retain. Deleted '
          'data may not be recoverable.',
    ),
    (
      title: '9. Children & Authorized Use',
      body:
          'MyKhata is intended as a personal finance utility. If you are not '
          'legally competent to accept the applicable terms, you should use '
          'the application only with the involvement and authorization of a '
          'parent, guardian, or other person where required by law.\n\n'
          'Do not access, import, record, or disclose another person’s financial '
          'or message information without appropriate permission or another '
          'lawful basis. Users are responsible for ensuring that their use of '
          'the application complies with applicable privacy and data protection '
          'requirements.',
    ),
    (
      title: '10. Privacy Policy Changes & Contact',
      body:
          'This Policy may be revised to reflect changes in application '
          'functionality, security practices, third-party integrations, or '
          'applicable legal requirements. The revised Policy will be identified '
          'by an updated date when published.\n\n'
          'You should review this Policy periodically and after material '
          'changes to the application. Where applicable law requires notice, '
          'consent, or another action for a change, that requirement will '
          'continue to apply.\n\n'
          'For privacy-related questions or requests, use the developer contact '
          'details provided on the official application listing or another '
          'official support channel, if available.',
    ),
  ];

  // ───────────────────────────────────────────────────────────────────────────
  // TERMS & CONDITIONS
  // ───────────────────────────────────────────────────────────────────────────

  static const String termsLastUpdated = 'October 2026';

  static const List<({String title, String body})> termsSections = [
    (
      title: '1. Acceptance, Scope & Eligibility',
      body:
          'These Terms & Conditions govern your access to and use of MyKhata, '
          'a personal expense and finance tracking application. By installing '
          'or using the application, you acknowledge that you have had an '
          'opportunity to review these Terms and agree to them to the extent '
          'permitted by applicable law.\n\n'
          'If you do not agree to these Terms, discontinue use of the '
          'application and uninstall it if you no longer wish to keep it. '
          'If you are not legally competent to accept these Terms, use the '
          'application only with the authorization or involvement required '
          'by applicable law.\n\n'
          'Nothing in these Terms excludes any rights or protections that '
          'cannot lawfully be excluded or restricted.',
    ),
    (
      title: '2. Intended Purpose & No Professional Advice',
      body:
          'MyKhata is a record-keeping and budgeting utility intended to help '
          'you organize financial information that you enter, import, or confirm. '
          'It is not a bank, payment service provider, investment platform, '
          'lender, tax practitioner, accounting firm, or legal adviser merely '
          'because it records financial information.\n\n'
          'Unless expressly stated otherwise in a separate written agreement, '
          'the application does not provide personalized financial, investment, '
          'tax, accounting, or legal advice. Budgets, charts, forecasts, alerts, '
          'summaries, and other calculations are informational outputs based '
          'on available records and implemented rules. They may not reflect '
          'your complete financial position.\n\n'
          'You should obtain qualified professional advice where appropriate '
          'and independently verify information before making important '
          'financial, tax, legal, or business decisions.',
    ),
    (
      title: '3. User Responsibilities & Lawful Use',
      body:
          'You are responsible for the information you enter, import, edit, '
          'confirm, export, or otherwise manage through MyKhata. You should '
          'review transaction amounts, dates, account assignments, categories, '
          'balances, and other material details for accuracy.\n\n'
          'You agree not to use the application to facilitate unlawful activity, '
          'obtain unauthorized access to information, violate another person’s '
          'rights, interfere with device or application security, or process '
          'information without the permission or legal authority required in '
          'the circumstances.\n\n'
          'You must comply with applicable laws, valid platform requirements, '
          'and any permissions or restrictions governing information you access. '
          'You remain responsible for determining whether your particular use '
          'of the application is lawful.',
    ),
    (
      title: '4. Accuracy, Calculations & Automated Detection',
      body:
          'MyKhata may calculate balances, categorize transactions, generate '
          'spending summaries, issue budget alerts, and identify possible '
          'transactions from supported bank or UPI messages. These functions '
          'depend on the data available and the rules implemented in the '
          'application.\n\n'
          'Incorrect entries, duplicate imports, unsupported message formats, '
          'rounding, missing records, changes in bank message formats, or '
          'software defects may result in incomplete or inaccurate results. '
          'An automatically detected message is a suggestion and is not a '
          'substitute for an official bank statement or payment confirmation.\n\n'
          'You should check material figures against authoritative records '
          'and correct discrepancies before relying on the information. '
          'MyKhata does not guarantee that every transaction will be detected, '
          'categorized, calculated, or displayed without error.',
    ),
    (
      title: '5. Local Storage, Backups & Data Loss',
      body:
          'MyKhata is designed primarily for local storage and does not provide '
          'a developer-operated cloud synchronization service as part of its '
          'core functionality. Unless a separate supported mechanism is '
          'explicitly provided, the developer cannot restore records that '
          'exist only on a device or in a backup that is unavailable.\n\n'
          'You are responsible for securing your device, keeping your operating '
          'system updated, protecting exported files, and creating and checking '
          'backups appropriate to your needs. Device loss, damage, theft, '
          'factory reset, application removal, storage failure, file corruption, '
          'or other events may result in partial or permanent data loss.\n\n'
          'To the extent permitted by applicable law, the developer is not '
          'responsible for loss caused by circumstances beyond reasonable '
          'control or by your failure to maintain a usable backup. This clause '
          'does not exclude liability that cannot lawfully be excluded.',
    ),

    (
      title: '6. Permissions & Optional Features',
      body:
          'MyKhata may request access to SMS, location, camera, files or media, '
          'notifications, and device authentication where required to provide '
          'specific features. The permissions requested depend on the features '
          'you choose to use, your Android version, and the application’s '
          'implementation.\n\n'
          'You may grant, deny, or revoke permissions through the available '
          'Android permission controls. If you deny or revoke a permission, '
          'the corresponding functionality may be unavailable or limited. '
          'Where supported, alternative methods of entering information may '
          'remain available.\n\n'
          'You are responsible for using the application lawfully and for '
          'having the authority required to access or process information '
          'you provide. However, granting a permission does not remove the '
          'developer’s own obligations under applicable law or authorize '
          'processing beyond the permission’s scope or the application’s '
          'disclosed purposes.\n\n'
          'The availability and use of permissions remain subject to Android '
          'system controls, applicable legal requirements, and the rules of '
          'the relevant distribution platform.',
    ),

    (
      title: '7. Intellectual Property & Permitted Use',
      body:
          'Subject to applicable law and the terms of any relevant open-source '
          'licence, the application’s name, original branding, original design '
          'elements, and developer-created materials remain the property of '
          'their respective rights holders.\n\n'
          'MyKhata is distributed under the MIT License as identified in the '
          'project’s licence file. The MIT License governs the rights it grants '
          'in the covered software and takes precedence over any inconsistent '
          'restriction in these Terms concerning rights expressly granted '
          'under that licence.\n\n'
          'Third-party libraries, fonts, and other components may be subject '
          'to their own licences and notices. You are responsible for complying '
          'with those terms where applicable.',
    ),
    (
      title: '8. Warranty Disclaimer',
      body:
          'To the maximum extent permitted by applicable law, MyKhata is '
          'provided on an “AS IS” and “AS AVAILABLE” basis. The developer '
          'does not warrant that the application will be uninterrupted, '
          'error-free, compatible with every device, or capable of meeting '
          'every individual requirement.\n\n'
          'To the extent legally permissible, implied warranties or conditions '
          'that may lawfully be disclaimed are disclaimed. No statement in '
          'these Terms excludes a warranty, consumer right, or remedy that '
          'applicable law requires to remain available.\n\n'
          'The application’s calculations, data storage, automated detection, '
          'security features, and export functions should not be treated as '
          'infallible or as a substitute for independent verification.',
    ),
    (
      title: '9. Limitation of Liability',
      body:
          'To the maximum extent permitted by applicable law, the developer '
          'shall not be liable for indirect, incidental, special, exemplary, '
          'or consequential loss arising from the use of, or inability to use, '
          'MyKhata, including loss of anticipated savings, business opportunity, '
          'or data, where such exclusion is lawful.\n\n'
          'Nothing in these Terms excludes or limits liability for fraud, '
          'fraudulent misrepresentation, wilful misconduct, or any other '
          'liability that cannot lawfully be excluded or limited. Nothing in '
          'these Terms removes mandatory consumer protections or other '
          'non-waivable rights available under applicable law.\n\n'
          'Where liability may lawfully be limited, the limitation applies '
          'only to the extent permitted by the law applicable to the relevant '
          'claim and circumstances. These Terms do not create an exemption '
          'from criminal law, regulatory obligations, or liability arising '
          'from conduct for which the law provides no such exemption.',
    ),
    (
      title: '10. Updates, Changes & Discontinuation',
      body:
          'The application may be updated to improve functionality, address '
          'defects, maintain compatibility, or respond to security or legal '
          'requirements. An update may change, add, limit, or discontinue '
          'features, subject to applicable law and any rights that cannot '
          'lawfully be restricted.\n\n'
          'These Terms may also be revised when necessary. The published '
          'version should identify its latest revision date. Where a change '
          'requires advance notice, renewed consent, or another action under '
          'applicable law, the developer must follow that requirement.\n\n'
          'Continued use does not override any mandatory legal requirement '
          'for express acceptance or consent. If you do not agree to a revised '
          'version, you may discontinue use, subject to any rights or '
          'obligations that continue under applicable law.',
    ),
    (
      title: '11. Governing Law & Dispute Resolution',
      body:
          'These Terms are intended to be interpreted in accordance with '
          'the laws of India, subject to applicable conflict-of-law rules '
          'and mandatory legal protections.\n\n'
          'Any dispute relating to the application or these Terms shall be '
          'addressed through the remedies and procedures available under '
          'applicable law. Courts and authorities having lawful jurisdiction '
          'may hear matters in accordance with those rules.\n\n'
          'Nothing in this clause prevents a user from exercising a mandatory '
          'consumer right, approaching a competent regulatory authority, or '
          'using a statutory dispute-resolution mechanism where available.',
    ),
    (
      title: '12. Severability & Entire Agreement',
      body:
          'If a provision of these Terms is held unlawful, invalid, or '
          'unenforceable by a competent authority, that provision shall be '
          'given effect to the maximum extent lawfully permitted or severed '
          'to the extent necessary. The remaining provisions shall continue '
          'to apply where legally valid.\n\n'
          'These Terms and the Privacy Policy describe the general terms '
          'applicable to MyKhata, together with any applicable open-source '
          'licences and other terms expressly incorporated by reference. '
          'They do not override mandatory law or a separate binding agreement '
          'that lawfully governs a particular matter.',
    ),
  ];
}
