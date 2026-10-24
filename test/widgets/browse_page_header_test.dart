// The headers a connected server's pages gain while browsing it (the phone
// spec's §4.1.1, §4.3 and §4.5): where the pill sits — beside the text or
// under it — is measured once, on the widest words the page's own copy can
// read in, so a copy's state changing never moves the pill or the rows
// below it; another server's longer "Copying from …" wraps in that place
// rather than keeping the compact row from every phone.

import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/l10n/app_localizations.dart';
import 'package:mstream_music/l10n/localizations_delegates.dart';
import 'package:mstream_music/objects/discovery_plugins.dart';
import 'package:mstream_music/objects/display_item.dart';
import 'package:mstream_music/util/discover_badges.dart';
import 'package:mstream_music/widgets/browse_keep_pill.dart';
import 'package:mstream_music/widgets/browse_page_header.dart';

const pb = {'id': 1, 'name': 'Stage Peer B'};
const pc = {'id': 4, 'name': 'Stage Peer C'};

int _id = 300;

DiscoveryJob job(String scope,
        {String state = 'running', Map<String, Object> peer = pb, String? statusText, double? progress, Map<String, Object>? result}) =>
    DiscoveryJob.fromServerMap({
      'id': _id++,
      'plugin': kCopyPlugin,
      'recommendation': {
        'source': 'federation',
        'peer': peer,
        if (scope == 'folder') ...{'filepath': 'music/Boukmanflow', 'title': 'Boukmanflow'} else 'artist': 'Boukmanflow',
      },
      'params': {'scope': scope},
      'state': state,
      'progress': progress,
      'statusText': statusText,
      'result': result,
    })!;

Widget app(Widget child, {double width = 390}) => MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: appSupportedLocales,
      home: Scaffold(body: Align(alignment: Alignment.topLeft, child: SizedBox(width: width, child: child))),
    );

