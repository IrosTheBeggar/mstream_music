import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../objects/listening_stats.dart';
import '../../objects/server.dart';
import '../../singletons/play_history.dart';
import '../../theme/velvet_theme.dart';
import '../../util/server_tree.dart';
import '../../widgets/federation_widgets.dart';
import '../settings_screen.dart';
import 'listening_controller.dart';
import 'listening_widgets.dart';

/// The Listening page (PLAY_HISTORY_PLAN.md §7, the 2026-09-07 design): one
/// scope at a time — this phone's own record, or one server's per-user
/// record — with the same layout for both, so flipping between them is a
/// fair comparison. Everything it shows comes from [ListeningController];
/// the lists and formatters live in listening_widgets.dart.
class ListeningScreen extends StatefulWidget {
  /// Opens on this server's record; null opens on this phone's.
  final Server? server;
  const ListeningScreen({super.key, this.server});

  @override
  State<ListeningScreen> createState() => _ListeningScreenState();
}

class _ListeningScreenState extends State<ListeningScreen>
    with WidgetsBindingObserver {
  late final ListeningController c;

  @override
  void initState() {
    super.initState();
    c = ListeningController(initial: widget.server);
    WidgetsBinding.instance.addObserver(this);
    c.load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    c.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) c.load(quiet: true);
  }

  Future<void> _openSettings() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const SettingsScreen()));
    if (!mounted) return;
    // The history and sync toggles live there; re-read them on the way back.
    c.load(quiet: true);
  }

  Future<void> _showScopeSheet() async {
    final picked = await showModalBottomSheet<ListeningScope>(
      context: context,
      backgroundColor: VelvetColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _ScopeSheet(controller: c),
    );
    if (picked != null) c.setScope(picked);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return ListenableBuilder(
      listenable: c,
      builder: (context, _) => Scaffold(
        appBar: AppBar(
          title: Text(l.listeningTitle),
          actions: [
            IconButton(
              icon: const Icon(Icons.tune),
              tooltip: l.listeningSettings,
              onPressed: _openSettings,
            ),
          ],
        ),
        body: SafeArea(
          top: false,
          child: RefreshIndicator(
            onRefresh: () => c.load(quiet: true),
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 24),
              children: _body(l),
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _body(AppLocalizations l) {
    final out = <Widget>[
      _ScopeRow(controller: c, onInfo: _showScopeSheet),
      const SizedBox(height: 8),
      _Provenance(controller: c),
      const SizedBox(height: 12),
      _PeriodRow(controller: c),
      const SizedBox(height: 12),
    ];
    if (c.loading && c.summary.isEmpty && c.history.isEmpty) {
      out.add(fedLoading());
      return out;
    }
    if (c.error != null) {
      out.add(_ErrorCard(message: c.error!, onRetry: () => c.load()));
      out.add(const SizedBox(height: 10));
    }
    if (c.summary.isEmpty) {
      // An error already explains the blank; the empty copy would contradict it.
      if (c.error == null) out.add(_EmptyCard(controller: c));
      out.add(_footer(l));
      return out;
    }
    out.addAll([
      _Tiles(summary: c.summary),
      FedSection(l.listeningWhenYouListen),
      _HoursCard(hours: c.hours, peakHour: c.summary.peakHour),
      FedSection(l.listeningTop),
      ListeningTopCard(controller: c),
      FedSection(l.listeningRecent),
      ListeningRecentCard(controller: c),
      _footer(l),
    ]);
    return out;
  }

  Widget _footer(AppLocalizations l) => Padding(
        padding: const EdgeInsets.only(top: 16),
        child: FedCard(children: [
          FedRow(
            icon: Icons.history,
            title: l.listeningSettings,
            trailing: fedChevron(),
            onTap: _openSettings,
          ),
        ]),
      );
}

// ── scope ─────────────────────────────────────────────────────────────

/// The scope a chip or sheet row stands for: [Server.statsServer] answers,
/// the picked server labels it (a peer counts on its parent).
ListeningScope _scopeFor(Server s) =>
    ListeningScope.server(s.statsServer ?? s, picked: s);

bool _isPicked(ListeningScope scope, Server s) =>
    !scope.isDevice &&
    (scope.picked ?? scope.server)?.localname == s.localname;

/// A peer's label carries the branch glyph the server list draws it with.
String _serverLabel(Server s) =>
    s.isFederated ? '$kPeerBranch ${s.displayName}' : s.displayName;

class _ScopeRow extends StatelessWidget {
  final ListeningController controller;
  final VoidCallback onInfo;
  const _ScopeRow({required this.controller, required this.onInfo});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = controller;
    return Row(children: [
      Expanded(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(children: [
            _ScopePill(
              l.listeningScopeThisPhone,
              selected: c.scope.isDevice,
              onTap: () => c.setScope(const ListeningScope.device()),
            ),
            for (final s in c.servers) ...[
              const SizedBox(width: 6),
              _ScopePill(
                _serverLabel(s),
                selected: _isPicked(c.scope, s),
                onTap: () => c.setScope(_scopeFor(s)),
              ),
            ],
          ]),
        ),
      ),
      IconButton(
        icon: Icon(Icons.info_outline,
            size: 20, color: VelvetColors.textTertiary),
        tooltip: l.listeningScopeSheetTitle,
        visualDensity: VisualDensity.compact,
        onPressed: onInfo,
      ),
    ]);
  }
}

/// A scope pill: filled with the accent when it is the one showing.
class _ScopePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ScopePill(this.label, {required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? VelvetColors.primary : VelvetColors.raised,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          height: 30,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(label,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: selected
                        ? VelvetColors.onPrimary
                        : VelvetColors.textSecondary)),
          ]),
        ),
      ),
    );
  }
}

