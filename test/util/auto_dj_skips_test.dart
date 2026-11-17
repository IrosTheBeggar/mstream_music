import 'package:audio_service/audio_service.dart' show MediaItem;
import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/util/auto_dj_seeds.dart' show seedKey;
import 'package:mstream_music/util/auto_dj_skips.dart';

// Quick skips and the re-roll they can ask for (design E): which Next counts
// against a DJ pick, which ones move forward through the queue, which queued
// picks a re-roll may replace, and how many of its songs it queues.
void main() {
  group('isQuickSkip', () {
    bool quick(int heardMs,
            {int? durationMs = 240000, bool djPick = true, bool hasNext = true}) =>
        isQuickSkip(
            djPick: djPick,
            heardMs: heardMs,
            durationMs: durationMs,
            hasNext: hasNext);

    test('under a second heard is no verdict on the song', () {
      expect(quick(0), isFalse);
      expect(quick(999), isFalse);
    });

    test('one second up to just under a play is quick', () {
      expect(quick(1000), isTrue);
      expect(quick(29000), isTrue);
      expect(quick(29999), isTrue);
    });

    test('thirty seconds is a play, not a skip', () {
      expect(quick(30000), isFalse);
      expect(quick(120000), isFalse);
    });

    test('half of a short song is a play, not a skip', () {
      expect(quick(19999, durationMs: 40000), isTrue);
      expect(quick(20000, durationMs: 40000), isFalse);
    });

    test('with no duration known only the thirty seconds count', () {
      expect(quick(29999, durationMs: null), isTrue);
      expect(quick(30000, durationMs: null), isFalse);
      expect(quick(5000, durationMs: 0), isTrue);
    });

    test('a row that is neither a DJ pick nor the blended song is never a '
        'quick skip', () {
      expect(quick(5000, djPick: false), isFalse);
    });

    test('a Next that goes nowhere (repeat-one, the end) is no skip', () {
      expect(quick(5000, hasNext: false), isFalse);
    });
  });

  group('skipMovesForward', () {
    bool forward(int? index, int length, {bool shuffle = false}) =>
        skipMovesForward(index: index, queueLength: length, shuffle: shuffle);

    test('a Next from a row with rows after it moves forward', () {
      expect(forward(0, 5), isTrue);
      expect(forward(3, 5), isTrue);
    });

    test('a Next from the last row wraps, not forward', () {
      expect(forward(4, 5), isFalse);
      expect(forward(0, 1), isFalse);
    });

    test('nothing under shuffle, where play order is not queue order', () {
      expect(forward(1, 5, shuffle: true), isFalse);
    });

    test('no current row, no forward', () {
      expect(forward(null, 5), isFalse);
      expect(forward(-1, 5), isFalse);
      expect(forward(0, 0), isFalse);
    });
  });

  group('rerollDroppable', () {
    // A queue row as the handler builds it: a DJ pick carries djPick and its
    // server's bare path, a row the user queued a browsed '/'-path.
    MediaItem row(String path, {bool dj = true, String server = 'home'}) =>
        MediaItem(id: 'id:$path', title: path, extras: {
          'server': server,
          'path': path,
          if (dj) 'djPick': true,
        });

    List<int> droppable(List<MediaItem> q, int current,
            {bool Function(MediaItem)? onDisk,
            bool Function(String, String)? inFlight,
            bool shuffle = false}) =>
        rerollDroppable(q, current,
            onDisk: onDisk ?? (_) => false,
            inFlight: inFlight ?? (_, _) => false,
            shuffle: shuffle);

    test('only the picks strictly after the current row, nearest first', () {
      final q = [row('a'), row('b'), row('c'), row('d'), row('e')];
      expect(droppable(q, 2), [3, 4]);
      // The current row is a pick too, and it is playing.
      expect(droppable(q, 0), [1, 2, 3, 4]);
    });

    test('nothing after the last row', () {
      final q = [row('a'), row('b')];
      expect(droppable(q, 1), isEmpty);
    });

    test('rows the user queued stay, between picks too', () {
      final q = [
        row('a'),
        row('/Music/next.flac', dj: false),
        row('b'),
        row('/Music/later.flac', dj: false),
        row('c'),
      ];
      expect(droppable(q, 0), [2, 4]);
    });

    test('a pick on the phone stays', () {
      final q = [row('a'), row('b'), row('c')];
      expect(droppable(q, 0, onDisk: (m) => m.extras?['path'] == 'b'), [2]);
    });

    test('a pick on its way to the phone stays, by server and path', () {
      final q = [row('a'), row('b', server: 'nas'), row('b'), row('c')];
      final asked = <String>[];
      final out = droppable(q, 0, inFlight: (server, path) {
        asked.add('$server|$path');
        return server == 'nas' && path == 'b';
      });
      expect(out, [2, 3]);
      expect(asked, ['nas|b', 'home|b', 'home|c']);
    });

    test('nothing under shuffle', () {
      final q = [row('a'), row('b'), row('c')];
      expect(droppable(q, 0, shuffle: true), isEmpty);
    });

    test('a pick with no server or path can have no download running', () {
      final q = [
        row('a'),
        MediaItem(id: 'odd', title: 'odd', extras: const {'djPick': true}),
      ];
      expect(droppable(q, 0, inFlight: (_, _) => true), [1]);
    });
  });

  group('the rows a landing re-roll takes out', () {
    MediaItem row(String path, {bool dj = true, String server = 'home'}) =>
        MediaItem(id: 'id:$path', title: path, extras: {
          'server': server,
          'path': path,
          if (dj) 'djPick': true,
        });
    List<int> droppable(List<MediaItem> q, int current) => rerollDroppable(q,
        current,
        onDisk: (_) => false, inFlight: (_, _) => false, shuffle: false);
    List<String> paths(List<MediaItem> q, List<int> at) =>
        [for (final i in at) q[i].extras!['path'] as String];

    // [p0, p1, p2, p3, p4], all DJ picks: a learned skip of p2 lands on p3.
    final q = [for (var i = 0; i < 5; i++) row('p$i')];
    final stale = rerollStaleKeys(q, droppable(q, 3));

    test('the stale picks are the rows after the one the skip landed on', () {
      expect(stale, {seedKey('home', 'p4')});
      expect(rerollKey(q[4]), seedKey('home', 'p4'));
      expect(rerollKey(MediaItem(id: 'local', title: 'local')), isNull);
    });

    test('landing on that row, the nearest of them go first', () {
      expect(paths(q, rerollDrops(q, droppable(q, 3), picks: 4, stale: stale)),
          ['p4']);
    });

    test('the user went back to p0 meanwhile: the rows played are kept', () {
      // Measured from p0, every row after it is droppable; before, the
      // re-roll took p1..p4 (or p1, p2 of a two-song batch), the skipped p2
      // and the liked p1 among them.
      expect(paths(q, rerollDrops(q, droppable(q, 0), picks: 4)),
          ['p1', 'p2', 'p3', 'p4']);
      expect(paths(q, rerollDrops(q, droppable(q, 0), picks: 2, stale: stale)),
          ['p4']);
      expect(paths(q, rerollDrops(q, droppable(q, 0), picks: 4, stale: stale)),
          ['p4']);
    });

    test('never more than the re-roll brought, nearest first', () {
      final long = [for (var i = 0; i < 8; i++) row('p$i')];
      final named = rerollStaleKeys(long, droppable(long, 1));
      expect(
          paths(long,
              rerollDrops(long, droppable(long, 1), picks: 3, stale: named)),
          ['p2', 'p3', 'p4']);
      expect(rerollDrops(long, droppable(long, 1), picks: 0), isEmpty);
    });

    test('a URL rebuild while the re-roll waited swaps the rows, not the '
        'songs', () {
      final rebuilt = [for (final m in q) m.copyWith(id: '${m.id}?t=new')];
      expect(identical(rebuilt[4], q[4]), isFalse);
      expect(
          paths(rebuilt,
              rerollDrops(rebuilt, droppable(rebuilt, 3), picks: 4, stale: stale)),
          ['p4']);
    });

    test('with no stale picks named, the nearest droppable rows go', () {
      expect(paths(q, rerollDrops(q, droppable(q, 2), picks: 1)), ['p3']);
    });

    test('a user row is never named, a DJ row of another server is its own',
        () {
      final mixed = [
        row('a'),
        row('/Music/mine.flac', dj: false),
        row('b'),
        row('b', server: 'nas'),
      ];
      final named = rerollStaleKeys(mixed, droppable(mixed, 0));
      expect(named, {seedKey('home', 'b'), seedKey('nas', 'b')});
    });
  });

  group('learnedOnceVectorLands', () {
    bool lands(
            {bool learned = false,
            bool forward = true,
            bool sameLane = true,
            bool sentBefore = false,
            bool sentNow = true}) =>
        learnedOnceVectorLands(
            learned: learned,
            forward: forward,
            sameLane: sameLane,
            sentBefore: sentBefore,
            sentNow: sentNow);

    test('a new Less like song whose vector now reaches another server', () {
      expect(lands(), isTrue);
    });

    test('a re-skip whose cached vector was already going there: no news',
        () {
      expect(lands(sentBefore: true), isFalse);
    });

    test('nothing for a skip already learned, a wrap, a new lane, or a vector '
        'that reaches nobody', () {
      expect(lands(learned: true), isFalse);
      expect(lands(forward: false), isFalse);
      expect(lands(sameLane: false), isFalse);
      expect(lands(sentNow: false), isFalse);
    });
  });

  group('rerollQueueCount', () {
    test('one song for each stale pick taken out', () {
      expect(rerollQueueCount(picks: 4, dropped: 2, atEnd: false), 2);
      expect(rerollQueueCount(picks: 4, dropped: 4, atEnd: false), 4);
    });

    test('never more than the re-roll brought', () {
      expect(rerollQueueCount(picks: 2, dropped: 3, atEnd: false), 2);
    });

    test('the whole batch when the current row is now the last', () {
      expect(rerollQueueCount(picks: 4, dropped: 2, atEnd: true), 4);
      expect(rerollQueueCount(picks: 4, dropped: 0, atEnd: true), 4);
    });

    test('nothing when nothing could go and rows still lie ahead', () {
      expect(rerollQueueCount(picks: 4, dropped: 0, atEnd: false), 0);
    });
  });

  group('shouldRerunPick', () {
    bool rerun(
            {int genAtEntry = 0,
            int gen = 1,
            int rerolledGen = 0,
            bool sameLane = true,
            bool armed = true,
            bool pickPending = false}) =>
        shouldRerunPick(
            genAtEntry: genAtEntry,
            gen: gen,
            rerolledGen: rerolledGen,
            sameLane: sameLane,
            armed: armed,
            pickPending: pickPending);

    test('a learned skip while the pick was out, re-roll owed: run again', () {
      expect(rerun(), isTrue);
    });

    test('no skip while it was out: nothing to run', () {
      expect(rerun(genAtEntry: 1, rerolledGen: 0), isFalse);
      expect(rerun(genAtEntry: 3, gen: 3, rerolledGen: 3), isFalse);
    });

    test('the pick itself settled the re-roll: nothing owed', () {
      // It waited out the tunnel across the skip and was built after it.
      expect(rerun(rerolledGen: 1), isFalse);
    });

    test('a new lane, or the DJ off, owes nothing', () {
      expect(rerun(sameLane: false), isFalse);
      expect(rerun(armed: false), isFalse);
    });

    test('a deferred pick is left to its own retry', () {
      expect(rerun(pickPending: true), isFalse);
    });

    test('a run that settles cannot run again; a further skip can', () {
      // The re-run starts under generation 1 and lands as the re-roll.
      expect(rerun(genAtEntry: 1, gen: 1, rerolledGen: 1), isFalse);
      // Another learned skip came while the re-run was out.
      expect(rerun(genAtEntry: 1, gen: 2, rerolledGen: 1), isTrue);
    });
  });
}
