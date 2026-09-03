import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:mstream_music/singletons/file_explorer.dart';

import '../objects/server.dart';
import './api.dart';
import './app_messenger.dart';
import './browser_list.dart';
import './log_manager.dart';
import '../build_variant.dart';
import '../util/insecure_tls_channel.dart';
import '../util/server_version.dart';
import '../util/write_chain.dart';
import '../native/iroh_tunnel.dart';
import './tunnel_policy.dart';
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

  // ── Reconnect bookkeeping (the rules live in tunnel_policy.dart) ──
  // Single-flight handleNetworkChange: a burst (app resume + a connectivity
  // event) runs once, plus one re-run if anything landed while it was busy.
  Future<void>? _networkChangeInFlight;
  bool _networkChangeRerun = false;
  String _rerunReason = '';
  // When the reported status last left `connected` (null while connected).
  DateTime? _notConnectedSince;
  // Last in-place kick (native force-reconnect; null when never/unsupported).
  DateTime? _kickedAt;
  // Last hard rebuild (stop + fresh dial) from ANY caller — rate-limited, since
  // it rotates the loopback port and token.
  DateTime? _lastHardRebuildAt;
  // Last `[none]` connectivity event, to tell a modem re-attach from a hand-off.
  DateTime? _lastOfflineAt;
  // Last failed cold dial; gates every non-user ensure behind the retry timer.
  DateTime? _lastFailedDialAt;
  DateTime? _lastSkipLogAt;
  // The retry loop that makes "no tunnel and nothing scheduled" unreachable
  // while an iroh server is the tunnel's target.
  Timer? _retryTimer;
  int _retryAttempt = 0;
  // A connectivity event landed while a cold dial was in flight: that dial
  // was doomed from its first packet, so its failure restarts the ladder fast.
  bool _networkReturnedDuringDial = false;
  // Ensures queued on _tunnelChain but not finished (awaitTunnelReady extends
  // its deadline while one is pending, not just while a dial is in flight).
  int _pendingEnsures = 0;
  // A cold dial answered "NO": surface Repair (not Retry) and stop re-dialing
  // on every network event — no native tunnel exists to report `rejected`.
  bool _startRejected = false;
  // The launch ping was skipped because the tunnel was not up yet; the next
  // successful dial runs it (vpaths, transcode defaults, version).
  // Servers whose launch-time capability refresh skipped because their
  // TRANSPORT's tunnel was not up: the iroh server itself, and any federated
  // peer riding it. A set, not a slot — one dial serves all of them.
  final Set<String> _pingPendingFor = {};
  // A Retry tap that lands while a network change is in flight must not be
  // downgraded to an automatic re-run.
  bool _rerunUser = false;

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

  // Serializes writes so overlapping truncate+writes can't corrupt
  // servers.json — notably the parallel getServerPaths() pings fired at
  // startup (loadServerList), which can each trigger a capability-change
  // write at the same moment.
  final WriteChain _writeChain = WriteChain();

  Future<void> writeServerFile() => _writeChain.run(() async {
        final file = await _serverFile;
        await file.writeAsString(jsonEncode(serverList));
      });

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

    // Before ANYTHING resolves a URL: a federated server addresses itself
    // through its parent, and QueueStore.init restores tracks against these
    // objects moments from now.
    _linkFederatedParents();

    _serverListStream.sink.add(serverList);
    syncInsecureTls();

    if (serverList.isNotEmpty) {
      currentServer = serverList[0];
      // An iroh default: bring its tunnel up BEFORE the browser queries it —
      // bounded: a cold dial in a dead zone takes up to ~43s and the retry
      // loop owns failures, so launch must not wait on it. The dial keeps
      // running on the chain; the first browse/playback awaits the tunnel
      // itself. A standard default needs nothing and must not wait on the
      // chain either (a queued iroh server's dial may already be running on it).
      if (currentServer!.isIrohTransport) {
        await ensureActiveTunnel(reason: 'launch', bypassBackoff: true)
            .timeout(const Duration(seconds: 12), onTimeout: () {});
      }
      // Publish the default to the UI now: it is usable as soon as it is
      // known. Everything below is background tunnel work for the queue and
      // used to hold the browser (blank panel, "Connecting…") for up to 12s.
      BrowserManager().goToNavScreen();
      _currentServerStream.sink.add(currentServer);
      // Timing marker for the smoke scripts (smoke/android/launch-matrix.sh).
      appLog('[app] default server ready: ${currentServer!.localname}');
      // Pre-warm the saved queue's iroh server (if it's a DIFFERENT server) in the
      // BACKGROUND — without selecting it — so the queue restores against a live
      // tunnel instead of a dead loopback port. The default stays selected; this
      // just points the playback tunnel ahead of QueueStore.init (main.dart gates
      // that on loadServerList completing). Bounded by awaitTunnelReady's cap.
      final resumeName = await QueueStore().peekResumeServer();
      if (resumeName != null && resumeName != currentServer?.localname) {
        // A federated resume server needs its PARENT's tunnel.
        final rs = byLocalname(resumeName)?.transportServer;
        if (rs != null && rs.isIroh) {
          setQueueIrohServer(rs);
          await awaitTunnelReady(
              server: rs, caller: 'launch', extendWhileDialing: false);
        }
      }
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

    await _ensureDownloadDir(newServer);

    await writeServerFile();

    _serverListStream.sink.add(serverList);
    syncInsecureTls();

    // Fetch the version now and warn if the server predates what this app
    // supports. Here rather than in the add-server form because both entry
    // points (URL and Quick Connect) funnel through this, and because the
    // warning should follow the server, not the screen that created it.
    //
    // Warn, never block: an old server still browses and plays. The point is
    // that the user finds out from us rather than from a feature quietly
    // doing nothing.
    unawaited(_warnIfBelowFloor(newServer));
  }

  /// Create `media/<localname>`, where this server's downloads land.
  ///
  /// Every server needs one, but they arrive by two doors: the add-server form
  /// ([addServer]) and the peer reconcile ([refreshFederatedPeers]), which adds
  /// its servers to the list directly.
  Future<void> _ensureDownloadDir(Server server) async {
    Directory? file = await FileExplorer()
        .getDownloadDir(server.storageMode, server.storageBasePath);
    if (file == null) return;
    try {
      String dir = path.join(file.path, "media/${server.localname}");
      await Directory(dir).create(recursive: true);
    } catch (e) {
      // A permanent/SD path can fail to create (unmounted, read-only).
      // Don't let that abort the save that follows and lose the server
      // entirely.
      showGlobalSnack(
          'Saved, but the download folder could not be created — storage '
          'may be unavailable.');
    }
  }

  Future<void> _warnIfBelowFloor(Server server) async {
    final probe = await fetchServerVersion(server);
    if (probe.version != null) {
      server.serverVersion = probe.version;
      server.versionCheckedAt = DateTime.now();
      await writeServerFile();
      _serverListStream.sink.add(serverList);
    }
    final parsed = ServerVersion.tryParse(probe.version);
    // Only two outcomes are evidence of age: a version below the floor, and
    // a 404 (pre-5.4.2 has no /api/ at all). A probe that FAILED — the
    // just-added iroh server whose tunnel auth hadn't settled, a Wi-Fi blip
    // on an HTTP add — says nothing about the server, and greeting a new
    // user's current server with "older than 5.5" is exactly the wrong
    // first impression. Stay quiet there: the capability re-check re-probes
    // and stores the version when it lands, and the nav-drawer update flag
    // reads that.
    switch (floorVerdictFor(parsed, notFound: probe.notFound)) {
      case FloorVerdict.ok:
        return;
      case FloorVerdict.belowFloor:
        showGlobalSnack(
            'This server is version ${parsed!.raw}. Some features need 5.5 '
            'or newer and will be unavailable.');
      case FloorVerdict.preVersionEndpoint:
        showGlobalSnack(
            'This server is older than 5.5. Some features will be '
            'unavailable.');
      case FloorVerdict.unknown:
        appLog('[api] add-time version probe inconclusive for '
            '${server.localname} — not warning');
    }
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
    await _settleTunnelForSwitch('server-switch');
  }

  /// After [currentServer] changed: reset the browser onto it and point the
  /// tunnel where it now belongs. An iroh server is brought up BEFORE the
  /// browser queries it. A standard server needs no tunnel, so the browser
  /// resets at once — the old server's stack must not sit under the new
  /// header, and it must not wait on the chain, where a cold dial for the
  /// queue's iroh server may be running; the ensure (keep the tunnel for the
  /// queue, or release it) runs behind.
  Future<void> _settleTunnelForSwitch(String reason) async {
    final s = currentServer!;
    appLog('[srv] switched to ${s.localname} ($reason)');
    if (!s.isIrohTransport) {
      BrowserManager().goToNavScreen();
      unawaited(getServerPaths(s));
      unawaited(ensureActiveTunnel(reason: reason, bypassBackoff: true));
      return;
    }
    await ensureActiveTunnel(reason: reason, bypassBackoff: true);
    BrowserManager().goToNavScreen();
    unawaited(getServerPaths(s));
  }

  Future<void> getServerPaths(Server server, {bool throwErr = false}) async {
    // Whatever actually carries this server's bytes. A federated server has no
    // transport of its own — it rides the parent's, so a peer of an iroh
    // server has to wait on the PARENT's tunnel, not its own (it has none).
    final transport = server.isFederated ? server.parentServer : server;
    // A federated server whose parent isn't linked yet can't be addressed at
    // all; every URL would resolve to the unroutable origin.
    if (transport == null) {
      if (throwErr) throw Exception('federation parent not linked');
      return;
    }
    // An iroh server can only be reached through its live tunnel.
    if (transport.isIroh && transport.tunnelPort == null) {
      // At launch this fires for the ACTIVE server too: loadServerList pings
      // every server as soon as the list is read, and the tunnel is still
      // dialling. Skipping meant its capabilities and — since the version
      // probe rides along here — its VERSION were never fetched at all, so an
      // iroh server sat on "version unknown" with an update warning under it
      // until something else happened to re-ping.
      //
      // Bounded, and only for the active server: one tunnel at a time, so any
      // other iroh server's is never coming up and waiting on it would stall
      // the launch sweep for nothing. extendWhileDialing:false keeps the bound
      // real — the default re-arms for as long as a dial is in flight.
      if (identical(transport, currentServer) ||
          identical(server, currentServer)) {
        await awaitTunnelReady(
            server: transport,
            timeout: const Duration(seconds: 12),
            extendWhileDialing: false,
            caller: 'ping');
      }
      if (transport.tunnelPort == null) {
        if (throwErr) throw Exception('iroh tunnel not connected');
        _pingPendingFor.add(server.localname); // re-run when the dial lands
        return;
      }
    }
    try {
      // GET /api — version, server-wide `features` and the caller-scoped
      // `user` block in ONE call (mStream #932/#934). Also the only capability
      // route a federated server answers: /api/v1/ping is off the federation
      // allowlist and 403s a peer key.
      final info = await _fetchServerInfo(server);

      final bool? prevAvail = server.transcodeAvailable;
      final String? prevCodec = server.transcodeDefaultCodec;
      final String? prevBitrate = server.transcodeDefaultBitrate;
      final bool? prevDiscovery = server.discoveryAvailable;
      final bool? prevDiscoveryP2p = server.discoveryP2pAvailable;
      final bool? prevFedDiscovery = server.federationDiscoveryAvailable;
      final bool? prevDiscoveryPath = server.discoveryPathAvailable;
      final prevVersion = server.serverVersion;

      // Whichever payload carried the caller-scoped flags. A layered answer
      // has `user`; a pre-#932 server answers the same route with a flat
      // {server, apiVersions, features:{subsonic}} and keeps its capabilities
      // on ping.
      Map? scoped;
      if (info != null && info['user'] is Map) {
        _applyServerInfo(server, info);
        scoped = info['user'] as Map;
        // Playlists left the boot payload in #932 — a resource, not a
        // capability. Federated servers skip it: every playlist route is off
        // the federation allowlist.
        if (!server.isFederated) await _refreshPlaylists(server);
      } else if (server.isFederated) {
        // A peer too old for #932 has nothing else to offer — ping would 403
        // even if we asked. Keep the federated defaults rather than invent
        // capabilities we cannot confirm.
        appLog('[server] ${server.localname}: peer has no layered /api; '
            'keeping federated defaults');
        _applyFederatedDefaults(server);
      } else {
        scoped = await _applyPing(server);
      }

      // The version rides along with whichever shape answered — both carry
      // `server` — so it costs no extra round trip. Failure leaves the stored
      // value alone rather than blanking it: a momentary blip should not make
      // a known-good server look ancient.
      final fetched = info?['server'];
      if (fetched is String && fetched.trim().isNotEmpty) {
        server.serverVersion = fetched.trim();
        server.versionCheckedAt = DateTime.now();
      } else {
        // Never successfully checked AND it just failed: record the attempt so
        // the periodic re-check backs off instead of retrying every resume.
        server.versionCheckedAt ??= DateTime.now();
      }

      // Persist the capabilities so the NEXT launch knows them before the queue
      // is restored — otherwise restore races the refresh and bakes in /media
      // URLs.
      if (server.serverVersion != prevVersion ||
          server.transcodeAvailable != prevAvail ||
          server.transcodeDefaultCodec != prevCodec ||
          server.transcodeDefaultBitrate != prevBitrate ||
          server.discoveryAvailable != prevDiscovery ||
          server.discoveryP2pAvailable != prevDiscoveryP2p ||
          server.federationDiscoveryAvailable != prevFedDiscovery ||
          server.discoveryPathAvailable != prevDiscoveryPath) {
        unawaited(writeServerFile());
      }

      // Peers are the parent's data, so only a parent reconciles them — and
      // only when it says it has some (flags, never probes).
      if (!server.isFederated && scoped?['federationBrowse'] == true) {
        unawaited(refreshFederatedPeers(server));
      }
    } catch (err) {
      if (throwErr) {
        rethrow;
      }
    }
  }

  /// `GET /api/` — the layered server-info endpoint (mStream #932/#934):
  /// version, server-wide `features`, and the caller-scoped `user` block in one
  /// call.
  ///
  /// Returns the decoded body, or null when the server answered but had nothing
  /// to say (404 on a pre-5.4.2 build, 403 from a peer whose allowlist predates
  /// #932). Transport failures throw, so [getServerPaths]'s throwErr still
  /// reports a server that is simply down.
  ///
  /// Sent WITH the access token: #934 put this route back behind the auth wall,
  /// where a tokenless request is a 401 by contract — that 401 is how a client
  /// detects "this server needs a login", deliberately not a silent downgrade
  /// to a public payload.
  Future<Map<String, dynamic>?> _fetchServerInfo(Server server) async {
    final response = await http.get(
      server.apiUri('/api/'),
      headers: {'x-access-token': server.authToken ?? ''},
    ).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      appLog('[server] /api on ${server.localname} -> '
          'HTTP ${response.statusCode}');
      return null;
    }
    final decoded = jsonDecode(response.body);
    return decoded is Map<String, dynamic> ? decoded : null;
  }

  /// Fold a layered `GET /api/` response into [server].
  ///
  /// `features` is server-wide; `user` is scoped to the credential that asked —
  /// for a federated server that credential is the parent's federation key, so
  /// `user.vpaths` arrives already narrowed to the libraries the key was
  /// granted.
  void _applyServerInfo(Server server, Map info) {
    final features = info['features'];
    final user = info['user'];

    _applyVpaths(server, user is Map ? user['vpaths'] : null);
    _applyTranscode(server, features is Map ? features['transcode'] : null);

    server.discoveryAvailable = features is Map && features['discovery'] == true;
    server.discoveryP2pAvailable =
        features is Map && features['discoveryP2p'] == true;
    server.federationDiscoveryAvailable =
        user is Map && user['federationDiscovery'] == true;
    // /api carries no discoveryPath. It was only ever a "this server VERSION
    // has the sonic-path route" gate, and mStream #934 records that it is
    // identical to `discovery` on every build carrying that code.
    server.discoveryPathAvailable = server.discoveryAvailable;

    if (server.isFederated) _applyFederatedDefaults(server);
  }

  /// `GET /api/v1/ping` — the pre-#932 boot payload, still served (frozen) by
  /// every mStream build. The fallback when `/api/` answers with the old flat
  /// shape, so the app keeps working against servers released before the
  /// layered endpoint. Returns the decoded body for its caller-scoped flags.
  Future<Map?> _applyPing(Server server) async {
    final response = await http.get(
      server.apiUri('/api/v1/ping'),
      headers: {
        'Content-Type': 'application/json',
        'x-access-token': server.authToken ?? '',
      },
    ).timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) {
      throw Exception('Failed to connect to server');
    }
    final res = jsonDecode(response.body);
    if (res is! Map) throw Exception('Failed to connect to server');

    _applyVpaths(server, res['vpaths']);
    _applyPlaylists(server, res['playlists']);
    _applyTranscode(server, res['transcode']);
    server.discoveryAvailable = res['discovery'] == true;
    server.discoveryP2pAvailable = res['discoveryP2p'] == true;
    server.federationDiscoveryAvailable = res['federationDiscovery'] == true;
    server.discoveryPathAvailable = res['discoveryPath'] == true;
    return res;
  }

  /// Reconcile [server]'s Auto DJ path map against the library list it just
  /// reported: add new vpaths (enabled), drop ones that are gone, and re-enable
  /// everything if the user's selection has emptied out.
  void _applyVpaths(Server server, dynamic vpaths) {
    final Set<String> reported = {};
    if (vpaths is List) {
      for (final raw in vpaths) {
        if (raw is! String) continue; // tolerate unexpected element shapes
        reported.add(raw);
        if (!server.autoDJPaths.containsKey(raw)) {
          server.autoDJPaths[raw] = true;
        }
      }
    }
    server.autoDJPaths.removeWhere((key, value) => !reported.contains(key));
    if (server.autoDJPaths.values.every((v) => v != true)) {
      server.autoDJPaths.updateAll((key, value) => true);
    }
  }

  /// Accept both the bare-name form (["A", "B"]) and the object form
  /// ([{"name": "A"}, ...]) that some builds (e.g. Velvet) return.
  void _applyPlaylists(Server server, dynamic pls) {
    server.playlists.clear();
    if (pls is! List) return;
    for (final raw in pls) {
      final name = raw is String ? raw : (raw is Map ? raw['name'] : null);
      if (name is String && name.isNotEmpty) server.playlists.add(name);
    }
  }

  /// `transcode` is false when the server has no working ffmpeg, otherwise
  /// { defaultCodec, defaultBitrate } — the values /transcode falls back to
  /// when the client omits those params. Same field on ping's flat payload and
  /// on /api's `features`.
  void _applyTranscode(Server server, dynamic transcodeInfo) {
    if (transcodeInfo is! Map) {
      server.transcodeAvailable = false;
      server.transcodeDefaultCodec = null;
      server.transcodeDefaultBitrate = null;
      return;
    }
    server.transcodeAvailable = true;
    // Coerce defensively: a fork may return these as objects/numbers rather
    // than strings. A shape mismatch must never throw here — it would surface
    // as a bogus "failed to connect" on a server that actually responded 200.
    final codec = transcodeInfo['defaultCodec'];
    final bitrate = transcodeInfo['defaultBitrate'];
    server.transcodeDefaultCodec = codec is String ? codec : null;
    server.transcodeDefaultBitrate = bitrate is String ? bitrate : null;
  }

  /// `GET /api/v1/playlist/getall` — the playlist names ping used to carry.
  ///
  /// Fetched separately since #932 moved playlists off the boot payload (a
  /// resource, not a capability). Best-effort: the names only feed pickers, and
  /// losing them must not cost a capability refresh that already succeeded.
  Future<void> _refreshPlaylists(Server server) async {
    try {
      final response = await http.get(
        server.apiUri('/api/v1/playlist/getall'),
        headers: {'x-access-token': server.authToken ?? ''},
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return;
      _applyPlaylists(server, jsonDecode(response.body));
    } catch (err) {
      appLog('[server] playlist refresh for ${server.localname} failed: $err');
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
  // Pending release of _queueIrohServer (see setQueueIrohServer).
  Timer? _queueReleaseTimer;

  /// Record the iroh server the play queue references ([s]), or null when no
  /// queued song is from an iroh server. No-op when unchanged; otherwise
  /// re-evaluates the tunnel target. Called by the audio handler on queue changes.
  ///
  /// A null is applied after [TunnelTiming.queueReleaseGrace], not at once:
  /// the handler's initial empty queue, a restore and a clear-then-refill all
  /// pass through "nothing from the iroh server queued" for a moment, and an
  /// immediate release tore a launch tunnel down mid-dial (a full rebuild —
  /// new port, reloaded URLs — seconds later). A server arriving inside the
  /// grace period simply cancels the release.
  void setQueueIrohServer(Server? s) {
    final next = (s != null && s.isIroh) ? s : null;
    if (next != null) {
      _queueReleaseTimer?.cancel();
      _queueReleaseTimer = null;
    }
    if (next?.localname == _queueIrohServer?.localname) return;
    if (next == null) {
      _queueReleaseTimer ??= Timer(TunnelTiming.queueReleaseGrace, () {
        _queueReleaseTimer = null;
        final was = _queueIrohServer;
        if (was == null) return;
        appLog('[iroh] queue no longer references ${was.localname} — '
            'releasing the tunnel');
        _queueIrohServer = null;
        unawaited(ensureActiveTunnel(reason: 'queue-server'));
      });
      return;
    }
    _queueIrohServer = next;
    // No backoff bypass: this fires from the launch queue restore as well as
    // from a user queuing songs, and a bypass here re-dialed a REJECTED code
    // 0.3s after the launch dial was refused (simulator run 2026-09-01).
    // When nothing failed it dials right away; otherwise the timer owns it.
    unawaited(ensureActiveTunnel(reason: 'queue-server'));
  }

  // Which iroh server the single tunnel should serve: the browsed server when it
  // IS the iroh server, OR the iroh server whose songs are queued. Null → no
  // tunnel. (One-iroh-server cap, so these resolve to the same server when both
  // apply — there's never a second iroh server to contend for the tunnel.)
  //
  // Both sides resolve through the TRANSPORT server: a federated peer has no
  // tunnel of its own and rides its parent's, so browsing a peer (or queuing
  // its songs) must keep the parent's tunnel up, not release it.
  Server? _tunnelTargetServer() {
    final c = currentServer?.transportServer;
    if (c != null && c.isIroh) return c;
    final q = _queueIrohServer?.transportServer;
    return (q != null && q.isIroh) ? q : null;
  }

  /// True when the tunnel currently has a server to serve (the browsed iroh server
  /// OR a background playback server). Drives the status banner — which must show
  /// for a background tunnel even while a non-iroh default is the selected server.
  bool get tunnelActive => _tunnelTargetServer() != null;

  /// True when the single tunnel is currently assigned to [s] (regardless of its
  /// connection state) — i.e. [s] is the server we last (re)started it for.
  ///
  /// Answered for the TRANSPORT: a federated peer is served exactly when its
  /// parent's tunnel is, so every caller may pass whichever server it holds.
  bool tunnelAssignedTo(Server s) {
    final t = s.transportServer;
    return t != null &&
        t.isIroh &&
        _activeTunnelCode != null &&
        t.irohPairingCode == _activeTunnelCode;
  }

  /// True when the tunnel is assigned to [s] AND reports connected — i.e. [s]'s
  /// loopback is live right now.
  bool tunnelServes(Server s) =>
      tunnelAssignedTo(s) && IrohTunnel.instance.status == IrohTunnelStatus.connected;

  /// Bring the single iroh tunnel in line with the active server. With [verify],
  /// also force a rebuild when the native tunnel is fully *down* despite our
  /// bookkeeping (the shim's supervisor self-heals transient drops, so this only
  /// fires for a hard-down tunnel). Serialized against concurrent callers.
  ///
  /// [reason] is logged with every start/stop so the next incident log says who
  /// asked. [bypassBackoff] lets the retry timer and user-driven callers dial
  /// even when a cold dial failed moments ago; everything else waits for the
  /// timer (see [TunnelPolicy.shouldSkipColdDial]).
  ///
  /// Invariants (hold them when touching anything below):
  ///  1. Every native mutation — start, stop, kick, pairing-code swap — runs
  ///     inside _tunnelChain. Probes may run outside it, but a consequence of a
  ///     probe re-checks the tunnel identity (code, port) inside the chain
  ///     before acting (see _sameTunnel).
  ///  2. A native tunnel reporting `reconnecting` is never stopped unless the
  ///     user asked (Retry) or the watchdog says the relay is reachable and the
  ///     supervisor is not converging.
  ///  3. s.tunnelPort / s.tunnelToken / _activeTunnelCode change only inside
  ///     the chain; a kick leaves all three unchanged.
  ///  4. While the target is an iroh server and no native tunnel exists, a retry
  ///     Timer is armed (unless the pairing was rejected). There is no "down
  ///     with nothing scheduled" state.
  ///  5. At most one hard rebuild per hardRebuildMinGap across all callers; a
  ///     user-initiated Retry/Repair bypasses the gap.
  Future<void> ensureActiveTunnel(
      {bool verify = false,
      String reason = 'ensure',
      bool bypassBackoff = false}) {
    _pendingEnsures++;
    final next = _tunnelChain
        .then((_) => _ensureActiveTunnel(verify, reason, bypassBackoff))
        .whenComplete(() => _pendingEnsures--);
    _tunnelChain = next.catchError((_) {});
    return next;
  }

  Future<void> _ensureActiveTunnel(
      bool verify, String reason, bool bypassBackoff) async {
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
      // A cold dial answered "NO" (wrong/rotated secret): only a repair or a
      // user tap may dial again. Otherwise every automatic caller — a DJ pick
      // re-fired every ~30s, a playback error, a download — would re-dial
      // into the same rejection and flicker the banner Repair↔Connecting.
      if (_activeTunnelCode == null && _startRejected && !bypassBackoff) {
        return;
      }
      // No tunnel and a cold dial failed recently: the retry timer owns the
      // next attempt. Without this gate every caller that wants the tunnel
      // would queue its own 33–43s dial behind the last one, so a dead zone
      // became back-to-back radio time with no backoff at all.
      if (_activeTunnelCode == null &&
          TunnelPolicy.shouldSkipColdDial(
              sinceFailedDial: _since(_lastFailedDialAt),
              nextRetry: TunnelPolicy.retryDelay(_retryAttempt),
              bypassBackoff: bypassBackoff)) {
        final now = DateTime.now();
        if (_lastSkipLogAt == null ||
            now.difference(_lastSkipLogAt!) >= const Duration(seconds: 60)) {
          _lastSkipLogAt = now;
          appLog('[iroh] start skipped ($reason) — a dial failed '
              '${_since(_lastFailedDialAt)!.inSeconds}s ago; '
              'retry #${_retryAttempt + 1} owns the next attempt');
        }
        if (_retryTimer == null && !_startRejected) _scheduleRetry();
        return;
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
        _stopTunnel('switch/$reason');
      }
      _tunnelStarting = true;
      _networkReturnedDuringDial = false;
      _refreshTunnelStatus(); // surface "Connecting…" while the dial runs
      final sw = Stopwatch()..start();
      try {
        final port = await IrohTunnel.instance.start(s.irohPairingCode!);
        s.tunnelPort = port;
        s.tunnelToken = IrohTunnel.instance.localToken;
        _activeTunnelCode = s.irohPairingCode;
        _cancelRetry();
        _startRejected = false;
        _lastFailedDialAt = null;
        _notConnectedSince = null;
        _kickedAt = null;
        appLog('[iroh] tunnel up port=$port '
            'path=${IrohTunnel.instance.pathKind.name} '
            'in ${sw.elapsedMilliseconds}ms ($reason)');
        // The launch sweep no longer waits for a slow dial; run the ping it
        // skipped so vpaths / transcode / version are not stale all session.
        for (final name in _pingPendingFor.toList()) {
          final pending = byLocalname(name);
          if (pending == null) {
            _pingPendingFor.remove(name);
          } else if (identical(pending.transportServer, s)) {
            _pingPendingFor.remove(name);
            unawaited(getServerPaths(pending));
          }
        }
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
          // Reaching here should now be rare: the handler runs this rebuild
          // on the same chain as every other local-backend load, so a
          // concurrent load can't interrupt it. It is NOT benign if it does —
          // an interrupt inside just_audio's activation window wedges the
          // player until stop() or process death (see the customAction case
          // in audio_stuff.dart). Logged, not swallowed silently.
          appLog('[iroh] auto URL rebuild after tunnel bind failed: $e');
        }));
      } catch (e) {
        s.tunnelPort = null;
        s.tunnelToken = null;
        _activeTunnelCode = null;
        _lastFailedDialAt = DateTime.now();
        // The native side distinguishes a "NO" handshake (wrong/rotated secret)
        // from an unreachable server; only the latter is worth retrying.
        _startRejected = '$e'.contains('rejected');
        appLog('[iroh] tunnel start failed after ${sw.elapsedMilliseconds}ms '
            '($reason): $e');
        if (_startRejected) {
          _cancelRetry();
        } else {
          final next = TunnelPolicy.retryAfterFailedDial(
              attempt: _retryAttempt,
              networkReturnedDuringDial: _networkReturnedDuringDial);
          _retryAttempt = next.attempt;
          _scheduleRetry(
              delay: next.delay,
              note: _networkReturnedDuringDial
                  ? ' — the network came back mid-dial'
                  : '');
        }
      } finally {
        _tunnelStarting = false;
      }
      _refreshTunnelStatus();
    } else if (_activeTunnelCode != null) {
      _stopTunnel('no-target/$reason');
      _cancelRetry();
      _stopStatusPolling();
    } else {
      _cancelRetry();
      _stopStatusPolling();
    }
  }

  Duration? _since(DateTime? t) =>
      t == null ? null : DateTime.now().difference(t);

  /// Run [fn] on the tunnel chain (invariant 1). Returns the chained future so
  /// the caller can await the mutation; the chain itself swallows errors.
  Future<void> _mutateTunnel(String reason, FutureOr<void> Function() fn) {
    final next = _tunnelChain.then((_) => fn());
    _tunnelChain = next.catchError((_) {});
    return next;
  }

  /// Stop the native tunnel and forget its assignment. ONLY from inside the
  /// chain (invariant 3).
  void _stopTunnel(String reason) {
    if (_activeTunnelCode != null) {
      appLog('[iroh] tunnel stopped ($reason) '
          'port=${_tunnelTargetServer()?.tunnelPort}');
    }
    IrohTunnel.instance.stop();
    _activeTunnelCode = null;
  }

  /// True when the tunnel is still the one a probe was taken against — the
  /// re-check every probe consequence runs inside the chain before acting.
  bool _sameTunnel(Server s, String? code, int? port) =>
      code != null &&
      _activeTunnelCode == code &&
      s.tunnelPort == port &&
      s.irohPairingCode == code;

  /// Arm the retry after a failed cold dial (invariant 4). The attempt index is
  /// only reset by a success or a target change, so a burst of callers cannot
  /// shorten the backoff.
  void _scheduleRetry({Duration? delay, String note = ''}) {
    _retryTimer?.cancel();
    final d = delay ?? TunnelPolicy.retryDelay(_retryAttempt);
    appLog('[iroh] retry #${_retryAttempt + 1} in ${d.inSeconds}s$note');
    _retryTimer = Timer(d, () {
      _retryTimer = null;
      final s = _tunnelTargetServer();
      if (s == null ||
          !s.isIroh ||
          _activeTunnelCode != null ||
          _tunnelStarting ||
          _startRejected) {
        return;
      }
      _retryAttempt++;
      unawaited(ensureActiveTunnel(
          verify: true, reason: 'retry#$_retryAttempt', bypassBackoff: true));
    });
  }

  void _cancelRetry() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _retryAttempt = 0;
  }

  /// Called by the connectivity listener on a `[none]` result (invariant: the
  /// only place _lastOfflineAt is written).
  void noteConnectivityLost() {
    _lastOfflineAt = DateTime.now();
  }

  /// React to a device network change / app resume / the banner's Retry tap:
  /// nudge iroh to re-probe paths (it can't self-detect on Android), then let
  /// the pure [TunnelPolicy] decide — leave a reconnecting tunnel to its
  /// supervisor, probe a connected-reporting one for ground truth, or (re)start
  /// a missing one. Single-flight: overlapping calls (a resume plus a
  /// connectivity burst) coalesce into one run plus at most one re-run.
  ///
  /// History: this used to probe the loopback unconditionally and hard-drop on
  /// any failure. During a reconnect the shim fails every loopback request
  /// within a second, so the probe always failed, and the app killed the very
  /// supervisor that would have healed the tunnel in place — replacing it with
  /// one cold dial (drive log: 15:08:50 "resume probe failed" → 15:09:23
  /// "tunnel start failed", then nothing until the user tapped a track). The
  /// probe is now reserved for the case it was written for (98d06c8): native
  /// status `connected` on a QUIC connection that is actually dead after an
  /// iOS thaw — and it has to fail twice, with a grace window for iroh's own
  /// path migration, before anything is torn down.
  Future<void> handleNetworkChange(
      {String reason = 'unknown', bool userInitiated = false}) {
    if (_networkChangeInFlight != null) {
      _networkChangeRerun = true;
      _rerunReason = reason;
      _rerunUser = _rerunUser || userInitiated;
      return _networkChangeInFlight!;
    }
    Future<void> run() async {
      var r = reason;
      var user = userInitiated;
      do {
        _networkChangeRerun = false;
        try {
          await _handleNetworkChangeOnce(r, user);
        } catch (e) {
          appLog('[iroh] network change ($r) failed: $e');
        }
        r = _rerunReason;
        user = _rerunUser;
        _rerunUser = false;
      } while (_networkChangeRerun);
    }

    final f = run().whenComplete(() => _networkChangeInFlight = null);
    _networkChangeInFlight = f;
    return f;
  }

  Future<void> _handleNetworkChangeOnce(String reason, bool user) async {
    final s = _tunnelTargetServer();
    if (!IrohTunnel.isSupported || s == null) return;
    IrohTunnel.instance.networkChanged();
    if (!user && reason.startsWith('connectivity:') && _tunnelStarting) {
      _networkReturnedDuringDial = true;
    }
    final native = IrohTunnel.instance.status;
    final code = _activeTunnelCode;
    final port = s.tunnelPort;
    appLog('[iroh] network change ($reason) native=${native.name} port=$port '
        'notConnectedFor=${_since(_notConnectedSince)?.inSeconds ?? 0}s');
    switch (TunnelPolicy.onNetworkChange(
        native: native,
        assigned: tunnelAssignedTo(s) && port != null,
        starting: _tunnelStarting,
        rejected: native == IrohTunnelStatus.rejected || _startRejected,
        sinceOffline: _since(_lastOfflineAt),
        userInitiated: user)) {
      case NetworkChangeRemedy.leaveRejected:
        appLog('[iroh] pairing rejected — waiting for a repair, not re-dialing');
        return;
      case NetworkChangeRemedy.leaveToSupervisor:
        appLog(native == IrohTunnelStatus.connected
            ? '[iroh] network just re-attached — leaving the connection to iroh'
            : '[iroh] leaving the reconnect to the supervisor');
        return;
      case NetworkChangeRemedy.escalate:
        // The banner's Retry while the supervisor re-dials: kick in place
        // first (same port — a fresh endpoint cold-dials into the same dead
        // zone and rotates every URL; Galaxy S25 round: 24s vs 8s); a second
        // tap inside the post-kick window gets the fresh endpoint.
        switch (TunnelPolicy.onUserEscalate(
            canKick: IrohTunnel.instance.hasKick,
            sinceKick: _since(_kickedAt))) {
          case DeadTunnelRemedy.kick:
            await _kickTunnel(s, code: code, port: port, reason: reason);
          case DeadTunnelRemedy.hardRebuild:
          case DeadTunnelRemedy.wait:
            await _hardRebuild(s,
                code: code, port: port, reason: 'escalate/$reason', user: user);
        }
        return;
      case NetworkChangeRemedy.probe:
        if (await _probeTwice(s, code: code, port: port)) {
          await _remedyDeadTunnel(s,
              code: code, port: port, reason: reason, user: user);
        }
        return;
      case NetworkChangeRemedy.ensureOnly:
        break;
    }
    // No tunnel (or a dial in flight): make sure one is coming. An automatic
    // trigger with a failed dial behind it does not dial on the spot — the
    // network just changed and is often not usable yet (log: the re-attach at
    // 15:08:49 landed while service was still dead) — but it restarts the
    // retry schedule so the next attempt is seconds away, not a minute.
    if (!user &&
        _activeTunnelCode == null &&
        !_tunnelStarting &&
        _lastFailedDialAt != null &&
        !_startRejected) {
      // Clamp rather than zero: a flapping dead zone emits a transport event
      // every few minutes, and a full 5/10/20/40s ramp per event would keep
      // the radio busy; one quick attempt per event is enough.
      _retryAttempt = _retryAttempt.clamp(0, 1);
      _scheduleRetry();
      return;
    }
    await ensureActiveTunnel(verify: true, reason: reason, bypassBackoff: user);
  }

  /// True only when two probes, spaced across iroh's migration window, both
  /// failed AND the tunnel is still the same one reporting connected. A
  /// supervisor that noticed the drop in between (status → reconnecting) owns
  /// the recovery, so that is a "false" too.
  Future<bool> _probeTwice(Server s,
      {required String? code, required int? port}) async {
    final t0 = DateTime.now();
    await Future<void>.delayed(TunnelTiming.probeFirstDelay);
    if (!_sameTunnel(s, code, port)) return false;
    final r1 = await _probeTunnel(s);
    appLog('[iroh] probe #1 ${r1.ok ? 'passed' : 'failed'} '
        '(${r1.reason}, ${r1.ms}ms, native=${IrohTunnel.instance.status.name})');
    if (r1.ok) return false;
    // "refused" on loopback is definitive — nothing listens on the port any
    // more. The second probe exists to tell a path migration from a zombie,
    // and a migration never refuses, so waiting for it would only add 7s to
    // every iOS thaw (iPhone X round: kick at +10s → +3s).
    if (TunnelPolicy.probeIsDefinitive(r1.reason) &&
        _sameTunnel(s, code, port) &&
        IrohTunnel.instance.status == IrohTunnelStatus.connected) {
      return true;
    }
    final wait = TunnelTiming.probeSecondAt - DateTime.now().difference(t0);
    if (wait > Duration.zero) await Future<void>.delayed(wait);
    if (!_sameTunnel(s, code, port) ||
        IrohTunnel.instance.status != IrohTunnelStatus.connected) {
      return false;
    }
    final r2 = await _probeTunnel(s);
    appLog('[iroh] probe #2 ${r2.ok ? 'passed' : 'failed'} '
        '(${r2.reason}, ${r2.ms}ms)');
    return !r2.ok;
  }

  /// A connected-reporting tunnel is dead (two probes, or repeated load
  /// failures): kick it in place when the binary can, else rebuild — rate
  /// limited, because a rebuild rotates the port and token.
  Future<void> _remedyDeadTunnel(Server s,
      {required String? code,
      required int? port,
      required String reason,
      required bool user}) async {
    switch (TunnelPolicy.onProbeFailedTwice(
        canKick: IrohTunnel.instance.hasKick,
        sinceHardRebuild: _since(_lastHardRebuildAt),
        sinceKick: _since(_kickedAt),
        userInitiated: user)) {
      case DeadTunnelRemedy.kick:
        await _kickTunnel(s, code: code, port: port, reason: reason);
      case DeadTunnelRemedy.hardRebuild:
        await _hardRebuild(s,
            code: code,
            port: port,
            reason: 'dead/$reason',
            user: user,
            onlyIfConnected: !user);
      case DeadTunnelRemedy.wait:
        appLog('[iroh] tunnel dead but a rebuild ran '
            '${_since(_lastHardRebuildAt)?.inSeconds}s ago — waiting');
    }
  }

  /// The in-place remedy: the native force-reconnect (network nudge, loopback
  /// listener re-bind, close + immediate re-dial) on the same port and token,
  /// so nothing built against the tunnel goes stale.
  Future<void> _kickTunnel(Server s,
      {required String? code,
      required int? port,
      required String reason}) async {
    await _mutateTunnel('kick/$reason', () {
      if (!_sameTunnel(s, code, port)) return;
      _kickedAt = DateTime.now();
      _notConnectedSince ??= _kickedAt;
      appLog('[iroh] kicking the tunnel in place ($reason) — port $port kept');
      IrohTunnel.instance.kick();
    });
  }

  /// Stop the native tunnel and dial fresh (new port + token). The one path
  /// that discards the supervisor, so it re-checks the tunnel identity inside
  /// the chain and honours hardRebuildMinGap unless the user asked.
  ///
  /// [onlyIfConnected]: a probe-derived rebuild must not stop a supervisor
  /// that flipped to `reconnecting` while the probe was running (the QUIC
  /// idle timeout lands inside that window) — it is already healing on the
  /// same port. The watchdog and a user tap target a reconnecting tunnel on
  /// purpose and leave this false.
  Future<void> _hardRebuild(Server s,
      {required String? code,
      required int? port,
      required String reason,
      required bool user,
      bool onlyIfConnected = false}) async {
    final gap = _since(_lastHardRebuildAt);
    if (!user && gap != null && gap < TunnelTiming.hardRebuildMinGap) {
      appLog('[iroh] hard rebuild ($reason) skipped — last one '
          '${gap.inSeconds}s ago');
      return;
    }
    var dropped = false;
    await _mutateTunnel('drop/$reason', () {
      if (!_sameTunnel(s, code, port)) return; // already rebuilt or dropped
      if (onlyIfConnected &&
          IrohTunnel.instance.status != IrohTunnelStatus.connected) {
        appLog('[iroh] rebuild ($reason) skipped — the supervisor took over');
        return;
      }
      _lastHardRebuildAt = DateTime.now();
      _stopTunnel('rebuild/$reason');
      dropped = true;
    });
    if (!dropped) return;
    await ensureActiveTunnel(
        verify: true, reason: 'rebuild/$reason', bypassBackoff: true);
  }

  /// Read the server's version from `GET /api/` — public, no auth, and served
  /// since 5.4.2. Returns the raw `server` string, or null when the endpoint
  /// isn't there (pre-5.4.2), the body isn't the shape we expect, or the
  /// request fails. Null is meaningful rather than an error: see
  /// util/server_version.dart for why "can't say" and "too old" are the same
  /// answer.
  ///
  /// Lives here rather than in ApiManager because api.dart already imports
  /// this file, and reaching back the other way would make the first mutual
  /// import in the singleton layer for the sake of twelve lines. It is also
  /// server lifecycle, not library browsing — the same reason _probeTunnel is
  /// here.
  /// Ask `GET /api/` who the server is. Null when it won't say — which the
  /// caller treats as "older than 5.4.2", the release that added the route.
  ///
  /// package:http, like the ping right above it, NOT dart:io's HttpClient.
  /// The HttpClient version failed on every iroh server while the ping over
  /// the same tunnel succeeded in the same call — an app pinned to a 6.20
  /// server sat on "Server version unknown" with an update warning under it.
  /// The pairing flow proves the URL itself is fine: add_server fetches
  /// `/api/?__lt=…` through the tunnel with package:http and requires a 200
  /// before it will save the server. Same URL, same token, different client,
  /// different answer — so the client was the variable worth removing.
  ///
  /// Logs its failures. This runs unattended and its only visible symptom is
  /// a version that never appears, which is indistinguishable from an old
  /// server unless something says otherwise.
  /// Probe `GET /api/` for the server's version. [notFound] is true only for
  /// a 404 — the one answer that genuinely means "pre-5.4.2, the endpoint
  /// does not exist". Every other empty outcome (timeout, connection failure,
  /// an auth layer answering for the route, junk body) is a FAILED probe, not
  /// evidence of age — the two used to collapse into one null, and a blip at
  /// add time toasted "older than 5.5" at a current server.
  Future<({String? version, bool notFound})> fetchServerVersion(
      Server s) async {
    try {
      final resp = await http.get(
        s.apiUri('/api/'),
        // The route is public, but something in front of it on an iroh
        // connection is not: the probe came back 401 over the tunnel while
        // the ping in the same call — identical URL builder, but carrying
        // this header — came back 200. Sent unconditionally; a plain HTTP
        // server ignores it on a route that never asked.
        headers: {'x-access-token': s.authToken ?? ''},
      ).timeout(const Duration(seconds: 8));
      if (resp.statusCode > 299) {
        // 404 is the expected answer from a pre-5.4.2 server, not a fault.
        if (resp.statusCode != 404) {
          appLog('[api] version probe ${s.localname} → '
              'HTTP ${resp.statusCode}');
        }
        return (version: null, notFound: resp.statusCode == 404);
      }
      final decoded = jsonDecode(resp.body);
      final v = decoded is Map ? decoded['server'] : null;
      if (v is String && v.trim().isNotEmpty) {
        return (version: v.trim(), notFound: false);
      }
      appLog('[api] version probe ${s.localname} → no version in response');
      return (version: null, notFound: false);
    } catch (e) {
      appLog('[api] version probe ${s.localname} failed: $e');
      return (version: null, notFound: false);
    }
  }

  /// Ground-truth tunnel liveness: one HTTP round-trip through the loopback
  /// (listener → QUIC stream → server → back). Any HTTP response — even an
  /// error status — proves the path; only a connect failure/timeout means
  /// dead. A FRESH client per probe is load-bearing: the shim authenticates
  /// per TCP connection, and a pooled socket would test yesterday's
  /// connection instead of the tunnel. Returns WHY it failed, classified by
  /// [TunnelPolicy.classifyProbeError], because "refused", "reset" and
  /// "timeout" are three different tunnel states.
  Future<({bool ok, String reason, int ms})> _probeTunnel(Server s) async {
    final sw = Stopwatch()..start();
    final client = HttpClient()
      ..connectionTimeout = TunnelTiming.probeLoopbackTimeout;
    try {
      final req = await client
          .getUrl(s.apiUri('/api/v1/ping'))
          .timeout(TunnelTiming.probeLoopbackTimeout);
      final resp =
          await req.close().timeout(TunnelTiming.probeResponseTimeout);
      await resp.drain<void>();
      return (
        ok: true,
        reason: 'http ${resp.statusCode}',
        ms: sw.elapsedMilliseconds
      );
    } catch (e) {
      return (
        ok: false,
        reason: TunnelPolicy.classifyProbeError(e),
        ms: sw.elapsedMilliseconds
      );
    } finally {
      client.close(force: true);
    }
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
    } else if (_startRejected && _activeTunnelCode == null) {
      // A cold dial answered "NO": no native tunnel exists to say so, but the
      // banner must offer Repair, not Retry.
      st = IrohTunnelStatus.rejected;
    } else {
      st = IrohTunnel.instance.status;
    }
    final pk = (isIroh && !_tunnelStarting)
        ? IrohTunnel.instance.pathKind
        : IrohPathKind.unknown;
    final now = DateTime.now();
    if (st != _tunnelStatus.value) {
      final was = _notConnectedSince;
      final after = (st == IrohTunnelStatus.connected && was != null)
          ? ' after ${now.difference(was).inSeconds}s'
          : '';
      appLog('[iroh] status ${_tunnelStatus.value.name} → ${st.name}$after '
          'path=${pk.name} port=${_tunnelTargetServer()?.tunnelPort}');
      _tunnelStatus.add(st);
    }
    if (st == IrohTunnelStatus.connected) {
      _notConnectedSince = null;
      _kickedAt = null;
    } else if (isIroh) {
      _notConnectedSince ??= now;
    }
    if (pk != _pathKind.value) _pathKind.add(pk);
    // Native supervisor events (a binary with the events ring); nothing on
    // older binaries.
    for (final line in IrohTunnel.instance.drainEvents()) {
      appLog('[iroh-native] $line');
    }
    // Watchdog: a supervisor that is not converging although the relay is
    // reachable (or a kick that did not take) gets a fresh endpoint. Never in
    // a dead zone — see TunnelPolicy.shouldEscalate — and never more than one
    // rebuild per minute (_hardRebuild), so the 2s poll is a safe caller.
    final s = _tunnelTargetServer();
    if (s != null &&
        !_tunnelStarting &&
        _activeTunnelCode != null &&
        TunnelPolicy.shouldEscalate(
            native: IrohTunnel.instance.status,
            notConnectedFor: _since(_notConnectedSince),
            sinceKick: _since(_kickedAt),
            relayReachable: IrohTunnel.instance.relayOnline)) {
      unawaited(_hardRebuild(s,
          code: _activeTunnelCode,
          port: s.tunnelPort,
          reason: 'watchdog',
          user: false));
    }
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
    _notConnectedSince = null;
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
  /// Set [extendWhileDialing] false to make [timeout] a HARD deadline. The
  /// default keeps extending it while a dial is in flight — right for the
  /// playback and download paths, which would rather wait than fail — but a
  /// caller driving a UI needs a bound it can actually promise the user.
  Future<bool> awaitTunnelReady(
      {Server? server,
      Duration timeout = const Duration(seconds: 12),
      bool extendWhileDialing = true,
      String caller = '?',
      bool bypassBackoff = false}) async {
    // Default to the browsed server; callers on the playback path pass the
    // track's server (which the single tunnel may be serving instead). Either
    // way the wait is for the TRANSPORT's tunnel — a federated peer has none
    // of its own and is ready exactly when its parent is.
    final s = (server ?? currentServer)?.transportServer;
    if (!IrohTunnel.isSupported || s == null || !s.isIroh) return true;
    // A rejected cold dial leaves no native tunnel to report it; answer
    // before firing an ensure that would only re-dial into the rejection.
    if (_startRejected &&
        !bypassBackoff &&
        s.localname == _tunnelTargetServer()?.localname) {
      return false;
    }
    unawaited(ensureActiveTunnel(
        verify: true, reason: 'await-ready:$caller', bypassBackoff: bypassBackoff));
    // start() can take ~30s; don't report not-ready while a dial is in flight
    // — or while an ensure is still queued behind one (a rebuild's fresh dial
    // runs after the drop). Keep extending the window while so, bounded by a
    // hard cap that fits two full attempts.
    final hardCap = DateTime.now().add(extendWhileDialing
        ? const Duration(seconds: 90)
        : const Duration(seconds: 45));
    var deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline) && DateTime.now().isBefore(hardCap)) {
      // Ready only when the tunnel is connected AND serving THIS server — with one
      // tunnel, a different server being served means s isn't reachable yet.
      if (tunnelServes(s)) return true;
      if (tunnelAssignedTo(s) &&
          IrohTunnel.instance.status == IrohTunnelStatus.rejected) {
        return false; // this server's code was rejected (needs re-pair)
      }
      // A rejected cold dial leaves no native tunnel to report it.
      if (_startRejected &&
          s.localname == _tunnelTargetServer()?.localname) {
        return false;
      }
      if (extendWhileDialing && (_tunnelStarting || _pendingEnsures > 0)) {
        deadline = DateTime.now().add(timeout);
      }
      await Future.delayed(const Duration(milliseconds: 300));
    }
    return tunnelServes(s);
  }

  bool _reverifying = false;

  /// Ground-truth check for a tunnel that REPORTS connected while nothing can
  /// actually stream through it — the shim only flips to reconnecting once the
  /// QUIC connection's close arrives (≤30s idle timeout), so a link that
  /// vanished underneath it keeps claiming to be up, and the playback heal
  /// fires on a status TRANSITION that therefore never comes.
  ///
  /// Probes the loopback and, only when the probe fails, hands the tunnel to
  /// [_remedyDeadTunnel] (kick in place when the binary can, else a hard
  /// rebuild rate-limited to one per minute). A passing probe means the tunnel
  /// is fine and the failures were the source's own problem, so nothing moves.
  Future<void> reverifyTunnel(Server server) async {
    // Probe the transport: a peer's failures happen on its parent's tunnel.
    final s = server.transportServer;
    if (!IrohTunnel.isSupported || s == null || !s.isIroh || _reverifying) {
      return;
    }
    if (_activeTunnelCode == null || s.tunnelPort == null) return;
    // Already known down: ensureActiveTunnel / awaitTunnelReady own that case
    // and this would only race them.
    if (!tunnelServes(s)) return;
    final gap = _since(_lastHardRebuildAt);
    if (gap != null && gap < TunnelTiming.hardRebuildMinGap) return;
    _reverifying = true;
    try {
      final code = _activeTunnelCode;
      final port = s.tunnelPort;
      final r = await _probeTunnel(s);
      if (r.ok) {
        appLog('[iroh] tunnel probe passed (${r.reason}, ${r.ms}ms) — '
            'the failures were not the path');
        return;
      }
      if (!tunnelServes(s)) {
        appLog('[iroh] probe failed (${r.reason}) but the supervisor '
            'noticed meanwhile — leaving it');
        return;
      }
      appLog('[iroh] tunnel says connected but the probe failed '
          '(${r.reason}, ${r.ms}ms) after repeated load failures');
      await _remedyDeadTunnel(s,
          code: code, port: port, reason: 'reverify', user: false);
    } finally {
      _reverifying = false;
    }
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
      // The swap runs on the chain (invariant 1) so an in-flight ensure can't
      // record the OLD code as the one it dialed.
      await _mutateTunnel('repair', () {
        s.irohPairingCode = code;
        _stopTunnel('repair');
        s.tunnelPort = null;
        s.tunnelToken = null;
        _startRejected = false;
        _cancelRetry();
      });
      await ensureActiveTunnel(
          verify: true, reason: 'repair', bypassBackoff: true);
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
      _cancelRetry();
      _startRejected = false;
      _lastFailedDialAt = null;
    }).catchError((_) {});
  }

  Future<void> removeServer(
      Server removeThisServer, bool removeSyncedFiles) async {
    serverList.remove(removeThisServer);
    // A peer is only reachable through its parent, so removing the parent
    // removes them too — leaving them would strand entries that can no longer
    // resolve a URL. Done before the queue cleanup below so their tracks go in
    // the same sweep.
    final orphans = federatedChildren(removeThisServer);
    serverList.removeWhere(orphans.contains);
    _serverListStream.sink.add(serverList);
    // Deleting a server also deletes its queued tracks — they can't stream
    // anymore and their metadata context (ratings, art, URL re-resolution)
    // went with it. Done before ensureActiveTunnel so no tunnel is kept
    // alive for tracks that are about to disappear.
    // Caught here on purpose: everything below persists the shortened server
    // list and re-points the tunnel. Letting this throw past would skip
    // writeServerFile, and the server the user just deleted would be back on
    // the next launch.
    try {
      for (final gone in [removeThisServer, ...orphans]) {
        await MediaManager()
            .audioHandler
            .removeServerQueueItems(gone.localname);
      }
    } catch (err) {
      appLog('[server] clearing queued tracks failed: $err');
    }
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
    } else if (!serverList.contains(currentServer)) {
      // The active server went — either it IS the one being removed, or it was
      // one of its peers, swept out with it.
      currentServer = serverList[0];
      // clear the browser
      BrowserManager().goToNavScreen();
      _currentServerStream.sink.add(currentServer);
    }

    // Start/stop the tunnel to match the (possibly changed) active server.
    await ensureActiveTunnel(reason: 'remove-server');
    await writeServerFile();
    syncInsecureTls();
    // Pooled keep-alive sockets to the removed server would otherwise linger.
    ApiManager().resetDirectClient();
  }

  Future<void> callAfterEditServer() async {
    _serverListStream.sink.add(serverList);
    syncInsecureTls();
    await writeServerFile();
    // The edit may have changed URL/credentials — drop pooled connections so
    // nothing rides a socket opened under the old identity.
    ApiManager().resetDirectClient();
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
    await _settleTunnelForSwitch('make-default');

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

  // ─── Federation ──────────────────────────────────────────────────────────
  // A federated server stands in for one PEER of a configured server, reached
  // through that parent's browse proxy (mStream #927). It is an ordinary entry
  // in [serverList] — which is what makes the picker, queue restore and the
  // download folder work without a parallel code path — but it owns no
  // transport, credentials or peer list of its own.

  /// Point every federated server at its live parent. Must run after the list
  /// is read and after anything that changes it: [Server.parentServer] is
  /// runtime-only, and every federated URL resolves through it.
  void _linkFederatedParents() {
    for (final s in serverList) {
      if (s.isFederated) s.parentServer = byLocalname(s.federationParent);
    }
  }

  /// The federated servers reached through [parent].
  List<Server> federatedChildren(Server parent) => serverList
      .where((s) => s.isFederated && s.federationParent == parent.localname)
      .toList();

  Server? _childByPeerId(Server parent, int peerId) {
    for (final s in serverList) {
      if (s.isFederated &&
          s.federationParent == parent.localname &&
          s.federationPeerId == peerId) {
        return s;
      }
    }
    return null;
  }

  /// Hide a peer from the picker (or show it again). Hiding the server that
  /// is being browsed moves the browser to its parent first — the peer is
  /// still addressable (queued tracks keep playing), it just stops being
  /// offered.
  Future<void> setFederatedHidden(Server s, bool hidden) async {
    if (!s.isFederated || s.federationHidden == hidden) return;
    s.federationHidden = hidden;
    if (hidden && identical(s, currentServer)) {
      final parent = s.parentServer;
      final idx = parent == null ? -1 : serverList.indexOf(parent);
      await changeCurrentServer(idx >= 0 ? idx : 0);
    }
    _serverListStream.sink.add(serverList);
    await writeServerFile();
  }

  /// Follow a parent's rename through to its peers. [Server.federationParent]
  /// stores the parent's localname, and the edit screen lets the user change
  /// it; without this the children would point at a name nothing answers to.
  void renameFederationParent(String oldName, String newName) {
    if (oldName == newName) return;
    for (final s in serverList) {
      if (s.federationParent == oldName) s.federationParent = newName;
    }
    _linkFederatedParents();
  }

  /// `GET /api/v1/federation/peers` on [parent] — the read-only projection any
  /// logged-in user may read (never api_key or the endpoint ticket) — folded
  /// into the servers we already hold for that parent.
  ///
  /// A mirror, not a source: peers are the parent admin's data. New ones
  /// appear, renames follow, and a peer that stops being listed is FLAGGED,
  /// not deleted — a queued track and a downloaded file both point at its
  /// localname, so deleting the record would strand them. It goes when the
  /// user says so, or with its parent.
  Future<void> refreshFederatedPeers(Server parent) async {
    if (parent.isFederated) return; // a peer has no peers of its own
    final List peers;
    try {
      final response = await http.get(
        parent.apiUri('/api/v1/federation/peers'),
        headers: {'x-access-token': parent.authToken ?? ''},
      ).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) {
        appLog('[federation] peer list on ${parent.localname} -> '
            'HTTP ${response.statusCode}');
        return;
      }
      final decoded = jsonDecode(response.body);
      final raw = decoded is Map ? decoded['peers'] : null;
      if (raw is! List) return;
      peers = raw;
    } catch (err) {
      appLog('[federation] peer list on ${parent.localname} failed: $err');
      return;
    }

    bool changed = false;
    final Set<int> listed = {};
    for (final p in peers) {
      if (p is! Map) continue;
      final id = p['id'];
      final name = p['name'];
      if (id is! int || name is! String || name.isEmpty) continue;
      listed.add(id);

      final existing = _childByPeerId(parent, id);
      if (existing == null) {
        final fresh = _newFederatedServer(parent, id, name);
        serverList.add(fresh);
        await _ensureDownloadDir(fresh);
        changed = true;
        continue;
      }
      // A rename on the parent is just a new label; the localname (and so the
      // download folder and every queued track) deliberately stays put.
      if (existing.federationPeerName != name || existing.federationMissing) {
        existing.federationPeerName = name;
        existing.federationMissing = false;
        changed = true;
      }
    }

    for (final child in federatedChildren(parent)) {
      final gone = !listed.contains(child.federationPeerId);
      if (gone != child.federationMissing) {
        child.federationMissing = gone;
        changed = true;
      }
    }

    if (!changed) return;
    _linkFederatedParents();
    _serverListStream.sink.add(serverList);
    await writeServerFile();
    // Capabilities for anything new or newly back: one /api through the proxy.
    for (final child in federatedChildren(parent)) {
      if (!child.federationMissing) unawaited(getServerPaths(child));
    }
  }

  /// A Server standing in for peer [id] of [parent], named [name].
  ///
  /// Storage follows the parent so a peer's downloads land beside it. The
  /// capabilities start at the federated floor rather than unknown: the
  /// allowlist already rules them out, and leaving transcodeAvailable null
  /// would send the first stream URL to /transcode optimistically.
  Server _newFederatedServer(Server parent, int id, String name) {
    final s = Server('federated://${parent.localname}/$id', null, null, null,
        _federatedLocalname(name))
      ..federationParent = parent.localname
      ..federationPeerId = id
      ..federationPeerName = name
      ..parentServer = parent
      ..storageMode = parent.storageMode
      ..storageBasePath = parent.storageBasePath;
    _applyFederatedDefaults(s);
    return s;
  }

  /// Pin the capabilities a federated server cannot have, whatever the peer
  /// says about itself.
  ///
  /// A peer's answer describes what IT can do; the federation allowlist decides
  /// what we can reach through the parent's proxy, and it is the narrower of
  /// the two. /transcode, every /api/v1/discovery/* route and every playlist
  /// route are off it — so a peer reporting working ffmpeg or a finished
  /// discovery scan would otherwise light up UI whose requests can only 403.
  void _applyFederatedDefaults(Server server) {
    server.transcodeAvailable = false;
    server.transcodeDefaultCodec = null;
    server.transcodeDefaultBitrate = null;
    server.discoveryAvailable = false;
    server.discoveryP2pAvailable = false;
    server.federationDiscoveryAvailable = false;
    server.discoveryPathAvailable = false;
    server.playlists.clear();
  }

  /// A stable, unique, filesystem-safe download-folder name for a peer.
  ///
  /// This server's OWN name, never derived from the parent's: localname keys
  /// queue restore and `media/<localname>`, and the parent's localname is
  /// user-editable — deriving from it would force a folder migration for every
  /// child on a rename. Suffixed on collision because two parents can each have
  /// a peer called "home".
  String _federatedLocalname(String peerName) {
    final slug = peerName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    final base = slug.isEmpty ? 'peer' : 'peer-$slug';
    for (int n = 1;; n++) {
      final candidate = n == 1 ? base : '$base-$n';
      if (byLocalname(candidate) == null) return candidate;
    }
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

  /// Sync the native per-host TLS bypass (ExoPlayer streaming) to the hosts of
  /// servers that opted into self-signed — only those hosts skip validation;
  /// everything else keeps platform TLS. No-op on the Play build. Call whenever
  /// the server list changes.
  void syncInsecureTls() {
    final hosts = <String>{};
    for (final s in serverList) {
      if (!s.allowSelfSigned) continue;
      try {
        final host = Uri.parse(s.url).host;
        if (host.isNotEmpty) hosts.add(host);
      } catch (_) {}
    }
    InsecureTlsChannel.setAllowedHosts(hosts);
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
