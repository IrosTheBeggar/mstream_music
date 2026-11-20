// screens/discovery/peer_recs_strip.dart — the Peer Recommendations page's
// peer strip (mStream docs/peer-recommendations-plan.md §4.2 "Drawing", the
// strip; item rules §5.6): every item state drawn as the approved boards draw
// it (Main M:33-40, M:127-135; Variants V:21, V:146-150) with its screen
// reader words, the 10 px step before the first "+", the item and strip sizes
// at text 1.0 and 1.3 (and the item's under Android's non-linear text
// scaling), a name's bounded shrink, the taps (No room inert, plan §2
// item 6), no overflow on a small phone at a large text size, its own
// sideways scroll kept across a poll, and nothing of it kept in page
// storage.
//
// The items are the stage's admin peers answer as the rules build it (A's
// fixtures), plus one addable peer whose Add found no room.

import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mstream_music/l10n/localizations_delegates.dart';
import 'package:mstream_music/screens/discovery/keep_copy_ui.dart'
    show keepInkOnPage;
import 'package:mstream_music/screens/discovery/peer_recs_strip.dart';
import 'package:mstream_music/theme/velvet_theme.dart';
import 'package:mstream_music/util/peer_recs_colours.dart';
import 'package:mstream_music/util/peer_recs_rules.dart';

import 'peer_recs_fixtures.dart';
import 'peer_recs_strip_scalers.dart';

/// An addable peer whose Add found no room (no board draws one).
final String kQuiet = 'ab' * 32;

/// The admin's answer plus the No room peer: All, Basement Hi-Fi and
/// Kitchen Radio online, Attic Tapes and mStream · 3f9a offline, then
/// Lighthouse Tapes "+", Static Garden Adding…, Rooftop FM Try again and
/// Quiet Room No room.
Map<String, dynamic> peersJson() {
  final m = peersAdminJson;
  (m['peers'] as List).add({
    'endpointId': kQuiet,
    'name': 'Quiet Room',
    'label': 'Quiet Room',
    'monogram': 'QR',
    'hue': 50,
    'online': true,
    'onShelf': false,
    'pinned': false,
    'rowCount': 12000,
    'add': {
      'state': 'failed',
      'code': 'no-room',
      'at': '2026-11-19T10:00:00.000Z',
    },
  });
  return m;
}

List<PeerStripItem> itemsOf({String? selected, Map<String, dynamic>? json}) =>
    peerStripItems(parsePeers(json ?? peersJson()), selected: selected).items;

