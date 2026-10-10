import 'package:flutter/material.dart';

import '../../core/theme/app_palette.dart';

/// The shared look for text fields and dropdowns: filled surface, rounded
/// border, primary-coloured focus ring.
InputDecoration appFieldDecoration(AppPalette p, {String? hint}) {
  OutlineInputBorder border(BorderSide side) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: side,
      );
  return InputDecoration(
    hintText: hint,
    hintStyle: TextStyle(color: p.muted.withValues(alpha: 0.7)),
    filled: true,
    fillColor: p.surface,
    border: border(BorderSide.none),
    enabledBorder: border(BorderSide(color: p.border)),
    focusedBorder: border(BorderSide(color: p.primary, width: 2)),
    contentPadding: const EdgeInsets.all(14),
  );
}
