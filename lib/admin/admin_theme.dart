import 'package:flutter/material.dart';

/// "Instrument" — the admin surface's own theme.
///
/// Deliberately not the app's Velvet skin and not stock Material either. The
/// panel is where libraries get removed, keys revoked and the admin API locked,
/// so it should be visibly a different place from the player — but the break
/// should look chosen rather than like an unstyled default.
///
/// The result is a cool slate ground with mStream's logo blue lifted to sit on
/// it, and **state carries the colour**: everything else is greyscale, so a
/// green/amber/red pill is the only saturated thing on screen and reads as
/// meaning rather than decoration. Its brightness follows the app (see
/// `admin_launcher.dart`), so both variants below get used.
const Color _brandBlue = Color(0xFF6684B2); // mStream logo blue

// ── Instrument, dark ────────────────────────────────────────────────────────
const _darkSurface = Color(0xFF10131A); // page ground
const _darkContainer = Color(0xFF151923); // app bar, sidebar
const _darkCard = Color(0xFF171B24); // AdminCard
const _darkRaised = Color(0xFF1E2532); // chips, code blocks
const _darkHairline = Color(0xFF262C38); // card borders, dividers
const _darkOutline = Color(0xFF3A4354);
const _darkPrimary = Color(0xFF8AA9DC); // brand blue, lifted for a dark ground
const _darkOnPrimary = Color(0xFF0D1017);
const _darkPrimaryContainer = Color(0xFF22304A); // selected nav row
const _darkOnSurface = Color(0xFFE6E9EF);
const _darkOnSurfaceVariant = Color(0xFF9AA3B2);

// ── Instrument, light ───────────────────────────────────────────────────────
const _lightSurface = Color(0xFFF4F6FA);
const _lightContainer = Color(0xFFE9EDF5);
const _lightCard = Color(0xFFFFFFFF);
const _lightRaised = Color(0xFFEDF1F8);
const _lightHairline = Color(0xFFDCE2EC);
const _lightOutline = Color(0xFFA8B2C4);
const _lightPrimary = Color(0xFF3C5F94); // brand blue darkened to hold on white
const _lightOnPrimary = Color(0xFFFFFFFF);
const _lightPrimaryContainer = Color(0xFFD7E2F5);
const _lightOnSurface = Color(0xFF171B24);
const _lightOnSurfaceVariant = Color(0xFF58627A);

/// The four states the panel actually reports, kept out of the views so a
/// status never reaches for a raw `Colors.green`. Each is tuned to stay legible
/// as StatusPill uses it — as text and icon over a 15%-alpha wash of itself.
@immutable
class AdminStatusColors extends ThemeExtension<AdminStatusColors> {
  /// Healthy, connected, verified, enabled.
  final Color ok;

  /// Reachable but degraded, or configured but not yet confirmed.
  final Color warn;

  /// Off, unavailable, not configured — deliberately colourless.
  final Color idle;

  /// Neutral identification (a running job, "mstream"), not a health claim.
  final Color info;

  const AdminStatusColors({
    required this.ok,
    required this.warn,
    required this.idle,
    required this.info,
  });

  static const dark = AdminStatusColors(
    ok: Color(0xFF34D399),
    warn: Color(0xFFFBBF24),
    idle: Color(0xFF7C8698),
    info: _darkPrimary,
  );

  static const light = AdminStatusColors(
    ok: Color(0xFF0F9D6B),
    warn: Color(0xFFB4740E),
    idle: Color(0xFF6B7488),
    info: _lightPrimary,
  );

  /// The set for the surrounding admin theme. Falls back to the dark set only
  /// if someone mounts an admin widget outside [adminTheme].
  static AdminStatusColors of(BuildContext context) =>
      Theme.of(context).extension<AdminStatusColors>() ?? dark;

