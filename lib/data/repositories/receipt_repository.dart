import 'dart:io';
import '../../core/database/database_helper.dart';
import '../../core/logging/app_logger.dart';
import '../models/receipt_model.dart';

class ReceiptRepository {
  final DatabaseHelper _dbHelper = DatabaseHelper.instance;

  Future<List<ReceiptModel>> getAllReceipts() async {
    final db = await _dbHelper.database;
    final maps = await db.query('receipts', orderBy: 'created_at DESC');
    return maps.map((m) => ReceiptModel.fromMap(m)).toList();
  }

  Future<void> addReceipt(ReceiptModel receipt) async {
    final db = await _dbHelper.database;
    await db.insert('receipts', receipt.toMap());
    await AppLogger.i('Added receipt ${receipt.id}');
  }

  Future<void> deleteReceipt(ReceiptModel receipt) async {
    final db = await _dbHelper.database;
    await db.delete('receipts', where: 'id = ?', whereArgs: [receipt.id]);

    // Delete image files from disk
    try {
      final imgFile = File(receipt.filePath);
      if (await imgFile.exists()) await imgFile.delete();

      final thumbFile = File(receipt.thumbnailPath);
      if (await thumbFile.exists()) await thumbFile.delete();
    } catch (e) {
      await AppLogger.w('Failed to delete receipt files from disk: $e');
    }

    await AppLogger.i('Deleted receipt ${receipt.id}');
  }
}
