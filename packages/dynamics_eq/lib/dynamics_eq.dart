import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// Bridge to Android's DynamicsProcessing effect (Android 9+), used as a
/// graphic equalizer on the player's audio session. One effect per engine;
/// [attach] replaces any previous one. Off Android [isSupported] is false
/// and the other calls are no-ops.
class DynamicsEq {
  static const MethodChannel _channel = MethodChannel('mstream/dynamics_eq');

  /// API 28+ and the device's effect library can create the effect, probed
  /// once natively on a throwaway session.
  static Future<bool> isSupported() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('isSupported') ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Create the effect on [sessionId] with one band per cutoff (Hz, each
  /// band's upper edge) and the matching gains (dB). Throws a
  /// [PlatformException] when the platform refuses.
  static Future<void> attach({
    required int sessionId,
    required List<double> cutoffsHz,
    required List<double> gainsDb,
    bool enabled = true,
    bool limiter = false,
  }) async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('attach', {
      'sessionId': sessionId,
      'cutoffs': cutoffsHz,
      'gains': gainsDb,
      'enabled': enabled,
      'limiter': limiter,
    });
  }

  /// The limiter stage that keeps boosted bands from clipping, on or off.
  static Future<void> setLimiter(bool enabled) async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('setLimiter', {'enabled': enabled});
  }

  static Future<void> setGain(int band, double gainDb) async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('setGain', {'band': band, 'gain': gainDb});
  }

  static Future<void> setEnabled(bool enabled) async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('setEnabled', {'enabled': enabled});
  }

  static Future<void> release() async {
    if (!Platform.isAndroid) return;
    await _channel.invokeMethod<void>('release');
  }
}
