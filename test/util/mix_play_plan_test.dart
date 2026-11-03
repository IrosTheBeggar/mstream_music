// Play on an Instant mix keeps a playing seed going (mixPlayPlan, the pure
// half of playMix): when the mix's first row is the queue item playing now
// — same server, same path — every other queue position goes, last first,
// and the playing one stays; anything else is no plan, and Play starts the
// mix over.
//
// playMix itself, on a stand-in handler: the queue it leaves is the seed
// and rows 2…n, in order, whatever Auto DJ does meanwhile.

import 'package:audio_service/audio_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/media/audio_stuff.dart';
import 'package:mstream_music/media/playback_backend.dart';
import 'package:mstream_music/objects/display_item.dart';
import 'package:mstream_music/objects/metadata.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/util/queue_actions.dart';

MediaItem _item(String server, String path) => MediaItem(
    id: 'http://$server.example/media$path',
    title: path,
    extras: {'server': server, 'path': path});

/// The app's audio handler as far as Play on a mix reaches it. A removal
/// changes the list before the index moves (AudioPlayerHandler's order),
/// and an index that moves onto the last row with Auto DJ armed is a top-up
/// (its currentIndex listener, shouldTopUpAutoDJ) — here the pick lands at
/// once, as from a fast server.
class _Handler extends BaseAudioHandler {
  _Handler(List<MediaItem> items, int current, {this.djArmed = false}) {
    queue.add(items);
    playbackState.add(PlaybackState(
        queueIndex: current,
        playing: true,
        processingState: AudioProcessingState.ready));
  }

  final bool djArmed;
  int topUps = 0;

  List<String?> get paths =>
      [for (final m in queue.value) m.extras?['path'] as String?];

  @override
  Future<void> removeQueueItemAt(int index) async {
    queue.add(queue.value..removeAt(index));
    final current = playbackState.value.queueIndex!;
    if (index > current) return; // the playing index stays put
    final now = current - 1;
    playbackState.add(playbackState.value.copyWith(queueIndex: now));
    if (djArmed &&
        AudioPlayerHandler.shouldTopUpAutoDJ(
            index: now,
            queueLength: queue.value.length,
            state: BackendProcessingState.ready,
            inFailureWalk: false)) {
      topUps++;
      queue.add(queue.value..add(_item('home', '/dj-pick-$topUps.mp3')));
    }
  }

  @override
  Future<void> addQueueItems(List<MediaItem> mediaItems) async =>
      queue.add(queue.value..addAll(mediaItems));

  @override
  Future<void> play() async =>
      playbackState.add(playbackState.value.copyWith(playing: true));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final queue = [
    _item('home', '/a.mp3'),
    _item('home', '/dolo.mp3'),
    _item('home', '/c.mp3'),
    _item('home', '/d.mp3'),
  ];

  test('the lead is the playing item: every other position, last first', () {
    expect(mixPlayPlan(queue, 1, server: 'home', path: '/dolo.mp3'),
        [3, 2, 0]);
  });

  test("an Auto DJ pick (queued under random-songs' path, no leading "
      "slash) playing is the lead's track", () {
    final dj = [
      _item('home', '/a.mp3'),
      const MediaItem(
          id: 'http://home.example/media/dolo.mp3',
          title: 'dolo',
          extras: {'server': 'home', 'path': 'dolo.mp3', 'djPick': true}),
    ];
    expect(mixPlayPlan(dj, 1, server: 'home', path: '/dolo.mp3'), [0]);
  });

  test('a playing item alone in the queue: nothing to remove', () {
    expect(
        mixPlayPlan([queue[1]], 0, server: 'home', path: '/dolo.mp3'), isEmpty);
  });

  test('the lead is another track, or on another server: no plan', () {
    expect(mixPlayPlan(queue, 0, server: 'home', path: '/dolo.mp3'), isNull,
        reason: 'Dolo is queued, but not the one playing');
    expect(mixPlayPlan(queue, 1, server: 'work', path: '/dolo.mp3'), isNull);
    expect(mixPlayPlan(queue, 1, server: 'home', path: null), isNull);
  });

