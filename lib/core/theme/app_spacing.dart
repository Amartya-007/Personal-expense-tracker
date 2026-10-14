/// Named spacing steps for padding and gaps between widgets.
///
/// Adopted in the high-traffic screens and shared widgets touched this phase;
/// a literal is only swapped for a token when the two are already equal, so
/// spacing never shifts visually.
class AppSpacing {
  const AppSpacing._();

  /// Tight gap between closely related elements.
  static const double xs = 4;

  /// Compact gap, e.g. between a row's adjacent controls.
  static const double sm = 8;

  /// Default gap between stacked elements inside a card.
  static const double md = 12;

  /// Standard gap between sections' inner content and screen padding.
  static const double lg = 16;

  /// Large gap between major sections.
  static const double xl = 24;

  /// Extra-large gap for generous separation.
  static const double xxl = 32;
}
