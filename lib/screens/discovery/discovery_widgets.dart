import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../objects/discovery.dart';
import '../../objects/display_item.dart';
import '../../singletons/browser_list.dart';
import '../../theme/velvet_theme.dart';
import '../../util/queue_actions.dart';
import '../../util/stream_url.dart';
import '../../util/image_cache.dart';
import '../../widgets/federation_widgets.dart';
import '../../widgets/track_actions_sheet.dart';
import '../discover_screen.dart' show MatchMeter;
import 'discovery_page_controller.dart';

/// The Discover page's rows, cards and formatters, shared by the page
/// (discovery_page.dart) and its "See all" lists (discovery_source_list.dart).
/// Colours come from VelvetColors only; the theme's primary drives every
/// control and no source gets a colour of its own (the canvas's plug-ins
/// decision) — sources are told apart by their headers.

// ── formatters ──────────────────────────────────────────────────────────

/// "30 days" / "All time" for a taste window (days; 0 = all time).
String discoveryWindowLabel(AppLocalizations l, int window) =>
    window <= 0 ? l.discoverPageWindowAll : l.discoverPageWindowDays(window);

/// A calendar-day relative time: today, yesterday, N days, then months, then
/// years — the "last played 8 months ago" scale, which fmtAgo (minutes to a
/// short date) does not cover.
String discoveryAgo(AppLocalizations l, DateTime when, DateTime now) {
  final a = when.toLocal();
  final b = now.toLocal();
  final days = (DateTime(b.year, b.month, b.day)
              .difference(DateTime(a.year, a.month, a.day))
              .inHours /
          24)
      .round();
  if (days <= 0) return l.discoverPageAgoToday;
  if (days == 1) return l.discoverPageAgoYesterday;
  if (days < 30) return l.agoDays(days);
  // 30-day months reach 12 at day 360, a few days before 365 does: from
  // there it is "1 year ago", never "12 months ago".
  final months = days ~/ 30;
  if (months < 12) return l.discoverPageAgoMonths(months);
  final years = days ~/ 365;
  return l.discoverPageAgoYears(years < 1 ? 1 : years);
}

/// "never played" / "last played 8 months ago" for a library row; null when
/// the server did not say (a claim the page will not make for it).
String? discoveryPlayLabel(AppLocalizations l, TasteTrack t, DateTime now) {
  if (t.playCount == 0) return l.discoverPageNeverPlayed;
  final last = t.lastPlayed;
  if (last != null) return l.discoverPageLastPlayed(discoveryAgo(l, last, now));
  return null;
}

/// The album card's third line: "never played", "2 of 12 played", or the
/// song count when the server gave no play facts.
String? discoveryAlbumLabel(AppLocalizations l, TasteAlbum a) {
  if (a.unplayed) return l.discoverPageNeverPlayed;
  final played = a.playedTracks;
  final total = a.scopedTracks ?? a.trackCount;
  if (played != null && total != null && total > 0) {
    return l.discoverPageAlbumPlayed(played, total);
  }
  if (a.trackCount != null) return l.discoverPageSongsCount(a.trackCount!);
  return null;
}

/// The app-bar subtitle: what the page is seeded from (plan §2.1–§2.2).
/// "finished" only when every history seed was played to the end; a seed
/// that was stopped past half makes it "listened to".
String? discoverySubtitle(AppLocalizations l, TasteResponse? r) {
  if (r == null) return null;
  if (r.seedSource == TasteSeedSource.random || r.fallback) {
    return l.discoverPageSubRandom;
  }
  if (r.seedSource == TasteSeedSource.pinned) return l.discoverPageSubPinned;
  if (r.seedSource == TasteSeedSource.counters) {
    return l.discoverPageSubCounters;
  }
  final history = r.seeds.where((s) => !s.pinned).toList();
  if (history.isEmpty) {
    return r.seeds.isEmpty ? null : l.discoverPageSubPinned;
  }
  final window = discoveryWindowLabel(l, r.window ?? kTasteDefaultWindow);
  return history.any((s) => s.outcome == 'stopped')
      ? l.discoverPageSubListened(history.length, window)
      : l.discoverPageSubFinished(history.length, window);
}

