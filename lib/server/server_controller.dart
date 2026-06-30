import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'server_binary_manager.dart';

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

  // mStream's default port. Assumed for now; a configurable port is a follow-up.
  static const int port = 3000;
  String get baseUrl => 'http://127.0.0.1:$port';

  final ValueNotifier<ServerRunStatus> status =
      ValueNotifier<ServerRunStatus>(const ServerRunStatus(ServerRunPhase.stopped));

  Process? _process;
  bool _starting = false;

  bool get isRunning => _process != null;

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
      final exe = await ServerBinaryManager.instance.ensureReady();
      if (exe == null) {
        _set(const ServerRunStatus(ServerRunPhase.error,
            error: 'server binary unavailable'));
        return;
      }

      _set(const ServerRunStatus(ServerRunPhase.starting));
      final dataDir = await _dataDir();
      // mStream resolves its storage dirs relative to the BINARY (appRoot), not
      // the working dir — so a db left there would be wiped when the binary
      // updates and the old version dir is pruned. Pass `-j <config>` with the
      // storage dirs redirected into the stable data folder; mStream fills in
      // the rest (secrets, iroh keys) and maintains the file from there.
      final configPath = await _ensureConfig(dataDir);
      final proc = await Process.start(exe, ['-j', configPath],
          workingDirectory: dataDir.path);
      _process = proc;
      proc.stdout
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((l) => debugPrint('[mstream] $l'));
      proc.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((l) => debugPrint('[mstream:err] $l'));
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

  /// Stop the server (and its sidecar children). Called on app Quit.
  Future<void> stop() async {
    final proc = _process;
    _process = null;
    if (proc == null) return;
    _log('stopping (pid ${proc.pid})');
    await _killTree(proc.pid);
    _set(const ServerRunStatus(ServerRunPhase.stopped));
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

  /// Write a boot config (first run only) that redirects mStream's five
  /// appRoot-relative storage dirs into [dataDir], then return its path for
  /// `-j`. Written only when absent so mStream owns it afterwards (it persists
  /// secrets, iroh keys, the library, and the user's settings there).
  Future<String> _ensureConfig(Directory dataDir) async {
    final confDir = Directory(p.join(dataDir.path, 'conf'));
    await confDir.create(recursive: true);
    final configFile = File(p.join(confDir.path, 'default.json'));
    if (!await configFile.exists()) {
      final cfg = <String, dynamic>{
        'storage': <String, String>{
          'albumArtDirectory': p.join(dataDir.path, 'image-cache'),
          'dbDirectory': p.join(dataDir.path, 'db'),
          'logsDirectory': p.join(dataDir.path, 'logs'),
          'syncConfigDirectory': p.join(dataDir.path, 'sync'),
          'waveformCacheDirectory': p.join(dataDir.path, 'waveform-cache'),
        },
      };
      await configFile
          .writeAsString(const JsonEncoder.withIndent('  ').convert(cfg));
      _log('seeded config at ${configFile.path}');
    }
    return configFile.path;
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