  @override
  AdminStatusColors copyWith({
    Color? ok,
    Color? warn,
    Color? idle,
    Color? info,
  }) =>
      AdminStatusColors(
        ok: ok ?? this.ok,
        warn: warn ?? this.warn,
        idle: idle ?? this.idle,
        info: info ?? this.info,
      );

  @override
  AdminStatusColors lerp(ThemeExtension<AdminStatusColors>? other, double t) {
    if (other is! AdminStatusColors) return this;
    return AdminStatusColors(
      ok: Color.lerp(ok, other.ok, t)!,
      warn: Color.lerp(warn, other.warn, t)!,
      idle: Color.lerp(idle, other.idle, t)!,
      info: Color.lerp(info, other.info, t)!,
    );
  }
}

ThemeData adminTheme(Brightness brightness) {
  final dark = brightness == Brightness.dark;

  // Seeded first so every role Material needs exists and stays coherent, then
  // the roles the panel actually reads are pinned to the Instrument values.
  final scheme = ColorScheme.fromSeed(
    seedColor: _brandBlue,
    brightness: brightness,
  ).copyWith(
    surface: dark ? _darkSurface : _lightSurface,
    surfaceContainerLowest: dark ? const Color(0xFF0C0F15) : Colors.white,
    surfaceContainerLow: dark ? _darkCard : _lightCard,
    surfaceContainer: dark ? _darkContainer : _lightContainer,
    surfaceContainerHigh: dark ? _darkRaised : _lightRaised,
    surfaceContainerHighest: dark ? _darkRaised : _lightRaised,
    onSurface: dark ? _darkOnSurface : _lightOnSurface,
    onSurfaceVariant: dark ? _darkOnSurfaceVariant : _lightOnSurfaceVariant,
    outlineVariant: dark ? _darkHairline : _lightHairline,
    outline: dark ? _darkOutline : _lightOutline,
    primary: dark ? _darkPrimary : _lightPrimary,
    onPrimary: dark ? _darkOnPrimary : _lightOnPrimary,
    primaryContainer: dark ? _darkPrimaryContainer : _lightPrimaryContainer,
    onPrimaryContainer: dark ? const Color(0xFFDCE6F6) : const Color(0xFF12233B),
    error: dark ? const Color(0xFFF87171) : const Color(0xFFB3261E),
    onError: dark ? const Color(0xFF1A0E0E) : Colors.white,
    errorContainer: dark ? const Color(0xFF3A1E1E) : const Color(0xFFF9DEDC),
    onErrorContainer: dark ? const Color(0xFFFFD9D9) : const Color(0xFF410E0B),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: scheme.surface,
    dividerColor: scheme.outlineVariant,
    extensions: [dark ? AdminStatusColors.dark : AdminStatusColors.light],
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surfaceContainer,
      foregroundColor: scheme.onSurface,
      elevation: 0,
      scrolledUnderElevation: 0,
      // The ground is darker than the bar, so a hairline reads better than a
      // shadow — and it holds up in light mode too.
      shape: Border(bottom: BorderSide(color: scheme.outlineVariant)),
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
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      space: 1,
      thickness: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
      isDense: true,
      filled: true,
      fillColor: dark ? _darkSurface : _lightRaised,
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 16),
    ),
    // Squarer than Material's stadium default: this is a control surface, and
    // the softer shape reads closer to the 12px cards it sits inside.
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        minimumSize: const Size(0, 44),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        minimumSize: const Size(0, 44),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(0, 44)),
    ),
    // M3 defaults an extended FAB to primaryContainer, which on this ground is
    // barely brighter than a card — the one "add" action per view should read
    // as the primary thing you can do.
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: scheme.primary,
      foregroundColor: scheme.onPrimary,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      highlightElevation: 0,
      extendedTextStyle: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: dark ? _darkRaised : _lightRaised,
      side: BorderSide(color: scheme.outlineVariant),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
    ),
  );
}

ThemeData get adminLightTheme => adminTheme(Brightness.light);
ThemeData get adminDarkTheme => adminTheme(Brightness.dark);
