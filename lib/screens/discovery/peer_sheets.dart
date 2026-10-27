import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../objects/discovery.dart';
import '../../objects/discovery_plugins.dart';
import '../../objects/display_item.dart';
import '../../objects/metadata.dart';
import '../../objects/server.dart';
import '../../singletons/api.dart';
import '../../singletons/app_messenger.dart';
import '../../singletons/browser_list.dart';
import '../../singletons/downloads.dart';
import '../../singletons/server_list.dart';
import '../../singletons/settings.dart';
import '../../theme/velvet_theme.dart';
import '../../util/browse_keep_leads.dart';
import '../../util/discover_badges.dart' show nameKey;
import '../../util/discover_jobs.dart' show folderCounts;
import '../../util/image_cache.dart' show artCacheSize;
import '../../util/queue_actions.dart';
import '../../util/stream_url.dart';
import 'browse_copy_marks.dart';
import 'copies_hub.dart';
import 'copy_news.dart';
import 'discovery_jobs_controller.dart';
import 'discovery_keep_routes.dart';
import 'discovery_page_controller.dart';
import 'discovery_widgets.dart' show discoveryToast;
import 'keep_copy_card.dart';
import 'keep_copy_facts.dart';
import 'keep_copy_ui.dart';
import 'keep_folder_facts.dart';
import 'keep_toast.dart';

/// A connected server's song and album, acted on from Discover (the design
/// canvas's PhoneSongSheet and PhoneAlbumSheet boards): the Track actions
/// sheet for a connected server's row — the listen verbs, the album and
/// the artist, Keep a copy, Open elsewhere, Browse that server, and the
/// old Download, renamed "Download to this phone" and moved last — and the
/// same sheet in album focus, opened by a long-press (or the ⋯) on a
/// connected server's album card.
///
/// Both stream through the user's own server as the rows do, and both send
/// every plug-in call to the user's own server with the row exactly as the
/// taste route gave it. No previews: the whole song already plays.
///
/// And the same sheet entered while browsing a connected server
/// ([showBrowseKeepSheet], the phone spec's §6): a song, an album, an artist
/// or a folder, from a page pill, a card or a menu row.

/// Tall sheets stop here and scroll inside (the grab handle stays put).
const double kPeerSheetMaxHeight = 0.87;

Future<void> _showSheet(BuildContext context, WidgetBuilder builder) =>
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: VelvetColors.surface,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * kPeerSheetMaxHeight,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: builder,
    );

/// Long-press on a connected server's song row on Discover.
Future<void> showPeerSongSheet(
  BuildContext context,
  DisplayItem row,
  DiscoveryLead lead,
  DiscoveryPageController page, {
  KeepFactsFetch? fetch,
}) async {
  final started = <DiscoveryJob>[];
  await _showSheet(
    context,
    (_) => PeerSongSheet(
      row: row,
      lead: lead,
      page: page,
      parentContext: context,
      fetch: fetch,
      onStarted: started.add,
    ),
  );
  if (!context.mounted) return;
  _toastStarted(context, started, _peerName(lead, row.server));
}

/// Long-press (or the ⋯) on a connected server's album card on Discover.
Future<void> showPeerAlbumSheet(
  BuildContext context,
  DisplayItem card,
  DiscoveryPageController page, {
  KeepFactsFetch? fetch,
}) async {
  final started = <DiscoveryJob>[];
  await _showSheet(
    context,
    (_) => PeerAlbumSheet(
      card: card,
      page: page,
      parentContext: context,
      fetch: fetch,
      onStarted: started.add,
    ),
  );
  if (!context.mounted) return;
  final leads = discoveryCardLeads(card);
  _toastStarted(
    context,
    started,
    leads.isEmpty
        ? (card.server?.federationPeerName ?? '')
        : _peerName(leads.first, card.server),
  );
}

/// Once the sheet that started a copy has closed: "Copying Borrowed Tapes
/// from Stage Peer B" (the last one, when it started more).
void _toastStarted(
  BuildContext context,
  List<DiscoveryJob> started,
  String peerName,
) {
  if (started.isEmpty || !context.mounted) return;
  KeepToast.show(
    context,
    copyStartedToast(
      AppLocalizations.of(context),
      started.last,
      peer: peerName,
    ),
  );
}

/// The connected server's name for [lead] (its row's, else the virtual
/// Server's).
String _peerName(DiscoveryLead lead, Server? peer) =>
    (lead.peerName ?? '').trim().isNotEmpty
    ? lead.peerName!.trim()
    : (peer?.federationPeerName ?? peer?.displayName ?? '');

/// "Browse Stage Peer B": the peer becomes the browsed server, as the
/// connected server's own screen does (the browser resets onto its home).
Future<void> _browsePeer(Server? peer) async {
  if (peer == null) return;
  final sm = ServerManager();
  final index = sm.serverList.indexOf(peer);
  if (index < 0) return;
  await sm.changeCurrentServer(index);
  try {
    await sm.getServerPaths(peer, throwErr: true);
    await sm.callAfterEditServer();
  } catch (_) {
    // The home it lands on shows the server's state itself.
  }
}

// ── shared pieces ─────────────────────────────────────────────────────────

class _GrabHandle extends StatelessWidget {
  const _GrabHandle();

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 22,
    child: Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: VelvetColors.border2,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    ),
  );
}

