// SettingsManager.resetAll: Settings › Reset reaches every row on the page
// (the torrent ask, the cast resolution that moved to the cast picker), tells
// the expanded player about its layout, and leaves the listening-history
// choices alone.
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/player_layout.dart';
import 'package:mstream_music/singletons/settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;

  setUpAll(() {
    dir = Directory.systemTemp.createTempSync('settings-reset-test');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => dir.path);
  });
  tearDownAll(() => dir.deleteSync(recursive: true));

  test('reset reaches the page rows and the player, keeps history choices',
      () async {
    final s = SettingsManager()
      ..torrentSkipChooser = true
      ..castVisualizerQuality = CastVisualizerQuality.uhd2160
      ..playerLayout = PlayerLayout.xl
      ..offlineQueue = true
      ..historyEnabled = false
      ..historySendToServer = false;
    final layouts = <PlayerLayout>[];
    final sub = s.playerLayoutStream.listen(layouts.add);

    await s.resetAll();
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(s.torrentSkipChooser, isFalse);
    expect(s.castVisualizerQuality, CastVisualizerQuality.fhd1080);
    expect(s.playerLayout, PlayerLayout.medium);
    expect(layouts.last, PlayerLayout.medium,
        reason: 'the player follows the stream, not the field');
    expect(s.offlineQueue, isFalse);
    // Listening history is the user's record, not a preference to reset.
    expect(s.historyEnabled, isFalse);
    expect(s.historySendToServer, isFalse);
  });
}
