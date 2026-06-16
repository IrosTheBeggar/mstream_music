import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'admin_screen.dart';
import 'admin_session.dart';
import 'admin_theme.dart';
import 'login_screen.dart';

/// Entry point for the **standalone web build** of the admin panel:
///
/// ```
/// flutter build web -t lib/admin/admin_main.dart --release
/// ```
///
/// Drop the resulting `build/web/` into a directory the mStream server serves
/// statically. Because it's served from the server, the login defaults the
/// server URL to the page origin and all requests are same-origin (no CORS,
/// browser already trusts the TLS cert).
///
/// This file imports only `lib/admin/*` — no `dart:io`, no app singletons, no
/// Velvet theme — so the web compile stays clean.
void main() {
  runApp(const AdminWebApp());
}

class AdminWebApp extends StatefulWidget {
  const AdminWebApp({super.key});

  @override
  State<AdminWebApp> createState() => _AdminWebAppState();
}

class _AdminWebAppState extends State<AdminWebApp> {
  AdminSession? _session;

  String get _origin {
    // Page origin when running on web; harmless fallback elsewhere.
    final base = Uri.base;
    if (base.hasAuthority) return '${base.scheme}://${base.authority}';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'mStream Admin',
      debugShowCheckedModeBanner: false,
      theme: adminLightTheme,
      darkTheme: adminDarkTheme,
      themeMode: ThemeMode.system,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: _session == null
          ? LoginScreen(
              defaultBaseUrl: _origin,
              // When served from the server the origin is fixed; still allow an
              // override so the same build works when opened standalone in dev.
              allowServerEdit: true,
              onLoggedIn: (s) => setState(() => _session = s),
            )
          : AdminScreen(
              session: _session!,
              onExit: () => setState(() => _session = null),
            ),
    );
  }
}
