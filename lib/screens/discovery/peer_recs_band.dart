import 'dart:math' as math;

import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../objects/discovery.dart';
import '../../theme/velvet_theme.dart';
import '../../util/peer_recs_colours.dart';
import '../../util/peer_recs_rules.dart';
import '../../widgets/generated_tile.dart';
import 'keep_copy_ui.dart' show KeepRing;

/// Keys the page's tests (and the integration test) find the band's parts
/// by.
const Key kPeerBandToggleKey = ValueKey('peer-band-toggle');
const Key kPeerBandNextKey = ValueKey('peer-band-next');
const Key kPeerBandCloseKey = ValueKey('peer-band-close');
const Key kPeerBandLinkKey = ValueKey('peer-band-link');
const Key kPeerBandCoverKey = ValueKey('peer-band-cover');
const Key kPeerBandHairlineKey = ValueKey('peer-band-hairline');

/// The page's live preview, docked at the frame's bottom over the mini
/// player while a clip session is live (mStream
/// docs/peer-recommendations-plan.md §2 item 14, §4.2 "Band"; boards M:105
/// and V:167): a hairline of how far the clip has played, the lead's cover,
/// title and artist, the plug-in's attribution once the clip resolved (a
/// link back only when it is https), and ⏸/▶ ⏭ ✕. It draws what it is
/// handed; the page's previews do the rest.
class PeerRecsBand extends StatelessWidget {
  final DiscoveryLead lead;

  /// The art the clip earned (any provider's).
  final Uri? art;

  /// The resolved clip's attribution, drawn verbatim ("Preview from
  /// Deezer"); null until the clip resolves.
  final String? attribution;

  /// The clip's link back to the store; the attribution links to it only
  /// when it is https.
  final Uri? link;
  final PeerClipStatus status;

  /// Where the clip is. Only the hairline listens, so a tick never rebuilds
  /// the band.
  final ValueListenable<PeerClipProgress> progress;

  /// The preview plug-in's name as the sheet's rows show it (the busy
  /// button's "Stop the Deezer preview").
  final String providerLabel;

  /// A lead after this one can still be previewed (⏭ is off without).
  final bool hasNext;
  final VoidCallback onToggle;
  final VoidCallback onNext;
  final VoidCallback onClose;
  final void Function(Uri) onLink;

