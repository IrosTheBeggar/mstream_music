import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// Android WifiLock shim — the Wi-Fi half of ExoPlayer's WAKE_MODE_NETWORK,
/// which just_audio doesn't expose. audio_service already holds the CPU half
/// (a partial wake lock); without this, screen-off Wi-Fi power-save can
/// throttle the radio mid-stream and stall playback.
///
/// Effective on API <= 33 (the fleet the stall reports came from). On 34+ the
/// OS converts the lock to screen-on-only LOW_LATENCY — harmless but inert
/// for screen-off streaming; see the platform-side comment.
class WifiLockShim {
  static const MethodChannel _channel = MethodChannel('mstream/wifi_lock');

  static bool _held = false;

  /// Acquire ([want] true) or release the lock. Deduped — repeat calls with
  /// the same value never cross the platform channel, so this is cheap to
  /// call from every state broadcast — and fail-open: a platform error can
  /// never block playback (worst case is pre-shim behavior, and an engine
  /// detach releases a stranded lock natively). No-op off Android.
  static Future<void> setHeld(bool want) async {
    if (!Platform.isAndroid || want == _held) return;
    _held = want;
    try {
      await _channel.invokeMethod<bool>('setHeld', want);
    } catch (_) {
      // Fail open (see doc comment).
    }
  }
}
