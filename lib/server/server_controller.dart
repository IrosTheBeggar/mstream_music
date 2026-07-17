import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'server_binary_manager.dart';
import 'server_log.dart';

/// When the built-in mStream server is launched.
///
/// This is the single knob for the start trigger — change [kServerStartTrigger]
/// to move it. To defer the server until the user adds a local library folder,
/// set it to [firstLocalFolder] and call
/// `ServerController.instance.maybeStartFor(ServerStartTrigger.firstLocalFolder)`
/// from that flow (the existing `appStart` call in main() then becomes a no-op).
/// [manual] disables auto-start entirely (start it explicitly from the UI).
enum ServerStartTrigger { appStart, firstLocalFolder, manual }

/// THE knob: when does the built-in server boot? (See [ServerStartTrigger].)
const ServerStartTrigger kServerStartTrigger = ServerStartTrigger.appStart;

enum ServerRunPhase { stopped, preparing, starting, running, error }

@immutable
class ServerRunStatus {
  const ServerRunStatus(this.phase, {this.baseUrl, this.error});
  final ServerRunPhase phase;
  final String? baseUrl; // set while running
  final String? error;
}

/// Owns the lifecycle of the bundled mStream server process: ensure the binary
/// is present (via [ServerBinaryManager]), spawn it on loopback, wait for it to
/// answer, and tear it down. The server keeps running while the window is hidden
/// to the tray — only an explicit [stop] (app Quit) kills it.
///
/// First cut: spawns the binary with its defaults (it serves on :3000, binding
/// loopback) and points its data dir (save/) at a stable app-data folder via the
/// working directory. Port/config selection + first-run auto-auth are follow-ups.
class ServerController {
  ServerController._();
  static final ServerController instance = ServerController._();

  // Chosen at first run (prefers 3000, else a free loopback port) and persisted
  // in the server config; read back from the config on later runs so the URL
  // stays stable.
  int _port = 3000;
  int get port => _port;
  String get baseUrl => 'http://127.0.0.1:$_port';

  final ValueNotifier<ServerRunStatus> status =
      ValueNotifier<ServerRunStatus>(const ServerRunStatus(ServerRunPhase.stopped));

  Process? _process;
  // Pid of a pre-existing server we ADOPTED instead of spawning (a previous
  // app instance's child that outlived a force-kill or crash — only a graceful
  // Quit reaps the process tree). Tracked so stop() can still reap it.
  int? _adoptedPid;
  bool _starting = false;

  bool get isRunning => _process != null || _adoptedPid != null;

  void _log(String m) => debugPrint('[server-ctl] $m');
  void _set(ServerRunStatus s) => status.value = s;

  /// Start the server only if [trigger] matches the configured
  /// [kServerStartTrigger]. The call site for each trigger stays in place; this
  /// gate decides which one actually fires, so moving the trigger is a one-line
  /// change. No-op on platforms without a server binary.
  Future<void> maybeStartFor(ServerStartTrigger trigger) async {
    if (kServerStartTrigger != trigger) return;
    if (!ServerBinaryManager.instance.isSupported) return;
    await start();
  }

