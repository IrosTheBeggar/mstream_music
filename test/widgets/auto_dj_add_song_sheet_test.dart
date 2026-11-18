// The Seeds page's Add song sheet (widgets/auto_dj_add_song_sheet.dart):
// the search field on top; under it, while fewer than two characters are
// typed, Up next, Skipped (Less like's: the song playing now, then the songs
// skipped lately) and Recently played, each hidden when empty and none
// repeating a song an earlier one shows; from two characters the home
// server's hits, asked once typing pauses (350 ms), with "No matches found."
// only for the term in the field and an old answer never shown over a newer
// one. A tap picks the song: an Up next row, the playing row or a hit as it
// is, a song from the play history (Recently played, a past skip) only once
// its server says it still has it (a snackbar when it says no). A song the
// list already has shows, dimmed, and can't be picked; closing picks
// nothing. When the page offers it, "Pick a song from the library" sits under
// the header: a tap closes the sheet, picks nothing, and hands the pick to
// the page, which closing the sheet or a song's tap never does.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/l10n/localizations_delegates.dart';
import 'package:mstream_music/objects/display_item.dart';
import 'package:mstream_music/objects/metadata.dart';
import 'package:mstream_music/objects/play_event.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/util/auto_dj_seeds.dart';
import 'package:mstream_music/widgets/auto_dj_add_song_sheet.dart';

final _home = Server('https://home.example.com', 'u', 'p', 'JWT', 'home');

TrackFacts _song(String path, {String server = 'home', String? title}) =>
    TrackFacts(
        server: server,
        path: path,
        title: title ?? path.split('/').last,
        artist: 'Artist');

/// A title hit as the server's search answers it.
DisplayItem _hit(String path, String title) =>
    DisplayItem(_home, 'Artist - $title', 'file', path, null, null)
      ..metadata = MusicMetadata.fromServerMap({'title': title, 'artist': 'A'})
      ..partialMetadata = true;

final _field = find.byKey(const ValueKey('auto-dj-add-song-search'));
final _none = find.byKey(const ValueKey('auto-dj-add-song-none'));
final _library = find.byKey(const ValueKey('auto-dj-add-song-library'));
Finder _upNext(int i) => find.byKey(ValueKey('auto-dj-add-song-upnext-$i'));
Finder _skipped(int i) => find.byKey(ValueKey('auto-dj-add-song-skipped-$i'));
Finder _recent(int i) => find.byKey(ValueKey('auto-dj-add-song-recent-$i'));
Finder _hitRow(int i) => find.byKey(ValueKey('auto-dj-add-song-hit-$i'));

