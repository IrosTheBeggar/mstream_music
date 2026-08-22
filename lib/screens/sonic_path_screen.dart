import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../objects/discovery.dart';
import '../objects/display_item.dart';
import '../objects/server.dart';
import '../singletons/api.dart';
import '../singletons/media.dart';
import '../singletons/sonic_path_state.dart';
import '../singletons/track_capture.dart';
import '../theme/velvet_theme.dart';
import '../util/queue_actions.dart';
import '../util/stream_url.dart';
import '../widgets/playlist_picker_sheet.dart';
import '../widgets/song_picker_sheet.dart';
import 'discover_screen.dart' show MatchMeter;

/// Sonic path — the ordered "journey" between two tracks
/// (POST /api/v1/discovery/local/path, mStream #762+): waypoints along the
/// arc between the seeds' embeddings, snapped to real library tracks.
///
/// Two stages, webapp parity (alpha/m.js SONICPATH). Setup: a Start and an
/// End card — filled from the playing track, the search sheet, or by
/// browsing the library (TrackCapture) — plus the length slider and Build.
/// Results: the preview arc (seed rows accented, waypoints wearing match
/// meters) with Play / Queue all / Save as playlist pinned below, endpoints
/// editable in place, and Start over back to a pristine setup. All setup
/// state lives in [SonicPathState] because browse-to-pick tears this route
/// down and re-pushes it after the captured tap.
class SonicPathScreen extends StatefulWidget {
  /// True on the Discover "Play a path to…" flow: the state's endpoints are
  /// complete, skip setup and build immediately. Every other entry (drawer,
  /// capture round-trip) opens on the setup stage.
  final bool autoBuild;

  const SonicPathScreen({super.key, this.autoBuild = false});

  @override
  State<SonicPathScreen> createState() => _SonicPathScreenState();
}

class _SonicPathScreenState extends State<SonicPathScreen> {
  SonicPathState get _s => SonicPathState();
  Server get _server => _s.server!;

  bool _showResults = false;
  bool _loading = false;
  bool _failed = false;
  DiscoveryPath? _path;
  List<DisplayItem> _rows = const [];

  // Repick/Regenerate can overlap an in-flight fetch; last request wins.
  int _reqId = 0;

  @override
  void initState() {
    super.initState();
    // A stale armed pick (drawer re-entry over a live banner) would capture
    // the next browse tap after this screen closes again — drop it.
    TrackCapture.cancel();
    if (widget.autoBuild && _s.ready) {
      _showResults = true;
      _load();
    }
  }

