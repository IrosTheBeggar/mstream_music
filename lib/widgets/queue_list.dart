import 'dart:async';
import 'package:audio_service/audio_service.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:rxdart/rxdart.dart';

import '../l10n/app_localizations.dart';
import '../objects/discovery_plugins.dart' show kScopeSong;
import '../singletons/api.dart';
import '../singletons/track_capture.dart';
import '../objects/play_event.dart';
import '../objects/server.dart';
import '../screens/discover_screen.dart';
import '../screens/discovery/copies_hub.dart';
import '../screens/metadata_screen.dart';
import '../singletons/app_route_observer.dart' show nowPlayingExpanded;
import '../singletons/auto_dj_manager.dart';
import '../singletons/downloads.dart';
import '../singletons/media.dart';
import '../singletons/play_history.dart';
import '../singletons/server_list.dart';
import '../singletons/settings.dart';
import '../theme/velvet_theme.dart';
import '../util/auto_dj_play_from.dart';
import '../util/auto_dj_recent.dart';
import '../util/browse_keep_leads.dart';
import '../util/discover_badges.dart' show CopyMarker;
import '../util/media_format.dart';
import '../util/image_cache.dart';
import 'auto_dj_quick_config.dart';
import 'auto_dj_recent_menu.dart';
import 'auto_dj_start_sheet.dart';
import 'browse_keep_entry.dart';
import 'playlist_picker_sheet.dart' show addSongToPlaylistFlow;
import 'queue_item_sheet.dart';

/// Active-row state — which queue slot is playing, and whether it's playing —
/// pushed down to each row (see [QueueList.build]) so a track advancing rebuilds
/// only the two rows whose highlight flips, never the ReorderableListView /
/// rows above them (which used to hitch the whole queue on every
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

/// The connected server whose "Keep a copy…" a queued track offers (its
/// own server's gate open for songs) — a track downloaded to this phone
/// still is that server's song — or null: the user's own server's track, a
/// file on this phone, a server no longer listed or hidden, a closed gate.
Server? _keepPeerOf(MediaItem item) => queueKeepPeer(
      item,
      byLocalname: ServerManager().byLocalname,
      gateOpen: (peer) => CopiesHub().gateFor(peer).allows(kScopeSong),
    );

/// Keep a copy of a queued connected-server track: its song sheet on the
/// track's own server (its jobs, gate and destination its parent's).
void _keepQueued(BuildContext context, MediaItem item, Server peer) {
  final req = BrowseKeepRequest.queued(item, peer);
  if (req == null) return;
  BrowseKeepEntry.open(context, req);
}

void _openInfo(BuildContext context, MediaItem item) {
  Navigator.push(
    context,
    MaterialPageRoute(builder: (_) => MetadataScreen(item: item)),
  );
}

/// Find similar for a queued track: Discover, seeded with it.
void _findSimilar(BuildContext context, MediaItem item) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => DiscoverScreen(
        seedServer:
            ServerManager().byLocalname(item.extras?['server'] as String?),
        seedPath: item.extras?['path'] as String?,
        seedTitle: item.title,
        seedArtist: item.artist,
      ),
    ),
  );
}

/// The "Up Next" queue list (design Variant B rows). Reads/writes the queue
/// purely through `MediaManager().audioHandler`, so it works identically
/// wherever it's mounted. Hold a row — or tap its grip — for the song's
/// options ([QueueItemSheet]); swipe a row either way to remove it, with
/// Undo; hold the grip and drag to reorder.
class QueueList extends StatefulWidget {
  const QueueList({super.key});

  @override
  State<QueueList> createState() => _QueueListState();
}

class _QueueListState extends State<QueueList> {
  /// Rows swiped away whose removal the handler has not echoed yet. A
  /// dismissed [Dismissible] has to leave the tree in the frame it reports,
  /// and the queue answers a beat later, so the row is hidden here at once.
  /// By identity: MediaItem.== is id-only, and a queue can hold the same
  /// track twice.
  final Set<MediaItem> _hidden = Set<MediaItem>.identity();

