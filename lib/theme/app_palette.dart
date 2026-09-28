import 'package:flutter/material.dart';

enum AppThemeId { light, ash, dark, onyx, galaxy, aurora }

@immutable
class AppPalette {
  final Color background;

  final Color sidebarBackground;

  final Color surface;

  final Color card;

  final Color cardHover;

  final Color inputBackground;

  final Color border;

  final Color textPrimary;
  final Color textSecondary;
  final Brightness brightness;

  const AppPalette({
    required this.background,
    required this.sidebarBackground,
    required this.surface,
    required this.card,
    required this.cardHover,
    required this.inputBackground,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.brightness,
  });

  AppPalette withOpaqueSurfaces() {
    Color solid(Color color) => Color.alphaBlend(color, Colors.black);
    return AppPalette(
      background: background,
      sidebarBackground: sidebarBackground,
      surface: solid(surface),
      card: solid(card),
      cardHover: solid(cardHover),
      inputBackground: solid(inputBackground),
      border: solid(border),
      textPrimary: textPrimary,
      textSecondary: textSecondary,
      brightness: brightness,
    );
  }
}

const AppPalette kDarkPalette = AppPalette(
  background: Color(0xFF121212),
  sidebarBackground: Color(0xFF0F0F0F),
  surface: Color(0xFF181818),
  card: Color(0xFF242424),
  cardHover: Color(0xFF282828),
  inputBackground: Color(0xFF2A2A2A),
  border: Color(0xFF3E3E3E),
  textPrimary: Colors.white,
  textSecondary: Colors.white70,
  brightness: Brightness.dark,
);

const AppPalette kOnyxPalette = AppPalette(
  background: Color(0xFF000000),
  sidebarBackground: Color(0xFF000000),
  surface: Color(0xFF0A0A0A),
  card: Color(0xFF141414),
  cardHover: Color(0xFF1E1E1E),
  inputBackground: Color(0xFF1A1A1A),
  border: Color(0xFF2A2A2A),
  textPrimary: Colors.white,
  textSecondary: Colors.white70,
  brightness: Brightness.dark,
);

const AppPalette kAshPalette = AppPalette(
  background: Color(0xFF36393F),
  sidebarBackground: Color(0xFF2F3136),
  surface: Color(0xFF313338),
  card: Color(0xFF3A3D44),
  cardHover: Color(0xFF43474F),
  inputBackground: Color(0xFF3F4147),
  border: Color(0xFF4A4D53),
  textPrimary: Colors.white,
  textSecondary: Colors.white70,
  brightness: Brightness.dark,
);

const AppPalette kLightPalette = AppPalette(
  background: Color(0xFFFFFFFF),
  sidebarBackground: Color(0xFFF7F7F7),
  surface: Color(0xFFF2F2F2),
  card: Color(0xFFECECEC),
  cardHover: Color(0xFFE0E0E0),
  inputBackground: Color(0xFFEDEDED),
  border: Color(0xFFD8D8D8),
  textPrimary: Color(0xFF1A1A1A),
  textSecondary: Color(0xFF5F5F5F),
  brightness: Brightness.light,
);

const AppPalette kGalaxyPalette = AppPalette(
  background: Color(0x66101935),
  sidebarBackground: Color(0x660B1330),
  surface: Color(0x99141E3D),
  card: Color(0x991B2749),
  cardHover: Color(0xB3223056),
  inputBackground: Color(0xB31F2B52),
  border: Color(0xCC3A4A7A),
  textPrimary: Colors.white,
  textSecondary: Colors.white70,
  brightness: Brightness.dark,
);

const AppPalette kAuroraPalette = AppPalette(
  background: Color(0x66050B14),
  sidebarBackground: Color(0x66040810),
  surface: Color(0x9909121E),
  card: Color(0x990E1526),
  cardHover: Color(0xB3131B33),
  inputBackground: Color(0xB3111931),
  border: Color(0xCC2A3A5C),
  textPrimary: Colors.white,
  textSecondary: Colors.white70,
  brightness: Brightness.dark,
);

