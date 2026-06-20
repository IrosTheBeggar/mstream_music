// Dart FFI binding for the iroh remote-access tunnel (rust/iroh_tunnel).
//
// Talks to the C ABI in `rust/iroh_tunnel/src/c_api.rs` via the prebuilt
// `libiroh_tunnel.so` (packaged into android/app/src/main/jniLibs/<abi>/).
//
// Usage (M3 wires this into the connection model):
//   final port = await IrohTunnel.instance.start(pairingCode);
//   // then point the server's effective base URL at http://127.0.0.1:$port
//   ...
//   await IrohTunnel.instance.stop();
//
// `start` blocks in native code (relay warmup + dial, up to ~30s), so it runs on
// a background isolate; the tunnel's accept loop then lives on the Rust runtime.
// The tunnel state is process-global on the Rust side, so `stop`/`isActive` can be
// called from the main isolate regardless of where `start` ran.

import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

typedef _StartNative = Int32 Function(Pointer<Utf8>, Uint16);
typedef _StartDart = int Function(Pointer<Utf8>, int);
typedef _VoidNative = Void Function();
typedef _VoidDart = void Function();
typedef _BoolNative = Bool Function();
typedef _BoolDart = bool Function();
typedef _LastErrNative = Pointer<Utf8> Function();
typedef _FreeNative = Void Function(Pointer<Utf8>);
typedef _FreeDart = void Function(Pointer<Utf8>);

/// Thrown when starting the tunnel fails (bad/rotated pairing code, unreachable
/// server, etc.). The message is the native side's human-readable reason.
class IrohTunnelException implements Exception {
  final String message;
  IrohTunnelException(this.message);
  @override
  String toString() => 'IrohTunnelException: $message';
}

class _Bindings {
  final _StartDart start;
  final _VoidDart stop;
  final _BoolDart isActive;
  final _LastErrNative lastError;
  final _FreeDart stringFree;

  factory _Bindings.open() {
    // jniLibs places the .so on the loader path under its SONAME on Android.
    final lib = DynamicLibrary.open('libiroh_tunnel.so');
    return _Bindings._(
      lib.lookupFunction<_StartNative, _StartDart>('mstream_iroh_start'),
      lib.lookupFunction<_VoidNative, _VoidDart>('mstream_iroh_stop'),
      lib.lookupFunction<_BoolNative, _BoolDart>('mstream_iroh_is_active'),
      lib.lookupFunction<_LastErrNative, _LastErrNative>('mstream_iroh_last_error'),
      lib.lookupFunction<_FreeNative, _FreeDart>('mstream_iroh_string_free'),
    );
  }

  _Bindings._(this.start, this.stop, this.isActive, this.lastError, this.stringFree);

  String? takeLastError() {
    final p = lastError();
    if (p == nullptr) return null;
    try {
      return p.toDartString();
    } finally {
      stringFree(p);
    }
  }
}

/// Thin Dart wrapper over the native tunnel. Only available on Android (the .so
/// is built for arm64-v8a / x86_64); [isSupported] is false elsewhere.
class IrohTunnel {
  IrohTunnel._();
  static final IrohTunnel instance = IrohTunnel._();

  static bool get isSupported => Platform.isAndroid;

  _Bindings? _bindings;
  _Bindings get _b => _bindings ??= _Bindings.open();

  /// Start the tunnel for [pairingCode]; returns the loopback port to use as the
  /// server's base URL host:port. Runs the blocking native call off the UI
  /// isolate. Throws [IrohTunnelException] on failure.
  Future<int> start(String pairingCode, {int localPort = 0}) async {
    if (!isSupported) {
      throw IrohTunnelException('iroh tunnel is only supported on Android');
    }
    // The blocking native call runs on a background isolate; on failure it throws
    // IrohTunnelException, which Isolate.run rethrows here.
    return Isolate.run(() => _startTunnelSync(pairingCode, localPort));
  }

  /// Stop the tunnel (graceful). Safe to call when nothing is running.
  void stop() {
    if (isSupported) _b.stop();
  }

  /// Whether a tunnel is currently active.
  bool get isActive => isSupported && _b.isActive();
}

// Top-level so it can run in a background isolate (no captured `this`). The .so
// is process-global, so opening the bindings here and starting the tunnel leaves
// state the main isolate can later stop()/isActive() through its own handle.
int _startTunnelSync(String code, int localPort) {
  final b = _Bindings.open();
  final cstr = code.toNativeUtf8();
  try {
    final port = b.start(cstr, localPort);
    if (port < 0) {
      throw IrohTunnelException(b.takeLastError() ?? 'unknown tunnel error');
    }
    return port;
  } finally {
    malloc.free(cstr);
  }
}
