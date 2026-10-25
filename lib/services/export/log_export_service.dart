import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../../core/logging/app_logger.dart';
import '../../core/logging/log_category.dart';
import '../../core/logging/log_entry.dart';
import '../../core/logging/log_export_document.dart';
import '../../data/repositories/log_repository.dart';

/// Exports the local diagnostic log as a JSON file the user saves
/// themselves (Android's system save dialog; no storage permission, no
/// network, no sharing to a server).
class LogExportService {
  final LogRepository _repository;
  final DateTime Function() _now;

  LogExportService({LogRepository? repository, DateTime Function()? clock})
    : _repository = repository ?? LogRepository(),
      _now = clock ?? DateTime.now;

  static const int _pageSize = 500;

  /// Every stored log, newest first, read a page at a time.
  Future<List<AppLogEntry>> _readAll() async {
    final all = <AppLogEntry>[];
    var offset = 0;
    while (true) {
      final page = await _repository.getLogs(limit: _pageSize, offset: offset);
      all.addAll(page);
      if (page.length < _pageSize) break;
      offset += _pageSize;
    }
    return all;
  }

  /// The JSON for all stored logs.
  Future<({String json, int count})> buildAll() async {
    final logs = await _readAll();
    return (
      json: LogExportDocument.build(logs, exportedAt: _now()),
      count: logs.length,
    );
  }

  /// Lets the user save the log file. Resolves to where it was saved, or
  /// `null` if they cancelled. Throws if the file could not be created/saved.
  Future<String?> exportForUser() async {
    AppLogger.info('Log export started', category: LogCategory.exportData);
    try {
      final built = await buildAll();
      final stamp = _now().millisecondsSinceEpoch;
      final savedUri = await FilePicker.saveFile(
        dialogTitle: 'Save MyKhata logs',
        fileName: 'MyKhata_Logs_$stamp.json',
        type: FileType.any,
        bytes: Uint8List.fromList(utf8.encode(built.json)),
      );
      if (savedUri == null) {
        AppLogger.info(
          'Log export cancelled by the user',
          category: LogCategory.exportData,
        );
        return null;
      }
      AppLogger.info(
        'Log export completed',
        category: LogCategory.exportData,
        details: '${built.count} entries',
      );
      return savedUri.isScheme('file')
          ? savedUri.toFilePath()
          : savedUri.toString();
    } catch (e, st) {
      AppLogger.error(
        'Log export failed',
        category: LogCategory.exportData,
        error: e,
        stackTrace: st,
      );
      rethrow;
    }
  }
}
