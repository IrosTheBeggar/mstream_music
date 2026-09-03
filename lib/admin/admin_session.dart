/// The single seam between the two hosts the admin module runs in:
///
///  - **Embedded** in the mStream mobile app — `baseUrl` + `token` come from the
///    currently-selected [Server] (see `admin_launcher.dart`).
///  - **Standalone web build** served from the mStream server itself — `baseUrl`
///    is the page origin and `token` comes from the in-app login
///    (`POST /api/v1/auth/login`, see `admin_main.dart` / `LoginScreen`).
///
/// Everything above this file — [AdminApi] and every view — depends only on
/// `baseUrl` + `token`, never on `dart:io`, app singletons, or the Velvet theme.
/// That isolation is what lets the same code compile for web and ship inside the
/// mobile app unchanged.
class AdminSession {
  /// Server origin, e.g. `https://music.example.com:3000` (no trailing slash,
  /// no `/api`). All request paths are resolved against this.
  final String baseUrl;

  /// JWT presented as the `x-access-token` header on every request. Null only
  /// in the brief window before a standalone-web login completes.
  final String? token;

  /// Human label for the app bar (server name when embedded, username on web).
  final String? label;

  const AdminSession({required this.baseUrl, this.token, this.label});

  AdminSession copyWith({String? baseUrl, String? token, String? label}) =>
      AdminSession(
        baseUrl: baseUrl ?? this.baseUrl,
        token: token ?? this.token,
        label: label ?? this.label,
      );
}
