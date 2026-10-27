// album_detail_view.dart — album detail rendered INSIDE the browser body (not a
// route), so the global mini-player stays visible. Driven by
// BrowserManager.albumDetail: when set, main.dart shows this over the file list
// (in an IndexedStack) and Back dismisses it via BrowserManager.closeAlbumDetail.
//
// Layout (simplified from the original route screen): a medium-player-style
// banner — album art left, title/artist/meta right — painted over the
// album-art colour splash, then the track list. Play / Shuffle / Add all live
// in the shared BrowserToolbar above, same as every other track list. Per-track
// album runtime, and the kbps · kHz readout render only when the server reports
// them (older API builds omit them; see MusicMetadata).
//
// The banner scrolls with the songs, on every album page: at large text a
// pinned banner left the list no room on a small phone.
//
// A connected server's album (its item's server is a peer — on that
// server's stack or the user's own, Discover's "Open album") also carries
// Keep a copy: the banner names the album's real credit (resolved, never
// the "Various Artists" a page derives from disagreeing track artists),
// the slot under its facts holds the page pill — or its reserved place
// while the credit resolves, the line why there is no album copy, or with
// the gate closed an earlier copy's state as plain text — and the rows
// mark what the user's copies did with each song.

import 'package:audio_service/audio_service.dart';
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:material_ui/material_ui.dart';
import 'package:rxdart/rxdart.dart';

import '../l10n/app_localizations.dart';
import '../objects/discovery_plugins.dart';
import '../objects/display_item.dart';
import '../singletons/api.dart';
import '../singletons/browser_list.dart';
import '../singletons/media.dart';
import '../singletons/track_capture.dart';
import '../theme/velvet_theme.dart';
import '../util/ambient_color.dart';
import '../util/browse_keep_leads.dart';
import '../util/discover_badges.dart';
import '../util/media_format.dart';
import '../util/queue_actions.dart';
import '../util/stream_url.dart';
import '../util/image_cache.dart';
import '../widgets/browse_keep_entry.dart';
import '../widgets/browse_keep_pill.dart';
import '../widgets/browse_page_header.dart' show KeepNoCreditLine;
import '../widgets/player_panel.dart';
import '../widgets/track_actions_sheet.dart';
import 'discovery/browse_copy_marks.dart';
import 'discovery/copies_hub.dart';
import 'discovery/discovery_copy_marks.dart';
import 'discovery/keep_copy_ui.dart' show keepMarkerWord;

class AlbumDetailView extends StatefulWidget {
  /// The tapped album row — carries name, server, altAlbumArt (`album_art_file`),
  /// subtext, albumArtist and year, from getAlbums().
  final DisplayItem album;

  const AlbumDetailView({super.key, required this.album});

  /// How a connected server's album page makes its credit resolver (tests
  /// answer its one read).
  static AlbumCreditResolver Function() makeResolver = AlbumCreditResolver.new;

  @override
  State<AlbumDetailView> createState() => _AlbumDetailViewState();
}

class _AlbumDetailViewState extends State<AlbumDetailView> {
  List<DisplayItem>? _songs; // null while loading
  bool _error = false;
  Gradient? _ambient; // null until the seed resolves (or stays null = no tint)

  // ── Keep a copy (a connected server's album only) ──
  late final bool _peer = isKeepPeer(widget.album.server);

  // The gate as the page first built with it; read again only when a Keep
  // sheet closes here, so no way in appears or vanishes under the thumb.
  KeepGateSnapshot _gate = KeepGateSnapshot.closed;

  // The album's credit: null while it resolves.
  ResolvedCredit? _credit;

  // What the user's copies did with the album and its songs (null: the own
  // server's plug-ins are off — nothing is asked, nothing marked).
  BrowseCopyMarks? _marks;

  // The banner's node: where focus lands when the opener of a closed Keep
  // sheet is gone.
  final FocusNode _bannerFocus = FocusNode(debugLabel: 'album banner');

