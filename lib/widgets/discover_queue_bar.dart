import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:material_ui/material_ui.dart';

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
import 'track_actions_sheet.dart';

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

class _DiscoverQueueBarState extends State<DiscoverQueueBar>
    with SingleTickerProviderStateMixin {
  static const int _limit = 6;

  /// Header height. The panel never goes below this — it is the collapsed bar.
  static const double _headerHeight = 44;

  StreamSubscription<MediaItem?>? _sub;
  Timer? _debounce;
  int _reqId = 0;

  // 0.0 = collapsed strip, 1.0 = open panel. A continuous value rather than
  // a bool, which is the whole difference between "commits on release" and
  // "follows the finger" — the same thing PlayerPanelState does one layer up.
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  /// Travel available to a drag, in logical px: set from layout each build,
  /// so the finger moves the panel 1:1 whatever height the panel resolved to.
  double _dragExtent = 1.0;

  bool get _expanded => _ctrl.value > 0.5;
  bool _dirty = true; // seed changed while collapsed → refetch on expand
  bool _loading = false;
  // 403 → the ping flag said yes and the route said no. Latched so an
  // automatic refetch (track change) doesn't re-ask a server that just
  // refused; only the explicit re-check below clears it.
  bool _disabled = false;
  bool _rechecking = false;
  bool _probed = false;


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
    _ctrl.dispose();
    super.dispose();
  }

  void _expand() {
    _ctrl.animateTo(1.0, curve: Curves.easeOutCubic);
    if (_dirty || _tracks == null) _refresh();
  }

  void _collapse() => _ctrl.animateTo(0.0, curve: Curves.easeOutCubic);

  void _toggle() => _expanded ? _collapse() : _expand();

  /// Track the finger. Dividing by [_dragExtent] is what makes the panel move
  /// exactly as far as the thumb does rather than at some invented rate.
  void _onDragUpdate(DragUpdateDetails d) {
    if (_dragExtent <= 0) return;
    _ctrl.value =
        (_ctrl.value - (d.primaryDelta ?? 0) / _dragExtent).clamp(0.0, 1.0);
  }

  /// The player panel's rule, and worth stating why it is not just "past
  /// half wins": a fast flick is a decision even when it covered no distance,
  /// and without the velocity arm a quick flick from rest would spring back
  /// and feel broken. Distance only decides when the release was slow enough
  /// to be a placement rather than a throw.
  void _onDragEnd(DragEndDetails d) {
    final v = d.primaryVelocity ?? 0; // px/s, negative = upward
    if (v < -300) {
      _expand();
    } else if (v > 300) {
      _collapse();
    } else if (_ctrl.value > 0.5) {
      _expand();
    } else {
      _collapse();
    }
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

    _dragExtent = (panelHeight - _headerHeight).clamp(1.0, double.infinity);

    // The body is built ONCE and handed to the builder as `child`: a drag
    // then re-runs only the height wrapper, not the track list, the art or
    // the row builders. AnimatedSize used to relayout the whole subtree on
    // every animation tick, which is the expensive half of what made the old
    // open feel heavier than the player panel's.
    return AnimatedBuilder(
      animation: _ctrl,
      child: _body(l),
      builder: (context, body) => Container(
        // +1: Container folds the decoration's border widths into padding,
        // so the top hairline insets the content box by a pixel — without
        // accounting for it the fixed-height header overflows by exactly
        // 1.00px while collapsed.
        height: 1 + _headerHeight + _ctrl.value * _dragExtent,
        decoration: BoxDecoration(
          // Tinted rather than the queue's own surface: this strip sat in
          // exactly the same colour as the list above it and read as part of
          // the queue, so nobody found it. Low alpha so it stays a wash over
          // whichever theme is active instead of a slab of colour.
          color: _discoverLight.withValues(alpha: 0.14),
          border: Border(top: BorderSide(color: _discoverAccent)),
        ),
        child: ClipRect(
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
            // The header's press feedback lands on RELEASE, not on touch: the
            // drag recognizer here competes with the InkWell's tap in the
            // gesture arena, and Flutter holds the tap's highlight until the
            // arena resolves. Measured, not assumed — a held press on the
            // header changes no pixels, while a queue row (no competing drag)
            // highlights immediately. The rows inside this panel have no drag
            // over them and behave normally.
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onVerticalDragUpdate: _onDragUpdate,
              onVerticalDragEnd: _onDragEnd,
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
              onTap: _toggle,
              splashColor: _discoverLight.withValues(alpha: 0.18),
              highlightColor: _discoverLight.withValues(alpha: 0.08),
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
            ),
            // OverflowBox so the body always lays out at its FULL height and
            // is clipped to whatever the panel currently shows. Without it a
            // half-open panel would try to lay the content out in half the
            // space — reflowing text and rows on every frame of the drag, and
            // overflowing the ones that cannot shrink.
            //
            // Gated on the live controller value, not on `_expanded`: this
            // runs inside the builder, so a fully-closed panel keeps the
            // rows (and their album art) out of the tree entirely, while the
            // first pixel of a drag brings them in. Reading a bool here
            // instead would leave the list mounted-but-clipped whenever the
            // panel had ever been open.
            if (_ctrl.value > 0)
              Expanded(
                child: OverflowBox(
                  alignment: Alignment.topCenter,
                  minHeight: 0,
                  maxHeight: panelHeight - _headerHeight,
                  child: body,
                ),
              ),
          ],
        ),
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
        // Material(transparency) + InkWell rather than ListTile's own
        // onTap. The panel paints its tint with a Container decoration, and a
        // Container's background sits ABOVE the Material that would draw the
        // splash — so ListTile's ripple was being applied to a surface nobody
        // could see. A transparent Material inside the Container gives the ink
        // somewhere to land. Same shape the browser's file rows use.
        //
        // Splash in the panel's own periwinkle, not the user's accent: the
        // Discover surface deliberately keeps one colour across both clients
        // (see _discoverAccent), and a press that flashed amber here would
        // break that on exactly the interaction that draws the eye.
        return Material(
          type: MaterialType.transparency,
          child: InkWell(
            splashColor: _discoverLight.withValues(alpha: 0.20),
            highlightColor: _discoverLight.withValues(alpha: 0.10),
            onTap: () => _queueRow(i),
            // Same sheet as everywhere else. Guarded on the row existing: the
            // DisplayItem list is rebuilt alongside the results and a
            // long-press landing between the two would otherwise open a sheet
            // on nothing.
            onLongPress:
                row == null ? null : () => showTrackActionsSheet(context, row),
            child: ListTile(
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
            ),
          ),
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
