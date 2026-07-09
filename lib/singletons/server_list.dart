import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:mstream_music/singletons/file_explorer.dart';

import '../objects/server.dart';
import './app_messenger.dart';
import './browser_list.dart';
import './log_manager.dart';
import '../build_variant.dart';
import '../util/insecure_tls_channel.dart';
import '../native/iroh_tunnel.dart';
import '../media/cast_target.dart';
import 'cast_manager.dart';
import './media.dart';
import './queue_store.dart';

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:rxdart/rxdart.dart';
import 'package:http/http.dart' as http;

class ServerManager {
  final List<Server> serverList = [];
  Server? currentServer;

  // The pairing code of the server the (single) iroh tunnel is currently up for,
  // or null when no tunnel is running. Drives (re)start decisions in
  // [ensureActiveTunnel]; the shim holds one tunnel at a time, for the active server.
  String? _activeTunnelCode;

  // streams
  late final BehaviorSubject<List<Server>> _serverListStream =
      BehaviorSubject<List<Server>>.seeded(serverList);
  late final BehaviorSubject<Server?> _currentServerStream =
      BehaviorSubject<Server?>.seeded(currentServer);

  ServerManager._privateConstructor();
  static final ServerManager _instance = ServerManager._privateConstructor();

  factory ServerManager() {
    return _instance;
  }

  Future<File> get _serverFile async {
    final directory = await getApplicationDocumentsDirectory();
    final path = directory.path;
    return File('$path/servers.json');
  }

  // Serializes writes through a single chain so overlapping truncate+writes
  // can't corrupt servers.json — notably the parallel getServerPaths() pings
  // fired at startup (loadServerList), which can each trigger a
  // capability-change write at the same moment.
  Future<void> _writeChain = Future.value();

  Future<void> writeServerFile() {
    final write = _writeChain.then((_) async {
      final file = await _serverFile;
      await file.writeAsString(jsonEncode(serverList));
    });
    // The baton swallows errors so one failed write can't block later writes;
    // the caller still sees this write's own error via [write].
    _writeChain = write.catchError((_) {});
    return write;
  }

  Future<List> readServerManager() async {
    try {
      final file = await _serverFile;

      // Read the file
      String contents = await file.readAsString();
      return jsonDecode(contents);
    } catch (e) {
      // If we encounter an error, return 0
      return [];
    }
  }

  // Memoizes loadServerList so it runs exactly once across the UI startup path
  // (MStreamApp.initState) and the headless Android Auto browser (AutoBrowse) —
  // loadServerList appends without clearing, so a second concurrent call would
  // duplicate every server.
  Future<void>? _loadOnce;
  Future<void> ensureLoaded() => _loadOnce ??= loadServerList();

  Future<void> loadServerList() async {
    List serversJson = await readServerManager();

    for (var s in serversJson) {
      try {
        serverList.add(Server.fromJson(s));
      } catch (e) {
        // Skip a corrupt entry instead of failing to load every server
        // that comes after it in the file.
      }
    }

    _serverListStream.sink.add(serverList);
    syncInsecureTls();

    if (serverList.isNotEmpty) {
      currentServer = serverList[0];
      // Bring up the tunnel for an iroh default server BEFORE the browser queries
      // it.
      await ensureActiveTunnel();
      // Pre-warm the saved queue's iroh server (if it's a DIFFERENT server) in the
      // BACKGROUND — without selecting it — so the queue restores against a live
      // tunnel instead of a dead loopback port. The default stays selected; this
      // just points the playback tunnel ahead of QueueStore.init (main.dart gates
      // that on loadServerList completing). Bounded by awaitTunnelReady's cap.
      final resumeName = await QueueStore().peekResumeServer();
      if (resumeName != null && resumeName != currentServer?.localname) {
        final rs = byLocalname(resumeName);
        if (rs != null && rs.isIroh) {
          setQueueIrohServer(rs);
          await awaitTunnelReady(server: rs);
        }
      }
      BrowserManager().goToNavScreen();
      _currentServerStream.sink.add(currentServer);
      for (var s in serverList) {
        getServerPaths(s);
      }
    } else {
      BrowserManager().noServerScreen();
    }
  }


