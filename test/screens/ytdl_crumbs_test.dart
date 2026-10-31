// Add from YouTube's folder paths: each crumb isolated so right-to-left
// names keep the › order, read aloud as "Music, then Daft Punk, then
// Discovery, a new folder", cut at the start on one line so the last folder
// stays, and wrapped only at the separators inside the card.
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/l10n/app_localizations.dart';
import 'package:mstream_music/l10n/localizations_delegates.dart';
import 'package:mstream_music/screens/ytdl/ytdl_crumbs.dart';
import 'package:mstream_music/util/ytdl_layout.dart';

void main() {
  final l = lookupAppLocalizations(const Locale('en'));

  test('crumbs are isolated and joined with ›', () {
    expect(ytdlPathText(['Music', 'Daft Punk']),
        '\u2068Music\u2069 › \u2068Daft Punk\u2069');
    expect(ytdlToastPath('Music', const []), '\u2068Music\u2069');
    expect(ytdlToastPath('Music', ['Daft Punk', 'Discovery']),
        '\u2068Daft Punk\u2069 › \u2068Discovery\u2069');
  });

  test('a path reads aloud folder by folder, new folders and traps named', () {
    expect(
      ytdlSpokenPath(l, ['Music', 'Daft Punk', 'Discovery'], newAt: {2}),
      'Music, then Daft Punk, then Discovery, a new folder',
    );
    expect(
      ytdlSpokenPath(l, ['Music', 'Gorillaz', '()'],
          trapAt: {2}, file: 'Gorillaz_-_Feel_Good.mp3'),
      'Music, then Gorillaz, then empty brackets, file Gorillaz_-_Feel_Good.mp3',
    );
    expect(
      ytdlSpokenPath(l, ['Music', 'Daft Punk', 'Discovery ()'], trapAt: {2}),
      'Music, then Daft Punk, then Discovery with empty brackets',
    );
  });

  test('only-bracket folders are recognised', () {
    expect(ytdlOnlyBrackets('()'), isTrue);
    expect(ytdlOnlyBrackets(' [ ] '), isTrue);
    expect(ytdlOnlyBrackets('-'), isTrue);
    expect(ytdlOnlyBrackets('【】'), isTrue);
    expect(ytdlOnlyBrackets('Discovery ()'), isFalse);
    expect(ytdlOnlyBrackets(''), isFalse);
  });

  // Every folder the bracket warning flags (and tints) is read with its
  // warning word: an empty pair anywhere in the name, the CJK pair too.
  for (final (layout, heard) in [
    ('{{ALBUM}} ({{YEAR}})', 'Discovery with empty brackets'),
    ('({{YEAR}}) {{ALBUM}}', 'Discovery with empty brackets'),
    ('{{ALBUM}} 【{{YEAR}}】', 'Discovery with empty brackets'),
    ('【{{YEAR}}】', 'empty brackets'),
    ('[{{YEAR}}]', 'empty brackets'),
  ]) {
    test('the flagged folder of $layout reads "$heard"', () {
      final t = ytdlTarget(
        vpath: 'Music',
        layout: layout,
        tags: const YtdlTags(artist: 'Daft Punk', album: 'Discovery'),
      );
      final trap = t.trap;
      expect(trap, isNotNull, reason: 'the warning flags it');
      final at = t.segments.indexOf(trap!.folder) + 1;
      expect(ytdlSpokenPath(l, t.crumbs, trapAt: {at}), 'Music, then $heard');
    });
  }

  test('a line too narrow for the whole path drops leading crumbs', () {
    const style = TextStyle(fontSize: 12);
    final crumbs = ['Music', 'Daft Punk', 'Homework'];
    final wide = YtdlCrumbLine.fit(
      crumbs: crumbs,
      style: style,
      maxWidth: 2000,
      direction: TextDirection.ltr,
      scaler: TextScaler.noScaling,
    );
    expect(wide, ytdlPathText(crumbs));
    final narrow = YtdlCrumbLine.fit(
      crumbs: crumbs,
      style: style,
      maxWidth: 160,
      direction: TextDirection.ltr,
      scaler: TextScaler.noScaling,
    );
    expect(narrow.startsWith('…'), isTrue);
    expect(narrow.endsWith('\u2068Homework\u2069'), isTrue);
  });

  testWidgets('the card path shows the new tag and reads as one phrase',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: appSupportedLocales,
      home: Scaffold(
        body: YtdlCrumbs(crumbs: const ['Music', 'Daft Punk', 'Discovery'], newAt: const {2}),
      ),
    ));
    expect(find.text('new'), findsOneWidget);
    expect(
      find.bySemanticsLabel('Music, then Daft Punk, then Discovery, a new folder'),
      findsOneWidget,
    );
  });

  testWidgets('at 200% text the new tag is scaled once, with the path',
      (tester) async {
    Future<double> tagHeight(double scale) async {
      await tester.pumpWidget(MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: appSupportedLocales,
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Scaffold(
            body: YtdlCrumbs(
                crumbs: const ['Music', 'Daft Punk', 'Discovery'],
                newAt: const {2}),
          ),
        ),
      ));
      // As drawn on screen: the paragraph's own scaling included.
      return tester.getRect(find.text('new')).height;
    }

    final at100 = await tagHeight(1);
    expect(await tagHeight(2), moreOrLessEquals(at100 * 2, epsilon: 1));
  });

  testWidgets('the card path never breaks inside a name after its hyphen',
      (tester) async {
    const crumbs = ['Music', 'Hip-Hop', 'Jay-Z', 'The Blueprint 2-The Gift'];
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: appSupportedLocales,
      home: const Scaffold(body: YtdlCrumbs(crumbs: crumbs)),
    ));
    final para =
        tester.renderObject<RenderParagraph>(find.byType(RichText).first);
    final text = para.text.toPlainText();
    // From the widest unbreakable run on: a name wider than the line has
    // to break somewhere.
    final measure = TextPainter(
      text: para.text,
      textDirection: TextDirection.ltr,
      textScaler: para.textScaler,
    )..layout();
    final from = measure.minIntrinsicWidth.ceilToDouble();
    measure.dispose();
    expect(from, greaterThan(100), reason: 'a name is one run');
    for (var w = from; w <= 600; w += 4) {
      final tp = TextPainter(
        text: para.text,
        textDirection: TextDirection.ltr,
        textScaler: para.textScaler,
      )..layout(maxWidth: w);
      var offset = 0;
      final lines = <String>[];
      while (offset < text.length) {
        final b = tp.getLineBoundary(TextPosition(offset: offset));
        if (b.end <= offset) break;
        lines.add(text.substring(b.start, b.end));
        offset = b.end;
      }
      tp.dispose();
      for (final line in lines.take(lines.length - 1)) {
        expect(line.trimRight().replaceAll('\u2060', '').endsWith('-'), isFalse,
            reason: 'at $w px a line ends "$line"');
      }
    }
  });

  testWidgets('a one-line path never overflows at 360 dp and 200% text',
      (tester) async {
    tester.view.physicalSize = const Size(360 * 3, 800 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: appSupportedLocales,
      home: MediaQuery(
        data: const MediaQueryData(textScaler: TextScaler.linear(2)),
        child: Scaffold(
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: YtdlCrumbLine(
              crumbs: const ['Music', 'Daft Punk', 'Random Access Memories'],
              prefix: 'Lands in ',
              suffix: ' · MP3',
            ),
          ),
        ),
      ),
    ));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('Random Access Memories'), findsOneWidget);
  });
}