  /// Ensure the binary is present (downloading on first run), spawn it, and wait
  /// for it to answer. Safe to call repeatedly.
  Future<void> start() async {
    if (!ServerBinaryManager.instance.isSupported) return;
    if (isRunning || _starting) return;
    _starting = true;
    try {
      _set(const ServerRunStatus(ServerRunPhase.preparing));
      final dataDir = await _dataDir();
      // mStream resolves its storage dirs relative to the BINARY (appRoot), not
      // the working dir — so a db left there would be wiped when the binary
      // updates and the old version dir is pruned. Pass `-j <config>` with the
      // storage dirs redirected into the stable data folder; mStream fills in
      // the rest (secrets, iroh keys) and maintains the file from there.
      final (:configPath, :port) = await _ensureConfig(dataDir);
      _port = port;

      // A healthy mStream may already be serving our port: the child of a
      // previous app instance that was force-killed or crashed (only a
      // graceful Quit reaps the process tree). Spawning over it just crashes
      // the new child on the taken port — adopt it instead. Same config/data
      // dir, so it's equivalent; Quit still reaps it via the resolved pid.
      // Trade-offs: its console isn't piped into ServerLog, and the binary
      // auto-update check is skipped until a boot with no adoptable server.
      final existingPid = await _findExistingServer(port);
      if (existingPid != null) {
        _adoptedPid = existingPid > 0 ? existingPid : null;
        _set(ServerRunStatus(ServerRunPhase.running, baseUrl: baseUrl));
        _log('adopted running server at $baseUrl'
            '${_adoptedPid != null ? ' (pid $_adoptedPid)' : ' (pid unknown)'}');
        return;
      }

      final exe = await ServerBinaryManager.instance.ensureReady();
      if (exe == null) {
        _set(const ServerRunStatus(ServerRunPhase.error,
            error: 'server binary unavailable'));
        return;
      }

      _set(const ServerRunStatus(ServerRunPhase.starting));
      final proc = await Process.start(exe, ['-j', configPath],
          workingDirectory: dataDir.path);
      _process = proc;
      // Mirror the server's console into ServerLog (the Diagnostics "Server"
      // view) and the app console. debugPrint also tees into the app log buffer.
      proc.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((l) {
        ServerLog().add(l);
        debugPrint('[mstream] $l');
      });
      proc.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((l) {
        ServerLog().add(l);
        debugPrint('[mstream:err] $l');
      });
      unawaited(proc.exitCode.then(_onProcessExit));

      final ready = await _waitForHealth();
      if (!isRunning) return; // stopped while we were waiting
      _set(ready
          ? ServerRunStatus(ServerRunPhase.running, baseUrl: baseUrl)
          : const ServerRunStatus(ServerRunPhase.error,
              error: 'server did not become ready'));
      _log(ready ? 'running at $baseUrl' : 'health check timed out');
    } catch (e) {
      _log('start failed: $e');
      _set(ServerRunStatus(ServerRunPhase.error, error: '$e'));
    } finally {
      _starting = false;
    }
  }

  /// Stop the server (and its sidecar children). Called on app Quit. Reaps an
  /// adopted server too — it's this app's child from a previous run, so its
  /// lifecycle follows this instance once adopted.
  Future<void> stop() async {
    final pid = _process?.pid ?? _adoptedPid;
    _process = null;
    _adoptedPid = null;
    if (pid == null) return;
    _log('stopping (pid $pid)');
    await _killTree(pid);
    _set(const ServerRunStatus(ServerRunPhase.stopped));
  }

  /// A compatible mStream already answering on [port], or null. Returns its
  /// pid, or -1 when the process can't be resolved (adopted anyway — it just
  /// can't be reaped on Quit). Fingerprinted on the ping payload so a random
  /// non-mStream process squatting the port isn't adopted.
  Future<int?> _findExistingServer(int port) async {
    try {
      final r = await http
          .get(Uri.parse('http://127.0.0.1:$port/api/v1/ping'))
          .timeout(const Duration(seconds: 2));
      if (r.statusCode != 200 || !r.body.contains('"vpaths"')) return null;
    } catch (_) {
      return null; // nothing listening (or not answering like an mStream)
    }
    return await _listenerPid(port) ?? -1;
  }

  /// Owning pid of the LISTENING socket on [port] (netstat parse), so an
  /// adopted server can still be reaped on Quit. Null when unresolved.
  Future<int?> _listenerPid(int port) async {
    if (!Platform.isWindows) return null;
    try {
      final r = await Process.run('netstat', ['-ano', '-p', 'TCP']);
      for (final line in (r.stdout as String).split('\n')) {
        if (!line.contains('LISTENING') || !line.contains(':$port ')) continue;
        final pid = int.tryParse(line.trim().split(RegExp(r'\s+')).last);
        if (pid != null && pid > 0) return pid;
      }
    } catch (_) {}
    return null;
  }

  void _onProcessExit(int code) {
    // Unexpected exit (we null _process in stop(), so this only fires on a crash
    // or external kill).
    if (_process == null) return;
    _process = null;
    _log('server exited unexpectedly (code $code)');
    _set(ServerRunStatus(ServerRunPhase.error, error: 'server exited ($code)'));
  }

