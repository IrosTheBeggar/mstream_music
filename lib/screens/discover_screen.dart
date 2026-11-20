import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../objects/discovery.dart';
import '../objects/display_item.dart';
import '../objects/server.dart';
import '../singletons/api.dart';
import '../singletons/auto_dj_manager.dart';
import '../singletons/log_manager.dart';
import '../singletons/media.dart';
import '../singletons/server_list.dart';
import '../singletons/settings.dart';
import '../singletons/sonic_path_state.dart';
import '../theme/velvet_theme.dart';
import '../util/discover_jobs.dart' show TraySummary;
import '../util/discovery_plugins_api.dart' show ownServerOf;
import '../util/media_item_credits.dart';
import '../util/network_sheet_gate.dart';
import '../util/queue_actions.dart';
import '../util/stream_url.dart';
import '../widgets/song_picker_sheet.dart';
import 'discovery/copies_hub.dart';
import 'discovery/discovery_jobs_controller.dart';
import 'discovery/discovery_keep_routes.dart';
import 'discovery/discovery_lead_row.dart';
import 'discovery/network_lead_sheet.dart'
    show networkLeadTapFor, networkSheetSectionsFor;
import 'sonic_path_screen.dart';

/// More like this — sonic-similarity recommendations seeded by ONE song (the
/// now-playing track, or the one a "Find similar" entry passed), the mobile
/// counterpart of the webapp's now-playing panel. Titled "More like this"
/// (l.discoverTitle) since the Discover page plan §2.12: "Discover" alone
/// names the history-seeded listing (discovery/discovery_listing.dart). Up to four
/// sections, each shown only when the seed's server advertised the matching
/// /api/v1/ping flag (never probed blind):
///   • Similar tracks   — local library, playable rows + "Queue all"
///   • Similar artists  — local library, playable entry points
///   • From the network — P2P leads: a tap opens the network-lead sheet
///                        (previews, the YouTube add, links) when the
///                        user's OWN server's plug-ins can offer something
///                        for the row, else copies "Artist - Title"
///                        (DiscoveryLeadRow)
///   • From your peers  — federation leads (tap copies; not playable at
///                        this server version)
///
/// With the user's own server's plug-ins on, the screen holds that server's
/// shared jobs controller (CopiesHub) for its life: the network rows read
/// its listing and gate, a "Copies" door in the app bar counts its copies
/// and YouTube adds, and its poll keeps Discover's 4 s beat while one runs.
/// A lead action on a network-lead sheet (a preview, Play, Add to queue,
/// Add this one) pins the seed: the screen stops following playback, and a
/// push pin says so beside the seed line.
///
/// Webapp-parity behaviors: refetch on track change debounced 500 ms, stale
/// responses dropped via request ids, 403 hides a section for the screen's
/// lifetime, `notAnalyzed` renders a hint rather than an error, and a
/// transient failure keeps whatever rows are already shown.
class DiscoverScreen extends StatefulWidget {
  /// Explicit seed — the "Find similar" entry points (track menus, Song
  /// Info) pass the track they were invoked on and the screen stays pinned
  /// to it. When null (the player's ⋮ entry) the screen follows the
  /// now-playing track and refreshes on track change — until a lead action
  /// pins the song it shows.
  final Server? seedServer;
  final String? seedPath;
  final String? seedTitle;
  final String? seedArtist;

  const DiscoverScreen(
      {super.key,
      this.seedServer,
      this.seedPath,
      this.seedTitle,
      this.seedArtist});

  bool get hasExplicitSeed => seedServer != null && seedPath != null;

  /// Where "From the network" asks for its leads (the per-song P2P route,
  /// ApiManager.fetchDiscoveryP2pSimilar); tests answer it themselves.
  @visibleForTesting
  static Future<DiscoveryFetchResult<DiscoveryLeads>> Function(
          Server server, String path,
          {required int limit, required bool newArtistsOnly})
      fetchNetworkLeads = _fetchNetworkLeads;

  static Future<DiscoveryFetchResult<DiscoveryLeads>> _fetchNetworkLeads(
          Server server, String path,
          {required int limit, required bool newArtistsOnly}) =>
      ApiManager().fetchDiscoveryP2pSimilar(server, path,
          limit: limit, newArtistsOnly: newArtistsOnly);

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
}

/// A song More like this is seeded by: where it lives and what it is called.
@immutable
class DiscoverSeed {
  final Server? server;
  final String? path;
  final String? title;
  final String? artist;

  const DiscoverSeed({this.server, this.path, this.title, this.artist});
}

/// Which song a refresh of More like this asks for ([fetch]), and whether it
/// becomes the song the screen shows ([show]; its seed line, and what Check
/// again and the new-artists-only switch ask for next):
///  • [explicit] — the screen was opened on a song (a "Find similar"
///    entry): always that one;
///  • [pinned] — a lead action pinned the song on screen ([shown]): that
///    one, for every refresh, Check again and the switch included —
///    whatever plays now;
///  • otherwise the song playing now ([playing], read only on this path): a
///    full refresh shows it, a [leadsOnly] one (the switch) asks only its
///    leads again.
({DiscoverSeed fetch, bool show}) discoverRefreshSeed({
  DiscoverSeed? explicit,
  required bool pinned,
  required DiscoverSeed shown,
  required DiscoverSeed Function() playing,
  required bool leadsOnly,
}) {
  if (explicit != null) return (fetch: explicit, show: !leadsOnly);
  if (pinned) return (fetch: shown, show: false);
  return (fetch: playing(), show: !leadsOnly);
}

