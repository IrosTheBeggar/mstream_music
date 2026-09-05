// Dart FFI binding for the iroh remote-access tunnel (rust/iroh_tunnel).
//
// Talks to the C ABI in `rust/iroh_tunnel/src/c_api.rs` via a prebuilt
// native library:
//   - Android: `libiroh_tunnel.so` (android/app/src/main/jniLibs/<abi>/,
//     built by rust/iroh_tunnel/build-android.sh)
//   - iOS: `iroh_tunnel.framework` embedded in the app bundle (vended by
//     packages/iroh_tunnel_native, built by rust/iroh_tunnel/build-ios.sh)
//
// ABI v2: tunnels are keyed by an app-chosen id — the server's identity, so
// several can run at once (a Quick Connect server and a directly-reached
// federated peer, say), each on its own loopback port with its own
// supervisor. The key is NOT the credential: a federated peer's guest token
// is refreshed daily through [IrohTunnel.setCredential] while the tunnel,
// its port and every URL built against it stay put.
//
// Usage:
//   final port = await IrohTunnel.instance.start(key, code);
//   // then point the server's effective base URL at http://127.0.0.1:$port
//   ...
//   IrohTunnel.instance.stop(key);
//
// `start` blocks in native code (relay warmup + dial, up to ~30s), so it runs on
// a background isolate; the tunnel's accept loop then lives on the Rust runtime.
// The tunnel table is process-global on the Rust side, so every other call can
// be made from the main isolate regardless of where `start` ran.

import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';

typedef _StartNative = Int32 Function(Pointer<Utf8>, Pointer<Utf8>, Uint16);
typedef _StartDart = int Function(Pointer<Utf8>, Pointer<Utf8>, int);
typedef _KeyVoidNative = Void Function(Pointer<Utf8>);
typedef _KeyVoidDart = void Function(Pointer<Utf8>);
typedef _KeyBoolNative = Bool Function(Pointer<Utf8>);
typedef _KeyBoolDart = bool Function(Pointer<Utf8>);
typedef _KeyInt32Native = Int32 Function(Pointer<Utf8>);
typedef _KeyInt32Dart = int Function(Pointer<Utf8>);
typedef _KeyStrNative = Pointer<Utf8> Function(Pointer<Utf8>);
typedef _TwoStrInt32Native = Int32 Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _TwoStrInt32Dart = int Function(Pointer<Utf8>, Pointer<Utf8>);
typedef _VoidNative = Void Function();
typedef _VoidDart = void Function();
typedef _Int32Native = Int32 Function();
typedef _Int32Dart = int Function();
typedef _StrNative = Pointer<Utf8> Function();
typedef _FreeNative = Void Function(Pointer<Utf8>);
typedef _FreeDart = void Function(Pointer<Utf8>);

