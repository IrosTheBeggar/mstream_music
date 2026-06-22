import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import './app_messenger.dart';
import './browser_list.dart';
import './log_manager.dart';
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

    // Relative path within this server's local store (download/media/<localname>)
    // for the breadcrumb subheader, mirroring the server file explorer. '' at the
    // root renders as '/'.
    final marker = '${path.separator}media${path.separator}${s.localname}';
    final mi = file.path.indexOf(marker);
    String rel = mi >= 0 ? file.path.substring(mi + marker.length) : '';
    if (rel.startsWith(path.separator)) rel = rel.substring(1);

    // Bracket the directory listing in the browser's load token, the same as a
    // server fetch: it raises the loading bar, engages the tap-guard (tapping
    // another folder mid-listing is ignored, so it can't start a racing
    // listing), and lets Back cancel — cancelLoading() fires onCancel (cancels
    // this subscription) and marks the token dropped, so a late result for a
    // directory the user already left can't push onto the stack.
    late final StreamSubscription<FileSystemEntity> sub;
    final loadToken =
        BrowserManager().beginLoading(onCancel: () => sub.cancel());

    // Single finalizer, guarded so done/error can't double-run it and so the
    // token can never leak (a stuck token would freeze the loading bar +
    // tap-guard). The Back path cancels the subscription instead, so neither
    // done nor error fires there — cancelLoading() already cleared the in-flight
    // set, and the isLoadCancelled check drops any late finalize that still races
    // through.
    var settled = false;
    void settle() {
      if (settled) return;
      settled = true;
      BrowserManager().endLoading(loadToken);
      if (BrowserManager().isLoadCancelled(loadToken)) return;
      BrowserManager().addListToStack(newList, path: rel);
    }

    sub = file.list(recursive: false, followLinks: false).listen(
      (FileSystemEntity entity) {
        Icon useIcon;
        String type;
        if (entity is File) {
          useIcon = Icon(Icons.music_note, color: VelvetColors.textSecondary);
          type = 'localFile';
        } else {
          useIcon = Icon(Icons.folder_open_outlined,
              color: VelvetColors.textSecondary);
          type = 'localDirectory';
        }

        String thisName =
            entity.path.substring(stringLength, entity.path.length);
        DisplayItem newItem =
            DisplayItem(s, thisName, type, entity.path, useIcon, null);
        newList.add(newItem);
      },
      onDone: settle,
      // Surface whatever was enumerated and, crucially, release the token so a
      // listing error (e.g. a vanished folder) can't lock the browser.
      onError: (Object e) {
        appLog('[fileExplorer] local listing error: $e');
        settle();
      },
      cancelOnError: true,
    );
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
      case 'sdCardApp':
        // The SD card's app-specific dir (Android/data/<pkg>/files on the
        // removable volume). Play-compliant (no permission), but cleared on
        // uninstall. getExternalStorageDirectories returns one Directory per
        // volume; the second is the SD card. Null when no card is present — the
        // caller null-guards, so that reads as "no local copy here".
        final dirs = await getExternalStorageDirectories();
        return (dirs != null && dirs.length > 1) ? dirs[1] : null;
      case 'appLocal':
      default:
        return getApplicationDocumentsDirectory();
    }
  }
}
