import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../objects/discovery_plugins.dart';
import '../../objects/display_item.dart';
import '../../singletons/log_manager.dart';
import '../../theme/velvet_theme.dart';
import '../../util/discover_jobs.dart';
import '../../util/discovery_plugins_api.dart';
import '../../util/image_cache.dart' show artCacheSize;
import '../../util/queue_actions.dart';
import '../../util/youtube_add_words.dart';
import '../../util/ytdl_layout.dart' show kYtdlNeverVars;
import 'destination_pieces.dart' show destHold, destToken, destUsesVar;
import 'destination_sheet.dart';
import 'discovery_jobs_controller.dart';
import 'discovery_keep_routes.dart';
import 'elsewhere_sheet.dart' show openOutside;
import 'keep_copy_ui.dart';
import 'network_lead_sheet.dart' show NetworkKeepSlot;
import 'network_preview_rows.dart' show LeadMatchTag;
import 'youtube_add_ui.dart';

/// KEEP A COPY on the network-lead sheet: the YouTube add (the design
/// canvas's LookupReady, LookupStates and JobStates boards). One card:
/// where files land ("Files go to Music › The Quiet Assembly › Static
/// Bloom", Change), then YouTube — a song the phone cannot play, found on
/// YouTube and added to the user's own library from there.
///
/// Nothing reaches YouTube until the user presses Search YouTube. The
/// search (`POST /plugins/youtube/resolve`) may take a minute: the card
/// counts it, says after 20 s that the server goes on searching (and keeps
/// the answer for a few hours) if the sheet closes, and gives up waiting
/// after 120 s; Stop waiting — or the sheet closing — drops the answer
/// whenever it comes. The answer is the uploads found, best first, each
/// with how closely it matches ("match 96%", a loose one under the bar in
/// the error colour), the first picked; the library's own copy instead
/// (Play, Add to queue); or nothing close. "Add this one" adds only the
/// upload picked.
///
/// Once the song has a YouTube add — one this card started, or one the
/// account made before (the single lookup, as the card opens) — its line
/// replaces the card: waiting, the step it is at ("Fetching from YouTube ·
/// 42%"), how it ended, and its verbs (Cancel, Retry, Choose another — the
/// search again, another upload picked — Play, Add to queue). A cancelled
/// add gives the card back as it was, under "Stopped · nothing was added".
///
/// A press the server refuses keeps the card and says why under it — or,
/// for 403 and 404 (adding turned off for the account, the plug-in gone),
/// the sheet takes the section away and says so ([NetworkKeepSlot]).
class YoutubeKeepBlock extends StatefulWidget {
  final NetworkKeepSlot slot;
  const YoutubeKeepBlock({super.key, required this.slot});

  /// Past this the searching card says YouTube can take a minute.
  static const Duration kSlowAfter = Duration(seconds: 20);

  /// How Play and Add to queue reach the queue (tests stand in for them).
  static Future<void> Function(DisplayItem row) play = playNow;
  static Future<void> Function(DisplayItem row) queue = addToQueueEnd;

  /// Put the real ones back (tests).
  @visibleForTesting
  static void reset() {
    play = playNow;
    queue = addToQueueEnd;
  }

  @override
  State<YoutubeKeepBlock> createState() => _YoutubeKeepBlockState();
}

/// What the YouTube card shows while no add's line takes its place.
enum _Card {
  /// Never searched: what it would search for, Search YouTube.
  idle,

  /// The search is out: the counter, Stop waiting.
  searching,

  /// Uploads found: pick one, Add this one.
  ready,

  /// The library already has the song: Play, Add to queue.
  owned,

  /// Nothing close enough: Search again.
  nothing,

  /// 429, too many searches on the server: Search again.
  busy,

  /// 403, 502, 400 or no answer at all: Search again.
  couldNot,

  /// No answer in 120 s (the server may still finish): Search again.
  timedOut,
}

class _YoutubeKeepBlockState extends State<YoutubeKeepBlock> {
  NetworkKeepSlot get slot => widget.slot;
  DiscoveryJobsController get jobs => slot.jobs;

  /// What every call sends: the lead's repaired recommendation.
  Map<String, dynamic> get rec => slot.lead.raw;

  _Card _card = _Card.idle;

