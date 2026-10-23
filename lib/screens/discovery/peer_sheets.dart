import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../objects/discovery.dart';
import '../../objects/discovery_plugins.dart';
import '../../objects/display_item.dart';
import '../../objects/server.dart';
import '../../singletons/api.dart';
import '../../singletons/browser_list.dart';
import '../../singletons/downloads.dart';
import '../../singletons/server_list.dart';
import '../../singletons/settings.dart';
import '../../theme/velvet_theme.dart';
import '../../util/discover_badges.dart' show nameKey;
import '../../util/queue_actions.dart';
import '../../util/stream_url.dart';
import 'copy_news.dart';
import 'discovery_jobs_controller.dart';
import 'discovery_keep_routes.dart';
import 'discovery_page_controller.dart';
import 'discovery_widgets.dart' show discoveryToast;
import 'keep_copy_card.dart';
import 'keep_copy_facts.dart';
import 'keep_copy_ui.dart';
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
class _SheetHeader extends StatelessWidget {
  final Widget cover;
  final String title;
  final String byline;
  final String? spec;
  final String peerName;
  final bool answering;
  const _SheetHeader({
    required this.cover,
    required this.title,
    required this.byline,
    this.spec,
    required this.peerName,
    required this.answering,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Padding(
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
                  maxLines: 1,
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
                      maxLines: 1,
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
                                : VelvetColors.textTertiary,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            answering
                                ? l.discoverSheetPeerOnline(peerName)
                                : l.discoverSheetPeerNotAnswering(peerName),
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
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A 52 px action row: a 24 px icon, the label (and an optional second
/// line), an optional chevron.
class _ActionRow extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final String? sub;
  final bool chevron;
  final VoidCallback onTap;
  const _ActionRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.iconColor,
    this.sub,
    this.chevron = false,
  });

  @override
  Widget build(BuildContext context) => InkWell(
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
