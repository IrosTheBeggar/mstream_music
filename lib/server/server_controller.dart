import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';
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

/// Thrown by [ServerController.quickSetup] when the server already has users
/// configured — first-run setup can't run, but the caller can attach by
/// signing in with the existing credentials instead.
class ServerHasUsersException implements Exception {}

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
  bool _starting = false;

  bool get isRunning => _process != null;

  // Last-run log on disk (logs/server-run.log, truncated each start): the
  // server's console + this controller's decisions. The in-app log buffers die
  // with the process, so this is what makes a failed boot diagnosable after
  // the fact.
  File? _runLogFile;

  void _log(String m) {
    debugPrint('[server-ctl] $m');
    _logFile('[server-ctl] $m');
  }

  void _logFile(String line) {
    try {
      _runLogFile?.writeAsStringSync('$line\n', mode: FileMode.append);
    } catch (_) {/* diagnostics must never break the server flow */}
  }

  Future<void> _openRunLog(Directory dataDir) async {
    try {
      final dir = Directory(p.join(dataDir.path, 'logs'));
      await dir.create(recursive: true);
      final f = File(p.join(dir.path, 'server-run.log'));
      await f.writeAsString(''); // describes the LAST run only
      _runLogFile = f;
      _logFile('run started ${DateTime.now().toUtc().toIso8601String()}');
    } catch (e) {
      debugPrint('[server-ctl] run log unavailable: $e');
    }
  }

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
      await _openRunLog(dataDir);
      // mStream resolves its storage dirs relative to the BINARY (appRoot), not
      // the working dir — so a db left there would be wiped when the binary
      // updates and the old version dir is pruned. Pass `-j <config>` with the
      // storage dirs redirected into the stable data folder; mStream fills in
      // the rest (secrets, iroh keys) and maintains the file from there.
      final (:configPath, :port) = await _ensureConfig(dataDir);
      _port = port;

      // An mStream may already hold our port: a leftover child of a previous
      // app run, another live app instance's child, or someone else's install.
      // Spawning over any of them just crashes the new child on the taken
      // port, so sort out who it is first.
      final existingPid = await _findExistingServer(port);
      if (existingPid != null && existingPid > 0) {
        if (!await _isOurServerExe(existingPid)) {
          // A user's separate mStream install — never touch its lifecycle.
          _log('port $port held by a foreign mStream (pid $existingPid) — '
              'not touching it');
          _set(ServerRunStatus(ServerRunPhase.error,
              error: 'port $port is in use by another mStream server'));
          return;
        }
        if (await _isChildOfLiveApp(existingPid)) {
          // Another RUNNING app instance owns it. Use it without owning it —
          // killing it would yank the server out from under that instance,
          // and reaping it on our Quit would do the same later.
          _set(ServerRunStatus(ServerRunPhase.running, baseUrl: baseUrl));
          _log('sharing server (pid $existingPid) owned by another running '
              'app instance');
          return;
        }
        // Our own leftover with a DEAD parent. Do NOT adopt it: its
        // stdout/stderr still pipe to the dead parent, so its next console
        // write EPIPE-crashes it (observed: the fingerprint probe above is
        // often what kills it). Recycle instead — kill the tree and fall
        // through to spawn a fresh child with live pipes.
        _log('recycling leftover server (pid $existingPid) on port $port');
        await _killTree(existingPid);
        if (!await _waitPortFree(port)) {
          _set(ServerRunStatus(ServerRunPhase.error,
              error: 'port $port did not free up after stopping the old '
                  'server'));
          return;
        }
      } else if (existingPid == -1) {
        // An mStream answered but the listening pid can't be resolved —
        // usually a broken-pipe zombie that our own probe just killed. Give
        // the port a moment to free, then spawn; if it's still held, we can't
        // safely kill what we can't identify.
        if (!await _waitPortFree(port, tries: 8)) {
          _set(ServerRunStatus(ServerRunPhase.error,
              error: 'port $port is in use by an unidentifiable server'));
          return;
        }
      } else if (!await _isPortFree(port)) {
        // Held, but not by anything answering like an mStream.
        _log('port $port is in use by a non-mStream process — not starting');
        _set(ServerRunStatus(ServerRunPhase.error,
            error: 'port $port is already in use by another program'));
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
        _logFile(l);
      });
      proc.stderr
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen((l) {
        ServerLog().add(l);
        debugPrint('[mstream:err] $l');
        _logFile('[err] $l');
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

  /// Stop the server (and its sidecar children). Called on app Quit. Only
  /// kills a child THIS instance spawned — a server shared from another live
  /// app instance stays theirs.
  Future<void> stop() async {
    final pid = _process?.pid;
    _process = null;
    if (pid == null) return;
    _log('stopping (pid $pid)');
    await _killTree(pid);
    _set(const ServerRunStatus(ServerRunPhase.stopped));
  }

  /// A compatible mStream already answering on [port], or null. Returns its
  /// pid, or -1 when the process can't be resolved. Fingerprinted on the ping
  /// payload so a random process squatting the port isn't matched. Two mStream
  /// shapes exist: a user-less server answers 200 with `"vpaths"`, and a
  /// server WITH users answers the unauthenticated ping 401
  /// `{"error":"Authentication Error"}` — after first-run setup creates a
  /// user, the 401 shape is the one every leftover server presents.
  Future<int?> _findExistingServer(int port) async {
    try {
      final r = await http
          .get(Uri.parse('http://127.0.0.1:$port/api/v1/ping'))
          .timeout(const Duration(seconds: 2));
      final looksLikeMstream =
          (r.statusCode == 200 && r.body.contains('"vpaths"')) ||
              (r.statusCode == 401 && r.body.contains('Authentication Error'));
      if (!looksLikeMstream) return null;
    } catch (_) {
      return null; // nothing listening (or not answering like an mStream)
    }
    return await _listenerPid(port) ?? -1;
  }

  /// Owning pid of the LISTENING socket on [port] (netstat parse), so the
  /// recycle/share/foreign decision can identify the holder. Null when
  /// unresolved.
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
    final childPid = _process?.pid;
    try {
      // ~30s — the HTTP server comes up well before first-run ffmpeg fetch.
      for (var i = 0; i < 60; i++) {
        if (!isRunning) return false;
        try {
          final r = await client
              .get(Uri.parse('$baseUrl/'))
              .timeout(const Duration(seconds: 2));
          if (r.statusCode > 0) {
            // An answer alone isn't proof: a stale/foreign server could hold
            // the port while our child dies behind it (then sign-in fails
            // against a server running someone else's config). Require the
            // LISTENING socket to belong to the child we spawned.
            if (childPid == null) return true;
            if (await _listenerPid(_port) == childPid) return true;
          }
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

  /// First-run quick setup (desktop onboarding, Server Mode): make sure the
  /// server is running on [port], then create the music library + the first
  /// admin user THROUGH THE ADMIN API. Writing them into the config file does
  /// NOT work on an existing install — mStream ingests config users/folders
  /// into SQLite exactly once (a marker file gates the migration), so config
  /// entries added later are silently ignored and sign-in 401s. The API path
  /// works on both a virgin server (no users → API is open) and is the same
  /// mechanism the webapp admin panel uses. `PUT /api/v1/admin/directory`
  /// also kicks off the library scan.
  ///
  /// Throws [ServerHasUsersException] when the server already has users — the
  /// caller decides whether to attach with existing credentials instead.
  Future<void> quickSetup({
    required String folderName,
    required String folderRoot,
    required String username,
    required String password,
    required int port,
  }) async {
    // Make sure the server is up on the requested port. Common path: it's
    // already running there (booted with the app) — reuse it. A different
    // port means a config write + restart.
    if (!isRunning || status.value.phase != ServerRunPhase.running) {
      await start();
    }
    if (status.value.phase != ServerRunPhase.running) {
      throw Exception(status.value.error ?? 'the server did not start');
    }
    if (_port != port) {
      await stop();
      await _freePortForTakeover(port);
      await _writeConfigPort(port);
      await start();
      if (status.value.phase != ServerRunPhase.running) {
        throw Exception(status.value.error ?? 'the server did not start');
      }
    }

    // No-users servers answer the unauthenticated ping 200 (public mode);
    // configured ones answer 401. Decides between first-run setup and attach.
    final ping = await http
        .get(Uri.parse('$baseUrl/api/v1/ping'))
        .timeout(const Duration(seconds: 5));
    if (ping.statusCode != 200) {
      throw ServerHasUsersException();
    }

    _log('quick setup: adding library "$folderName" -> $folderRoot');
    final dirResp = await http
        .put(
          Uri.parse('$baseUrl/api/v1/admin/directory'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'directory': folderRoot,
            'vpath': folderName,
            'autoAccess': false,
          }),
        )
        .timeout(const Duration(seconds: 10));
    if (dirResp.statusCode != 200) {
      throw Exception(
          'adding the music folder failed (HTTP ${dirResp.statusCode})');
    }

    _log('quick setup: creating admin user "$username"');
    final userResp = await http
        .put(
          Uri.parse('$baseUrl/api/v1/admin/users'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'username': username,
            'password': password,
            'vpaths': [folderName],
            'admin': true,
          }),
        )
        .timeout(const Duration(seconds: 10));
    if (userResp.statusCode != 200) {
      throw Exception(
          'creating your login failed (HTTP ${userResp.statusCode})');
    }
  }

  /// Persist [port] into the server config (mStream owns the rest of the
  /// file; see [_ensureConfig] for why storage/port are the app's keys).
  Future<void> _writeConfigPort(int port) async {
    final dataDir = await _dataDir();
    final confDir = Directory(p.join(dataDir.path, 'conf'));
    await confDir.create(recursive: true);
    final configFile = File(p.join(confDir.path, 'default.json'));
    Map<String, dynamic> cfg = <String, dynamic>{};
    if (await configFile.exists()) {
      try {
        cfg = jsonDecode(await configFile.readAsString())
            as Map<String, dynamic>;
      } catch (_) {/* corrupt — reseeded by _ensureConfig on start */}
    }
    cfg['port'] = port;
    await configFile
        .writeAsString(const JsonEncoder.withIndent('  ').convert(cfg));
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

  /// Ensure [port] is free before a takeover start: kill-tree a leftover of
  /// OUR bundled server when one holds it (waiting for the socket to release),
  /// and fail fast when a foreign process does — killing someone else's server
  /// is never on the table.
  Future<void> _freePortForTakeover(int port) async {
    if (await _isPortFree(port)) return;
    final pid = await _listenerPid(port);
    if (pid == null || !await _isOurServerExe(pid)) {
      throw Exception(
          'port $port is in use by another program — choose a different port');
    }
    _log('reaping leftover server (pid $pid) to free port $port');
    await _killTree(pid);
    if (!await _waitPortFree(port)) {
      throw Exception(
          'port $port did not free up after stopping the old server');
    }
  }

  /// Poll until [port] is bindable (250ms x [tries]); true when it freed.
  Future<bool> _waitPortFree(int port, {int tries = 20}) async {
    for (var i = 0; i < tries; i++) {
      if (await _isPortFree(port)) return true;
      await Future<void>.delayed(const Duration(milliseconds: 250));
    }
    return false;
  }

  /// Whether [pid]'s parent process is a LIVE instance of this app — i.e. the
  /// server belongs to another running copy of mstream_music, not to a dead
  /// run. One PowerShell CIM query; only reached on the rare
  /// port-already-held boot path.
  Future<bool> _isChildOfLiveApp(int pid) async {
    if (!Platform.isWindows) return false;
    try {
      final r = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        "\$p = (Get-CimInstance Win32_Process -Filter 'ProcessId=$pid')"
            ".ParentProcessId; "
            "(Get-Process -Id \$p -ErrorAction SilentlyContinue).ProcessName",
      ]);
      return (r.stdout as String).trim().toLowerCase() == 'mstream_music';
    } catch (_) {
      return false;
    }
  }

  /// Whether [pid] runs one of OUR managed server binaries (exe path under the
  /// binary manager's install root). Gates recycling and takeover reaping —
  /// a user's separate mStream install must never be killed.
  Future<bool> _isOurServerExe(int pid) async {
    final exe = _exeOfPid(pid);
    if (exe == null) return false;
    final root = await ServerBinaryManager.instance.installRootPath();
    return p.isWithin(root, exe);
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
    // netstat's LISTENING table is the truth; bind probes lie on Windows in
    // two ways (both observed with a python http.server squatting 3000): a
    // loopback probe coexists with another process's wildcard socket, and any
    // probe binds "successfully" over an SO_REUSEADDR listener. The spawned
    // child then EADDRINUSE-crashes on a port we called free.
    if (await _listenerPid(port) != null) return false;
    try {
      // netstat unavailable/unparsable → fall back to a wildcard bind probe.
      final s = await ServerSocket.bind(InternetAddress.anyIPv4, port);
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

// ── pid → executable path (Windows) ──

typedef _OpenProcessC = IntPtr Function(Uint32, Int32, Uint32);
typedef _OpenProcessD = int Function(int, int, int);
typedef _CloseHandleC = Int32 Function(IntPtr);
typedef _CloseHandleD = int Function(int);
typedef _QueryImageNameC = Int32 Function(
    IntPtr, Uint32, Pointer<Utf16>, Pointer<Uint32>);
typedef _QueryImageNameD = int Function(
    int, int, Pointer<Utf16>, Pointer<Uint32>);

/// Full executable path of [pid] via kernel32 (OpenProcess +
/// QueryFullProcessImageNameW), or null when it can't be resolved (process
/// gone, access denied, non-Windows). No subprocess — cheap enough for the
/// recycle/takeover paths.
String? _exeOfPid(int pid) {
  if (!Platform.isWindows) return null;
  try {
    final k32 = DynamicLibrary.open('kernel32.dll');
    final openProcess =
        k32.lookupFunction<_OpenProcessC, _OpenProcessD>('OpenProcess');
    final closeHandle =
        k32.lookupFunction<_CloseHandleC, _CloseHandleD>('CloseHandle');
    final queryName = k32.lookupFunction<_QueryImageNameC, _QueryImageNameD>(
        'QueryFullProcessImageNameW');
    const processQueryLimitedInformation = 0x1000;
    final handle = openProcess(processQueryLimitedInformation, 0, pid);
    if (handle == 0) return null;
    final buf = malloc<Uint16>(1024);
    final len = malloc<Uint32>(1)..value = 1024;
    try {
      final ok = queryName(handle, 0, buf.cast<Utf16>(), len);
      if (ok == 0) return null;
      return buf.cast<Utf16>().toDartString(length: len.value);
    } finally {
      malloc.free(buf);
      malloc.free(len);
      closeHandle(handle);
    }
  } catch (_) {
    return null;
  }
}
