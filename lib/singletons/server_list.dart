import 'package:flutter/foundation.dart' show visibleForTesting;
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:mstream_music/singletons/file_explorer.dart';

import '../objects/server.dart';
import '../objects/direct_access.dart';
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
import './tunnel_handle.dart';
import './media.dart';
import './queue_store.dart';

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:rxdart/rxdart.dart';
import 'package:http/http.dart' as http;

class ServerManager {
  final List<Server> serverList = [];
  Server? currentServer;

  // ── Native tunnels: one TunnelHandle per TRANSPORT server ──
  // A Quick Connect server today; a directly-reached federated peer next.
  // Keyed by the transport's localname. Each handle owns its own dial chain,
  // retry ladder, probe bookkeeping and watchdog — the rules (tunnel_policy)
  // and the calls (below) are the same for every handle, so a second tunnel
  // is a second entry here, not a second copy of the lifecycle.
  final Map<String, TunnelHandle> _tunnels = {};

  // The servers the play queue references (pushed by the audio handler on
  // every queue edit) — held as the item's own server, not its transport,
  // because a federated peer's transport changes with its mode — and the
  // release timers for the ones it let go of.
  final Map<String, Server> _queueServers = {};
  final Map<String, Timer> _queueReleaseTimers = {};

  // ── Manager-wide reconnect bookkeeping (the rules live in tunnel_policy.dart) ──
  // Single-flight handleNetworkChange: a burst (app resume + a connectivity
  // event) runs once, plus one re-run if anything landed while it was busy.
  Future<void>? _networkChangeInFlight;
  bool _networkChangeRerun = false;
  String _rerunReason = '';
  // A Retry tap that lands while a network change is in flight must not be
  // downgraded to an automatic re-run.
  bool _rerunUser = false;
  // Last `[none]` connectivity event, to tell a modem re-attach from a hand-off.
  DateTime? _lastOfflineAt;
  // Servers whose launch-time capability refresh skipped because their
  // TRANSPORT's tunnel was not up: the iroh server itself, and any federated
  // peer riding it. A set, not a slot — one dial serves all of them.
  final Set<String> _pingPendingFor = {};

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
      currentServer = firstSelectable(serverList);
      // An iroh default: bring its tunnel up BEFORE the browser queries it —
      // bounded: a cold dial in a dead zone takes up to ~43s and the retry
      // loop owns failures, so launch must not wait on it. The dial keeps
      // running on the chain; the first browse/playback awaits the tunnel
      // itself. A standard default needs nothing and must not wait on the
      // chain either (a queued iroh server's dial may already be running on it).
      if (currentServer!.isIrohTransport) {
        await ensureTunnelFor(currentServer!.transportServer!,
                reason: 'launch', bypassBackoff: true)
            .timeout(const Duration(seconds: 12), onTimeout: () {});
      }
      // A federated default worth dialing directly gets its own tunnel next
      // to the parent's; nothing else changes here.
      unawaited(ensureTunnels(reason: 'launch'));
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
          setQueueIrohServers([rs]);
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


