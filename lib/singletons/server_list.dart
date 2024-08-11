import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:mstream_music/singletons/file_explorer.dart';

import '../objects/server.dart';
import './browser_list.dart';

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

  Future<File> writeServerFile() async {
    final file = await _serverFile;

    // Write the file
    return file.writeAsString(jsonEncode(serverList));
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
      Server newServer = Server.fromJson(s);
      serverList.add(newServer);
    });

    _serverListStream.sink.add(serverList);

    if (serverList.length > 0) {
      currentServer = serverList[0];
      BrowserManager().goToNavScreen();
      _currentServerStream.sink.add(currentServer);
      serverList.forEach((Server s) {
        getServerPaths(s);
      });
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
    Directory? file =
        await FileExplorer().getDownloadDir(newServer.saveToSdCard);
    if (file != null) {
      String dir = path.join(file.path, "media/${newServer.localname}");
      await new Directory(dir).create(recursive: true);
    }

    await writeServerFile();

    _serverListStream.sink.add(serverList);
  }

  Future<void> editServer(int serverIndex, String url, String? username,
      String? password, bool saveToSd) async {
    serverList[serverIndex].url = url;
    ServerManager().serverList[serverIndex].password = password;
    ServerManager().serverList[serverIndex].username = username;
    ServerManager().serverList[serverIndex].saveToSdCard = saveToSd;

    await callAfterEditServer();
  }

  void changeCurrentServer(int currentServerIndex) {
    currentServer = serverList[currentServerIndex];
    _currentServerStream.sink.add(currentServer);
    BrowserManager().goToNavScreen();
  }

  Future<void> getServerPaths(Server server, {bool throwErr = false}) async {
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

    // delete synced files
    // if (removeSyncedFiles == true) {
    //   _deleteServeDirectory(removeThisServer);
    // }
  }

  Future<void> callAfterEditServer() async {
    _serverListStream.sink.add(serverList);
    await writeServerFile();
  }

  Future<void> _deleteServeDirectory(Server removedServer) async {
    Directory? directory =
        await FileExplorer().getDownloadDir(removedServer.saveToSdCard);
    if (directory != null) {
      Directory dir = new Directory(path.join(
          directory.path.toString(), "media/${removedServer.localname}"));
      dir.delete(recursive: true);
    }
  }

  void makeDefault(int i) {
    Server s = serverList[i];

    serverList.remove(s);
    serverList.insert(0, s);

    _serverListStream.sink.add(serverList);
  }

  Server lookupServer(String id) {
    return serverList.firstWhere((e) => e.localname == id);
  }

  void dispose() {
    _serverListStream.close();
    _currentServerStream.close();
  } //initializes the subject with element already;

  Stream<Server?> get curentServerStream => _currentServerStream.stream;

  Stream<List<Server>> get serverListStream => _serverListStream.stream;
}
