import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:mstream_music/screens/browser.dart';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import './browser_list.dart';
import '../objects/display_item.dart';
import '../objects/server.dart';

class FileExplorer {
  FileExplorer._privateConstructor();
  static final FileExplorer _instance = FileExplorer._privateConstructor();
  factory FileExplorer() {
    return _instance;
  }

  Future<void> getLocalFiles(String? directory) async {
    BrowserManager().setBrowserLabel('Local Files');
    List<DisplayItem> newList = [];

    Directory file;
    if (directory == null) {
      BrowserManager().clear();
      Directory woo = await getApplicationDocumentsDirectory();
      file = new Directory(path.join(woo.path.toString(), 'media'));
    } else {
      file = new Directory(directory);
    }

    int stringLength = file.path.toString().length +
        1; // The plug ones covers the extra `/` that will be on the results

    file
        .list(recursive: false, followLinks: false)
        .listen((FileSystemEntity entity) {
      print(entity.path);
      Icon useIcon;
      String type;
      if (entity is File) {
        useIcon = new Icon(Icons.music_note, color: Colors.black);
        type = 'localFile';
      } else {
        useIcon = new Icon(Icons.folder_open_outlined, color: Colors.black);
        type = 'localDirectory';
      }

      String thisName = entity.path.substring(stringLength, entity.path.length);
      DisplayItem newItem =
          new DisplayItem(null, thisName, type, entity.path, useIcon, null);
      newList.add(newItem);
    }).onDone(() {
      BrowserManager().addListToStack(newList);
    });
  }

  Future<void> getPathForServer(String serverName) async {
    Directory woo = await getApplicationDocumentsDirectory();
    Directory file =
        new Directory(path.join(woo.path.toString(), 'media/$serverName'));
    getLocalFiles(file.path.toString());
  }

  Future<void> deleteFile(String path, Server? server) async {
    File f = File(path);
    if (f.existsSync()) {
      await f.delete();
    }

    BrowserManager().removeAll(path, server, 'localFile');
  }

  Future<void> deleteDirectory(String path, Server? server) async {
    Directory f = Directory(path);
    if (f.existsSync()) {
      await f.delete(recursive: true);
    }

    BrowserManager().removeAll(path, server, 'localDirectory');
  }
}
