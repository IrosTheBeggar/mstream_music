import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../objects/display_item.dart';
import '../objects/server.dart';
import '../singletons/api.dart';
import '../theme/velvet_theme.dart';
import 'player_panel.dart';
import 'playlist_name_dialog.dart';

/// Playlist picker sheet: a server's playlists (from the last ping) plus
/// a "New playlist" entry (named via the shared dialog). Pops with the
/// chosen/entered name, or null when dismissed. Used by the track sheet's
/// Add-to-playlist and the sonic path screen's Save-as-playlist — both
/// backing endpoints create missing playlists on the fly.
class PlaylistPickerSheet extends StatelessWidget {
  final Server server;

  /// The name "New playlist" offers in its dialog (an Instant mix's "Dolo
  /// Mix"), or null for an empty field.
  final String? newName;
  const PlaylistPickerSheet({super.key, required this.server, this.newName});

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
                  title: l.playlistsNew, action: l.create, initial: newName);
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

/// "Save as playlist" for [rows] on [server]: the picker (an existing
/// playlist is overwritten — the save-flow convention — and New playlist
/// opens its dialog on [newName]), then playlist/save with the rows'
/// paths, then "Added to …" or the failure line. The name joins the
/// server's playlists at once, so the pickers (and the next default name)
/// see it before the next ping refreshes the list.
Future<void> savePlaylistFlow(
    BuildContext context, Server server, List<DisplayItem> rows,
    {String? newName}) async {
  final l = AppLocalizations.of(context);
  final name = await showModalBottomSheet<String>(
    context: context,
    backgroundColor: VelvetColors.surface,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (_) => PlaylistPickerSheet(server: server, newName: newName),
  );
  final playlist = name?.trim();
  if (playlist == null || playlist.isEmpty) return;
  // Floating, so it clears the docked mini-player (a plain bottom snackbar
  // renders behind it).
  void toast(String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: PlayerPanel.kCollapsedHeight +
            MediaQuery.of(context).viewPadding.bottom +
            8,
      ),
    ));
  }

  try {
    await ApiManager()
        .savePlaylist(server, playlist, [for (final r in rows) ?r.data]);
    if (!server.playlists.contains(playlist)) server.playlists.add(playlist);
    toast(l.addedToPlaylist(playlist));
  } catch (_) {
    toast(l.trackAddToPlaylistFailed);
  }
}
