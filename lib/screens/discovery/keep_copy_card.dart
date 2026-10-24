import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../objects/discovery.dart';
import '../../objects/discovery_plugins.dart';
import '../../objects/display_item.dart';
import '../../singletons/settings.dart';
import '../../theme/velvet_theme.dart';
import '../../util/browse_keep_leads.dart'
    show FolderRef, KeepSubject, kFederationSource;
import '../../util/discover_badges.dart';
import '../../util/discover_copy_gate.dart';
import '../../util/discover_jobs.dart';
import '../../util/queue_actions.dart';
import '../../widgets/federation_widgets.dart';
import 'browse_copy_marks.dart';
import 'destination_sheet.dart';
import 'discovery_jobs_controller.dart';
import 'discovery_keep_routes.dart';
import 'keep_copy_facts.dart';
import 'keep_copy_ui.dart';
import 'keep_folder_body.dart';
import 'keep_folder_facts.dart';

/// "Keep a copy" on a connected server's song or album sheet (the design
/// canvas's PhoneKeepStates board): the KEEP A COPY label and one card.
///
/// The card offers only the scopes the server lists for this row
/// ([DiscoveryJobsController.scopesForRow] / [scopesForCard] — Album needs
/// the album and its artist, Artist the artist, never Folder): This song |
/// Album | Artist, each with its size, and under Artist "Only the N albums
/// you don't have" (hidden when none is missing by name). Then where files
/// land and ONE pill named for the choice. Once the chosen scope has a job,
/// that job's line replaces the destination and the pill: waiting,
/// copying (bar, the server's status line, Cancel), stopping, and every
/// outcome with its verbs.
///
/// Hidden — no label, no card, no gap — unless the server's plug-ins are
/// on, the copy plug-in is listed with a scope this row has, and jobs are
/// allowed; a missing upload right or no library to put files in reads as
/// one plain line instead ([copyGate]).
///
/// The recommendation every call sends is [lead]'s raw row, unchanged — on
/// an album card, its best row's.
///
/// Entered while browsing a connected server ([subject] set — the phone
/// spec's "the sheet, entered from browsing"), the card follows what the
/// sheet copies: a song offers This song · Album · Artist · Folder, each
/// once its facts say so (Album only with the album's known credit, Folder
/// only from an explorer file row), appended as they arrive; an album
/// offers Album · Artist (a compilation its lone Album); an artist has no
/// chips (every album of theirs, or only the ones the library lacks, and
/// what the copy leaves out); a folder has no chips but where it lands
/// (keep_folder_body.dart) — or, past the server's cap, one line. Artist
/// counts THEIR albums (planArtistAlbums), never the ones they only appear
/// on. Its jobs are the sheet's own lookup ([marks]), never Discover's
/// rows; a start, Retry and Add again send a folder's landing; a refused
/// start stays as one plain line; New seeds never shows. The card then
/// draws the sheet's whole body ([above] and itself scrolling, its Add
/// pinned in a bar under them).
class KeepCopySection extends StatefulWidget {
  final DiscoveryJobsController jobs;
  final DiscoveryLead lead;

  /// The album sheet: the card's scopes (no song), Album preselected.
  final bool albumFocus;

  /// The album card's rows, best first (album focus).
  final List<DiscoveryLead> cardLeads;

  /// A compilation card (album focus): the album only.
  final bool compilation;
  final KeepFactsLoader facts;

  /// The connected server's name, for the lines that name it.
  final String peerName;

  /// "New seeds" on a copy whose server was re-paired since the row was
  /// drawn (closes the sheet and asks Discover again).
  final VoidCallback? onNewSeeds;

  /// A floating toast above the mini player.
  final void Function(String message)? toast;

  /// The choice the card opens on (song / album / artist), when offered;
  /// else This song (Album in album focus).
  final String? initialChoice;

  /// A copy the server took as new (a start, a Retry, an Add again): the
  /// sheet toasts it once it closes.
  final void Function(DiscoveryJob job)? onStarted;

  /// Entered from browsing a connected server: what the sheet copies (null:
  /// Discover's sheets, as they always were).
  final KeepSubject? subject;

  /// Browsing: the jobs the card shows — the sheet's lookup of its own
  /// recommendations.
  final BrowseCopyMarks? marks;

  /// Browsing: the folder (folder focus's, or an explorer file row's — the
  /// Folder chip), its count and tags, and the user's own folders "Into a
  /// folder…" lists.
  final FolderRef? folder;
  final KeepFolderFactsLoader? folderFacts;
  final OwnFolderLister? ownFolders;

  /// Browsing: "Show in your library" on a folder copy that landed — its
  /// directory on the user's own server ("/copies/Boukmanflow/…").
  final void Function(String directory)? onShowInLibrary;

  /// Browsing: the sheet's parts above the card (its header, Listen).
  final List<Widget> above;

  const KeepCopySection({
    super.key,
    required this.jobs,
    required this.lead,
    required this.facts,
    required this.peerName,
    this.albumFocus = false,
    this.cardLeads = const [],
    this.compilation = false,
    this.onNewSeeds,
    this.toast,
    this.initialChoice,
    this.onStarted,
    this.subject,
    this.marks,
    this.folder,
    this.folderFacts,
    this.ownFolders,
    this.onShowInLibrary,
    this.above = const [],
  });

  @override
  State<KeepCopySection> createState() => _KeepCopySectionState();
}

/// What the chips choose between (artist covers both artist scopes).
const String _kChipArtist = kScopeArtist;

/// A path segment never breaks inside itself: a line of crumbs breaks only
/// between the › separators.
String _hold(String s) => s.replaceAll(' ', '\u00A0');

/// A path not landed yet as the card draws it: its [crumbs] (library \u203A
/// folders, slot marks inside), whether an artist copy's albums each take a
/// folder under it ([perAlbum]: "\u203A one folder per album"), the [scope]
/// whose note it takes ([keepSlotNote]), and whether it would pass the
/// server's cap ([tooLong]: no crumbs, the warning in their place).
typedef _Place = ({
  List<String> crumbs,
  bool perAlbum,
  String scope,
  bool tooLong,
});

class _KeepCopySectionState extends State<KeepCopySection> {
  late String? _chip = widget.initialChoice == kScopeArtistMissing
      ? _kChipArtist
      : widget.initialChoice;
  bool _onlyMissing = true;
  String? _error;

  /// [_error] is the start refused because where files land moved (the
  /// warning colour): the "Files go to" line above is already the new one
  /// (drawn under a job's line too while the warning stands). It goes once
  /// the gate closes (nowhere takes files: no path to point at) and when
  /// Change is tapped (the user is checking that path).
  bool _moved = false;

  /// Where the card showed the files going on its last build — what a
  /// start sends ([DiscoveryJobsController.start]'s `shown`).
  CollectionDestination? _drawn;

  /// The pill's place, and the job line's when it stands in for the pill,
  /// for [_revealPill].
  final GlobalKey _pillAnchor = GlobalKey();
  final GlobalKey _jobAnchor = GlobalKey();

  /// The user chose a chip on this card (the only-missing box landing after
  /// that brings the pill back into view too).
  bool _chipChosen = false;

  /// Whether the only-missing box showed on the last build.
  bool _missingShown = false;

  /// Browsing: the copies this card started, by slot — the sheet's lookup
  /// may not have answered them yet; the job list's newer word on each wins.
  final Map<String, DiscoveryJob> _startedHere = {};

  /// Browsing: the folder's landing and place, when the card has a folder.
  KeepFolderChoice? _folderChoice;

  DiscoveryJobsController get jobs => widget.jobs;
  DiscoveryLead get lead => widget.lead;
  bool get _browse => widget.subject != null;

  @override
  void initState() {
    super.initState();
    // Where files land, read again with every card that opens (it may have
    // changed on another device): the last one known is drawn meanwhile and
    // the answer replaces it.
    if (jobs.pluginsOn) unawaited(jobs.loadDestination());
    final folder = widget.folder;
    if (_browse && folder != null) {
      _folderChoice = KeepFolderChoice(folder)..addListener(_onFolderChoice);
      // Folder focus counts its folder as the sheet opens.
      if (widget.subject == KeepSubject.folder) {
        unawaited(widget.folderFacts?.count());
      }
    }
    if (_browse) _ask();
  }

  @override
  void didUpdateWidget(KeepCopySection old) {
    super.didUpdateWidget(old);
    // A song's tags or its album's credit arrived: the new recommendation
    // is looked up too.
    if (_browse &&
        BrowseCopyMarks.keyOf(old.lead.raw) !=
            BrowseCopyMarks.keyOf(lead.raw)) {
      _ask();
    }
  }

  @override
  void dispose() {
    _folderChoice
      ?..removeListener(_onFolderChoice)
      ..dispose();
    super.dispose();
  }

