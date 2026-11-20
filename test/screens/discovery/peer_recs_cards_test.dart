// screens/discovery/peer_recs_cards.dart — the Peer Recommendations page's
// grid, footer, states and skeleton (mStream
// docs/peer-recommendations-plan.md §4.2 "Drawing", §2 items 10, 14, 18 and
// 24; boards Main M:43-58, States S:43-152 and Variants V:62-169): the card
// width rule and its 240 cap, the circle 8 in from the tile's bottom-right,
// a card tap that only opens and a circle that only plays, the muted and
// hidden circles, the circle's round shadow and its ripple kept in the
// circle, the live title in ink, earned art and the bare tile, the
// two-line text at 1.3 with nothing else scaling, the footer's two pills,
// the word states, the six-card skeleton, and no overflow on small phones
// at either text size in either theme.

import 'dart:math' as math;
import 'dart:typed_data' show ByteData;
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart'
    show RenderRepaintBoundary, debugDisableShadows;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/l10n/localizations_delegates.dart';
import 'package:mstream_music/objects/discovery.dart';
import 'package:mstream_music/screens/discovery/discovery_widgets.dart'
    show DiscoveryPill;
import 'package:mstream_music/screens/discovery/keep_copy_ui.dart';
import 'package:mstream_music/screens/discovery/peer_recs_band.dart';
import 'package:mstream_music/screens/discovery/peer_recs_cards.dart';
import 'package:mstream_music/theme/velvet_theme.dart';
import 'package:mstream_music/util/peer_recs_colours.dart';
import 'package:mstream_music/util/peer_recs_rules.dart';
import 'package:mstream_music/widgets/generated_tile.dart';

import 'peer_recs_fixtures.dart';

