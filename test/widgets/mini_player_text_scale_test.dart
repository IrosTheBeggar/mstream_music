// The mini player's title line at large text. The bar is a fixed
// PlayerPanel.kCollapsedHeight, and its title line ("title · artist" and the
// time) is an 18 dp row with no room to grow. At 2.0× text the title ran out
// of the row and was cut off. Its line box was already 18.6 px at 1.0×, in
// the theme's 1.43 line height. Now the title is set in a 1.2 line height,
// and its words stop growing at the largest scale the row holds, about 1.15×.
// The bar keeps its height and layout, and nothing in it overflows.
//
// The harness uses the app's own theme, so the title gets the line height it
// gets on the phone.

import 'package:audio_service/audio_service.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/l10n/localizations_delegates.dart';
import 'package:mstream_music/media/audio_stuff.dart';
import 'package:mstream_music/singletons/media.dart';
import 'package:mstream_music/theme/velvet_theme.dart';
import 'package:mstream_music/widgets/player_panel.dart';
import 'package:rxdart/rxdart.dart';

/// A player paused 19 s into a 2:03 song.
class _Player implements AudioPlayerHandler {
  @override
  final BehaviorSubject<MediaItem?> mediaItem = BehaviorSubject.seeded(
      MediaItem(
          id: 'song-1',
          title: 'Rooftop Cypher',
          artist: 'Boukmanflow',
          duration: const Duration(seconds: 123)));
  @override
  final BehaviorSubject<PlaybackState> playbackState =
      BehaviorSubject.seeded(PlaybackState());
  @override
  final BehaviorSubject<List<MediaItem>> queue =
      BehaviorSubject.seeded(const []);
  @override
  final BehaviorSubject<dynamic> customState = BehaviorSubject.seeded(null);
  @override
  Stream<Duration> get positionStream =>
      Stream.value(const Duration(seconds: 19));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

const _bar = ValueKey('bar');
final _title = find.text('Rooftop Cypher  ·  Boukmanflow');
final _time = find.textContaining(' / ');

/// The largest text scale the 18 dp row holds a 13 px line at 1.2.
const _upTo = 18 / (13 * 1.2);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() => MediaManager().audioHandler = _Player());

  /// The bar as the panel docks it, across a 402 dp phone, at [textScale].
  Future<void> pumpBar(WidgetTester tester, double textScale) async {
    tester.view.physicalSize = const Size(402 * 3, 874 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      theme: buildAppTheme(paletteFor(AppTheme.dark)),
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: appSupportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: SizedBox(
            width: 402,
            height: PlayerPanel.kCollapsedHeight,
            child: PlayerPanel.miniBar(key: _bar),
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump();
  }

  /// The title line's own row: the SizedBox nearest above the title.
  double lineHeight(WidgetTester tester) => tester
      .getSize(find.ancestor(of: _title, matching: find.byType(SizedBox)).first)
      .height;

  void expectNotCutOff(WidgetTester tester, Finder text, String why) {
    final p = tester.renderObject<RenderParagraph>(text);
    expect(p.textSize.height, lessThanOrEqualTo(p.size.height), reason: why);
  }

  for (final scale in [1.0, 1.3, 2.0]) {
    testWidgets(
        'at $scale× the title and the time are whole, the bar keeps its '
        'height and layout, and nothing overflows', (tester) async {
      await pumpBar(tester, scale);
      expect(tester.takeException(), isNull, reason: 'no overflow');
      expect(tester.getSize(find.byKey(_bar)).height,
          PlayerPanel.kCollapsedHeight);
      expect(lineHeight(tester), 18, reason: 'the row never grows');
      expectNotCutOff(tester, _title, 'the title, at $scale×');
      expectNotCutOff(tester, _time, 'the time, at $scale×');
      // The transport row is still inside the bar.
      final bar = tester.getRect(find.byKey(_bar));
      for (final icon in [Icons.skip_previous, Icons.skip_next]) {
        expect(tester.getRect(find.byIcon(icon)).bottom,
            lessThanOrEqualTo(bar.bottom),
            reason: '$icon at $scale×');
      }
    });
  }

  testWidgets(
      'the words grow with the text up to about 1.15×, the most the row '
      'holds, and stop there', (tester) async {
    double titleSize() =>
        MediaQuery.textScalerOf(tester.element(_title)).scale(13);

    await pumpBar(tester, 1.0);
    expect(titleSize(), 13);

    await pumpBar(tester, 1.1);
    expect(titleSize(), moreOrLessEquals(13 * 1.1));

    for (final scale in [1.3, 2.0]) {
      await pumpBar(tester, scale);
      expect(titleSize(), moreOrLessEquals(13 * _upTo), reason: '$scale×');
    }
  });
}