  // Current-track path + playing flag, distinct() so per-position playbackState
  // ticks don't rebuild the list (only a track change / play-pause flips the
  // highlight). Path matches buildServerFileMediaItem's extras['path'].
  late final Stream<({String? path, bool playing})> _nowStream =
      Rx.combineLatest2<MediaItem?, PlaybackState,
          ({String? path, bool playing})>(
        MediaManager().audioHandler.mediaItem,
        MediaManager().audioHandler.playbackState,
        (m, s) => (path: m?.extras?['path'] as String?, playing: s.playing),
      ).distinct((a, b) => a.path == b.path && a.playing == b.playing);

  @override
  void initState() {
    super.initState();
    if (_peer) {
      final peer = widget.album.server!;
      _gate = CopiesHub().gateFor(peer);
      _credit = AlbumCreditResolver.fromOpener(widget.album);
      if (_gate.marks) {
        _marks = BrowseCopyMarks(jobs: CopiesHub().jobsFor(peer), peer: peer)
          ..addListener(_onMarks);
      }
    }
    _load();
    _loadAmbient();
  }

  @override
  void dispose() {
    _marks
      ?..removeListener(_onMarks)
      ..dispose();
    _bannerFocus.dispose();
    super.dispose();
  }

  void _onMarks() {
    if (mounted) setState(() {});
  }

