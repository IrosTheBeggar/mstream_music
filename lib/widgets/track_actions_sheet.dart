import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../objects/display_item.dart';
import '../screens/discover_screen.dart';
import '../singletons/api.dart';
import '../singletons/browser_list.dart';
import '../singletons/downloads.dart';
import '../singletons/settings.dart';
import '../theme/velvet_theme.dart';
import '../util/queue_actions.dart';
import '../util/media_format.dart';
import '../util/stream_url.dart';
import 'player_panel.dart';
import 'playlist_picker_sheet.dart';
import 'star_rating.dart';

/// Track context sheet, opened by long-pressing a browser row. Long-press on
/// a list row conventionally opens the item's context menu (Apple Music,
/// Spotify, Symfonium all do exactly this), so this sheet carries the same
/// queue actions the album-detail dropdown offers — the browser's first
/// per-track actions — plus Find similar when the track's server supports
/// discovery.
///
/// [parentContext] is a context ABOVE this sheet (the browser's), used for
/// follow-on navigation and snackbars after the sheet is popped — the
/// sheet's own context is gone once it closes.
class TrackActionsSheet extends StatelessWidget {
  final DisplayItem item;
  final BuildContext parentContext;
  const TrackActionsSheet(
      {super.key, required this.item, required this.parentContext});

