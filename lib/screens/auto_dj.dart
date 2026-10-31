// Auto DJ configuration screen: every setting is one row showing its value,
// and each row opens one sheet (auto_dj_sheets.dart).
//
//   Start / Stop — the button is the status
//   Play from · First song — how the session runs
//   Must match — the limits that can empty the pool: Sonic similarity, Mood,
//     Genres, Rating, Length
//   Prefer — what the DJ leans towards and gives up when it must: Tempo,
//     Harmonic mixing, Skip words
//   Batch
//
// Rows never move between off and on, or between one server and several.
// A setting the server can't do stays in place, greyed, with a reason of a few
// words where its value would be. Values in amber are shaping the picks.
//
// Per-server fields (folders, minimum rating, the genre filter) live on Server
// objects, because each is the library's own vocabulary — a set of vpath
// names, a rating scale, a set of genre tags. App-level filters (sonic
// similarity, mood, track length, tempo, harmonic mixing, skip words) live in
// AutoDJManager and persist to auto_dj.json; they mean the same thing on every
// server. With several servers in Play from, the Rating and Genres sheets gain
// a chip for each.

import 'dart:async';

import 'package:material_ui/material_ui.dart';
import 'package:rxdart/rxdart.dart' show MergeStream;

import '../l10n/app_localizations.dart';
import '../media/audio_stuff.dart' show SonicDrop;
import '../objects/mood_filter.dart';
import '../objects/server.dart';
import '../singletons/auto_dj_manager.dart';
import '../singletons/media.dart';
import '../singletons/server_list.dart';
import '../theme/velvet_theme.dart';
import '../util/auto_dj_play_from.dart';
import '../util/auto_dj_values.dart';
import '../util/fan_out_readout.dart';
import '../util/server_tree.dart';
import '../util/server_version.dart';
import '../widgets/federation_widgets.dart';
import '../widgets/mood_filter_sheet.dart' show moodLabels, showMoodFilterSheet;
import '../widgets/queue_list.dart' show toggleAutoDJ;
import 'add_server.dart';
import 'auto_dj_sheets.dart';

class AutoDJScreen extends StatefulWidget {
  const AutoDJScreen({super.key});

  @override
  State<AutoDJScreen> createState() => _AutoDJScreenState();
}

class _AutoDJScreenState extends State<AutoDJScreen> {
  StreamSubscription<dynamic>? _customStateSub;
  StreamSubscription<int>? _autoDjMgrSub;
  StreamSubscription? _tunnelSub;
  StreamSubscription? _capabilitiesSub;

  /// The server the DJ is running on, or null while it is off.
  Server? _dj;

  @override
  void initState() {
    super.initState();
    // BehaviorSubject emits seeded value on subscribe, so this fires
    // immediately with the current state. It also fires when a session drops
    // sonic similarity, which the Sonic similarity row shows.
    _customStateSub =
        MediaManager().audioHandler.customState.listen((event) {
      if (mounted) setState(() => _dj = event?.autoDJState as Server?);
    });
    _autoDjMgrSub = AutoDJManager().changeStream.listen((_) {
      if (mounted) setState(() {});
    });
    // The Play from row says which servers are still connecting; a tunnel
    // coming up or dropping is what changes that.
    _tunnelSub = ServerManager().tunnelTransitions.listen((_) {
      if (mounted) setState(() {});
    });
    // And how many take part, which a server's flags decide — the first
    // answer through a tunnel lands a moment after the tunnel comes up.
    _capabilitiesSub = ServerManager().capabilityChanges.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _customStateSub?.cancel();
    _autoDjMgrSub?.cancel();
    _tunnelSub?.cancel();
    _capabilitiesSub?.cancel();
    super.dispose();
  }

  // ── what the rows are about ──────────────────────────────────────

  /// Every server Play from may offer: a federated peer counts — it takes
  /// part like any other server — but not one the user hid or its parent
  /// stopped listing.
  List<Server> get _servers => serversGrouped(ServerManager().serverList)
      .where((s) => s.isSelectable)
      .toList();

