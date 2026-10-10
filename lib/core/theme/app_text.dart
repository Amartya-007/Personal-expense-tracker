import 'dart:ui' show FontFeature;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shared text styles (Sora). Pass the colour so styles stay theme-aware:
/// `AppText.title(context.palette.ink)`.
class AppText {
  AppText._();

  static TextStyle _s(
    double size,
    FontWeight weight,
    Color? color, {
    double? letterSpacing,
    double? height,
  }) =>
      GoogleFonts.sora(
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
        height: height,
      );

  static TextStyle display(Color? c) =>
      _s(26, FontWeight.w800, c, letterSpacing: -0.5).copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// Money figures: tabular (equal-width) digits so amounts line up in lists
  /// and don't jitter while a total counts up.
  static TextStyle amount(Color? c, {double size = 15}) =>
      _s(size, FontWeight.w800, c, letterSpacing: -0.2).copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
      );

  /// Small all-caps label above a block of content.
  static TextStyle overline(Color? c) =>
      _s(11, FontWeight.w700, c, letterSpacing: 1.0);
  static TextStyle title(Color? c) =>
      _s(18, FontWeight.w800, c, letterSpacing: -0.2);
  static TextStyle section(Color? c) =>
      _s(12, FontWeight.w700, c, letterSpacing: 0.4);
  static TextStyle body(Color? c) => _s(14, FontWeight.w600, c);
  static TextStyle bodyStrong(Color? c) => _s(14, FontWeight.w700, c);
  static TextStyle caption(Color? c) => _s(12, FontWeight.w500, c, height: 1.4);
  static TextStyle button(Color? c) => _s(15, FontWeight.w800, c);
}
