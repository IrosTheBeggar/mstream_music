import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:rxdart/rxdart.dart';

import '../l10n/app_localizations.dart';
import '../objects/server.dart';
import '../screens/discover_screen.dart';
import '../screens/metadata_screen.dart';
import '../singletons/auto_dj_manager.dart';
import '../singletons/downloads.dart';
import '../singletons/media.dart';
import '../singletons/server_list.dart';
import '../theme/velvet_theme.dart';
import '../util/media_format.dart';
import '../util/image_cache.dart';

/// Active-row state — which queue slot is playing, and whether it's playing —
/// pushed down to each row (see [QueueList.build]) so a track advancing rebuilds
/// only the two rows whose highlight flips, never the ReorderableListView /
/// Slidable rows above them (which used to hitch the whole queue on every
/// advance, because the active flag lived in the list-wide snapshot).
///
/// queueIndex is the playing *position*, not the playing MediaItem: MediaItem.==
/// is id-based, so a queue that legitimately holds the same track id more than
/// once would light up every matching row at once. A position is unambiguous.
///
/// Memoised as a single broadcast subject + distinct() so the per-position-tick
/// playbackState emissions (several a second) don't churn it.
final BehaviorSubject<({int? index, bool playing})> _activeStream =
    BehaviorSubject<({int? index, bool playing})>()
      ..addStream(MediaManager()
          .audioHandler
          .playbackState
          .map((s) => (index: s.queueIndex, playing: s.playing))
          .distinct());

Widget _artFallback() => albumArtFallback(iconSize: 20);

String _fmtDur(Duration? d) =>
    d == null ? '' : formatDuration(d, padMinutes: false);

/// Whether a queue item can seed Discover: a server track whose server
/// advertised discovery on ping. Local files (no server path) and older
/// servers get no Find-similar action — never probed.
bool _canFindSimilar(MediaItem item) {
  final server =
      ServerManager().byLocalname(item.extras?['server'] as String?);
  return server?.discoveryAvailable == true && item.extras?['path'] is String;
}

