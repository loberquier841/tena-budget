import 'package:flutter/material.dart';

/// Identité visuelle TENΛ Budget.
///
/// Les valeurs étaient jusqu'ici recopiées dans chaque page (et parfois dans
/// chaque composant), ce qui rendait l'harmonisation impossible : modifier un
/// arrondi ou une nuance obligait à tout relire. Ce fichier est la source
/// unique de vérité, les pages ne font plus que s'y référer.
class TenaColors {
  const TenaColors._();

  /// Or principal : couleur d'accent, réservée aux éléments qui méritent
  /// l'attention (sélection, action principale, solde positif).
  static const Color gold = Color(0xFFD4AF37);

  /// Or éclairci, utilisé sur fond sombre pour rester lisible.
  static const Color goldLight = Color(0xFFE8CC6A);

  /// Or discret, pour les fonds et bordures sans trop de poids visuel.
  static const Color goldMuted = Color(0xFF8A7434);

  /// Fond le plus profond (écrans, app bar).
  static const Color background = Color(0xFF09090B);

  /// Fond de carte.
  static const Color surface = Color(0xFF141416);

  /// Fond légèrement élevé (champs, tuiles).
  static const Color surfaceRaised = Color(0xFF1C1C20);

  /// Bordure standard.
  static const Color border = Color(0xFF2A2A30);

  /// Texte principal.
  static const Color textPrimary = Color(0xFFF5F5F7);

  /// Texte secondaire.
  static const Color textSecondary = Color(0xFFA0A0AB);

  /// Texte discret (légendes, axes).
  static const Color textTertiary = Color(0xFF6E6E7A);

  /// Revenus et validations.
  static const Color success = Color(0xFF4ADE80);

  /// Dépenses et points d'attention.
  static const Color danger = Color(0xFFF87171);

  /// Information neutre.
  static const Color info = Color(0xFF60A5FA);

  /// Or dégradé des cartes mises en avant (solde, bouton IA).
  static const List<Color> goldGradient = [Color(0xFF3A2F12), Color(0xFF241C08)];

  static const LinearGradient goldSheen = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0x33D4AF37), Color(0x0DD4AF37)],
  );
}

/// Échelle d'espacement unique.
///
/// Les pages mélangeaient 4, 6, 8, 10, 12, 14, 16, 18, 20 et 24 px sans
/// logique, ce qui produit des alignements imparfaits. Seules ces valeurs sont
/// désormais utilisées.
class TenaSpacing {
  const TenaSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 20;
  static const double xxl = 28;

  /// Marge latérale des écrans, réduite sur petit écran.
  static double gutter(double width) {
    if (width >= 1200) return 32;
    if (width >= 700) return 24;
    return 16;
  }
}

/// Arrondis cohérents : moins de valeurs distinctes, plus de régularité.
class TenaRadius {
  const TenaRadius._();

  static const BorderRadius sm = BorderRadius.all(Radius.circular(10));
  static const BorderRadius md = BorderRadius.all(Radius.circular(14));
  static const BorderRadius lg = BorderRadius.all(Radius.circular(18));
  static const BorderRadius xl = BorderRadius.all(Radius.circular(24));
}

/// Ombres douces, à utiliser avec parcimonie (Flutter interdit d'en mettre
/// plusieurs sur un même axe sans les cumuler).
class TenaShadows {
  const TenaShadows._();

  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x66000000),
      blurRadius: 24,
      offset: Offset(0, 8),
    ),
  ];

  static const List<BoxShadow> gold = [
    BoxShadow(
      color: Color(0x40D4AF37),
      blurRadius: 20,
      offset: Offset(0, 6),
    ),
  ];
}

/// Étiquettes en petites capitales, pour les titres de section.
class TenaLabels {
  const TenaLabels._();

  static const TextStyle overline = TextStyle(
    fontSize: 11,
    letterSpacing: 1.3,
    fontWeight: FontWeight.w700,
    color: TenaColors.textTertiary,
  );

  static const TextStyle title = TextStyle(
    fontSize: 19,
    fontWeight: FontWeight.w700,
    color: TenaColors.textPrimary,
    letterSpacing: -0.2,
  );

  static const TextStyle subtitle = TextStyle(
    fontSize: 13.5,
    color: TenaColors.textSecondary,
    height: 1.35,
  );
}

/// Formatage monétaire français, centralisé pour que toutes les pages
/// affichent exactement le même rendu.
String tenaMoney(double value, {bool showSign = false}) {
  final sign = value < 0 ? '-' : (showSign ? '+' : '');

  // `toStringAsFixed` utilise toujours le point comme séparateur : on le
  // remplace pour obtenir la virgule française.
  final fixed = value.abs().toStringAsFixed(2);
  final parts = fixed.split('.');
  final integer = parts.first;
  final decimals = parts.length > 1 ? parts.last : '00';

  /// Espace insécable devant le symbole pour éviter une coupure de ligne
  /// entre le montant et la devise.
  return '$sign$integer,$decimals €';
}

/// Formatage compact pour les grands nombres dans les graphiques.
String tenaMoneyCompact(double value) {
  final abs = value.abs();

  if (abs >= 1000000) {
    return '${(value / 1000000).toStringAsFixed(1)}M €';
  }

  if (abs >= 1000) {
    return '${(value / 1000).toStringAsFixed(abs >= 10000 ? 0 : 1)}k €';
  }

  return '${value.toStringAsFixed(0)} €';
}
