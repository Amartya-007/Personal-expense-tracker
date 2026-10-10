import 'package:flutter/material.dart';

import '../constants/app_colors.dart';

/// Resolved, theme-aware colours for the current brightness.
///
/// Replaces the `isDark ? AppColors.xDark : AppColors.xLight` ternaries that
/// were repeated across every screen. Use `context.palette` in any build
/// method.
@immutable
class AppPalette {
  final bool isDark;
  final Color background;
  final Color surface;
  final Color surface2;
  final Color border;
  final Color ink;
  final Color muted;
  final Color primary;
  final Color onPrimary;
  final Color secondary;
  final Color income;
  final Color expense;
  final LinearGradient heroGradient;
  final BoxShadow cardShadow;

  const AppPalette._({
    required this.isDark,
    required this.background,
    required this.surface,
    required this.surface2,
    required this.border,
    required this.ink,
    required this.muted,
    required this.primary,
    required this.onPrimary,
    required this.secondary,
    required this.income,
    required this.expense,
    required this.heroGradient,
    required this.cardShadow,
  });

  static const AppPalette light = AppPalette._(
    isDark: false,
    background: AppColors.backgroundLight,
    surface: AppColors.surfaceLight,
    surface2: AppColors.surface2Light,
    border: AppColors.borderLight,
    ink: AppColors.textPrimaryLight,
    muted: AppColors.textSecondaryLight,
    primary: AppColors.primary,
    onPrimary: Colors.white,
    secondary: AppColors.secondary,
    income: AppColors.income,
    expense: AppColors.expense,
    heroGradient: AppColors.heroGradientLight,
    cardShadow: AppColors.cardShadowLight,
  );

  static const AppPalette dark = AppPalette._(
    isDark: true,
    background: AppColors.backgroundDark,
    surface: AppColors.surfaceDark,
    surface2: AppColors.surface2Dark,
    border: AppColors.borderDark,
    ink: AppColors.textPrimaryDark,
    muted: AppColors.textSecondaryDark,
    primary: AppColors.primaryDark,
    onPrimary: Color(0xFF12102E),
    secondary: AppColors.secondaryDark,
    income: AppColors.incomeDark,
    expense: AppColors.expenseDark,
    heroGradient: AppColors.heroGradientDark,
    cardShadow: AppColors.cardShadowDark,
  );

  // ---- Depth tokens -------------------------------------------------------
  // Layers, from the page up: background -> surface -> surfaceRaised ->
  // glass (floating chrome such as the nav bar). Shadows come in three
  // elevations, each a soft ambient layer plus a tighter key layer, which
  // reads far more natural than one blurred shadow.

  /// Brand colour at low opacity: selected backgrounds, soft badges.
  Color get primarySoft => primary.withValues(alpha: isDark ? 0.18 : 0.10);

  /// A surface one step closer to the viewer than [surface].
  Color get surfaceRaised => isDark ? const Color(0xFF132428) : Colors.white;

  /// Translucent fill for floating chrome (use with a backdrop blur).
  Color get glass => isDark
      ? const Color(0xFF0E1D20).withValues(alpha: 0.72)
      : Colors.white.withValues(alpha: 0.78);

  /// Hairline highlight on glass edges.
  Color get glassBorder => isDark
      ? Colors.white.withValues(alpha: 0.08)
      : Colors.white.withValues(alpha: 0.9);

  /// Coloured glow under primary actions.
  BoxShadow get primaryGlow => BoxShadow(
        color: primary.withValues(alpha: isDark ? 0.40 : 0.32),
        blurRadius: 20,
        offset: const Offset(0, 8),
      );

  List<BoxShadow> get shadowSm => isDark
      ? const [
          BoxShadow(color: Color(0x40000000), blurRadius: 6, offset: Offset(0, 2)),
          BoxShadow(color: Color(0x26000000), blurRadius: 2, offset: Offset(0, 1)),
        ]
      : const [
          BoxShadow(color: Color(0x0F0B3B3F), blurRadius: 6, offset: Offset(0, 2)),
          BoxShadow(color: Color(0x0A0B3B3F), blurRadius: 2, offset: Offset(0, 1)),
        ];

  List<BoxShadow> get shadowMd => isDark
      ? const [
          BoxShadow(color: Color(0x59000000), blurRadius: 18, offset: Offset(0, 6)),
          BoxShadow(color: Color(0x33000000), blurRadius: 4, offset: Offset(0, 1)),
        ]
      : const [
          BoxShadow(color: Color(0x140B3B3F), blurRadius: 18, offset: Offset(0, 6)),
          BoxShadow(color: Color(0x0A0B3B3F), blurRadius: 4, offset: Offset(0, 1)),
        ];

  List<BoxShadow> get shadowLg => isDark
      ? const [
          BoxShadow(color: Color(0x73000000), blurRadius: 34, offset: Offset(0, 14)),
          BoxShadow(color: Color(0x40000000), blurRadius: 8, offset: Offset(0, 2)),
        ]
      : const [
          BoxShadow(color: Color(0x1F0B3B3F), blurRadius: 34, offset: Offset(0, 14)),
          BoxShadow(color: Color(0x0F0B3B3F), blurRadius: 8, offset: Offset(0, 2)),
        ];

  static AppPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  /// Colour for a signed amount: income green, expense red, otherwise ink.
  Color amount({required bool isIncome, required bool isExpense}) {
    if (isIncome) return income;
    if (isExpense) return expense;
    return ink;
  }
}

extension AppThemeContext on BuildContext {
  AppPalette get palette => AppPalette.of(this);
}