  @override
  void initState() {
    super.initState();
    nowPlayingExpanded.addListener(_maybeShowHint);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowHint());
  }

  @override
  void dispose() {
    nowPlayingExpanded.removeListener(_maybeShowHint);
    super.dispose();
  }

  /// The first time the queue is on screen with songs in it, say once how
  /// its rows work, as the browser's keep hint does. Shown on the panel's
  /// own messenger, which is where this list's snackbars land.
  void _maybeShowHint() {
    if (!mounted || !nowPlayingExpanded.value) return;
    final settings = SettingsManager();
    if (settings.queueHoldHintShown) return;
    final queue =
        MediaManager().audioHandler.queue.valueOrNull ?? const <MediaItem>[];
    if (queue.isEmpty) return;
    final l = AppLocalizations.of(context);
    unawaited(settings.markQueueHoldHintShown());
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(l.queueHoldHint),
      duration: const Duration(seconds: 8),
      action: SnackBarAction(label: l.ok, onPressed: () {}),
    ));
  }

  /// The move that makes [item] play next — moveQueueItem's from and its
  /// post-removal to — or null: nothing is playing, it is the song playing,
  /// or it is already next.
  ({int from, int to})? _playNextMove(MediaItem item) {
    final h = MediaManager().audioHandler;
    final live = h.queue.valueOrNull ?? const <MediaItem>[];
    final from = live.indexWhere((e) => identical(e, item));
    final current = h.playbackState.valueOrNull?.queueIndex;
    if (from < 0 ||
        current == null ||
        current < 0 ||
        current >= live.length ||
        from == current) {
      return null;
    }
    // Taking a row out from before the playing one moves the playing one up
    // a place, so "right after it" is then its old index.
    final to = from < current ? current : current + 1;
    return to == from ? null : (from: from, to: to);
  }

  void _playNext(MediaItem item) {
    // Again, on the queue as it is now: the sheet may have stood open while
    // the song moved on.
    final move = _playNextMove(item);
    if (move == null) return;
    final l = AppLocalizations.of(context);
    // The handler reorders the queue at once; the player follows behind.
    unawaited(MediaManager().audioHandler.customAction(
        'moveQueueItem', {'from': move.from, 'to': move.to}));
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.queuePlaysNext(item.title))));
  }

  /// Take [item] out of the queue, then offer it back: "Removed {title}"
  /// with Undo. The row's place is found by identity at the time — the
  /// build-time index goes stale if the queue moved meanwhile (the playing
  /// track advancing), and an id match would take a twin of the same track.
  ///
  /// The snackbar doesn't wait for the player: the handler drops the row
  /// from the queue at once, but the player's own removal can take seconds
  /// (about 5 s on the emulator, 2026-11), and an Undo that only shows up
  /// then has missed its moment. The player applies its edits in order, so
  /// an Undo's re-add still lands after the removal.
  void _remove(MediaItem item) {
    final h = MediaManager().audioHandler;
    final at = h.queue.value.indexWhere((e) => identical(e, item));
    if (at < 0) return;
    final l = AppLocalizations.of(context);
    unawaited(h.removeQueueItemAt(at));
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(l.queueRemovedSong(item.title)),
        action: SnackBarAction(
          label: l.queueUndo,
          onPressed: () => unawaited(_undoRemove(item, at)),
        ),
      ));
  }

  /// Undo puts [item] back where it was: appended, then moved into place —
  /// the two queue edits the handler has. A removed song that was playing
  /// comes back to the queue; playback stays on the song that took over.
  Future<void> _undoRemove(MediaItem item, int at) async {
    if (mounted) setState(() => _hidden.remove(item));
    final h = MediaManager().audioHandler;
    // The removal reaches the handler's queue a beat after the call. Put
    // the song back only once it has gone, or the two edits would cross.
    if (h.queue.value.any((e) => identical(e, item))) {
      try {
        await h.queue
            .firstWhere((q) => !q.any((e) => identical(e, item)))
            .timeout(const Duration(seconds: 2));
      } on TimeoutException {
        return; // it never left: there is nothing to put back
      }
    }
    await h.addQueueItem(item);
    final last = h.queue.value.length - 1;
    final to = at < last ? at : last;
    if (to != last) {
      await h.customAction('moveQueueItem', {'from': last, 'to': to});
    }
  }

  Future<void> _addToPlaylist(Server server, String path) {
    final messenger = ScaffoldMessenger.of(context);
    return addSongToPlaylistFlow(context,
        server: server,
        path: path,
        toast: (m) => messenger.showSnackBar(SnackBar(content: Text(m))));
  }

  void _download(MediaItem item, Server server, String path) {
    final l = AppLocalizations.of(context);
    // As the header's download-all does: the queued stream URL, the track's
    // own server and path.
    unawaited(
        DownloadManager().downloadOneFile(item.id, server.localname, path));
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l.browserDownloadsStarted(1))));
  }

  /// The options sheet for [item], with the verbs that apply to it.
  void _openMenu(MediaItem item) {
    final e = item.extras;
    final server = ServerManager().byLocalname(e?['server'] as String?);
    final path = e?['path'] as String?;
    VoidCallback? addToPlaylist;
    VoidCallback? download;
    if (server != null && path != null) {
      // Playlists live on the user's OWN server: a connected server's path
      // would be stored where the parent cannot resolve it (and the playlist
      // routes are off the federation allowlist besides).
      if (!server.isFederated) {
        addToPlaylist = () => unawaited(_addToPlaylist(server, path));
      }
      if (e?['localPath'] == null) {
        download = () => _download(item, server, path);
      }
    }
    final peer = _keepPeerOf(item);
    final request =
        peer == null ? null : BrowseKeepRequest.queued(item, peer);
    VoidCallback? keep;
    Future<CopyMarker?> Function()? keepAsk;
    if (peer != null && request != null) {
      keep = () => _keepQueued(context, item, peer);
      keepAsk = () =>
          KeepMenuState.lookupSong(CopiesHub().jobsFor(peer), request);
    }
    unawaited(showQueueItemSheet(
      context,
      QueueItemSheet(
        item: item,
        onPlayNext: _playNextMove(item) == null
            ? null
            : () => _playNext(item),
        onKeep: keep,
        keepAsk: keepAsk,
        onAddToPlaylist: addToPlaylist,
        onDownload: download,
        onFindSimilar:
            _canFindSimilar(item) ? () => _findSimilar(context, item) : null,
        onInfo: () => _openInfo(context, item),
        onRemove: () => _remove(item),
      ),
    ));
  }

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
        // A swiped row the handler has let go of needs hiding no longer.
        _hidden.removeWhere((h) => !queue.any((e) => identical(e, h)));
        final rows = _hidden.isEmpty
            ? queue
            : [
                for (final e in queue)
                  if (!_hidden.contains(e)) e
              ];

        if (rows.isEmpty) return const _EmptyQueue();

        // Built again once a queued connected server's own gate answers:
        // its rows' Keep a copy… offers itself only once known open.
        return _GateWatch(
          queue: queue,
          builder: (context) => ReorderableListView.builder(
            // We supply our own per-row drag grip so reorder never competes
            // with the row's swipe or its hold; the default
            // long-press-anywhere reorder is off.
            buildDefaultDragHandles: false,
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 8),
            itemCount: rows.length,
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
            // The indices are the rows'; while a swiped row is still hidden
            // they are not the queue's, and that lasts a frame — let it go.
            onReorderItem: (oldIndex, newIndex) {
              if (newIndex == oldIndex || _hidden.isNotEmpty) return;
              MediaManager().audioHandler.customAction(
                  'moveQueueItem', {'from': oldIndex, 'to': newIndex});
            },
            itemBuilder: (BuildContext context, int index) {
              final item = rows[index];
              // The row's place in the QUEUE — what the active highlight and
              // a tap mean. It is the list's index except while a swiped row
              // is hidden.
              final at = identical(rows, queue)
                  ? index
                  : queue.indexWhere((e) => identical(e, item));
              final downloaded = item.extras?['localPath'] != null;

              // This row's (active, playing) from the shared active-state stream,
              // distinct() per row so only the two rows whose active flag actually
              // flips rebuild on a track change (not the whole visible list).
              ({bool active, bool playing}) rowState(
                  ({int? index, bool playing}) s) {
                final on = s.index == at;
                return (active: on, playing: on && s.playing);
              }

              final activeNow = _activeStream.valueOrNull;

              // A connected server's track offers Keep a copy… (in its menu
              // and to a screen reader).
              final keepPeer = _keepPeerOf(item);

              return Dismissible(
                // Identity key (also the ReorderableListView item key): follows
                // the *item* across reorders; distinct MediaItem instances avoid a
                // duplicate-key clash.
                key: ObjectKey(item),
                // A swipe either way removes, as a full swipe did when the
                // rows had drawers; the menu holds everything else.
                direction: DismissDirection.horizontal,
                background: const _RemoveBackground(start: true),
                secondaryBackground: const _RemoveBackground(start: false),
                // A tick as the swipe crosses the point where letting go
                // removes, and back.
                onUpdate: (d) {
                  if (d.reached != d.previousReached) {
                    HapticFeedback.selectionClick();
                  }
                },
                onDismissed: (_) {
                  setState(() => _hidden.add(item));
                  _remove(item);
                },
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
                        // The menu's shortcuts, for a screen reader: on the
                        // grip's node (see _QueueRow.actions).
                        actions: {
                          CustomSemanticsAction(label: l.info): () =>
                              _openInfo(this.context, item),
                          if (keepPeer != null)
                            CustomSemanticsAction(
                                    label: l.browseKeepOfItem(item.title)):
                                () => _keepQueued(this.context, item, keepPeer),
                          CustomSemanticsAction(label: l.mainRemove): () =>
                              _remove(item),
                        },
                        focusKey: keepPeer == null
                            ? null
                            : BrowseKeepRequest.queued(item, keepPeer)?.focusKey,
                        onTap: () {
                          MediaManager().audioHandler.skipToQueueItem(at);
                          MediaManager().audioHandler.play();
                        },
                        onMenu: () => _openMenu(item),
                      );
                    },
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

/// What a swipe uncovers: Remove, on the side the row leaves from.
class _RemoveBackground extends StatelessWidget {
  /// Uncovered by a swipe toward the end (the row moves right).
  final bool start;
  const _RemoveBackground({required this.start});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ExcludeSemantics(
      child: Container(
        color: Colors.red.shade700,
        alignment: start ? Alignment.centerLeft : Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.delete_outline, color: Colors.white, size: 22),
            const SizedBox(width: 8),
            Text(
              l.mainRemove,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The queue, built again when the Keep a copy gate of a queued connected
/// server's own server answers after it was unread (the panel reads it as
/// it opens and as the queue changes: readQueueKeepGates). It listens only
/// while such a gate is still unread.
class _GateWatch extends StatefulWidget {
  final List<MediaItem> queue;
  final WidgetBuilder builder;
  const _GateWatch({required this.queue, required this.builder});

  @override
  State<_GateWatch> createState() => _GateWatchState();
}

class _GateWatchState extends State<_GateWatch> {
  List<Listenable> _watched = const [];

  @override
  void initState() {
    super.initState();
    _watch();
  }

  @override
  void didUpdateWidget(_GateWatch old) {
    super.didUpdateWidget(old);
    if (!identical(old.queue, widget.queue)) _watch();
  }

  @override
  void dispose() {
    for (final w in _watched) {
      w.removeListener(_changed);
    }
    super.dispose();
  }

  /// The own servers' controllers whose gate is still unread, once each.
  void _watch() {
    for (final w in _watched) {
      w.removeListener(_changed);
    }
    final hub = CopiesHub();
    final seen = <Listenable>{};
    for (final item in widget.queue) {
      final server =
          ServerManager().byLocalname(item.extras?['server'] as String?);
      if (!isKeepPeer(server)) continue;
      if (hub.gateFor(server).state != KeepGateState.unknown) continue;
      seen.add(hub.jobsFor(server!));
    }
    _watched = seen.toList();
    for (final w in _watched) {
      w.addListener(_changed);
    }
  }

  void _changed() {
    if (!mounted) return;
    setState(_watch);
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}

class _QueueRow extends StatelessWidget {
  final MediaItem item;
  final int index;
  final bool active;
  final bool playing;
  final bool downloaded;
  final VoidCallback onTap;

  /// Opens the song's options sheet: a hold on the row, a tap on the grip.
  final VoidCallback onMenu;

  /// The menu's shortcuts, as the grip's screen-reader actions ("Actions
  /// for {title}…": Info, Keep a copy…, Remove). The row's own node is the
  /// reorderable list's — its Move up / Move down / to the start / to the
  /// end, the tap, the hold — and a node holds one set of custom actions:
  /// these on the row would split it from the list's, its moves left on a
  /// node that says nothing.
  final Map<CustomSemanticsAction, VoidCallback> actions;

  /// The grip's stable key, for focus to come back to once a Keep sheet
  /// from this row closes.
  final String? focusKey;
  const _QueueRow({
    required this.item,
    required this.index,
    required this.active,
    required this.playing,
    required this.downloaded,
    required this.onTap,
    required this.onMenu,
    this.actions = const {},
    this.focusKey,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final url = item.extras?['artUrl'] as String?;
    final dur = _fmtDur(item.duration);
    final edgeColor = active
        ? VelvetColors.primary
        : (downloaded ? VelvetColors.success : Colors.transparent);

    // Its name joins the list's own node for the row (see [actions]).
    return Semantics(
      label: [
        item.title,
        if (item.artist != null && item.artist!.isNotEmpty) item.artist!,
        if (dur.isNotEmpty) dur,
      ].join(', '),
      child: Material(
        color: active ? VelvetColors.active : Colors.transparent,
        child: InkWell(
          onTap: onTap,
          // Hold for the song's options. The grip claims its own hold first
          // (it grabs the row for a reorder after 220ms, before a long press
          // is decided), so this is the rest of the row's.
          onLongPress: onMenu,
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
                ExcludeSemantics(
                  child: SizedBox(
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
                ),
                const SizedBox(width: 12),
                // Title + artist (the row's label says them).
                Expanded(
                  child: ExcludeSemantics(
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
                        // The duration rides the ARTIST line, right-aligned,
                        // rather than sitting in its own column beside both. Its
                        // column used to run the full row height and take that
                        // width from the title on every row — the title is the
                        // thing that gets truncated, and the artist line almost
                        // never fills its width. Same x as before: the text
                        // column now extends into the space the duration column
                        // occupied, so a right-aligned readout lands where the
                        // old one did.
                        //
                        // Rendered whenever there is EITHER an artist or a
                        // duration: a row with no artist still has a length.
                        if (item.artist != null || dur.isNotEmpty) ...[
                          const SizedBox(height: 1),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(
                                child: Text(
                                  item.artist ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: VelvetColors.textSecondary,
                                  ),
                                ),
                              ),
                              if (dur.isNotEmpty) ...[
                                const SizedBox(width: 10),
                                Text(
                                  dur,
                                  style: TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11.5,
                                    color: VelvetColors.textTertiary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                // Drag-to-reorder grip — a comfortable 44px touch target. HOLD
                // then drag to reorder, or TAP it for the song's options, the
                // sheet a hold on the row opens: the visible way in, since a
                // hold can't be seen. The GestureDetector also keeps the tap
                // from falling through to the row's play-on-tap. A screen
                // reader hears what it does: "Actions for Late Train Verse, or
                // hold to reorder" — its actions the menu's shortcuts (Info,
                // Keep a copy…, Remove), its focus its own node's.
                _HeldDragStartListener(
                  index: index,
                  child: KeepFocusAnchor(
                    focusKey: focusKey,
                    builder: (context, node) => Semantics(
                      key: const ValueKey('queue-row-grip'),
                      container: true,
                      button: true,
                      label: l.queueRowGripLabel(item.title),
                      onTap: onMenu,
                      customSemanticsActions: actions,
                      child: Focus(
                        focusNode: node,
                        child: ExcludeSemantics(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            // Tap → the song's options; hold and drag →
                            // reorder.
                            onTap: onMenu,
                            child: SizedBox(
                              width: 44,
                              height: 44,
                              child: Center(
                                child: Icon(Icons.drag_handle,
                                    color: VelvetColors.textTertiary,
                                    size: 20),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
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
    // Quick config opens below the header and leaves it undimmed.
    return AutoDjAnchorBar(
      child: Material(
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
                  // autoplay-control pattern) — lit while the DJ runs — and
                  // quick config behind its chevron.
                  const AutoDjSplitButton(),
                  const SizedBox(width: 4),
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

/// Start Auto DJ on the Auto DJ screen's Play from server, or stop it. Stop
/// always stops, whichever server is being browsed: it used to re-arm the DJ
/// on the browsed server instead, so the same button meant two things. Shared
/// by the queue header's and the mini player's Auto DJ buttons and the Auto
/// DJ screen's Start; [announce] confirms with a snackbar, which the screen
/// turns off because its own button already says so.
Future<void> toggleAutoDJ(BuildContext context, {bool announce = true}) async {
  final l = AppLocalizations.of(context);
  final handler = MediaManager().audioHandler;
  final messenger = ScaffoldMessenger.of(context);
  final Server? state = handler.customState.valueOrNull?.autoDJState as Server?;
  if (state != null) {
    handler.customAction('setAutoDJ', {'autoDJServer': null});
    if (announce) {
      messenger.showSnackBar(SnackBar(content: Text(l.autoDjDisabled)));
    }
    return;
  }
  // A shared (federated) server hosts the DJ like any other since mStream
  // #946 put random-songs on the federation allowlist.
  final server = autoDjPlayFrom();
  if (server == null) return;
  // Nothing queued: the DJ has no cue to work from, so it needs a first
  // track before it means anything. With a queue this never runs — the DJ
  // reads what is already there, which is why the old standing "seed song"
  // setting is gone.
  if (handler.queue.value.isEmpty && !await _seedEmptyQueue(context, server)) {
    return; // dismissed, or the pick handed off to the browser
  }
  handler.customAction('setAutoDJ', {'autoDJServer': server});
  if (announce) {
    // Named only when it is the one server the picks come from.
    messenger.showSnackBar(SnackBar(
        content: Text(ServerManager().serverList.length == 1 ||
                autoDjPlayFromSet().length > 1
            ? l.autoDjEnabled
            : l.autoDjEnabledFor(server.displayName))));
  }
}

/// Give the DJ an opening track for an empty queue. Returns true when one is
/// set and the caller should switch the DJ on now; false when it must not —
/// the sheet was dismissed, or the user chose to pick from the library and the
/// browser has taken over (the capture switches the DJ on once a row lands).
Future<bool> _seedEmptyQueue(BuildContext context, Server server) async {
  final mgr = AutoDJManager();
  var choice = mgr.emptyQueueStart;
  TrackFacts? song;
  // Recently played names a song, so it asks every time too — with its
  // dropdown already open.
  if (choice == EmptyQueueStart.ask || choice == EmptyQueueStart.recent) {
    final recent =
        recentlyPlayedOn(await PlayHistory().events(), server.localname);
    if (!context.mounted) return false;
    final picked = await showModalBottomSheet<AutoDjStartChoice>(
      context: context,
      backgroundColor: VelvetColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => AutoDjStartSheet(
          recent: recent, openRecent: choice == EmptyQueueStart.recent),
    );
    if (picked == null) return false; // dismissed — leave the DJ off
    choice = picked.how;
    song = picked.song;
  }
  if (!context.mounted) return false;

  if (choice == EmptyQueueStart.random) return _seedRandom(context, server);
  if (choice == EmptyQueueStart.recent) {
    return song != null && await _seedSong(context, server, song);
  }

  // Pick-from-library: hand off to the browser. Switching the DJ on happens in
  // onPicked, not here — there is nothing to start from until a row lands, and
  // arming it now would open on a random track instead of the chosen one.
  _armLibraryPick(
      context,
      server,
      () => MediaManager()
          .audioHandler
          .customAction('setAutoDJ', {'autoDJServer': server}));
  return false;
}

/// Store [song] — one this phone played on [server] — as the one-shot opener.
/// False, with a snackbar, when the server says it no longer has it (moved,
/// renamed or deleted since it played, or in a library this account has lost):
/// opening on it would take the queue for a track that can't play. A server
/// that can't say (an error, an older server) gets the benefit of the doubt.
Future<bool> _seedSong(
    BuildContext context, Server server, TrackFacts song) async {
  if (await ApiManager().trackExists(server, song.path) == false) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(AppLocalizations.of(context).autoDjSonicSeedFailed)));
    }
    return false;
  }
  await AutoDJManager().setSonicSeed(
      path: song.path,
      title: song.title ?? song.path.split('/').last,
      server: server.localname,
      chosen: true);
  return true;
}

/// Store a random opening track as the one-shot sonic seed. True when a seed
/// is set; false (with a snackbar) when the server had nothing to offer.
Future<bool> _seedRandom(BuildContext context, Server server) async {
  // The FILTERED pick, not the plain random one: this track opens the
  // session, so it has to obey the same rating/genre/length rules every
  // later pick does.
  final seed = await ApiManager().fetchAutoDjSeed(server);
  final path = seed.item?.data;
  if (path == null) {
    if (context.mounted) {
      final l = AppLocalizations.of(context);
      // "Nothing matched" is a different problem from "the request
      // failed", and only one of them the user can do anything about.
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(
              seed.noMatch ? l.autoDjSeedNoMatch : l.autoDjSonicSeedFailed)));
    }
    return false;
  }
  final item = seed.item!;
  await AutoDJManager().setSonicSeed(
      path: path,
      title: item.metadata?.title ?? item.name.split('/').last,
      server: server.localname);
  return true;
}

/// Arm browse-to-pick for the DJ's opening track on [server]. The tapped row
/// becomes the one-shot sonic seed and then [onSeeded] runs — after the
/// arming widget is gone, so it must touch singletons only. Drops every
/// pushed route so the library is in view (the player panel collapses on its
/// own: main.dart watches TrackCapture.active).
void _armLibraryPick(
    BuildContext context, Server server, Future<void> Function() onSeeded) {
  // The pick has to come from [server] — Play from, which need not be the
  // server being browsed — so the library opens on it.
  final servers = ServerManager().serverList;
  if (server != ServerManager().currentServer && servers.contains(server)) {
    unawaited(ServerManager().changeCurrentServer(servers.indexOf(server)));
  }
  TrackCapture.arm(TrackCaptureRequest(
    server: server,
    bannerLabel: (l) => l.autoDjStartPickBanner,
    // No return screen: the question came from the queue, so the pick simply
    // starts the DJ and leaves the user where they are.
    onPicked: (item) {
      final path = item.data;
      if (path == null) return;
      unawaited(AutoDJManager()
          .setSonicSeed(
              path: path,
              title: item.metadata?.title ?? item.name.split('/').last,
              server: server.localname,
              chosen: true)
          .then((_) => onSeeded()));
    },
  ));
  Navigator.of(context).popUntil((r) => r.isFirst);
}

/// The empty-queue placeholder. With the DJ armed the queue is waiting on an
/// opening song (a clear keeps the DJ on but adds nothing itself), so this
/// offers the two ways to give it one; with the DJ off it is just the label.
/// Reads the DJ state live, so switching the DJ off takes the buttons away.
class _EmptyQueue extends StatefulWidget {
  const _EmptyQueue();

  @override
  State<_EmptyQueue> createState() => _EmptyQueueState();
}

class _EmptyQueueState extends State<_EmptyQueue> {
  // Recently played's songs, read once per DJ server: a FutureBuilder handed
  // a new future on every rebuild would flash the row away each time.
  String? _recentFor;
  Future<List<TrackFacts>>? _recent;

  Future<List<TrackFacts>> _recentOn(Server dj) {
    if (_recent == null || _recentFor != dj.localname) {
      _recentFor = dj.localname;
      _recent = PlayHistory()
          .events()
          .then((events) => recentlyPlayedOn(events, dj.localname));
    }
    return _recent!;
  }

  static Future<void> _start() =>
      MediaManager().audioHandler.customAction('startAutoDJFromSeed');

  Future<void> _random(BuildContext context, Server server) async {
    if (await _seedRandom(context, server)) await _start();
  }

  Future<void> _fromSong(Server server, TrackFacts song) async {
    if (await _seedSong(context, server, song)) await _start();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final label = Text(
      l.mainQueueEmpty,
      textAlign: TextAlign.center,
      style: TextStyle(color: VelvetColors.textSecondary, fontSize: 13),
    );
    return StreamBuilder<dynamic>(
      stream: MediaManager().audioHandler.customState,
      initialData: MediaManager().audioHandler.customState.valueOrNull,
      builder: (context, snap) {
        final Server? dj = snap.data?.autoDJState as Server?;
        if (dj == null) return Center(child: label);
        // Centred while it fits; scrolls when the slot is short (a small
        // phone, large text) rather than cutting off the last button.
        return LayoutBuilder(
          builder: (context, box) => SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: box.maxHeight),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      label,
                      const SizedBox(height: 6),
                      Text(
                        l.queueEmptyDjHint,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: VelvetColors.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 14),
                      FutureBuilder<List<TrackFacts>>(
                        future: _recentOn(dj),
                        builder: (context, recent) => Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          alignment: WrapAlignment.center,
                          children: [
                            FilledButton.icon(
                              onPressed: () => _random(context, dj),
                              icon: const Icon(Icons.casino, size: 18),
                              label: Text(l.queueEmptyDjRandom),
                            ),
                            OutlinedButton.icon(
                              onPressed: () => _armLibraryPick(context, dj, _start),
                              icon:
                                  const Icon(Icons.library_music_outlined, size: 18),
                              label: Text(l.queueEmptyDjChoose),
                            ),
                            // Left out until there is something to offer.
                            if (recent.data case final songs? when songs.isNotEmpty)
                              RecentlyPlayedMenu(
                                songs: songs,
                                onPicked: (song) => _fromSong(dj, song),
                                builder: (context, open) => OutlinedButton.icon(
                                  key: const ValueKey('queue-empty-dj-recent'),
                                  onPressed: open,
                                  icon: const Icon(Icons.history, size: 18),
                                  label: Text(l.autoDjRecentlyPlayed),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Auto DJ state at a glance in the queue header (the ∞-icon-on-the-queue
/// pattern): lit while the DJ runs — explore icon when sonic similarity is
/// shaping picks, album icon for the classic random DJ — dim when off.
/// Tapping toggles the DJ for the current server.
/// A reorder grip that waits to be held before it grabs the row.
///
/// The grip column runs the length of the queue, so a flick that happens to
/// start on one used to pick the song up and drag it instead of scrolling.
/// [ReorderableDragStartListener] claims the gesture on touch-down; this waits
/// [_holdBeforeDrag] first, which lets the list's own drag win a quick scroll
/// and leaves a deliberate hold to reorder. Shorter than a long-press: the
/// grip's whole job is dragging, so 500ms of nothing reads as a dead control.
class _HeldDragStartListener extends ReorderableDragStartListener {
  static const _holdBeforeDrag = Duration(milliseconds: 220);

  const _HeldDragStartListener({required super.child, required super.index});

  @override
  MultiDragGestureRecognizer createRecognizer() =>
      DelayedMultiDragGestureRecognizer(
          delay: _holdBeforeDrag, debugOwner: this);
}

