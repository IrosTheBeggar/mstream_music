import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// Desktop-only window/tray/startup integration (leanflutter suite), matching
/// the Electron build's behaviours:
///   * a sized, min-bounded window;
///   * a system-tray icon with a Show / Quit menu;
///   * close-to-tray (the app keeps running when the window is closed);
///   * launch-at-login (opt-in, toggled from Settings).
///
/// Every entry point is gated on [isDesktop], so the mobile builds — where these
/// plugins have no native implementation — never call into them. The window/tray
/// plugins are wired here once at startup; [setLaunchAtStartup] /
/// [isLaunchAtStartupEnabled] back the Settings toggle (the OS is the source of
/// truth, so there's no separate persisted preference).
class DesktopIntegration with WindowListener, TrayListener {
  DesktopIntegration._();
  static final DesktopIntegration instance = DesktopIntegration._();

  /// Registry value name (Windows) / autostart entry (Linux) / login-item label
  /// (macOS). Stable so toggling never orphans an old entry.
  static const _appName = 'mStream Music';
  static const _trayIcon = 'assets/tray_icon.ico';

  static bool get isDesktop =>
      Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  bool _ready = false;

  /// Initialise the window + tray. Call once in main() after
  /// `WidgetsFlutterBinding.ensureInitialized()`, before `runApp`.
  Future<void> init() async {
    if (!isDesktop || _ready) return;
    _ready = true;

    await windowManager.ensureInitialized();
    const options = WindowOptions(
      size: Size(1280, 800),
      minimumSize: Size(900, 600),
      center: true,
      title: 'mStream Music',
      titleBarStyle: TitleBarStyle.normal,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
    // Closing the window hides it to the tray instead of quitting (see
    // onWindowClose); Quit from the tray menu is the real exit.
    await windowManager.setPreventClose(true);
    windowManager.addListener(this);

    await _initTray();
    trayManager.addListener(this);

    // Wire launch-at-login to *this* executable; the actual on/off lives in the
    // OS and is driven by the Settings toggle.
    launchAtStartup.setup(
      appName: _appName,
      appPath: Platform.resolvedExecutable,
    );
  }

  Future<void> _initTray() async {
    await trayManager.setIcon(_trayIcon);
    await trayManager.setToolTip('mStream Music');
    await trayManager.setContextMenu(Menu(items: [
      MenuItem(key: 'show', label: 'Show mStream'),
      MenuItem.separator(),
      MenuItem(key: 'quit', label: 'Quit'),
    ]));
  }

  // ── Launch-at-startup (Settings toggle) ──
  Future<bool> isLaunchAtStartupEnabled() async {
    if (!isDesktop) return false;
    return launchAtStartup.isEnabled();
  }

  Future<void> setLaunchAtStartup(bool enabled) async {
    if (!isDesktop) return;
    if (enabled) {
      await launchAtStartup.enable();
    } else {
      await launchAtStartup.disable();
    }
  }

  // ── WindowListener ──
  @override
  void onWindowClose() async {
    // setPreventClose keeps the X from quitting; hide to the tray instead. When
    // we really want to exit (tray Quit) we clear preventClose first, so this
    // guard lets the close proceed.
    if (await windowManager.isPreventClose()) {
      await windowManager.hide();
    }
  }

  // ── TrayListener ──
  @override
  void onTrayIconMouseDown() => _showWindow();

  @override
  void onTrayIconRightMouseDown() => trayManager.popUpContextMenu();

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show':
        _showWindow();
        break;
      case 'quit':
        _quit();
        break;
    }
  }

  Future<void> _showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> _quit() async {
    await windowManager.setPreventClose(false);
    await trayManager.destroy();
    await windowManager.close();
  }
}
