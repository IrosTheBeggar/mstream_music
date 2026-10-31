// An auto_dj.json written before the Auto DJ screen's redesign, read by the
// new app: Play from starts where the DJ last ran (it has no key of its own
// yet), and "Play from every server" left on with sonic similarity off —
// which the old screen allowed, with a warning — comes back as one server,
// because All servers runs on sonic picks.
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
    scratch = Directory.systemTemp.createTempSync('mstream-auto-dj-upgrade-');
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

  test('an older file: Play from = where the DJ ran; All servers needs sonic',
      () async {
    File('${scratch.path}/auto_dj.json').writeAsStringSync(jsonEncode({
      'enabledServer': 'office',
      'multiServerEnabled': true,
      'sonicSimilarityEnabled': false,
    }));
    final mgr = AutoDJManager();
    await mgr.load();
    expect(mgr.playFromServer, 'office');
    expect(mgr.multiServerEnabled, isFalse);
    expect(mgr.sonicSimilarityEnabled, isFalse);
  });
}
