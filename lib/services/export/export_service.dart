import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/constants/app_constants.dart';
import '../../core/database/database_helper.dart';
import '../../core/logging/app_logger.dart';
import '../../core/utils/currency_formatter.dart';

class ExportService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<Directory> _getDocsDirectory() async {
    try {
      return await getApplicationDocumentsDirectory();
    } catch (_) {
      return Directory.systemTemp;
    }
  }

  /// Exports all transactions to a CSV file.
  Future<File> exportToCsv({DateTime? startDate, DateTime? endDate}) async {
    try {
      final db = await _dbHelper.database;
      final startMs = startDate?.millisecondsSinceEpoch ?? 0;
      final endMs = endDate?.millisecondsSinceEpoch ?? 9999999999999;

      final rows = await db.rawQuery('''
        SELECT 
          t.id, t.date, t.type, t.amount, t.description,
          c.name as category, t.payment_method, a.name as account,
          da.name as destination_account, t.note, t.location_name, t.source, t.external_reference
        FROM transactions t
        LEFT JOIN categories c ON t.category_id = c.id
        LEFT JOIN accounts a ON t.account_id = a.id
        LEFT JOIN accounts da ON t.destination_account_id = da.id
        WHERE t.deleted_at IS NULL AND t.date >= ? AND t.date <= ?
        ORDER BY t.date DESC
      ''', [startMs, endMs]);

      final csvData = <List<dynamic>>[
        [
          'ID',
          'Date',
          'Type',
          'Amount',
          'Description',
          'Category',
          'Payment Method',
          'Account',
          'Destination Account',
          'Note',
          'Location',
          'Source',
          'External Reference',
        ],
      ];

      for (final r in rows) {
        final dateMs = (r['date'] as num).toInt();
        final dateStr = DateTime.fromMillisecondsSinceEpoch(dateMs).toIso8601String();
        csvData.add([
          r['id'],
          dateStr,
          r['type'],
          r['amount'],
          r['description'],
          r['category'] ?? '',
          r['payment_method'],
          r['account'] ?? '',
          r['destination_account'] ?? '',
          r['note'] ?? '',
          r['location_name'] ?? '',
          r['source'] ?? 'manual',
          r['external_reference'] ?? '',
        ]);
      }

      final csvString = const ListToCsvConverter().convert(csvData);
      final docsDir = await _getDocsDirectory();
      final file = File(
        p.join(
          docsDir.path,
          'MyKhata_Export_${DateTime.now().millisecondsSinceEpoch}.csv',
        ),
      );
      await file.writeAsString(csvString);

      await AppLogger.i('Exported transactions to CSV: ${file.path}');
      return file;
    } catch (e, st) {
      await AppLogger.e('exportToCsv failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Exports full structured JSON application data covering all database entities.
  Future<File> exportToJson() async {
    try {
      final db = await _dbHelper.database;
      final docsDir = await _getDocsDirectory();

      final accounts = await db.query('accounts');
      final categories = await db.query('categories');
      final categoryRules = await db.query('category_rules');
      final tags = await db.query('tags');
      final transactions = await db.query('transactions');
      final transactionTags = await db.query('transaction_tags');
      final receipts = await db.query('receipts');
      final budgets = await db.query('budgets');
      final recurringPayments = await db.query('recurring_payments');
      final smsQueue = await db.query('sms_review_queue');
      final balanceAdjustments = await db.query('balance_adjustments');

      final exportData = {
        'version': AppConstants.backupVersion,
        'createdAt': DateTime.now().toIso8601String(),
        'appName': AppConstants.appName,
        'accounts': accounts,
        'categories': categories,
        'category_rules': categoryRules,
        'tags': tags,
        'transactions': transactions,
        'transaction_tags': transactionTags,
        'receipts': receipts,
        'budgets': budgets,
        'recurring_payments': recurringPayments,
        'sms_review_queue': smsQueue,
        'balance_adjustments': balanceAdjustments,
      };

      final file = File(
        p.join(
          docsDir.path,
          'MyKhata_Data_${DateTime.now().millisecondsSinceEpoch}.json',
        ),
      );

      await file.writeAsString(jsonEncode(exportData));
      await AppLogger.i('Exported complete JSON application data to ${file.path}');
      return file;
    } catch (e, st) {
      await AppLogger.e('exportToJson failed', error: e, stackTrace: st);
      rethrow;
    }
  }

  /// Generates a PDF financial summary report.
  Future<File> generatePdfReport({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final pdf = pw.Document();
      final db = await _dbHelper.database;

      final startMs = startDate?.millisecondsSinceEpoch ?? 0;
      final endMs = endDate?.millisecondsSinceEpoch ?? 9999999999999;

      final txs = await db.rawQuery(
        '''
        SELECT t.*, c.name as category, a.name as account
        FROM transactions t
        LEFT JOIN categories c ON t.category_id = c.id
        LEFT JOIN accounts a ON t.account_id = a.id
        WHERE t.deleted_at IS NULL AND t.date >= ? AND t.date <= ?
        ORDER BY t.date DESC
        LIMIT 500
      ''',
        [startMs, endMs],
      );

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          build: (context) => [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'MyKhata Financial Report',
                    style: pw.TextStyle(
                      fontSize: 24,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(DateTime.now().toString().split(' ')[0]),
                ],
              ),
            ),
            pw.SizedBox(height: 16),
            pw.TableHelper.fromTextArray(
              headers: [
                'Date',
                'Type',
                'Description',
                'Category',
                'Account',
                'Amount (INR)',
              ],
              data: txs.map((r) {
                final d = DateTime.fromMillisecondsSinceEpoch(
                  (r['date'] as num).toInt(),
                );
                return [
                  '${d.day}/${d.month}/${d.year}',
                  ((r['type'] as String?) ?? 'unknown').toUpperCase(),
                  (r['description'] as String?) ?? '',
                  (r['category'] as String?) ?? '-',
                  (r['account'] as String?) ?? '-',
                  CurrencyFormatter.format((r['amount'] as num).toDouble()),
                ];
              }).toList(),
            ),
          ],
        ),
      );

      final docsDir = await _getDocsDirectory();
      final file = File(
        p.join(
          docsDir.path,
          'MyKhata_Report_${DateTime.now().millisecondsSinceEpoch}.pdf',
        ),
      );
      await file.writeAsBytes(await pdf.save());

      await AppLogger.i('Generated PDF report at ${file.path}');
      return file;
    } catch (e, st) {
      await AppLogger.e('generatePdfReport failed', error: e, stackTrace: st);
      rethrow;
    }
  }
}
