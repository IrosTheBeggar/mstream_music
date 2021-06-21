import './server_list.dart';
import './browser_list.dart';
import '../objects/server.dart';
import '../objects/display_item.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

import 'package:http/http.dart' as http;
import 'dart:convert';

class ApiManager {
  ApiManager._privateConstructor();
  static final ApiManager _instance = ApiManager._privateConstructor();
  factory ApiManager() {
    return _instance;
  }

  Future makeServerCall(Server? currentServer, String location, Map payload,
      String getOrPost) async {
    Server server = ServerManager().currentServer ??
        (throw Exception('No Server Selected'));

    Uri currentUri = Uri.parse(server.url).resolve(location);

    var response;
    if (getOrPost == 'GET') {
      response = await http
          .get(currentUri, headers: {'x-access-token': server.jwt ?? ''});
    } else {
      response = await http.post(currentUri,
          body: payload, headers: {'x-access-token': server.jwt ?? ''});
    }

    if (response.statusCode > 299) {
      throw Exception('Server Call Failed');
    }

    return jsonDecode(response.body);
  }

  Future<void> getFileList(String directory, {Server? useThisServer}) async {
    var res;
    try {
      res = await makeServerCall(useThisServer, '/api/v1/file-explorer',
          {"directory": directory}, 'POST');
    } catch (err) {
      // TODO: Handle Errors
      print(err);
      return;
    }

    BrowserManager().setBrowserLabel('File Explorer');

    List<DisplayItem> newList = [];
    res['directories'].forEach((e) {
      DisplayItem newItem = new DisplayItem(
          useThisServer,
          e['name'],
          'directory',
          path.join(res['path'], e['name']),
          Icon(Icons.folder, color: Color(0xFFffab00)),
          null);
      newList.add(newItem);
    });

    res['files'].forEach((e) {
      DisplayItem newItem = new DisplayItem(
          useThisServer,
          e['name'],
          'file',
          path.join(res['path'], e['name']),
          Icon(Icons.music_note, color: Colors.blue),
          null);
      newList.add(newItem);
    });

    BrowserManager().addListToStack(newList);
  }
}
