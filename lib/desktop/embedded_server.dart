import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../singletons/log_manager.dart';

/// SPIKE: manages the bundled mStream server that ships next to the desktop app
/// (windows/sidecar/ -> the app's `server/` dir). It spawns the server into a
/// per-user writable data dir (the install dir may be read-only), waits for
/// /api/v1/ping, and tears it (and its worker children) down on quit.
///
/// The port is FIXED (not ephemeral) so the server has a predictable URL — some
/// users will run this as a normal mStream server and expect a stable address.
/// If the port is already in use the server does NOT start: [startupError] is
/// set so the UI can warn the user, rather than silently moving to another port
/// and changing the URL out from under them.
///
/// Public/no-auth on loopback: the generated config carries no `users` key, so
/// the API needs no token. `address:127.0.0.1` keeps it off the network.
class EmbeddedServer {
  EmbeddedServer._();
  static final EmbeddedServer instance = EmbeddedServer._();

  /// Fixed loopback port for the bundled server (mStream's traditional default).
  static const int port = 3000;

  Process? _proc;

  /// Set when [start] fails (port in use, binary missing, no response); null on
  /// success. The UI reads this to warn the user.
  String? startupError;

  bool get isRunning => _proc != null;

  /// Spawn the server on [port]. On failure, sets [startupError] and throws.
  Future<void> start() async {
    if (_proc != null) return;
    startupError = null;
    final exe = _serverExe();
    if (!File(exe).existsSync()) {
      _fail('The bundled mStream server was not found at $exe.');
    }
    if (!await _isPortAvailable(port)) {
      _fail('Port $port is already in use, so the built-in mStream server '
          "couldn't start. Something else is using port $port — likely another "
          'copy of mStream or another program. Close it and reopen the app.');
    }
    final dataDir = await _dataDir();
    final configPath = await _writeConfig(dataDir, port);
    appLog('[embedded] launching $exe  port=$port  data=$dataDir');
    final proc = await Process.start(
      exe,
      ['-j', configPath],
      workingDirectory: p.dirname(exe),
      runInShell: false,
    );
    _proc = proc;
    proc.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((l) => appLog('[server] $l'));
    proc.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((l) => appLog('[server!] $l'));
    unawaited(proc.exitCode.then((code) {
      appLog('[embedded] server process exited ($code)');
      if (identical(_proc, proc)) _proc = null;
    }));
    try {
      await _awaitReady(port);
    } catch (_) {
      _fail('The built-in mStream server did not respond on port $port.');
    }
  }

  /// Kill the server and its worker children. Safe to call repeatedly / when
  /// already stopped.
  void stop() {
    final proc = _proc;
    if (proc == null) return;
    _proc = null;
    appLog('[embedded] stopping server pid=${proc.pid}');
    if (Platform.isWindows) {
      // The Bun server self-dispatches worker children (scanner, etc.); /T kills
      // the whole tree so no orphan keeps the port.
      Process.run('taskkill', ['/F', '/T', '/PID', '${proc.pid}']);
    } else {
      proc.kill(ProcessSignal.sigterm);
    }
  }

  Never _fail(String message) {
    startupError = message;
    appLog('[embedded] $message');
    throw StateError(message);
  }

  String _serverExe() {
    final dir = p.dirname(Platform.resolvedExecutable);
    final name = Platform.isWindows ? 'mStream.exe' : 'mStream';
    return p.join(dir, 'server', name);
  }

  /// True if [port] is free. We probe by trying to CONNECT, not bind: a bind
  /// probe is unreliable on Windows — the OS often lets a second bind succeed
  /// even when another process is already listening, which would miss the
  /// conflict and silently start a second server. A successful connect means
  /// something is already answering on the port, so it's taken.
  Future<bool> _isPortAvailable(int port) async {
    try {
      final s = await Socket.connect(InternetAddress.loopbackIPv4, port,
          timeout: const Duration(seconds: 1));
      s.destroy();
      return false; // something answered -> in use
    } on SocketException {
      return true; // connection refused / timed out -> nothing listening
    }
  }

  Future<String> _dataDir() async {
    final base = await getApplicationSupportDirectory();
    final dir = Directory(p.join(base.path, 'embedded-server'));
    if (!dir.existsSync()) dir.createSync(recursive: true);
    return dir.path;
  }

  Future<String> _writeConfig(String dataDir, int port) async {
    String sub(String name) => p.join(dataDir, name);
    // Override every writable path so nothing lands next to the (read-only)
    // binary. setup() mkdir's each of these. No `users` key -> public mode.
    final config = <String, dynamic>{
      'port': port,
      'address': '127.0.0.1',
      'storage': {
        'albumArtDirectory': sub('album-art'),
        'dbDirectory': sub('db'),
        'logsDirectory': sub('logs'),
        'syncConfigDirectory': sub('sync'),
        'waveformCacheDirectory': sub('waveform'),
      },
      'transcode': {'ffmpegDirectory': sub('ffmpeg')},
    };
    final f = File(p.join(dataDir, 'config.json'));
    await f.writeAsString(jsonEncode(config));
    return f.path;
  }

  Future<void> _awaitReady(int port,
      {Duration timeout = const Duration(seconds: 40)}) async {
    final uri = Uri.parse('http://127.0.0.1:$port/api/v1/ping');
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      try {
        final r = await http.get(uri).timeout(const Duration(seconds: 2));
        if (r.statusCode == 200) {
          appLog('[embedded] server ready on $port');
          return;
        }
      } catch (_) {}
      await Future.delayed(const Duration(milliseconds: 300));
    }
    throw TimeoutException('embedded server did not become ready on $port');
  }
}