/// The titles of a section's rows, top to bottom, while [row] finds them.
List<String> _titles(WidgetTester tester, Finder Function(int i) row) => [
      for (var i = 0; row(i).evaluate().isNotEmpty; i++)
        tester
            .widgetList<Text>(
                find.descendant(of: row(i), matching: find.byType(Text)))
            .first
            .data!,
    ];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // What each opening of the sheet answered, in order.
  late List<TrackFacts?> answers;
  // Every search the sheet asked for, as "<server> <term>".
  late List<String> searched;
  // The songs checked with their server.
  late List<TrackFacts> checked;

  setUp(() {
    answers = [];
    searched = [];
    checked = [];
  });

  /// A page whose button opens the sheet for [taken], offering [upNext],
  /// [playing] and [skipped] (Less like's Skipped) and [recent]; [search]
  /// answers the field (nothing, by default), and [exists] the server's check
  /// of a pick from the play history (yes, by default). [onLibrary] is the
  /// page's library pick (none, by default: no row for it).
  Future<void> open(WidgetTester tester,
      {List<TrackFacts> upNext = const [],
      TrackFacts? playing,
      List<TrackFacts> skipped = const [],
      List<TrackFacts> recent = const [],
      Set<String> taken = const {},
      Future<List<DisplayItem>> Function(String term)? search,
      Future<bool?> Function(TrackFacts song)? exists,
      VoidCallback? onLibrary}) async {
    // A tall phone, so every section's rows are on screen at once.
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: appSupportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async => answers.add(await showAutoDjAddSongSheet(
              context,
              searchServer: _home,
              upNext: upNext,
              playing: playing,
              skipped: skipped,
              recent: recent,
              taken: taken,
              search: (server, term) async {
                searched.add('${server.localname} $term');
                return search == null ? const [] : search(term);
              },
              exists: (song) async {
                checked.add(song);
                return exists == null ? true : exists(song);
              },
              onPickFromLibrary: onLibrary,
            )),
            child: const Text('open'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('Up next and Recently played under the field, each hidden '
      'when empty', (tester) async {
    await open(tester,
        upNext: [_song('a.mp3', title: 'Alpha'), _song('/b.mp3')],
        recent: [_song('/c.mp3', title: 'Gamma')]);
    expect(find.text('Add song'), findsOneWidget);
    expect(_field, findsOneWidget);
    expect(find.text('Search'), findsOneWidget, reason: 'the placeholder');
    expect(find.text('Up next'), findsOneWidget);
    expect(find.text('Recently played'), findsOneWidget);
    expect(find.text('Skipped'), findsNothing,
        reason: "More like's sheet has no Skipped");
    expect(find.descendant(of: _upNext(0), matching: find.text('Alpha')),
        findsOneWidget);
    expect(find.descendant(of: _upNext(1), matching: find.text('b.mp3')),
        findsOneWidget);
    expect(find.descendant(of: _recent(0), matching: find.text('Gamma')),
        findsOneWidget);
    expect(find.descendant(of: _upNext(0), matching: find.text('Artist')),
        findsOneWidget);
    expect(find.descendant(of: _upNext(0), matching: find.byIcon(Icons.add)),
        findsOneWidget);
    // Up next sits above Recently played.
    expect(tester.getTopLeft(find.text('Up next')).dy,
        lessThan(tester.getTopLeft(find.text('Recently played')).dy));

    await open(tester, recent: [_song('/c.mp3')]);
    expect(find.text('Up next'), findsNothing);
    expect(find.text('Recently played'), findsOneWidget);

    await open(tester, upNext: [_song('/a.mp3')]);
    expect(find.text('Up next'), findsOneWidget);
    expect(find.text('Recently played'), findsNothing);

    await open(tester);
    expect(find.text('Up next'), findsNothing);
    expect(find.text('Recently played'), findsNothing);
    expect(_field, findsOneWidget);
  });

  testWidgets('a song both coming up and played lately shows once, under Up '
      'next', (tester) async {
    await open(tester,
        upNext: [_song('/a.mp3', title: 'Alpha')],
        recent: [_song('a.mp3', title: 'Alpha'), _song('/c.mp3')]);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.descendant(of: _recent(0), matching: find.text('c.mp3')),
        findsOneWidget);
    expect(_recent(1), findsNothing);
  });

  testWidgets("Less like's Skipped sits between Up next and Recently played: "
      'the song playing now, then the songs skipped lately', (tester) async {
    await open(tester,
        upNext: [_song('/next.mp3', title: 'Next')],
        playing: _song('/now.mp3', title: 'Now'),
        skipped: [
          _song('/s1.mp3', title: 'Skip one'),
          _song('/s2.mp3', title: 'Skip two'),
        ],
        recent: [_song('/r.mp3', title: 'Played')]);
    expect(find.text('Skipped'), findsOneWidget);
    expect(_titles(tester, _upNext), ['Next']);
    expect(_titles(tester, _skipped), ['Now', 'Skip one', 'Skip two']);
    expect(_titles(tester, _recent), ['Played']);
    double top(String text) => tester.getTopLeft(find.text(text)).dy;
    expect(top('Up next'), lessThan(top('Next')));
    expect(top('Next'), lessThan(top('Skipped')));
    expect(top('Skipped'), lessThan(top('Now')));
    expect(top('Skip two'), lessThan(top('Recently played')));
    expect(top('Recently played'), lessThan(top('Played')));
    expect(find.descendant(of: _skipped(0), matching: find.byIcon(Icons.add)),
        findsOneWidget);

    // The playing row alone, or the skips alone, still make the section.
    await open(tester, playing: _song('/now.mp3', title: 'Now'));
    expect(find.text('Skipped'), findsOneWidget);
    expect(_titles(tester, _skipped), ['Now']);
    await open(tester, skipped: [_song('/s1.mp3', title: 'Skip one')]);
    expect(_titles(tester, _skipped), ['Skip one']);

    // Neither: no header.
    await open(tester, upNext: [_song('/next.mp3')], recent: [_song('/r.mp3')]);
    expect(find.text('Skipped'), findsNothing);
    expect(_skipped(0), findsNothing);
  });

  testWidgets('a song shows once, in the first section that has it',
      (tester) async {
    await open(tester,
        upNext: [_song('/a.mp3', title: 'Alpha')],
        // Playing now and coming up again later.
        playing: _song('a.mp3', title: 'Alpha'),
        skipped: [
          // Coming up, and skipped before: Up next has it.
          _song('/a.mp3', title: 'Alpha'),
          // Skipped, and played to the end another time.
          _song('/b.mp3', title: 'Beta'),
          _song('/c.mp3', title: 'Gamma'),
        ],
        recent: [
          _song('b.mp3', title: 'Beta'),
          _song('/a.mp3', title: 'Alpha'),
          _song('/d.mp3', title: 'Delta'),
        ]);
    expect(_titles(tester, _upNext), ['Alpha']);
    expect(_titles(tester, _skipped), ['Beta', 'Gamma']);
    expect(_titles(tester, _recent), ['Delta']);
    expect(find.text('Alpha'), findsOneWidget);
    expect(find.text('Beta'), findsOneWidget);

    // The song playing now that was also skipped lately: one row, the
    // playing one.
    await open(tester, playing: _song('/now.mp3', title: 'Now'), skipped: [
      _song('now.mp3', title: 'Now'),
      _song('/s1.mp3', title: 'Skip one'),
    ]);
    expect(_titles(tester, _skipped), ['Now', 'Skip one']);
    await tester.tap(_skipped(0));
    await tester.pumpAndSettle();
    expect(checked, isEmpty, reason: 'the playing row is not checked');
    expect(answers.single!.path, '/now.mp3');

    // The same path on another server is another song.
    await open(tester,
        upNext: [_song('/a.mp3', title: 'Home A')],
        skipped: [_song('/a.mp3', server: 'office', title: 'Office A')]);
    expect(_titles(tester, _skipped), ['Office A']);
  });

  testWidgets('Skipped: the playing row is picked as it is; a past skip only '
      "once its server says it's there", (tester) async {
    final now = _song('/now.mp3', title: 'Now');
    final old = _song('/gone.mp3', title: 'Gone');
    await open(tester, playing: now, skipped: [old]);
    await tester.tap(_skipped(0));
    await tester.pumpAndSettle();
    expect(answers.last, same(now));
    expect(checked, isEmpty, reason: 'the playing row is in the queue now');

    // Yes, and can't say: picked once checked.
    for (final verdict in [true, null]) {
      checked.clear();
      await open(tester,
          playing: now, skipped: [old], exists: (_) async => verdict);
      await tester.tap(_skipped(1));
      await tester.pumpAndSettle();
      expect(checked, [same(old)]);
      expect(answers.last, same(old), reason: 'the server said $verdict');
      expect(find.text("Couldn't get a song"), findsNothing);
    }

    // No: refused, and the page says so.
    await open(tester, skipped: [old], exists: (_) async => false);
    await tester.tap(_skipped(0));
    await tester.pumpAndSettle();
    expect(answers.last, isNull);
    expect(find.text("Couldn't get a song"), findsOneWidget);
  });

  testWidgets('the field searches the home server from two characters, once '
      'typing pauses', (tester) async {
    await open(tester,
        upNext: [_song('/a.mp3', title: 'Alpha')],
        search: (term) async => [_hit('/Music/sky.mp3', 'SkyWalk')]);

    await tester.enterText(_field, 's');
    await tester.pump(const Duration(milliseconds: 500));
    expect(searched, isEmpty, reason: 'one character asks nothing');
    expect(find.text('Up next'), findsOneWidget);

    await tester.enterText(_field, 'sk');
    await tester.pump(const Duration(milliseconds: 349));
    expect(searched, isEmpty, reason: 'still typing');
    expect(find.text('Up next'), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    expect(searched, ['home sk']);
    await tester.pumpAndSettle();
    expect(find.descendant(of: _hitRow(0), matching: find.text('SkyWalk')),
        findsOneWidget);
    expect(find.text('Alpha'), findsNothing);

    // Typing on asks again once it pauses, the last answer standing until
    // then.
    await tester.enterText(_field, 'sky');
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('SkyWalk'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 300));
    expect(searched, ['home sk', 'home sky']);

    // Back under two characters: the suggestions at once.
    await tester.enterText(_field, 's');
    await tester.pump();
    expect(find.text('Up next'), findsOneWidget);
    expect(find.text('SkyWalk'), findsNothing);

    // The keyboard's search key asks without waiting.
    await tester.enterText(_field, 'ab');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    expect(searched.last, 'home ab');
    await tester.pumpAndSettle();
  });

  testWidgets('"No matches found." only for the term in the field',
      (tester) async {
    final answer = Completer<List<DisplayItem>>();
    await open(tester, search: (term) => answer.future);
    await tester.enterText(_field, 'zz');
    await tester.pump(const Duration(milliseconds: 350));
    expect(searched, ['home zz']);
    expect(_none, findsNothing, reason: 'not answered yet');
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    answer.complete(const []);
    await tester.pump();
    expect(_none, findsOneWidget);
    expect(find.text('No matches found.'), findsOneWidget);

    // A new term not yet answered is waited on, not called empty.
    await tester.enterText(_field, 'zzz');
    await tester.pump();
    expect(_none, findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('an older answer never replaces a newer one', (tester) async {
    final pending = <String, Completer<List<DisplayItem>>>{};
    await open(tester,
        search: (term) => (pending[term] = Completer()).future);
    await tester.enterText(_field, 'ab');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.enterText(_field, 'abc');
    await tester.pump(const Duration(milliseconds: 350));
    expect(searched, ['home ab', 'home abc']);

    pending['abc']!.complete([_hit('/new.mp3', 'Newer')]);
    await tester.pump();
    pending['ab']!.complete([_hit('/old.mp3', 'Older')]);
    await tester.pump();
    expect(find.text('Newer'), findsOneWidget);
    expect(find.text('Older'), findsNothing);

    // Nor does one that lands after the field went back to the
    // suggestions.
    await tester.enterText(_field, 'abcd');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.enterText(_field, '');
    await tester.pump();
    pending['abcd']!.complete([_hit('/late.mp3', 'Late')]);
    await tester.pump();
    expect(find.text('Late'), findsNothing);
  });

  testWidgets('a tap picks the song: Up next and the hits as they are',
      (tester) async {
    final next = _song('/a.mp3', title: 'Alpha');
    await open(tester, upNext: [next]);
    await tester.tap(_upNext(0));
    await tester.pumpAndSettle();
    expect(answers.single, same(next));
    expect(checked, isEmpty, reason: 'a queued song is not checked');
    expect(_field, findsNothing, reason: 'the sheet closed');

    await open(tester,
        search: (term) async => [_hit('/Music/sky.mp3', 'SkyWalk')]);
    await tester.enterText(_field, 'sky');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.tap(_hitRow(0));
    await tester.pumpAndSettle();
    final hit = answers.last!;
    expect(hit.server, 'home');
    expect(hit.path, '/Music/sky.mp3');
    expect(hit.title, 'SkyWalk');
    expect(checked, isEmpty, reason: 'a hit is in the library right now');
  });

  testWidgets("a Recently played pick only once its server says it's there",
      (tester) async {
    final old = _song('/gone.mp3', title: 'Gone');
    // Yes, and can't say: both picked.
    for (final verdict in [true, null]) {
      checked.clear();
      await open(tester, recent: [old], exists: (_) async => verdict);
      await tester.tap(_recent(0));
      await tester.pumpAndSettle();
      expect(checked, [same(old)]);
      expect(answers.last, same(old), reason: 'the server said $verdict');
      expect(find.text("Couldn't get a song"), findsNothing);
    }

    // No: refused, and the page says so.
    await open(tester, recent: [old], exists: (_) async => false);
    await tester.tap(_recent(0));
    await tester.pumpAndSettle();
    expect(answers.last, isNull);
    expect(find.text("Couldn't get a song"), findsOneWidget);
  });

  testWidgets('a song the list has shows dimmed with a check, and a tap '
      'picks nothing', (tester) async {
    await open(tester,
        taken: {seedKey('home', 'Music/sky.mp3')},
        search: (term) async => [
              _hit('/Music/sky.mp3', 'SkyWalk'),
              _hit('/Music/other.mp3', 'Other'),
            ]);
    await tester.enterText(_field, 'sky');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    expect(find.descendant(of: _hitRow(0), matching: find.byIcon(Icons.check)),
        findsOneWidget);
    expect(
        find.descendant(
            of: _hitRow(0),
            matching: find.byWidgetPredicate(
                (w) => w is Opacity && w.opacity == 0.38)),
        findsOneWidget);
    expect(find.descendant(of: _hitRow(1), matching: find.byIcon(Icons.add)),
        findsOneWidget);
    await tester.tap(_hitRow(0));
    await tester.pumpAndSettle();
    expect(answers, isEmpty);
    expect(_field, findsOneWidget, reason: 'still open');
  });

  testWidgets('closing picks nothing', (tester) async {
    await open(tester, upNext: [_song('/a.mp3')]);
    await tester.tap(find.byKey(const ValueKey('auto-dj-add-song-close')));
    await tester.pumpAndSettle();
    expect(answers, [null]);
    expect(checked, isEmpty);
  });

  testWidgets('the field is named for screen readers', (tester) async {
    final semantics = tester.ensureSemantics();
    await open(tester);
    expect(tester.getSemantics(_field),
        isSemantics(label: 'Search songs', isTextField: true));
    semantics.dispose();
  });

  testWidgets('"Pick a song from the library" sits under the header, only '
      'when the page offers it', (tester) async {
    await open(tester, upNext: [_song('/a.mp3')]);
    expect(_library, findsNothing);
    expect(find.text('Pick a song from the library'), findsNothing);

    var asked = 0;
    await open(tester, upNext: [_song('/a.mp3')], onLibrary: () => asked++);
    expect(
        find.descendant(
            of: _library, matching: find.text('Pick a song from the library')),
        findsOneWidget);
    final row = tester.getRect(_library);
    expect(row.top, greaterThanOrEqualTo(tester.getRect(find.text('Add song')).bottom),
        reason: 'under the header');
    expect(row.bottom, lessThanOrEqualTo(tester.getRect(_field).top),
        reason: 'above the field');
    expect(row.height, greaterThanOrEqualTo(48), reason: 'a full touch target');
    expect(asked, 0);
  });

  testWidgets('a tap on it closes the sheet, picks nothing, and hands the '
      'pick to the page', (tester) async {
    var asked = 0;
    await open(tester,
        upNext: [_song('/a.mp3')],
        recent: [_song('/r.mp3')],
        onLibrary: () => asked++);
    await tester.tap(_library);
    await tester.pumpAndSettle();
    expect(find.byType(DraggableScrollableSheet), findsNothing);
    expect(answers, [null]);
    expect(asked, 1);
    expect(checked, isEmpty, reason: 'no song was picked to check');
  });

  testWidgets('with it on offer, closing the sheet by its X, Back or a tap '
      'above it picks nothing and hands nothing to the page', (tester) async {
    var asked = 0;
    await open(tester, upNext: [_song('/a.mp3')], onLibrary: () => asked++);
    await tester.tap(find.byKey(const ValueKey('auto-dj-add-song-close')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(400, 100));
    await tester.pumpAndSettle();
    expect(find.byType(DraggableScrollableSheet), findsNothing);
    expect(answers, [null, null, null]);
    expect(asked, 0, reason: 'only the row hands the pick to the page');
  });

  testWidgets('with it on offer, a song tap picks that song, and a refused '
      'one picks nothing; neither hands the pick to the page', (tester) async {
    var asked = 0;
    final next = _song('/a.mp3', title: 'Alpha');
    await open(tester, upNext: [next], onLibrary: () => asked++);
    await tester.tap(_upNext(0));
    await tester.pumpAndSettle();
    expect(answers, [same(next)]);

    await open(tester,
        search: (term) async => [_hit('/Music/sky.mp3', 'SkyWalk')],
        onLibrary: () => asked++);
    await tester.enterText(_field, 'sky');
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();
    await tester.tap(_hitRow(0));
    await tester.pumpAndSettle();
    expect(answers.last?.title, 'SkyWalk');

    // Refused: its server says it no longer has it.
    final old = _song('/gone.mp3', title: 'Gone');
    await open(tester,
        recent: [old], exists: (_) async => false, onLibrary: () => asked++);
    await tester.tap(_recent(0));
    await tester.pumpAndSettle();
    expect(checked, [same(old)]);
    expect(answers.last, isNull);
    expect(asked, 0, reason: 'only the row hands the pick to the page');
  });

  testWidgets('it is a button to screen readers, named by its words',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await open(tester, onLibrary: () {});
    expect(tester.getSemantics(_library),
        isSemantics(label: 'Pick a song from the library', isButton: true));
    semantics.dispose();
  });
}
