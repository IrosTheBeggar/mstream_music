// Album grid view.
//
// Renders a list of DisplayItems with type='album' as a grid of
// rounded-corner cards with cover art (or a stylized "no art"
// placeholder when album_art_file is null). Tapping a card delegates
// to a passed-in handler so the same Browser navigation logic still
// drives drilldown.

import 'package:material_ui/material_ui.dart';

import '../objects/display_item.dart';
import '../theme/velvet_theme.dart';
import 'browse_keep_entry.dart' show KeepFocusAnchor;
import 'letter_strip.dart';
import '../util/stream_url.dart';
import '../util/image_cache.dart';

/// What one card of an [AlbumGrid] carries beyond its tap (a connected
/// server's album while browsing it: Keep a copy's ⋯ and long-press, its
/// copy's badge, the badge's word for a screen reader). See
/// [AlbumGridCard].
class AlbumCardExtras {
  final VoidCallback? onMore;
  final VoidCallback? onLongPress;
  final String? moreLabel;
  final Widget? coverBadge;
  final String? mark;
  final String? moreFocusKey;
  final String? cardFocusKey;
  const AlbumCardExtras({
    this.onMore,
    this.onLongPress,
    this.moreLabel,
    this.coverBadge,
    this.mark,
    this.moreFocusKey,
    this.cardFocusKey,
  });
}

class AlbumGrid extends StatelessWidget {
  final List<DisplayItem> items;
  final void Function(int index) onTap;
  // Optional: pass BrowserManager().sc so the letter-strip's jumpTo
  // actually moves the grid. When null, GridView uses its own
  // implicit controller.
  final ScrollController? controller;

  /// Right-edge space reserved for the overlaid letter strip. Without it the
  /// last column runs underneath the letters.
  final double gutter;

  /// Scrolled first, above the cards (a connected server's artist page:
  /// its header). Null: the cards start at the top.
  final Widget? header;

  /// What card [index] carries beyond its tap; null for a plain card.
  /// Asked as the card is laid out — on screen, or about to be — so a
  /// page's copy marks can ask for the cards a scroll brings in.
  final AlbumCardExtras? Function(int index)? extrasOf;

  const AlbumGrid({
    super.key,
    required this.items,
    required this.onTap,
    this.controller,
    this.gutter = 0,
    this.header,
    this.extrasOf,
  });

  // Layout constants exposed so the parent can compute the per-row
  // offset for the letter-strip's jumpTo without duplicating the
  // math. Keep in sync with the GridView config below.
  static const double padTop = 12;
  static const double padHorizontal = 12;
  static const double spacing = 12;
  static const double aspectRatio = 0.72;

  /// [gutter] is space reserved for an overlaid letter strip, on whichever
  /// edge LetterStrip.onLeft says it is.
  /// It has to reach every one of these: the strip sits ON TOP of the grid, so
  /// tiles laid out under it are half-hidden, and the letter-jump offset is
  /// derived from row height, which moves as soon as the usable width does.
  /// Threading it through all three keeps the two in agreement.
  static int columnsFor(double width, [double gutter = 0]) {
    final w = width - gutter;
    return w > 600 ? 4 : (w > 400 ? 3 : 2);
  }

  static double itemWidthFor(double width, [double gutter = 0]) {
    final cols = columnsFor(width, gutter);
    return (width - gutter - padHorizontal * 2 - spacing * (cols - 1)) / cols;
  }

  static double rowHeightFor(double width, [double gutter = 0]) =>
      itemWidthFor(width, gutter) / aspectRatio;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = columnsFor(width, gutter);
    // Decode cover art at the card's pixel width (computed once for the grid),
    // not the full source resolution — see artCacheSize.
    final cacheW = artCacheSize(itemWidthFor(width, gutter));

