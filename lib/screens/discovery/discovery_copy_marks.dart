import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/velvet_theme.dart';
import '../../util/discover_badges.dart';
import 'discovery_keep_routes.dart';
import 'discovery_page_controller.dart';
import 'keep_copy_ui.dart';

/// What Discover's page shows of the copies (the design canvas's
/// PhoneDiscover board): a word and a glyph on a connected server's song
/// row (its 4 px strip filling with the copy), a badge inside an album
/// card's cover ("copying 2 of 3" — songs done of the album's), and the
/// Copies strip under the configuration bar ("Copying 2 · 1 failed ›").
/// Only connected servers' rows and cards carry markers, and only for that
/// server's copies (DiscoveryJobsController.markerFor / cardMarker).

/// A marked row's second line: the glyph and the word (13/500, primary
/// text) lead, then the row's own "Artist · Album" in the secondary text as
/// on its unmarked neighbours. The row keeps its height.
class DiscoveryRowMarkerLine extends StatelessWidget {
  final CopyMarker marker;
  final String? rest;

  /// An album's row (the album grid off): a copy that says how far it is
  /// reads "copying 2 of 3", as the album card's badge does. A song row
  /// never counts.
  final bool counts;
  const DiscoveryRowMarkerLine({
    super.key,
    required this.marker,
    this.rest,
    this.counts = false,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final hasRest = rest != null && rest!.isNotEmpty;
    return Row(
      key: ValueKey('discovery-row-marker-${marker.kind.name}'),
      children: [
        keepMarkerGlyph(marker, size: 14),
        const SizedBox(width: 4),
        // Alone on its line (an album page's song row) the word shrinks to
        // the row at any text size; beside "· Artist · Album" it keeps its
        // width and the rest gives way.
        Flexible(
          flex: hasRest ? 0 : 1,
          child: Text(
            keepMarkerWord(l, marker, card: counts),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: VelvetColors.textPrimary,
            ),
          ),
        ),
        if (hasRest) ...[
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              '· ${rest!}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: VelvetColors.textSecondary),
            ),
          ),
        ],
      ],
    );
  }
}

/// A connected server's song row's 4 px strip while its copy moves: primary
/// on a border track, filling bottom-up with the copy's fraction (a
/// sliding segment while the server cannot say). Null when the row's strip
/// is the phone download's as ever.
Widget? discoveryRowCopyStrip(CopyMarker? marker) {
  if (marker == null || !marker.showsStrip) return null;
  return RotatedBox(
    key: const ValueKey('discovery-row-copy-strip'),
    quarterTurns: 3,
    child: LinearProgressIndicator(
      value: marker.fraction,
      valueColor: AlwaysStoppedAnimation(
        marker.kind == CopyMarkerKind.stopping
            ? VelvetColors.textTertiary
            : VelvetColors.primary,
      ),
      backgroundColor: VelvetColors.border,
    ),
  );
}

/// The badge inside a connected server's album cover: 22 px, black 72 %,
/// a 12 px glyph and an 11/600 white word, ellipsized; the card keeps its
/// size. Browsing a connected server ([fit]: its Albums grid, an artist's
/// page) it is the glyph alone above 1.3× text, or where its word does not
/// fit the card (the cover's width less 16) — a 24 px circle of the same
/// fill, the glyph 14 px white — and the word lives in the card's
/// accessible label; [glyphOnly] forces it (a list row's 48 px thumb).
/// Discover's strip keeps its ellipsized word. Drawn only: the card says
/// the word.
class DiscoveryCardBadge extends StatelessWidget {
  final CopyMarker marker;
  final bool glyphOnly;
  final bool fit;
  const DiscoveryCardBadge({
    super.key,
    required this.marker,
    this.glyphOnly = false,
    this.fit = false,
  });

  static const Color _scrim = Color(0xB8000000);
  static const TextStyle _word = TextStyle(
    color: Colors.white,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );

