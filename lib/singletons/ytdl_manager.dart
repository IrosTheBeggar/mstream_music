import 'dart:async';

import 'package:rxdart/rxdart.dart';

import 'api.dart';
import 'browser_list.dart';

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

  // pids we've already reacted to on completion, so a lingering
  // "complete" entry in the server's tracker doesn't re-trigger a file
  // list refresh on every poll.
  final Set<int> _handledComplete = {};

  /// Begin polling (no-op if already running). Call right after a
  /// successful ytdl() submit.
  void start() {
    if (_timer != null) return;
    _poll();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
  }

  Future<void> _poll() async {
    List<Map<String, dynamic>> downloads;
    try {
      downloads = await ApiManager().ytdlDownloads();
    } catch (_) {
      return; // transient — try again next tick
    }

    final active = downloads.where((d) => d['status'] == 'downloading').length;
    _activeCount.add(active);

    // Refresh the file list once per completed download that landed in
    // the directory we're looking at, so the new track appears.
    final dir = BrowserManager().currentDirectory;
    if (dir != null) {
      for (final d in downloads) {
        final pid = d['pid'];
        if (d['status'] == 'complete' &&
            d['directory'] == dir &&
            pid is int &&
            !_handledComplete.contains(pid)) {
          _handledComplete.add(pid);
          ApiManager().getFileList(dir);
        }
      }
    }

    if (active == 0) _stop();
  }

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  void dispose() {
    _stop();
    _activeCount.close();
  }
}
