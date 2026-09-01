import 'package:flutter/services.dart';

import '../build_variant.dart';

/// Syncs the native per-host TLS bypass (full flavor only) so just_audio's
/// ExoPlayer can stream from a self-signed server. The Dart `http` API path is
/// handled separately by SelfSignedHttpOverrides — ExoPlayer uses the native TLS
/// stack, which Dart can't reach into.
///
/// Only the hosts passed here skip validation on the native side; every other
/// host keeps full platform TLS validation (mirroring the per-host scoping of
/// SelfSignedHttpOverrides). An empty list restores the platform defaults.
///
/// No-op on the Play build (the channel isn't registered there); errors are
/// swallowed so a missing handler never breaks startup.
class InsecureTlsChannel {
  static const MethodChannel _channel = MethodChannel('mstream/insecure_tls');

  static Future<void> setAllowedHosts(Iterable<String> hosts) async {
    if (isPlayBuild) return;
    try {
      await _channel
          .invokeMethod('setAllowedHosts', {'hosts': hosts.toList()});
    } catch (_) {
      // No handler (Play build / non-Android / tests) — streaming self-signed
      // is simply unavailable; API self-signed still works via HttpOverrides.
    }
  }
}
