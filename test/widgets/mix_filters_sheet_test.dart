// An Instant mix page's Filters (widgets/mix_filters_sheet.dart): Auto DJ's
// rows in Auto DJ's order with no headings, Beat matching and Harmonic
// mixing only for a song seed with a tempo and a key, Smart filters greyed
// where the server has no mood scores, the folders when it has two or more.
// The sheet edits a draft: each row's own sheet (in value mode) hands its
// choice back to it, Done hands it back, Clear empties it, and closing any
// other way hands back nothing. Nothing reaches Auto DJ's settings.

import 'dart:convert';

import 'package:cupertino_ui/cupertino_ui.dart' show CupertinoTimerPicker;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/l10n/localizations_delegates.dart';
import 'package:mstream_music/objects/display_item.dart';
import 'package:mstream_music/objects/genre_source.dart';
import 'package:mstream_music/objects/instant_mix.dart';
import 'package:mstream_music/objects/metadata.dart';
import 'package:mstream_music/objects/mix_filters.dart';
import 'package:mstream_music/objects/mood_filter.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/screens/auto_dj.dart' show AutoDjValueRow;
import 'package:mstream_music/screens/auto_dj_sheets.dart';
import 'package:mstream_music/singletons/api.dart';
import 'package:mstream_music/singletons/auto_dj_manager.dart';
import 'package:mstream_music/widgets/mix_filters_sheet.dart';

final _done = find.byKey(const ValueKey('auto-dj-sheet-done'));
final _clear = find.byKey(const ValueKey('auto-dj-sheet-clear'));

Finder _row(String name) => find.byKey(ValueKey('mix-filter-$name'));