/// What to show: one row per scope with a line on where its numbers come
/// from. Pops with the picked scope.
class _ScopeSheet extends StatelessWidget {
  final ListeningController controller;
  const _ScopeSheet({required this.controller});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = controller;
    String serverNote(Server s) {
      if (!c.serverHasStats(s)) return l.listeningScopeSheetLegacy;
      if (s.isFederated) {
        return l.listeningScopeSheetPeer(
            s.parentServer?.displayName ?? s.federationParent ?? '');
      }
      return l.listeningScopeSheetServer;
    }

    final rows = <Widget>[
      _sheetRow(context,
          icon: Icons.smartphone,
          title: l.listeningScopeThisPhone,
          subtitle: l.listeningScopeSheetDevice,
          selected: c.scope.isDevice,
          scope: const ListeningScope.device()),
      for (final s in c.servers)
        _sheetRow(context,
            icon: s.isFederated ? Icons.hub_outlined : Icons.dns_outlined,
            title: _serverLabel(s),
            subtitle: serverNote(s),
            selected: _isPicked(c.scope, s),
            scope: _scopeFor(s)),
    ];
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 18, 14, 6),
              child: Text(l.listeningScopeSheetTitle,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: VelvetColors.textPrimary)),
            ),
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0)
                Divider(
                    height: 1,
                    thickness: 1,
                    indent: 66,
                    endIndent: 14,
                    color: VelvetColors.border),
              rows[i],
            ],
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _sheetRow(BuildContext context,
      {required IconData icon,
      required String title,
      required String subtitle,
      required bool selected,
      required ListeningScope scope}) {
    return FedRow(
      icon: icon,
      iconColor: selected ? VelvetColors.primary : VelvetColors.textTertiary,
      title: title,
      subtitle: subtitle,
      subtitleLines: 3,
      trailing: selected
          ? Icon(Icons.check, color: VelvetColors.primary, size: 22)
          : null,
      onTap: () => Navigator.of(context).pop(scope),
    );
  }
}

// ── provenance, period ────────────────────────────────────────────────

/// Where the numbers come from, the unsynced count, and the history-off
/// note for the device.
class _Provenance extends StatelessWidget {
  final ListeningController controller;
  const _Provenance({required this.controller});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = controller;
    final scope = c.scope;
    final String line;
    if (scope.isDevice) {
      line = l.listeningProvenanceDevice;
    } else {
      final answering = scope.server!.displayName;
      final picked = (scope.picked ?? scope.server)!.displayName;
      if (c.legacy) {
        line = l.listeningProvenanceLegacy(picked);
      } else if (c.fellBack) {
        line = l.listeningProvenanceFallback(answering);
      } else if (scope.isPeer) {
        line = l.listeningProvenancePeer(picked, answering);
      } else {
        line = l.listeningProvenanceServer(answering);
      }
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(line,
            style: TextStyle(
                fontSize: 12, height: 1.35, color: VelvetColors.textSecondary)),
        if (c.unsynced > 0)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(l.listeningUnsynced(c.unsynced),
                style: TextStyle(fontSize: 12, color: VelvetColors.warning)),
          ),
        if (scope.isDevice && !c.historyEnabled)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: FedNote(l.listeningHistoryOff,
                icon: Icons.history_toggle_off),
          ),
      ]),
    );
  }
}

class _PeriodRow extends StatelessWidget {
  final ListeningController controller;
  const _PeriodRow({required this.controller});

  static String _label(AppLocalizations l, StatsPeriod p) => switch (p) {
        StatsPeriod.week => l.listeningPeriodWeek,
        StatsPeriod.month => l.listeningPeriodMonth,
        StatsPeriod.quarter => l.listeningPeriodQuarter,
        StatsPeriod.year => l.listeningPeriodYear,
        StatsPeriod.all => l.listeningPeriodAll,
      };

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = controller;
    const periods = StatsPeriod.values;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: [
        for (var i = 0; i < periods.length; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          FedChip(_label(l, periods[i]),
              selected: c.period == periods[i],
              onTap: () => c.setPeriod(periods[i])),
        ],
      ]),
    );
  }
}

// ── summary tiles ─────────────────────────────────────────────────────