  Future<void> addServer(Server newServer) async {
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
    // The strip follows the browsed server's tunnel: recompute before the
    // banner rebuilds on the emission below.
    _refreshStatusNow();
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
      unawaited(ensureTunnels(reason: reason, bypassBackoff: true));
      return;
    }
    await ensureTunnelFor(s.transportServer!,
        reason: reason, bypassBackoff: true);
    // Release whatever the switch left behind (nothing else references it).
    unawaited(ensureTunnels(reason: reason));
    BrowserManager().goToNavScreen();
    unawaited(getServerPaths(s));
  }

  Future<void> getServerPaths(Server server, {bool throwErr = false}) async {
    // Whatever actually carries this server's bytes: the parent's tunnel for
    // a federated peer on the proxy path, the peer's own once it is direct.
    final transport = server.transportServer;
    // A federated server whose parent isn't linked yet can't be addressed at
    // all; every URL would resolve to the unroutable origin.
    if (transport == null) {
      if (throwErr) throw Exception('federation parent not linked');
      return;
    }
    // A tunnel server can only be reached through its live tunnel.
    if (transport.ownsTunnel && transport.tunnelPort == null) {
      // At launch this fires for the ACTIVE server too: loadServerList pings
      // every server as soon as the list is read, and the tunnel is still
      // dialling. Skipping meant its capabilities and — since the version
      // probe rides along here — its VERSION were never fetched at all, so an
      // iroh server sat on "version unknown" with an update warning under it
      // until something else happened to re-ping.
      //
      // Bounded, and only for the active server: another iroh server's
      // tunnel is not dialed for a capability refresh, so waiting on it would
      // stall the launch sweep for nothing. extendWhileDialing:false keeps
      // the bound real — the default re-arms for as long as a dial is in
      // flight.
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
      final bool? prevFedDirect = server.federationDirectAvailable;
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
          server.federationDirectAvailable != prevFedDirect ||
          server.discoveryPathAvailable != prevDiscoveryPath) {
        unawaited(writeServerFile());
      }
      // The parent just started offering direct access: any peer of it that
      // is browsed or queued is worth a tunnel of its own right away.
      if (server.federationDirectAvailable == true && prevFedDirect != true) {
        unawaited(ensureTunnels(reason: 'direct-available'));
      }

      // Peers are the parent's data, so only a parent reconciles them — and
      // only when it says it has some (flags, never probes). The flag going
      // OFF is information too: the parent removed its last peer, or switched
      // federation off. Either way nothing we hold for it is reachable any
      // more, so the peers we have are reconciled against an empty list —
      // flagged missing, and the browser moved off one being browsed.
      if (!server.isFederated) {
        if (scoped?['federationBrowse'] == true) {
          unawaited(refreshFederatedPeers(server));
        } else if (scoped != null && federatedChildren(server).isNotEmpty) {
          unawaited(_reconcilePeers(server, const []));
        }
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
    server.federationDirectAvailable =
        user is Map && user['federationDirect'] == true;
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
    server.federationDirectAvailable = res['federationDirect'] == true;
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

  // ═══════════════════════════════════════════════════════════════════════
  // Native tunnels — one TunnelHandle per transport server
  // ═══════════════════════════════════════════════════════════════════════
  //
  // Which servers need a tunnel: the browsed server's transport when that is
  // an iroh server, plus every iroh transport the play queue references
  // (tunnel-follows-queue: a queued Quick Connect track keeps its tunnel up
  // while a standard server is browsed). One handle per such transport, in
  // [_tunnels]; a handle whose server drops out of that set is stopped — on
  // the queue side after [TunnelTiming.queueReleaseGrace].
  //
  // Invariants (hold them when touching anything below):
  //  1. Every native mutation for a handle — start, stop, kick, code swap —
  //     runs on THAT handle's chain. Probes may run outside it, but a
  //     consequence of a probe re-checks the tunnel identity (code, port)
  //     inside the chain before acting (see TunnelHandle.sameTunnel).
  //  2. A native tunnel reporting `reconnecting` is never stopped unless the
  //     user asked (Retry) or the watchdog says the relay is reachable and
  //     the supervisor is not converging.
  //  3. A handle's port / token / code change only inside its chain; a kick
  //     leaves all three unchanged.
  //  4. While a server is a target and no native tunnel exists for it, a
  //     retry Timer is armed (unless the pairing was rejected). There is no
  //     "down with nothing scheduled" state.
  //  5. At most one hard rebuild per hardRebuildMinGap per handle; a
  //     user-initiated Retry/Repair bypasses the gap.
  //  6. Handles are independent: one server's cold dial never delays
  //     another's, and a decision about one never stops another.

  /// The transports that need a tunnel right now: for every referenced
  /// server (browsed, or holding queued tracks) the Quick Connect server
  /// itself, or — for a federated peer — the peer's own tunnel when it is
  /// worth dialing directly, plus the parent's while the peer is not direct
  /// yet (and whenever it is not), since the proxy path serves until then.
  Set<Server> _tunnelTargets() {
    final out = <Server>{};
    void add(Server? referenced) {
      if (referenced == null) return;
      if (referenced.isFederated) {
        if (_directWanted(referenced)) out.add(referenced);
        final parent = referenced.parentServer;
        // The parent's tunnel carries the proxy path until the peer is
        // direct, and the access call whenever the peer's guest ticket has
        // to be fetched again (stale, or refused by the peer).
        if (parent != null &&
            parent.isIroh &&
            (!referenced.isDirect ||
                _directTicketStale(referenced) ||
                _directRefused(referenced))) {
          out.add(parent);
        }
        return;
      }
      if (referenced.isIroh) out.add(referenced);
    }

    add(currentServer);
    for (final q in _queueServers.values) {
      add(q);
    }
    return out;
  }

  /// Whether [peer] should have a tunnel of its own: its parent offers
  /// direct access (the `federationDirect` flag), nobody declined for this
  /// peer this session, and the parent still lists it.
  bool _directWanted(Server peer) {
    final parent = peer.parentServer;
    return IrohTunnel.isSupported &&
        parent != null &&
        parent.federationDirectAvailable == true &&
        !peer.directDenied &&
        !peer.federationMissing;
  }

  /// The peer's own tunnel is up but its supervisor gave up on the guest
  /// token (the peer answered "NO"): a refresh through the parent is due.
  bool _directRefused(Server peer) {
    final h = _tunnels[peer.localname];
    return h != null &&
        h.assigned &&
        _nativeStatusOf(h) == IrohTunnelStatus.rejected;
  }

  bool _directTicketStale(Server peer) => TunnelPolicy.directTicketStale(
      fetchedAt: peer.directFetchedAt,
      expiresAt: peer.directExpiresAt,
      now: DateTime.now());

  bool _isTarget(Server transport) =>
      _tunnelTargets().any((t) => t.localname == transport.localname);

  TunnelHandle? _handleFor(Server s) {
    final t = s.transportServer;
    return t == null ? null : _tunnels[t.localname];
  }

  TunnelHandle _handleOf(Server transport) =>
      _tunnels.putIfAbsent(transport.localname, () => TunnelHandle(transport));

  /// The tunnel the status strip and the repair sheet talk about (see
  /// [bannerTargetAmong]).
  Server? _bannerTarget() => bannerTargetAmong(
        browsed: currentServer?.transportServer,
        background: [
          // A peer's handle that is still an ATTEMPT (dialing, or refused)
          // serves nothing yet — the proxy does — so its state is not the
          // user's problem and must not put Repair/Retry on the strip.
          for (final h in _tunnels.values)
            if (!h.server.isFederated || h.server.isDirect)
              (server: h.server, status: _effectiveStatus(h)),
        ],
      );

  /// True when some tunnel has a server to serve. Drives the status strip,
  /// which must show for a background tunnel even while a standard server is
  /// the selected one.
  bool get tunnelActive => _bannerTarget() != null;

  /// Record the servers the play queue references ([servers], any kind — the
  /// tunnel-carried ones are picked out here). No-op for an unchanged set;
  /// otherwise re-evaluates the targets. Called by the audio handler on
  /// queue changes.
  ///
  /// A transport that dropped out is released after
  /// [TunnelTiming.queueReleaseGrace], not at once: the handler's initial
  /// empty queue, a restore and a clear-then-refill all pass through
  /// "nothing from the iroh server queued" for a moment, and an immediate
  /// release tore a launch tunnel down mid-dial (a full rebuild — new port,
  /// reloaded URLs — seconds later). A server arriving inside the grace
  /// period simply cancels its release.
  void setQueueIrohServers(Iterable<Server> servers) {
    final next = <String, Server>{};
    for (final s in servers) {
      if (s.isIroh || s.isFederated) next[s.localname] = s;
    }
    var changed = false;
    for (final e in next.entries) {
      _queueReleaseTimers.remove(e.key)?.cancel();
      if (!_queueServers.containsKey(e.key)) {
        _queueServers[e.key] = e.value;
        changed = true;
      }
    }
    for (final name in _queueServers.keys.toList()) {
      if (next.containsKey(name) || _queueReleaseTimers.containsKey(name)) {
        continue;
      }
      _queueReleaseTimers[name] = Timer(TunnelTiming.queueReleaseGrace, () {
        _queueReleaseTimers.remove(name);
        final was = _queueServers.remove(name);
        if (was == null) return;
        appLog('[iroh] queue no longer references ${was.localname} — '
            'releasing its tunnel');
        unawaited(ensureTunnels(reason: 'queue-server'));
      });
    }
    if (!changed) return;
    // No backoff bypass: this fires from the launch queue restore as well as
    // from a user queuing songs, and a bypass here re-dialed a REJECTED code
    // 0.3s after the launch dial was refused (simulator run 2026-09-01).
    // When nothing failed it dials right away; otherwise the timer owns it.
    unawaited(ensureTunnels(reason: 'queue-server'));
  }

  /// True when a tunnel is assigned to [s]'s transport (regardless of its
  /// connection state) — i.e. the one its port and token were recorded for.
  ///
  /// Answered for the TRANSPORT: a federated peer is served exactly when its
  /// parent's tunnel is, so every caller may pass whichever server it holds.
  bool tunnelAssignedTo(Server s) {
    final h = _handleFor(s);
    return h != null &&
        h.assigned &&
        h.code == TunnelHandle.credentialFor(h.server);
  }

  /// True when the tunnel for [s] is assigned AND reports connected — i.e.
  /// [s]'s loopback is live right now.
  bool tunnelServes(Server s) =>
      tunnelAssignedTo(s) &&
      _nativeStatusOf(_handleFor(s)!) == IrohTunnelStatus.connected;

  /// The status of [s]'s tunnel as the UI should read it: `connecting`
  /// while a dial is in flight (the native side has nothing to report until
  /// it returns), `rejected` after a cold dial answered "NO" (no native
  /// tunnel exists to say so), else the native status — `down` when [s]
  /// rides no tunnel.
  IrohTunnelStatus tunnelStatusOf(Server s) {
    final h = _handleFor(s);
    return h == null ? IrohTunnelStatus.down : _effectiveStatus(h);
  }

  /// Direct-vs-relay path of [s]'s tunnel; unknown while dialing or without
  /// a tunnel.
  IrohPathKind pathKindOf(Server s) {
    final h = _handleFor(s);
    return (h == null || h.starting) ? IrohPathKind.unknown : _nativePathKindOf(h);
  }

  // ── Native reads for a handle (no key → nothing running) ──
  IrohTunnelStatus _nativeStatusOf(TunnelHandle h) => h.nativeKey == null
      ? IrohTunnelStatus.down
      : IrohTunnel.instance.statusOf(h.nativeKey!);
  IrohPathKind _nativePathKindOf(TunnelHandle h) => h.nativeKey == null
      ? IrohPathKind.unknown
      : IrohTunnel.instance.pathKindOf(h.nativeKey!);
  bool? _nativeRelayOnlineOf(TunnelHandle h) => h.nativeKey == null
      ? null
      : IrohTunnel.instance.relayOnlineOf(h.nativeKey!);
  List<String> _drainNativeEventsOf(TunnelHandle h) => h.nativeKey == null
      ? const []
      : IrohTunnel.instance.drainEvents(h.nativeKey!);

  IrohTunnelStatus _effectiveStatus(TunnelHandle h) {
    if (h.starting) return IrohTunnelStatus.connecting;
    // A cold dial answered "NO": no native tunnel exists to say so, but the
    // strip must offer Repair, not Retry.
    if (h.startRejected && h.nativeKey == null) return IrohTunnelStatus.rejected;
    final native = _nativeStatusOf(h);
    // A direct peer whose supervisor gave up on a refused guest token is
    // being refreshed from the parent (_maintainDirect), not re-paired:
    // "reconnecting" is what the user should read.
    if (h.server.isFederated && native == IrohTunnelStatus.rejected) {
      return IrohTunnelStatus.reconnecting;
    }
    return native;
  }

  // Logged once: the reason the native tunnel is unavailable while a server
  // needs it (a stale committed binary reports an ABI mismatch here).
  bool _loggedUnsupported = false;
  void _logUnsupportedOnce(String reason) {
    if (_loggedUnsupported || _tunnelTargets().isEmpty) return;
    _loggedUnsupported = true;
    appLog('[iroh] native tunnel unavailable ($reason): '
        '${IrohTunnel.unsupportedReason ?? 'no native library on this device'}');
  }

  /// Bring every tunnel in line with the targets: start one for each target
  /// that has none, leave the healthy ones alone, stop the ones nothing
  /// references any more. Each handle's work runs on its own chain, so a
  /// cold dial for one server never holds another. With [verify], a handle
  /// whose native tunnel is fully *down* despite our bookkeeping is rebuilt
  /// (the supervisor self-heals transient drops, so this only fires for a
  /// hard-down tunnel).
  ///
  /// [reason] is logged with every start/stop so the next incident log says
  /// who asked. [bypassBackoff] lets the retry timer and user-driven callers
  /// dial even when a cold dial failed moments ago; everything else waits for
  /// the timer (see [TunnelPolicy.shouldSkipColdDial]).
  Future<void> ensureTunnels(
      {bool verify = false,
      String reason = 'ensure',
      bool bypassBackoff = false}) {
    if (!IrohTunnel.isSupported) {
      _logUnsupportedOnce(reason);
      return Future.value();
    }
    final targets = _tunnelTargets();
    final targetNames = {for (final t in targets) t.localname};
    final work = <Future<void>>[
      for (final t in targets)
        ensureTunnelFor(t,
            verify: verify, reason: reason, bypassBackoff: bypassBackoff),
      for (final h in _tunnels.values.toList())
        if (!targetNames.contains(h.server.localname))
          _releaseHandle(h, 'no-target/$reason'),
    ];
    return Future.wait(work).then((_) {});
  }

  /// [ensureTunnels] for one transport: (re)start [transport]'s tunnel on
  /// its handle's chain, creating the handle if there is none. Callers on the
  /// playback and download paths ask for the server a track lives on, which
  /// is a target by construction; anything else gets a tunnel on demand that
  /// the next reconcile releases once nothing references it.
  Future<void> ensureTunnelFor(Server transport,
      {bool verify = false,
      String reason = 'ensure',
      bool bypassBackoff = false}) {
    if (!IrohTunnel.isSupported || !(transport.isIroh || transport.isFederated)) {
      return Future.value();
    }
    final h = _handleOf(transport);
    h.pendingEnsures++;
    _startStatusPolling();
    final next = h.chain
        .then((_) => _ensureHandle(h, verify, reason, bypassBackoff))
        .whenComplete(() => h.pendingEnsures--);
    h.chain = next.catchError((_) {});
    return next;
  }

  Future<void> _ensureHandle(
      TunnelHandle h, bool verify, String reason, bool bypassBackoff) async {
    final s = h.server;
    final name = s.localname;
    String? credential = TunnelHandle.credentialFor(s);
    if (h.assigned && credential != null && h.code == credential) {
      // Already wired up. The supervisor handles transient drops itself; only
      // rebuild on a verify when it's fully down (a reconnecting/rejected
      // tunnel is left alone — restarting wouldn't help).
      if (!verify || _nativeStatusOf(h) != IrohTunnelStatus.down) return;
    }
    // A cold dial answered "NO" (wrong/rotated secret): only a repair or a
    // user tap may dial again. Otherwise every automatic caller — a DJ pick
    // re-fired every ~30s, a playback error, a download — would re-dial
    // into the same rejection and flicker the strip Repair↔Connecting.
    if (!h.assigned && h.startRejected && !bypassBackoff) return;
    // No tunnel and a cold dial failed recently: the retry timer owns the
    // next attempt. Without this gate every caller that wants the tunnel
    // would queue its own 33–43s dial behind the last one, so a dead zone
    // became back-to-back radio time with no backoff at all.
    if (!h.assigned &&
        TunnelPolicy.shouldSkipColdDial(
            sinceFailedDial: _since(h.lastFailedDialAt),
            nextRetry: TunnelPolicy.retryDelay(h.retryAttempt),
            bypassBackoff: bypassBackoff)) {
      final now = DateTime.now();
      if (h.lastSkipLogAt == null ||
          now.difference(h.lastSkipLogAt!) >= const Duration(seconds: 60)) {
        h.lastSkipLogAt = now;
        appLog('[iroh] start skipped ($reason) — a dial failed '
            '${_since(h.lastFailedDialAt)!.inSeconds}s ago; '
            'retry #${h.retryAttempt + 1} owns the next attempt for=$name');
      }
      if (h.retryTimer == null && !h.startRejected) _scheduleRetry(h);
      return;
    }
    if (s.isFederated && !h.assigned) {
      // A peer's credential comes from its parent and expires: fetch it when
      // missing, stale, or the one the peer refused. Behind the gates above
      // on purpose — a parent that keeps failing is asked on the retry
      // ladder, not on every reconcile. (A tunnel that is UP refreshes in
      // place instead — _maintainDirect.)
      if (credential == null ||
          _directTicketStale(s) ||
          credential == h.refusedCredential) {
        final outcome = await _refreshDirectAccess(s,
            force: credential != null && credential == h.refusedCredential);
        credential = TunnelHandle.credentialFor(s);
        if (credential == null || credential == h.refusedCredential) {
          // Declined, unreachable, or the same refused token: the proxy
          // serves; a transient failure gets the retry ladder.
          if (outcome != DirectAccessOutcome.denied && _directWanted(s)) {
            h.lastFailedDialAt = DateTime.now();
            _scheduleRetry(h, note: ' — waiting for a guest token');
          }
          return;
        }
      }
    }
    if (credential == null) return;
    final code = credential;
    // A dead (verify) or re-paired tunnel is replaced: drop the old one first
    // (a start under a key that is still running returns its stale port).
    // NB: no cast fallback here. A renderer reaches a tunnel server through
    // the LAN proxy (LocalMediaServer), and a same-server rebuild keeps the
    // queue valid — rebuildTranscodeUrls below reloads the active backend,
    // cast included, onto the fresh port. Handles are independent, so
    // selecting another server never tears this tunnel out from under a
    // cast; only the queue letting go of it does, after the grace.
    if (h.assigned) _stopHandleTunnel(h, 'switch/$reason');
    h.starting = true;
    h.networkReturnedDuringDial = false;
    _refreshStatusNow(); // surface "Connecting…" while the dial runs
    final sw = Stopwatch()..start();
    final key = TunnelHandle.keyFor(s);
    try {
      final port = await IrohTunnel.instance.start(key, code);
      h.bind(
          key: key,
          credential: code,
          localPort: port,
          localToken: IrohTunnel.instance.localTokenOf(key));
      h.cancelRetry();
      h.startRejected = false;
      h.lastFailedDialAt = null;
      h.notConnectedSince = null;
      h.kickedAt = null;
      appLog('[iroh] tunnel up port=$port '
          'path=${_nativePathKindOf(h).name} '
          'in ${sw.elapsedMilliseconds}ms ($reason) for=$name');
      // The launch sweep no longer waits for a slow dial; run the ping it
      // skipped so vpaths / transcode / version are not stale all session.
      for (final pending in _pingPendingFor.toList()) {
        final ps = byLocalname(pending);
        if (ps == null) {
          _pingPendingFor.remove(pending);
        } else if (identical(ps.transportServer, s)) {
          _pingPendingFor.remove(pending);
          unawaited(getServerPaths(ps));
        }
      }
      // This bind set a loopback port + token. Any queued stream URL built
      // against this server before now is stale, so rebuild them off the
      // live effectiveBaseUrl. Unconditional on purpose: besides a port that
      // changed on a reconnect / re-pair, the queue can also be restored at
      // launch BEFORE the tunnel is up (a slow or failed first connect bakes
      // http://127.0.0.1:0 with no token), and the retry that finally
      // connects has no prior port — so a "changed-only" guard would skip
      // exactly the case that strands the saved queue. Only an actual
      // (re)start reaches here, and the rebuild no-ops for every URL that
      // did not change (other servers' included). auto:true → skipped while
      // casting: the cast backends re-resolve each track against the live
      // tunnel at load time (irohProxyUri), and a mid-session reload clobbers
      // the Cast SDK's own suspend/resume recovery.
      // A direct peer's proxy URLs still work while its own tunnel comes
      // up, so only UPCOMING items move over — the playing track keeps its
      // stream instead of reloading mid-song (a paused or idle one moves
      // too; see protectsCurrentTrack). And a peer that just went direct no
      // longer needs its parent's tunnel unless the parent is browsed or
      // queued itself: reconcile now rather than at the next queue edit.
      if (s.isFederated) unawaited(ensureTunnels(reason: 'direct-up'));
      unawaited(MediaManager()
          .audioHandler
          .customAction('rebuildTranscodeUrls',
              {'upcomingOnly': s.isFederated, 'auto': true})
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
      h.clearRuntime();
      h.lastFailedDialAt = DateTime.now();
      // The native side distinguishes a "NO" handshake (wrong/rotated secret,
      // or a refused guest token) from an unreachable server; only the
      // latter is worth retrying.
      h.startRejected = '$e'.contains('rejected');
      appLog('[iroh] tunnel start failed after ${sw.elapsedMilliseconds}ms '
          '($reason): $e for=$name');
      if (h.startRejected && s.isFederated) {
        // A refused GUEST token is not a pairing problem: it expired or its
        // key was rotated, and the parent is where a fresh one comes from.
        // Ask once; a new ticket gets a quick retry, a refusal to mint puts
        // the peer on the proxy for the session, anything else waits for
        // the ladder.
        h.refusedCredential = code;
        h.startRejected = false;
        final outcome = await _refreshDirectAccess(s, force: true);
        if (outcome == DirectAccessOutcome.issued) {
          _scheduleRetry(h,
              delay: TunnelTiming.retryAfterNetworkReturn,
              note: ' — fresh guest token');
        } else if (outcome != DirectAccessOutcome.denied) {
          _scheduleRetry(h, note: ' — guest token refused, refresh pending');
        }
      } else if (h.startRejected) {
        h.cancelRetry();
      } else {
        final next = TunnelPolicy.retryAfterFailedDial(
            attempt: h.retryAttempt,
            networkReturnedDuringDial: h.networkReturnedDuringDial);
        h.retryAttempt = next.attempt;
        _scheduleRetry(h,
            delay: next.delay,
            note: h.networkReturnedDuringDial
                ? ' — the network came back mid-dial'
                : '');
      }
    } finally {
      h.starting = false;
    }
    _refreshStatusNow();
  }

  Duration? _since(DateTime? t) =>
      t == null ? null : DateTime.now().difference(t);

  /// Run [fn] on [h]'s chain (invariant 1). Returns the chained future so the
  /// caller can await the mutation; the chain itself swallows errors.
  Future<void> _mutateHandle(
      TunnelHandle h, String reason, FutureOr<void> Function() fn) {
    final next = h.chain.then((_) => fn());
    h.chain = next.catchError((_) {});
    return next;
  }

  /// Stop [h]'s native tunnel and forget its assignment. ONLY from inside
  /// its chain (invariant 3).
  void _stopHandleTunnel(TunnelHandle h, String reason) {
    final had = h.nativeKey != null;
    if (had) {
      appLog('[iroh] tunnel stopped ($reason) port=${h.port} '
          'for=${h.server.localname}');
      IrohTunnel.instance.stop(h.nativeKey!);
    }
    h.clearRuntime();
    // A direct peer just went back to the proxy path: every queued URL on
    // its old loopback is dead, so rebuild them against the parent (which
    // rebuilds again when its own tunnel binds, if it has one).
    if (had && h.server.isFederated) {
      unawaited(MediaManager()
          .audioHandler
          .customAction('rebuildTranscodeUrls',
              const {'upcomingOnly': false, 'auto': true})
          .catchError((Object e) {
        appLog('[iroh] URL rebuild after the direct tunnel went failed: $e');
      }));
    }
  }

  /// Nothing references [h]'s server any more: stop its tunnel on its chain
  /// and drop the handle — unless an ensure is queued behind the stop, in
  /// which case something wants it back and the handle stays to serve that.
  /// Queued URLs that still ride the dropped loopback are rebuilt: a peer's
  /// tracks left on their parent's proxy port when the peer went direct
  /// (the playing one is left alone on the bind on purpose, and reloads at
  /// its spot here — a short gap instead of a dead source and a retry);
  /// otherwise a no-op. (Federated handles rebuild in _stopHandleTunnel.)
  Future<void> _releaseHandle(TunnelHandle h, String reason) =>
      _mutateHandle(h, reason, () {
        final carried = h.nativeKey != null && !h.server.isFederated;
        _stopHandleTunnel(h, reason);
        if (carried) {
          unawaited(MediaManager()
              .audioHandler
              .customAction('rebuildTranscodeUrls',
                  const {'upcomingOnly': false, 'auto': true})
              .catchError((Object e) {
            appLog('[iroh] URL rebuild after the release failed: $e');
          }));
        }
        h.cancelRetry();
        if (identical(_tunnels[h.server.localname], h) &&
            h.pendingEnsures == 0) {
          _tunnels.remove(h.server.localname);
        }
        _refreshBannerStatus();
      });

  /// Arm the retry after a failed cold dial (invariant 4). The attempt index
  /// is only reset by a success or a release, so a burst of callers cannot
  /// shorten the backoff.
  void _scheduleRetry(TunnelHandle h, {Duration? delay, String note = ''}) {
    h.retryTimer?.cancel();
    final d = delay ?? TunnelPolicy.retryDelay(h.retryAttempt);
    appLog('[iroh] retry #${h.retryAttempt + 1} in ${d.inSeconds}s$note '
        'for=${h.server.localname}');
    h.retryTimer = Timer(d, () {
      h.retryTimer = null;
      if (!_isTarget(h.server) ||
          h.assigned ||
          h.starting ||
          h.startRejected) {
        return;
      }
      h.retryAttempt++;
      unawaited(ensureTunnelFor(h.server,
          verify: true,
          reason: 'retry#${h.retryAttempt}',
          bypassBackoff: true));
    });
  }

  /// Called by the connectivity listener on a `[none]` result (invariant: the
  /// only place _lastOfflineAt is written).
  void noteConnectivityLost() {
    _lastOfflineAt = DateTime.now();
  }

  /// React to a device network change / app resume / the strip's Retry tap:
  /// nudge iroh to re-probe paths (it can't self-detect on Android), then let
  /// the pure [TunnelPolicy] decide per tunnel — leave a reconnecting one to
  /// its supervisor, probe a connected-reporting one for ground truth, or
  /// (re)start a missing one. Single-flight: overlapping calls (a resume plus
  /// a connectivity burst) coalesce into one run plus at most one re-run.
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
    if (!IrohTunnel.isSupported) return;
    final targets = _tunnelTargets();
    if (targets.isEmpty) return;
    IrohTunnel.instance.networkChanged();
    // A user's Retry means the tunnel on the strip; the rest get the
    // automatic treatment. Every target runs at once — a probe round takes
    // seconds and one tunnel's must not delay another's.
    final banner = _bannerTarget();
    await Future.wait([
      for (final t in targets)
        _handleNetworkChangeFor(_handleOf(t), reason,
            user && (banner == null || banner.localname == t.localname)),
    ]);
  }

  Future<void> _handleNetworkChangeFor(
      TunnelHandle h, String reason, bool user) async {
    final s = h.server;
    final name = s.localname;
    if (!user && reason.startsWith('connectivity:') && h.starting) {
      h.networkReturnedDuringDial = true;
    }
    final native = _nativeStatusOf(h);
    final code = h.code;
    final port = h.port;
    appLog('[iroh] network change ($reason) native=${native.name} port=$port '
        'notConnectedFor=${_since(h.notConnectedSince)?.inSeconds ?? 0}s '
        'for=$name');
    switch (TunnelPolicy.onNetworkChange(
        native: native,
        assigned: tunnelAssignedTo(s) && port != null,
        starting: h.starting,
        rejected: native == IrohTunnelStatus.rejected || h.startRejected,
        sinceOffline: _since(_lastOfflineAt),
        userInitiated: user)) {
      case NetworkChangeRemedy.leaveRejected:
        appLog('[iroh] pairing rejected — waiting for a repair, not '
            're-dialing for=$name');
        return;
      case NetworkChangeRemedy.leaveToSupervisor:
        appLog(native == IrohTunnelStatus.connected
            ? '[iroh] network just re-attached — leaving the connection to '
                'iroh for=$name'
            : '[iroh] leaving the reconnect to the supervisor for=$name');
        return;
      case NetworkChangeRemedy.escalate:
        // The strip's Retry while the supervisor re-dials: kick in place
        // first (same port — a fresh endpoint cold-dials into the same dead
        // zone and rotates every URL; Galaxy S25 round: 24s vs 8s); a second
        // tap inside the post-kick window gets the fresh endpoint.
        switch (TunnelPolicy.onUserEscalate(
            canKick: IrohTunnel.instance.hasKick,
            sinceKick: _since(h.kickedAt))) {
          case DeadTunnelRemedy.kick:
            await _kickTunnel(h, code: code, port: port, reason: reason);
          case DeadTunnelRemedy.hardRebuild:
          case DeadTunnelRemedy.wait:
            await _hardRebuild(h,
                code: code, port: port, reason: 'escalate/$reason', user: user);
        }
        return;
      case NetworkChangeRemedy.probe:
        if (await _probeTwice(h, code: code, port: port)) {
          await _remedyDeadTunnel(h,
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
        !h.assigned &&
        !h.starting &&
        h.lastFailedDialAt != null &&
        !h.startRejected) {
      // Clamp rather than zero: a flapping dead zone emits a transport event
      // every few minutes, and a full 5/10/20/40s ramp per event would keep
      // the radio busy; one quick attempt per event is enough.
      h.retryAttempt = h.retryAttempt.clamp(0, 1);
      _scheduleRetry(h);
      return;
    }
    await ensureTunnelFor(s, verify: true, reason: reason, bypassBackoff: user);
  }

  /// True only when two probes, spaced across iroh's migration window, both
  /// failed AND the tunnel is still the same one reporting connected. A
  /// supervisor that noticed the drop in between (status → reconnecting) owns
  /// the recovery, so that is a "false" too.
  Future<bool> _probeTwice(TunnelHandle h,
      {required String? code, required int? port}) async {
    final name = h.server.localname;
    final t0 = DateTime.now();
    await Future<void>.delayed(TunnelTiming.probeFirstDelay);
    if (!h.sameTunnel(code, port)) return false;
    final r1 = await _probeTunnel(h.server);
    appLog('[iroh] probe #1 ${r1.ok ? 'passed' : 'failed'} '
        '(${r1.reason}, ${r1.ms}ms, native=${_nativeStatusOf(h).name}) '
        'for=$name');
    if (r1.ok) return false;
    // "refused" on loopback is definitive — nothing listens on the port any
    // more. The second probe exists to tell a path migration from a zombie,
    // and a migration never refuses, so waiting for it would only add 7s to
    // every iOS thaw (iPhone X round: kick at +10s → +3s).
    if (TunnelPolicy.probeIsDefinitive(r1.reason) &&
        h.sameTunnel(code, port) &&
        _nativeStatusOf(h) == IrohTunnelStatus.connected) {
      return true;
    }
    final wait = TunnelTiming.probeSecondAt - DateTime.now().difference(t0);
    if (wait > Duration.zero) await Future<void>.delayed(wait);
    if (!h.sameTunnel(code, port) ||
        _nativeStatusOf(h) != IrohTunnelStatus.connected) {
      return false;
    }
    final r2 = await _probeTunnel(h.server);
    appLog('[iroh] probe #2 ${r2.ok ? 'passed' : 'failed'} '
        '(${r2.reason}, ${r2.ms}ms) for=$name');
    return !r2.ok;
  }

  /// A connected-reporting tunnel is dead (two probes, or repeated load
  /// failures): kick it in place when the binary can, else rebuild — rate
  /// limited, because a rebuild rotates the port and token.
  Future<void> _remedyDeadTunnel(TunnelHandle h,
      {required String? code,
      required int? port,
      required String reason,
      required bool user}) async {
    switch (TunnelPolicy.onProbeFailedTwice(
        canKick: IrohTunnel.instance.hasKick,
        sinceHardRebuild: _since(h.lastHardRebuildAt),
        sinceKick: _since(h.kickedAt),
        userInitiated: user)) {
      case DeadTunnelRemedy.kick:
        await _kickTunnel(h, code: code, port: port, reason: reason);
      case DeadTunnelRemedy.hardRebuild:
        await _hardRebuild(h,
            code: code,
            port: port,
            reason: 'dead/$reason',
            user: user,
            onlyIfConnected: !user);
      case DeadTunnelRemedy.wait:
        appLog('[iroh] tunnel dead but a rebuild ran '
            '${_since(h.lastHardRebuildAt)?.inSeconds}s ago — waiting '
            'for=${h.server.localname}');
    }
  }

  /// The in-place remedy: the native force-reconnect (network nudge, loopback
  /// listener re-bind, close + immediate re-dial) on the same port and token,
  /// so nothing built against the tunnel goes stale.
  Future<void> _kickTunnel(TunnelHandle h,
      {required String? code,
      required int? port,
      required String reason}) async {
    await _mutateHandle(h, 'kick/$reason', () {
      if (!h.sameTunnel(code, port)) return;
      h.kickedAt = DateTime.now();
      h.notConnectedSince ??= h.kickedAt;
      appLog('[iroh] kicking the tunnel in place ($reason) — port $port kept '
          'for=${h.server.localname}');
      IrohTunnel.instance.kick(h.nativeKey!);
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
  Future<void> _hardRebuild(TunnelHandle h,
      {required String? code,
      required int? port,
      required String reason,
      required bool user,
      bool onlyIfConnected = false}) async {
    final name = h.server.localname;
    final gap = _since(h.lastHardRebuildAt);
    if (!user && gap != null && gap < TunnelTiming.hardRebuildMinGap) {
      appLog('[iroh] hard rebuild ($reason) skipped — last one '
          '${gap.inSeconds}s ago for=$name');
      return;
    }
    var dropped = false;
    await _mutateHandle(h, 'drop/$reason', () {
      if (!h.sameTunnel(code, port)) return; // already rebuilt or dropped
      if (onlyIfConnected &&
          _nativeStatusOf(h) != IrohTunnelStatus.connected) {
        appLog('[iroh] rebuild ($reason) skipped — the supervisor took over '
            'for=$name');
        return;
      }
      h.lastHardRebuildAt = DateTime.now();
      _stopHandleTunnel(h, 'rebuild/$reason');
      dropped = true;
    });
    if (!dropped) return;
    await ensureTunnelFor(h.server,
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
  // ── Direct access to federated peers (issue #143) ──
  //
  // The parent hands out a guest ticket per peer (GET …/peers/:id/access —
  // objects/direct_access.dart); the peer's handle dials it like a pairing
  // code, on the federation ALPN. The ticket expires daily: a tunnel that is
  // up gets the new one swapped in place (same port, same queued URLs), a
  // refused one is asked for again rather than treated as a re-pair, and a
  // parent that declines puts the peer on the proxy for the session.

  /// Ask [peer]'s parent for direct access and record the answer on the
  /// peer. Waits (bounded) for the parent's own tunnel first when the
  /// parent is a Quick Connect server — the access call rides it.
  Future<DirectAccessOutcome> _refreshDirectAccess(Server peer,
      {bool force = false}) async {
    final parent = peer.parentServer;
    final id = peer.federationPeerId;
    if (parent == null || id == null) return DirectAccessOutcome.failed;
    final name = peer.localname;
    if (parent.isIroh && !tunnelServes(parent)) {
      // The parent is a target while this peer's ticket is due (see
      // _tunnelTargets), so nothing releases it under the call; it may just
      // not have been dialed yet.
      unawaited(ensureTunnelFor(parent, reason: 'direct-access'));
      await awaitTunnelReady(
          server: parent,
          timeout: const Duration(seconds: 12),
          extendWhileDialing: false,
          caller: 'direct-access');
      if (!tunnelServes(parent)) {
        appLog('[federation] $name: direct access needs ${parent.localname}\'s '
            'tunnel, which is not up');
        return DirectAccessOutcome.failed;
      }
    }
    try {
      final response = await http.get(
        parent.apiUri('/api/v1/federation/peers/$id/access'
            '${force ? '?refresh=1' : ''}'),
        headers: {'x-access-token': parent.authToken ?? ''},
      ).timeout(const Duration(seconds: 20));
      if (response.statusCode != 200) {
        appLog('[federation] $name: direct access on ${parent.localname} -> '
            'HTTP ${response.statusCode}');
        return DirectAccessOutcome.failed;
      }
      final body = jsonDecode(response.body);
      if (body is! Map) return DirectAccessOutcome.failed;
      final access = DirectAccess.fromJson(body);
      if (access == null) {
        peer.directDenied = true;
        appLog('[federation] $name: no direct access '
            '(${body['reason'] ?? 'declined'}) — staying on '
            '${parent.localname}\'s proxy');
        return DirectAccessOutcome.denied;
      }
      final changed = access.ticket != peer.directTicket;
      peer.directDenied = false;
      if (changed) {
        // The staleness clock starts at the fetch of a NEW ticket only: the
        // same one handed out again would otherwise look fresh again.
        peer
          ..directTicket = access.ticket
          ..directGuestToken = access.guestToken
          ..directEndpointId = access.endpointId
          ..directExpiresAt = access.expiresAt
          ..directFetchedAt = DateTime.now();
      }
      appLog('[federation] $name: direct access '
          '${changed ? 'issued' : 'unchanged'}, expires '
          '${access.expiresAt.toIso8601String()}');
      return changed ? DirectAccessOutcome.issued : DirectAccessOutcome.unchanged;
    } on FormatException catch (e) {
      appLog('[federation] $name: direct access answer unreadable: $e');
      return DirectAccessOutcome.failed;
    } catch (e) {
      appLog('[federation] $name: direct access failed: $e');
      return DirectAccessOutcome.failed;
    }
  }

  /// Poll-time upkeep for a direct peer's tunnel: re-fetch a ticket past
  /// three quarters of its life and swap it in place, and treat a supervisor
  /// that gave up on a refused token as "refresh it" — rate-limited, since a
  /// refresh is a round trip through the parent.
  void _maintainDirect(TunnelHandle h) {
    final s = h.server;
    if (!s.isFederated || !h.assigned || h.directRefreshing) return;
    final refused = _nativeStatusOf(h) == IrohTunnelStatus.rejected;
    final stale = _directTicketStale(s);
    if (!refused && !stale) return;
    // Rate-limit ATTEMPTS after a refusal, and only FAILED attempts for a
    // stale ticket — a renewal that worked must not delay the next one. A
    // ticket that has already run out (the parent was unreachable at the
    // scheduled point) is urgent: every request is failing, so ask on the
    // short gap.
    final expiresAt = s.directExpiresAt;
    final expired = expiresAt != null && !DateTime.now().isBefore(expiresAt);
    final gap = _since(refused ? h.directRefreshedAt : h.directRefreshFailedAt);
    final minGap = refused || expired
        ? TunnelTiming.directRefusedRetryGap
        : TunnelTiming.directRefreshMinGap;
    if (gap != null && gap < minGap) return;
    unawaited(_refreshDirectCredential(h,
        force: refused, why: refused ? 'refused' : 'stale'));
  }

  /// Fetch a fresh ticket for a peer whose tunnel is up and hand it to the
  /// native side in place — same port, same token, the queued URLs survive;
  /// only upcoming items take the new guest token. A parent that declines
  /// releases the tunnel (the proxy takes over); a swap the native side
  /// refuses (a different endpoint id) rebuilds instead.
  Future<void> _refreshDirectCredential(TunnelHandle h,
      {required bool force, required String why}) async {
    final s = h.server;
    final name = s.localname;
    h.directRefreshing = true;
    h.directRefreshedAt = DateTime.now();
    try {
      final before = s.directTicket;
      var outcome = await _refreshDirectAccess(s, force: force);
      if (outcome == DirectAccessOutcome.unchanged && !force) {
        // The parent's own cache is not due for a re-mint yet: make it.
        outcome = await _refreshDirectAccess(s, force: true);
      }
      if (!h.assigned || h.nativeKey == null) return;
      switch (outcome) {
        case DirectAccessOutcome.denied:
          appLog('[iroh] direct access withdrawn ($why) — back to the proxy '
              'for=$name');
          await _releaseHandle(h, 'direct-withdrawn');
          return;
        case DirectAccessOutcome.failed:
        case DirectAccessOutcome.unchanged:
          h.directRefreshFailedAt = DateTime.now();
          return; // try again after the gap
        case DirectAccessOutcome.issued:
          break;
      }
      final ticket = s.directTicket;
      if (ticket == null || ticket == before) return;
      try {
        IrohTunnel.instance.setCredential(h.nativeKey!, ticket);
        h.code = ticket;
        h.refusedCredential = null;
        h.directRefreshFailedAt = null;
        appLog('[iroh] guest credential refreshed in place ($why) for=$name');
        // The parent's tunnel was kept up for the access call; drop it if
        // nothing else wants it.
        unawaited(ensureTunnels(reason: 'direct-refreshed'));
        unawaited(MediaManager()
            .audioHandler
            .customAction('rebuildTranscodeUrls',
                const {'upcomingOnly': true, 'auto': true})
            .catchError((Object e) {
          appLog('[iroh] URL rebuild after the credential refresh failed: $e');
        }));
      } on IrohTunnelException catch (e) {
        appLog('[iroh] credential swap refused (${e.message}) — rebuilding '
            'for=$name');
        await _hardRebuild(h,
            code: h.code, port: h.port, reason: 'credential', user: true);
      }
    } finally {
      h.directRefreshing = false;
    }
  }

  /// The browse layer saw a 401 from a direct peer: its guest token is no
  /// longer honoured (expired early, or the key was rotated). Refresh it now
  /// rather than at the next scheduled point.
  Future<void> onDirectAuthRejected(Server server) async {
    if (!server.isDirect) return;
    final h = _tunnels[server.localname];
    if (h == null || h.directRefreshing) return;
    final gap = _since(h.directRefreshedAt);
    if (gap != null && gap < TunnelTiming.directRefusedRetryGap) return;
    await _refreshDirectCredential(h, force: true, why: '401');
  }

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

  // ── Tunnel status (drives the reconnecting / re-pair strip) ──
  // The native status is a poll (no push from the Rust supervisor), so we
  // sample every handle on a light timer while any exists and emit only on
  // change. The strip's single value is the banner target's; listeners that
  // care about ONE server's tunnel (the playback heal watches the parked
  // track's) take [tunnelTransitions], where one tunnel's edge can never hide
  // behind another's state.
  final BehaviorSubject<IrohTunnelStatus> _tunnelStatus =
      BehaviorSubject.seeded(IrohTunnelStatus.down);
  Stream<IrohTunnelStatus> get tunnelStatusStream => _tunnelStatus.stream;
  IrohTunnelStatus get tunnelStatus => _tunnelStatus.value;
  // Direct-vs-relay path of the strip's tunnel, sampled on the same poll.
  final BehaviorSubject<IrohPathKind> _pathKind =
      BehaviorSubject.seeded(IrohPathKind.unknown);
  Stream<IrohPathKind> get pathKindStream => _pathKind.stream;
  IrohPathKind get pathKind => _pathKind.value;
  final PublishSubject<TunnelTransition> _transitions = PublishSubject();
  Stream<TunnelTransition> get tunnelTransitions => _transitions.stream;
  Timer? _statusPoll;

  void _refreshStatusNow() {
    for (final h in _tunnels.values.toList()) {
      _refreshHandleStatus(h);
    }
    _refreshBannerStatus();
  }

  void _refreshHandleStatus(TunnelHandle h) {
    final name = h.server.localname;
    final st = _effectiveStatus(h);
    final pk = h.starting ? IrohPathKind.unknown : _nativePathKindOf(h);
    final now = DateTime.now();
    if (st != h.lastStatus) {
      final was = h.notConnectedSince;
      final after = (st == IrohTunnelStatus.connected && was != null)
          ? ' after ${now.difference(was).inSeconds}s'
          : '';
      appLog('[iroh] status ${h.lastStatus.name} → ${st.name}$after '
          'path=${pk.name} port=${h.port} for=$name');
      final from = h.lastStatus;
      h.lastStatus = st;
      _transitions.add((server: h.server, from: from, to: st));
    }
    if (st == IrohTunnelStatus.connected) {
      h.notConnectedSince = null;
      h.kickedAt = null;
    } else {
      h.notConnectedSince ??= now;
    }
    h.lastPath = pk;
    // Native supervisor events (a binary with the events ring).
    for (final line in _drainNativeEventsOf(h)) {
      appLog('[iroh-native] $line for=$name');
    }
    _maintainDirect(h);
    // Watchdog: a supervisor that is not converging although the relay is
    // reachable (or a kick that did not take) gets a fresh endpoint. Never in
    // a dead zone — see TunnelPolicy.shouldEscalate — and never more than one
    // rebuild per minute per handle (_hardRebuild), so the 2s poll is a safe
    // caller.
    if (!h.starting &&
        h.assigned &&
        TunnelPolicy.shouldEscalate(
            native: _nativeStatusOf(h),
            notConnectedFor: _since(h.notConnectedSince),
            sinceKick: _since(h.kickedAt),
            relayReachable: _nativeRelayOnlineOf(h))) {
      unawaited(_hardRebuild(h,
          code: h.code, port: h.port, reason: 'watchdog', user: false));
    }
  }

  void _refreshBannerStatus() {
    final target = _bannerTarget();
    final h = target == null ? null : _tunnels[target.localname];
    final st = h == null ? IrohTunnelStatus.down : _effectiveStatus(h);
    final pk = h == null ? IrohPathKind.unknown : h.lastPath;
    if (st != _tunnelStatus.value) _tunnelStatus.add(st);
    if (pk != _pathKind.value) _pathKind.add(pk);
  }

  void _startStatusPolling() {
    _statusPoll ??= Timer.periodic(const Duration(seconds: 2), (_) {
      _refreshStatusNow();
      if (_tunnels.isEmpty) _stopStatusPolling();
    });
    _refreshStatusNow();
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

  /// Wait (bounded) for [server]'s tunnel to report CONNECTED, kicking a
  /// verify-rebuild in case it's hard-down. Returns true once connected;
  /// false on a rejected (re-pair) state or timeout. Non-iroh servers are
  /// ready immediately. Set [extendWhileDialing] false to make [timeout] a
  /// HARD deadline. The default keeps extending it while a dial is in flight
  /// — right for the playback and download paths, which would rather wait
  /// than fail — but a caller driving a UI needs a bound it can actually
  /// promise the user.
  Future<bool> awaitTunnelReady(
      {Server? server,
      Duration timeout = const Duration(seconds: 12),
      bool extendWhileDialing = true,
      String caller = '?',
      bool bypassBackoff = false}) async {
    // Default to the browsed server; callers on the playback path pass the
    // track's server. Either way the wait is for the TRANSPORT's tunnel — a
    // federated peer has none of its own and is ready exactly when its
    // parent is.
    final s = (server ?? currentServer)?.transportServer;
    if (!IrohTunnel.isSupported || s == null || !s.ownsTunnel) return true;
    final h = _handleOf(s);
    // A rejected cold dial leaves no native tunnel to report it; answer
    // before firing an ensure that would only re-dial into the rejection.
    if (h.startRejected && !bypassBackoff) return false;
    unawaited(ensureTunnelFor(s,
        verify: true,
        reason: 'await-ready:$caller',
        bypassBackoff: bypassBackoff));
    // start() can take ~30s; don't report not-ready while a dial is in flight
    // — or while an ensure is still queued behind one (a rebuild's fresh dial
    // runs after the drop). Keep extending the window while so, bounded by a
    // hard cap that fits two full attempts.
    final hardCap = DateTime.now().add(extendWhileDialing
        ? const Duration(seconds: 90)
        : const Duration(seconds: 45));
    var deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline) &&
        DateTime.now().isBefore(hardCap)) {
      if (tunnelServes(s)) return true;
      if (tunnelAssignedTo(s) &&
          _nativeStatusOf(h) == IrohTunnelStatus.rejected) {
        return false; // this server's code was rejected (needs re-pair)
      }
      // A rejected cold dial leaves no native tunnel to report it.
      if (h.startRejected) return false;
      if (extendWhileDialing && (h.starting || h.pendingEnsures > 0)) {
        deadline = DateTime.now().add(timeout);
      }
      await Future.delayed(const Duration(milliseconds: 300));
    }
    return tunnelServes(s);
  }

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
  ///
  /// Returns true only when the probe ran and passed (the path is fine, the
  /// failures were the source's own); false when it was remedied or not
  /// probed at all.
  Future<bool> reverifyTunnel(Server server) async {
    // Probe the transport: a peer's failures happen on its parent's tunnel.
    final s = server.transportServer;
    if (!IrohTunnel.isSupported || s == null || !s.ownsTunnel) return false;
    final h = _tunnels[s.localname];
    if (h == null || h.reverifying || !h.assigned) return false;
    // Already known down: ensureTunnelFor / awaitTunnelReady own that case
    // and this would only race them.
    if (!tunnelServes(s)) return false;
    final gap = _since(h.lastHardRebuildAt);
    if (gap != null && gap < TunnelTiming.hardRebuildMinGap) return false;
    h.reverifying = true;
    try {
      final code = h.code;
      final port = h.port;
      final r = await _probeTunnel(s);
      if (r.ok) {
        appLog('[iroh] tunnel probe passed (${r.reason}, ${r.ms}ms) — '
            'the failures were not the path for=${s.localname}');
        return true;
      }
      if (!tunnelServes(s)) {
        appLog('[iroh] probe failed (${r.reason}) but the supervisor '
            'noticed meanwhile — leaving it for=${s.localname}');
        return false;
      }
      appLog('[iroh] tunnel says connected but the probe failed '
          '(${r.reason}, ${r.ms}ms) after repeated load failures '
          'for=${s.localname}');
      await _remedyDeadTunnel(h,
          code: code, port: port, reason: 'reverify', user: false);
      return false;
    } finally {
      h.reverifying = false;
    }
  }

  /// Re-pair an iroh server with a fresh pairing code (after a rotated
  /// secret) and restart its tunnel. Validates the new code by bringing the
  /// tunnel up BEFORE persisting; on failure the previous code is restored
  /// (and re-dialed) and nothing is written — so a wrong/typo code can't
  /// destroy a working one. Returns true iff the new code connected.
  ///
  /// [server] defaults to the tunnel on the strip — the one whose code was
  /// rejected (it may be a background playback server, not the browsed one)
  /// — then to the browsed server.
  Future<bool> repairIrohPairingCode(String newCode, {Server? server}) async {
    final s = (server ?? _bannerTarget() ?? currentServer)?.transportServer;
    if (s == null || !s.isIroh) return false;
    final h = _handleOf(s);
    final oldCode = s.irohPairingCode;

    Future<void> activate(String? code) async {
      // The swap runs on the chain (invariant 1) so an in-flight ensure can't
      // record the OLD code as the one it dialed. The stop uses the key the
      // running tunnel was started under, which the swap does not touch.
      await _mutateHandle(h, 'repair', () {
        s.irohPairingCode = code;
        _stopHandleTunnel(h, 'repair');
        h.startRejected = false;
        h.cancelRetry();
      });
      await ensureTunnelFor(s,
          verify: true, reason: 'repair', bypassBackoff: true);
    }

    // Try the new code WITHOUT persisting yet.
    await activate(newCode);
    if (_nativeStatusOf(h) == IrohTunnelStatus.connected) {
      await writeServerFile(); // persist only a code that actually connected
      _refreshStatusNow();
      return true;
    }
    // Failed → roll back to the previous code and re-establish the old tunnel.
    await activate(oldCode);
    _refreshStatusNow();
    return false;
  }

  /// Adopt a tunnel already started elsewhere (the add-server test, which
  /// dials under the pairing code) as [s]'s, so the next ensure won't
  /// needlessly restart it.
  void registerActiveTunnel(Server s, int port) {
    final key = TunnelHandle.keyFor(s);
    final token = IrohTunnel.instance.localTokenOf(key);
    final h = _handleOf(s);
    // Serialize the adopt through the handle's chain so an in-flight
    // (re)start can't clobber these values mid-flight; the changeCurrentServer
    // that follows chains after this and observes the adopted tunnel (no
    // needless re-dial).
    h.chain = h.chain.then((_) {
      h.bind(
          key: key,
          credential: s.irohPairingCode!,
          localPort: port,
          localToken: token);
      h.cancelRetry();
      h.startRejected = false;
      h.lastFailedDialAt = null;
    }).catchError((_) {});
    _startStatusPolling();
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
    // went with it. Done before ensureTunnels so no tunnel is kept
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
    // Drop a stale queue-tunnel pointer to the removed server so the ensure
    // below doesn't try to keep its tunnel up (the queue listener would clear
    // it on the next edit, but do it now).
    for (final gone in [removeThisServer, ...orphans]) {
      _queueReleaseTimers.remove(gone.localname)?.cancel();
      _queueServers.remove(gone.localname);
    }

    if (serverList.isEmpty) {
      // force the browser to rerender so it displays
      BrowserManager().noServerScreen();

      currentServer = null;
      _currentServerStream.sink.add(currentServer);
    } else if (!serverList.contains(currentServer)) {
      // The active server went — either it IS the one being removed, or it was
      // one of its peers, swept out with it.
      currentServer = firstSelectable(serverList);
      // clear the browser
      BrowserManager().goToNavScreen();
      _currentServerStream.sink.add(currentServer);
    }

    // Start/stop the tunnel to match the (possibly changed) active server.
    await ensureTunnels(reason: 'remove-server');
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

  /// The default: the first server the picker would offer. A hidden or
  /// no-longer-listed peer can sit at index 0 (Make Default, then hidden, or
  /// the parent stopped sharing it), and opening on it would only 404.
  @visibleForTesting
  static Server firstSelectable(List<Server> servers) =>
      servers.firstWhere((s) => s.isSelectable, orElse: () => servers.first);

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
    await _reconcilePeers(parent, peers);
  }

  /// Fold the parent's peer list ([peers], possibly empty) into the servers
  /// held for it. See [refreshFederatedPeers] for the rules.
  Future<void> _reconcilePeers(Server parent, List peers) async {
    bool changed = false;
    // Ids first, names second: a peer the admin removed and re-added comes
    // back under a NEW row id (the plan's "peer ids are parent-side rowids"
    // risk). Matching by id alone would flag the old record missing and mint
    // a `-2` twin, stranding the queue and the download folder — so a listed
    // id nobody holds is adopted by a child of the same name whose own id is
    // no longer listed.
    final Set<int> listed = {};
    final entries = <({int id, String name})>[];
    for (final p in peers) {
      if (p is! Map) continue;
      final id = p['id'];
      final name = p['name'];
      if (id is! int || name is! String || name.isEmpty) continue;
      listed.add(id);
      entries.add((id: id, name: name));
    }
    for (final e in entries) {
      final id = e.id;
      final name = e.name;
      var existing = _childByPeerId(parent, id);
      if (existing == null) {
        final orphan =
            adoptablePeer(federatedChildren(parent), name, listed);
        if (orphan != null) {
          appLog('[federation] ${orphan.localname}: peer id '
              '${orphan.federationPeerId} → $id (re-added on '
              '${parent.localname})');
          orphan.federationPeerId = id;
          existing = orphan;
          changed = true;
        }
      }
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

    Server? vanishedUnderUs;
    for (final child in federatedChildren(parent)) {
      final gone = !listed.contains(child.federationPeerId);
      if (gone != child.federationMissing) {
        child.federationMissing = gone;
        changed = true;
        if (gone && identical(child, currentServer)) vanishedUnderUs = child;
      }
    }

    if (!changed) return;
    _linkFederatedParents();
    _serverListStream.sink.add(serverList);
    await writeServerFile();
    // The peer being browsed stopped being shared: every request through the
    // proxy is a 404 from here on, and the picker no longer offers it. Move
    // the browser to the parent, the way Hide does.
    if (vanishedUnderUs != null) {
      appLog('[federation] ${vanishedUnderUs.localname} is no longer shared '
          'by ${parent.localname} — leaving it for the parent');
      final idx = serverList.indexOf(parent);
      await changeCurrentServer(idx >= 0 ? idx : 0);
    }
    // Capabilities for anything new or newly back: one /api through the proxy.
    for (final child in federatedChildren(parent)) {
      if (!child.federationMissing) unawaited(getServerPaths(child));
    }
  }

  /// Among [children] (one parent's peers), the record a listed peer named
  /// [name] should re-use when no child holds its id: a child of that name
  /// whose OWN id is not in [listed] — the admin removed and re-added it, and
  /// the parent handed out a fresh row id. Null when nothing qualifies.
  @visibleForTesting
  static Server? adoptablePeer(
      List<Server> children, String name, Set<int> listed) {
    for (final c in children) {
      if (c.federationPeerName == name && !listed.contains(c.federationPeerId)) {
        return c;
      }
    }
    return null;
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
    server.federationDirectAvailable = false; // a peer's own peers are out of reach
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

/// What asking the parent for a peer's direct access came to.
enum DirectAccessOutcome {
  /// A ticket the peer did not hold before (first fetch, or a fresh mint).
  issued,

  /// The parent handed out the ticket the peer already holds.
  unchanged,

  /// The parent said `direct: false`: the proxy is all there is.
  denied,

  /// Unreachable, an HTTP error, or an unreadable answer: try again later.
  failed,
}
