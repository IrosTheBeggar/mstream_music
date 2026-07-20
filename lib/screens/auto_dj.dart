// Auto DJ configuration screen.
//
// Layout mirrors the webapp's panel:
//   * Status / enable button at top
//   * Server picker (if multi-server)
//   * Sources — per-server vpath toggles
//   * Filters — min rating (per-server), genre filter (app-level),
//     keyword filter (app-level)
//
// Per-server fields (minRating, autoDJPaths) live on Server objects.
// App-level filters (genre, keyword) live in AutoDJManager and
// persist to auto_dj.json. Genre filter is server-side via the
// `genres`/`genreMode` request fields; keyword filter is client-
// side, applied in audio_stuff.dart's autoDJ() retry loop.

import 'dart:async';

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../l10n/enum_labels.dart';
import '../objects/display_item.dart';
import '../objects/server.dart';
import '../singletons/api.dart';
import '../singletons/auto_dj_manager.dart';
import '../singletons/media.dart';
import '../singletons/server_list.dart';
import '../theme/velvet_theme.dart';

class AutoDJScreen extends StatefulWidget {
  const AutoDJScreen({super.key});

  @override
  State<AutoDJScreen> createState() => _AutoDJScreenState();
}

class _AutoDJScreenState extends State<AutoDJScreen> {
  StreamSubscription<dynamic>? _customStateSub;
  StreamSubscription<int>? _autoDjMgrSub;

  Server? _autoDJServer;

  // Genre autocomplete cache. Fetched once when the screen mounts
  // (background) so the picker sheet shows results without waiting.
  // Re-fetched if the AutoDJ server changes.
  List<String>? _availableGenres;
  bool _loadingGenres = false;
  String? _genreLoadError;
  Server? _genresLoadedFor;

