// screens/discovery/peer_recs_band.dart — the Peer Recommendations page's
// live preview band (mStream docs/peer-recommendations-plan.md §2 item 14,
// §4.2 "Band"; boards M:105 and V:167): 64 tall at 1.0 and at least 78 once
// the text is scaled; every control a 44 px target, the attribution's link
// included, which reaches only a few pixels into the title; the attribution
// drawn verbatim and only once resolved, a link
// only when https; ⏭ off without a next lead; each clip status's button and
// label; and the hairline that follows the clip without rebuilding the band.

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/l10n/localizations_delegates.dart';
import 'package:mstream_music/objects/discovery.dart';
import 'package:mstream_music/screens/discovery/keep_copy_ui.dart';
import 'package:mstream_music/screens/discovery/peer_recs_band.dart';
import 'package:mstream_music/theme/velvet_theme.dart';
import 'package:mstream_music/util/peer_recs_colours.dart';
import 'package:mstream_music/util/peer_recs_rules.dart';
import 'package:mstream_music/widgets/generated_tile.dart';

import 'peer_recs_fixtures.dart';

void main() {
  final dark = paletteFor(AppTheme.dark);
  tearDown(() => VelvetColors.setActive(dark));

  // Signal Fires · Paper Lantern (Kitchen Radio's, tile 'P' on hue 39).
  final lead = parseLeads(tasteJson())[2];
  final deezer = Uri.parse('https://www.deezer.com/track/3');

  late List<String> calls;
  late List<Uri> links;
  setUp(() {
    calls = [];
    links = [];
  });

  ValueNotifier<PeerClipProgress> progressAt(int position, [int length = 30]) =>
      ValueNotifier((
        position: Duration(seconds: position),
        length: Duration(seconds: length),
      ));

  PeerRecsBand band({
    DiscoveryLead? of,
    Uri? art,
    String? attribution = 'Preview from Deezer',
    Uri? link,
    bool noLink = false,
    PeerClipStatus status = PeerClipStatus.playing,
    ValueListenable<PeerClipProgress>? progress,
    bool hasNext = true,
  }) =>
      PeerRecsBand(
        lead: of ?? lead,
        art: art,
        attribution: attribution,
        link: noLink ? null : (link ?? deezer),
        status: status,
        progress: progress ?? progressAt(12),
        providerLabel: 'Deezer',
        hasNext: hasNext,
        onToggle: () => calls.add('toggle'),
        onNext: () => calls.add('next'),
        onClose: () => calls.add('close'),
        onLink: links.add,
      );

  // The band as the view docks it: the last child of the frame's column.
  Future<void> pumpBand(
    WidgetTester t,
    PeerRecsBand b, {
    double width = 390,
    double height = 844,
    double textScale = 1,
  }) async {
    t.view.physicalSize = Size(width * 3, height * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MaterialApp(
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: appSupportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: Column(children: [const Expanded(child: SizedBox()), b]),
      ),
    ));
  }

  final toggle = find.byKey(kPeerBandToggleKey);
  final next = find.byKey(kPeerBandNextKey);
  final close = find.byKey(kPeerBandCloseKey);
  final linkFinder = find.byKey(kPeerBandLinkKey);

  group(
      '64 tall; every target ≥ 44; attribution verbatim, linked only when '
      'https; ⏭ disabled without next; each status\'s button and label', () {
    testWidgets('64 tall at 1.0, full width, raised; at least 78 at 1.3',
        (t) async {
      await pumpBand(t, band());
      expect(t.getSize(find.byType(PeerRecsBand)), const Size(390, 64));
      expect(
          t
              .widget<Material>(find
                  .descendant(
                      of: find.byType(PeerRecsBand),
                      matching: find.byType(Material))
                  .first)
              .color,
          VelvetColors.raised);
      // The cover: 44, radius 7, the tile's letter at 20.
      final cover = t.widget<GeneratedTile>(find.byKey(kPeerBandCoverKey));
      expect(cover.size, 44);
      expect(cover.radius, VelvetColors.radiusSmall);
      expect(cover.letterSize, 20);
      expect(cover.hue, 39);
      expect(cover.letter, 'P');
      // Title, then artist, one line each.
      final title = t.widget<Text>(find.text('Signal Fires'));
      expect(title.maxLines, 1);
      expect(title.style!.fontSize, 15);
      expect(title.style!.color, VelvetColors.textPrimary);
      final artist = t.widget<Text>(find.text('Paper Lantern'));
      expect(artist.maxLines, 1);
      expect(artist.style!.fontSize, 13);
      expect(artist.style!.color, VelvetColors.textSecondary);

      await pumpBand(t, band(), textScale: 1.3);
      expect(t.getSize(find.byType(PeerRecsBand)).height,
          greaterThanOrEqualTo(78));
      expect(t.getSize(find.byKey(kPeerBandCoverKey)), const Size(44, 44));
    });

    testWidgets('every target is 44 at every scale, the link included',
        (t) async {
      for (final scale in [1.0, 1.3, 2.0]) {
        await pumpBand(t, band(), textScale: scale);
        for (final f in [toggle, next, close]) {
          expect(t.getSize(f), const Size(44, 44), reason: '$f at $scale');
        }
        expect(t.getSize(linkFinder).height, greaterThanOrEqualTo(44),
            reason: 'link at $scale');
        // The link's box holds its words.
        final words = t.getRect(find.text('Preview from Deezer'));
        final hit = t.getRect(linkFinder);
        expect(hit.contains(words.center), isTrue, reason: '$scale');
        expect(hit.bottom, greaterThanOrEqualTo(words.bottom));
        // The band holds the link's box.
        final whole = t.getRect(find.byType(PeerRecsBand));
        expect(hit.top, greaterThanOrEqualTo(whole.top));
        expect(hit.bottom, lessThanOrEqualTo(whole.bottom));
      }
    });

    testWidgets('attribution verbatim, linked only when https', (t) async {
      final semantics = t.ensureSemantics();
      // Verbatim: never trimmed, folded or translated.
      const odd = '  Preview  from DEEZER · 30 s ';
      await pumpBand(t, band(attribution: odd));
      expect(find.text(odd), findsOneWidget);
      final words = t.widget<Text>(find.text(odd));
      expect(words.style!.fontSize, 12);
      expect(words.style!.color, VelvetColors.helper);
      expect(words.style!.decoration, TextDecoration.underline);
      expect(t.getSemantics(linkFinder),
          isSemantics(label: odd, isLink: true, hasTapAction: true));
      await t.tap(find.text(odd));
      expect(links, [deezer]);

      // The hit area reaches above the line (the board pads it 22 up).
      await pumpBand(t, band(attribution: 'Deezer'));
      final line = t.getRect(find.text('Deezer'));
      await t.tapAt(Offset(line.center.dx, line.top - 20));
      expect(links, [deezer, deezer]);
      // …but no wider than its words: the rest of the column is no link.
      await t.tapAt(Offset(line.right + 30, line.center.dy));
      expect(links, hasLength(2));

      // http, another scheme, or none: the words alone, no link.
      for (final (what, b) in [
        ('http', band(link: Uri.parse('http://www.deezer.com/track/3'))),
        ('itms', band(link: Uri.parse('itms://music.apple.com/x'))),
        ('none', band(noLink: true)),
      ]) {
        await pumpBand(t, b);
        expect(find.text('Preview from Deezer'), findsOneWidget, reason: what);
        expect(linkFinder, findsNothing, reason: what);
        expect(
            t.widget<Text>(find.text('Preview from Deezer')).style!.decoration,
            isNull,
            reason: what);
        await t.tap(find.text('Preview from Deezer'));
        expect(links, hasLength(2), reason: what);
      }
      semantics.dispose();
    });

    testWidgets('the link does not reach over the title', (t) async {
      for (final scale in [1.0, 1.1, 1.2, 1.3, 2.0]) {
        final why = 'text $scale';
        links.clear();
        await pumpBand(t, band(), textScale: scale);
        final whole = t.getRect(find.byType(PeerRecsBand));
        // The column is padded only into room the band already has: it
        // stays 64 at 1.0 and 78 while the text still fits its 62 px row.
        if (scale == 1.0) expect(whole.height, 64, reason: why);
        if (scale == 1.1 || scale == 1.2) {
          expect(whole.height, moreOrLessEquals(78), reason: why);
        }
        final title = t.getRect(find.text('Signal Fires'));
        final words = t.getRect(find.text('Preview from Deezer'));
        final hit = t.getRect(linkFinder);
        expect(hit.height, greaterThanOrEqualTo(44), reason: why);
        expect(hit.bottom, lessThanOrEqualTo(whole.bottom), reason: why);
        // A few pixels into the title at most, as far as the board's 22 px
        // pad over the line reaches (M:105).
        expect(hit.top, greaterThanOrEqualTo(title.bottom - 6.5),
            reason: '$why: $hit over the title $title');
        // A tap on the title stays in the app…
        for (final dy in [1.0, 4.0, 8.0, title.height - 7]) {
          await t.tapAt(Offset(title.left + 10, title.top + dy));
        }
        expect(links, isEmpty, reason: why);
        // …and one on the words, or just under them, follows the link.
        await t.tap(find.text('Preview from Deezer'));
        expect(links, [deezer], reason: why);
        final under =
            words.bottom + 6 < hit.bottom ? words.bottom + 6 : hit.bottom - 1;
        await t.tapAt(Offset(words.left + 10, under));
        expect(links, [deezer, deezer], reason: why);
      }
    });

    testWidgets('the attribution shows only once the clip resolved',
        (t) async {
      for (final status in [PeerClipStatus.resolving, PeerClipStatus.waiting]) {
        await pumpBand(t, band(status: status));
        expect(find.text('Preview from Deezer'), findsNothing,
            reason: '$status');
        expect(linkFinder, findsNothing, reason: '$status');
      }
      for (final status in [
        PeerClipStatus.loading,
        PeerClipStatus.playing,
        PeerClipStatus.paused,
      ]) {
        await pumpBand(t, band(status: status));
        expect(find.text('Preview from Deezer'), findsOneWidget,
            reason: '$status');
      }
      // Not resolved yet: no words at all, and none for an empty one — the
      // cover's letter, the title and the artist only.
      await pumpBand(t, band(attribution: null));
      expect(linkFinder, findsNothing);
      expect(find.byType(Text), findsNWidgets(3));
      await pumpBand(t, band(attribution: ''));
      expect(linkFinder, findsNothing);
      expect(find.byType(Text), findsNWidgets(3));
    });

    testWidgets('⏭ disabled without next', (t) async {
      final semantics = t.ensureSemantics();
      await pumpBand(t, band(hasNext: false));
      expect(
          t.getSemantics(next),
          isSemantics(
              label: 'Next preview',
              isButton: true,
              hasEnabledState: true,
              isEnabled: false,
              hasTapAction: false));
      final glyph =
          t.widget<Icon>(find.descendant(of: next, matching: find.byType(Icon)));
      expect(glyph.icon, Icons.skip_next);
      expect(glyph.size, 26);
      expect(glyph.color, VelvetColors.textDim);
      await t.tap(next);
      expect(calls, isEmpty);

      await pumpBand(t, band());
      expect(
          t.getSemantics(next),
          isSemantics(
              label: 'Next preview',
              isButton: true,
              hasEnabledState: true,
              isEnabled: true,
              hasTapAction: true));
      expect(
          t
              .widget<Icon>(
                  find.descendant(of: next, matching: find.byType(Icon)))
              .color,
          VelvetColors.textPrimary);
      await t.tap(next);
      expect(calls, ['next']);
      semantics.dispose();
    });

    testWidgets('each status\'s button and label; ✕ closes', (t) async {
      final semantics = t.ensureSemantics();
      for (final (status, icon, label) in [
        (PeerClipStatus.playing, Icons.pause, 'Pause preview of Signal Fires'),
        (PeerClipStatus.paused, Icons.play_arrow, 'Preview Signal Fires'),
        (PeerClipStatus.resolving, null, 'Stop the Deezer preview'),
        (PeerClipStatus.waiting, null, 'Stop the Deezer preview'),
        (PeerClipStatus.loading, null, 'Stop the Deezer preview'),
      ]) {
        calls.clear();
        await pumpBand(t, band(status: status));
        if (icon == null) {
          expect(find.descendant(of: toggle, matching: find.byType(KeepRing)),
              findsOneWidget,
              reason: '$status');
          expect(find.descendant(of: toggle, matching: find.byType(Icon)),
              findsNothing);
        } else {
          final glyph = t.widget<Icon>(
              find.descendant(of: toggle, matching: find.byType(Icon)));
          expect(glyph.icon, icon, reason: '$status');
          expect(glyph.color, VelvetColors.onPrimary);
        }
        // A 36 px amber disc inside the 44 px target.
        final disc = find.descendant(of: toggle, matching: find.byType(Container));
        expect(t.getSize(disc.first), const Size(36, 36));
        expect((t.widget<Container>(disc.first).decoration! as BoxDecoration)
            .color, VelvetColors.primary);
        expect(
            t.getSemantics(toggle),
            isSemantics(
                label: label,
                isButton: true,
                hasEnabledState: true,
                isEnabled: true,
                hasTapAction: true),
            reason: '$status');
        await t.tap(toggle);
        expect(calls, ['toggle'], reason: '$status');
      }

      calls.clear();
      expect(
          t.getSemantics(close),
          isSemantics(
              label: 'Close',
              isButton: true,
              isEnabled: true,
              hasTapAction: true));
      final x =
          t.widget<Icon>(find.descendant(of: close, matching: find.byType(Icon)));
      expect(x.icon, Icons.close);
      expect(x.size, 22);
      expect(x.color, VelvetColors.textSecondary);
      await t.tap(close);
      expect(calls, ['close']);
      semantics.dispose();
    });

    testWidgets('earned art on the cover; a lead with no tile is plain',
        (t) async {
      final art = Uri.parse('https://is1-ssl.mzstatic.example/100x100bb.jpg');
      await pumpBand(t, band(art: art));
      expect(t.widget<GeneratedTile>(find.byKey(kPeerBandCoverKey)).art, art);

      final bare = parseLeads(tasteJson(leads: [leadJson(title: 'Bare')]))[0];
      await pumpBand(t, band(of: bare));
      final cover = t.widget<GeneratedTile>(find.byKey(kPeerBandCoverKey));
      expect(cover.hue, isNull);
      expect(cover.letter, '');
    });
  });

  testWidgets('the hairline follows progress without rebuilding the band',
      (t) async {
    final progress = progressAt(12);
    await pumpBand(t, band(progress: progress));
    final hairline = find.byKey(kPeerBandHairlineKey);
    Finder fill() =>
        find.descendant(of: hairline, matching: find.byType(ColoredBox));

    // 2 px over the top edge: the border-coloured track, the ink fill.
    final whole = t.getRect(find.byType(PeerRecsBand));
    expect(t.getRect(hairline), Rect.fromLTWH(0, whole.top, 390, 2));
    expect(t.getSize(fill()), const Size(156, 2));
    expect(t.widget<ColoredBox>(fill()).color, peerInk());
    final track = find.ancestor(of: hairline, matching: find.byType(ColoredBox));
    expect(t.widget<ColoredBox>(track.first).color, VelvetColors.border);
    expect(
        find.ancestor(of: hairline, matching: find.byType(ExcludeSemantics)),
        findsWidgets);

    // A tick moves the fill; the band's own widgets are the same instances,
    // so only the hairline was rebuilt.
    final title = t.widget(find.text('Signal Fires'));
    final cover = t.widget(find.byKey(kPeerBandCoverKey));
    progress.value = (
      position: const Duration(seconds: 24),
      length: const Duration(seconds: 30),
    );
    await t.pump();
    expect(t.getSize(fill()), const Size(312, 2));
    expect(identical(t.widget(find.text('Signal Fires')), title), isTrue);
    expect(identical(t.widget(find.byKey(kPeerBandCoverKey)), cover), isTrue);

    // No length yet: empty; past the end: full.
    progress.value = (position: const Duration(seconds: 3), length: Duration.zero);
    await t.pump();
    expect(
        t.widget<FractionallySizedBox>(hairline).widthFactor, 0);
    progress.value = (
      position: const Duration(seconds: 40),
      length: const Duration(seconds: 30),
    );
    await t.pump();
    expect(t.widget<FractionallySizedBox>(hairline).widthFactor, 1);
    expect(t.getSize(fill()), const Size(390, 2));

    // The hairline never takes a tap from what it overlaps.
    expect(
        find.ancestor(of: hairline, matching: find.byType(IgnorePointer)),
        findsWidgets);
  });
}
