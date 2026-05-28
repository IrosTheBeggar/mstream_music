// App theme system — three swappable palettes built on the same shape.
//
// The original Velvet palette (navy/purple) lives alongside two more:
// Dark (neutral dark + amber accent) and Light (master branch's mixed
// scheme — light body + dark AppBar + amber accents).
//
// VelvetColors used to be a class of static const colors. To allow
// runtime theme switching, the constants are now dynamic getters that
// read from a single "active" palette which the app re-points before
// MaterialApp rebuilds (see main.dart's StreamBuilder wrapping).
// Existing callers (e.g. `VelvetColors.bg`) work unchanged.

import 'package:flutter/material.dart';

enum AppTheme {
  velvet,
  dark,
  light;

  String get label {
    switch (this) {
      case AppTheme.velvet:
        return 'Velvet';
      case AppTheme.dark:
        return 'Dark';
      case AppTheme.light:
        return 'Light';
    }
  }
}

class VelvetPalette {
  final Brightness brightness;
  final Color bg, surface, raised, card, border, border2;
  final Color primary, primaryHover, primaryDim, primaryGlow;
  final Color accent, success, error, warning;
  final Color textPrimary, textSecondary, textTertiary, textDim;
  final Color hover, active;
  // AppBar-specific so a theme can pair a light body with a dark
  // AppBar (or vice versa) without losing text contrast.
  final Color appBarBg, appBarText, appBarTextSecondary;

  const VelvetPalette({
    required this.brightness,
    required this.bg,
    required this.surface,
    required this.raised,
    required this.card,
    required this.border,
    required this.border2,
    required this.primary,
    required this.primaryHover,
    required this.primaryDim,
    required this.primaryGlow,
    required this.accent,
    required this.success,
    required this.error,
    required this.warning,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textDim,
    required this.hover,
    required this.active,
    required this.appBarBg,
    required this.appBarText,
    required this.appBarTextSecondary,
  });
}

// Original Velvet palette — navy bg, purple primary.
const _velvetPalette = VelvetPalette(
  brightness: Brightness.dark,
  bg: Color(0xFF1A1A2E),
  surface: Color(0xFF16213E),
  raised: Color(0xFF0F3460),
  card: Color(0xFF1E2D4A),
  border: Color(0xFF2A3A5E),
  border2: Color(0xFF3A4E72),
  primary: Color(0xFF8B5CF6),
  primaryHover: Color(0xFF7C3AED),
  primaryDim: Color(0x268B5CF6),
  primaryGlow: Color(0x668B5CF6),
  accent: Color(0xFF60A5FA),
  success: Color(0xFF34D399),
  error: Color(0xFFF87171),
  warning: Color(0xFFFBBF24),
  textPrimary: Color(0xFFEEEEFF),
  textSecondary: Color(0xFF8888B0),
  textTertiary: Color(0xFF7E8EC0),
  textDim: Color(0xFF2A3A5E),
  hover: Color(0x14FFFFFF),
  active: Color(0x2E8B5CF6),
  // AppBar matches surface — same dark navy.
  appBarBg: Color(0xFF16213E),
  appBarText: Color(0xFFEEEEFF),
  appBarTextSecondary: Color(0xFF8888B0),
);

// Neutral dark theme with amber accent — closer to material defaults
// than Velvet but stays dark across the board. Bars are the darker
// shade so they frame the slightly-lighter body.
const _darkPalette = VelvetPalette(
  brightness: Brightness.dark,
  bg: Color(0xFF1E1E1E),
  surface: Color(0xFF1E1E1E),
  raised: Color(0xFF2A2A2A),
  card: Color(0xFF242424),
  border: Color(0xFF333333),
  border2: Color(0xFF4A4A4A),
  primary: Color(0xFFFFAB00),
  primaryHover: Color(0xFFFFC233),
  primaryDim: Color(0x26FFAB00),
  primaryGlow: Color(0x66FFAB00),
  accent: Color(0xFFFFAB00),
  success: Color(0xFF34D399),
  error: Color(0xFFF87171),
  warning: Color(0xFFFBBF24),
  textPrimary: Color(0xFFEEEEEE),
  textSecondary: Color(0xFFAAAAAA),
  textTertiary: Color(0xFF888888),
  textDim: Color(0xFF555555),
  hover: Color(0x14FFFFFF),
  active: Color(0x26FFAB00),
  appBarBg: Color(0xFF121212),
  appBarText: Color(0xFFEEEEEE),
  appBarTextSecondary: Color(0xFFAAAAAA),
);

// Light theme mirrors master: light gray body, dark AppBar, amber.
// Master's actual values:
//   scaffoldBackgroundColor: 0xFFe1e2e1
//   cardColor: 0xFFffffff
//   primaryColor (AppBar bg): 0xFF212121
//   buttonColor / accent: 0xFFFFAB00
const _lightPalette = VelvetPalette(
  brightness: Brightness.light,
  bg: Color(0xFFE1E2E1),
  surface: Color(0xFFFFFFFF),
  raised: Color(0xFFEFEFEF),
  card: Color(0xFFFFFFFF),
  border: Color(0xFFCCCCCC),
  border2: Color(0xFFAAAAAA),
  primary: Color(0xFFFFAB00),
  primaryHover: Color(0xFFE69500),
  primaryDim: Color(0x26FFAB00),
  primaryGlow: Color(0x66FFAB00),
  accent: Color(0xFFFFAB00),
  success: Color(0xFF22C55E),
  error: Color(0xFFEF4444),
  warning: Color(0xFFFB923C),
  textPrimary: Color(0xFF1A1A1A),
  textSecondary: Color(0xFF555555),
  textTertiary: Color(0xFF777777),
  textDim: Color(0xFFBBBBBB),
  hover: Color(0x14000000),
  active: Color(0x26FFAB00),
  // Master's dark AppBar with light text on top.
  appBarBg: Color(0xFF212121),
  appBarText: Color(0xFFFAFAFA),
  appBarTextSecondary: Color(0xFFBBBBBB),
);

