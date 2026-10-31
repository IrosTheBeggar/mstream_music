// Add from YouTube's folder paths: each crumb isolated so right-to-left
// names keep the › order, read aloud as "Music, then Daft Punk, then
// Discovery, a new folder", cut at the start on one line so the last folder
// stays, and wrapped only at the separators inside the card.
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/l10n/app_localizations.dart';
import 'package:mstream_music/l10n/localizations_delegates.dart';
import 'package:mstream_music/screens/ytdl/ytdl_crumbs.dart';

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
    expect(ytdlOnlyBrackets('Discovery ()'), isFalse);
    expect(ytdlOnlyBrackets(''), isFalse);
  });

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
