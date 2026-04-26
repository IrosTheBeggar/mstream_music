// Playlist creation flow.
//
// Opens the drawer, navigates to Playlists, taps the FAB, types a
// name, and asserts the new playlist appears in the list. Catches
// regressions in the dialog/persistence wiring without needing
// audio playback or a server connection.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';

import 'package:mstream_music/main.dart';
import 'package:mstream_music/singletons/media.dart';
import 'package:mstream_music/singletons/playlists.dart';

import 'helpers/test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await MediaManager().start();
  });

  setUp(() async {
    await resetAppState();
    // Also wipe playlists.json so each run starts fresh.
    final dir = await getApplicationDocumentsDirectory();
    final f = File('${dir.path}/playlists.json');
    if (await f.exists()) await f.delete();
    PlaylistManager().playlists.clear();
  });

  testWidgets(
    'create a playlist from the drawer FAB',
    (WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(home: MStreamApp()));
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // Open drawer.
      final scaffoldState = tester.firstState<ScaffoldState>(
          find.byType(Scaffold));
      scaffoldState.openDrawer();
      await tester.pumpAndSettle();

      await tester.tap(find.text('Playlists'));
      await tester.pumpAndSettle();

      expect(find.text('No playlists yet'), findsOneWidget);

      // FAB.
      await tester.tap(find.text('New playlist'));
      await tester.pumpAndSettle();

      // Dialog should be up; type a name and submit.
      await tester.enterText(find.byType(TextField), 'Road Trip');
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();

      expect(find.text('Road Trip'), findsOneWidget);
      expect(find.text('0 tracks'), findsOneWidget);

      // The playlist persisted to disk.
      final dir = await getApplicationDocumentsDirectory();
      final f = File('${dir.path}/playlists.json');
      expect(await f.exists(), isTrue);
      final raw = await f.readAsString();
      expect(raw.contains('Road Trip'), isTrue);
    },
  );
}