  /// What the search asks for: the row's phrase until the server names its
  /// own.
  late String _query = youtubeSearchPhrase(rec);
  List<YoutubeCandidate> _candidates = const [];
  double _minScore = kYoutubeMinScore;
  String? _ownedPath;
  int _selected = 0;
  bool _expanded = false;

  /// The user picked an upload themselves: a late "Choose another" reading
  /// leaves their pick alone.
  bool _picked = false;

  /// An answer to an older search (one given up on, or before the sheet
  /// closed) is dropped.
  int _gen = 0;
  int _elapsed = 0;
  Timer? _ticker;

  /// The song's YouTube add the line shows (a start's answer, or the one
  /// the lookup found), as first heard of; [DiscoveryJobsController.latest]
  /// of it is what it is now.
  DiscoveryJob? _job;

  /// An add set aside for the card (Choose another; one that failed or was
  /// cancelled, with Copies' Choose another opening the sheet): its line
  /// gives way to the search.
  int? _setAside;

  /// The upload a "Choose another" moves off: the first other one found is
  /// picked.
  String? _avoid;

  /// A start this card asked for answered with a live add of another
  /// upload of the song (the server's dedupe ignores the pick): said under
  /// that add's line.
  int? _otherUploadOf;

  /// Why the server would not start the last add asked (the line under Add
  /// this one, or under a job's Retry), and in which tone.
  (String, Color)? _refusal;

  /// A failed add's raw words are open under Details.
  bool _details = false;

  @override
  void initState() {
    super.initState();
    _avoid = slot.avoidUrl;
    unawaited(_restore());
    if (slot.autoSearch) unawaited(_search());
  }

  @override
  void dispose() {
    // Whatever answers now answers no one.
    _gen++;
    _ticker?.cancel();
    super.dispose();
  }

  // ── the search ───────────────────────────────────────────────────────

  /// The add the account already made of this song, when the card opens:
  /// its line, unless one this card started since is newer. Opened to
  /// choose another upload ([NetworkKeepSlot.autoSearch]), a failed or
  /// cancelled one gives way to the search, and its upload is the one not
  /// picked — unless the slot named one ([NetworkKeepSlot.avoidUrl]: the
  /// row the user chose another for).
  Future<void> _restore() async {
    final found = await jobs.youtubeJobFor(rec);
    if (!mounted || found == null) return;
    final mine = _job;
    if (mine != null && mine.id >= found.id) return;
    setState(() {
      _job = found;
      final state = jobs.latest(found).state;
      if (slot.autoSearch &&
          (state == JobState.failed || state == JobState.cancelled)) {
        _setAside = found.id;
        _avoid ??= found.choiceUrl;
        if (_card == _Card.ready && !_picked) _selected = _firstPick();
      }
    });
  }

  /// The first upload that is not [_avoid]'s (the first when every one is).
  int _firstPick() {
    final avoid = _avoid;
    if (avoid == null) return 0;
    final i = _candidates.indexWhere((c) => c.url != avoid);
    return i < 0 ? 0 : i;
  }

