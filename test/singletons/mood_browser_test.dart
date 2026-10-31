// Albums, Artists, Rated and Recent against a fake mStream (mStream #1092's
// and #1095's mood filters):
// what each list asks for — a plain GET without a filter, a POST carrying
// `moods` with one — the frame it leaves on BrowserManager's stack when the
// answer echoes the filter (the toolbar's Filters reads it), a server that
// cannot filter, re-listing in place, an overtaken answer; the song lists
// (Rated, Recent), whose bare-array answers carry no echo, going by the
// server's flag instead, each song's match and the Sort that ranks by it —
// then, through the real toolbar and Browser screen, the Filters button and
// its count, the sheet (only Done applies; a level alone asks nothing) and
// the grey strip with its Clear.
//
// Every request goes through ApiManager.makeServerCall's per-call
// http.Client, so running a body inside http.runWithClient answers it.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/l10n/localizations_delegates.dart';
import 'package:mstream_music/objects/mood_filter.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/screens/browser.dart';
import 'package:mstream_music/singletons/api.dart';
import 'package:mstream_music/singletons/browser_list.dart';
import 'package:mstream_music/singletons/server_list.dart';
import 'package:mstream_music/widgets/browser_toolbar.dart';

final _server = Server('http://music.local:3000', null, null, 'JWT', 'home');

const _albums = [
  {'name': 'Perspectives EP', 'album_artist': 'Color Out', 'year': 2020},
  {'name': 'Stim Pack Volume one', 'album_artist': 'Boukmanflow', 'year': 2019},
];
const _artists = ['ALM', 'Boukmanflow', 'Color Out'];
const _songs = [
  {
    'filepath': 'music/Color Out/High Hopes.mp3',
    'metadata': {'title': 'High Hopes', 'artist': 'Color Out'}
  },
  {
    'filepath': 'music/ALM/Swing.mp3',
    'metadata': {'title': 'Swing', 'artist': 'ALM'}
  },
];

/// A fake mStream: a relaxed filter keeps Stim Pack and ALM, any other
/// filter keeps everything, and every answer echoes the filter it applied —
/// unless [echo] is false (an older server, or one with no scores yet,
/// which ignores the filter). [gate], when set, holds the next answer.
class _FakeServer {
  _FakeServer({this.echo = true});
  final bool echo;
  Completer<void>? gate;
  final requests = <({String path, String method, Map<String, dynamic> body})>[];

  List<({String path, String method, Map<String, dynamic> body})> to(
          String path) =>
      [for (final r in requests) if (r.path == path) r];

  MockClient get client => MockClient((req) async {
        final body = req.body.isEmpty
            ? <String, dynamic>{}
            : (jsonDecode(req.body) as Map).cast<String, dynamic>();
        requests.add((path: req.url.path, method: req.method, body: body));
        final held = gate;
        if (held != null) {
          gate = null;
          await held.future;
        }
        final moods = echo ? body['moods'] as Map? : null;
        final relaxed = moods?['energy'] == 'relaxed';
        Map<String, dynamic> reply(String key, List rows) => {
              key: rows,
              if (echo) 'moods': moods ?? {},
            };
        if (req.url.path == '/api/v1/db/albums') {
          return http.Response(
              jsonEncode(reply('albums', relaxed ? [_albums[1]] : _albums)),
              200,
              headers: {'content-type': 'application/json'});
        }
        if (req.url.path == '/api/v1/db/artists') {
          return http.Response(
              jsonEncode(reply('artists', relaxed ? ['ALM'] : _artists)), 200,
              headers: {'content-type': 'application/json'});
        }
        if (req.url.path == '/api/v1/db/artists-albums') {
          return http.Response(jsonEncode({'albums': [_albums[1]]}), 200,
              headers: {'content-type': 'application/json'});
        }
        // The song lists: bare arrays, filtered by what they are sent. A
        // sad filter keeps both, each with its match — High Hopes 0.55,
        // Swing 0.85, in the list's own order; at threshold 0.7, Swing.
        if (req.url.path == '/api/v1/db/rated' ||
            req.url.path == '/api/v1/db/recent/added') {
          final m = body['moods'] as Map?;
          final rows = m?['valence'] == 'sad'
              ? [
                  if ((m?['threshold'] ?? 0.5) < 0.55)
                    {..._songs[0], 'moodMatch': 0.55},
                  {..._songs[1], 'moodMatch': 0.85},
                ]
              : m?['energy'] == 'relaxed'
                  ? [_songs[1]]
                  : _songs;
          return http.Response(jsonEncode(rows), 200,
              headers: {'content-type': 'application/json'});
        }
        return http.Response('not found', 404);
      });

