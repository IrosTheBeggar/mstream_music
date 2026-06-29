import 'dart:io' show Platform;

import 'package:flutter/services.dart';

/// Thin wrapper over the `mstream/battery` native channel (Android only).
///
/// Lets the app check whether it's exempt from battery optimization (Doze / OEM
/// app-sleeping) and open the system screen so the user can exempt it — so a
/// foreground-service music player isn't frozen/killed with the screen off.
/// Every method no-ops (returns false) off Android.
class BatteryOptimization {
  BatteryOptimization._();
  static final BatteryOptimization _instance = BatteryOptimization._();
  factory BatteryOptimization() => _instance;

  static const MethodChannel _channel = MethodChannel('mstream/battery');

  /// True when the app is already exempt from battery optimization.
  Future<bool> isIgnored() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel
              .invokeMethod<bool>('isIgnoringBatteryOptimizations') ??
          false;
    } on PlatformException {
      return false;
    }
  }

  /// Open the system battery-optimization settings so the user can exempt the
  /// app. Returns false if the screen couldn't be opened.
  Future<bool> openSettings() async {
    if (!Platform.isAndroid) return false;
    try {
      return await _channel.invokeMethod<bool>('openBatterySettings') ?? false;
    } on PlatformException {
      return false;
    }
  }
}
