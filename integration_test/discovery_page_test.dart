// Discover journey (Discover page plan §4.2, §2.13 — the play-now page, in
// the browser).
//
// A server whose ping advertises `discovery` and `discoveryTaste` gets a
// Discover card under Listen on the home; tapping it fills the BROWSER
// listing (no new screen): ONE library taste call (no network source, and
// no peers call — the ping does not grant federationDiscovery), then the
// configuration bar (the window, and "More options" for the seeds sheet)
// over "Songs from your library" as the browser's own song rows, with no
// counts. Choosing a window in the bar re-asks with it and the phone
// remembers it; Back returns to the server home, and opening Discover again
// asks again (nothing is reused: the server draws a new random batch of
// seeds on every call). The
// mock's GET /api/ is unmatched (404), so the app falls back to the ping —
// the flat shape the flags are read from.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';

import 'package:mstream_music/singletons/media.dart';
import 'package:mstream_music/singletons/settings.dart';

import 'helpers/test_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  MockServer? mockServer;

  // Every taste body the app sent, oldest first.
  final tasteBodies = <Map<String, dynamic>>[];

  Future<Object?> taste(HttpRequest req) async {
    tasteBodies.add(jsonDecode(await utf8.decoder.bind(req).join())
        as Map<String, dynamic>);
    return {
      'window': 30,
      'widenedFrom': null,
      'seedSource': 'history',
      'fallback': false,
      'seeds': [
        {
          'hash': 'h1',
          'filepath': 'default/ALM/Manor.flac',
          'metadata': {'title': 'Manor', 'artist': 'ALM'},
          'outcome': 'completed',
          'lastPlayed': '2026-10-04T21:10:00.000Z',
          'plays': 3,
          'pinned': false,
          'analyzed': true,
        },
        {
          'hash': 'h2',
          'filepath': 'default/Boards/Roygbiv.flac',
          'metadata': {'title': 'Roygbiv', 'artist': 'Boards of Canada'},
          'outcome': 'completed',
          'lastPlayed': '2026-10-03T21:10:00.000Z',
          'plays': 1,
          'pinned': false,
          'analyzed': true,
        },
      ],
      'excluded': [],
      'dropped': 0,
      'notAnalyzed': false,
      'model': {'id': 'effnet-discogs', 'version': '1'},
      'library': {
        'tracks': [
          {
            'filepath': 'default/Moderat/Dawn Chorus.mp3',
            'similarity': 0.83,
            'seedHash': 'h1',
            'metadata': {
              'title': 'Dawn Chorus',
              'artist': 'Moderat',
              'album': 'III',
            },
            'genreTags': [],
            'playCount': 0,
            'lastPlayed': null,
          },
          {
            'filepath': 'default/Bonobo/Cirrus.mp3',
            'similarity': 0.8,
            'seedHash': 'h2',
            'metadata': {'title': 'Cirrus', 'artist': 'Bonobo'},
            'genreTags': [],
            'playCount': 0,
            'lastPlayed': null,
          },
        ],
        'albums': [],
        'capped': false,
      },
      'network': null,
      'peers': null,
    };
  }

  setUpAll(() async {
    await MediaManager().start();
  });

  setUp(resetAppState);

  tearDown(() async {
    await mockServer?.close();
    mockServer = null;
  });

  testWidgets(
    'the home Discover card fills the browser with its bar, seeds sheet and '
    'library rows',
    (WidgetTester tester) async {
      mockServer = await MockServer.start({
        '/api/v1/ping': (_) => {
              'vpaths': ['default'],
              'playlists': <String>[],
              'discovery': true,
              'discoveryTaste': 1,
              'stats': 2,
            },
        '/api/v1/discovery/taste': taste,
      });

      await seedServer(mockServer!.url);

      await tester.pumpWidget(testApp());
      await tester.pumpAndSettle(const Duration(seconds: 5));

      // A fresh install shows the one-time welcome screen over the home
      // (SettingsManager.welcomeShown persists, so later runs skip it).
      if (find.text('Skip').evaluate().isNotEmpty) {
        await tester.tap(find.text('Skip'));
        await tester.pumpAndSettle(const Duration(seconds: 2));
      }

      // The card sits under Listen; scroll the home to it if the screen is
      // short.
      final card = find.text('Discover');
      if (card.evaluate().isEmpty) {
        await tester.dragUntilVisible(
          card,
          find
              .ancestor(
                  of: find.text('Albums'), matching: find.byType(Scrollable))
              .first,
          const Offset(0, -200),
        );
      }
      expect(card, findsOneWidget);
      expect(tasteBodies, isEmpty, reason: 'the home never fetches taste');
      // The window is remembered on the phone (settings.json survives
      // resetAppState): start every run from the default.
      await SettingsManager().setDiscoverWindow(30);

      await tester.tap(card);
      await tester.pumpAndSettle(const Duration(seconds: 3));

      // One library call; nothing playing, so nothing pinned.
      expect(tasteBodies, hasLength(1));
      expect(tasteBodies.single['sources'], ['library']);
      expect(tasteBodies.single['newArtistsOnly'], isFalse);
      expect(tasteBodies.single['window'], 30);
      expect(tasteBodies.single.containsKey('pin'), isFalse);
      expect(tasteBodies.single.containsKey('remember'), isFalse);
      expect(tasteBodies.single.containsKey('filter'), isFalse);

      // In the browser, not a pushed screen: the home's cards are gone and
      // the browser toolbar names the listing.
      expect(find.text('Auto DJ', skipOffstage: false), findsNothing);
      // The bar: the window form and "More options"; no seed chips, no
      // subtitle, no counts.
      expect(find.text('Based on the last'), findsOneWidget);
      expect(find.text('30 days'), findsOneWidget);
      expect(find.text('More options'), findsOneWidget);
      expect(find.textContaining('songs you finished'), findsNothing);
      expect(find.textContaining('Manor'), findsNothing);
      expect(find.textContaining('Roygbiv'), findsNothing);
      expect(find.text('SONGS FROM YOUR LIBRARY'), findsOneWidget);
      expect(find.text('Dawn Chorus'), findsOneWidget);
      expect(find.text('Moderat · III'), findsOneWidget);
      expect(find.text('Cirrus'), findsOneWidget);
      expect(find.text('Queue all'), findsOneWidget);
      expect(find.textContaining('Play all'), findsNothing);
      expect(find.textContaining('never played'), findsNothing);
      expect(find.textContaining('%'), findsNothing);
      expect(find.text('FROM THE NETWORK'), findsNothing);

      // "More options" opens the seeds sheet with the seeds the answer was
      // built from (no checkbox); closing it asks nothing.
      await tester.tap(find.text('More options'));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.text('Based on'), findsOneWidget);
      expect(find.text("Include songs I've played lately"), findsNothing);
      expect(find.text('Manor'), findsOneWidget);
      expect(find.text('Roygbiv'), findsOneWidget);
      expect(find.text('Use these 2'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(tasteBodies, hasLength(1));

      // The window chooser re-asks with the new window, remembered on the
      // phone.
      await tester.tap(find.text('30 days'));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      await tester.tap(find.ancestor(
          of: find.text('90 days'),
          matching: find.byType(CheckedPopupMenuItem<int>)));
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(tasteBodies, hasLength(2));
      expect(tasteBodies.last['window'], 90);
      expect(tasteBodies.last.containsKey('remember'), isFalse);
      expect(find.text('90 days'), findsOneWidget);
      expect(SettingsManager().discoverWindow, 90);

      // Back (the browser toolbar's) returns to the server home.
      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle(const Duration(seconds: 2));
      expect(find.text('More options'), findsNothing);
      expect(find.text('Dawn Chorus'), findsNothing);
      expect(find.text('Discover', skipOffstage: false), findsOneWidget);
      expect(find.text('Auto DJ', skipOffstage: false), findsOneWidget);

      // Opening Discover again asks again, over the remembered window.
      if (card.evaluate().isEmpty) {
        await tester.dragUntilVisible(
          card,
          find
              .ancestor(
                  of: find.text('Albums'), matching: find.byType(Scrollable))
              .first,
          const Offset(0, -200),
        );
      }
      await tester.tap(card);
      await tester.pumpAndSettle(const Duration(seconds: 3));
      expect(tasteBodies, hasLength(3), reason: 'no earlier answer reused');
      expect(tasteBodies.last['window'], 90);
      expect(find.text('90 days'), findsOneWidget);
      await SettingsManager().setDiscoverWindow(30);
    },
  );
}
