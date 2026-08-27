import 'dart:io' show Platform;

/// True on the three desktop targets. Top-level final so the platform checks
/// resolve once. (The same triple is still open-coded in a handful of older
/// call sites; new code should read this instead.)
final bool isDesktopPlatform =
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;

/// Whether this platform hides the native title bar in favour of the shell's
/// app-drawn band (`_WindowTitleBar`): drives both the window style
/// (desktop/window_setup.dart) and whether the shell mounts the band. macOS
/// only for now — Windows/Linux keep native chrome, and their sidebar keeps
/// the wordmark.
final bool usesCustomTitleBar = Platform.isMacOS;