/// Whether More like this's app bar shows the Copies door: Copies can exist
/// on the user's own server ([copiesVisible]: DiscoveryJobsController
/// .copiesVisible), and either the network-lead sheet can add from YouTube
/// there ([youtube] ready) or something is copying, adding or has failed
/// ([summary]). Hidden, never greyed.
bool copiesDoorShown({
  required bool copiesVisible,
  required YoutubeBlock youtube,
  required TraySummary summary,
}) =>
    copiesVisible && (youtube == YoutubeBlock.ready || summary.shown);

/// The Copies door's tooltip and spoken label: "Copies" with nothing
/// running or failed, else "Copies: Copying 2, 1 failed" — the counts the
/// Discover page's Copies strip reads.
String copiesDoorLabel(AppLocalizations l, TraySummary summary) {
  final parts = [
    if (summary.running > 0) l.discoverCopiesCopying(summary.running),
    if (summary.failed > 0) l.discoverCopiesFailed(summary.failed),
  ];
  return parts.isEmpty
      ? l.discoverCopiesTitle
      : l.discoverCopiesLabel(parts.join(', '));
}

/// More like this's door to the Copies sheet: the Copies glyph with how many
/// copies and YouTube adds run or wait ([TraySummary.running]), or — none
/// running, some failed — a red dot.
class DiscoverCopiesDoor extends StatelessWidget {
  final TraySummary summary;
  final VoidCallback onPressed;

  const DiscoverCopiesDoor(
      {super.key, required this.summary, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final running = summary.running;
    final dot = running == 0 && summary.failed > 0;
    return IconButton(
      key: const ValueKey('discover-copies-door'),
      tooltip: copiesDoorLabel(l, summary),
      onPressed: onPressed,
      color: VelvetColors.textPrimary,
      // The label says the counts; the badge is only drawn.
      icon: ExcludeSemantics(
        child: Badge(
          key: ValueKey(running > 0
              ? 'discover-copies-count'
              : (dot ? 'discover-copies-dot' : 'discover-copies-plain')),
          isLabelVisible: running > 0 || dot,
          label: running > 0 ? Text('$running') : null,
          smallSize: 8,
          backgroundColor:
              running > 0 ? VelvetColors.primary : VelvetColors.error,
          textColor: VelvetColors.onPrimary,
          textStyle:
              const TextStyle(fontSize: 10, fontWeight: FontWeight.w700),
          child: const Icon(Icons.library_add_outlined),
        ),
      ),
    );
  }
}

class _DiscoverScreenState extends State<DiscoverScreen> {
  StreamSubscription<MediaItem?>? _sub;
  Timer? _debounce;

  // Stale-response guards: one for the local (library) sections, one for the
  // lead sections — separate so the new-artists-only toggle can refetch leads
  // without discarding an in-flight local fetch.
  int _localRid = 0;
  int _leadsRid = 0;

  // The seed = the playing track at the last (debounced) refresh.
  Server? _seedServer;
  String? _seedPath;
  String? _seedArtist;
  String? _seedTitle;

  // Similar tracks.
  bool _tracksLoading = false;
  bool _tracksDisabled = false; // 403 → hidden for this screen's lifetime
  DiscoverySimilarTracks? _tracks;
  List<DisplayItem> _trackRows = const [];

  // Similar artists.
  bool _artistsLoading = false;
  bool _artistsDisabled = false;
  DiscoverySimilarArtists? _artists;
  List<List<DisplayItem>> _artistEntryRows = const [];

  // "From the network" (P2P) / "From your peers" (federation).
  bool _networkLoading = false;
  bool _networkDisabled = false;
  DiscoveryLeads? _network;
  // The song [_network]'s rows sound like: the seed asked when they came —
  // not always the one on show (a track change shows the next song while
  // its rows are still on their way).
  DiscoverSeed? _networkSeed;
  bool _peersLoading = false;
  bool _peersDisabled = false;
  DiscoveryLeads? _peers;

  // "Start a sonic session" card — guards double-taps while the seed is
  // being set up / the first DJ pick is fetched.
  bool _startingSession = false;

  // Re-checking whether the discovery scan has produced anything yet.
  bool _rechecking = false;

  // One automatic probe per screen after a 403 — see _probeAfterRefusal.
  bool _probed = false;

  // The user's OWN server's plug-in jobs (CopiesHub: shared, never disposed
  // here) while its plug-ins are on — the seed's server itself, or a
  // connected server's parent. Null: every network row copies, no door.
  DiscoveryJobsController? _jobs;
  // Its 4 s poll beat while this screen is open (holdPage).
  VoidCallback? _pageHold;

  // A lead action on a network-lead sheet pinned the seed: playback is no
  // longer followed (only ever set without an explicit seed).
  bool _pinned = false;

