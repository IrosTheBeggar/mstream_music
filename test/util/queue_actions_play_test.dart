// Starting playback from an add. The first add onto an empty queue starts
// playing, and the handler's play() returns late: on an idle player only
// once the first song has loaded (about 1.2 s on the emulator, longer on a
// slow link), and otherwise as just_audio's play(), whose future completes
// only when playback stops. The add helpers awaited it, so a caller waiting
// on them for its "added to queue" toast got the toast that late. Now they
// start playback and return at once. The fake player takes the worst case:
// its play() does not return while the song plays.

import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/media/audio_stuff.dart';
import 'package:mstream_music/objects/display_item.dart';
import 'package:mstream_music/singletons/media.dart';
import 'package:mstream_music/singletons/settings.dart';
import 'package:mstream_music/util/queue_actions.dart';
import 'package:rxdart/rxdart.dart';

/// A player whose play() does not return while the song plays.
class _Player implements AudioPlayerHandler {
  @override
  final BehaviorSubject<List<MediaItem>> queue =
      BehaviorSubject.seeded(const []);
  int plays = 0;
  Completer<void>? _playing;

  /// play() was called and has not returned: the song is still playing.
  bool get playing => _playing != null && !_playing!.isCompleted;

  @override
  Future<void> addQueueItems(List<MediaItem> mediaItems) async =>
      queue.add([...queue.value, ...mediaItems]);

  @override
  Future<void> addQueueItem(MediaItem mediaItem) async =>
      queue.add([...queue.value, mediaItem]);

  @override
  Future<void> play() {
    plays++;
    return (_playing ??= Completer<void>()).future;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

List<DisplayItem> _songs(int n) => [
      for (var i = 1; i <= n; i++)
        DisplayItem(null, 'Song $i.mp3', 'localFile',
            '/storage/music/Song $i.mp3', null, null),
    ];

/// Fails at once, rather than at the test's timeout, if [f] waits for
/// playback.
Future<T> _soon<T>(Future<T> f) => f.timeout(const Duration(seconds: 2));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Player player;

  setUp(() {
    player = _Player();
    MediaManager().audioHandler = player;
  });
  tearDown(() => SettingsManager().tapBehavior = TapBehavior.playFromHere);

  group('addRowsToQueue', () {
    test(
        'onto an empty queue: starts playback and returns its count while '
        'the first song plays', () async {
      expect(await _soon(addRowsToQueue(_songs(3))), 3);
      expect(player.queue.value, hasLength(3));
      expect(player.plays, 1);
      expect(player.playing, isTrue);
    });

    test('onto a queue with songs: appends and leaves playback alone',
        () async {
      player.queue.add([MediaItem(id: 'now', title: 'Now playing')]);
      expect(await _soon(addRowsToQueue(_songs(2))), 2);
      expect(player.queue.value, hasLength(3));
      expect(player.plays, 0);
    });
  });

  group('handleTrackTap with Add to queue', () {
    setUp(() => SettingsManager().tapBehavior = TapBehavior.addToQueue);

    test(
        'onto an empty queue: starts playback and reports the add while the '
        'song plays', () async {
      expect(await _soon(handleTrackTap(_songs(3), 1)), isTrue);
      expect(player.queue.value.single.title, 'Song 2.mp3');
      expect(player.plays, 1);
      expect(player.playing, isTrue);
    });

    test('onto a queue with songs: reports the add and leaves playback alone',
        () async {
      player.queue.add([MediaItem(id: 'now', title: 'Now playing')]);
      expect(await _soon(handleTrackTap(_songs(3), 0)), isTrue);
      expect(player.queue.value, hasLength(2));
      expect(player.plays, 0);
    });
  });
}
