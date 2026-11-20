// The Peer Recommendations page's leads and what stands in for them (mStream
// docs/peer-recommendations-plan.md §4.2 "Drawing", §2 items 10, 14, 18
// and 24; the approved phone boards Main, States and Variants): the grid of
// cards, each a tile, a title and an artist with its play circle over the
// tile; the footer's "Preview all · Copy list"; the skeleton while the
// first answer is out; and the "No peers yet", "Nothing new" and "Try
// again" states. Scan pending is Discover's own card (the view draws it).
//
// Everything here draws what it is handed: the page's previews decide each
// circle, the art a card earned and which lead is live; the view decides
// what a tap does (a card opens #237's network-lead sheet or copies, a
// circle presses the page's previews). Nothing here plays or asks.

import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../objects/discovery.dart';
import '../../theme/velvet_theme.dart';
import '../../util/peer_recs_colours.dart';
import '../../util/peer_recs_rules.dart';
import '../../widgets/generated_tile.dart';
import 'discovery_widgets.dart' show DiscoveryPill;
import 'keep_copy_ui.dart' show KeepRing;

/// A card's side: two columns 12 apart inside 14 a side, at most 240 (plan
/// §2 item 24): 175 at 390 (board M:44), 167.5 at 375 (V:118), 160 at 360.
double peerCardWidth(double width) =>
    math.max(0, math.min((width - 28 - 12) / 2, 240));

/// The grid's width for a page [width]: two cards and their gap.
double peerGridWidth(double width) => 2 * peerCardWidth(width) + 12;

/// The grid's side inset, which the footer starts at too: 14 up to the
/// 240 cap, then the rest centres the grid (266 at 1024).
double peerGridInset(double width) => width.isFinite
    ? math.max(14, (width - peerGridWidth(width)) / 2)
    : 14;

/// Keys the page's tests (and the integration test) find the parts by.
Key peerCardKey(int index) => ValueKey('peer-card-$index');
const Key kPeerCardOpenKey = ValueKey('peer-card-open');
const Key kPeerCardPlayKey = ValueKey('peer-card-play');
const Key kPeerPreviewAllKey = ValueKey('peer-preview-all');
const Key kPeerCopyListKey = ValueKey('peer-copy-list');
const Key kPeerSkeletonCardKey = ValueKey('peer-skeleton-card');

/// True once the text is scaled up: card titles and artists then take two
/// lines (V:158), and the band grows (V:167).
bool _textScaled(BuildContext context, double size) =>
    MediaQuery.textScalerOf(context).scale(size) > size;

// ── grid ────────────────────────────────────────────────────────────────

/// The leads in rows of two (row-major, rows top-aligned so a larger text
/// size may leave them uneven; never a fixed-aspect GridView), 12 between
/// the columns and 14 between the rows, the grid centred (board M:43,
/// V:118, V:157).
class PeerLeadGrid extends StatelessWidget {
  final List<DiscoveryLead> leads;

  /// Each lead's play circle ([PeerCircle.hidden] without a provider).
  final PeerCircle Function(DiscoveryLead) circleOf;

  /// The art a lead's tile earned this visit (Deezer's, on cards).
  final Uri? Function(DiscoveryLead) artOf;

  /// The lead whose clip is the page's live one (its title in ink).
  final bool Function(DiscoveryLead) isLive;
  final void Function(DiscoveryLead) onOpen;
  final void Function(DiscoveryLead) onPlay;

  /// The preview plug-in's name as the sheet's rows show it (a busy
  /// circle's label: "Stop the Deezer preview").
  final String providerLabel;

  const PeerLeadGrid({
    super.key,
    required this.leads,
    required this.circleOf,
    required this.artOf,
    required this.isLive,
    required this.onOpen,
    required this.onPlay,
    required this.providerLabel,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final cardW = peerCardWidth(constraints.maxWidth);
      Widget card(int i) {
        final lead = leads[i];
        return PeerLeadCard(
          key: peerCardKey(i),
          lead: lead,
          width: cardW,
          circle: circleOf(lead),
          art: artOf(lead),
          live: isLive(lead),
          onOpen: () => onOpen(lead),
          onPlay: () => onPlay(lead),
          providerLabel: providerLabel,
        );
      }

      return Center(
        child: SizedBox(
          width: 2 * cardW + 12,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < leads.length; i += 2)
                Padding(
                  padding: EdgeInsets.only(top: i == 0 ? 0 : 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      card(i),
                      const SizedBox(width: 12),
                      if (i + 1 < leads.length)
                        card(i + 1)
                      else
                        SizedBox(width: cardW),
                    ],
                  ),
                ),
            ],
          ),
        ),
      );
    });
  }
}

