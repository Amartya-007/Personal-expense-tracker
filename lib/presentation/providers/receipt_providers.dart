import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/models/receipt_model.dart';
import '../../data/repositories/receipt_repository.dart';

final receiptRepositoryProvider = Provider((ref) => ReceiptRepository());

final receiptGalleryProvider = FutureProvider<List<ReceiptModel>>((ref) async {
  final repo = ref.watch(receiptRepositoryProvider);
  return await repo.getAllReceipts();
});
