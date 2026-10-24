// The page pill a connected server's album, artist and folder pages carry
// while browsing it (the phone spec's §4.1.1 and §5.1): every state's glyph
// and words — "Copying 2 of 3" counted in songs, another server's copy in
// grey, done is not kept — its accessible names, the narrow rule's measure,
// a long server name shortened before the verb ever is; with the gate closed
// an earlier copy as plain text and nothing else; the live line and the
// header's bar; and a menu row's sub-line (§5.5).

import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/l10n/app_localizations.dart';
import 'package:mstream_music/l10n/app_localizations_en.dart';
import 'package:mstream_music/l10n/localizations_delegates.dart';
import 'package:mstream_music/objects/discovery_plugins.dart';
import 'package:mstream_music/util/browse_keep_leads.dart' show KeepSubject;
import 'package:mstream_music/util/discover_badges.dart';
import 'package:mstream_music/widgets/browse_keep_entry.dart';
import 'package:mstream_music/widgets/browse_keep_pill.dart';
import 'package:mstream_music/widgets/keep_folder_glyph.dart';

const pb = {'id': 1, 'name': 'Stage Peer B'};
const pc = {'id': 4, 'name': 'Stage Peer C'};

final AppLocalizations l = AppLocalizationsEn();

int _id = 100;

DiscoveryJob job({
  String scope = 'album',
  String state = 'done',
  Map<String, Object> peer = pb,
  Map<String, dynamic>? result,
  double? progress,
  String? statusText,
  bool cancelRequested = false,
  Map<String, dynamic>? landing,
}) =>
    DiscoveryJob.fromServerMap({
      'id': _id++,
      'plugin': kCopyPlugin,
      'recommendation': {
        'source': 'federation',
        'peer': peer,
        'album': 'Borrowed Tapes',
        'albumArtist': 'Boukmanflow',
        'artist': 'Boukmanflow',
        'year': 2019,
        if (scope == 'folder') 'filepath': 'music/Boukmanflow/Borrowed Tapes',
        if (scope == 'folder') 'title': 'Borrowed Tapes',
      },
      'params': {
        if (scope != 'song') 'scope': scope,
        'destination': {
          'vpath': 'copies',
          'base': '',
          'layout': '{{ALBUMARTIST}}/{{ALBUM}}',
        },
        'landing': ?landing,
      },
      'state': state,
      'progress': progress,
      'statusText': statusText,
      'result': result,
      'cancelRequested': cancelRequested,
    })!;

Map<String, dynamic> many({int copied = 0, int skipped = 0, int failed = 0, String? stopped}) => {
      'scope': 'album',
      'songs': {'total': copied + skipped + failed, 'copied': [], 'skipped': [], 'failed': []},
      'counts': {'total': copied + skipped + failed, 'copied': copied, 'skipped': skipped, 'failed': failed},
      'stopped': stopped,
      'peer': pb,
    };

KeepPillForm formOf(DiscoveryJob? j, {bool other = false}) =>
    KeepPillForm.of(l, j == null ? null : KeepChoiceJob(j, fromOtherPeer: other));

Widget app(Widget child, {double textScale = 1, double width = 390}) => MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: appSupportedLocales,
      builder: (context, c) => MediaQuery(
        data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(textScale)),
        child: c!,
      ),
      home: Scaffold(body: Center(child: SizedBox(width: width, child: child))),
    );