  test('nothing current, or a position out of range: no plan', () {
    expect(mixPlayPlan(queue, null, server: 'home', path: '/dolo.mp3'),
        isNull);
    expect(mixPlayPlan(queue, -1, server: 'home', path: '/dolo.mp3'), isNull);
    expect(mixPlayPlan(queue, 4, server: 'home', path: '/dolo.mp3'), isNull);
    expect(mixPlayPlan(const [], 0, server: 'home', path: '/dolo.mp3'),
        isNull);
  });

  test('a local file (no server) never matches a server row', () {
    final local = [
      const MediaItem(
          id: 'local', title: 'x', extras: {'path': '/x.mp3', 'localPath': '/x.mp3'}),
    ];
    expect(mixPlayPlan(local, 0, server: 'home', path: '/x.mp3'), isNull);
  });

  group('playMix, when the seed is the track playing', () {
    final server = Server('http://music.example', null, null, 'JWT', 'home');

    // The rows' builds look for an on-device copy through path_provider; a
    // VM test has no platform side, so answer it (there is no copy).
    setUpAll(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
              const MethodChannel('plugins.flutter.io/path_provider'),
              (_) async => '/nonexistent-play-mix-test-dir');
    });

    // A mix row with its full metadata block, so nothing is fetched.
    DisplayItem row(String path) =>
        DisplayItem(server, path, 'file', path, null, null)
          ..metadata = MusicMetadata(
              'Boukmanflow', null, path, null, null, null, 'h-$path', null,
              null);
    final rows = [row('/dolo.mp3'), row('/r2.mp3'), row('/r3.mp3')];

    test('Auto DJ armed: the seed plays on, rows 2…n follow it, and the '
        'removals set off no pick', () async {
      // An Auto DJ session's queue: what played, the seed, the next pick.
      final seed = _item('home', '/dolo.mp3');
      final h = _Handler([
        _item('home', '/p1.mp3'),
        _item('home', '/p2.mp3'),
        seed,
        _item('home', '/next.mp3'),
      ], 2, djArmed: true);
      await playMix(rows, audio: h);
      expect(h.paths, ['/dolo.mp3', '/r2.mp3', '/r3.mp3'],
          reason: 'no Auto DJ pick between the seed and row 2');
      expect(h.topUps, 0,
          reason: 'the playing track is never the last row while the rest '
              'leave');
      expect(identical(h.queue.value.first, seed), isTrue,
          reason: 'the playing item itself stays');
      expect(h.playbackState.value.queueIndex, 0);
    });

    test('the playing Auto DJ pick (its path without the leading slash) '
        'plays on, not over', () async {
      final pick = MediaItem(
          id: 'http://music.example/media/dolo.mp3',
          title: 'dolo',
          extras: {'server': 'home', 'path': 'dolo.mp3', 'djPick': true});
      final h = _Handler([_item('home', '/p1.mp3'), pick], 1);
      await playMix(rows, audio: h);
      expect(h.paths, ['dolo.mp3', '/r2.mp3', '/r3.mp3']);
      expect(identical(h.queue.value.first, pick), isTrue,
          reason: 'kept, not rebuilt and started again');
    });

    test('a song that joined the queue while the rows were built leaves '
        'too: the queue becomes the mix', () async {
      final h = _Handler([_item('home', '/p1.mp3'), _item('home', '/dolo.mp3')],
          1);
      final done = playMix(rows, audio: h);
      // An Auto DJ pick already on its way, landing during the builds.
      h.queue.add(h.queue.value..add(_item('home', '/late-pick.mp3')));
      await done;
      expect(h.paths, ['/dolo.mp3', '/r2.mp3', '/r3.mp3']);
    });

    test('an old item equal to a mix row (same song, same id) still leaves: '
        'by identity, not by id', () async {
      final h = _Handler([
        _item('home', '/dolo.mp3'),
        MediaItem(
            id: 'http://music.example/media/r2.mp3?token=JWT',
            title: 'old r2',
            extras: {'server': 'home', 'path': '/r2.mp3'}),
      ], 0);
      await playMix(rows, audio: h);
      expect(h.paths, ['/dolo.mp3', '/r2.mp3', '/r3.mp3']);
      expect(h.queue.value.map((m) => m.title), isNot(contains('old r2')));
    });
  });
}
