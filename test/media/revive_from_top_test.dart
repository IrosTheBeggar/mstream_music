import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/media/audio_stuff.dart';
import 'package:mstream_music/media/playback_backend.dart';

void main() {
  group('AudioPlayerHandler.shouldReviveFromTop', () {
    // Defaults are the reported case: a three-track queue played out with
    // shuffle and repeat off, the player still on the track that finished.
    bool top({
      bool queueFinished = true,
      bool onFinishedTrack = true,
      bool spotParked = false,
      int index = 2,
      int queueLength = 3,
      bool shuffle = false,
      BackendRepeat repeat = BackendRepeat.off,
    }) =>
        AudioPlayerHandler.shouldReviveFromTop(
            queueFinished: queueFinished,
            onFinishedTrack: onFinishedTrack,
            spotParked: spotParked,
            index: index,
            queueLength: queueLength,
            shuffle: shuffle,
            repeat: repeat);

    // The regression this exists for: the idle player keeps the finished
    // track's END as its position, the re-seed on Play loaded there, and the
    // load went ready → completed → stop with nothing heard.
    test('the last track of a queue that played out → from the top', () {
      expect(top(), isTrue);
    });

    test('a one-track queue → from the top', () {
      expect(top(index: 0, queueLength: 1), isTrue);
    });

    // A user stop in the middle of a track, an error park, a pause: the
    // position the player kept is where they were, and resuming there is the
    // whole point of the re-seed.
    test('no finished queue behind the revive → the position it kept', () {
      for (final onFinishedTrack in [true, false]) {
        for (final shuffle in [true, false]) {
          for (final repeat in BackendRepeat.values) {
            for (final index in [0, 2]) {
              expect(
                top(
                    queueFinished: false,
                    onFinishedTrack: onFinishedTrack,
                    index: index,
                    shuffle: shuffle,
                    repeat: repeat),
                isFalse,
                reason: 'onFinishedTrack=$onFinishedTrack shuffle=$shuffle '
                    '$repeat index=$index',
              );
            }
          }
        }
      }
    });

    // A parked spot is a place someone chose — a tapped row, a failed
    // restore's saved position — and the revive already loads there.
    test('a parked spot always wins', () {
      expect(top(spotParked: true), isFalse);
      expect(top(spotParked: true, onFinishedTrack: false), isFalse);
      expect(top(spotParked: true, index: 0, queueLength: 1), isFalse);
    });

    // "The queue ran out, I added an album, Play": loading the finished
    // track at its end is what rolls playback into the first new one.
    // Starting it over would play the old song through first.
    test('tracks queued after the end → kept, so playback moves on to them',
        () {
      expect(top(index: 2, queueLength: 4), isFalse);
      expect(top(index: 0, queueLength: 2), isFalse);
    });

    // Every load deals a fresh shuffle with the loaded row first, so the
    // rest of the queue follows it — unless there is no rest.
    test('shuffle → kept, a new shuffle follows; one track has no rest', () {
      expect(top(shuffle: true), isFalse);
      expect(top(shuffle: true, index: 0, queueLength: 3), isFalse);
      expect(top(shuffle: true, index: 0, queueLength: 1), isTrue);
    });

    // Repeat can only have been switched on after the end (a repeating queue
    // never ends). All wraps to the first row; one starts the track over.
    test('repeat all / one → kept, the player moves on by itself', () {
      expect(top(repeat: BackendRepeat.all), isFalse);
      expect(top(repeat: BackendRepeat.one), isFalse);
      expect(top(repeat: BackendRepeat.all, index: 0, queueLength: 1),
          isFalse);
      expect(top(repeat: BackendRepeat.one, shuffle: true), isFalse);
    });

    // The finished track's row was removed, or the queue was cleared and
    // refilled: the kept position is another track's end. Tapping a song
    // after clearing a finished queue loaded the new song there and stopped.
    test('no longer on the track that finished → from the top, whatever '
        'follows', () {
      expect(top(onFinishedTrack: false, index: 0, queueLength: 1), isTrue);
      expect(top(onFinishedTrack: false, index: 0, queueLength: 3), isTrue);
      expect(top(onFinishedTrack: false, shuffle: true), isTrue);
      for (final repeat in BackendRepeat.values) {
        expect(top(onFinishedTrack: false, index: 1, repeat: repeat), isTrue,
            reason: '$repeat');
      }
    });

    // The caller clamps the index, but an out-of-range one must still read
    // as "nothing after it", never as a reason to keep a dead-end position.
    test('an index at or past the last row has nothing after it', () {
      expect(top(index: 3, queueLength: 3), isTrue);
      expect(top(index: 0, queueLength: 0), isTrue);
    });
  });
}