/// The C ABI version this binding was written against. A committed binary
/// older than this is refused outright ([IrohTunnel.isSupported] is false and
/// [IrohTunnel.unsupportedReason] says why) rather than being driven with
/// arguments it would misread.
const int kIrohTunnelAbiVersion = 2;

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
  final int abiVersion;
  final _StartDart start;
  final _KeyVoidDart stop;
  final _KeyBoolDart isActive;
  final _KeyInt32Dart statusCode;
  final _KeyInt32Dart pathKindCode;
  final _VoidDart networkChanged;
  final _KeyVoidDart forceReconnect;
  final _TwoStrInt32Dart setCredential;
  final _KeyStrNative drainEventsPtr;
  final _KeyInt32Dart relayOnlineCode;
  final _KeyStrNative localTokenPtr;
  final _StrNative lastError;
  final _FreeDart stringFree;

  /// Resolves every symbol. Throws [IrohTunnelException] on a binary that
  /// predates ABI v2 (no version symbol, or a smaller number): its `start`
  /// takes different arguments, so driving it would be worse than refusing.
  factory _Bindings.open() {
    final lib = _openNativeLib();
    final int abi;
    try {
      abi = lib.lookupFunction<_Int32Native, _Int32Dart>('mstream_iroh_abi_version')();
    } on ArgumentError {
      throw IrohTunnelException(
          'native tunnel binary predates ABI v$kIrohTunnelAbiVersion — rebuild it (rust/iroh_tunnel/build-*.sh)');
    }
    if (abi < kIrohTunnelAbiVersion) {
      throw IrohTunnelException(
          'native tunnel binary is ABI v$abi; this app needs v$kIrohTunnelAbiVersion — rebuild it');
    }
    return _Bindings._(
      abi,
      lib.lookupFunction<_StartNative, _StartDart>('mstream_iroh_start'),
      lib.lookupFunction<_KeyVoidNative, _KeyVoidDart>('mstream_iroh_stop'),
      lib.lookupFunction<_KeyBoolNative, _KeyBoolDart>('mstream_iroh_is_active'),
      lib.lookupFunction<_KeyInt32Native, _KeyInt32Dart>('mstream_iroh_status'),
      lib.lookupFunction<_KeyInt32Native, _KeyInt32Dart>('mstream_iroh_path_kind'),
      lib.lookupFunction<_VoidNative, _VoidDart>('mstream_iroh_network_changed'),
      lib.lookupFunction<_KeyVoidNative, _KeyVoidDart>('mstream_iroh_force_reconnect'),
      lib.lookupFunction<_TwoStrInt32Native, _TwoStrInt32Dart>('mstream_iroh_set_credential'),
      lib.lookupFunction<_KeyStrNative, _KeyStrNative>('mstream_iroh_drain_events'),
      lib.lookupFunction<_KeyInt32Native, _KeyInt32Dart>('mstream_iroh_relay_online'),
      lib.lookupFunction<_KeyStrNative, _KeyStrNative>('mstream_iroh_local_token'),
      lib.lookupFunction<_StrNative, _StrNative>('mstream_iroh_last_error'),
      lib.lookupFunction<_FreeNative, _FreeDart>('mstream_iroh_string_free'),
    );
  }

  _Bindings._(
      this.abiVersion,
      this.start,
      this.stop,
      this.isActive,
      this.statusCode,
      this.pathKindCode,
      this.networkChanged,
      this.forceReconnect,
      this.setCredential,
      this.drainEventsPtr,
      this.relayOnlineCode,
      this.localTokenPtr,
      this.lastError,
      this.stringFree);

  /// Run [f] with [key] as a native string, freeing it afterwards.
  T withKey<T>(String key, T Function(Pointer<Utf8>) f) {
    final p = key.toNativeUtf8();
    try {
      return f(p);
    } finally {
      malloc.free(p);
    }
  }

  /// Take ownership of a native string result (null → null) and free it.
  String? takeString(Pointer<Utf8> p) {
    if (p == nullptr) return null;
    try {
      return p.toDartString();
    } finally {
      stringFree(p);
    }
  }

  String? takeLastError() => takeString(lastError());
}

/// Thin Dart wrapper over the native tunnel table. Available only where the
/// native lib (Android `libiroh_tunnel.so`, iOS `iroh_tunnel.framework`) is
/// actually loadable AND at least ABI v2 — see [isSupported].
class IrohTunnel {
  IrohTunnel._();
  static final IrohTunnel instance = IrohTunnel._();

  /// True only when the native tunnel library is present, loadable, and new
  /// enough. On Android it's bundled for arm64-v8a / x86_64 only; on a 32-bit
  /// armeabi-v7a device (which we still ship for broad Play device coverage,
  /// without native libs) the .so is absent, so iroh is unavailable there —
  /// not just on unsupported platforms. On iOS it's the embedded
  /// iroh_tunnel.framework. Probed once and cached. Every FFI entry point
  /// below is gated on this, so a missing or stale lib degrades to
  /// "unavailable" instead of crashing (mirrors ProjectMBindings.isAvailable).
  static bool get isSupported => _isSupported ??= _probeSupport();
  static bool? _isSupported;

  /// Why [isSupported] is false, for the diagnostics log; null when it is
  /// true or the platform simply ships no native lib.
  static String? unsupportedReason;

  static bool _probeSupport() {
    // Desktop stays unsupported (no native lib is shipped there).
    if (!Platform.isAndroid && !Platform.isIOS) return false;
    try {
      // Opening the bindings also checks the ABI version (see _Bindings.open):
      // a stale committed binary must not be driven with v2 arguments.
      instance._bindings ??= _Bindings.open();
      return true;
    } on IrohTunnelException catch (e) {
      unsupportedReason = e.message;
      return false;
    } catch (_) {
      return false;
    }
  }

  _Bindings? _bindings;
  _Bindings get _b => _bindings ??= _Bindings.open();

  /// The running binary's C ABI version, or 0 when unsupported.
  int get abiVersion => isSupported ? _b.abiVersion : 0;

  /// Start the tunnel for [key] from [code] — a Quick Connect pairing code or
  /// a federation guest ticket; returns the loopback port to use as that
  /// server's base URL host:port. Idempotent per key. Runs the blocking native
  /// call off the UI isolate. Throws [IrohTunnelException] on failure; the
  /// message contains "rejected" when the server refused the credential
  /// (wrong/rotated secret, or an expired/revoked guest token).
  Future<int> start(String key, String code, {int localPort = 0}) async {
    if (!isSupported) {
      throw IrohTunnelException(
          unsupportedReason ?? 'iroh tunnel is not supported on this device');
    }
    // The blocking native call runs on a background isolate; on failure it throws
    // IrohTunnelException, which Isolate.run rethrows here.
    return Isolate.run(() => _startTunnelSync(key, code, localPort));
  }

