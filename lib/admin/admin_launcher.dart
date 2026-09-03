import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/velvet_theme.dart';
import 'admin_screen.dart';
import 'admin_session.dart';
import 'admin_theme.dart';

/// Opens the admin panel from inside the mobile app for the currently-selected
/// server. Wraps the whole subtree in a standalone Material theme so the admin
/// UI stays visually distinct from the app's Velvet theme — you can see at a
/// glance that you are on the admin surface. Dialogs spawned by the views
/// inherit this theme via `InheritedTheme.capture`, so the entire admin
/// surface — including its dialogs — stays Material.
///
/// Its *brightness*, though, comes from the app rather than the platform:
/// pushing a route from a dark app into a white panel is a jarring flash, and
/// the app's own light/dark choice is the one the user actually made here.
Future<void> openAdminPanel(
  BuildContext context, {
  required String baseUrl,
  required String? token,
  String? label,
  Map<String, String> query = const {},
}) {
  // VelvetColors, not Theme.of(context): the app styles itself from the static
  // palette (46 files do, none of the screens read the inherited theme), and
  // Theme.of in this subtree does not report the app's own light/dark choice.
  final brightness = VelvetColors.brightness;
  return Navigator.of(context).push(MaterialPageRoute(
    builder: (routeContext) {
      return Theme(
        data: adminTheme(brightness),
        child: Builder(
          builder: (themedContext) => AdminScreen(
            session: AdminSession(
                baseUrl: baseUrl, token: token, label: label, query: query),
            embedded: true,
            exitLabel: AppLocalizations.of(themedContext).adminClose,
            onExit: () => Navigator.of(themedContext).maybePop(),
          ),
        ),
      );
    },
  ));
}
