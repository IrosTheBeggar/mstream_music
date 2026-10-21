import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../objects/discovery.dart';
import '../../objects/discovery_plugins.dart';
import '../../objects/display_item.dart';
import '../../singletons/settings.dart';
import '../../theme/velvet_theme.dart';
import '../../util/discover_badges.dart';
import '../../util/discover_copy_gate.dart';
import '../../util/discover_jobs.dart';
import '../../util/queue_actions.dart';
import '../../widgets/federation_widgets.dart';
import 'destination_sheet.dart';
import 'discovery_jobs_controller.dart';
import 'discovery_keep_routes.dart';
import 'keep_copy_facts.dart';
import 'keep_copy_ui.dart';

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
  });

  @override
  State<KeepCopySection> createState() => _KeepCopySectionState();
}

/// What the chips choose between (artist covers both artist scopes).
const String _kChipArtist = kScopeArtist;

class _KeepCopySectionState extends State<KeepCopySection> {
  late String? _chip = widget.initialChoice == kScopeArtistMissing
      ? _kChipArtist
      : widget.initialChoice;
  bool _onlyMissing = true;
  String? _error;

  /// The pill's place, and the job line's when it stands in for the pill,
  /// for [_revealPill].
  final GlobalKey _pillAnchor = GlobalKey();
  final GlobalKey _jobAnchor = GlobalKey();

  /// The user chose a chip on this card (the only-missing box landing after
  /// that brings the pill back into view too).
  bool _chipChosen = false;

  /// Whether the only-missing box showed on the last build.
  bool _missingShown = false;

  DiscoveryJobsController get jobs => widget.jobs;
  DiscoveryLead get lead => widget.lead;

  List<String> get _scopes => widget.albumFocus
      ? jobs.scopesForCard(
          widget.cardLeads.isEmpty ? [lead] : widget.cardLeads,
          compilation: widget.compilation,
        )
      : jobs.scopesForRow(lead);

  List<String> _chips(List<String> scopes) => [
    if (scopes.contains(kScopeSong)) kScopeSong,
    if (scopes.contains(kScopeAlbum)) kScopeAlbum,
    if (scopes.contains(kScopeArtist) || scopes.contains(kScopeArtistMissing))
      _kChipArtist,
  ];

  String? _chipNow(List<String> chips) {
    if (chips.isEmpty) return null;
    final c = _chip;
    if (c != null && chips.contains(c)) return c;
    if (widget.albumFocus && chips.contains(kScopeAlbum)) return kScopeAlbum;
    return chips.first;
  }

  List<String>? get _missing => widget.facts.facts.missing;

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

  List<String> _crumbs(String scope) {
    final d = jobs.destination?.destination;
    if (d == null) return const [];
    final artistScope = scope == kScopeArtist || scope == kScopeArtistMissing;
    final one = artistScope ? _oneMissing(scope) : null;
    // This row's year speaks only for this row's album.
    final ownAlbum =
        !artistScope || (one != null && nameKey(one) == nameKey(lead.album));
    final t = previewTarget(
      vpath: d.vpath,
      base: d.base,
      layout: d.layout,
      tags: {
        'artist': lead.artist,
        // An artist copy lands album by album, so no one album names the
        // folder — unless only one is missing, which it then names.
        'album': artistScope ? one : lead.album,
        'year': ownAlbum ? lead.year : null,
        // The artist walk copies the artist's own albums, credited to the
        // artist (federation-copy asks album-songs by albumArtist = the
        // artist): ALBUMARTIST falls back to the artist, never this row's
        // compilation credit ("Various Artists").
        'albumartist': artistScope ? null : lead.albumArtist,
      },
      peerName: widget.peerName,
      fileName: lead.filepath,
    );
    return t.valid ? t.crumbs : [if (d.vpath.isNotEmpty) d.vpath];
  }

