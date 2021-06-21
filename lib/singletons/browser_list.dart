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

    browserCache.add([newItem1]);
    browserList.add(newItem1);

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
