import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:mstream_music/singletons/file_explorer.dart';

import '../objects/server.dart';
import '../util/server_compat.dart';
import './app_messenger.dart';
import './browser_list.dart';
import '../build_variant.dart';
import '../util/insecure_tls_channel.dart';

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:rxdart/rxdart.dart';
import 'package:http/http.dart' as http;

class ServerManager {
  final List<Server> serverList = [];
  Server? currentServer;

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

  Future<void> loadServerList() async {
    List serversJson = await readServerManager();

    serversJson.forEach((s) {
      try {
        serverList.add(Server.fromJson(s));
      } catch (e) {
        // Skip a corrupt entry instead of failing to load every server
        // that comes after it in the file.
      }
    });

    _serverListStream.sink.add(serverList);
    syncInsecureTls();

    if (serverList.length > 0) {
      currentServer = serverList[0];
      BrowserManager().goToNavScreen();
      _currentServerStream.sink.add(currentServer);
      serverList.forEach((Server s) {
        getServerPaths(s);
      });
      // Probe saved servers in the background; flips the active server
      // away from an unsupported build without blocking startup.
      unawaited(_screenServers());
    } else {
      BrowserManager().noServerScreen();
    }
  }

  // Marks every saved server this client doesn't support. Runs after the
  // UI has already shown the first server (so startup isn't gated on the
  // network); if the active server turns out to be unsupported, falls
  // back to the first supported one, or the no-server screen if none.
  Future<void> _screenServers() async {
    await Future.wait(serverList.map((Server s) async {
      s.unsupported = !await isServerSupported(s.url);
    }));

    if (currentServer?.unsupported != true) return;

    Server? next;
    for (final Server s in serverList) {
      if (!s.unsupported) {
        next = s;
        break;
      }
    }
    currentServer = next;
    _currentServerStream.sink.add(currentServer);
    if (next != null) {
      BrowserManager().goToNavScreen();
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

    // Create server directory (for downloads)
    Directory? file = await FileExplorer()
        .getDownloadDir(newServer.storageMode, newServer.storageBasePath);
    if (file != null) {
      try {
        String dir = path.join(file.path, "media/${newServer.localname}");
        await new Directory(dir).create(recursive: true);
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

  void changeCurrentServer(int currentServerIndex) {
    currentServer = serverList[currentServerIndex];
    _currentServerStream.sink.add(currentServer);
    BrowserManager().goToNavScreen();
  }

  Future<void> getServerPaths(Server server, {bool throwErr = false}) async {
    if (server.unsupported) {
      if (throwErr) throw Exception('Failed to connect to server');
      return;
    }
    try {
      var response = await http
          .get(Uri.parse(server.url).resolve('/api/v1/ping'), headers: {
        'Content-Type': 'application/json',
        'x-access-token': server.jwt ?? ''
      }).timeout(Duration(seconds: 5));

      if (response.statusCode != 200) {
        throw Exception('Failed to connect to server');
      }

      var res = jsonDecode(response.body);

      Set<String> pathCompare = new Set();
      for (var i = 0; i < res['vpaths'].length; i++) {
        pathCompare.add(res['vpaths'][i]);
        // add new keys
        if (!server.autoDJPaths.containsKey(res['vpaths'][i])) {
          server.autoDJPaths[res['vpaths'][i]] = true;
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

      // Update Playlists
      server.playlists.clear();
      for (var i = 0; i < res['playlists'].length; i++) {
        server.playlists.add(res['playlists'][i]);
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
        server.transcodeDefaultCodec = transcodeInfo['defaultCodec'] as String?;
        server.transcodeDefaultBitrate =
            transcodeInfo['defaultBitrate'] as String?;
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
        throw err;
      }
    }
  }

  Future<void> removeServer(
      Server removeThisServer, bool removeSyncedFiles) async {
    serverList.remove(removeThisServer);
    _serverListStream.sink.add(serverList);

    if (serverList.length == 0) {
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

  /// True if [host] belongs to a configured server that opted into accepting a
  /// self-signed cert — SelfSignedHttpOverrides bypasses validation for just
  /// that host. Always false on the Play build.
  bool allowsSelfSigned(String host) {
    if (isPlayBuild) return false;
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
  } //initializes the subject with element already;

  Stream<Server?> get currentServerStream => _currentServerStream.stream;

  Stream<List<Server>> get serverListStream => _serverListStream.stream;
}
