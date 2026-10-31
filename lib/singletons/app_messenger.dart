import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import 'settings.dart';

// Global ScaffoldMessenger key so context-less singletons (e.g.
// DownloadManager) can surface SnackBars. Wired into
// MaterialApp.scaffoldMessengerKey in main.dart.
// Global Navigator key for the same reason: a notification tap has no
// context of its own to push the Federation screen from.
final GlobalKey<NavigatorState> rootNavigatorKey = GlobalKey<NavigatorState>();

final GlobalKey<ScaffoldMessengerState> rootMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

// Best-effort SnackBar from anywhere. No-ops if the messenger isn't
// mounted yet (e.g. very early startup).
void showGlobalSnack(String message) {
  rootMessengerKey.currentState?.showSnackBar(SnackBar(content: Text(message)));
}

/// Strings without a widget context: the live app's localizations when the
/// navigator is up, else the configured (or device) locale. For singletons
/// that speak to the user from off the widget tree — a notification, a
/// snackbar from the API layer.
AppLocalizations appL10n() {
  final ctx = rootNavigatorKey.currentContext;
  if (ctx != null) return AppLocalizations.of(ctx);
  final locale = SettingsManager().localeOverride ??
      WidgetsBinding.instance.platformDispatcher.locale;
  try {
    return lookupAppLocalizations(locale);
  } catch (_) {
    return lookupAppLocalizations(const Locale('en'));
  }
}