/// The sheet header: cover, title, byline, the spec line, and whether the
/// connected server answers.
///
/// A browse-entered sheet ([browse]) gives the title two lines and the
/// byline [bylineLines] (a folder's path wraps between its crumbs), puts
/// [status] after the server's line ("● Stage Peer B online · 3 songs · no
/// subfolders"), draws the dot of a server not answering in the error
/// colour, and reads as one header node — the full title in it.
class _SheetHeader extends StatelessWidget {
  final Widget cover;
  final String title;
  final String byline;
  final String? spec;
  final String peerName;
  final bool answering;
  final bool browse;
  final int bylineLines;
  final String? status;
  const _SheetHeader({
    required this.cover,
    required this.title,
    required this.byline,
    this.spec,
    required this.peerName,
    required this.answering,
    this.browse = false,
    this.bylineLines = 1,
    this.status,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final head = Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 12),
      child: Row(
        children: [
          cover,
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: browse ? 2 : 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: VelvetColors.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (byline.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      byline,
                      maxLines: bylineLines,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: VelvetColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                  ),
                if (spec != null && spec!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Text(
                      spec!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        letterSpacing: 0.2,
                        color: VelvetColors.textTertiary,
                      ),
                    ),
                  ),
                if (peerName.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Row(
                      key: const ValueKey('peer-sheet-server'),
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: answering
                                ? keepTone(VelvetColors.success)
                                : (browse
                                      ? keepTone(VelvetColors.error)
                                      : VelvetColors.textTertiary),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            [
                              answering
                                  ? l.discoverSheetPeerOnline(peerName)
                                  : l.discoverSheetPeerNotAnswering(peerName),
                              ?status,
                            ].join(' · '),
                            maxLines: browse ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: VelvetColors.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
    if (!browse) return head;
    // One header node: what the sheet is about, then where it comes from.
    return MergeSemantics(
      key: const ValueKey('browse-keep-header'),
      child: Semantics(header: true, child: head),
    );
  }
}

/// A 52 px action row: a 24 px icon, the label (and an optional second
/// line), an optional chevron. Not [enabled] (a folder's Listen before it
/// is counted): drawn at 45 %, inert, still in reach of a screen reader.
class _ActionRow extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final String? sub;
  final bool chevron;
  final bool enabled;
  final VoidCallback onTap;
  const _ActionRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.sub,
    this.chevron = false,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final row = _row();
    if (enabled) return row;
    return Semantics(
      button: true,
      enabled: false,
      label: [label, ?sub].join(', '),
      excludeSemantics: true,
      child: Opacity(opacity: 0.45, child: IgnorePointer(child: row)),
    );
  }

  Widget _row() => InkWell(
    onTap: onTap,
    splashColor: VelvetColors.primaryDim,
    child: ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 52),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Icon(
              icon,
              size: 24,
              color: iconColor ?? VelvetColors.textSecondary,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: VelvetColors.textPrimary,
                      fontSize: 15,
                    ),
                  ),
                  if (sub != null)
                    Text(
                      sub!,
                      style: TextStyle(
                        color: VelvetColors.textSecondary,
                        fontSize: 13,
                      ),
                    ),
                ],
              ),
            ),
            if (chevron)
              Icon(
                Icons.chevron_right,
                size: 20,
                color: VelvetColors.textTertiary,
              ),
          ],
        ),
      ),
    ),
  );
}

/// A line about the album or the artist, with its pills under it.
class _FactLine extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? sub;
  final List<Widget> pills;
  final EdgeInsets padding;
  const _FactLine({
    super.key,
    required this.icon,
    required this.title,
    this.sub,
    required this.pills,
    this.padding = const EdgeInsets.fromLTRB(16, 10, 16, 4),
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: padding,
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 24, color: VelvetColors.textSecondary),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: VelvetColors.textPrimary, fontSize: 15),
              ),
              if (sub != null && sub!.isNotEmpty)
                Text(
                  sub!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: VelvetColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Wrap(spacing: 8, runSpacing: 0, children: pills),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

Widget _divider() =>
    Divider(height: 1, thickness: 1, color: VelvetColors.border);

/// The sheet's frame: the pinned grab handle, then everything scrolling as
/// one.
Widget _sheetFrame(List<Widget> children) => SafeArea(
  top: false,
  child: Column(
    mainAxisSize: MainAxisSize.min,
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const _GrabHandle(),
      Flexible(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [...children, const SizedBox(height: 16)],
          ),
        ),
      ),
    ],
  ),
);

mixin _PeerSheetState<T extends StatefulWidget> on State<T> {
  late final KeepFactsLoader facts;
  VoidCallback? _release;

  DiscoveryJobsController get jobs;
  BuildContext get parentContext;

  void startFacts(KeepFactsLoader loader) {
    facts = loader..load();
    // A sheet that may show a job polls fast while it is open.
    _release = jobs.holdFast();
  }

  @override
  void dispose() {
    _release?.call();
    facts.dispose();
    super.dispose();
  }

  void toast(String message) {
    if (parentContext.mounted) discoveryToast(parentContext, message);
  }

  /// Close the sheet, then [then] (it acts on the page behind it).
  void closeThen(FutureOr<void> Function() then) {
    Navigator.of(context).pop();
    unawaited(Future.sync(then));
  }

  /// Play album / Queue album: the album's songs on the connected server,
  /// once they answered.
  Future<void> albumVerb(String peerName, {required bool play}) async {
    final l = AppLocalizations.of(parentContext);
    final songs = await facts.albumSongs();
    if (songs == null || songs.isEmpty) {
      toast(l.discoverSheetAlbumFailed(peerName));
      return;
    }
    if (play) {
      await playFromHere(songs, 0);
    } else {
      final n = await addRowsToQueue(songs);
      if (n > 0) toast(l.browserSongsAdded(n));
    }
  }
}

// ── the song sheet ────────────────────────────────────────────────────────

class PeerSongSheet extends StatefulWidget {
  final DisplayItem row;
  final DiscoveryLead lead;
  final DiscoveryPageController page;
  final BuildContext parentContext;
  final KeepFactsFetch? fetch;

