// The headers a connected server's pages gain while browsing it (the phone
// spec's §4.1.1, §4.3 and §4.5): the Keep a copy pill and nothing else — the
// page's own bar names the artist or the folder, and the server. Its width
// is measured once, on the widest words the page's own copy can read in, so
// a copy's state changing never moves the pill or the rows below it.

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/l10n/app_localizations.dart';
import 'package:mstream_music/l10n/localizations_delegates.dart';
import 'package:mstream_music/objects/discovery_plugins.dart';
import 'package:mstream_music/objects/display_item.dart';
import 'package:mstream_music/util/discover_badges.dart';
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

  Widget folderHeader(KeepChoiceJob? pick) =>
      FolderPageHeader(name: 'Boukmanflow', open: true, pick: pick, onKeep: () {});

  Widget scaled(double scale, Widget child) => Builder(
        builder: (c) => MediaQuery(
          data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
          child: child,
        ),
      );

  // Every text the header draws is the pill's own.
  Iterable<String> texts(WidgetTester tester, String header) => tester
      .widgetList<Text>(find.descendant(of: find.byKey(ValueKey(header)), matching: find.byType(Text)))
      .map((t) => t.data ?? t.textSpan!.toPlainText());

  for (final w in const [528.0, 390.0]) {
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
      for (final k in ['copying', 'kept']) {
        expect(seen[k]!.$1.height, seen['idle']!.$1.height, reason: k);
        expect(seen[k]!.$2, seen['idle']!.$2, reason: k);
        expect(seen[k]!.$3.height, seen['idle']!.$3.height, reason: k);
      }
    });
  }

  testWidgets('the folder header is the pill alone: no name, server or counts', (tester) async {
    await tester.pumpWidget(app(folderHeader(null)));
    expect(texts(tester, 'browse-folder-header'), ['Keep a copy…']);
    final header = tester.getRect(find.byKey(const ValueKey('browse-folder-header')));
    final pill = tester.getRect(find.byKey(const ValueKey('browse-keep-pill')));
    expect(pill.left, header.left + 16, reason: 'at the start of the row');
    expect(pill.width, lessThan(header.width - 32), reason: 'at its own width');
  });

  testWidgets('above 1.3× text, or narrower than its widest words, the pill takes the full width', (tester) async {
    for (final (w, scale) in const [(390.0, 1.31), (200.0, 1.0)]) {
      await tester.pumpWidget(app(scaled(scale, folderHeader(null)), width: w));
      expect(tester.takeException(), isNull);
      final header = tester.getRect(find.byKey(const ValueKey('browse-folder-header')));
      final pill = tester.getRect(find.byKey(const ValueKey('browse-keep-pill')));
      expect(pill.width, header.width - 32, reason: '$w at $scale×');
    }
  });

  final artist = ArtistContext(server: null, name: 'Boukmanflow', albums: const [
    {'name': 'Borrowed Tapes', 'album_artist': 'Boukmanflow', 'artists': ['Boukmanflow'], 'compilation': false},
    {'name': 'Harbour Lights', 'album_artist': 'Boukmanflow', 'artists': ['Boukmanflow'], 'compilation': false},
  ]);

  testWidgets("the artist header: the pill stays put as the artist copy's state changes", (tester) async {
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
    final seen = <String, (Size, Offset, Size)>{};
    for (final e in artistPicks.entries) {
      await tester.pumpWidget(app(
        ArtistPageHeader(artist: artist, open: true, pick: e.value, onKeep: () {}),
        width: 700,
      ));
      seen[e.key] = (
        tester.getSize(find.byKey(const ValueKey('browse-artist-header'))),
        tester.getTopLeft(find.byKey(const ValueKey('browse-keep-pill'))),
        tester.getSize(find.byKey(const ValueKey('browse-keep-pill'))),
      );
    }
    for (final k in ['copying', 'kept', 'other']) {
      expect(seen[k]!.$2, seen['idle']!.$2, reason: k);
    }
    // Its own copy's words keep the pill's and the header's height; another
    // server's longer "Copying from …" may take a second line in that place.
    for (final k in ['copying', 'kept']) {
      expect(seen[k]!.$1.height, seen['idle']!.$1.height, reason: k);
      expect(seen[k]!.$3.height, seen['idle']!.$3.height, reason: k);
    }
  });

  testWidgets('the artist header is the pill alone: no name, count or takes line', (tester) async {
    await tester.pumpWidget(app(ArtistPageHeader(artist: artist, open: true, pick: null, onKeep: () {})));
    expect(texts(tester, 'browse-artist-header'), ['Keep a copy…']);
  });

  test('whether an artist page has a header at all', () {
    final done = KeepChoiceJob(job('artist', state: 'done', result: {
      'scope': 'artist',
      'songs': {'total': 3, 'copied': [], 'skipped': [], 'failed': []},
      'counts': {'total': 3, 'copied': 3, 'skipped': 0, 'failed': 0},
      'albums': [
        {'name': 'Borrowed Tapes', 'copied': 3},
      ],
    }));
    expect(ArtistPageHeader.showsFor(l, artist, open: true, pick: null), isTrue);
    expect(ArtistPageHeader.showsFor(l, artist, open: false, pick: null), isFalse, reason: 'closed, no copy');
    expect(ArtistPageHeader.showsFor(l, artist, open: false, pick: done), isTrue, reason: "an earlier copy's state");
    // They only appear on others' albums: no artist copy, and no line why.
    final guest = ArtistContext(server: null, name: 'Boukmanflow', albums: const [
      {'name': 'Night Market Sampler', 'album_artist': 'Various Artists', 'artists': ['Boukmanflow', 'ALM'], 'compilation': true},
    ]);
    expect(ArtistPageHeader.showsFor(l, guest, open: true, pick: null), isFalse);
    final various = ArtistContext(server: null, name: 'Various Artists', albums: const [
      {'name': 'Night Market Sampler', 'album_artist': 'Various Artists', 'artists': ['Boukmanflow', 'ALM'], 'compilation': true},
    ]);
    expect(ArtistPageHeader.showsFor(l, various, open: true, pick: null), isFalse);
  });

  testWidgets("the artist pill's hint says what the copy takes, in every state", (tester) async {
    final handle = tester.ensureSemantics();
    final one = ArtistContext(server: null, name: 'Boukmanflow', albums: const [
      {'name': 'Borrowed Tapes', 'album_artist': 'Boukmanflow', 'artists': ['Boukmanflow'], 'compilation': false},
    ]);
    await tester.pumpWidget(app(
      ArtistPageHeader(artist: one, open: true, pick: KeepChoiceJob(job('artist', state: 'done')), onKeep: () {}),
      width: 700,
    ));
    expect(tester.getSemantics(find.byKey(const ValueKey('browse-keep-pill'))),
        isSemantics(hint: 'Takes the 1 album credited to Boukmanflow'));
    handle.dispose();
  });
}
