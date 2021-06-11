import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import 'package:http/http.dart' as http;

import '../singletons/server_list.dart';
import '../objects/display_item.dart';
import '../objects/server.dart';

class BrowserManager {
  BrowserManager._privateConstructor();
  static final BrowserManager _instance = BrowserManager._privateConstructor();

  factory BrowserManager() {
    return _instance;
  }

  String listName = 'Welcome';
  bool loading = false;

  final List<List<DisplayItem>> browserCache = [];
  late final List<DisplayItem> browserList = [];

  late final BehaviorSubject<List<DisplayItem>> _browserStream =
      BehaviorSubject<List<DisplayItem>>.seeded(browserList);

  void goToNavScreen() {
    browserCache.clear();
    browserList.clear();

    if (ServerManager().currentServer == null) {
      return;
    }

    DisplayItem newItem1 = new DisplayItem(
        ServerManager().currentServer!,
        'File Explorer',
        'execAction',
        'fileExplorer',
        Icon(Icons.folder, color: Color(0xFFffab00)),
        null);

    browserCache.add([newItem1]);
    browserList.add(newItem1);
  }

  void dispose() {
    _browserStream.close();
  }

  Stream<List<DisplayItem>> get browserListStream => _browserStream.stream;

  Future<void> getFileList(String directory,
      {bool wipeBackCache = false, Server? useThisServer}) async {
    listName = 'File Explorer';

    if (useThisServer == null) {
      return;
    }

    var res = await _makeServerCall(
        useThisServer, '/dirparser', {"dir": directory}, 'POST', wipeBackCache);
    //   if (res == null) {
    //     return;
    //   }

    //   displayList.clear();
    //   List<DisplayItem> newList = new List();
    //   res['contents'].forEach((e) {
    //     Icon thisIcon = e['type'] == 'directory'
    //         ? Icon(Icons.folder, color: Color(0xFFffab00))
    //         : Icon(Icons.music_note, color: Colors.blue);
    //     var thisType = (e['type'] == 'directory') ? 'directory' : 'file';
    //     DisplayItem newItem = new DisplayItem(useThisServer, e['name'], thisType,
    //         path.join(res['path'], e['name']), thisIcon, null);
    //     displayList.add(newItem);
    //     newList.add(newItem);
    //   });
    //   displayCache.add(newList);
  }

  Future _makeServerCall(Server useThisServer, String location, Map payload,
      String getOrPost, bool wipeBackCache) async {
    Uri currentUri = Uri.parse(useThisServer.url).resolve(location);
    var response;
    const Map<String, String> headers = {};
    if (useThisServer.jwt != null) {
      headers['x-access-token'] = useThisServer.jwt!;
    }

    if (getOrPost == 'GET') {
      response = await http.get(currentUri, headers: headers);
    } else {
      response = await http.post(currentUri, body: payload, headers: headers);
    }

    //   if (response.statusCode > 299) {
    //     Fluttertoast.showToast(
    //       msg: "Server Call Failed",
    //       toastLength: Toast.LENGTH_SHORT,
    //       gravity: ToastGravity.CENTER,
    //       timeInSecForIos: 1,
    //       backgroundColor: Colors.orange,
    //       textColor: Colors.white
    //     );
    //     return null;
    //   }

    var res = jsonDecode(response.body);
    //   if(wipeBackCache) {
    //     displayCache.clear();
    //     List<DisplayItem> newList = new List();
    //     newList.add(new DisplayItem(useThisServer, 'File Explorer', 'execAction', 'fileExplorer', Icon(Icons.folder, color: Color(0xFFffab00)), null));
    //     newList.add(new DisplayItem(useThisServer, 'Playlists', 'execAction', 'playlists', Icon(Icons.queue_music, color: Colors.black), null));
    //     newList.add(new DisplayItem(useThisServer, 'Albums', 'execAction', 'albums', Icon(Icons.album, color: Colors.black), null));
    //     newList.add(new DisplayItem(useThisServer, 'Artists', 'execAction', 'artists', Icon(Icons.library_music, color: Colors.black), null));
    //     newList.add(new DisplayItem(useThisServer, 'Rated', 'execAction', 'rated', Icon(Icons.star, color: Colors.black), null));
    //     newList.add(new DisplayItem(useThisServer, 'Recent', 'execAction', 'recent', Icon(Icons.query_builder, color: Colors.black), null));
    //     displayCache.add(newList);
    //   }

    return res;
  }
}