/// No seed is analyzed yet (the scan is pending). The server then answers
/// every source it was asked for EMPTY — on purpose, so a client never hides
/// an advertised source while a scan runs (discovery-taste.js) — and each
/// source's own empty line ("nothing matches", "warming up", "no peers")
/// would blame the wrong thing: this line names the scan instead.
bool discoveryScanWaiting(DiscoveryPageController c) =>
    c.seeded?.notAnalyzed == true;

/// The network source's one line when it has no rows: the scan, then the
/// P2P shelf still filling (nothing searched), then a plain "no match".
String discoveryNetworkEmptyLine(
    AppLocalizations l, DiscoveryPageController c, TasteLeads net) {
  if (discoveryScanWaiting(c)) return l.discoverPageScanWaiting;
  return net.searchedPeers == 0
      ? l.discoverNetworkWarmingUp
      : l.discoverPageNetworkEmpty;
}

// ── actions ─────────────────────────────────────────────────────────────

void discoveryToast(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(message),
    behavior: SnackBarBehavior.floating,
  ));
}

/// A network row's tap (v1 has no plug-in verbs on mobile, plan §4.2):
/// copy "Artist - Title", as DiscoverScreen's lead rows do.
Future<void> discoveryCopyLead(BuildContext context, DiscoveryLead lead) async {
  final l = AppLocalizations.of(context);
  await Clipboard.setData(ClipboardData(text: lead.copyText));
  if (context.mounted) discoveryToast(context, l.discoverLeadCopied);
}

Future<void> discoveryOpenMusicBrainz(
    BuildContext context, DiscoveryLead lead) async {
  final mbid = lead.recordingMbid;
  if (mbid == null) return;
  final url = 'https://musicbrainz.org/recording/$mbid';
  final ok =
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    discoveryToast(context, AppLocalizations.of(context).couldNotOpen(url));
  }
}

/// A library song tapped: the user's tap behaviour over the whole list
/// (play from here / append and jump / add), as every browse list does.
Future<void> discoveryTapTrack(
    BuildContext context, List<DisplayItem> rows, int index) async {
  final l = AppLocalizations.of(context);
  if (await handleTrackTap(rows, index) && context.mounted) {
    discoveryToast(context, l.browserSongsAdded(1));
  }
}

void discoveryTrackActions(BuildContext context, DisplayItem row) =>
    showTrackActionsSheet(context, row);

/// A library row's inline "next" (plan §1: Library = inline play / queue /
/// next + track-actions): after the current track, playback untouched.
Future<void> discoveryQueueNext(BuildContext context, DisplayItem row) async {
  final l = AppLocalizations.of(context);
  if (await addNext(row) != null && context.mounted) {
    discoveryToast(context, l.browserSongsAdded(1));
  }
}

/// A library row's inline "queue": the end of the queue, without playing.
Future<void> discoveryQueueEnd(BuildContext context, DisplayItem row) async {
  final l = AppLocalizations.of(context);
  await addToQueueEnd(row);
  if (context.mounted) discoveryToast(context, l.browserSongsAdded(1));
}

Future<void> discoveryQueueAll(
    BuildContext context, List<DisplayItem> rows) async {
  final l = AppLocalizations.of(context);
  final n = await addRowsToQueue(rows);
  if (n > 0 && context.mounted) discoveryToast(context, l.browserSongsAdded(n));
}