  @override
  void initState() {
    super.initState();
    _refresh();
    // An explicit seed is pinned — no reason to watch playback. Otherwise
    // follow track changes; the BehaviorSubject fires immediately with the
    // current item and the seed comparison below swallows that first echo.
    if (!widget.hasExplicitSeed) {
      _sub = MediaManager().audioHandler.mediaItem.listen((item) {
        // Pinned by a lead action: the screen stays on its song.
        if (_pinned) return;
        final extras = item?.extras;
        if (extras?['path'] == _seedPath &&
            extras?['server'] == _seedServer?.localname) {
          return;
        }
        _debounce?.cancel();
        _debounce = Timer(const Duration(milliseconds: 500), () {
          if (mounted) _refresh();
        });
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _sub?.cancel();
    _pageHold?.call();
    super.dispose();
  }

  /// The first lead action on a network-lead sheet (a preview, Play, Add to
  /// queue, Add this one): the screen stays on [seed] — the song the sheet's
  /// row sounds like — whatever plays next, a refresh already armed by a
  /// track change included. The screen may have followed playback to
  /// another song while the sheet was open: it goes back to [seed] and asks
  /// for its sections again.
  void _pinSeed([DiscoverSeed? seed]) {
    if (widget.hasExplicitSeed || _pinned || !mounted) return;
    _debounce?.cancel();
    final moved = seed != null &&
        (seed.path != _seedPath || !identical(seed.server, _seedServer));
    setState(() {
      _pinned = true;
      if (moved) {
        _seedServer = seed.server;
        _seedPath = seed.path;
        _seedTitle = seed.title;
        _seedArtist = seed.artist;
      }
    });
    if (moved) _refresh();
  }

  /// Hold [seed]'s own server's jobs controller (or none, its plug-ins
  /// off): a move to another own server lets go of the old one's poll beat
  /// before taking the new one's.
  void _bindJobs(Server? seed) {
    final own = ownServerOf(seed);
    final next = own != null && own.discoveryPluginsAvailable == true
        ? CopiesHub().jobsFor(own)
        : null;
    if (!identical(next, _jobs)) {
      _pageHold?.call();
      _pageHold = null;
      _jobs = next;
      _pageHold = next?.holdPage();
    }
    // The listing, the destination and the job list — only what has not
    // answered yet (the hub's controller lives for the app's session).
    if (next != null) unawaited(next.activate());
  }

  /// Re-reads the seed (discoverRefreshSeed: the explicit or pinned one, else
  /// the playing item) and refetches every visible section ([leadsOnly]
  /// skips the local ones — used by the new-artists-only toggle so the
  /// library sections don't flicker).
  void _refresh({bool leadsOnly = false}) {
    final plan = discoverRefreshSeed(
      explicit: widget.hasExplicitSeed
          ? DiscoverSeed(
              server: widget.seedServer,
              path: widget.seedPath,
              title: widget.seedTitle,
              artist: widget.seedArtist)
          : null,
      pinned: _pinned,
      shown: DiscoverSeed(
          server: _seedServer,
          path: _seedPath,
          title: _seedTitle,
          artist: _seedArtist),
      playing: () {
        final item = MediaManager().audioHandler.mediaItem.value;
        final extras = item?.extras;
        return DiscoverSeed(
          server: ServerManager().byLocalname(extras?['server'] as String?),
          path: extras?['path'] as String?,
          title: item?.title,
          artist: item == null ? null : primaryArtistOf(item),
        );
      },
      leadsOnly: leadsOnly,
    );
    final server = plan.fetch.server;
    final path = plan.fetch.path;
    final artist = plan.fetch.artist;

    if (plan.show) {
      _seedServer = server;
      _seedPath = path;
      _seedTitle = plan.fetch.title;
      _seedArtist = artist;
    }
    _bindJobs(server);
    if (server == null || path == null) {
      setState(() {});
      return;
    }
    // A branch-assigned local doesn't stay promoted inside the fetch
    // closures below; bind a non-null copy for them.
    final Server seedServer = server;

    final newArtistsOnly = SettingsManager().discoverNewArtistsOnly;

    if (!leadsOnly) {
      final rid = ++_localRid;
      if (server.discoveryAvailable == true && !_tracksDisabled) {
        _tracksLoading = true;
        ApiManager()
            .fetchDiscoverySimilarTracks(server, path, limit: 10)
            .then((r) {
          if (!mounted || rid != _localRid) return;
          setState(() {
            _tracksLoading = false;
            if (r.disabled) {
              _tracksDisabled = true;
              _probeAfterRefusal();
            } else if (r.data != null) {
              _tracks = r.data;
              _trackRows = _rowsFor(seedServer, r.data!.results);
            }
          });
        });
      }
      if (server.discoveryAvailable == true &&
          !_artistsDisabled &&
          artist != null &&
          artist.trim().isNotEmpty) {
        _artistsLoading = true;
        ApiManager()
            .fetchDiscoverySimilarArtists(server, artist, limit: 5)
            .then((r) {
          if (!mounted || rid != _localRid) return;
          setState(() {
            _artistsLoading = false;
            if (r.disabled) {
              _artistsDisabled = true;
            } else if (r.data != null) {
              _artists = r.data;
              _artistEntryRows = r.data!.results
                  .map((a) => _rowsFor(seedServer, a.entryPoints))
                  .toList();
            }
          });
        });
      } else {
        _artists = null;
        _artistEntryRows = const [];
      }
    }

    final rid = ++_leadsRid;
    if (server.discoveryP2pAvailable == true && !_networkDisabled) {
      _networkLoading = true;
      final fetchSeed = plan.fetch;
      DiscoverScreen.fetchNetworkLeads(server, path,
              limit: 10, newArtistsOnly: newArtistsOnly)
          .then((r) {
        if (!mounted || rid != _leadsRid) return;
        setState(() {
          _networkLoading = false;
          if (r.disabled) {
            _networkDisabled = true;
          } else if (r.data != null) {
            _network = r.data;
            _networkSeed = fetchSeed;
          }
        });
      });
    }
    if (server.federationDiscoveryAvailable == true && !_peersDisabled) {
      _peersLoading = true;
      ApiManager()
          .fetchDiscoveryFederationSimilar(server, path,
              limit: 10, newArtistsOnly: newArtistsOnly)
          .then((r) {
        if (!mounted || rid != _leadsRid) return;
        setState(() {
          _peersLoading = false;
          if (r.disabled) {
            _peersDisabled = true;
          } else if (r.data != null) {
            _peers = r.data;
          }
        });
      });
    }
    setState(() {});
  }

  /// Discovery results carry vpath-form filepaths without the leading slash;
  /// DisplayItem rows (and the stream-URL builders behind them) expect one —
  /// same mapping as getRecentlyAdded.
  List<DisplayItem> _rowsFor(Server server, List<DiscoveryTrack> tracks) {
    return tracks.map((t) {
      final row = DisplayItem(server, t.filepath, 'file', '/${t.filepath}',
          Icon(Icons.music_note, color: VelvetColors.accent), null);
      // Lite metadata, like a search hit: the /discovery routes render
      // their results through the server's toLiteMetadata, which drops the
      // fidelity / identity / stats fields Song Info shows. Flagging it
      // partial is what makes buildServerFileMediaItem fetch the full block
      // before queueing — without it a track queued from Discover kept the
      // lite block for good, while the same track queued from search did
      // not. One prefill request now covers the whole list.
      row.metadata = t.metadata;
      row.partialMetadata = true;
      return row;
    }).toList();
  }

  void _toast(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
    ));
  }

  Future<void> _queueAllTracks() async {
    final l = AppLocalizations.of(context);
    final n = await addRowsToQueue(_trackRows);
    if (n > 0) _toast(l.browserSongsAdded(n));
  }

  Future<void> _tapTrack(int index) async {
    final l = AppLocalizations.of(context);
    if (await handleTrackTap(_trackRows, index)) _toast(l.browserSongsAdded(1));
  }

  Future<void> _queueArtist(int index) async {
    if (index >= _artistEntryRows.length) return;
    final l = AppLocalizations.of(context);
    final n = await addRowsToQueue(_artistEntryRows[index]);
    if (n > 0) _toast(l.browserSongsAdded(n));
  }

  Future<void> _copyLead(DiscoveryLead lead) async {
    final l = AppLocalizations.of(context);
    await Clipboard.setData(ClipboardData(text: lead.copyText));
    _toast(l.discoverLeadCopied);
  }

  Future<void> _openMusicBrainz(DiscoveryLead lead) async {
    final mbid = lead.recordingMbid;
    if (mbid == null) return;
    final url = 'https://musicbrainz.org/recording/$mbid';
    final ok =
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      _toast(AppLocalizations.of(context).couldNotOpen(url));
    }
  }

