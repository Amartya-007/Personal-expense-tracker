class AppConstants {
  static const String appName = 'MyKhata';
  static const String currencySymbol = '₹';
  static const String currencyCode = 'INR';

  // Payment methods offered across the app (add transaction, filters).
  static const List<String> paymentMethods = ['UPI', 'Cash', 'Debit Card'];

  // DB Pagination
  static const int defaultPageSize = 30;
  static const int undoDurationSeconds = 10;

  // Preferences Keys
  static const String prefDefaultUpiAccount = 'default_upi_account_id';
  static const String prefIsOnboardingComplete = 'is_onboarding_complete';
  static const String prefBiometricsEnabled = 'biometrics_enabled';
  static const String prefUserName = 'user_name';
  static const String prefAutoSmsDetection = 'auto_sms_detection';
  static const String prefAutoLocationCapture = 'auto_location_capture';
  static const String prefThemeMode = 'theme_mode';
  static const String prefHapticsEnabled = 'haptics_enabled';

  // Database
  // BUG FIX: single source of truth for the DB file name used by both
  // DatabaseHelper and BackupService. The old backupDbFileName ('mykhata_backup.sqlite')
  // was misleading dead code that didn't match the actual file name.
  static const String dbFileName = 'mykhata.db';

  // Backup
  static const String backupVersion = '1.0';
  static const String backupManifestFileName = 'manifest.json';
}
