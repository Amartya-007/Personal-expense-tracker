import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/receipt_providers.dart';

class ReceiptGalleryScreen extends ConsumerWidget {
  const ReceiptGalleryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final receiptsAsync = ref.watch(receiptGalleryProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Receipt Gallery'),
      ),
      body: receiptsAsync.when(
        data: (receipts) {
          if (receipts.isEmpty) {
            return const Center(child: Text('No receipt images captured yet.'));
          }
          return GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
            ),
            itemCount: receipts.length,
            itemBuilder: (context, index) {
              final r = receipts[index];
              return GestureDetector(
                onTap: () {
                  showDialog(
                    context: context,
                    builder: (_) => Dialog(
                      child: Image.file(File(r.filePath)),
                    ),
                  );
                },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.file(
                    File(r.thumbnailPath),
                    fit: BoxFit.cover,
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Error: $err')),
      ),
    );
  }
}