/// An album card opens the album detail. That view lives in the root
/// route's body (main.dart's IndexedStack, so the browser toolbar's Play /
/// Shuffle / Add and the mini-player stay with it), not in a route of its
/// own — so the page steps back to the root first. Coming back is free: the
/// visit is cached for kDiscoveryPageTtl.
void discoveryOpenAlbum(BuildContext context, DisplayItem album) {
  Navigator.of(context).popUntil((r) => r.isFirst);
  BrowserManager().openAlbumDetail(album);
}

/// A peers row's play action: now, through the parent's federation stream
/// proxy (plan §1: peers rows are playable, never a plug-in). A row whose
/// peer the app has not mirrored yet says so instead of failing silently;
/// a row with no peer path cannot play at all.
VoidCallback? discoveryPeerPlay(
    BuildContext context, DiscoveryPageController c, DiscoveryLead lead) {
  if (lead.filepath == null) return null;
  final row = c.peerTrackItem(lead);
  if (row == null) {
    return () => discoveryToast(
        context, AppLocalizations.of(context).discoverPagePeerNotReady);
  }
  return () => playNow(row);
}

/// A peers row's queue button (or long-press): append it to the queue.
/// Null for a row that cannot play (see [discoveryPeerPlay]).
VoidCallback? discoveryPeerQueue(
    BuildContext context, DiscoveryPageController c, DiscoveryLead lead) {
  final row = c.peerTrackItem(lead);
  if (row == null) return null;
  return () async {
    final l = AppLocalizations.of(context);
    await addToQueueEnd(row);
    if (context.mounted) discoveryToast(context, l.browserSongsAdded(1));
  };
}

/// The peers source's groups and its one-line empty states — shared with
/// the "See all" list.
List<Widget> discoveryPeerGroups(
    BuildContext context, DiscoveryPageController c, TastePeers p,
    {int? maxRows}) {
  final l = AppLocalizations.of(context);
  if (discoveryScanWaiting(c) && p.allResults.isEmpty) {
    return [DiscoveryHint(l.discoverPageScanWaiting)];
  }
  if (p.peers.isEmpty) return [DiscoveryHint(l.discoverPageNoPeers)];
  final out = <Widget>[
    for (final g in p.peers)
      // A reachable peer with nothing to offer is noise; an offline or
      // mismatched one is state the user should see.
      if (g.results.isNotEmpty || !g.reachable || g.mismatched)
        DiscoveryPeerGroup(
          group: g,
          maxRows: maxRows,
          playable: (lead) => c.peerTrackItem(lead) != null,
          onPlay: (lead) => discoveryPeerPlay(context, c, lead),
          onQueue: (lead) => discoveryPeerQueue(context, c, lead),
        ),
  ];
  if (p.allResults.isEmpty) {
    out.add(DiscoveryHint(p.peers.every((g) => !g.reachable)
        ? l.discoverPeersUnreachable
        : l.discoverPagePeersEmpty));
  }
  return out;
}

/// The "Not in N days" threshold the chip names: the route's default
/// staleDays (plan §2.5). The page never changes it, and a value saved by
/// another client is not read back here.
const int kDiscoveryStaleDays = 90;

// ── layout ──────────────────────────────────────────────────────────────

/// The tap-target floor for every control the page adds (44 px; Apple's
/// HIG and the Material 48 dp padded target both clear it).
const double kDiscoveryTapTarget = 44;

/// A [kDiscoveryTapTarget]-tall hit area around a smaller visual control,
/// the way Material pads a dense button's tap target: the control keeps its
/// canvas height and a tap in the band above or below it still lands. The
/// inner InkWell wins taps on the visual itself (the deepest recognizer is
/// first in the arena), so its ink still shows there.
class _HitArea extends StatelessWidget {
  final VoidCallback? onTap;
  final Widget child;
  const _HitArea({required this.onTap, required this.child});

  @override
  Widget build(BuildContext context) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: kDiscoveryTapTarget),
          // Factors of 1: as tall as the floor and as wide as the control,
          // never stretched to the parent (a Wrap would lay one per row).
          child: Center(widthFactor: 1, heightFactor: 1, child: child),
        ),
      );
}