class _Tiles extends StatelessWidget {
  final ListeningSummary summary;
  const _Tiles({required this.summary});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final s = summary;
    final fmt = NumberFormat.decimalPattern(
        Localizations.localeOf(context).toString());
    final rate = s.skipRate;
    final avg = s.sessionAvgMs;
    final tiles = <(String, String, String?)>[
      (l.listeningTilePlays, fmt.format(s.plays), l.listeningTileSubCounted),
      (l.listeningTileTime, listeningDuration(s.listenedMs), null),
      (
        l.listeningTileTracks,
        fmt.format(s.uniqueTracks),
        l.listeningTileSubTracks
      ),
      (
        l.listeningTileSkips,
        fmt.format(s.skips),
        rate == null ? null : l.listeningTileSubSkips((rate * 100).round())
      ),
      (
        l.listeningTileStreak,
        l.listeningDays(s.streakCurrent),
        l.listeningTileSubStreak(s.streakLongest)
      ),
      (
        l.listeningTileSessions,
        fmt.format(s.sessions),
        avg == null
            ? null
            : l.listeningTileSubSessions(listeningDuration(avg))
      ),
    ];
    return Column(children: [
      for (var i = 0; i + 1 < tiles.length; i += 2)
        Padding(
          padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
          child: IntrinsicHeight(
            child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Expanded(child: _Tile(tiles[i])),
              const SizedBox(width: 8),
              Expanded(child: _Tile(tiles[i + 1])),
            ]),
          ),
        ),
    ]);
  }
}

class _Tile extends StatelessWidget {
  final (String, String, String?) data;
  const _Tile(this.data);

  @override
  Widget build(BuildContext context) {
    final (label, value, sub) = data;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      decoration: BoxDecoration(
        color: VelvetColors.raised,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
                color: VelvetColors.textSecondary)),
        const SizedBox(height: 4),
        Text(value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                height: 1.1,
                color: VelvetColors.textPrimary)),
        if (sub != null)
          Padding(
            padding: const EdgeInsets.only(top: 3),
            child: Text(sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: VelvetColors.textDim)),
          ),
      ]),
    );
  }
}

// ── when you listen ───────────────────────────────────────────────────

/// Twenty-four thin bars, the peak hour in the accent, a note naming it.
class _HoursCard extends StatelessWidget {
  final List<int> hours;
  final int? peakHour;
  const _HoursCard({required this.hours, required this.peakHour});

  static const _labelled = {0, 6, 12, 18, 23};

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final max = hours.fold<int>(0, (m, v) => v > m ? v : m);
    return FedCard(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          SizedBox(
            height: 64,
            child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              for (var h = 0; h < hours.length; h++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1.5),
                    child: Container(
                      height: max == 0 ? 2 : 2 + 62 * hours[h] / max,
                      decoration: BoxDecoration(
                        color: hours[h] == 0
                            ? VelvetColors.primary.withValues(alpha: 0.25)
                            : h == peakHour
                                ? VelvetColors.accent
                                : VelvetColors.primary,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
            ]),
          ),
          const SizedBox(height: 6),
          Row(children: [
            for (var h = 0; h < hours.length; h++)
              Expanded(
                child: Text(_labelled.contains(h) ? '$h' : '',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 10, color: VelvetColors.textTertiary)),
              ),
          ]),
          if (peakHour != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(l.listeningMostAround(listeningHour(peakHour!)),
                  style: TextStyle(
                      fontSize: 12, color: VelvetColors.textSecondary)),
            ),
        ]),
      ),
    ]);
  }
}

// ── states ────────────────────────────────────────────────────────────

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return FedCard(children: [
      FedRow(
        icon: Icons.cloud_off_outlined,
        iconColor: VelvetColors.error,
        title: l.listeningError(message),
        titleLines: 3,
        titleSize: 13,
        trailing: FedButton(l.listeningRetry,
            kind: FedButtonKind.text,
            height: 36,
            fontSize: 14,
            onPressed: onRetry),
      ),
    ]);
  }
}

class _EmptyCard extends StatelessWidget {
  final ListeningController controller;
  const _EmptyCard({required this.controller});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = controller;
    final scope = c.scope;
    final narrowed = c.period != StatsPeriod.all;
    final String copy;
    if (scope.isDevice) {
      // A narrowed period only explains the blank once the phone has
      // recorded anything at all; a fresh install gets the onboarding line.
      copy = narrowed && !PlayHistory().stats.isEmpty
          ? l.listeningEmptyPeriod
          : l.listeningEmptyDevice;
    } else {
      copy = narrowed
          ? l.listeningEmptyPeriod
          : l.listeningEmptyServer(
              (scope.picked ?? scope.server)!.displayName);
    }
    return FedCard(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(20, 26, 20, 26),
        child: Column(children: [
          FedTile(Icons.headphones_outlined,
              size: 52, color: VelvetColors.textTertiary),
          const SizedBox(height: 14),
          Text(l.listeningEmptyTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: VelvetColors.textPrimary)),
          const SizedBox(height: 6),
          Text(copy,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: VelvetColors.textSecondary)),
        ]),
      ),
    ]);
  }
}