/// The "Up Next" queue list (design Variant B rows). Reads/writes the queue
/// purely through `MediaManager().audioHandler`, so it works identically
/// wherever it's mounted. Swipe a row for download / remove / info.
class QueueList extends StatelessWidget {
  const QueueList({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return StreamBuilder<List<MediaItem>>(
      // The list depends ONLY on the queue, so a track advancing (which just
      // moves the active highlight — handled per-row via _activeStream below)
      // never rebuilds the ReorderableListView. queue is already a
      // BehaviorSubject on the handler.
      stream: MediaManager().audioHandler.queue,
      initialData: MediaManager().audioHandler.queue.valueOrNull,
      builder: (context, snapshot) {
        final queue = snapshot.data ?? const <MediaItem>[];

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
            final downloaded = item.extras?['localPath'] != null;

            // This row's (active, playing) from the shared active-state stream,
            // distinct() per row so only the two rows whose active flag actually
            // flips rebuild on a track change (not the whole visible list).
            ({bool active, bool playing}) rowState(
                ({int? index, bool playing}) s) {
              final on = s.index == index;
              return (active: on, playing: on && s.playing);
            }

            final activeNow = _activeStream.valueOrNull;

            // Remove this row from the queue. Re-resolves the row's CURRENT
            // position at dismiss time by IDENTITY: the build-time index can be
            // stale if the queue shifted during the swipe (e.g. the playing
            // track auto-advanced). We match the exact MediaItem instance —
            // not `indexOf`, whose `==` is id-only — so that when two entries
            // share an id (e.g. the same playlist track loaded twice) we delete
            // the row the user actually swiped, not its twin. The ObjectKey
            // below guarantees every queue entry is a distinct instance.
            // -1 → already gone.
            void removeItem() {
              final live = MediaManager().audioHandler.queue.value;
              final at = live.indexWhere((e) => identical(e, item));
              if (at >= 0) {
                MediaManager().audioHandler.removeQueueItemAt(at);
              }
            }

            return Slidable(
              // Identity key (also the ReorderableListView item key): follows
              // the *item* across reorders; distinct MediaItem instances avoid a
              // duplicate-key clash.
              key: ObjectKey(item),
              // RIGHT swipe (or a grip tap, see _QueueRow) → Info, plus Find
              // similar when this track's server has discovery data (the pane
              // widens to fit the second action; hidden on older servers and
              // for local files, never probed).
              startActionPane: ActionPane(
                motion: const DrawerMotion(),
                extentRatio: _canFindSimilar(item) ? 0.5 : 0.25,
                // A full right-swipe past the actions also removes the track,
                // so a full swipe in EITHER direction removes.
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
                  if (_canFindSimilar(item))
                    SlidableAction(
                      backgroundColor: VelvetColors.raised,
                      foregroundColor: VelvetColors.primary,
                      icon: Icons.explore,
                      label: l.discoverFindSimilar,
                      onPressed: (context) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => DiscoverScreen(
                              seedServer: ServerManager().byLocalname(
                                  item.extras?['server'] as String?),
                              seedPath: item.extras?['path'] as String?,
                              seedTitle: item.title,
                              seedArtist: item.artist,
                            ),
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
              // RepaintBoundary so a highlight flip repaints only this row's
              // layer — the panel wraps QueueList in one RepaintBoundary, so
              // without this every advance would re-raster all visible rows.
              child: RepaintBoundary(
                child: StreamBuilder<({bool active, bool playing})>(
                  initialData: activeNow == null
                      ? (active: false, playing: false)
                      : rowState(activeNow),
                  stream: _activeStream.map(rowState).distinct(),
                  builder: (context, snap) {
                    final st = snap.data ?? (active: false, playing: false);
                    return _QueueRow(
                      item: item,
                      index: index,
                      active: st.active,
                      playing: st.playing,
                      downloaded: downloaded,
                      onTap: () {
                        MediaManager().audioHandler.skipToQueueItem(index);
                        MediaManager().audioHandler.play();
                      },
                    );
                  },
                ),
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
                              cacheWidth: artCacheSize(40),
                              errorBuilder: (_, _, _) => _artFallback())
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
                    Row(
                      children: [
                        // DJ-pick badge (Finamp's radio-icon / Spotify's
                        // sparkle pattern): explore = sonic-pool pick,
                        // album = classic random DJ pick. User-queued rows
                        // carry no badge.
                        if (item.extras?['djPick'] == true) ...[
                          Icon(
                            item.extras?['djSonic'] == true
                                ? Icons.explore
                                : Icons.album,
                            size: 12,
                            color: active
                                ? VelvetColors.primary
                                : VelvetColors.textTertiary,
                          ),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
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
                        ),
                      ],
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
  const QueueHeader({super.key, this.showOptions = false, this.onOptions});

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
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Auto DJ at a glance + one-tap toggle (the queue-header
                // autoplay-control pattern) — lit while the DJ runs.
                _DjHeaderButton(),
                if (showOptions)
                  IconButton(
                    icon: const Icon(Icons.more_vert, size: 20),
                    color: VelvetColors.textSecondary,
                    tooltip: l.mainMore,
                    onPressed: onOptions,
                  )
                else ...[
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

/// Toggle Auto DJ for the current server — off when it's already driving it,
/// on (or switched over) otherwise — with the standard confirmation
/// snackbars. Shared by the queue header's DJ button and the player sheet's
/// Auto DJ switch.
Future<void> toggleAutoDJ(BuildContext context) async {
  final l = AppLocalizations.of(context);
  final current = ServerManager().currentServer;
  if (current == null) return;
  final handler = MediaManager().audioHandler;
  final messenger = ScaffoldMessenger.of(context);
  final Server? state = handler.customState.valueOrNull?.autoDJState as Server?;
  if (state == null) {
    handler.customAction('setAutoDJ', {'autoDJServer': current});
    messenger.showSnackBar(SnackBar(
        content: Text(ServerManager().serverList.length == 1
            ? l.autoDjEnabled
            : l.autoDjEnabledFor(current.url))));
  } else if (current == state) {
    handler.customAction('setAutoDJ', {'autoDJServer': null});
    messenger.showSnackBar(SnackBar(content: Text(l.autoDjDisabled)));
  } else {
    handler.customAction('setAutoDJ', {'autoDJServer': current});
    messenger.showSnackBar(
        SnackBar(content: Text(l.autoDjEnabledFor(current.url))));
  }
}

/// Auto DJ state at a glance in the queue header (the ∞-icon-on-the-queue
/// pattern): lit while the DJ runs — explore icon when sonic similarity is
/// shaping picks, album icon for the classic random DJ — dim when off.
/// Tapping toggles the DJ for the current server.
class _DjHeaderButton extends StatelessWidget {
  const _DjHeaderButton();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return StreamBuilder<dynamic>(
      stream: MediaManager().audioHandler.customState,
      builder: (context, snap) {
        final Server? djServer = snap.data?.autoDJState as Server?;
        final on = djServer != null;
        final sonic = on && AutoDJManager().sonicSimilarityEnabled;
        return IconButton(
          icon: Icon(sonic ? Icons.explore : Icons.album, size: 20),
          color: on ? VelvetColors.primary : VelvetColors.textSecondary,
          tooltip: l.autoDjTitle,
          onPressed: () => toggleAutoDJ(context),
        );
      },
    );
  }
}
