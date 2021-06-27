import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';
import 'package:http/http.dart' as http;

import '../singletons/server_list.dart';
import '../objects/display_item.dart';
import '../objects/server.dart';

class BrowserManager {
  final List<List<DisplayItem>> browserCache = [];
  final List<DisplayItem> browserList = [];

  String listName = 'Welcome';
  bool loading = false;

  late final BehaviorSubject<List<DisplayItem>> _browserStream =
      BehaviorSubject<List<DisplayItem>>.seeded(browserList);
  late final BehaviorSubject<String> _browserLabel =
      BehaviorSubject<String>.seeded(listName);

  BrowserManager._privateConstructor();
  static final BrowserManager _instance = BrowserManager._privateConstructor();

  factory BrowserManager() {
    return _instance;
  }

  void setBrowserLabel(String label) {
    listName = label;
    _browserLabel.sink.add(label);
  }

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

    DisplayItem newItem2 = new DisplayItem(
        ServerManager().currentServer!,
        'Playlists',
        'execAction',
        'playlists',
        Icon(Icons.queue_music, color: Colors.black),
        null);

    DisplayItem newItem3 = new DisplayItem(
        ServerManager().currentServer!,
        'Albums',
        'execAction',
        'albums',
        Icon(Icons.album, color: Colors.black),
        null);

    DisplayItem newItem4 = new DisplayItem(
        ServerManager().currentServer!,
        'Artists',
        'execAction',
        'artists',
        Icon(Icons.library_music, color: Colors.black),
        null);

    DisplayItem newItem5 = new DisplayItem(
        ServerManager().currentServer!,
        'Rated',
        'execAction',
        'rated',
        Icon(Icons.star, color: Colors.black),
        null);

    DisplayItem newItem6 = new DisplayItem(
        ServerManager().currentServer!,
        'Recent',
        'execAction',
        'recent',
        Icon(Icons.query_builder, color: Colors.black),
        null);

    browserCache
        .add([newItem1, newItem2, newItem3, newItem4, newItem5, newItem6]);
    browserList.add(newItem1);
    browserList.add(newItem2);
    browserList.add(newItem3);
    browserList.add(newItem4);
    browserList.add(newItem5);
    browserList.add(newItem6);

    _browserStream.sink.add(browserList);
  }

  void noServerScreen() {
    browserCache.clear();
    browserList.clear();

    browserList.add(new DisplayItem(null, 'Welcome To mStream', 'addServer', '',
        Icon(Icons.add, color: Colors.black), 'Click here to add server'));
  }

  void addListToStack(List<DisplayItem> newList) {
    browserCache.add(newList);

    browserList.clear();
    newList.forEach((element) {
      browserList.add(element);
    });

    _browserStream.sink.add(browserList);
  }

  void popBrowser() {
    if (BrowserManager().browserCache.length < 2) {
      return;
    }

    browserCache.removeLast();
    browserList.clear();
    browserCache[browserCache.length - 1].forEach((el) {
      browserList.add(el);
    });

    _browserStream.sink.add(browserList);
  }

  void dispose() {
    _browserStream.close();
    _browserLabel.close();
  }

  Stream<List<DisplayItem>> get browserListStream => _browserStream.stream;
  Stream<String> get broswerLabelStream => _browserLabel.stream;
}