  /// A "From the network" row's tap, as its row was drawn ([tap]): the
  /// network-lead sheet (its match line names the song the row sounds
  /// like; its first lead action pins that song), or the copy.
  void _tapNetworkLead(DiscoveryLead lead, NetworkLeadTap tap) {
    appLog('[lead] tap → ${tap.name}');
    final jobs = _jobs;
    if (tap == NetworkLeadTap.sheet && jobs != null) {
      final seed = _networkSeed;
      DiscoveryKeepRoutes.openNetworkLead(context, jobs, lead,
          seedTitle: seed != null ? seed.title : _seedTitle,
          onLeadAction: () => _pinSeed(seed));
    } else {
      unawaited(_copyLead(lead));
    }
  }

  // ── build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final hasSeed = _seedServer != null && _seedPath != null;
    final seedLine = [
      if ((_seedTitle ?? '').trim().isNotEmpty) _seedTitle!.trim(),
      if ((_seedArtist ?? '').trim().isNotEmpty) _seedArtist!.trim(),
    ].join(' · ');
    final jobs = _jobs;

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
              l.discoverTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: VelvetColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            if (seedLine.isNotEmpty)
              // As wide as its line: iOS centres the title block.
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_pinned)
                    Padding(
                      padding: const EdgeInsets.only(right: 4),
                      child: Icon(
                        Icons.push_pin,
                        key: const ValueKey('discover-seed-pinned'),
                        size: 12,
                        color: VelvetColors.primary,
                        semanticLabel: l.discoverLeadPinned,
                      ),
                    ),
                  Flexible(
                    child: Text(
                      seedLine,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: VelvetColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
          ],
        ),
        actions: [
          if (jobs != null)
            ListenableBuilder(
              listenable: jobs,
              builder: (context, _) {
                final summary = jobs.summary;
                if (!copiesDoorShown(
                    copiesVisible: jobs.copiesVisible,
                    youtube: networkSheetSectionsFor(jobs).youtube,
                    summary: summary)) {
                  return const SizedBox.shrink();
                }
                return DiscoverCopiesDoor(
                  summary: summary,
                  onPressed: () =>
                      DiscoveryKeepRoutes.openCopies(context, jobs),
                );
              },
            ),
        ],
      ),
      body: hasSeed ? _sections(l) : _noSeed(l),
    );
  }

  Widget _noSeed(AppLocalizations l) {
    // Even without a playing track the screen can still be useful: start a
    // session from a RANDOM seed on the current server (when it has
    // discovery data).
    final canRandom =
        ServerManager().currentServer?.discoveryAvailable == true;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l.discoverNoSeed,
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: VelvetColors.textSecondary, fontSize: 14),
            ),
            if (canRandom) ...[
              const SizedBox(height: 12),
              _sessionCard(l, random: true),
            ],
          ],
        ),
      ),
    );
  }

  /// One-tap endless radio: seeds the sonic Auto DJ (from the screen's seed,
  /// or a random song in the no-seed state), REPLACES the queue — standard
  /// "start radio" semantics, and the subtitle says so — and hands off to
  /// the player.
  /// Settle WHY the route refused, without waiting for the user to ask.
  ///
  /// Measured against a live server rather than assumed: with
  /// collectDiscoveryData on, discovery.db is created at boot AND by the admin
  /// toggle (which calls initDiscoveryDb immediately), so getIndex() is never
  /// null and the "enabled but no index" 403 does not occur in normal
  /// operation. A library the scan hasn't reached answers 200 with
  /// notAnalyzed instead — which the sections below already handle.
  ///
  /// So a 403 reaching us almost always means the feature was switched OFF
  /// since our last ping, and the card would otherwise open by blaming a scan
  /// that isn't the problem. One re-ping decides it: the flag flips false, the
  /// card stops being drawn, and the panel says it was turned off. If the flag
  /// survives, this really is the rare no-index case and the card is right.
  ///
  /// Once per screen. A server that is genuinely off answers the same way
  /// every time, and this fires from inside a fetch handler.
  void _probeAfterRefusal() {
    if (_probed) return;
    _probed = true;
    final server = _seedServer;
    if (server == null) return;
    unawaited(ServerManager().getServerPaths(server).then((_) {
      if (mounted) setState(() {});
    }));
  }

  /// Ask the server again whether the discovery scan has produced anything.
  ///
  /// The 403 that lands us in the scan-pending state is deliberately
  /// ambiguous: requireIndex() answers the same status for "the feature is
  /// off" and "the feature is on but there is no index yet", so probing
  /// cannot tell configuration from failure. Asking again is the only honest
  /// way to separate them — the ping reports the CONFIG flag, the discovery
  /// routes report the DATA — so this re-pings FIRST. A server switched off
  /// since the screen opened then resolves to the off message instead of
  /// sitting on "scan pending" forever.
  Future<void> _recheckScan() async {
    final server = _seedServer;
    if (server == null || _rechecking) return;
    setState(() => _rechecking = true);
    await ServerManager().getServerPaths(server);
    if (!mounted) return;
    setState(() {
      _rechecking = false;
      // Drop the per-screen 403 latches. They exist so one refusal doesn't
      // cost a request per rebuild; the user has just explicitly asked us to
      // try again, which is the one thing that should clear them.
      _tracksDisabled = false;
      _artistsDisabled = false;
      _networkDisabled = false;
      _peersDisabled = false;
    });
    _refresh();
  }

  Future<void> _startSonicSession() async {
    if (_startingSession) return;
    setState(() => _startingSession = true);
    final l = AppLocalizations.of(context);
    // Root messenger — survives the pop below, unlike this route's scaffold.
    final messenger = ScaffoldMessenger.of(context);

    Server? server = _seedServer;
    String? path = _seedPath;
    String? title = _seedTitle;
    // The page's seed is a song the user can see and starts from on purpose
    // (the one Discover was opened on, else the one playing); with none, a
    // random draw stands in, and like Auto DJ's Random it is no choice.
    final chosen = server != null && path != null;
    if (server == null || path == null) {
      final target = ServerManager().currentServer;
      if (target == null || target.discoveryAvailable != true) {
        setState(() => _startingSession = false);
        return;
      }
      // The filtered draw Auto DJ's own Random start makes: this song opens
      // the session, so it obeys the rating, genre, length and mood filters
      // every later pick does ([ApiManager.fetchAutoDjSeed]).
      final seed = await ApiManager().fetchAutoDjSeed(target);
      if (!mounted) return;
      final item = seed.item;
      if (item == null || item.data == null) {
        messenger.showSnackBar(SnackBar(
            content: Text(seed.noMatch
                ? l.autoDjSeedNoMatch
                : l.autoDjSonicSeedFailed)));
        setState(() => _startingSession = false);
        return;
      }
      server = target;
      path = item.data!;
      title = item.metadata?.title ?? item.name;
    }

    // The bare title, as the other seeded starts store it: it names the
    // opening row when the song's tags can't be fetched.
    final seedTitle = (title ?? '').trim();

    final mgr = AutoDJManager();
    if (!mgr.sonicSimilarityEnabled) {
      await mgr.setSonicSimilarityEnabled(true);
    }
    // A new queue, then the DJ opening on the song, whether it was off, on
    // another server or already on this one (the handler's method says why
    // the order matters).
    await MediaManager().audioHandler.startSessionFromSong(
        server: server,
        path: path,
        title: seedTitle.isEmpty ? path.split('/').last : seedTitle,
        chosen: chosen);
    if (!mounted) return;
    messenger
        .showSnackBar(SnackBar(content: Text(l.discoverSessionStarted)));
    Navigator.of(context).pop();
  }

  /// "Play a path to…" — destination picked via the shared song sheet, then
  /// the preview screen fetches and shows the journey.
  Future<void> _pickPathDestination() async {
    final server = _seedServer;
    final path = _seedPath;
    if (server == null || path == null) return;
    final l = AppLocalizations.of(context);
    final dest = await showModalBottomSheet<DisplayItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: VelvetColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) =>
          SongPickerSheet(server: server, title: l.discoverPlayPathTo),
    );
    final destPath = dest?.data;
    if (dest == null || destPath == null || !mounted) return;
    final destArt = dest.altAlbumArt ?? dest.metadata?.albumArt;
    SonicPathState().beginJourney(
      server,
      SonicPathEndpoint(path, title: _seedTitle, artist: _seedArtist),
      SonicPathEndpoint(
        destPath,
        title: dest.metadata?.title ?? destPath.split('/').last,
        artist: dest.metadata?.artist,
        artUrl: destArt == null ? null : buildAlbumArtUrl(server, destArt),
      ),
    );
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const SonicPathScreen(autoBuild: true),
    ));
  }

  Widget _pathRow(AppLocalizations l) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
      child: Material(
        color: VelvetColors.raised,
        borderRadius: BorderRadius.circular(VelvetColors.radiusLarge),
        child: InkWell(
          borderRadius: BorderRadius.circular(VelvetColors.radiusLarge),
          onTap: _pickPathDestination,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.route, color: VelvetColors.primary, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l.discoverPlayPathTo,
                    style: TextStyle(
                      color: VelvetColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Icon(Icons.chevron_right,
                    color: VelvetColors.textSecondary, size: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _sessionCard(AppLocalizations l, {required bool random}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Material(
        color: VelvetColors.raised,
        borderRadius: BorderRadius.circular(VelvetColors.radiusLarge),
        child: InkWell(
          borderRadius: BorderRadius.circular(VelvetColors.radiusLarge),
          onTap: _startingSession ? null : _startSonicSession,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: VelvetColors.primaryDim,
                    shape: BoxShape.circle,
                  ),
                  child: _startingSession
                      ? Padding(
                          padding: const EdgeInsets.all(10),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: VelvetColors.primary,
                          ),
                        )
                      : Icon(Icons.radio,
                          color: VelvetColors.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l.discoverStartSession,
                        style: TextStyle(
                          color: VelvetColors.textPrimary,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        random
                            ? l.discoverStartSessionSubtitleRandom
                            : l.discoverStartSessionSubtitle,
                        style: TextStyle(
                          color: VelvetColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.play_arrow, color: VelvetColors.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Shown when the ping advertised discovery but the routes answered 403:
  /// the server has the feature switched on and nothing analyzed to search.
  ///
  /// Without this the panel fell through to "No matches found", which reads
  /// as "your music has no matches" — the one thing we know is NOT the case,
  /// since the server never got as far as looking.
  Widget _scanPendingCard(AppLocalizations l) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: VelvetColors.raised,
          borderRadius: BorderRadius.circular(VelvetColors.radiusLarge),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.hourglass_empty,
                    size: 18, color: VelvetColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l.discoverScanPendingTitle,
                    style: TextStyle(
                      color: VelvetColors.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              l.discoverScanPendingBody,
              style:
                  TextStyle(color: VelvetColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _rechecking ? null : _recheckScan,
                icon: _rechecking
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: VelvetColors.primary),
                      )
                    : Icon(Icons.refresh,
                        size: 16, color: VelvetColors.primary),
                label: Text(
                  l.discoverCheckAgain,
                  style: TextStyle(color: VelvetColors.primary, fontSize: 13),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sections(AppLocalizations l) {
    final server = _seedServer!;
    final showTracks = server.discoveryAvailable == true && !_tracksDisabled;
    final showArtists = server.discoveryAvailable == true &&
        !_artistsDisabled &&
        (_seedArtist ?? '').trim().isNotEmpty;
    final showNetwork =
        server.discoveryP2pAvailable == true && !_networkDisabled;
    final showPeers =
        server.federationDiscoveryAvailable == true && !_peersDisabled;

    final children = <Widget>[
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: Text(
          l.discoverMatchedBySound,
          style: TextStyle(
            color: VelvetColors.textSecondary,
            fontSize: 12,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    ];

    // A 403 from a route the ping said was available. `_tracksDisabled` can
    // only be set after a request we chose to make, so reaching here means
    // the flag said yes and the route said no — nothing analyzed yet (or,
    // rarely, a store that failed to open). Explain it and offer the retry.
    final scanPending = server.discoveryAvailable == true && _tracksDisabled;
    if (scanPending) children.add(_scanPendingCard(l));

    // One-tap endless radio anchored on this seed. Hidden while the seed is
    // known to be unanalyzed — starting a session would clear the queue and
    // then fail loud with nothing playing. Hidden on `scanPending` for the
    // same reason: nothing is analyzed, so the DJ has nothing to anchor on.
    if (server.discoveryAvailable == true &&
        !scanPending &&
        _tracks?.notAnalyzed != true) {
      children.add(_sessionCard(l, random: false));
    }
    // Sonic path: pick a destination, get a queue that morphs from this
    // seed's sound to it. Needs the newer server route (discoveryPath flag)
    // — and the same index, so the same 403 takes it out too.
    if (server.discoveryPathAvailable == true &&
        !scanPending &&
        _tracks?.notAnalyzed != true) {
      children.add(_pathRow(l));
    }

    if (showTracks) children.addAll(_tracksSection(l));
    if (showArtists) children.addAll(_artistsSection(l));
    if (showNetwork || showPeers) {
      children.add(_newArtistsToggle(l));
      if (showNetwork) {
        children.addAll(_leadsSection(
          header: l.discoverFromNetwork,
          loading: _networkLoading,
          leads: _network,
          emptyText: _networkEmptyText(l),
          row: _networkRow,
        ));
      }
      if (showPeers) {
        children.addAll(_leadsSection(
          header: l.discoverFromPeers,
          loading: _peersLoading,
          leads: _peers,
          emptyText: _peersEmptyText(l),
          row: _copyRow,
        ));
      }
    }

    if (children.length == 1) {
      // Only reachable after a re-check flipped the flag: the screen cannot
      // be opened unless the ping said discovery was available, so this is
      // "switched off while you were looking at it", not a cold state.
      children.add(_hintRow(server.discoveryAvailable == true
          ? l.discoverNothingFound
          : l.discoverTurnedOff));
    }
    children.add(const SizedBox(height: 24));

    return ListView(children: children);
  }

  // ── similar tracks ─────────────────────────────────────────────────────

  List<Widget> _tracksSection(AppLocalizations l) {
    final result = _tracks;
    final rows = <Widget>[
      _sectionHeader(
        l.discoverSimilarTracks,
        action: (result != null && result.results.isNotEmpty)
            ? TextButton(
                onPressed: _queueAllTracks,
                child: Text(
                  l.discoverQueueAll,
                  style: TextStyle(color: VelvetColors.primary, fontSize: 13),
                ),
              )
            : null,
      ),
    ];
    if (_tracksLoading && result == null) {
      rows.add(_loadingRow());
    } else if (result == null) {
      rows.add(_hintRow(l.discoverNothingFound));
    } else if (result.notAnalyzed) {
      rows.add(_hintRow(l.discoverNotAnalyzed));
    } else if (result.results.isEmpty) {
      rows.add(_hintRow(l.discoverNothingFound));
    } else {
      for (var i = 0; i < result.results.length; i++) {
        rows.add(_trackRow(result.results[i], i));
      }
    }
    return rows;
  }

  Widget _trackRow(DiscoveryTrack track, int index) {
    final row = index < _trackRows.length ? _trackRows[index] : null;
    final artist = track.metadata?.artist;
    final genre = genreTagLabel(track.genreTags);
    final subtitle = [
      if (artist != null && artist.trim().isNotEmpty) artist.trim(),
      ?genre,
    ].join(' · ');
    return ListTile(
      dense: true,
      leading: row?.getAlbumThumb(size: 44),
      title: Text(
        track.displayTitle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 15, color: VelvetColors.textPrimary),
      ),
      subtitle: subtitle.isEmpty
          ? null
          : Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: VelvetColors.textSecondary),
            ),
      trailing: MatchMeter(similarity: track.similarity),
      onTap: () => _tapTrack(index),
    );
  }

  // ── similar artists ────────────────────────────────────────────────────

  List<Widget> _artistsSection(AppLocalizations l) {
    final result = _artists;
    final rows = <Widget>[_sectionHeader(l.discoverSimilarArtists)];
    if (_artistsLoading && result == null) {
      rows.add(_loadingRow());
    } else if (result == null) {
      rows.add(_hintRow(l.discoverNothingFound));
    } else if (result.notAnalyzed) {
      rows.add(_hintRow(l.discoverNotAnalyzed));
    } else if (result.results.isEmpty) {
      rows.add(_hintRow(l.discoverNothingFound));
    } else {
      for (var i = 0; i < result.results.length; i++) {
        rows.add(_artistRow(result.results[i], i));
      }
    }
    return rows;
  }

  Widget _artistRow(DiscoveryArtistMatch match, int index) {
    final entryRows =
        index < _artistEntryRows.length ? _artistEntryRows[index] : const <DisplayItem>[];
    final genre = genreTagLabel(match.genreTags, max: 1);
    return ListTile(
      dense: true,
      leading: entryRows.isNotEmpty
          ? entryRows.first.getAlbumThumb(size: 44)
          : Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: VelvetColors.raised,
                borderRadius: BorderRadius.circular(VelvetColors.radiusSmall),
              ),
              child: Icon(Icons.person,
                  color: VelvetColors.textSecondary, size: 24),
            ),
      title: Text(
        match.artist,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 15, color: VelvetColors.textPrimary),
      ),
      subtitle: genre == null
          ? null
          : Text(
              genre,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 13, color: VelvetColors.textSecondary),
            ),
      trailing: entryRows.isEmpty
          ? null
          : IconButton(
              icon: Icon(Icons.play_circle_outline,
                  color: VelvetColors.primary, size: 26),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              onPressed: () => _queueArtist(index),
            ),
      onTap: entryRows.isEmpty ? null : () => _queueArtist(index),
    );
  }

  // ── leads (network / peers) ────────────────────────────────────────────

  Widget _newArtistsToggle(AppLocalizations l) {
    return SwitchListTile(
      dense: true,
      title: Text(
        l.discoverNewArtistsOnly,
        style: TextStyle(fontSize: 14, color: VelvetColors.textPrimary),
      ),
      value: SettingsManager().discoverNewArtistsOnly,
      activeThumbColor: VelvetColors.primary,
      onChanged: (v) async {
        await SettingsManager().setDiscoverNewArtistsOnly(v);
        if (!mounted) return;
        // Clear the stale lead lists so the sections show their spinners
        // instead of the previous filter's rows.
        _network = null;
        _peers = null;
        _refresh(leadsOnly: true);
      },
    );
  }

  String _networkEmptyText(AppLocalizations l) {
    final n = _network;
    if (n == null) return l.discoverNothingFound;
    if (n.searchedPeers == 0) return l.discoverNetworkWarmingUp;
    if (SettingsManager().discoverNewArtistsOnly) {
      return l.discoverNetworkNothingNew;
    }
    return l.discoverNothingFound;
  }

  String _peersEmptyText(AppLocalizations l) {
    final p = _peers;
    if (p == null) return l.discoverNothingFound;
    if (p.searchedPeers > 0 && p.unreachablePeers >= p.searchedPeers) {
      return l.discoverPeersUnreachable;
    }
    if (SettingsManager().discoverNewArtistsOnly) {
      return l.discoverPeersNothingNew;
    }
    return l.discoverNothingFound;
  }

  List<Widget> _leadsSection({
    required String header,
    required bool loading,
    required DiscoveryLeads? leads,
    required String emptyText,
    required Widget Function(DiscoveryLead lead) row,
  }) {
    final rows = <Widget>[_sectionHeader(header)];
    if (loading && leads == null) {
      rows.add(_loadingRow());
    } else if (leads == null || leads.results.isEmpty) {
      rows.add(_hintRow(emptyText));
    } else {
      for (final lead in leads.results) {
        rows.add(row(lead));
      }
    }
    return rows;
  }

  /// Today's lead row: the tap copies "Artist - Title" ([onTap] says
  /// otherwise only for a network row, which logs its tap).
  Widget _copyRow(DiscoveryLead lead, {VoidCallback? onTap}) =>
      DiscoveryLeadRow(
        lead: lead,
        opensSheet: false,
        artServer: _seedServer,
        onTap: onTap ?? () => unawaited(_copyLead(lead)),
        onOpenMusicBrainz: () => unawaited(_openMusicBrainz(lead)),
      );

  /// A "From the network" row: the network-lead sheet's way in while the
  /// user's own server's plug-ins can offer something for it (redrawn as
  /// its listing and gate answer), else today's copy row.
  Widget _networkRow(DiscoveryLead lead) {
    final jobs = _jobs;
    if (jobs == null) {
      return _copyRow(lead,
          onTap: () => _tapNetworkLead(lead, NetworkLeadTap.copy));
    }
    return ListenableBuilder(
      listenable: jobs,
      builder: (context, _) {
        final tap = networkLeadTapFor(jobs, lead);
        if (tap == NetworkLeadTap.copy) {
          return _copyRow(lead, onTap: () => _tapNetworkLead(lead, tap));
        }
        return DiscoveryLeadRow(
          lead: lead,
          opensSheet: true,
          onTap: () => _tapNetworkLead(lead, tap),
        );
      },
    );
  }

  // ── shared bits ────────────────────────────────────────────────────────

  Widget _sectionHeader(String text, {Widget? action}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 8, 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: TextStyle(
                color: VelvetColors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.1,
              ),
            ),
          ),
          ?action,
        ],
      ),
    );
  }

  Widget _loadingRow() => SizedBox(
        height: 72,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: VelvetColors.primary,
            ),
          ),
        ),
      );

  Widget _hintRow(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Text(
          text,
          style: TextStyle(color: VelvetColors.textSecondary, fontSize: 13),
        ),
      );
}

/// The webapp's vertical "match meter": a slim bar filled bottom-up to the
/// similarity fraction, with the percentage underneath. Public — also used
/// by the queue's compact Discover bar (widgets/discover_queue_bar.dart).
class MatchMeter extends StatelessWidget {
  final double similarity;
  const MatchMeter({super.key, required this.similarity});

  @override
  Widget build(BuildContext context) {
    // scaleDown: tight parents (the queue bar's compact list rows give the
    // trailing slot a few px less than the full screen's rows) shrink the
    // meter to fit instead of overflowing its bottom.
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Container(
              width: 4,
              height: 28,
              color: VelvetColors.raised,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  heightFactor: similarity,
                  child: Container(color: VelvetColors.primary),
                ),
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '${(similarity * 100).round()}',
            style: TextStyle(
              color: VelvetColors.textSecondary,
              fontSize: 9,
              // Trim the line box to the glyphs — the default line height
              // is most of the few pixels the compact rows are short by.
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}
