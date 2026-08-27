// window_setup.dart — desktop window chrome: a sized, min-bounded window and
// the platform's title-bar style.
//
// This is all that remains of the old DesktopIntegration: serving — and the
// tray icon, close-to-tray, and launch-at-login that existed to babysit it —
// moved to the standalone mstream-launcher (server repo, rust-launcher/). The
// player's window now behaves like any app's: closing it quits.

import 'package:flutter/widgets.dart' show Size;
import 'package:window_manager/window_manager.dart';

import '../util/desktop_platform.dart';

/// Initialise the desktop window. Call once in main() after
/// `WidgetsFlutterBinding.ensureInitialized()`, before `runApp`. No-op on
/// mobile platforms.
Future<void> initDesktopWindow() async {
  if (!isDesktopPlatform) return;

  await windowManager.ensureInitialized();
  final options = WindowOptions(
    size: const Size(1280, 800),
    // Keep the floor comfortably above the 900px desktop-shell breakpoint
    // (main.dart): minimumSize is the OUTER window, but the breakpoint reads
    // the inner Flutter view (window minus borders, scaled by DPI), which is a
    // few px smaller. Sitting the min at exactly 900 let the content tip under
    // 900 at the smallest size and flip to the phone shell — 960 leaves room.
    minimumSize: const Size(960, 640),
    center: true,
    title: 'mStream Music',
    // With the custom title bar the shell draws its own band (wordmark +
    // drag area) under the native traffic lights, which stay visible.
    titleBarStyle:
        usesCustomTitleBar ? TitleBarStyle.hidden : TitleBarStyle.normal,
  );
  await windowManager.waitUntilReadyToShow(options, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}
