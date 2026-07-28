import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../objects/discovery.dart';
import '../objects/display_item.dart';
import '../objects/server.dart';
import '../singletons/api.dart';
import '../theme/velvet_theme.dart';
import '../util/queue_actions.dart';
import '../widgets/playlist_picker_sheet.dart';
import '../widgets/song_picker_sheet.dart';
import 'discover_screen.dart' show MatchMeter;

/// Sonic path — the ordered "journey" between two tracks
/// (POST /api/v1/discovery/local/path, mStream #762+): waypoints along the
/// arc between the seeds' embeddings, snapped to real library tracks. A
/// preview-first screen: the user sees the whole arc (start → rows → end)
/// before committing, then Play (replaces the queue), Queue all (appends)
/// or Save as playlist. The launch args only seed the first fetch — both
/// endpoints are editable in place (chip tap → repick → rebuild) and the
/// length slider stays local until Regenerate, so the current list is
/// never yanked away mid-look (webapp parity).
class SonicPathScreen extends StatefulWidget {
  final Server server;
  final String startPath;
  final String? startTitle;
  final String? startArtist;
  final String endPath;
  final String? endTitle;
  final String? endArtist;

  const SonicPathScreen({
    super.key,
    required this.server,
    required this.startPath,
    this.startTitle,
    this.startArtist,
    required this.endPath,
    this.endTitle,
    this.endArtist,
  });

  @override
  State<SonicPathScreen> createState() => _SonicPathScreenState();
}

class _SonicPathScreenState extends State<SonicPathScreen> {
  bool _loading = true;
  bool _failed = false;
  DiscoveryPath? _path;
  List<DisplayItem> _rows = const [];

  // Editable endpoints, seeded from the launch args. Kept as plain state so
  // a repick (or a not-analyzed dead end) can be fixed without backing out
  // to the Discover screen.
  late String _startPath = widget.startPath;
  late String? _startTitle = widget.startTitle;
  late String? _startArtist = widget.startArtist;
  late String _endPath = widget.endPath;
  late String? _endTitle = widget.endTitle;
  late String? _endArtist = widget.endArtist;

  /// Requested total rows including both seeds (server default 14, valid
  /// 4..32). Slider moves are local; only Regenerate (or an endpoint
  /// change) refetches with it.
  int _length = 14;

