// Album grid view.
//
// Renders a list of DisplayItems with type='album' as a grid of
// rounded-corner cards with cover art (or a stylized "no art"
// placeholder when album_art_file is null). Tapping a card delegates
// to a passed-in handler so the same Browser navigation logic still
// drives drilldown.

import 'package:flutter/material.dart';

import '../objects/display_item.dart';
import '../theme/velvet_theme.dart';
import '../util/stream_url.dart';
import '../util/image_cache.dart';

class AlbumGrid extends StatelessWidget {
  final List<DisplayItem> items;
  final void Function(int index) onTap;
  // Optional: pass BrowserManager().sc so the letter-strip's jumpTo
  // actually moves the grid. When null, GridView uses its own
  // implicit controller.
  final ScrollController? controller;

  const AlbumGrid({
    super.key,
    required this.items,
    required this.onTap,
    this.controller,
  });

  // Layout constants exposed so the parent can compute the per-row
  // offset for the letter-strip's jumpTo without duplicating the
  // math. Keep in sync with the GridView config below.
  static const double padTop = 12;
  static const double padHorizontal = 12;
  static const double spacing = 12;
  static const double aspectRatio = 0.72;

  // Phones keep their 2/3 columns; wider panes scale by a ~220px target tile so
  // album cards don't balloon on a desktop window. Used by itemWidthFor and
  // rowHeightFor too, so the letter-strip jumpTo math stays in sync.
  static int columnsFor(double width) {
    if (width <= 400) return 2;
    if (width <= 600) return 3;
    return (width ~/ 220).clamp(4, 12);
  }

  static double itemWidthFor(double width) {
    final cols = columnsFor(width);
    return (width - padHorizontal * 2 - spacing * (cols - 1)) / cols;
  }

  static double rowHeightFor(double width) => itemWidthFor(width) / aspectRatio;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final crossAxisCount = columnsFor(width);
    // Decode cover art at the card's pixel width (computed once for the grid),
    // not the full source resolution — see artCacheSize.
    final cacheW = artCacheSize(itemWidthFor(width));

    return Container(
      color: VelvetColors.bg,
      child: GridView.builder(
        controller: controller,
        padding: EdgeInsets.fromLTRB(padHorizontal, padTop, padHorizontal, 80),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: spacing,
          mainAxisSpacing: spacing,
          childAspectRatio: aspectRatio,
        ),
        itemCount: items.length,
        itemBuilder: (context, i) {
          final item = items[i];
          return _AlbumCard(
            item: item,
            onTap: () => onTap(i),
            cacheWidth: cacheW,
          );
        },
      ),
    );
  }
}

class _AlbumCard extends StatelessWidget {
  final DisplayItem item;
  final VoidCallback onTap;
  final int cacheWidth;

  const _AlbumCard(
      {required this.item, required this.onTap, required this.cacheWidth});

  @override
  Widget build(BuildContext context) {
    final image = _buildArt();
    return Material(
      color: VelvetColors.card,
      borderRadius: BorderRadius.circular(VelvetColors.radiusLarge),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        splashColor: VelvetColors.primaryDim,
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
                child: image,
              ),
            ),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(8, 6, 8, 8),
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
    );
  }

  Widget _buildArt() {
    final aaFile = item.altAlbumArt ?? item.metadata?.albumArt;
    if (item.server != null && aaFile != null) {
      final url = buildAlbumArtUrl(item.server!, aaFile, compress: 'm');
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
