// An auto_dj.json written before Play from could name a set of servers,
// with All servers on and sonic similarity too, read by the new app: it is
// still All servers — the key it was saved under means just that — and
// nothing has been chosen by name yet.
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
    scratch = Directory.systemTemp.createTempSync('mstream-auto-dj-all-');
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

  test('an older All servers file is still All servers', () async {
    File('${scratch.path}/auto_dj.json').writeAsStringSync(jsonEncode({
      'enabledServer': 'office',
      'playFromServer': 'home',
      'multiServerEnabled': true,
      'sonicSimilarityEnabled': true,
    }));
    final mgr = AutoDJManager();
    await mgr.load();
    expect(mgr.playFromAll, isTrue);
    expect(mgr.multiServerEnabled, isTrue);
    expect(mgr.playFromServers, isEmpty);
    expect(mgr.playFromServer, 'home');
  });
}
