import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../objects/playlist.dart';
import '../singletons/playlists.dart';
import '../theme/velvet_theme.dart';
import '../widgets/playlist_name_dialog.dart';

class PlaylistsScreen extends StatelessWidget {
  const PlaylistsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.playlistsTitle)),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: VelvetColors.primary,
        foregroundColor: Colors.white,
        icon: Icon(Icons.add),
        label: Text(l.playlistsNew),
        onPressed: () => _showCreateDialog(context),
      ),
      body: StreamBuilder<List<Playlist>>(
        stream: PlaylistManager().stream,
        initialData: PlaylistManager().playlists,
        builder: (context, snapshot) {
          final list = snapshot.data ?? const <Playlist>[];
          if (list.isEmpty) {
            return _emptyState(context);
          }
          return ListView.separated(
            padding: EdgeInsets.fromLTRB(0, 0, 0, 96),
            itemCount: list.length,
            separatorBuilder: (_, _) =>
                Divider(height: 1, color: VelvetColors.border),
            itemBuilder: (context, i) {
              final p = list[i];
              return ListTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: VelvetColors.raised,
                    borderRadius:
                        BorderRadius.circular(VelvetColors.radiusSmall),
                  ),
                  child: Icon(Icons.queue_music,
                      color: VelvetColors.primary),
                ),
                title: Text(p.name,
                    style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: VelvetColors.textPrimary)),
                subtitle: Text(
                  l.trackCount(p.entries.length),
                  style: TextStyle(
                      color: VelvetColors.textSecondary, fontSize: 12),
                ),
                trailing: PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert,
                      color: VelvetColors.textSecondary),
                  onSelected: (cmd) async {
                    if (cmd == 'play') {
                      await PlaylistManager().playPlaylist(i);
                    } else if (cmd == 'rename') {
                      _showRenameDialog(context, i, p.name);
                    } else if (cmd == 'delete') {
                      await PlaylistManager().remove(i);
                    }
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'play', child: Text(l.play)),
                    PopupMenuItem(value: 'rename', child: Text(l.rename)),
                    PopupMenuItem(value: 'delete', child: Text(l.delete)),
                  ],
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => PlaylistDetailScreen(playlistIndex: i),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }

  Widget _emptyState(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.queue_music,
                size: 64, color: VelvetColors.textTertiary),
            SizedBox(height: 16),
            Text(l.playlistsEmptyTitle,
                style: TextStyle(
                    color: VelvetColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            Text(
              l.playlistsEmptyBody,
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: VelvetColors.textSecondary,
                  fontSize: 13,
                  height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateDialog(BuildContext context) async {
    final l = AppLocalizations.of(context);
    final result = await PlaylistNameDialog.show(context,
        title: l.playlistsNew, action: l.create);
    if (result != null && result.isNotEmpty) {
      await PlaylistManager().create(result);
    }
  }

  Future<void> _showRenameDialog(
      BuildContext context, int index, String currentName) async {
    final l = AppLocalizations.of(context);
    final result = await PlaylistNameDialog.show(context,
        title: l.playlistsRename, action: l.rename, initial: currentName);
    if (result != null && result.isNotEmpty) {
      await PlaylistManager().rename(index, result);
    }
  }
}

class PlaylistDetailScreen extends StatelessWidget {
  final int playlistIndex;
  const PlaylistDetailScreen({super.key, required this.playlistIndex});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<List<Playlist>>(
          stream: PlaylistManager().stream,
          initialData: PlaylistManager().playlists,
          builder: (context, snapshot) {
            final list = snapshot.data ?? const <Playlist>[];
            if (playlistIndex >= list.length) return Text(l.playlistFallbackTitle);
            return Text(list[playlistIndex].name);
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.play_arrow),
            tooltip: l.playAll,
            onPressed: () =>
                PlaylistManager().playPlaylist(playlistIndex),
          ),
        ],
      ),
      body: StreamBuilder<List<Playlist>>(
        stream: PlaylistManager().stream,
        initialData: PlaylistManager().playlists,
        builder: (context, snapshot) {
          final list = snapshot.data ?? const <Playlist>[];
          if (playlistIndex >= list.length) return SizedBox.shrink();
          final p = list[playlistIndex];
          if (p.entries.isEmpty) {
            return Center(
              child: Text(
                l.playlistEmptyDetail,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: VelvetColors.textSecondary, fontSize: 14),
              ),
            );
          }
          return ListView.separated(
            itemCount: p.entries.length,
            separatorBuilder: (_, _) =>
                Divider(height: 1, color: VelvetColors.border),
            itemBuilder: (context, i) {
              final e = p.entries[i];
              return ListTile(
                leading: Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: VelvetColors.raised,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text('${i + 1}',
                      style: TextStyle(
                          color: VelvetColors.textSecondary, fontSize: 12)),
                ),
                title: Text(e.title,
                    style: TextStyle(color: VelvetColors.textPrimary)),
                subtitle: e.artist != null
                    ? Text(e.artist!,
                        style:
                            TextStyle(color: VelvetColors.textSecondary))
                    : null,
                trailing: IconButton(
                  icon: Icon(Icons.close, color: VelvetColors.textTertiary),
                  onPressed: () => PlaylistManager()
                      .removeEntry(playlistIndex, i),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
