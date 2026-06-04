import 'dart:async';

import 'package:rxdart/rxdart.dart';

import 'media.dart';

/// Session-only countdown that pauses playback when it fires. Not
/// persisted — sleep timers shouldn't survive an app restart (waking
/// up to yesterday's 30-minute timer firing mid-song is hostile).
class SleepTimerManager {
  SleepTimerManager._privateConstructor();
  static final SleepTimerManager _instance =
      SleepTimerManager._privateConstructor();
  factory SleepTimerManager() => _instance;

  Timer? _ticker;

  // null = inactive. Non-null = remaining time, refreshed every second
  // so the picker sheet can show a live countdown.
  final BehaviorSubject<Duration?> _remaining =
      BehaviorSubject<Duration?>.seeded(null);

  Stream<Duration?> get remainingStream => _remaining.stream;
  Duration? get remaining => _remaining.value;
  bool get active => _ticker != null;

  void start(Duration d) {
    cancel();
    final ends = DateTime.now().add(d);
    _remaining.add(d);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final left = ends.difference(DateTime.now());
      if (left.inMilliseconds <= 0) {
        _fire();
      } else {
        _remaining.add(left);
      }
    });
  }

  void cancel() {
    _ticker?.cancel();
    _ticker = null;
    _remaining.add(null);
  }

  void _fire() {
    _ticker?.cancel();
    _ticker = null;
    _remaining.add(null);
    MediaManager().audioHandler.pause();
  }

  void dispose() {
    _ticker?.cancel();
    _remaining.close();
  }
}
