// SettingsManager.media3Engine: the Android playback-engine choice is three
// states, not two. Unset follows the app's default, so that default can
// change in a later release and move everyone who never chose; either
// position of the Settings switch is a choice of the user's own and
// survives that. Reset goes back to unset, not to off.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/singletons/settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;

  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('settings-engine-test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => dir.path);
  });
  tearDownAll(() => dir.deleteSync(recursive: true));

  File settingsFile() => File('${dir.path}/settings.json');
  Map<String, dynamic> saved() =>
      jsonDecode(settingsFile().readAsStringSync()) as Map<String, dynamic>;

  setUp(() => SettingsManager().media3Engine = null);

  test('unset follows the app default', () {
    final s = SettingsManager();
    expect(s.media3Engine, isNull);
    expect(s.useMedia3Engine, SettingsManager.kMedia3EngineDefault);
  });

  test('either position of the switch is saved as a choice and read back',
      () async {
    final s = SettingsManager();

    await s.setMedia3Engine(true);
    expect(saved()['media3Engine'], isTrue);
    s.media3Engine = null;
    await s.load();
    expect(s.media3Engine, isTrue);
    expect(s.useMedia3Engine, isTrue);

    // Off is a choice too: it must not collapse back into "unset".
    await s.setMedia3Engine(false);
    expect(saved()['media3Engine'], isFalse);
    s.media3Engine = null;
    await s.load();
    expect(s.media3Engine, isFalse);
    expect(s.useMedia3Engine, isFalse);
  });

  test('saving another setting leaves an unset choice unset', () async {
    final s = SettingsManager();
    await s.setEqShowValues(s.eqShowValues);
    expect(saved().containsKey('media3Engine'), isTrue);
    expect(saved()['media3Engine'], isNull);
    await s.load();
    expect(s.media3Engine, isNull);
  });

  test('a value that is not a bool reads as unset', () async {
    final s = SettingsManager();
    await s.setMedia3Engine(true);
    final m = saved()..['media3Engine'] = 'yes';
    settingsFile().writeAsStringSync(jsonEncode(m));
    await s.load();
    expect(s.media3Engine, isNull);
  });

  test('reset returns to the default, not to off', () async {
    final s = SettingsManager();
    await s.setMedia3Engine(true);
    await s.resetAll();
    expect(s.media3Engine, isNull);
    expect(saved()['media3Engine'], isNull);
  });
}