  /// True when an iroh server is already configured. Only one is supported (a
  /// single native tunnel), so the add-server flow gates a second one.
  bool get hasIrohServer => serverList.any((s) => s.isIroh);

  Future<void> addServer(Server newServer) async {
    // One iroh server max (single tunnel). The add-server UI blocks this; this is
    // the code-level backstop so no other path can add a second.
    if (newServer.isIroh && hasIrohServer) {
      showGlobalSnack('Only one iroh server is supported.');
      return;
    }
    serverList.add(newServer);

    if (currentServer == null) {
      currentServer = newServer;
      _currentServerStream.sink.add(currentServer);
      BrowserManager().goToNavScreen();
    }

    // Create server directory (for downloads)
    Directory? file = await FileExplorer()
        .getDownloadDir(newServer.storageMode, newServer.storageBasePath);
    if (file != null) {
      try {
        String dir = path.join(file.path, "media/${newServer.localname}");
        await Directory(dir).create(recursive: true);
      } catch (e) {
        // A permanent/SD path can fail to create (unmounted, read-only).
        // Don't let that abort the save below and lose the server entirely.
        showGlobalSnack(
            'Saved, but the download folder could not be created — storage '
            'may be unavailable.');
      }
    }

    await writeServerFile();

    _serverListStream.sink.add(serverList);
    syncInsecureTls();
  }

  // Storage mode + base path are set directly on the Server in the
  // add-server form (like localname is), so they aren't part of this
  // signature — callAfterEditServer() persists whatever was set.
  Future<void> editServer(int serverIndex, String url, String? username,
      String? password) async {
    serverList[serverIndex].url = url;
    ServerManager().serverList[serverIndex].password = password;
    ServerManager().serverList[serverIndex].username = username;

    await callAfterEditServer();
  }

  Future<void> changeCurrentServer(int currentServerIndex) async {
    currentServer = serverList[currentServerIndex];
    _currentServerStream.sink.add(currentServer);
    // Bring the tunnel up for the newly-active iroh server (or tear it down when
    // switching to HTTP) before the browser queries it.
    await ensureActiveTunnel();
    BrowserManager().goToNavScreen();
    unawaited(getServerPaths(currentServer!));
  }

  Future<void> getServerPaths(Server server, {bool throwErr = false}) async {
    // An iroh server can only be pinged through its live tunnel; skip when the
    // tunnel isn't up (e.g. a non-active iroh server at startup).
    if (server.isIroh && server.tunnelPort == null) {
      if (throwErr) throw Exception('iroh tunnel not connected');
      return;
    }
    try {
      var response = await http
          .get(server.apiUri('/api/v1/ping'),
              headers: {
        'Content-Type': 'application/json',
        'x-access-token': server.jwt ?? ''
      }).timeout(Duration(seconds: 5));

      if (response.statusCode != 200) {
        throw Exception('Failed to connect to server');
      }

      var res = jsonDecode(response.body);

      Set<String> pathCompare = {};
      final vpaths = res['vpaths'];
      if (vpaths is List) {
        for (final raw in vpaths) {
          if (raw is! String) continue; // tolerate unexpected element shapes
          pathCompare.add(raw);
          // add new keys
          if (!server.autoDJPaths.containsKey(raw)) {
            server.autoDJPaths[raw] = true;
          }
        }
      }

      // Remove outdated entries
      server.autoDJPaths
          .removeWhere((key, value) => !pathCompare.contains(key));

      // Make sure all entries are not false
      bool falseFlag = true;
      server.autoDJPaths.forEach((key, value) {
        if (value == true) {
          falseFlag = false;
        }
      });
      if (falseFlag == true) {
        server.autoDJPaths.forEach((key, value) {
          server.autoDJPaths[key] = true;
        });
      }

      // Update Playlists. Accept both the bare-name form (["A", "B"]) and the
      // object form ([{"name": "A"}, ...]) that some builds (e.g. Velvet) return.
      server.playlists.clear();
      final pls = res['playlists'];
      if (pls is List) {
        for (final raw in pls) {
          final name = raw is String ? raw : (raw is Map ? raw['name'] : null);
          if (name is String && name.isNotEmpty) server.playlists.add(name);
        }
      }

      // Transcoding capability (mStream/Velvet /api/v1/ping): `transcode` is
      // false when the server has no working ffmpeg, otherwise
      // { defaultCodec, defaultBitrate } — the values /transcode falls back to
      // when we omit the codec/bitrate params.
      final bool? prevAvail = server.transcodeAvailable;
      final String? prevCodec = server.transcodeDefaultCodec;
      final String? prevBitrate = server.transcodeDefaultBitrate;
      final transcodeInfo = res['transcode'];
      if (transcodeInfo is Map) {
        server.transcodeAvailable = true;
        // Coerce defensively: a fork may return these as objects/numbers rather
        // than strings. A shape mismatch must never throw here — it would surface
        // as a bogus "failed to connect" on a server that actually responded 200.
        final codec = transcodeInfo['defaultCodec'];
        final bitrate = transcodeInfo['defaultBitrate'];
        server.transcodeDefaultCodec = codec is String ? codec : null;
        server.transcodeDefaultBitrate = bitrate is String ? bitrate : null;
      } else {
        server.transcodeAvailable = false;
        server.transcodeDefaultCodec = null;
        server.transcodeDefaultBitrate = null;
      }
      // Persist the capability so the NEXT launch knows it before the queue is
      // restored — otherwise restore races the ping and bakes in /media URLs.
      if (server.transcodeAvailable != prevAvail ||
          server.transcodeDefaultCodec != prevCodec ||
          server.transcodeDefaultBitrate != prevBitrate) {
        unawaited(writeServerFile());
      }
    } catch (err) {
      if (throwErr) {
        rethrow;
      }
    }
  }

