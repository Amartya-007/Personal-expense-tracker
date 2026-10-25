/// The area of the app a log entry belongs to.
enum LogCategory {
  app('app', 'App'),
  database('database', 'Database'),
  transactions('transactions', 'Transactions'),
  budgets('budgets', 'Budgets'),
  sms('sms', 'SMS'),
  backup('backup', 'Backup'),
  restore('restore', 'Restore'),
  importData('import', 'Import'),
  exportData('export', 'Export'),
  permissions('permissions', 'Permissions'),
  settings('settings', 'Settings');

  const LogCategory(this.value, this.label);

  /// Stable value stored in the database.
  final String value;

  /// Human-readable name for the UI.
  final String label;

  /// Parses a stored value. Unknown values fall back to [app].
  static LogCategory fromValue(String? raw) {
    final v = raw?.trim().toLowerCase();
    for (final c in LogCategory.values) {
      if (c.value == v) return c;
    }
    return LogCategory.app;
  }
}
