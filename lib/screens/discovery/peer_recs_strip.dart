import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/velvet_theme.dart';
import '../../util/peer_recs_colours.dart';
import '../../util/peer_recs_rules.dart';

/// The Peer Recommendations page's peer strip (mStream
/// docs/peer-recommendations-plan.md §4.2 "Drawing", the strip; item rules
/// §5.6): All, then the shelf peers as tabs, then — for an admin — the peers
/// it may Add, each with its Add's state. A horizontal list of 56 px circles
/// with two-line labels, drawn as the approved boards draw it (Main M:33-40,
/// M:127-135; Variants V:21, V:146-150).
///
/// The strip draws [PeerStripItem]s as the rules built them and decides
/// nothing: a label and a monogram are the server's, verbatim, and a tap does
/// what the item's act says. "Adding…" and "No room" do nothing (plan §2
/// item 6: No room is inert, and not even a button). It owns its horizontal
/// scroll, so a poll's new items keep where the user scrolled it; the page's
/// vertical scroll is the browser's.
///
/// That scroll lasts as long as the strip is on screen. A strip drawn afresh
/// (the page back from a frame pushed over it, or the strip gone and back)
/// starts at All, as the web's strip does once the page is drawn again. It
/// keeps nothing in page storage, where the page keeps its own offset.
class PeerStripView extends StatefulWidget {
  const PeerStripView({
    super.key,
    required this.items,
    required this.onSelect,
    required this.onAdd,
  });

  final List<PeerStripItem> items;

  /// A tab's tap: the peer's endpoint id, null for All.
  final void Function(String? endpointId) onSelect;

  /// A "+" or a "Try again" tap.
  final void Function(String endpointId) onAdd;

  @override
  State<PeerStripView> createState() => _PeerStripViewState();
}

/// The circle's side. It stays 56 at every text size (V:148); the monogram
/// and the label scale.
const double _kCircle = 56;

/// The vertical padding, above and below the items.
const double _kPadV = 12;

/// The gap between the circle and its label.
const double _kGap = 6;

/// The label: 12 / w600 at a 15 px line (M:34), scaled with the text.
const TextStyle _kLabel =
    TextStyle(fontSize: 12, fontWeight: FontWeight.w600, height: 15 / 12);

/// Two label lines, laid out as the label lays them out. They are measured,
/// not computed: the text engine rounds each line to a whole pixel, so at
/// text 1.3 a 19.5 px line takes 20 (as board V:148 draws it) and
/// `scale(30)` would clip the second line by a pixel. A non-linear text
/// scaler cannot clip one either.
double _twoLines(BuildContext context, TextScaler scaler) {
  final base = DefaultTextStyle.of(context);
  final painter = TextPainter(
    text: TextSpan(text: 'A\nA', style: base.style.merge(_kLabel)),
    textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
    textScaler: scaler,
    maxLines: 2,
    textHeightBehavior:
        base.textHeightBehavior ?? DefaultTextHeightBehavior.maybeOf(context),
  )..layout();
  final height = painter.height;
  painter.dispose();
  return height;
}

/// The strip's fixed height: the padding, the circle, the gap and two label
/// lines — 116 at text 1.0, 126 at 1.3. A horizontal list inside the page's
/// vertical scroll needs a fixed height, and this one never clips a
/// two-line label.
double _stripHeight(BuildContext context, TextScaler scaler) =>
    2 * _kPadV + _kCircle + _kGap + _twoLines(context, scaler);

/// An item's width: 68 at text 1.0, 88 at 1.3 (V:148), in whole pixels.
///
/// It grows as its label grows. 68 is not a font size, so it is not scaled
/// as one: Android 14's non-linear text scaling grows a 12 px font by the
/// whole factor and a large one far less, so a scaled 68 would leave the
/// item narrow under a label drawn at the full size.
double _itemWidth(TextScaler scaler) {
  final size = _kLabel.fontSize!;
  return (68 * scaler.scale(size) / size).roundToDouble();
}

/// The smallest a peer's name is drawn to keep its widest word whole: 0.8
/// of the label's size, 9.6 px at text 1.0, about the 10 pt of an iPhone
/// tab bar's labels.
///
/// It was picked by measuring names in the label's style with Roboto (an
/// Android phone) and with SF Semibold (an iPhone; it matches the live
/// walk's screenshot to a pixel). At text 1.0 and 1.3 a word of up to 12
/// letters fits or needs 0.80 to 0.99, so it shrinks and stays whole:
/// "Lighthouse" needs 0.99 in SF at 1.0, "Headquarters" 0.80 in SF and 0.88
/// in Roboto. A word of 15 letters or more needs 0.71 or less in every
/// font, and a 30-letter name about 0.39, too small to read; those wrap as
/// they are. With the system's Bold Text on, SF's bold "Headquarters" needs
/// 0.78 and wraps; "Lighthouse" needs 0.97 and shrinks.
const double _kNameFloor = 0.8;