  /// The badge's glyph in white, for the glyph-only form.
  static Widget _whiteGlyph(CopyMarker m) => switch (m.kind) {
    CopyMarkerKind.waiting => const Icon(
      Icons.schedule,
      size: 14,
      color: Colors.white,
    ),
    CopyMarkerKind.copying ||
    CopyMarkerKind.stopping => const KeepRing(size: 14, color: Colors.white),
    CopyMarkerKind.inCollection || CopyMarkerKind.alreadyYours => const Icon(
      Icons.check_circle_outline,
      size: 14,
      color: Colors.white,
    ),
    CopyMarkerKind.stopped ||
    CopyMarkerKind.refused ||
    CopyMarkerKind.skipped ||
    CopyMarkerKind.failed => const Icon(
      Icons.warning_amber_rounded,
      size: 14,
      color: Colors.white,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final word = keepMarkerWord(l, marker, card: true);
    final ts = MediaQuery.textScalerOf(context);
    return ExcludeSemantics(
      child: LayoutBuilder(
        builder: (context, box) {
          var glyph = glyphOnly || (fit && ts.scale(1) > 1.3);
          if (!glyph && fit && box.maxWidth.isFinite) {
            final p = TextPainter(
              text: TextSpan(text: word, style: _word),
              textDirection: TextDirection.ltr,
              textScaler: ts,
              maxLines: 1,
            )..layout();
            // 6 + glyph 12 + 4 + the word + 8, inside the cover less 16.
            glyph = p.width + 30 > box.maxWidth - 4;
            p.dispose();
          }
          if (glyph) {
            return Container(
              key: ValueKey('discovery-card-badge-glyph-${marker.kind.name}'),
              width: 24,
              height: 24,
              decoration: const BoxDecoration(
                color: _scrim,
                shape: BoxShape.circle,
              ),
              child: Center(child: _whiteGlyph(marker)),
            );
          }
          return Container(
            key: ValueKey('discovery-card-badge-${marker.kind.name}'),
            height: 22,
            padding: const EdgeInsets.fromLTRB(6, 0, 8, 0),
            decoration: BoxDecoration(
              color: _scrim,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                keepMarkerGlyph(marker, size: 12, onScrim: true),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    word,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: _word,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// The height of the Copies strip (and of the place it holds).
const double kDiscoverCopiesStripHeight = 44;

/// The Copies strip under the configuration bar, shown only while a copy
/// is live or failed: "Copying 2 · 1 failed ›" (each part only when its
/// count is above 0); a tap opens the Copies sheet. While the visit's first
/// job list is still out its place is held, so the strip landing moves
/// nothing below it; it comes and goes with an eased height otherwise.
class DiscoveryCopiesStrip extends StatelessWidget {
  final DiscoveryPageController controller;
  const DiscoveryCopiesStrip({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final jobs = controller.jobs;
    final summary = jobs.summary;
    final shown = jobs.copiesVisible && summary.shown;
    final holding =
        !shown &&
        jobs.pluginsOn &&
        !jobs.jobsLoaded &&
        jobs.jobsError == null &&
        (jobs.listing == null ? !jobs.listingFailed : jobs.copiesVisible);
    final Widget child;
    if (shown) {
      child = _strip(context, summary.running, summary.failed);
    } else if (holding) {
      child = Container(
        key: const ValueKey('discovery-copies-held'),
        height: kDiscoverCopiesStripHeight,
        decoration: BoxDecoration(
          color: VelvetColors.bg,
          border: Border(bottom: BorderSide(color: VelvetColors.border)),
        ),
      );
    } else {
      child = const SizedBox(width: double.infinity);
    }
    return AnimatedSize(
      key: const ValueKey('discovery-copies-slot'),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      alignment: Alignment.topCenter,
      child: child,
    );
  }

  Widget _strip(BuildContext context, int running, int failed) {
    final l = AppLocalizations.of(context);
    final jobs = controller.jobs;
    final strong = TextStyle(
      color: VelvetColors.textPrimary,
      fontSize: 14,
      fontWeight: FontWeight.w500,
    );
    final parts = [
      if (running > 0) l.discoverCopiesCopying(running),
      if (failed > 0) l.discoverCopiesFailed(failed),
    ];
    return Semantics(
      key: const ValueKey('discovery-copies-strip'),
      button: true,
      label: l.discoverCopiesLabel(parts.join(', ')),
      excludeSemantics: true,
      child: Material(
        color: VelvetColors.bg,
        child: InkWell(
          onTap: () => DiscoveryKeepRoutes.openCopies(context, jobs),
          splashColor: VelvetColors.primaryDim,
          child: Container(
            constraints: const BoxConstraints(
              minHeight: kDiscoverCopiesStripHeight,
            ),
            padding: const EdgeInsets.fromLTRB(16, 4, 10, 4),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: VelvetColors.border)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      if (running > 0) ...[
                        KeepRing(size: 16, color: keepInkOnPage()),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            parts.first,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: strong,
                          ),
                        ),
                      ],
                      if (running > 0 && failed > 0)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          child: Text(
                            '·',
                            style: TextStyle(
                              color: VelvetColors.textSecondary,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      if (failed > 0) ...[
                        Icon(
                          Icons.error_outline,
                          size: 16,
                          color: keepToneOnPage(VelvetColors.error),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            parts.last,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: strong,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: VelvetColors.textSecondary,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
