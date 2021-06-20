import 'dart:async';
import 'dart:io';
import 'dart:convert';
import '../objects/server.dart';
import './browser_list.dart';

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:rxdart/rxdart.dart';

class ServerManager {
  final List<Server> serverList = [];
  Server? currentServer;

  // streams
  late final BehaviorSubject<List<Server>> _serverListStream =
      BehaviorSubject<List<Server>>.seeded(serverList);
  late final BehaviorSubject<Server?> _curentServerStream =
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
      _curentServerStream.sink.add(currentServer);
    } else {
      BrowserManager().noServerScreen();
    }
  }

  Future<void> addServer(Server newServer) async {
    serverList.add(newServer);

    if (currentServer == null) {
      currentServer = newServer;
      _curentServerStream.sink.add(currentServer);
      BrowserManager().goToNavScreen();
    }

    // // Create server directory (for downloads)
    // var file = await getApplicationDocumentsDirectory();
    // String dir = path.join(file.path, "media/${newServer.localname}");
    // await new Directory(dir).create(recursive: true);

    await writeServerFile();

    _serverListStream.sink.add(serverList);
  }

  void editServer(
      int serverIndex, String url, String? username, String? password) {
    serverList[serverIndex].url = url;
    ServerManager().serverList[serverIndex].password = password;
    ServerManager().serverList[serverIndex].username = username;

    callAfterEditServer();
  }

  void changeCurrentServer(int currentServerIndex) {
    currentServer = serverList[currentServerIndex];
    _curentServerStream.sink.add(currentServer);
  }

  Future<void> removeServer(
      Server removeThisServer, bool removeSyncedFiles) async {
    serverList.remove(removeThisServer);
    _serverListStream.sink.add(serverList);

    if (serverList.length == 0) {
      // force the browser to rerender so it displays
      BrowserManager().noServerScreen();

      currentServer = null;
      _curentServerStream.sink.add(currentServer);
    } else if (removeThisServer == currentServer) {
      currentServer = serverList[0];
      // clear the browser
      BrowserManager().goToNavScreen();
      _curentServerStream.sink.add(currentServer);
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
    final directory = await getApplicationDocumentsDirectory();
    var dir = new Directory(path.join(
        directory.path.toString(), "media/${removedServer.localname}"));
    dir.delete(recursive: true);
  }

  void dispose() {
    _serverListStream.close();
    _curentServerStream.close();
  } //initializes the subject with element already;

  Stream<Server?> get curentServerStream => _curentServerStream.stream;

  Stream<List<Server>> get serverListStream => _serverListStream.stream;
}
