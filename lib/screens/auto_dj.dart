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

import '../objects/server.dart';
import '../singletons/api.dart';
import '../singletons/auto_dj_manager.dart';
import '../singletons/media.dart';
import '../singletons/server_list.dart';
import '../theme/velvet_theme.dart';

class AutoDJScreen extends StatefulWidget {
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
        _genreLoadError = 'Could not load genres';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ServerManager().serverList.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text('Auto DJ')),
        body: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Add a server first.',
            style: TextStyle(color: VelvetColors.textSecondary),
          ),
        ),
      );
    }

    final enabled = _autoDJServer != null;

    return Scaffold(
      appBar: AppBar(title: Text('Auto DJ')),
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
            _sectionHeader('Server'),
            _serverPickerTile(_autoDJServer!),
            Divider(color: VelvetColors.border, height: 1),
          ],
          if (enabled && _autoDJServer!.autoDJPaths.length > 1) ...[
            _sectionHeader('Sources'),
            ..._vpathTiles(_autoDJServer!),
            Divider(color: VelvetColors.border, height: 1),
          ],
          _sectionHeader('Continuity'),
          _bpmContinuitySection(),
          _harmonicMixingSection(),
          Divider(color: VelvetColors.border, height: 1),
          _sectionHeader('Filters'),
          if (enabled) _minRatingTile(_autoDJServer!),
          _genreFilterSection(),
          _keywordFilterSection(),
        ],
      ),
      ),
    );
  }

  // ── Continuity: BPM + harmonic mixing ───────────────────────────

  Widget _bpmContinuitySection() {
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
                    Text('BPM continuity',
                        style: TextStyle(
                            color: VelvetColors.textPrimary, fontSize: 15)),
                    SizedBox(height: 2),
                    Text(
                      'Prefer picks within a tempo window of the current '
                      'song. Honours half/double-tempo equivalence.',
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
                  'Tolerance',
                  style: TextStyle(
                      color: VelvetColors.textSecondary, fontSize: 13),
                ),
                Spacer(),
                Text(
                  '± ${mgr.bpmTolerance} BPM',
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
    final mgr = AutoDJManager();
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Harmonic mixing',
                    style: TextStyle(
                        color: VelvetColors.textPrimary, fontSize: 15)),
                SizedBox(height: 2),
                Text(
                  'Prefer picks in keys that mix well with the locked '
                  'song (Camelot wheel neighbours).',
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
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            enabled
                ? 'Auto DJ is on'
                : 'Auto DJ is off',
            style: TextStyle(
              color: VelvetColors.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 4),
          Text(
            enabled
                ? 'Songs are picked from ${autoDJServer!.url} when the queue runs low.'
                : "Tap below to start. The current server's library will be used.",
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
            child: Text(enabled ? 'Stop Auto DJ' : 'Start Auto DJ'),
          ),
        ],
      ),
    );
  }

  // ── Server picker (multi-server only, when enabled) ─────────────

  Widget _serverPickerTile(Server autoDJServer) {
    final otherServers = ServerManager()
        .serverList
        .where((s) => s != autoDJServer)
        .toList();
    if (otherServers.isEmpty) {
      return ListTile(
        contentPadding: EdgeInsets.symmetric(horizontal: 20),
        title: Text(autoDJServer.url,
            style: TextStyle(color: VelvetColors.textPrimary)),
        subtitle: Text('Active source',
            style: TextStyle(
                color: VelvetColors.textSecondary, fontSize: 12)),
      );
    }
    return ListTile(
      contentPadding: EdgeInsets.symmetric(horizontal: 20),
      title: Text(autoDJServer.url,
          style: TextStyle(color: VelvetColors.textPrimary)),
      subtitle: Text('Active source — tap to switch',
          style:
              TextStyle(color: VelvetColors.textSecondary, fontSize: 12)),
      trailing: DropdownButton<Server>(
        underline: SizedBox.shrink(),
        hint: Text('Switch', style: TextStyle(color: VelvetColors.primary)),
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
              SnackBar(content: Text('At least one source is required.')),
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
      title: Text('Minimum rating',
          style: TextStyle(color: VelvetColors.textPrimary)),
      subtitle: Text('Only pick songs at or above this rating.',
          style:
              TextStyle(color: VelvetColors.textSecondary, fontSize: 12)),
      trailing: DropdownButton<int?>(
        underline: SizedBox.shrink(),
        dropdownColor: VelvetColors.surface,
        value: autoDJServer.autoDJminRating,
        items: items
            .map((e) => DropdownMenuItem<int?>(
                  value: e.key,
                  child: Text(e.value,
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
                    Text('Genre filter',
                        style: TextStyle(
                            color: VelvetColors.textPrimary, fontSize: 15)),
                    SizedBox(height: 2),
                    Text(
                      'Whitelist plays only matching tracks; '
                      'blacklist skips them.',
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
              segments: const [
                ButtonSegment(value: 'whitelist', label: Text('Whitelist')),
                ButtonSegment(value: 'blacklist', label: Text('Blacklist')),
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
                'No genres selected. Tap "Pick genres" to choose.',
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
                label: Text('Pick genres'),
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
                    Text('Keyword filter',
                        style: TextStyle(
                            color: VelvetColors.textPrimary, fontSize: 15)),
                    SizedBox(height: 2),
                    Text(
                      'Skip picks whose title, artist, album, or filepath '
                      'contains any of these words.',
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
                'No keywords. Add words below to start filtering.',
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
                      hintText: 'e.g. "live" or "remix"',
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
                  label: Text('Add'),
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
                      'Pick genres',
                      style: TextStyle(
                        color: VelvetColors.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    '${selected.length} selected',
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
                  hintText: 'Search genres…',
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
          'No genres found on this server.',
          style: TextStyle(color: VelvetColors.textSecondary),
        ),
      );
    }
    if (filtered.isEmpty) {
      return Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'No genres match "${_query.trim()}".',
          style: TextStyle(color: VelvetColors.textSecondary),
        ),
      );
    }
    return ListView.separated(
      controller: controller,
      itemCount: filtered.length,
      separatorBuilder: (_, __) =>
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
