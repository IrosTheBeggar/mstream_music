// Settings persistence.
//
// Toggles a setting on the SettingsScreen, asserts it lands in
// settings.json on disk, then reloads SettingsManager from disk and
// confirms the value sticks across "restart". Catches regressions in
// the load/save round-trip without needing a full process restart.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'package:mstream_music/main.dart';
import 'package:mstream_music/singletons/media.dart';
import 'package:mstream_music/singletons/settings.dart';
import 'package:mstream_music/singletons/transcode.dart';

import 'helpers/test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await MediaManager().start();
  });

  setUp(() async {
    await resetAppState();
    final dir = await getApplicationDocumentsDirectory();
    final f = File('${dir.path}/settings.json');
    if (await f.exists()) await f.delete();
    // Reset in-memory defaults.
    TranscodeManager().transcodeOn = false;
    SettingsManager().albumGrid = true;
    SettingsManager().autoPlayOnTap = false;
  });

  testWidgets(
    'toggling Transcode on Settings persists to disk and survives reload',
    (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: MStreamApp()));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Open drawer → Settings.
      tester
          .firstState<ScaffoldState>(find.byType(Scaffold))
          .openDrawer();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();

      // Toggle the Transcode switch.
      expect(TranscodeManager().transcodeOn, isFalse);
      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();
      expect(TranscodeManager().transcodeOn, isTrue);

      // Disk should contain the new value.
      final dir = await getApplicationDocumentsDirectory();
      final raw = await File('${dir.path}/settings.json').readAsString();
      final parsed = jsonDecode(raw) as Map<String, dynamic>;
      expect(parsed['transcode'], isTrue);

      // Simulate a fresh launch by zeroing the in-memory flag and
      // reloading from disk.
      TranscodeManager().transcodeOn = false;
      await SettingsManager().load();
      expect(TranscodeManager().transcodeOn, isTrue,
          reason: 'transcode setting should round-trip through disk');
    },
  );
}
