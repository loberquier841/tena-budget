import 'package:flutter/material.dart';

import 'tena_theme.dart';

/// Thème sombre Material 3 (existant, préservé) — noir/blanc/or subtil.
ThemeData buildTenaTheme() => buildTenaDarkTheme();

ThemeData buildTenaDarkTheme() {
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

  return _applyComponents(base, scheme,
      appBarBg: TenaColors.background,
      cardColor: TenaColors.surface,
      dialogBg: TenaColors.surface,
      inputFill: TenaColors.surfaceRaised,
      popupBg: TenaColors.surfaceRaised,
      snackBg: TenaColors.surfaceRaised,
      track: TenaColors.surfaceRaised,
      border: TenaColors.border,
      textPrimary: TenaColors.textPrimary,
      textSecondary: TenaColors.textSecondary,
      textTertiary: TenaColors.textTertiary);
}

/// Thème clair Material 3 (LOT 9.1) — premium sobre, or subtil conservé.
ThemeData buildTenaLightTheme() {
  const gold = TenaColors.gold; // #D4AF37 accent conservé
  const bg = Color(0xFFF7F7F8);
  const surface = Colors.white;
  const raised = Color(0xFFF0F0F2);
  const border = Color(0xFFE1E1E6);
  const textPrimary = Color(0xFF17171B);
  const textSecondary = Color(0xFF5A5A66);
  const textTertiary = Color(0xFF8A8A96);
  const scheme = ColorScheme.light(
    primary: Color(0xFF9A7B1F), // or plus lisible sur fond clair
    onPrimary: Colors.white,
    primaryContainer: Color(0xFFF3E6B8),
    onPrimaryContainer: Color(0xFF2A2108),
    secondary: TenaColors.goldMuted,
    onSecondary: Colors.white,
    surface: surface,
    onSurface: textPrimary,
    surfaceContainerHighest: raised,
    onSurfaceVariant: textSecondary,
    outline: textTertiary,
    outlineVariant: border,
    error: TenaColors.danger,
    onError: Colors.white,
  );

  final base = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: scheme,
    scaffoldBackgroundColor: bg,
  );

  return _applyComponents(base, scheme,
      appBarBg: bg,
      cardColor: surface,
      dialogBg: surface,
      inputFill: raised,
      popupBg: surface,
      snackBg: const Color(0xFF1C1C20),
      snackText: TenaColors.textPrimary,
      track: raised,
      border: border,
      textPrimary: textPrimary,
      textSecondary: textSecondary,
      textTertiary: textTertiary,
      focusPrimary: gold);
}

ThemeData _applyComponents(ThemeData base, ColorScheme scheme,
    {required Color appBarBg,
    required Color cardColor,
    required Color dialogBg,
    required Color inputFill,
    required Color popupBg,
    required Color snackBg,
    Color? snackText,
    required Color track,
    required Color border,
    required Color textPrimary,
    required Color textSecondary,
    required Color textTertiary,
    Color? focusPrimary}) {
  final focus = focusPrimary ?? scheme.primary;
  return base.copyWith(
    appBarTheme: AppBarTheme(
      backgroundColor: appBarBg,
      surfaceTintColor: Colors.transparent,
      foregroundColor: textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    cardTheme: CardThemeData(
      color: cardColor,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
          borderRadius: TenaRadius.lg, side: BorderSide(color: border)),
      margin: EdgeInsets.zero,
    ),
    dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: TenaColors.gold,
        foregroundColor: Colors.black,
        elevation: 0,
        padding: const EdgeInsets.symmetric(
            horizontal: TenaSpacing.xl, vertical: 14),
        shape: const RoundedRectangleBorder(borderRadius: TenaRadius.md),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: focus,
        side: BorderSide(color: focus.withValues(alpha: 0.7)),
        padding: const EdgeInsets.symmetric(
            horizontal: TenaSpacing.xl, vertical: 14),
        shape: const RoundedRectangleBorder(borderRadius: TenaRadius.md),
        textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
          foregroundColor: focus,
          textStyle: const TextStyle(fontWeight: FontWeight.w600)),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: inputFill,
      contentPadding: const EdgeInsets.symmetric(
          horizontal: TenaSpacing.lg, vertical: TenaSpacing.lg),
      border: OutlineInputBorder(
          borderRadius: TenaRadius.md, borderSide: BorderSide(color: border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: TenaRadius.md, borderSide: BorderSide(color: border)),
      focusedBorder: OutlineInputBorder(
          borderRadius: TenaRadius.md,
          borderSide: BorderSide(color: focus, width: 1.5)),
      errorBorder: const OutlineInputBorder(
          borderRadius: TenaRadius.md,
          borderSide: BorderSide(color: TenaColors.danger)),
      focusedErrorBorder: const OutlineInputBorder(
          borderRadius: TenaRadius.md,
          borderSide: BorderSide(color: TenaColors.danger, width: 1.5)),
      labelStyle: TextStyle(color: textSecondary),
      floatingLabelStyle: TextStyle(color: focus),
      hintStyle: TextStyle(color: textTertiary),
      prefixIconColor: textSecondary,
      suffixIconColor: textSecondary,
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: dialogBg,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: border)),
      titleTextStyle:
          TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: textPrimary),
      contentTextStyle:
          TextStyle(fontSize: 14, color: textSecondary, height: 1.4),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: dialogBg,
      surfaceTintColor: Colors.transparent,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: snackBg,
      contentTextStyle:
          TextStyle(color: snackText ?? textPrimary, fontSize: 14),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    listTileTheme:
        ListTileThemeData(iconColor: textSecondary, textColor: textPrimary),
    popupMenuTheme: PopupMenuThemeData(
      color: popupBg,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: border)),
      textStyle: TextStyle(color: textPrimary, fontSize: 14),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: TenaColors.gold,
        foregroundColor: Colors.black,
        elevation: 4),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
          color: popupBg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: border)),
      textStyle: TextStyle(color: textSecondary, fontSize: 12),
    ),
    progressIndicatorTheme:
        ProgressIndicatorThemeData(color: focus, linearTrackColor: track),
    textTheme: TextTheme(
      headlineSmall: TextStyle(
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
          color: textPrimary),
      titleLarge:
          TextStyle(fontWeight: FontWeight.w700, color: textPrimary),
      titleMedium:
          TextStyle(fontWeight: FontWeight.w600, color: textPrimary),
      bodyMedium: TextStyle(color: textSecondary, height: 1.4),
      bodySmall: TextStyle(color: textTertiary),
      labelLarge: const TextStyle(fontWeight: FontWeight.w600),
    ),
  );
}
