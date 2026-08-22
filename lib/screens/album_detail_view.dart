// album_detail_view.dart — album detail rendered INSIDE the browser body (not a
// route), so the global mini-player stays visible. Driven by
// BrowserManager.albumDetail: when set, main.dart shows this over the file list
// (in an IndexedStack) and Back dismisses it via BrowserManager.closeAlbumDetail.
//
// Layout (simplified from the original route screen): a medium-player-style
// banner — album art left, title/artist/meta right — painted over the
// album-art colour splash, then the track list. Play / Shuffle / Add all live
// in the shared BrowserToolbar above, same as every other track list. Per-track
// album runtime, and the kbps · kHz readout render only when the server reports
// them (older API builds omit them; see MusicMetadata).

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

import '../l10n/app_localizations.dart';
import '../objects/display_item.dart';
import '../screens/sonic_path_screen.dart';
import '../singletons/api.dart';
import '../singletons/browser_list.dart';
import '../singletons/media.dart';
import '../singletons/track_capture.dart';
import '../theme/velvet_theme.dart';
import '../util/ambient_color.dart';
import '../util/media_format.dart';
import '../util/queue_actions.dart';
import '../util/stream_url.dart';
import '../util/image_cache.dart';
import '../widgets/player_panel.dart';
import '../widgets/track_actions_sheet.dart';

class AlbumDetailView extends StatefulWidget {
  /// The tapped album row — carries name, server, altAlbumArt (`album_art_file`)
  /// and subtext, from getAlbums().
  final DisplayItem album;

  const AlbumDetailView({super.key, required this.album});

  @override
  State<AlbumDetailView> createState() => _AlbumDetailViewState();
}

class _AlbumDetailViewState extends State<AlbumDetailView> {
  List<DisplayItem>? _songs; // null while loading
  bool _error = false;
  Gradient? _ambient; // null until the seed resolves (or stays null = no tint)

  // Current-track path + playing flag, distinct() so per-position playbackState
  // ticks don't rebuild the list (only a track change / play-pause flips the
  // highlight). Path matches buildServerFileMediaItem's extras['path'].
  late final Stream<({String? path, bool playing})> _nowStream =
      Rx.combineLatest2<MediaItem?, PlaybackState,
          ({String? path, bool playing})>(
        MediaManager().audioHandler.mediaItem,
        MediaManager().audioHandler.playbackState,
        (m, s) => (path: m?.extras?['path'] as String?, playing: s.playing),
      ).distinct((a, b) => a.path == b.path && a.playing == b.playing);

  @override
  void initState() {
    super.initState();
    _load();
    _loadAmbient();
  }

