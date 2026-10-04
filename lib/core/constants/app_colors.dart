import 'package:flutter/material.dart';

class AppColors {
  // Brand Accents
  static const Color primary = Color(0xFF5B3DF5); // --ac: #5b3df5
  static const Color primaryDark = Color(0xFF8D7BFF); // --ac: #8d7bff
  static const Color secondary = Color(0xFFFFB627); // --ac2: #ffb627 (Warm gold / amber)
  static const Color secondaryDark = Color(0xFFFFC247); // --ac2: #ffc247
  static const Color darkFabText = Color(0xFF2A1D00); // FAB icon / text on gold

  // Light Theme
  static const Color backgroundLight = Color(0xFFF4F3FB); // --bg: #f4f3fb
  static const Color surfaceLight = Color(0xFFFFFFFF); // --sf: #fff
  static const Color surface2Light = Color(0xFFEBEAF6); // --s2: #ebeaf6
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF17163A); // --ink: #17163a
  static const Color textSecondaryLight = Color(0xFF767493); // --mut: #767493
  static const Color borderLight = Color(0xFFE3E1F1); // --ln: #e3e1f1

  // Shorthand Light Aliases (matching CSS vars)
  static const Color bg = backgroundLight;
  static const Color surface = surfaceLight;
  static const Color surface2 = surface2Light;
  static const Color ink = textPrimaryLight;
  static const Color muted = textSecondaryLight;
  static const Color lines = borderLight;

  // Dark Theme
  static const Color backgroundDark = Color(0xFF0E0E1F); // --bg: #0e0e1f
  static const Color surfaceDark = Color(0xFF181833); // --sf: #181833
  static const Color surface2Dark = Color(0xFF222247); // --s2: #222247
  static const Color cardDark = Color(0xFF181833);
  static const Color textPrimaryDark = Color(0xFFF1F0FC); // --ink: #f1f0fc
  static const Color textSecondaryDark = Color(0xFF9391B8); // --mut: #9391b8
  static const Color borderDark = Color(0xFF2A2A52); // --ln: #2a2a52

  // Shorthand Dark Aliases (matching CSS vars)
  static const Color darkBg = backgroundDark;
  static const Color darkSurface = surfaceDark;
  static const Color darkSurface2 = surface2Dark;
  static const Color darkInk = textPrimaryDark;
  static const Color darkMuted = textSecondaryDark;
  static const Color darkLines = borderDark;

  // Status Colors
  static const Color expense = Color(0xFFE5484D); // --ex: #e5484d
  static const Color expenseDark = Color(0xFFFF7075);
  static const Color income = Color(0xFF12A574); // --in: #12a574
  static const Color incomeDark = Color(0xFF4FDCAB);
  static const Color transfer = Color(0xFF5B3DF5);
  static const Color pending = Color(0xFFFFB627);
  static const Color overlay = Color(0x800F0E28); // --ov: rgba(15,14,40,.5)

  // Category palette (for charts)
  static const List<Color> categoryPalette = [
    Color(0xFFFF8A5B), // Food (coral)
    Color(0xFF7C8CFF), // Shopping (indigo)
    Color(0xFF46D6A4), // Bills (mint)
    Color(0xFFFFB627), // Transport (gold)
    Color(0xFFC77DFF), // Other (purple)
    Color(0xFF38BDF8), // Blue
    Color(0xFFF472B6), // Pink
  ];

  // Hero Card Gradients
  static const LinearGradient heroGradientLight = LinearGradient(
    colors: [Color(0xFF5B3DF5), Color(0xFF2D1BB0)],
    begin: Alignment(-0.8, -0.6),
    end: Alignment(0.8, 0.6),
  );

  static const LinearGradient heroGradientDark = LinearGradient(
    colors: [Color(0xFF4A38C9), Color(0xFF241A78)],
    begin: Alignment(-0.8, -0.6),
    end: Alignment(0.8, 0.6),
  );

  // Soft Shadows
  static const BoxShadow cardShadowLight = BoxShadow(
    color: Color(0x1F281E78),
    blurRadius: 24,
    offset: Offset(0, 8),
  );

  static const BoxShadow cardShadowDark = BoxShadow(
    color: Color(0x66000000),
    blurRadius: 24,
    offset: Offset(0, 8),
  );

  // Category Emoji Map
  static String getCategoryEmoji(String? categoryName) {
    if (categoryName == null) return '📂';
    final lower = categoryName.toLowerCase();
    if (lower.contains('food') || lower.contains('dining') || lower.contains('restaurant') || lower.contains('snack')) return '🍜';
    if (lower.contains('grocer') || lower.contains('supermarket')) return '🛒';
    if (lower.contains('shop') || lower.contains('cloth') || lower.contains('mall')) return '🛍️';
    if (lower.contains('bill') || lower.contains('recharge') || lower.contains('utilit') || lower.contains('electricity')) return '🧾';
    if (lower.contains('transport') || lower.contains('travel') || lower.contains('cab') || lower.contains('auto') || lower.contains('fuel') || lower.contains('bus')) return '🚕';
    if (lower.contains('stationery') || lower.contains('office') || lower.contains('book')) return '✏️';
    if (lower.contains('electronic') || lower.contains('gadget') || lower.contains('phone')) return '🔌';
    if (lower.contains('education') || lower.contains('course') || lower.contains('school')) return '📚';
    if (lower.contains('health') || lower.contains('medic') || lower.contains('doctor') || lower.contains('hospital')) return '💊';
    if (lower.contains('salary') || lower.contains('pay')) return '💰';
    if (lower.contains('freelance') || lower.contains('business') || lower.contains('work')) return '💼';
    if (lower.contains('invest') || lower.contains('return') || lower.contains('cashback')) return '📈';
    if (lower.contains('transfer')) return '⇄';
    if (lower.contains('entertain') || lower.contains('movie') || lower.contains('netflix')) return '🎬';
    return '📂';
  }
}