  void _onFolderChoice() {
    if (mounted) setState(() {});
  }

  /// Browsing: what the user already did with this card's things — one
  /// lookup as it opens, of what the page's own marks have no answer for
  /// (their ask may still be out, or may have failed: asked afresh).
  void _ask() {
    final marks = widget.marks;
    if (marks == null) return;
    final unknown = [
      for (final r in [lead.raw, ?_folderRec])
        if (!marks.knows(r)) r,
    ];
    if (unknown.isNotEmpty) unawaited(marks.ask(unknown, fresh: true));
  }

  /// The folder's recommendation: its path on the connected server and its
  /// name (the one the folder's own lookup and start send).
  Map<String, dynamic>? get _folderRec {
    final f = widget.folder;
    if (f == null) return null;
    if (widget.subject == KeepSubject.folder) return lead.raw;
    return {
      'source': kFederationSource,
      'peer': lead.raw['peer'],
      'filepath': f.filepath,
      'title': f.name,
    };
  }

  /// The recommendation a copy of [scope] sends.
  Map<String, dynamic> _recFor(String scope) =>
      scope == kScopeFolder ? (_folderRec ?? lead.raw) : lead.raw;

  List<String> get _scopes {
    if (_browse) return _browseScopes;
    return widget.albumFocus
        ? jobs.scopesForCard(
            widget.cardLeads.isEmpty ? [lead] : widget.cardLeads,
            compilation: widget.compilation,
          )
        : jobs.scopesForRow(lead);
  }

  /// Browsing: the scopes the sheet's subject offers ([offeredCopyScopes]'s
  /// browse rule: Album only with the album's known credit, no artist copy
  /// of Various Artists, Folder only from an explorer file row whose folder
  /// is below its library's root — and only while its gate is ready).
  List<String> get _browseScopes {
    final copy = jobs.listing?.copy;
    if (copy == null) return const [];
    switch (widget.subject!) {
      case KeepSubject.artist:
        return [
          kScopeArtist,
          kScopeArtistMissing,
        ].where(copy.hasScope).toList();
      case KeepSubject.folder:
        return copy.hasScope(kScopeFolder) ? const [kScopeFolder] : const [];
      case KeepSubject.album:
        return offeredCopyScopes(
          lead.raw,
          copy,
          card: true,
          compilation: widget.compilation,
          browse: true,
        );
      case KeepSubject.song:
        return offeredCopyScopes(
          lead.raw,
          copy,
          browse: true,
          folder:
              widget.folder != null &&
              jobs.gate(kScopeFolder, KeepEntry.explorer).ready,
        );
    }
  }

  List<String> _chips(List<String> scopes) => [
    if (scopes.contains(kScopeSong)) kScopeSong,
    if (scopes.contains(kScopeAlbum)) kScopeAlbum,
    if (scopes.contains(kScopeArtist) || scopes.contains(kScopeArtistMissing))
      _kChipArtist,
    if (scopes.contains(kScopeFolder)) kScopeFolder,
  ];

  /// The chips drawn: none in artist and folder focus (one choice there).
  bool get _drawsChips =>
      widget.subject != KeepSubject.artist &&
      widget.subject != KeepSubject.folder;

  /// The gate of [scope] where this card was entered (Folder only from the
  /// file explorer).
  CopyGate _gate(String scope) => _browse
      ? jobs.gate(
          scope,
          scope == kScopeFolder ? KeepEntry.explorer : KeepEntry.browse,
        )
      : jobs.gate(scope);

  String? _chipNow(List<String> chips) {
    if (chips.isEmpty) return null;
    final c = _chip;
    if (c != null && chips.contains(c)) return c;
    if (widget.albumFocus && chips.contains(kScopeAlbum)) return kScopeAlbum;
    return chips.first;
  }

  /// The albums an only-missing copy takes: by name, the peer's albums the
  /// library lacks — browsing, THEIR albums the library lacks, as the copy
  /// plans it.
  List<String>? get _missing => _browse
      ? widget.facts.facts.missingTheirs(lead.artist)
      : widget.facts.facts.missing;

  /// Browsing: the artist's own albums there ("theirs"); null until known.
  List<String>? get _theirs => widget.facts.facts.theirsOf(lead.artist);

  /// Browsing, under Artist: the artist only appears on albums there —
  /// one line, no path, no Add.
  bool _noArtistCopy(String chip) =>
      _browse && chip == _kChipArtist && _theirs?.isEmpty == true;

  bool _showsMissing(String chip, List<String> scopes) {
    final m = _missing;
    return chip == _kChipArtist &&
        scopes.contains(kScopeArtistMissing) &&
        scopes.contains(kScopeArtist) &&
        m != null &&
        m.isNotEmpty;
  }

  String _scopeOf(String chip, List<String> scopes) {
    if (chip != _kChipArtist) return chip;
    if (!scopes.contains(kScopeArtist)) return kScopeArtistMissing;
    return _showsMissing(chip, scopes) && _onlyMissing
        ? kScopeArtistMissing
        : kScopeArtist;
  }

  /// The job the card shows for [scope]: this row's; under Artist a live
  /// copy of either artist scope wins (the box may have been ticked the
  /// other way when it started). Another server's copy of the same album or
  /// artist shows only while it runs ("Copying from …"); once it ends the
  /// button is back. Under Album and This song a finished wider copy of
  /// this server speaks too, as it came out for this album or this song,
  /// unless the choice's own job is live or newer
  /// ([DiscoveryJobsController.choiceJob]).
  SheetJob? _jobFor(String chip, String scope) {
    if (_browse) return _browseJobFor(chip, scope);
    if (chip == kScopeSong || chip == kScopeAlbum) {
      return jobs.choiceJob(
        lead,
        scope,
        cardLeads: widget.albumFocus ? widget.cardLeads : const [],
      );
    }
    final mine = jobs.sheetJob(lead, scope);
    if (chip == _kChipArtist) {
      final other = jobs.sheetJob(
        lead,
        scope == kScopeArtist ? kScopeArtistMissing : kScopeArtist,
      );
      if (mine?.job.live != true && other?.job.live == true) return other;
    }
    if (mine == null) return null;
    if (mine.fromOtherPeer && !mine.job.live) return null;
    return mine;
  }

  /// Browsing: [rec]'s jobs by slot — the sheet's lookup's, and a copy this
  /// card started since, as the job list has it now.
  Map<String, DiscoveryJob> _held(Map<String, dynamic> rec) {
    final held = Map<String, DiscoveryJob>.of(
      widget.marks?.jobsOf(rec) ?? const {},
    );
    for (final e in _startedHere.entries) {
      final now = jobs.jobs.firstWhere(
        (j) => j.id == e.value.id,
        orElse: () => e.value,
      );
      final have = held[e.key];
      if (have == null || now.id >= have.id) held[e.key] = now;
    }
    return held;
  }

  /// Browsing: the job the card shows for [scope] — the page marks' rules
  /// (pagePillJob: this server's album and artist copies, another's only
  /// while it runs; a song copy from any), and for Album and This song a
  /// finished wider copy's account as on Discover ([keepChoiceJob]); a
  /// folder by its own key.
  SheetJob? _browseJobFor(String chip, String scope) {
    final peerId = lead.peerId;
    if (chip == kScopeFolder) {
      final rec = _folderRec;
      if (rec == null) return null;
      final pick = pagePillJob(_held(rec), kScopeFolder, peerId: peerId);
      return pick == null ? null : SheetJob(pick.job);
    }
    final held = _held(lead.raw);
    if (chip == kScopeSong || chip == kScopeAlbum) {
      final own = pagePillJob(held, scope, peerId: peerId);
      final pick = keepChoiceJob(
        scope,
        own: own?.job,
        ownFromOtherPeer: own?.fromOtherPeer ?? false,
        held: held.values,
        peerId: peerId,
        album: lead.album,
        filepath: lead.filepath,
      );
      return pick == null
          ? null
          : SheetJob(
              pick.job,
              fromOtherPeer: pick.fromOtherPeer,
              wider: pick.wider,
            );
    }
    final pick = pagePillJob(held, kScopeArtist, peerId: peerId);
    if (pick == null || (pick.fromOtherPeer && !pick.job.live)) return null;
    return SheetJob(pick.job, fromOtherPeer: pick.fromOtherPeer);
  }

  // ── verbs ────────────────────────────────────────────────────────────

  String _startWords(AppLocalizations l, String error, int? status) {
    final fromServer =
        status != null &&
        status >= 400 &&
        !RegExp(r'^HTTP \d+$').hasMatch(error.trim());
    return fromServer ? error : l.discoverKeepStartFailed;
  }

  /// The one album an only-missing copy takes, when exactly one is missing:
  /// "Files go to" names it (the canvas's state 09, "Add 1 album").
  String? _oneMissing(String scope) {
    if (scope != kScopeArtistMissing) return null;
    final m = _missing;
    return m != null && m.length == 1 ? m.first : null;
  }