  /// The server the rows are about: the DJ's while it runs (named even when
  /// it has left the picker's list), else Play from's. With several servers
  /// it is the session's home, whose version gates the rows.
  Server? get _home => _dj ?? autoDjPlayFrom();

  /// The servers Play from names — the DJ's own among them while it runs.
  List<Server> get _set {
    final set = autoDjPlayFromSet();
    final dj = _dj;
    return dj == null || set.contains(dj) ? set : [dj, ...set];
  }

  /// Several servers: each pick is fanned out across them.
  bool get _several => _set.length > 1;

  ServerVersion? get _version => ServerVersion.tryParse(_home?.serverVersion);

  /// The servers a per-server setting (rating, genres) is edited for.
  List<Server> get _editServers => _several ? _set : [?_home];

  String _needs(AppLocalizations l, ServerParam p) =>
      l.autoDjNeedsServer(paramFloorLabel(p));

  Future<void> _open(WidgetBuilder builder) => showAutoDjSheet<void>(context, builder);

  // ── build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (ServerManager().serverList.isEmpty) return _noServers(l);
    final home = _home;
    final showPlayFrom = _servers.length > 1 ||
        _several ||
        (home?.autoDJPaths.length ?? 0) > 1;
    return Scaffold(
      appBar: AppBar(title: Text(l.autoDjTitle)),
      // SafeArea(bottom: true) keeps the last card clear of the system
      // gesture/nav bar on edge-to-edge devices. AppBar handles the top.
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          children: [
            _startButton(l),
            const SizedBox(height: 16),
            FedCard(children: [
              if (showPlayFrom) _playFromRow(l),
              _firstSongRow(l),
              _batchRow(l),
            ]),
            _header(l.autoDjMustMatch),
            FedCard(children: [
              _sonicRow(l),
              _moodRow(l),
              _genresRow(l),
              _ratingRow(l),
              _lengthRow(l),
            ]),
            _header(l.autoDjPrefer),
            FedCard(children: [
              _tempoRow(l),
              _harmonicRow(l),
              _skipWordsRow(l),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _noServers(AppLocalizations l) => Scaffold(
        appBar: AppBar(title: Text(l.autoDjTitle)),
        body: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const FedTile(Icons.all_inclusive),
            const SizedBox(height: 20),
            IntrinsicWidth(
              child: FedButton(
                l.addServerTitle,
                key: const ValueKey('auto-dj-add-server'),
                icon: Icons.add,
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => AddServerScreen())),
              ),
            ),
          ]),
        ),
      );

  /// Sentence case, over a card of two or more rows.
  Widget _header(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(14, 20, 14, 8),
        child: Text(text,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: VelvetColors.textSecondary)),
      );

  /// Start, or the lit Stop — the Auto DJ button's on look, never red. The
  /// label is the status: nothing else on the screen says whether it is on.
  Widget _startButton(AppLocalizations l) {
    final on = _dj != null;
    final fg = on ? VelvetColors.primary : VelvetColors.onPrimary;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(VelvetColors.radiusLarge),
      side: on
          ? BorderSide(color: VelvetColors.primary, width: 1.5)
          : BorderSide.none,
    );
    return Material(
      color: on ? VelvetColors.primaryDim : VelvetColors.primary,
      shape: shape,
      child: InkWell(
        key: const ValueKey('auto-dj-start'),
        customBorder: shape,
        // Through the shared toggle: on an empty queue it asks for a first
        // song, it starts on Play from's server, and Stop always stops.
        onTap: () => toggleAutoDJ(context, announce: false),
        child: SizedBox(
          height: 52,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(on ? Icons.stop : Icons.play_arrow, size: 20, color: fg),
            const SizedBox(width: 6),
            Text(on ? l.autoDjStopShort : l.start,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: fg)),
          ]),
        ),
      ),
    );
  }

  // ── session ──────────────────────────────────────────────────────

  Widget _playFromRow(AppLocalizations l) {
    final handler = MediaManager().audioHandler;
    final set = _set;
    void open() => _open((_) => PlayFromSheet(
          servers: _servers,
          chosen: set,
          home: _home,
          sitOut: handler.multiServerSitOut,
          // A tunnel server counts as taking part from the moment the
          // session is armed, but it can only answer once its tunnel is up.
          connecting: (s) =>
              _dj != null &&
              fanOutConnecting([s], ServerManager().tunnelServes).isNotEmpty,
          changes: MergeStream([
            ServerManager().tunnelTransitions,
            ServerManager().capabilityChanges,
          ]),
        ));
    if (set.length < 2) {
      return _ValueRow(
        key: const ValueKey('auto-dj-row-play-from'),
        title: l.autoDjPlayFrom,
        value: _home == null ? '' : autoDjServerName(_home!),
        onTap: open,
      );
    }
    // Every server (the ones added later too), or the ones ticked by name.
    final value = AutoDJManager().playFromAll
        ? l.autoDjAllServers
        : set.map(autoDjServerName).join(' · ');
    // A home that can't run sonic itself never asks anyone else: say why
    // rather than count servers that will not be asked.
    final blocked = _home == null ? null : fanOutHomeBlocked(_home!);
    if (blocked != null) {
      return _ValueRow(
        key: const ValueKey('auto-dj-row-play-from'),
        title: l.autoDjPlayFrom,
        value: value,
        onTap: open,
        extra: _warningExtra(sitOutLabel(l, blocked)),
      );
    }
    final taking =
        set.where((s) => handler.multiServerSitOut(s) == null).toList();
    final connecting = _dj == null
        ? 0
        : fanOutConnecting(taking, ServerManager().tunnelServes).length;
    final short = taking.length < set.length;
    return _ValueRow(
      key: const ValueKey('auto-dj-row-play-from'),
      title: l.autoDjPlayFrom,
      value: value,
      onTap: open,
      extra: (connecting > 0 || short)
          ? Row(mainAxisSize: MainAxisSize.min, children: [
              if (connecting > 0)
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: VelvetColors.primary),
                ),
              if (short) ...[
                const SizedBox(width: 6),
                Flexible(
                  child: _warningExtra(
                      l.autoDjServersTakingPart(taking.length, set.length)),
                ),
              ],
            ])
          : null,
    );
  }

  /// A warning after a value: the icon and a few words.
  Widget _warningExtra(String text) => Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(Icons.warning_amber_rounded, size: 16, color: VelvetColors.warning),
        const SizedBox(width: 4),
        Flexible(
          child: Text(text,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 15, color: VelvetColors.warning)),
        ),
      ]);

  Widget _firstSongRow(AppLocalizations l) => _ValueRow(
        key: const ValueKey('auto-dj-row-first-song'),
        title: l.autoDjFirstSong,
        value: switch (AutoDJManager().emptyQueueStart) {
          EmptyQueueStart.ask => l.autoDjStartAskShort,
          EmptyQueueStart.random => l.autoDjFirstSongRandom,
          EmptyQueueStart.pick => l.autoDjFirstSongChoose,
          EmptyQueueStart.recent => l.autoDjFirstSongRecent,
        },
        onTap: () => _open((_) => const FirstSongSheet()),
      );

  // ── must match ───────────────────────────────────────────────────

  Widget _sonicRow(AppLocalizations l) {
    final mgr = AutoDJManager();
    final home = _home;
    const key = ValueKey('auto-dj-row-sonic');
    // Three reasons it can't run, and the row says which: the server
    // predates 6.15.2, its scan has not produced vectors yet (mStream #879),
    // or discovery is off there.
    final String? reason = sonicKnownUnsupported(_version)
        ? _needs(l, ServerParam.similarTo)
        : home?.discoveryOn == true && home?.discoveryReady == false
            ? l.autoDjStillScanning
            : home?.sonicUsable != true
                ? l.autoDjDiscoveryOff
                : null;
    if (reason != null) {
      return _ValueRow(key: key, title: l.autoDjSonicTitle, value: reason);
    }
    void open() => _open((_) => const SonicSheet());
    // A running session that had to drop it says why, where the user goes to
    // loosen it.
    final drop =
        _dj != null && mgr.sonicSimilarityEnabled ? MediaManager().audioHandler.sonicDrop : null;
    if (drop != null) {
      return _ValueRow(
        key: key,
        title: l.autoDjSonicTitle,
        value: switch (drop) {
          SonicDrop.tooStrict => l.autoDjTooStrict,
          SonicDrop.scanning => l.autoDjStillScanning,
          SonicDrop.discoveryOff => l.autoDjDiscoveryOff,
        },
        tone: AutoDjTone.warning,
        onTap: open,
      );
    }
    final on = mgr.sonicSimilarityEnabled;
    return _ValueRow(
      key: key,
      title: l.autoDjSonicTitle,
      value: on
          ? l.autoDjPercent((mgr.sonicMinSimilarity * 100).round())
          : l.commonOff,
      tone: on ? AutoDjTone.active : AutoDjTone.neutral,
      onTap: open,
    );
  }

  Widget _moodRow(AppLocalizations l) {
    final mgr = AutoDJManager();
    final home = _home;
    const key = ValueKey('auto-dj-row-mood');
    // A peer's flags can't be read, so its mood flag is pinned off; with
    // several servers the mood holds where one taking part can filter by it.
    final String? reason = !_several && home?.isFederated == true
        ? l.autoDjNotOnPeers
        : (_several
                ? _set.any((s) => s.moodFiltersAvailable == true)
                : home?.moodFiltersAvailable == true)
            ? null
            : l.autoDjNoMoodData;
    if (reason != null) {
      return _ValueRow(key: key, title: l.autoDjMoodTitle, value: reason);
    }
    final mood = mgr.activeMoodFilter;
    return _ValueRow(
      key: key,
      title: l.autoDjMoodTitle,
      value: mood == null ? l.autoDjAny : moodLabels(l, mood).join(' · '),
      tone: mood == null ? AutoDjTone.neutral : AutoDjTone.active,
      onTap: () async {
        // Off, the sheet still starts at the level last picked.
        final f = await showMoodFilterSheet(context,
            mgr.activeMoodFilter ?? MoodFilter(level: mgr.moodFilter.level),
            title: l.autoDjMoodTitle);
        if (f != null) await mgr.setMood(f.filter);
      },
    );
  }

  /// A server's genre filter in words, or null while it sets nothing. Sorted,
  /// so two servers with the same genres agree whatever order they were
  /// ticked in.
  String? _genreValue(AppLocalizations l, Server s) {
    if (!s.autoDJGenreEnabled || s.autoDJGenres.isEmpty) return null;
    final list = ([...s.autoDJGenres]
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase())))
        .join(' · ');
    return s.autoDJGenreMode == 'blacklist'
        ? l.autoDjGenresSkipValue(list)
        : list;
  }

  Widget _genresRow(AppLocalizations l) {
    const key = ValueKey('auto-dj-row-genres');
    final home = _home;
    if (home == null || autoDjFiltersKnownUnsupported(_version)) {
      return _ValueRow(
          key: key,
          title: l.autoDjGenres,
          value: home == null ? '' : _needs(l, ServerParam.genres));
    }
    final servers = _editServers;
    final values = servers.map((s) => _genreValue(l, s)).toList();
    // Servers agree on what they are sent, the kind of genre too, though the
    // value doesn't name it.
    final sent = [
      for (final (i, s) in servers.indexed)
        values[i] == null ? null : (values[i], genreKindSent(s)),
    ];
    final value = allSame(sent) ? values.firstOrNull : l.autoDjVaries;
    return _ValueRow(
      key: key,
      title: l.autoDjGenres,
      value: value ?? l.autoDjAny,
      tone: value == null ? AutoDjTone.neutral : AutoDjTone.active,
      onTap: () => _open((_) => GenresSheet(
          servers: servers,
          initial: servers.contains(home) ? home : servers.first)),
    );
  }

  Widget _ratingRow(AppLocalizations l) {
    const key = ValueKey('auto-dj-row-rating');
    // Ratings are per user, and a peer is reached with a key (or a guest
    // token) that has none: the server skips minRating for that caller.
    final servers = [
      for (final s in _editServers)
        if (!s.isFederated) s,
    ];
    if (servers.isEmpty) {
      return _ValueRow(
          key: key, title: l.autoDjRating, value: l.autoDjNotOnPeers);
    }
    final values = servers.map((s) => s.autoDJminRating).toList();
    final String? value;
    if (!allSame(values)) {
      value = l.autoDjVaries;
    } else if (values.first case final r?) {
      value = l.autoDjRatingValue(fmtStars(r));
    } else {
      value = null;
    }
    final home = _home;
    return _ValueRow(
      key: key,
      title: l.autoDjRating,
      value: value ?? l.autoDjAny,
      tone: value == null ? AutoDjTone.neutral : AutoDjTone.active,
      onTap: () => _open((_) => RatingSheet(
          servers: servers,
          initial: servers.contains(home) ? home! : servers.first)),
    );
  }

  Widget _lengthRow(AppLocalizations l) {
    const key = ValueKey('auto-dj-row-length');
    // The track-length window landed long after the 6.7.1 filters, so it is
    // gated on its own.
    if (autoDjDurationKnownUnsupported(_version)) {
      return _ValueRow(
          key: key,
          title: l.autoDjDurationRange,
          value: _needs(l, ServerParam.minDuration));
    }
    final b = AutoDJManager().activeDurationBounds;
    return _ValueRow(
      key: key,
      title: l.autoDjDurationRange,
      value: b == null
          ? l.autoDjAny
          : autoDjLengthValue(l, b.min ?? AutoDJManager.durationFloorSec,
              b.max ?? AutoDJManager.durationCeilSec),
      tone: b == null ? AutoDjTone.neutral : AutoDjTone.active,
      onTap: () => _open((_) => const LengthSheet()),
    );
  }

  // ── prefer ───────────────────────────────────────────────────────

  Widget _tempoRow(AppLocalizations l) {
    const key = ValueKey('auto-dj-row-tempo');
    // BPM continuity, harmonic mixing and the genre filter all arrived in
    // 6.7.1. On a server known to predate them the rows say so instead of
    // switching on something the app would strip before sending.
    if (autoDjFiltersKnownUnsupported(_version)) {
      return _ValueRow(
          key: key, title: l.autoDjTempo, value: _needs(l, ServerParam.bpmRanges));
    }
    final mgr = AutoDJManager();
    final on = mgr.bpmContinuityEnabled;
    return _ValueRow(
      key: key,
      title: l.autoDjTempo,
      value: on ? l.autoDjBpmTolerance(mgr.bpmTolerance) : l.commonOff,
      tone: on ? AutoDjTone.active : AutoDjTone.neutral,
      onTap: () => _open((_) => const TempoSheet()),
    );
  }

  Widget _harmonicRow(AppLocalizations l) {
    const key = ValueKey('auto-dj-row-harmonic');
    if (autoDjFiltersKnownUnsupported(_version)) {
      return _ValueRow(
          key: key,
          title: l.autoDjHarmonicTitle,
          value: _needs(l, ServerParam.musicalKeys));
    }
    final mgr = AutoDJManager();
    // The one switch on the screen: a plain yes or no with nothing to tune,
    // so a line under the title says what it does. One node for screen
    // readers: the title and that line, then on or off.
    return MergeSemantics(
      key: key,
      child: Semantics(
        toggled: mgr.harmonicMixingEnabled,
        child: InkWell(
          onTap: () =>
              mgr.setHarmonicMixingEnabled(!mgr.harmonicMixingEnabled),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 52),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
              child: Row(children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(l.autoDjHarmonicTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: VelvetColors.textPrimary)),
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(l.autoDjHarmonicHint,
                            style: TextStyle(
                                fontSize: 13,
                                color: VelvetColors.textSecondary)),
                      ),
                    ],
                  ),
                ),
                ExcludeSemantics(
                  child: Switch(
                    key: const ValueKey('auto-dj-harmonic-switch'),
                    value: mgr.harmonicMixingEnabled,
                    onChanged: (v) => mgr.setHarmonicMixingEnabled(v),
                    activeThumbColor: VelvetColors.primary,
                    inactiveThumbColor: VelvetColors.textSecondary,
                  ),
                ),
              ]),
            ),
          ),
        ),
      ),
    );
  }

  Widget _skipWordsRow(AppLocalizations l) {
    // Applied on the phone, after the server answers, so it works against
    // any server however old.
    final mgr = AutoDJManager();
    final on = mgr.keywordFilterEnabled && mgr.keywordFilterWords.isNotEmpty;
    return _ValueRow(
      key: const ValueKey('auto-dj-row-skip-words'),
      title: l.autoDjSkipWords,
      value: on ? mgr.keywordFilterWords.join(' · ') : l.commonOff,
      tone: on ? AutoDjTone.active : AutoDjTone.neutral,
      onTap: () => _open((_) => const SkipWordsSheet()),
    );
  }

  // ── batch ────────────────────────────────────────────────────────

  Widget _batchRow(AppLocalizations l) {
    const key = ValueKey('auto-dj-row-batch');
    // The app strips `limit` before sending to a server known to predate
    // batch picks (6.26.0), so a row promising a batch would be a lie there.
    if (autoDjBatchKnownUnsupported(_version)) {
      return _ValueRow(
          key: key, title: l.autoDjBatch, value: _needs(l, ServerParam.limit));
    }
    return _ValueRow(
      key: key,
      title: l.autoDjBatch,
      value: l.autoDjSongsPerFetchValue(AutoDJManager().songsPerFetch),
      onTap: () => _open((_) => const BatchSheet()),
    );
  }
}

