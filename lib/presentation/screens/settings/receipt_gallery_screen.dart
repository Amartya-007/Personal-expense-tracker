import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_palette.dart';
import '../../../data/models/receipt_model.dart';
import '../../providers/receipt_providers.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/fade_slide_in.dart';
import '../../widgets/receipt_viewer.dart';

class ReceiptGalleryScreen extends ConsumerWidget {
  const ReceiptGalleryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final receiptsAsync = ref.watch(receiptGalleryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Receipts')),
      body: receiptsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => EmptyState(
          emoji: '⚠️',
          title: 'Could not load receipts',
          message: '$err',
        ),
        data: (receipts) {
          if (receipts.isEmpty) {
            return const EmptyState(
              emoji: '🧾',
              title: 'No receipts yet',
              message:
                  'Attach a photo to an expense and it will show up here.',
            );
          }
          return GridView.builder(
            padding: EdgeInsets.fromLTRB(
              18,
              8,
              18,
              MediaQuery.of(context).padding.bottom + 24,
            ),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: receipts.length,
            itemBuilder: (context, index) {
              final r = receipts[index];
              return FadeSlideIn(
                index: index,
                offsetY: 12,
                child: GestureDetector(
                  onTap: () => AppRoutes.push(context, ReceiptViewer(receipt: r)),
                  child: Hero(
                    tag: 'receipt-${r.id}',
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        color: p.surface2,
                        child: Image.file(
                          File(r.thumbnailPath),
                          fit: BoxFit.cover,
                          // A missing/corrupt thumbnail used to throw.
                          errorBuilder: (_, __, ___) => Icon(
                            Icons.broken_image_outlined,
                            color: p.muted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