  bool _folderPerAlbum(String scope) {
    final layout = jobs.destination?.destination?.layout ?? '';
    return (scope == kScopeArtist || scope == kScopeArtistMissing) &&
        _oneMissing(scope) == null &&
        RegExp(r'\{\{\s*ALBUM\s*\}\}', caseSensitive: false).hasMatch(layout);
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
      count = widget.facts.facts.peerAlbums?.length;
    } else if (scope == kScopeArtistMissing) {
      final m = _missing?.length;
      if (m == null || m <= 1) return true;
      count = m;
    } else {
      return true;
    }
    final peer = widget.peerName;
    final known = count != null && count > 0;
    return fedConfirm(
      context,
      title: known
          ? l.discoverKeepConfirmTitle(count, peer)
          : l.discoverKeepConfirmEveryTitle(lead.artist, peer),
      message: l.discoverKeepConfirmBody(_crumbs(scope).join(' › ')),
      confirmLabel: known
          ? l.discoverKeepConfirmAction(count)
          : l.discoverKeepConfirmEveryAction,
    );
  }

  Future<void> _start(String scope) async {
    if (!await _confirm(scope)) return;
    if (!mounted) return;
    setState(() => _error = null);
    final out = await jobs.start(lead.raw, scope: scope);
    if (!mounted) return;
    _started(out);
    final err = out.error;
    if (err != null) {
      setState(
        () =>
            _error = _startWords(AppLocalizations.of(context), err, out.status),
      );
    }
  }

  /// A copy the server took as new: the first-use note is done with, and
  /// the sheet hears of it (its toast, once it closes).
  void _started(StartOutcome out) {
    final job = out.job;
    if (job == null || !out.created || out.fromOtherPeer) return;
    unawaited(SettingsManager().markDiscoverKeepNoteSeen());
    widget.onStarted?.call(job);
  }

  /// The song the destination picker previews: this row's, or in album
  /// focus the album's first song once its songs are known.
  DestinationPreviewSong _previewSong() {
    final songs = widget.albumFocus ? widget.facts.facts.albumSongs : null;
    if (songs != null && songs.isNotEmpty) {
      final s = songs.first;
      final m = s.metadata;
      String? pick(String? v, String? or) =>
          (v ?? '').trim().isNotEmpty ? v : or;
      return DestinationPreviewSong(
        title: pick(m?.title, s.name) ?? s.name,
        artist: pick(m?.artist, lead.artist) ?? lead.artist,
        album: pick(m?.album, lead.album),
        albumArtist: lead.albumArtist,
        year: m?.year ?? lead.year,
        filepath: s.data,
      );
    }
    return DestinationPreviewSong.ofLead(lead);
  }

  /// "Copies go to your server, not this phone": until the first copy
  /// starts or a destination is saved (on this phone, or the account's
  /// already saved one), and while the account has no copy at all.
  bool get _firstUse =>
      !SettingsManager().discoverKeepNoteSeen &&
      jobs.destination?.saved == null &&
      !jobs.jobs.any((j) => j.plugin == kCopyPlugin);

  Future<void> _retry(DiscoveryJob job) async {
    setState(() => _error = null);
    final out = await jobs.retry(job);
    if (!mounted) return;
    _started(out);
    final err = out.error;
    if (err != null) {
      setState(
        () =>
            _error = _startWords(AppLocalizations.of(context), err, out.status),
      );
    }
  }

  Future<void> _cancel(DiscoveryJob job) async {
    final r = await jobs.cancel(job);
    if (!mounted) return;
    if (r.outcome == CancelOutcome.failed) {
      setState(() => _error = r.message);
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
    return ListenableBuilder(
      listenable: Listenable.merge([jobs, widget.facts]),
      builder: (context, _) => _build(context),
    );
  }

  Widget _build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final scopes = _scopes;
    final chips = _chips(scopes);
    final chip = _chipNow(chips);
    if (chip == null) return const SizedBox.shrink();
    final gate = jobs.gate(_scopeOf(chip, scopes));
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
            if (_error != null) _errorLine(_error!),
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
          if (shown != null && _error != null) _errorLine(_error!),
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
      default:
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
      _ => l.discoverKeepArtist,
    };
    return KeepChoice(
      key: ValueKey('keep-chip-$chip'),
      label: label,
      size: size,
      sizeLoading: loading,
      selected: selected,
      onTap: () {
        setState(() {
          _chip = chip;
          _chipChosen = true;
          _error = null;
        });
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

  Widget _destination(AppLocalizations l, String scope) {
    final crumbs = _crumbs(scope);
    // A segment never breaks inside itself: the line breaks only between
    // the › separators.
    String hold(String s) => s.replaceAll(' ', '\u00A0');
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
      TextSpan(text: '${l.discoverKeepFilesGoTo} ', style: soft),
    ];
    for (var i = 0; i < crumbs.length; i++) {
      if (i > 0) spans.add(TextSpan(text: ' › ', style: soft));
      spans.add(TextSpan(text: hold(crumbs[i]), style: strong));
    }
    if (_folderPerAlbum(scope)) {
      spans.add(TextSpan(text: ' › ', style: soft));
      spans.add(
        TextSpan(text: hold(l.discoverKeepFolderPerAlbum), style: soft),
      );
    }
    return Row(
      key: const ValueKey('keep-destination'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Icon(
            Icons.folder_outlined,
            size: 16,
            color: VelvetColors.textSecondary,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 13),
            child: Text.rich(TextSpan(children: spans)),
          ),
        ),
        Semantics(
          button: true,
          label: l.discoverKeepChangeHint,
          excludeSemantics: true,
          child: InkWell(
            key: const ValueKey('keep-change'),
            borderRadius: BorderRadius.circular(VelvetColors.radiusSmall),
            onTap: () => DiscoveryKeepRoutes.changeDestination(
              context,
              jobs,
              _previewSong(),
              widget.peerName,
            ),
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

  Widget _errorLine(String words) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Semantics(
      liveRegion: true,
      child: Row(
        key: const ValueKey('keep-error'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              Icons.warning_amber_rounded,
              size: 16,
              color: keepTone(VelvetColors.error),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              words,
              style: TextStyle(
                color: keepTone(VelvetColors.error),
                fontSize: 13,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    ),
  );
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
  });

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
    var bar = false;
    Color barColor = VelvetColors.primary;
    var cancel = false;
    final actions = <Widget>[];

    Widget icon(IconData i, Color c) => Icon(i, size: 20, color: c);
    Widget retry() => job.state == JobState.failed && jobNeedsNewSeeds(job)
        ? KeepPill(
            l.discoverPageNewSeeds,
            key: const ValueKey('keep-new-seeds'),
            icon: Icons.refresh,
            onTap: onNewSeeds,
          )
        : KeepPill(
            l.discoverJobRetry,
            key: const ValueKey('keep-retry'),
            icon: Icons.refresh,
            onTap: () => unawaited(onRetry(job)),
          );
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
          cancel = true;
        case JobRowKind.running:
          final stopping = job.cancelRequested;
          glyph = KeepRing(size: 18, color: stopping ? text2 : ink);
          title = stopping ? l.discoverJobStopping : l.discoverJobCopying;
          titleColor = stopping ? text2 : ink;
          bar = true;
          if (stopping) barColor = VelvetColors.textTertiary;
          subs.add(status.isNotEmpty ? status : l.discoverJobStarting);
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
          if (n != null && (n.failed > 0 || n.albumsFailed > 0)) {
            actions.add(retry());
          }
        case JobRowKind.owned:
          glyph = icon(
            Icons.check_circle_outline,
            keepTone(VelvetColors.success),
          );
          title = l.discoverJobOwned;
          titleColor = keepTone(VelvetColors.success);
          if (many != null) {
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
          actions.add(retry());
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
          actions.add(retry());
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
          if (!refused) actions.add(retry());
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