  /// Stop the tunnel for [key] (graceful). Safe to call when it isn't running.
  void stop(String key) {
    if (isSupported) _b.withKey(key, _b.stop);
  }

  /// Whether the tunnel for [key] is currently CONNECTED (honest health check
  /// — a reconnecting/rejected/dead tunnel reports false).
  bool isActive(String key) => isSupported && _b.withKey(key, _b.isActive);

  /// Connection status of the tunnel for [key]. [IrohTunnelStatus.down] when
  /// unsupported or no such tunnel is running.
  IrohTunnelStatus statusOf(String key) {
    if (!isSupported) return IrohTunnelStatus.down;
    final code = _b.withKey(key, _b.statusCode);
    if (code < 0 || code >= IrohTunnelStatus.values.length) {
      return IrohTunnelStatus.down;
    }
    return IrohTunnelStatus.values[code];
  }

  /// Connection path kind (direct vs relayed) of the tunnel for [key].
  /// [IrohPathKind.unknown] when unsupported, nothing is running, or no path
  /// is selected yet. A cheap pure read — safe to poll from the main isolate.
  IrohPathKind pathKindOf(String key) {
    if (!isSupported) return IrohPathKind.unknown;
    final code = _b.withKey(key, _b.pathKindCode);
    if (code < 0 || code >= IrohPathKind.values.length) {
      return IrohPathKind.unknown;
    }
    return IrohPathKind.values[code];
  }

  /// The loopback auth token of the tunnel for [key] (appended to loopback
  /// URLs as `__lt=<token>`), or null when unsupported or nothing is running.
  /// Other apps on the device can't use the proxy without it.
  String? localTokenOf(String key) =>
      isSupported ? _b.takeString(_b.withKey(key, _b.localTokenPtr)) : null;

  /// Notify every native tunnel that the device network changed, so iroh
  /// re-homes the relay and re-probes paths promptly (it can't self-detect
  /// this on Android). Cheap; safe to call when nothing is running.
  void networkChanged() {
    if (isSupported) _b.networkChanged();
  }

  /// Whether the running binary offers an in-place reconnect. Always true on
  /// an ABI v2 binary; kept as a query so callers read as before.
  bool get hasKick => isSupported;

  /// Force an in-place reconnect of the tunnel for [key] (same endpoint /
  /// port / token; the supervisor re-dials at once). No-op when unsupported
  /// or not running.
  void kick(String key) {
    if (isSupported) _b.withKey(key, _b.forceReconnect);
  }

  /// Swap the credential the tunnel for [key] dials with — a refreshed guest
  /// ticket, or a new pairing code for the same server — in place: same port,
  /// same token, nothing built against the tunnel goes stale. Applies at the
  /// next dial; a tunnel whose supervisor gave up on a rejected handshake
  /// re-dials immediately. Non-blocking. Throws [IrohTunnelException] when
  /// no such tunnel runs, the code is unparseable, or it names a different
  /// server or kind.
  void setCredential(String key, String code) {
    if (!isSupported) {
      throw IrohTunnelException(
          unsupportedReason ?? 'iroh tunnel is not supported on this device');
    }
    final k = key.toNativeUtf8();
    final c = code.toNativeUtf8();
    try {
      if (_b.setCredential(k, c) < 0) {
        throw IrohTunnelException(
            _b.takeLastError() ?? 'credential swap failed');
      }
    } finally {
      malloc.free(k);
      malloc.free(c);
    }
  }

  /// Native supervisor events of the tunnel for [key] since the last call,
  /// for the app log. Empty when unsupported or nothing happened.
  List<String> drainEvents(String key) {
    if (!isSupported) return const [];
    final s = _b.takeString(_b.withKey(key, _b.drainEventsPtr));
    if (s == null) return const [];
    return s.split('\n').where((l) => l.trim().isNotEmpty).toList();
  }

  /// Whether the tunnel for [key] has its home relay reachable, or null when
  /// unsupported or no such tunnel runs. Drives the reconnect watchdog: a
  /// reconnect failing WITH the relay up is worth a fresh endpoint; one
  /// failing without it is a dead zone the supervisor handles better.
  bool? relayOnlineOf(String key) {
    if (!isSupported) return null;
    final code = _b.withKey(key, _b.relayOnlineCode);
    return code < 0 ? null : code != 0;
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
// state the main isolate can later drive through its own handle.
int _startTunnelSync(String key, String code, int localPort) {
  final b = _Bindings.open();
  final k = key.toNativeUtf8();
  final c = code.toNativeUtf8();
  try {
    final port = b.start(k, c, localPort);
    if (port < 0) {
      throw IrohTunnelException(b.takeLastError() ?? 'unknown tunnel error');
    }
    return port;
  } finally {
    malloc.free(k);
    malloc.free(c);
  }
}