  /// Bring the single iroh tunnel in line with the active server: start it for an
  /// iroh [currentServer] (recording the live port on the server), restart it
  /// when switching to a different iroh server, or tear it down when the active
  /// server is HTTP/none. Idempotent; await before anything uses the server.
  // Serializes tunnel (re)starts so app-resume / connectivity / server-switch
  // can't race the single tunnel's start/stop (mirrors the cast _switchChain).
  Future<void> _tunnelChain = Future.value();

  // With the one-iroh-server cap, the tunnel "follows the queue": it's up when
  // the iroh server is the browsed server OR its songs are in the play queue.
  // This holds the iroh server the queue currently references (pushed by the
  // audio handler on queue changes); null when no queued song is from it.
  Server? _queueIrohServer;

  /// Record the iroh server the play queue references ([s]), or null when no
  /// queued song is from an iroh server. No-op when unchanged; otherwise
  /// re-evaluates the tunnel target. Called by the audio handler on queue changes.
  void setQueueIrohServer(Server? s) {
    final next = (s != null && s.isIroh) ? s : null;
    if (next?.localname == _queueIrohServer?.localname) return;
    _queueIrohServer = next;
    unawaited(ensureActiveTunnel());
  }

  // Which iroh server the single tunnel should serve: the browsed server when it
  // IS the iroh server, OR the iroh server whose songs are queued. Null → no
  // tunnel. (One-iroh-server cap, so these resolve to the same server when both
  // apply — there's never a second iroh server to contend for the tunnel.)
  Server? _tunnelTargetServer() {
    final c = currentServer;
    if (c != null && c.isIroh) return c;
    final q = _queueIrohServer;
    return (q != null && q.isIroh) ? q : null;
  }

  /// True when the tunnel currently has a server to serve (the browsed iroh server
  /// OR a background playback server). Drives the status banner — which must show
  /// for a background tunnel even while a non-iroh default is the selected server.
  bool get tunnelActive => _tunnelTargetServer() != null;

  /// True when the single tunnel is currently assigned to [s] (regardless of its
  /// connection state) — i.e. [s] is the server we last (re)started it for.
  bool tunnelAssignedTo(Server s) =>
      s.isIroh && _activeTunnelCode != null && s.irohPairingCode == _activeTunnelCode;