  /// A copy started from this sheet (toasted once it closes).
  final void Function(DiscoveryJob job)? onStarted;
  const PeerSongSheet({
    super.key,
    required this.row,
    required this.lead,
    required this.page,
    required this.parentContext,
    this.fetch,
    this.onStarted,
  });

  @override
  State<PeerSongSheet> createState() => _PeerSongSheetState();
}

class _PeerSongSheetState extends State<PeerSongSheet>
    with _PeerSheetState<PeerSongSheet> {
  @override
  DiscoveryJobsController get jobs => widget.page.jobs;
  @override
  BuildContext get parentContext => widget.parentContext;

  DiscoveryLead get lead => widget.lead;
  Server? get peer => widget.row.server;

  @override
  void initState() {
    super.initState();
    startFacts(
      KeepFactsLoader.forLead(
        lead,
        peer: peer,
        own: widget.page.server,
        fetch: widget.fetch,
      ),
    );
  }

  /// The album card this row belongs to, else one made for it — what Open
  /// album opens (the card's own tap does the same).
  DisplayItem? _albumItem() {
    for (final card in widget.page.peerAlbumItems) {
      if (discoveryCardLeads(card).contains(lead)) return card;
    }
    final album = lead.album;
    if (album == null || album.trim().isEmpty || peer == null) return null;
    final credit = (lead.albumArtist ?? '').trim();
    final card = DisplayItem(
      peer,
      album,
      'album',
      album,
      Icon(Icons.album, color: VelvetColors.textSecondary),
      credit.isNotEmpty ? credit : (lead.artist.isEmpty ? null : lead.artist),
    );
    if (credit.isNotEmpty) {
      card.albumArtist = credit;
    } else if (lead.artist.isNotEmpty) {
      card.trackArtist = lead.artist;
    }
    card.altAlbumArt = lead.art;
    return card;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final row = widget.row;
    final peerName = _peerName(lead, peer);
    final byline = [
      if (lead.artist.trim().isNotEmpty) lead.artist.trim(),
      if ((lead.album ?? '').trim().isNotEmpty) lead.album!.trim(),
    ].join('  ·  ');
    final d = lead.durationSeconds;
    final spec = [
      ?keepFormatOf(lead.filepath),
      if (d != null) keepClock(Duration(milliseconds: (d * 1000).round())),
    ].join('  ·  ');
    final linksListed = jobs.pluginsOn && jobs.listing?.links != null;

    return ListenableBuilder(
      listenable: facts,
      builder: (context, _) {
        final f = facts.facts;
        final album = (lead.album ?? '').trim();
        final albumSub = <String>[
          if ((lead.year ?? f.albumYear) != null) '${lead.year ?? f.albumYear}',
          if (f.albumSongCount != null)
            l.discoverSheetSongCount(f.albumSongCount!),
          if (f.albumLength != null) keepClock(f.albumLength!),
          if ((lead.albumArtist ?? '').trim().isEmpty)
            if (f.libraryHas(lead.album) case final has?)
              has ? l.discoverSheetInLibrary : l.discoverSheetNotInLibrary,
        ].join(' · ');
        String? artistSub;
        final pa = f.peerAlbums;
        if (pa != null && pa.isNotEmpty) {
          final only =
              pa.length == 1 &&
              nameKey(pa.first) == nameKey(lead.album) &&
              f.albumSongCount != null;
          artistSub = [
            l.discoverSheetAlbumCount(pa.length),
            if (only) l.discoverSheetSongCount(f.albumSongCount!),
          ].join(' · ');
        } else if (f.libraryAlbums != null && f.libraryAlbums!.isNotEmpty) {
          artistSub = l.discoverSheetYouHaveAlbums(f.libraryAlbums!.length);
        }
        return _sheetFrame([
          _SheetHeader(
            cover: row.getAlbumThumb(size: 60),
            title: lead.title,
            byline: byline,
            spec: spec,
            peerName: peerName,
            answering: !f.peerFailed,
          ),
          _divider(),
          _ActionRow(
            key: const ValueKey('peer-song-add-next'),
            icon: Icons.playlist_play,
            label: l.queueAddNext,
            onTap: () => closeThen(() async {
              if (await addNext(row) != null) toast(l.browserSongsAdded(1));
            }),
          ),
          _ActionRow(
            key: const ValueKey('peer-song-play-now'),
            icon: Icons.play_arrow,
            label: l.queuePlayNow,
            onTap: () => closeThen(() => playNow(row)),
          ),
          if (SettingsManager().tapBehavior == TapBehavior.playFromHere)
            _ActionRow(
              key: const ValueKey('peer-song-add-to-end'),
              icon: Icons.playlist_add,
              label: l.queueAddToEnd,
              onTap: () => closeThen(() async {
                await addToQueueEnd(row);
                toast(l.browserSongsAdded(1));
              }),
            ),
          _divider(),
          if (album.isNotEmpty)
            _FactLine(
              key: const ValueKey('peer-song-album'),
              icon: Icons.album,
              title: album,
              sub: albumSub,
              pills: [
                KeepPill(
                  l.discoverSheetOpenAlbum,
                  key: const ValueKey('peer-song-open-album'),
                  onTap: () {
                    final item = _albumItem();
                    if (item == null) return;
                    closeThen(() => BrowserManager().openAlbumDetail(item));
                  },
                ),
                KeepPill(
                  l.discoverSheetQueueAlbum,
                  key: const ValueKey('peer-song-queue-album'),
                  onTap: () =>
                      closeThen(() => albumVerb(peerName, play: false)),
                ),
              ],
            ),
          if (lead.artist.trim().isNotEmpty)
            _FactLine(
              key: const ValueKey('peer-song-artist'),
              icon: Icons.person_outline,
              title: lead.artist.trim(),
              sub: artistSub,
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
              pills: [
                KeepPill(
                  l.discoverSheetOpenArtist,
                  key: const ValueKey('peer-song-open-artist'),
                  onTap: () => closeThen(
                    () => ApiManager().getArtistAlbums(
                      lead.artist,
                      useThisServer: peer,
                    ),
                  ),
                ),
              ],
            ),
          KeepCopySection(
            jobs: jobs,
            lead: lead,
            facts: facts,
            peerName: peerName,
            toast: toast,
            onNewSeeds: () => closeThen(() => widget.page.refresh()),
            onStarted: widget.onStarted,
          ),
          if (linksListed)
            _ActionRow(
              key: const ValueKey('peer-song-elsewhere'),
              icon: Icons.open_in_new,
              label: l.discoverSheetOpenElsewhere,
              chevron: true,
              onTap: () =>
                  DiscoveryKeepRoutes.openElsewhere(context, jobs, lead),
            ),
          if (peer != null && peerName.isNotEmpty)
            _ActionRow(
              key: const ValueKey('peer-song-browse'),
              icon: Icons.dns_outlined,
              label: l.discoverSheetBrowsePeer(peerName),
              chevron: true,
              onTap: () => closeThen(() => _browsePeer(peer)),
            ),
          _divider(),
          if (peer != null && row.data != null)
            _ActionRow(
              key: const ValueKey('peer-song-download'),
              icon: Icons.install_mobile,
              iconColor: keepTone(VelvetColors.success),
              label: l.discoverSheetDownloadToPhone,
              sub: l.discoverSheetDownloadToPhoneSub,
              onTap: () => closeThen(
                () => DownloadManager().downloadOneFile(
                  buildServerStreamUrl(peer!, row.data!),
                  peer!.localname,
                  row.data!,
                  referenceItem: row,
                ),
              ),
            ),
        ]);
      },
    );
  }
}

