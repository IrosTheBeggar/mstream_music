// Velvet theme — color tokens and ThemeData.
//
// Mirrors the navy/purple dark palette from the Velvet web UI
// (mStream/webapp/velvet/style.css). Colors live as static constants
// here so the rest of the app (DisplayItem, screens, custom painters)
// can reference them without rebuilding the full ThemeData.

import 'package:flutter/material.dart';

class VelvetColors {
  VelvetColors._();

  static const bg = Color(0xFF1A1A2E);
  static const surface = Color(0xFF16213E);
  static const raised = Color(0xFF0F3460);
  static const card = Color(0xFF1E2D4A);
  static const border = Color(0xFF2A3A5E);
  static const border2 = Color(0xFF3A4E72);

  static const primary = Color(0xFF8B5CF6);
  static const primaryHover = Color(0xFF7C3AED);
  static const primaryDim = Color(0x268B5CF6); // ~15% alpha
  static const primaryGlow = Color(0x668B5CF6); // ~40% alpha

  static const accent = Color(0xFF60A5FA);
  static const success = Color(0xFF34D399);
  static const error = Color(0xFFF87171);
  static const warning = Color(0xFFFBBF24);

  static const textPrimary = Color(0xFFEEEEFF);
  static const textSecondary = Color(0xFF8888B0);
  static const textTertiary = Color(0xFF7E8EC0);
  static const textDim = Color(0xFF2A3A5E);

  // Subtle hover/active overlays used on rows & buttons.
  static const hover = Color(0x14FFFFFF); // rgba(255,255,255,.08)
  static const active = Color(0x2E8B5CF6); // rgba(139,92,246,.18)

  // Common radii used throughout the Velvet web UI.
  static const radiusSmall = 7.0;
  static const radiusLarge = 12.0;
}

ThemeData buildVelvetTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: VelvetColors.bg,
    canvasColor: VelvetColors.bg,
    cardColor: VelvetColors.card,
    dividerColor: VelvetColors.border,
    splashColor: VelvetColors.primaryDim,
    highlightColor: VelvetColors.active,

    colorScheme: ColorScheme(
      brightness: Brightness.dark,
      primary: VelvetColors.primary,
      onPrimary: Colors.white,
      primaryContainer: VelvetColors.primaryDim,
      onPrimaryContainer: VelvetColors.textPrimary,
      secondary: VelvetColors.accent,
      onSecondary: Colors.white,
      secondaryContainer: VelvetColors.raised,
      onSecondaryContainer: VelvetColors.textPrimary,
      tertiary: VelvetColors.success,
      onTertiary: Colors.white,
      error: VelvetColors.error,
      onError: Colors.white,
      surface: VelvetColors.surface,
      onSurface: VelvetColors.textPrimary,
      surfaceContainerHighest: VelvetColors.card,
      surfaceContainer: VelvetColors.card,
      surfaceContainerHigh: VelvetColors.raised,
      outline: VelvetColors.border,
      outlineVariant: VelvetColors.border2,
    ),

    appBarTheme: AppBarTheme(
      backgroundColor: VelvetColors.surface,
      foregroundColor: VelvetColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 1,
      shadowColor: VelvetColors.primaryDim,
      surfaceTintColor: Colors.transparent,
      titleTextStyle: TextStyle(
        color: VelvetColors.textPrimary,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.3,
      ),
      iconTheme: IconThemeData(color: VelvetColors.textSecondary),
    ),

    drawerTheme: DrawerThemeData(
      backgroundColor: VelvetColors.surface,
      surfaceTintColor: Colors.transparent,
    ),

    bottomAppBarTheme: BottomAppBarThemeData(
      color: VelvetColors.surface,
      surfaceTintColor: Colors.transparent,
    ),

    tabBarTheme: TabBarThemeData(
      labelColor: VelvetColors.primary,
      unselectedLabelColor: VelvetColors.textSecondary,
      indicatorColor: VelvetColors.primary,
      labelStyle: TextStyle(
        fontWeight: FontWeight.w600,
        fontSize: 14,
        letterSpacing: 0.4,
      ),
      unselectedLabelStyle: TextStyle(fontSize: 14, letterSpacing: 0.4),
      dividerColor: VelvetColors.border,
    ),

    listTileTheme: ListTileThemeData(
      iconColor: VelvetColors.textSecondary,
      textColor: VelvetColors.textPrimary,
      selectedColor: VelvetColors.primary,
      selectedTileColor: VelvetColors.active,
    ),

    iconTheme: IconThemeData(color: VelvetColors.textSecondary),
    textTheme: ThemeData.dark(useMaterial3: true).textTheme.apply(
          bodyColor: VelvetColors.textPrimary,
          displayColor: VelvetColors.textPrimary,
        ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: VelvetColors.raised,
      hintStyle: TextStyle(color: VelvetColors.textTertiary),
      labelStyle: TextStyle(color: VelvetColors.textSecondary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(VelvetColors.radiusSmall),
        borderSide: BorderSide(color: VelvetColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(VelvetColors.radiusSmall),
        borderSide: BorderSide(color: VelvetColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(VelvetColors.radiusSmall),
        borderSide: BorderSide(color: VelvetColors.primary, width: 1.5),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: VelvetColors.primary,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(VelvetColors.radiusSmall),
        ),
        textStyle: TextStyle(fontWeight: FontWeight.w600),
      ),
    ),

    snackBarTheme: SnackBarThemeData(
      backgroundColor: VelvetColors.raised,
      contentTextStyle: TextStyle(color: VelvetColors.textPrimary),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(VelvetColors.radiusSmall),
      ),
    ),

    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: VelvetColors.primary,
      linearTrackColor: VelvetColors.border,
      circularTrackColor: VelvetColors.border,
    ),
  );
}