  // Floating so it clears the docked mini-player overlay (a plain bottom
  // snackbar renders behind it) — same fix as the browser's other toasts.
  void _toast(String message) {
    ScaffoldMessenger.of(parentContext).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: PlayerPanel.kCollapsedHeight +
            MediaQuery.of(parentContext).viewPadding.bottom +
            8,
      ),
    ));
  }

  void _queuedToast() =>
      _toast(AppLocalizations.of(parentContext).browserSongsAdded(1));

  /// Playlist picker (existing playlists from the track's server + "New
  /// playlist", which the add-song endpoint creates on the fly), then the
  /// add call. Runs on [parentContext] — this sheet is already popped.
  Future<void> _addToPlaylist() async {
    final server = item.server;
    final path = item.data;
    if (server == null || path == null) return;
    final l = AppLocalizations.of(parentContext);
    final name = await showModalBottomSheet<String>(
      context: parentContext,
      backgroundColor: VelvetColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => PlaylistPickerSheet(server: server),
    );
    final playlist = name?.trim();
    if (playlist == null || playlist.isEmpty) return;
    try {
      await ApiManager().addSongToPlaylist(server, playlist, path);
      // Keep pickers fresh before the next ping refreshes the server's
      // playlist list.
      if (!server.playlists.contains(playlist)) {
        server.playlists.add(playlist);
      }
      _toast(l.addedToPlaylist(playlist));
    } catch (_) {
      _toast(l.trackAddToPlaylistFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final title =
        item.metadata?.title ?? (item.data ?? item.name).split('/').last;
    final artist = item.metadata?.artist;
    final m = item.metadata;
    // "Artist / Album" on one line - either half may be missing.
    final byline = [
      if (artist != null && artist.trim().isNotEmpty) artist.trim(),
      if (m?.album != null && m!.album!.trim().isNotEmpty) m.album!.trim(),
    ].join('  ·  ');
    // The monospace readout, in the album banner's vocabulary. Older servers
    // omit bitrate / sample rate and a local file has no server metadata at
    // all, so each part is independent and the line vanishes when empty.
    final specParts = <String>[
      if (m?.format != null && m!.format!.trim().isNotEmpty)
        m.format!.trim().toUpperCase(),
      if (m?.bitrate != null) formatBitrate(m!.bitrate!),
      if (m?.sampleRate != null) formatSampleRate(m!.sampleRate!),
      if (m?.duration != null) formatDuration(m!.duration!),
    ];
    // A file explorer row carries NO metadata when the read-metadata setting
    // is off, or when the file was never scanned into the library DB - so
    // "title is the filename and nothing else is known" is a common case, not
    // an edge one. Give the cover a slot only when something can balance it:
    // real art, or enough text beside it. A bare filename next to a 60px
    // empty placeholder reads worse than the plain centred title this
    // replaced, so that case keeps the centred treatment.
    final hasArt = item.server != null &&
        (item.altAlbumArt ?? m?.albumArt) != null;
    final showCover = hasArt || byline.isNotEmpty || specParts.isNotEmpty;
    final crossAlign =
        showCover ? CrossAxisAlignment.start : CrossAxisAlignment.center;
    final textAlign = showCover ? TextAlign.start : TextAlign.center;
    // Server tracks get the server-side verbs (download, playlists); local
    // files keep just the queue actions. Find similar additionally needs a
    // server that advertised discovery on ping — a downloaded copy's local
    // path can't address the similarity index.
    final isServerTrack =
        item.type == 'file' && item.server != null && item.data != null;
    final canFindSimilar =
        isServerTrack && item.server?.discoveryAvailable == true;

    Widget action(IconData icon, String label, VoidCallback onTap) {
      return ListTile(
        leading: Icon(icon, color: VelvetColors.textSecondary),
        title: Text(label, style: TextStyle(color: VelvetColors.textPrimary)),
        onTap: () {
          Navigator.of(context).pop();
          onTap();
        },
      );
    }

    return SafeArea(
      // Scrollable so the sheet can never overflow. The action list is
      // conditional (Add to end, the server-only pair, Find similar) and the
      // tallest combination plus the header outgrew the room a short screen —
      // or a large text scale — leaves. mainAxisSize.min keeps the sheet
      // hugging its content in the normal case where it fits.
      child: SingleChildScrollView(
        child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Track header: cover + title / artist + album + the monospace
          // format readout, so the sheet identifies the song by sight and not
          // only by name. Same FLAC / kbps / kHz vocabulary the album banner
          // already speaks.
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Grab handle - the accent-colour sheet has one and this
                // didn't; closing that inconsistency.
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 14),
                    decoration: BoxDecoration(
                      color: VelvetColors.border2,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                Builder(builder: (_) {
                  final text = Column(
                    crossAxisAlignment: crossAlign,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: showCover ? 1 : 2,
                        overflow: TextOverflow.ellipsis,
                        textAlign: textAlign,
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
                            textAlign: textAlign,
                            style: TextStyle(
                              color: VelvetColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      if (specParts.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            specParts.join('  ·  '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: textAlign,
                            style: TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 10,
                              letterSpacing: 0.2,
                              color: VelvetColors.textTertiary,
                            ),
                          ),
                        ),
                    ],
                  );
                  if (!showCover) return text;
                  return Row(
                    children: [
                      // Real art when there is any; otherwise a same-size
                      // placeholder tile, which only renders here because the
                      // text beside it can carry the pairing.
                      item.getAlbumThumb(size: 60),
                      const SizedBox(width: 14),
                      Expanded(child: text),
                    ],
                  );
                }),
                // Rating on its own labelled row rather than floating under
                // the title: it is the only control up here, so it should
                // read as one. Moved off the browser row when the overflow
                // button took that slot; writes through the same way - patch
                // the in-memory metadata, then re-emit so rows repaint.
                if (isServerTrack && item.metadata != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            l.trackRating,
                            style: TextStyle(
                                color: VelvetColors.textSecondary,
                                fontSize: 13),
                          ),
                        ),
                        // The box hugs the STARS, not the whole row. Around
                        // the label too it drew one control-sized affordance
                        // whose left half was inert — it read as a button
                        // that ignored taps. Only the stars take input, so
                        // only the stars get the frame.
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: VelvetColors.card,
                            border: Border.all(color: VelvetColors.border),
                            borderRadius: BorderRadius.circular(
                                VelvetColors.radiusSmall),
                          ),
                          child: RatingControl(
                            rating: item.metadata?.rating,
                            server: item.server!,
                            filepath: item.data!,
                            size: 18,
                            onChanged: (r) {
                              item.metadata?.rating = r;
                              BrowserManager().updateStream();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Divider(color: VelvetColors.border, height: 1),
          action(Icons.playlist_play, l.queueAddNext, () async {
            if (await addNext(item) != null) _queuedToast();
          }),
          action(Icons.play_arrow, l.queuePlayNow, () => playNow(item)),
          // Redundant when the row tap already appends (addToQueue /
          // appendAndJump tap behaviors) — same rule as the album-detail
          // dropdown.
          if (SettingsManager().tapBehavior == TapBehavior.playFromHere)
            action(Icons.queue_music, l.queueAddToEnd, () async {
              await addToQueueEnd(item);
              _queuedToast();
            }),
          if (isServerTrack) ...[
            action(Icons.playlist_add, l.trackAddToPlaylist, _addToPlaylist),
            // downloadOneFile does its own progress/error snackbars, so no
            // toast here; referenceItem keeps the row's download badge live.
            action(
              Icons.download_for_offline,
              l.download,
              () => DownloadManager().downloadOneFile(
                buildServerStreamUrl(item.server!, item.data!),
                item.server!.localname,
                item.data!,
                referenceItem: item,
              ),
            ),
          ],
          if (canFindSimilar)
            action(Icons.explore, l.discoverFindSimilar, () {
              Navigator.of(parentContext).push(MaterialPageRoute(
                builder: (_) => DiscoverScreen(
                  seedServer: item.server,
                  seedPath: item.data,
                  seedTitle: title,
                  seedArtist: artist,
                ),
              ));
            }),
          const SizedBox(height: 8),
        ],
        ),
      ),
    );
  }
}
