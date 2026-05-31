import 'package:flutter/material.dart';

// Global ScaffoldMessenger key so context-less singletons (e.g.
// DownloadManager) can surface SnackBars. Wired into
// MaterialApp.scaffoldMessengerKey in main.dart.
final GlobalKey<ScaffoldMessengerState> rootMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

// Best-effort SnackBar from anywhere. No-ops if the messenger isn't
// mounted yet (e.g. very early startup).
void showGlobalSnack(String message) {
  rootMessengerKey.currentState?.showSnackBar(SnackBar(content: Text(message)));
}
