import 'dart:ffi';
import 'dart:io';

import '../singletons/log_manager.dart';

/// Keeps the DISPLAY awake while desktop party mode is locked — audio
/// playback alone doesn't stop display sleep, and a party screen that goes
/// black defeats the point.
///
/// No dependencies: macOS runs a `caffeinate -d` child scoped to our pid
/// (`-w` makes it exit with us even if release() never runs); Windows sets
/// SetThreadExecutionState via FFI. Linux is a no-op for now (TODO: D-Bus
/// ScreenSaver Inhibit).
class WakeGuard {
  WakeGuard._();
  static final WakeGuard instance = WakeGuard._();

  Process? _caffeinate;
  bool _held = false;

  Future<void> acquire() async {
    if (_held) return;
    _held = true;
    if (Platform.isMacOS) {
      try {
        _caffeinate =
            await Process.start('/usr/bin/caffeinate', ['-d', '-w', '$pid']);
      } catch (e) {
        appLog('[wake] caffeinate failed: $e');
      }
    } else if (Platform.isWindows) {
      _setThreadExecutionState(_esContinuous | _esDisplayRequired);
    }
  }

  void release() {
    if (!_held) return;
    _held = false;
    _caffeinate?.kill();
    _caffeinate = null;
    if (Platform.isWindows) {
      // Clear the display requirement; CONTINUOUS alone resets to normal.
      _setThreadExecutionState(_esContinuous);
    }
  }

  static const int _esContinuous = 0x80000000;
  static const int _esDisplayRequired = 0x00000002;

  static void _setThreadExecutionState(int flags) {
    try {
      final k32 = DynamicLibrary.open('kernel32.dll');
      final f = k32.lookupFunction<Uint32 Function(Uint32), int Function(int)>(
          'SetThreadExecutionState');
      f(flags);
    } catch (e) {
      appLog('[wake] SetThreadExecutionState failed: $e');
    }
  }
}