  /// True when the tunnel is assigned to [s] AND reports connected — i.e. [s]'s
  /// loopback is live right now.
  bool tunnelServes(Server s) =>
      tunnelAssignedTo(s) && IrohTunnel.instance.status == IrohTunnelStatus.connected;

  /// Bring the single iroh tunnel in line with the active server. With [verify],
  /// also force a rebuild when the native tunnel is fully *down* despite our
  /// bookkeeping (the shim's supervisor self-heals transient drops, so this only
  /// fires for a hard-down tunnel). Serialized against concurrent callers.
  Future<void> ensureActiveTunnel({bool verify = false}) {
    final next = _tunnelChain.then((_) => _ensureActiveTunnel(verify));
    _tunnelChain = next.catchError((_) {});
    return next;
  }

  Future<void> _ensureActiveTunnel(bool verify) async {
    if (!IrohTunnel.isSupported) return;
    final s = _tunnelTargetServer();
    if (s != null && s.isIroh && s.irohPairingCode != null) {
      // NB: don't drop an active cast here at the top. A renderer reaches an iroh
      // server through the LAN proxy (LocalMediaServer), so casting iroh is
      // supported, and a no-op ensure (healthy tunnel → early return below) must
      // leave the cast alone — otherwise every app-resume/network-change would
      // kick playback back to the phone. A real same-server rebuild (new loopback
      // port) is handled by rebuildTranscodeUrls below, which reloads the active
      // backend (cast included) onto the fresh tunnel. The only case that DOES
      // fall back to the phone — switching to a *different* iroh server, which
      // tears the single tunnel out from under the current queue — is handled at
      // the stop below.
      _startStatusPolling();
      if (_activeTunnelCode == s.irohPairingCode && s.tunnelPort != null) {
        // Already wired up. The supervisor handles transient drops itself; only
        // rebuild on a verify when it's fully down (a reconnecting/rejected
        // tunnel is left alone — restarting wouldn't help).
        if (!verify || IrohTunnel.instance.status != IrohTunnelStatus.down) {
          return;
        }
      }
      // The shim holds one tunnel; switching servers (or rebuilding a dead one)
      // requires dropping the old one first (start() returns the stale port otherwise).
      if (_activeTunnelCode != null) {
        // Switching to a DIFFERENT iroh server tears down the only tunnel, so the
        // current queue (which belongs to the outgoing server) can no longer be
        // reached by a renderer — fall back to on-device playback. A same-server
        // rebuild keeps the queue valid (the cast reloads via rebuildTranscodeUrls
        // below), so it must NOT drop.
        if (_activeTunnelCode != s.irohPairingCode && CastManager().isCasting) {
          unawaited(CastManager().selectTarget(CastTarget.local));
        }
        IrohTunnel.instance.stop();
        _activeTunnelCode = null;
      }
      _tunnelStarting = true;
      _refreshTunnelStatus(); // surface "Connecting…" while the dial runs
      try {
        final port = await IrohTunnel.instance.start(s.irohPairingCode!);
        s.tunnelPort = port;
        s.tunnelToken = IrohTunnel.instance.localToken;
        _activeTunnelCode = s.irohPairingCode;
        // This bind set a loopback port + token. Any queued iroh stream URL built
        // before now is stale, so rebuild them off the live effectiveBaseUrl.
        // Unconditional on purpose: besides a port that changed on a reconnect /
        // re-pair / server switch, the queue can also be restored at launch
        // BEFORE the tunnel is up (a slow or failed first connect bakes
        // http://127.0.0.1:0 with no token), and the retry that finally connects
        // has no prior port — so a "changed-only" guard would skip exactly the
        // case that strands the saved queue. Only an actual (re)start reaches here
        // (the already-wired-up fast path returned above), and the rebuild no-ops
        // when no URL actually changed. auto:true → skipped while casting: the
        // cast backends re-resolve each track against the live tunnel at load
        // time (irohProxyUri), and a mid-session reload clobbers the Cast SDK's
        // own suspend/resume recovery.
        unawaited(MediaManager()
            .audioHandler
            .customAction('rebuildTranscodeUrls',
                const {'upcomingOnly': false, 'auto': true})
            .catchError((Object e) {
          // A concurrent serialized load (restore, re-seed) can interrupt this
          // reload ("Loading interrupted") — benign, the newer load already
          // carries the fresh tunnel URLs; just don't let it hit the zone.
          appLog('[iroh] auto URL rebuild after tunnel bind failed: $e');
        }));
      } catch (e) {
        s.tunnelPort = null;
        s.tunnelToken = null;
        _activeTunnelCode = null;
        // Leave it down; requests fail fast via effectiveBaseUrl until retried.
        appLog('[iroh] tunnel start failed: $e');
      } finally {
        _tunnelStarting = false;
      }
      _refreshTunnelStatus();
    } else if (_activeTunnelCode != null) {
      IrohTunnel.instance.stop();
      _activeTunnelCode = null;
      _stopStatusPolling();
    } else {
      _stopStatusPolling();
    }
  }

