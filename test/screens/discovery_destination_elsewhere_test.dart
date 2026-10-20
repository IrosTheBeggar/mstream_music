// Where copies land, and Open elsewhere (the design canvas's
// PhoneDestination and PhoneElsewhere boards): the destination picker from
// the Keep card's Change — the library default, the live preview of where
// this song lands, the writable libraries, the base folder, the layouts,
// Save and "Use the library default", a refusal in the server's words,
// saving, loading, no library, uploads off, a failed read, the keyboard,
// German — and the links plug-in's sub-sheet over the song sheet: loading,
// exact pages then searches, opening outside the app, a link that will not
// open, empty, and the server's error.
//
// The plug-in API is the scripted fake; the URL launcher is the test's.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/screens/discovery/destination_sheet.dart';
import 'package:mstream_music/screens/discovery/discovery_keep_routes.dart';
import 'package:mstream_music/screens/discovery/elsewhere_sheet.dart';
import 'package:mstream_music/screens/discovery/keep_toast.dart';
import 'package:mstream_music/singletons/browser_list.dart';
import 'package:mstream_music/singletons/server_list.dart';
import 'package:mstream_music/singletons/settings.dart';

import 'discovery_copies_fixtures.dart';
import 'discovery_keep_fixtures.dart';

const _dest = '/api/v1/discovery/collection/destination';
const _resolve = '/plugins/links/resolve';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final k = KeepHarness();
  final toasts = <String>[];
  final successes = <bool>[];

  setUpAll(mockPathProvider);
  setUp(() {
    k.setUp();
    // The real sheets behind Change and Open elsewhere.
    DiscoveryKeepRoutes.reset();
    toasts.clear();
    successes.clear();
    KeepToast.debugSink = (m, {success = false}) {
      toasts.add(m);
      successes.add(success);
    };
    SettingsManager().discoverKeepNoteSeen = true;
  });
  tearDown(() {
    KeepToast.debugSink = null;
    elsewhereLaunch = (uri) async => false;
    BrowserManager().closeAlbumDetail();
    ServerManager().currentServer = null;
    SettingsManager().discoverKeepNoteSeen = false;
    k.tearDown();
  });

  Future<void> frames(WidgetTester tester, [int n = 6]) =>
      KeepHarness.pumpFor(tester, n);

  Future<void> tapKey(WidgetTester tester, String key) async {
    final f = find.byKey(ValueKey(key));
    await tester.ensureVisible(f.last);
    await tester.pump();
    await tester.tap(f.last);
    await frames(tester);
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    final f = find.text(text);
    await tester.ensureVisible(f.last);
    await tester.pump();
    await tester.tap(f.last);
    await frames(tester);
  }

  /// The song sheet of [title], then its Change.
  Future<void> openPicker(
    WidgetTester tester, {
    String title = 'Late Train Verse',
  }) async {
    await k.pumpDiscover(tester);
    await tester.longPress(find.text(title));
    await frames(tester, 8);
    await tapKey(tester, 'keep-change');
    await frames(tester, 4);
  }

  /// The preview as read (a segment's no-break spaces and word joiners —
  /// it never breaks inside itself — read as plain text).
  String preview(WidgetTester tester) => tester
      .widget<Text>(find.byKey(const ValueKey('destination-preview')))
      .textSpan!
      .toPlainText()
      .replaceAll('\u00A0', ' ')
      .replaceAll('\u2060', '');

  Map<String, dynamic> lastPut() =>
      jsonDecode(k.fake.calls('PUT', _dest).last.body) as Map<String, dynamic>;

  group('the destination picker', () {
    testWidgets(
      'Change opens it over the sheet: the library default in force, where '
      'this song lands, the writable libraries, the base folder, the '
      'layouts; Save waits for a change',
      (tester) async {
        await openPicker(tester);
        expect(tester.takeException(), isNull);
        expect(find.text('Where copies land'), findsOneWidget);
        expect(find.text('library default'), findsOneWidget);
        expect(
          find.text('One setting for your account · every copy uses it'),
          findsOneWidget,
        );
        // The picker reads the destination afresh.
        expect(k.fake.count('GET', _dest), 2);
        expect(find.text('Late Train Verse lands at'), findsOneWidget);
        expect(
          preview(tester),
          'copies › Boukmanflow › Borrowed Tapes › 02 - Late Train Verse.mp3',
        );
        expect(
          find.byKey(const ValueKey('destination-library-copies')),
          findsOneWidget,
        );
        expect(find.text('copies /'), findsOneWidget);
        expect(find.text('library root'), findsOneWidget);
        expect(
          find.text('Inside copies. Leave empty for the library root.'),
          findsOneWidget,
        );
        expect(find.text('Artist / Album'), findsOneWidget);
        expect(find.text('{{ALBUMARTIST}}/{{ALBUM}}'), findsOneWidget);
        expect(find.text('Server / Artist / Album'), findsOneWidget);
        expect(find.text('{{PEER}}/{{ALBUMARTIST}}/{{ALBUM}}'), findsOneWidget);
        expect(find.text('Library layout'), findsNothing);
        // The server's own default is the Artist / Album preset: a fresh
        // account's layout is no "current layout" of its own.
        expect(find.text('Your current layout'), findsNothing);
        expect(find.text('Use the library default'), findsNothing);
        await tapKey(tester, 'destination-save');
        expect(k.fake.count('PUT', _dest), 0, reason: 'nothing changed yet');
      },
    );

    testWidgets(
      'typing a base folder moves the preview; Save sends it, toasts where '
      'copies land, the tag reads yours; Use the library default saves none',
      (tester) async {
        await openPicker(tester);
        await tester.enterText(
          find.byKey(const ValueKey('destination-base')),
          'from-peers',
        );
        await frames(tester, 2);
        expect(
          preview(tester),
          'copies › from-peers › Boukmanflow › Borrowed Tapes › 02 - Late Train Verse.mp3',
        );
        await tapKey(tester, 'destination-save');
        expect(lastPut(), {
          'destination': {
            'vpath': 'copies',
            'base': 'from-peers',
            'layout': '{{ALBUMARTIST}}/{{ALBUM}}',
          },
        });
        expect(toasts, ['Saved · copies land in copies › from-peers']);
        expect(successes, [true], reason: 'the check toast');
        expect(find.text('yours'), findsOneWidget);
        expect(find.text('Use the library default'), findsOneWidget);
        expect(SettingsManager().discoverKeepNoteSeen, isTrue);
        // Saved: Save waits for the next change again.
        await tapKey(tester, 'destination-save');
        expect(k.fake.count('PUT', _dest), 1);

        await tapText(tester, 'Use the library default');
        expect(lastPut(), {'destination': null});
        expect(find.text('library default'), findsOneWidget);
        expect(find.text('Use the library default'), findsNothing);
        expect(toasts.last, 'Saved · copies land in copies');
        // The Keep card behind it follows.
        Navigator.of(tester.element(find.text('Where copies land'))).pop();
        await frames(tester, 8);
        expect(find.text('Where copies land'), findsNothing);
      },
    );

    testWidgets(
      "a compilation's song lands under the album's credit, one folder for "
      'the whole album; the server preset keeps it',
      (tester) async {
        k.peersAnswer = () => keepPeersPayload(extraB: compilationRows());
        await k.pumpDiscover(tester);
        await tester.ensureVisible(find.text('Block Rocker'));
        await tester.pump();
        await tester.longPress(find.text('Block Rocker'));
        await frames(tester, 8);
        await tapKey(tester, 'keep-change');
        await frames(tester, 4);
        expect(
          preview(tester),
          startsWith('copies › Various Artists › Block Party Comp › '),
        );
        await tapText(tester, 'Server / Artist / Album');
        expect(
          preview(tester),
          startsWith(
            'copies › Stage Peer B › Various Artists › Block Party Comp › ',
          ),
        );
        await tapKey(tester, 'destination-save');
        expect(
          (lastPut()['destination'] as Map)['layout'],
          '{{PEER}}/{{ALBUMARTIST}}/{{ALBUM}}',
          reason: 'never a per-track-artist layout from a preset',
        );
      },
    );

    testWidgets(
      "an older server's default ({{ARTIST}}/{{ALBUM}}) is its Artist / "
      'Album preset: no "current layout" beside it',
      (tester) async {
        k.fake.destination = {
          ...k.fake.destination,
          'destination': {
            'vpath': 'copies',
            'base': '',
            'layout': '{{ARTIST}}/{{ALBUM}}',
            'source': 'default',
          },
          'defaultLayout': '{{ARTIST}}/{{ALBUM}}',
        };
        await openPicker(tester);
        expect(find.text('{{ARTIST}}/{{ALBUM}}'), findsOneWidget);
        expect(find.text('Your current layout'), findsNothing);
        expect(find.text('{{PEER}}/{{ALBUMARTIST}}/{{ALBUM}}'), findsOneWidget);
      },
    );

    testWidgets(
      "Server / Artist / Album adds the server's folder; a library with its "
      'own Path Template offers it as a third layout',
      (tester) async {
        k.fake.destination = {
          ...k.fake.destination,
          'libraries': [
            {'vpath': 'copies', 'template': null},
            {
              'vpath': 'demo',
              'template': '{{ALBUMARTIST}}/{{YEAR}} - {{ALBUM}}',
            },
          ],
        };
        await openPicker(tester);
        await tapText(tester, 'Server / Artist / Album');
        expect(
          preview(tester),
          'copies › Stage Peer B › Boukmanflow › Borrowed Tapes › 02 - Late Train Verse.mp3',
        );
        await tapKey(tester, 'destination-library-demo');
        expect(find.text('Library layout'), findsOneWidget);
        expect(
          find.text('{{ALBUMARTIST}}/{{YEAR}} - {{ALBUM}}'),
          findsOneWidget,
        );
        await tapText(tester, 'Library layout');
        expect(
          preview(tester),
          'demo › Boukmanflow › 2019 - Borrowed Tapes › 02 - Late Train Verse.mp3',
        );
        expect(
          find.text('Inside demo. Leave empty for the library root.'),
          findsOneWidget,
        );
        await tapKey(tester, 'destination-save');
        expect(lastPut(), {
          'destination': {
            'vpath': 'demo',
            'base': '',
            'layout': '{{ALBUMARTIST}}/{{YEAR}} - {{ALBUM}}',
          },
        });
      },
    );

    testWidgets(
      "a base folder the server would refuse: the preview waits; Save's 400 "
      "puts the server's words under the field; typing clears them",
      (tester) async {
        await openPicker(tester);
        await tester.enterText(
          find.byKey(const ValueKey('destination-base')),
          '../shared',
        );
        await frames(tester, 2);
        expect(
          find.text('Fix the base folder to see where files land'),
          findsOneWidget,
        );
        expect(find.byKey(const ValueKey('destination-preview')), findsNothing);
        k.fake.refuseOn['PUT $_dest'] = (
          400,
          'destination base folder: Resolved path cannot contain .. segments',
        );
        await tapKey(tester, 'destination-save');
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('destination-base-error')),
            matching: find.text(
              'destination base folder: Resolved path cannot contain .. segments',
            ),
          ),
          findsOneWidget,
        );
        expect(toasts, isEmpty);
        await tester.enterText(
          find.byKey(const ValueKey('destination-base')),
          'shared',
        );
        await frames(tester, 2);
        expect(
          find.byKey(const ValueKey('destination-base-error')),
          findsNothing,
        );
      },
    );

    testWidgets('saving: Saving…, the inputs locked, then the saved one', (
      tester,
    ) async {
      await openPicker(tester);
      await tester.enterText(
        find.byKey(const ValueKey('destination-base')),
        'from-peers',
      );
      await frames(tester, 2);
      k.fake.destinationGate = Completer<void>();
      await tapKey(tester, 'destination-save');
      expect(find.text('Saving…'), findsOneWidget);
      final field = tester.widget<TextField>(
        find.byKey(const ValueKey('destination-base')),
      );
      expect(field.enabled, isFalse);
      k.fake.destinationGate!.complete();
      k.fake.destinationGate = null;
      await frames(tester);
      expect(find.text('Saving…'), findsNothing);
      expect(find.text('yours'), findsOneWidget);
    });

    testWidgets("from the album sheet it previews the album's first song", (
      tester,
    ) async {
      await k.pumpDiscover(tester);
      await tester.longPress(find.text('Borrowed Tapes').first);
      await frames(tester, 8);
      await tapKey(tester, 'keep-change');
      await frames(tester, 4);
      expect(find.text('Rooftop Cypher lands at'), findsOneWidget);
      expect(
        preview(tester),
        'copies › Boukmanflow › Borrowed Tapes › 01 - Rooftop Cypher.mp3',
      );
    });
  });

  group('the destination picker on its own: its states', () {
    final h = SheetHarness();
    setUp(h.setUp);
    tearDown(h.tearDown);

    const song = DestinationPreviewSong(
      title: 'Rooftop Cypher',
      artist: 'Boukmanflow',
      album: 'Borrowed Tapes',
      year: 2019,
      filepath: 'peerlib/Boukmanflow/Borrowed Tapes/01 - Rooftop Cypher.mp3',
    );

    Future<void> pumpPicker(
      WidgetTester tester, {
      double width = 390,
      double height = 844,
      double textScale = 1,
      Locale? locale,
    }) => h.pumpHost(
      tester,
      (c) =>
          showDestinationSheet(c, h.jobs, song: song, peerName: 'Stage Peer B'),
      width: width,
      height: height,
      textScale: textScale,
      locale: locale,
    );

    testWidgets('loading: still blocks, Save off; then the form in place', (
      tester,
    ) async {
      h.fake.destinationGate = Completer<void>();
      await pumpPicker(tester);
      expect(find.byKey(const ValueKey('destination-loading')), findsOneWidget);
      expect(find.text('LIBRARY'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('destination-save')));
      await tester.pump();
      expect(h.fake.count('PUT', _dest), 0);
      h.fake.destinationGate!.complete();
      h.fake.destinationGate = null;
      await KeepHarness.pumpFor(tester);
      expect(find.byKey(const ValueKey('destination-loading')), findsNothing);
      expect(find.text('Rooftop Cypher lands at'), findsOneWidget);
    });

    testWidgets('no library takes new files: one line and Close', (
      tester,
    ) async {
      h.fake.destination = {
        'destination': null,
        'saved': null,
        'libraries': [],
        'defaultLayout': '{{ALBUMARTIST}}/{{ALBUM}}',
        'variables': [],
      };
      await pumpPicker(tester);
      expect(
        find.text('No library on your server takes new files'),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('destination-form')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('destination-close-blocked')));
      await KeepHarness.pumpFor(tester);
      expect(find.text('Where copies land'), findsNothing);
    });

    testWidgets("uploads off: \"Your account can't add files\"", (
      tester,
    ) async {
      h.server.noUpload = true;
      h.fake.destination = {
        'destination': null,
        'saved': null,
        'libraries': [],
      };
      await pumpPicker(tester);
      expect(
        find.text("Your account can't add files to this server"),
        findsOneWidget,
      );
      expect(
        find.text('No library on your server takes new files'),
        findsNothing,
      );
    });

    testWidgets("a failed read: the sentence, the server's words, Try again", (
      tester,
    ) async {
      h.fake.refuse[_dest] = (500, 'database is locked');
      await pumpPicker(tester);
      expect(find.text("Couldn't load where copies land"), findsOneWidget);
      expect(find.text('database is locked'), findsOneWidget);
      h.fake.refuse.clear();
      await tester.tap(find.byKey(const ValueKey('destination-try-again')));
      await KeepHarness.pumpFor(tester);
      expect(find.text('Rooftop Cypher lands at'), findsOneWidget);
    });

    testWidgets(
      'the keyboard up: the sheet lifts above it and Save stays in reach',
      (tester) async {
        await pumpPicker(tester);
        tester.view.viewInsets = const FakeViewPadding(bottom: 300 * 3);
        addTearDown(tester.view.resetViewInsets);
        await tester.tap(find.byKey(const ValueKey('destination-base')));
        await KeepHarness.pumpFor(tester);
        expect(tester.takeException(), isNull);
        final save = tester.getRect(
          find.byKey(const ValueKey('destination-save')),
        );
        expect(save.bottom, lessThanOrEqualTo(844 - 300));
        final field = tester.getRect(
          find.byKey(const ValueKey('destination-base')),
        );
        expect(field.bottom, lessThanOrEqualTo(844 - 300));
      },
    );

    testWidgets('German at 1.3× on 360 px: nothing overflows', (tester) async {
      await pumpPicker(
        tester,
        width: 360,
        height: 780,
        textScale: 1.3,
        locale: const Locale('de'),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Wo Kopien landen'), findsOneWidget);
      expect(find.text('Bibliotheksstandard'), findsOneWidget);
      await tester.drag(
        find.byKey(const ValueKey('destination-form')),
        const Offset(0, -400),
      );
      await KeepHarness.pumpFor(tester);
      expect(tester.takeException(), isNull);
    });
  });

  group('Open elsewhere', () {
    final links = [
      {
        'id': 'musicbrainz-recording',
        'label': 'MusicBrainz recording',
        'url': 'https://musicbrainz.org/recording/abc',
        'kind': 'canonical',
      },
      {
        'id': 'musicbrainz-release-group',
        'label': 'MusicBrainz release group',
        'url': 'https://musicbrainz.org/release-group/def',
        'kind': 'canonical',
      },
      {
        'id': 'musicbrainz-search',
        'label': 'Search MusicBrainz',
        'url': 'https://musicbrainz.org/search?query=x',
        'kind': 'search',
      },
      {
        'id': 'deezer-search',
        'label': 'Search Deezer',
        'url':
            'https://www.deezer.com/search/Boukmanflow%20Late%20Train%20Verse',
        'kind': 'search',
      },
      {
        'id': 'youtube-search',
        'label': 'Search YouTube',
        'url': 'https://www.youtube.com/results?search_query=x',
        'kind': 'search',
      },
      {
        'id': 'some-new-search',
        'label': 'Search Elsewhere FM',
        'url': 'https://elsewhere.example/search?q=x',
        'kind': 'search',
      },
    ];

    Future<void> openElsewhere(WidgetTester tester) async {
      await k.pumpDiscover(tester);
      await tester.longPress(find.text('Late Train Verse'));
      await frames(tester, 8);
      await tapText(tester, 'Open elsewhere');
      await frames(tester, 4);
    }

    testWidgets(
      'asked only when tapped, the row unchanged; loading keeps the list\'s '
      'shape; exact pages first, then searches',
      (tester) async {
        k.fake.links = links;
        k.fake.linksGate = Completer<void>();
        await k.pumpDiscover(tester);
        await tester.longPress(find.text('Late Train Verse'));
        await frames(tester, 8);
        expect(k.fake.count('POST', _resolve), 0, reason: 'never prefetched');
        await tapText(tester, 'Open elsewhere');
        await frames(tester, 2);
        expect(find.byKey(const ValueKey('elsewhere-loading')), findsOneWidget);
        expect(find.text('Late Train Verse · Boukmanflow'), findsOneWidget);
        final body =
            jsonDecode(k.fake.calls('POST', _resolve).single.body) as Map;
        expect(
          body['recommendation'],
          jsonDecode(jsonEncode(k.lead('Late Train Verse').raw)),
        );
        k.fake.linksGate!.complete();
        k.fake.linksGate = null;
        await frames(tester);
        expect(find.text('EXACT PAGES'), findsOneWidget);
        expect(find.text('SEARCH'), findsOneWidget);
        expect(find.text('MusicBrainz recording'), findsOneWidget);
        expect(find.text('MusicBrainz release group'), findsOneWidget);
        expect(find.text('MusicBrainz'), findsOneWidget);
        expect(find.text('Deezer'), findsOneWidget);
        expect(find.text('YouTube'), findsOneWidget);
        expect(
          find.text('Search Elsewhere FM'),
          findsOneWidget,
          reason: "the plug-in's own label",
        );
        expect(
          tester.getTopLeft(find.text('MusicBrainz release group')).dy,
          lessThan(tester.getTopLeft(find.text('Deezer')).dy),
        );
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('a row opens outside the app; one that will not says so and '
        'the sheet stays', (tester) async {
      k.fake.links = links;
      final opened = <Uri>[];
      var ok = true;
      elsewhereLaunch = (uri) async {
        opened.add(uri);
        return ok;
      };
      await openElsewhere(tester);
      await tapText(tester, 'Deezer');
      expect(
        opened.single.toString(),
        'https://www.deezer.com/search/Boukmanflow%20Late%20Train%20Verse',
      );
      expect(toasts, isEmpty);
      ok = false;
      await tapText(tester, 'YouTube');
      expect(toasts, ["Couldn't open that link"]);
      expect(find.text('EXACT PAGES'), findsOneWidget, reason: 'still open');
    });

    testWidgets('empty: one sentence and Close', (tester) async {
      k.fake.links = [];
      await openElsewhere(tester);
      expect(find.text('No links for this song'), findsOneWidget);
      expect(
        find.text(
          'It has no MusicBrainz ids, and no title or artist to search for.',
        ),
        findsOneWidget,
      );
      await tapKey(tester, 'elsewhere-close-empty');
      await frames(tester, 6);
      expect(find.text('No links for this song'), findsNothing);
      expect(
        find.text('KEEP A COPY'),
        findsOneWidget,
        reason: 'back on the song sheet',
      );
    });

    testWidgets("the server's error verbatim, Try again", (tester) async {
      k.fake.links = links;
      k.fake.refuse[_resolve] = (
        502,
        'plug-in links could not resolve this recommendation',
      );
      await openElsewhere(tester);
      expect(find.text("Couldn't look up links right now"), findsOneWidget);
      expect(
        find.text('plug-in links could not resolve this recommendation'),
        findsOneWidget,
      );
      k.fake.refuse.clear();
      await tapKey(tester, 'elsewhere-try-again');
      expect(find.text('Deezer'), findsOneWidget);
    });

    testWidgets('an error with no words of the server: only the first line', (
      tester,
    ) async {
      k.fake.refuse[_resolve] = (502, '');
      await openElsewhere(tester);
      expect(find.text("Couldn't look up links right now"), findsOneWidget);
      expect(find.textContaining('HTTP'), findsNothing);
    });

    testWidgets('German at 1.3× on 360 px', (tester) async {
      k.fake.links = links;
      await k.pumpDiscover(
        tester,
        width: 360,
        height: 2400,
        textScale: 1.3,
        locale: const Locale('de'),
      );
      await tester.longPress(find.text('Late Train Verse'));
      await frames(tester, 8);
      await tapText(tester, 'Woanders öffnen');
      await frames(tester, 4);
      expect(tester.takeException(), isNull);
      expect(find.text('GENAUE SEITEN'), findsOneWidget);
      expect(find.text('MusicBrainz-Aufnahme'), findsOneWidget);
    });
  });
}
