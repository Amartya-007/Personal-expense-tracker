/// Named corner-radius steps, the single source of truth for rounding.
///
/// Values equal the radii already in use across the theme and shared widgets,
/// so routing components through [AppRadius] is a consistency change only and
/// never alters how anything looks.
class AppRadius {
  const AppRadius._();

  /// Small square controls, the summary banner, and small icon chips.
  static const double sm = 14;

  /// Inputs, the search field, hero account chips, and snackbars.
  static const double md = 16;

  /// Elevated buttons.
  static const double button = 18;

  /// Content cards and the card theme / chips.
  static const double card = 20;

  /// Dialogs and the About sheet logo tile.
  static const double dialog = 24;

  /// The Settings profile card.
  static const double profile = 26;

  /// Hero card, bottom-sheet top edge, and the nav pill.
  static const double lg = 28;
}