  /// React to a device network change / app resume: nudge iroh to re-probe paths
  /// (it can't self-detect on Android) and rebuild the tunnel if it's hard-down.
  /// Cheap and safe when the active server isn't iroh.
  Future<void> handleNetworkChange() async {
    // Nudge whichever server the tunnel serves (a background playback server, not
    // just the browsed one) so a Wi-Fi/cellular switch re-probes the live tunnel.
    if (!IrohTunnel.isSupported || _tunnelTargetServer() == null) return;
    IrohTunnel.instance.networkChanged();
    await ensureActiveTunnel(verify: true);
  }

  // ── iroh tunnel status (drives the reconnecting / re-pair banner) ──
  // The native status is a poll (no push from the Rust supervisor), so we sample
  // it on a light timer while an iroh server is active and emit only on change.
  final BehaviorSubject<IrohTunnelStatus> _tunnelStatus =
      BehaviorSubject.seeded(IrohTunnelStatus.down);
  Stream<IrohTunnelStatus> get tunnelStatusStream => _tunnelStatus.stream;
  IrohTunnelStatus get tunnelStatus => _tunnelStatus.value;
  // Direct-vs-relay path of the active iroh tunnel, sampled on the same poll.
  final BehaviorSubject<IrohPathKind> _pathKind =
      BehaviorSubject.seeded(IrohPathKind.unknown);
  Stream<IrohPathKind> get pathKindStream => _pathKind.stream;
  IrohPathKind get pathKind => _pathKind.value;
  Timer? _statusPoll;
  // True while IrohTunnel.start() is dialing. The native tunnel isn't stored until
  // the dial returns (so native status reads "down"); surface "connecting" instead.
  bool _tunnelStarting = false;

  void _refreshTunnelStatus() {
    // Status reflects the tunnel's target (which may be a background playback
    // server, not the browsed one).
    final isIroh = IrohTunnel.isSupported && _tunnelTargetServer() != null;
    final IrohTunnelStatus st;
    if (!isIroh) {
      st = IrohTunnelStatus.down;
    } else if (_tunnelStarting) {
      st = IrohTunnelStatus.connecting;
    } else {
      st = IrohTunnel.instance.status;
    }
    if (st != _tunnelStatus.value) _tunnelStatus.add(st);
    final pk = (isIroh && !_tunnelStarting)
        ? IrohTunnel.instance.pathKind
        : IrohPathKind.unknown;
    if (pk != _pathKind.value) _pathKind.add(pk);
  }

  void _startStatusPolling() {
    _statusPoll ??= Timer.periodic(const Duration(seconds: 2), (_) {
      _refreshTunnelStatus();
      if (_tunnelTargetServer() == null) _stopStatusPolling();
    });
    _refreshTunnelStatus();
  }

  void _stopStatusPolling() {
    _statusPoll?.cancel();
    _statusPoll = null;
    if (_tunnelStatus.value != IrohTunnelStatus.down) {
      _tunnelStatus.add(IrohTunnelStatus.down);
    }
    if (_pathKind.value != IrohPathKind.unknown) {
      _pathKind.add(IrohPathKind.unknown);
    }
  }

