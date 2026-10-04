import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/constants/app_colors.dart';
import '../../../services/backup/backup_service.dart';

class BackupRestoreScreen extends StatefulWidget {
  const BackupRestoreScreen({super.key});

  @override
  State<BackupRestoreScreen> createState() => _BackupRestoreScreenState();
}

class _BackupRestoreScreenState extends State<BackupRestoreScreen> {
  bool _isProcessing = false;
  final BackupService _backupService = BackupService();

  // BUG FIX: try/catch/finally ensures _isProcessing never sticks on error.
  Future<void> _createBackup() async {
    setState(() => _isProcessing = true);
    try {
      final file = await _backupService.createFullBackupPackage();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Backup created at ${file.path}')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Backup failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _restoreBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );

    if (result == null || result.files.single.path == null) return;

    setState(() => _isProcessing = true);
    try {
      final success = await _backupService.restoreFullBackupPackage(
        File(result.files.single.path!),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success
                  ? 'Backup restored successfully! Please restart the app.'
                  : 'Backup restore failed. The file may be corrupt.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Restore failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Backup & Restore')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.backup, color: AppColors.primary),
                title: const Text('Create Full Backup'),
                subtitle: const Text(
                  'Generates a complete ZIP archive with database and receipt photos.',
                ),
                trailing: ElevatedButton(
                  onPressed: _isProcessing ? null : _createBackup,
                  child: const Text('Backup'),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Card(
              child: ListTile(
                leading: const Icon(
                  Icons.restore_page,
                  color: AppColors.secondary,
                ),
                title: const Text('Restore Backup'),
                subtitle: const Text(
                  'Restore application data from a previously created ZIP file.',
                ),
                trailing: ElevatedButton(
                  onPressed: _isProcessing ? null : _restoreBackup,
                  child: const Text('Restore'),
                ),
              ),
            ),
            if (_isProcessing) ...[
              const SizedBox(height: 32),
              const CircularProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }
}
