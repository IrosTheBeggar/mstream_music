// The Auto DJ screen's whole-sheet setters on AutoDJManager: each sheet's
// Done hands its draft over in one call, which sets the values, derives the
// switch from them (nothing chosen, or a window at both rails, is off), saves
// auto_dj.json and notifies the screen once. Play from is remembered across
// launches.
//
// _save goes through path_provider, which a VM test has no platform side
// for; the channel is pointed at a scratch folder, so the file is real.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/mood_filter.dart';
import 'package:mstream_music/singletons/auto_dj_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final mgr = AutoDJManager();
  late Directory scratch;

  Map<String, dynamic> saved() => jsonDecode(
          File('${scratch.path}/auto_dj.json').readAsStringSync())
      as Map<String, dynamic>;

  setUpAll(() {
    scratch = Directory.systemTemp.createTempSync('mstream-auto-dj-sheets-');
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

  setUp(() {
    // A singleton: every test starts from the field defaults.
    mgr
      ..moodFilterEnabled = false
      ..moodFilter = MoodFilter.empty
      ..durationFilterEnabled = false
      ..minDurationSec = 120
      ..maxDurationSec = AutoDJManager.durationCeilSec
      ..allowUnknownDuration = false
      ..keywordFilterEnabled = false
      ..keywordFilterWords = []
      ..bpmContinuityEnabled = false
      ..bpmTolerance = 8
      ..sonicSimilarityEnabled = true
      ..sonicMinSimilarity = 0.55
      ..sonicAnchorMode = SonicAnchorMode.rolling
      ..playFromServer = null;
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

  group('setMood', () {
    const relaxed = MoodFilter(energy: 'relaxed', voice: 'instrumental');

    test('a choice is the filter on, and saved', () async {
      expect(await ticks(() => mgr.setMood(relaxed)), 1);
      expect(mgr.moodFilter, relaxed);
      expect(mgr.moodFilterEnabled, isTrue);
      expect(mgr.activeMoodFilter, relaxed);
      expect(saved()['moodFilterEnabled'], isTrue);
      expect(saved()['moodFilter'], {'energy': 'relaxed', 'voice': 'instrumental'});
    });

    test('nothing chosen is the filter off', () async {
      await mgr.setMood(relaxed);
      expect(await ticks(() => mgr.setMood(MoodFilter.empty)), 1);
      expect(mgr.moodFilter.isEmpty, isTrue);
      expect(mgr.moodFilterEnabled, isFalse);
      expect(mgr.activeMoodFilter, isNull);
      expect(saved()['moodFilterEnabled'], isFalse);
    });

    test('tags alone count as a choice', () async {
      await mgr.setMood(const MoodFilter(tags: ['party']));
      expect(mgr.moodFilterEnabled, isTrue);
    });
  });

  group('setDurationFilter', () {
    const floor = AutoDJManager.durationFloorSec;
    const ceil = AutoDJManager.durationCeilSec;

    test('a window is the filter on', () async {
      expect(
          await ticks(() => mgr.setDurationFilter(
              minSec: 120, maxSec: 360, allowUnknown: true)),
          1);
      expect(mgr.durationFilterEnabled, isTrue);
      expect((mgr.minDurationSec, mgr.maxDurationSec), (120, 360));
      expect(mgr.allowUnknownDuration, isTrue);
      expect(mgr.activeDurationBounds, (min: 120, max: 360));
      final f = saved();
      expect(f['durationFilterEnabled'], isTrue);
      expect(f['minDurationSec'], 120);
      expect(f['maxDurationSec'], 360);
      expect(f['allowUnknownDuration'], isTrue);
    });

    test('one bound off its rail is enough', () async {
      await mgr.setDurationFilter(minSec: 90, maxSec: ceil, allowUnknown: false);
      expect(mgr.durationFilterEnabled, isTrue);
      expect(mgr.activeDurationBounds, (min: 90, max: null));
      await mgr.setDurationFilter(minSec: floor, maxSec: 600, allowUnknown: false);
      expect(mgr.durationFilterEnabled, isTrue);
      expect(mgr.activeDurationBounds, (min: null, max: 600));
    });

    test('both rails is "Any": the filter off', () async {
      await mgr.setDurationFilter(minSec: 120, maxSec: 360, allowUnknown: false);
      await mgr.setDurationFilter(
          minSec: floor, maxSec: ceil, allowUnknown: false);
      expect(mgr.durationFilterEnabled, isFalse);
      expect(mgr.activeDurationBounds, isNull);
      expect(saved()['durationFilterEnabled'], isFalse);
    });

    test('a maximum of 0 is no maximum, as on the wheel', () async {
      await mgr.setDurationFilter(minSec: 120, maxSec: 0, allowUnknown: false);
      expect((mgr.minDurationSec, mgr.maxDurationSec), (120, ceil));
      expect(mgr.activeDurationBounds, (min: 120, max: null));
      mgr
        ..durationFilterEnabled = true
        ..minDurationSec = 120
        ..maxDurationSec = 0;
      expect(mgr.activeDurationBounds, (min: 120, max: null),
          reason: 'however it got there, 0 is never sent as a maximum');
    });

    test("to the second, and past the old slider's 20 minutes", () async {
      await mgr.setDurationFilter(minSec: 97, maxSec: 3930, allowUnknown: false);
      expect(mgr.activeDurationBounds, (min: 97, max: 3930));
      expect(saved()['durationCeilSec'], ceil,
          reason: 'the file says what "no maximum" was when it was written');
    });

    test('outside the ends is clamped onto them; an inverted pair swaps',
        () async {
      await mgr.setDurationFilter(
          minSec: -30, maxSec: 90000, allowUnknown: false);
      expect((mgr.minDurationSec, mgr.maxDurationSec), (floor, ceil));
      expect(mgr.durationFilterEnabled, isFalse,
          reason: 'clamped onto both ends is Any');

      await mgr.setDurationFilter(minSec: 600, maxSec: 120, allowUnknown: false);
      expect((mgr.minDurationSec, mgr.maxDurationSec), (120, 600));
      expect(mgr.durationFilterEnabled, isTrue);
    });
  });

  group('storedMaxDurationSec', () {
    const ceil = AutoDJManager.durationCeilSec;
    int read(Map<String, dynamic> m) => AutoDJManager.storedMaxDurationSec(m);

    test("an older file's 20:00 was its slider's end: no maximum", () {
      expect(read({'maxDurationSec': 1200}), ceil);
      expect(read({'maxDurationSec': 0}), ceil,
          reason: 'both thumbs at the left; 0 is no maximum on the wheel');
      expect(read({'durationCeilSec': ceil, 'maxDurationSec': 0}), ceil);
      expect(read({'maxDurationSec': 600}), 600);
      expect(read({}), ceil);
      expect(read({'maxDurationSec': 'six'}), ceil);
    });

    test('a file that says what no maximum was keeps a real 20:00', () {
      expect(read({'durationCeilSec': ceil, 'maxDurationSec': 1200}), 1200);
      expect(read({'durationCeilSec': ceil, 'maxDurationSec': ceil}), ceil);
      expect(read({'durationCeilSec': ceil, 'maxDurationSec': 3930}), 3930);
    });
  });

  group('setKeywords', () {
    test('the list is the filter on, trimmed, empties dropped', () async {
      expect(
          await ticks(() => mgr.setKeywords(['  live ', 'remix', '', '   '])),
          1);
      expect(mgr.keywordFilterWords, ['live', 'remix']);
      expect(mgr.keywordFilterEnabled, isTrue);
      expect(saved()['keywordFilterWords'], ['live', 'remix']);
      expect(saved()['keywordFilterEnabled'], isTrue);
    });

    test('unique without regard to case; the first spelling stays', () async {
      await mgr.setKeywords(['Live', 'live', 'LIVE ', 'Remix', 'remix']);
      expect(mgr.keywordFilterWords, ['Live', 'Remix']);
    });

    test('capped at the server\'s 50, counting unique words only', () async {
      final words = [for (var i = 0; i < 60; i++) 'w$i'];
      await mgr.setKeywords(['W0', ...words]);
      expect(mgr.keywordFilterWords, hasLength(AutoDJManager.maxKeywords));
      expect(mgr.keywordFilterWords.first, 'W0');
      expect(mgr.keywordFilterWords.last, 'w49',
          reason: 'w0 was a duplicate of W0, so w1..w49 fill the rest');
    });

    test('an empty list is the filter off', () async {
      await mgr.setKeywords(['live']);
      await mgr.setKeywords(const []);
      expect(mgr.keywordFilterWords, isEmpty);
      expect(mgr.keywordFilterEnabled, isFalse);
      await mgr.setKeywords(['live']);
      await mgr.setKeywords(const ['  ', '']);
      expect(mgr.keywordFilterEnabled, isFalse,
          reason: 'only blanks is nothing');
      expect(saved()['keywordFilterEnabled'], isFalse);
    });

    test('the list handed in is copied, not kept', () async {
      final draft = ['live'];
      await mgr.setKeywords(draft);
      draft.add('remix');
      expect(mgr.keywordFilterWords, ['live']);
    });
  });

  group('setTempo', () {
    test('on with a tolerance, saved', () async {
      expect(await ticks(() => mgr.setTempo(enabled: true, tolerance: 12)), 1);
      expect(mgr.bpmContinuityEnabled, isTrue);
      expect(mgr.bpmTolerance, 12);
      expect(saved()['bpmContinuityEnabled'], isTrue);
      expect(saved()['bpmTolerance'], 12);
    });

    test('off keeps the tolerance', () async {
      await mgr.setTempo(enabled: false, tolerance: 5);
      expect(mgr.bpmContinuityEnabled, isFalse);
      expect(mgr.bpmTolerance, 5);
    });

    test('the tolerance is clamped to 1–20', () async {
      await mgr.setTempo(enabled: true, tolerance: 0);
      expect(mgr.bpmTolerance, 1);
      await mgr.setTempo(enabled: true, tolerance: 99);
      expect(mgr.bpmTolerance, 20);
    });
  });

  group('setSonic', () {
    test('switch, match and anchor in one call, saved', () async {
      expect(
          await ticks(() => mgr.setSonic(
              enabled: false,
              minSimilarity: 0.7,
              anchor: SonicAnchorMode.locked)),
          1);
      expect(mgr.sonicSimilarityEnabled, isFalse);
      expect(mgr.sonicMinSimilarity, 0.7);
      expect(mgr.sonicAnchorMode, SonicAnchorMode.locked);
      final f = saved();
      expect(f['sonicSimilarityEnabled'], isFalse);
      expect(f['sonicMinSimilarity'], 0.7);
      expect(f['sonicAnchorMode'], 'locked');
    });

    test('the match is clamped to 0–1', () async {
      await mgr.setSonic(
          enabled: true, minSimilarity: 1.5, anchor: SonicAnchorMode.rolling);
      expect(mgr.sonicMinSimilarity, 1.0);
      await mgr.setSonic(
          enabled: true, minSimilarity: -0.2, anchor: SonicAnchorMode.rolling);
      expect(mgr.sonicMinSimilarity, 0.0);
    });
  });

  group('setPlayFromServer', () {
    test('names the server, saved; null lets it go', () async {
      expect(await ticks(() => mgr.setPlayFromServer('office')), 1);
      expect(mgr.playFromServer, 'office');
      expect(saved()['playFromServer'], 'office');
      expect(await ticks(() => mgr.setPlayFromServer(null)), 1);
      expect(mgr.playFromServer, isNull);
      expect(saved().containsKey('playFromServer'), isTrue);
      expect(saved()['playFromServer'], isNull);
    });

    test('the same server again is a no-op: no tick', () async {
      await mgr.setPlayFromServer('office');
      expect(await ticks(() => mgr.setPlayFromServer('office')), 0);
    });
  });

  // load() is memoized for the app's life, so the round trip runs once.
  test('load brings Play from back, with what the sheets saved', () async {
    await mgr.setKeywords(['live']);
    await mgr.setTempo(enabled: true, tolerance: 3);
    await mgr.setPlayFromServer('office');
    expect(saved()['playFromServer'], 'office');

    // A fresh launch's memory: defaults, then the file.
    mgr
      ..playFromServer = null
      ..keywordFilterWords = []
      ..keywordFilterEnabled = false
      ..bpmContinuityEnabled = false
      ..bpmTolerance = 8;
    expect(await ticks(() => mgr.load()), 1);
    expect(mgr.playFromServer, 'office');
    expect(mgr.keywordFilterWords, ['live']);
    expect(mgr.keywordFilterEnabled, isTrue);
    expect(mgr.bpmContinuityEnabled, isTrue);
    expect(mgr.bpmTolerance, 3);
  });
}
