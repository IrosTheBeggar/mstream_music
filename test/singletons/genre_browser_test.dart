// The Genres browser against a fake mStream (mStream #716's `source` filter):
// what the list and a genre's songs ask for, the frame it leaves on
// BrowserManager's stack (the toolbar's switch reads it), the fallback when
// a kind is empty, a server that predates the filter, re-listing in place —
// and the toolbar's Tags | Generated | Both switch drawn on the genre list
// only, re-listing when tapped.
//
// Every request goes through ApiManager.makeServerCall's per-call
// http.Client, so running a body inside http.runWithClient answers it.

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/l10n/localizations_delegates.dart';
import 'package:mstream_music/objects/genre_source.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/singletons/api.dart';
import 'package:mstream_music/singletons/browser_list.dart';
import 'package:mstream_music/singletons/server_list.dart';
import 'package:mstream_music/singletons/settings.dart';
import 'package:mstream_music/widgets/browser_toolbar.dart';

final _server = Server('http://music.local:3000', null, null, 'JWT', 'home');

const _genres = {
  'tag': [
    {'name': 'Ambient', 'track_count': 3},
    {'name': 'Electronic', 'track_count': 5},
  ],
  'model': [
    {'name': 'Ambient', 'track_count': 1},
    {'name': 'Synthwave', 'track_count': 2},
  ],
};

/// A fake mStream: /db/genres answers the asked-for kind (every genre
/// without one) plus `sources`; `withSources: false` plays a server that
/// predates the filter. /db/genre-songs answers one song per call.
class _FakeServer {
  _FakeServer({this.tag = true, this.model = true, this.withSources = true});
  final bool tag;
  final bool model;
  final bool withSources;
  final requests = <({String path, Map<String, dynamic> body})>[];

  List<Map<String, dynamic>> bodiesFor(String path) =>
      [for (final r in requests) if (r.path == path) r.body];

  MockClient get client => MockClient((req) async {
        final body = req.body.isEmpty
            ? <String, dynamic>{}
            : (jsonDecode(req.body) as Map).cast<String, dynamic>();
        requests.add((path: req.url.path, body: body));
        if (req.url.path == '/api/v1/db/genres') {
          final have = {
            'tag': tag ? _genres['tag']! : const [],
            'model': model ? _genres['model']! : const [],
          };
          final source = withSources ? body['source'] as String? : null;
          final genres =
              source == null ? [...have['tag']!, ...have['model']!] : have[source]!;
          return http.Response(
              jsonEncode({
                'genres': genres,
                if (withSources)
                  'sources': {
                    'tag': have['tag']!.length,
                    'model': have['model']!.length
                  },
              }),
              200,
              headers: {'content-type': 'application/json'});
        }
        if (req.url.path == '/api/v1/db/genre-songs') {
          return http.Response(
              jsonEncode([
                {
                  'filepath': 'music/${body['genre']}.mp3',
                  'metadata': {'title': '${body['genre']} song'}
                }
              ]),
              200,
              headers: {'content-type': 'application/json'});
        }
        return http.Response('not found', 404);
      });

