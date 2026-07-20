import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../objects/discovery.dart';
import '../objects/display_item.dart';
import '../objects/server.dart';
import '../singletons/api.dart';
import '../theme/velvet_theme.dart';
import '../util/queue_actions.dart';
import 'discover_screen.dart' show MatchMeter;

/// Sonic path — the ordered "journey" between two tracks
/// (POST /api/v1/discovery/local/path, mStream #762+): waypoints along the
/// arc between the seeds' embeddings, snapped to real library tracks. A
/// preview-first screen: the user sees the whole arc (start card → rows →
/// end card) before committing, then Play (replaces the queue) or Queue all
/// (appends). Fetched once on open — the seeds are pinned, so there's
/// nothing to follow.
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

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _failed = false;
    });
    final r = await ApiManager()
        .fetchDiscoveryPath(widget.server, widget.startPath, widget.endPath);
    if (!mounted) return;
    setState(() {
      _loading = false;
      // 403 = the ping flag was stale; both fold into the retryable state.
      if (r.data == null) {
        _failed = true;
        return;
      }
      _path = r.data;
      _rows = r.data!.results.map((t) {
        final row = DisplayItem(widget.server, t.filepath, 'file',
            '/${t.filepath}', null, null);
        row.metadata = t.metadata;
        return row;
      }).toList();
    });
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

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final subtitle = [
      (widget.startTitle ?? '').trim(),
      (widget.endTitle ?? '').trim(),
    ].where((s) => s.isNotEmpty).join('  →  ');
    final path = _path;
    final hasRows = path != null && path.results.isNotEmpty;

    return Scaffold(
      backgroundColor: VelvetColors.bg,
      appBar: AppBar(
        backgroundColor: VelvetColors.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        foregroundColor: VelvetColors.textPrimary,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l.pathScreenTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: VelvetColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (subtitle.isNotEmpty)
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    color: VelvetColors.textSecondary, fontSize: 12),
              ),
          ],
        ),
      ),
      body: _body(l),
      // Play / Queue all — pinned so the arc scrolls under them.
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
                  ],
                ),
              ),
            )
          : null,
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
