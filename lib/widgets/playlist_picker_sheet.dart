import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../objects/server.dart';
import '../singletons/api.dart';
import '../theme/velvet_theme.dart';
import 'playlist_name_dialog.dart';

/// A song's Add to playlist, the track sheet's and the queue's: the picker
/// (the [server]'s playlists + "New playlist", which the add-song endpoint
/// creates on the fly), then the add call for [path]. [toast] says how it
/// went, in the caller's own toast. Runs on [context], a context that
/// outlives the menu the action came from.
Future<void> addSongToPlaylistFlow(
  BuildContext context, {
  required Server server,
  required String path,
  required void Function(String message) toast,
}) async {
  final l = AppLocalizations.of(context);
  final name = await showModalBottomSheet<String>(
    context: context,
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
    toast(l.addedToPlaylist(playlist));
  } catch (_) {
    toast(l.trackAddToPlaylistFailed);
  }
}

/// Playlist picker sheet: a server's playlists (from the last ping) plus
/// a "New playlist" entry (named via the shared dialog). Pops with the
/// chosen/entered name, or null when dismissed. Used by Add to playlist
/// (the track sheet's and the queue's: [addSongToPlaylistFlow]) and the
/// sonic path screen's Save-as-playlist — both backing endpoints create
/// missing playlists on the fly.
class PlaylistPickerSheet extends StatelessWidget {
  final Server server;
  const PlaylistPickerSheet({super.key, required this.server});

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
