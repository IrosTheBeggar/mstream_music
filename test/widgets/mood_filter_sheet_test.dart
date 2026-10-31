// The mood Filters sheet, button and strip (widgets/mood_filter_sheet.dart):
// one chosen value per scale, pressing it again lets it go, tags toggle,
// Strict | Standard | Loose with one always pressed, a song list's Sort
// (Match resting while no mood is set), Clear empties the choices in the
// sheet, only Done hands them back; the button counts what is set; the
// strip names it and offers Clear.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/l10n/localizations_delegates.dart';
import 'package:mstream_music/objects/mood_filter.dart';
import 'package:mstream_music/widgets/mood_filter_sheet.dart';

Widget _app(Widget body) => MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: appSupportedLocales,
      home: Scaffold(body: body),
    );

void main() {
  /// A page whose button opens the sheet on [start] (and [sortFor]'s Sort
  /// at [sort]); each answer lands in the list returned (null: closed
  /// without Done).
  Future<List<MoodSheetChoice?>> openSheet(WidgetTester tester,
      {MoodFilter start = MoodFilter.empty,
      String? title,
      MoodPage? sortFor,
      MoodSort sort = MoodSort.list}) async {
    final answers = <MoodSheetChoice?>[];
    await tester.pumpWidget(_app(Builder(
      builder: (context) => TextButton(
        onPressed: () async => answers.add(await showMoodFilterSheet(
            context, start,
            title: title, sortFor: sortFor, sort: sort)),
        child: const Text('open'),
      ),
    )));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return answers;
  }

  Set<String> chosen(WidgetTester tester, MoodScale scale) => tester
      .widget<SegmentedButton<String>>(
          find.byKey(ValueKey('mood-${scale.name}')))
      .selected;

  bool tagOn(WidgetTester tester, String tag) =>
      tester.widget<FilterChip>(find.byKey(ValueKey('mood-tag-$tag'))).selected;

  final levelRow = find.byKey(const ValueKey('mood-level'));
  Set<MoodLevel> level(WidgetTester tester) =>
      tester.widget<SegmentedButton<MoodLevel>>(levelRow).selected;

  final sortRow = find.byKey(const ValueKey('mood-sort'));
  SegmentedButton<MoodSort> sortButton(WidgetTester tester) =>
      tester.widget<SegmentedButton<MoodSort>>(sortRow);
  bool matchOn(WidgetTester tester) => sortButton(tester)
      .segments
      .firstWhere((s) => s.value == MoodSort.match)
      .enabled;

  final sheet = find.byKey(const ValueKey('mood-sheet'));
  final clear = find.byKey(const ValueKey('mood-sheet-clear'));
  final done = find.byKey(const ValueKey('mood-sheet-done'));

  bool clearOn(WidgetTester tester) => tester
      .widget<GestureDetector>(
          find.descendant(of: clear, matching: find.byType(GestureDetector)))
      .onTap != null;

  testWidgets('three scales and three tags; nothing chosen, Clear off',
      (tester) async {
    await openSheet(tester);
    expect(sheet, findsOneWidget);
    expect(find.text('Filters'), findsOneWidget);
    for (final label in [
      'Happy', 'Sad', 'Relaxed', 'Aggressive', 'Instrumental', 'Vocals',
      'Acoustic', 'Party', 'Danceable',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('Neutral'), findsNWidgets(2));
    for (final s in MoodScale.values) {
      expect(chosen(tester, s), isEmpty);
    }
    expect(clearOn(tester), isFalse);
    expect(done, findsOneWidget);
    expect(level(tester), {MoodLevel.standard});
    expect(sortRow, findsNothing, reason: 'only Rated and Recent sort');
  });

  testWidgets('pressing a value picks it, again lets it go; Done hands the '
      'choices back', (tester) async {
    final answers = await openSheet(tester);
    await tester.tap(find.text('Relaxed'));
    await tester.pumpAndSettle();
    expect(chosen(tester, MoodScale.energy), {'relaxed'});
    expect(clearOn(tester), isTrue);

    await tester.tap(find.text('Aggressive'));
    await tester.pumpAndSettle();
    expect(chosen(tester, MoodScale.energy), {'aggressive'},
        reason: 'one value per scale');
    await tester.tap(find.text('Aggressive'));
    await tester.pumpAndSettle();
    expect(chosen(tester, MoodScale.energy), isEmpty);

    await tester.tap(find.text('Sad'));
    await tester.tap(find.text('Vocals'));
    await tester.pumpAndSettle();
    expect(answers, isEmpty, reason: 'nothing is handed back before Done');
    await tester.tap(done);
    await tester.pumpAndSettle();
    expect(sheet, findsNothing);
    expect(answers.single?.filter.toJson(),
        {'valence': 'sad', 'voice': 'vocals'});
  });

  testWidgets("tags toggle; Clear empties the sheet's choices", (tester) async {
    final answers = await openSheet(tester,
        start: const MoodFilter(valence: 'happy', voice: 'vocals'));
    expect(chosen(tester, MoodScale.valence), {'happy'});
    await tester.tap(find.text('Party'));
    await tester.tap(find.text('Acoustic'));
    await tester.pumpAndSettle();
    expect(tagOn(tester, 'party'), isTrue);
    expect(tagOn(tester, 'acoustic'), isTrue);
    await tester.tap(find.text('Party'));
    await tester.pumpAndSettle();
    expect(tagOn(tester, 'party'), isFalse);

    await tester.tap(clear);
    await tester.pumpAndSettle();
    expect(sheet, findsOneWidget, reason: 'Clear does not close the sheet');
    expect(chosen(tester, MoodScale.valence), isEmpty);
    expect(tagOn(tester, 'acoustic'), isFalse);
    expect(clearOn(tester), isFalse);
    await tester.tap(done);
    await tester.pumpAndSettle();
    expect(answers.single?.filter, MoodFilter.empty);
  });

  testWidgets('closing it any other way hands nothing back', (tester) async {
    final answers = await openSheet(tester,
        start: const MoodFilter(energy: 'relaxed'));
    await tester.tap(find.text('Happy'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
    expect(sheet, findsNothing);
    expect(answers, [null]);

    // The scrim, too.
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(400, 20));
    await tester.pumpAndSettle();
    expect(sheet, findsNothing);
    expect(answers, [null, null]);
  });

  testWidgets('a short screen scrolls the choices, never overflows',
      (tester) async {
    tester.view.physicalSize = const Size(874 * 3, 402 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await openSheet(tester, sortFor: MoodPage.rated);
    expect(tester.takeException(), isNull);
    expect(done, findsOneWidget);
    final choices =
        find.descendant(of: sheet, matching: find.byType(Scrollable));
    await tester.scrollUntilVisible(find.text('Danceable'), 40,
        scrollable: choices);
    await tester.tap(find.text('Danceable'));
    await tester.pumpAndSettle();
    expect(tagOn(tester, 'danceable'), isTrue);
    await tester.scrollUntilVisible(find.text('Rating'), 40,
        scrollable: choices);
    await tester.tap(find.text('Match'));
    await tester.pumpAndSettle();
    expect(sortButton(tester).selected, {MoodSort.match});
  });

  testWidgets("a title replaces Filters (Auto DJ's Mood row); the sheet is "
      'otherwise the same', (tester) async {
    final answers = await openSheet(tester,
        start: const MoodFilter(energy: 'relaxed'), title: 'Mood');
    expect(find.text('Mood'), findsOneWidget);
    expect(find.text('Filters'), findsNothing);
    expect(chosen(tester, MoodScale.energy), {'relaxed'});
    await tester.tap(find.text('Sad'));
    await tester.pumpAndSettle();
    await tester.tap(done);
    await tester.pumpAndSettle();
    expect(sheet, findsNothing);
    expect(answers.single?.filter.toJson(),
        {'valence': 'sad', 'energy': 'relaxed'});

    // No title: the browse lists' own word.
    await openSheet(tester);
    expect(find.text('Filters'), findsOneWidget);
    expect(find.text('Mood'), findsNothing);
  });

  testWidgets('the button counts the choices set', (tester) async {
    Badge badge() => tester.widget<Badge>(find.byType(Badge));
    await tester.pumpWidget(_app(MoodFilterButton(count: 0, onPressed: () {})));
    expect(badge().isLabelVisible, isFalse);
    await tester.pumpWidget(_app(MoodFilterButton(count: 3, onPressed: () {})));
    expect(badge().isLabelVisible, isTrue);
    expect(find.text('3'), findsOneWidget);
    expect(find.byTooltip('Filters'), findsOneWidget);
  });

  testWidgets('the strip names the scales then the tags; Clear calls back',
      (tester) async {
    var cleared = 0;
    await tester.pumpWidget(_app(MoodFilterStrip(
      filter: const MoodFilter(
          valence: 'happy', energy: 'relaxed', tags: ['acoustic', 'party']),
      onClear: () => cleared++,
    )));
    expect(find.text('Happy · Relaxed · Acoustic · Party'), findsOneWidget);
    await tester.tap(find.text('Clear'));
    expect(cleared, 1);

    // Off where it can do nothing (Discover while its route refuses).
    await tester.pumpWidget(_app(const MoodFilterStrip(
        filter: MoodFilter(voice: 'instrumental'), onClear: null)));
    expect(find.text('Instrumental'), findsOneWidget);
    expect(
        tester
            .widget<TextButton>(
                find.byKey(const ValueKey('mood-strip-clear')))
            .enabled,
        isFalse);
  });

  testWidgets('the strip names a level other than Standard, last',
      (tester) async {
    await tester.pumpWidget(_app(MoodFilterStrip(
      filter: const MoodFilter(
          energy: 'relaxed', tags: ['party'], level: MoodLevel.strict),
      onClear: () {},
    )));
    expect(find.text('Relaxed · Party · Strict'), findsOneWidget);
    await tester.pumpWidget(_app(MoodFilterStrip(
      filter: const MoodFilter(energy: 'relaxed', level: MoodLevel.loose),
      onClear: () {},
    )));
    expect(find.text('Relaxed · Loose'), findsOneWidget);
    await tester.pumpWidget(_app(MoodFilterStrip(
      filter: const MoodFilter(energy: 'relaxed'),
      onClear: () {},
    )));
    expect(find.text('Relaxed'), findsOneWidget);
  });

  testWidgets('Strict | Standard | Loose: Standard to start, one always '
      'pressed; Clear goes back to Standard', (tester) async {
    var answers = await openSheet(tester);
    expect(find.text('Strict'), findsOneWidget);
    expect(find.text('Standard'), findsOneWidget);
    expect(find.text('Loose'), findsOneWidget);
    await tester.tap(find.text('Strict'));
    await tester.pumpAndSettle();
    expect(level(tester), {MoodLevel.strict});
    await tester.tap(find.text('Strict'));
    await tester.pumpAndSettle();
    expect(level(tester), {MoodLevel.strict},
        reason: 'pressing the pressed one does nothing');
    expect(clearOn(tester), isTrue, reason: 'a level to go back from');
    await tester.tap(clear);
    await tester.pumpAndSettle();
    expect(level(tester), {MoodLevel.standard});
    expect(clearOn(tester), isFalse);

    // Picked with no mood set, it is still handed back (kept for next time).
    await tester.tap(find.text('Loose'));
    await tester.pumpAndSettle();
    await tester.tap(done);
    await tester.pumpAndSettle();
    expect(answers.single?.filter, const MoodFilter(level: MoodLevel.loose));
    expect(answers.single?.filter.toJson(), isNull);

    // Kept through the choices.
    const start = MoodFilter(energy: 'relaxed', level: MoodLevel.strict);
    answers = await openSheet(tester, start: start);
    expect(level(tester), {MoodLevel.strict});
    await tester.tap(find.text('Instrumental'));
    await tester.tap(done);
    await tester.pumpAndSettle();
    expect(answers.single?.filter.toJson(),
        {'energy': 'relaxed', 'voice': 'instrumental', 'threshold': 0.7});
  });

  testWidgets("Rated's Sort: Rating | Match, Match resting while no mood is "
      'set and coming back with one', (tester) async {
    final answers = await openSheet(tester, sortFor: MoodPage.rated);
    expect(find.text('Sort'), findsOneWidget);
    expect(find.text('Rating'), findsOneWidget);
    expect(sortButton(tester).selected, {MoodSort.list});
    expect(matchOn(tester), isFalse, reason: 'nothing to rank by');

    await tester.tap(find.text('Relaxed'));
    await tester.pumpAndSettle();
    expect(matchOn(tester), isTrue);
    await tester.tap(find.text('Match'));
    await tester.pumpAndSettle();
    expect(sortButton(tester).selected, {MoodSort.match});
    await tester.tap(find.text('Match'));
    await tester.pumpAndSettle();
    expect(sortButton(tester).selected, {MoodSort.match},
        reason: 'pressing the pressed one does nothing');

    await tester.tap(find.text('Relaxed'));
    await tester.pumpAndSettle();
    expect(matchOn(tester), isFalse);
    expect(sortButton(tester).selected, {MoodSort.list},
        reason: "the list's own order shows while Match rests");
    await tester.tap(find.text('Relaxed'));
    await tester.pumpAndSettle();
    expect(sortButton(tester).selected, {MoodSort.match},
        reason: 'Match comes back with the filter');

    await tester.tap(done);
    await tester.pumpAndSettle();
    expect(answers.single?.sort, MoodSort.match);
    expect(answers.single?.filter, const MoodFilter(energy: 'relaxed'));
  });

  testWidgets("Recent's Sort: Newest | Match, from the list's Sort; a sheet "
      'with none hands its Sort back as it came', (tester) async {
    var answers = await openSheet(tester,
        start: const MoodFilter(energy: 'relaxed'),
        sortFor: MoodPage.recent,
        sort: MoodSort.match);
    expect(find.text('Newest'), findsOneWidget);
    expect(find.text('Rating'), findsNothing);
    expect(sortButton(tester).selected, {MoodSort.match});
    await tester.tap(find.text('Newest'));
    await tester.pumpAndSettle();
    await tester.tap(done);
    await tester.pumpAndSettle();
    expect(answers.single?.sort, MoodSort.list);

    answers = await openSheet(tester, sort: MoodSort.match);
    expect(sortRow, findsNothing);
    await tester.tap(done);
    await tester.pumpAndSettle();
    expect(answers.single?.sort, MoodSort.match);
  });
}
