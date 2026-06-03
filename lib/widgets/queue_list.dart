import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:rxdart/rxdart.dart';

import '../l10n/app_localizations.dart';
import '../objects/metadata.dart';
import '../screens/metadata_screen.dart';
import '../singletons/downloads.dart';
import '../singletons/media.dart';
import '../theme/velvet_theme.dart';

/// Combined snapshot of the queue, the currently-playing item, and whether
/// playback is running — so a row can render the list, highlight the active
/// track, and show a live EQ / paused badge over its art.
class _QueueSnapshot {
  final List<MediaItem> queue;
  final MediaItem? current;
  final bool playing;
  const _QueueSnapshot(this.queue, this.current, this.playing);
}

Stream<_QueueSnapshot> _queueStream() =>
    Rx.combineLatest3<List<MediaItem>, MediaItem?, PlaybackState,
        _QueueSnapshot>(
      MediaManager().audioHandler.queue,
      MediaManager().audioHandler.mediaItem,
      MediaManager().audioHandler.playbackState,
      (q, m, s) => _QueueSnapshot(q, m, s.playing),
    );

Widget _artFallback() => Container(
      color: VelvetColors.raised,
      child:
          Icon(Icons.music_note, color: VelvetColors.textSecondary, size: 20),
    );

String _fmtDur(Duration? d) {
  if (d == null) return '';
  final mm = d.inMinutes.remainder(60).toString();
  final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return d.inHours > 0
      ? '${d.inHours}:${mm.padLeft(2, '0')}:$ss'
      : '$mm:$ss';
}

/// The "Up Next" queue list (design Variant B rows). Reads/writes the queue
/// purely through `MediaManager().audioHandler`, so it works identically
/// wherever it's mounted. Swipe a row for download / remove / info.
class QueueList extends StatelessWidget {
  const QueueList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return StreamBuilder<_QueueSnapshot>(
      stream: _queueStream(),
      builder: (context, snapshot) {
        final queue = snapshot.data?.queue ?? const <MediaItem>[];
        final current = snapshot.data?.current;
        final playing = snapshot.data?.playing ?? false;

        if (queue.isEmpty) {
          return Center(
            child: Text(
              l.mainQueueEmpty,
              style:
                  TextStyle(color: VelvetColors.textSecondary, fontSize: 13),
            ),
          );
        }

        return ListView.builder(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 8),
          itemCount: queue.length,
          itemBuilder: (BuildContext context, int index) {
            final item = queue[index];
            final active = item == current;
            final downloaded = item.extras?['localPath'] != null;

            return Slidable(
              key: Key(item.id),
              startActionPane: ActionPane(
                motion: const DrawerMotion(),
                extentRatio: 0.18,
                children: [
                  SlidableAction(
                    backgroundColor: Colors.blueGrey,
                    icon: Icons.download,
                    label: l.mainSync,
                    onPressed: (_) {
                      if (!downloaded) {
                        DownloadManager().downloadOneFile(item.id,
                            item.extras!['server'], item.extras!['path']);
                      }
                    },
                  ),
                ],
              ),
              endActionPane: ActionPane(
                motion: const DrawerMotion(),
                extentRatio: 0.36,
                dismissible: DismissiblePane(
                  onDismissed: () {
                    MediaManager().audioHandler.removeQueueItemAt(index);
                  },
                ),
                children: [
                  SlidableAction(
                    backgroundColor: VelvetColors.raised,
                    foregroundColor: VelvetColors.textPrimary,
                    icon: Icons.info,
                    label: l.info,
                    onPressed: (context) {
                      final m = MusicMetadata(
                        item.artist,
                        item.album,
                        item.title,
                        null,
                        null,
                        item.extras?['year'],
                        'X',
                        null,
                        item.extras?['artUrl'],
                      );
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MeteDataScreen(
                              meta: m, path: item.extras?['path']),
                        ),
                      );
                    },
                  ),
                ],
              ),
              child: _QueueRow(
                item: item,
                active: active,
                playing: playing,
                downloaded: downloaded,
                onTap: () {
                  MediaManager().audioHandler.skipToQueueItem(index);
                  MediaManager().audioHandler.play();
                },
              ),
            );
          },
        );
      },
    );
  }
}