/// A compact icon button with a [kDiscoveryTapTarget] square hit area.
Widget discoveryIconButton({
  required IconData icon,
  required String tooltip,
  required VoidCallback? onPressed,
  Color? color,
  double size = 22,
}) =>
    IconButton(
      icon: Icon(icon, color: color ?? VelvetColors.textSecondary, size: size),
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints.tightFor(
          width: kDiscoveryTapTarget, height: kDiscoveryTapTarget),
      tooltip: tooltip,
      onPressed: onPressed,
    );

/// The canvas's section header: uppercase title, a quiet count / state, and
/// a "See all" link on the right.
class DiscoverySectionHeader extends StatelessWidget {
  final String title;
  final String? meta;
  final VoidCallback? onSeeAll;

  /// The link's label; "See all" by default ("Edit" over the seeds).
  final String? actionLabel;
  final bool first;
  const DiscoverySectionHeader(this.title,
      {super.key,
      this.meta,
      this.onSeeAll,
      this.actionLabel,
      this.first = false});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(16, first ? 10 : 18, 4, 4),
      child: Row(
        children: [
          Expanded(
            child: Row(
              children: [
                Flexible(
                  flex: 3,
                  child: Text(
                    title.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: VelvetColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                    ),
                  ),
                ),
                if (meta != null && meta!.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    flex: 2,
                    child: Text(
                      meta!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: VelvetColors.textTertiary, fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onSeeAll != null)
            // Standard density: the padded 48 px target (compact would cut
            // it to 40, under the floor).
            TextButton(
              onPressed: onSeeAll,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
              child: Text(
                actionLabel ?? l.discoverPageSeeAll,
                style: TextStyle(
                  color: VelvetColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else
            // The link's height, so a header reads the same with or
            // without one.
            const SizedBox(height: 48),
        ],
      ),
    );
  }
}

/// "A source with nothing → one italic line".
class DiscoveryHint extends StatelessWidget {
  final String text;
  const DiscoveryHint(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: Text(
          text,
          style: TextStyle(
            color: VelvetColors.textSecondary,
            fontSize: 13,
            height: 1.35,
            fontStyle: FontStyle.italic,
          ),
        ),
      );
}

Widget discoveryLoadingRow() => SizedBox(
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

/// The match percentage pinned to a cover's corner (the canvas's badge).
class DiscoveryMatchBadge extends StatelessWidget {
  final double similarity;
  final double fontSize;
  const DiscoveryMatchBadge(this.similarity, {super.key, this.fontSize = 10});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(
          color: VelvetColors.bg,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: VelvetColors.border),
        ),
        child: Text(
          '${(similarity * 100).round()}%',
          style: TextStyle(
            color: VelvetColors.primary,
            fontSize: fontSize,
            fontWeight: FontWeight.w700,
            height: 1.2,
          ),
        ),
      );
}

/// A library song: art with its match badge, title, artist · play facts,
/// the inline next / queue verbs and the track-actions ⋮ (rate, playlist,
/// go to album, more like this) — plan §1's Library verbs. The tap is the
/// caller's (the user's tap behaviour over the whole list), which is the
/// inline play.
class DiscoveryTrackRow extends StatelessWidget {
  final DisplayItem row;
  final TasteTrack track;
  final DateTime now;
  final VoidCallback onTap;
  final VoidCallback onNext;
  final VoidCallback onQueue;
  final VoidCallback onMore;
  const DiscoveryTrackRow({
    super.key,
    required this.row,
    required this.track,
    required this.now,
    required this.onTap,
    required this.onNext,
    required this.onQueue,
    required this.onMore,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final artist = track.metadata?.artist?.trim();
    final facts = discoveryPlayLabel(l, track, now);
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 60),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 4, 6),
          child: Row(
            children: [
              SizedBox(
                width: 48,
                height: 48,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    row.getAlbumThumb(size: 44),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: DiscoveryMatchBadge(track.similarity),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      track.displayTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 15, color: VelvetColors.textPrimary),
                    ),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(children: [
                        if (artist != null && artist.isNotEmpty)
                          TextSpan(text: artist),
                        if (facts != null)
                          TextSpan(
                            text: (artist != null && artist.isNotEmpty)
                                ? ' · $facts'
                                : facts,
                            style:
                                TextStyle(color: VelvetColors.textTertiary),
                          ),
                      ]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13, color: VelvetColors.textSecondary),
                    ),
                  ],
                ),
              ),
              discoveryIconButton(
                icon: Icons.playlist_play,
                tooltip: l.queueAddNext,
                onPressed: onNext,
              ),
              discoveryIconButton(
                icon: Icons.queue_music,
                tooltip: l.queueAddToEnd,
                onPressed: onQueue,
              ),
              discoveryIconButton(
                icon: Icons.more_vert,
                tooltip: MaterialLocalizations.of(context).moreButtonTooltip,
                onPressed: onMore,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// An album card in AlbumGrid's style (card surface, square cover, name,
/// credit) plus the match badge and this account's play facts.
class DiscoveryAlbumCard extends StatelessWidget {
  final DisplayItem item;
  final TasteAlbum album;
  final VoidCallback onTap;
  final double width;
  const DiscoveryAlbumCard({
    super.key,
    required this.item,
    required this.album,
    required this.onTap,
    this.width = 128,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final credit = album.albumArtist ??
        (album.artists.isEmpty ? null : album.artists.join(', '));
    final facts = discoveryAlbumLabel(l, album);
    return SizedBox(
      width: width,
      child: Material(
        color: VelvetColors.card,
        borderRadius: BorderRadius.circular(VelvetColors.radiusLarge),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          splashColor: VelvetColors.primaryDim,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: width,
                height: width,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    _cover(),
                    Positioned(
                      left: 8,
                      top: 8,
                      child: DiscoveryMatchBadge(album.similarity,
                          fontSize: 11),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      album.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: VelvetColors.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    Text(
                      credit ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: VelvetColors.textSecondary, fontSize: 12),
                    ),
                    Text(
                      facts ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: VelvetColors.textTertiary,
                        fontSize: 11,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cover() {
    final file = item.altAlbumArt;
    final server = item.server;
    final placeholder = Container(
      color: VelvetColors.raised,
      child: Icon(Icons.album,
          color: VelvetColors.textTertiary, size: width * 0.3),
    );
    if (server == null || file == null) return placeholder;
    return Image.network(
      buildAlbumArtUrl(server, file, compress: 'm'),
      fit: BoxFit.cover,
      cacheWidth: artCacheSize(width),
      errorBuilder: (_, _, _) => placeholder,
    );
  }
}

/// A network lead — DiscoverScreen's lead row (tap copies "Artist - Title",
/// the MusicBrainz button when the row has a recording id), with the
/// canvas's "new artist" pill.
class DiscoveryLeadRow extends StatelessWidget {
  final DiscoveryLead lead;

  /// Every row is a new artist when the call asked newArtistsOnly: the
  /// server then drops artists the library already has. The row itself
  /// carries no such flag, so without the setting the pill is not drawn.
  final bool newArtist;
  const DiscoveryLeadRow(
      {super.key, required this.lead, this.newArtist = false});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final genre = genreTagLabel(lead.genreTags, max: 1);
    final subtitle = [
      if (lead.artist.isNotEmpty) lead.artist,
      ?genre,
      ?lead.peerName,
    ].join(' · ');
    return ListTile(
      dense: true,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: VelvetColors.raised,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.travel_explore,
            color: VelvetColors.textSecondary, size: 22),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              lead.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 15, color: VelvetColors.textPrimary),
            ),
          ),
          if (newArtist) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
              decoration: BoxDecoration(
                color: VelvetColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                l.discoverPageNewArtist,
                style: TextStyle(
                  color: VelvetColors.onPrimary,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ],
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
            discoveryIconButton(
              icon: Icons.open_in_new,
              size: 18,
              tooltip: l.discoverOpenMusicBrainz,
              onPressed: () => discoveryOpenMusicBrainz(context, lead),
            ),
          MatchMeter(similarity: lead.similarity),
        ],
      ),
      onTap: () => discoveryCopyLead(context, lead),
    );
  }
}

/// One peer's answer: an online/offline dot and the peer's name, then its
/// rows. An unreachable or model-mismatched peer is dimmed and says why.
class DiscoveryPeerGroup extends StatelessWidget {
  final TastePeerGroup group;