void main() {
  final l = lookupAppLocalizations(const Locale('en'));

  // The test font draws every glyph a full em wide. At 528 the pill sits
  // beside the text in every state; at 480 the idle pill ("Keep a copy…",
  // 12 em) would, "In your collection" (18 em) would not — so a measure of
  // the state's own words would move the pill as the copy went on. (A
  // folder's pill never reads another server's copy: a folder copy keys on
  // its server.)
  const width = 528.0;
  final picks = <String, KeepChoiceJob?>{
    'idle': null,
    'copying': KeepChoiceJob(job('folder', statusText: '12 of 24 songs · 30 MB', progress: 0.5)),
    'kept': KeepChoiceJob(job('folder', state: 'done', result: {
      'scope': 'folder',
      'folder': {'path': 'music/Boukmanflow', 'name': 'Boukmanflow', 'landed': 'copies/Boukmanflow'},
      'songs': {'total': 3, 'copied': [], 'skipped': [], 'failed': []},
      'counts': {'total': 3, 'copied': 3, 'skipped': 0, 'failed': 0},
    })),
  };

  Widget folderHeader(KeepChoiceJob? pick,
          {String peerName = 'Stage Peer B', String name = 'Boukmanflow', int folders = 3, int songs = 0}) =>
      FolderPageHeader(
        name: name,
        folders: folders,
        songs: songs,
        peerName: peerName,
        open: true,
        pick: pick,
        onKeep: () {},
      );

  // The folder header's text, and as laid out.
  Finder headLine() => find.byKey(const ValueKey('browse-folder-head-text'));
  RenderParagraph headText(WidgetTester tester) =>
      tester.renderObject<RenderParagraph>(find.descendant(of: headLine(), matching: find.byType(RichText)));

  Widget scaled(double scale, Widget child) => Builder(
        builder: (c) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
          child: child,
        ),
      );

  // (Its own copy running adds the live line under the pill: the header
  // grows by that line below the pill, never by the pill moving.)
  for (final w in const [width, 480.0]) {
    testWidgets('the folder header at $w: the pill in the same place and the same size, idle, copying and kept', (tester) async {
      final seen = <String, (Size, Offset, Size)>{};
      for (final e in picks.entries) {
        await tester.pumpWidget(app(folderHeader(e.value), width: w));
        if (e.key == 'kept') expect(find.text('In your collection'), findsOneWidget);
        seen[e.key] = (
          tester.getSize(find.byKey(const ValueKey('browse-folder-header'))),
          tester.getTopLeft(find.byKey(const ValueKey('browse-keep-pill'))),
          tester.getSize(find.byKey(const ValueKey('browse-keep-pill'))),
        );
      }
      expect(seen['kept']!.$1.height, seen['idle']!.$1.height);
      for (final k in ['copying', 'kept']) {
        expect(seen[k]!.$2, seen['idle']!.$2, reason: k);
        expect(seen[k]!.$3.height, seen['idle']!.$3.height, reason: k);
      }
    });
  }

  // The live walk's 402 pt phone with the stage's "Stage Peer B (:3992)":
  // "Copying from Stage Peer B (:3992)" (33 em) and 150 pt of text never
  // fit beside each other, so the header always stacked (≈115 pt). The own
  // words (18 em) leave the text its 150 pt: one row, the pill at the right.
  testWidgets('the folder header takes its compact row where the own words fit beside 150 pt of text, however long the server\'s name', (tester) async {
    const peer = 'Stage Peer B (:3992)';
    expect(KeepPagePill.widestWidth(l, TextScaler.noScaling, peer), greaterThan(width - 28 - 12 - 150),
        reason: 'the widest form would not fit beside the text');
    await tester.pumpWidget(app(folderHeader(null, peerName: peer), width: width));
    final header = tester.getRect(find.byKey(const ValueKey('browse-folder-header')));
    final pill = tester.getRect(find.byKey(const ValueKey('browse-keep-pill')));
    final text = tester.getRect(headLine());
    expect(header.height, lessThanOrEqualTo(66), reason: 'one ≈64 pt row');
    expect(pill.left, greaterThan(text.right), reason: 'beside its text');
    expect(pill.top, lessThan(header.top + 20), reason: 'in the row, not under it');
    expect(text.width, greaterThanOrEqualTo(150));
  });

  testWidgets('the folder header still goes under its text when the own words leave it less than 150 pt, and above 1.3×', (tester) async {
    for (final (w, scale) in const [(480.0, 1.0), (900.0, 1.31)]) {
      await tester.pumpWidget(app(
        Builder(
          builder: (c) => MediaQuery(
            data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
            child: folderHeader(null),
          ),
        ),
        width: w,
      ));
      final pill = tester.getRect(find.byKey(const ValueKey('browse-keep-pill')));
      final text = tester.getRect(headLine());
      expect(pill.top, greaterThan(text.bottom), reason: '$w at $scale×');
    }
  });

  // The live walk's recheck (D7): on its 402 pt phone with the stage's
  // "Stage Peer B (:3992)" the sub's ellipsis cut into the count ("· 1
  // fol…", "· 3 …"). The count is the one fact the sub adds: the server's
  // name gives way first, then "Folder on …", then the folder's own name —
  // the count is drawn whole, nothing ellipsized. (The test font draws a
  // glyph a full em wide: at 402 the header stacks even at 1.0×; at 528 the
  // text has 182 pt beside the pill — in these glyphs narrower than any
  // phone's, so there even two counts and a long name take more lines.)
  group("the folder header draws its count whole, however long the server's name", () {
    const peer = 'Stage Peer B (:3992)';
    const cases = [
      ('Boukmanflow', 1, 0, '1\u00A0folder'),
      ('Boukmanflow', 3, 0, '3\u00A0folders'),
      ('Borrowed Tapes', 0, 3, '3\u00A0songs'),
      ('Free Instrumentals Vol. 9', 2, 14, '2\u00A0folders · 14\u00A0songs'),
    ];
    for (final (w, scale) in const [(402.0, 1.0), (528.0, 1.0), (402.0, 1.3), (402.0, 2.0)]) {
      for (final (name, folders, songs, counts) in cases) {
        testWidgets('$w pt at $scale×: $name · $counts', (tester) async {
          await tester.pumpWidget(app(
            scaled(scale, folderHeader(null, peerName: peer, name: name, folders: folders, songs: songs)),
            width: w,
          ));
          expect(tester.takeException(), isNull);
          final para = headText(tester);
          final drawn = para.text.toPlainText();
          expect(drawn, endsWith(' $counts'));
          expect(para.didExceedMaxLines, isFalse, reason: 'nothing ellipsized: "$drawn"');
          // Every glyph of the counts laid out, inside the text's box.
          final boxes = para.getBoxesForSelection(
              TextSelection(baseOffset: drawn.length - counts.length, extentOffset: drawn.length));
          expect(boxes, isNotEmpty);
          expect(boxes.last.right, lessThanOrEqualTo(para.size.width + 0.5));
          expect(boxes.last.bottom, lessThanOrEqualTo(para.size.height + 0.5));
          // The header is beside the pill only at 528 (1.0×), and within it.
          final header = tester.getRect(find.byKey(const ValueKey('browse-folder-header')));
          final pill = tester.getRect(find.byKey(const ValueKey('browse-keep-pill')));
          expect(pill.left > tester.getRect(headLine()).right, w == 528, reason: 'beside');
          expect(pill.bottom, lessThanOrEqualTo(header.bottom));
        });
      }
    }

    testWidgets('the server\'s name is what gives way first, and the line is the spec\'s wherever it fits', (tester) async {
      // 402 pt at 1.0×: the folder's name and its count kept whole, the
      // server's name cut.
      for (final (name, folders, songs) in const [('Boukmanflow', 1, 0), ('Borrowed Tapes', 0, 3)]) {
        await tester.pumpWidget(
            app(folderHeader(null, peerName: peer, name: name, folders: folders, songs: songs), width: 402));
        final drawn = headText(tester).text.toPlainText();
        expect(drawn, startsWith('$name  ·  Folder on Stage Peer B ('));
        expect(drawn, isNot(contains(peer)));
        expect(drawn, matches(RegExp(r'… · \d+\u00A0(folder|song)s?$')));
      }
      // Room for it all: drawn whole, the folder's name and its facts.
      await tester.binding.setSurfaceSize(const Size(1200, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(app(folderHeader(null, peerName: peer, folders: 3, songs: 2), width: 1100));
      expect(headText(tester).text.toPlainText(),
          'Boukmanflow  ·  Folder on Stage Peer B (:3992) · 3\u00A0folders · 2\u00A0songs');
      expect(headText(tester).didExceedMaxLines, isFalse);
    });

    testWidgets('a screen reader hears the sub whole, whatever the line draws', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(app(folderHeader(null, peerName: peer, folders: 1), width: 402));
      expect(headText(tester).text.toPlainText(), isNot(contains(peer)));
      expect(tester.getSemantics(find.bySemanticsLabel('Boukmanflow')),
          isSemantics(label: 'Boukmanflow', value: 'Folder on $peer · 1\u00A0folder', isHeader: true));
      handle.dispose();
    });
  });

  test("the folder header's counts never break inside themselves", () {
    expect(FolderPageHeader.subOf(l, 'Stage Peer B', folders: 3, songs: 2),
        'Folder on Stage Peer B · 3\u00A0folders · 2\u00A0songs');
    expect(FolderPageHeader.subOf(l, 'Stage Peer B', folders: 1, songs: 0), 'Folder on Stage Peer B · 1\u00A0folder');
    expect(FolderPageHeader.subOf(l, 'Stage Peer B', folders: 0, songs: 0), 'Folder on Stage Peer B');
    // Where a plain space would end a line at "3", the count wraps whole.
    final sub = FolderPageHeader.subOf(l, 'Stage Peer B (:3992)', folders: 0, songs: 3);
    bool together(String text) {
      final p = TextPainter(
        text: TextSpan(text: text, style: const TextStyle(fontSize: 13)),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 35 * 13.0);
      final at = text.indexOf('3', text.indexOf('·'));
      final line = p.getLineBoundary(TextPosition(offset: at));
      p.dispose();
      return line.end >= text.length;
    }

    expect(together(sub.replaceAll('\u00A0', ' ')), isFalse, reason: 'the width splits a plain count');
    expect(together(sub), isTrue);
  });

  testWidgets("the artist header: the takes line and the pill stay put as the artist copy's state changes", (tester) async {
    final artist = ArtistContext(server: null, name: 'Boukmanflow', albums: const [
      {'name': 'Borrowed Tapes', 'album_artist': 'Boukmanflow', 'artists': ['Boukmanflow'], 'compilation': false},
      {'name': 'Harbour Lights', 'album_artist': 'Boukmanflow', 'artists': ['Boukmanflow'], 'compilation': false},
    ]);
    final artistPicks = <String, KeepChoiceJob?>{
      'idle': null,
      'copying': KeepChoiceJob(job('artist', statusText: '1 of 2 albums · Borrowed Tapes', progress: 0.5)),
      'kept': KeepChoiceJob(job('artist', state: 'done', result: {
        'scope': 'artist',
        'songs': {'total': 3, 'copied': [], 'skipped': [], 'failed': []},
        'counts': {'total': 3, 'copied': 3, 'skipped': 0, 'failed': 0},
        'albums': [
          {'name': 'Borrowed Tapes', 'copied': 3},
        ],
      })),
      'other': KeepChoiceJob(job('artist', peer: pc, statusText: '1 of 2 albums'), fromOtherPeer: true),
    };
    final seen = <String, (Size, Offset, Offset, Size)>{};
    for (final e in artistPicks.entries) {
      await tester.pumpWidget(app(
        ArtistPageHeader(artist: artist, peerName: 'Stage Peer B', open: true, pick: e.value, onKeep: () {}),
        width: 700,
      ));
      seen[e.key] = (
        tester.getSize(find.byKey(const ValueKey('browse-artist-header'))),
        tester.getTopLeft(find.byKey(const ValueKey('browse-keep-pill'))),
        tester.getTopLeft(find.byKey(const ValueKey('browse-artist-takes'))),
        tester.getSize(find.byKey(const ValueKey('browse-keep-pill'))),
      );
    }
    for (final k in ['copying', 'kept', 'other']) {
      expect(seen[k]!.$2, seen['idle']!.$2, reason: k);
      expect(seen[k]!.$3, seen['idle']!.$3, reason: k);
    }
    // Its own copy's words keep the pill's height (copying adds the live
    // line under it); another server's longer "Copying from …" may take a
    // second line in the same place.
    expect(seen['kept']!.$1.height, seen['idle']!.$1.height);
    for (final k in ['copying', 'kept']) {
      expect(seen[k]!.$4.height, seen['idle']!.$4.height, reason: k);
    }
  });

  // The live walk's 402 pt phone: the takes line went under the pill
  // because the place kept beside it was "Copying from Stage Peer B
  // (:3992)"'s. With the own words' place and 140 pt left, it sits beside.
  testWidgets('the artist header: the takes line beside the pill while 140 pt is left beside the own words, however long the server\'s name', (tester) async {
    const peer = 'Stage Peer B (:3992)';
    final artist = ArtistContext(server: null, name: 'Boukmanflow', albums: const [
      {'name': 'Borrowed Tapes', 'album_artist': 'Boukmanflow', 'artists': ['Boukmanflow'], 'compilation': false},
    ]);
    // Column = width − 28: the own words (18 em + chrome) and 12 + 140 fit.
    const width = 28 + 306 + 12 + 140 + 4.0;
    expect(KeepPagePill.ownWidth(l, TextScaler.noScaling), 306);
    expect(KeepPagePill.fitsBeside(l, width - 28 - 152, TextScaler.noScaling, peer), isFalse,
        reason: 'the widest form would have put the takes line under');
    await tester.pumpWidget(app(
      ArtistPageHeader(artist: artist, peerName: peer, open: true, pick: null, onKeep: () {}),
      width: width,
    ));
    final pill = tester.getRect(find.byKey(const ValueKey('browse-keep-pill')));
    final takes = tester.getRect(find.byKey(const ValueKey('browse-artist-takes')));
    expect(takes.left, greaterThan(pill.right), reason: 'beside the pill');
    expect(takes.top, lessThan(pill.bottom));
    // Narrower than that, it goes under.
    await tester.pumpWidget(app(
      ArtistPageHeader(artist: artist, peerName: peer, open: true, pick: null, onKeep: () {}),
      width: width - 8,
    ));
    expect(tester.getRect(find.byKey(const ValueKey('browse-artist-takes'))).top,
        greaterThan(tester.getRect(find.byKey(const ValueKey('browse-keep-pill'))).bottom));
  });

  testWidgets("the artist pill's hint is the takes line in every state, not only while idle", (tester) async {
    final handle = tester.ensureSemantics();
    final artist = ArtistContext(server: null, name: 'Boukmanflow', albums: const [
      {'name': 'Borrowed Tapes', 'album_artist': 'Boukmanflow', 'artists': ['Boukmanflow'], 'compilation': false},
    ]);
    await tester.pumpWidget(app(
      ArtistPageHeader(
        artist: artist,
        peerName: 'Stage Peer B',
        open: true,
        pick: KeepChoiceJob(job('artist', state: 'done')),
        onKeep: () {},
      ),
      width: 700,
    ));
    expect(tester.getSemantics(find.byKey(const ValueKey('browse-keep-pill'))),
        isSemantics(hint: 'Takes the 1 album credited to Boukmanflow'));
    handle.dispose();
  });
}
