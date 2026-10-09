import 'dart:io';

import 'package:flutter/material.dart';

import '../../data/models/receipt_model.dart';

/// Full-screen, pinch-to-zoom receipt photo. Shared by the receipt gallery and
/// the transaction detail page (each used to need its own viewer).
class ReceiptViewer extends StatelessWidget {
  final ReceiptModel receipt;

  const ReceiptViewer({super.key, required this.receipt});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Hero(
          tag: 'receipt-${receipt.id}',
          child: InteractiveViewer(
            minScale: 1,
            maxScale: 5,
            child: Image.file(
              File(receipt.filePath),
              errorBuilder: (_, __, ___) => const Icon(
                Icons.broken_image_outlined,
                color: Colors.white54,
                size: 48,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