  /// Rows to show (the page shows the first few; "See all" every one).
  final int? maxRows;

  /// Plays the row now / queues it; null for a row that cannot (see
  /// discoveryPeerPlay — a not-yet-mirrored peer's ▶ still answers, with
  /// a snackbar saying why).
  final VoidCallback? Function(DiscoveryLead lead) onPlay;
  final VoidCallback? Function(DiscoveryLead lead) onQueue;

  /// Whether the row can actually play here (its peer is mirrored), so a
  /// row that can only explain itself is not drawn as one that plays.
  final bool Function(DiscoveryLead lead) playable;
  const DiscoveryPeerGroup(
      {super.key,
      required this.group,
      required this.onPlay,
      required this.onQueue,
      required this.playable,
      this.maxRows});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final status = !group.reachable
        ? l.discoverPagePeerOffline
        : group.mismatched
            ? l.discoverPagePeerMismatched
            : null;
    final rows = maxRows == null
        ? group.results
        : group.results.take(maxRows!).toList();
    return Opacity(
      opacity: group.reachable && !group.mismatched ? 1 : 0.5,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 2),
            child: Row(
              children: [
                FedDot(group.reachable
                    ? VelvetColors.success
                    : VelvetColors.textTertiary),
                Flexible(
                  child: Text(
                    group.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: VelvetColors.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (status != null) ...[
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      status,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: VelvetColors.textTertiary, fontSize: 12),
                    ),
                  ),
                ],
              ],
            ),
          ),
          for (final lead in rows)
            DiscoveryPeerRow(
                lead: lead,
                playable: playable(lead),
                onPlay: onPlay(lead),
                onQueue: onQueue(lead)),
        ],
      ),
    );
  }
}