  Future<T> run<T>(Future<T> Function() body) =>
      http.runWithClient(body, () => client);
}

const _relaxed = MoodFilter(energy: 'relaxed');

List<String> _names() => [for (final e in BrowserManager().browserList) e.name];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Download badges go through path_provider; a VM test has no platform
  // side, so point it at a scratch folder.
  late Directory scratch;
  setUpAll(() {
    scratch = Directory.systemTemp.createTempSync('mstream-mood-test-');
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
    MoodFilters().reset();
    BrowserManager().goToNavScreen();
  });
  tearDown(() {
    MoodFilters().reset();
    _server.moodFiltersAvailable = null;
    ServerManager().currentServer = null;
    ServerManager().serverList.clear();
  });

  group('the lists', () {
    test('no filter: a plain GET; the echo leaves a frame to offer Filters on',
        () async {
      final fake = _FakeServer();
      await fake.run(() async {
        await ApiManager().getAlbums(useThisServer: _server);
      });
      final asked = fake.to('/api/v1/db/albums').single;
      expect(asked.method, 'GET');
      expect(asked.body, isEmpty);
      expect(BrowserManager().currentMoodFrame?.page, MoodPage.albums);
      expect(_names(), ['Perspectives EP', 'Stim Pack Volume one']);
    });

    test('a server that cannot filter leaves no frame', () async {
      final fake = _FakeServer(echo: false);
      await fake.run(() async {
        await ApiManager().getArtists(useThisServer: _server);
      });
      expect(BrowserManager().currentMoodFrame, isNull);
      expect(_names(), _artists);
    });

    test('a set filter is a POST with moods — on that page only', () async {
      MoodFilters().set(MoodPage.albums, _relaxed);
      final fake = _FakeServer();
      await fake.run(() async {
        await ApiManager().getAlbums(useThisServer: _server);
        await ApiManager().getArtists(useThisServer: _server);
      });
      final albums = fake.to('/api/v1/db/albums').single;
      expect(albums.method, 'POST');
      expect(albums.body, {
        'moods': {'energy': 'relaxed'}
      });
      expect(fake.to('/api/v1/db/artists').single.method, 'GET',
          reason: 'Artists keeps its own (empty) filter');
    });

    test('changing the filter re-lists in place', () async {
      final fake = _FakeServer();
      await fake.run(() async {
        await ApiManager().getAlbums(useThisServer: _server);
        final depth = BrowserManager().browserCache.length;
        await ApiManager()
            .setMoodFilter(BrowserManager().currentMoodFrame!, _relaxed);
        expect(BrowserManager().browserCache.length, depth);
      });
      expect(_names(), ['Stim Pack Volume one']);
      expect(MoodFilters().of(MoodPage.albums), _relaxed);
      expect(fake.to('/api/v1/db/albums').last.body, {
        'moods': {'energy': 'relaxed'}
      });

      // Clear: back to the plain list.
      await fake.run(() => ApiManager()
          .setMoodFilter(BrowserManager().currentMoodFrame!, MoodFilter.empty));
      expect(fake.to('/api/v1/db/albums').last.method, 'GET');
      expect(_names(), ['Perspectives EP', 'Stim Pack Volume one']);
    });

    test('an answer overtaken by a newer filter is dropped', () async {
      final fake = _FakeServer();
      await fake.run(() async {
        await ApiManager().getAlbums(useThisServer: _server);
        final frame = BrowserManager().currentMoodFrame!;
        // The relaxed list is held; the filter is cleared before it lands.
        final gate = fake.gate = Completer<void>();
        final slow = ApiManager().setMoodFilter(frame, _relaxed);
        await pumpEventQueue();
        final fast = ApiManager().setMoodFilter(frame, MoodFilter.empty);
        await fast;
        gate.complete();
        await slow;
      });
      expect(_names(), ['Perspectives EP', 'Stim Pack Volume one'],
          reason: 'the relaxed answer landed last but was asked first');
    });

    test("a list pushed over it has no frame; Back brings the list's back",
        () async {
      final fake = _FakeServer();
      await fake.run(() async {
        await ApiManager().getArtists(useThisServer: _server);
        await ApiManager().getArtistAlbums('ALM', useThisServer: _server);
      });
      expect(BrowserManager().currentMoodFrame, isNull,
          reason: "an artist's albums are not filtered");
      BrowserManager().popBrowser();
      expect(BrowserManager().currentMoodFrame?.page, MoodPage.artists);
    });
  });

  group('the song lists', () {
    const swing = 'music/ALM/Swing.mp3';
    const both = ['music/Color Out/High Hopes.mp3', swing];

    test('without the flag: Rated is the plain GET, Recent sends no moods, '
        'and neither offers Filters — even with a filter set', () async {
      MoodFilters().set(MoodPage.rated, _relaxed);
      MoodFilters().set(MoodPage.recent, _relaxed);
      final fake = _FakeServer();
      await fake.run(() async {
        await ApiManager().getRated(useThisServer: _server);
        expect(BrowserManager().currentMoodFrame, isNull);
        await ApiManager().getRecentlyAdded(useThisServer: _server);
        expect(BrowserManager().currentMoodFrame, isNull);
      });
      final rated = fake.to('/api/v1/db/rated').single;
      expect(rated.method, 'GET');
      expect(rated.body, isEmpty);
      expect(fake.to('/api/v1/db/recent/added').single.body, {'limit': 100});
      expect(_names(), both, reason: 'the old route ignores what it never got');
    });

    test('with it: Rated asks a GET while nothing is set and a POST with '
        'moods once set, re-listing in place', () async {
      _server.moodFiltersAvailable = true;
      final fake = _FakeServer();
      await fake.run(() async {
        await ApiManager().getRated(useThisServer: _server);
        expect(BrowserManager().currentMoodFrame?.page, MoodPage.rated);
        expect(fake.to('/api/v1/db/rated').single.method, 'GET');
        final depth = BrowserManager().browserCache.length;
        await ApiManager()
            .setMoodFilter(BrowserManager().currentMoodFrame!, _relaxed);
        expect(BrowserManager().browserCache.length, depth);
      });
      final last = fake.to('/api/v1/db/rated').last;
      expect(last.method, 'POST');
      expect(last.body, {
        'moods': {'energy': 'relaxed'}
      });
      expect(_names(), [swing]);
      expect(BrowserManager().listName, 'Rated');
      expect(BrowserManager().currentMoodFrame?.page, MoodPage.rated);
    });

    test('Recent keeps its limit and adds moods; Clear asks it again without',
        () async {
      _server.moodFiltersAvailable = true;
      MoodFilters().set(MoodPage.recent, _relaxed);
      final fake = _FakeServer();
      await fake.run(() async {
        await ApiManager().getRecentlyAdded(useThisServer: _server);
        expect(BrowserManager().currentMoodFrame?.page, MoodPage.recent);
        expect(_names(), [swing]);
        await ApiManager().setMoodFilter(
            BrowserManager().currentMoodFrame!, MoodFilter.empty);
      });
      final asked = fake.to('/api/v1/db/recent/added');
      expect(asked.first.body, {
        'limit': 100,
        'moods': {'energy': 'relaxed'}
      });
      expect(asked.last.body, {'limit': 100});
      expect(_names(), both);
      expect(MoodFilters().of(MoodPage.rated).isEmpty, isTrue,
          reason: 'each list keeps its own filter');
    });

    test("a filtered answer: in the list's own order, best match first "
        'under Match; Strict asks with the threshold; a level alone asks '
        'nothing', () async {
      _server.moodFiltersAvailable = true;
      const sad = MoodFilter(valence: 'sad');
      MoodFilters().set(MoodPage.recent, sad);
      final fake = _FakeServer();
      await fake.run(() async {
        await ApiManager().getRecentlyAdded(useThisServer: _server);
        expect(_names(), both);
        expect([for (final e in BrowserManager().browserList) e.moodMatch],
            [0.55, 0.85]);
        final frame = BrowserManager().currentMoodFrame!;
        await ApiManager().setMoodFilter(frame, sad, sort: MoodSort.match);
        expect(_names(), [swing, both[0]]);
        await ApiManager()
            .setMoodFilter(frame, sad.withLevel(MoodLevel.strict));
        expect(_names(), [swing]);
        expect(fake.to('/api/v1/db/recent/added').last.body, {
          'limit': 100,
          'moods': {'valence': 'sad', 'threshold': 0.7}
        });
        await ApiManager().setMoodFilter(
            frame, const MoodFilter(level: MoodLevel.strict));
        expect(fake.to('/api/v1/db/recent/added').last.body, {'limit': 100});
        expect(_names(), both, reason: 'no mood: Match rests');
        final n = fake.requests.length;
        await ApiManager().setMoodFilter(frame, MoodFilter.empty);
        await ApiManager()
            .setMoodFilter(frame, MoodFilter.empty, sort: MoodSort.list);
        expect(fake.requests, hasLength(n),
            reason: 'the list would come back the same');
      });
    });

    test('a Recent answer overtaken by a newer filter is dropped', () async {
      _server.moodFiltersAvailable = true;
      final fake = _FakeServer();
      await fake.run(() async {
        await ApiManager().getRecentlyAdded(useThisServer: _server);
        final frame = BrowserManager().currentMoodFrame!;
        final gate = fake.gate = Completer<void>();
        final slow = ApiManager().setMoodFilter(frame, _relaxed);
        await pumpEventQueue();
        await ApiManager().setMoodFilter(frame, MoodFilter.empty);
        gate.complete();
        await slow;
      });
      expect(_names(), both);
    });
  });

  group('the toolbar, the sheet and the strip', () {
    Future<void> pumpBrowser(WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        home: const Scaffold(appBar: BrowserToolbar(), body: Browser()),
      ));
      await tester.pumpAndSettle();
    }

    final button = find.byKey(const ValueKey('mood-filters'));
    final sheet = find.byKey(const ValueKey('mood-sheet'));
    final strip = find.byKey(const ValueKey('mood-strip'));
    bool counted(WidgetTester tester) => tester
        .widget<Badge>(find.descendant(of: button, matching: find.byType(Badge)))
        .isLabelVisible;
    Finder inStrip(String text) =>
        find.descendant(of: strip, matching: find.text(text));

    testWidgets('offers Filters left of search where the list can filter; '
        'nothing set, no count and no strip', (tester) async {
      final fake = _FakeServer();
      await fake.run(() => ApiManager().getAlbums(useThisServer: _server));
      await pumpBrowser(tester);
      expect(button, findsOneWidget);
      expect(tester.getRect(find.byIcon(Icons.search)).left,
          greaterThan(tester.getRect(button).right));
      expect(counted(tester), isFalse);
      expect(strip, findsNothing);
    });

    testWidgets('the sheet applies on Done: the list asks again, the button '
        'counts the choices and the strip names them', (tester) async {
      final fake = _FakeServer();
      await fake.run(() async {
        await ApiManager().getAlbums(useThisServer: _server);
        await pumpBrowser(tester);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(sheet, findsOneWidget);
        await tester.tap(find.text('Relaxed'));
        await tester.tap(find.text('Instrumental'));
        await tester.pumpAndSettle();
        expect(fake.to('/api/v1/db/albums'), hasLength(1),
            reason: 'nothing is asked before Done');
        expect(MoodFilters().of(MoodPage.albums).isEmpty, isTrue);
        await tester.tap(find.byKey(const ValueKey('mood-sheet-done')));
        await tester.pumpAndSettle();
      });
      expect(sheet, findsNothing);
      expect(fake.to('/api/v1/db/albums').last.body, {
        'moods': {'energy': 'relaxed', 'voice': 'instrumental'}
      });
      expect(_names(), ['Stim Pack Volume one']);
      expect(counted(tester), isTrue);
      expect(find.descendant(of: button, matching: find.text('2')),
          findsOneWidget);
      expect(inStrip('Relaxed · Instrumental'), findsOneWidget);
    });

    testWidgets('closing the sheet without Done changes nothing',
        (tester) async {
      final fake = _FakeServer();
      await fake.run(() async {
        await ApiManager().getAlbums(useThisServer: _server);
        await pumpBrowser(tester);
        await tester.tap(button);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Happy'));
        await tester.pumpAndSettle();
        await tester.tap(find.byTooltip('Close'));
        await tester.pumpAndSettle();
      });
      expect(sheet, findsNothing);
      expect(MoodFilters().of(MoodPage.albums).isEmpty, isTrue);
      expect(fake.to('/api/v1/db/albums'), hasLength(1));
      expect(strip, findsNothing);
    });

    testWidgets("the strip's Clear lets every choice go and asks again",
        (tester) async {
      MoodFilters().set(MoodPage.artists,
          const MoodFilter(energy: 'relaxed', tags: ['party']));
      final fake = _FakeServer();
      await fake.run(() async {
        await ApiManager().getArtists(useThisServer: _server);
        await pumpBrowser(tester);
        expect(inStrip('Relaxed · Party'), findsOneWidget);
        expect(find.descendant(of: button, matching: find.text('2')),
            findsOneWidget);
        expect(_names(), ['ALM']);
        await tester.tap(find.byKey(const ValueKey('mood-strip-clear')));
        await tester.pumpAndSettle();
      });
      expect(strip, findsNothing);
      expect(counted(tester), isFalse);
      expect(MoodFilters().of(MoodPage.artists).isEmpty, isTrue);
      expect(fake.to('/api/v1/db/artists').last.method, 'GET');
      expect(_names(), _artists);
    });

    testWidgets('on Rated, Filters goes before Play; Done re-lists it and the '
        'strip names the choice', (tester) async {
      _server.moodFiltersAvailable = true;
      final fake = _FakeServer();
      await fake.run(() async {
        await ApiManager().getRated(useThisServer: _server);
        await pumpBrowser(tester);
        expect(tester.getRect(button).right,
            lessThanOrEqualTo(tester.getRect(find.byTooltip('Play')).left));
        await tester.tap(button);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Relaxed'));
        await tester.tap(find.byKey(const ValueKey('mood-sheet-done')));
        await tester.pumpAndSettle();
      });
      expect(fake.to('/api/v1/db/rated').last.body, {
        'moods': {'energy': 'relaxed'}
      });
      expect(_names(), ['music/ALM/Swing.mp3']);
      expect(inStrip('Relaxed'), findsOneWidget);
      expect(find.descendant(of: button, matching: find.text('1')),
          findsOneWidget);
    });

    testWidgets("Rated under a filter: the sheet's Sort draws the best match "
        'first; Strict re-lists at the threshold and the strip names it',
        (tester) async {
      _server.moodFiltersAvailable = true;
      MoodFilters().set(MoodPage.rated, const MoodFilter(valence: 'sad'));
      final done = find.byKey(const ValueKey('mood-sheet-done'));
      final sort = find.byKey(const ValueKey('mood-sort'));
      final fake = _FakeServer();
      await fake.run(() async {
        await ApiManager().getRated(useThisServer: _server);
        await pumpBrowser(tester);
        expect(tester.getRect(find.text('High Hopes')).top,
            lessThan(tester.getRect(find.text('Swing')).top),
            reason: 'its own order');
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(find.descendant(of: sort, matching: find.text('Rating')),
            findsOneWidget);
        await tester.tap(find.text('Match'));
        await tester.tap(done);
        await tester.pumpAndSettle();
        expect(tester.getRect(find.text('Swing')).top,
            lessThan(tester.getRect(find.text('High Hopes')).top),
            reason: 'best match first');

        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(
            tester.widget<SegmentedButton<MoodSort>>(sort).selected,
            {MoodSort.match},
            reason: 'the list keeps its Sort');
        await tester.tap(find.text('Strict'));
        await tester.tap(done);
        await tester.pumpAndSettle();
      });
      expect(fake.to('/api/v1/db/rated').last.body, {
        'moods': {'valence': 'sad', 'threshold': 0.7}
      });
      expect(find.text('High Hopes'), findsNothing);
      expect(inStrip('Sad · Strict'), findsOneWidget);
      expect(find.descendant(of: button, matching: find.text('1')),
          findsOneWidget,
          reason: 'the level is not a choice');
    });

    testWidgets('a level picked with no mood set asks nothing, and is kept',
        (tester) async {
      _server.moodFiltersAvailable = true;
      final fake = _FakeServer();
      await fake.run(() async {
        await ApiManager().getRated(useThisServer: _server);
        await pumpBrowser(tester);
        await tester.tap(button);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Loose'));
        await tester.tap(find.byKey(const ValueKey('mood-sheet-done')));
        await tester.pumpAndSettle();
        expect(fake.to('/api/v1/db/rated'), hasLength(1));
        expect(strip, findsNothing);
        expect(counted(tester), isFalse);
        await tester.tap(button);
        await tester.pumpAndSettle();
        expect(
            tester
                .widget<SegmentedButton<MoodLevel>>(
                    find.byKey(const ValueKey('mood-level')))
                .selected,
            {MoodLevel.loose});
        await tester.tap(find.text('Relaxed'));
        await tester.tap(find.byKey(const ValueKey('mood-sheet-done')));
        await tester.pumpAndSettle();
      });
      expect(fake.to('/api/v1/db/rated').last.body, {
        'moods': {'energy': 'relaxed', 'threshold': 0.3}
      });
      expect(inStrip('Relaxed · Loose'), findsOneWidget);
    });

    testWidgets('no Filters on Recent where the server has no flag',
        (tester) async {
      final fake = _FakeServer();
      await fake.run(
          () => ApiManager().getRecentlyAdded(useThisServer: _server));
      await pumpBrowser(tester);
      expect(button, findsNothing);
      expect(find.byTooltip('Play'), findsOneWidget);
    });

    testWidgets('no Filters where the server cannot filter', (tester) async {
      final fake = _FakeServer(echo: false);
      await fake.run(() async {
        await ApiManager().getAlbums(useThisServer: _server);
      });
      await pumpBrowser(tester);
      expect(button, findsNothing);
      expect(find.byIcon(Icons.search), findsOneWidget);
    });
  });
}