void main() {
  final dark = paletteFor(AppTheme.dark);
  final light = paletteFor(AppTheme.light);
  tearDown(() => VelvetColors.setActive(dark));

  final leads = parseLeads(tasteJson());

  Future<void> pumpPage(
    WidgetTester t,
    Widget body, {
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
      home: Scaffold(body: body),
    ));
  }

  PeerLeadGrid grid(
    List<DiscoveryLead> list, {
    PeerCircle Function(DiscoveryLead)? circleOf,
    Uri? Function(DiscoveryLead)? artOf,
    bool Function(DiscoveryLead)? isLive,
    void Function(DiscoveryLead)? onOpen,
    void Function(DiscoveryLead)? onPlay,
  }) =>
      PeerLeadGrid(
        leads: list,
        circleOf: circleOf ?? (_) => PeerCircle.idle,
        artOf: artOf ?? (_) => null,
        isLive: isLive ?? (_) => false,
        onOpen: onOpen ?? (_) {},
        onPlay: onPlay ?? (_) {},
        providerLabel: 'Deezer',
      );

  // The grid as the view lays it: a box in a sliver list.
  Widget scrolled(Widget child) => CustomScrollView(
        slivers: [SliverToBoxAdapter(child: child)],
      );

  Finder card(int i) => find.byKey(peerCardKey(i));
  Finder tileOf(int i) =>
      find.descendant(of: card(i), matching: find.byType(GeneratedTile));
  Finder circleOf(int i) =>
      find.descendant(of: card(i), matching: find.byKey(kPeerCardPlayKey));

  group('cards and grid', () {
    testWidgets('card width 175/167.5/160; capped at 240 and centred at 1024',
        (t) async {
      for (final (w, cardW) in [(390.0, 175.0), (375.0, 167.5), (360.0, 160.0)]) {
        expect(peerCardWidth(w), cardW);
        await pumpPage(t, scrolled(grid(leads)), width: w);
        final first = t.getRect(tileOf(0));
        final second = t.getRect(tileOf(1));
        expect(first.size, Size(cardW, cardW), reason: '$w');
        expect(first.left, 14, reason: '$w');
        expect(second.left, 14 + cardW + 12, reason: '$w');
        expect(second.right, w - 14, reason: '$w');
        // Rows 14 apart, row-major.
        expect(t.getTopLeft(card(2)).dy, t.getBottomLeft(card(0)).dy + 14);
        expect(t.getTopLeft(card(2)).dx, first.left);
      }
      // A card at 1.0: the tile, 7 + 20 for the title, 16 for the artist
      // (218 at 175, M:44).
      await pumpPage(t, scrolled(grid(leads)));
      expect(t.getSize(card(0)), const Size(175, 218));

      // The cap: 240 a card, the grid centred (plan §2 item 24).
      expect(peerCardWidth(1024), 240);
      expect(peerGridInset(1024), 266);
      await pumpPage(t, scrolled(grid(leads)), width: 1024, height: 768);
      expect(t.getRect(tileOf(0)).size, const Size(240, 240));
      expect(t.getRect(tileOf(0)).left, 266);
      expect(t.getRect(tileOf(1)).right, 1024 - 266);
    });

    testWidgets('an odd lead count leaves the last row\'s right cell empty',
        (t) async {
      await pumpPage(t, scrolled(grid(leads.take(3).toList())));
      expect(find.byType(PeerLeadCard), findsNWidgets(3));
      expect(t.getTopLeft(card(2)).dx, 14);
    });

    testWidgets('the circle sits 8 in from the tile\'s bottom-right',
        (t) async {
      for (final (w, cardW, top) in [
        (390.0, 175.0, 123.0),
        (375.0, 167.5, 115.5),
        (360.0, 160.0, 108.0),
      ]) {
        await pumpPage(t, scrolled(grid(leads)), width: w);
        final tile = t.getRect(tileOf(0));
        final circle = t.getRect(circleOf(0));
        expect(circle.size, const Size(44, 44), reason: '$w');
        expect(circle.right, tile.right - 8, reason: '$w');
        expect(circle.bottom, tile.bottom - 8, reason: '$w');
        expect(circle.top - tile.top, top, reason: '$w');
        expect(tile.width, cardW);
      }
    });

    testWidgets('a card tap calls onOpen only; the circle calls onPlay only',
        (t) async {
      final opened = <String>[];
      final played = <String>[];
      await pumpPage(
          t,
          scrolled(grid(leads,
              onOpen: (l) => opened.add(l.title),
              onPlay: (l) => played.add(l.title))));

      await t.tap(find.text('Salt Road'));
      await t.tap(find.text('Hollow Coast').first);
      // The tile, away from the circle.
      await t.tapAt(t.getTopLeft(tileOf(1)) + const Offset(20, 20));
      expect(opened, ['Salt Road', 'Salt Road', 'Breakwater']);
      expect(played, isEmpty);

      await t.tap(circleOf(0));
      await t.tap(circleOf(1));
      expect(played, ['Salt Road', 'Breakwater']);
      expect(opened, hasLength(3));
    });

    testWidgets('the card is one button named by its title and artist',
        (t) async {
      final semantics = t.ensureSemantics();
      await pumpPage(t, scrolled(grid(leads)));
      expect(
          t.getSemantics(find.descendant(
              of: card(0), matching: find.byKey(kPeerCardOpenKey))),
          isSemantics(
              label: 'Salt Road\nHollow Coast',
              isButton: true,
              hasTapAction: true));
      semantics.dispose();
    });

    testWidgets('each circle state\'s glyph and label', (t) async {
      final semantics = t.ensureSemantics();
      final played = <String>[];
      for (final (state, icon, label) in [
        (PeerCircle.idle, Icons.play_arrow, 'Preview Salt Road'),
        (PeerCircle.playing, Icons.pause, 'Pause preview of Salt Road'),
        (PeerCircle.paused, Icons.play_arrow, 'Preview Salt Road'),
        (PeerCircle.busy, null, 'Stop the Deezer preview'),
      ]) {
        await pumpPage(
            t,
            scrolled(grid(leads,
                circleOf: (_) => state, onPlay: (l) => played.add('$state'))));
        final circle = circleOf(0);
        if (icon == null) {
          expect(find.descendant(of: circle, matching: find.byType(KeepRing)),
              findsOneWidget);
          expect(find.descendant(of: circle, matching: find.byType(Icon)),
              findsNothing);
        } else {
          final glyph = t.widget<Icon>(
              find.descendant(of: circle, matching: find.byType(Icon)));
          expect(glyph.icon, icon, reason: '$state');
          expect(glyph.color, VelvetColors.onPrimary);
        }
        expect(
            t.getSemantics(circle),
            isSemantics(
                label: label,
                isButton: true,
                hasEnabledState: true,
                isEnabled: true,
                hasTapAction: true),
            reason: '$state');
        await t.tap(circle);
      }
      expect(played, [
        '${PeerCircle.idle}',
        '${PeerCircle.playing}',
        '${PeerCircle.paused}',
        '${PeerCircle.busy}',
      ]);
      semantics.dispose();
    });

    testWidgets('muted circle disabled; hidden draws none', (t) async {
      final semantics = t.ensureSemantics();
      final opened = <String>[];
      final played = <String>[];
      await pumpPage(
          t,
          scrolled(grid(leads,
              circleOf: (l) =>
                  l.title == 'Salt Road' ? PeerCircle.muted : PeerCircle.idle,
              onOpen: (l) => opened.add(l.title),
              onPlay: (l) => played.add(l.title))));

      // Drawn, never hidden (plan [review]): raised, a border2 ring, the
      // quiet glyph.
      final circle = circleOf(0);
      expect(circle, findsOneWidget);
      final disc = t.widget<Container>(
          find.descendant(of: circle, matching: find.byType(Container)));
      final deco = disc.decoration! as BoxDecoration;
      expect(deco.color, VelvetColors.raised);
      expect((deco.border! as Border).top.color, VelvetColors.border2);
      expect((deco.border! as Border).top.width, 1);
      expect(
          t
              .widget<Icon>(
                  find.descendant(of: circle, matching: find.byType(Icon)))
              .color,
          VelvetColors.helper);
      expect(
          t.getSemantics(circle),
          isSemantics(
              label: 'Preview Salt Road',
              hint: 'No preview',
              isButton: true,
              hasEnabledState: true,
              isEnabled: false,
              hasTapAction: false));

      // Inert: neither plays nor opens the card under it.
      await t.tap(circle);
      expect(played, isEmpty);
      expect(opened, isEmpty);
      // Its neighbour still plays.
      await t.tap(circleOf(1));
      expect(played, ['Breakwater']);

      // No provider: no circle anywhere (V:62-82); the cards still open.
      await pumpPage(
          t,
          scrolled(grid(leads,
              circleOf: (_) => PeerCircle.hidden,
              onOpen: (l) => opened.add(l.title))));
      expect(find.byKey(kPeerCardPlayKey), findsNothing);
      await t.tapAt(t.getRect(tileOf(0)).bottomRight - const Offset(30, 30));
      expect(opened, ['Salt Road']);
      semantics.dispose();
    });

    testWidgets("the circle's shadow is round, never cut to its 44 px box",
        (t) async {
      // A flat tile (no letter), so only the shadow darkens it.
      final lead = parseLeads(tasteJson(leads: [
        leadJson(title: 'Round', artist: 'Disc', tile: tileJson('k', 203, '')),
      ])).single;
      const shot = ValueKey('peer-circle-shot');
      // The test binding draws shadows as flat discs; the device blurs them,
      // and the blur is what the old 44 px clip cut into a square.
      debugDisableShadows = false;
      try {
        for (final palette in [light, dark]) {
          VelvetColors.setActive(palette);
          await pumpPage(
              t,
              Center(
                child: RepaintBoundary(
                  key: shot,
                  child: PeerLeadCard(
                    lead: lead,
                    width: 240,
                    circle: PeerCircle.idle,
                    onOpen: () {},
                    onPlay: () {},
                    providerLabel: 'Deezer',
                  ),
                ),
              ));
          final origin = t.getTopLeft(find.byKey(shot));
          final box = t.getRect(find.byKey(kPeerCardPlayKey)).shift(-origin);
          expect(box.size, const Size(44, 44));
          final boundary =
              t.renderObject<RenderRepaintBoundary>(find.byKey(shot));
          late final ByteData bytes;
          late final int stride;
          await t.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 1);
            stride = image.width;
            bytes =
                (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
            image.dispose();
          });
          // The pixel at (x, y) from the circle box's top-left, as r+g+b.
          int sum(int x, int y) {
            final i =
                ((box.top.round() + y) * stride + box.left.round() + x) * 4;
            return bytes.getUint8(i) +
                bytes.getUint8(i + 1) +
                bytes.getUint8(i + 2);
          }

          // The bare tile, far from the circle.
          final ground = sum(-30, 24);
          // Five pixels just outside the circle whose centres sit 25.5 from
          // the shadow's centre (the box's centre, 2 down): straight right,
          // left and down, which lie outside the 44 px box, and down-right
          // and down-left, inside its corners.
          final darkening = [
            for (final (x, y) in [
              (47, 23),
              (-4, 23),
              (21, 49),
              (40, 41),
              (3, 41),
            ])
              ground - sum(x, y),
          ];
          final reason = '${palette.brightness}: ground $ground, $darkening';
          // Shadowed all round, past the box's edges too.
          for (final d in darkening) {
            expect(d, greaterThan(8), reason: reason);
          }
          // And round: as dark at the box's corners as straight out.
          final mean = darkening.reduce((a, b) => a + b) / darkening.length;
          final spread =
              darkening.reduce(math.max) - darkening.reduce(math.min);
          expect(spread, lessThanOrEqualTo(mean * .25 + 3), reason: reason);
        }
      } finally {
        debugDisableShadows = true;
      }
    });

    testWidgets("the circle's 44 px target and its ripple, kept in the circle",
        (t) async {
      final played = <String>[];
      await pumpPage(
          t, scrolled(grid(leads, onPlay: (l) => played.add(l.title))));
      final circle = circleOf(0);
      final well = find.descendant(of: circle, matching: find.byType(InkWell));
      expect(t.getSize(well), const Size(44, 44));
      expect(t.widget<InkWell>(well).customBorder, const CircleBorder());

      // A press: its ink is clipped to the circle, in at the centre and out
      // at the box's corners.
      final press = await t.startGesture(t.getCenter(circle));
      await t.pump(const Duration(milliseconds: 100));
      expect(
          t.renderObject(
              find.descendant(of: circle, matching: find.byType(Material))),
          paints
            ..clipPath(
                pathMatcher: isPathThat(
              includes: const [Offset(22, 22)],
              excludes: const [
                Offset(3, 3),
                Offset(41, 3),
                Offset(3, 41),
                Offset(41, 41),
              ],
            )));
      await press.up();
      await t.pumpAndSettle();
      expect(played, ['Salt Road']);
    });

    testWidgets('the live title in ink', (t) async {
      for (final palette in [dark, light]) {
        VelvetColors.setActive(palette);
        await pumpPage(
            t,
            scrolled(grid(leads,
                isLive: (l) => l.title == 'Breakwater',
                circleOf: (l) => l.title == 'Breakwater'
                    ? PeerCircle.playing
                    : PeerCircle.idle)));
        Color? colourOf(String text) =>
            t.widget<Text>(find.text(text).first).style!.color;
        expect(colourOf('Breakwater'), peerInk());
        expect(colourOf('Salt Road'), VelvetColors.textPrimary);
        expect(colourOf('Hollow Coast'), VelvetColors.textSecondary);
      }
      // In Dark the ink is the page's amber, not the text colour (M:96); in
      // Light it is the board's #1A1A1A, the text colour itself (V:21).
      VelvetColors.setActive(dark);
      expect(peerInk(), isNot(VelvetColors.textPrimary));
    });

    testWidgets('art shows; a null tile draws raised, no letter', (t) async {
      final art = Uri.parse('https://e-cdns-images.dzcdn.example/cover/1.jpg');
      final bare = parseLeads(tasteJson(leads: [
        leadJson(title: 'Bare', artist: 'Nobody'),
        leadJson(title: 'Lettered', tile: tileJson('k', 203, 'L')),
      ]));
      await pumpPage(
          t,
          scrolled(grid([leads[0], ...bare],
              artOf: (l) => l.title == 'Salt Road' ? art : null)));

      final earned = t.widget<GeneratedTile>(tileOf(0));
      expect(earned.art, art);
      expect(find.descendant(of: card(0), matching: find.byType(Image)),
          findsOneWidget);

      final none = t.widget<GeneratedTile>(tileOf(1));
      expect(none.hue, isNull);
      expect(none.letter, '');
      expect(none.art, isNull);
      expect(
          t
              .widget<ColoredBox>(find.descendant(
                  of: tileOf(1), matching: find.byType(ColoredBox)))
              .color,
          VelvetColors.raised);
      // Only the title and the artist: no letter on the bare tile.
      expect(find.descendant(of: card(1), matching: find.byType(Text)),
          findsNWidgets(2));

      final lettered = t.widget<GeneratedTile>(tileOf(2));
      expect(lettered.hue, 203);
      expect(lettered.letter, 'L');
      expect(lettered.size, 175);
    });

    testWidgets(
        'text 1.3: 2-line title and artist; circles, tiles and the band '
        'cover do not scale', (t) async {
      int? linesOf(String text) =>
          t.widget<Text>(find.text(text).first).maxLines;

      await pumpPage(t, scrolled(grid(leads)));
      expect(linesOf('Salt Road'), 1);
      expect(linesOf('Hollow Coast'), 1);

      await pumpPage(
          t,
          Column(children: [
            Expanded(child: scrolled(grid(leads))),
            PeerRecsBand(
              lead: leads[2],
              status: PeerClipStatus.playing,
              progress: ValueNotifier((
                position: const Duration(seconds: 12),
                length: const Duration(seconds: 30),
              )),
              providerLabel: 'Deezer',
              hasNext: true,
              onToggle: () {},
              onNext: () {},
              onClose: () {},
              onLink: (_) {},
            ),
          ]),
          textScale: 1.3);
      expect(linesOf('Salt Road'), 2);
      expect(linesOf('Hollow Coast'), 2);
      expect(t.getSize(tileOf(0)), const Size(175, 175));
      expect(t.getSize(circleOf(0)), const Size(44, 44));
      expect(
          t
              .widget<Icon>(
                  find.descendant(of: circleOf(0), matching: find.byType(Icon)))
              .size,
          22);
      expect(t.getSize(find.byKey(kPeerBandCoverKey)), const Size(44, 44));
      // The tile's letter keeps its 45 % too (V:158).
      expect(
          t
              .widget<Text>(
                  find.descendant(of: tileOf(0), matching: find.text('H')))
              .style!
              .fontSize,
          79);
    });
  });

  group('footer and states', () {
    testWidgets('footer: Preview all only with a provider; Copy list always',
        (t) async {
      var all = 0;
      var copy = 0;
      await pumpPage(
          t,
          scrolled(PeerRecsFooter(
              showPreviewAll: true,
              running: false,
              onPreviewAll: () => all++,
              onCopyList: () => copy++)));
      expect(find.text('Preview all'), findsOneWidget);
      expect(find.text('Copy list'), findsOneWidget);
      // At the grid's left inset (14 at 390), Preview all first.
      expect(t.getTopLeft(find.byKey(kPeerPreviewAllKey)).dx, 14);
      expect(
          t
              .widgetList<DiscoveryPill>(find.byType(DiscoveryPill))
              .map((p) => (p.label, p.primary, p.icon)),
          [
            ('Preview all', true, Icons.play_arrow),
            ('Copy list', false, Icons.content_copy),
          ]);
      await t.tap(find.text('Preview all'));
      await t.tap(find.text('Copy list'));
      expect((all, copy), (1, 1));

      // No preview plug-in (V:82): Copy list alone, at the inset.
      await pumpPage(
          t,
          scrolled(PeerRecsFooter(
              showPreviewAll: false,
              running: false,
              onPreviewAll: () => all++,
              onCopyList: () => copy++)));
      expect(find.text('Preview all'), findsNothing);
      expect(find.byKey(kPeerPreviewAllKey), findsNothing);
      expect(t.getTopLeft(find.byKey(kPeerCopyListKey)).dx, 14);
      await t.tap(find.text('Copy list'));
      expect((all, copy), (1, 2));

      // Wide: the footer starts where the centred grid does.
      await pumpPage(
          t,
          scrolled(PeerRecsFooter(
              showPreviewAll: true,
              running: false,
              onPreviewAll: () {},
              onCopyList: () {})),
          width: 1024,
          height: 768);
      expect(t.getTopLeft(find.byKey(kPeerPreviewAllKey)).dx, 266);
    });

    testWidgets('Preview all reads toggled while running, not toggled otherwise',
        (t) async {
      final semantics = t.ensureSemantics();
      for (final running in [false, true]) {
        await pumpPage(
            t,
            scrolled(PeerRecsFooter(
                showPreviewAll: true,
                running: running,
                onPreviewAll: () {},
                onCopyList: () {})));
        expect(
            t.getSemantics(find.byKey(kPeerPreviewAllKey)),
            isSemantics(
                label: 'Preview all',
                hasToggledState: true,
                isToggled: running,
                hasTapAction: true),
            reason: 'running $running');
        // Copy list is no toggle.
        expect(t.getSemantics(find.byKey(kPeerCopyListKey)),
            isSemantics(label: 'Copy list', hasToggledState: false));
      }
      semantics.dispose();
    });

    testWidgets('each state draws its words only', (t) async {
      final semantics = t.ensureSemantics();
      var retry = 0;
      var seeds = 0;
      Future<void> pumpState(PeerRecsState s) => pumpPage(
          t,
          Column(children: [
            SizedBox(
              height: 400,
              child: PeerRecsStateView(
                  state: s,
                  onRetry: () => retry++,
                  onNewSeeds: () => seeds++),
            ),
          ]));
      Finder texts() => find.descendant(
          of: find.byType(PeerRecsStateView), matching: find.byType(Text));

      // No peers yet (S:82): one line, centred, announced.
      await pumpState(PeerRecsState.noPeers);
      expect(texts(), findsOneWidget);
      expect(find.text('No peers yet'), findsOneWidget);
      expect(t.getCenter(find.text('No peers yet')).dx, 195);
      // Centred in the room above the 24 px bottom pad.
      expect(t.getCenter(find.text('No peers yet')).dy, closeTo(188, 0.01));
      final line = t.widget<Text>(find.text('No peers yet'));
      expect(line.style!.fontSize, 15);
      expect(line.style!.height, 20 / 15);
      expect(line.style!.color, VelvetColors.textSecondary);
      expect(t.getSemantics(find.text('No peers yet')),
          isSemantics(label: 'No peers yet', isLiveRegion: true));

      // Nothing new (S:117): the line, then New seeds 8 under it.
      await pumpState(PeerRecsState.nothingNew);
      expect(texts(), findsNWidgets(2));
      expect(find.text('Nothing new'), findsOneWidget);
      expect(find.text('New seeds'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
      expect(t.getCenter(find.text('Nothing new')).dx, 195);
      await t.tap(find.text('New seeds'));
      expect((retry, seeds), (0, 1));

      // Try again alone (S:152), no line.
      await pumpState(PeerRecsState.failed);
      expect(texts(), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
      await t.tap(find.text('Try again'));
      expect((retry, seeds), (1, 1));

      // The rest are drawn elsewhere.
      for (final s in [
        PeerRecsState.loading,
        PeerRecsState.scanPending,
        PeerRecsState.ready,
      ]) {
        await pumpState(s);
        expect(texts(), findsNothing, reason: '$s');
        expect(find.byType(DiscoveryPill), findsNothing);
      }
      semantics.dispose();
    });

    testWidgets('the skeleton has 6 cards', (t) async {
      final semantics = t.ensureSemantics();
      await pumpPage(t, scrolled(const PeerRecsSkeleton()));
      final cards = find.byKey(kPeerSkeletonCardKey);
      expect(cards, findsNWidgets(6));
      // In the grid's geometry: 175 wide at 390, 14 in, 12 apart, rows 14
      // apart.
      final rects = [for (var i = 0; i < 6; i++) t.getRect(cards.at(i))];
      expect(rects[0].left, 14);
      expect(rects[0].width, 175);
      expect(rects[1].left, 14 + 175 + 12);
      expect(rects[2].top, rects[0].bottom + 14);
      // No words, nothing for the screen reader.
      expect(find.descendant(
              of: find.byType(PeerRecsSkeleton), matching: find.byType(Text)),
          findsNothing);
      expect(
          find.descendant(
              of: find.byType(PeerRecsSkeleton),
              matching: find.byType(ExcludeSemantics)),
          findsWidgets);
      semantics.dispose();
    });
  });

  group('overflow', () {
    testWidgets('no overflow at 360×780 and 390×844, text 1.0/1.3, dark/light',
        (t) async {
      final long = parseLeads(tasteJson(leads: [
        leadJson(
            title: 'An Extraordinarily Long Title That Keeps On Going',
            artist: 'The Band With The Longest Name In The Whole Shelf',
            tile: tileJson('long', 300, 'T')),
        leadJson(title: 'Short', artist: 'A'),
        leadJson(title: 'W' * 60, artist: 'W' * 60),
      ]));
      final all = [...leads, ...long];
      for (final (w, h) in [(360.0, 780.0), (390.0, 844.0)]) {
        for (final scale in [1.0, 1.3]) {
          for (final palette in [dark, light]) {
            VelvetColors.setActive(palette);
            await pumpPage(
                t,
                Column(children: [
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(children: [
                        grid(all,
                            circleOf: (l) => switch (all.indexOf(l) % 5) {
                                  0 => PeerCircle.idle,
                                  1 => PeerCircle.playing,
                                  2 => PeerCircle.busy,
                                  3 => PeerCircle.paused,
                                  _ => PeerCircle.muted,
                                },
                            isLive: (l) => all.indexOf(l) == 1),
                        PeerRecsFooter(
                            showPreviewAll: true,
                            running: true,
                            onPreviewAll: () {},
                            onCopyList: () {}),
                        const PeerRecsSkeleton(),
                        for (final s in [
                          PeerRecsState.noPeers,
                          PeerRecsState.nothingNew,
                          PeerRecsState.failed,
                        ])
                          SizedBox(
                            height: 200,
                            child: PeerRecsStateView(
                                state: s, onRetry: () {}, onNewSeeds: () {}),
                          ),
                      ]),
                    ),
                  ),
                  PeerRecsBand(
                    lead: all[12],
                    attribution: 'Preview from a provider with a long name',
                    link: Uri.parse('https://www.deezer.com/track/3'),
                    status: PeerClipStatus.playing,
                    progress: ValueNotifier((
                      position: const Duration(seconds: 12),
                      length: const Duration(seconds: 30),
                    )),
                    providerLabel: 'Deezer',
                    hasNext: true,
                    onToggle: () {},
                    onNext: () {},
                    onClose: () {},
                    onLink: (_) {},
                  ),
                ]),
                width: w,
                height: h,
                textScale: scale);
            expect(t.takeException(), isNull,
                reason: '$w×$h at $scale, ${palette.brightness}');
          }
        }
      }
    });
  });
}