  // Repick/Regenerate can overlap an in-flight fetch; last request wins.
  int _reqId = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final rid = ++_reqId;
    setState(() {
      _loading = true;
      _failed = false;
    });
    final r = await ApiManager().fetchDiscoveryPath(
        widget.server, _startPath, _endPath,
        length: _length);
    if (!mounted || rid != _reqId) return;
    setState(() {
      _loading = false;
      // 403 = the ping flag was stale; both fold into the retryable state.
      if (r.data == null) {
        _failed = true;
        return;
      }
      _path = r.data;
      final results = r.data!.results;
      _rows = results.map((t) {
        final row = DisplayItem(widget.server, t.filepath, 'file',
            '/${t.filepath}', null, null);
        row.metadata = t.metadata;
        return row;
      }).toList();
      // The chips show whatever the picker knew; the seed rows carry the
      // server's own metadata — backfill so a filename-titled pick heals.
      if (results.isNotEmpty) {
        final start = results.first.metadata;
        if ((start?.title ?? '').trim().isNotEmpty) {
          _startTitle = start!.title;
          _startArtist = start.artist ?? _startArtist;
        }
        if (results.length > 1) {
          final end = results.last.metadata;
          if ((end?.title ?? '').trim().isNotEmpty) {
            _endTitle = end!.title;
            _endArtist = end.artist ?? _endArtist;
          }
        }
      }
    });
  }

  /// Chip tap → shared song picker → endpoint swap. An endpoint change
  /// rebuilds immediately (unlike length, which waits for Regenerate) —
  /// the old journey is wrong the moment its anchor moved.
  Future<void> _repick({required bool isStart}) async {
    final l = AppLocalizations.of(context);
    final pick = await showModalBottomSheet<DisplayItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: VelvetColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SongPickerSheet(
        server: widget.server,
        title: isStart ? l.pathStartSong : l.pathEndSong,
      ),
    );
    final path = pick?.data;
    if (pick == null || path == null || !mounted) return;
    setState(() {
      final title = pick.metadata?.title ?? path.split('/').last;
      if (isStart) {
        _startPath = path;
        _startTitle = title;
        _startArtist = pick.metadata?.artist;
      } else {
        _endPath = path;
        _endTitle = title;
        _endArtist = pick.metadata?.artist;
      }
    });
    _load();
  }

  Future<void> _play() async {
    if (_rows.isEmpty) return;
    await playFromHere(_rows, 0);
  }

  Future<void> _queueAll() async {
    if (_rows.isEmpty) return;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final n = await addRowsToQueue(_rows);
    if (n > 0 && mounted) {
      messenger.showSnackBar(SnackBar(
        content: Text(l.browserSongsAdded(n)),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  /// Save the current journey as a server playlist (create-or-overwrite —
  /// picking an existing name replaces its contents, the save-flow
  /// convention). Reuses the shared picker sheet from Add-to-playlist.
  Future<void> _saveAsPlaylist() async {
    final path = _path;
    if (path == null || path.results.isEmpty) return;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final name = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: VelvetColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => PlaylistPickerSheet(server: widget.server),
    );
    final playlist = name?.trim();
    if (playlist == null || playlist.isEmpty || !mounted) return;
    try {
      await ApiManager().savePlaylist(widget.server, playlist,
          [for (final t in path.results) t.filepath]);
      // Keep pickers fresh before the next ping refreshes the server's
      // playlist list.
      if (!widget.server.playlists.contains(playlist)) {
        widget.server.playlists.add(playlist);
      }
      messenger.showSnackBar(SnackBar(
        content: Text(l.addedToPlaylist(playlist)),
        behavior: SnackBarBehavior.floating,
      ));
    } catch (_) {
      messenger.showSnackBar(SnackBar(
        content: Text(l.trackAddToPlaylistFailed),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final path = _path;
    final hasRows = path != null && path.results.isNotEmpty;

    return Scaffold(
      backgroundColor: VelvetColors.bg,
      appBar: AppBar(
        backgroundColor: VelvetColors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: VelvetColors.textPrimary,
        title: Text(
          l.pathScreenTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: VelvetColors.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      // Endpoint chips + length controls stay visible in every body state:
      // a failed or not-analyzed journey is fixed by editing them, not by
      // leaving the screen.
      body: Column(
        children: [
          _endpointsRow(l),
          _lengthRow(l),
          Expanded(child: _body(l)),
        ],
      ),
      // Play / Queue all / Save — pinned so the arc scrolls under them.
      bottomNavigationBar: hasRows
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        icon: const Icon(Icons.play_arrow, size: 20),
                        label: Text(l.play),
                        style: FilledButton.styleFrom(
                          backgroundColor: VelvetColors.primary,
                          foregroundColor: VelvetColors.bg,
                        ),
                        onPressed: _play,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.playlist_add, size: 20),
                        label: Text(l.discoverQueueAll),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: VelvetColors.primary,
                          side: BorderSide(color: VelvetColors.border2),
                        ),
                        onPressed: _queueAll,
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Icon-only to fit three actions on narrow screens; the
                    // tooltip + result toast carry the name.
                    Tooltip(
                      message: l.pathSaveAsPlaylist,
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: VelvetColors.primary,
                          side: BorderSide(color: VelvetColors.border2),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                        ),
                        onPressed: _saveAsPlaylist,
                        child: const Icon(Icons.playlist_add_check, size: 20),
                      ),
                    ),
                  ],
                ),
              ),
            )
          : null,
    );
  }

  Widget _endpointsRow(AppLocalizations l) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Row(
        children: [
          Expanded(child: _endpointChip(l, isStart: true)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Icon(Icons.arrow_right_alt,
                size: 18, color: VelvetColors.textSecondary),
          ),
          Expanded(child: _endpointChip(l, isStart: false)),
        ],
      ),
    );
  }

  Widget _endpointChip(AppLocalizations l, {required bool isStart}) {
    final title = (isStart ? _startTitle : _endTitle)?.trim();
    final artist = (isStart ? _startArtist : _endArtist)?.trim();
    final fallback = (isStart ? _startPath : _endPath).split('/').last;
    return Material(
      color: VelvetColors.raised,
      borderRadius: BorderRadius.circular(VelvetColors.radiusLarge),
      child: InkWell(
        borderRadius: BorderRadius.circular(VelvetColors.radiusLarge),
        onTap: () => _repick(isStart: isStart),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              Icon(
                isStart ? Icons.trip_origin : Icons.flag,
                size: 16,
                color: VelvetColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      (title != null && title.isNotEmpty) ? title : fallback,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: VelvetColors.textPrimary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (artist != null && artist.isNotEmpty)
                      Text(
                        artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: VelvetColors.textSecondary, fontSize: 11),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Icon(Icons.edit, size: 14, color: VelvetColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }

  Widget _lengthRow(AppLocalizations l) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 4, 0),
      child: Row(
        children: [
          Text(
            l.pathLength,
            style: TextStyle(color: VelvetColors.textSecondary, fontSize: 13),
          ),
          Expanded(
            child: Slider(
              value: _length.toDouble().clamp(4.0, 32.0),
              min: 4,
              max: 32,
              divisions: 28,
              label: '$_length',
              onChanged: (v) => setState(() => _length = v.round()),
            ),
          ),
          SizedBox(
            width: 22,
            child: Text(
              '$_length',
              textAlign: TextAlign.end,
              style: TextStyle(
                color: VelvetColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, size: 20),
            color: VelvetColors.primary,
            tooltip: l.pathRegenerate,
            onPressed: _loading ? null : _load,
          ),
        ],
      ),
    );
  }

  Widget _body(AppLocalizations l) {
    if (_loading) {
      return Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: VelvetColors.primary,
          ),
        ),
      );
    }
    final path = _path;
    if (_failed || path == null) {
      return _hint(l.discoverNothingFound, retry: true);
    }
    if (path.notAnalyzed) {
      return _hint(
        path.notAnalyzedStart ? l.pathStartNotAnalyzed : l.pathEndNotAnalyzed,
      );
    }
    if (path.results.isEmpty) {
      return _hint(l.discoverNothingFound, retry: true);
    }

    final last = path.results.length - 1;
    return ListView.builder(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      itemCount: path.results.length,
      itemBuilder: (context, i) {
        final track = path.results[i];
        final row = i < _rows.length ? _rows[i] : null;
        final isSeed = i == 0 || i == last;
        final artist = track.metadata?.artist;
        final genre = genreTagLabel(track.genreTags);
        final subtitle = [
          if (artist != null && artist.trim().isNotEmpty) artist.trim(),
          ?genre,
        ].join(' · ');
        return ListTile(
          dense: true,
          // The endpoints anchor the journey — flag + accent them; the
          // waypoints show how far along the arc they sit via the meter.
          leading: row?.getAlbumThumb(size: 44),
          title: Text(
            track.displayTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: isSeed ? FontWeight.w600 : FontWeight.w400,
              color:
                  isSeed ? VelvetColors.primary : VelvetColors.textPrimary,
            ),
          ),
          subtitle: subtitle.isEmpty
              ? null
              : Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 13, color: VelvetColors.textSecondary),
                ),
          trailing: isSeed
              ? Icon(
                  i == 0 ? Icons.trip_origin : Icons.flag,
                  size: 18,
                  color: VelvetColors.primary,
                )
              : MatchMeter(similarity: track.similarity),
          onTap: () => handleTrackTap(_rows, i),
        );
      },
    );
  }

  Widget _hint(String text, {bool retry = false}) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(
                    color: VelvetColors.textSecondary, fontSize: 14),
              ),
              if (retry) ...[
                const SizedBox(height: 12),
                TextButton(
                  onPressed: _load,
                  child: Text(
                    l10nRetry(context),
                    style: TextStyle(color: VelvetColors.primary),
                  ),
                ),
              ],
            ],
          ),
        ),
      );
}

// The lyrics screen's retry label is the app's generic one — reuse it.
String l10nRetry(BuildContext context) =>
    AppLocalizations.of(context).lyricsRetry;
