import 'dart:io' show Platform;

/// True on the three desktop targets. Top-level final so the platform checks
/// resolve once. (The same triple is still open-coded in a handful of older
/// call sites; new code should read this instead.)
final bool isDesktopPlatform =
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;

/// Whether this platform hides the native title bar in favour of the shell's
/// app-drawn band (`_DesktopTopBar`): drives both the window style
/// (desktop/window_setup.dart) and the band's chrome. macOS and Windows;
/// Linux keeps native chrome (its window managers own the title bar).
final bool usesCustomTitleBar = Platform.isMacOS || Platform.isWindows;

/// A hidden title bar that leaves no native buttons behind: the band draws
/// minimize / maximize / close itself and handles double-click zoom. Windows
/// only — macOS keeps its traffic lights floating over the band's left end.
final bool drawsWindowControls = Platform.isWindows;
