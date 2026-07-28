// Dart FFI binding for the iroh remote-access tunnel (rust/iroh_tunnel).
//
// Talks to the C ABI in `rust/iroh_tunnel/src/c_api.rs` via a prebuilt
// native library:
//   - Android: `libiroh_tunnel.so` (android/app/src/main/jniLibs/<abi>/,
//     built by rust/iroh_tunnel/build-android.sh)
//   - iOS: `iroh_tunnel.framework` embedded in the app bundle (vended by
//     packages/iroh_tunnel_native, built by rust/iroh_tunnel/build-ios.sh)
//
// ABI v2: the native side keys tunnels by pairing code, so every per-tunnel
// call here takes the code and distinct codes can run concurrently:
//   final port = await IrohTunnel.instance.start(pairingCode);
//   // then point the server's effective base URL at http://127.0.0.1:$port
//   ...
//   IrohTunnel.instance.stop(pairingCode);
//
// Against a stale v1 binary ([abiVersion] == 1: same symbol names, no code
// parameter — the committed iOS framework until build-ios.sh is re-run) the code
// argument lands in an unused register and is ignored: single-tunnel semantics,
// which match how the app drives the tunnel today. Multi-tunnel features must
// gate on [abiVersion] >= 2.
//
// `start` blocks in native code (relay warmup + dial, up to ~30s), so it runs on
// a background isolate; the tunnel's accept loop then lives on the Rust runtime.
// The tunnel registry is process-global on the Rust side, so `stop`/`statusOf`
// can be called from the main isolate regardless of where `start` ran.

import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

typedef _StartNative = Int32 Function(Pointer<Utf8>, Uint16);
typedef _StartDart = int Function(Pointer<Utf8>, int);
typedef _CodeVoidNative = Void Function(Pointer<Utf8>);
typedef _CodeVoidDart = void Function(Pointer<Utf8>);
typedef _CodeInt32Native = Int32 Function(Pointer<Utf8>);
typedef _CodeInt32Dart = int Function(Pointer<Utf8>);
typedef _CodeStrNative = Pointer<Utf8> Function(Pointer<Utf8>);
typedef _VoidNative = Void Function();
typedef _VoidDart = void Function();
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
  final _CodeVoidDart stop;
  final _CodeInt32Dart statusCode;
  final _CodeInt32Dart pathKindCode;
  final _VoidDart networkChanged;
  final _LastErrNative lastError;
  final _FreeDart stringFree;
  final _CodeStrNative localTokenPtr;
  final int abiVersion;

  factory _Bindings.open() {
    final lib = _openNativeLib();
    // The version symbol is new in ABI v2; a v1 binary (stale committed iOS
    // framework) doesn't export it — treat a failed lookup as v1.
    int version;
    try {
      version =
          lib.lookupFunction<_Int32Native, _Int32Dart>('mstream_iroh_abi_version')();
    } catch (_) {
      version = 1;
    }
    return _Bindings._(
      lib.lookupFunction<_StartNative, _StartDart>('mstream_iroh_start'),
      lib.lookupFunction<_CodeVoidNative, _CodeVoidDart>('mstream_iroh_stop'),
      lib.lookupFunction<_CodeInt32Native, _CodeInt32Dart>('mstream_iroh_status'),
      lib.lookupFunction<_CodeInt32Native, _CodeInt32Dart>(
          'mstream_iroh_path_kind'),
      lib.lookupFunction<_VoidNative, _VoidDart>('mstream_iroh_network_changed'),
      lib.lookupFunction<_LastErrNative, _LastErrNative>('mstream_iroh_last_error'),
      lib.lookupFunction<_FreeNative, _FreeDart>('mstream_iroh_string_free'),
      lib.lookupFunction<_CodeStrNative, _CodeStrNative>(
          'mstream_iroh_local_token'),
      version,
    );
  }

  _Bindings._(this.start, this.stop, this.statusCode, this.pathKindCode,
      this.networkChanged, this.lastError, this.stringFree, this.localTokenPtr,
      this.abiVersion);

  String? takeLastError() {
    final p = lastError();
    if (p == nullptr) return null;
    try {
      return p.toDartString();
    } finally {
      stringFree(p);
    }
  }

  // Run [body] with [code] as a native UTF-8 string, freeing it after.
  T withCode<T>(String code, T Function(Pointer<Utf8>) body) {
    final cstr = code.toNativeUtf8();
    try {
      return body(cstr);
    } finally {
      malloc.free(cstr);
    }
  }

  String? takeLocalToken(String code) {
    final p = withCode(code, localTokenPtr);
    if (p == nullptr) return null;
    try {
      return p.toDartString();
    } finally {
      stringFree(p);
    }
  }
}

