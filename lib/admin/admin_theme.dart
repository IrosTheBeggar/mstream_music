import 'package:flutter/material.dart';

/// Clean Material 3 light/dark themes for the admin surface.
///
/// The goal explicitly says: ignore the app's Velvet theme here, just honor a
/// standard light/dark theme. So the admin module derives its own [ThemeData]
/// from the ambient [Brightness] — seeded with mStream's brand blue — and never
/// imports `theme/velvet_theme.dart`. The mobile host wraps the embedded screen
/// in one of these; the standalone web `MaterialApp` uses both with
/// `themeMode: ThemeMode.system`.
const Color _seed = Color(0xFF6684B2); // mStream logo blue

ThemeData adminTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: _seed, brightness: brightness);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surfaceContainer,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 1,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      margin: EdgeInsets.zero,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      isDense: true,
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
    ),
  );
}

ThemeData get adminLightTheme => adminTheme(Brightness.light);
ThemeData get adminDarkTheme => adminTheme(Brightness.dark);
