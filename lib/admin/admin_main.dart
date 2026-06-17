import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'admin_api.dart';
import 'admin_screen.dart';
import 'admin_session.dart';
import 'admin_theme.dart';
import 'login_screen.dart';

/// Entry point for the **standalone web build** of the admin panel:
///
/// ```
/// flutter build web -t lib/admin/admin_main.dart --release --wasm --no-source-maps --base-href /admin/
/// ```
///
/// `--wasm` uses the faster skwasm renderer; `--base-href` must match the route
/// the server serves it from (`/admin/` for mStream's webapp/admin). Drop the
/// resulting `build/web/` into the directory the mStream server serves
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

  /// True while the startup probe runs — decides login-vs-direct entry.
  bool _probing = true;

  @override
  void initState() {
    super.initState();
    _probe();
  }

  /// On a public/no-user server (or when a session cookie is already set) the
  /// admin API is reachable without a token — there is no login to perform, so
  /// enter the panel directly with a token-less session. Otherwise show login.
  Future<void> _probe() async {
    final open = await AdminApi.isOpenAdmin(_origin);
    if (!mounted) return;
    setState(() {
      _probing = false;
      if (open) _session = AdminSession(baseUrl: _origin, token: null);
    });
  }

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
      home: _probing
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : _session == null
              ? LoginScreen(
                  defaultBaseUrl: _origin,
                  // When served from the server the origin is fixed; still allow
                  // an override so the same build works when opened standalone.
                  allowServerEdit: true,
                  onLoggedIn: (s) => setState(() => _session = s),
                )
              : AdminScreen(
                  session: _session!,
                  // A public/no-token session has nothing to log out of.
                  onExit: _session!.token == null
                      ? null
                      : () => setState(() => _session = null),
                ),
    );
  }
}
