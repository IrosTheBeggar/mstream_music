// album_detail_view.dart — album detail rendered INSIDE the browser body (not a
// route), so the global mini-player stays visible. Driven by
// BrowserManager.albumDetail: when set, main.dart shows this over the file list
// (in an IndexedStack) and Back dismisses it via BrowserManager.closeAlbumDetail.
//
// Layout (simplified from the original route screen): a medium-player-style
// banner — album art left, title/artist/meta right, Play + Shuffle — painted
// over the album-art colour splash, then the track list. Per-track duration,
// album runtime, and the kbps · kHz readout render only when the server reports
// them (older API builds omit them; see MusicMetadata).

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:rxdart/rxdart.dart';

import '../l10n/app_localizations.dart';
import '../objects/display_item.dart';
import '../singletons/api.dart';
import '../singletons/browser_list.dart';
import '../singletons/media.dart';
import '../singletons/settings.dart';
import '../theme/velvet_theme.dart';
import '../util/ambient_color.dart';
import '../util/media_format.dart';
import '../util/queue_actions.dart';
import '../util/stream_url.dart';
import '../util/image_cache.dart';
import '../widgets/player_panel.dart';

/// Ink on top of the accent-filled Play button: dark espresso on bright accents,
/// white on a dark custom accent (mirrors player_panel's `_kAmberInk`).
Color get _accentInk => VelvetColors.primary.computeLuminance() > 0.42
    ? const Color(0xFF1A1206)
    : Colors.white;

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
  void _playFrom(int index, {bool shuffle = false}) {
    final songs = _songs;
    if (songs == null || songs.isEmpty) return;
    playFromHere(songs, index, shuffle: shuffle);
  }

  // Row tap: defer to the shared TapBehavior setting (the same one the file
  // browser uses). A pure add-to-queue shows a confirmation toast.
  Future<void> _onRowTap(int index) async {
    final songs = _songs;
    if (songs == null) return;
    if (await handleTrackTap(songs, index)) _toast();
  }

  // ── per-row play-options menu ──
  Future<void> _rowAddNext(int index) async {
    final songs = _songs;
    if (songs == null || index < 0 || index >= songs.length) return;
    await addNext(songs[index]);
    _toast();
  }

  void _rowPlayNow(int index) {
    final songs = _songs;
    if (songs == null || index < 0 || index >= songs.length) return;
    playNow(songs[index]);
  }

  Future<void> _rowAddToEnd(int index) async {
    final songs = _songs;
    if (songs == null || index < 0 || index >= songs.length) return;
    await addToQueueEnd(songs[index]);
    _toast();
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
    final enabled = songs != null && songs.isNotEmpty;
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
                const SizedBox(width: 8),
                // Play (filled) + Shuffle, stacked to keep the banner compact.
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton.filled(
                      onPressed: enabled ? () => _playFrom(0) : null,
                      tooltip: l.play,
                      icon: Icon(Icons.play_arrow, color: _accentInk),
                      style: IconButton.styleFrom(
                        backgroundColor: VelvetColors.primary,
                        disabledBackgroundColor:
                            VelvetColors.primary.withValues(alpha: 0.4),
                      ),
                    ),
                    const SizedBox(height: 6),
                    IconButton(
                      onPressed:
                          enabled ? () => _playFrom(0, shuffle: true) : null,
                      tooltip: l.shuffle,
                      icon: const Icon(Icons.shuffle),
                      color: VelvetColors.textSecondary,
                      style: IconButton.styleFrom(
                        shape: CircleBorder(
                            side: BorderSide(color: VelvetColors.border)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _trackList(List<DisplayItem> songs) {
    return StreamBuilder<({String? path, bool playing})>(
      stream: _nowStream,
      initialData: (path: null, playing: false),
      builder: (context, snap) {
        final now = snap.data ?? (path: null, playing: false);
        return ListView.builder(
          padding: const EdgeInsets.only(top: 4, bottom: 12),
          itemCount: songs.length,
          itemBuilder: (context, i) {
            final s = songs[i];
            return _SongRow(
              number: i + 1,
              title: s.metadata?.title ?? (s.data ?? '').split('/').last,
              active: now.path != null && now.path == s.data,
              playing: now.playing,
              duration: s.metadata?.duration,
              onTap: () => _onRowTap(i),
              onAddNext: () => _rowAddNext(i),
              onPlayNow: () => _rowPlayNow(i),
              onAddToEnd: () => _rowAddToEnd(i),
            );
          },
        );
      },
    );
  }
}

/// One track row: number (or active EQ/play indicator), title, duration (when
/// reported), and a play-options menu (Add next / Play now, plus Add to end of
/// queue when the row tap is in play-from-here mode). The row tap itself follows
/// the shared TapBehavior setting.
class _SongRow extends StatelessWidget {
  final int number;
  final String title;
  final bool active;
  final bool playing;
  final Duration? duration;
  final VoidCallback onTap;
  final VoidCallback onAddNext;
  final VoidCallback onPlayNow;
  final VoidCallback onAddToEnd;

  const _SongRow({
    required this.number,
    required this.title,
    required this.active,
    required this.playing,
    required this.onTap,
    required this.onAddNext,
    required this.onPlayNow,
    required this.onAddToEnd,
    this.duration,
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
                          number.toString().padLeft(2, '0'),
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
              if (duration != null) ...[
                const SizedBox(width: 10),
                Text(
                  formatDuration(duration!, padMinutes: false),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12,
                    color: VelvetColors.textTertiary,
                  ),
                ),
              ],
              const SizedBox(width: 4),
              // Play-options menu: Add next / Play now (+ Add to end of queue
              // when the row tap is play-from-here, so every queue action stays
              // reachable).
              PopupMenuButton<String>(
                icon: Icon(Icons.play_arrow_rounded,
                    color: VelvetColors.textSecondary),
                iconSize: 24,
                color: VelvetColors.surface,
                tooltip: l.play,
                padding: EdgeInsets.zero,
                constraints:
                    const BoxConstraints(minWidth: 40, minHeight: 40),
                onSelected: (v) {
                  switch (v) {
                    case 'next':
                      onAddNext();
                      break;
                    case 'now':
                      onPlayNow();
                      break;
                    case 'end':
                      onAddToEnd();
                      break;
                  }
                },
                itemBuilder: (context) => [
                  PopupMenuItem(value: 'next', child: Text(l.queueAddNext)),
                  PopupMenuItem(value: 'now', child: Text(l.queuePlayNow)),
                  if (SettingsManager().tapBehavior ==
                      TapBehavior.playFromHere)
                    PopupMenuItem(
                        value: 'end', child: Text(l.queueAddToEnd)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