  const PeerRecsBand({
    super.key,
    required this.lead,
    this.art,
    this.attribution,
    this.link,
    required this.status,
    required this.progress,
    required this.providerLabel,
    required this.hasNext,
    required this.onToggle,
    required this.onNext,
    required this.onClose,
    required this.onLink,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scaler = MediaQuery.textScalerOf(context);
    // The band grows with the text (V:167: min 78, padded 8).
    final scaled = scaler.scale(15) > 15;
    // The row's least height, inside that padding.
    final rowMin = scaled ? 62.0 : 64.0;
    final tile = lead.tile;

    final titleStyle = TextStyle(
      color: VelvetColors.textPrimary,
      fontSize: 15,
      height: 18 / 15,
    );
    final artistStyle = TextStyle(
      color: VelvetColors.textSecondary,
      fontSize: 13,
      height: 16 / 13,
    );
    final title = Text(
      lead.title,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: titleStyle,
    );
    final artist = Text(
      lead.artist,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: artistStyle,
    );

    // The attribution shows once the clip resolved, never while it is still
    // asked for (or waits out a 429).
    final words = attribution;
    final resolved =
        status != PeerClipStatus.resolving && status != PeerClipStatus.waiting;
    final shown = resolved && words != null && words.isNotEmpty;
    final target = link;
    final linked = shown && target != null && target.isScheme('https');
    final attrStyle = TextStyle(
      color: VelvetColors.helper,
      fontSize: 12,
      height: 14 / 12,
      decoration: linked ? TextDecoration.underline : null,
      decorationColor: VelvetColors.helper,
    );

    final Widget text;
    if (!linked) {
      text = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          title,
          artist,
          if (shown)
            Text(
              words,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: attrStyle,
            ),
        ],
      );
    } else {
      // The link's hit area is 44 tall at every scale (plan [review];
      // design.md §11 item 12): the line keeps its own height in the
      // column, and the link itself, as wide as its words, sits over the
      // column's last 44 px. The row leaves room over and under the column
      // (8 px each at text 1.0), so the column is padded into it and the
      // link reaches down into the room under its line first. It then
      // reaches up over the artist and only a few pixels into the title,
      // as the board pads it 22 up and 8 down (M:105). A tap on the title
      // never leaves the app.
      final lineHeight = scaler.scale(12) * 14 / 12;
      final column = _lineHeight(context, titleStyle, scaler) +
          _lineHeight(context, artistStyle, scaler) +
          lineHeight;
      final room = math.max(0.0, (rowMin - column) / 2);
      text = ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Stack(
          alignment: AlignmentDirectional.bottomStart,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(vertical: room),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [title, artist, SizedBox(height: lineHeight)],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Align(
                alignment: AlignmentDirectional.bottomStart,
                child: Semantics(
                  key: kPeerBandLinkKey,
                  container: true,
                  link: true,
                  label: words,
                  onTap: () => onLink(target),
                  excludeSemantics: true,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    excludeFromSemantics: true,
                    onTap: () => onLink(target),
                    child: SizedBox(
                      height: math.max(44, lineHeight + room),
                      child: Padding(
                        padding: EdgeInsets.only(bottom: room),
                        child: Align(
                          alignment: AlignmentDirectional.bottomStart,
                          widthFactor: 1,
                          child: Text(
                            words,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: attrStyle,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    final (String toggleLabel, Widget toggleGlyph) = switch (status) {
      PeerClipStatus.playing => (
          l.peerRecsPauseTrack(lead.title),
          Icon(Icons.pause, size: 20, color: VelvetColors.onPrimary),
        ),
      PeerClipStatus.resolving ||
      PeerClipStatus.waiting ||
      PeerClipStatus.loading => (
          l.discoverLeadPreviewStopA11y(providerLabel),
          KeepRing(size: 20, color: VelvetColors.onPrimary),
        ),
      PeerClipStatus.paused || PeerClipStatus.idle => (
          l.peerRecsPreviewTrack(lead.title),
          Icon(Icons.play_arrow, size: 20, color: VelvetColors.onPrimary),
        ),
    };

    return Material(
      color: VelvetColors.raised,
      child: Stack(
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(minHeight: scaled ? 78 : 64),
            child: Padding(
              padding: scaled
                  ? const EdgeInsets.fromLTRB(14, 8, 4, 8)
                  : const EdgeInsets.fromLTRB(14, 0, 4, 0),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: rowMin),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          GeneratedTile(
                            key: kPeerBandCoverKey,
                            size: 44,
                            radius: VelvetColors.radiusSmall,
                            letterSize: 20,
                            hue: tile?.hue,
                            letter: tile?.letter ?? '',
                            art: art,
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: text),
                        ],
                      ),
                    ),
                    _BandButton(
                      key: kPeerBandToggleKey,
                      label: toggleLabel,
                      onTap: onToggle,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: VelvetColors.primary,
                        ),
                        alignment: Alignment.center,
                        child: toggleGlyph,
                      ),
                    ),
                    _BandButton(
                      key: kPeerBandNextKey,
                      label: l.peerRecsNextPreview,
                      onTap: hasNext ? onNext : null,
                      child: Icon(
                        Icons.skip_next,
                        size: 26,
                        color: hasNext
                            ? VelvetColors.textPrimary
                            : VelvetColors.textDim,
                      ),
                    ),
                    _BandButton(
                      key: kPeerBandCloseKey,
                      label: l.close,
                      onTap: onClose,
                      child: Icon(
                        Icons.close,
                        size: 22,
                        color: VelvetColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // The 2 px hairline over the top edge: how far the clip has
          // played (M:105). Decorative, and the only part that redraws per
          // tick.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: 2,
            child: IgnorePointer(
              child: ExcludeSemantics(
                child: ColoredBox(
                  color: VelvetColors.border,
                  child: ValueListenableBuilder<PeerClipProgress>(
                    valueListenable: progress,
                    builder: (context, p, _) => FractionallySizedBox(
                      key: kPeerBandHairlineKey,
                      alignment: AlignmentDirectional.centerStart,
                      widthFactor: _fraction(p),
                      heightFactor: 1,
                      child: ColoredBox(color: peerInk()),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A one-line [style]'s height as the band lays it out, in its own
/// Material, whose text style is the theme's bodyMedium.
double _lineHeight(BuildContext context, TextStyle style, TextScaler scaler) {
  final base = Theme.of(context).textTheme.bodyMedium ?? const TextStyle();
  final painter = TextPainter(
    text: TextSpan(text: 'A', style: base.merge(style)),
    textDirection: Directionality.maybeOf(context) ?? TextDirection.ltr,
    textScaler: scaler,
    maxLines: 1,
    textHeightBehavior: DefaultTextHeightBehavior.maybeOf(context),
  )..layout();
  final height = painter.height;
  painter.dispose();
  return height;
}

/// How far [p] is through its clip, 0..1 (0 before the length is known).
double _fraction(PeerClipProgress p) {
  final len = p.length.inMicroseconds;
  if (len <= 0) return 0;
  return (p.position.inMicroseconds / len).clamp(0.0, 1.0);
}

/// A 44 × 44 band button; off (and dimmed by its caller) while [onTap] is
/// null.
class _BandButton extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final Widget child;
  const _BandButton({
    super.key,
    required this.label,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) => Semantics(
        container: true,
        button: true,
        enabled: onTap != null,
        label: label,
        onTap: onTap,
        excludeSemantics: true,
        child: SizedBox(
          width: 44,
          height: 44,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Center(child: child),
          ),
        ),
      );
}
