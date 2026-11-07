import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Préférences d'apparence/personnalisation (LOT 9.1/9.2) — local uniquement.
/// Aucune donnée transmise ; SharedPreferences (stockage local app).
class AppearanceService extends ChangeNotifier {
  AppearanceService._();
  static final AppearanceService instance = AppearanceService._();

  static const _kTheme = 'tena_appearance_theme_mode'; // system|light|dark
  static const _kTextScale = 'tena_appearance_text_scale'; // 0.9..1.3
  static const _kReduceMotion = 'tena_appearance_reduce_motion';
  static const _kDateFormat = 'tena_appearance_date_format'; // fr|iso
  static const _kCurrency = 'tena_appearance_currency'; // EUR|CHF|...

  ThemeMode _themeMode = ThemeMode.dark; // défaut historique premium sombre
  double _textScale = 1.0;
  bool _reduceMotion = false;
  String _dateFormat = 'fr';
  String _currency = 'EUR';
  bool _loaded = false;

  ThemeMode get themeMode => _themeMode;
  double get textScale => _textScale;
  bool get reduceMotion => _reduceMotion;
  String get dateFormat => _dateFormat;
  String get currency => _currency;
  bool get loaded => _loaded;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    _themeMode = _parseMode(p.getString(_kTheme));
    _textScale = (p.getDouble(_kTextScale) ?? 1.0).clamp(0.85, 1.35);
    _reduceMotion = p.getBool(_kReduceMotion) ?? false;
    _dateFormat = p.getString(_kDateFormat) ?? 'fr';
    _currency = p.getString(_kCurrency) ?? 'EUR';
    _loaded = true;
    notifyListeners();
  }

  ThemeMode _parseMode(String? v) {
    switch (v) {
      case 'light':
        return ThemeMode.light;
      case 'system':
        return ThemeMode.system;
      case 'dark':
      default:
        return ThemeMode.dark;
    }
  }

  String _modeToString(ThemeMode m) {
    switch (m) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.system:
        return 'system';
      case ThemeMode.dark:
        return 'dark';
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString(_kTheme, _modeToString(mode));
  }

  Future<void> setTextScale(double v) async {
    _textScale = v.clamp(0.85, 1.35);
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setDouble(_kTextScale, _textScale);
  }

  Future<void> setReduceMotion(bool v) async {
    _reduceMotion = v;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kReduceMotion, v);
  }

  Future<void> setDateFormat(String v) async {
    _dateFormat = v;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString(_kDateFormat, v);
  }

  Future<void> setCurrency(String v) async {
    _currency = v;
    notifyListeners();
    final p = await SharedPreferences.getInstance();
    await p.setString(_kCurrency, v);
  }
}
