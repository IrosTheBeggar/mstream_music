// The track sheet's actions (long-press on a browser row, album detail, the
// queue's Discover bar, an Instant mix's own rows): Instant mix right after
// Play now where the track's server can make a mix now — and nowhere else:
// not for a local file, not without the server's flag, not while its
// sonic index is still scanning, not on a connected server's track.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/l10n/localizations_delegates.dart';
import 'package:mstream_music/objects/display_item.dart';
import 'package:mstream_music/objects/metadata.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/widgets/track_actions_sheet.dart';

Server _server() => Server('http://music.example', null, null, 'JWT', 'home')
  ..discoveryAvailable = true
  ..discoveryEnabled = true
  ..discoveryReady = true
  ..instantMixGeneration = 1;

DisplayItem _track(Server? server, {String type = 'file'}) =>
    DisplayItem(server, '/demo/Dolo.mp3', type, '/demo/Dolo.mp3', null, null)
      ..metadata = MusicMetadata('Boukmanflow', 'Stim Pack Volume one',
          'Dolo', null, null, null, 'h1', null, null);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => '/nonexistent-track-sheet-test-dir');
  });

  /// Open the sheet for [item]; the action titles, top to bottom.
  Future<List<String>> actions(WidgetTester tester, DisplayItem item) async {
    tester.view.physicalSize = const Size(390 * 3, 1400 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: appSupportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () => showTrackActionsSheet(context, item),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final tiles = find.descendant(
        of: find.byType(TrackActionsSheet), matching: find.byType(ListTile));
    return [
      for (final t in tester.widgetList<ListTile>(tiles))
        (t.title as Text).data!,
    ];
  }

  testWidgets('Instant mix comes right after Play now', (tester) async {
    expect(await actions(tester, _track(_server())), [
      'Add next',
      'Play now',
      'Instant mix',
      'Add to end of queue',
      'Add to playlist',
      'Download',
      'Find similar',
    ]);
    expect(
        find.descendant(
            of: find.widgetWithText(ListTile, 'Instant mix'),
            matching: find.byIcon(Icons.auto_awesome)),
        findsOneWidget);
  });

  testWidgets('hidden for a local file', (tester) async {
    final titles =
        await actions(tester, _track(_server(), type: 'localFile'));
    expect(titles, isNot(contains('Instant mix')));
    expect(titles.take(2), ['Add next', 'Play now']);
  });

  testWidgets('hidden without the flag', (tester) async {
    final titles = await actions(
        tester, _track(_server()..instantMixGeneration = null));
    expect(titles, isNot(contains('Instant mix')));
    expect(titles, contains('Find similar'),
        reason: 'the rest of discovery is still there');
  });

  testWidgets('hidden while the sonic index is still scanning, and with '
      'discovery off', (tester) async {
    expect(
        await actions(tester, _track(_server()..discoveryReady = false)),
        isNot(contains('Instant mix')));
    expect(
        await actions(
            tester,
            _track(_server()
              ..discoveryEnabled = false
              ..discoveryAvailable = false)),
        isNot(contains('Instant mix')));
  });

  testWidgets("hidden on a connected server's track", (tester) async {
    final peer = Server('federated://home/3', null, null, null, 'peer-3')
      ..federationParent = 'home'
      ..federationPeerId = 3
      ..parentServer = _server()
      ..discoveryEnabled = true
      ..discoveryReady = true
      ..instantMixGeneration = 1;
    expect(await actions(tester, _track(peer)), isNot(contains('Instant mix')));
  });
}
