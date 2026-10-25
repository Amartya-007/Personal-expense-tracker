import 'dart:convert';
import 'dart:io';

import 'package:csv/csv.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/constants/app_constants.dart';
import '../../core/database/database_helper.dart';
import '../../core/logging/app_logger.dart';
import '../../core/logging/log_category.dart';

class ExportService {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<Directory> _getDocsDirectory() async {
    try {
      return await getApplicationDocumentsDirectory();
    } catch (_) {
      return Directory.systemTemp;
    }
  }

  /// Exports all transactions to CSV and lets the user choose where to save it
  /// (Android's system save dialog; no storage permission needed). Resolves to
  /// where it was saved, or `null` if the user cancelled.
  Future<String?> exportCsvForUser() async =>
      _saveForUser(await exportToCsv(), 'Save transactions CSV');

  /// Same as [exportCsvForUser], for the PDF report.
  Future<String?> exportPdfForUser() async =>
      _saveForUser(await generatePdfReport(), 'Save PDF report');

  /// Hands [staged] (created in private app storage, where the user cannot
  /// reach it) to the system save dialog, then removes the private copy.
  Future<String?> _saveForUser(File staged, String dialogTitle) async {
    try {
      final savedUri = await FilePicker.saveFile(
        dialogTitle: dialogTitle,
        fileName: p.basename(staged.path),
        type: FileType.any,
        bytes: await staged.readAsBytes(),
      );
      if (savedUri == null) return null;
      // file_picker 13 returns a Uri; keep a file-system path when the scheme
      // is `file`, otherwise hand back the Uri string (e.g. Android SAF
      // `content://` targets) for display.
      return savedUri.isScheme('file')
          ? savedUri.toFilePath()
          : savedUri.toString();
    } catch (e, st) {
      await AppLogger.error(
        'Saving export for the user failed',
        error: e,
        stackTrace: st,
        category: LogCategory.exportData,
      );
      rethrow;
    } finally {
      try {
        if (await staged.exists()) await staged.delete();
      } catch (_) {}
    }
  }

  /// Exports all transactions to a CSV file.
  Future<File> exportToCsv({DateTime? startDate, DateTime? endDate}) async {
    AppLogger.info('CSV export started', category: LogCategory.exportData);
    try {
      final db = await _dbHelper.database;
      final startMs = startDate?.millisecondsSinceEpoch ?? 0;
      final endMs = endDate?.millisecondsSinceEpoch ?? 9999999999999;

      final rows = await db.rawQuery(
        '''
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
      ''',
        [startMs, endMs],
      );

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
        final dateStr = DateTime.fromMillisecondsSinceEpoch(dateMs)
            .toIso8601String();
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

      await AppLogger.info(
        'Transactions exported to CSV',
        category: LogCategory.exportData,
        details: '${rows.length} rows',
      );
      return file;
    } catch (e, st) {
      await AppLogger.error(
        'exportToCsv failed',
        error: e,
        stackTrace: st,
        category: LogCategory.exportData,
      );
      rethrow;
    }
  }

