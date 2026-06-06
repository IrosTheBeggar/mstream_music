import 'package:flutter/services.dart';

import '../build_variant.dart';

/// Toggles the native trust-all TLS bridge (full flavor only) so just_audio's
/// ExoPlayer can stream from a self-signed server. The Dart `http` API path is
/// handled separately by SelfSignedHttpOverrides — ExoPlayer uses the native TLS
/// stack, which Dart can't reach into.
///
/// No-op on the Play build (the channel isn't registered there); errors are
/// swallowed so a missing handler never breaks startup.
class InsecureTlsChannel {
  static const MethodChannel _channel = MethodChannel('mstream/insecure_tls');

  static Future<void> setEnabled(bool enabled) async {
    if (isPlayBuild) return;
    try {
      await _channel.invokeMethod('setEnabled', {'enabled': enabled});
    } catch (_) {
      // No handler (Play build / non-Android / tests) — streaming self-signed
      // is simply unavailable; API self-signed still works via HttpOverrides.
    }
  }
}
