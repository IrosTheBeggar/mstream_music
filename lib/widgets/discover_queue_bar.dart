import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../objects/discovery.dart';
import '../objects/display_item.dart';
import '../objects/server.dart';
import '../screens/discover_screen.dart';
import '../singletons/api.dart';
import '../singletons/media.dart';
import '../singletons/server_list.dart';
import '../theme/velvet_theme.dart';
import '../util/queue_actions.dart';

/// Collapsible Discover bar docked under the queue in the expanded player —
/// the mobile counterpart of the webapp's Discover panel in the Now Playing
/// column. Collapsed it's a slim labeled bar; tapping slides up a compact
/// "similar tracks" panel (the playable core) with Queue all and a button
/// to the full Discover screen.
///
/// Webapp-parity laziness: NO requests while collapsed — a track change
/// only marks the panel dirty, and the fetch happens on expand. It also
/// always STARTS collapsed: the expanded player sheet is pre-built at app
/// startup, so a persisted open state would fetch invisibly behind a
/// closed player.
///
/// Hidden entirely (never probed) unless the playing track's server
/// advertised `discovery` on ping; a 403 mid-session hides it until the
/// next app launch.
class DiscoverQueueBar extends StatefulWidget {
  const DiscoverQueueBar({super.key});

  @override
  State<DiscoverQueueBar> createState() => _DiscoverQueueBarState();
}

class _DiscoverQueueBarState extends State<DiscoverQueueBar> {
  static const int _limit = 6;

  StreamSubscription<MediaItem?>? _sub;
  Timer? _debounce;
  int _reqId = 0;

  bool _expanded = false;
  bool _dirty = true; // seed changed while collapsed → refetch on expand
  bool _loading = false;
  bool _disabled = false; // 403 → hide for the session (flag was stale)

  Server? _seedServer;
  String? _seedPath;
  DiscoverySimilarTracks? _tracks;
  List<DisplayItem> _rows = const [];

  @override
  void initState() {
    super.initState();
    _sub = MediaManager().audioHandler.mediaItem.listen((item) {
      final extras = item?.extras;
      if (extras?['path'] == _seedPath &&
          extras?['server'] == _seedServer?.localname) {
        return;
      }
      if (!_expanded) {
        // Collapsed = lazy: remember we're stale, rebuild only for the
        // bar's visibility (the new track may be on a non-discovery
        // server), and fetch nothing.
        _dirty = true;
        if (mounted) setState(() {});
        return;
      }
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 500), () {
        if (mounted) _refresh();
      });
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _sub?.cancel();
    super.dispose();
  }

  void _toggle() {
    setState(() => _expanded = !_expanded);
    if (_expanded && (_dirty || _tracks == null)) _refresh();
  }

  void _refresh() {
    final item = MediaManager().audioHandler.mediaItem.value;
    final extras = item?.extras;
    final path = extras?['path'] as String?;
    final server = ServerManager().byLocalname(extras?['server'] as String?);
    _seedServer = server;
    _seedPath = path;
    if (server == null || path == null || server.discoveryAvailable != true) {
      setState(() {
        _tracks = null;
        _rows = const [];
      });
      return;
    }
    final rid = ++_reqId;
    setState(() {
      _loading = true;
      _dirty = false;
    });
    ApiManager()
        .fetchDiscoverySimilarTracks(server, path, limit: _limit)
        .then((r) {
      if (!mounted || rid != _reqId) return;
      setState(() {
        _loading = false;
        if (r.disabled) {
          _disabled = true;
        } else if (r.data != null) {
          _tracks = r.data;
          _rows = r.data!.results.map((t) {
            final row = DisplayItem(server, t.filepath, 'file',
                '/${t.filepath}', null, null);
            row.metadata = t.metadata;
            return row;
          }).toList();
        }
        // Transient error: keep whatever rows are shown (webapp rule).
      });
    });
  }

  // In the queue panel a tap always APPENDS (the webapp's queue-a-discover-
  // track behavior) — respecting a play-from-here tap setting inside the
  // queue would wipe the queue the user is looking at.
  Future<void> _queueRow(int index) async {
    if (index >= _rows.length) return;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final n = await addRowsToQueue([_rows[index]]);
    if (n > 0 && mounted) {
      messenger.showSnackBar(SnackBar(
        content: Text(l.browserSongsAdded(1)),
        behavior: SnackBarBehavior.floating,
      ));
    }
  }

