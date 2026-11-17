// The Seeds page's rows in auto_dj.json: what outlives the app
// ('pinnedSeeds': in Drift the rows the user pinned, in Stay close every row
// the page showed, each with its own 'pinned', and 'seedsFrozenAt', when
// those lists froze), the "Clear pins when the queue is cleared" box
// ('clearPinsOnQueueClear', off by default), and the opening song's mark
// that the user chose it ('sonicSeedChosen').
//
// The manager reads the stored rows one entry at a time and skips any entry
// that isn't one, so a bad entry can't cost the keys after it (_load is one
// try block); seedsFrozenAt's reader never throws either (its junk values
// are storedTimeFromJson's VM cases, since this file holds one load). It
// holds what it read as it was: the server filter and the cap per list
// (eight, sixteen for a file written in Stay close) belong to the audio
// handler's launch load (restorablePinnedRows), since the manager loads
// before the server list.
//
// load() is memoized for the app's life, so this file holds the one load; the
// tests after it build on what it read. _save goes through path_provider,
// pointed at a scratch folder, so the file is real.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/play_event.dart';
import 'package:mstream_music/singletons/auto_dj_manager.dart';
import 'package:mstream_music/util/auto_dj_seeds.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mgr = AutoDJManager();
  late Directory scratch;
  File file() => File('${scratch.path}/auto_dj.json');
  Map<String, dynamic> saved() =>
      jsonDecode(file().readAsStringSync()) as Map<String, dynamic>;

  setUpAll(() {
    scratch = Directory.systemTemp.createTempSync('mstream-auto-dj-pins-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => scratch.path);
  });
  tearDownAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'), null);
    try {
      scratch.deleteSync(recursive: true);
    } catch (_) {}
  });

  /// Runs [body] and counts the change ticks it caused.
  Future<int> ticks(Future<void> Function() body) async {
    var n = 0;
    // A BehaviorSubject replays its last value on listen: skip it.
    final sub = mgr.changeStream.skip(1).listen((_) => n++);
    await body();
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();
    return n;
  }

  const at = 1763380800000; // 2025-11-17 12:00 UTC, in ms

  // One stored row as the app writes it (storedSeedToJson); without
  // [pinned], as a build from before the key wrote it.
  Map<String, Object?> pin(String list, String path,
          {String server = 'home', String? origin = 'manual', bool? pinned}) =>
      {
        'list': list,
        'song': {'srv': server, 'p': path, 'ti': path},
        'origin': ?origin,
        'pinned': ?pinned,
        'at': at,
      };

  // When the stored lists froze, in the fixture.
  const frozenAt = at + 5000;

  // The stored pins as "list:wirePath", in order.
  List<String> listed(Iterable<StoredSeed> rows) => [
        for (final r in rows)
          '${r.list == SeedList.moreLike ? 'more' : 'less'}:${r.seed.wirePath}',
      ];

  final nine = [for (var i = 0; i < 9; i++) 'more:Music/m$i.flac'];

  test('the load: each good row kept as read with its own pin, junk skipped, '
      'later keys still loaded', () async {
    file().writeAsStringSync(jsonEncode({
      'sonicAnchorMode': 'locked',
      'learnFromSkips': true,
      'pinnedSeeds': [
        pin('lessLike', '/Music/good.flac', origin: 'skip'),
        'not a map',
        {'list': 'moreLike'}, // no song
        pin('moreLike', '/sdcard/local.mp3', server: ''), // a local file
        pin('maybeLike', '/Music/unknown-list.flac'),
        pin('lessLike', '/Music/new-origin.flac', origin: 'fromTheFuture'),
        // A row Stay close kept that the user never pinned.
        pin('lessLike', '/Music/unpinned.flac', origin: 'skip', pinned: false),
        // More than a list holds: the launch load caps, not this.
        for (var i = 0; i < 9; i++)
          pin('moreLike', '/Music/m$i.flac', pinned: true),
      ],
      // Keys the load reads after pinnedSeeds.
      'seedsFrozenAt': frozenAt,
      'sonicSeedPath': 'Music/seed.flac',
      'sonicSeedTitle': 'Seed',
      'sonicSeedServer': 'home',
      'sonicSeedChosen': true,
      'emptyQueueStart': 'random',
      'durationFilterEnabled': true,
      'minDurationSec': 90,
      'maxDurationSec': 600,
      'durationCeilSec': 86400,
      'enabledServer': 'home',
      'playFromServer': 'home',
      'playFromServers': ['home'],
    }));

    final n = await ticks(mgr.load);

    expect(n, 1, reason: 'the load read the file to the end');
    expect(listed(mgr.pinnedSeeds), [
      'less:Music/good.flac',
      'less:Music/new-origin.flac',
      'less:Music/unpinned.flac',
      ...nine,
    ]);
    expect([for (final r in mgr.pinnedSeeds) r.seed.pinned],
        [true, true, false, for (var i = 0; i < 9; i++) true],
        reason: 'only an explicit false reads unpinned; a file from before '
            'the key held pins alone');
    expect(mgr.pinnedSeeds.first.seed.origin, SeedOrigin.skip);
    expect(mgr.pinnedSeeds.first.seed.addedAt.millisecondsSinceEpoch, at);
    expect(mgr.pinnedSeeds.first.seed.song.path, '/Music/good.flac');
    expect(mgr.pinnedSeeds[1].seed.origin, SeedOrigin.manual,
        reason: 'an unknown origin reads as the user\'s own');
    expect(mgr.seedsFrozenAt?.millisecondsSinceEpoch, frozenAt);
    // Absent, the box reads as off.
    expect(mgr.clearPinsOnQueueClear, isFalse);
    // Every key after the pins still loaded.
    expect(mgr.sonicAnchorMode, SonicAnchorMode.locked);
    expect(mgr.learnFromSkips, isTrue);
    expect(mgr.sonicSeedPath, 'Music/seed.flac');
    expect(mgr.sonicSeedServer, 'home');
    expect(mgr.sonicSeedChosen, isTrue);
    expect(mgr.emptyQueueStart, EmptyQueueStart.random);
    expect(mgr.durationFilterEnabled, isTrue);
    expect(mgr.minDurationSec, 90);
    expect(mgr.maxDurationSec, 600);
    expect(mgr.enabledServer, 'home');
    expect(mgr.playFromServer, 'home');
  });

  test('another setter\'s save keeps the rows as read, when they froze, the '
      'chosen mark and the box', () async {
    await mgr.setEmptyQueueStart(EmptyQueueStart.pick);
    final file = saved();
    expect(file['emptyQueueStart'], 'pick');
    expect(file['clearPinsOnQueueClear'], false);
    expect(file['seedsFrozenAt'], frozenAt);
    expect(file['sonicSeedChosen'], true);
    final pins = file['pinnedSeeds'] as List;
    expect(pins.length, 12, reason: 'the junk entries are gone');
    final back = [
      for (final e in pins) storedSeedFromJson(e, now: DateTime(2000)),
    ];
    expect(back.every((r) => r != null), isTrue);
    expect(listed(back.nonNulls), listed(mgr.pinnedSeeds));
    expect([for (final e in pins) (e as Map)['pinned']],
        [true, true, false, for (var i = 0; i < 9; i++) true],
        reason: 'every row is written with its own pin');
    expect((pins[1] as Map)['origin'], 'manual');
    expect((pins.first as Map)['at'], at);
  });

  test('setClearPinsOnQueueClear notifies and saves; unchanged, it does '
      'nothing', () async {
    expect(await ticks(() => mgr.setClearPinsOnQueueClear(true)), 1);
    expect(mgr.clearPinsOnQueueClear, isTrue);
    expect(saved()['clearPinsOnQueueClear'], true);

    // No change: no tick, and no write (the file stays gone).
    file().deleteSync();
    expect(await ticks(() => mgr.setClearPinsOnQueueClear(true)), 0);
    expect(file().existsSync(), isFalse);

    expect(await ticks(() => mgr.setClearPinsOnQueueClear(false)), 1);
    expect(saved()['clearPinsOnQueueClear'], false);
    await mgr.setClearPinsOnQueueClear(true);
  });

  test('setPinnedSeeds saves without a tick', () async {
    final rows = <StoredSeed>[
      (
        list: SeedList.moreLike,
        seed: AutoDjSeed(
            song: const TrackFacts(
                server: 'lab', path: '/Music/a.flac', title: 'A'),
            pinned: true,
            origin: SeedOrigin.pick,
            addedAt: DateTime.fromMillisecondsSinceEpoch(at),
            vector: 'VEC',
            vectorModel: 'm'),
      ),
      (
        list: SeedList.lessLike,
        seed: AutoDjSeed(
            song: const TrackFacts(server: 'home', path: 'Music/b.flac'),
            pinned: true,
            origin: SeedOrigin.manual,
            addedAt: DateTime.fromMillisecondsSinceEpoch(at + 1000)),
      ),
    ];
    expect(await ticks(() => mgr.setPinnedSeeds(rows)), 0);
    expect(listed(mgr.pinnedSeeds), ['more:Music/a.flac', 'less:Music/b.flac']);
    final pins = saved()['pinnedSeeds'] as List;
    expect(pins, [
      {
        'list': 'moreLike',
        'song': const TrackFacts(
                server: 'lab', path: '/Music/a.flac', title: 'A')
            .toJson(),
        'origin': 'pick',
        'pinned': true,
        'at': at,
      },
      {
        'list': 'lessLike',
        'song': const TrackFacts(server: 'home', path: 'Music/b.flac').toJson(),
        'origin': 'manual',
        'pinned': true,
        'at': at + 1000,
      },
    ]);
    // Saved in Drift: no frozenAt.
    expect(mgr.seedsFrozenAt, isNull);
    expect(saved()['seedsFrozenAt'], isNull);
    // The box rides along with every save.
    expect(saved()['clearPinsOnQueueClear'], true);
  });

  test('a later save of another setting keeps the saved pins', () async {
    await mgr.setLearnFromSkips(false);
    final file = saved();
    expect(file['learnFromSkips'], false);
    expect(file['clearPinsOnQueueClear'], true);
    expect(
        listed([
          for (final e in file['pinnedSeeds'] as List)
            ?storedSeedFromJson(e, now: DateTime(2000)),
        ]),
        ['more:Music/a.flac', 'less:Music/b.flac']);
  });

  test('setPinnedSeeds saves when the lists froze with the rows; without it, '
      'none', () async {
    final kept = mgr.pinnedSeeds;
    // Stay close's rows: one the user never pinned.
    final shown = <StoredSeed>[
      (
        list: SeedList.moreLike,
        seed: AutoDjSeed(
            song: const TrackFacts(server: 'home', path: 'Music/c.flac'),
            origin: SeedOrigin.anchor,
            addedAt: DateTime.fromMillisecondsSinceEpoch(at)),
      ),
      ...kept,
    ];
    final froze = DateTime.fromMillisecondsSinceEpoch(at + 9000);
    expect(await ticks(() => mgr.setPinnedSeeds(shown, frozenAt: froze)), 0);
    expect(mgr.seedsFrozenAt, froze);
    var file = saved();
    expect(file['seedsFrozenAt'], at + 9000);
    expect([for (final e in file['pinnedSeeds'] as List) (e as Map)['pinned']],
        [false, true, true]);
    expect((file['pinnedSeeds'] as List).first['origin'], 'anchor');

    // Back in Drift: the pins alone, and no frozenAt.
    await mgr.setPinnedSeeds(kept);
    expect(mgr.seedsFrozenAt, isNull);
    file = saved();
    expect(file['seedsFrozenAt'], isNull);
    expect(listed([
      for (final e in file['pinnedSeeds'] as List)
        ?storedSeedFromJson(e, now: DateTime(2000)),
    ]), ['more:Music/a.flac', 'less:Music/b.flac']);
  });

  test('setSonicSeed saves the mark of a chosen song; without it, none; the '
      'clear takes it with the seed', () async {
    await mgr.setSonicSeed(
        path: '/Music/c.flac', title: 'C', server: 'home', chosen: true);
    expect(mgr.sonicSeedChosen, isTrue);
    expect(saved()['sonicSeedPath'], 'Music/c.flac');
    expect(saved()['sonicSeedChosen'], true);

    // Random's song: no mark.
    await mgr.setSonicSeed(path: '/Music/d.flac', title: 'D', server: 'home');
    expect(mgr.sonicSeedChosen, isFalse);
    expect(saved()['sonicSeedPath'], 'Music/d.flac');
    expect(saved()['sonicSeedChosen'], false);

    await mgr.setSonicSeed(
        path: '/Music/e.flac', title: 'E', server: 'home', chosen: true);
    await mgr.clearSonicSeed();
    expect(mgr.sonicSeedChosen, isFalse);
    expect(saved()['sonicSeedPath'], isNull);
    expect(saved()['sonicSeedChosen'], false);
  });

  test('clearing the pins saves an empty list; clearing none writes nothing',
      () async {
    await mgr.setPinnedSeeds(const []);
    expect(mgr.pinnedSeeds, isEmpty);
    expect(saved()['pinnedSeeds'], isEmpty);

    file().deleteSync();
    expect(await ticks(() => mgr.setPinnedSeeds(const [])), 0);
    expect(file().existsSync(), isFalse);
  });
}
