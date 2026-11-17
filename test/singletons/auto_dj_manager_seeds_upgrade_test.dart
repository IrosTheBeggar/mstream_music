// An auto_dj.json written before the Seeds page, read by the new app. The
// Seeds page's Drift | Stay close is the same 'sonicAnchorMode' key, with
// the same names, so a stored Stay close comes back as Stay close with no
// migration. The file has no learnFromSkips key yet, so Learn from skips
// starts off, as on a fresh install, and every key after it still loads:
// the load notifies only once it has read the file to the end.
//
// load() is memoized for the app's life, so this file holds the one load.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/singletons/auto_dj_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory scratch;

  setUpAll(() {
    scratch =
        Directory.systemTemp.createTempSync('mstream-auto-dj-seeds-upgrade-');
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

  test('an older file: Stay close kept, Learn from skips off', () async {
    // Every key the app saved before the Seeds page, Stay close among them.
    File('${scratch.path}/auto_dj.json').writeAsStringSync(jsonEncode({
      'keywordFilterEnabled': false,
      'keywordFilterWords': [],
      'bpmContinuityEnabled': false,
      'bpmTolerance': 8,
      'songsPerFetch': 4,
      'harmonicMixingEnabled': false,
      'sonicSimilarityEnabled': true,
      'sonicMinSimilarity': 0.6,
      'sonicAnchorMode': 'locked',
      'sonicSeedPath': null,
      'sonicSeedTitle': null,
      'sonicSeedServer': null,
      'emptyQueueStart': 'random',
      'enabledServer': 'home',
      'playFromServer': 'home',
      'playFromServers': ['home'],
      'multiServerEnabled': false,
      'durationFilterEnabled': false,
      'minDurationSec': 120,
      'maxDurationSec': 86400,
      'durationCeilSec': 86400,
      'allowUnknownDuration': false,
      'moodFilterEnabled': false,
      'moodFilter': null,
    }));
    final mgr = AutoDJManager();
    var ticks = 0;
    // A BehaviorSubject replays its last value on listen: skip it.
    final sub = mgr.changeStream.skip(1).listen((_) => ticks++);
    await mgr.load();
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(ticks, 1, reason: 'the load read the file to the end');
    expect(mgr.sonicAnchorMode, SonicAnchorMode.locked);
    expect(mgr.learnFromSkips, isFalse);
    // Keys the load reads after the new one.
    expect(mgr.emptyQueueStart, EmptyQueueStart.random);
    expect(mgr.playFromServer, 'home');
    expect(mgr.sonicMinSimilarity, 0.6);
  });
}