// ── the album sheet ───────────────────────────────────────────────────────

class PeerAlbumSheet extends StatefulWidget {
  final DisplayItem card;
  final DiscoveryPageController page;
  final BuildContext parentContext;
  final KeepFactsFetch? fetch;

  /// A copy started from this sheet (toasted once it closes).
  final void Function(DiscoveryJob job)? onStarted;
  const PeerAlbumSheet({
    super.key,
    required this.card,
    required this.page,
    required this.parentContext,
    this.fetch,
    this.onStarted,
  });

  @override
  State<PeerAlbumSheet> createState() => _PeerAlbumSheetState();
}

class _PeerAlbumSheetState extends State<PeerAlbumSheet>
    with _PeerSheetState<PeerAlbumSheet> {
  @override
  DiscoveryJobsController get jobs => widget.page.jobs;
  @override
  BuildContext get parentContext => widget.parentContext;

  DisplayItem get card => widget.card;
  late final List<DiscoveryLead> leads = discoveryCardLeads(card);
  late final bool compilation = discoveryCardIsCompilation(card);
  DiscoveryLead? get best => leads.isEmpty ? null : leads.first;

  @override
  void initState() {
    super.initState();
    final b = best;
    startFacts(
      KeepFactsLoader(
        peer: card.server,
        own: widget.page.server,
        album: card.name,
        albumArtist: card.albumArtist,
        artist: b?.artist ?? card.trackArtist ?? '',
        wantArtist: !compilation,
        fetch: widget.fetch,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final b = best;
    final peerName = b == null
        ? (card.server?.federationPeerName ?? '')
        : _peerName(b, card.server);
    return ListenableBuilder(
      listenable: facts,
      builder: (context, _) {
        final f = facts.facts;
        final year = b?.year ?? f.albumYear;
        final byline = [
          if ((card.subtext ?? '').trim().isNotEmpty) card.subtext!.trim(),
          if (year != null) '$year',
          if (f.albumSongCount != null)
            l.discoverSheetSongCount(f.albumSongCount!),
          if (f.albumLength != null) keepClock(f.albumLength!),
        ].join(' · ');
        return _sheetFrame([
          _SheetHeader(
            cover: card.getAlbumThumb(size: 60),
            title: card.name,
            byline: byline,
            peerName: peerName,
            answering: !f.peerFailed,
          ),
          _divider(),
          KeepSheetLabel(l.discoverSheetListen),
          _ActionRow(
            key: const ValueKey('peer-album-play'),
            icon: Icons.play_arrow,
            label: l.discoverSheetPlayAlbum,
            onTap: () => closeThen(() => albumVerb(peerName, play: true)),
          ),
          _ActionRow(
            key: const ValueKey('peer-album-queue'),
            icon: Icons.queue_music,
            label: l.discoverSheetQueueAlbum,
            onTap: () => closeThen(() => albumVerb(peerName, play: false)),
          ),
          _ActionRow(
            key: const ValueKey('peer-album-open'),
            icon: Icons.album,
            label: l.discoverSheetOpenAlbum,
            chevron: true,
            onTap: () =>
                closeThen(() => BrowserManager().openAlbumDetail(card)),
          ),
          if (b != null)
            KeepCopySection(
              jobs: jobs,
              lead: b,
              albumFocus: true,
              cardLeads: leads,
              compilation: compilation,
              facts: facts,
              peerName: peerName,
              toast: toast,
              onNewSeeds: () => closeThen(() => widget.page.refresh()),
              onStarted: widget.onStarted,
            ),
        ]);
      },
    );
  }
}

// ── entered from browsing a connected server ──────────────────────────────

/// One headless metadata read of a file on a connected server (a row with
/// no tags, a queued track: what gives a song its album's credit); null when
/// it did not answer. Tests inject theirs.
typedef KeepTrackFetch =
    Future<MusicMetadata?> Function(Server server, String filepath);

/// Keep a copy entered while browsing a connected server — a page pill, a
/// card's ⋯ or long-press, an album row, a track or folder menu's row, the
/// queue's pane ([BrowseKeepRequest] says which, and what): the sheet in
/// one of its three shapes, its copies the user's own server's
/// (`CopiesHub().jobsFor(request.peer)`), never a Discover page's.
///   V-page  header · Listen (an album's Play album and Queue album, a
///           folder's Play folder and Add to queue, an artist's none) ·
///           Keep a copy
///   V-item  header · Listen with Open album › · Keep a copy
///   V-menu  header · Keep a copy (the menu that just closed held the rest)
/// Never "Browse {peer}", "Download to this phone" or "Open elsewhere".
///
/// [marks] is the page's own lookup holder when it passes one (the sheet
/// asks its own otherwise; the page's is asked again for the request's
/// recommendation once the sheet closes). A copy the sheet started is
/// toasted once it closes, with "View" — the Copies sheet of the user's own
/// server, out of reach otherwise while browsing — or, ended by then, with
/// its ending ("Already in your library"). Focus going back to the
/// opener is the caller's (BrowseKeepEntry.open). The facts, track, folder
/// and own-folders fetches are the real ones unless a test passes its own.
Future<void> showBrowseKeepSheet(
  BuildContext context,
  BrowseKeepRequest request, {
  BrowseCopyMarks? marks,
  KeepFactsFetch? fetch,
  KeepTrackFetch? track,
  FolderListFetch? folderList,
  FolderTagsFetch? folderTags,
  OwnFoldersFetch? ownFolders,
}) async {
  final l = AppLocalizations.of(context);
  final jobs = CopiesHub().jobsFor(request.peer);
  final started = <DiscoveryJob>[];
  await _showSheet(
    context,
    (_) => BrowseKeepSheet(
      request: request,
      jobs: jobs,
      marks: marks,
      parentContext: context,
      fetch: fetch,
      track: track,
      folderList: folderList,
      folderTags: folderTags,
      ownFolders: ownFolders,
      onStarted: started.add,
    ),
  );
  if (marks != null) unawaited(marks.reask(request.lead));
  if (started.isEmpty) return;
  BuildContext? host() =>
      context.mounted ? context : rootNavigatorKey.currentContext;
  // One that already ended (a copy of what is already here ends as it
  // starts) is no "Copying …": its ending instead — unless the poll told
  // it while the sheet was open.
  final last = jobs.latest(started.last);
  if (!last.live) {
    final ended = jobs.claimEnding(last) ? copyFinishedToast(l, last) : null;
    if (ended != null) KeepToast.show(host(), ended);
    return;
  }
  showCopyStarted(
    host(),
    l,
    last,
    peer: request.peerName,
    onView: () {
      final at = host();
      if (at != null && at.mounted) DiscoveryKeepRoutes.openCopies(at, jobs);
    },
  );
}

/// The browse-entered sheet ([showBrowseKeepSheet]). It reads what the
/// request names and nothing it does not: a song's tags when its row had
/// none (or named no album credit of its own — the read names it on a
/// server since 2026-10-23), then its album's credit as the connected
/// server's album list bears the song's own out (see [_settleCredit]); an
/// album's songs and its artist's albums; an artist's albums from the
/// page's own answer; a folder's count (once, as the folder focus opens or
/// the Folder chip is first chosen) and, for "By your layout", its songs'
/// tags.
class BrowseKeepSheet extends StatefulWidget {
  final BrowseKeepRequest request;
  final DiscoveryJobsController jobs;
  final BrowseCopyMarks? marks;
  final BuildContext parentContext;
  final KeepFactsFetch? fetch;
  final KeepTrackFetch? track;
  final FolderListFetch? folderList;
  final FolderTagsFetch? folderTags;
  final OwnFoldersFetch? ownFolders;

  /// A copy started from this sheet (toasted once it closes).
  final void Function(DiscoveryJob job)? onStarted;

  const BrowseKeepSheet({
    super.key,
    required this.request,
    required this.jobs,
    required this.parentContext,
    this.marks,
    this.fetch,
    this.track,
    this.folderList,
    this.folderTags,
    this.ownFolders,
    this.onStarted,
  });

  /// What Listen does with an album's or a folder's songs: play them from
  /// the first, add them to the queue (the count added). Tests record them.
  static Future<void> Function(List<DisplayItem> songs) play = _play;
  static Future<int> Function(List<DisplayItem> songs) queue = addRowsToQueue;

  static Future<void> _play(List<DisplayItem> songs) => playFromHere(songs, 0);

  /// Put the real verbs back (tests).
  static void resetVerbs() {
    play = _play;
    queue = addRowsToQueue;
  }

  @override
  State<BrowseKeepSheet> createState() => _BrowseKeepSheetState();
}

String? _text(Object? v) => v is String && v.trim().isNotEmpty ? v : null;

class _BrowseKeepSheetState extends State<BrowseKeepSheet> {
  BrowseKeepRequest get r => widget.request;
  Server get peer => r.peer;
  DiscoveryJobsController get jobs => widget.jobs;

  late final BrowseCopyMarks _marks =
      widget.marks ?? BrowseCopyMarks(jobs: jobs, peer: peer);
  late KeepFactsLoader _facts;
  KeepFolderFactsLoader? _folderFacts;
  OwnFolderLister? _ownFolders;
  VoidCallback? _release;

  /// The recommendation as the sheet knows it now: the opener's, with the
  /// song's tags once read and its album's credit once known.
  late Map<String, dynamic> _rec = r.lead;
  late DiscoveryLead _lead = leadOfRec(_rec);

  /// The song's metadata read is out.
  bool _reading = false;

  /// What it answered (the header's spec line: the format, the length).
  MusicMetadata? _tags;

  /// The song's own album credit (the row's tag, a queued track's, or the
  /// read's), held until the album list bears it out ([_settleCredit]).
  late String? _candidate = r.songCredit;

  /// The album's credit was settled: the Album choice came, or will not.
  bool _creditSettled = false;

  /// Play album or Queue album waiting on the album's songs: the loader
  /// outlives the sheet (it closes first) until they answered.
  Future<void>? _pending;

  @override
  void initState() {
    super.initState();
    final folder = r.folder;
    if (folder != null) {
      _folderFacts = KeepFolderFactsLoader(
        peer: peer,
        folder: folder,
        list: widget.folderList,
        tags: widget.folderTags,
      );
      _ownFolders = OwnFolderLister(own: r.own, fetch: widget.ownFolders);
    }
    // Listened to once asked: the first notification is the ask itself.
    _facts = _loaderFor(_rec)..load();
    _facts.addListener(_onFacts);
    // A sheet that may show a job polls fast while it is open.
    _release = jobs.holdFast();
    if (jobs.listing == null || jobs.destination == null) {
      unawaited(jobs.activate());
    }
    // A song's tags: a row that had none takes them whole; one whose album
    // credit is still to be found and that named none of its own reads the
    // file's (a server since 2026-10-23 names it there).
    if (r.subject == KeepSubject.song && _text(_rec['filepath']) != null) {
      if (_untagged || (_seeksCredit && _candidate == null)) {
        _reading = true;
        unawaited(_readTags());
      } else {
        _settleCredit();
      }
    }
  }

  @override
  void dispose() {
    _release?.call();
    final facts = _facts..removeListener(_onFacts);
    final pending = _pending;
    if (pending == null) {
      facts.dispose();
    } else {
      unawaited(pending.whenComplete(facts.dispose));
    }
    _folderFacts?.dispose();
    _ownFolders?.dispose();
    if (widget.marks == null) _marks.dispose();
    super.dispose();
  }

  KeepFactsLoader _loaderFor(Map<String, dynamic> rec) {
    final lead = leadOfRec(rec);
    switch (r.subject) {
      case KeepSubject.song:
        return KeepFactsLoader.forLead(
          lead,
          peer: peer,
          own: r.own,
          fetch: widget.fetch,
        );
      case KeepSubject.album:
        return KeepFactsLoader(
          peer: peer,
          own: r.own,
          album: lead.album,
          albumArtist: lead.albumArtist,
          artist: lead.artist,
          // A compilation offers no artist copy: no artist lists.
          wantArtist: !r.compilation,
          fetch: widget.fetch,
        );
      case KeepSubject.artist:
        // The artist page's own answer: the peer is not asked again.
        final held = r.artist?.albums;
        return KeepFactsLoader(
          peer: peer,
          own: r.own,
          album: null,
          artist: lead.artist,
          peerListing: held == null || held.isEmpty ? null : held,
          fetch: widget.fetch,
        );
      case KeepSubject.folder:
        return KeepFactsLoader(
          peer: peer,
          own: r.own,
          album: null,
          artist: '',
          fetch: widget.fetch,
        );
    }
  }

  void _setRec(Map<String, dynamic> rec) {
    _rec = Map.unmodifiable(rec);
    _lead = leadOfRec(_rec);
  }

  /// The recommendation names no tags (an explorer file with the metadata
  /// setting off, an M3U row): its path and file name.
  bool get _untagged =>
      !_rec.containsKey('artist') && !_rec.containsKey('album');

  /// A song whose album credit the sheet still looks for: not an album
  /// page's (that page said), not known yet.
  bool get _seeksCredit =>
      r.subject == KeepSubject.song &&
      r.pageCredit == null &&
      _text(_rec['albumArtist']) == null;

  /// The song's tags, read once on the connected server: a row that had
  /// none takes them whole (its title, artist, album — the sheet asks its
  /// facts again for them); its album credit is the candidate either way.
  Future<void> _readTags() async {
    final path = _rec['filepath'] as String;
    MusicMetadata? m;
    try {
      m = await (widget.track ?? ApiManager().fetchTrackMetadata)(peer, path);
    } catch (_) {
      m = null;
    }
    if (!mounted) return;
    _reading = false;
    _tags = m;
    if (m != null) _candidate ??= _text(m.albumArtist);
    if (m != null && _untagged && _text(m.title) != null) {
      final next = songLeadFor(
        peer,
        path,
        m,
        albumCredit: _text(_rec['albumArtist']),
        albumArt: _text(_rec['albumArt']),
      );
      final old = _facts..removeListener(_onFacts);
      _setRec(next);
      // In place before it asks: its first word is the new loader's.
      _facts = _loaderFor(_rec)..addListener(_onFacts);
      _facts.load();
      // The card lets go of the old one as it rebuilds.
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
    _settleCredit();
    setState(() {});
  }

  /// The song's album credit became known: the recommendation carries it —
  /// the Album choice appears, its copy is keyed by it — and the album's
  /// songs are asked by it.
  void _creditKnown(String credit) {
    if (_text(_rec['albumArtist']) != null || _text(_rec['album']) == null) {
      return;
    }
    _setRec({..._rec, 'albumArtist': credit});
    _facts.albumCreditKnown(credit);
  }

  /// A song's album credit (the album page's third step, as the webapp's
  /// song window takes it): once the connected server's album list for its
  /// artist answered — or could not, or there is no artist to ask by — the
  /// one album of its album's name (and year) gives the credit, and one
  /// whose songs name different album artists gives none, whatever the
  /// song's own tag says (each half of a split album names its own artist:
  /// an album copy by it would take that half). None or several matching,
  /// or no list, the song's own [_candidate] stands. Until then no Album:
  /// it appears once and never goes.
  void _settleCredit() {
    if (!_seeksCredit || _reading || _creditSettled) return;
    if (_text(_rec['album']) == null) return;
    if (_facts.asksArtist && _facts.loadingArtist) return;
    _creditSettled = true;
    final c = _facts.facts.creditOf(_text(_rec['album']), year: _lead.year);
    switch (c.state) {
      case AlbumCredit.known:
        _creditKnown(c.credit!);
      case AlbumCredit.disagree:
        break;
      case AlbumCredit.unknown:
        final own = _candidate;
        if (own != null) _creditKnown(own);
    }
  }

  void _onFacts() {
    if (!mounted) return;
    _settleCredit();
    setState(() {});
  }

  void _toast(String message) => KeepToast.show(
    widget.parentContext.mounted ? widget.parentContext : null,
    message,
  );

  /// Close the sheet, then [then] (it acts on the page behind it).
  void _closeThen(FutureOr<void> Function() then) {
    Navigator.of(context).pop();
    unawaited(Future.sync(then));
  }

  /// Play album / Queue album: the album page's own songs when it has them,
  /// else the album's songs on the connected server once they answered —
  /// asked before the sheet closes, its loader kept until they did.
  void _albumVerb(AppLocalizations l, {required bool play}) {
    final have = r.songs;
    final Future<List<DisplayItem>?> ask = have != null && have.isNotEmpty
        ? Future.value(have)
        : _facts.albumSongs();
    _pending = ask;
    _closeThen(() async {
      final songs = await ask;
      if (songs == null || songs.isEmpty) {
        _toast(l.discoverSheetAlbumFailed(r.peerName));
        return;
      }
      if (play) {
        await BrowseKeepSheet.play(songs);
      } else {
        final n = await BrowseKeepSheet.queue(songs);
        if (n > 0) _toast(l.browserSongsAdded(n));
      }
    });
  }

  /// Play folder / Add to queue: the counted songs, in path order.
  void _folderVerb(AppLocalizations l, {required bool play}) {
    final rows = _folderFacts?.songRows;
    if (rows == null || rows.isEmpty) return;
    _closeThen(() async {
      if (play) {
        await BrowseKeepSheet.play(rows);
      } else {
        final n = await BrowseKeepSheet.queue(rows);
        if (n > 0) _toast(l.browserSongsAdded(n));
      }
    });
  }

  /// "Show in your library": the user's own server, its explorer where the
  /// files are — and, when it does not open there, a toast that says so
  /// rather than the own server's home alone.
  void _showInLibrary(String directory) {
    final l = AppLocalizations.of(context);
    final segments = directory.split('/').where((s) => s.isNotEmpty);
    final name = segments.isEmpty ? directory : segments.last;
    _closeThen(() async {
      if (!await DiscoveryKeepRoutes.showInLibrary(r.own, directory)) {
        _toast(l.discoverCopiesShowFailed(name));
      }
    });
  }

  // ── drawing ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    // The keyboard up (a New folder… name): the sheet sits above it, the
    // pinned Add on top of it, the field scrolled into what is left.
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Column(
          key: const ValueKey('browse-keep-sheet'),
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _GrabHandle(),
            Flexible(
              child: ListenableBuilder(
                listenable: Listenable.merge([_facts, ?_folderFacts]),
                builder: (context, _) => KeepCopySection(
                  jobs: jobs,
                  lead: _lead,
                  facts: _facts,
                  peerName: r.peerName,
                  albumFocus: r.subject == KeepSubject.album,
                  compilation: r.compilation,
                  toast: _toast,
                  initialChoice: r.initialScope,
                  onStarted: widget.onStarted,
                  subject: r.subject,
                  marks: _marks,
                  folder: r.folder,
                  folderFacts: _folderFacts,
                  ownFolders: _ownFolders,
                  onShowInLibrary: _showInLibrary,
                  above: [_header(l), _divider(), ..._listen(l)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The connected server did not answer what the sheet asked: the album
  /// and artist lists, or a folder's count (one that answered counts as
  /// the server answering).
  bool get _down {
    final ff = _folderFacts?.facts;
    if (r.subject == KeepSubject.folder) return ff?.countFailed ?? false;
    return _facts.facts.peerFailed && !(ff?.counted ?? false);
  }

  Widget _header(AppLocalizations l) {
    final lead = _lead;
    final f = _facts.facts;
    switch (r.subject) {
      case KeepSubject.song:
        final d = lead.durationSeconds ?? _tags?.durationSeconds;
        return _SheetHeader(
          browse: true,
          cover: _songCover(),
          title: lead.title,
          byline: [
            if (lead.artist.trim().isNotEmpty) lead.artist.trim(),
            if ((lead.album ?? '').trim().isNotEmpty) lead.album!.trim(),
          ].join('  ·  '),
          spec: [
            ?keepFormatOf(lead.filepath),
            if (d != null && d > 0)
              keepClock(Duration(milliseconds: (d * 1000).round())),
          ].join('  ·  '),
          peerName: r.peerName,
          answering: !_down,
        );
      case KeepSubject.album:
        final year = lead.year ?? f.albumYear;
        return _SheetHeader(
          browse: true,
          cover:
              r.item?.getAlbumThumb(size: 60) ??
              _tile(Icons.album, shape: BoxShape.rectangle),
          title: lead.album ?? '',
          byline: [
            ?_text(lead.albumArtist),
            if (year != null) '$year',
            if (f.albumSongCount != null)
              l.discoverSheetSongCount(f.albumSongCount!),
            if (f.albumLength != null) keepClock(f.albumLength!),
          ].join(' · '),
          peerName: r.peerName,
          answering: !_down,
        );
      case KeepSubject.artist:
        final held = r.artist;
        final count = held != null && held.albums.isNotEmpty
            ? held.albumCount
            : f.peerAlbums?.length;
        return _SheetHeader(
          browse: true,
          cover: _tile(Icons.person_outline, shape: BoxShape.circle),
          title: lead.artist,
          byline: count == null
              ? l.discoverKeepArtist
              : l.discoverSheetArtistSub(
                  l.discoverSheetAlbumCount(count),
                  r.peerName,
                ),
          peerName: r.peerName,
          answering: !_down,
        );
      case KeepSubject.folder:
        final folder = r.folder;
        final ff = _folderFacts;
        return _SheetHeader(
          browse: true,
          cover: _tile(
            Icons.folder,
            shape: BoxShape.rectangle,
            size: 32,
            color: keepTone(VelvetColors.warning),
          ),
          title: folder?.name ?? lead.title,
          // The path there, library first, wrapping between its folders.
          byline: folder == null
              ? ''
              : l.discoverSheetFolderSub(
                  folder.segments
                      .map((s) => s.replaceAll(' ', '\u00A0'))
                      .join(' › '),
                ),
          bylineLines: 3,
          status: ff == null ? null : _countWords(l, ff),
          peerName: r.peerName,
          answering: !_down,
        );
    }
  }

  /// "Counting…" → "3 songs · no subfolders" / "9 songs · 3 subfolders",
  /// or "Couldn't count its songs".
  String _countWords(AppLocalizations l, KeepFolderFactsLoader ff) {
    final f = ff.facts;
    if (f.countFailed) return l.discoverSheetCountFailed;
    final songs = f.songs;
    if (songs == null) return l.discoverSheetCounting;
    final n = folderCounts(songs);
    return [
      l.discoverSheetFolderSongCount(n.songs),
      n.subfolders == 0
          ? l.discoverSheetNoSubfolders
          : l.discoverSheetSubfolders(n.subfolders),
    ].join(' · ');
  }

  /// A song's cover: its row's, else the queue's own art (a queued
  /// track's), else the recommendation's art on the connected server, else
  /// the note tile.
  Widget _songCover() {
    final item = r.item;
    if (item != null) return item.getAlbumThumb(size: 60);
    final url = r.coverUrl;
    if (url != null && _lead.art == null) {
      return ClipRRect(
        key: const ValueKey('browse-keep-queue-cover'),
        borderRadius: BorderRadius.circular(VelvetColors.radiusSmall),
        child: Image.network(
          url,
          width: 60,
          height: 60,
          fit: BoxFit.cover,
          cacheWidth: artCacheSize(60),
          errorBuilder: (_, _, _) =>
              _tile(Icons.music_note, shape: BoxShape.rectangle),
        ),
      );
    }
    final row = DisplayItem(
      peer,
      _lead.title,
      'file',
      '/${_lead.filepath ?? ''}',
      Icon(Icons.music_note, color: VelvetColors.accent),
      null,
    );
    row.altAlbumArt = _lead.art ?? _tags?.albumArt;
    return row.getAlbumThumb(size: 60);
  }

  /// The 60 px tile of an artist (a circle, the person glyph) or a folder
  /// (radius 7, the folder glyph in the warning colour).
  Widget _tile(
    IconData icon, {
    required BoxShape shape,
    double size = 28,
    Color? color,
  }) => Container(
    width: 60,
    height: 60,
    decoration: BoxDecoration(
      shape: shape,
      color: VelvetColors.raised,
      borderRadius: shape == BoxShape.circle ? null : BorderRadius.circular(7),
      border: shape == BoxShape.circle
          ? Border.all(color: VelvetColors.border)
          : null,
    ),
    child: Icon(icon, size: size, color: color ?? VelvetColors.textSecondary),
  );

  /// Listen: an album's Play album and Queue album (and Open album › from a
  /// card or a row); a folder page's Play folder and Add to queue, waiting
  /// on the count. Nothing from a menu row, nor for an artist (the page is
  /// right behind the sheet).
  List<Widget> _listen(AppLocalizations l) {
    if (r.variant == KeepVariant.menu) return const [];
    switch (r.subject) {
      case KeepSubject.album:
        final item = r.item;
        return [
          KeepSheetLabel(l.discoverSheetListen),
          _ActionRow(
            key: const ValueKey('browse-keep-play-album'),
            icon: Icons.play_arrow,
            label: l.discoverSheetPlayAlbum,
            onTap: () => _albumVerb(l, play: true),
          ),
          _ActionRow(
            key: const ValueKey('browse-keep-queue-album'),
            icon: Icons.queue_music,
            label: l.discoverSheetQueueAlbum,
            onTap: () => _albumVerb(l, play: false),
          ),
          if (item != null &&
              r.variant == KeepVariant.item &&
              !r.hidden.contains(KeepHiddenLink.openAlbum))
            _ActionRow(
              key: const ValueKey('browse-keep-open-album'),
              icon: Icons.album,
              label: l.discoverSheetOpenAlbum,
              chevron: true,
              onTap: () =>
                  _closeThen(() => BrowserManager().openAlbumDetail(item)),
            ),
        ];
      case KeepSubject.folder:
        if (r.variant != KeepVariant.page) return const [];
        final n = _folderFacts?.facts.songs?.length;
        final ready = n != null && n > 0;
        return [
          KeepSheetLabel(l.discoverSheetListen),
          _ActionRow(
            key: const ValueKey('browse-keep-play-folder'),
            icon: Icons.play_arrow,
            label: l.discoverSheetPlayFolder,
            sub: n == null ? null : l.discoverSheetFolderSongCount(n),
            enabled: ready,
            onTap: () => _folderVerb(l, play: true),
          ),
          _ActionRow(
            key: const ValueKey('browse-keep-queue-folder'),
            icon: Icons.queue_music,
            label: l.discoverJobAddToQueue,
            enabled: ready,
            onTap: () => _folderVerb(l, play: false),
          ),
        ];
      case KeepSubject.song:
      case KeepSubject.artist:
        return const [];
    }
  }
}
