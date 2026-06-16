import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import './app_messenger.dart';
import './browser_list.dart';
import '../l10n/app_localizations.dart';
import '../objects/display_item.dart';
import '../objects/server.dart';
import '../theme/velvet_theme.dart';

class FileExplorer {
  FileExplorer._privateConstructor();
  static final FileExplorer _instance = FileExplorer._privateConstructor();
  factory FileExplorer() {
    return _instance;
  }

  Future<String> getServerDir(Server s) async {
    Directory? woo = await getDownloadDir(s.storageMode, s.storageBasePath);
    if (woo == null) {
      final ctx = rootMessengerKey.currentContext;
      return ctx != null && ctx.mounted
          ? AppLocalizations.of(ctx).dlLocationUnavailable
          : 'Download location unavailable';
    }

    return Directory(path.join(woo.path.toString(), 'media/${s.localname}'))
        .path
        .toString();
  }

  Future<void> getLocalFiles(String? directory, Server s) async {
    BrowserManager().setBrowserLabel('Local Files');
    List<DisplayItem> newList = [];

    Directory file;
    if (directory == null) {
      BrowserManager().clear();
      Directory? woo = await getDownloadDir(s.storageMode, s.storageBasePath);
      if (woo == null) {
        // permanent/sdCard location is gone (card removed / folder deleted).
        final ctx = rootMessengerKey.currentContext;
        showGlobalSnack(ctx != null && ctx.mounted
            ? AppLocalizations.of(ctx).dlLocationUnavailableServer
            : 'Download location unavailable for this server.');
        BrowserManager().addListToStack(newList); // show an empty list
        return;
      }
      file = Directory(path.join(woo.path.toString(), 'media'));
    } else {
      file = Directory(directory);
    }

    int stringLength = file.path.toString().length +
        1; // The plug ones covers the extra `/` that will be on the results

    file
        .list(recursive: false, followLinks: false)
        .listen((FileSystemEntity entity) {
      Icon useIcon;
      String type;
      if (entity is File) {
        useIcon = Icon(Icons.music_note, color: VelvetColors.textSecondary);
        type = 'localFile';
      } else {
        useIcon = Icon(Icons.folder_open_outlined, color: VelvetColors.textSecondary);
        type = 'localDirectory';
      }

      String thisName = entity.path.substring(stringLength, entity.path.length);
      DisplayItem newItem =
          DisplayItem(s, thisName, type, entity.path, useIcon, null);
      newList.add(newItem);
    }).onDone(() {
      BrowserManager().addListToStack(newList);
    });
  }

  Future<void> getPathForServer(Server s) async {
    Directory? woo = await getDownloadDir(s.storageMode, s.storageBasePath);
    if (woo != null) {
      Directory file =
          Directory(path.join(woo.path.toString(), 'media/${s.localname}'));
      getLocalFiles(file.path.toString(), s);
    }
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

  // Resolves the base directory under which a server's downloads live
  // (final paths are <base>/media/<localname>/...). Driven by the
  // server's storage mode rather than a bool so callers can choose
  // app-local, a user-picked permanent folder, or an SD-card folder.
  //
  // Returns null when the configured location is currently unavailable
  // (permanent/sdCard base path missing — e.g. SD card removed or the
  // folder was deleted). Every caller already null-guards getDownloadDir,
  // so a null cleanly means "no local copy here" (playback streams,
  // listings empty) instead of throwing on an unmounted volume.
  Future<Directory?> getDownloadDir(
      String storageMode, String? storageBasePath) async {
    switch (storageMode) {
      case 'permanent':
      case 'sdCard':
        if (storageBasePath == null) return null;
        final dir = Directory(storageBasePath);
        return dir.existsSync() ? dir : null;
      case 'appExternal':
      case 'legacyExternal':
        // App-scoped external storage (Android/data/<pkg>/files): more room /
        // SD-capable, needs NO permission. 'appExternal' is the Play-compliant
        // option offered in the UI; 'legacyExternal' is the migration-only
        // value that resolves to the same place.
        return getExternalStorageDirectory();
      case 'appLocal':
      default:
        return getApplicationDocumentsDirectory();
    }
  }
}
