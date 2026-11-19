import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../objects/discovery.dart';
import '../../objects/server.dart';
import '../../theme/velvet_theme.dart';
import '../discover_screen.dart' show MatchMeter;
import 'discovery_page_controller.dart' show discoveryLeadArtItem;

/// One lead row on More like this ("From the network" / "From your
/// peers"): a song in someone else's library, which the phone cannot play.
/// Its title, "Artist · Genre · Peer" and how close it sounds to the seed
/// (the match meter).
///
/// Two ways it reads (the design canvas's Main and Degraded boards):
///  • sheet — a "From the network" row whose tap opens the network-lead
///    sheet (the user's own server's plug-ins can offer something for it:
///    util/network_sheet_gate.dart networkLeadTap). The whole row is one
///    button, at least [kSheetRowMinHeight] tall, with the network's globe
///    and the meter alone at its end — "Open on MusicBrainz" is one of the
///    sheet's rows.
///  • copy — today's row, for every other lead (a federation row, plug-ins
///    off, a row the plug-in routes would not take): a federation lead's
///    cover or the lead glyph, a MusicBrainz link-out when the row names a
///    recording, and a tap that copies "Artist - Title" (the caller's
///    [onTap]: "Copied — go find it!").
class DiscoveryLeadRow extends StatelessWidget {
  final DiscoveryLead lead;

  /// The tap opens the network-lead sheet (else it copies).
  final bool opensSheet;

  /// The seed's server: a federation lead's cover comes through its
  /// federation art proxy (copy mode only).
  final Server? artServer;

  /// The row's tap: the sheet, or the copy.
  final VoidCallback onTap;

  /// Copy mode's link-out, shown when the row names a recording.
  final VoidCallback? onOpenMusicBrainz;

  const DiscoveryLeadRow({
    super.key,
    required this.lead,
    required this.opensSheet,
    required this.onTap,
    this.artServer,
    this.onOpenMusicBrainz,
  });

  /// A sheet row's least height: a two-line row is taller already (a dense
  /// list tile's 64); one with no second line is raised to it.
  static const double kSheetRowMinHeight = 56;

  /// "Artist · Genre · Peer", null parts left out (a network row has no
  /// genre).
  String get subtitle {
    final genre = genreTagLabel(lead.genreTags, max: 1);
    return [
      if (lead.artist.isNotEmpty) lead.artist,
      ?genre,
      ?lead.peerName,
    ].join(' · ');
  }

  @override
  Widget build(BuildContext context) =>
      opensSheet ? _sheetRow(context) : _copyRow(context);

  Widget _title() => Text(
    lead.title,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: TextStyle(fontSize: 15, color: VelvetColors.textPrimary),
  );

  Widget? _subtitle(String line) => line.isEmpty
      ? null
      : Text(
          line,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 13, color: VelvetColors.textSecondary),
        );

  Widget _sheetRow(BuildContext context) {
    final line = subtitle;
    return Semantics(
      button: true,
      child: ListTile(
        dense: true,
        minTileHeight: line.isEmpty ? kSheetRowMinHeight : null,
        leading: Icon(
          Icons.public,
          color: VelvetColors.textSecondary,
          size: 22,
        ),
        title: _title(),
        subtitle: _subtitle(line),
        trailing: MatchMeter(similarity: lead.similarity),
        onTap: onTap,
      ),
    );
  }

  Widget _copyRow(BuildContext context) {
    final l = AppLocalizations.of(context);
    final musicBrainz = onOpenMusicBrainz;
    return ListTile(
      dense: true,
      // A federation lead with albumArt shows its cover, fetched through
      // the seed server's federation art proxy; otherwise the lead icon.
      leading:
          discoveryLeadArtItem(artServer, lead)?.getAlbumThumb(size: 44) ??
          Icon(
            Icons.travel_explore,
            color: VelvetColors.textSecondary,
            size: 22,
          ),
      title: _title(),
      subtitle: _subtitle(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (lead.recordingMbid != null && musicBrainz != null)
            IconButton(
              icon: Icon(
                Icons.open_in_new,
                color: VelvetColors.textSecondary,
                size: 18,
              ),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: l.discoverOpenMusicBrainz,
              onPressed: musicBrainz,
            ),
          MatchMeter(similarity: lead.similarity),
        ],
      ),
      onTap: onTap,
    );
  }
}