  Future<void> _search() async {
    final gen = ++_gen;
    _ticker?.cancel();
    setState(() {
      _card = _Card.searching;
      _elapsed = 0;
      _refusal = null;
    });
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _elapsed++);
    });
    try {
      final found = await jobs.api.searchYoutube(rec);
      if (!mounted || gen != _gen) return;
      appLog(
        '[lead] yt search n=${found.candidates.length} in ${_elapsed}s'
        '${found.owned ? ' owned' : ''}',
      );
      _ticker?.cancel();
      setState(() {
        if (found.query.isNotEmpty) _query = found.query;
        _minScore = found.minScore;
        if (found.owned) {
          _card = _Card.owned;
          _ownedPath = found.ownedFilepath;
        } else if (found.candidates.isEmpty) {
          _card = _Card.nothing;
        } else {
          _card = _Card.ready;
          _candidates = found.candidates;
          _expanded = false;
          _picked = false;
          _selected = _firstPick();
        }
      });
    } on DiscoveryPluginsException catch (e) {
      if (!mounted || gen != _gen) return;
      appLog('[lead] yt search failed ${e.timedOut ? 'timeout' : e.status}');
      _ticker?.cancel();
      if (e.status == 404) {
        // The plug-in is gone: so is the section.
        slot.onRefused(AppLocalizations.of(context).discoverLeadOptionOff);
        return;
      }
      // The jobs gate or the upload right moved: the gate is read again
      // (the section goes if it closed).
      if (e.status == 403) unawaited(jobs.regate());
      setState(
        () => _card = e.timedOut
            ? _Card.timedOut
            : e.status == 429
            ? _Card.busy
            : _Card.couldNot,
      );
    }
  }

  /// Stop waiting: the card goes back to its start; the server goes on
  /// searching (and keeps what it finds), the answer is dropped here.
  void _stopWaiting() {
    _gen++;
    _ticker?.cancel();
    setState(() => _card = _Card.idle);
  }

  /// Choose another: the search again (the server answers from what it
  /// kept), landing on the uploads with another one than [job]'s picked.
  void _chooseAnother(DiscoveryJob job) {
    setState(() {
      _setAside = job.id;
      _avoid = job.choiceUrl;
      _details = false;
    });
    unawaited(_search());
  }

  // ── starts and the job's verbs ───────────────────────────────────────

  Future<void> _add() async {
    if (_candidates.isEmpty) return;
    final pick = _candidates[_selected.clamp(0, _candidates.length - 1)];
    slot.onLeadAction();
    setState(() => _refusal = null);
    final out = await jobs.start(
      rec,
      plugin: kYoutubePlugin,
      choice: {'url': pick.url},
      // The place on show as Add this one was pressed: one moved since is
      // refused, never quietly used.
      shown: ShownPlace(jobs.destination?.destination),
    );
    _answered(out, pick.url);
  }

  /// Retry (a failed add, or one a file was already in the way of): the
  /// same song and upload again, to where files land now.
  Future<void> _retry(DiscoveryJob job) async {
    setState(() => _refusal = null);
    final out = await jobs.retry(
      job,
      shown: ShownPlace(jobs.destination?.destination),
    );
    _answered(out, job.choiceUrl);
  }

  /// What a start answered: its add's line (with a note when the add is
  /// another upload's: the server took none new), or why it was refused.
  void _answered(StartOutcome out, String? pick) {
    if (out.ignored) return;
    final job = out.job;
    appLog(
      '[lead] yt start job=${job?.id ?? '-'} created=${out.created} '
      'status=${job == null ? out.status ?? 0 : (out.created ? 202 : 200)}',
    );
    if (!mounted) return;
    final l = AppLocalizations.of(context);
    if (job != null) {
      setState(() {
        _job = job;
        _details = false;
        _otherUploadOf = !out.created && job.choiceUrl != pick ? job.id : null;
      });
      if (out.created) slot.onStarted(job);
      return;
    }
    final status = out.status ?? 0;
    if (out.destinationChanged) {
      // Nowhere takes files now: the gate closes and the section with it.
      if (jobs.destination?.destination == null) {
        slot.toast(l.discoverKeepNoLibrary);
        return;
      }
      // The path above is redrawn from the answer: the user checks it and
      // adds again.
      setState(
        () => _refusal = (
          l.discoverKeepDestChanged,
          keepTone(VelvetColors.warning),
        ),
      );
      return;
    }
    // Adding was turned off for the account, or the plug-in is gone: the
    // section goes, and the sheet says why.
    if (status == 403 || status == 404) {
      slot.onRefused(
        status == 403 ? l.discoverLeadAddOff : l.discoverLeadOptionOff,
      );
      return;
    }
    setState(
      () => _refusal = (
        youtubeStartRefusalText(
          l,
          DiscoveryPluginsException(status, out.error ?? ''),
        ),
        keepTone(status == 409 ? VelvetColors.warning : VelvetColors.error),
      ),
    );
  }

  Future<void> _cancel(DiscoveryJob job) async {
    final l = AppLocalizations.of(context);
    final r = await jobs.cancel(job);
    if (!mounted) return;
    if (r.outcome == CancelOutcome.alreadyFinished) {
      slot.toast(l.discoverCopiesAlreadyFinished);
    } else if (r.outcome == CancelOutcome.failed) {
      slot.toast(l.discoverCopiesCancelFailed);
    }
  }

  void _play(String filepath) {
    slot.onLeadAction();
    unawaited(YoutubeKeepBlock.play(keepOwnFileRow(jobs.server, filepath)));
  }

  Future<void> _queue(String filepath) async {
    final l = AppLocalizations.of(context);
    slot.onLeadAction();
    await YoutubeKeepBlock.queue(keepOwnFileRow(jobs.server, filepath));
    slot.toast(l.browserSongsAdded(1));
  }

  Future<void> _openUpload(YoutubeCandidate c) async {
    final l = AppLocalizations.of(context);
    final uri = Uri.tryParse(c.url);
    var ok = false;
    try {
      ok = uri != null && await openOutside(uri);
    } catch (_) {
      ok = false;
    }
    if (!ok && mounted) slot.toast(l.discoverToastLinkFailed);
  }

  // ── drawing ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: jobs,
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final mine = _job;
    final job = mine == null || mine.id == _setAside ? null : jobs.latest(mine);
    // A cancelled add gives the card back, under one quiet line.
    final line = job != null && job.state != JobState.cancelled;
    final destination = _destination(l);
    return Padding(
      key: const ValueKey('yt-block'),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        decoration: BoxDecoration(
          color: VelvetColors.card,
          borderRadius: BorderRadius.circular(VelvetColors.radiusLarge),
          border: Border.all(color: VelvetColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (destination != null) ...[
              destination,
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 12),
                child: Divider(
                  height: 1,
                  thickness: 1,
                  color: VelvetColors.border,
                ),
              ),
            ] else
              const SizedBox(height: 12),
            if (line) ...[
              _title(l, tagged: false),
              const SizedBox(height: 4),
              ..._jobLine(l, job),
            ] else ...[
              if (job != null) _cancelledLine(l),
              ..._cardBody(l),
            ],
            if (_refusal != null) _refusalLine(_refusal!),
          ],
        ),
      ),
    );
  }

  /// "Files go to Music › The Quiet Assembly › Static Bloom", Change. The
  /// song's own tags as the plug-in files a download (destination.js
  /// tagsForLayout of what it tags the file with, youtube.js run): its
  /// artist, album, year and album credit; GENRE, PEER and SERVERFOLDER are
  /// always empty, and a layout naming them says so under the path.
  Widget? _destination(AppLocalizations l) {
    final d = jobs.destination?.destination;
    if (d == null) return null;
    final t = previewTarget(
      vpath: d.vpath,
      base: d.base,
      layout: d.layout,
      tags: {
        'artist': rec['artist'],
        'album': rec['album'],
        'year': rec['year'],
        'genre': null,
        'albumartist': rec['albumArtist'],
      },
      fileName: '${rec['title'] ?? ''}',
    );
    // A path past the server's cap: the warning where the path goes.
    final tooLong = t.tooLong;
    final crumbs = t.valid
        ? t.crumbs
        : [if (!tooLong && d.vpath.isNotEmpty) d.vpath];
    final never = [
      for (final v in kYtdlNeverVars)
        if (destUsesVar(d.layout, v)) destToken(v),
    ];
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
      for (var i = 0; i < crumbs.length; i++) ...[
        if (i > 0) TextSpan(text: ' › ', style: soft),
        ...keepCrumbSpans(l, crumbs[i], style: strong, hold: destHold),
      ],
    ];
    return Row(
      key: const ValueKey('yt-destination'),
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
                Text.rich(
                  TextSpan(children: spans),
                  key: const ValueKey('yt-destination-path'),
                ),
                if (never.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      l.ytdlWhereAlwaysEmpty(never.join(', ')),
                      key: const ValueKey('yt-never-note'),
                      style: TextStyle(
                        color: VelvetColors.textSecondary,
                        fontSize: 12,
                        height: 16 / 12,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Semantics(
          button: true,
          label: l.discoverLeadYtChangeHint,
          excludeSemantics: true,
          child: InkWell(
            key: const ValueKey('yt-change'),
            borderRadius: BorderRadius.circular(VelvetColors.radiusSmall),
            onTap: () {
              // The user is checking the path the warning points at.
              if (_refusal != null) setState(() => _refusal = null);
              DiscoveryKeepRoutes.changeDestination(
                context,
                jobs,
                DestinationPreviewSong.ofLead(slot.lead, download: true),
                '',
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

  /// "YouTube", and what the card is doing on the right ("searching",
  /// "already yours"; nothing over an add's line: [tagged] false).
  Widget _title(AppLocalizations l, {bool tagged = true}) {
    final Widget? tag = !tagged
        ? null
        : switch (_card) {
            _Card.searching => Row(
              key: const ValueKey('yt-searching-tag'),
              mainAxisSize: MainAxisSize.min,
              children: [
                KeepRing(size: 12, color: keepInk()),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    l.discoverLeadYtSearchingTag,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: keepInk(),
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            _Card.owned => LeadMatchTag(
              l.discoverJobOwned,
              key: const ValueKey('yt-owned-tag'),
              tone: keepTone(VelvetColors.success),
            ),
            _ => null,
          };
    return Row(
      children: [
        Expanded(
          child: Text(
            'YouTube',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: VelvetColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 20 / 15,
            ),
          ),
        ),
        // The tag at the far end, never wider than the title's half.
        if (tag != null) ...[
          const SizedBox(width: 8),
          Flexible(
            child: Align(alignment: AlignmentDirectional.centerEnd, child: tag),
          ),
        ],
      ],
    );
  }

  Widget _text(
    String text, {
    Key? key,
    Color? color,
    double size = 13,
    double top = 4,
  }) => Padding(
    padding: EdgeInsets.only(top: top),
    child: Text(
      text,
      key: key,
      style: TextStyle(
        color: color ?? VelvetColors.textSecondary,
        fontSize: size,
        height: size <= 12 ? 16 / size : 1.35,
      ),
    ),
  );

  Widget _pills(List<Widget> pills) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Wrap(spacing: 8, runSpacing: 0, children: pills),
  );

  Widget _searchAgain(AppLocalizations l) => _pills([
    KeepPill(
      l.discoverLeadYtSearchAgain,
      key: const ValueKey('yt-search-again'),
      icon: Icons.refresh,
      onTap: () => unawaited(_search()),
    ),
  ]);

  /// The card in its [_card] state, under its title.
  List<Widget> _cardBody(AppLocalizations l) {
    final title = _title(l);
    switch (_card) {
      case _Card.idle:
        return [
          title,
          _text(l.discoverLeadYtIdle(_query), key: const ValueKey('yt-idle')),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: KeepPill(
              l.discoverLeadYtSearch,
              key: const ValueKey('yt-search'),
              icon: Icons.search,
              primary: true,
              expand: true,
              onTap: () => unawaited(_search()),
            ),
          ),
        ];
      case _Card.searching:
        return [
          title,
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    l.discoverLeadYtAsking(_query),
                    style: TextStyle(
                      color: VelvetColors.textSecondary,
                      fontSize: 13,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  keepClock(Duration(seconds: _elapsed)),
                  key: const ValueKey('yt-counter'),
                  style: TextStyle(
                    color: VelvetColors.textTertiary,
                    fontSize: 12,
                    height: 1.5,
                    fontFamily: 'monospace',
                    fontFamilyFallback: kMonoFallback,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ),
          if (_elapsed >= YoutubeKeepBlock.kSlowAfter.inSeconds)
            _text(
              l.discoverLeadYtSlowHint,
              key: const ValueKey('yt-slow-hint'),
              color: VelvetColors.textTertiary,
              size: 12,
              top: 6,
            ),
          _pills([
            KeepPill(
              l.discoverLeadYtStopWaiting,
              key: const ValueKey('yt-stop'),
              onTap: _stopWaiting,
            ),
          ]),
        ];
      case _Card.ready:
        return [title, ..._ready(l)];
      case _Card.owned:
        final fp = _ownedPath;
        return [
          title,
          _text(l.discoverJobOwnedSub),
          if (fp != null) ...[
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                pathCrumbs(fp).join(' / '),
                key: const ValueKey('yt-owned-path'),
                style: TextStyle(
                  color: VelvetColors.textTertiary,
                  fontSize: 11,
                  height: 16 / 11,
                  fontFamily: 'monospace',
                  fontFamilyFallback: kMonoFallback,
                ),
              ),
            ),
            _pills(_playPills(l, fp)),
          ],
        ];
      case _Card.nothing:
        return [
          title,
          _text(
            l.discoverLeadYtNothing(_query),
            key: const ValueKey('yt-nothing'),
          ),
          _searchAgain(l),
        ];
      case _Card.busy:
        return [
          title,
          _text(
            l.discoverLeadYtBusy,
            key: const ValueKey('yt-busy'),
            color: keepTone(VelvetColors.warning),
          ),
          _searchAgain(l),
        ];
      case _Card.couldNot:
        return [
          title,
          _text(l.discoverLeadYtCouldnt, key: const ValueKey('yt-couldnt')),
          _searchAgain(l),
        ];
      case _Card.timedOut:
        return [
          title,
          _text(l.discoverLeadYtTimedOut, key: const ValueKey('yt-timed-out')),
          _searchAgain(l),
        ];
    }
  }

  /// "5 uploads found · pick one", the uploads (only the one picked until
  /// the list is opened), Add this one, and that only the pick is added.
  List<Widget> _ready(AppLocalizations l) {
    final n = _candidates.length;
    final selected = _selected.clamp(0, n - 1);
    final starting = jobs.isStarting(rec, null, kYoutubePlugin);
    final shown = _expanded || n <= 1
        ? [for (var i = 0; i < n; i++) i]
        : [selected];
    return [
      _text(l.discoverLeadYtFound(n), top: 2),
      Padding(
        padding: const EdgeInsets.only(top: 8),
        child: Semantics(
          label: l.discoverLeadYtUploadsA11y,
          container: true,
          explicitChildNodes: true,
          child: Column(
            key: const ValueKey('yt-uploads'),
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final i in shown)
                Padding(
                  padding: EdgeInsets.only(top: i == shown.first ? 0 : 8),
                  child: _candidate(
                    l,
                    i,
                    selected: i == selected,
                    enabled: !starting,
                  ),
                ),
            ],
          ),
        ),
      ),
      if (n > 1)
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            key: const ValueKey('yt-more'),
            onPressed: starting
                ? null
                : () => setState(() => _expanded = !_expanded),
            style: TextButton.styleFrom(
              foregroundColor: keepInk(),
              minimumSize: const Size(0, 44),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            iconAlignment: IconAlignment.end,
            icon: Icon(
              _expanded ? Icons.expand_less : Icons.expand_more,
              size: 18,
            ),
            label: Text(
              _expanded ? l.discoverLeadYtFewer : l.discoverLeadYtMore(n - 1),
            ),
          ),
        )
      else
        const SizedBox(height: 6),
      KeepPill(
        l.discoverLeadYtAddThis,
        key: const ValueKey('yt-add'),
        icon: Icons.library_add,
        primary: true,
        expand: true,
        busy: starting,
        onTap: () => unawaited(_add()),
      ),
      _text(
        l.discoverLeadYtOnlyPick,
        key: const ValueKey('yt-only-pick'),
        color: VelvetColors.textTertiary,
        size: 12,
        top: 2,
      ),
    ];
  }

  /// One upload: its thumbnail, title, channel and length, how closely it
  /// matches, and its page on YouTube.
  Widget _candidate(
    AppLocalizations l,
    int i, {
    required bool selected,
    required bool enabled,
  }) {
    final c = _candidates[i];
    final pct = (c.score * 100).round();
    final loose = c.loose(_minScore);
    final d = c.durationSec;
    final sub = [
      ?c.channel,
      if (d != null) keepClock(Duration(seconds: d)),
    ].join(' · ');
    final radius = BorderRadius.circular(10);
    final tile = Container(
      width: 64,
      height: 36,
      decoration: BoxDecoration(
        color: VelvetColors.raised,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(Icons.play_arrow, size: 18, color: VelvetColors.textTertiary),
    );
    final thumb = c.thumbnail;
    return Semantics(
      key: ValueKey('yt-candidate-$i'),
      container: true,
      inMutuallyExclusiveGroup: true,
      checked: selected,
      button: true,
      enabled: enabled,
      child: Material(
        color: selected ? VelvetColors.primaryDim : Colors.transparent,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: enabled
              ? () => setState(() {
                  _selected = i;
                  _picked = true;
                })
              : null,
          child: Container(
            constraints: const BoxConstraints(minHeight: 64),
            padding: const EdgeInsets.fromLTRB(10, 8, 0, 8),
            decoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(
                color: selected ? VelvetColors.primary : VelvetColors.border2,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: thumb == null
                      ? tile
                      : Image.network(
                          thumb.toString(),
                          width: 64,
                          height: 36,
                          fit: BoxFit.cover,
                          cacheWidth: artCacheSize(64),
                          errorBuilder: (_, _, _) => tile,
                        ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (c.title.isNotEmpty)
                        Text(
                          c.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: VelvetColors.textPrimary,
                            fontSize: 14,
                            height: 18 / 14,
                          ),
                        ),
                      if (sub.isNotEmpty)
                        Text(
                          sub,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: VelvetColors.textSecondary,
                            fontSize: 12,
                            height: 16 / 12,
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: LeadMatchTag(
                          loose
                              ? l.discoverLeadLooseMatchPill(pct)
                              : l.discoverLeadMatchPill(pct),
                          key: ValueKey('yt-match-$i'),
                          tone: keepTone(
                            loose ? VelvetColors.error : VelvetColors.success,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  key: ValueKey('yt-open-$i'),
                  tooltip: l.discoverLeadYtOpenOnYoutube,
                  onPressed: () => unawaited(_openUpload(c)),
                  icon: Icon(
                    Icons.open_in_new,
                    size: 18,
                    color: VelvetColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _playPills(AppLocalizations l, String filepath) => [
    KeepPill(
      l.play,
      key: const ValueKey('yt-play'),
      icon: Icons.play_arrow,
      primary: true,
      onTap: () => _play(filepath),
    ),
    KeepPill(
      l.discoverJobAddToQueue,
      key: const ValueKey('yt-queue'),
      icon: Icons.queue_music,
      onTap: () => unawaited(_queue(filepath)),
    ),
  ];

  /// "Stopped · nothing was added", over the card given back.
  Widget _cancelledLine(AppLocalizations l) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      key: const ValueKey('yt-cancelled'),
      children: [
        Icon(Icons.highlight_off, size: 16, color: VelvetColors.textTertiary),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            l.discoverJobYtCancelled,
            style: TextStyle(
              color: VelvetColors.textTertiary,
              fontSize: 12,
              height: 16 / 12,
            ),
          ),
        ),
      ],
    ),
  );

  /// The line a refused start leaves under the card (or the job's Retry).
  Widget _refusalLine((String, Color) refusal) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Semantics(
      liveRegion: true,
      child: Row(
        key: const ValueKey('yt-refusal'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(
              Icons.warning_amber_rounded,
              size: 16,
              color: refusal.$2,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              refusal.$1,
              style: TextStyle(color: refusal.$2, fontSize: 13, height: 1.35),
            ),
          ),
        ],
      ),
    ),
  );

  /// The song's YouTube add in place of the card: its glyph and state, the
  /// step it is at and the bar while it runs, how it ended, its verbs.
  List<Widget> _jobLine(AppLocalizations l, DiscoveryJob job) {
    final row = jobRowState(job, plugin: kYoutubePlugin);
    final text2 = VelvetColors.textSecondary;
    final ink = keepInk();
    Widget icon(IconData i, Color c) => Icon(i, size: 18, color: c);

    late Widget glyph;
    late String title;
    Color titleColor = VelvetColors.textPrimary;
    final subs = <String>[];
    String? meta;
    var bar = false;
    Color barColor = VelvetColors.primary;
    var cancel = false;
    String? raw;
    final actions = <Widget>[];
    Widget retry() => KeepPill(
      l.discoverJobRetry,
      key: const ValueKey('yt-retry'),
      icon: Icons.refresh,
      onTap: () => unawaited(_retry(job)),
    );

    switch (row.kind) {
      case JobRowKind.queued:
        glyph = icon(Icons.schedule, text2);
        title = l.discoverJobQueued;
        subs.add(l.discoverJobQueuedSub);
        cancel = true;
      case JobRowKind.running:
        final stopping = job.cancelRequested;
        glyph = KeepRing(size: 18, color: stopping ? text2 : ink);
        title = stopping ? l.discoverJobStopping : youtubeStepText(l, job);
        titleColor = stopping ? text2 : ink;
        bar = true;
        if (stopping) barColor = VelvetColors.textTertiary;
        cancel = !stopping;
      case JobRowKind.downloaded:
      case JobRowKind.copied:
        final v = job.view;
        glyph = icon(
          Icons.check_circle_outline,
          keepTone(VelvetColors.success),
        );
        title = l.discoverJobInCollection;
        titleColor = keepTone(VelvetColors.success);
        final fp = row.filepath;
        if (fp != null) subs.add(pathCrumbs(fp).join(' / '));
        final format = v.downloadedFormat;
        final channel = v.matchChannel;
        final parts = [
          if (format != null) format.toUpperCase(),
          if (fmtBytes(v.downloadedBytes).isNotEmpty)
            fmtBytes(v.downloadedBytes),
          if (channel != null) l.discoverJobYtFromChannel(channel),
        ];
        if (parts.isNotEmpty) meta = parts.join(' · ');
        if (fp != null) actions.addAll(_playPills(l, fp));
      case JobRowKind.owned:
        glyph = icon(Icons.check_circle_outline, text2);
        title = l.discoverJobOwned;
        final fp = row.filepath;
        subs.add(
          fp == null ? l.discoverJobOwnedSub : pathCrumbs(fp).join(' / '),
        );
        if (fp != null) actions.addAll(_playPills(l, fp));
      case JobRowKind.exists:
        final warn = keepTone(VelvetColors.warning);
        glyph = icon(Icons.warning_amber_rounded, warn);
        title = l.discoverJobSkipped;
        titleColor = warn;
        subs.add(
          l.discoverJobExistsSub(pathCrumbs(job.view.filepath).join(' / ')),
        );
        // Change, above, is the way out; Retry once the place moved.
        actions.add(retry());
      case JobRowKind.failed:
        final err = keepTone(VelvetColors.error);
        final failure = youtubeFailureOf(job.error);
        glyph = icon(Icons.error_outline, err);
        title = l.discoverJobAddFailed;
        titleColor = err;
        subs.add(youtubeFailureText(l, failure));
        raw = job.error;
        if (failure.choosesAnother) {
          actions.add(
            KeepPill(
              l.discoverJobYtChooseAnother,
              key: const ValueKey('yt-choose-another'),
              icon: Icons.search,
              primary: true,
              onTap: () => _chooseAnother(job),
            ),
          );
        }
        if (failure.retries) actions.add(retry());
      case JobRowKind.cancelled:
      case JobRowKind.copiedMany:
      case JobRowKind.stopped:
      case JobRowKind.nothing:
      case JobRowKind.done:
      case JobRowKind.idle:
        // Finished, with nothing this line can read (a newer plug-in's
        // result).
        glyph = icon(
          Icons.check_circle_outline,
          keepTone(VelvetColors.success),
        );
        title = l.discoverJobDone;
        titleColor = keepTone(VelvetColors.success);
    }
    final details = raw;

    return [
      Semantics(
        liveRegion: true,
        container: true,
        child: Column(
          key: ValueKey('yt-job-${job.id}'),
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
                      key: const ValueKey('yt-job-title'),
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
                      key: const ValueKey('yt-cancel'),
                      onTap: () => unawaited(_cancel(job)),
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
                    key: const ValueKey('yt-bar'),
                    value: job.progress,
                    minHeight: 2,
                    color: barColor,
                    backgroundColor: VelvetColors.border,
                  ),
                ),
              ),
            for (final s in subs) _text(s, top: 6),
            if (meta != null)
              _text(
                meta,
                key: const ValueKey('yt-job-meta'),
                color: VelvetColors.textTertiary,
                size: 12,
              ),
            if (details != null)
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: TextButton(
                  key: const ValueKey('yt-details'),
                  onPressed: () => setState(() => _details = !_details),
                  style: TextButton.styleFrom(
                    foregroundColor: keepInk(),
                    minimumSize: const Size(0, 44),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: Text(l.ytdlStripDetails),
                ),
              ),
            if (details != null && _details)
              Text(
                details,
                key: const ValueKey('yt-error-raw'),
                style: TextStyle(
                  color: VelvetColors.textTertiary,
                  fontSize: 11,
                  height: 16 / 11,
                  fontFamily: 'monospace',
                  fontFamilyFallback: kMonoFallback,
                ),
              ),
            if (_otherUploadOf == job.id)
              _text(
                l.discoverLeadYtAlreadyAdding,
                key: const ValueKey('yt-other-upload'),
                color: keepTone(VelvetColors.warning),
                top: 6,
              ),
            if (actions.isNotEmpty) _pills(actions),
          ],
        ),
      ),
    ];
  }
}
