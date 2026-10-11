import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../objects/discovery.dart';
import '../objects/display_item.dart';
import '../objects/server.dart';
import '../singletons/media.dart';
import '../theme/velvet_theme.dart';
import '../util/queue_actions.dart';
import '../widgets/song_picker_sheet.dart';
import 'discovery/discovery_page_controller.dart';
import 'discovery/discovery_seeds_sheet.dart';
import 'discovery/discovery_source_list.dart';
import 'discovery/discovery_widgets.dart';

/// Rows of each source the page itself shows; "See all" shows the rest.
const int kDiscoveryPageAlbums = 3;
const int kDiscoveryPageTracks = 4;
const int kDiscoveryPageLeads = 3;
const int kDiscoveryPagePeerRows = 3;

/// The Discover page for one server (Discover page plan §1, §4.2; the
/// Phone / PhoneStates canvas boards): recommendations seeded by this
/// account's play history there — songs and albums from the library, leads
/// from the P2P network, songs on federated peers. Opened from the home's
/// Discover card under Listen, which only exists when the server advertised
/// `discovery` and `discoveryTaste` (flags, never probes).
///
/// Everything it shows comes from [DiscoveryPageController]; the rows and
/// cards live in discovery/discovery_widgets.dart, the seeds sheet and the
/// "See all" lists in their own files.
///
/// Configuration lives in the pinned gray bar under the app bar, never in
/// the scrolling body: "Based on the last [30 days ▾]" and "More options",
/// which opens the seeds sheet. The window lives in the bar only — the
/// app-bar subtitle says what the page is seeded from, not over when. The seeds themselves stay behind that link —
/// a strip of seed chips at the top of the body read as songs to play, and
/// a first-time listener tapped them expecting music.
class DiscoveryPage extends StatefulWidget {
  final Server server;

  /// Injected by tests; the page builds (and disposes) its own otherwise.
  final DiscoveryPageController? controller;
  const DiscoveryPage({super.key, required this.server, this.controller});

  @override
  State<DiscoveryPage> createState() => _DiscoveryPageState();
}

/// The now-playing song, when it is on [server] — pinned once at open
/// (plan §2.3). Null before the audio service is up (widget tests, a cold
/// start), for a song on another server (a federated peer's included: its
/// tracks are a different Server), and for a local file.
String? discoveryNowPlayingPin(Server server) {
  try {
    final extras = MediaManager().audioHandler.mediaItem.value?.extras;
    if (extras?['server'] != server.localname) return null;
    final path = extras?['path'];
    return path is String && path.isNotEmpty ? path : null;
  } catch (_) {
    // audioHandler is `late` and unset until MediaManager().start().
    return null;
  }
}

class _DiscoveryPageState extends State<DiscoveryPage> {
  late final DiscoveryPageController c;
  late final bool _owns;
  bool _picking = false;

  @override
  void initState() {
    super.initState();
    _owns = widget.controller == null;
    c = widget.controller ??
        DiscoveryPageController(
          server: widget.server,
          pinAtOpen: discoveryNowPlayingPin(widget.server),
        );
    unawaited(c.load());
  }

  @override
  void dispose() {
    if (_owns) c.dispose();
    super.dispose();
  }

