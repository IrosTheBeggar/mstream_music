// Every transport command the audio handler is given, numbered. The preview
// player (media/preview_player.dart) pauses the song for a 30-second clip and
// resumes it afterwards only if nobody touched the song in between, and the
// number is how it tells: a pause of a song that is already paused (the sleep
// timer, a Siri or Assistant "pause", the handler's own becoming-noisy pause)
// changes no stream, but it does bump the number.
//
// The handler calls [TransportLog.note] as the FIRST statement of each of
// [TransportLog.verbs] (test/media/transport_log_test.dart pins that in the
// source), so an early return inside a verb can never skip it. That also
// logs the handler's own calls of those verbs: the queue-end stop, the Auto
// DJ park timing out, Auto DJ starting a session's first song. One of those
// landing while a clip plays ends the clip as the user touching the song
// (stop) or starting it (play), and the song stays where that left it. That
// is rare and harmless, so they are not routed around the log. Recovery
// paths that call the backend directly (the tunnel heal, a re-seed) are not
// commands and are not logged.

import 'dart:async';

/// One logged command: the number it got and the verb's name ('play',
/// 'pause', 'stop', 'seek', 'skipToNext', 'skipToPrevious',
/// 'skipToQueueItem').
typedef TransportCommand = ({int epoch, String command});

class TransportLog {
  /// The handler's verbs that note themselves, by the name they note.
  /// `click()` (headset and Bluetooth keys) goes through play and pause.
  static const List<String> verbs = [
    'play',
    'pause',
    'stop',
    'seek',
    'skipToNext',
    'skipToPrevious',
    'skipToQueueItem',
  ];

  int _epoch = 0;
  final StreamController<TransportCommand> _commands =
      StreamController<TransportCommand>.broadcast();

  /// The newest command's number; 0 before the first. Read it right after
  /// calling a verb to learn the number that call got: [note] bumps it
  /// synchronously, before the verb's first await.
  int get epoch => _epoch;

  /// Every command after it is noted, in order. Delivered asynchronously, so
  /// a listener that calls a verb and then reads [epoch] can tell its own
  /// command apart by number when it arrives.
  Stream<TransportCommand> get commands => _commands.stream;

  void note(String command) {
    _epoch++;
    _commands.add((epoch: _epoch, command: command));
  }
}