  Future<void> _load() async {
    if (!_s.ready) return;
    final rid = ++_reqId;
    setState(() {
      _loading = true;
      _failed = false;
    });
    final r = await ApiManager().fetchDiscoveryPath(
        _server, _s.start!.path, _s.end!.path,
        length: _s.length);
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
        final row =
            DisplayItem(_server, t.filepath, 'file', '/${t.filepath}', null, null);
        row.metadata = t.metadata;
        return row;
      }).toList();
      // The cards show whatever the picker knew; the seed rows carry the
      // server's own metadata — backfill so a filename-titled pick heals.
      if (results.isNotEmpty) {
        final start = results.first.metadata;
        if ((start?.title ?? '').trim().isNotEmpty) {
          _s.start!.title = start!.title;
          _s.start!.artist = start.artist ?? _s.start!.artist;
        }
        if (results.length > 1) {
          final end = results.last.metadata;
          if ((end?.title ?? '').trim().isNotEmpty) {
            _s.end!.title = end!.title;
            _s.end!.artist = end.artist ?? _s.end!.artist;
          }
        }
      }
    });
  }

  SonicPathEndpoint _endpointFromItem(DisplayItem item) {
    final art = item.altAlbumArt ?? item.metadata?.albumArt;
    return SonicPathEndpoint(
      item.data!,
      title: item.metadata?.title ?? item.name.split('/').last,
      artist: item.metadata?.artist,
      artUrl: art == null ? null : buildAlbumArtUrl(_server, art),
    );
  }

  void _setEndpoint(bool isStart, SonicPathEndpoint? ep) {
    setState(() {
      if (isStart) {
        _s.start = ep;
      } else {
        _s.end = ep;
      }
    });
  }

  /// Search-sheet pick — the setup cards' Search button and the results
  /// stage's chip tap. An endpoint change in results rebuilds immediately
  /// (unlike length, which waits for Regenerate) — the old journey is wrong
  /// the moment its anchor moved.
  Future<void> _pickViaSearch({required bool isStart}) async {
    final l = AppLocalizations.of(context);
    final pick = await showModalBottomSheet<DisplayItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: VelvetColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SongPickerSheet(
        server: _server,
        title: isStart ? l.pathStartSong : l.pathEndSong,
      ),
    );
    if (pick == null || pick.data == null || !mounted) return;
    _setEndpoint(isStart, _endpointFromItem(pick));
    if (_showResults) _load();
  }

  /// Browse-to-pick: arm the capture and drop back to the home browser —
  /// the banner up there carries the instructions, and the tap site
  /// re-pushes this screen once a track lands (state survives in
  /// [SonicPathState], so the card is filled on return).
  void _pickViaBrowse({required bool isStart}) {
    final server = _server;
    TrackCapture.arm(TrackCaptureRequest(
      server: server,
      bannerLabel: (l) =>
          isStart ? l.pathPickBannerStart : l.pathPickBannerEnd,
      returnScreen: (_) => const SonicPathScreen(),
      onPicked: (item) {
        // Runs after this State is disposed — write the singleton only.
        final art = item.altAlbumArt ?? item.metadata?.albumArt;
        final ep = SonicPathEndpoint(
          item.data!,
          title: item.metadata?.title ?? item.name.split('/').last,
          artist: item.metadata?.artist,
          artUrl: art == null ? null : buildAlbumArtUrl(server, art),
        );
        if (isStart) {
          SonicPathState().start = ep;
        } else {
          SonicPathState().end = ep;
        }
      },
    ));
    Navigator.of(context).pop();
  }

  void _usePlaying({required bool isStart}) {
    final l = AppLocalizations.of(context);
    final item = MediaManager().audioHandler.mediaItem.value;
    final extras = item?.extras;
    final path = extras?['path'] as String?;
    if (item == null || path == null) {
      _snack(l.pathNothingPlaying);
      return;
    }
    // Local-only items carry no server; other servers can't seed this one's
    // index. Same guard the webapp applies to federated tracks.
    if (extras?['server'] != _server.localname) {
      _snack(l.pathPickOnServer(_server.localname));
      return;
    }
    _setEndpoint(
        isStart,
        SonicPathEndpoint(path,
            title: item.title,
            artist: item.artist,
            artUrl: extras?['artUrl'] as String?));
  }

  void _build() {
    if (!_s.ready) return;
    setState(() => _showResults = true);
    _load();
  }

  /// Start over — drop the journey and the endpoints, back to a pristine
  /// setup on the same server (webapp parity).
  void _startOver() {
    _reqId++; // orphan any in-flight fetch
    _s.reset();
    setState(() {
      _showResults = false;
      _loading = false;
      _failed = false;
      _path = null;
      _rows = const [];
    });
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      behavior: SnackBarBehavior.floating,
    ));
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
      builder: (_) => PlaylistPickerSheet(server: _server),
    );
    final playlist = name?.trim();
    if (playlist == null || playlist.isEmpty || !mounted) return;
    try {
      await ApiManager().savePlaylist(
          _server, playlist, [for (final t in path.results) t.filepath]);
      // Keep pickers fresh before the next ping refreshes the server's
      // playlist list.
      if (!_server.playlists.contains(playlist)) {
        _server.playlists.add(playlist);
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
    // Every entry point binds the server before pushing; a bare push (hot
    // reload edge) has nothing to build against.
    if (_s.server == null) {
      return Scaffold(backgroundColor: VelvetColors.bg);
    }
    final path = _path;
    final hasRows = _showResults && path != null && path.results.isNotEmpty;

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
        actions: [
          if (_showResults)
            IconButton(
              icon: const Icon(Icons.restart_alt, size: 22),
              tooltip: l.pathStartOver,
              onPressed: _startOver,
            ),
        ],
      ),
      body: _showResults
          // Endpoint chips + length controls stay visible in every result
          // state: a failed or not-analyzed journey is fixed by editing
          // them, not by leaving the screen.
          ? Column(
              children: [
                _endpointsRow(l),
                _lengthRow(l, withRegen: true),
                Expanded(child: _resultsBody(l)),
              ],
            )
          : _setupBody(l),
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

  // ── setup stage ──

  Widget _setupBody(AppLocalizations l) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        Text(
          l.pathSetupHint,
          style: TextStyle(color: VelvetColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 14),
        _setupCard(l, isStart: true),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child:
              Icon(Icons.south, size: 18, color: VelvetColors.textSecondary),
        ),
        _setupCard(l, isStart: false),
        const SizedBox(height: 6),
        _lengthRow(l, withRegen: false, inset: false),
        const SizedBox(height: 10),
        FilledButton.icon(
          icon: const Icon(Icons.route, size: 20),
          label: Text(l.pathBuild),
          style: FilledButton.styleFrom(
            backgroundColor: VelvetColors.primary,
            foregroundColor: VelvetColors.bg,
            disabledBackgroundColor: VelvetColors.raised,
            disabledForegroundColor: VelvetColors.textSecondary,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          onPressed: _s.ready ? _build : null,
        ),
      ],
    );
  }

  Widget _setupCard(AppLocalizations l, {required bool isStart}) {
    final ep = isStart ? _s.start : _s.end;
    return Material(
      color: VelvetColors.raised,
      borderRadius: BorderRadius.circular(VelvetColors.radiusLarge),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  isStart ? Icons.trip_origin : Icons.flag,
                  size: 16,
                  color: VelvetColors.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  isStart ? l.pathStartSong : l.pathEndSong,
                  style: TextStyle(
                    color: VelvetColors.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (ep == null) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 10, right: 6),
                child: Text(
                  l.pathNotSet,
                  style: TextStyle(
                      color: VelvetColors.textSecondary,
                      fontSize: 13,
                      fontStyle: FontStyle.italic),
                ),
              ),
              // A filled card hides these — a settled decision (webapp
              // parity); the ✕ below reopens it.
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _cardButton(Icons.play_circle_outline, l.pathUsePlaying,
                        () => _usePlaying(isStart: isStart)),
                    _cardButton(Icons.search, l.pathSearchSong,
                        () => _pickViaSearch(isStart: isStart)),
                    _cardButton(Icons.library_music_outlined,
                        l.pathBrowseLibrary,
                        () => _pickViaBrowse(isStart: isStart)),
                  ],
                ),
              ),
            ] else
              Row(
                children: [
                  _endpointArt(ep),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          (ep.title?.trim().isNotEmpty ?? false)
                              ? ep.title!
                              : ep.path.split('/').last,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: VelvetColors.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (ep.artist?.trim().isNotEmpty ?? false)
                          Text(
                            ep.artist!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: VelvetColors.textSecondary,
                                fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    color: VelvetColors.textSecondary,
                    onPressed: () => _setEndpoint(isStart, null),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _cardButton(IconData icon, String label, VoidCallback onPressed) {
    return OutlinedButton.icon(
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 12)),
      style: OutlinedButton.styleFrom(
        foregroundColor: VelvetColors.primary,
        side: BorderSide(color: VelvetColors.border2),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onPressed,
    );
  }

  Widget _endpointArt(SonicPathEndpoint ep) {
    final radius = BorderRadius.circular(VelvetColors.radiusSmall);
    if (ep.artUrl != null) {
      return ClipRRect(
        borderRadius: radius,
        child: Image.network(
          ep.artUrl!,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => _artPlaceholder(radius),
        ),
      );
    }
    return _artPlaceholder(radius);
  }

  Widget _artPlaceholder(BorderRadius radius) => Container(
        width: 44,
        height: 44,
        decoration:
            BoxDecoration(color: VelvetColors.surface, borderRadius: radius),
        child: Icon(Icons.music_note,
            size: 20, color: VelvetColors.textSecondary),
      );

  // ── results stage ──

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
    final ep = isStart ? _s.start : _s.end;
    final title = ep?.title?.trim();
    final artist = ep?.artist?.trim();
    final fallback = ep?.path.split('/').last ?? '';
    return Material(
      color: VelvetColors.raised,
      borderRadius: BorderRadius.circular(VelvetColors.radiusLarge),
      child: InkWell(
        borderRadius: BorderRadius.circular(VelvetColors.radiusLarge),
        onTap: () => _pickViaSearch(isStart: isStart),
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

  Widget _lengthRow(AppLocalizations l,
      {required bool withRegen, bool inset = true}) {
    return Padding(
      padding: inset
          ? const EdgeInsets.fromLTRB(16, 0, 4, 0)
          : EdgeInsets.zero,
      child: Row(
        children: [
          Text(
            l.pathLength,
            style: TextStyle(color: VelvetColors.textSecondary, fontSize: 13),
          ),
          Expanded(
            child: Slider(
              value: _s.length.toDouble().clamp(4.0, 32.0),
              min: 4,
              max: 32,
              divisions: 28,
              label: '${_s.length}',
              onChanged: (v) => setState(() => _s.length = v.round()),
            ),
          ),
          SizedBox(
            width: 22,
            child: Text(
              '${_s.length}',
              textAlign: TextAlign.end,
              style: TextStyle(
                color: VelvetColors.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          if (withRegen)
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

  Widget _resultsBody(AppLocalizations l) {
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