  Future<void> _editSeeds() async {
    final l = AppLocalizations.of(context);
    final pending = await showModalBottomSheet<Future<bool>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: VelvetColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DiscoverySeedsSheet(controller: c),
    );
    // "Use these N" pops with the apply in flight; a dismissed sheet, null.
    if (pending == null) return;
    final restored = await pending;
    if (!restored && mounted) {
      discoveryToast(context, l.discoverPageRestoreFailed);
    }
  }

  void _seeAll(TasteSource source) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => DiscoverySourceList(controller: c, source: source),
    ));
  }

  Future<void> _anotherPick() async {
    if (_picking) return;
    setState(() => _picking = true);
    final l = AppLocalizations.of(context);
    final ok = await c.anotherPick();
    if (!mounted) return;
    setState(() => _picking = false);
    if (!ok) discoveryToast(context, l.discoverPageRandomFailed);
  }

  Future<void> _chooseSong() async {
    final l = AppLocalizations.of(context);
    final picked = await showModalBottomSheet<DisplayItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: VelvetColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) =>
          SongPickerSheet(server: widget.server, title: l.discoverPageChooseSong),
    );
    final path = picked?.data;
    if (path == null || !mounted) return;
    await c.pinSong(path);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        final subtitle = c.available ? discoverySubtitle(l, c.seeded) : null;
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
                  l.discoverPageTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: VelvetColors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: VelvetColors.textSecondary, fontSize: 12),
                  ),
              ],
            ),
            actions: [
              IconButton(
                icon: Icon(Icons.refresh, color: VelvetColors.textPrimary),
                tooltip: l.discoverPageRefresh,
                onPressed: c.available && !c.loading ? c.refresh : null,
              ),
            ],
          ),
          body: SafeArea(
            top: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (c.available) _configBar(l),
                Expanded(
                  child: RefreshIndicator(
                    color: VelvetColors.primary,
                    onRefresh: c.refresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 24),
                      children: _body(l),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _body(AppLocalizations l) {
    // Only reachable after a re-ping flipped a flag: the card that opens
    // the page is gated on both, so this is "switched off while you were
    // looking", not a cold state.
    if (!c.available) return [DiscoveryHint(l.discoverTurnedOff)];

    final seeded = c.seeded;
    final out = <Widget>[];
    if (seeded == null) {
      if (c.scanPending) {
        return [
          DiscoveryScanPendingCard(
              rechecking: c.rechecking, onRecheck: c.recheck),
        ];
      }
      // Spin only while something is actually in flight: any other way to
      // reach here with no answer (a failed call, a stale guard) gets the
      // retry card, never a spinner nothing will stop.
      if (!c.loading) return [_errorCard(l)];
      return [
        const SizedBox(height: 120),
        Center(
          child: CircularProgressIndicator(color: VelvetColors.primary),
        ),
      ];
    }

    if (c.loading) {
      out.add(LinearProgressIndicator(
        minHeight: 2,
        color: VelvetColors.primary,
        backgroundColor: Colors.transparent,
      ));
    }
    if (c.scanPending) {
      out.add(DiscoveryScanPendingCard(
          rechecking: c.rechecking, onRecheck: c.recheck));
    }
    if (c.error) out.add(DiscoveryHint(l.discoverPageError));
    // The bar names the window asked for; when the server had to reach
    // further back for seeds, say so where the rows are.
    final widened = discoveryWidenedNote(l, seeded);
    if (widened != null) out.add(DiscoveryHint(widened));
    if (c.isRandom) {
      out.add(DiscoveryRandomCard(
        busy: _picking || c.loading,
        onAnotherPick: _anotherPick,
        onChooseSong: _chooseSong,
      ));
    }
    if (c.library != null) {
      // Straight under the bar (nothing but the progress line above it):
      // the tighter top gap of a first section.
      final first = out.every((w) => w is LinearProgressIndicator);
      out.addAll(_librarySection(l, c.library!, first: first));
    }
    if (c.network != null) out.addAll(_networkSection(l, c.network!));
    out.addAll(_peersSection(l));
    return out;
  }

  Widget _errorCard(AppLocalizations l) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 32, 16, 0),
      child: Column(
        children: [
          Text(
            l.discoverPageError,
            textAlign: TextAlign.center,
            style: TextStyle(color: VelvetColors.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 12),
          DiscoveryPill(l.discoverPageRetry,
              icon: Icons.refresh, primary: true, onTap: c.refresh),
        ],
      ),
    );
  }

  // ── configuration bar ──────────────────────────────────────────────

  /// The pinned configuration bar: the window ("Based on the last
  /// [30 days ▾]", the window's one home) and "More options" for the seeds
  /// sheet. One Wrap, so a narrow screen or a large text setting moves
  /// "More options" to a second line instead of overflowing.
  ///
  /// Each control is off — and dimmed, since their text carries its own
  /// colour — while it could not do anything useful: during a call (a
  /// change would only race the answer it is about to replace, as the
  /// refresh action), under the 403 latch (nothing would be asked; the
  /// scan-pending card's "Check again" is the way out), and for "More
  /// options" before any answer (there are no seeds to show yet).
  Widget _configBar(AppLocalizations l) {
    final idle = !c.loading && !c.disabled;
    final canSeeds = idle && c.seeded != null;
    final current = c.effectiveWindow;
    // Plain text colours, not the link colour: on the bar's `raised` the
    // primary is unreadable in Light (amber on light gray) and the
    // secondary text too faint in Velvet.
    final ink = VelvetColors.textPrimary;
    return Container(
      key: const ValueKey('discovery-config-bar'),
      decoration: BoxDecoration(
        color: VelvetColors.raised,
        border: Border(bottom: BorderSide(color: VelvetColors.border)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 0, 4, 0),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Text(
                // "Based on the last All time" reads wrong.
                current <= 0
                    ? l.discoverPageBasedOnAllTime
                    : l.discoverPageBasedOnLast,
                style: TextStyle(color: ink, fontSize: 13),
              ),
              Opacity(
                opacity: idle ? 1 : 0.5,
                child: PopupMenuButton<int>(
                  key: const ValueKey('discovery-window'),
                  enabled: idle,
                  tooltip: '',
                  initialValue: current,
                  color: VelvetColors.surface,
                  onSelected: (w) => unawaited(c.setWindow(w)),
                  itemBuilder: (_) => [
                    for (final w in kTasteWindows)
                      CheckedPopupMenuItem<int>(
                        value: w,
                        checked: w == current,
                        child: Text(
                          discoveryWindowLabel(l, w),
                          style: TextStyle(
                              color: VelvetColors.textPrimary, fontSize: 14),
                        ),
                      ),
                  ],
                  child: _WindowPill(discoveryWindowLabel(l, current)),
                ),
              ),
            ],
          ),
          Opacity(
            opacity: canSeeds ? 1 : 0.5,
            // Standard density: the padded 48 px target.
            child: TextButton(
              key: const ValueKey('discovery-more-options'),
              onPressed: canSeeds ? _editSeeds : null,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: Text(
                l.discoverPageMoreOptions,
                style: TextStyle(
                  color: ink,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                  decorationColor: VelvetColors.textSecondary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── library ────────────────────────────────────────────────────────────

  List<Widget> _librarySection(AppLocalizations l, TasteLibrary lib,
      {bool first = false}) {
    final count = lib.tracks.length + lib.albums.length;
    // The filter the rows ARE (the answer's), not one still in flight or
    // one whose refetch failed.
    final shown = lib.filter ?? c.effectiveFilter;
    final out = <Widget>[
      DiscoverySectionHeader(
        l.discoverPageFromLibrary,
        meta: '$count · ${DiscoverySourceList.filterLabel(l, shown)}',
        onSeeAll: () => _seeAll(TasteSource.library),
        first: first,
      ),
    ];
    if (lib.albums.isEmpty && lib.tracks.isEmpty) {
      out.add(DiscoveryHint(discoveryScanWaiting(c)
          ? l.discoverPageScanWaiting
          : l.discoverPageLibraryEmpty));
      return out;
    }
    if (lib.albums.isNotEmpty) {
      final albums = lib.albums.take(kDiscoveryPageAlbums).toList();
      // A scrolling Row rather than a horizontal ListView: the cards size
      // the strip, so a large text setting grows it instead of overflowing
      // a fixed height.
      out.add(SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < albums.length; i++) ...[
              if (i > 0) const SizedBox(width: 12),
              DiscoveryAlbumCard(
                item: c.albumItems[i],
                album: albums[i],
                onTap: () => discoveryOpenAlbum(context, c.albumItems[i]),
              ),
            ],
          ],
        ),
      ));
    }
    final rows = c.libraryRows;
    final n = lib.tracks.length < kDiscoveryPageTracks
        ? lib.tracks.length
        : kDiscoveryPageTracks;
    for (var i = 0; i < n && i < rows.length; i++) {
      out.add(DiscoveryTrackRow(
        row: rows[i],
        track: lib.tracks[i],
        now: c.now(),
        onTap: () => discoveryTapTrack(context, rows, i),
        onNext: () => discoveryQueueNext(context, rows[i]),
        onQueue: () => discoveryQueueEnd(context, rows[i]),
        onMore: () => discoveryTrackActions(context, rows[i]),
      ));
    }
    if (rows.isNotEmpty) {
      out.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
        child: Wrap(
          spacing: 8,
          // The pills' 44 px hit areas already space the rows.
          runSpacing: 0,
          children: [
            DiscoveryPill(l.discoverPagePlayAll(rows.length),
                icon: Icons.play_arrow,
                primary: true,
                onTap: () => playFromHere(rows, 0)),
            DiscoveryPill(l.shuffle,
                icon: Icons.shuffle,
                onTap: () => playFromHere(rows, 0, shuffle: true)),
            DiscoveryPill(l.discoverPageAddToQueue,
                icon: Icons.playlist_add,
                onTap: () => discoveryQueueAll(context, rows)),
          ],
        ),
      ));
    }
    return out;
  }

  // ── network ────────────────────────────────────────────────────────────

  List<Widget> _networkSection(AppLocalizations l, TasteLeads net) {
    final waiting = discoveryScanWaiting(c);
    final out = <Widget>[
      DiscoverySectionHeader(
        l.discoverFromNetwork,
        // While no seed is analyzed the server searched nothing on purpose.
        meta: waiting ? null : l.discoverPageServersSearched(net.searchedPeers),
        onSeeAll: net.results.length > kDiscoveryPageLeads
            ? () => _seeAll(TasteSource.network)
            : null,
      ),
    ];
    if (net.results.isEmpty) {
      out.add(DiscoveryHint(discoveryNetworkEmptyLine(l, c, net)));
      return out;
    }
    for (final lead in net.results.take(kDiscoveryPageLeads)) {
      out.add(DiscoveryLeadRow(lead: lead, newArtist: c.newArtistsOnly));
    }
    return out;
  }

  // ── peers ──────────────────────────────────────────────────────────────

  List<Widget> _peersSection(AppLocalizations l) {
    // Not asked (this account may not query peers), refused, or skipped by
    // the server (a random seed) — then there is no section to draw.
    if (!c.asksPeers || c.peersDisabled) return const [];
    final p = c.peers;
    if (p == null && !c.loadingPeers) return const [];
    final online = p?.peers.where((g) => g.reachable).length ?? 0;
    final out = <Widget>[
      DiscoverySectionHeader(
        l.discoverFromPeers,
        meta: p == null || p.peers.isEmpty
            ? null
            : l.discoverPagePeersOnline(online, p.peers.length),
        // The cap is per peer group, so "See all" only when some group
        // holds rows the page does not show.
        onSeeAll: p != null &&
                p.peers.any((g) => g.results.length > kDiscoveryPagePeerRows)
            ? () => _seeAll(TasteSource.peers)
            : null,
      ),
    ];
    if (p == null) {
      out.add(discoveryLoadingRow());
      return out;
    }
    out.addAll(discoveryPeerGroups(context, c, p,
        maxRows: kDiscoveryPagePeerRows));
    return out;
  }
}

/// The window chooser's face in the configuration bar: the window in force
/// and a caret, outlined so it reads on the bar's gray in every palette.
/// 32 px tall (taller only under a large text setting); the
/// [kDiscoveryTapTarget] band around it is the menu's hit area too. The
/// label ellipsizes rather than overflow a bar narrower than it.
class _WindowPill extends StatelessWidget {
  final String label;
  const _WindowPill(this.label);

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: kDiscoveryTapTarget),
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: Container(
          constraints: const BoxConstraints(minHeight: 32),
          padding: const EdgeInsets.fromLTRB(12, 0, 6, 0),
          decoration: ShapeDecoration(
            shape: StadiumBorder(
                side: BorderSide(color: VelvetColors.border2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: VelvetColors.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Icon(Icons.arrow_drop_down,
                  size: 20, color: VelvetColors.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