/// A peer's song: playable through this server (plan §1 — never a plug-in),
/// so the row plays it now and the trailing ▶ says so, with the inline
/// queue beside it (plan §1: Peers = inline Listen and queue). A row whose
/// peer is not mirrored yet ([playable] false) is dimmed with a quiet ▶
/// whose tap explains; it has no queue.
class DiscoveryPeerRow extends StatelessWidget {
  final DiscoveryLead lead;
  final bool playable;
  final VoidCallback? onPlay;
  final VoidCallback? onQueue;
  const DiscoveryPeerRow(
      {super.key,
      required this.lead,
      this.playable = true,
      this.onPlay,
      this.onQueue});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final genre = genreTagLabel(lead.genreTags, max: 1);
    final subtitle = [
      if (lead.artist.isNotEmpty) lead.artist,
      ?genre,
    ].join(' · ');
    final live = playable && onPlay != null;
    final tile = ListTile(
      dense: true,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: VelvetColors.raised,
          shape: BoxShape.circle,
        ),
        child: Icon(Icons.hub_outlined,
            color: VelvetColors.textSecondary, size: 22),
      ),
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
          MatchMeter(similarity: lead.similarity),
          if (live && onQueue != null)
            discoveryIconButton(
              icon: Icons.queue_music,
              tooltip: l.queueAddToEnd,
              onPressed: onQueue,
            ),
          discoveryIconButton(
            icon: Icons.play_circle_outline,
            size: 26,
            color: live ? VelvetColors.primary : VelvetColors.textTertiary,
            tooltip: l.discoverPageListen,
            onPressed: onPlay,
          ),
        ],
      ),
      onTap: onPlay,
      onLongPress: onQueue,
    );
    return live ? tile : Opacity(opacity: 0.6, child: tile);
  }
}