AppPalette paletteFor(AppThemeId id) => switch (id) {
      AppThemeId.light => kLightPalette,
      AppThemeId.ash => kAshPalette,
      AppThemeId.dark => kDarkPalette,
      AppThemeId.onyx => kOnyxPalette,
      AppThemeId.galaxy => kGalaxyPalette,
      AppThemeId.aurora => kAuroraPalette,
    };

String themeLabelFor(AppThemeId id) => switch (id) {
      AppThemeId.light => 'Light',
      AppThemeId.ash => 'Ash',
      AppThemeId.dark => 'Dark',
      AppThemeId.onyx => 'Onyx',
      AppThemeId.galaxy => 'Astral',
      AppThemeId.aurora => 'Aurore',
    };

typedef _LightnessLadder = ({
  double background,
  double sidebarBackground,
  double surface,
  double card,
  double cardHover,
  double inputBackground,
  double border,
});

const _LightnessLadder _darkLadder = (
  background: 0.0706,
  sidebarBackground: 0.0588,
  surface: 0.0941,
  card: 0.1412,
  cardHover: 0.1569,
  inputBackground: 0.1647,
  border: 0.2431,
);

const _LightnessLadder _lightLadder = (
  background: 1.0,
  sidebarBackground: 0.9686,
  surface: 0.9490,
  card: 0.9255,
  cardHover: 0.8784,
  inputBackground: 0.9294,
  border: 0.8471,
);

typedef _AlphaLadder = ({
  double background,
  double sidebarBackground,
  double surface,
  double card,
  double cardHover,
  double inputBackground,
  double border,
});

const _AlphaLadder _translucentAlphaLadder = (
  background: 0.4,
  sidebarBackground: 0.4,
  surface: 0.6,
  card: 0.6,
  cardHover: 0.7,
  inputBackground: 0.7,
  border: 0.8,
);

AppPalette customPaletteFrom(Color seed, {bool translucent = false}) {
  final hsl = HSLColor.fromColor(seed);
  final isDark = ThemeData.estimateBrightnessForColor(seed) == Brightness.dark;
  final ladder = isDark ? _darkLadder : _lightLadder;
  Color roleColor(double lightness, double alpha, {double saturationScale = 1.0}) {
    final color = HSLColor.fromAHSL(1.0, hsl.hue, (hsl.saturation * saturationScale).clamp(0.0, 1.0), lightness).toColor();
    return translucent ? color.withValues(alpha: alpha) : color;
  }

  return AppPalette(
    background: roleColor(ladder.background, _translucentAlphaLadder.background),
    sidebarBackground: roleColor(ladder.sidebarBackground, _translucentAlphaLadder.sidebarBackground),
    surface: roleColor(ladder.surface, _translucentAlphaLadder.surface),
    card: roleColor(ladder.card, _translucentAlphaLadder.card),
    cardHover: roleColor(ladder.cardHover, _translucentAlphaLadder.cardHover),
    inputBackground: roleColor(ladder.inputBackground, _translucentAlphaLadder.inputBackground),
    border: roleColor(ladder.border, _translucentAlphaLadder.border, saturationScale: 0.6),
    textPrimary: isDark ? Colors.white : const Color(0xFF1A1A1A),
    textSecondary: isDark ? Colors.white70 : const Color(0xFF5F5F5F),
    brightness: isDark ? Brightness.dark : Brightness.light,
  );
}

const List<(String, Color)> kAccentPresets = [
  ('Violet', Colors.deepPurple),
  ('Vert', Color(0xFF1DB954)),
  ('Bleu', Color(0xFF3B82F6)),
  ('Rouge', Color(0xFFE53935)),
  ('Orange', Color(0xFFFF7A00)),
  ('Rose', Color(0xFFEC4899)),
  ('Jaune', Color(0xFFFBBF24)),
  ('Turquoise', Color(0xFF14B8A6)),
];