class _QueueRow extends StatelessWidget {
  final MediaItem item;
  final bool active;
  final bool playing;
  final bool downloaded;
  final VoidCallback onTap;
  const _QueueRow({
    required this.item,
    required this.active,
    required this.playing,
    required this.downloaded,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final url = item.extras?['artUrl'] as String?;
    final edgeColor = active
        ? VelvetColors.primary
        : (downloaded ? VelvetColors.success : Colors.transparent);

    return Material(
      color: active ? VelvetColors.active : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: edgeColor, width: 2),
              bottom: BorderSide(color: VelvetColors.border, width: 0.5),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(14, 9, 16, 9),
          child: Row(
            children: [
              // Art + active EQ / paused badge.
              SizedBox(
                width: 40,
                height: 40,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: url != null
                          ? Image.network(url,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _artFallback())
                          : _artFallback(),
                    ),
                    if (active)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          color: Colors.black.withValues(alpha:0.45),
                          alignment: Alignment.center,
                          child: Icon(
                            playing ? Icons.graphic_eq : Icons.play_arrow,
                            color: VelvetColors.primary,
                            size: playing ? 20 : 16,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              // Title + artist.
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w500,
                        color: active
                            ? VelvetColors.primary
                            : VelvetColors.textPrimary,
                      ),
                    ),
                    if (item.artist != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        item.artist!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: VelvetColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Duration.
              Text(
                _fmtDur(item.duration),
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11.5,
                  color: VelvetColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Header strip for the queue (design "UP NEXT" framing): a label + live count
/// on the left, and the functional bulk actions (download-all, clear) on the
/// right.
class QueueHeader extends StatelessWidget {
  /// When true (non-Small layouts) the right side collapses to a single ⋮ menu
  /// that opens [onOptions]; otherwise it shows the download-all + clear icons.
  final bool showOptions;
  final VoidCallback? onOptions;
  const QueueHeader({Key? key, this.showOptions = false, this.onOptions})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Material(
      color: Colors.transparent,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 8, 6),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            StreamBuilder<List<MediaItem>>(
              stream: MediaManager().audioHandler.queue,
              builder: (context, snap) {
                final n = snap.data?.length ?? 0;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      l.tabQueue.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        letterSpacing: 2.0,
                        fontWeight: FontWeight.w600,
                        color: VelvetColors.textSecondary,
                      ),
                    ),
                    const SizedBox(width: 9),
                    Text(
                      l.mainQueueCount(n),
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: VelvetColors.textTertiary,
                      ),
                    ),
                  ],
                );
              },
            ),
            if (showOptions)
              IconButton(
                icon: const Icon(Icons.more_vert, size: 20),
                color: VelvetColors.textSecondary,
                tooltip: l.mainMore,
                onPressed: onOptions,
              )
            else
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.download_for_offline, size: 20),
                    color: VelvetColors.textSecondary,
                    tooltip: l.queueDownloadAll,
                    onPressed: () => downloadQueue(context),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_sweep, size: 20),
                    color: VelvetColors.textSecondary,
                    tooltip: l.mainClearQueue,
                    onPressed: () => MediaManager()
                        .audioHandler
                        .customAction('clearPlaylist'),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

}

/// Enqueue every track that isn't already on the device (no localPath) and is
/// actually downloadable (has a server + path). Confirms the count first;
/// downloadOneFile no-ops on files already on disk. Top-level so the queue
/// header and the More sheet can both trigger it.
void downloadQueue(BuildContext context) {
    final l = AppLocalizations.of(context);
    final queue = MediaManager().audioHandler.queue.value;
    final pending = queue
        .where((m) =>
            m.extras?['localPath'] == null &&
            m.extras?['server'] != null &&
            m.extras?['path'] != null)
        .toList();

    if (pending.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(queue.isEmpty
              ? 'Queue is empty — nothing to download'
              : 'Nothing to download — tracks are already saved')));
      return;
    }

    final n = pending.length;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VelvetColors.surface,
        title: Text(l.queueDownloadAll),
        content: Text(l.queueDownloadAllBody(n)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l.cancel,
                style: TextStyle(color: VelvetColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              for (final m in pending) {
                DownloadManager().downloadOneFile(
                    m.id, m.extras!['server'], m.extras!['path']);
              }
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                  content: Text(l.browserDownloadsStarted(n))));
            },
            child: Text(l.download),
          ),
        ],
      ),
    );
}