  Future<void> _load() async {
    try {
      final songs = await ApiManager()
          .fetchAlbumSongs(widget.album.data,
              useThisServer: widget.album.server,
              year: widget.album.year,
              albumArtist: widget.album.albumArtist,
              artist: widget.album.trackArtist);
      // Publish to BrowserManager so the top toolbar's download / add-all act on
      // these songs.
      BrowserManager().albumDetailSongs = songs;
      if (!mounted) return;
      setState(() => _songs = songs);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _songs = const [];
        _error = true;
      });
    }
    if (!_peer) return;
    if (_credit == null) {
      await _resolve(_songs ?? const []);
    } else {
      _ask();
    }
  }

  // The credit the opener did not know, from the songs' own album-artist or
  // the server's albums by their artist (AlbumCreditResolver). Stored on the
  // album item, so Back reuses it.
  Future<void> _resolve(List<DisplayItem> songs) async {
    final r = await AlbumDetailView.makeResolver().resolve(widget.album, songs);
    if (!mounted) return;
    setState(() => _credit = r);
    _ask();
  }

  // ── Keep a copy's recommendations and marks ──

  /// The connected server's name, as the page's words say it.
  String get _peerName {
    final peer = widget.album.server!;
    return peer.federationPeerName ?? peer.displayName;
  }

  /// The resolved credit, when known.
  String? get _knownCredit =>
      _credit?.state == AlbumCredit.known ? _credit!.credit : null;

  /// The loaded songs' own artists, in song order: a credit none of them
  /// carries is a compilation's (as the webapp's album page reads one).
  List<String>? get _songArtists {
    final songs = _songs;
    if (songs == null || songs.isEmpty) return null;
    final seen = <String>{};
    return [
      for (final s in songs)
        if ((s.metadata?.artist ?? '').trim().isNotEmpty &&
            seen.add(nameKey(s.metadata!.artist)))
          s.metadata!.artist!,
    ];
  }

  /// The album's recommendation (null until its credit is known).
  Map<String, dynamic>? get _albumRec => _knownCredit == null
      ? null
      : albumLeadOf(widget.album,
          credit: _knownCredit, artists: _songArtists);

  /// The page pill's request: the album by its credit, its songs' own
  /// artists and the songs themselves (Play album takes them).
  BrowseKeepRequest? get _albumRequest => BrowseKeepRequest.album(
      widget.album,
      variant: KeepVariant.page,
      credit: _knownCredit,
      artists: _songArtists,
      songs: _songs);

  /// A song row's recommendation, the page's credit in it once known.
  Map<String, dynamic>? _songRec(DisplayItem s) =>
      songLeadOf(s, albumCredit: _knownCredit);

  // One batch once the rows drew and the credit resolved: the album's rec
  // and the first 99 rows'.
  void _ask() {
    final marks = _marks;
    final songs = _songs;
    if (marks == null || songs == null) return;
    final album = _albumRec;
    marks.ask([
      ?album,
      for (final s in songs.take(album == null ? 100 : 99)) ?_songRec(s),
    ]);
  }

  /// A Keep sheet closed on the page: the gate is read again (the sheet
  /// asked the page's marks of its opener again).
  void _afterKeep() {
    if (!mounted) return;
    setState(() => _gate = CopiesHub().gateFor(widget.album.server));
  }

  void _keepAlbum() {
    final req = _albumRequest;
    if (req == null) return;
    BrowseKeepEntry.open(context, req,
        marks: _marks, fallback: _bannerFocus, closed: _afterKeep);
  }

  // A song row's request: the page's credit when known, else its word that
  // there is none (the sheet then offers no Album) — while it still
  // resolves, the sheet finds the song's own.
  BrowseKeepRequest? _songRequest(DisplayItem s) => _peer
      ? BrowseKeepRequest.song(s,
          albumCredit: _knownCredit,
          pageCredit: _credit?.state,
          hidden: const {KeepHiddenLink.openAlbum})
      : null;

  /// A song row's own stable key (its long-press, or a screen reader's
  /// action on it, opened the sheet: focus goes back to the row, not its ⋮).
  static String _rowKey(BrowseKeepRequest req) => '${req.focusKey}|row';

  void _keepSong(DisplayItem s) {
    final req = _songRequest(s);
    if (req == null) return;
    BrowseKeepEntry.open(context, req,
        marks: _marks,
        from: BrowseKeepEntry.anchorOf(_rowKey(req)),
        fallback: _bannerFocus,
        closed: _afterKeep);
  }

  /// The track sheet's Keep row for [s]: the song's own state as the page's
  /// marks know it — and the album copy, while it runs. [fromRow]: the
  /// row's long-press opened the sheet.
  TrackSheetKeep? _trackKeep(DisplayItem s, {bool fromRow = false}) {
    if (!_gate.allows(kScopeSong)) return null;
    final req = _songRequest(s);
    if (req == null) return null;
    final marks = _marks;
    final albumJob = marks?.albumJob(_albumRec);
    final album = albumJob == null
        ? null
        : (name: widget.album.name, job: albumJob);
    final rec = req.lead;
    return TrackSheetKeep(
      request: req,
      state: marks != null && marks.knows(rec)
          ? KeepMenuState.known(marks.songMarker(rec, albumRec: _albumRec),
              album: album)
          : KeepMenuState.ask(album: album),
      marks: marks,
      from: fromRow ? BrowseKeepEntry.anchorOf(_rowKey(req)) : null,
      fallback: _bannerFocus,
      closed: _afterKeep,
    );
  }

  // Colour splash seeded from the cover (vibrant, falling back to dominant);
  // anchored top-left to glow from the art. Stays null on missing / near-
  // grayscale art (the engine's grayscale fallback).
  Future<void> _loadAmbient() async {
    final url = _artUrl();
    if (url == null) return;
    final seed = await dominantAlbumColor(url, vibrant: true) ??
        await dominantAlbumColor(url);
    if (!mounted || seed == null) return;
    final grad = ambientGradient(seed,
        base: VelvetColors.bg,
        vibrant: true,
        center: Alignment.topLeft,
        radius: 1.0); // 80% of the engine default (1.25)
    if (grad == null) return;
    setState(() => _ambient = grad);
  }

  String? _artUrl([String compress = 'l']) {
    final aa = widget.album.altAlbumArt;
    final server = widget.album.server;
    if (server == null || aa == null) return null;
    return buildAlbumArtUrl(server, aa, compress: compress);
  }

  // ── derived metadata ──
  String _artistLabel(List<DisplayItem> songs, AppLocalizations l) {
    final artists = songs
        .map((s) => s.metadata?.artist)
        .where((a) => a != null && a.trim().isNotEmpty)
        .toSet();
    if (artists.isEmpty) return '';
    if (artists.length == 1) return artists.first!;
    return l.variousArtists;
  }

  // A connected server's banner never derives "Various Artists": that label
  // would read as the credit a compilation copies under. Its credit when
  // known, else the songs' own artists in song order ("ALM, Night Owl
  // Radio").
  String _peerCreditLabel(List<DisplayItem>? songs) {
    final credit = _knownCredit;
    if (credit != null) return credit;
    if (songs == null) return '';
    final seen = <String>{};
    final names = <String>[];
    for (final s in songs) {
      final a = s.metadata?.artist?.trim();
      if (a == null || a.isEmpty) continue;
      if (seen.add(nameKey(a))) names.add(a);
    }
    return names.join(', ');
  }

  String? _yearLabel(List<DisplayItem> songs) {
    for (final song in songs) {
      if (song.metadata?.year != null) return song.metadata!.year.toString();
    }
    return null;
  }

  // Format from the first track's file extension (e.g. ".flac" → "FLAC").
  String? _formatLabel(List<DisplayItem> songs) {
    for (final s in songs) {
      final fp = s.data ?? '';
      final dot = fp.lastIndexOf('.');
      if (dot > 0 && dot < fp.length - 1) {
        return fp.substring(dot + 1).toUpperCase();
      }
    }
    return null;
  }

  // Album runtime — only when EVERY track reports a duration (newer servers),
  // so a partial sum never shows a misleading total.
  Duration? _runtime(List<DisplayItem> songs) {
    if (songs.isEmpty) return null;
    int ms = 0;
    for (final s in songs) {
      final d = s.metadata?.duration;
      if (d == null) return null;
      ms += d.inMilliseconds;
    }
    return Duration(milliseconds: ms);
  }

  // Under ten minutes a runtime reads as a clock ("0:29"): rounded to whole
  // minutes a short EP read "0 min".
  String _runtimeLabel(Duration d) {
    if (d < const Duration(minutes: 10)) {
      return formatDuration(d, padMinutes: false);
    }
    final mins = (d.inSeconds / 60).round();
    if (mins < 60) return '$mins min';
    return '${mins ~/ 60} hr ${mins % 60} min';
  }

  int? _bitrate(List<DisplayItem> songs) {
    for (final s in songs) {
      if (s.metadata?.bitrate != null) return s.metadata!.bitrate;
    }
    return null;
  }

  int? _sampleRate(List<DisplayItem> songs) {
    for (final s in songs) {
      if (s.metadata?.sampleRate != null) return s.metadata!.sampleRate;
    }
    return null;
  }

  // ── actions ──
  // Row tap: defer to the shared TapBehavior setting (the same one the file
  // browser uses). A pure add-to-queue shows a confirmation toast. An armed
  // browse-to-pick eats the tap first — nothing may queue mid-pick.
  Future<void> _onRowTap(int index) async {
    final songs = _songs;
    if (songs == null || index < 0 || index >= songs.length) return;
    // Read before tryCapture — a capture clears the pending request.
    final route = TrackCapture.pending?.returnScreen;
    switch (TrackCapture.tryCapture(songs[index])) {
      case CaptureResult.captured:
        if (route != null) {
          Navigator.push(context, MaterialPageRoute(builder: route));
        }
        return;
      case CaptureResult.rejected:
        showCaptureRejectedToast(context);
        return;
      case CaptureResult.pass:
        break;
    }
    if (await handleTrackTap(songs, index)) _toast();
  }

  // ── per-row overflow ──
  // The same sheet the browser's track rows open, so a song offers the same
  // actions wherever you meet it — and gains Add to playlist / Download,
  // which the dropdown this replaced never had (and, on a connected server,
  // Keep a copy…).
  void _showTrackActions(DisplayItem item, {bool fromRow = false}) =>
      showTrackActionsSheet(context, item,
          keep: _trackKeep(item, fromRow: fromRow));


  // "Added to queue" confirmation. Floats above the docked mini-player — that
  // overlay sits in a higher layer at the bottom and would otherwise hide a
  // standard bottom snackbar (the bug this fixes).
  void _toast() {
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(l.browserSongsAdded(1)),
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.only(
        left: 16,
        right: 16,
        bottom: PlayerPanel.kCollapsedHeight +
            MediaQuery.of(context).viewPadding.bottom +
            8,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final songs = _songs;
    // Ambient colour splash spans the whole view (banner + track list), glowing
    // from the top-left and fading down across the song list. The rows are
    // transparent, so it shows through; the engine's contrast floor keeps titles
    // legible, and it fades to bg (opaque) so the offstage browser never shows.
    return AnimatedContainer(
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        gradient: _ambient ??
            LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [VelvetColors.surface, VelvetColors.bg],
            ),
      ),
      // One scroll for the banner and the songs, so at large text the list
      // is reachable on a small phone.
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _banner(l, songs)),
          if (songs == null)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (songs.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    _error ? l.mainFailedToConnect : l.mainQueueEmpty,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        color: VelvetColors.textSecondary, fontSize: 14),
                  ),
                ),
              ),
            )
          else
            _trackList(songs),
          const SliverPadding(padding: EdgeInsets.only(bottom: 12)),
        ],
      ),
    );
  }

  // ── banner: back/overflow + medium-player-style art-left header over the splash ──
  Widget _banner(AppLocalizations l, List<DisplayItem>? songs) {
    final artUrl = _artUrl();
    final ts = MediaQuery.textScalerOf(context);
    final large = ts.scale(1) > 1.3;
    // The server's album credit (what the card showed) when it gave one; else
    // derived from the tracks — Various Artists when they disagree. A
    // connected server's: its resolved credit, else its songs' artists.
    final artist = _peer
        ? _peerCreditLabel(songs)
        : widget.album.albumArtist ??
            (songs == null ? '' : _artistLabel(songs, l));

    final metaParts = <String>[];
    if (songs != null) {
      final year = _yearLabel(songs);
      if (year != null) metaParts.add(year);
      metaParts.add(l.trackCount(songs.length));
      final rt = _runtime(songs);
      if (rt != null) metaParts.add(_runtimeLabel(rt));
      final fmt = _formatLabel(songs);
      if (fmt != null) metaParts.add(fmt);
      final br = _bitrate(songs);
      if (br != null) metaParts.add(formatBitrate(br));
      final sr = _sampleRate(songs);
      if (sr != null) metaParts.add(formatSampleRate(sr));
    }

    final facts = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.album.name,
          maxLines: _peer && large ? 3 : 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            height: 1.12,
            letterSpacing: -0.2,
            color: VelvetColors.textPrimary,
          ),
        ),
        if (artist.isNotEmpty) ...[
          const SizedBox(height: 3),
          Text(
            artist,
            key: const ValueKey('album-banner-credit'),
            maxLines: _peer ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style:
                TextStyle(fontSize: 13.5, color: VelvetColors.textSecondary),
          ),
        ],
        if (metaParts.isNotEmpty) ...[
          const SizedBox(height: 5),
          Text(
            metaParts.join('  ·  '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 10,
              letterSpacing: 0.2,
              color: VelvetColors.textTertiary,
            ),
          ),
        ],
      ],
    );
    final cover = ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 86,
        height: 86,
        child: artUrl != null
            ? Image.network(artUrl,
                fit: BoxFit.cover,
                cacheWidth: artCacheSize(86),
                errorBuilder: (_, _, _) => albumArtFallback(iconSize: 30))
            : albumArtFallback(iconSize: 30),
      ),
    );

    // The banner reads as one header node — the album, then its facts —
    // and the pill (or the line in its place) follows it. Focus can land on
    // it when the opener of a closed Keep sheet is gone.
    Widget headed(Widget child) => Semantics(
          container: true,
          header: true,
          label: widget.album.name,
          value: [
            if (artist.isNotEmpty) artist,
            ...metaParts,
          ].join(' · '),
          child: Focus(
            focusNode: _bannerFocus,
            child: ExcludeSemantics(child: child),
          ),
        );

    final pick = _marks?.pillJob(_albumRec, kScopeAlbum);
    final form = KeepPillForm.of(l, pick, album: widget.album.data);
    final barFraction =
        _gate.allows(kScopeAlbum) && form.live ? form.fraction : null;

    return Container(
      // The splash is painted by the root now; the banner just carries the
      // hairline divider and lets the gradient show through.
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: VelvetColors.border)),
      ),
      child: Stack(
        children: [
          // Back + overflow live in the top toolbar now; the banner is just the
          // art-left header. Top pad clears the AppBar toolbar above it.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 12, 16),
            child: LayoutBuilder(builder: (context, box) {
              // The text column beside the cover; the pill sits in it when
              // its longest words fit there, else under the cover at the
              // full width (measured once a page, never between states).
              final column = box.maxWidth - 86 - 14;
              final under =
                  _peer && !KeepPagePill.fitsBeside(l, column, ts, _peerName);
              final slot = _slot(l, pick, fullWidth: under);
              if (!_peer) {
                // Play + Shuffle used to sit beside the facts, stacked. They
                // live in the top toolbar now (see BrowserToolbar's album
                // branch) so the controls are in the same place on every
                // track list.
                return headed(Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    cover,
                    const SizedBox(width: 14),
                    Expanded(child: facts),
                  ],
                ));
              }
              if (under) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    headed(Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        cover,
                        const SizedBox(width: 14),
                        Expanded(child: facts),
                      ],
                    )),
                    slot,
                  ],
                );
              }
              // The header node is the facts it reads (the cover beside
              // them says nothing), the pill its own node under it.
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(child: cover),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        headed(facts),
                        slot,
                      ],
                    ),
                  ),
                ],
              );
            }),
          ),
          if (barFraction != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: KeepHeaderBar(fraction: barFraction),
            ),
        ],
      ),
    );
  }

  // The slot under the banner's facts (a connected server's named album):
  //   gate open, credit known      the pill, its live line while it copies
  //   gate open, credit resolving  the pill's 44 pt, held empty
  //   gate open, credits disagree  the line why there is no album copy
  //   gate open, credit unknown    nothing — the held place folds away
  //   gate closed, a copy of it    its state as plain text
  //   otherwise                    nothing
  // The only shift the page makes is that fold, eased over 150 ms.
  Widget _slot(AppLocalizations l, KeepChoiceJob? pick,
      {required bool fullWidth}) {
    Widget? child;
    final credit = _credit;
    final named = widget.album.data != null;
    if (_peer && named) {
      final open = _gate.allows(kScopeAlbum);
      if (open && credit == null) {
        child = const KeepReservedSlot();
      } else if (open && credit!.state == AlbumCredit.disagree) {
        child = const KeepNoCreditLine();
      } else if (credit?.state == AlbumCredit.known &&
          KeepPageAction.shows(l, open, pick)) {
        final req = _albumRequest;
        child = KeepFocusAnchor(
          focusKey: req?.focusKey,
          builder: (context, node) => KeepPageAction(
            open: open,
            pick: pick,
            subject: KeepSubject.album,
            name: widget.album.name,
            peerName: _peerName,
            album: widget.album.data,
            fullWidth: fullWidth,
            onTap: _keepAlbum,
            focusNode: node,
          ),
        );
      }
    }
    return AnimatedSize(
      duration: const Duration(milliseconds: 150),
      curve: Curves.easeOut,
      alignment: Alignment.topLeft,
      child: child == null
          ? const SizedBox(width: double.infinity)
          : Padding(padding: const EdgeInsets.only(top: 12), child: child),
    );
  }

  // Tappable rating for a track row: small stars when rated, a single outline
  // star otherwise; opens the rating form on tap and refreshes the list on
  // change. Empty placeholder if the row has no server/path (shouldn't happen

  /// Disc a track belongs to. The server treats an absent disc tag as disc 1
  /// when it sorts (COALESCE(disc_number, 1) in ALBUM_TRACK_ORDER), so the
  /// grouping here has to agree or a half-tagged album would show a phantom
  /// extra disc.
  int _discOf(DisplayItem s) => s.metadata?.disc ?? 1;

  Widget _trackList(List<DisplayItem> songs) {
    // Rows arrive already in album order (server-side ALBUM_TRACK_ORDER:
    // disc, then track, with untagged tracks last within their disc), so this
    // only has to RENDER that order — never re-sort it.
    final discs = {for (final s in songs) _discOf(s)};
    final showDiscs = discs.length > 1;
    // Real track numbers, but only when the album actually carries them.
    // Falling back to the row's position per-track would hand an untagged
    // file a tidy sequential number and hide the fact it has no tag; falling
    // back for the WHOLE album keeps a completely untagged one readable.
    final anyTrackNumbers =
        songs.any((s) => s.metadata?.track != null);

    // Flattened render list: a disc header owns a null song.
    final entries = <({DisplayItem? song, int index, int disc})>[];
    int? lastDisc;
    for (var i = 0; i < songs.length; i++) {
      final d = _discOf(songs[i]);
      if (showDiscs && d != lastDisc) {
        entries.add((song: null, index: -1, disc: d));
        lastDisc = d;
      }
      entries.add((song: songs[i], index: i, disc: d));
    }

    final albumRec = _albumRec;
    final keepSongs = _peer && _gate.allows(kScopeSong);
    return StreamBuilder<({String? path, bool playing})>(
      stream: _nowStream,
      initialData: (path: null, playing: false),
      builder: (context, snap) {
        final now = snap.data ?? (path: null, playing: false);
        final l = AppLocalizations.of(context);
        return SliverPadding(
          padding: const EdgeInsets.only(top: 4),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, e) {
                final entry = entries[e];
                final s = entry.song;
                if (s == null) return _discHeader(l, entry.disc);
                final title = s.metadata?.title ?? (s.data ?? '').split('/').last;
                final rec = _marks == null ? null : _songRec(s);
                final mark =
                    rec == null ? null : _marks!.songMarker(rec, albumRec: albumRec);
                final req = keepSongs ? _songRequest(s) : null;
                return _SongRow(
                  // A track with no number inside an otherwise-tagged album shows
                  // a dash rather than a made-up one.
                  number: anyTrackNumbers
                      ? s.metadata?.track
                      : entry.index + 1,
                  title: title,
                  active: now.path != null && now.path == s.data,
                  playing: now.playing,
                  mark: mark,
                  focusKey: req?.focusKey,
                  rowFocusKey: req == null ? null : _rowKey(req),
                  keepLabel: req == null ? null : l.browseKeepOfItem(title),
                  onKeep: req == null ? null : () => _keepSong(s),
                  onTap: () => _onRowTap(entry.index),
                  onMenu: () => _showTrackActions(s),
                  onHold: () => _showTrackActions(s, fromRow: true),
                );
              },
              childCount: entries.length,
            ),
          ),
        );
      },
    );
  }

  Widget _discHeader(AppLocalizations l, int disc) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
      child: Row(
        children: [
          Icon(Icons.album_outlined, size: 13, color: VelvetColors.primary),
          const SizedBox(width: 7),
          Text(
            l.albumDiscNumber(disc),
            style: TextStyle(
              color: VelvetColors.primary,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Container(height: 1, color: VelvetColors.border)),
        ],
      ),
    );
  }
}