/// Thin Dart wrapper over the native tunnel registry (one tunnel per pairing
/// code). Available only where the native lib (Android `libiroh_tunnel.so`, iOS
/// `iroh_tunnel.framework`) is actually loadable — see [isSupported].
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

  /// The native library's C ABI version: 2 = pairing-code-keyed tunnels
  /// (concurrent tunnels supported), 1 = legacy single-tunnel binary (the code
  /// arguments are ignored natively). 0 when [isSupported] is false. Anything
  /// that runs more than one tunnel at once must require >= 2.
  int get abiVersion => isSupported ? _b.abiVersion : 0;

  /// Start the tunnel for [pairingCode]; returns the loopback port to use as that
  /// server's base URL host:port. Idempotent per code. Runs the blocking native
  /// call off the UI isolate. Throws [IrohTunnelException] on failure.
  Future<int> start(String pairingCode, {int localPort = 0}) async {
    if (!isSupported) {
      throw IrohTunnelException('iroh tunnel is not supported on this device');
    }
    // The blocking native call runs on a background isolate; on failure it throws
    // IrohTunnelException, which Isolate.run rethrows here.
    return Isolate.run(() => _startTunnelSync(pairingCode, localPort));
  }

  /// Stop [pairingCode]'s tunnel (graceful). Safe to call when it isn't running.
  void stop(String pairingCode) {
    if (isSupported) _b.withCode(pairingCode, _b.stop);
  }

  /// [pairingCode]'s tunnel status. [IrohTunnelStatus.down] when unsupported or
  /// that tunnel isn't running.
  IrohTunnelStatus statusOf(String pairingCode) {
    if (!isSupported) return IrohTunnelStatus.down;
    final code = _b.withCode(pairingCode, _b.statusCode);
    if (code < 0 || code >= IrohTunnelStatus.values.length) {
      return IrohTunnelStatus.down;
    }
    return IrohTunnelStatus.values[code];
  }

  /// [pairingCode]'s tunnel connection path kind (direct vs relayed).
  /// [IrohPathKind.unknown] when unsupported, that tunnel isn't running, or no
  /// path is selected yet. A cheap pure read — safe to poll from the main isolate.
  IrohPathKind pathKindOf(String pairingCode) {
    if (!isSupported) return IrohPathKind.unknown;
    final code = _b.withCode(pairingCode, _b.pathKindCode);
    if (code < 0 || code >= IrohPathKind.values.length) {
      return IrohPathKind.unknown;
    }
    return IrohPathKind.values[code];
  }

  /// [pairingCode]'s tunnel loopback auth token (appended to loopback URLs as
  /// `__lt=<token>`), or null when unsupported or that tunnel isn't running.
  /// Other apps on the device can't use the proxy without it.
  String? localTokenOf(String pairingCode) =>
      isSupported ? _b.takeLocalToken(pairingCode) : null;

  /// Notify the native side that the device network changed, so every running
  /// tunnel re-homes its relay and re-probes paths promptly (iroh can't
  /// self-detect this on Android). Cheap; safe to call when nothing is running.
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
// state the main isolate can later stop()/statusOf() through its own handle.
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
