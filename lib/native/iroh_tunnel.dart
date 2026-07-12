// Dart FFI binding for the iroh remote-access tunnel (rust/iroh_tunnel).
//
// Talks to the C ABI in `rust/iroh_tunnel/src/c_api.rs` via a prebuilt
// native library:
//   - Android: `libiroh_tunnel.so` (android/app/src/main/jniLibs/<abi>/,
//     built by rust/iroh_tunnel/build-android.sh)
//   - iOS: `iroh_tunnel.framework` embedded in the app bundle (vended by
//     packages/iroh_tunnel_native, built by rust/iroh_tunnel/build-ios.sh)
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
typedef _Int32Native = Int32 Function();
typedef _Int32Dart = int Function();
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

// Opens the platform's copy of the native tunnel library.
//  - Android: jniLibs places libiroh_tunnel.so on the loader path under its
//    SONAME.
//  - iOS: the dynamic framework embedded at Runner.app/Frameworks/ (vended by
//    packages/iroh_tunnel_native via SwiftPM); dlopen resolves the
//    bundle-relative framework path — the standard Flutter FFI pattern.
DynamicLibrary _openNativeLib() {
  if (Platform.isIOS) {
    return DynamicLibrary.open('iroh_tunnel.framework/iroh_tunnel');
  }
  return DynamicLibrary.open('libiroh_tunnel.so');
}

class _Bindings {
  final _StartDart start;
  final _VoidDart stop;
  final _BoolDart isActive;
  final _Int32Dart statusCode;
  final _Int32Dart pathKindCode;
  final _VoidDart networkChanged;
  final _LastErrNative lastError;
  final _FreeDart stringFree;
  final _LastErrNative localTokenPtr;

  factory _Bindings.open() {
    final lib = _openNativeLib();
    return _Bindings._(
      lib.lookupFunction<_StartNative, _StartDart>('mstream_iroh_start'),
      lib.lookupFunction<_VoidNative, _VoidDart>('mstream_iroh_stop'),
      lib.lookupFunction<_BoolNative, _BoolDart>('mstream_iroh_is_active'),
      lib.lookupFunction<_Int32Native, _Int32Dart>('mstream_iroh_status'),
      lib.lookupFunction<_Int32Native, _Int32Dart>('mstream_iroh_path_kind'),
      lib.lookupFunction<_VoidNative, _VoidDart>('mstream_iroh_network_changed'),
      lib.lookupFunction<_LastErrNative, _LastErrNative>('mstream_iroh_last_error'),
      lib.lookupFunction<_FreeNative, _FreeDart>('mstream_iroh_string_free'),
      lib.lookupFunction<_LastErrNative, _LastErrNative>('mstream_iroh_local_token'),
    );
  }

  _Bindings._(this.start, this.stop, this.isActive, this.statusCode,
      this.pathKindCode, this.networkChanged, this.lastError, this.stringFree,
      this.localTokenPtr);

  String? takeLastError() {
    final p = lastError();
    if (p == nullptr) return null;
    try {
      return p.toDartString();
    } finally {
      stringFree(p);
    }
  }

  String? takeLocalToken() {
    final p = localTokenPtr();
    if (p == nullptr) return null;
    try {
      return p.toDartString();
    } finally {
      stringFree(p);
    }
  }
}

/// Thin Dart wrapper over the native tunnel. Available only where the native
/// lib (Android `libiroh_tunnel.so`, iOS `iroh_tunnel.framework`) is actually
/// loadable — see [isSupported].
class IrohTunnel {
  IrohTunnel._();
  static final IrohTunnel instance = IrohTunnel._();

  /// True only when the native tunnel library is present and loadable. On
  /// Android it's bundled for arm64-v8a / x86_64 only; on a 32-bit
  /// armeabi-v7a device (which we still ship for broad Play device coverage,
  /// without native libs) the .so is absent, so iroh is unavailable there —
  /// not just on unsupported platforms. On iOS it's the embedded
  /// iroh_tunnel.framework. Probed once and cached. Every FFI entry point
  /// below is gated on this, so a missing lib degrades to "unavailable"
  /// instead of crashing (mirrors ProjectMBindings.isAvailable).
  static bool get isSupported => _isSupported ??= _probeSupport();
  static bool? _isSupported;
  static bool _probeSupport() {
    // Desktop stays unsupported (no native lib is shipped there).
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    try {
      _openNativeLib();
      return true;
    } catch (_) {
      return false;
    }
  }

  _Bindings? _bindings;
  _Bindings get _b => _bindings ??= _Bindings.open();

  /// Start the tunnel for [pairingCode]; returns the loopback port to use as the
  /// server's base URL host:port. Runs the blocking native call off the UI
  /// isolate. Throws [IrohTunnelException] on failure.
  Future<int> start(String pairingCode, {int localPort = 0}) async {
    if (!isSupported) {
      throw IrohTunnelException('iroh tunnel is not supported on this device');
    }
    // The blocking native call runs on a background isolate; on failure it throws
    // IrohTunnelException, which Isolate.run rethrows here.
    return Isolate.run(() => _startTunnelSync(pairingCode, localPort));
  }

  /// Stop the tunnel (graceful). Safe to call when nothing is running.
  void stop() {
    if (isSupported) _b.stop();
  }

  /// Whether the tunnel is currently CONNECTED (honest health check — a
  /// reconnecting/rejected/dead tunnel reports false).
  bool get isActive => isSupported && _b.isActive();

  /// Current connection status. [IrohTunnelStatus.down] when unsupported or no
  /// tunnel is running.
  IrohTunnelStatus get status {
    if (!isSupported) return IrohTunnelStatus.down;
    final code = _b.statusCode();
    if (code < 0 || code >= IrohTunnelStatus.values.length) {
      return IrohTunnelStatus.down;
    }
    return IrohTunnelStatus.values[code];
  }

  /// Current connection path kind (direct vs relayed) for the active tunnel.
  /// [IrohPathKind.unknown] when unsupported, nothing is running, or no path is
  /// selected yet. A cheap pure read — safe to poll from the main isolate.
  IrohPathKind get pathKind {
    if (!isSupported) return IrohPathKind.unknown;
    final code = _b.pathKindCode();
    if (code < 0 || code >= IrohPathKind.values.length) {
      return IrohPathKind.unknown;
    }
    return IrohPathKind.values[code];
  }

  /// The active tunnel's loopback auth token (appended to loopback URLs as
  /// `__lt=<token>`), or null when unsupported or nothing is running. Other apps
  /// on the device can't use the proxy without it.
  String? get localToken => isSupported ? _b.takeLocalToken() : null;

  /// Notify the native tunnel that the device network changed, so iroh re-homes
  /// the relay and re-probes paths promptly (it can't self-detect this on
  /// Android). Cheap; safe to call when nothing is running.
  void networkChanged() {
    if (isSupported) _b.networkChanged();
  }
}

/// Tunnel connection status — mirrors the STATUS_* codes in
/// rust/iroh_tunnel/src/lib.rs (index == code).
enum IrohTunnelStatus { connecting, connected, reconnecting, rejected, down }

/// Tunnel path kind — mirrors the PATH_* codes in rust/iroh_tunnel/src/lib.rs
/// (index == code). `direct` is a hole-punched peer-to-peer path (fast);
/// `relay` means traffic is routed via a relay server (works anywhere, slower).
enum IrohPathKind { unknown, direct, relay }

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
