import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_palette.dart';
import '../../../core/theme/app_text.dart';
import '../../../services/backup/backup_service.dart';
import '../../../services/export/export_service.dart';
import '../../../services/import/import_service.dart';
import '../../providers/data_refresh.dart';
import '../../widgets/app_sheets.dart';
import '../../widgets/fade_slide_in.dart';
import '../../widgets/list_widgets.dart';
import '../../widgets/section_header.dart';

/// One place for everything that moves data in or out of the app: full
/// backup/restore, CSV/PDF export and CSV import. (These were split across a
/// "Backup & Restore" screen and an "Import / Export" sheet that only
/// exported, while `ImportService` had no UI at all.)
class BackupRestoreScreen extends ConsumerStatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  ConsumerState<BackupRestoreScreen> createState() =>
      _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends ConsumerState<BackupRestoreScreen> {
  final BackupService _backupService = BackupService();
  final ExportService _exportService = ExportService();
  final ImportService _importService = ImportService();

  bool _busy = false;

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(content: Text(message), duration: const Duration(seconds: 6)),
      );
  }

  /// Runs [task] with a progress bar, blocking other actions, and always
  /// clears the busy state (even when the task throws).
  Future<void> _run(Future<void> Function() task, String failurePrefix) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await task();
    } catch (e) {
      _toast('$failurePrefix: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Stays on screen until dismissed (a snackbar vanished before people could
  /// read where the file went) and says how to find the file whatever Android
  /// reports as its location.
  void _announceSaved(String what, String savedPath) {
    if (!mounted) return;
    final readable = BackupService.describeSavedLocation(savedPath);
    // Android often reports an internal document id (like "/document/msf:123")
    // that means nothing to a person: only show a path when it is a real one.
    final isRealPath = readable.startsWith('Internal storage/') ||
        readable.startsWith('/storage/') ||
        readable.startsWith('/sdcard');
    final where = isRealPath
        ? 'Saved to: $readable'
        : 'Saved in the folder you chose in the save dialog.';
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('$what saved'),
        content: Text(
          '$where\n\nCan\'t find it? Open your phone\'s Files app, tap search and type "MyKhata". Every export is named MyKhata_…',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _createBackup() => _run(() async {
        // Opens Android's "save file" dialog so the backup lands somewhere
        // the user can find it (e.g. Downloads), not in private app storage.
        final savedPath = await _backupService.exportBackupForUser();
        if (savedPath == null) {
          _toast('Backup cancelled. Nothing was saved.');
          return;
        }
        _announceSaved('Backup', savedPath);
      }, 'Backup failed');

  Future<void> _restoreBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );
    final path = result?.files.single.path;
    if (path == null || !mounted) return;

    // Restoring replaces everything, so never do it without asking.
    final ok = await confirmDestructive(
      context,
      title: 'Replace all data?',
      message:
          'Restoring this backup replaces the transactions, accounts and receipts currently in MyKhata. This cannot be undone.',
      confirmLabel: 'Restore',
    );
    if (!ok) return;

    await _run(() async {
      final success = await _backupService.restoreFullBackupPackage(File(path));
      if (success) {
        // The database file was replaced underneath the app: reload every
        // screen's data from it.
        await refreshAllAppData(ref);
        _toast('Backup restored successfully.');
      } else {
        _toast('Restore failed. The file may be damaged or not a MyKhata backup.');
      }
    }, 'Restore failed');
  }

  Future<void> _exportCsv() => _run(() async {
        final savedPath = await _exportService.exportCsvForUser();
        if (savedPath == null) {
          _toast('Export cancelled. Nothing was saved.');
          return;
        }
        _announceSaved('CSV', savedPath);
      }, 'Export failed');

  Future<void> _exportPdf() => _run(() async {
        final savedPath = await _exportService.exportPdfForUser();
        if (savedPath == null) {
          _toast('Export cancelled. Nothing was saved.');
          return;
        }
        _announceSaved('PDF report', savedPath);
      }, 'PDF export failed');

  Future<void> _importCsv() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
    );
    final path = result?.files.single.path;
    if (path == null || !mounted) return;

    setState(() => _busy = true);
    CsvPreviewResult preview;
    try {
      preview = await _importService.previewCsvImport(File(path));
    } catch (e) {
      _toast('Could not read that file: $e');
      if (mounted) setState(() => _busy = false);
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);

    final confirmed = await AppBottomSheet.show<bool>(
      context,
      title: 'Import preview',
      builder: (_) => _ImportPreview(preview: preview),
    );
    if (confirmed != true) return;

    await _run(() async {
      final ok = await _importService.executeCsvImport(
        preview.validTransactions,
      );
      if (ok) {
        await refreshAllAppData(ref);
        _toast('Imported ${preview.validTransactions.length} transactions.');
      } else {
        _toast('Import failed and nothing was changed.');
      }
    }, 'Import failed');
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Backup & data'),
        bottom: _busy
            ? PreferredSize(
                preferredSize: const Size.fromHeight(3),
                child: LinearProgressIndicator(
                  minHeight: 3,
                  color: p.primary,
                  backgroundColor: p.surface2,
                ),
              )
            : null,
      ),
      body: AbsorbPointer(
        absorbing: _busy,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            18,
            8,
            18,
            MediaQuery.of(context).padding.bottom + 24,
          ),
          children: [
            FadeSlideIn(
              child: Text(
                'Everything stays on this phone unless you move it yourself.',
                style: AppText.caption(p.muted),
              ),
            ),
            const SizedBox(height: 18),
            FadeSlideIn(
              index: 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(title: 'Backup'),
                  SettingsGroup(
                    children: [
                      ListRowTile(
                        emoji: '💾',
                        title: 'Create full backup',
                        subtitle: 'ZIP of your data and receipts. You choose where to save it (e.g. Downloads)',
                        onTap: _createBackup,
                      ),
                      ListRowTile(
                        emoji: '♻️',
                        title: 'Restore from backup',
                        subtitle: 'Replaces all current data',
                        onTap: _restoreBackup,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FadeSlideIn(
              index: 2,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(title: 'Export'),
                  SettingsGroup(
                    children: [
                      ListRowTile(
                        emoji: '📊',
                        title: 'Export CSV',
                        subtitle: 'All transactions as a spreadsheet',
                        onTap: _exportCsv,
                      ),
                      ListRowTile(
                        emoji: '📄',
                        title: 'Export PDF report',
                        subtitle: 'Totals and summaries',
                        onTap: _exportPdf,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FadeSlideIn(
              index: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SectionHeader(title: 'Import'),
                  SettingsGroup(
                    children: [
                      ListRowTile(
                        emoji: '📥',
                        title: 'Import transactions from CSV',
                        subtitle: 'You will see a preview before anything is added',
                        onTap: _importCsv,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImportPreview extends StatelessWidget {
  final CsvPreviewResult preview;

  const _ImportPreview({required this.preview});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final ready = preview.validTransactions.length;

    Widget stat(String label, int value, Color color) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            children: [
              Expanded(child: Text(label, style: AppText.body(p.ink))),
              Text('$value', style: AppText.bodyStrong(color)),
            ],
          ),
        );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        stat('Ready to import', ready, p.income),
        stat('Duplicates skipped', preview.duplicateCount, p.muted),
        stat('Rows rejected', preview.rejectedCount, p.expense),
        if (preview.errors.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('First problems', style: AppText.section(p.muted)),
          const SizedBox(height: 6),
          for (final e in preview.errors.take(3))
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                'Row ${e.rowIndex}: ${e.message}',
                style: AppText.caption(p.muted),
              ),
            ),
        ],
        const SizedBox(height: 18),
        ElevatedButton(
          onPressed: ready == 0 ? null : () => Navigator.pop(context, true),
          child: Text(ready == 0 ? 'Nothing to import' : 'Import $ready transactions'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}
