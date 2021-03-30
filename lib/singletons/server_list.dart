import 'dart:async';
import 'dart:io';
import 'dart:convert';
import '../objects/server.dart';

import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:rxdart/rxdart.dart';

class ServerManager {
  ServerManager._privateConstructor();

  static final ServerManager _instance = ServerManager._privateConstructor();

  factory ServerManager() {
    return _instance;
  }

  static final List<Server> serverList = [];
  static Server? currentServer;

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

    if (serverList.length > 0) {
      currentServer = serverList[0];
      _curentServerStream.sink.add(currentServer);
    }

    _serverListStream.sink.add(serverList);
  }

  Future<void> addServer(Server newServer) async {
    serverList.add(newServer);

    if (currentServer == null) {
      currentServer = newServer;
      _curentServerStream.sink.add(currentServer);
    }

    // Create server directory (for downloads)
    var file = await getApplicationDocumentsDirectory();
    String dir = path.join(file.path, "media/${newServer.localname}");
    await new Directory(dir).create(recursive: true);

    await writeServerFile();

    _serverListStream.sink.add(serverList);
  }

  // streams
  BehaviorSubject<List<Server>> _serverListStream =
      BehaviorSubject<List<Server>>.seeded(serverList);

  BehaviorSubject<Server?> _curentServerStream =
      BehaviorSubject<Server?>.seeded(currentServer);

  void dispose() {
    _serverListStream.close();
    _curentServerStream.close();
  } //initializes the subject with element already;
}