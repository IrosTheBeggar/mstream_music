import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../objects/discovery.dart';
import '../objects/display_item.dart';
import '../objects/server.dart';
import '../singletons/api.dart';
import '../singletons/media.dart';
import '../singletons/server_list.dart';
import '../singletons/settings.dart';
import '../theme/velvet_theme.dart';
import '../util/queue_actions.dart';

/// Discover — sonic-similarity recommendations seeded by the NOW-PLAYING
/// track, the mobile counterpart of the webapp's Discover panel. Up to four
/// sections, each shown only when the seed's server advertised the matching
/// /api/v1/ping flag (never probed blind):
///   • Similar tracks   — local library, playable rows + "Queue all"
///   • Similar artists  — local library, playable entry points
///   • From the network — P2P leads (tap copies "Artist - Title")
///   • From your peers  — federation leads (same; not playable at this
///                        server version)
///
/// Webapp-parity behaviors: refetch on track change debounced 500 ms, stale
/// responses dropped via request ids, 403 hides a section for the screen's
/// lifetime, `notAnalyzed` renders a hint rather than an error, and a
/// transient failure keeps whatever rows are already shown.
class DiscoverScreen extends StatefulWidget {
  const DiscoverScreen({super.key});

  @override
  State<DiscoverScreen> createState() => _DiscoverScreenState();
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
  bool _peersLoading = false;
  bool _peersDisabled = false;
  DiscoveryLeads? _peers;

  @override
  void initState() {
    super.initState();
    _refresh();
    // BehaviorSubject → fires immediately with the current item; the seed
    // comparison below swallows that first echo.
    _sub = MediaManager().audioHandler.mediaItem.listen((item) {
      final extras = item?.extras;
      if (extras?['path'] == _seedPath && extras?['server'] == _seedServer?.localname) {
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

  /// Re-reads the seed from the playing item and refetches every visible
  /// section ([leadsOnly] skips the local ones — used by the new-artists-only
  /// toggle so the library sections don't flicker).
  void _refresh({bool leadsOnly = false}) {
    final item = MediaManager().audioHandler.mediaItem.value;
    final extras = item?.extras;
    final path = extras?['path'] as String?;
    final server = ServerManager().byLocalname(extras?['server'] as String?);

    if (!leadsOnly) {
      _seedServer = server;
      _seedPath = path;
      _seedTitle = item?.title;
      _seedArtist = item?.artist;
    }
    if (server == null || path == null) {
      setState(() {});
      return;
    }

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
            } else if (r.data != null) {
              _tracks = r.data;
              _trackRows = _rowsFor(server, r.data!.results);
            }
          });
        });
      }
      final artist = item?.artist;
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
                  .map((a) => _rowsFor(server, a.entryPoints))
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
      ApiManager()
          .fetchDiscoveryP2pSimilar(server, path,
              limit: 10, newArtistsOnly: newArtistsOnly)
          .then((r) {
        if (!mounted || rid != _leadsRid) return;
        setState(() {
          _networkLoading = false;
          if (r.disabled) {
            _networkDisabled = true;
          } else if (r.data != null) {
            _network = r.data;
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
      row.metadata = t.metadata;
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

  // ── build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final hasSeed = _seedServer != null && _seedPath != null;
    final seedLine = [
      if ((_seedTitle ?? '').trim().isNotEmpty) _seedTitle!.trim(),
      if ((_seedArtist ?? '').trim().isNotEmpty) _seedArtist!.trim(),
    ].join(' · ');

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
              Text(
                seedLine,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: VelvetColors.textSecondary,
                  fontSize: 12,
                ),
              ),
          ],
        ),
      ),
      body: hasSeed ? _sections(l) : _noSeed(l),
    );
  }

  Widget _noSeed(AppLocalizations l) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            l.discoverNoSeed,
            textAlign: TextAlign.center,
            style: TextStyle(color: VelvetColors.textSecondary, fontSize: 14),
          ),
        ),
      );

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

    if (showTracks) children.addAll(_tracksSection(l));
    if (showArtists) children.addAll(_artistsSection(l));
    if (showNetwork || showPeers) {
      children.add(_newArtistsToggle(l));
      if (showNetwork) {
        children.addAll(_leadsSection(
          l,
          header: l.discoverFromNetwork,
          loading: _networkLoading,
          leads: _network,
          emptyText: _networkEmptyText(l),
        ));
      }
      if (showPeers) {
        children.addAll(_leadsSection(
          l,
          header: l.discoverFromPeers,
          loading: _peersLoading,
          leads: _peers,
          emptyText: _peersEmptyText(l),
        ));
      }
    }

    if (children.length == 1) {
      // Every section 403'd away (stale ping flags) — mirror the no-results
      // look rather than an empty white void.
      children.add(_hintRow(l.discoverNothingFound));
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
      trailing: _MatchMeter(similarity: track.similarity),
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

  List<Widget> _leadsSection(
    AppLocalizations l, {
    required String header,
    required bool loading,
    required DiscoveryLeads? leads,
    required String emptyText,
  }) {
    final rows = <Widget>[_sectionHeader(header)];
    if (loading && leads == null) {
      rows.add(_loadingRow());
    } else if (leads == null || leads.results.isEmpty) {
      rows.add(_hintRow(emptyText));
    } else {
      for (final lead in leads.results) {
        rows.add(_leadRow(l, lead));
      }
    }
    return rows;
  }

  Widget _leadRow(AppLocalizations l, DiscoveryLead lead) {
    final genre = genreTagLabel(lead.genreTags, max: 1);
    final subtitle = [
      if (lead.artist.isNotEmpty) lead.artist,
      ?genre,
      ?lead.peerName,
    ].join(' · ');
    return ListTile(
      dense: true,
      leading: Icon(Icons.travel_explore,
          color: VelvetColors.textSecondary, size: 22),
      title: Text(
        lead.title,
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
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (lead.recordingMbid != null)
            IconButton(
              icon: Icon(Icons.open_in_new,
                  color: VelvetColors.textSecondary, size: 18),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
              tooltip: l.discoverOpenMusicBrainz,
              onPressed: () => _openMusicBrainz(lead),
            ),
          _MatchMeter(similarity: lead.similarity),
        ],
      ),
      onTap: () => _copyLead(lead),
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
/// similarity fraction, with the percentage underneath.
class _MatchMeter extends StatelessWidget {
  final double similarity;
  const _MatchMeter({required this.similarity});

  @override
  Widget build(BuildContext context) {
    return Column(
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
          style: TextStyle(color: VelvetColors.textSecondary, fontSize: 9),
        ),
      ],
    );
  }
}