  Future<T> run<T>(Future<T> Function() body) =>
      http.runWithClient(body, () => client);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Download badges and the settings file go through path_provider; a VM
  // test has no platform side, so point it at a scratch folder.
  late Directory scratch;
  setUpAll(() {
    scratch = Directory.systemTemp.createTempSync('mstream-genre-test-');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/path_provider'),
            (_) async => scratch.path);
  });
  tearDownAll(() {
    try {
      scratch.deleteSync(recursive: true);
    } catch (_) {}
  });

  setUp(() {
    ServerManager().serverList
      ..clear()
      ..add(_server);
    ServerManager().currentServer = _server;
    SettingsManager().genreSource = GenreSource.tag;
    BrowserManager().goToNavScreen();
  });
  tearDown(() {
    ServerManager().currentServer = null;
    ServerManager().serverList.clear();
  });

  test('the home lists Genres after Artists', () {
    final names = BrowserManager()
        .browserList
        .where((e) => e.type == 'execAction')
        .map((e) => e.data)
        .toList();
    expect(names.indexOf('genres'), names.indexOf('artists') + 1);
  });

  group('the genre list', () {
    test('asks for tag genres by default and offers the switch', () async {
      final fake = _FakeServer();
      await fake.run(() => ApiManager().getGenreList(useThisServer: _server));

      expect(fake.bodiesFor('/api/v1/db/genres'), [
        {'source': 'tag'}
      ]);
      final frame = BrowserManager().currentGenreFrame!;
      expect(frame.source, GenreSource.tag);
      expect(frame.offersChoice, isTrue);
      expect(BrowserManager().listName, 'Genres');
      final rows = BrowserManager().browserList;
      expect(rows.map((e) => (e.type, e.name, e.subtext)).toList(), [
        ('genre', 'Ambient', '3'),
        ('genre', 'Electronic', '5'),
      ]);
    });

    test('a genre\'s songs carry the list\'s kind; Back brings the list '
        'and its state back', () async {
      final fake = _FakeServer();
      SettingsManager().genreSource = GenreSource.model;
      await fake.run(() async {
        await ApiManager().getGenreList(useThisServer: _server);
        await ApiManager().getGenreSongs('Synthwave',
            useThisServer: _server,
            source: BrowserManager().currentGenreFrame!.songsSource);
      });

      expect(fake.bodiesFor('/api/v1/db/genre-songs'), [
        {'genre': 'Synthwave', 'source': 'model'}
      ]);
      expect(BrowserManager().currentGenreFrame, isNull,
          reason: 'the songs frame is not the genre list');
      expect(BrowserManager().browserList.single.type, 'file');

      BrowserManager().popBrowser();
      expect(BrowserManager().currentGenreFrame?.source, GenreSource.model);
    });

    test('both asks without a filter, and so do its genres\' songs', () async {
      final fake = _FakeServer();
      SettingsManager().genreSource = GenreSource.both;
      await fake.run(() async {
        await ApiManager().getGenreList(useThisServer: _server);
        await ApiManager().getGenreSongs('Ambient',
            useThisServer: _server,
            source: BrowserManager().currentGenreFrame!.songsSource);
      });
      expect(fake.bodiesFor('/api/v1/db/genres'), [<String, dynamic>{}]);
      expect(fake.bodiesFor('/api/v1/db/genre-songs'), [
        {'genre': 'Ambient'}
      ]);
    });

    test('only generated genres: the other kind, no switch', () async {
      final fake = _FakeServer(tag: false);
      await fake.run(() => ApiManager().getGenreList(useThisServer: _server));
      expect(fake.bodiesFor('/api/v1/db/genres'), [
        {'source': 'tag'},
        {'source': 'model'},
      ]);
      final frame = BrowserManager().currentGenreFrame!;
      expect(frame.source, GenreSource.model);
      expect(frame.offersChoice, isFalse);
      expect(BrowserManager().browserList.map((e) => e.name),
          ['Ambient', 'Synthwave']);
    });

    test('a server without the filter: every genre, no switch, songs '
        'asked for as always', () async {
      final fake = _FakeServer(withSources: false);
      await fake.run(() => ApiManager().getGenreList(useThisServer: _server));
      final frame = BrowserManager().currentGenreFrame!;
      expect(frame.offersChoice, isFalse);
      expect(frame.songsSource, isNull);
      expect(BrowserManager().browserList, hasLength(4));
    });

    test('re-listing replaces the open list in place, and is dropped once '
        'the user has moved on', () async {
      final fake = _FakeServer();
      await fake.run(() async {
        await ApiManager().getGenreList(useThisServer: _server);
        final depth = BrowserManager().browserCache.length;

        SettingsManager().genreSource = GenreSource.model;
        await ApiManager().getGenreList(useThisServer: _server, replace: true);
        expect(BrowserManager().browserCache.length, depth, reason: 'no push');
        expect(BrowserManager().currentGenreFrame?.source, GenreSource.model);
        expect(BrowserManager().browserList.map((e) => e.name),
            ['Ambient', 'Synthwave']);

        await ApiManager().getGenreSongs('Ambient', useThisServer: _server);
        await ApiManager().getGenreList(useThisServer: _server, replace: true);
        expect(BrowserManager().currentGenreFrame, isNull,
            reason: 'the songs frame stays on top');
        expect(BrowserManager().browserList.single.type, 'file');
      });
    });
  });

  group('the toolbar switch', () {
    Future<void> pumpToolbar(WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        home: const Scaffold(appBar: BrowserToolbar()),
      ));
      await tester.pumpAndSettle();
    }

    Set<GenreSource> selected(WidgetTester tester) => tester
        .widget<SegmentedButton<GenreSource>>(
            find.byType(SegmentedButton<GenreSource>))
        .selected;

    testWidgets('shows on the genre list with Tags selected; Generated '
        're-lists in place and is remembered', (tester) async {
      final fake = _FakeServer();
      await fake.run(() async {
        await ApiManager().getGenreList(useThisServer: _server);
        await pumpToolbar(tester);
        expect(find.text('Tags'), findsOneWidget);
        expect(find.text('Generated'), findsOneWidget);
        expect(find.text('Both'), findsOneWidget);
        expect(selected(tester), {GenreSource.tag});

        final depth = BrowserManager().browserCache.length;
        await tester.tap(find.text('Generated'));
        await tester.pumpAndSettle();
        expect(SettingsManager().genreSource, GenreSource.model);
        expect(fake.bodiesFor('/api/v1/db/genres').last, {'source': 'model'});
        expect(BrowserManager().browserCache.length, depth);
        expect(selected(tester), {GenreSource.model});
      });
    });

    testWidgets('is not drawn on a genre\'s songs, nor when the server has '
        'one kind', (tester) async {
      final fake = _FakeServer();
      await fake.run(() async {
        await ApiManager().getGenreList(useThisServer: _server);
        await ApiManager().getGenreSongs('Ambient',
            useThisServer: _server, source: GenreSource.tag);
        await pumpToolbar(tester);
        expect(find.byType(SegmentedButton<GenreSource>), findsNothing);
      });

      BrowserManager().goToNavScreen();
      final oneKind = _FakeServer(model: false);
      await oneKind.run(() async {
        await ApiManager().getGenreList(useThisServer: _server);
        await pumpToolbar(tester);
        expect(find.byType(SegmentedButton<GenreSource>), findsNothing);
      });
    });
  });
}