/// A rounded action pill under the library rows (Play all / Shuffle / Add
/// to queue); [primary] fills it with the accent.
class DiscoveryPill extends StatelessWidget {
  final String label;
  final IconData? icon;
  final bool primary;
  final VoidCallback? onTap;
  const DiscoveryPill(this.label,
      {super.key, this.icon, this.primary = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final fg = primary ? VelvetColors.onPrimary : VelvetColors.textPrimary;
    // 36 px on the canvas; the hit area reaches the 44 px floor.
    return _HitArea(onTap: onTap, child: Material(
      color: primary ? VelvetColors.primary : VelvetColors.raised,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 6),
              ],
              Text(
                label,
                style: TextStyle(
                    color: fg, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    ));
  }
}

/// A selectable pill (filter chips, the window segments): filled with the
/// accent when it is the one in force — ListeningScreen's scope pill.
class DiscoveryChoicePill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Shrink a label that does not fit instead of ellipsizing it — for a
  /// fixed-width segment, where the label is the whole meaning.
  final bool fit;
  const DiscoveryChoicePill(this.label,
      {super.key,
      required this.selected,
      required this.onTap,
      this.fit = false});

  @override
  Widget build(BuildContext context) {
    final text = Text(
      label,
      maxLines: 1,
      overflow: fit ? TextOverflow.visible : TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: selected ? VelvetColors.onPrimary : VelvetColors.textSecondary,
      ),
    );
    // 32 px on the canvas; the hit area reaches the 44 px floor.
    return _HitArea(onTap: onTap, child: Material(
      color: selected ? VelvetColors.primary : VelvetColors.raised,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          height: 32,
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 13),
          child: fit ? FittedBox(fit: BoxFit.scaleDown, child: text) : text,
        ),
      ),
    ));
  }
}

/// Discovery is on but nothing is analyzed yet — DiscoverScreen's
/// scan-pending card (same copy), with its "Check again".
class DiscoveryScanPendingCard extends StatelessWidget {
  final bool rechecking;
  final VoidCallback onRecheck;
  const DiscoveryScanPendingCard(
      {super.key, required this.rechecking, required this.onRecheck});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
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
              style: TextStyle(color: VelvetColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: rechecking ? null : onRecheck,
                icon: rechecking
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
}

/// Nothing counted yet (plan §2.8): the page runs on one random library
/// song. Explains why, and offers another pick or a song of the user's own.
class DiscoveryRandomCard extends StatelessWidget {
  final bool busy;
  final VoidCallback onAnotherPick;
  final VoidCallback onChooseSong;
  const DiscoveryRandomCard({
    super.key,
    required this.busy,
    required this.onAnotherPick,
    required this.onChooseSong,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: VelvetColors.card,
          borderRadius: BorderRadius.circular(VelvetColors.radiusLarge),
          border: Border.all(color: VelvetColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.discoverPageRandomTitle,
              style: TextStyle(
                color: VelvetColors.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l.discoverPageRandomBody,
              style: TextStyle(
                  color: VelvetColors.textSecondary, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              // The pills' 44 px hit areas already space the rows.
              runSpacing: 0,
              children: [
                DiscoveryPill(l.discoverPageAnotherPick,
                    icon: Icons.casino_outlined,
                    primary: true,
                    onTap: busy ? null : onAnotherPick),
                DiscoveryPill(l.discoverPageChooseSong,
                    icon: Icons.search, onTap: busy ? null : onChooseSong),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
