// The queue header at large text: "QUEUE · N tracks", the Auto DJ button and
// ⋮ share one row. On a 402 dp phone at 2.0× text that row overflowed (by
// 24 px in English and 77 px in Russian on the phone) and pushed ⋮ off
// screen. Now the label and count give way with an ellipsis, and past 1.5×
// the Auto DJ button shows its glyph instead of its word. A screen reader
// still hears "Auto DJ", a long press shows it, and both halves of the
// button still work.
//
// The test font draws every glyph as a 1 em square, wider than any phone's
// font, so a row that fits here fits on the phone.

import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/l10n/app_localizations.dart';
import 'package:mstream_music/l10n/localizations_delegates.dart';
import 'package:mstream_music/media/audio_stuff.dart';
import 'package:mstream_music/singletons/media.dart';
import 'package:mstream_music/widgets/auto_dj_quick_config.dart';
import 'package:mstream_music/widgets/queue_list.dart';
import 'package:rxdart/rxdart.dart';

/// A player with nothing playing and 12 tracks queued.
class _Player implements AudioPlayerHandler {
  @override
  final BehaviorSubject<MediaItem?> mediaItem = BehaviorSubject.seeded(null);
  @override
  final BehaviorSubject<PlaybackState> playbackState =
      BehaviorSubject.seeded(PlaybackState());
  @override
  final BehaviorSubject<List<MediaItem>> queue = BehaviorSubject.seeded([
    for (var i = 1; i <= 12; i++) MediaItem(id: 'song-$i', title: 'Song $i'),
  ]);
  @override
  final BehaviorSubject<dynamic> customState = BehaviorSubject.seeded(null);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _screen = Rect.fromLTWH(0, 0, 402, 874);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => MediaManager().audioHandler = _Player());

  /// The header as the full player shows it (⋮ on every layout), on a
  /// 402 × 874 phone in [locale] at [textScale].
  Future<AppLocalizations> pumpHeader(
      WidgetTester tester, String locale, double textScale,
      {VoidCallback? onOptions}) async {
    tester.view.physicalSize = const Size(402 * 3, 874 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      locale: Locale(locale),
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: appSupportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Column(children: [
          QueueHeader(showOptions: true, onOptions: onOptions ?? () {}),
        ]),
      ),
    ));
    await tester.pump();
    return lookupAppLocalizations(Locale(locale));
  }

  Matcher onScreen() => predicate<Rect>(
      (r) =>
          r.left >= _screen.left &&
          r.right <= _screen.right &&
          r.top >= _screen.top &&
          r.bottom <= _screen.bottom,
      'inside the 402 × 874 screen');

  for (final locale in ['en', 'ru']) {
    testWidgets(
        '$locale at 2.0×: the row fits, with ⋮ and both halves of the Auto '
        'DJ button on screen', (tester) async {
      var options = 0;
      final l = await pumpHeader(tester, locale, 2.0,
          onOptions: () => options++);
      expect(tester.takeException(), isNull, reason: 'no overflow');

      final more = find.byTooltip(l.mainMore);
      expect(tester.getRect(more), onScreen());
      for (final half in ['auto-dj-split-toggle', 'auto-dj-split-chevron']) {
        expect(tester.getRect(find.byKey(ValueKey(half))), onScreen(),
            reason: half);
      }
      await tester.tap(more);
      expect(options, 1);

      // The label and count give way: one line, cut with an ellipsis.
      final label =
          tester.widget<Text>(find.textContaining(l.tabQueue.toUpperCase()));
      expect(label.maxLines, 1);
      expect(label.overflow, TextOverflow.ellipsis);
    });

    testWidgets(
        '$locale: past 1.5× the Auto DJ button is its glyph, still "Auto '
        'DJ" to a screen reader; up to 1.5× it keeps its word',
        (tester) async {
      final semantics = tester.ensureSemantics();
      for (final (scale, word) in [(1.0, true), (1.5, true), (2.0, false)]) {
        final l = await pumpHeader(tester, locale, scale);
        expect(tester.takeException(), isNull, reason: '$scale×');
        expect(find.text(l.autoDjTitle), word ? findsOneWidget : findsNothing,
            reason: '$scale×');
        expect(find.byIcon(Icons.all_inclusive),
            word ? findsNothing : findsOneWidget,
            reason: '$scale×');
        expect(
            tester.getSemantics(
                find.byKey(const ValueKey('auto-dj-split-toggle'))),
            isSemantics(
                label: l.autoDjTitle,
                isButton: true,
                hasToggledState: true,
                hasTapAction: true),
            reason: '$scale×');
      }
      semantics.dispose();
    });
  }

  testWidgets(
      'past 1.5× the glyph still starts and stops the DJ, a long press names '
      'it, and the chevron still opens quick config', (tester) async {
    var toggles = 0;
    var opened = 0;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: appSupportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(2.0)),
        child: child!,
      ),
      home: Scaffold(
        body: Center(
          child: AutoDjSplitButton(
            on: Stream.value(false),
            onToggle: () => toggles++,
            onOpen: (context,
                {required button, required bar, required above}) async {
              opened++;
            },
          ),
        ),
      ),
    ));
    await tester.pump();
    final toggle = find.byKey(const ValueKey('auto-dj-split-toggle'));
    expect(
        find.descendant(of: toggle, matching: find.byIcon(Icons.all_inclusive)),
        findsOneWidget);

    await tester.tap(toggle);
    expect(toggles, 1);

    await tester.longPress(toggle);
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Auto DJ'), findsOneWidget,
        reason: 'the long press names it');
    expect(toggles, 1, reason: 'a long press never toggles');
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('Auto DJ'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('auto-dj-split-chevron')));
    await tester.pump();
    expect(opened, 1);
  });
}