    // A scroll view of slivers rather than a GridView so a header can be
    // the first thing it scrolls; with none it lays out as the grid did.
    return Container(
      color: VelvetColors.bg,
      child: CustomScrollView(
        controller: controller,
        slivers: [
          if (header != null) SliverToBoxAdapter(child: header),
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
                padHorizontal + (LetterStrip.onLeft ? gutter : 0),
                padTop,
                padHorizontal + (LetterStrip.onLeft ? 0 : gutter),
                80),
            sliver: SliverGrid(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: spacing,
                mainAxisSpacing: spacing,
                childAspectRatio: aspectRatio,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, i) {
                  final item = items[i];
                  final x = extrasOf?.call(i);
                  return AlbumGridCard(
                    item: item,
                    onTap: () => onTap(i),
                    cacheWidth: cacheW,
                    onMore: x?.onMore,
                    onLongPress: x?.onLongPress,
                    moreLabel: x?.moreLabel,
                    coverBadge: x?.coverBadge,
                    mark: x?.mark,
                    moreFocusKey: x?.moreFocusKey,
                    cardFocusKey: x?.cardFocusKey,
                  );
                },
                childCount: items.length,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// One album card: cover art, name, subtext. Public so Discover's album
/// strips draw the browser's own album look (browser.dart).
class AlbumGridCard extends StatelessWidget {
  final DisplayItem item;
  final VoidCallback onTap;
  final int cacheWidth;

  /// A long-press on the card (Discover's connected-server cards: the album
  /// sheet). Null: tap only, as every other card.
  final VoidCallback? onLongPress;

  /// A ⋯ in the bottom-right of the card's text block, never over the
  /// cover's tap target (Discover's connected-server cards). Null: none.
  final VoidCallback? onMore;

  /// The ⋯'s accessible name ("More for Borrowed Tapes").
  final String? moreLabel;

  /// Drawn inside the cover, bottom-left (a copy's state on Discover).
  final Widget? coverBadge;

  /// The badge's word, said after the card's title and subtext
  /// ("Borrowed Tapes, Boukmanflow · 2019, in your collection") — the
  /// badge itself is drawn, never read.
  final String? mark;

  /// The ⋯'s stable key: focus comes back to it when the sheet it opened
  /// closes (BrowseKeepEntry).
  final String? moreFocusKey;

  /// The card's own stable key (its long-press opened the sheet: focus goes
  /// back to the card, not its ⋯).
  final String? cardFocusKey;

  const AlbumGridCard(
      {super.key,
      required this.item,
      required this.onTap,
      required this.cacheWidth,
      this.onLongPress,
      this.onMore,
      this.moreLabel,
      this.coverBadge,
      this.mark,
      this.moreFocusKey,
      this.cardFocusKey});

  /// What a screen reader says for the card: its title, its subtext and
  /// its copy's word, joined with ", ".
  String get semanticsLabel => [
        item.name,
        if (item.subtext != null && item.subtext!.isNotEmpty) item.subtext!,
        if (mark != null && mark!.isNotEmpty) mark!,
      ].join(', ');

  @override
  Widget build(BuildContext context) {
    final image = _buildArt();
    final card = Material(
      color: VelvetColors.card,
      borderRadius: BorderRadius.circular(VelvetColors.radiusLarge),
      clipBehavior: Clip.antiAlias,
      // One node for the card, its tap (and long-press) on it; the texts and
      // the badge inside are drawn, the label says them.
      child: Semantics(
        container: true,
        button: true,
        label: semanticsLabel,
        child: KeepFocusAnchor(
          focusKey: cardFocusKey,
          builder: (context, node) => InkWell(
            focusNode: node,
            onTap: onTap,
            onLongPress: onLongPress,
            splashColor: VelvetColors.primaryDim,
            child: ExcludeSemantics(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AspectRatio(
                    aspectRatio: 1,
                    child: ClipRRect(
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(VelvetColors.radiusLarge),
                        topRight: Radius.circular(VelvetColors.radiusLarge),
                      ),
                      child: coverBadge == null
                          ? image
                          : Stack(
                              fit: StackFit.expand,
                              children: [
                                image,
                                Positioned(
                                  left: 6,
                                  bottom: 6,
                                  right: 6,
                                  child: Align(
                                    alignment: Alignment.bottomLeft,
                                    child: coverBadge!,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      // Room on the title's right for the ⋯ when there is one.
                      padding:
                          EdgeInsets.fromLTRB(8, 6, onMore == null ? 8 : 26, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Flexible(
                            child: Text(
                              item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: VelvetColors.textPrimary,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ),
                          if (item.subtext != null && item.subtext!.isNotEmpty)
                            Flexible(
                              child: Padding(
                                padding: EdgeInsets.only(top: 1),
                                child: Text(
                                  item.subtext!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: VelvetColors.textSecondary,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    if (onMore == null) return card;
    // The ⋯'s 44 px hit area covers the text block's right end only — the
    // cover above it keeps the tap that opens the album. Its own node (the
    // band's rect, after the card's in reading order), its tap and focus
    // the InkWell's: focus coming back to it is where a screen reader is.
    return LayoutBuilder(builder: (context, box) {
      final textHeight = box.maxHeight.isFinite
          ? (box.maxHeight - box.maxWidth).clamp(0.0, double.infinity)
          : 48.0;
      return Stack(
        children: [
          Positioned.fill(child: card),
          Positioned(
            right: 0,
            bottom: 0,
            width: 44,
            height: textHeight < 44 ? 44 : textHeight,
            child: Semantics(
              key: ValueKey('album-card-more-node-${item.name}'),
              container: true,
              button: true,
              label: moreLabel,
              child: Material(
                type: MaterialType.transparency,
                child: KeepFocusAnchor(
                  focusKey: moreFocusKey,
                  builder: (context, node) => InkWell(
                    key: ValueKey('album-card-more-${item.name}'),
                    focusNode: node,
                    onTap: onMore,
                    borderRadius: BorderRadius.only(
                      bottomRight: Radius.circular(VelvetColors.radiusLarge),
                    ),
                    child: ExcludeSemantics(
                      child: Align(
                        alignment: Alignment.topRight,
                        child: Padding(
                          padding: const EdgeInsets.only(top: 5, right: 6),
                          child: Icon(Icons.more_horiz,
                              size: 18, color: VelvetColors.textSecondary),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildArt() {
    final aaFile = item.altAlbumArt ?? item.metadata?.albumArt;
    if (item.server != null && aaFile != null) {
      // 'l': the server's 256 px rendition, the webapp's album-card size.
      // mStream caches only 's' (92 px) and 'l'; any other value serves the
      // full-size original, which is what 'm' quietly did here.
      final url = buildAlbumArtUrl(item.server!, aaFile, compress: 'l');
      return Image.network(
        url,
        fit: BoxFit.cover,
        cacheWidth: cacheWidth,
        errorBuilder: (_, _, _) => _NoArtPlaceholder(),
        loadingBuilder: (_, child, prog) => prog == null
            ? child
            : Container(
                color: VelvetColors.raised,
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation(VelvetColors.primary),
                    ),
                  ),
                ),
              ),
      );
    }
    return _NoArtPlaceholder();
  }
}

/// Stylized "no art" placeholder mirroring the Velvet web UI's
/// no-art-wave bars.
class _NoArtPlaceholder extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: Alignment.center,
          radius: 0.6,
          colors: [
            VelvetColors.primary.withValues(alpha: 0.18),
            VelvetColors.surface,
          ],
        ),
      ),
      child: Center(
        child: SizedBox(
          width: 56,
          height: 36,
          child: CustomPaint(painter: _WaveBarsPainter()),
        ),
      ),
    );
  }
}

class _WaveBarsPainter extends CustomPainter {
  static const _heights = [0.45, 0.9, 0.6, 0.8, 0.4];

  @override
  void paint(Canvas canvas, Size size) {
    final n = _heights.length;
    final gap = size.width * 0.04;
    final w = (size.width - gap * (n - 1)) / n;
    final paint = Paint()..color = VelvetColors.textSecondary.withValues(alpha: 0.55);
    for (int i = 0; i < n; i++) {
      final h = _heights[i] * size.height;
      final left = i * (w + gap);
      final cy = size.height / 2;
      canvas.drawRRect(
        RRect.fromLTRBR(left, cy - h / 2, left + w, cy + h / 2,
            Radius.circular(w / 3)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_) => false;
}
