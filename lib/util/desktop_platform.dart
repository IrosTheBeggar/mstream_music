import 'dart:io' show Platform;

/// True on the three desktop targets. Top-level final so the platform checks
/// resolve once. (The same triple is still open-coded in a handful of older
/// call sites; new code should read this instead.)
final bool isDesktopPlatform =
    Platform.isWindows || Platform.isLinux || Platform.isMacOS;
