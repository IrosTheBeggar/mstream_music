// The mood Filters sheet, button and strip (widgets/mood_filter_sheet.dart):
// one chosen value per scale, pressing it again lets it go, tags toggle,
// Clear empties the choices in the sheet, only Done hands them back; the
// button counts what is set; the strip names it and offers Strict and
// Clear; the close matches' divider.

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
  /// A page whose button opens the sheet on [start]; each answer lands in
  /// the list returned (null: closed without Done).
  Future<List<MoodFilter?>> openSheet(WidgetTester tester,
      {MoodFilter start = MoodFilter.empty}) async {
    final answers = <MoodFilter?>[];
    await tester.pumpWidget(_app(Builder(
      builder: (context) => TextButton(
        onPressed: () async =>
            answers.add(await showMoodFilterSheet(context, start)),
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
    expect(answers.single?.toJson(), {'valence': 'sad', 'voice': 'vocals'});
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
    expect(answers.single?.isEmpty, isTrue);
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
    await openSheet(tester);
    expect(tester.takeException(), isNull);
    expect(done, findsOneWidget);
    await tester.scrollUntilVisible(find.text('Danceable'), 40,
        scrollable: find.descendant(
            of: sheet, matching: find.byType(Scrollable)));
    await tester.tap(find.text('Danceable'));
    await tester.pumpAndSettle();
    expect(tagOn(tester, 'danceable'), isTrue);
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
      onStrict: () {},
    )));
    expect(find.text('Happy · Relaxed · Acoustic · Party'), findsOneWidget);
    await tester.tap(find.text('Clear'));
    expect(cleared, 1);

    // Off where it can do nothing (Discover while its route refuses).
    await tester.pumpWidget(_app(const MoodFilterStrip(
        filter: MoodFilter(voice: 'instrumental'),
        onClear: null,
        onStrict: null)));
    expect(find.text('Instrumental'), findsOneWidget);
    expect(
        tester
            .widget<TextButton>(
                find.byKey(const ValueKey('mood-strip-clear')))
            .enabled,
        isFalse);
    expect(
        tester
            .widget<FilterChip>(
                find.byKey(const ValueKey('mood-strip-strict')))
            .onSelected,
        isNull);
  });

  testWidgets("the strip's Strict: pressed while the filter is strict, and "
      'calls back', (tester) async {
    FilterChip chip() => tester
        .widget<FilterChip>(find.byKey(const ValueKey('mood-strip-strict')));
    var pressed = 0;
    await tester.pumpWidget(_app(MoodFilterStrip(
      filter: const MoodFilter(energy: 'relaxed'),
      onClear: () {},
      onStrict: () => pressed++,
    )));
    expect(chip().selected, isFalse);
    expect(find.text('Relaxed'), findsOneWidget,
        reason: 'Strict is the switch, not one of the words');
    await tester.tap(find.text('Strict'));
    expect(pressed, 1);
    await tester.pumpWidget(_app(MoodFilterStrip(
      filter: const MoodFilter(energy: 'relaxed', strict: true),
      onClear: () {},
      onStrict: () {},
    )));
    expect(chip().selected, isTrue);
  });

  testWidgets('the sheet keeps Strict while a choice stays; Clear lets it go',
      (tester) async {
    const start = MoodFilter(energy: 'relaxed', strict: true);
    var answers = await openSheet(tester, start: start);
    await tester.tap(find.text('Instrumental'));
    await tester.tap(find.byKey(const ValueKey('mood-sheet-done')));
    await tester.pumpAndSettle();
    expect(answers.single,
        const MoodFilter(energy: 'relaxed', voice: 'instrumental', strict: true));

    answers = await openSheet(tester, start: start);
    await tester.tap(find.byKey(const ValueKey('mood-sheet-clear')));
    await tester.tap(find.byKey(const ValueKey('mood-sheet-done')));
    await tester.pumpAndSettle();
    expect(answers.single, MoodFilter.empty);
  });

  testWidgets('the close matches divider: its words, in capitals',
      (tester) async {
    await tester.pumpWidget(_app(SizedBox(
        height: MoodCloseMatches.extentFor(TextScaler.noScaling),
        child: const MoodCloseMatches())));
    expect(find.text('CLOSE MATCHES'), findsOneWidget);
    expect(MoodCloseMatches.extentFor(const TextScaler.linear(2)), 80);
    expect(MoodCloseMatches.extentFor(const TextScaler.linear(0.8)), 40);
  });
}