  /// Where a copy of [scope] lands ([scopeTarget]): this row's tags, its
  /// genre when the album's listing tells it, its folder on the connected
  /// server, the listing itself (an album copy's songs each file under their
  /// own artist, year, genre and folder there), and the one album an
  /// only-missing copy takes when only one is missing. Null while where
  /// files land is unknown.
  ScopeTarget? _target(String scope) {
    final d = jobs.destination?.destination;
    if (d == null) return null;
    if (scope == kScopeFolder) {
      return _folderTarget(_folderChoice?.landingFor(d), d);
    }
    final facts = widget.facts.facts;
    final one = _oneMissing(scope);
    return scopeTarget(
      vpath: d.vpath,
      base: d.base,
      layout: d.layout,
      scope: scope,
      tags: {
        // This song files under its file's ARTIST tag as written ("A feat.
        // B"), which the album's listing tells — the row names A alone.
        'artist': scope == kScopeSong
            ? facts.artistOf(lead.filepath) ?? lead.artist
            : lead.artist,
        'album': lead.album,
        'year': lead.year,
        'genre': facts.genreOf(lead.filepath),
        'albumartist': lead.albumArtist,
      },
      serverFolder: serverFolderOf(lead.filepath),
      albumSongs: facts.layoutSongs,
      oneAlbum: one == null ? null : (name: one, year: _yearOf(one)),
      peerName: widget.peerName,
      fileName: lead.filepath,
    );
  }

  /// Where the folder lands by [landing] (none: as on the connected server)
  /// from destination [d] (the folder rule, [folderTarget]): its songs once
  /// counted, their tags once read.
  ScopeTarget? _folderTarget(Object? landing, CollectionDestination? d) {
    final f = widget.folder;
    if (f == null) return null;
    final ff = widget.folderFacts?.facts;
    return scopeTarget(
      vpath: d?.vpath,
      base: d?.base,
      layout: d?.layout,
      scope: kScopeFolder,
      landing: landing,
      folder: f.filepath,
      folderSongs: ff?.songs,
      folderTags: ff?.tags,
      peerName: widget.peerName,
    );
  }

  /// [album]'s year, one of the artist's on the connected server: what its
  /// album list says, else this row's when it is this row's album.
  int? _yearOf(String album) =>
      widget.facts.facts.peerAlbumYears?[nameKey(album)] ??
      (nameKey(album) == nameKey(lead.album) ? lead.year : null);

  /// Where a copy of [scope] lands as the card draws it ([_Place]): library
  /// › folders (slot marks inside), the library alone when the layout or
  /// the base folder would be refused — and no path at all when a layout
  /// the server takes renders one past its cap for this copy (long tags,
  /// deep folders on the connected server): no file lands there, the
  /// library's root least of all. Null while where files land is unknown.
  _Place? _place(String scope) {
    final d = jobs.destination?.destination;
    final t = _target(scope);
    if (t == null || d == null) return null;
    final tooLong = t.target.tooLong;
    return (
      crumbs: t.valid
          ? t.crumbs
          : [if (!tooLong && d.vpath.isNotEmpty) d.vpath],
      perAlbum: t.perAlbum,
      scope: scope,
      tooLong: tooLong,
    );
  }

