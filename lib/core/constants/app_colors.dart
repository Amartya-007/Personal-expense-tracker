import 'package:flutter/material.dart';

class AppColors {
  // Brand accents: deep teal, with a warm gold used sparingly for the one
  // primary action (the add button) so it always stands out.
  static const Color primary = Color(0xFF0F766E); // teal-700
  static const Color primaryDark = Color(0xFF2DD4BF); // teal-400
  static const Color secondary = Color(0xFFFFB627); // warm gold
  static const Color secondaryDark = Color(0xFFFFC247);
  static const Color darkFabText = Color(0xFF2A1D00); // icon / text on gold

  // Light theme: cool slate neutrals with a faint teal cast.
  static const Color backgroundLight = Color(0xFFF2F6F6);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color surface2Light = Color(0xFFE6EEEE);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color textPrimaryLight = Color(0xFF0B1F24);
  static const Color textSecondaryLight = Color(0xFF52696E);
  static const Color borderLight = Color(0xFFD9E4E4);

  // Shorthand light aliases
  static const Color bg = backgroundLight;
  static const Color surface = surfaceLight;
  static const Color surface2 = surface2Light;
  static const Color ink = textPrimaryLight;
  static const Color muted = textSecondaryLight;
  static const Color lines = borderLight;

  // Dark theme: deep slate-teal layers; each step up is lighter, which is
  // what makes raised surfaces read as closer to the user.
  static const Color backgroundDark = Color(0xFF071214);
  static const Color surfaceDark = Color(0xFF0E1D20);
  static const Color surface2Dark = Color(0xFF16292D);
  static const Color cardDark = Color(0xFF0E1D20);
  static const Color textPrimaryDark = Color(0xFFE8F3F2);
  static const Color textSecondaryDark = Color(0xFF8FA9AC);
  static const Color borderDark = Color(0xFF21383C);

  // Shorthand dark aliases
  static const Color darkBg = backgroundDark;
  static const Color darkSurface = surfaceDark;
  static const Color darkSurface2 = surface2Dark;
  static const Color darkInk = textPrimaryDark;
  static const Color darkMuted = textSecondaryDark;
  static const Color darkLines = borderDark;

  // Status colours. Income is a true green (not teal) so it is never
  // confused with the brand colour.
  static const Color expense = Color(0xFFD92D3A);
  static const Color expenseDark = Color(0xFFFF7A82);
  static const Color income = Color(0xFF15803D);
  static const Color incomeDark = Color(0xFF5BE29A);
  static const Color transfer = Color(0xFF0F766E);
  static const Color pending = Color(0xFFFFB627);
  static const Color overlay = Color(0x800A1A1E);

  // Category palette (charts): distinct hues that sit well beside teal.
  static const List<Color> categoryPalette = [
    Color(0xFFFF8A5B), // coral
    Color(0xFF4F9DFF), // blue
    Color(0xFF46D6A4), // mint
    Color(0xFFFFB627), // gold
    Color(0xFFC77DFF), // purple
    Color(0xFF38BDF8), // sky
    Color(0xFFF472B6), // pink
  ];

  // Hero card gradients: deep teal falling into near-black teal.
  static const LinearGradient heroGradientLight = LinearGradient(
    colors: [Color(0xFF0D756B), Color(0xFF0A4A52)],
    begin: Alignment(-0.8, -0.8),
    end: Alignment(0.8, 0.9),
  );

  static const LinearGradient heroGradientDark = LinearGradient(
    colors: [Color(0xFF0D6B65), Color(0xFF082F36)],
    begin: Alignment(-0.8, -0.8),
    end: Alignment(0.8, 0.9),
  );

  // Soft shadows, tinted with the slate instead of neutral grey.
  static const BoxShadow cardShadowLight = BoxShadow(
    color: Color(0x1A0B3B3F),
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
