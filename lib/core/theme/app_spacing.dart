/// Échelle d'espacements (multiples de 4).
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;

  /// Marge latérale des pages.
  static const double page = lg;

  /// Largeur max du contenu : au-delà (tablette, paysage), on centre.
  static const double maxContentWidth = 600;
}

abstract final class AppRadius {
  static const double sm = 10;
  static const double md = 14;
  static const double lg = 20;
}