  Future<void> _load() async {
    try {
      final songs = await ApiManager()
          .fetchAlbumSongs(widget.album.data, useThisServer: widget.album.server);
      // Publish to BrowserManager so the top toolbar's download / add-all act on
      // these songs.
      BrowserManager().albumDetailSongs = songs;
      if (!mounted) return;
      setState(() => _songs = songs);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _songs = const [];
        _error = true;
      });
    }
  }

  // Colour splash seeded from the cover (vibrant, falling back to dominant);
  // anchored top-left to glow from the art. Stays null on missing / near-
  // grayscale art (the engine's grayscale fallback).
  Future<void> _loadAmbient() async {
    final url = _artUrl();
    if (url == null) return;
    final seed = await dominantAlbumColor(url, vibrant: true) ??
        await dominantAlbumColor(url);
    if (!mounted || seed == null) return;
    final grad = ambientGradient(seed,
        base: VelvetColors.bg,
        vibrant: true,
        center: Alignment.topLeft,
        radius: 1.0); // 80% of the engine default (1.25)
    if (grad == null) return;
    setState(() => _ambient = grad);
  }

  String? _artUrl([String compress = 'l']) {
    final aa = widget.album.altAlbumArt;
    final server = widget.album.server;
    if (server == null || aa == null) return null;
    return buildAlbumArtUrl(server, aa, compress: compress);
  }

  // ── derived metadata ──
  String _artistLabel(List<DisplayItem> songs, AppLocalizations l) {
    final artists = songs
        .map((s) => s.metadata?.artist)
        .where((a) => a != null && a.trim().isNotEmpty)
        .toSet();
    if (artists.isEmpty) return '';
    if (artists.length == 1) return artists.first!;
    return l.variousArtists;
  }

  String? _yearLabel(List<DisplayItem> songs) {
    for (final song in songs) {
      if (song.metadata?.year != null) return song.metadata!.year.toString();
    }
    return null;
  }

  // Format from the first track's file extension (e.g. ".flac" → "FLAC").
  String? _formatLabel(List<DisplayItem> songs) {
    for (final s in songs) {
      final fp = s.data ?? '';
      final dot = fp.lastIndexOf('.');
      if (dot > 0 && dot < fp.length - 1) {
        return fp.substring(dot + 1).toUpperCase();
      }
    }
    return null;
  }

  // Album runtime — only when EVERY track reports a duration (newer servers),
  // so a partial sum never shows a misleading total.
  Duration? _runtime(List<DisplayItem> songs) {
    if (songs.isEmpty) return null;
    int ms = 0;
    for (final s in songs) {
      final d = s.metadata?.duration;
      if (d == null) return null;
      ms += d.inMilliseconds;
    }
    return Duration(milliseconds: ms);
  }

  String _runtimeLabel(Duration d) {
    final mins = (d.inSeconds / 60).round();
    if (mins < 60) return '$mins min';
    return '${mins ~/ 60} hr ${mins % 60} min';
  }

  int? _bitrate(List<DisplayItem> songs) {
    for (final s in songs) {
      if (s.metadata?.bitrate != null) return s.metadata!.bitrate;
    }
    return null;
  }

  int? _sampleRate(List<DisplayItem> songs) {
    for (final s in songs) {
      if (s.metadata?.sampleRate != null) return s.metadata!.sampleRate;
    }
    return null;
  }

  // ── actions ──
  // Row tap: defer to the shared TapBehavior setting (the same one the file
  // browser uses). A pure add-to-queue shows a confirmation toast. An armed
  // sonic-path pick eats the tap first — nothing may queue mid-pick.
  Future<void> _onRowTap(int index) async {
    final songs = _songs;
    if (songs == null || index < 0 || index >= songs.length) return;
    switch (TrackCapture.tryCapture(songs[index])) {
      case CaptureResult.captured:
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const SonicPathScreen()),
        );
        return;
      case CaptureResult.rejected:
        showCaptureRejectedToast(context);
        return;
      case CaptureResult.pass:
        break;
    }
    if (await handleTrackTap(songs, index)) _toast();
  }

  // ── per-row overflow ──
  // The same sheet the browser's track rows open, so a song offers the same
  // actions wherever you meet it — and gains Add to playlist / Download,
  // which the dropdown this replaced never had.
  void _showTrackActions(DisplayItem item) {
    showModalBottomSheet(
      context: context,
      backgroundColor: VelvetColors.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => TrackActionsSheet(item: item, parentContext: context),
    );
  }


  // "Added to queue" confirmation. Floats above the docked mini-player — that
  // overlay sits in a higher layer at the bottom and would otherwise hide a
  // standard bottom snackbar (the bug this fixes).
  void _toast() {
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(l.browserSongsAdded(1)),
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: PlayerPanel.kCollapsedHeight +
            MediaQuery.of(context).viewPadding.bottom +
            8,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final songs = _songs;
    // Ambient colour splash spans the whole view (banner + track list), glowing
    // from the top-left and fading down across the song list. The rows are
    // transparent, so it shows through; the engine's contrast floor keeps titles
    // legible, and it fades to bg (opaque) so the offstage browser never shows.
    return AnimatedContainer(
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        gradient: _ambient ??
            LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [VelvetColors.surface, VelvetColors.bg],
            ),
      ),
      child: Column(
        children: [
          _banner(l, songs),
          Expanded(
            child: songs == null
                ? const Center(child: CircularProgressIndicator())
                : songs.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            _error ? l.mainFailedToConnect : l.mainQueueEmpty,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: VelvetColors.textSecondary, fontSize: 14),
                          ),
                        ),
                      )
                    : _trackList(songs),
          ),
        ],
      ),
    );
  }

  // ── banner: back/overflow + medium-player-style art-left header over the splash ──
  Widget _banner(AppLocalizations l, List<DisplayItem>? songs) {
    final artUrl = _artUrl();
    final artist = songs == null ? '' : _artistLabel(songs, l);

    final metaParts = <String>[];
    if (songs != null) {
      final year = _yearLabel(songs);
      if (year != null) metaParts.add(year);
      metaParts.add(l.trackCount(songs.length));
      final rt = _runtime(songs);
      if (rt != null) metaParts.add(_runtimeLabel(rt));
      final fmt = _formatLabel(songs);
      if (fmt != null) metaParts.add(fmt);
      final br = _bitrate(songs);
      if (br != null) metaParts.add(formatBitrate(br));
      final sr = _sampleRate(songs);
      if (sr != null) metaParts.add(formatSampleRate(sr));
    }

    return Container(
      // The splash is painted by the root now; the banner just carries the
      // hairline divider and lets the gradient show through.
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: VelvetColors.border)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Back + overflow live in the top toolbar now; the banner is just the
          // art-left header. Top pad clears the AppBar toolbar above it.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 86,
                    height: 86,
                    child: artUrl != null
                        ? Image.network(artUrl,
                            fit: BoxFit.cover,
                            cacheWidth: artCacheSize(86),
                            errorBuilder: (_, _, _) =>
                                albumArtFallback(iconSize: 30))
                        : albumArtFallback(iconSize: 30),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.album.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          height: 1.12,
                          letterSpacing: -0.2,
                          color: VelvetColors.textPrimary,
                        ),
                      ),
                      if (artist.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          artist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13.5,
                              color: VelvetColors.textSecondary),
                        ),
                      ],
                      if (metaParts.isNotEmpty) ...[
                        const SizedBox(height: 5),
                        Text(
                          metaParts.join('  ·  '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 10,
                            letterSpacing: 0.2,
                            color: VelvetColors.textTertiary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                // Play + Shuffle used to sit here, stacked. They live in the
                // top toolbar now (see BrowserToolbar's album branch) so the
                // controls are in the same place on every track list.
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Tappable rating for a track row: small stars when rated, a single outline
  // star otherwise; opens the rating form on tap and refreshes the list on
  // change. Empty placeholder if the row has no server/path (shouldn't happen
 
  /// Disc a track belongs to. The server treats an absent disc tag as disc 1
  /// when it sorts (COALESCE(disc_number, 1) in ALBUM_TRACK_ORDER), so the
  /// grouping here has to agree or a half-tagged album would show a phantom
  /// extra disc.
  int _discOf(DisplayItem s) => s.metadata?.disc ?? 1;

  Widget _trackList(List<DisplayItem> songs) {
    // Rows arrive already in album order (server-side ALBUM_TRACK_ORDER:
    // disc, then track, with untagged tracks last within their disc), so this
    // only has to RENDER that order — never re-sort it.
    final discs = {for (final s in songs) _discOf(s)};
    final showDiscs = discs.length > 1;
    // Real track numbers, but only when the album actually carries them.
    // Falling back to the row's position per-track would hand an untagged
    // file a tidy sequential number and hide the fact it has no tag; falling
    // back for the WHOLE album keeps a completely untagged one readable.
    final anyTrackNumbers =
        songs.any((s) => s.metadata?.track != null);

    // Flattened render list: a disc header owns a null song.
    final entries = <({DisplayItem? song, int index, int disc})>[];
    int? lastDisc;
    for (var i = 0; i < songs.length; i++) {
      final d = _discOf(songs[i]);
      if (showDiscs && d != lastDisc) {
        entries.add((song: null, index: -1, disc: d));
        lastDisc = d;
      }
      entries.add((song: songs[i], index: i, disc: d));
    }

    return StreamBuilder<({String? path, bool playing})>(
      stream: _nowStream,
      initialData: (path: null, playing: false),
      builder: (context, snap) {
        final now = snap.data ?? (path: null, playing: false);
        final l = AppLocalizations.of(context);
        return ListView.builder(
          padding: const EdgeInsets.only(top: 4, bottom: 12),
          itemCount: entries.length,
          itemBuilder: (context, e) {
            final entry = entries[e];
            final s = entry.song;
            if (s == null) return _discHeader(l, entry.disc);
            return _SongRow(
              // A track with no number inside an otherwise-tagged album shows
              // a dash rather than a made-up one.
              number: anyTrackNumbers
                  ? s.metadata?.track
                  : entry.index + 1,
              title: s.metadata?.title ?? (s.data ?? '').split('/').last,
              active: now.path != null && now.path == s.data,
              playing: now.playing,
              onTap: () => _onRowTap(entry.index),
              onMenu: () => _showTrackActions(s),
            );
          },
        );
      },
    );
  }

  Widget _discHeader(AppLocalizations l, int disc) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      child: Row(
        children: [
          Icon(Icons.album_outlined, size: 13, color: VelvetColors.primary),
          const SizedBox(width: 7),
          Text(
            l.albumDiscNumber(disc),
            style: TextStyle(
              color: VelvetColors.primary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Container(height: 1, color: VelvetColors.border)),
        ],
      ),
    );
  }
}

/// One track row: number (or active EQ/play indicator), title, and the
/// overflow that opens the shared TrackActionsSheet. Duration and rating both
/// live in that sheet now — the row is just the song. The row tap itself
/// follows the shared TapBehavior setting.
class _SongRow extends StatelessWidget {
  /// Null when the track carries no number in a tagged album.
  final int? number;
  final String title;
  final bool active;
  final bool playing;
  final VoidCallback onTap;
  final VoidCallback onMenu;

  const _SongRow({
    required this.number,
    required this.title,
    required this.active,
    required this.playing,
    required this.onTap,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Material(
      color: active ? VelvetColors.primaryDim : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                  color: active ? VelvetColors.primary : Colors.transparent,
                  width: 2),
              bottom: BorderSide(color: VelvetColors.border, width: 0.5),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                child: Center(
                  child: active
                      ? Icon(playing ? Icons.graphic_eq : Icons.play_arrow,
                          size: playing ? 18 : 16, color: VelvetColors.primary)
                      : Text(
                          number == null
                              ? '--'
                              : number.toString().padLeft(2, '0'),
                          style: TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13,
                            color: VelvetColors.textTertiary,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: active ? FontWeight.w500 : FontWeight.w400,
                    color:
                        active ? VelvetColors.primary : VelvetColors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Same overflow the browser's track rows carry, opening the
              // same sheet. Rating lives in there now, which is why the row's
              // inline stars are gone.
              IconButton(
                icon: Icon(Icons.more_vert,
                    size: 20, color: VelvetColors.textSecondary),
                tooltip: l.browserMoreActions,
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 40, minHeight: 40),
                onPressed: onMenu,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
