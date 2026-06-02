// Drives the app through several screens, captures each as a PNG and
// emits the base64-encoded bytes via stdout (chunked) so the host can
// reconstruct them from the test log. The app sandbox path
// disappears when the test APK is uninstalled, hence the log
// channel.
//
// Skips connected-browse screens (Albums grid etc.) — those need a
// fresh MStreamApp pump to pick up servers.json, but flutter_downloader
// asserts single-init within a process so re-pumping mid-test crashes.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'package:mstream_music/main.dart';
import 'package:mstream_music/singletons/media.dart';
import 'package:mstream_music/singletons/playlists.dart';
import 'package:mstream_music/singletons/settings.dart';

import 'helpers/test_helpers.dart';

final _rootKey = GlobalKey();

Future<void> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(
    RepaintBoundary(
      key: _rootKey,
      child: MaterialApp(home: MStreamApp()),
    ),
  );
}

Future<void> _dumpScreenshot(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  final boundary =
      _rootKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 1.0);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  if (bytes == null) return;
  final png = bytes.buffer.asUint8List();
  final encoded = base64Encode(png);
  const chunkSize = 4096;
  print('SCREENSHOT_BEGIN:$name:${png.length}');
  for (var i = 0; i < encoded.length; i += chunkSize) {
    final end = (i + chunkSize) < encoded.length ? i + chunkSize : encoded.length;
    print('SS:$name:${encoded.substring(i, end)}');
  }
  print('SCREENSHOT_END:$name');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await MediaManager().start();
  });

  setUp(() async {
    await resetAppState();
    final dir = await getApplicationDocumentsDirectory();
    for (final f in ['playlists.json', 'settings.json']) {
      final file = File('${dir.path}/$f');
      if (await file.exists()) await file.delete();
    }
    PlaylistManager().playlists.clear();
    SettingsManager().albumGrid = true;
  });

  testWidgets('capture screen tour', (WidgetTester tester) async {
    await _pumpApp(tester);
    await tester.pumpAndSettle(const Duration(seconds: 4));

    // 1. Welcome screen.
    await _dumpScreenshot(tester, '01_welcome');

    // 2. Drawer.
    final scaffoldState =
        tester.firstState<ScaffoldState>(find.byType(Scaffold));
    scaffoldState.openDrawer();
    await tester.pumpAndSettle();
    await _dumpScreenshot(tester, '02_drawer');

    // 3. Settings.
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();
    await _dumpScreenshot(tester, '03_settings');
    await tester.pageBack();
    await tester.pumpAndSettle();

    // 4. Open drawer again, navigate to Playlists (empty state).
    final scaffoldState2 =
        tester.firstState<ScaffoldState>(find.byType(Scaffold));
    scaffoldState2.openDrawer();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Playlists'));
    await tester.pumpAndSettle();
    await _dumpScreenshot(tester, '04_playlists_empty');

    // 5. New-playlist dialog.
    await tester.tap(find.text('New playlist'));
    await tester.pumpAndSettle();
    await _dumpScreenshot(tester, '05_new_playlist_dialog');

    await tester.enterText(find.byType(TextField), 'Road Trip');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Create'));
    await tester.pumpAndSettle();
    await _dumpScreenshot(tester, '06_playlist_created');

    // 6. Tap into the playlist detail.
    await tester.tap(find.text('Road Trip'));
    await tester.pumpAndSettle();
    await _dumpScreenshot(tester, '07_playlist_detail_empty');

    // 7. Back to welcome, tap the welcome row to open AddServer form.
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.text('Welcome To mStream'));
    await tester.pumpAndSettle();
    await _dumpScreenshot(tester, '08_add_server');
  });
}