void main() {
  group('the pill\'s forms', () {
    test('none, cancelled, nothing of theirs: "Keep a copy…" with the folder glyph', () {
      for (final j in [null, job(state: 'cancelled')]) {
        final f = formOf(j);
        expect([f.idle, f.words, f.glyph, f.settled, f.live], [true, 'Keep a copy…', KeepPillGlyph.keep, false, false]);
      }
    });

    test('live: Waiting · Starting… · Copying 2 of 3 (songs) · Copying · Stopping…, each with the live line', () {
      final cases = {
        job(state: 'queued'): ('Waiting', KeepPillGlyph.clock),
        job(state: 'running'): ('Starting…', KeepPillGlyph.ring),
        job(state: 'running', progress: 0.6, statusText: '2 of 3 songs · 4.1 MB · Late Train Verse'): ('Copying 2 of 3', KeepPillGlyph.dot),
        job(state: 'running', progress: 0.1, statusText: 'asking Stage Peer B'): ('Copying', KeepPillGlyph.dot),
        job(state: 'running', progress: 0.6, statusText: '2 of 3 songs', cancelRequested: true): ('Stopping…', KeepPillGlyph.dot),
      };
      for (final e in cases.entries) {
        final f = formOf(e.key);
        expect([f.words, f.glyph, f.live, f.settled], [e.value.$1, e.value.$2, true, false], reason: e.value.$1);
      }
      expect(formOf(cases.keys.elementAt(2)).fraction, 0.6, reason: 'the header bar follows the copy');
      expect(formOf(cases.keys.elementAt(4)).fraction, isNull, reason: 'no bar while it stops');
    });

    test("another server's live copy: \"Copying from Stage Peer C\", grey dot, the final states' edge, no live line", () {
      final f = formOf(job(state: 'running', peer: pc, statusText: '1 of 3 songs'), other: true);
      expect([f.words, f.glyph, f.settled, f.live, f.otherPeer], ['Copying from Stage Peer C', KeepPillGlyph.otherDot, true, false, 'Stage Peer C']);
    });

    test('done is not kept: In your collection · Already yours · Skipped · Stopped · Refused · Copy failed', () {
      final cases = {
        job(result: many(copied: 3)): ('In your collection', KeepPillGlyph.check),
        job(result: many(copied: 2, failed: 1)): ('In your collection', KeepPillGlyph.check),
        job(result: many(skipped: 3)): ('Already yours', KeepPillGlyph.owned),
        job(scope: 'song', result: {'skipped': 'exists', 'filepath': 'copies/x.mp3'}): ('Skipped', KeepPillGlyph.warning),
        job(result: many(copied: 1, stopped: 'quota')): ('Stopped', KeepPillGlyph.warning),
        job(result: many(stopped: 'refused')): ('Refused', KeepPillGlyph.warning),
        job(result: many(failed: 3)): ('Copy failed', KeepPillGlyph.error),
        job(state: 'failed'): ('Copy failed', KeepPillGlyph.error),
      };
      for (final e in cases.entries) {
        final f = formOf(e.key);
        expect([f.words, f.glyph, f.settled, f.live], [e.value.$1, e.value.$2, true, false], reason: e.value.$1);
      }
    });

    test('its accessible names: idle per scope, a state, a live copy and where it goes', () {
      expect(formOf(null).label(l, subject: KeepSubject.album, name: 'Borrowed Tapes'), 'Keep a copy of Borrowed Tapes…');
      expect(formOf(null).label(l, subject: KeepSubject.artist, name: 'Boukmanflow'), 'Keep a copy of albums by Boukmanflow…');
      expect(formOf(null).label(l, subject: KeepSubject.folder, name: 'Boukmanflow'), 'Keep a copy of the folder Boukmanflow…');
      expect(formOf(job(result: many(copied: 3))).label(l, subject: KeepSubject.album, name: 'Borrowed Tapes'),
          'Borrowed Tapes: In your collection. Open the copy');
      final live = job(state: 'running', progress: 0.6, statusText: '2 of 3 songs');
      expect(keepJobInto(l, live), 'copies/Boukmanflow/Borrowed Tapes');
      expect(formOf(live).label(l, subject: KeepSubject.album, name: 'Borrowed Tapes', into: keepJobInto(l, live)),
          'Borrowed Tapes: Copying 2 of 3, into copies/Boukmanflow/Borrowed Tapes. Open the copy');
    });

    test("where a copy goes, for speech: a folder's own landing, as on the server, its landed folder once it says", () {
      expect(keepJobInto(l, job(scope: 'folder', state: 'running', landing: {'vpath': 'copies', 'path': 'From Sam'})), 'copies/From Sam');
      expect(keepJobInto(l, job(scope: 'folder', state: 'running')), 'copies/Boukmanflow/Borrowed Tapes');
      expect(keepJobInto(l, job(scope: 'folder', result: {'scope': 'folder', 'folder': {'path': 'music/Boukmanflow/Borrowed Tapes', 'name': 'Borrowed Tapes', 'landed': 'copies/From Sam'}})),
          'copies/From Sam');
      expect(keepJobInto(l, job(scope: 'artist', state: 'running')), 'copies/Boukmanflow/one folder per album');
    });
  });

  group('the narrow rule', () {
    // The test font draws every glyph a full em wide: "Copying from Stage
    // Peer B", the widest of the three, is 25 × 14 = 350 pt, plus the
    // pill's 54 pt of chrome.
    test('the widest of its words and its chrome fit the column, never above 1.3×', () {
      expect(KeepPagePill.fitsBeside(l, 404, TextScaler.noScaling, 'Stage Peer B'), isTrue);
      expect(KeepPagePill.fitsBeside(l, 403, TextScaler.noScaling, 'Stage Peer B'), isFalse);
      expect(KeepPagePill.fitsBeside(l, 404, const TextScaler.linear(1.3), 'Stage Peer B'), isFalse,
          reason: '1.3× of 350 no longer fits');
      expect(KeepPagePill.fitsBeside(l, 2000, const TextScaler.linear(1.31), 'Stage Peer B'), isFalse);
      expect(KeepPagePill.fitsBeside(l, 2000, const TextScaler.linear(1.3), 'Stage Peer B'), isTrue);
    });

    testWidgets("a long server's name is shortened with \"…\" before the verb ever is", (tester) async {
      await tester.pumpWidget(app(const SizedBox()));
      const long = 'Stage Peer B (studio basement, :3992) and a very long tail that never ends here';
      final short = KeepPagePill.fitOther(l, long, 200, TextScaler.noScaling);
      expect(short, endsWith('…'));
      expect(short.length, lessThan(long.length));
      expect(l.discoverJobFromOther(short), startsWith('Copying from '));
      expect(KeepPagePill.fitOther(l, 'Stage Peer C', 200, TextScaler.noScaling), 'Stage Peer C');
    });

    testWidgets('the cut it finds by halving is the longest that fits — what a character at a time finds', (tester) async {
      await tester.pumpWidget(app(const SizedBox()));
      bool fits(String s, double w) {
        final p = TextPainter(
          text: TextSpan(text: s, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, height: 1.3, letterSpacing: 0)),
          textDirection: TextDirection.ltr,
          maxLines: 2,
        )..layout(maxWidth: w);
        final over = p.didExceedMaxLines;
        p.dispose();
        return !over;
      }

      const peer = 'Stage Peer B (studio basement, :3992)';
      for (final w in [120.0, 200.0, 260.0, 330.0]) {
        var linear = '…';
        for (var n = peer.length - 1; n > 0; n--) {
          final s = '${peer.substring(0, n).trimRight()}…';
          if (fits(l.discoverJobFromOther(s), w)) {
            linear = s;
            break;
          }
        }
        if (fits(l.discoverJobFromOther(peer), w)) linear = peer;
        expect(KeepPagePill.fitOther(l, peer, w, TextScaler.noScaling), linear, reason: '$w');
      }
    });
  });

  group('the pill on a page', () {
    testWidgets('idle: a 44 pt button named for what it keeps, opaque, its folder glyph; a tap opens the sheet', (tester) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(app(KeepPageAction(
        open: true,
        pick: null,
        subject: KeepSubject.artist,
        name: 'Boukmanflow',
        peerName: 'Stage Peer B',
        hint: 'Takes the 3 albums credited to Boukmanflow',
        onTap: () => taps++,
      )));
      expect(find.text('Keep a copy…'), findsOneWidget);
      expect(find.byType(KeepFolderGlyph), findsOneWidget);
      expect(tester.getSize(find.byKey(const ValueKey('browse-keep-pill'))).height, greaterThanOrEqualTo(44));
      expect(
          tester.getSemantics(find.byKey(const ValueKey('browse-keep-pill'))),
          isSemantics(
            label: 'Keep a copy of albums by Boukmanflow…',
            hint: 'Takes the 3 albums credited to Boukmanflow',
            isButton: true,
          ));
      expect(find.byKey(const ValueKey('browse-keep-live-line')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('browse-keep-pill')));
      expect(taps, 1);
      tester.semantics.tap(find.semantics.byLabel('Keep a copy of albums by Boukmanflow…'));
      expect(taps, 2, reason: 'a screen reader activates it too');
      handle.dispose();
    });

    testWidgets('live: the line under it says copies keep going; the pill keeps its height', (tester) async {
      await tester.pumpWidget(app(KeepPageAction(
        open: true,
        pick: KeepChoiceJob(job(state: 'running', progress: 0.6, statusText: '2 of 3 songs')),
        subject: KeepSubject.album,
        name: 'Borrowed Tapes',
        peerName: 'Stage Peer B',
        album: 'Borrowed Tapes',
        onTap: () {},
      )));
      expect(find.text('Copying 2 of 3'), findsOneWidget);
      expect(find.text('Copies keep going if you leave this page or Stage Peer B.'), findsOneWidget);
      expect(tester.getSize(find.byKey(const ValueKey('browse-keep-pill'))).height, 44);
    });

    testWidgets('gate closed: an earlier copy as plain text (not a button), another server\'s or none: nothing', (tester) async {
      final handle = tester.ensureSemantics();
      Widget closed(KeepChoiceJob? pick) => app(KeepPageAction(
            open: false,
            pick: pick,
            subject: KeepSubject.album,
            name: 'Borrowed Tapes',
            peerName: 'Stage Peer B',
            onTap: () {},
          ));
      await tester.pumpWidget(closed(KeepChoiceJob(job(result: many(copied: 3)))));
      expect(find.byKey(const ValueKey('browse-keep-pill')), findsNothing);
      expect(find.text('In your collection'), findsOneWidget);
      expect(tester.getSemantics(find.byKey(const ValueKey('browse-keep-plain'))),
          isSemantics(label: 'Borrowed Tapes: In your collection', isButton: false));
      expect(KeepPageAction.shows(l, false, KeepChoiceJob(job(result: many(copied: 3)))), isTrue);

      await tester.pumpWidget(closed(KeepChoiceJob(job(state: 'running', peer: pc), fromOtherPeer: true)));
      expect(find.byKey(const ValueKey('browse-keep-plain')), findsNothing);
      await tester.pumpWidget(closed(null));
      expect(find.byKey(const ValueKey('browse-keep-plain')), findsNothing);
      expect(KeepPageAction.shows(l, false, null), isFalse);
      expect(KeepPageAction.shows(l, false, KeepChoiceJob(job(state: 'cancelled'))), isFalse);
      handle.dispose();
    });

    testWidgets('the reserved slot holds 44 pt and says nothing; the bar is drawn, never read', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(app(const Column(mainAxisSize: MainAxisSize.min, children: [
        KeepReservedSlot(),
        SizedBox(width: 300, child: KeepHeaderBar(fraction: 0.4)),
      ])));
      expect(tester.getSize(find.byKey(const ValueKey('browse-keep-reserved'))).height, 44);
      final bar = tester.widget<LinearProgressIndicator>(find.byType(LinearProgressIndicator));
      expect([bar.value, bar.minHeight], [0.4, 3]);
      expect(find.bySemanticsLabel(RegExp('.')), findsNothing);
      handle.dispose();
    });

    testWidgets('2.0× text: the pill takes the full width, its words wrap to two lines, nothing overflows', (tester) async {
      await tester.pumpWidget(app(
        KeepPageAction(
          open: true,
          pick: KeepChoiceJob(job(state: 'running', peer: pc), fromOtherPeer: true),
          subject: KeepSubject.album,
          name: 'Borrowed Tapes',
          peerName: 'Stage Peer B',
          fullWidth: true,
          onTap: () {},
        ),
        textScale: 2,
        width: 328,
      ));
      expect(tester.takeException(), isNull);
      expect(tester.getSize(find.byKey(const ValueKey('browse-keep-pill'))).width, 328);
      final text = tester.renderObject<RenderParagraph>(find.textContaining('Copying from'));
      expect(text.size.height, greaterThan(text.text.style!.fontSize! * 2 * 1.2), reason: 'two lines');
    });
  });

  group("a menu row's sub-line", () {
    test('the album copy running first; then the item\'s own copy; else where copies go', () {
      final album = job(state: 'running', progress: 0.6, statusText: '2 of 3 songs');
      expect(keepMenuSub(l, peer: 'Stage Peer B', albumLive: (name: 'Borrowed Tapes', job: album)), 'Copying Borrowed Tapes · 2 of 3');
      expect(keepMenuSub(l, peer: 'Stage Peer B', albumLive: (name: 'Borrowed Tapes', job: job(state: 'running'))), 'Copying Borrowed Tapes');
      expect(keepMenuSub(l, peer: 'Stage Peer B', own: const CopyMarker(CopyMarkerKind.waiting)), 'Waiting for a free slot');
      expect(keepMenuSub(l, peer: 'Stage Peer B', own: const CopyMarker(CopyMarkerKind.copying, done: 2, total: 3)), 'Copying 2 of 3');
      expect(keepMenuSub(l, peer: 'Stage Peer B', own: const CopyMarker(CopyMarkerKind.inCollection)), 'In your collection');
      expect(keepMenuSub(l, peer: 'Stage Peer B', own: const CopyMarker(CopyMarkerKind.refused)), 'Refused');
      expect(keepMenuSub(l, peer: 'Stage Peer B', own: const CopyMarker(CopyMarkerKind.failed)), 'Copy failed');
      expect(keepMenuSub(l, peer: 'Stage Peer B'), 'To your server, from Stage Peer B');
      expect(keepMenuSub(l, peer: 'Stage Peer B', albumLive: (name: 'Borrowed Tapes', job: job(result: many(copied: 3)))),
          'To your server, from Stage Peer B', reason: 'a finished album copy is not "copying"');
    });
  });
}
