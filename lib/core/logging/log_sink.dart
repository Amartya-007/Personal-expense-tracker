import 'log_entry.dart';

/// Where [AppLogger] persists entries. Implemented by the SQLite log
/// repository; tests supply fakes.
abstract class LogSink {
  /// Stores [entries] in order. May throw; the logger swallows failures.
  Future<void> writeBatch(List<AppLogEntry> entries);

  /// Keeps only the newest [maxEntries] entries.
  Future<void> trim(int maxEntries);
}
