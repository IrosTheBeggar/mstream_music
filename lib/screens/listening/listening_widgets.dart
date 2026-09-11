import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../objects/listening_stats.dart';
import '../../objects/play_event.dart';
import '../../objects/server.dart';
import '../../singletons/server_list.dart';
import '../../theme/velvet_theme.dart';
import '../../util/image_cache.dart';
import '../../util/stream_url.dart';
import '../../widgets/federation_widgets.dart';
import 'listening_controller.dart';

/// The Listening page's lists — the Top card and the Recent plays card, one
/// row shape each — and the formatters the whole page shares (durations,
/// positions, clock times, day labels). Everything reads through
/// [ListeningController]; nothing here talks to a server.

// ── formatters ────────────────────────────────────────────────────────

/// "44 min" under an hour, then "4h 53m"; a whole hour drops the minutes.
String listeningDuration(int ms) {
  final minutes = (ms / 60000).round();
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60;
  final m = minutes % 60;
  return m == 0 ? '${h}h' : '${h}h ${m}m';
}

/// "1:20" — a position inside a track.
String listeningClock(int ms) {
  final s = ms ~/ 1000;
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// "20:13", local time.
String listeningTime(DateTime t) {
  final l = t.toLocal();
  return '${l.hour.toString().padLeft(2, '0')}:'
      '${l.minute.toString().padLeft(2, '0')}';
}

/// "20:00" for an hour-of-day bucket.
String listeningHour(int h) => '${h.toString().padLeft(2, '0')}:00';

/// Today / Yesterday / "Sep 8" / "Sep 8, 2025", relative to [now].
String listeningDayLabel(BuildContext context, DateTime t, DateTime now) {
  final l = AppLocalizations.of(context);
  final d = t.toLocal();
  final n = now.toLocal();
  final days = DateTime(n.year, n.month, n.day)
      .difference(DateTime(d.year, d.month, d.day))
      .inDays;
  if (days == 0) return l.listeningToday;
  if (days == 1) return l.listeningYesterday;
  final ml = MaterialLocalizations.of(context);
  return d.year == n.year ? ml.formatShortMonthDay(d) : ml.formatShortDate(d);
}

/// "mstream-webapp" out of "mstream-webapp/6.27.0".
String _clientName(String client) {
  final name = client.split('/').first.trim();
  return name.isEmpty ? client : name;
}

// ── art ───────────────────────────────────────────────────────────────

/// The server a row's art lives on. A device-scope row names its own
/// server; a server-scope row belongs to the picked server — or, for a
/// peer's track listed under its parent, to the peer record carrying that
/// name, so the art rides the parent's proxy the way playback does.
Server? _rowServer(ListeningController c, String? localname,
    {bool fromPeer = false, String? peerName}) {
  if (localname != null) return ServerManager().byLocalname(localname);
  if (c.scope.isDevice) return null;
  final base = c.scope.picked ?? c.scope.server;
  if (base == null) return null;
  if (fromPeer && peerName != null && !base.isFederated) {
    for (final s in ServerManager().serverList) {
      if (s.isFederated &&
          s.federationParent == base.localname &&
          s.displayName == peerName) {
        return s;
      }
    }
  }
  return base;
}

class _ArtTile extends StatelessWidget {
  final Server? server;
  final String? artFile;
  final IconData icon;
  const _ArtTile(
      {required this.server, required this.artFile, required this.icon});

  @override
  Widget build(BuildContext context) {
    final s = server;
    final art = artFile;
    if (s == null || art == null) return FedTile(icon);
    return ClipRRect(
      borderRadius: BorderRadius.circular(VelvetColors.radiusSmall),
      child: Image.network(
        buildAlbumArtUrl(s, art),
        width: 40,
        height: 40,
        fit: BoxFit.cover,
        cacheWidth: artCacheSize(40),
        errorBuilder: (_, _, _) => FedTile(icon),
      ),
    );
  }
}

// ── top ───────────────────────────────────────────────────────────────

/// Tracks / Artists / Albums by plays or by time: the entity chips, the
/// smaller metric pair, then up to ten ranked rows.
class ListeningTopCard extends StatelessWidget {
  final ListeningController controller;
  const ListeningTopCard({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = controller;
    final entities = [
      ('tracks', l.listeningTopTracks),
      ('artists', l.listeningTopArtists),
      ('albums', l.listeningTopAlbums),
    ];
    return FedCard(children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
        child: Row(children: [
          Expanded(
            child: Wrap(spacing: 6, runSpacing: 6, children: [
              for (final (id, label) in entities)
                FedChip(label,
                    selected: c.topEntity == id,
                    onTap: () => c.setTop(entity: id)),
            ]),
          ),
          const SizedBox(width: 8),
          _MetricToggle(
              metric: c.topMetric, onChanged: (m) => c.setTop(metric: m)),
        ]),
      ),
      if (c.top.isEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 8, 6, 12),
          child: FedHint(l.listeningEmptyPeriod),
        ),
      for (final t in c.top) _TopRow(item: t, controller: c),
    ]);
  }
}

/// Plays | Time — the smaller pair beside the entity chips.
class _MetricToggle extends StatelessWidget {
  final String metric;
  final ValueChanged<String> onChanged;
  const _MetricToggle({required this.metric, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    Widget option(String id, String label) {
      final on = metric == id;
      return InkWell(
        onTap: () => onChanged(id),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
          decoration: BoxDecoration(
            color: on ? VelvetColors.primaryDim : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(label,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color:
                      on ? VelvetColors.primary : VelvetColors.textTertiary)),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: VelvetColors.raised,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        option('plays', l.listeningByPlays),
        option('time', l.listeningByTime),
      ]),
    );
  }
}