/// One setting: its name at the left, its value at the right, a chevron.
/// The whole row opens the setting's sheet. Without [onTap] it is a setting
/// the server can't do: greyed, no chevron, and the value is the reason.
class _ValueRow extends StatelessWidget {
  const _ValueRow({
    super.key,
    required this.title,
    required this.value,
    this.tone = AutoDjTone.neutral,
    this.onTap,
    this.extra,
  });

  final String title;
  final String value;
  final AutoDjTone tone;
  final VoidCallback? onTap;

  /// Drawn after the value: Play from's spinner and "2 of 3".
  final Widget? extra;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final valueColor =
        enabled ? autoDjToneColor(tone) : VelvetColors.textSecondary;
    Widget valueText(int lines) => Text(value,
        maxLines: lines,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.right,
        style: TextStyle(fontSize: 15, color: valueColor));
    return Semantics(
      button: enabled,
      enabled: enabled,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 0, 10, 0),
            child: LayoutBuilder(
              builder: (context, box) => Row(children: [
                // The name keeps its line; a long value gives way.
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: box.maxWidth * 0.6),
                  child: Text(title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: enabled
                              ? VelvetColors.textPrimary
                              : VelvetColors.textTertiary)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (enabled && tone == AutoDjTone.warning) ...[
                        Icon(Icons.warning_amber_rounded,
                            size: 16, color: VelvetColors.warning),
                        const SizedBox(width: 4),
                      ],
                      // A reason, or a value beside a status, may take two
                      // lines rather than lose its words; a value keeps to
                      // one. Beside a status the value takes its own width up
                      // to a cap, and the status — the part saying what is
                      // wrong — gets the rest.
                      if (extra == null)
                        Flexible(child: valueText(enabled ? 1 : 2))
                      else ...[
                        ConstrainedBox(
                          constraints:
                              BoxConstraints(maxWidth: box.maxWidth * 0.3),
                          child: valueText(2),
                        ),
                        const SizedBox(width: 6),
                        Flexible(child: extra!),
                      ],
                    ],
                  ),
                ),
                // Disabled rows keep the chevron's room, so every value ends
                // on the same line.
                const SizedBox(width: 6),
                enabled
                    ? Icon(Icons.chevron_right,
                        size: 18, color: VelvetColors.textTertiary)
                    : const SizedBox(width: 18),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}