  Future<void> _queueAll() async {
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
    final item = MediaManager().audioHandler.mediaItem.valueOrNull;
    final extras = item?.extras;
    final path = extras?['path'] as String?;
    final server = ServerManager().byLocalname(extras?['server'] as String?);
    final visible =
        !_disabled && path != null && server?.discoveryAvailable == true;
    if (!visible) return const SizedBox.shrink();

    // Compact panel height: enough for the header + a few rows without
    // squeezing the queue out on small screens.
    final panelHeight =
        (MediaQuery.of(context).size.height * 0.34).clamp(200.0, 320.0);

    return AnimatedSize(
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: Container(
        // +1: Container folds the decoration's border widths into padding,
        // so the top hairline insets the content box by a pixel — without
        // accounting for it the fixed-height header overflows by exactly
        // 1.00px while collapsed.
        height: 1 + (_expanded ? panelHeight : 44),
        decoration: BoxDecoration(
          color: VelvetColors.surface,
          border: Border(top: BorderSide(color: VelvetColors.border)),
        ),
        child: Column(
          children: [
            // Header — the whole strip toggles, like the webapp's panel
            // header. Extra actions appear only while expanded.
            InkWell(
              onTap: _toggle,
              child: SizedBox(
                height: 44,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(Icons.explore,
                          size: 18, color: VelvetColors.primary),
                      const SizedBox(width: 8),
                      Text(
                        l.discoverTitle.toUpperCase(),
                        style: TextStyle(
                          color: VelvetColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 1.1,
                        ),
                      ),
                      const Spacer(),
                      if (_expanded && _rows.isNotEmpty)
                        TextButton(
                          onPressed: _queueAll,
                          child: Text(
                            l.discoverQueueAll,
                            style: TextStyle(
                                color: VelvetColors.primary, fontSize: 12),
                          ),
                        ),
                      if (_expanded)
                        IconButton(
                          icon: Icon(Icons.open_in_full,
                              size: 16, color: VelvetColors.textSecondary),
                          tooltip: l.discoverTitle,
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                              minWidth: 32, minHeight: 32),
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) => const DiscoverScreen()),
                          ),
                        ),
                      Icon(
                        _expanded
                            ? Icons.keyboard_arrow_down
                            : Icons.keyboard_arrow_up,
                        size: 20,
                        color: VelvetColors.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (_expanded) Expanded(child: _body(l)),
          ],
        ),
      ),
    );
  }

  Widget _body(AppLocalizations l) {
    final result = _tracks;
    if (_loading && result == null) {
      return Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: VelvetColors.primary,
          ),
        ),
      );
    }
    if (result == null || (!result.notAnalyzed && result.results.isEmpty)) {
      return _hint(l.discoverNothingFound);
    }
    if (result.notAnalyzed) {
      return _hint(l.discoverNotAnalyzed);
    }
    return ListView.builder(
      padding: EdgeInsets.zero,
      itemCount: result.results.length,
      itemBuilder: (context, i) {
        final track = result.results[i];
        final row = i < _rows.length ? _rows[i] : null;
        final artist = track.metadata?.artist;
        final genre = genreTagLabel(track.genreTags);
        final subtitle = [
          if (artist != null && artist.trim().isNotEmpty) artist.trim(),
          ?genre,
        ].join(' · ');
        return ListTile(
          dense: true,
          visualDensity: VisualDensity.compact,
          leading: row?.getAlbumThumb(size: 36),
          title: Text(
            track.displayTitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14, color: VelvetColors.textPrimary),
          ),
          subtitle: subtitle.isEmpty
              ? null
              : Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12, color: VelvetColors.textSecondary),
                ),
          trailing: MatchMeter(similarity: track.similarity),
          onTap: () => _queueRow(i),
        );
      },
    );
  }

  Widget _hint(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        child: Align(
          alignment: Alignment.topLeft,
          child: Text(
            text,
            style: TextStyle(color: VelvetColors.textSecondary, fontSize: 12),
          ),
        ),
      );
}
