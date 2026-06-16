import 'package:flutter/material.dart';

import 'admin_screen.dart';
import 'admin_session.dart';
import 'admin_theme.dart';

/// Opens the admin panel from inside the mobile app for the currently-selected
/// server. Wraps the whole subtree in a standalone light/dark Material theme so
/// the admin UI ignores the app's Velvet theme (per the design goal). Dialogs
/// spawned by the views inherit this theme via `InheritedTheme.capture`, so the
/// entire admin surface — including its dialogs — stays light/dark Material.
Future<void> openAdminPanel(
  BuildContext context, {
  required String baseUrl,
  required String? token,
  String? label,
}) {
  return Navigator.of(context).push(MaterialPageRoute(
    builder: (routeContext) {
      final brightness = MediaQuery.platformBrightnessOf(routeContext);
      return Theme(
        data: adminTheme(brightness),
        child: Builder(
          builder: (themedContext) => AdminScreen(
            session: AdminSession(baseUrl: baseUrl, token: token, label: label),
            exitLabel: 'Close',
            onExit: () => Navigator.of(themedContext).maybePop(),
          ),
        ),
      );
    },
  ));
}