  /// Wait (bounded) for the active iroh tunnel to report CONNECTED, kicking a
  /// verify-rebuild in case it's hard-down. Returns true once connected; false on
  /// a rejected (re-pair) state or timeout. Non-iroh servers are ready immediately.
  Future<bool> awaitTunnelReady(
      {Server? server, Duration timeout = const Duration(seconds: 12)}) async {
    // Default to the browsed server; callers on the playback path pass the
    // track's server (which the single tunnel may be serving instead).
    final s = server ?? currentServer;
    if (!IrohTunnel.isSupported || s == null || !s.isIroh) return true;
    unawaited(ensureActiveTunnel(verify: true));
    // start() can take ~30s; don't report not-ready while a dial is in flight.
    // Keep extending the window while connecting, bounded by a hard cap.
    final hardCap = DateTime.now().add(const Duration(seconds: 45));
    var deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline) && DateTime.now().isBefore(hardCap)) {
      // Ready only when the tunnel is connected AND serving THIS server — with one
      // tunnel, a different server being served means s isn't reachable yet.
      if (tunnelServes(s)) return true;
      if (tunnelAssignedTo(s) &&
          IrohTunnel.instance.status == IrohTunnelStatus.rejected) {
        return false; // this server's code was rejected (needs re-pair)
      }
      if (_tunnelStarting) deadline = DateTime.now().add(timeout);
      await Future.delayed(const Duration(milliseconds: 300));
    }
    return tunnelServes(s);
  }

  /// Re-pair the active iroh server with a fresh pairing code (after a rotated
  /// secret) and restart the tunnel. Validates the new code by bringing the tunnel
  /// up BEFORE persisting; on failure the previous code is restored (and re-dialed)
  /// and nothing is written — so a wrong/typo code can't destroy a working one.
  /// Returns true iff the new code connected.
  Future<bool> repairIrohPairingCode(String newCode) async {
    // Re-pair whichever server the tunnel actually serves — that's the one whose
    // code was rejected (it may be a background playback server, not the browsed
    // one). Falls back to the browsed server.
    final s = _tunnelTargetServer() ?? currentServer;
    if (s == null || !s.isIroh) return false;
    final oldCode = s.irohPairingCode;

    Future<void> activate(String? code) async {
      s.irohPairingCode = code;
      IrohTunnel.instance.stop();
      _activeTunnelCode = null;
      s.tunnelPort = null;
      s.tunnelToken = null;
      await ensureActiveTunnel(verify: true);
    }

    // Try the new code WITHOUT persisting yet.
    await activate(newCode);
    if (IrohTunnel.instance.status == IrohTunnelStatus.connected) {
      await writeServerFile(); // persist only a code that actually connected
      _refreshTunnelStatus();
      return true;
    }
    // Failed → roll back to the previous code and re-establish the old tunnel.
    await activate(oldCode);
    _refreshTunnelStatus();
    return false;
  }

  /// Adopt a tunnel already started elsewhere (the add-server test) as the active
  /// one, so [ensureActiveTunnel] won't needlessly restart it.
  void registerActiveTunnel(Server s, int port) {
    final token = IrohTunnel.instance.localToken;
    // Serialize the adopt through _tunnelChain so an in-flight (re)start can't
    // clobber these values mid-flight; the changeCurrentServer that follows chains
    // after this and observes the adopted tunnel (no needless re-dial).
    _tunnelChain = _tunnelChain.then((_) {
      s.tunnelPort = port;
      s.tunnelToken = token;
      _activeTunnelCode = s.irohPairingCode;
    }).catchError((_) {});
  }

  Future<void> removeServer(
      Server removeThisServer, bool removeSyncedFiles) async {
    serverList.remove(removeThisServer);
    _serverListStream.sink.add(serverList);
    // Drop a stale queue-tunnel pointer to the removed server so ensureActiveTunnel
    // below doesn't try to keep its tunnel up (the queue listener would clear it on
    // the next edit, but do it now).
    if (_queueIrohServer?.localname == removeThisServer.localname) {
      _queueIrohServer = null;
    }

    if (serverList.isEmpty) {
      // force the browser to rerender so it displays
      BrowserManager().noServerScreen();

      currentServer = null;
      _currentServerStream.sink.add(currentServer);
    } else if (removeThisServer == currentServer) {
      currentServer = serverList[0];
      // clear the browser
      BrowserManager().goToNavScreen();
      _currentServerStream.sink.add(currentServer);
    }

    // Start/stop the tunnel to match the (possibly changed) active server.
    await ensureActiveTunnel();
    await writeServerFile();
    syncInsecureTls();
  }

  Future<void> callAfterEditServer() async {
    _serverListStream.sink.add(serverList);
    syncInsecureTls();
    await writeServerFile();
  }

  Future<void> makeDefault(int i) async {
    Server s = serverList[i];

    serverList.remove(s);
    serverList.insert(0, s);
    _serverListStream.sink.add(serverList);

    // Switch the active server to it right away (not just on next launch)
    // and reset the browser onto the new server — mirrors
    // changeCurrentServer().
    currentServer = s;
    _currentServerStream.sink.add(currentServer);
    await ensureActiveTunnel();
    BrowserManager().goToNavScreen();

    // Persist the new order so serverList[0] — the default loaded on the
    // next launch — is this server. Without this the choice was lost on
    // restart (every other mutator writes the file; this one didn't).
    await writeServerFile();
  }

  /// The configured server with this [localname], or null when none match.
  /// One place to resolve a queue item's / download's server by its stable
  /// localname (used by playback, the transcode badge, queue restore, …).
  Server? byLocalname(String? localname) {
    if (localname == null) return null;
    for (final s in serverList) {
      if (s.localname == localname) return s;
    }
    return null;
  }

  // Self-signed / insecure TLS (full flavor only) — see SelfSignedHttpOverrides
  // (Dart API path) and InsecureTlsChannel (native ExoPlayer streaming path).

  // Hosts the add/edit screen is actively testing or saving with self-signed
  // enabled, before the server is persisted to serverList. Lets allowsSelfSigned
  // trust the in-progress server during its connection test and first
  // getServerPaths; cleared when that screen closes.
  final Set<String> _pendingSelfSignedHosts = {};

  void addPendingSelfSigned(String host) {
    if (host.isNotEmpty) _pendingSelfSignedHosts.add(host);
  }

  void clearPendingSelfSigned() => _pendingSelfSignedHosts.clear();

  /// Drop a single pending trust once its bootstrap is over — blanket trust
  /// must not outlive the flow that needed it (mDNS adverts are
  /// unauthenticated, so a tapped-but-never-saved host keeps no trust).
  void removePendingSelfSigned(String host) =>
      _pendingSelfSignedHosts.remove(host);

  /// True if [host] belongs to a configured server that opted into accepting a
  /// self-signed cert — SelfSignedHttpOverrides bypasses validation for just
  /// that host — or a host the add/edit screen is currently testing/saving with
  /// self-signed on. Always false on the Play build.
  bool allowsSelfSigned(String host) {
    if (isPlayBuild) return false;
    if (_pendingSelfSignedHosts.contains(host)) return true;
    for (final s in serverList) {
      if (!s.allowSelfSigned) continue;
      try {
        if (Uri.parse(s.url).host == host) return true;
      } catch (_) {}
    }
    return false;
  }

  /// Enable the native trust-all TLS bridge (ExoPlayer streaming) iff some
  /// server opted into self-signed. No-op on the Play build. Call whenever the
  /// server list changes.
  void syncInsecureTls() {
    InsecureTlsChannel.setEnabled(serverList.any((s) => s.allowSelfSigned));
  }

  /// Like [byLocalname] but throws when no server matches — for legacy callers
  /// that expect a non-null result (and handle the throw).
  Server lookupServer(String id) {
    final s = byLocalname(id);
    if (s == null) throw StateError('No server with localname "$id"');
    return s;
  }

  void dispose() {
    _serverListStream.close();
    _currentServerStream.close();
    _statusPoll?.cancel();
    _tunnelStatus.close();
    _pathKind.close();
  } //initializes the subject with element already;

  Stream<Server?> get currentServerStream => _currentServerStream.stream;

  Stream<List<Server>> get serverListStream => _serverListStream.stream;
}
