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
