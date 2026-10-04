import 'package:flutter/material.dart';

import 'tena_theme.dart';

/// Thème Material 3 de l'application.
///
/// Le `colorScheme` est construit explicitement plutôt qu'à partir d'une
/// graine : `fromSeed` produisait un doré ternedé et laissait les composants
/// natifs (champs, dialogues, menus) dans un gris par défaut, ce qui
/// contredisait les écrans dessinés à la main. Les couleurs proviennent
/// toutes de [TenaColors], ce qui garantit la cohérence sur tous les widgets
/// Material sans les redéfinir page par page.
ThemeData buildTenaTheme() {
  const scheme = ColorScheme.dark(
    primary: TenaColors.gold,
    onPrimary: Colors.black,
    primaryContainer: Color(0xFF3A2F12),
    onPrimaryContainer: TenaColors.goldLight,
    secondary: TenaColors.goldMuted,
    onSecondary: Colors.white,
    surface: TenaColors.surface,
    onSurface: TenaColors.textPrimary,
    surfaceContainerHighest: TenaColors.surfaceRaised,
    onSurfaceVariant: TenaColors.textSecondary,
    outline: TenaColors.textTertiary,
    outlineVariant: TenaColors.border,
    error: TenaColors.danger,
    onError: Colors.black,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: scheme,
    scaffoldBackgroundColor: TenaColors.background,
  );

  return base.copyWith(
    appBarTheme: const AppBarTheme(
      backgroundColor: TenaColors.background,
      surfaceTintColor: Colors.transparent,
      foregroundColor: TenaColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),

    cardTheme: CardThemeData(
      color: TenaColors.surface,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(borderRadius: TenaRadius.lg),
      margin: EdgeInsets.zero,
    ),

    dividerTheme: const DividerThemeData(
      color: TenaColors.border,
      thickness: 1,
      space: 1,
    ),

    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: TenaColors.gold,
        foregroundColor: Colors.black,
        // Material dessine par défaut une ombre qui assombrit le bouton sur
        // fond sombre.
        elevation: 0,
        padding: const EdgeInsets.symmetric(
          horizontal: TenaSpacing.xl,
          vertical: 14,
        ),
        shape: const RoundedRectangleBorder(borderRadius: TenaRadius.md),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
    ),

    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: TenaColors.gold,
        side: const BorderSide(color: TenaColors.goldMuted),
        padding: const EdgeInsets.symmetric(
          horizontal: TenaSpacing.xl,
          vertical: 14,
        ),
        shape: const RoundedRectangleBorder(borderRadius: TenaRadius.md),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),

    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: TenaColors.goldLight,
        textStyle: const TextStyle(fontWeight: FontWeight.w600),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: TenaColors.surfaceRaised,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: TenaSpacing.lg,
        vertical: TenaSpacing.lg,
      ),
      // Bordure discrète au repos, dorée au focus : c'est le principal
      // marqueur d'interactivité des formulaires.
      border: const OutlineInputBorder(
        borderRadius: TenaRadius.md,
        borderSide: BorderSide(color: TenaColors.border),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: TenaRadius.md,
        borderSide: BorderSide(color: TenaColors.border),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: TenaRadius.md,
        borderSide: BorderSide(color: TenaColors.gold, width: 1.5),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: TenaRadius.md,
        borderSide: BorderSide(color: TenaColors.danger),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: TenaRadius.md,
        borderSide: BorderSide(color: TenaColors.danger, width: 1.5),
      ),
      labelStyle: const TextStyle(color: TenaColors.textSecondary),
      floatingLabelStyle: const TextStyle(color: TenaColors.gold),
      hintStyle: const TextStyle(color: TenaColors.textTertiary),
      prefixIconColor: TenaColors.textSecondary,
      suffixIconColor: TenaColors.textSecondary,
    ),

    dialogTheme: DialogThemeData(
      backgroundColor: TenaColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: const BorderSide(color: TenaColors.border),
      ),
      titleTextStyle: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: TenaColors.textPrimary,
      ),
      contentTextStyle: const TextStyle(
        fontSize: 14,
        color: TenaColors.textSecondary,
        height: 1.4,
      ),
    ),

    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: TenaColors.surface,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: TenaColors.surfaceRaised,
      contentTextStyle: const TextStyle(
        color: TenaColors.textPrimary,
        fontSize: 14,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),

    listTileTheme: const ListTileThemeData(
      iconColor: TenaColors.textSecondary,
      textColor: TenaColors.textPrimary,
    ),

    popupMenuTheme: PopupMenuThemeData(
      color: TenaColors.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: TenaColors.border),
      ),
      textStyle: const TextStyle(
        color: TenaColors.textPrimary,
        fontSize: 14,
      ),
    ),

    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: TenaColors.gold,
      foregroundColor: Colors.black,
      elevation: 4,
    ),

    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: TenaColors.surfaceRaised,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: TenaColors.border),
      ),
      textStyle: const TextStyle(
        color: TenaColors.textSecondary,
        fontSize: 12,
      ),
    ),

    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: TenaColors.gold,
      linearTrackColor: TenaColors.surfaceRaised,
    ),

    textTheme: const TextTheme(
      headlineSmall: TextStyle(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
        color: TenaColors.textPrimary,
      ),
      titleLarge: TextStyle(
        fontWeight: FontWeight.w700,
        color: TenaColors.textPrimary,
      ),
      titleMedium: TextStyle(
        fontWeight: FontWeight.w600,
        color: TenaColors.textPrimary,
      ),
      bodyMedium: TextStyle(color: TenaColors.textSecondary, height: 1.4),
      bodySmall: TextStyle(color: TenaColors.textTertiary),
      labelLarge: TextStyle(fontWeight: FontWeight.w600),
    ),
  );
}