class _PeerStripViewState extends State<PeerStripView> {
  // It neither reads nor writes page storage. The page files its scroller's
  // offset under a key above the strip, and a scrollable below that key with
  // no key of its own files its offset under the same entry: the strip would
  // come back at the page's vertical offset, and its own offset would
  // overwrite the page's.
  final ScrollController _scroll = ScrollController(keepScrollOffset: false);

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  VoidCallback? _tapOf(PeerStripItem item) {
    final id = item.id;
    switch (item.act) {
      case PeerItemAct.tab:
        return () => widget.onSelect(id);
      case PeerItemAct.add:
        return id == null ? null : () => widget.onAdd(id);
      case PeerItemAct.none:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    final width = _itemWidth(scaler);
    final items = widget.items;
    // The first addable item sits 10 px further from the shelf (M:38).
    final firstAdd = items.indexWhere((i) => i.kind == PeerItemKind.add);
    return Semantics(
      container: true,
      label: l.peerRecsPeers,
      child: SizedBox(
        height: _stripHeight(context, scaler),
        child: Material(
          type: MaterialType.transparency,
          child: ListView.builder(
            controller: _scroll,
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: _kPadV),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final item = items[i];
              return Padding(
                padding: EdgeInsetsDirectional.only(
                    start: i == 0 ? 0 : (i == firstAdd ? 14 : 4)),
                child: _PeerStripItemView(
                  key: ValueKey('peer-strip-${item.id ?? 'all'}'),
                  item: item,
                  width: width,
                  onTap: _tapOf(item),
                  l: l,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// One item: a single button of the circle, a 6 px gap and the label, as
/// wide as the item and as tall as the strip lets it be (≥ 68 × 92).
class _PeerStripItemView extends StatelessWidget {
  const _PeerStripItemView({
    super.key,
    required this.item,
    required this.width,
    required this.onTap,
    required this.l,
  });

  final PeerStripItem item;
  final double width;
  final VoidCallback? onTap;
  final AppLocalizations l;

  @override
  Widget build(BuildContext context) {
    final (label, colour) = _label();
    Widget body = SizedBox(
      width: width,
      child: Column(
        children: [
          _PeerCircle(item: item),
          const SizedBox(height: _kGap),
          // Flexible: a label taller than its two lines is clipped by its
          // own paragraph, never overflowing the item.
          Flexible(
            child: _StripLabel(
              label: label,
              colour: colour,
              width: width,
              // The app's own words (All, Adding…, Try again, No room) are
              // never broken inside a word, however far they must shrink.
              // A peer's name is the server's, of any length: it shrinks
              // only as far as the floor, and past it it wraps and ends in
              // an ellipsis.
              floor: item.kind == PeerItemKind.all ||
                      (item.kind == PeerItemKind.add && item.state != null)
                  ? 0
                  : _kNameFloor,
            ),
          ),
        ],
      ),
    );
    final tap = onTap;
    if (tap != null) {
      body = InkWell(
        onTap: tap,
        borderRadius: BorderRadius.circular(8),
        child: body,
      );
    }
    final noRoom = item.state == PeerAddView.noRoom;
    final tab = item.kind != PeerItemKind.add;
    return Semantics(
      container: true,
      // No room is not a button at all (plan §2 item 6); "Adding…" is one
      // that is disabled (M:133 aria-disabled).
      button: noRoom ? null : true,
      enabled: noRoom ? null : tap != null,
      selected: tab ? item.selected : null,
      label: _semanticsLabel(),
      value: _semanticsValue(),
      onTap: tap,
      excludeSemantics: true,
      child: body,
    );
  }

  /// The drawn label and its colour (design.md §4).
  (String, Color) _label() {
    switch (item.kind) {
      case PeerItemKind.all:
        return (
          l.peerRecsAll,
          item.selected ? VelvetColors.textPrimary : VelvetColors.textSecondary,
        );
      case PeerItemKind.peer:
        return (
          item.label,
          item.selected
              ? VelvetColors.textPrimary
              : (item.online
                  ? VelvetColors.textSecondary
                  : VelvetColors.helper),
        );
      case PeerItemKind.add:
        switch (item.state) {
          case null:
            return (item.label, VelvetColors.textSecondary);
          case PeerAddView.adding:
            return (l.peerRecsAdding, VelvetColors.textSecondary);
          case PeerAddView.failed:
            return (l.discoverPageRetry, VelvetColors.error);
          case PeerAddView.noRoom:
            return (l.peerRecsNoRoom, VelvetColors.helper);
        }
    }
  }

  String _semanticsLabel() {
    switch (item.kind) {
      case PeerItemKind.all:
        return l.peerRecsAll;
      case PeerItemKind.peer:
        return item.label;
      case PeerItemKind.add:
        return item.state == null ? l.peerRecsAddPeer(item.label) : item.label;
    }
  }

  String? _semanticsValue() {
    switch (item.kind) {
      case PeerItemKind.all:
        return null;
      case PeerItemKind.peer:
        return item.online ? l.p2pOnline : l.peerRecsOffline;
      case PeerItemKind.add:
        switch (item.state) {
          case null:
            return null;
          case PeerAddView.adding:
            return l.peerRecsAdding;
          case PeerAddView.failed:
            return l.discoverPageRetry;
          case PeerAddView.noRoom:
            return l.peerRecsNoRoom;
        }
    }
  }
}

/// An item's label: two centred lines that end in an ellipsis.
///
/// A word wider than the item is kept whole where it can be. The text
/// engine would split it by character ("hinzugefü" over a lone "…",
/// "Lighthous" over "e Tapes"), so the label is laid out as wide as its
/// widest word instead and scaled down to the item's width, as long as that
/// scale is at least [floor]. Past the floor the label wraps at the item's
/// width, and a word wider than the line is broken.
///
/// The app's own words have no floor. For them the shrink is the guard for
/// a translation or a text size the strings were not measured at; at the
/// sizes they were measured at (Roboto, 12 / w600 at 68 px and at 88 px)
/// every word already fits. A peer's name has [_kNameFloor].
class _StripLabel extends StatelessWidget {
  const _StripLabel({
    required this.label,
    required this.colour,
    required this.width,
    required this.floor,
  });

  final String label;
  final Color colour;
  final double width;

  /// The smallest scale the label may be drawn at; 0 for no floor.
  final double floor;

  @override
  Widget build(BuildContext context) {
    final style = _kLabel.copyWith(color: colour);
    final text = Text(
      label,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      textAlign: TextAlign.center,
      style: style,
    );
    final widest = _widestWord(context, style);
    if (widest <= width) return text;
    final laidOut = widest.ceilToDouble();
    if (width / laidOut < floor) return text;
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: SizedBox(width: laidOut, child: text),
    );
  }

  /// The label's minimum intrinsic width, measured as its own paragraph
  /// lays it out: its widest word, or a single character in Chinese and
  /// Japanese.
  ///
  /// The engine measures that width split only at spaces and between
  /// Chinese and Japanese characters. The line breaker also breaks after a
  /// hyphen and between Thai words, so a name such as "Hi-Fi-Lounge" can
  /// be shrunk onto one line (never past the floor) where it would have
  /// wrapped cleanly. No word is broken either way.
  double _widestWord(BuildContext context, TextStyle style) {
    final base = DefaultTextStyle.of(context);
    var effective = base.style.merge(style);
    // Text draws bold when the system asks for bold text; so does this.
    if (MediaQuery.boldTextOf(context)) {
      effective = effective.merge(const TextStyle(fontWeight: FontWeight.bold));
    }
    final painter = TextPainter(
      text: TextSpan(text: label, style: effective),
      textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      locale: Localizations.maybeLocaleOf(context),
      textHeightBehavior:
          base.textHeightBehavior ?? DefaultTextHeightBehavior.maybeOf(context),
    )..layout();
    final widest = painter.minIntrinsicWidth;
    painter.dispose();
    return widest;
  }
}

/// The 56 px circle of one item, with its ring, dot, badge or spinner drawn
/// around it (design.md §4's table).
class _PeerCircle extends StatelessWidget {
  const _PeerCircle({required this.item});

  final PeerStripItem item;

  @override
  Widget build(BuildContext context) {
    final ring = peerRing();
    Color? fill;
    BoxBorder? border;
    Widget? content;
    Widget? overlay;
    switch (item.kind) {
      case PeerItemKind.all:
        fill = peerAllFill();
        content = CustomPaint(
          key: const ValueKey('peer-strip-all-glyph'),
          size: const Size.square(24),
          painter: _AllGlyph(peerInk()),
        );
      case PeerItemKind.peer:
        fill = item.online
            ? peerCircleOnline(item.hue)
            : peerCircleOffline(item.hue);
        content = _monogram(Colors.black);
        if (item.online) {
          overlay = Positioned(
            right: 1,
            bottom: 1,
            child: _Dot(
              key: const ValueKey('peer-strip-dot'),
              size: 12,
              colour: peerOnlineDot(),
            ),
          );
        }
      case PeerItemKind.add:
        switch (item.state) {
          case null:
            content = Icon(Icons.add, size: 24, color: ring);
          case PeerAddView.adding:
            fill = peerCircleAdding(item.hue);
            content = _monogram(VelvetColors.textPrimary);
            // The ring spinner's stroke is centred on r = 30.5 (M:133): an
            // inside stroke of 2.5 in a 63.5 box.
            overlay = Positioned(
              left: (_kCircle - 63.5) / 2,
              top: (_kCircle - 63.5) / 2,
              child: SizedBox.square(
                dimension: 63.5,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  strokeAlign: CircularProgressIndicator.strokeAlignInside,
                  strokeCap: StrokeCap.round,
                  padding: EdgeInsets.zero,
                  color: ring,
                  backgroundColor: ring.withValues(alpha: .22),
                ),
              ),
            );
          case PeerAddView.failed:
            fill = VelvetColors.raised;
            border = Border.all(color: VelvetColors.error, width: 2);
            content = _monogram(VelvetColors.textPrimary);
            overlay = Positioned(
              right: -3,
              bottom: -3,
              child: _Dot(
                key: const ValueKey('peer-strip-badge'),
                size: 18,
                colour: VelvetColors.error,
                child: const Icon(Icons.priority_high,
                    size: 12, color: Colors.black),
              ),
            );
          case PeerAddView.noRoom:
            fill = VelvetColors.raised;
            border = Border.all(color: VelvetColors.border2, width: 1);
            content = _monogram(VelvetColors.helper);
        }
    }
    Widget circle = Container(
      key: const ValueKey('peer-strip-circle'),
      width: _kCircle,
      height: _kCircle,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: border,
      ),
      alignment: Alignment.center,
      child: content,
    );
    if (item.kind == PeerItemKind.add && item.state == null) {
      // The plain "+": a dashed ring and no fill (M:38).
      circle = CustomPaint(
        key: const ValueKey('peer-strip-dashed'),
        painter: _DashedRing(ring),
        child: circle,
      );
    }
    return SizedBox.square(
      dimension: _kCircle,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // The selected tab: a 2 px gap, then a 2 px ring, 64 across
          // (M:34, M:130).
          if (item.selected && item.kind != PeerItemKind.add)
            Positioned(
              left: -4,
              top: -4,
              child: Container(
                key: const ValueKey('peer-strip-ring'),
                width: _kCircle + 8,
                height: _kCircle + 8,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: ring, width: 2),
                ),
              ),
            ),
          circle,
          ?overlay,
        ],
      ),
    );
  }

  /// The server's monogram, verbatim: 18 / w700 / h 1.0, scaled with the
  /// text but never past the circle (it shrinks to fit there instead).
  Widget _monogram(Color colour) => Padding(
        padding: const EdgeInsets.all(4),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            item.monogram,
            maxLines: 1,
            softWrap: false,
            style: TextStyle(
              color: colour,
              fontSize: 18,
              fontWeight: FontWeight.w700,
              height: 1.0,
            ),
          ),
        ),
      );
}

