import 'dart:isolate';
import 'dart:ui';
import 'dart:async';
import 'dart:io';

import 'package:rxdart/rxdart.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../objects/download_tracker.dart';
import '../objects/server.dart';
import '../objects/display_item.dart';

class DownloadManager {
  DownloadManager._privateConstructor();
  static final DownloadManager _instance =
      DownloadManager._privateConstructor();
  factory DownloadManager() {
    return _instance;
  }

  // streams
  late final BehaviorSubject<Map<String, DownloadTracker>> _downloadStream =
      BehaviorSubject<Map<String, DownloadTracker>>.seeded(downloadMap);

  Map<String, DownloadTracker> downloadMap = {};
  ReceivePort _port = ReceivePort();

  initDownloader() async {
    await FlutterDownloader.initialize();
    IsolateNameServer.registerPortWithName(
        _port.sendPort, 'downloader_send_port');
    // bindBackgroundIsolate();

    _port.listen((dynamic data) {
      _syncItem(data[0], data[1], data[2]);
    });

    FlutterDownloader.registerCallback(_callbackDownloader);
  }

  static void _callbackDownloader(id, status, progress) {
    print('Download task ($id) is in status ($status) and process ($progress)');
    final SendPort send =
        IsolateNameServer.lookupPortByName('downloader_send_port')!;
    send.send([id, status, progress]);
  }

  disposeDownloader() {}

  void dispose() {
    _downloadStream.close();
  }

  void unbindBackgroundIsolate() {
    IsolateNameServer.removePortNameMapping('downloader_send_port');
  }

  void bindBackgroundIsolate() {
    bool isSuccess = IsolateNameServer.registerPortWithName(
        _port.sendPort, 'downloader_send_port');
    if (!isSuccess) {
      unbindBackgroundIsolate();
      bindBackgroundIsolate();
      return;
    }
    _port.listen((dynamic data) {
      // if (debug) {
      //   print('UI Isolate Callback: $data');
      // }
      String id = data[0];
      DownloadTaskStatus status = data[1];
      int progress = data[2];

      _syncItem(id, status, progress);
    });
  }

  Future<void> _syncItem(
      String id, DownloadTaskStatus status, int progress) async {
    try {
      DownloadTracker dt = downloadMap[id]!;
      if (status == DownloadTaskStatus.complete) {
        // TODO: update queue items
      }

      // dt.referenceDisplayItem?.downloadProgress = progress;
      dt.progress = progress;
    } catch (err) {
      print(err);
    }
  }

  Future<void> downloadOneFile(
      String downloadUrl, String serverName, String filepath) async {
    String downloadDirectory = serverName + filepath;
    final dir = await getApplicationDocumentsDirectory();

    print(downloadUrl);
    print(filepath);

    String downloadTo = '${dir.path}/media/$downloadDirectory';

    if (new File(downloadTo).existsSync() == true) {
      print('exists!');
      return;
    }

    String lol = path.dirname(downloadTo);
    String filename = path.basename(downloadTo);

    new Directory(lol).createSync(recursive: true);
    Uri url = Uri.parse(downloadUrl);

    String? taskId = await FlutterDownloader.enqueue(
      url: downloadUrl,
      fileName: filename,
      savedDir: lol,
      showNotification:
          false, // show download progress in status bar (for Android)
      openFileFromNotification:
          false, // click on notification to open downloaded file (for Android)
    );

    downloadMap[taskId!] = new DownloadTracker(downloadUrl, downloadDirectory);
  }

  Stream<Map<String, DownloadTracker>> get downloadSream =>
      _downloadStream.stream;
}
