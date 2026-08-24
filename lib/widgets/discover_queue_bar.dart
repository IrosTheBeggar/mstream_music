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
/// advertised `discovery` on ping. A 403 does NOT hide it: the bar is lazy,
/// so a 403 can only arrive in response to the tap that opened the panel,
/// and vanishing under that tap read as a glitch. It stays and says what
/// happened instead — see [_scanPendingBody].
/// Discover's own accent, matching the webapp's panel (webapp/alpha/spa.css,
/// `.discover-icon` / `.discover-panel`): periwinkle #657ee4 with #8ea0f0 as
/// its light end. Deliberately NOT the user's accent — Discover is one
/// feature with a colour of its own in both clients, and tying it to a custom
/// accent would make it a different colour in every install.
const Color _discoverAccent = Color(0xFF657EE4);
const Color _discoverLight = Color(0xFF8EA0F0);

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
  // 403 → the ping flag said yes and the route said no. Latched so an
  // automatic refetch (track change) doesn't re-ask a server that just
  // refused; only the explicit re-check below clears it.
  bool _disabled = false;
  bool _rechecking = false;
  bool _probed = false;

  // Distance travelled by the current header drag, so a slow drag that never
  // reaches a fling velocity still resolves by direction.
  double _dragDy = 0;

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

  void _setExpanded(bool open) {
    if (open == _expanded) return;
    _toggle();
  }

  /// Same reading the player panel gives a release: a flick past ±300 px/s
  /// wins outright, otherwise the drag has to have travelled far enough to
  /// count — 24px, so a wobble on a tap does not flip the panel.
  void _onHeaderDragEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0; // negative = upward
    if (v < -300) {
      _setExpanded(true);
    } else if (v > 300) {
      _setExpanded(false);
    } else if (_dragDy < -24) {
      _setExpanded(true);
    } else if (_dragDy > 24) {
      _setExpanded(false);
    }
    _dragDy = 0;
  }

  /// Same re-check as the Discover panel: re-ping FIRST, then retry.
  ///
  /// The 403 is ambiguous — requireIndex() answers the same status for
  /// "discovery is off" and "it is on but there is no index yet" — and the
  /// two live in different places: the ping carries the config flag, the
  /// route carries the data. If the flag has gone, `visible` goes false and
  /// the bar hides itself, which is the right answer to "check again" when
  /// the feature really was switched off.
  Future<void> _recheck() async {
    final server = _seedServer;
    if (server == null || _rechecking) return;
    setState(() => _rechecking = true);
    await ServerManager().getServerPaths(server);
    if (!mounted) return;
    setState(() {
      _rechecking = false;
      _disabled = false;
    });
    _refresh();
  }

  void _refresh() {
    final item = MediaManager().audioHandler.mediaItem.value;
    final extras = item?.extras;
    final path = extras?['path'] as String?;
    final server = ServerManager().byLocalname(extras?['server'] as String?);
    _seedServer = server;
    _seedPath = path;
    if (server == null ||
        path == null ||
        server.discoveryAvailable != true ||
        _disabled) {
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
          // Decide WHY before the panel says why — a 403 nearly always means
          // the feature was switched off since our last ping, not that the
          // scan is pending (discovery.db exists whenever the flag is on, so
          // an unscanned library answers 200 + notAnalyzed instead). If the
          // re-ping clears the flag, `visible` goes false and the bar stands
          // down; if it survives, the scan-pending body is correct. Same
          // reasoning as _probeAfterRefusal in screens/discover_screen.dart.
          if (!_probed) {
            _probed = true;
            unawaited(ServerManager().getServerPaths(server).then((_) {
              if (mounted) setState(() {});
            }));
          }
        } else if (r.data != null) {
          _tracks = r.data;
          _rows = r.data!.results.map((t) {
            final row = DisplayItem(server, t.filepath, 'file',
                '/${t.filepath}', null, null);
            // Lite metadata (server-side toLiteMetadata), so flag it partial and
            // let the queue path fetch the full block — see _rowsFor in
            // screens/discover_screen.dart for why.
            row.metadata = t.metadata;
            row.partialMetadata = true;
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
    // `_disabled` deliberately absent: a refused route is something to
    // report in the panel, not a reason to remove the panel.
    final visible = path != null && server?.discoveryAvailable == true;
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
          // Tinted rather than the queue's own surface: this strip sat in
          // exactly the same colour as the list above it and read as part of
          // the queue, so nobody found it. Low alpha so it stays a wash over
          // whichever theme is active instead of a slab of colour.
          color: _discoverLight.withValues(alpha: 0.14),
          border: Border(top: BorderSide(color: _discoverAccent)),
        ),
        child: Column(
          children: [
            // Header — the whole strip toggles, like the webapp's panel
            // header. Extra actions appear only while expanded.
            //
            // Also drags, the way the player panel above it does: a flick
            // decides by velocity, a slow drag by how far it went. Only the
            // HEADER takes the gesture — putting it on the whole bar would
            // fight the track list inside for vertical drags, which is the
            // same reason the player panel hangs its drag off the grab area
            // rather than the sheet.
            //
            // This is two states with an AnimatedSize between them, not a
            // controller the finger drives, so the panel does not track the
            // finger mid-drag; it commits on release. Worth knowing before
            // anyone tries to make it rubber-band.
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragStart: (_) => _dragDy = 0,
              onVerticalDragUpdate: (d) => _dragDy += d.primaryDelta ?? 0,
              onVerticalDragEnd: _onHeaderDragEnd,
              child: InkWell(
              onTap: _toggle,
              child: SizedBox(
                height: 44,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(Icons.explore, size: 18, color: _discoverLight),
                      const SizedBox(width: 8),
                      Text(
                        l.discoverTitle.toUpperCase(),
                        style: TextStyle(
                          // Matches the explore icon beside it; the muted grey
                          // it replaces was the other half of why the strip
                          // disappeared into the queue.
                          color: _discoverLight,
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
            ),
            if (_expanded) Expanded(child: _body(l)),
          ],
        ),
      ),
    );
  }

  /// The ping advertised discovery and the route answered 403: switched on,
  /// nothing analyzed. Same state the Discover panel names, in the compact
  /// shape — one line and the re-check, no title (the bar's own header
  /// already says DISCOVER).
  Widget _scanPendingBody(AppLocalizations l) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l.discoverScanPendingBody,
              style:
                  TextStyle(color: VelvetColors.textSecondary, fontSize: 12),
            ),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: _rechecking ? null : _recheck,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: const Size(0, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: _rechecking
                  ? SizedBox(
                      width: 13,
                      height: 13,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: _discoverLight),
                    )
                  : Icon(Icons.refresh, size: 15, color: _discoverLight),
              label: Text(
                l.discoverCheckAgain,
                style: TextStyle(color: _discoverLight, fontSize: 12),
              ),
            ),
          ],
        ),
      );

  Widget _body(AppLocalizations l) {
    final result = _tracks;
    if (_disabled) return _scanPendingBody(l);
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