/// One lead (board M:44): the card button — the tile, the title and the
/// artist — opens the lead and never plays; the play circle over the
/// tile's bottom-right corner, its sibling, plays and never opens.
class PeerLeadCard extends StatelessWidget {
  final DiscoveryLead lead;

  /// The card's width, and its tile's side.
  final double width;
  final PeerCircle circle;
  final Uri? art;
  final bool live;
  final VoidCallback onOpen;
  final VoidCallback onPlay;
  final String providerLabel;

  const PeerLeadCard({
    super.key,
    required this.lead,
    required this.width,
    required this.circle,
    this.art,
    this.live = false,
    required this.onOpen,
    required this.onPlay,
    required this.providerLabel,
  });

  @override
  Widget build(BuildContext context) {
    // One line each at text 1.0, two once the text is scaled (V:158).
    final lines = _textScaled(context, 14) ? 2 : 1;
    final tile = lead.tile;
    final open = MergeSemantics(
      child: Semantics(
        button: true,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            key: kPeerCardOpenKey,
            onTap: onOpen,
            borderRadius: BorderRadius.circular(VelvetColors.radiusLarge),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GeneratedTile(
                  size: width,
                  hue: tile?.hue,
                  letter: tile?.letter ?? '',
                  art: art,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 7, 2, 0),
                  child: Text(
                    lead.title,
                    maxLines: lines,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: live ? peerInk() : VelvetColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 20 / 14,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Text(
                    lead.artist,
                    maxLines: lines,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: VelvetColors.textSecondary,
                      fontSize: 12,
                      height: 16 / 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return SizedBox(
      width: width,
      child: Stack(
        children: [
          open,
          if (circle != PeerCircle.hidden)
            // 8 in from the tile's bottom-right corner: top 123 at 175
            // (M:44), 115.5 at 167.5 (V:118).
            Positioned(
              right: 8,
              top: width - 52,
              child: _PlayCircle(
                circle: circle,
                title: lead.title,
                providerLabel: providerLabel,
                onPlay: onPlay,
              ),
            ),
        ],
      ),
    );
  }
}

/// A card's 44 px play circle: amber with the play glyph, pause while its
/// clip plays, a still ring while it is asked for or loads, and muted — a
/// raised disc with a border and a quiet glyph — once the visit found no
/// preview for it. A muted circle stays drawn and takes the tap itself, so
/// a press on it neither plays nor opens the card under it (the webapp's
/// aria-disabled circle; plan [review]: never hidden).
class _PlayCircle extends StatelessWidget {
  final PeerCircle circle;
  final String title;
  final String providerLabel;
  final VoidCallback onPlay;
  const _PlayCircle({
    required this.circle,
    required this.title,
    required this.providerLabel,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final muted = circle == PeerCircle.muted;
    final on = VelvetColors.onPrimary;
    final (String label, Widget glyph) = switch (circle) {
      PeerCircle.playing => (
          l.peerRecsPauseTrack(title),
          Icon(Icons.pause, size: 22, color: on),
        ),
      PeerCircle.busy => (
          l.discoverLeadPreviewStopA11y(providerLabel),
          KeepRing(size: 20, color: on),
        ),
      PeerCircle.muted => (
          l.peerRecsPreviewTrack(title),
          Icon(Icons.play_arrow, size: 22, color: VelvetColors.helper),
        ),
      _ => (
          l.peerRecsPreviewTrack(title),
          Icon(Icons.play_arrow, size: 22, color: on),
        ),
    };
    final decoration = BoxDecoration(
      shape: BoxShape.circle,
      color: muted ? VelvetColors.raised : VelvetColors.primary,
      border: muted ? Border.all(color: VelvetColors.border2) : null,
      boxShadow: [
        BoxShadow(
          color: peerShadow(),
          offset: const Offset(0, 2),
          blurRadius: 8,
        ),
      ],
    );
    final Widget face;
    if (muted) {
      face = AbsorbPointer(
        child: Container(
          width: 44,
          height: 44,
          decoration: decoration,
          alignment: Alignment.center,
          child: glyph,
        ),
      );
    } else {
      // The disc and its shadow are painted under the ink's Material, not
      // as its Ink: a Material clips the ink it paints to its own box, which
      // cut the round shadow into a 44 px square. The ripple is still drawn
      // on the Material, over the disc, and the InkWell's border keeps it
      // inside the circle.
      face = Container(
        width: 44,
        height: 44,
        decoration: decoration,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPlay,
            child: Center(child: glyph),
          ),
        ),
      );
    }
    return Semantics(
      key: kPeerCardPlayKey,
      container: true,
      button: true,
      enabled: !muted,
      label: label,
      hint: muted ? l.peerRecsNoPreview : null,
      onTap: muted ? null : onPlay,
      excludeSemantics: true,
      child: face,
    );
  }
}

// ── footer ──────────────────────────────────────────────────────────────

/// Under the last row (board M:58): "Preview all" — only with a preview
/// plug-in (V:82 has none), pressed while its chain runs (the webapp's
/// aria-pressed, m.js peerRecsActsHtml) — and "Copy list", always. It
/// starts at the grid's left inset.
class PeerRecsFooter extends StatelessWidget {
  final bool showPreviewAll;

  /// The Preview all chain is live.
  final bool running;
  final VoidCallback onPreviewAll;
  final VoidCallback onCopyList;

  const PeerRecsFooter({
    super.key,
    required this.showPreviewAll,
    required this.running,
    required this.onPreviewAll,
    required this.onCopyList,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return LayoutBuilder(builder: (context, constraints) {
      final inset = peerGridInset(constraints.maxWidth);
      return Padding(
        padding: EdgeInsets.fromLTRB(inset, 10, inset, 16),
        child: Wrap(
          spacing: 8,
          // The pills' 44 px hit areas already space the rows.
          runSpacing: 0,
          children: [
            if (showPreviewAll)
              MergeSemantics(
                key: kPeerPreviewAllKey,
                child: Semantics(
                  toggled: running,
                  child: DiscoveryPill(
                    l.peerRecsPreviewAll,
                    icon: Icons.play_arrow,
                    primary: true,
                    onTap: onPreviewAll,
                  ),
                ),
              ),
            MergeSemantics(
              key: kPeerCopyListKey,
              child: DiscoveryPill(
                l.peerRecsCopyList,
                icon: Icons.content_copy,
                onTap: onCopyList,
              ),
            ),
          ],
        ),
      );
    });
  }
}

// ── states ──────────────────────────────────────────────────────────────

/// The page's word states, centred in the room under the bar and the strip
/// (boards S:82, S:117, S:152): "No peers yet"; "Nothing new" with New
/// seeds; and Try again alone, with no line (plan §2 item 18). Loading,
/// scan pending and ready are drawn elsewhere, so they draw nothing here.
class PeerRecsStateView extends StatelessWidget {
  final PeerRecsState state;
  final VoidCallback onRetry;
  final VoidCallback onNewSeeds;

  const PeerRecsStateView({
    super.key,
    required this.state,
    required this.onRetry,
    required this.onNewSeeds,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    Widget line(String text) => Semantics(
          liveRegion: true,
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: VelvetColors.textSecondary,
              fontSize: 15,
              height: 20 / 15,
            ),
          ),
        );
    final List<Widget> children = switch (state) {
      PeerRecsState.noPeers => [line(l.peerRecsNoPeers)],
      PeerRecsState.nothingNew => [
          line(l.peerRecsNothingNew),
          const SizedBox(height: 8),
          DiscoveryPill(
            l.discoverPageNewSeeds,
            icon: Icons.refresh,
            onTap: onNewSeeds,
          ),
        ],
      PeerRecsState.failed => [
          DiscoveryPill(
            l.discoverPageRetry,
            icon: Icons.refresh,
            primary: true,
            onTap: onRetry,
          ),
        ],
      _ => const [],
    };
    if (children.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: children,
        ),
      ),
    );
  }
}

/// While the first answer is out (board S:43-49): six cards in the grid's
/// geometry — a raised tile, a title bar and an artist bar — and no words.
class PeerRecsSkeleton extends StatelessWidget {
  const PeerRecsSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: LayoutBuilder(builder: (context, constraints) {
        final cardW = peerCardWidth(constraints.maxWidth);
        Widget block(double w, double h, double r) => Container(
              width: math.min(w, math.max(0, cardW - 4)),
              height: h,
              decoration: BoxDecoration(
                color: VelvetColors.raised,
                borderRadius: BorderRadius.circular(r),
              ),
            );
        // The key sits inside, so the two cards of a row are no keyed
        // siblings.
        Widget card() => SizedBox(
              width: cardW,
              child: Column(
                key: kPeerSkeletonCardKey,
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: cardW,
                    height: cardW,
                    decoration: BoxDecoration(
                      color: VelvetColors.raised,
                      borderRadius:
                          BorderRadius.circular(VelvetColors.radiusLarge),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(2, 11, 2, 0),
                    child: block(103, 12, 4),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(2, 8, 2, 2),
                    child: block(68, 10, 4),
                  ),
                ],
              ),
            );
        return Center(
          child: SizedBox(
            width: 2 * cardW + 12,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var row = 0; row < 3; row++)
                  Padding(
                    padding: EdgeInsets.only(top: row == 0 ? 0 : 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [card(), const SizedBox(width: 12), card()],
                    ),
                  ),
              ],
            ),
          ),
        );
      }),
    );
  }
}