void main() {
  final dark = paletteFor(AppTheme.dark);
  final light = paletteFor(AppTheme.light);
  tearDown(() => VelvetColors.setActive(dark));

  final selects = <String?>[];
  final adds = <String>[];
  setUp(() {
    selects.clear();
    adds.clear();
  });

  Widget strip(List<PeerStripItem> items) => PeerStripView(
        items: items,
        onSelect: selects.add,
        onAdd: adds.add,
      );

  /// The strip at the top of a vertical scroll, as the page holds it.
  Future<void> pumpStrip(
    WidgetTester t,
    List<PeerStripItem> items, {
    double width = 1024,
    double height = 844,
    double textScale = 1,
    TextScaler? scaler,
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
            .copyWith(textScaler: scaler ?? TextScaler.linear(textScale)),
        child: child!,
      ),
      home: Scaffold(
        body: CustomScrollView(slivers: [
          SliverToBoxAdapter(child: strip(items)),
        ]),
      ),
    ));
  }

  Finder item(String? id) => find.byKey(ValueKey('peer-strip-${id ?? 'all'}'));
  Finder part(String? id, String key) =>
      find.descendant(of: item(id), matching: find.byKey(ValueKey(key)));
  BoxDecoration circleOf(WidgetTester t, String? id) =>
      t.widget<Container>(part(id, 'peer-strip-circle')).decoration!
          as BoxDecoration;
  Finder labelFinder(String? id) =>
      find.descendant(of: item(id), matching: find.byType(Text)).last;
  Text labelOf(WidgetTester t, String? id) => t.widget<Text>(labelFinder(id));
  Text monogramOf(WidgetTester t, String id) =>
      t.widget<Text>(find
          .descendant(of: item(id), matching: find.byType(Text))
          .first);
  /// The online dot's or the failed badge's disc.
  BoxDecoration discOf(WidgetTester t, String id, String key) => t
      .widget<Container>(find
          .descendant(of: part(id, key), matching: find.byType(Container))
          .first)
      .decoration! as BoxDecoration;
  Color borderOf(BoxDecoration d) => (d.border! as Border).top.color;
  double borderWidthOf(BoxDecoration d) => (d.border! as Border).top.width;
  Finder inkOf(String? id) =>
      find.descendant(of: item(id), matching: find.byType(InkWell));

  group("every item state's drawing and semantics", () {
    testWidgets('the strip is one group labelled Peers', (t) async {
      final h = t.ensureSemantics();
      await pumpStrip(t, itemsOf());
      expect(t.getSemantics(find.byType(PeerStripView)),
          isSemantics(label: 'Peers'));
      h.dispose();
    });

    testWidgets('All, selected: raised fill, the ink glyph, a ring (M:34)',
        (t) async {
      final h = t.ensureSemantics();
      await pumpStrip(t, itemsOf());
      expect(circleOf(t, null).color, VelvetColors.raised);
      expect(circleOf(t, null).border, isNull);
      expect(t.renderObject(part(null, 'peer-strip-all-glyph')),
          paints..circle(x: 12, y: 5, radius: 2.5, color: keepInkOnPage()));
      expect(t.getSize(part(null, 'peer-strip-all-glyph')),
          const Size.square(24));
      final ring = t.widget<Container>(part(null, 'peer-strip-ring'));
      final rd = ring.decoration! as BoxDecoration;
      expect(rd.shape, BoxShape.circle);
      expect(borderOf(rd), VelvetColors.primary);
      expect(borderWidthOf(rd), 2);
      // A 2 px gap, then the 2 px ring: 64 across, centred on the circle.
      final c = t.getRect(part(null, 'peer-strip-circle'));
      final r = t.getRect(part(null, 'peer-strip-ring'));
      expect(r.size, const Size.square(64));
      expect(r.center, c.center);
      expect(labelOf(t, null).data, 'All');
      expect(labelOf(t, null).style!.color, VelvetColors.textPrimary);
      expect(
          t.getSemantics(item(null)),
          isSemantics(
            label: 'All',
            isButton: true,
            hasSelectedState: true,
            isSelected: true,
            hasEnabledState: true,
            isEnabled: true,
            hasTapAction: true,
          ));
      h.dispose();
    });

    testWidgets('All, unselected: no ring, the secondary label (M:128)',
        (t) async {
      final h = t.ensureSemantics();
      await pumpStrip(t, itemsOf(selected: kKitchen));
      expect(part(null, 'peer-strip-ring'), findsNothing);
      expect(labelOf(t, null).style!.color, VelvetColors.textSecondary);
      expect(
          t.getSemantics(item(null)),
          isSemantics(
              label: 'All', hasSelectedState: true, isSelected: false));
      h.dispose();
    });

    testWidgets('a shelf peer online: its hue, black monogram, the dot (M:35)',
        (t) async {
      final h = t.ensureSemantics();
      await pumpStrip(t, itemsOf());
      expect(circleOf(t, kBasement).color, peerCircleOnline(210));
      expect(circleOf(t, kBasement).color,
          HSLColor.fromAHSL(1, 210, .55, .72).toColor());
      expect(monogramOf(t, kBasement).data, 'BH');
      expect(monogramOf(t, kBasement).style!.color, Colors.black);
      final dd = discOf(t, kBasement, 'peer-strip-dot');
      expect(dd.color, VelvetColors.success);
      expect(dd.shape, BoxShape.circle);
      // The 2 px ground ring around it.
      expect(dd.boxShadow,
          [BoxShadow(color: VelvetColors.bg, spreadRadius: 2)]);
      final c = t.getRect(part(kBasement, 'peer-strip-circle'));
      final d = t.getRect(part(kBasement, 'peer-strip-dot'));
      expect(d.size, const Size.square(12));
      expect(c.right - d.right, 1);
      expect(c.bottom - d.bottom, 1);
      expect(part(kBasement, 'peer-strip-ring'), findsNothing);
      expect(labelOf(t, kBasement).data, 'Basement Hi-Fi');
      expect(labelOf(t, kBasement).style!.color, VelvetColors.textSecondary);
      expect(
          t.getSemantics(item(kBasement)),
          isSemantics(
            label: 'Basement Hi-Fi',
            value: 'online',
            isButton: true,
            hasSelectedState: true,
            isSelected: false,
            hasTapAction: true,
          ));
      h.dispose();
    });

    testWidgets('a shelf peer offline: the dim hue, no dot (M:37)', (t) async {
      final h = t.ensureSemantics();
      await pumpStrip(t, itemsOf());
      expect(circleOf(t, kAttic).color, peerCircleOffline(112));
      expect(circleOf(t, kAttic).color,
          HSLColor.fromAHSL(1, 112, .30, .44).toColor());
      expect(monogramOf(t, kAttic).style!.color, Colors.black);
      expect(part(kAttic, 'peer-strip-dot'), findsNothing);
      expect(labelOf(t, kAttic).style!.color, VelvetColors.helper);
      expect(
          t.getSemantics(item(kAttic)),
          isSemantics(
            label: 'Attic Tapes',
            value: 'offline',
            isButton: true,
            hasSelectedState: true,
            isSelected: false,
            hasTapAction: true,
          ));
      h.dispose();
    });

    testWidgets('a selected shelf peer: the ring, the primary label (M:130)',
        (t) async {
      final h = t.ensureSemantics();
      await pumpStrip(t, itemsOf(selected: kKitchen));
      final rd = t.widget<Container>(part(kKitchen, 'peer-strip-ring'))
          .decoration! as BoxDecoration;
      expect(borderOf(rd), VelvetColors.primary);
      expect(t.getRect(part(kKitchen, 'peer-strip-ring')).size,
          const Size.square(64));
      // Still online: the dot stays.
      expect(part(kKitchen, 'peer-strip-dot'), findsOneWidget);
      expect(labelOf(t, kKitchen).style!.color, VelvetColors.textPrimary);
      expect(
          t.getSemantics(item(kKitchen)),
          isSemantics(
            label: 'Kitchen Radio',
            value: 'online',
            isButton: true,
            hasSelectedState: true,
            isSelected: true,
          ));
      // Only one tab is selected.
      expect(find.byKey(const ValueKey('peer-strip-ring')), findsOneWidget);
      h.dispose();
    });

    testWidgets('"+": a dashed ring of 24, the add glyph, "Add {name}" (M:38)',
        (t) async {
      final h = t.ensureSemantics();
      await pumpStrip(t, itemsOf());
      expect(circleOf(t, kLighthouse).color, isNull);
      expect(circleOf(t, kLighthouse).border, isNull);
      final dashed = t.renderObject(part(kLighthouse, 'peer-strip-dashed'));
      expect(
          dashed,
          paints
            ..arc(
                color: VelvetColors.primary,
                strokeWidth: 1.5,
                style: PaintingStyle.stroke));
      expect(dashed, paintsExactlyCountTimes(#drawArc, 24));
      final icon = t.widget<Icon>(
          find.descendant(of: item(kLighthouse), matching: find.byType(Icon)));
      expect(icon.icon, Icons.add);
      expect(icon.size, 24);
      expect(icon.color, VelvetColors.primary);
      expect(labelOf(t, kLighthouse).data, 'Lighthouse Tapes');
      expect(labelOf(t, kLighthouse).style!.color, VelvetColors.textSecondary);
      expect(
          t.getSemantics(item(kLighthouse)),
          isSemantics(
            label: 'Add Lighthouse Tapes',
            isButton: true,
            hasSelectedState: false,
            isEnabled: true,
            hasTapAction: true,
          ));
      h.dispose();
    });

    testWidgets('Adding…: the faint hue, a ring spinner, disabled (M:133)',
        (t) async {
      final h = t.ensureSemantics();
      await pumpStrip(t, itemsOf());
      expect(circleOf(t, kStatic).color, peerCircleAdding(330));
      expect(monogramOf(t, kStatic).data, 'SG');
      expect(monogramOf(t, kStatic).style!.color, VelvetColors.textPrimary);
      final spin = find.descendant(
          of: item(kStatic), matching: find.byType(CircularProgressIndicator));
      final p = t.widget<CircularProgressIndicator>(spin);
      expect(p.strokeWidth, 2.5);
      expect(p.strokeCap, StrokeCap.round);
      expect(p.strokeAlign, CircularProgressIndicator.strokeAlignInside);
      expect(p.color, VelvetColors.primary);
      expect(p.value, isNull);
      // Its stroke is centred on r = 30.5 around the circle's centre.
      final c = t.getRect(part(kStatic, 'peer-strip-circle'));
      final s = t.getRect(spin);
      expect(s.size, const Size.square(63.5));
      expect(s.center, c.center);
      expect(labelOf(t, kStatic).data, 'Adding…');
      expect(labelOf(t, kStatic).style!.color, VelvetColors.textSecondary);
      expect(inkOf(kStatic), findsNothing);
      expect(
          t.getSemantics(item(kStatic)),
          isSemantics(
            label: 'Static Garden',
            value: 'Adding…',
            isButton: true,
            hasEnabledState: true,
            isEnabled: false,
            hasTapAction: false,
          ));
      h.dispose();
    });

    testWidgets('Try again: raised, the error border and badge (M:134)',
        (t) async {
      final h = t.ensureSemantics();
      await pumpStrip(t, itemsOf());
      final d = circleOf(t, kRooftop);
      expect(d.color, VelvetColors.raised);
      expect(borderOf(d), VelvetColors.error);
      expect(borderWidthOf(d), 2);
      expect(monogramOf(t, kRooftop).data, 'RF');
      expect(monogramOf(t, kRooftop).style!.color, VelvetColors.textPrimary);
      final bd = discOf(t, kRooftop, 'peer-strip-badge');
      expect(bd.color, VelvetColors.error);
      expect(bd.boxShadow,
          [BoxShadow(color: VelvetColors.bg, spreadRadius: 2)]);
      final c = t.getRect(part(kRooftop, 'peer-strip-circle'));
      final b = t.getRect(part(kRooftop, 'peer-strip-badge'));
      expect(b.size, const Size.square(18));
      expect(b.right - c.right, 3);
      expect(b.bottom - c.bottom, 3);
      final icon = t.widget<Icon>(find.descendant(
          of: part(kRooftop, 'peer-strip-badge'), matching: find.byType(Icon)));
      expect(icon.icon, Icons.priority_high);
      expect(icon.size, 12);
      expect(icon.color, Colors.black);
      expect(labelOf(t, kRooftop).data, 'Try again');
      expect(labelOf(t, kRooftop).style!.color, VelvetColors.error);
      expect(
          t.getSemantics(item(kRooftop)),
          isSemantics(
            label: 'Rooftop FM',
            value: 'Try again',
            isButton: true,
            isEnabled: true,
            hasTapAction: true,
          ));
      h.dispose();
    });

    testWidgets('No room: raised, a quiet border, not a button', (t) async {
      final h = t.ensureSemantics();
      await pumpStrip(t, itemsOf());
      final d = circleOf(t, kQuiet);
      expect(d.color, VelvetColors.raised);
      expect(borderOf(d), VelvetColors.border2);
      expect(borderWidthOf(d), 1);
      expect(monogramOf(t, kQuiet).data, 'QR');
      expect(monogramOf(t, kQuiet).style!.color, VelvetColors.helper);
      expect(part(kQuiet, 'peer-strip-badge'), findsNothing);
      expect(
          find.descendant(
              of: item(kQuiet),
              matching: find.byType(CircularProgressIndicator)),
          findsNothing);
      expect(labelOf(t, kQuiet).data, 'No room');
      expect(labelOf(t, kQuiet).style!.color, VelvetColors.helper);
      expect(inkOf(kQuiet), findsNothing);
      expect(
          t.getSemantics(item(kQuiet)),
          isSemantics(
            label: 'Quiet Room',
            value: 'No room',
            isButton: false,
            hasEnabledState: false,
            hasTapAction: false,
          ));
      h.dispose();
    });

    testWidgets('the label: 12 / w600 / a 15 px line, two lines, centred',
        (t) async {
      await pumpStrip(t, itemsOf());
      for (final id in [null, kBasement, kLighthouse, kStatic, kQuiet]) {
        final label = labelOf(t, id);
        expect(label.style!.fontSize, 12);
        expect(label.style!.fontWeight, FontWeight.w600);
        expect(label.style!.height, 15 / 12);
        expect(label.maxLines, 2);
        expect(label.overflow, TextOverflow.ellipsis);
        expect(label.textAlign, TextAlign.center);
      }
    });
  });

  testWidgets('the 10 px gap before the first +', (t) async {
    for (final scale in [1.0, 1.3]) {
      await pumpStrip(t, itemsOf(), textScale: scale);
      double gap(String? a, String b) =>
          t.getRect(item(b)).left - t.getRect(item(a)).right;
      // The list starts 14 in.
      expect(t.getRect(item(null)).left, 14);
      expect(gap(null, kBasement), 4);
      expect(gap(kBasement, kKitchen), 4);
      expect(gap(kAttic, kMstream), 4);
      // The first addable peer, whatever its state, steps 10 further out.
      expect(gap(kMstream, kLighthouse), 14);
      expect(gap(kLighthouse, kStatic), 4);
      expect(gap(kStatic, kRooftop), 4);
      expect(gap(kRooftop, kQuiet), 4);
    }
    // The step goes with the first addable item, even when it is Adding….
    final m = peersAdminJson;
    (m['peers'] as List).removeAt(4); // Lighthouse Tapes
    await pumpStrip(t, itemsOf(json: m));
    expect(t.getRect(item(kStatic)).left - t.getRect(item(kMstream)).right,
        14);
    // A member has no addable item: no step at all.
    await pumpStrip(t, itemsOf(json: peersMemberJson));
    expect(t.getRect(item(kMstream)).left - t.getRect(item(kAttic)).right, 4);
  });

  testWidgets('items are 68 at 1.0 and 88 at 1.3; circles stay 56',
      (t) async {
    for (final (scale, width) in [(1.0, 68.0), (1.3, 88.0)]) {
      await pumpStrip(t, itemsOf(), textScale: scale);
      for (final id in [
        null,
        kBasement,
        kAttic,
        kLighthouse,
        kStatic,
        kRooftop,
        kQuiet,
      ]) {
        expect(t.getSize(item(id)).width, width, reason: '$id at $scale');
        expect(t.getSize(part(id, 'peer-strip-circle')),
            const Size.square(56),
            reason: '$id at $scale');
      }
      // The monogram and the label scale with the text.
      expect(t.renderObject<RenderParagraph>(find.text('BH')).textScaler,
          TextScaler.linear(scale));
      expect(t.renderObject<RenderParagraph>(labelFinder(null)).textScaler,
          TextScaler.linear(scale));
    }
  });

  testWidgets(
      'under a non-linear text scaler an item grows as its label does: 88 '
      "at Android's 130 %, 136 at 200 %", (t) async {
    // Android 14 draws a 12 px font at the whole factor and a 68 px one at
    // 68 (130 %) or about 72 (200 %). A scaled 68 kept the item at 68 or
    // 72 under a label drawn at 15.6 or 24 px.
    final m = peersJson();
    (m['peers'] as List)[0]['label'] = 'Studio One';
    for (final (scaler, width) in [
      (AndroidFontScale.x13, 88.0),
      (AndroidFontScale.x20, 136.0),
    ]) {
      await pumpStrip(t, itemsOf(json: m), width: 1600, scaler: scaler);
      expect(t.takeException(), isNull);
      final why = '$scaler';
      for (final id in [null, kBasement, kAttic, kLighthouse, kQuiet]) {
        expect(t.getSize(item(id)).width, width, reason: '$id at $why');
        expect(t.getSize(part(id, 'peer-strip-circle')),
            const Size.square(56),
            reason: '$id at $why');
      }
      final label = t.renderObject<RenderParagraph>(labelFinder(kBasement));
      expect(label.textScaler, same(scaler));
      // "Studio" (95.1 px at 15.6 px, 145.5 at 24) needs 0.92 or 0.93 of
      // its size here: it shrinks whole. In a 68 or 72 px item it needed
      // 0.71 or 0.49 and was broken.
      expect(
          find.ancestor(
              of: labelFinder(kBasement), matching: find.byType(FittedBox)),
          findsOneWidget,
          reason: why);
      expect(label.getMinIntrinsicWidth(double.infinity),
          lessThanOrEqualTo(label.size.width),
          reason: '$why: a word is broken');
      expect(t.getRect(labelFinder(kBasement)).width, closeTo(width, .01),
          reason: why);
    }
  });

  testWidgets(
      'the strip is 116 tall at 1.0 and 126 at 1.3 (±0.5); '
      'a 2-line label is never clipped', (t) async {
    // 126, not 86 + scale(30) = 125: the engine lays each 19.5 px line out
    // as 20, as board V:148 draws it, so 125 would clip the second line.
    final m = peersJson();
    (m['peers'] as List)[0]['label'] =
        'Basement Hi-Fi of the Northern Reaches Collective';
    for (final (scale, height) in [(1.0, 116.0), (1.3, 126.0)]) {
      await pumpStrip(t, itemsOf(json: m), textScale: scale);
      expect(t.takeException(), isNull);
      final strip = t.getRect(find.byType(PeerStripView));
      expect(strip.height, closeTo(height, .5), reason: 'at $scale');
      // Every item is one button as tall as the strip lets it be: ≥ 68 × 92.
      final cell = t.getSize(item(kBasement));
      expect(cell.height, closeTo(height - 24, .5));
      expect(cell.height, greaterThanOrEqualTo(92));
      // The long label takes its two whole lines, ellipsized, inside the
      // strip's padding.
      final para = t.renderObject<RenderParagraph>(labelFinder(kBasement));
      expect(para.didExceedMaxLines, isTrue);
      expect(para.size.height, closeTo(height - 86, .01));
      expect(para.size.height,
          closeTo(para.getMinIntrinsicHeight(para.size.width), .01));
      final label = t.getRect(labelFinder(kBasement));
      expect(label.bottom, lessThanOrEqualTo(strip.bottom - 12 + .01));
      expect(t.getRect(part(kBasement, 'peer-strip-circle')).top,
          closeTo(strip.top + 12, .01));
    }
  });

  testWidgets(
      "a name's word a little too wide shrinks the label whole, to no less "
      'than 0.8 of its size; a wider one wraps as it did', (t) async {
    // The test font draws every letter 1 em wide, and the label's 0.25 px
    // letter spacing does not scale with the text. So "Studio" is 73.5 px
    // at text 1.0 (68 / 74 = 0.92 of its size), and "Kitchen" is 85.75 px
    // at 1.0 (68 / 86 = 0.791), 110.95 at 1.3 (88 / 111 = 0.793) and
    // 169.75 at 2.0 (136 / 170 = 0.8 exactly).
    //
    // Both kinds of item that draw a peer's name are checked: a shelf peer
    // (Studio One, Kitchen Radio) and a "+" (Studio Tapes, and Quiet Room
    // with no Add yet as Kitchen Sink).
    final m = peersJson();
    final peers = m['peers'] as List;
    peers[0]['label'] = 'Studio One';
    peers[4]['label'] = 'Studio Tapes';
    peers[7] = <String, dynamic>{
      ...peers[7] as Map<String, dynamic>,
      'label': 'Kitchen Sink',
      'add': null,
    };
    final items = itemsOf(json: m);
    expect(
        [
          for (final i in items)
            if (i.kind == PeerItemKind.add && i.state == null) i.id
        ],
        [kLighthouse, kQuiet]);
    const shrinks = ['Studio One', 'Studio Tapes'];
    const wraps = ['Kitchen Radio', 'Kitchen Sink'];
    final ids = {
      'Studio One': kBasement,
      'Studio Tapes': kLighthouse,
      'Kitchen Radio': kKitchen,
      'Kitchen Sink': kQuiet,
    };
    Finder fittedOf(String id) =>
        find.ancestor(of: labelFinder(id), matching: find.byType(FittedBox));

    /// The label is drawn whole, shrunk to the item's width by 0.8 to
    /// 0.95, centred under the circle and inside the item.
    void expectShrunk(String id, double width, String why) {
      expect(fittedOf(id), findsOneWidget, reason: why);
      final p = t.renderObject<RenderParagraph>(labelFinder(id));
      expect(p.didExceedMaxLines, isFalse, reason: why);
      expect(p.getMinIntrinsicWidth(double.infinity),
          lessThanOrEqualTo(p.size.width),
          reason: '$why: a word is broken');
      final drawn = t.getRect(labelFinder(id));
      expect(drawn.width / p.size.width, inInclusiveRange(.8, .95),
          reason: why);
      expect(drawn.width, closeTo(width, .01), reason: why);
      final cell = t.getRect(item(id));
      expect(drawn.center.dx, closeTo(cell.center.dx, .5), reason: why);
      expect(drawn.bottom, lessThanOrEqualTo(cell.bottom + .01), reason: why);
    }

    for (final (scale, width) in [(1.0, 68.0), (1.3, 88.0)]) {
      await pumpStrip(t, items, width: 1600, textScale: scale);
      expect(t.takeException(), isNull);
      for (final name in shrinks) {
        final why = '"$name" at $scale';
        expect(labelOf(t, ids[name]!).data, name, reason: why);
        expectShrunk(ids[name]!, width, why);
      }
      // "Kitchen" would need less than 0.8: the label keeps the item's
      // width and its two lines, and the word is broken.
      for (final name in wraps) {
        final id = ids[name]!;
        final why = '"$name" at $scale';
        expect(labelOf(t, id).data, name, reason: why);
        expect(fittedOf(id), findsNothing, reason: why);
        final p = t.renderObject<RenderParagraph>(labelFinder(id));
        expect(p.size.width, closeTo(width, .01), reason: why);
        expect(t.getRect(labelFinder(id)).width, closeTo(width, .01),
            reason: why);
        final needs =
            width / p.getMinIntrinsicWidth(double.infinity).ceilToDouble();
        expect(needs, inExclusiveRange(.78, .8), reason: why);
      }
    }

    // At 2.0 "Kitchen" needs exactly 0.8, the floor: it shrinks too.
    await pumpStrip(t, items, width: 1600, textScale: 2);
    expect(t.takeException(), isNull);
    for (final name in [...shrinks, ...wraps]) {
      expectShrunk(ids[name]!, 136, '"$name" at 2.0');
    }
    for (final name in wraps) {
      final p = t.renderObject<RenderParagraph>(labelFinder(ids[name]!));
      expect(t.getRect(labelFinder(ids[name]!)).width / p.size.width,
          closeTo(.8, 1e-9),
          reason: name);
    }
  });

  testWidgets(
      'taps: a peer selects, + adds, Try again adds, '
      'Adding… and No room do nothing', (t) async {
    await pumpStrip(t, itemsOf(selected: kKitchen));
    await t.tap(item(null));
    await t.tap(item(kBasement));
    // An offline peer is still a tab.
    await t.tap(item(kMstream));
    // The selected tab asks again when tapped (the controller decides).
    await t.tap(item(kKitchen));
    expect(selects, [null, kBasement, kMstream, kKitchen]);
    expect(adds, isEmpty);

    await t.tap(item(kLighthouse));
    await t.tap(item(kRooftop));
    expect(adds, [kLighthouse, kRooftop]);

    await t.tap(item(kStatic), warnIfMissed: false);
    await t.tap(item(kQuiet), warnIfMissed: false);
    // A tap on the label is the item's too.
    await t.tap(labelFinder(kStatic), warnIfMissed: false);
    expect(adds, [kLighthouse, kRooftop]);
    expect(selects, [null, kBasement, kMstream, kKitchen]);
  });

  testWidgets('the screen reader taps what a finger taps', (t) async {
    final h = t.ensureSemantics();
    await pumpStrip(t, itemsOf());
    t.semantics.tap(find.semantics.byLabel('Kitchen Radio'));
    t.semantics.tap(find.semantics.byLabel('Add Lighthouse Tapes'));
    t.semantics.tap(find.semantics.byLabel('Rooftop FM'));
    expect(selects, [kKitchen]);
    expect(adds, [kLighthouse, kRooftop]);
    h.dispose();
  });

  testWidgets('monogram and label verbatim (mStream · 3f9a / mS)', (t) async {
    await pumpStrip(t, itemsOf());
    expect(find.descendant(of: item(kMstream), matching: find.text('mS')),
        findsOneWidget);
    expect(
        find.descendant(
            of: item(kMstream), matching: find.text('mStream · 3f9a')),
        findsOneWidget);
    final mono = monogramOf(t, kMstream);
    expect(mono.style!.fontSize, 18);
    expect(mono.style!.fontWeight, FontWeight.w700);
    expect(mono.style!.height, 1.0);
    expect(mono.maxLines, 1);
    // Never upper-cased, trimmed or folded: drawn as the server sent it.
    final m = peersJson();
    (m['peers'] as List)[3]
      ..['label'] = '  mStream · 3f9a  '
      ..['monogram'] = 'ß';
    await pumpStrip(t, itemsOf(json: m));
    expect(labelOf(t, kMstream).data, '  mStream · 3f9a  ');
    expect(monogramOf(t, kMstream).data, 'ß');
  });

  testWidgets('light inks (#1A1A1A ring, #16A34A dot, white All)', (t) async {
    VelvetColors.setActive(light);
    await pumpStrip(t, itemsOf(selected: kKitchen));
    const ink = Color(0xFF1A1A1A);
    final rd = t.widget<Container>(part(kKitchen, 'peer-strip-ring'))
        .decoration! as BoxDecoration;
    expect(borderOf(rd), ink);
    final dd = discOf(t, kBasement, 'peer-strip-dot');
    expect(dd.color, const Color(0xFF16A34A));
    expect(circleOf(t, null).color, const Color(0xFFFFFFFF));
    expect(t.renderObject(part(null, 'peer-strip-all-glyph')),
        paints..circle(color: ink));
    expect(t.renderObject(part(kLighthouse, 'peer-strip-dashed')),
        paints..arc(color: ink));
    expect(
        t.widget<Icon>(find.descendant(
            of: item(kLighthouse), matching: find.byType(Icon))).color,
        ink);
    expect(
        t.widget<CircularProgressIndicator>(find.descendant(
            of: item(kStatic),
            matching: find.byType(CircularProgressIndicator))).color,
        ink);
    // The peer circles are the same in both themes (V:35 = M:35).
    expect(circleOf(t, kBasement).color, peerCircleOnline(210));
    // The ground ring around the dot is the light ground.
    expect(dd.boxShadow,
        [const BoxShadow(color: Color(0xFFE1E2E1), spreadRadius: 2)]);
  });

  testWidgets('no overflow at 360 wide, text 1.3, 8 items', (t) async {
    final items = itemsOf(json: peersAdminJson);
    expect(items, hasLength(8));
    await pumpStrip(t, items, width: 360, height: 780, textScale: 1.3);
    expect(t.takeException(), isNull);
    // It scrolls sideways to its last item, which sits 14 from the edge.
    await t.drag(find.byType(ListView), const Offset(-2000, 0));
    // The overscroll stretch springs back (the spinner never settles).
    for (var i = 0; i < 4; i++) {
      await t.pump(const Duration(milliseconds: 500));
    }
    expect(t.takeException(), isNull);
    expect(t.getRect(item(kRooftop)).right, closeTo(360 - 14, .01));
    expect(t.getSize(find.byType(PeerStripView)).height, closeTo(126, .5));
    // Far past the boards: a monogram shrinks inside its 56 circle rather
    // than spill out of it, and the labels still fit their two lines.
    await pumpStrip(t, items, width: 360, height: 780, textScale: 2);
    t.widget<ListView>(find.byType(ListView)).controller!.jumpTo(0);
    await t.pump();
    expect(t.takeException(), isNull);
    final circle = t.getRect(part(kBasement, 'peer-strip-circle'));
    expect(circle.size, const Size.square(56));
    final mono = t.getRect(find.descendant(
        of: part(kBasement, 'peer-strip-circle'),
        matching: find.byType(FittedBox)));
    expect(circle.contains(mono.topLeft) && circle.contains(mono.bottomRight),
        isTrue);
    final para = t.renderObject<RenderParagraph>(labelFinder(kBasement));
    expect(para.size.height,
        closeTo(para.getMinIntrinsicHeight(para.size.width), .01));
  });

  testWidgets("a poll's new items keep the strip's own scroll", (t) async {
    await pumpStrip(t, itemsOf(), width: 360);
    final list = t.widget<ListView>(find.byType(ListView));
    // Its own controller, never the page's (BrowserManager().sc).
    final scroll = list.controller!;
    await t.drag(find.byType(ListView), const Offset(-150, 0));
    await t.pump();
    final at = scroll.offset;
    expect(at, greaterThan(0));
    // The next poll's answer: a fresh list, Kitchen Radio now selected.
    await pumpStrip(t, itemsOf(selected: kKitchen), width: 360);
    expect(t.widget<ListView>(find.byType(ListView)).controller, same(scroll));
    expect(scroll.offset, at);
  });

  testWidgets(
      'the strip keeps nothing in page storage: under a key holding the '
      "page's offset it starts at All, its own scroll writes nothing there, "
      'and drawn afresh it starts at All again', (t) async {
    t.view.physicalSize = const Size(360 * 3, 780 * 3);
    t.view.devicePixelRatio = 3;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    // The page's case: a PageStorageKey above the strip, its entry seeded
    // with the page's vertical offset before the strip is built.
    final bucket = PageStorageBucket();
    late BuildContext page;
    var seeded = false;
    Future<void> pump({required bool shown}) => t.pumpWidget(MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: appSupportedLocales,
          home: Scaffold(
            body: PageStorage(
              bucket: bucket,
              child: KeyedSubtree(
                key: const PageStorageKey<String>('page-offset'),
                child: Builder(builder: (context) {
                  page = context;
                  if (!seeded) {
                    seeded = true;
                    bucket.writeState(context, 300.0);
                  }
                  return Align(
                    alignment: Alignment.topCenter,
                    child: shown ? strip(itemsOf()) : const SizedBox.shrink(),
                  );
                }),
              ),
            ),
          ),
        ));
    ScrollPosition at() =>
        t.state<ScrollableState>(find.byType(Scrollable)).position;

    await pump(shown: true);
    expect(at().maxScrollExtent, greaterThan(300),
        reason: 'room to take the stored offset as its own');
    expect(at().pixels, 0);
    expect(t.getRect(item(null)).left, 14);

    // Pumped, not settled: Static Garden's ring spinner never settles.
    await t.drag(find.byType(PeerStripView), const Offset(-150, 0));
    await t.pump();
    await t.pump(const Duration(seconds: 1));
    expect(at().pixels, greaterThan(0));
    expect(bucket.readState(page), 300.0,
        reason: "the page's entry is the page's alone");

    // Gone and back: a new strip, at All.
    await pump(shown: false);
    await pump(shown: true);
    expect(at().pixels, 0);
    expect(t.getRect(item(null)).left, 14);
  });
}
