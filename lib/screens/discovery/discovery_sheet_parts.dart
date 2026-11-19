import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/velvet_theme.dart';
import 'keep_copy_ui.dart';

/// The parts Discover's item sheets share (the design canvas's track-sheet
/// shell): the grab handle, the header, the 52 px action row, the hairline
/// divider and the 60 px glyph tile. The connected server's song, album and
/// browse-entered sheets (peer_sheets.dart) and the network-lead sheet
/// (network_lead_sheet.dart) draw them alike.

/// The 36 × 4 grab bar in a 22 px band.
class DiscoverySheetGrabHandle extends StatelessWidget {
  const DiscoverySheetGrabHandle({super.key});

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 22,
    child: Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: VelvetColors.border2,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    ),
  );
}

/// The sheet header: cover, title, byline, the spec line, and whether the
/// connected server answers.
///
/// A browse-entered sheet ([browse]) gives the title two lines and the
/// byline [bylineLines] (a folder's path wraps between its crumbs), puts
/// [status] after the server's line ("● Stage Peer B online · 3 songs · no
/// subfolders"), draws the dot of a server not answering in the error
/// colour, and reads as one header node — the full title in it.
///
/// [sourceLines] are where a row comes from when no connected server
/// answers for it (the network-lead sheet's "From the network · Vinyl
/// Vault" and "88% match to “Tidewater”"): a 12 px line each, after the
/// spec line, wrapping to three at most (German at 200 % needs all three
/// to keep the seed's title); a header with them gives the title two lines
/// too. A header with no [peerName] draws no server line.
class DiscoverySheetHeader extends StatelessWidget {
  final Widget cover;
  final String title;
  final String byline;
  final String? spec;
  final String peerName;
  final bool answering;
  final bool browse;
  final List<String> sourceLines;
  const DiscoverySheetHeader({
    super.key,
    required this.cover,
    required this.title,
    required this.byline,
    this.spec,
    this.peerName = '',
    this.answering = true,
    this.browse = false,
    this.sourceLines = const [],
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final head = Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
      child: Row(
        children: [
          cover,
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: browse || sourceLines.isNotEmpty ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: VelvetColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (byline.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      byline,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: VelvetColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                if (spec != null && spec!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      spec!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        letterSpacing: 0.2,
                        color: VelvetColors.textTertiary,
                      ),
                    ),
                  ),
                for (final (i, line) in sourceLines.indexed)
                  Padding(
                    padding: EdgeInsets.only(top: i == 0 ? 4 : 2),
                    child: Text(
                      line,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: VelvetColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                if (peerName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      key: const ValueKey('peer-sheet-server'),
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: answering
                                ? keepTone(VelvetColors.success)
                                : (browse
                                      ? keepTone(VelvetColors.error)
                                      : VelvetColors.textTertiary),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            answering
                                ? l.discoverSheetPeerOnline(peerName)
                                : l.discoverSheetPeerNotAnswering(peerName),
                            maxLines: browse ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: VelvetColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (!browse) return head;
    // One header node: what the sheet is about, then where it comes from.
    return MergeSemantics(
      key: const ValueKey('browse-keep-header'),
      child: Semantics(header: true, child: head),
    );
  }
}

/// A 52 px action row: a 24 px icon, the label (and an optional second
/// line), an optional chevron. Not [enabled] (a folder's Listen before it
/// is counted): drawn at 45 %, inert, still in reach of a screen reader.
class DiscoverySheetActionRow extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final String? sub;
  final bool chevron;
  final bool enabled;
  final VoidCallback onTap;
  const DiscoverySheetActionRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.sub,
    this.chevron = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final row = _row();
    if (enabled) return row;
    return Semantics(
      button: true,
      enabled: false,
      label: [label, ?sub].join(', '),
      excludeSemantics: true,
      child: Opacity(opacity: 0.45, child: IgnorePointer(child: row)),
    );
  }

  Widget _row() => InkWell(
    onTap: onTap,
    splashColor: VelvetColors.primaryDim,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24,
              color: iconColor ?? VelvetColors.textSecondary,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: VelvetColors.textPrimary,
                      fontSize: 15,
                    ),
                  ),
                  if (sub != null)
                    Text(
                      sub!,
                      style: TextStyle(
                        color: VelvetColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
            ),
            if (chevron)
              Icon(
                Icons.chevron_right,
                size: 20,
                color: VelvetColors.textTertiary,
              ),
          ],
        ),
      ),
    ),
  );
}

/// The 1 px hairline between a sheet's parts.
Widget discoverySheetDivider() =>
    Divider(height: 1, thickness: 1, color: VelvetColors.border);

/// The 60 px tile of an artist (a circle, the person glyph) or a folder
/// (radius 7, the folder glyph in the warning colour) — and of a song with
/// no cover yet (radius 7, the network-lead sheet's public glyph).
Widget discoverySheetTile(
  IconData icon, {
  required BoxShape shape,
  double size = 28,
  Color? color,
}) => Container(
  width: 60,
  height: 60,
  decoration: BoxDecoration(
    shape: shape,
    color: VelvetColors.raised,
    borderRadius: shape == BoxShape.circle ? null : BorderRadius.circular(7),
    border: shape == BoxShape.circle
        ? Border.all(color: VelvetColors.border)
        : null,
  ),
  child: Icon(icon, size: size, color: color ?? VelvetColors.textSecondary),
);
