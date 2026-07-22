import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../objects/server.dart';
import '../theme/velvet_theme.dart';
import 'playlist_name_dialog.dart';

/// Playlist picker sheet: a server's playlists (from the last ping) plus
/// a "New playlist" entry (named via the shared dialog). Pops with the
/// chosen/entered name, or null when dismissed. Used by the track sheet's
/// Add-to-playlist and the sonic path screen's Save-as-playlist — both
/// backing endpoints create missing playlists on the fly.
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