void main() {
  late Server server;
  late List<String> genreCalls;

  setUp(() {
    server = Server('https://music.example', 'u', 'p', 'JWT', 'home')
      ..moodFiltersAvailable = true
      ..autoDJPaths = {'music': true, 'podcasts': true};
    genreCalls = [];
    // GenresSheet lists the server's genres on ApiManager's pooled client.
    http.runWithClient(
        () => ApiManager().resetDirectClient(),
        () => MockClient((req) async {
              if (req.url.path != '/api/v1/db/genres') {
                return http.Response('not found', 404);
              }
              genreCalls.add(req.url.host);
              return http.Response(
                  jsonEncode({
                    'genres': [
                      for (final g in ['Jazz', 'Soul', 'Rock'])
                        {'name': g, 'track_count': 1},
                    ],
                  }),
                  200,
                  headers: {'content-type': 'application/json'});
            }));
  });
  tearDown(() => ApiManager().resetDirectClient());

  /// Dolo: 87 BPM, Bb minor.
  MixSeed dolo() => MixSeed.song(DisplayItem(server,
      '/demo/Boukmanflow/Dolo.mp3', 'file', '/demo/Boukmanflow/Dolo.mp3',
      null, null)
    ..metadata = MusicMetadata('Boukmanflow', 'Stim Pack Volume one', 'Dolo',
        null, null, null, 'h1', null, null,
        bpm: 87, musicalKey: 'Bb minor'));

  /// A page whose button opens the Filters on [seed] from [initial]; each
  /// answer lands in the list returned (null: closed without Done).
  Future<List<MixFilters?>> open(WidgetTester tester,
      {MixSeed? seed, MixFilters initial = MixFilters.empty}) async {
    tester.view.physicalSize = const Size(400 * 3, 1000 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final answers = <MixFilters?>[];
    final s = seed ?? dolo();
    // A fresh app each time: a sheet left open by the last call goes.
    await tester.pumpWidget(MaterialApp(
      key: UniqueKey(),
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: appSupportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => answers.add(
                await showAutoDjSheet<MixFilters>(context,
                    (_) => MixFiltersSheet(seed: s, initial: initial))),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return answers;
  }

  /// A row's value, as drawn at its right.
  String? value(WidgetTester tester, String name) => tester
      .widgetList<Text>(
          find.descendant(of: _row(name), matching: find.byType(Text)))
      .last
      .data;

  bool rowOn(WidgetTester tester, String name) => tester
      .widget<InkWell>(
          find.descendant(of: _row(name), matching: find.byType(InkWell)))
      .onTap != null;

  Switch harmonic(WidgetTester tester) => tester.widget<Switch>(
      find.byKey(const ValueKey('mix-filter-harmonic-switch')));

  Future<void> tapRow(WidgetTester tester, String name) async {
    await tester.tap(_row(name));
    await tester.pumpAndSettle();
  }

  /// The Done of the sheet on top.
  Future<void> done(WidgetTester tester) async {
    await tester.tap(_done.last);
    await tester.pumpAndSettle();
  }

  group('rows, order and gating', () {
    testWidgets("a song with a tempo and a key: Auto DJ's rows in its order, "
        'no headings, then the folders', (tester) async {
      await open(tester);
      expect(find.text('Filters'), findsOneWidget);
      const order = [
        'mood',
        'genres',
        'rating',
        'length',
        'tempo',
        'harmonic',
        'skip-words',
      ];
      final ys = [for (final r in order) tester.getTopLeft(_row(r)).dy];
      expect([...ys]..sort(), ys, reason: order.join(' · '));
      expect({
        for (final r in order)
          if (r != 'harmonic') r: value(tester, r),
      }, {
        'mood': 'Any',
        'genres': 'Any',
        'rating': 'Any',
        'length': 'Any',
        'tempo': 'Off',
        'skip-words': 'Off',
      });
      for (final title in [
        'Smart filters',
        'Genres',
        'Rating',
        'Length',
        'Beat matching',
        'Harmonic mixing',
        'Skip words',
      ]) {
        expect(find.text(title), findsOneWidget, reason: title);
      }
      expect(harmonic(tester).value, isFalse);
      expect(find.text('Next song in a key that mixes well'), findsNothing,
          reason: "the switch without Auto DJ's line");
      expect(find.text('Must match'), findsNothing);
      expect(find.text('Prefer'), findsNothing);

      // The server's two folders, under its name, after the rows.
      final folder =
          find.byKey(const ValueKey('auto-dj-folder-home-podcasts'));
      expect(find.text('music.example'), findsOneWidget);
      expect(folder, findsOneWidget);
      expect(tester.getTopLeft(folder).dy,
          greaterThan(tester.getTopLeft(_row('skip-words')).dy));
      expect(find.byType(AutoDjValueRow), findsNWidgets(6));
    });

    testWidgets('an album, an artist, a playlist: no Beat matching, no '
        'Harmonic mixing', (tester) async {
      for (final seed in [
        MixSeed.album(DisplayItem(server, 'Stim Pack Volume one', 'album',
            'Stim Pack Volume one', null, null)),
        MixSeed.artist(server, 'ALM'),
        MixSeed.playlist(server, 'Road trip'),
      ]) {
        await open(tester, seed: seed);
        expect(_row('tempo'), findsNothing, reason: seed.title);
        expect(_row('harmonic'), findsNothing, reason: seed.title);
        expect(_row('skip-words'), findsOneWidget);
      }
    });

    testWidgets('a song with no tempo or no key: the row it lacks is gone',
        (tester) async {
      MixSeed song({int? bpm, String? key}) => MixSeed.song(
          DisplayItem(server, '/a.mp3', 'file', '/a.mp3', null, null)
            ..metadata = MusicMetadata(
                null, null, 'A', null, null, null, 'h', null, null,
                bpm: bpm, musicalKey: key));
      await open(tester, seed: song(bpm: 120));
      expect(_row('tempo'), findsOneWidget);
      expect(_row('harmonic'), findsNothing);
      await open(tester, seed: song(key: 'Am'));
      expect(_row('tempo'), findsNothing);
      expect(_row('harmonic'), findsOneWidget);
      await open(tester, seed: song(key: 'not a key'));
      expect(_row('harmonic'), findsNothing,
          reason: 'a key the wheel cannot place');
    });

    testWidgets('Smart filters greyed, with the reason, where the server has '
        'no mood scores', (tester) async {
      server.moodFiltersAvailable = false;
      await open(tester);
      expect(value(tester, 'mood'), 'No mood data');
      expect(rowOn(tester, 'mood'), isFalse);
    });

    testWidgets('one folder: no folder card', (tester) async {
      server.autoDJPaths = {'music': true};
      await open(tester);
      expect(find.text('music.example'), findsNothing);
      expect(find.byKey(const ValueKey('auto-dj-folder-home-music')),
          findsNothing);
    });
  });

  group('the draft', () {
    testWidgets('closing hands nothing back; Done hands the draft back',
        (tester) async {
      final answers = await open(tester);
      await tester
          .tap(find.byKey(const ValueKey('mix-filter-harmonic-switch')));
      await tester.pumpAndSettle();
      expect(harmonic(tester).value, isTrue);
      await tester.tap(find.byTooltip('Close'));
      await tester.pumpAndSettle();
      expect(answers, [null], reason: 'closing changes nothing');

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(harmonic(tester).value, isFalse, reason: 'the draft went');
      await tester.tap(_row('harmonic'));
      await tester.pumpAndSettle();
      await done(tester);
      expect(answers.last, const MixFilters(harmonic: true));
    });

    testWidgets('it starts from the page, and Done unchanged hands the page '
        'back', (tester) async {
      const page = MixFilters(
          mood: MoodFilter(energy: 'relaxed'),
          harmonic: true,
          skipWords: ['live']);
      final answers = await open(tester, initial: page);
      expect(value(tester, 'mood'), 'Relaxed');
      expect(value(tester, 'skip-words'), 'live');
      expect(harmonic(tester).value, isTrue);
      await done(tester);
      expect(answers.single, page);
    });

    testWidgets('Clear empties the draft; off with nothing set',
        (tester) async {
      final answers = await open(tester,
          initial: const MixFilters(
              minRating: 6, tempo: true, foldersOff: ['podcasts']));
      expect(value(tester, 'rating'), '3★+');
      expect(value(tester, 'tempo'), '± 8 BPM');
      await tester.tap(_clear);
      await tester.pumpAndSettle();
      expect(value(tester, 'rating'), 'Any');
      expect(value(tester, 'tempo'), 'Off');
      expect(
          tester
              .widget<Switch>(find.descendant(
                  of: find
                      .byKey(const ValueKey('auto-dj-folder-home-podcasts')),
                  matching: find.byType(Switch)))
              .value,
          isTrue);
      expect(
          tester
              .widget<InkWell>(find.descendant(
                  of: _clear, matching: find.byType(InkWell)))
              .onTap,
          isNull,
          reason: 'nothing left to clear');
      expect(answers, isEmpty, reason: 'Clear is not Done');
      await done(tester);
      expect(answers.single, MixFilters.empty);
    });

    testWidgets('the last folder on cannot go', (tester) async {
      final answers = await open(tester);
      final podcasts =
          find.byKey(const ValueKey('auto-dj-folder-home-podcasts'));
      final music = find.byKey(const ValueKey('auto-dj-folder-home-music'));
      await tester.tap(
          find.descendant(of: podcasts, matching: find.byType(Switch)));
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<Switch>(
                  find.descendant(of: music, matching: find.byType(Switch)))
              .onChanged,
          isNull);
      await done(tester);
      expect(answers.single, const MixFilters(foldersOff: ['podcasts']));
    });
  });

  testWidgets("each row's own sheet hands its choice back to the draft, and "
      "nothing reaches Auto DJ's settings", (tester) async {
    final mgr = AutoDJManager();
    mgr
      ..bpmContinuityEnabled = false
      ..bpmTolerance = 12
      ..durationFilterEnabled = false
      ..keywordFilterEnabled = false
      ..keywordFilterWords = []
      ..moodFilterEnabled = false
      ..moodFilter = MoodFilter.empty;
    server
      ..autoDJminRating = null
      ..autoDJGenreEnabled = false
      ..autoDJGenres = [];
    final answers = await open(tester);

    // Smart filters: the mood sheet, named as Auto DJ's row.
    await tapRow(tester, 'mood');
    expect(find.text('Smart filters'), findsNWidgets(2));
    await tester.tap(find.text('Relaxed'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('mood-sheet-done')));
    await tester.pumpAndSettle();
    expect(value(tester, 'mood'), 'Relaxed');

    // Genres: this server's list.
    await tapRow(tester, 'genres');
    expect(genreCalls, ['music.example']);
    await tester.tap(find.byKey(const ValueKey('auto-dj-genre-Jazz')));
    await tester.pumpAndSettle();
    await done(tester);
    expect(value(tester, 'genres'), 'Jazz');

    // Rating.
    await tapRow(tester, 'rating');
    await tester.tap(find
        .descendant(
            of: find.byKey(const ValueKey('auto-dj-rating-stars')),
            matching: find.byType(GestureDetector))
        .at(3));
    await tester.pumpAndSettle();
    await done(tester);
    expect(value(tester, 'rating'), '4★+');

    // Length: the shortest wheel to two minutes.
    await tapRow(tester, 'length');
    await tester.tap(find.byKey(const ValueKey('auto-dj-length-shortest')));
    await tester.pumpAndSettle();
    tester
        .widget<CupertinoTimerPicker>(find.byType(CupertinoTimerPicker))
        .onTimerDurationChanged(const Duration(minutes: 2));
    await tester.pumpAndSettle();
    await done(tester);
    expect(value(tester, 'length'), '2:00+');

    // Beat matching.
    await tapRow(tester, 'tempo');
    await tester.tap(find.byKey(const ValueKey('auto-dj-tempo-switch')));
    await tester.pumpAndSettle();
    await done(tester);
    expect(value(tester, 'tempo'), '± 8 BPM',
        reason: "the mix's own tolerance, not Auto DJ's 12");

    // Skip words: a word typed but not added counts.
    await tapRow(tester, 'skip-words');
    await tester.enterText(
        find.byKey(const ValueKey('auto-dj-skip-words-field')), 'live');
    await tester.pumpAndSettle();
    await done(tester);
    expect(value(tester, 'skip-words'), 'live');

    await done(tester);
    expect(
        answers.single,
        const MixFilters(
          mood: MoodFilter(energy: 'relaxed'),
          genres: GenreChoice(genres: ['Jazz']),
          minRating: 8,
          minDuration: 120,
          tempo: true,
          skipWords: ['live'],
        ));

    expect(mgr.bpmContinuityEnabled, isFalse);
    expect(mgr.bpmTolerance, 12);
    expect(mgr.durationFilterEnabled, isFalse);
    expect(mgr.keywordFilterWords, isEmpty);
    expect(mgr.moodFilter, MoodFilter.empty);
    expect(server.autoDJminRating, isNull);
    expect(server.autoDJGenres, isEmpty);
    expect(server.autoDJGenreEnabled, isFalse);
    expect(server.autoDJPaths, {'music': true, 'podcasts': true});
  });
}