  /// The card grows downward when a chip is chosen (the only-missing box,
  /// a job's line): if the pill (or the job line in its place) would leave
  /// the screen, the sheet scrolls it back into view (the canvas's ARTIST
  /// CHOSEN frame). Only ever forward, and only as far as its bottom edge.
  void _revealPill() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final ctx = _pillAnchor.currentContext ?? _jobAnchor.currentContext;
      if (ctx == null) return;
      unawaited(
        Scrollable.ensureVisible(
          ctx,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        ),
      );
    });
  }

  String _pillLabel(AppLocalizations l, String scope) => switch (scope) {
    kScopeSong => l.discoverKeepAddSong,
    kScopeAlbum => l.discoverKeepAddAlbum,
    kScopeArtist => l.discoverKeepAddEveryAlbum,
    // Add never waits on the count: "Add folder" until it answers.
    kScopeFolder => switch (widget.folderFacts?.facts.songs?.length) {
      final int n when n > 0 => l.discoverKeepAddFolder(n),
      _ => l.discoverKeepAddFolderUncounted,
    },
    _ =>
      _missing == null
          ? l.discoverKeepAddMissing
          : l.discoverKeepAddAlbums(_missing!.length),
  };

  /// An every-album copy asks first; so does an only-missing one of more
  /// than one album.
  Future<bool> _confirm(String scope) async {
    final l = AppLocalizations.of(context);
    final int? count;
    if (scope == kScopeArtist) {
      // Browsing, an every-album copy names the artist ("Copy every album
      // by Boukmanflow from Stage Peer B?"): the peer's list counts the
      // albums they only appear on too.
      count = _browse ? null : widget.facts.facts.peerAlbums?.length;
    } else if (scope == kScopeArtistMissing) {
      final m = _missing?.length;
      if (m == null || m <= 1) return true;
      count = m;
    } else {
      return true;
    }
    final peer = widget.peerName;
    final known = count != null && count > 0;
    final place = _place(scope);
    final crumbs = place?.crumbs ?? const <String>[];
    final path = keepPathText(l, crumbs);
    // A layout that names no album's folder puts every album in one; a path
    // past the server's cap is no place to name.
    final body = place != null && place.tooLong
        ? l.discoverKeepPathTooLong(kMaxPathLength)
        : place != null && !place.perAlbum
        ? l.discoverKeepConfirmBodyFlat(path)
        : l.discoverKeepConfirmBody(path);
    final note = keepSlotNote(l, slotsIn(crumbs), scope: scope);
    return fedConfirm(
      context,
      title: known
          ? l.discoverKeepConfirmTitle(count, peer)
          : l.discoverKeepConfirmEveryTitle(lead.artist, peer),
      message: note == null ? body : '$body\n\n$note',
      confirmLabel: known
          ? l.discoverKeepConfirmAction(count)
          : l.discoverKeepConfirmEveryAction,
    );
  }

  Future<void> _start(String scope) async {
    // The place on show as the pill is pressed (the question names it too):
    // the start sends it, so one moved since is refused, never quietly used.
    final shown = ShownPlace(_drawn);
    if (!await _confirm(scope)) return;
    if (!mounted) return;
    _clearError();
    // A folder lands where its card says: none as on the connected server,
    // the folder picked, or by the layout.
    final landing = scope == kScopeFolder
        ? _folderChoice?.landingFor(_drawn)
        : null;
    final out = await jobs.start(
      _recFor(scope),
      scope: scope,
      shown: shown,
      landing: landing,
    );
    if (!mounted) return;
    _started(out);
    _refused(out);
  }

  void _clearError() => setState(() {
    _error = null;
    _moved = false;
  });

  /// A start the server refused: a moved place in its own warning line
  /// (nothing started; the path above is redrawn from the answer), else the
  /// server's words.
  void _refused(StartOutcome out) {
    final err = out.error;
    if (err == null) return;
    final l = AppLocalizations.of(context);
    setState(() {
      _moved = out.destinationChanged;
      _error = _moved
          ? l.discoverKeepDestChanged
          : _startWords(l, err, out.status);
    });
  }

  /// A copy the server took as new: the first-use note is done with, and
  /// the sheet hears of it (its toast, once it closes).
  void _started(StartOutcome out) {
    final job = out.job;
    // Browsing, the card follows any job the server answered with (its own
    // lookup may not know it yet), another server's live copy included.
    if (_browse && job != null) {
      setState(() => _startedHere[jobSlot(kCopyPlugin, jobScope(job))] = job);
    }
    if (job == null || !out.created || out.fromOtherPeer) return;
    unawaited(SettingsManager().markDiscoverKeepNoteSeen());
    widget.onStarted?.call(job);
  }

  /// The song the destination picker previews: this row's, or in album
  /// focus the album's first song once its songs are known.
  DestinationPreviewSong _previewSong() {
    final facts = widget.facts.facts;
    final songs = widget.albumFocus ? facts.albumSongs : null;
    if (songs != null && songs.isNotEmpty) {
      final s = songs.first;
      final m = s.metadata;
      String? pick(String? v, String? or) =>
          (v ?? '').trim().isNotEmpty ? v : or;
      return DestinationPreviewSong(
        title: pick(m?.title, s.name) ?? s.name,
        // Its ARTIST tag as written ("A feat. B"): where its copy files.
        artist:
            pick(m?.artistDisplay, pick(m?.artist, lead.artist)) ?? lead.artist,
        album: pick(m?.album, lead.album),
        albumArtist: lead.albumArtist,
        // Its own year, or none: a copy has no year to fall back to.
        year: m?.year,
        genre: facts.genreOf(s.data),
        filepath: s.data,
      );
    }
    return DestinationPreviewSong.ofLead(
      lead,
      artist: facts.artistOf(lead.filepath),
      genre: facts.genreOf(lead.filepath),
    );
  }

  /// "Copies go to your server, not this phone": until the first copy
  /// starts or a destination is saved (on this phone, or the account's
  /// already saved one), and while the account has no copy at all.
  bool get _firstUse =>
      !SettingsManager().discoverKeepNoteSeen &&
      jobs.destination?.saved == null &&
      !jobs.jobs.any((j) => j.plugin == kCopyPlugin);

  /// Retry and Add again land where files land now — what the card shows,
  /// naming it first when the copy ran somewhere else ([_againPlace]).
  Future<void> _retry(DiscoveryJob job) async {
    final shown = ShownPlace(_drawn);
    _clearError();
    final out = await jobs.retry(job, shown: shown);
    if (!mounted) return;
    _started(out);
    _refused(out);
  }

  Future<void> _cancel(DiscoveryJob job) async {
    final r = await jobs.cancel(job);
    if (!mounted) return;
    if (r.outcome == CancelOutcome.failed) {
      setState(() {
        _error = r.message;
        _moved = false;
      });
    }
  }

  /// Where Retry or Add again on [job] lands now when that is not where the
  /// copy ran — the account's place moved since (the webapp's retryPath),
  /// or the copy names none (pinned to nowhere, or from before the pin and
  /// never landed): the card names it before the verb is pressed, since
  /// the job's line hides "Files go to". Null when it is the same place, or
  /// where files land now is unknown.
  _Place? _againPlace(DiscoveryJob job, String scope) {
    final now = jobs.destination?.destination;
    if (now == null || sameDestination(job.destination, now)) return null;
    if (scope == kScopeFolder) {
      // A folder goes again by its own landing: one picked for it never
      // moves; as on the server or by the layout, it reads the saved place.
      if (landingMode(job.landing) == FolderLanding.folder) return null;
      final t = _folderTarget(job.landing, now);
      if (t == null) return null;
      return (
        crumbs: t.valid ? t.crumbs : [if (now.vpath.isNotEmpty) now.vpath],
        perAlbum: t.perAlbum,
        scope: scope,
        tooLong: t.target.tooLong,
      );
    }
    return _place(scope);
  }

  /// A folder copy's own place while it waits or copies: "copies ›
  /// Boukmanflow › Borrowed Tapes" — its landing, from the place pinned on
  /// it at start (where files land now when it names none) — each slot as
  /// its word. Null when it cannot be told.
  String? _folderInto(AppLocalizations l, DiscoveryJob job) {
    final t = _folderTarget(
      job.landing,
      job.destination ?? jobs.destination?.destination,
    );
    if (t == null || !t.valid || t.crumbs.isEmpty) return null;
    return [
      keepPathText(l, t.crumbs),
      if (t.perAlbum) l.discoverKeepFolderPerAlbum,
    ].join(' › ');
  }

  Future<void> _playFiles(List<String> files) async {
    if (files.isEmpty) return;
    if (files.length == 1) {
      await playNow(_ownFile(files.first));
    } else {
      await playFromHere([for (final f in files) _ownFile(f)], 0);
    }
  }

  DisplayItem _ownFile(String filepath) {
    final fp = filepath.startsWith('/') ? filepath : '/$filepath';
    return DisplayItem(
      jobs.server,
      fp.split('/').last,
      'file',
      fp,
      Icon(Icons.music_note, color: VelvetColors.accent),
      null,
    )..partialMetadata = true;
  }

  // ── drawing ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_browse) {
      return ListenableBuilder(
        listenable: Listenable.merge([
          jobs,
          widget.facts,
          ?widget.marks,
          ?widget.folderFacts,
          ?widget.ownFolders,
        ]),
        builder: (context, _) => _buildBrowse(context),
      );
    }
    return ListenableBuilder(
      listenable: Listenable.merge([jobs, widget.facts]),
      builder: (context, _) => _build(context),
    );
  }

  /// Browsing: the sheet's body — [KeepCopySection.above] and the card
  /// scrolling as one, the card's Add pinned in a bar under them while it
  /// is idle (a job's own verbs do the work otherwise).
  Widget _buildBrowse(BuildContext context) {
    final l = AppLocalizations.of(context);
    _drawn = jobs.destination?.destination;
    final scopes = _scopes;
    final chips = _chips(scopes);
    final chip = _chipNow(chips);
    Widget? body;
    Widget? bar;
    if (chip != null) {
      final scope = _scopeOf(chip, scopes);
      final gate = _gate(scope);
      if (!gate.ready && _moved) {
        _error = null;
        _moved = false;
      }
      if (gate.status == CopyGateStatus.line) {
        body = _line(
          gate.block == CopyGateBlock.noUpload
              ? (Icons.block, l.discoverKeepUploadsOff)
              : (Icons.folder_off_outlined, l.discoverKeepNoLibrary),
        );
      } else if (gate.status == CopyGateStatus.hidden) {
        // A right lost while the sheet is open (a start answered 403 or
        // 404 and the gate read again): one plain line, never a card gone.
        body = _line((Icons.cloud_off_outlined, l.discoverKeepStartFailed));
      } else if (gate.ready) {
        final shown = _jobFor(chip, scope);
        final missingBox = _showsMissing(chip, scopes);
        final cap = jobs.listing?.maxFolderSongs;
        final folderFacts = widget.folderFacts?.facts;
        final overCap =
            chip == kScopeFolder && (folderFacts?.overCap(cap) ?? false);
        final children = <Widget>[
          if (_drawsChips)
            Semantics(
              label: l.discoverKeepWhat,
              container: true,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [for (final c in chips) _choice(l, c, c == chip)],
              ),
            ),
          if (missingBox) _missingBox(l),
        ];
        if (shown != null) {
          children.add(
            KeyedSubtree(key: _jobAnchor, child: _jobLine(l, shown, scope)),
          );
          if (_error != null) {
            if (_moved) children.add(_destination(l, scope));
            children.add(
              _errorLine(
                _moved ? l.discoverKeepDestChangedTryAgain : _error!,
                warn: _moved,
                plain: true,
              ),
            );
          }
        } else if (_noArtistCopy(chip)) {
          // Theirs = 0: they only appear on albums there.
          children.add(
            _note(
              l.discoverKeepNoArtistCopyHere(lead.artist),
              key: const ValueKey('keep-no-artist-copy'),
            ),
          );
        } else if (overCap) {
          // Past the server's cap: this line alone — no landings, no Add.
          children.add(
            KeepFolderCapLine(
              l.discoverKeepFolderCap(
                widget.folder!.name,
                folderFacts!.songs!.length,
                cap!,
              ),
            ),
          );
        } else {
          if (_firstUse) {
            children.add(
              Padding(
                key: const ValueKey('keep-first-use'),
                padding: const EdgeInsets.only(top: 12),
                child: _FirstUseNote(l.discoverKeepFirstUse),
              ),
            );
          }
          // Under Artist, what the copy leaves out, right above its path.
          if (chip == _kChipArtist) {
            final out = _leftOut(l);
            if (out != null) children.add(out);
          }
          if (chip == kScopeFolder) {
            children.addAll(_folderBody(l));
          } else {
            children.add(_destination(l, scope));
          }
          if (_error != null) {
            children.add(_errorLine(_error!, warn: _moved, plain: true));
          }
          bar = _addBar(
            l,
            scope,
            enabled: chip != kScopeFolder || _folderPlaceOk(),
          );
        }
        body = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: children,
        );
      }
    }
    final card = body == null
        ? null
        : Column(
            key: const ValueKey('keep-copy'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              KeepSheetLabel(l.discoverSheetKeepCopy),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: VelvetColors.card,
                    borderRadius: BorderRadius.circular(
                      VelvetColors.radiusLarge,
                    ),
                    border: Border.all(color: VelvetColors.border),
                  ),
                  child: body,
                ),
              ),
            ],
          );
    return Column(
      key: const ValueKey('keep-browse-body'),
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Flexible(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [...widget.above, ?card, const SizedBox(height: 16)],
            ),
          ),
        ),
        ?bar,
      ],
    );
  }

  /// Browsing: [shown]'s line — Discover's, with a folder copy's own place
  /// ("Into copies › …" while it runs, "In copies › …" once it finished:
  /// where its files are, which for a copy of songs all already here is
  /// where those are), its Play and "Show in your library", and no New
  /// seeds.
  Widget _jobLine(AppLocalizations l, SheetJob shown, String scope) {
    final job = shown.job;
    final folder = scope == kScopeFolder;
    final landed = folder ? job.view.folderFilesAt : null;
    return _JobLine(
      key: ValueKey('keep-job-${job.id}'),
      sheetJob: shown,
      lead: lead,
      peerName: widget.peerName,
      pillLabel: _pillLabel(l, scope),
      onCancel: _cancel,
      onRetry: shown.wider ? (_) => _start(scope) : _retry,
      againPlace: _moved ? null : _againPlace(job, scope),
      onNewSeeds: null,
      browse: true,
      into: folder && job.live ? _folderInto(l, job) : null,
      landed: landed,
      onPlayFiles: folder ? (files) => unawaited(_playFiles(files)) : null,
      onShowInLibrary: landed == null || widget.onShowInLibrary == null
          ? null
          : () => widget.onShowInLibrary!('/$landed'),
      onPlay: (fp) => unawaited(playNow(_ownFile(fp))),
      onQueue: (fp) async {
        await addToQueueEnd(_ownFile(fp));
        widget.toast?.call(l.browserSongsAdded(1));
      },
    );
  }

  /// A quiet line in the card with an info glyph (no artist copy here).
  Widget _note(String text, {Key? key}) => Padding(
    key: key,
    padding: const EdgeInsets.only(top: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(
            Icons.info_outline,
            size: 16,
            color: VelvetColors.textSecondary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: VelvetColors.textSecondary,
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ),
      ],
    ),
  );

  /// Under Artist: what an artist copy leaves out, as the copy plans it —
  /// "Leaves out Night Market Sampler: Boukmanflow only appears on it." /
  /// "Leaves out 2 albums Boukmanflow only appears on.", then "Songs
  /// outside an album stay out too." when the list has songs in no album.
  /// Null when nothing is left out (or the peer's list has not answered).
  Widget? _leftOut(AppLocalizations l) {
    final out = widget.facts.facts.leftOutFor(lead.artist);
    if (out == null) return null;
    final words = [
      if (out.one != null)
        l.discoverKeepLeftOutOne(out.one!, lead.artist)
      else if (out.many > 0)
        l.discoverKeepLeftOutMany(out.many, lead.artist),
      if (out.singles) l.discoverKeepLeftOutSingles,
    ].join(' ');
    final tone = keepQuiet(VelvetColors.textTertiary);
    return Padding(
      key: const ValueKey('keep-left-out'),
      padding: const EdgeInsets.only(top: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(Icons.info_outline, size: 14, color: tone),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              words,
              style: TextStyle(color: tone, fontSize: 12, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  /// A folder's card under its chips: where it lands, then the landing's
  /// body — as on the connected server (the path, no Change: the layout
  /// does not apply; its first files; its foot), "Into a folder…" (its
  /// group), by the layout (the path and Change; the files only where the
  /// path is one exact folder).
  List<Widget> _folderBody(AppLocalizations l) {
    final c = _folderChoice;
    final f = widget.folder;
    final lister = widget.ownFolders;
    if (c == null || f == null) return const [];
    final t = _target(kScopeFolder);
    final files = t?.files;
    return [
      KeepLandingGroup(
        chosen: c.landing,
        peerName: widget.peerName,
        onChoose: (mode) {
          setState(() {
            _error = null;
            _moved = false;
          });
          c.choose(mode);
          // "By your layout" reads the songs' tags, once.
          if (mode == FolderLanding.tags) {
            unawaited(widget.folderFacts?.readTags());
          }
        },
      ),
      switch (c.landing) {
        FolderLanding.mirror => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _destination(l, kScopeFolder, change: false),
            if (files != null) KeepFolderFileList(files),
            KeepFolderNote(
              l.discoverKeepLandingMirrorFoot(f.library, widget.peerName),
              key: const ValueKey('keep-mirror-foot'),
            ),
          ],
        ),
        FolderLanding.folder =>
          lister == null
              ? const SizedBox.shrink()
              : KeepIntoFolder(
                  choice: c,
                  destination: jobs.destination,
                  lister: lister,
                  target: t,
                ),
        FolderLanding.tags => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _destination(l, kScopeFolder),
            if (files != null) KeepFolderFileList(files),
          ],
        ),
      },
    ];
  }

  /// The folder's place can take the copy: no name a layout would read as
  /// a variable ("Into a folder…"'s one validation), and a path the server
  /// would place.
  bool _folderPlaceOk() {
    final c = _folderChoice;
    if (c == null) return true;
    if (c.braced(_drawn) != null) return false;
    final t = _target(kScopeFolder);
    return t == null || t.valid;
  }

  /// The sheet's pinned Add: the pill named for the choice, in words only
  /// (⊞ means the queue — the page's Add All sits right above), full width,
  /// on the sheet's ground under a hairline — busy while its start is out;
  /// waiting ([enabled] false) only on a folder name it cannot use.
  Widget _addBar(AppLocalizations l, String scope, {bool enabled = true}) {
    final pill = KeepPill(
      _pillLabel(l, scope),
      key: const ValueKey('keep-start'),
      primary: true,
      expand: true,
      // Its count kept at large text: two lines rather than an ellipsis.
      maxLines: 2,
      busy: jobs.isStarting(_recFor(scope), scope == kScopeSong ? null : scope),
      onTap: enabled ? () => unawaited(_start(scope)) : null,
    );
    return Container(
      key: const ValueKey('keep-add-bar'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: VelvetColors.surface,
        border: Border(top: BorderSide(color: VelvetColors.border)),
      ),
      child: enabled ? pill : Opacity(opacity: 0.45, child: pill),
    );
  }

  Widget _build(BuildContext context) {
    final l = AppLocalizations.of(context);
    _drawn = jobs.destination?.destination;
    final scopes = _scopes;
    final chips = _chips(scopes);
    final chip = _chipNow(chips);
    if (chip == null) return const SizedBox.shrink();
    final gate = jobs.gate(_scopeOf(chip, scopes));
    // Nowhere takes files any more: the moved-place warning has no path to
    // point at, and does not come back with a place a later read brings.
    if (!gate.ready && _moved) {
      _error = null;
      _moved = false;
    }
    if (!gate.shown) return const SizedBox.shrink();

    final Widget body;
    if (gate.status == CopyGateStatus.line) {
      body = _line(
        gate.block == CopyGateBlock.noUpload
            ? (Icons.block, l.discoverKeepUploadsOff)
            : (Icons.folder_off_outlined, l.discoverKeepNoLibrary),
      );
    } else {
      final scope = _scopeOf(chip, scopes);
      final shown = _jobFor(chip, scope);
      final missingBox = _showsMissing(chip, scopes);
      // The box landing (its facts answered) after the user chose Artist
      // pushes the pill down: bring it back.
      if (missingBox && !_missingShown && _chipChosen) _revealPill();
      _missingShown = missingBox;
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            label: l.discoverKeepWhat,
            container: true,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [for (final c in chips) _choice(l, c, c == chip)],
            ),
          ),
          if (missingBox) _missingBox(l),
          if (shown != null)
            KeyedSubtree(
              key: _jobAnchor,
              child: _JobLine(
                key: ValueKey('keep-job-${shown.job.id}'),
                sheetJob: shown,
                lead: lead,
                peerName: widget.peerName,
                pillLabel: _pillLabel(l, scope),
                onCancel: _cancel,
                // A wider copy's account: Retry copies this choice (the
                // album, the song), never the whole artist again.
                onRetry: shown.wider ? (_) => _start(scope) : _retry,
                // While the moved-place warning stands, "Files go to"
                // under the line says where instead.
                againPlace: _moved ? null : _againPlace(shown.job, scope),
                onNewSeeds: widget.onNewSeeds,
                onPlay: (fp) => unawaited(playNow(_ownFile(fp))),
                onQueue: (fp) async {
                  await addToQueueEnd(_ownFile(fp));
                  widget.toast?.call(l.browserSongsAdded(1));
                },
              ),
            )
          else ...[
            if (_firstUse)
              Padding(
                key: const ValueKey('keep-first-use'),
                padding: const EdgeInsets.only(top: 12),
                child: _FirstUseNote(l.discoverKeepFirstUse),
              ),
            _destination(l, scope),
            if (_error != null) _errorLine(_error!, warn: _moved),
            Padding(
              key: _pillAnchor,
              padding: const EdgeInsets.only(top: 6),
              child: KeepPill(
                _pillLabel(l, scope),
                key: const ValueKey('keep-start'),
                icon: Icons.library_add_outlined,
                primary: true,
                expand: true,
                busy: jobs.isStarting(
                  lead.raw,
                  scope == kScopeSong ? null : scope,
                ),
                onTap: () => unawaited(_start(scope)),
              ),
            ),
          ],
          if (shown != null && _error != null) ...[
            // The path the warning points at: the job's line hides it.
            if (_moved) _destination(l, scope),
            _errorLine(
              _moved ? l.discoverKeepDestChangedTryAgain : _error!,
              warn: _moved,
            ),
          ],
        ],
      );
    }
    return Column(
      key: const ValueKey('keep-copy'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        KeepSheetLabel(l.discoverSheetKeepCopy),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: VelvetColors.card,
              borderRadius: BorderRadius.circular(VelvetColors.radiusLarge),
              border: Border.all(color: VelvetColors.border),
            ),
            child: body,
          ),
        ),
      ],
    );
  }

  Widget _line((IconData, String) what) => Row(
    key: const ValueKey('keep-line'),
    children: [
      Icon(what.$1, size: 18, color: VelvetColors.textSecondary),
      const SizedBox(width: 10),
      Expanded(
        child: Text(
          what.$2,
          style: TextStyle(
            color: VelvetColors.textSecondary,
            fontSize: 13,
            height: 1.35,
          ),
        ),
      ),
    ],
  );

  Widget _choice(AppLocalizations l, String chip, bool selected) {
    final f = widget.facts;
    final facts = f.facts;
    String? size;
    var loading = false;
    switch (chip) {
      case kScopeSong:
        // As the other sizes: still blocks while the facts are out, blank
        // once the connected server did not answer (states 04 and 05).
        if (f.loading) {
          loading = true;
        } else if (!facts.peerFailed) {
          final d = lead.durationSeconds;
          size = [
            if (d != null)
              keepClock(Duration(milliseconds: (d * 1000).round())),
            ?keepFormatOf(lead.filepath),
          ].join(' · ');
        }
      case kScopeAlbum:
        // An empty answer names no album the copy could take: no size.
        final n = facts.albumSongCount;
        if (n != null && n > 0) {
          size = l.discoverSheetSongCount(n);
        } else {
          loading = f.loadingAlbum;
        }
      case kScopeFolder:
        // The folder's name until it is counted ("Borrowed Tapes"), then
        // its songs.
        final n = widget.folderFacts?.facts.songs?.length;
        size = n == null
            ? widget.folder?.name
            : l.discoverSheetFolderSongCount(n);
      default:
        if (_browse) {
          // Browsing: THEIR albums ("3 albums · you have 1"; "0 albums" for
          // an artist who only appears on albums there).
          final theirs = _theirs;
          final have = facts.haveTheirs(lead.artist);
          if (theirs != null) {
            size = [
              l.discoverSheetAlbumCount(theirs.length),
              if (have != null && have > 0) l.discoverKeepYouHave(have),
            ].join(' · ');
          } else {
            loading = f.loadingArtist;
          }
          break;
        }
        final peer = facts.peerAlbums;
        final mine = facts.libraryAlbums;
        if (peer != null && peer.isNotEmpty) {
          size = [
            l.discoverSheetAlbumCount(peer.length),
            if (mine != null && mine.isNotEmpty)
              l.discoverKeepYouHave(mine.length),
          ].join(' · ');
        } else {
          loading = f.loadingArtist;
        }
    }
    final label = switch (chip) {
      kScopeSong => l.discoverKeepThisSong,
      kScopeAlbum => l.discoverKeepAlbum,
      kScopeFolder => l.discoverKeepFolder,
      _ => l.discoverKeepArtist,
    };
    final folder = widget.folder;
    final counted = widget.folderFacts?.facts.songs?.length;
    return KeepChoice(
      key: ValueKey('keep-chip-$chip'),
      label: label,
      size: size,
      sizeLoading: loading,
      selected: selected,
      // "Folder: Borrowed Tapes and everything in it", then its songs.
      semanticsLabel: chip == kScopeFolder && folder != null
          ? (counted == null
                ? l.discoverKeepFolderAria(folder.name)
                : l.discoverKeepFolderAriaCount(counted, folder.name))
          : null,
      onTap: () {
        setState(() {
          _chip = chip;
          _chipChosen = true;
          _error = null;
          _moved = false;
        });
        // The Folder chip first chosen counts the folder (once).
        if (chip == kScopeFolder) unawaited(widget.folderFacts?.count());
        _revealPill();
      },
    );
  }

  Widget _missingBox(AppLocalizations l) {
    final n = _missing!.length;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: InkWell(
        key: const ValueKey('keep-only-missing'),
        borderRadius: BorderRadius.circular(VelvetColors.radiusSmall),
        onTap: () => setState(() => _onlyMissing = !_onlyMissing),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            children: [
              SizedBox(
                width: 24,
                height: 24,
                child: Checkbox(
                  value: _onlyMissing,
                  activeColor: VelvetColors.primary,
                  checkColor: VelvetColors.onPrimary,
                  side: BorderSide(color: VelvetColors.textSecondary, width: 2),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: (v) => setState(() => _onlyMissing = v ?? false),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l.discoverKeepOnlyMissing(n),
                  style: TextStyle(
                    color: VelvetColors.textPrimary,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// "Files go to …" and Change ([change] false: none — a folder as on the
  /// connected server, where the layout does not apply).
  Widget _destination(AppLocalizations l, String scope, {bool change = true}) {
    final place = _place(scope);
    final crumbs = place?.crumbs ?? const <String>[];
    // A path past the server's cap: the warning where the path goes, Change
    // beside it.
    final tooLong = place?.tooLong == true;
    final warn = keepTone(VelvetColors.warning);
    final strong = TextStyle(
      color: VelvetColors.textPrimary,
      fontSize: 13,
      fontWeight: FontWeight.w500,
      height: 1.4,
    );
    final soft = TextStyle(
      color: VelvetColors.textSecondary,
      fontSize: 13,
      height: 1.4,
    );
    final spans = <InlineSpan>[
      tooLong
          ? TextSpan(
              text: l.discoverKeepPathTooLong(kMaxPathLength),
              style: soft.copyWith(color: warn),
            )
          : TextSpan(text: '${l.discoverKeepFilesGoTo} ', style: soft),
    ];
    for (var i = 0; i < crumbs.length; i++) {
      if (i > 0) spans.add(TextSpan(text: ' › ', style: soft));
      spans.addAll(keepCrumbSpans(l, crumbs[i], style: strong, hold: _hold));
    }
    // A slot in the path: one quiet line under it says why.
    final note = keepSlotNote(l, slotsIn(crumbs), scope: scope);
    if (place?.perAlbum == true) {
      spans.add(TextSpan(text: ' › ', style: soft));
      spans.add(
        TextSpan(text: _hold(l.discoverKeepFolderPerAlbum), style: soft),
      );
    }
    return Row(
      key: const ValueKey('keep-destination'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: tooLong
              ? Icon(Icons.warning_amber_rounded, size: 16, color: warn)
              : Icon(
                  Icons.folder_outlined,
                  size: 16,
                  color: VelvetColors.textSecondary,
                ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 13),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(TextSpan(children: spans)),
                if (note != null)
                  _SlotNote(note, key: const ValueKey('keep-slot-note')),
              ],
            ),
          ),
        ),
        if (change)
          Semantics(
            button: true,
            label: l.discoverKeepChangeHint,
            excludeSemantics: true,
            child: InkWell(
              key: const ValueKey('keep-change'),
              borderRadius: BorderRadius.circular(VelvetColors.radiusSmall),
              onTap: () {
                // The user is checking the path the warning points at.
                if (_moved) _clearError();
                // A folder by the layout previews the folder, its songs each
                // by their own tags.
                final f = widget.folder;
                if (scope == kScopeFolder && f != null) {
                  final ff = widget.folderFacts?.facts;
                  DiscoveryKeepRoutes.changeFolderDestination(
                    context,
                    jobs,
                    DestinationPreviewFolder(
                      folder: f.filepath,
                      name: f.name,
                      songs: ff?.songs,
                      tags: ff?.tags,
                    ),
                    widget.peerName,
                  );
                  return;
                }
                DiscoveryKeepRoutes.changeDestination(
                  context,
                  jobs,
                  _previewSong(),
                  widget.peerName,
                );
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 13, 4, 13),
                child: Text(
                  l.discoverKeepChange,
                  style: TextStyle(
                    color: keepInk(),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// The card's one refusal line, in the error colour — or, with [warn],
  /// the warning colour (where files land moved: nothing went wrong, the
  /// user checks the path and adds again). [plain]: a sheet entered from
  /// browsing says a refused start as one plain line in the warning colour
  /// too — the server's sentence, verbatim.
  Widget _errorLine(String words, {bool warn = false, bool plain = false}) {
    final tone = keepTone(
      warn || plain ? VelvetColors.warning : VelvetColors.error,
    );
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Semantics(
        liveRegion: true,
        child: Row(
          key: ValueKey(warn ? 'keep-moved' : 'keep-error'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(Icons.warning_amber_rounded, size: 16, color: tone),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                words,
                style: TextStyle(color: tone, fontSize: 13, height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The library files a finished folder copy left (Play): its copied songs
/// and the ones already there — at most 500, as the lists are.
List<String> _landedFilesOf(DiscoveryJob job) {
  final songs = job.result?['songs'];
  if (songs is! Map) return const [];
  final out = <String>[];
  for (final e in songs['copied'] is List ? songs['copied'] as List : []) {
    final fp = e is Map ? e['filepath'] : null;
    if (fp is String && fp.isNotEmpty) out.add(fp);
  }
  for (final e in songs['skipped'] is List ? songs['skipped'] as List : []) {
    final at = e is Map && e['why'] == 'owned' ? e['at'] : null;
    if (at is String && at.isNotEmpty) out.add(at);
  }
  return out.take(500).toList();
}

/// A job's line inside the Keep card: the state's glyph and word (and
/// Cancel while it can be cancelled), the bar while it copies, what the
/// server said or how it ended, then its verbs.
class _JobLine extends StatelessWidget {
  final SheetJob sheetJob;
  final DiscoveryLead lead;
  final String peerName;
  final String pillLabel;
  final Future<void> Function(DiscoveryJob) onCancel;
  final Future<void> Function(DiscoveryJob) onRetry;
  final VoidCallback? onNewSeeds;
  final void Function(String filepath) onPlay;
  final void Function(String filepath) onQueue;

  /// Where Retry or Add again lands now, when the copy ran somewhere else
  /// ("Retry adds to copies › …, your saved place now"); null when it is
  /// the same place.
  final _Place? againPlace;

  /// Entered from browsing: no New seeds (a copy that failed for a
  /// re-paired server shows no verb there), the server's line capitalised.
  final bool browse;

  /// A folder copy's own place: where it goes while it waits or copies
  /// ([into], "copies › Boukmanflow › Borrowed Tapes"), where its files are
  /// once it finished ([landed], '/'-joined from the library; null: no one
  /// folder holds them).
  final String? into;
  final String? landed;

  /// A folder copy's Play (its landed files, at most 500) and "Show in
  /// your library" (null: none).
  final void Function(List<String> files)? onPlayFiles;
  final VoidCallback? onShowInLibrary;

  const _JobLine({
    super.key,
    required this.sheetJob,
    required this.lead,
    required this.peerName,
    required this.pillLabel,
    required this.onCancel,
    required this.onRetry,
    required this.onNewSeeds,
    required this.onPlay,
    required this.onQueue,
    this.againPlace,
    this.browse = false,
    this.into,
    this.landed,
    this.onPlayFiles,
    this.onShowInLibrary,
  });

  /// A folder copy the server failed for its cap (an older server, which
  /// sent no cap to draw): the same folder fails again — no Retry.
  static bool _capFailed(DiscoveryJob job) =>
      jobScope(job) == kScopeFolder &&
      job.state == JobState.failed &&
      RegExp(r'\(the limit is \d+').hasMatch(job.error ?? '');

  /// The server's line as the sheet's sentences start (browsing).
  static String _capital(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  /// "Retry adds to copies › …, your saved place now": the sentence [addsTo]
  /// makes, the path's segments held together and its slots set apart as
  /// "Files go to"'s are, an artist copy's "one folder per album" after it;
  /// under it the slots' note when it shows any. A path past the server's
  /// cap is no place to add to: the warning instead, as "Files go to" has.
  List<Widget> _againLines(
    AppLocalizations l,
    String Function(String place) addsTo,
    _Place place,
    Color text2,
  ) {
    if (place.tooLong) {
      return [
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            l.discoverKeepPathTooLong(kMaxPathLength),
            key: const ValueKey('keep-again-too-long'),
            style: TextStyle(
              color: keepTone(VelvetColors.warning),
              fontSize: 13,
              height: 1.35,
            ),
          ),
        ),
      ];
    }
    const mark = '\uE002';
    final words = addsTo(mark).split(mark);
    final crumbs = place.crumbs;
    final perAlbum = place.perAlbum
        ? ' › ${_hold(l.discoverKeepFolderPerAlbum)}'
        : '';
    final path = <InlineSpan>[
      for (var i = 0; i < crumbs.length; i++) ...[
        if (i > 0) const TextSpan(text: ' › '),
        ...keepCrumbSpans(l, crumbs[i], hold: _hold),
      ],
      if (perAlbum.isNotEmpty) TextSpan(text: perAlbum),
    ];
    final plain =
        crumbs.map((c) => _hold(keepPathText(l, [c]))).join(' › ') + perAlbum;
    final note = keepSlotNote(l, slotsIn(crumbs), scope: place.scope);
    return [
      Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Text.rich(
          TextSpan(
            style: TextStyle(color: text2, fontSize: 13, height: 1.35),
            children: words.length == 2
                ? [TextSpan(text: words[0]), ...path, TextSpan(text: words[1])]
                // A translation that does not name the place once: as text.
                : [TextSpan(text: addsTo(plain))],
          ),
        ),
      ),
      if (note != null)
        _SlotNote(note, key: const ValueKey('keep-again-slot-note')),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final job = sheetJob.job;
    final row = jobRowState(job, plugin: kCopyPlugin);
    final peer = keepJobPeer(job, peerName);
    final ink = keepInk();
    final text2 = VelvetColors.textSecondary;
    String part(JobText t) =>
        keepJobText(l, t, peer: peer, artist: lead.artist);
    // An artist copy's account of this one album: the walk leaving this
    // album out (already yours) is no "album left out" here.
    List<String> parts(Map<String, dynamic>? many) => many == null
        ? const []
        : [
            for (final t in manyParts(many))
              if (!sheetJob.wider || t.phrase != JobPhrase.albumsLeftOut)
                part(t),
          ];

    Widget glyph;
    String title;
    Color titleColor = VelvetColors.textPrimary;
    final subs = <String>[];
    // A folder copy's quieter lines: where it goes or went, what it left
    // out.
    final muted = <String>[];
    var bar = false;
    Color barColor = VelvetColors.primary;
    var cancel = false;
    final actions = <Widget>[];

    // The sentence naming where a start again lands ([againPlace]), set
    // with the verb that starts it.
    String Function(String place)? againAddsTo;
    Widget icon(IconData i, Color c) => Icon(i, size: 20, color: c);
    Widget? retry({bool primary = false}) {
      if (job.state == JobState.failed && jobNeedsNewSeeds(job)) {
        // Browsing has no Discover to ask again: no verb.
        if (browse) return null;
        return KeepPill(
          l.discoverPageNewSeeds,
          key: const ValueKey('keep-new-seeds'),
          icon: Icons.refresh,
          onTap: onNewSeeds,
        );
      }
      againAddsTo = l.discoverKeepRetryAddsTo;
      return KeepPill(
        l.discoverJobRetry,
        key: const ValueKey('keep-retry'),
        icon: Icons.refresh,
        primary: primary,
        onTap: () => unawaited(onRetry(job)),
      );
    }

    // A folder copy's Play (what it landed or found already there) and
    // where its files are.
    final playFiles = onPlayFiles;
    final files = playFiles == null ? const <String>[] : _landedFilesOf(job);
    Widget? play({bool primary = true}) => files.isEmpty
        ? null
        : KeepPill(
            l.play,
            key: const ValueKey('keep-play-files'),
            icon: Icons.play_arrow,
            primary: primary,
            onTap: () => playFiles!(files),
          );
    final show = onShowInLibrary == null
        ? null
        : KeepPill(
            l.discoverCopiesShowInLibrary,
            key: const ValueKey('keep-show-in-library'),
            icon: Icons.folder_open,
            onTap: onShowInLibrary,
          );
    final landedAt = landed == null || landed!.isEmpty
        ? null
        : l.discoverKeepIn(pathCrumbs(landed).join(' › '));

    final many = job.view.isMany ? job.result : null;
    final status = (job.statusText ?? '').trim();

    if (sheetJob.fromOtherPeer) {
      glyph = KeepRing(size: 18, color: text2);
      title = l.discoverJobFromOther(job.peerName ?? peer);
      bar = true;
      if (status.isNotEmpty) subs.add(status);
      subs.add(l.discoverJobComesBack(pillLabel));
    } else {
      switch (row.kind) {
        case JobRowKind.queued:
          glyph = icon(Icons.schedule, text2);
          title = l.discoverJobQueued;
          subs.add(l.discoverJobQueuedSub);
          if (into != null) muted.add(l.discoverKeepInto(into!));
          cancel = true;
        case JobRowKind.running:
          final stopping = job.cancelRequested;
          glyph = KeepRing(size: 18, color: stopping ? text2 : ink);
          title = stopping ? l.discoverJobStopping : l.discoverJobCopying;
          titleColor = stopping ? text2 : ink;
          bar = true;
          if (stopping) barColor = VelvetColors.textTertiary;
          subs.add(
            status.isEmpty
                ? l.discoverJobStarting
                : (browse ? _capital(status) : status),
          );
          if (!stopping && into != null) muted.add(l.discoverKeepInto(into!));
          cancel = !stopping;
        case JobRowKind.copied:
        case JobRowKind.downloaded:
          glyph = icon(
            Icons.check_circle_outline,
            keepTone(VelvetColors.success),
          );
          title = l.discoverJobInCollection;
          titleColor = keepTone(VelvetColors.success);
          for (final t in row.sub ?? const <JobText>[]) {
            subs.add(part(t));
          }
          final fp = row.filepath;
          if (fp != null) {
            actions.add(
              KeepPill(
                l.play,
                key: const ValueKey('keep-play'),
                icon: Icons.play_arrow,
                primary: true,
                onTap: () => onPlay(fp),
              ),
            );
            actions.add(
              KeepPill(
                l.discoverJobAddToQueue,
                key: const ValueKey('keep-queue'),
                icon: Icons.queue_music,
                onTap: () => onQueue(fp),
              ),
            );
          }
        case JobRowKind.copiedMany:
          glyph = icon(
            Icons.check_circle_outline,
            keepTone(VelvetColors.success),
          );
          title = l.discoverJobInCollection;
          titleColor = keepTone(VelvetColors.success);
          final p = parts(many);
          if (p.isNotEmpty) subs.add(p.join(' · '));
          final n = many == null ? null : manyCounts(many);
          final failures = n != null && (n.failed > 0 || n.albumsFailed > 0);
          if (playFiles != null) {
            // A folder copy: what it left out, where its files are, Play —
            // then Retry for its failures, else where to find them.
            if (row.skippedFiles > 0) {
              muted.add(l.discoverKeepFilesLeftOut(row.skippedFiles));
            }
            if (landedAt != null) muted.add(landedAt);
            if (failures) {
              actions.addAll([?play(primary: false), ?retry(primary: true)]);
            } else {
              actions.addAll([?play(), ?show]);
            }
          } else if (failures) {
            actions.addAll([?retry()]);
          }
        case JobRowKind.owned:
          glyph = icon(
            Icons.check_circle_outline,
            keepTone(VelvetColors.success),
          );
          title = l.discoverJobOwned;
          titleColor = keepTone(VelvetColors.success);
          if (many != null && playFiles != null) {
            // A folder whose every song was already here.
            subs.add([l.discoverJobNothingAll, ...parts(many)].join(' · '));
            if (landedAt != null) muted.add(landedAt);
            actions.addAll([?play(), ?show]);
          } else if (many != null) {
            final p = parts(many);
            if (p.isNotEmpty) subs.add(p.join(' · '));
          } else {
            final at = row.filepath;
            subs.add(
              at == null
                  ? l.discoverJobOwnedSub
                  : '${l.discoverJobOwnedSub} · ${pathCrumbs(at).join(' / ')}',
            );
            if (at != null) {
              actions.add(
                KeepPill(
                  l.play,
                  key: const ValueKey('keep-play'),
                  icon: Icons.play_arrow,
                  primary: true,
                  onTap: () => onPlay(at),
                ),
              );
              actions.add(
                KeepPill(
                  l.discoverJobAddToQueue,
                  key: const ValueKey('keep-queue'),
                  icon: Icons.queue_music,
                  onTap: () => onQueue(at),
                ),
              );
            }
          }
        case JobRowKind.exists:
          glyph = icon(
            Icons.warning_amber_rounded,
            keepTone(VelvetColors.warning),
          );
          title = l.discoverJobSkipped;
          titleColor = keepTone(VelvetColors.warning);
          for (final t in row.sub ?? const <JobText>[]) {
            subs.add(part(t));
          }
          actions.addAll([?retry()]);
        case JobRowKind.failed:
          glyph = icon(Icons.highlight_off, keepTone(VelvetColors.error));
          title = l.discoverJobFailed;
          titleColor = keepTone(VelvetColors.error);
          if (many != null) {
            final n = manyCounts(many);
            subs.add(
              [
                if (n.copied == 0) l.discoverJobNothingCopiedLead,
                ...parts(many),
              ].join(' · '),
            );
          } else {
            subs.add(job.error ?? l.discoverJobFailedSub);
          }
          // Past an older server's cap the same folder fails again.
          if (!_capFailed(job)) actions.addAll([?retry()]);
        case JobRowKind.stopped:
          final refused = row.leadPhrase == JobPhrase.stoppedRefused;
          final tone = keepTone(
            refused ? VelvetColors.error : VelvetColors.warning,
          );
          glyph = icon(Icons.warning_amber_rounded, tone);
          title = l.discoverJobStopped;
          titleColor = tone;
          final sub = row.sub ?? const <JobText>[];
          final reason = sub.isEmpty ? null : part(sub.first);
          final rest = parts(many);
          subs.add(
            [
              ?reason,
              if (rest.isEmpty) l.discoverJobNothingCopied else ...rest,
            ].join(' · '),
          );
          if (!refused) actions.addAll([?retry()]);
        case JobRowKind.cancelled:
          glyph = icon(Icons.highlight_off, text2);
          titleColor = text2;
          final copied = many == null ? 0 : manyCounts(many).copied;
          if (copied > 0) {
            title = l.discoverJobCancelledSome(copied);
            subs.add(l.discoverJobCancelledStay(copied));
          } else {
            title = l.discoverJobCancelledNothing;
            subs.add(l.discoverJobCancelledSub);
          }
          againAddsTo = l.discoverKeepAddAgainAddsTo;
          actions.add(
            KeepPill(
              l.discoverJobAddAgain,
              key: const ValueKey('keep-add-again'),
              icon: Icons.refresh,
              onTap: () => unawaited(onRetry(job)),
            ),
          );
        case JobRowKind.nothing:
          final guest = row.leadPhrase == JobPhrase.onlyAppearances;
          glyph = icon(
            guest ? Icons.info_outline : Icons.check_circle_outline,
            text2,
          );
          title = guest ? l.discoverJobOnlyGuest : l.discoverJobNothingAll;
          subs.add(
            guest
                ? l.discoverJobOnlyGuestSub(lead.artist, peer)
                : l.discoverJobNothingFrom(peer),
          );
        case JobRowKind.done:
        case JobRowKind.idle:
          glyph = icon(
            Icons.check_circle_outline,
            keepTone(VelvetColors.success),
          );
          title = l.discoverJobDone;
          titleColor = keepTone(VelvetColors.success);
      }
    }
    // Retry and Add again land where files land now: when the copy ran
    // somewhere else, the card says where before the verb is pressed.
    final place = againPlace;
    final addsTo = againAddsTo;

    return Padding(
      key: const ValueKey('keep-job'),
      padding: const EdgeInsets.only(top: 14),
      child: Semantics(
        liveRegion: true,
        container: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 36),
              child: Row(
                children: [
                  SizedBox(width: 20, child: Center(child: glyph)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: titleColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 1.3,
                      ),
                    ),
                  ),
                  if (cancel) ...[
                    const SizedBox(width: 8),
                    KeepPill(
                      l.cancel,
                      key: const ValueKey('keep-cancel'),
                      onTap: () => unawaited(onCancel(job)),
                    ),
                  ],
                ],
              ),
            ),
            if (bar)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    key: const ValueKey('keep-bar'),
                    value: job.progress,
                    minHeight: 4,
                    color: barColor,
                    backgroundColor: VelvetColors.border,
                  ),
                ),
              ),
            for (final s in subs)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  s,
                  style: TextStyle(color: text2, fontSize: 13, height: 1.35),
                ),
              ),
            for (final s in muted)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  s,
                  key: ValueKey('keep-job-muted-${muted.indexOf(s)}'),
                  style: TextStyle(
                    color: VelvetColors.textTertiary,
                    fontSize: 12.5,
                    height: 1.35,
                  ),
                ),
              ),
            if (place != null && addsTo != null)
              ..._againLines(l, addsTo, place, text2),
            if (actions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Wrap(spacing: 8, runSpacing: 0, children: actions),
              ),
          ],
        ),
      ),
    );
  }
}

/// The quiet line under a path that shows slots ([keepSlotNote]).
class _SlotNote extends StatelessWidget {
  final String text;
  const _SlotNote(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text(
      text,
      style: TextStyle(
        color: VelvetColors.textSecondary,
        fontSize: 12,
        height: 16 / 12,
      ),
    ),
  );
}

/// The first-use note (FedNote's shape in the canvas's kit): raised, radius
/// 10, an info glyph and one sentence in the secondary text.
class _FirstUseNote extends StatelessWidget {
  final String text;
  const _FirstUseNote(this.text);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
    decoration: BoxDecoration(
      color: VelvetColors.raised,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(
            Icons.info_outline,
            size: 16,
            color: VelvetColors.textSecondary,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              color: VelvetColors.textSecondary,
              fontSize: 13,
              height: 18 / 13,
            ),
          ),
        ),
      ],
    ),
  );
}
