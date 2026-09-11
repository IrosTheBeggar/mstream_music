// Widget tests for the Listening page (the 2026-09-07 design): the header
// rows render, a phone with nothing recorded gets the empty state, the
// scope sheet opens, and a server in the list gets a chip of its own.
//
// The controller reads the PlayHistory / PlaySync singletons, which own
// files: PlayHistory is pointed at a temp directory and read once in setUp
// (in the real zone, outside the widget test's fake-async clock), so the
// page's first load completes without touching disk mid-pump.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/l10n/app_localizations.dart';
import 'package:mstream_music/objects/play_event.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/screens/listening/listening_screen.dart';
import 'package:mstream_music/screens/listening/listening_widgets.dart';
import 'package:mstream_music/singletons/play_history.dart';
import 'package:mstream_music/singletons/play_sync.dart';
import 'package:mstream_music/singletons/server_list.dart';

/// One closed play session on server `home`, counted by the usual rule.
PlayEvent ev(String id, DateTime at,
    {String path = '/music/a.mp3',
    String? title,
    String? artist,
    String? album,
    int playedMs = 200000,
    int durationMs = 240000,
    PlayOutcome outcome = PlayOutcome.completed}) {
  return PlayEvent(
    id: id,
    startedAt: at.toUtc(),
    endedAt: at.toUtc().add(Duration(milliseconds: playedMs)),
    track: TrackFacts(
        server: 'home',
        path: path,
        title: title ?? path.split('/').last,
        artist: artist,
        album: album,
        durationMs: durationMs),
    playedMs: playedMs,
    outcome: outcome,
    source: PlaySource.manual,
    counted: countsAsPlay(playedMs: playedMs, durationMs: durationMs),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  setUp(() async {
    dir = await Directory.systemTemp.createTemp('listening-screen-');
    PlayHistory.storageDirectory = () async => dir;
    PlayHistory().resetForTest();
    PlaySync().resetForTest();
    ServerManager().serverList.clear();
    // Warm the store here so the page's load is pure microtasks.
    await PlayHistory().events();
  });
  tearDown(() async {
    PlayHistory().resetForTest();
    PlaySync().resetForTest();
    ServerManager().serverList.clear();
    await dir.delete(recursive: true);
  });

  Future<void> pumpScreen(WidgetTester tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const ListeningScreen(),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('renders the title and the This phone scope chip',
      (tester) async {
    await pumpScreen(tester);
    expect(find.text('Listening'), findsOneWidget);
    expect(find.text('This phone'), findsOneWidget);
    expect(find.text('This month'), findsOneWidget, reason: 'default period');
  });

  testWidgets('a phone with no plays gets the empty state', (tester) async {
    await pumpScreen(tester);
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('No plays yet'), findsOneWidget);
    expect(find.textContaining('Plays land here'), findsOneWidget);
    // Nothing recorded anywhere: the onboarding copy, not the period one.
    expect(find.text('Nothing in this period.'), findsNothing);
    expect(find.text('History settings'), findsWidgets);
  });

  testWidgets('the info button opens the scope sheet', (tester) async {
    await pumpScreen(tester);
    await tester.tap(find.byTooltip('What to show'));
    await tester.pumpAndSettle();
    expect(find.text('What to show'), findsOneWidget);
    expect(find.text('This phone'), findsNWidgets(2),
        reason: 'the chip and the sheet row');
  });

  testWidgets('a server in the list gets a chip; picking a legacy one falls '
      'back to this phone\'s plays on it', (tester) async {
    ServerManager()
        .serverList
        .add(Server('http://music.example', null, null, null, 'music-example'));
    await pumpScreen(tester);
    expect(find.text('http://music.example'), findsOneWidget);

    await tester.tap(find.text('http://music.example'));
    await tester.pumpAndSettle();
    expect(find.textContaining('has no listening stats yet'), findsOneWidget);
    expect(find.text('No plays yet'), findsOneWidget);
  });

  testWidgets(
      'with plays recorded, the tiles, hours, Top and Recent cards render '
      'at the design width', (tester) async {
    // The design's 390 px width, where a row would overflow; tall enough
    // that the lazy ListView builds every card, so the finders below see
    // the Recent rows too.
    tester.view.physicalSize = const Size(390 * 3, 2600 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // record() writes the ring and stats files: real IO, so run it outside
    // the fake-async clock. Two plays of one track within the fold window
    // and a skipped-but-counted second track, minutes ago.
    final now = DateTime.now();
    await tester.runAsync(() async {
      final h = PlayHistory();
      await h.record(ev('1', now.subtract(const Duration(minutes: 40)),
          title: 'Blue Train', artist: 'Coltrane', album: 'Blue Train'));
      await h.record(ev('2', now.subtract(const Duration(minutes: 25)),
          title: 'Blue Train', artist: 'Coltrane', album: 'Blue Train'));
      await h.record(ev('3', now.subtract(const Duration(minutes: 5)),
          path: '/music/b.mp3',
          title: 'Naima',
          artist: 'Coltrane',
          album: 'Giant Steps',
          outcome: PlayOutcome.skipped));
    });

    await pumpScreen(tester);
    expect(tester.takeException(), isNull, reason: 'no overflow at 390 px');
    expect(find.text('No plays yet'), findsNothing);

    // All time, so a run minutes past a month boundary still sees them.
    await tester.ensureVisible(find.text('All time'));
    await tester.tap(find.text('All time'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Tiles and the hour card.
    expect(find.text('PLAYS'), findsOneWidget);
    expect(find.text('LISTENING TIME'), findsOneWidget);
    expect(find.text('counted plays'), findsOneWidget);
    expect(find.text('WHEN YOU LISTEN'), findsOneWidget);
    expect(find.textContaining('Most around'), findsOneWidget);

    // Top tracks: two rows; Recent: the repeat folded into one row.
    expect(find.text('TOP'), findsOneWidget);
    expect(find.text('2 plays'), findsOneWidget);
    expect(find.text('Blue Train'), findsNWidgets(2),
        reason: 'one Top row, one folded Recent row');
    expect(find.text('×2'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.textContaining('Skipped at 3:20'), findsOneWidget);
    expect(find.text('Today'), findsWidgets);

    // Artists: one artist across both tracks.
    await tester.tap(find.text('Artists'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('2 tracks'), findsOneWidget);

    // By time: the trailing value becomes a duration.
    await tester.tap(find.text('Time'));
    await tester.pumpAndSettle();
    expect(find.text('10 min'), findsNWidgets(2),
        reason: '3 × 200 s of listening: the time tile and the artist row');
  });

  group('formatters', () {
    test('durations', () {
      expect(listeningDuration(0), '0 min');
      expect(listeningDuration(44 * 60000), '44 min');
      expect(listeningDuration((4 * 60 + 53) * 60000), '4h 53m');
      expect(listeningDuration(2 * 60 * 60000), '2h');
    });

    test('positions and hours', () {
      expect(listeningClock(80000), '1:20');
      expect(listeningClock(5000), '0:05');
      expect(listeningHour(20), '20:00');
      expect(listeningHour(7), '07:00');
    });
  });
}