VelvetPalette paletteFor(AppTheme t) {
  switch (t) {
    case AppTheme.velvet:
      return _velvetPalette;
    case AppTheme.dark:
      return _darkPalette;
    case AppTheme.light:
      return _lightPalette;
  }
}

class VelvetColors {
  VelvetColors._();

  static VelvetPalette _active = _darkPalette;

  /// Re-point the active palette. Call this *before* MaterialApp
  /// rebuilds so the new theme and direct VelvetColors lookups stay
  /// in sync (see main.dart's theme StreamBuilder).
  static void setActive(VelvetPalette p) {
    _active = p;
  }

  static Color get bg => _active.bg;
  static Color get surface => _active.surface;
  static Color get raised => _active.raised;
  static Color get card => _active.card;
  static Color get border => _active.border;
  static Color get border2 => _active.border2;

  static Color get primary => _active.primary;
  static Color get primaryHover => _active.primaryHover;
  static Color get primaryDim => _active.primaryDim;
  static Color get primaryGlow => _active.primaryGlow;

  static Color get accent => _active.accent;
  static Color get success => _active.success;
  static Color get error => _active.error;
  static Color get warning => _active.warning;

  static Color get textPrimary => _active.textPrimary;
  static Color get textSecondary => _active.textSecondary;
  static Color get textTertiary => _active.textTertiary;
  static Color get textDim => _active.textDim;

  static Color get hover => _active.hover;
  static Color get active => _active.active;

  static Color get appBarBg => _active.appBarBg;
  static Color get appBarText => _active.appBarText;
  static Color get appBarTextSecondary => _active.appBarTextSecondary;

  // Theme-independent.
  static const radiusSmall = 7.0;
  static const radiusLarge = 12.0;
}

ThemeData buildAppTheme(VelvetPalette p) {
  return ThemeData(
    useMaterial3: true,
    brightness: p.brightness,
    scaffoldBackgroundColor: p.bg,
    canvasColor: p.bg,
    cardColor: p.card,
    dividerColor: p.border,
    splashColor: p.primaryDim,
    highlightColor: p.active,
    colorScheme: ColorScheme(
      brightness: p.brightness,
      primary: p.primary,
      onPrimary: Colors.white,
      primaryContainer: p.primaryDim,
      onPrimaryContainer: p.textPrimary,
      secondary: p.accent,
      onSecondary: Colors.white,
      secondaryContainer: p.raised,
      onSecondaryContainer: p.textPrimary,
      tertiary: p.success,
      onTertiary: Colors.white,
      error: p.error,
      onError: Colors.white,
      surface: p.surface,
      onSurface: p.textPrimary,
      surfaceContainerHighest: p.card,
      surfaceContainer: p.card,
      surfaceContainerHigh: p.raised,
      outline: p.border,
      outlineVariant: p.border2,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: p.appBarBg,
      foregroundColor: p.appBarText,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: p.primaryDim,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: p.appBarText,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      iconTheme: IconThemeData(color: p.appBarTextSecondary),
    ),
    drawerTheme: DrawerThemeData(
      backgroundColor: p.surface,
      surfaceTintColor: Colors.transparent,
    ),
    bottomAppBarTheme: BottomAppBarThemeData(
      color: p.appBarBg,
      surfaceTintColor: Colors.transparent,
    ),
    tabBarTheme: TabBarThemeData(
      labelColor: p.primary,
      // TabBar lives in AppBar.bottom, so it sits on appBarBg. Use the
      // AppBar-paired secondary text color so unselected tabs stay
      // readable when AppBar and body have different brightnesses
      // (notably the Light theme: dark bar over a light body).
      unselectedLabelColor: p.appBarTextSecondary,
      indicatorColor: p.primary,
      labelStyle: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 14,
        letterSpacing: 0.4,
      ),
      unselectedLabelStyle: TextStyle(fontSize: 14, letterSpacing: 0.4),
      dividerColor: p.border,
    ),
    listTileTheme: ListTileThemeData(
      iconColor: p.textSecondary,
      textColor: p.textPrimary,
      selectedColor: p.primary,
      selectedTileColor: p.active,
    ),
    iconTheme: IconThemeData(color: p.textSecondary),
    textTheme: (p.brightness == Brightness.dark
            ? ThemeData.dark(useMaterial3: true).textTheme
            : ThemeData.light(useMaterial3: true).textTheme)
        .apply(
      bodyColor: p.textPrimary,
      displayColor: p.textPrimary,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: p.raised,
      hintStyle: TextStyle(color: p.textTertiary),
      labelStyle: TextStyle(color: p.textSecondary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(VelvetColors.radiusSmall),
        borderSide: BorderSide(color: p.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(VelvetColors.radiusSmall),
        borderSide: BorderSide(color: p.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(VelvetColors.radiusSmall),
        borderSide: BorderSide(color: p.primary, width: 1.5),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: p.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VelvetColors.radiusSmall),
        ),
        textStyle: TextStyle(fontWeight: FontWeight.w600),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: p.raised,
      contentTextStyle: TextStyle(color: p.textPrimary),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(VelvetColors.radiusSmall),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: p.primary,
      linearTrackColor: p.border,
      circularTrackColor: p.border,
    ),
  );
}

// Backwards-compatible alias for code that still calls buildVelvetTheme().
ThemeData buildVelvetTheme() => buildAppTheme(_velvetPalette);