/// A disc ringed 2 px in the page's ground: the online dot, the failed
/// badge.
class _Dot extends StatelessWidget {
  const _Dot({
    super.key,
    required this.size,
    required this.colour,
    this.child,
  });

  final double size;
  final Color colour;
  final Widget? child;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: colour,
          boxShadow: [BoxShadow(color: VelvetColors.bg, spreadRadius: 2)],
        ),
        child: child,
      );
}

/// All's glyph: M:34's three connected nodes, stroked 2 at 24 px.
class _AllGlyph extends CustomPainter {
  const _AllGlyph(this.colour);

  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final p = Paint()
      ..color = colour
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawCircle(const Offset(12, 5), 2.5, p);
    canvas.drawCircle(const Offset(5, 18.5), 2.5, p);
    canvas.drawCircle(const Offset(19, 18.5), 2.5, p);
    canvas.drawLine(const Offset(10.8, 7.2), const Offset(6.2, 16.2), p);
    canvas.drawLine(const Offset(13.2, 7.2), const Offset(17.8, 16.2), p);
    canvas.drawLine(const Offset(7.5, 18.5), const Offset(16.5, 18.5), p);
    canvas.restore();
  }

  @override
  bool shouldRepaint(_AllGlyph old) => old.colour != colour;
}

/// The "+" item's dashed 1.5 px ring, inside the 56 circle: 24 dashes, each
/// 60 % of its step.
class _DashedRing extends CustomPainter {
  const _DashedRing(this.colour);

  final Color colour;

  static const int _dashes = 24;
  static const double _width = 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: size.shortestSide / 2 - _width / 2,
    );
    final p = Paint()
      ..color = colour
      ..style = PaintingStyle.stroke
      ..strokeWidth = _width;
    const step = 2 * math.pi / _dashes;
    for (var i = 0; i < _dashes; i++) {
      canvas.drawArc(rect, -math.pi / 2 + i * step, step * .6, false, p);
    }
  }

  @override
  bool shouldRepaint(_DashedRing old) => old.colour != colour;
}