  Future<bool> _waitForHealth() async {
    final client = http.Client();
    try {
      // ~30s — the HTTP server comes up well before first-run ffmpeg fetch.
      for (var i = 0; i < 60; i++) {
        if (!isRunning) return false;
        try {
          final r = await client
              .get(Uri.parse('$baseUrl/'))
              .timeout(const Duration(seconds: 2));
          if (r.statusCode > 0) return true; // any response = listening
        } catch (_) {
          // connection refused / not up yet — retry
        }
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
    } finally {
      client.close();
    }
    return false;
  }

  Future<void> _killTree(int pid) async {
    try {
      if (Platform.isWindows) {
        // /T kills the process tree (mStream + its rust sidecars).
        await Process.run('taskkill', ['/PID', '$pid', '/T', '/F']);
      } else {
        Process.killPid(pid, ProcessSignal.sigterm);
      }
    } catch (e) {
      _log('kill failed: $e');
    }
  }

  /// First-run quick setup (desktop onboarding, Server Mode): write a music
  /// folder + the first user + the port into the server config, then (re)start
  /// the server on it. [passwordHash]/[salt] arrive pre-hashed in mStream's
  /// own scheme (see util/mstream_auth.dart) so the server accepts logins for
  /// them directly from the config file.
  Future<void> quickSetup({
    required String folderName,
    required String folderRoot,
    required String username,
    required String passwordHash,
    required String salt,
    required int port,
  }) async {
    await stop();
    final dataDir = await _dataDir();
    final confDir = Directory(p.join(dataDir.path, 'conf'));
    await confDir.create(recursive: true);
    final configFile = File(p.join(confDir.path, 'default.json'));
    Map<String, dynamic> cfg = <String, dynamic>{};
    if (await configFile.exists()) {
      try {
        cfg = jsonDecode(await configFile.readAsString())
            as Map<String, dynamic>;
      } catch (_) {/* corrupt — rebuilt below */}
    }
    cfg['port'] = port;
    final folders =
        (cfg['folders'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    folders[folderName] = {'root': folderRoot, 'type': 'music'};
    cfg['folders'] = folders;
    final users =
        (cfg['users'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    users[username] = {
      'password': passwordHash,
      'salt': salt,
      'admin': true,
      'vpaths': [folderName],
    };
    cfg['users'] = users;
    await configFile
        .writeAsString(const JsonEncoder.withIndent('  ').convert(cfg));
    _log('quick setup: folder "$folderName" + user "$username" (port $port)');
    await start();
  }

  /// Resolve the boot config + port. Seeds the config when needed with (a) the
  /// five appRoot-relative storage dirs redirected into [dataDir] (else they'd
  /// sit in the binary's version folder and be pruned on update) and (b) a chosen
  /// port. The port is reused from the existing config when present (stable URL
  /// across runs), otherwise picked fresh (preferring 3000) and persisted. mStream
  /// owns the file otherwise — secrets, iroh keys, library, settings live there.
  Future<({String configPath, int port})> _ensureConfig(Directory dataDir) async {
    final confDir = Directory(p.join(dataDir.path, 'conf'));
    await confDir.create(recursive: true);
    final configFile = File(p.join(confDir.path, 'default.json'));

    Map<String, dynamic> cfg = <String, dynamic>{};
    if (await configFile.exists()) {
      try {
        cfg = jsonDecode(await configFile.readAsString())
            as Map<String, dynamic>;
      } catch (_) {/* corrupt — reseed below */}
    }

    final saved = cfg['port'];
    final port = (saved is int && saved > 0) ? saved : await _pickPort();

    // Only write when we changed something the app owns, so mStream's own edits
    // (secrets, iroh, the rest) are preserved.
    if (cfg['port'] != port || cfg['storage'] == null) {
      cfg['port'] = port;
      cfg['storage'] = <String, String>{
        'albumArtDirectory': p.join(dataDir.path, 'image-cache'),
        'dbDirectory': p.join(dataDir.path, 'db'),
        'logsDirectory': p.join(dataDir.path, 'logs'),
        'syncConfigDirectory': p.join(dataDir.path, 'sync'),
        'waveformCacheDirectory': p.join(dataDir.path, 'waveform-cache'),
      };
      await configFile
          .writeAsString(const JsonEncoder.withIndent('  ').convert(cfg));
      _log('wrote config (port $port) at ${configFile.path}');
    }
    return (configPath: configFile.path, port: port);
  }

  /// A free loopback port, preferring 3000; falls back to an OS-assigned one.
  /// (Small TOCTOU window before mStream binds — acceptable for a local server.)
  Future<int> _pickPort() async {
    if (await _isPortFree(3000)) return 3000;
    final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = s.port;
    await s.close();
    _log('port 3000 in use; chose $port');
    return port;
  }

  Future<bool> _isPortFree(int port) async {
    try {
      final s = await ServerSocket.bind(InternetAddress.loopbackIPv4, port);
      await s.close();
      return true;
    } catch (_) {
      return false;
    }
  }

  Directory? _dataDirCache;
  Future<Directory> _dataDir() async {
    if (_dataDirCache != null) return _dataDirCache!;
    final support = await getApplicationSupportDirectory();
    final dir = Directory(p.join(support.path, 'mstream-server-data'));
    await dir.create(recursive: true);
    return _dataDirCache = dir;
  }
}
