import 'package:flutter/material.dart';

import '../objects/playlist.dart';
import '../singletons/playlists.dart';
import '../theme/velvet_theme.dart';

class PlaylistsScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Playlists')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: VelvetColors.primary,
        foregroundColor: Colors.white,
        icon: Icon(Icons.add),
        label: Text('New playlist'),
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
            separatorBuilder: (_, __) =>
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
                  '${p.entries.length} track${p.entries.length == 1 ? '' : 's'}',
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
                    PopupMenuItem(value: 'play', child: Text('Play')),
                    PopupMenuItem(value: 'rename', child: Text('Rename')),
                    PopupMenuItem(value: 'delete', child: Text('Delete')),
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
    return Center(
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.queue_music,
                size: 64, color: VelvetColors.textTertiary),
            SizedBox(height: 16),
            Text('No playlists yet',
                style: TextStyle(
                    color: VelvetColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600)),
            SizedBox(height: 8),
            Text(
              'Create one with the New playlist button, then '
              'use the queue\'s Add-to-playlist swipe action to '
              'fill it.',
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
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VelvetColors.surface,
        title: Text('New playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(hintText: 'Name'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel',
                style: TextStyle(color: VelvetColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text('Create'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await PlaylistManager().create(result);
    }
  }

  Future<void> _showRenameDialog(
      BuildContext context, int index, String currentName) async {
    final controller = TextEditingController(text: currentName);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VelvetColors.surface,
        title: Text('Rename playlist'),
        content: TextField(
          controller: controller,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text('Cancel',
                style: TextStyle(color: VelvetColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text.trim()),
            child: Text('Rename'),
          ),
        ],
      ),
    );
    if (result != null && result.isNotEmpty) {
      await PlaylistManager().rename(index, result);
    }
  }
}

class PlaylistDetailScreen extends StatelessWidget {
  final int playlistIndex;
  const PlaylistDetailScreen({Key? key, required this.playlistIndex})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<List<Playlist>>(
          stream: PlaylistManager().stream,
          initialData: PlaylistManager().playlists,
          builder: (context, snapshot) {
            final list = snapshot.data ?? const <Playlist>[];
            if (playlistIndex >= list.length) return Text('Playlist');
            return Text(list[playlistIndex].name);
          },
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.play_arrow),
            tooltip: 'Play all',
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
                'Playlist is empty.\nAdd tracks via the queue.',
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: VelvetColors.textSecondary, fontSize: 14),
              ),
            );
          }
          return ListView.separated(
            itemCount: p.entries.length,
            separatorBuilder: (_, __) =>
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
