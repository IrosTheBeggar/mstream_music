import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:rxdart/rxdart.dart';

import '../l10n/app_localizations.dart';
import '../screens/metadata_screen.dart';
import '../singletons/downloads.dart';
import '../singletons/media.dart';
import '../theme/velvet_theme.dart';
import '../util/media_format.dart';

/// Combined snapshot of the queue, the currently-playing item, and whether
/// playback is running — so a row can render the list, highlight the active
/// track, and show a live EQ / paused badge over its art.
class _QueueSnapshot {
  final List<MediaItem> queue;
  final MediaItem? current;
  final bool playing;
  const _QueueSnapshot(this.queue, this.current, this.playing);
}

/// Memoised as a single broadcast subject (mirrors player_panel's _mediaPos):
/// the queue list is rebuilt by the panel's drag AnimationController, so a fresh
/// combineLatest per build would re-subscribe three handler streams every frame.
/// One shared upstream subscription, replayed to each new listener so a freshly
/// (re)mounted list paints the current queue immediately.
final Stream<_QueueSnapshot> _queueStream = BehaviorSubject<_QueueSnapshot>()
  ..addStream(Rx.combineLatest3<List<MediaItem>, MediaItem?, bool,
      _QueueSnapshot>(
    MediaManager().audioHandler.queue,
    MediaManager().audioHandler.mediaItem,
    // Only the play/pause flag from playbackState, distinct() — playbackState
    // re-emits on every position tick (several times a second), and we don't
    // want that rebuilding the whole reorderable queue (jank). The queue only
    // cares whether playback is running, for the active-row EQ/pause badge.
    MediaManager().audioHandler.playbackState.map((s) => s.playing).distinct(),
    (q, m, playing) => _QueueSnapshot(q, m, playing),
  ));

Widget _artFallback() => albumArtFallback(iconSize: 20);

String _fmtDur(Duration? d) =>
    d == null ? '' : formatDuration(d, padMinutes: false);

/// The "Up Next" queue list (design Variant B rows). Reads/writes the queue
/// purely through `MediaManager().audioHandler`, so it works identically
/// wherever it's mounted. Swipe a row for download / remove / info.
class QueueList extends StatelessWidget {
  const QueueList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return StreamBuilder<_QueueSnapshot>(
      stream: _queueStream,
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

        return ReorderableListView.builder(
          // We supply our own per-row drag grip so reorder never competes with
          // the Slidable's horizontal swipe; the default long-press-anywhere
          // reorder is off.
          buildDefaultDragHandles: false,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 8),
          itemCount: queue.length,
          // Haptic tick on pickup / drop — every polished native reorder does
          // this, and ReorderableListView fires none by default.
          onReorderStart: (_) => HapticFeedback.mediumImpact(),
          onReorderEnd: (_) => HapticFeedback.selectionClick(),
          // Lift the dragged row: scale it up slightly with an accent-tinted
          // shadow so it clearly detaches (vs the flat default elevation).
          proxyDecorator: (child, index, animation) => AnimatedBuilder(
            animation: animation,
            child: child,
            builder: (context, child) {
              final t = Curves.easeInOut.transform(animation.value);
              return Transform.scale(
                scale: 1 + 0.03 * t,
                child: Material(
                  color: VelvetColors.surface,
                  elevation: 8 * t,
                  shadowColor: VelvetColors.primary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(10),
                  child: child,
                ),
              );
            },
          ),
          // onReorderItem (vs the deprecated onReorder) hands us the
          // post-removal target index already — matching what the handler and
          // just_audio's moveAudioSource expect, so no off-by-one fixup here.
          onReorderItem: (oldIndex, newIndex) {
            if (newIndex == oldIndex) return;
            MediaManager().audioHandler.customAction(
                'moveQueueItem', {'from': oldIndex, 'to': newIndex});
          },
          itemBuilder: (BuildContext context, int index) {
            final item = queue[index];
            final active = item == current;
            final downloaded = item.extras?['localPath'] != null;

            // Remove this row from the queue. Re-resolves the row's CURRENT
            // position at dismiss time: the build-time index can be stale if the
            // queue shifted during the swipe (e.g. the playing track
            // auto-advanced), so deleting by the stale index would remove the
            // wrong item. -1 → already gone.
            void removeItem() {
              final live = MediaManager().audioHandler.queue.value;
              final at = live.indexOf(item);
              if (at >= 0) {
                MediaManager().audioHandler.removeQueueItemAt(at);
              }
            }

            return Slidable(
              // Identity key (also the ReorderableListView item key): follows
              // the *item* across reorders; distinct MediaItem instances avoid a
              // duplicate-key clash.
              key: ObjectKey(item),
              // RIGHT swipe (or a grip tap, see _QueueRow) → Info.
              startActionPane: ActionPane(
                motion: const DrawerMotion(),
                extentRatio: 0.25,
                // A full right-swipe past Info also removes the track, so a full
                // swipe in EITHER direction removes.
                dismissible: DismissiblePane(onDismissed: removeItem),
                children: [
                  SlidableAction(
                    backgroundColor: VelvetColors.raised,
                    foregroundColor: VelvetColors.textPrimary,
                    icon: Icons.info,
                    label: l.info,
                    onPressed: (context) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => MetadataScreen(item: item),
                        ),
                      );
                    },
                  ),
                ],
              ),
              // LEFT swipe → Remove; a full left-swipe also removes (the
              // DismissiblePane), so swipe-to-remove is back — on this side.
              endActionPane: ActionPane(
                motion: const DrawerMotion(),
                extentRatio: 0.25,
                dismissible: DismissiblePane(onDismissed: removeItem),
                children: [
                  SlidableAction(
                    backgroundColor: Colors.red.shade700,
                    foregroundColor: Colors.white,
                    icon: Icons.delete_outline,
                    label: l.mainRemove,
                    onPressed: (_) => removeItem(),
                  ),
                ],
              ),
              child: _QueueRow(
                item: item,
                index: index,
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
  final int index;
  final bool active;
  final bool playing;
  final bool downloaded;
  final VoidCallback onTap;
  const _QueueRow({
    required this.item,
    required this.index,
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
              // Drag-to-reorder grip — a comfortable 44px touch target. DRAG it
              // (ReorderableDragStartListener) to reorder, or TAP it to open the
              // action drawer (the start/left pane). The GestureDetector also
              // keeps the tap from falling through to the row's play-on-tap.
              ReorderableDragStartListener(
                index: index,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  // Tap → open the download/info drawer; drag → reorder.
                  onTap: () => Slidable.of(context)?.openStartActionPane(),
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: Center(
                      child: Icon(Icons.drag_handle,
                          color: VelvetColors.textTertiary, size: 20),
                    ),
                  ),
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
              ? l.queueNothingToDownloadEmpty
              : l.queueNothingToDownloadSaved)));
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