  /// Exports full structured JSON application data covering all database entities.
  Future<File> exportToJson() async {
    AppLogger.info('JSON export started', category: LogCategory.exportData);
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
      await AppLogger.info(
        'Full data exported to JSON',
        category: LogCategory.exportData,
        details: '${transactions.length} transactions',
      );
      return file;
    } catch (e, st) {
      await AppLogger.error(
        'exportToJson failed',
        error: e,
        stackTrace: st,
        category: LogCategory.exportData,
      );
      rethrow;
    }
  }

  /// Generates a clean, paginated PDF financial report.
  ///
  /// Uses flexible column widths and explicit cell widgets instead of
  /// TableHelper.fromTextArray, so long values can wrap within their cells.
  Future<File> generatePdfReport({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    AppLogger.info(
      'PDF report generation started',
      category: LogCategory.exportData,
    );

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

      final generatedAt = DateTime.now();
      String dateLabel(DateTime d) =>
          '${d.day.toString().padLeft(2, '0')}/'
              '${d.month.toString().padLeft(2, '0')}/${d.year}';

      // The built-in Helvetica font does not cover all Unicode characters.
      // Normalize currency symbols and replace unsupported characters without
      // relying on complex Unicode regular-expression ranges.
      String pdfSafeText(Object? value, {String fallback = '-'}) {
        var input = (value?.toString() ?? '').trim();
        if (input.isEmpty) return fallback;

        input = input
            .replaceAll('₹', 'INR ')
            .replaceAll('€', 'EUR ')
            .replaceAll('£', 'GBP ')
            .replaceAll('¥', 'JPY ');

        final normalized = StringBuffer();
        for (final rune in input.runes) {
          // Skip control characters except tab/newline, which are normalized
          // to spaces below. Replace unsupported non-Latin glyphs with '?'.
          if (rune < 0x20 || (rune >= 0x7F && rune <= 0x9F)) {
            normalized.write(' ');
          } else if (rune <= 0xFF) {
            normalized.writeCharCode(rune);
          } else {
            // This also safely removes emoji and avoids missing-glyph errors.
            normalized.write('?');
          }
        }

        var result = normalized
            .toString()
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();

        // Add safe break opportunities to long unbroken tokens. Spaces are
        // used instead of zero-width characters for predictable PDF wrapping.
        result = result.replaceAllMapped(
          RegExp(r'\S{25,}'),
              (match) {
            final token = match.group(0)!;
            final parts = <String>[];
            for (var i = 0; i < token.length; i += 18) {
              parts.add(token.substring(
                i,
                i + 18 > token.length ? token.length : i + 18,
              ));
            }
            return parts.join(' ');
          },
        );

        return result.isEmpty ? fallback : result;
      }

      final pageTheme = pw.PageTheme(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(28, 30, 28, 34),
        theme: pw.ThemeData.withFont(
          base: pw.Font.helvetica(),
          bold: pw.Font.helveticaBold(),
          italic: pw.Font.helveticaOblique(),
          boldItalic: pw.Font.helveticaBoldOblique(),
        ),
      );

      final headerStyle = pw.TextStyle(
        fontSize: 8,
        color: PdfColors.blueGrey700,
        fontWeight: pw.FontWeight.bold,
      );
      final cellStyle = pw.TextStyle(
        fontSize: 7.5,
        color: PdfColors.blueGrey900,
        lineSpacing: 1.5,
      );

      pw.Widget cell(
          String value, {
            pw.Alignment alignment = pw.Alignment.centerLeft,
            pw.TextStyle? style,
          }) {
        return pw.Container(
          alignment: alignment,
          padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 7),
          child: pw.Text(
            pdfSafeText(value),
            style: style ?? cellStyle,
            softWrap: true,
            textAlign: alignment == pw.Alignment.centerRight
                ? pw.TextAlign.right
                : pw.TextAlign.left,
          ),
        );
      }

      final rows = txs.map((r) {
        final date = DateTime.fromMillisecondsSinceEpoch(
          (r['date'] as num?)?.toInt() ?? 0,
        );
        final amount = (r['amount'] as num?)?.toDouble() ?? 0.0;
        final type = pdfSafeText(r['type'], fallback: 'UNKNOWN').toUpperCase();

        return <pw.Widget>[
          cell(dateLabel(date)),
          cell(type),
          cell(pdfSafeText(r['description'], fallback: 'No description')),
          cell(pdfSafeText(r['category'])),
          cell(pdfSafeText(r['account'])),
          cell(
            'INR ${amount.toStringAsFixed(2)}',
            alignment: pw.Alignment.centerRight,
            style: pw.TextStyle(
              fontSize: 7.5,
              color: PdfColors.blueGrey900,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
        ];
      }).toList();

      final income = txs.fold<double>(0, (sum, r) {
        final amount = (r['amount'] as num?)?.toDouble() ?? 0;
        final type = (r['type'] as String? ?? '').toLowerCase();
        return sum + (type == 'income' ? amount.abs() : 0);
      });
      final expenses = txs.fold<double>(0, (sum, r) {
        final amount = (r['amount'] as num?)?.toDouble() ?? 0;
        final type = (r['type'] as String? ?? '').toLowerCase();
        return sum + (type == 'expense' ? amount.abs() : 0);
      });

      final periodLabel = startDate == null && endDate == null
          ? 'All available dates'
          : '${startDate == null ? 'Beginning' : dateLabel(startDate)}'
          '  -  ${endDate == null ? 'Present' : dateLabel(endDate)}';

      pdf.addPage(
        pw.MultiPage(
          pageTheme: pageTheme,
          maxPages: 100,
          header: (context) => pw.Container(
            padding: const pw.EdgeInsets.only(bottom: 10),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                bottom: pw.BorderSide(
                  color: PdfColors.blueGrey200,
                  width: 0.8,
                ),
              ),
            ),
            child: pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.center,
              children: [
                pw.Container(
                  width: 5,
                  height: 28,
                  decoration: const pw.BoxDecoration(
                    color: PdfColors.indigo700,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(2)),
                  ),
                ),
                pw.SizedBox(width: 9),
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'MyKhata',
                        style: pw.TextStyle(
                          fontSize: 17,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blueGrey900,
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'FINANCIAL TRANSACTION REPORT',
                        style: pw.TextStyle(
                          fontSize: 7,
                          letterSpacing: 1.1,
                          color: PdfColors.blueGrey600,
                        ),
                      ),
                    ],
                  ),
                ),
                pw.Text(
                  dateLabel(generatedAt),
                  style: pw.TextStyle(
                    fontSize: 8,
                    color: PdfColors.blueGrey600,
                  ),
                ),
              ],
            ),
          ),
          footer: (context) => pw.Container(
            alignment: pw.Alignment.centerRight,
            padding: const pw.EdgeInsets.only(top: 8),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                top: pw.BorderSide(color: PdfColors.blueGrey200, width: 0.6),
              ),
            ),
            child: pw.Text(
              'MyKhata  |  Page ${context.pageNumber} of ${context.pagesCount}',
              style: pw.TextStyle(
                fontSize: 7,
                color: PdfColors.blueGrey500,
              ),
            ),
          ),
          build: (context) => [
            pw.SizedBox(height: 16),
            pw.Text(
              'Financial overview',
              style: pw.TextStyle(
                fontSize: 20,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.blueGrey900,
              ),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              'Period: $periodLabel',
              style: pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey600),
            ),
            pw.SizedBox(height: 14),
            pw.Row(
              children: [
                _summaryCard('TRANSACTIONS', '${txs.length}', PdfColors.indigo700),
                pw.SizedBox(width: 8),
                _summaryCard('INCOME', 'INR ${income.toStringAsFixed(2)}', PdfColors.green700),
                pw.SizedBox(width: 8),
                _summaryCard('EXPENSES', 'INR ${expenses.toStringAsFixed(2)}', PdfColors.red700),
              ],
            ),
            pw.SizedBox(height: 20),
            if (txs.isEmpty)
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(22),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blueGrey50,
                  borderRadius: pw.BorderRadius.circular(8),
                  border: pw.Border.all(color: PdfColors.blueGrey100),
                ),
                child: pw.Column(
                  children: [
                    pw.Text(
                      'No transactions found',
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blueGrey800,
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      'Try selecting a different reporting period.',
                      style: pw.TextStyle(fontSize: 9, color: PdfColors.blueGrey600),
                    ),
                  ],
                ),
              )
            else
              pw.Table(
                border: pw.TableBorder(
                  horizontalInside: const pw.BorderSide(
                    color: PdfColors.blueGrey100,
                    width: 0.5,
                  ),
                  bottom: const pw.BorderSide(
                    color: PdfColors.blueGrey200,
                    width: 0.7,
                  ),
                ),
                columnWidths: const {
                  0: pw.FlexColumnWidth(1.05),
                  1: pw.FlexColumnWidth(0.85),
                  2: pw.FlexColumnWidth(2.35),
                  3: pw.FlexColumnWidth(1.35),
                  4: pw.FlexColumnWidth(1.35),
                  5: pw.FlexColumnWidth(1.25),
                },
                children: [
                  pw.TableRow(
                    repeat: true,
                    decoration: const pw.BoxDecoration(color: PdfColors.blueGrey50),
                    children: [
                      cell('DATE', style: headerStyle),
                      cell('TYPE', style: headerStyle),
                      cell('DESCRIPTION', style: headerStyle),
                      cell('CATEGORY', style: headerStyle),
                      cell('ACCOUNT', style: headerStyle),
                      cell(
                        'AMOUNT (INR)',
                        alignment: pw.Alignment.centerRight,
                        style: headerStyle,
                      ),
                    ],
                  ),
                  for (var i = 0; i < rows.length; i++)
                    pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: i.isEven ? PdfColors.white : PdfColors.grey50,
                      ),
                      children: rows[i],
                    ),
                ],
              ),
            pw.SizedBox(height: 10),
            pw.Text(
              'Showing up to 500 most recent transactions. '
                  'Amounts are displayed in INR.',
              style: pw.TextStyle(fontSize: 7, color: PdfColors.blueGrey500),
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

      await AppLogger.info(
        'PDF report generated',
        category: LogCategory.exportData,
        details: '${txs.length} transactions',
      );
      return file;
    } catch (e, st) {
      await AppLogger.error(
        'generatePdfReport failed',
        error: e,
        stackTrace: st,
        category: LogCategory.exportData,
      );
      rethrow;
    }
  }

  pw.Widget _summaryCard(String label, String value, PdfColor accent) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: PdfColors.blueGrey50,
          borderRadius: pw.BorderRadius.circular(7),
          border: pw.Border.all(color: PdfColors.blueGrey100, width: 0.7),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 6.5,
                letterSpacing: 0.6,
                color: PdfColors.blueGrey600,
                fontWeight: pw.FontWeight.bold,
              ),
            ),
            pw.SizedBox(height: 5),
            pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 10,
                color: accent,
                fontWeight: pw.FontWeight.bold,
              ),
              softWrap: true,
            ),
          ],
        ),
      ),
    );
  }
}
