import 'dart:async';

import 'package:rxdart/rxdart.dart';

import '../objects/server.dart';
import 'api.dart';
import 'browser_list.dart';
import 'server_list.dart';

/// Polls the server's ytdl download tracker after a download is started,
/// mirroring the webapp's 3-second indicator. Exposes the number of
/// in-flight downloads so the browser can show a "Downloading N…" banner,
/// refreshes the file list once when a download completes in the
/// directory currently in view, and stops polling when nothing is active.
class YtdlManager {
  YtdlManager._privateConstructor();
  static final YtdlManager _instance = YtdlManager._privateConstructor();
  factory YtdlManager() => _instance;

  final BehaviorSubject<int> _activeCount = BehaviorSubject<int>.seeded(0);
  Stream<int> get activeCountStream => _activeCount.stream;
  int get activeCount => _activeCount.value;

  Timer? _timer;

  // The server the tracked download(s) were submitted to. Captured at start()
  // and used for every poll, so navigating to a different server can't make
  // the poll silently retarget it (and drop the banner).
  Server? _pollServer;

  // pids we've already reacted to on completion, so a lingering "complete"
  // entry in the server's tracker doesn't re-trigger a file-list refresh on
  // every poll. Cleared when polling stops / the bound server changes — pids
  // aren't comparable across servers and the set would otherwise grow forever.
  final Set<int> _handledComplete = {};

  /// Begin polling (no-op if already running). Call right after a successful
  /// ytdl() submit; binds to the submitting server so a later server switch
  /// can't retarget the poll.
  void start([Server? server]) {
    final s = server ?? ServerManager().currentServer;
    if (s == null) return;
    if (_pollServer != s) {
      _pollServer = s;
      _handledComplete.clear();
    }
    if (_timer != null) return;
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
  }

  Future<void> _poll() async {
    final server = _pollServer;
    if (server == null) {
      _stop();
      return;
    }
    List<Map<String, dynamic>> downloads;
    try {
      downloads = await ApiManager().ytdlDownloads(server: server);
    } catch (_) {
      return; // transient — try again next tick
    }

    final active = downloads.where((d) => d['status'] == 'downloading').length;
    _activeCount.add(active);

    // Refresh the file list once per completed download that landed in the
    // directory we're looking at — but only while the originating server is
    // still the one in view, so the refresh targets the right list.
    final dir = BrowserManager().currentDirectory;
    if (dir != null && ServerManager().currentServer == server) {
      for (final d in downloads) {
        final pid = d['pid'];
        if (d['status'] == 'complete' &&
            d['directory'] == dir &&
            pid is int &&
            !_handledComplete.contains(pid)) {
          _handledComplete.add(pid);
          ApiManager().getFileList(dir, useThisServer: server);
        }
      }
    }

    if (active == 0) _stop();
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
    _handledComplete.clear();
  }

  void dispose() {
    _stop();
    _activeCount.close();
  }
}
