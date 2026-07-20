import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../objects/display_item.dart';
import '../objects/server.dart';
import '../screens/discover_screen.dart';
import '../singletons/api.dart';
import '../singletons/downloads.dart';
import '../singletons/settings.dart';
import '../theme/velvet_theme.dart';
import '../util/queue_actions.dart';
import '../util/stream_url.dart';
import 'player_panel.dart';
import 'playlist_name_dialog.dart';

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
      builder: (_) => _PlaylistPickerSheet(server: server),
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Track header, so the sheet self-identifies (matches the
          // streaming apps' long-press sheets).
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: VelvetColors.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (artist != null && artist.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      artist,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: VelvetColors.textSecondary,
                        fontSize: 12,
                      ),
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
    );
  }
}

/// Playlist picker for "Add to playlist": the track's server's playlists
/// (from the last ping) plus a "New playlist" entry — the add-song endpoint
/// creates missing playlists on the fly, so a name is all it needs. Pops
/// with the chosen/entered name, or null when dismissed.
class _PlaylistPickerSheet extends StatelessWidget {
  final Server server;
  const _PlaylistPickerSheet({required this.server});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l.trackAddToPlaylist,
                style: TextStyle(
                  color: VelvetColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          ListTile(
            dense: true,
            leading: Icon(Icons.add, color: VelvetColors.primary),
            title: Text(
              l.playlistsNew,
              style: TextStyle(color: VelvetColors.textPrimary, fontSize: 14),
            ),
            onTap: () async {
              final name = await PlaylistNameDialog.show(context,
                  title: l.playlistsNew, action: l.create);
              if (name == null || name.trim().isEmpty) return;
              if (context.mounted) Navigator.of(context).pop(name.trim());
            },
          ),
          if (server.playlists.isNotEmpty) ...[
            Divider(color: VelvetColors.border, height: 1),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: server.playlists.length,
                itemBuilder: (context, i) {
                  final name = server.playlists[i];
                  return ListTile(
                    dense: true,
                    leading: Icon(Icons.queue_music,
                        color: VelvetColors.textSecondary),
                    title: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: VelvetColors.textPrimary, fontSize: 14),
                    ),
                    onTap: () => Navigator.of(context).pop(name),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
