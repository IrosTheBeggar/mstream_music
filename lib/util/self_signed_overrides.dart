import 'dart:io';

import '../build_variant.dart';
import '../singletons/server_list.dart';

/// Dart-side self-signed support for API calls (the `http` package routes
/// through dart:io's HttpClient, which has its own trust store — it ignores
/// Android's). Installed as HttpOverrides.global in main() on the full flavor
/// only.
///
/// Validation is bypassed ONLY for hosts of configured servers that opted into
/// [Server.allowSelfSigned]; every other host keeps normal TLS validation, so a
/// stray request to some other HTTPS endpoint isn't silently downgraded.
class SelfSignedHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.badCertificateCallback = (cert, host, port) {
      if (isPlayBuild) return false;
      return ServerManager().allowsSelfSigned(host);
    };
    return client;
  }
}