/// One track row: number (or active EQ/play indicator), title, and the
/// overflow that opens the shared TrackActionsSheet. Duration and rating both
/// live in that sheet now — the row is just the song. The row tap itself
/// follows the shared TapBehavior setting.
///
/// On a connected server's album the row also marks what the user's copies
/// did with the song ([mark], a second line under the title — only marked
/// rows grow) and offers a screen reader "Keep a copy of {title}…"
/// ([onKeep]).
class _SongRow extends StatelessWidget {
  /// Null when the track carries no number in a tagged album.
  final int? number;
  final String title;
  final bool active;
  final bool playing;
  final CopyMarker? mark;

  /// The ⋮'s stable key and the row's own, for focus to come back to the
  /// one that opened the sheet (BrowseKeepEntry).
  final String? focusKey;
  final String? rowFocusKey;
  final String? keepLabel;
  final VoidCallback? onKeep;
  final VoidCallback onTap;

  /// The ⋮'s and the row's long-press (the same sheet).
  final VoidCallback onMenu;
  final VoidCallback onHold;

  const _SongRow({
    required this.number,
    required this.title,
    required this.active,
    required this.playing,
    this.mark,
    this.focusKey,
    this.rowFocusKey,
    this.keepLabel,
    this.onKeep,
    required this.onTap,
    required this.onMenu,
    required this.onHold,
  });

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final shown = number == null ? '--' : number.toString().padLeft(2, '0');
    final label = [
      if (number != null) shown,
      title,
      if (mark != null) keepMarkerWord(l, mark!),
    ].join(', ');
    return Semantics(
      container: true,
      label: label,
      customSemanticsActions: {
        if (onKeep != null && keepLabel != null)
          CustomSemanticsAction(label: keepLabel!): onKeep!,
      },
      child: Material(
        color: active ? VelvetColors.primaryDim : Colors.transparent,
        child: KeepFocusAnchor(
          focusKey: rowFocusKey,
          builder: (context, node) => InkWell(
            focusNode: node,
            onTap: onTap,
            // Long-press opens the same sheet the ⋮ does, which is what a
            // browser row has always done. A song offering different gestures
            // depending on which screen you met it on is the inconsistency.
            onLongPress: onHold,
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                      color: active ? VelvetColors.primary : Colors.transparent,
                      width: 2),
                  bottom: BorderSide(color: VelvetColors.border, width: 0.5),
                ),
              ),
              padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: SizedBox(
                      width: 24,
                      child: Center(
                        child: active
                            ? Icon(playing ? Icons.graphic_eq : Icons.play_arrow,
                                size: playing ? 18 : 16,
                                color: VelvetColors.primary)
                            : Text(
                                shown,
                                style: TextStyle(
                                  fontFamily: 'monospace',
                                  fontSize: 13,
                                  color: VelvetColors.textTertiary,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ExcludeSemantics(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            title,
                            // Its own line; two at large text, the mark under.
                            maxLines:
                                MediaQuery.textScalerOf(context).scale(1) > 1.3
                                    ? 2
                                    : 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight:
                                  active ? FontWeight.w500 : FontWeight.w400,
                              color: active
                                  ? VelvetColors.primary
                                  : VelvetColors.textPrimary,
                            ),
                          ),
                          // The title keeps its own line; a mark is a second
                          // one under it ("in your collection").
                          if (mark != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 2),
                              child: DiscoveryRowMarkerLine(marker: mark!),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  // Same overflow the browser's track rows carry, opening the
                  // same sheet. Rating lives in there now, which is why the row's
                  // inline stars are gone. 44 pt, the app's touch floor.
                  KeepFocusAnchor(
                    focusKey: focusKey,
                    builder: (context, node) => IconButton(
                      focusNode: node,
                      icon: Icon(Icons.more_vert,
                          size: 20, color: VelvetColors.textSecondary),
                      tooltip: l.browserMoreActionsFor(title),
                      padding: EdgeInsets.zero,
                      constraints:
                          const BoxConstraints(minWidth: 44, minHeight: 44),
                      onPressed: onMenu,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
