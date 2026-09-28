import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../theme/app_palette.dart';
import '../utils/platform_paths.dart';

const String _kThemeIdPrefsKey = 'themeId';
const String _kAccentSeedPrefsKey = 'accentSeedValue';
const String _kCustomThemeSeedPrefsKey = 'customThemeSeedValue';
const String _kCustomThemeImagePathPrefsKey = 'customThemeImagePath';

class ThemeState extends ChangeNotifier {
  final SharedPreferences _prefs;
  AppThemeId _themeId;
  Color _accentSeed;
  Color? _customThemeSeed;
  String? _customThemeImagePath;

  ThemeState._(this._prefs, this._themeId, this._accentSeed, this._customThemeSeed, this._customThemeImagePath);

  factory ThemeState.load(SharedPreferences prefs) {
    final savedId = prefs.getString(_kThemeIdPrefsKey);
    final themeId = AppThemeId.values.firstWhere(
      (v) => v.name == savedId,
      orElse: () => AppThemeId.dark,
    );
    final savedAccent = prefs.getInt(_kAccentSeedPrefsKey);
    final accentSeed = savedAccent != null ? Color(savedAccent) : Colors.deepPurple;
    final savedCustomTheme = prefs.getInt(_kCustomThemeSeedPrefsKey);
    final customThemeSeed = savedCustomTheme != null ? Color(savedCustomTheme) : null;
    final customThemeImagePath = prefs.getString(_kCustomThemeImagePathPrefsKey);
    return ThemeState._(prefs, themeId, accentSeed, customThemeSeed, customThemeImagePath);
  }

  void reloadFromPrefs() {
    final savedId = _prefs.getString(_kThemeIdPrefsKey);
    _themeId = AppThemeId.values.firstWhere((v) => v.name == savedId, orElse: () => AppThemeId.dark);
    final savedAccent = _prefs.getInt(_kAccentSeedPrefsKey);
    _accentSeed = savedAccent != null ? Color(savedAccent) : Colors.deepPurple;
    final savedCustomTheme = _prefs.getInt(_kCustomThemeSeedPrefsKey);
    _customThemeSeed = savedCustomTheme != null ? Color(savedCustomTheme) : null;
    _customThemeImagePath = _prefs.getString(_kCustomThemeImagePathPrefsKey);
    notifyListeners();
  }

  AppThemeId get themeId => _themeId;
  Color get accentSeed => _accentSeed;

  Color? get customThemeSeed => _customThemeSeed;

  String? get customThemeImagePath => _customThemeImagePath;

  AppPalette get palette {
    final base = _customThemeSeed != null
        ? customPaletteFrom(_customThemeSeed!, translucent: isImageThemeActive)
        : paletteFor(_themeId);
    return isMobile && (isGalaxyActive || isAuroraActive) ? base.withOpaqueSurfaces() : base;
  }

  bool get isGalaxyActive => _customThemeSeed == null && _themeId == AppThemeId.galaxy;

  bool get isAuroraActive => _customThemeSeed == null && _themeId == AppThemeId.aurora;

  bool get isImageThemeActive => _customThemeImagePath != null;

  Color get accent => _accentSeed;

  Color get accentDeep => _shiftLightness(_accentSeed, -0.15);

  Color get accentBright => _shiftLightness(_accentSeed, 0.15);

  Color get accentForeground =>
      ThemeData.estimateBrightnessForColor(_accentSeed) == Brightness.dark ? Colors.white : Colors.black;

  void setThemeId(AppThemeId id) {
    if (id == _themeId && _customThemeSeed == null) return;
    _themeId = id;
    _customThemeSeed = null;
    _customThemeImagePath = null;
    notifyListeners();
    unawaited(_prefs.setString(_kThemeIdPrefsKey, id.name));
    unawaited(_prefs.remove(_kCustomThemeSeedPrefsKey));
    unawaited(_prefs.remove(_kCustomThemeImagePathPrefsKey));
  }

  void setCustomThemeSeed(Color color) {
    if (_customThemeSeed != null && color.toARGB32() == _customThemeSeed!.toARGB32() && _customThemeImagePath == null) {
      return;
    }
    _customThemeSeed = color;
    _customThemeImagePath = null;
    notifyListeners();
    unawaited(_prefs.setInt(_kCustomThemeSeedPrefsKey, color.toARGB32()));
    unawaited(_prefs.remove(_kCustomThemeImagePathPrefsKey));
  }

  void setCustomThemeFromImage(String imagePath, Color dominantColor) {
    _customThemeSeed = dominantColor;
    _customThemeImagePath = imagePath;
    notifyListeners();
    unawaited(_prefs.setInt(_kCustomThemeSeedPrefsKey, dominantColor.toARGB32()));
    unawaited(_prefs.setString(_kCustomThemeImagePathPrefsKey, imagePath));
  }

  void setAccentSeed(Color color) {
    if (color.toARGB32() == _accentSeed.toARGB32()) return;
    _accentSeed = color;
    notifyListeners();
    unawaited(_prefs.setInt(_kAccentSeedPrefsKey, color.toARGB32()));
  }
}

Color _shiftLightness(Color color, double delta) {
  final hsl = HSLColor.fromColor(color);
  return hsl.withLightness((hsl.lightness + delta).clamp(0.0, 1.0)).toColor();
}
