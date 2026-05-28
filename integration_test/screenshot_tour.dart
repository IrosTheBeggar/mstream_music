// Screenshot tour — drives the app through key screens with mock data,
// dumping a PNG of each into the app's documents directory. Pull them
// with:
//   adb exec-out run-as mstream.music cat \
//     files/screenshots/<name>.png > <name>.png
//
// Not really a test — it always passes — but it lives in
// integration_test/ so it inherits the platform-plugin setup.

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

import 'helpers/test_helpers.dart';

late Directory _shotDir;

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.pumpAndSettle(const Duration(milliseconds: 600));
  // Find the topmost RepaintBoundary (the app's root view). Render it
  // to an image and write the PNG bytes to disk.
  final renderObject = tester.binding.rootElement!.renderObject!;
  RenderRepaintBoundary? boundary;
  void visit(RenderObject o) {
    if (boundary != null) return;
    if (o is RenderRepaintBoundary) {
      boundary = o;
      return;
    }
    o.visitChildren(visit);
  }

  visit(renderObject);
  if (boundary == null) {
    print('### no RenderRepaintBoundary found for $name');
    return;
  }

  final image = await boundary!.toImage(pixelRatio: 1.0);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  if (byteData == null) {
    print('### byteData null for $name');
    return;
  }
  final bytes = byteData.buffer.asUint8List();
  final f = File('${_shotDir.path}/$name.png');
  await f.writeAsBytes(bytes);
  print('### wrote ${f.path} (${bytes.length} bytes)');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  MockServer? mockServer;

  setUpAll(() async {
    await MediaManager().start();
    final docs = await getApplicationDocumentsDirectory();
    _shotDir = Directory('${docs.path}/screenshots');
    if (await _shotDir.exists()) await _shotDir.delete(recursive: true);
    await _shotDir.create(recursive: true);
  });

  setUp(() async {
    await resetAppState();
    PlaylistManager().playlists.clear();
    final docs = await getApplicationDocumentsDirectory();
    final pf = File('${docs.path}/playlists.json');
    if (await pf.exists()) await pf.delete();
  });

  tearDown(() async {
    await mockServer?.close();
    mockServer = null;
  });

  testWidgets('screenshot tour', (tester) async {
    final wavBytes = buildSilentWav(seconds: 6);

    mockServer = await MockServer.start(
      {
        '/api/v1/db/albums': (_) => {
              'albums': [
                {'name': 'Wish You Were Here', 'year': 1975, 'album_art_file': null},
                {'name': 'The Dark Side of the Moon', 'year': 1973, 'album_art_file': null},
                {'name': 'Animals', 'year': 1977, 'album_art_file': null},
                {'name': 'The Wall', 'year': 1979, 'album_art_file': null},
                {'name': 'IV', 'year': 1971, 'album_art_file': null},
                {'name': 'Houses of the Holy', 'year': 1973, 'album_art_file': null},
              ],
            },
        '/api/v1/db/album-songs': (_) => [
              for (var t in [
                ['Shine On You Crazy Diamond (Pts. 1–5)', 1],
                ['Welcome to the Machine', 2],
                ['Have a Cigar', 3],
                ['Wish You Were Here', 4],
                ['Shine On You Crazy Diamond (Pts. 6–9)', 5],
              ])
                {
                  'filepath': 'pink-floyd/wywh/${t[1]}.mp3',
                  'metadata': {
                    'artist': 'Pink Floyd',
                    'album': 'Wish You Were Here',
                    'title': t[0],
                    'track': t[1],
                    'disc': 1,
                    'year': 1975,
                    'hash': 'h${t[1]}',
                    'rating': null,
                    'album-art': null,
                  },
                },
            ],
        '/api/v1/db/artists': (_) => {
              'artists': ['Pink Floyd', 'Led Zeppelin', 'King Crimson', 'Yes'],
            },
        '/api/v1/db/recent/added': (_) => [
              for (var t in [
                ['Shine On You Crazy Diamond', 'Pink Floyd'],
                ['Stairway to Heaven', 'Led Zeppelin'],
                ['21st Century Schizoid Man', 'King Crimson'],
              ])
                {
                  'filepath': 'p/p/p.mp3',
                  'metadata': {
                    'artist': t[1],
                    'album': 'X',
                    'title': t[0],
                    'track': 1,
                    'disc': 1,
                    'year': 1975,
                    'hash': 'h',
                    'rating': null,
                    'album-art': null,
                  },
                },
            ],
      },
      defaultHandler: (req) {
        if (req.uri.path.startsWith('/media/')) return wavBytes;
        return null;
      },
    );

    await seedServer(mockServer!.url);

    // Pre-create a playlist so the playlist screen has content too.
    await PlaylistManager().load();
    await PlaylistManager().create('Road Trip');
    await PlaylistManager().create('Late Night');

    await tester.pumpWidget(MaterialApp(home: MStreamApp()));
    await tester.pumpAndSettle(const Duration(seconds: 5));

    await _shot(tester, '01_browser_root');

    // Albums list (will render as grid by default).
    await tester.tap(find.text('Albums'));
    await _shot(tester, '02_album_grid');

    // Drill into the first album.
    await tester.tap(find.text('Wish You Were Here'));
    await _shot(tester, '03_album_songs');

    // Tap a song to enqueue it, then tap play.
    await tester.tap(find.text('Have a Cigar'));
    await tester.pumpAndSettle(const Duration(seconds: 2));
    final play = find.descendant(
      of: find.byType(BottomAppBar),
      matching: find.byIcon(Icons.play_arrow),
    );
    if (play.evaluate().isNotEmpty) {
      await tester.tap(play);
      await _pumpFor(tester, const Duration(seconds: 3));
    }
    await _shot(tester, '04_now_playing_browser');

    // Switch to Queue tab.
    await tester.tap(find.text('Queue'));
    await _shot(tester, '05_queue');

    // Open the drawer.
    final scaffoldState =
        tester.firstState<ScaffoldState>(find.byType(Scaffold));
    scaffoldState.openDrawer();
    await _shot(tester, '06_drawer');

    // Tap Playlists.
    await tester.tap(find.text('Playlists'));
    await _shot(tester, '07_playlists');

    // Hold the test alive long enough for an external `adb run-as`
    // pull. The APK is uninstalled the moment this test returns.
    print('### tour finished — pausing 90s so screenshots can be pulled');
    await Future.delayed(const Duration(seconds: 90));
  });
}

Future<void> _pumpFor(WidgetTester tester, Duration total) async {
  const step = Duration(milliseconds: 100);
  final ticks = total.inMilliseconds ~/ step.inMilliseconds;
  for (int i = 0; i < ticks; i++) {
    await tester.pump(step);
  }
}