  final TextEditingController _keywordCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // BehaviorSubject emits seeded value on subscribe, so this fires
    // immediately with the current state.
    _customStateSub =
        MediaManager().audioHandler.customState.listen((event) {
      final newServer = event?.autoDJState as Server?;
      if (mounted) {
        setState(() => _autoDJServer = newServer);
        _ensureGenresLoaded();
      }
    });
    _autoDjMgrSub = AutoDJManager().changeStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _customStateSub?.cancel();
    _autoDjMgrSub?.cancel();
    _keywordCtrl.dispose();
    super.dispose();
  }

  void _setAutoDJ(Server? server) {
    MediaManager()
        .audioHandler
        .customAction('setAutoDJ', {'autoDJServer': server});
  }

  // Use the AutoDJ server when configured; fall back to the current
  // server so the genre picker works before AutoDJ is enabled.
  Server? get _genreFetchTarget =>
      _autoDJServer ?? ServerManager().currentServer;

  Future<void> _ensureGenresLoaded() async {
    final server = _genreFetchTarget;
    if (server == null) return;
    if (_loadingGenres) return;
    if (_availableGenres != null && _genresLoadedFor == server) return;

    setState(() {
      _loadingGenres = true;
      _genreLoadError = null;
    });
    try {
      final genres = await ApiManager().getGenres(useThisServer: server);
      if (!mounted) return;
      setState(() {
        _availableGenres = genres
            .map((g) => (g['name'] ?? '').toString())
            .where((s) => s.isNotEmpty)
            .toList()
          ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
        _loadingGenres = false;
        _genresLoadedFor = server;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingGenres = false;
        _genreLoadError = AppLocalizations.of(context).autoDjGenreLoadError;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (ServerManager().serverList.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(l.autoDjTitle)),
        body: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            l.autoDjAddServerFirst,
            style: TextStyle(color: VelvetColors.textSecondary),
          ),
        ),
      );
    }

    final enabled = _autoDJServer != null;

    return Scaffold(
      appBar: AppBar(title: Text(l.autoDjTitle)),
      // SafeArea(bottom: true) ensures the last filter section
      // doesn't get tucked under the system gesture/nav bar on
      // edge-to-edge devices. AppBar handles the top inset.
      body: SafeArea(
        top: false,
        child: ListView(
        padding: EdgeInsets.only(bottom: 24),
        children: [
          _statusSection(enabled, _autoDJServer),
          Divider(color: VelvetColors.border, height: 1),
          if (ServerManager().serverList.length > 1 && enabled) ...[
            _sectionHeader(l.autoDjSectionServer),
            _serverPickerTile(_autoDJServer!),
            Divider(color: VelvetColors.border, height: 1),
          ],
          if (enabled && _autoDJServer!.autoDJPaths.length > 1) ...[
            _sectionHeader(l.autoDjSectionSources),
            ..._vpathTiles(_autoDJServer!),
            Divider(color: VelvetColors.border, height: 1),
          ],
          _sectionHeader(l.autoDjSectionContinuity),
          _sonicSimilaritySection(),
          _bpmContinuitySection(),
          _harmonicMixingSection(),
          Divider(color: VelvetColors.border, height: 1),
          _sectionHeader(l.autoDjSectionFilters),
          if (enabled) _minRatingTile(_autoDJServer!),
          _genreFilterSection(),
          _keywordFilterSection(),
        ],
      ),
      ),
    );
  }

  // ── Continuity: sonic similarity + BPM + harmonic mixing ────────

  Widget _sonicSimilaritySection() {
    final l = AppLocalizations.of(context);
    final mgr = AutoDJManager();
    // Capability of the server that would serve the picks (the DJ server
    // when one is running, otherwise the current server as a preview).
    // Without discovery data the toggle is inert, so show it disabled with
    // an explanation instead of letting it silently do nothing.
    final target = _autoDJServer ?? ServerManager().currentServer;
    final supported = target?.discoveryAvailable == true;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.autoDjSonicTitle,
                        style: TextStyle(
                            color: VelvetColors.textPrimary, fontSize: 15)),
                    SizedBox(height: 2),
                    Text(
                      supported
                          ? l.autoDjSonicSubtitle
                          : l.autoDjSonicUnavailable,
                      style: TextStyle(
                          color: VelvetColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Switch(
                value: mgr.sonicSimilarityEnabled && supported,
                onChanged: supported
                    ? (v) async {
                        await mgr.setSonicSimilarityEnabled(v);
                        // Webapp parity (clearSonicAnchors): toggling the
                        // feature off drops the session anchors — rolling
                        // history + locked pin. The explicit seed survives.
                        if (!v) {
                          MediaManager()
                              .audioHandler
                              .customAction('clearSonicSession');
                        }
                      }
                    : null,
                activeThumbColor: VelvetColors.primary,
              ),
            ],
          ),
          if (supported && mgr.sonicSimilarityEnabled) ...[
            SizedBox(height: 4),
            Row(
              children: [
                Text(
                  l.autoDjSonicStrictness,
                  style: TextStyle(
                      color: VelvetColors.textSecondary, fontSize: 13),
                ),
                Spacer(),
                Text(
                  l.autoDjSonicStrictnessValue(
                      (mgr.sonicMinSimilarity * 100).round()),
                  style: TextStyle(
                    color: VelvetColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: VelvetColors.primary,
                thumbColor: VelvetColors.primary,
                overlayColor: VelvetColors.primaryDim,
              ),
              // Raw cosine threshold; the useful band in practice —
              // webapp's slider covers the same perceptual range.
              child: Slider(
                value: mgr.sonicMinSimilarity.clamp(0.30, 0.80),
                min: 0.30,
                max: 0.80,
                divisions: 50,
                onChanged: (v) => mgr.setSonicMinSimilarity(v),
              ),
            ),
            // Explicit seed — "start the session from this song". Wins over
            // the playing track for the first pick; the rolling history
            // takes over afterwards. The dice picks a random library song.
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: _openSonicSeedPicker,
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l.autoDjSonicSeedLabel,
                            style: TextStyle(
                                color: VelvetColors.textSecondary,
                                fontSize: 13),
                          ),
                          SizedBox(height: 2),
                          Text(
                            mgr.sonicSeedTitle ?? l.autoDjSonicSeedNone,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: mgr.sonicSeedPath != null
                                  ? VelvetColors.textPrimary
                                  : VelvetColors.textSecondary,
                              fontSize: 13,
                              fontStyle: mgr.sonicSeedPath != null
                                  ? FontStyle.normal
                                  : FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                if (mgr.sonicSeedPath != null)
                  IconButton(
                    icon: Icon(Icons.close,
                        size: 18, color: VelvetColors.textSecondary),
                    tooltip: l.autoDjSonicSeedRemove,
                    visualDensity: VisualDensity.compact,
                    onPressed: _clearSonicSeed,
                  ),
                IconButton(
                  icon: Icon(Icons.casino,
                      size: 20, color: VelvetColors.primary),
                  tooltip: l.autoDjSonicSeedRandom,
                  visualDensity: VisualDensity.compact,
                  onPressed: _pickRandomSonicSeed,
                ),
              ],
            ),
            // Anchor policy: follow the session's own picks (rolling) or
            // stay pinned to the seed for the whole session (locked).
            SizedBox(height: 8),
            Text(
              l.autoDjSonicAnchorLabel,
              style:
                  TextStyle(color: VelvetColors.textSecondary, fontSize: 13),
            ),
            SizedBox(height: 6),
            SegmentedButton<SonicAnchorMode>(
              segments: [
                for (final mode in SonicAnchorMode.values)
                  ButtonSegment(value: mode, label: Text(mode.label(l))),
              ],
              selected: {mgr.sonicAnchorMode},
              onSelectionChanged: (set) {
                if (set.isNotEmpty) mgr.setSonicAnchorMode(set.first);
              },
              showSelectedIcon: false,
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
              ),
            ),
            SizedBox(height: 6),
            Text(
              mgr.sonicAnchorMode.hint(l),
              style:
                  TextStyle(color: VelvetColors.textTertiary, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  // The server a seed would be picked from / sent to: the DJ server when
  // one is running, else the current server (same fallback as the genre
  // picker).
  Server? get _sonicSeedTarget => _autoDJServer ?? ServerManager().currentServer;

  Future<void> _applySonicSeed(DisplayItem item) async {
    final path = item.data;
    final server = item.server;
    if (path == null || server == null) return;
    final meta = item.metadata;
    final artist = meta?.artist?.trim() ?? '';
    final title = [
      meta?.title ?? item.name,
      if (artist.isNotEmpty) artist,
    ].join(' · ');
    await AutoDJManager()
        .setSonicSeed(path: path, title: title, server: server.localname);
    // New lane: restart the rolling sonic session so the next pick anchors
    // on this seed instead of the previous picks.
    MediaManager().audioHandler.customAction('clearSonicSession');
  }

  Future<void> _clearSonicSeed() async {
    await AutoDJManager().clearSonicSeed();
    MediaManager().audioHandler.customAction('clearSonicSession');
  }

  Future<void> _pickRandomSonicSeed() async {
    final server = _sonicSeedTarget;
    if (server == null) return;
    final l = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final item = await ApiManager().fetchRandomSong(server);
    if (!mounted) return;
    if (item == null) {
      messenger
          .showSnackBar(SnackBar(content: Text(l.autoDjSonicSeedFailed)));
      return;
    }
    await _applySonicSeed(item);
  }

  Future<void> _openSonicSeedPicker() async {
    final server = _sonicSeedTarget;
    if (server == null) return;
    final picked = await showModalBottomSheet<DisplayItem>(
      context: context,
      isScrollControlled: true,
      backgroundColor: VelvetColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _SonicSeedSheet(server: server),
    );
    if (picked != null) await _applySonicSeed(picked);
  }

  Widget _bpmContinuitySection() {
    final l = AppLocalizations.of(context);
    final mgr = AutoDJManager();
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.autoDjBpmTitle,
                        style: TextStyle(
                            color: VelvetColors.textPrimary, fontSize: 15)),
                    SizedBox(height: 2),
                    Text(
                      l.autoDjBpmSubtitle,
                      style: TextStyle(
                          color: VelvetColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Switch(
                value: mgr.bpmContinuityEnabled,
                onChanged: (v) => mgr.setBpmContinuityEnabled(v),
                activeThumbColor: VelvetColors.primary,
              ),
            ],
          ),
          if (mgr.bpmContinuityEnabled) ...[
            SizedBox(height: 4),
            Row(
              children: [
                Text(
                  l.autoDjTolerance,
                  style: TextStyle(
                      color: VelvetColors.textSecondary, fontSize: 13),
                ),
                Spacer(),
                Text(
                  l.autoDjBpmTolerance(mgr.bpmTolerance),
                  style: TextStyle(
                    color: VelvetColors.primary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: VelvetColors.primary,
                thumbColor: VelvetColors.primary,
                overlayColor: VelvetColors.primaryDim,
              ),
              child: Slider(
                value: mgr.bpmTolerance.toDouble().clamp(1.0, 20.0),
                min: 1,
                max: 20,
                divisions: 19,
                onChanged: (v) => mgr.setBpmTolerance(v.round()),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _harmonicMixingSection() {
    final l = AppLocalizations.of(context);
    final mgr = AutoDJManager();
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.autoDjHarmonicTitle,
                    style: TextStyle(
                        color: VelvetColors.textPrimary, fontSize: 15)),
                SizedBox(height: 2),
                Text(
                  l.autoDjHarmonicSubtitle,
                  style: TextStyle(
                      color: VelvetColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          Switch(
            value: mgr.harmonicMixingEnabled,
            onChanged: (v) => mgr.setHarmonicMixingEnabled(v),
            activeThumbColor: VelvetColors.primary,
          ),
        ],
      ),
    );
  }

  // ── Status / enable button ───────────────────────────────────────

  Widget _statusSection(bool enabled, Server? autoDJServer) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            enabled ? l.autoDjStatusOn : l.autoDjStatusOff,
            style: TextStyle(
              color: VelvetColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4),
          Text(
            enabled
                ? l.autoDjStatusOnDetail(autoDJServer!.url)
                : l.autoDjStatusOffDetail,
            style: TextStyle(
                color: VelvetColors.textSecondary, fontSize: 12),
          ),
          SizedBox(height: 14),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
                  enabled ? VelvetColors.error : VelvetColors.primary,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(VelvetColors.radiusSmall),
              ),
              textStyle:
                  TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            onPressed: () => _setAutoDJ(
                enabled ? null : ServerManager().currentServer),
            child: Text(enabled ? l.autoDjStop : l.autoDjStart),
          ),
        ],
      ),
    );
  }

  // ── Server picker (multi-server only, when enabled) ─────────────

  Widget _serverPickerTile(Server autoDJServer) {
    final l = AppLocalizations.of(context);
    final otherServers = ServerManager()
        .serverList
        .where((s) => s != autoDJServer)
        .toList();
    if (otherServers.isEmpty) {
      return ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 20),
        title: Text(autoDJServer.url,
            style: TextStyle(color: VelvetColors.textPrimary)),
        subtitle: Text(l.autoDjActiveSource,
            style: TextStyle(
                color: VelvetColors.textSecondary, fontSize: 12)),
      );
    }
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 20),
      title: Text(autoDJServer.url,
          style: TextStyle(color: VelvetColors.textPrimary)),
      subtitle: Text(l.autoDjActiveSourceTap,
          style:
              TextStyle(color: VelvetColors.textSecondary, fontSize: 12)),
      trailing: DropdownButton<Server>(
        underline: SizedBox.shrink(),
        hint: Text(l.autoDjSwitch, style: TextStyle(color: VelvetColors.primary)),
        dropdownColor: VelvetColors.surface,
        items: otherServers
            .map((s) => DropdownMenuItem(
                  value: s,
                  child: Text(s.url,
                      style: TextStyle(color: VelvetColors.textPrimary)),
                ))
            .toList(),
        onChanged: (newValue) {
          if (newValue != null) _setAutoDJ(newValue);
        },
      ),
    );
  }

  // ── Sources (vpath switches) ─────────────────────────────────────

  List<Widget> _vpathTiles(Server autoDJServer) {
    final l = AppLocalizations.of(context);
    return autoDJServer.autoDJPaths.entries.map((entry) {
      return SwitchListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 20),
        title: Text(entry.key,
            style: TextStyle(color: VelvetColors.textPrimary)),
        value: entry.value,
        onChanged: (value) {
          // Refuse to disable the last enabled vpath — server would
          // have nothing to draw from.
          final anyOtherOn = autoDJServer.autoDJPaths.entries
              .any((e) => e.key != entry.key && e.value);
          if (!value && !anyOtherOn) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l.autoDjOneSourceRequired)),
            );
            return;
          }
          setState(() => autoDJServer.autoDJPaths[entry.key] = value);
          MediaManager()
              .audioHandler
              .customAction('forceAutoDJRefresh');
          ServerManager().callAfterEditServer();
        },
        activeThumbColor: VelvetColors.primary,
      );
    }).toList();
  }

  // ── Min Rating ──────────────────────────────────────────────────

  Widget _minRatingTile(Server autoDJServer) {
    final l = AppLocalizations.of(context);
    const items = [
      MapEntry<int?, String>(null, 'Any'),
      MapEntry<int?, String>(1, '0.5 ★'),
      MapEntry<int?, String>(2, '1.0 ★'),
      MapEntry<int?, String>(3, '1.5 ★'),
      MapEntry<int?, String>(4, '2.0 ★'),
      MapEntry<int?, String>(5, '2.5 ★'),
      MapEntry<int?, String>(6, '3.0 ★'),
      MapEntry<int?, String>(7, '3.5 ★'),
      MapEntry<int?, String>(8, '4.0 ★'),
      MapEntry<int?, String>(9, '4.5 ★'),
      MapEntry<int?, String>(10, '5.0 ★'),
    ];
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 20),
      title: Text(l.autoDjMinRating,
          style: TextStyle(color: VelvetColors.textPrimary)),
      subtitle: Text(l.autoDjMinRatingSubtitle,
          style:
              TextStyle(color: VelvetColors.textSecondary, fontSize: 12)),
      trailing: DropdownButton<int?>(
        underline: SizedBox.shrink(),
        dropdownColor: VelvetColors.surface,
        value: autoDJServer.autoDJminRating,
        items: items
            .map((e) => DropdownMenuItem<int?>(
                  value: e.key,
                  // 'Any' (null key) is the only word; star labels are
                  // universal and stay literal.
                  child: Text(e.key == null ? l.autoDjRatingAny : e.value,
                      style: TextStyle(color: VelvetColors.textPrimary)),
                ))
            .toList(),
        onChanged: (newValue) {
          setState(() => autoDJServer.autoDJminRating = newValue);
          MediaManager().audioHandler.customAction('forceAutoDJRefresh');
          ServerManager().callAfterEditServer();
        },
      ),
    );
  }

  // ── Genre Filter ─────────────────────────────────────────────────

  Widget _genreFilterSection() {
    final l = AppLocalizations.of(context);
    final mgr = AutoDJManager();
    final selected = mgr.genreFilterValues;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.autoDjGenreTitle,
                        style: TextStyle(
                            color: VelvetColors.textPrimary, fontSize: 15)),
                    SizedBox(height: 2),
                    Text(
                      l.autoDjGenreSubtitle,
                      style: TextStyle(
                          color: VelvetColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Switch(
                value: mgr.genreFilterEnabled,
                onChanged: (v) => mgr.setGenreFilterEnabled(v),
                activeThumbColor: VelvetColors.primary,
              ),
            ],
          ),
          if (mgr.genreFilterEnabled) ...[
            SizedBox(height: 8),
            SegmentedButton<String>(
              segments: [
                ButtonSegment(value: 'whitelist', label: Text(l.autoDjWhitelist)),
                ButtonSegment(value: 'blacklist', label: Text(l.autoDjBlacklist)),
              ],
              selected: {mgr.genreFilterMode},
              onSelectionChanged: (set) {
                if (set.isNotEmpty) {
                  mgr.setGenreFilterMode(set.first);
                }
              },
              showSelectedIcon: false,
              style: ButtonStyle(
                visualDensity: VisualDensity.compact,
              ),
            ),
            SizedBox(height: 12),
            if (selected.isEmpty)
              Text(
                l.autoDjNoGenres,
                style:
                    TextStyle(color: VelvetColors.textTertiary, fontSize: 12),
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: selected
                    .map((g) => Chip(
                          // Cap label width so a long genre like
                          // "Soundtracks — Film & TV" can't push the
                          // chip wider than the screen and force an
                          // overflow within the Wrap row.
                          label: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: 180),
                            child: Text(
                              g,
                              style: TextStyle(
                                  color: VelvetColors.textPrimary,
                                  fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          backgroundColor: VelvetColors.raised,
                          side: BorderSide(color: VelvetColors.border),
                          deleteIconColor: VelvetColors.textSecondary,
                          onDeleted: () => mgr.removeGenre(g),
                          visualDensity: VisualDensity.compact,
                        ))
                    .toList(),
              ),
            SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _openGenrePicker,
                icon: Icon(Icons.add, size: 18),
                label: Text(l.autoDjPickGenres),
                style: TextButton.styleFrom(
                  foregroundColor: VelvetColors.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openGenrePicker() async {
    await _ensureGenresLoaded();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: VelvetColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => _GenrePickerSheet(
        available: _availableGenres ?? const [],
        loading: _loadingGenres,
        error: _genreLoadError,
      ),
    );
  }

  // ── Keyword Filter ───────────────────────────────────────────────

  Widget _keywordFilterSection() {
    final l = AppLocalizations.of(context);
    final mgr = AutoDJManager();
    final words = mgr.keywordFilterWords;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.autoDjKeywordTitle,
                        style: TextStyle(
                            color: VelvetColors.textPrimary, fontSize: 15)),
                    SizedBox(height: 2),
                    Text(
                      l.autoDjKeywordSubtitle,
                      style: TextStyle(
                          color: VelvetColors.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Switch(
                value: mgr.keywordFilterEnabled,
                onChanged: (v) => mgr.setKeywordFilterEnabled(v),
                activeThumbColor: VelvetColors.primary,
              ),
            ],
          ),
          if (mgr.keywordFilterEnabled) ...[
            SizedBox(height: 8),
            if (words.isEmpty)
              Text(
                l.autoDjNoKeywords,
                style:
                    TextStyle(color: VelvetColors.textTertiary, fontSize: 12),
              )
            else
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: words
                    .map((w) => Chip(
                          label: ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: 180),
                            child: Text(
                              w,
                              style: TextStyle(
                                  color: VelvetColors.textPrimary,
                                  fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          backgroundColor: VelvetColors.raised,
                          side: BorderSide(color: VelvetColors.border),
                          deleteIconColor: VelvetColors.textSecondary,
                          onDeleted: () => mgr.removeKeyword(w),
                          visualDensity: VisualDensity.compact,
                        ))
                    .toList(),
              ),
            SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _keywordCtrl,
                    decoration: InputDecoration(
                      hintText: l.autoDjKeywordHint,
                      isDense: true,
                    ),
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _addKeyword(),
                  ),
                ),
                SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _addKeyword,
                  icon: Icon(Icons.add, size: 18),
                  label: Text(l.add),
                  style: TextButton.styleFrom(
                    foregroundColor: VelvetColors.primary,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _addKeyword() async {
    final w = _keywordCtrl.text.trim();
    if (w.isEmpty) return;
    await AutoDJManager().addKeyword(w);
    _keywordCtrl.clear();
  }

  // ── Section header (mirrors settings_screen.dart) ───────────────

  Widget _sectionHeader(String label) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: VelvetColors.primary,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.6,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Genre picker bottom sheet.
//
// Search-filtered, checkable list. Tapping toggles immediately
// through AutoDJManager (no separate "Done" button — the chips on
// the main screen reflect the live selection state).
// ─────────────────────────────────────────────────────────────────────

class _GenrePickerSheet extends StatefulWidget {
  final List<String> available;
  final bool loading;
  final String? error;
  const _GenrePickerSheet({
    required this.available,
    required this.loading,
    this.error,
  });

  @override
  State<_GenrePickerSheet> createState() => _GenrePickerSheetState();
}

class _GenrePickerSheetState extends State<_GenrePickerSheet> {
  String _query = '';
  StreamSubscription<int>? _mgrSub;

  @override
  void initState() {
    super.initState();
    // Rebuild when AutoDJManager state changes so checkboxes reflect
    // toggle taps live.
    _mgrSub =
        AutoDJManager().changeStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _mgrSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final selected = AutoDJManager().genreFilterValues.toSet();
    final q = _query.trim().toLowerCase();
    final filtered = q.isEmpty
        ? widget.available
        : widget.available
            .where((g) => g.toLowerCase().contains(q))
            .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            // Drag handle
            Container(
              margin: EdgeInsets.only(top: 8),
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: VelvetColors.border2,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l.autoDjPickGenres,
                      style: TextStyle(
                        color: VelvetColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    l.autoDjSelectedCount(selected.length),
                    style: TextStyle(
                        color: VelvetColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                autofocus: false,
                decoration: InputDecoration(
                  hintText: l.autoDjSearchGenres,
                  prefixIcon: Icon(Icons.search),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            SizedBox(height: 8),
            Expanded(child: _buildBody(filtered, selected, scrollController)),
          ],
        );
      },
    );
  }

  Widget _buildBody(List<String> filtered, Set<String> selected,
      ScrollController controller) {
    final l = AppLocalizations.of(context);
    if (widget.loading) {
      return Center(
          child: CircularProgressIndicator(color: VelvetColors.primary));
    }
    if (widget.error != null) {
      return Padding(
        padding: EdgeInsets.all(16),
        child: Text(widget.error!,
            style: TextStyle(color: VelvetColors.error)),
      );
    }
    if (widget.available.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          l.autoDjNoGenresOnServer,
          style: TextStyle(color: VelvetColors.textSecondary),
        ),
      );
    }
    if (filtered.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          l.autoDjNoGenresMatch(_query.trim()),
          style: TextStyle(color: VelvetColors.textSecondary),
        ),
      );
    }
    return ListView.separated(
      controller: controller,
      itemCount: filtered.length,
      separatorBuilder: (_, _) =>
          Divider(color: VelvetColors.border, height: 1),
      itemBuilder: (context, i) {
        final g = filtered[i];
        final on = selected.contains(g);
        return CheckboxListTile(
          dense: true,
          value: on,
          title: Text(g, style: TextStyle(color: VelvetColors.textPrimary)),
          activeColor: VelvetColors.primary,
          checkColor: Colors.white,
          controlAffinity: ListTileControlAffinity.leading,
          onChanged: (v) async {
            if (v == true) {
              await AutoDJManager().addGenre(g);
            } else {
              await AutoDJManager().removeGenre(g);
            }
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────
// Sonic seed picker bottom sheet.
//
// Debounced song search (titles only) against [server], plus a
// "Random song" row for a surprise seed. Pops with the picked
// DisplayItem; the caller stores it via AutoDJManager.setSonicSeed.
// ─────────────────────────────────────────────────────────────────────

class _SonicSeedSheet extends StatefulWidget {
  final Server server;
  const _SonicSeedSheet({required this.server});

  @override
  State<_SonicSeedSheet> createState() => _SonicSeedSheetState();
}

class _SonicSeedSheetState extends State<_SonicSeedSheet> {
  final TextEditingController _ctrl = TextEditingController();
  Timer? _debounce;
  int _reqId = 0;
  bool _loading = false;
  bool _failed = false;
  List<DisplayItem> _results = const [];

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), _search);
  }

  Future<void> _search() async {
    final term = _ctrl.text.trim();
    final rid = ++_reqId;
    if (term.length < 2) {
      setState(() {
        _results = const [];
        _loading = false;
        _failed = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _failed = false;
    });
    final hits = await ApiManager().fetchSongSearch(widget.server, term);
    if (!mounted || rid != _reqId) return;
    setState(() {
      _loading = false;
      _results = hits;
    });
  }

  Future<void> _random() async {
    final rid = ++_reqId;
    setState(() {
      _loading = true;
      _failed = false;
    });
    final item = await ApiManager().fetchRandomSong(widget.server);
    if (!mounted || rid != _reqId) return;
    if (item == null) {
      setState(() {
        _loading = false;
        _failed = true;
      });
      return;
    }
    Navigator.of(context).pop(item);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final term = _ctrl.text.trim();

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Column(
          children: [
            Container(
              margin: EdgeInsets.only(top: 8),
              height: 4,
              width: 40,
              decoration: BoxDecoration(
                color: VelvetColors.border2,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      l.autoDjSonicSeedLabel,
                      style: TextStyle(
                        color: VelvetColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _ctrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l.autoDjSonicSeedSearchHint,
                  isDense: true,
                  prefixIcon:
                      Icon(Icons.search, color: VelvetColors.textSecondary),
                ),
                textInputAction: TextInputAction.search,
                onChanged: _onChanged,
                onSubmitted: (_) => _search(),
              ),
            ),
            // "Surprise me" — one random library song as the seed.
            ListTile(
              dense: true,
              leading: Icon(Icons.casino, color: VelvetColors.primary),
              title: Text(
                l.autoDjSonicSeedRandom,
                style:
                    TextStyle(color: VelvetColors.textPrimary, fontSize: 14),
              ),
              onTap: _random,
            ),
            Divider(color: VelvetColors.border, height: 1),
            Expanded(
              child: _loading
                  ? Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: VelvetColors.primary,
                        ),
                      ),
                    )
                  : _failed
                      ? Center(
                          child: Padding(
                            padding: EdgeInsets.all(24),
                            child: Text(
                              l.autoDjSonicSeedFailed,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: VelvetColors.textSecondary,
                                  fontSize: 13),
                            ),
                          ),
                        )
                      : (_results.isEmpty && term.length >= 2)
                          ? Center(
                              child: Text(
                                l.discoverNothingFound,
                                style: TextStyle(
                                    color: VelvetColors.textSecondary,
                                    fontSize: 13),
                              ),
                            )
                          : ListView.builder(
                              controller: scrollController,
                              itemCount: _results.length,
                              itemBuilder: (context, i) {
                                final item = _results[i];
                                final artist = item.metadata?.artist;
                                return ListTile(
                                  dense: true,
                                  leading: item.getAlbumThumb(size: 40),
                                  title: Text(
                                    item.metadata?.title ?? item.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                        color: VelvetColors.textPrimary,
                                        fontSize: 14),
                                  ),
                                  subtitle: artist == null
                                      ? null
                                      : Text(
                                          artist,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                              color:
                                                  VelvetColors.textSecondary,
                                              fontSize: 12),
                                        ),
                                  onTap: () =>
                                      Navigator.of(context).pop(item),
                                );
                              },
                            ),
            ),
          ],
        );
      },
    );
  }
}
