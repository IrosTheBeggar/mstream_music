// Albums and Artists against a fake mStream (mStream #1092's mood filters):
// what each list asks for — a plain GET without a filter, a POST carrying
// `moods` with one — the frame it leaves on BrowserManager's stack when the
// answer echoes the filter (the toolbar's Filters reads it), a server that
// cannot filter, re-listing in place, an overtaken answer — then, through
// the real toolbar and Browser screen, the Filters button and its count,
// the sheet (only Done applies) and the grey strip with its Clear.
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