class _TopRow extends StatelessWidget {
  final TopItem item;
  final ListeningController controller;
  const _TopRow({required this.item, required this.controller});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = controller;
    final t = item;
    final entity = c.topEntity;
    final icon = switch (entity) {
      'artists' => Icons.person,
      'albums' => Icons.album,
      _ => Icons.music_note,
    };
    var sub =
        entity == 'artists' ? l.listeningTracksCount(t.tracks) : t.subtitle;
    if (t.fromPeer && t.peerName != null) {
      final via = l.listeningVia(t.peerName!);
      sub = sub == null ? via : '$sub · $via';
    }
    final value = c.topMetric == 'time'
        ? listeningDuration(t.listenedMs)
        : l.listeningPlays(t.plays);
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 9, 14, 9),
      child: Row(children: [
        SizedBox(
          width: 22,
          child: Text('${t.rank}',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: VelvetColors.textDim)),
        ),
        _ArtTile(
          server: entity == 'artists'
              ? null
              : _rowServer(c, t.server,
                  fromPeer: t.fromPeer, peerName: t.peerName),
          artFile: t.artFile,
          icon: icon,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(t.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: VelvetColors.textPrimary)),
              ),
              const SizedBox(width: 8),
              Text(value,
                  style: TextStyle(
                      fontSize: 13, color: VelvetColors.textSecondary)),
            ]),
            if (sub != null)
              Text(sub,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12, color: VelvetColors.textSecondary)),
            const SizedBox(height: 6),
            _ShareBar(t.share),
          ]),
        ),
      ]),
    );
  }
}

/// The row's share of the period, as a hairline under its text.
class _ShareBar extends StatelessWidget {
  final double share;
  const _ShareBar(this.share);

  @override
  Widget build(BuildContext context) {
    final factor = share.isFinite ? share.clamp(0.0, 1.0).toDouble() : 0.0;
    return SizedBox(
      height: 3,
      width: double.infinity,
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: factor,
          child: Container(
            decoration: BoxDecoration(
              color: VelvetColors.primary.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }
}

// ── recent plays ──────────────────────────────────────────────────────

/// Newest first, repeats folded into one row with a badge; a Load more
/// button while the server has older pages.
class ListeningRecentCard extends StatelessWidget {
  final ListeningController controller;
  const ListeningRecentCard({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = controller;
    return FedCard(children: [
      if (c.history.isEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(6, 10, 6, 12),
          child: FedHint(l.listeningEmptyPeriod),
        ),
      for (final h in c.history) _HistoryRow(item: h, controller: c),
      if (c.hasMore)
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 8),
          child: FedButton(l.listeningLoadMore,
              kind: FedButtonKind.text,
              height: 40,
              fontSize: 14,
              busy: c.loadingMore,
              onPressed: c.loadMoreHistory),
        ),
    ]);
  }
}

class _HistoryRow extends StatelessWidget {
  final HistoryItem item;
  final ListeningController controller;
  const _HistoryRow({required this.item, required this.controller});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final c = controller;
    final h = item;
    final parts = <String>[
      if (h.artist != null) h.artist! else if (h.isLocalFile) l.listeningLocalFile,
      if (h.fromPeer && h.peerName != null) l.listeningVia(h.peerName!),
      if (!c.scope.isDevice && h.client != null) _clientName(h.client!),
    ];
    final (dot, outcome) = switch (h.outcome) {
      PlayOutcome.completed => (
          VelvetColors.success,
          l.listeningOutcomeCompleted,
        ),
      PlayOutcome.skipped => (
          VelvetColors.warning,
          l.listeningOutcomeAt(
              l.listeningOutcomeSkipped, listeningClock(h.playedMs)),
        ),
      PlayOutcome.stopped => (
          VelvetColors.textTertiary,
          l.listeningOutcomeAt(
              l.listeningOutcomeStopped, listeningClock(h.playedMs)),
        ),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
          width: 56,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(listeningTime(h.startedAt),
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: VelvetColors.textPrimary)),
            Text(listeningDayLabel(context, h.startedAt, c.now()),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 11, color: VelvetColors.textDim)),
          ]),
        ),
        _ArtTile(
          server: _rowServer(c, h.server,
              fromPeer: h.fromPeer, peerName: h.peerName),
          artFile: h.artFile,
          icon: Icons.music_note,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(h.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: VelvetColors.textPrimary)),
              ),
              if (h.repeats > 1) ...[
                const SizedBox(width: 6),
                _Badge(l.listeningRepeats(h.repeats)),
              ],
            ]),
            if (parts.isNotEmpty)
              Text(parts.join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontSize: 12, color: VelvetColors.textSecondary)),
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Row(children: [
                Container(
                    width: 8,
                    height: 8,
                    decoration:
                        BoxDecoration(color: dot, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Flexible(
                  child: Text.rich(
                    TextSpan(text: outcome, children: [
                      if (!h.counted)
                        TextSpan(
                            text: ' · ${l.listeningNotCounted}',
                            style: TextStyle(color: VelvetColors.textDim)),
                    ]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 12, color: VelvetColors.textSecondary),
                  ),
                ),
              ]),
            ),
          ]),
        ),
      ]),
    );
  }
}

/// The ×N repeat badge on a folded history row.
class _Badge extends StatelessWidget {
  final String label;
  const _Badge(this.label);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: VelvetColors.primaryDim,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: VelvetColors.primary)),
      );
}
