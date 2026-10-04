import 'dart:io';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import '../../core/logging/app_logger.dart';
import '../../data/models/receipt_model.dart';

class ReceiptStorageService {
  final ImagePicker _picker = ImagePicker();
  final Uuid _uuid = const Uuid();

  Future<ReceiptModel?> captureAndSaveReceipt(ImageSource source, String transactionId) async {
    try {
      final XFile? file = await _picker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (file == null) return null;

      final docsDir = await getApplicationDocumentsDirectory();
      final receiptsDir = Directory(p.join(docsDir.path, 'receipts'));
      final thumbsDir = Directory(p.join(docsDir.path, 'receipts', 'thumbnails'));

      if (!await receiptsDir.exists()) await receiptsDir.create(recursive: true);
      if (!await thumbsDir.exists()) await thumbsDir.create(recursive: true);

      final receiptId = _uuid.v4();
      final ext = p.extension(file.path).isNotEmpty ? p.extension(file.path) : '.jpg';

      final targetPath = p.join(receiptsDir.path, '$receiptId$ext');
      final thumbPath = p.join(thumbsDir.path, 'thumb_$receiptId$ext');

      // Save main image
      await File(file.path).copy(targetPath);

      // Generate thumbnail asynchronously
      final bytes = await File(targetPath).readAsBytes();
      final original = img.decodeImage(bytes);
      if (original != null) {
        final thumbnail = img.copyResize(original, width: 250);
        final thumbBytes = img.encodeJpg(thumbnail, quality: 75);
        await File(thumbPath).writeAsBytes(thumbBytes);
      } else {
        await File(targetPath).copy(thumbPath);
      }

      final receipt = ReceiptModel(
        id: receiptId,
        transactionId: transactionId,
        filePath: targetPath,
        thumbnailPath: thumbPath,
        createdAt: DateTime.now(),
      );

      await AppLogger.i('Saved receipt image to $targetPath');
      return receipt;
    } catch (e, stack) {
      await AppLogger.e('Failed to capture receipt', error: e, stackTrace: stack);
      return null;
    }
  }
}
