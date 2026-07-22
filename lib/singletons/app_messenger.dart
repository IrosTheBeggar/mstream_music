import 'package:flutter/material.dart';

import '../widgets/desktop_toast.dart';

// Global ScaffoldMessenger key so context-less singletons (e.g.
// DownloadManager) can surface SnackBars. Wired into
// MaterialApp.scaffoldMessengerKey in main.dart.
final GlobalKey<ScaffoldMessengerState> rootMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

// Best-effort notification from anywhere. On the desktop shell this shows a
// bottom-right corner toast (see DesktopToasts) — a full-width SnackBar would
// paint across the Now Playing bar. Everywhere else (phone layout, or a
// desktop window narrowed into the phone shell, where no toast host is
// mounted) it stays a SnackBar. No-ops if neither surface is ready yet
// (e.g. very early startup).
void showGlobalSnack(String message) {
  if (DesktopToasts.instance.hasHost) {
    DesktopToasts.instance.show(message);
    return;
  }
  rootMessengerKey.currentState?.showSnackBar(SnackBar(content: Text(message)));
}
