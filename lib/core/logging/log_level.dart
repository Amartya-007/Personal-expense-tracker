/// Severity of a log entry, lowest to highest.
enum LogLevel {
  debug('debug', 'Debug'),
  info('info', 'Info'),
  warning('warning', 'Warning'),
  error('error', 'Error');

  const LogLevel(this.value, this.label);

  /// Stable value stored in the database.
  final String value;

  /// Human-readable name for the UI.
  final String label;

  /// Parses a stored value. Unknown values fall back to [info] so a row from
  /// an older or newer version can still be shown.
  static LogLevel fromValue(String? raw) {
    switch (raw?.trim().toLowerCase()) {
      case 'debug':
        return LogLevel.debug;
      case 'warning':
      case 'warn':
        return LogLevel.warning;
      case 'error':
        return LogLevel.error;
      default:
        return LogLevel.info;
    }
  }
}
