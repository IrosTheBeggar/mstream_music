import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../l10n/app_localizations.dart';
import '../../objects/discovery.dart';
import '../../objects/discovery_plugins.dart';
import '../../objects/display_item.dart';
import '../../theme/velvet_theme.dart';
import '../../util/discover_badges.dart' show nameKey;
import '../../util/discover_jobs.dart';
import '../../util/queue_actions.dart';
import 'copy_news.dart';
import 'discovery_jobs_controller.dart';
import 'discovery_listing.dart';
import 'discovery_page_controller.dart';
import 'keep_copy_ui.dart';
import 'keep_toast.dart';

/// The Copies sheet (the design canvas's PhoneCopies board): what the
/// user's server is copying for them, reached from Discover's Copies strip
/// and from the home's SERVER "Copies" row. A scroll-controlled sheet:
/// COPYING (running, then waiting), STOPPED OR FAILED (failed jobs, and
/// finished copies that failed or stopped), JUST FINISHED (copies this
/// phone saw end since), each row with its title, "Kind · Artist · from
/// Server", a bar while it copies and its state line with one verb —
/// Cancel, Retry, Play (and Add to queue), Add again. "Clear finished" is
/// pinned at the bottom. A connected server's folder copy (kept while
/// browsing it) is a row too — the folder's name, "Folder · from Server", a
/// folder tile — whose Retry and Add again send its own landing again.
///
/// States: loading (still rows at the real row height), the list failing
/// (Try again), nothing copying (from home: Open Discover), and a cancel
/// that lost the race to the end (409: the row turns into its outcome and a
/// toast says nothing was cancelled). Polls at the fast beat while open.

/// Tall sheets stop here and scroll inside (the header and Clear finished
/// stay put).
const double kCopiesSheetMaxHeight = 0.89;

Future<void> showCopiesSheet(
  BuildContext context,
  DiscoveryJobsController jobs, {
  bool fromHome = false,
}) => showModalBottomSheet<void>(
  context: context,
  backgroundColor: VelvetColors.surface,
  isScrollControlled: true,
  constraints: BoxConstraints(
    maxHeight: MediaQuery.of(context).size.height * kCopiesSheetMaxHeight,
  ),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
  ),
  builder: (_) => CopiesSheet(jobs: jobs, fromHome: fromHome),
);

class CopiesSheet extends StatefulWidget {
  final DiscoveryJobsController jobs;

  /// Opened from the home's Copies row: the empty state offers Discover.
  final bool fromHome;
  const CopiesSheet({super.key, required this.jobs, this.fromHome = false});

  @override
  State<CopiesSheet> createState() => _CopiesSheetState();
}

class _CopiesSheetState extends State<CopiesSheet> {
  VoidCallback? _release;
  bool _clearing = false;

  DiscoveryJobsController get jobs => widget.jobs;

  @override
  void initState() {
    super.initState();
    // A live copy on show polls fast while the sheet is open.
    _release = jobs.holdFast();
    // What the server holds now: the list once more (the poll may be
    // stopped), or everything the first time.
    if (jobs.jobsLoaded) {
      unawaited(jobs.refreshJobs());
    } else {
      unawaited(jobs.activate());
    }
  }

  @override
  void dispose() {
    _release?.call();
    super.dispose();
  }

  void _toast(String message) => KeepToast.show(context, message);

  /// The server's own words for a refused start, else the localized line.
  String _startWords(AppLocalizations l, String error, int? status) {
    final fromServer =
        status != null &&
        status >= 400 &&
        !RegExp(r'^HTTP \d+$').hasMatch(error.trim());
    return fromServer ? error : l.discoverKeepStartFailed;
  }

  Future<void> _cancel(DiscoveryJob job) async {
    final l = AppLocalizations.of(context);
    final r = await jobs.cancel(job);
    if (!mounted) return;
    if (r.outcome == CancelOutcome.alreadyFinished) {
      _toast(l.discoverCopiesAlreadyFinished);
    } else if (r.outcome == CancelOutcome.failed) {
      _toast(l.discoverCopiesCancelFailed);
    }
  }

  /// Retry and Add again start the copy again where it ran (the sheet shows
  /// no place); one moved since starts nothing and says to retry it from
  /// Keep a copy, which shows where files land now.
  Future<void> _retry(DiscoveryJob job) async {
    final l = AppLocalizations.of(context);
    final out = await jobs.retryWhereItRan(job);
    if (!mounted) return;
    final err = out.error;
    if (err == null) return;
    _toast(
      out.destinationChanged
          ? l.discoverCopiesDestChanged
          : _startWords(l, err, out.status),
    );
  }

  Future<void> _clear() async {
    final l = AppLocalizations.of(context);
    setState(() => _clearing = true);
    final removed = await jobs.clearFinished();
    if (!mounted) return;
    setState(() => _clearing = false);
    if (removed == null) {
      final words = jobs.jobsError;
      _toast(
        jobs.jobsErrorFromServer && words != null
            ? words
            : l.discoverKeepStartFailed,
      );
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

  Future<void> _play(List<String> files) async {
    if (files.isEmpty) return;
    if (files.length == 1) {
      await playNow(_ownFile(files.first));
    } else {
      await playFromHere([for (final f in files) _ownFile(f)], 0);
    }
  }

  Future<void> _queue(List<String> files) async {
    final l = AppLocalizations.of(context);
    if (files.isEmpty) return;
    final n = await addRowsToQueue([for (final f in files) _ownFile(f)]);
    if (n > 0) _toast(l.browserSongsAdded(n));
  }

  /// "New seeds" for a copy whose server was re-paired: only while the
  /// Discover page these copies belong to is open (it asks again).
  DiscoveryPageController? get _page {
    final page = DiscoveryListing().controller;
    return page != null && identical(page.jobs, jobs) ? page : null;
  }

  void _newSeeds() {
    final page = _page;
    if (page == null) return;
    Navigator.of(context).pop();
    unawaited(page.refresh());
  }

  bool get _discoverReachable =>
      jobs.server.discoveryAvailable == true &&
      jobs.server.discoveryTasteAvailable == true;

  void _openDiscover() {
    final server = jobs.server;
    Navigator.of(context).pop();
    DiscoveryListing().open(server);
  }

  // ── drawing ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: jobs,
    builder: (context, _) => _build(context),
  );

  Widget _build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final loading = !jobs.jobsLoaded && jobs.jobsError == null;
    final failed = !jobs.jobsLoaded && jobs.jobsError != null;
    final copies = jobs.copies;
    final live = copies.where(isLive).toList();
    final attention = copies.where((j) => !isLive(j)).toList();
    final finished = jobs.justFinished;
    final empty = !loading && !failed && copies.isEmpty && finished.isEmpty;
    final summary = jobs.summary;
    final summaryText = [
      if (summary.running > 0) l.discoverCopiesCopying(summary.running),
      if (summary.failed > 0) l.discoverCopiesFailed(summary.failed),
    ].join(' · ');

    final Widget body;
    if (loading) {
      body = Semantics(
        key: const ValueKey('copies-loading'),
        label: l.discoverCopiesLoading,
        container: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [for (var i = 0; i < 3; i++) const _SkeletonRow()],
        ),
      );
    } else if (failed) {
      final words = jobs.jobsError;
      body = _StateCard(
        key: const ValueKey('copies-failed'),
        icon: Icons.error_outline,
        iconColor: keepTone(VelvetColors.error),
        title: l.discoverCopiesLoadFailed,
        sub: jobs.jobsErrorFromServer && words != null
            ? words
            : l.discoverCopiesLoadFailedSub,
        pill: KeepPill(
          l.discoverPageRetry,
          key: const ValueKey('copies-try-again'),
          icon: Icons.refresh,
          primary: true,
          onTap: () => unawaited(jobs.refreshJobs()),
        ),
      );
    } else if (empty) {
      body = _StateCard(
        key: const ValueKey('copies-empty'),
        icon: Icons.library_add_outlined,
        iconColor: VelvetColors.textTertiary,
        title: l.discoverCopiesEmpty,
        sub: l.discoverCopiesEmptySubAny,
        pill: widget.fromHome && _discoverReachable
            ? KeepPill(
                l.discoverCopiesOpenDiscover,
                key: const ValueKey('copies-open-discover'),
                onTap: _openDiscover,
              )
            : null,
      );
    } else {
      Widget row(DiscoveryJob j) => _CopyRow(
        key: ValueKey('copies-row-${j.id}'),
        job: j,
        jobs: jobs,
        canNewSeeds: _page != null,
        onCancel: _cancel,
        onRetry: _retry,
        onNewSeeds: _newSeeds,
        onPlay: _play,
        onQueue: _queue,
      );
      body = SingleChildScrollView(
        key: const ValueKey('copies-list'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (live.isNotEmpty) ...[
              KeepSheetLabel(l.discoverCopiesSectionCopying),
              for (final j in live) row(j),
            ],
            if (attention.isNotEmpty) ...[
              KeepSheetLabel(l.discoverCopiesSectionAttention),
              for (final j in attention) row(j),
            ],
            if (finished.isNotEmpty) ...[
              KeepSheetLabel(l.discoverCopiesSectionFinished),
              for (final j in finished) row(j),
            ],
            const SizedBox(height: 8),
          ],
        ),
      );
    }
    final clearable =
        !loading && !failed && (attention.isNotEmpty || finished.isNotEmpty);

    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _GrabHandle(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 2, 20, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    l.discoverCopiesTitle,
                    style: TextStyle(
                      color: VelvetColors.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      height: 24 / 18,
                    ),
                  ),
                ),
                if (loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 6),
                    child: _Bone(width: 128, height: 12),
                  )
                else if (summaryText.isNotEmpty && !failed)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      summaryText,
                      key: const ValueKey('copies-summary'),
                      style: TextStyle(
                        color: VelvetColors.textSecondary,
                        fontSize: 13,
                        height: 18 / 13,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Divider(height: 1, thickness: 1, color: VelvetColors.border),
          Flexible(child: body),
          if (clearable)
            Container(
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: VelvetColors.border)),
              ),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: KeepPill(
                l.discoverCopiesClearFinished,
                key: const ValueKey('copies-clear'),
                expand: true,
                busy: _clearing,
                onTap: () => unawaited(_clear()),
              ),
            ),
        ],
      ),
    );
  }
}

// ── one row ───────────────────────────────────────────────────────────────

enum _Verb { cancel, retry, newSeeds, addAgain, play, queue }

/// What one row draws for its job.
class _RowSpec {
  Widget? glyph;
  String line1 = '';
  Color? line1Color;
  int line1Lines = 2;
  String? line2;
  int line2Lines = 3;
  bool bar = false;
  Color barColor = VelvetColors.primary;
  final verbs = <_Verb>[];
}

class _CopyRow extends StatelessWidget {
  final DiscoveryJob job;
  final DiscoveryJobsController jobs;
  final bool canNewSeeds;
  final Future<void> Function(DiscoveryJob) onCancel;
  final Future<void> Function(DiscoveryJob) onRetry;
  final VoidCallback onNewSeeds;
  final Future<void> Function(List<String>) onPlay;
  final Future<void> Function(List<String>) onQueue;

  const _CopyRow({
    super.key,
    required this.job,
    required this.jobs,
    required this.canNewSeeds,
    required this.onCancel,
    required this.onRetry,
    required this.onNewSeeds,
    required this.onPlay,
    required this.onQueue,
  });

  Map<String, dynamic> get _rec => job.recommendation;
  String _s(String k) => _rec[k] is String ? (_rec[k] as String).trim() : '';

  String _peer() => keepJobPeer(job, '');

  String _title(AppLocalizations l) {
    switch (job.scope) {
      case kScopeAlbum:
        return _s('album');
      case kScopeArtist:
        return l.discoverCopiesEveryAlbumBy(_s('artist'));
      case kScopeArtistMissing:
        return l.discoverCopiesMissingOf(_s('artist'));
      case kScopeFolder:
        return folderTitle(_rec);
      default:
        final t = _s('title');
        return t.isNotEmpty ? t : safeFileName(_rec['filepath']);
    }
  }

  String _kindLine(AppLocalizations l) {
    final peer = _peer();
    final from = peer.isEmpty ? null : l.discoverCopiesFrom(peer);
    String? nonEmpty(String s) => s.isEmpty ? null : s;
    return switch (job.scope) {
      kScopeAlbum => [
        l.discoverCopiesKindAlbum,
        ?nonEmpty(
          _s('albumArtist').isNotEmpty ? _s('albumArtist') : _s('artist'),
        ),
        ?from,
      ],
      kScopeArtist => [l.discoverCopiesKindEvery, ?from],
      kScopeArtistMissing => [l.discoverCopiesKindMissing, ?from],
      kScopeFolder => [l.discoverCopiesKindFolder, ?from],
      _ => [l.discoverCopiesKindSong, ?nonEmpty(_s('artist')), ?from],
    }.join(' · ');
  }

  /// The library files a finished copy left (Play / Add to queue): a song's
  /// landed or matched file, an album's or an artist's copied songs (and
  /// the ones already there). The lists stop at 500.
  List<String> _files() {
    final v = job.view;
    final copied = v.copiedFilepath;
    if (copied != null) return [copied];
    if (v.skipped == 'owned' && v.existingFilepath != null) {
      return [v.existingFilepath!];
    }
    if (!v.isMany) return const [];
    final songs = job.result?['songs'];
    if (songs is! Map) return const [];
    final out = <String>[];
    final c = songs['copied'];
    if (c is List) {
      for (final e in c) {
        final fp = e is Map ? e['filepath'] : null;
        if (fp is String && fp.isNotEmpty) out.add(fp);
      }
    }
    final s = songs['skipped'];
    if (s is List) {
      for (final e in s) {
        final at = e is Map && e['why'] == 'owned' ? e['at'] : null;
        if (at is String && at.isNotEmpty) out.add(at);
      }
    }
    return out;
  }

  /// "copies › ALM › Free Instrumentals Vol. 9": the folder a file is in.
  static String _folderOf(String? filepath) {
    final parts = pathCrumbs(filepath);
    if (parts.length > 1) parts.removeLast();
    return parts.join(' › ');
  }

  _RowSpec _spec(AppLocalizations l) {
    final r = _RowSpec();
    final row = jobRowState(job, plugin: kCopyPlugin);
    final peer = _peer();
    final text2 = VelvetColors.textSecondary;
    final many = job.view.isMany ? job.result : null;
    String part(JobText t) =>
        keepJobText(l, t, peer: peer, artist: _s('artist'));
    String parts() => many == null
        ? ''
        : [for (final t in manyParts(many)) part(t)].join(' · ');
    Widget icon(IconData i, Color c) => Icon(i, size: 18, color: c);

    switch (row.kind) {
      case JobRowKind.queued:
        r.glyph = icon(Icons.schedule, text2);
        r.line1 = l.discoverJobQueued;
        r.line1Color = text2;
        r.line2 = l.discoverJobQueuedSub;
        r.verbs.add(_Verb.cancel);
      case JobRowKind.running:
        final stopping = job.cancelRequested;
        final status = (job.statusText ?? '').trim();
        r.bar = true;
        if (stopping) {
          r.barColor = VelvetColors.textTertiary;
          r.glyph = KeepRing(size: 16, color: keepInk());
          r.line1 = l.discoverJobStopping;
        } else {
          r.line1 = status.isNotEmpty ? status : l.discoverJobStarting;
          r.line1Color = text2;
          r.verbs.add(_Verb.cancel);
        }
      case JobRowKind.copied:
      case JobRowKind.downloaded:
        r.glyph = icon(
          Icons.check_circle_outline,
          keepTone(VelvetColors.success),
        );
        r.line1 = l.discoverJobInCollection;
        r.line2 = _folderOf(row.filepath);
        r.line2Lines = 1;
        r.verbs
          ..add(_Verb.play)
          ..add(_Verb.queue);
      case JobRowKind.copiedMany:
        r.glyph = icon(
          Icons.check_circle_outline,
          keepTone(VelvetColors.success),
        );
        r.line1 = l.discoverJobInCollection;
        r.line2 = parts();
        if (_files().isNotEmpty) r.verbs.add(_Verb.play);
        final n = manyCounts(many!);
        if (n.failed > 0 || n.albumsFailed > 0) r.verbs.add(_Verb.retry);
      case JobRowKind.owned:
        r.glyph = icon(Icons.check_circle_outline, text2);
        r.line1 = l.discoverJobOwned;
        r.line2 = many != null ? parts() : l.discoverJobOwnedSub;
        if (_files().isNotEmpty) r.verbs.add(_Verb.play);
      case JobRowKind.exists:
        final warn = keepTone(VelvetColors.warning);
        r.glyph = icon(Icons.warning_amber_rounded, warn);
        r.line1 = l.discoverJobSkipped;
        r.line1Color = warn;
        r.line2 = _folderOf(job.view.filepath);
        r.line2Lines = 1;
        r.verbs.add(_Verb.retry);
      case JobRowKind.failed:
        final err = keepTone(VelvetColors.error);
        r.glyph = icon(Icons.error_outline, err);
        r.line1Color = err;
        if (many != null) {
          r.line1 = copyFailedWords(l, job);
        } else {
          r.line1 = l.discoverJobFailed;
          r.line2 = copyFailedWords(l, job);
        }
        if (jobNeedsNewSeeds(job)) {
          if (canNewSeeds) r.verbs.add(_Verb.newSeeds);
        } else {
          r.verbs.add(_Verb.retry);
        }
      case JobRowKind.stopped:
        final warn = keepTone(VelvetColors.warning);
        final refused = row.leadPhrase == JobPhrase.stoppedRefused;
        r.glyph = icon(Icons.warning_amber_rounded, warn);
        r.line1 = l.discoverJobStopped;
        r.line1Color = warn;
        final sub = row.sub ?? const <JobText>[];
        final rest = parts();
        r.line2 = [
          if (sub.isNotEmpty) part(sub.first),
          rest.isEmpty ? l.discoverJobNothingCopied : rest,
        ].join(' · ');
        if (!refused) r.verbs.add(_Verb.retry);
      case JobRowKind.cancelled:
        r.glyph = icon(Icons.highlight_off, text2);
        final copied = many == null ? 0 : manyCounts(many).copied;
        r.line1 = copied > 0
            ? l.discoverJobCancelledSome(copied)
            : l.discoverJobCancelledNothing;
        r.line2 = l.discoverJobCancelledSub;
        r.verbs.add(_Verb.addAgain);
      case JobRowKind.nothing:
        final guest = row.leadPhrase == JobPhrase.onlyAppearances;
        r.glyph = icon(
          guest ? Icons.info_outline : Icons.check_circle_outline,
          text2,
        );
        r.line1 = guest ? l.discoverJobOnlyGuest : l.discoverJobNothingAll;
        r.line2 = guest
            ? l.discoverJobOnlyGuestSub(_s('artist'), peer)
            : l.discoverJobNothingFrom(peer);
      case JobRowKind.done:
      case JobRowKind.idle:
        r.glyph = icon(
          Icons.check_circle_outline,
          keepTone(VelvetColors.success),
        );
        r.line1 = l.discoverJobDone;
    }
    return r;
  }

  /// The row's cover: the Discover row's art when the page holds it, else a
  /// tile (a person for the artist scopes, a folder for a folder copy).
  Widget _cover() {
    Widget tile(IconData i, {double size = 22, Color? color}) => Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: VelvetColors.raised,
        borderRadius: BorderRadius.circular(VelvetColors.radiusSmall),
      ),
      child: Icon(i, size: size, color: color ?? VelvetColors.textSecondary),
    );
    final scope = job.scope;
    if (scope == kScopeArtist || scope == kScopeArtistMissing) {
      return tile(Icons.person_outline);
    }
    if (scope == kScopeFolder) {
      return tile(
        Icons.folder,
        size: 24,
        color: keepTone(VelvetColors.warning),
      );
    }
    DiscoveryLead? lead;
    for (final l in jobs.leads) {
      if (l.peerId != job.peerId) continue;
      final same = scope == kScopeAlbum
          ? nameKey(l.album) == nameKey(_rec['album'])
          : l.filepath == _rec['filepath'];
      if (same) {
        lead = l;
        break;
      }
    }
    final art = lead == null ? null : discoveryLeadArtItem(jobs.server, lead);
    if (art != null) return art.getAlbumThumb(size: 40);
    return tile(scope == kScopeAlbum ? Icons.album : Icons.music_note);
  }

  Widget _verb(AppLocalizations l, _Verb v) {
    switch (v) {
      case _Verb.cancel:
        return KeepPill(
          l.cancel,
          key: const ValueKey('copies-cancel'),
          onTap: () => unawaited(onCancel(job)),
        );
      case _Verb.retry:
        return KeepPill(
          l.discoverJobRetry,
          key: const ValueKey('copies-retry'),
          icon: Icons.refresh,
          primary: true,
          busy: jobs.isStarting(
            job.recommendation,
            job.scope == kScopeSong ? null : job.scope,
          ),
          onTap: () => unawaited(onRetry(job)),
        );
      case _Verb.newSeeds:
        return KeepPill(
          l.discoverPageNewSeeds,
          key: const ValueKey('copies-new-seeds'),
          icon: Icons.refresh,
          onTap: onNewSeeds,
        );
      case _Verb.addAgain:
        return KeepPill(
          l.discoverJobAddAgain,
          key: const ValueKey('copies-add-again'),
          icon: Icons.refresh,
          busy: jobs.isStarting(
            job.recommendation,
            job.scope == kScopeSong ? null : job.scope,
          ),
          onTap: () => unawaited(onRetry(job)),
        );
      case _Verb.play:
        return KeepPill(
          l.play,
          key: const ValueKey('copies-play'),
          icon: Icons.play_arrow,
          onTap: () => unawaited(onPlay(_files())),
        );
      case _Verb.queue:
        return Semantics(
          button: true,
          label: l.discoverJobAddToQueue,
          excludeSemantics: true,
          child: KeepHitArea(
            onTap: () => unawaited(onQueue(_files())),
            child: Material(
              key: const ValueKey('copies-queue'),
              color: VelvetColors.raised,
              shape: const CircleBorder(),
              child: SizedBox(
                width: 36,
                height: 36,
                child: Icon(
                  Icons.queue_music,
                  size: 18,
                  color: VelvetColors.textPrimary,
                ),
              ),
            ),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final spec = _spec(l);
    final lines = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          spec.line1,
          maxLines: spec.line1Lines,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: spec.line1Color ?? VelvetColors.textPrimary,
            fontSize: 13,
            height: 18 / 13,
          ),
        ),
        if (spec.line2 != null && spec.line2!.isNotEmpty)
          Text(
            spec.line2!,
            maxLines: spec.line2Lines,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: VelvetColors.textSecondary,
              fontSize: 13,
              height: 18 / 13,
            ),
          ),
      ],
    );
    final state = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (spec.glyph != null) ...[
          Padding(padding: const EdgeInsets.only(top: 1), child: spec.glyph),
          const SizedBox(width: 6),
        ],
        Expanded(child: lines),
      ],
    );
    final verbs = spec.verbs.isEmpty
        ? null
        : Wrap(
            spacing: 8,
            runSpacing: 0,
            children: [for (final v in spec.verbs) _verb(l, v)],
          );
    return Semantics(
      container: true,
      child: Container(
        decoration: BoxDecoration(
          color: VelvetColors.surface,
          border: Border(bottom: BorderSide(color: VelvetColors.border)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _cover(),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _title(l),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: VelvetColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                      height: 20 / 15,
                    ),
                  ),
                  Text(
                    _kindLine(l),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: VelvetColors.textSecondary,
                      fontSize: 13,
                      height: 18 / 13,
                    ),
                  ),
                  if (spec.bar)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(2),
                        child: LinearProgressIndicator(
                          key: const ValueKey('copies-bar'),
                          value: job.progress,
                          minHeight: 4,
                          color: spec.barColor,
                          backgroundColor: VelvetColors.border,
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: LayoutBuilder(
                      builder: (context, box) {
                        // The verbs sit beside the state line; on a narrow
                        // row or at a large text size they go under it.
                        final scale = MediaQuery.textScalerOf(context).scale(1);
                        final stacked =
                            verbs != null &&
                            (box.maxWidth < 250 || scale > 1.15);
                        if (verbs == null) {
                          return ConstrainedBox(
                            constraints: const BoxConstraints(minHeight: 24),
                            child: state,
                          );
                        }
                        if (stacked) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              state,
                              Padding(
                                padding: const EdgeInsets.only(top: 2),
                                child: verbs,
                              ),
                            ],
                          );
                        }
                        return ConstrainedBox(
                          constraints: const BoxConstraints(minHeight: 36),
                          child: Row(
                            children: [
                              Expanded(child: state),
                              const SizedBox(width: 10),
                              verbs,
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── small pieces ──────────────────────────────────────────────────────────

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

class _Bone extends StatelessWidget {
  final double? width;
  final double height;
  final double? fraction;
  const _Bone({this.width, required this.height, this.fraction});

  @override
  Widget build(BuildContext context) {
    final block = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: VelvetColors.raised,
        borderRadius: BorderRadius.circular(height / 2),
      ),
    );
    if (fraction == null) return block;
    return FractionallySizedBox(
      alignment: Alignment.centerLeft,
      widthFactor: fraction,
      child: block,
    );
  }
}

/// A row's still placeholder at the real row height.
class _SkeletonRow extends StatelessWidget {
  const _SkeletonRow();

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('copies-skeleton-row'),
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: VelvetColors.border)),
    ),
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: VelvetColors.raised,
            borderRadius: BorderRadius.circular(VelvetColors.radiusSmall),
          ),
        ),
        const SizedBox(width: 12),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 4),
              _Bone(height: 12, fraction: 0.58),
              SizedBox(height: 10),
              _Bone(height: 12, fraction: 0.76),
              SizedBox(height: 14),
              _Bone(height: 4, fraction: 1),
              SizedBox(height: 12),
              _Bone(height: 12, fraction: 0.44),
            ],
          ),
        ),
      ],
    ),
  );
}

/// Empty and error: a glyph, one sentence, its line, one pill.
class _StateCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String sub;
  final Widget? pill;
  const _StateCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.sub,
    this.pill,
  });

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 32, color: iconColor),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: VelvetColors.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              height: 20 / 15,
            ),
          ),
          const SizedBox(height: 4),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 290),
            child: Text(
              sub,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: VelvetColors.textSecondary,
                fontSize: 13,
                height: 18 / 13,
              ),
            ),
          ),
          if (pill != null) ...[const SizedBox(height: 12), pill!],
        ],
      ),
    ),
  );
}

/// The home's Copies card's second lines: "Copying 2" in the primary's ink,
/// "1 failed" in the error colour, one part per line so neither ellipsizes
/// in a half-width card; nothing while idle.
class CopiesHomeLines extends StatelessWidget {
  final DiscoveryJobsController jobs;
  const CopiesHomeLines({super.key, required this.jobs});

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: jobs,
    builder: (context, _) {
      final l = AppLocalizations.of(context);
      final s = jobs.summary;
      if (s.running == 0 && s.failed == 0) return const SizedBox.shrink();
      TextStyle style(Color c) =>
          TextStyle(fontSize: 13, color: c, height: 17 / 13);
      return Column(
        key: const ValueKey('home-copies-lines'),
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (s.running > 0)
            Text(
              l.discoverCopiesCopying(s.running),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style(keepInkOn(VelvetColors.card)),
            ),
          if (s.failed > 0)
            Text(
              l.discoverCopiesFailed(s.failed),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style(keepTone(VelvetColors.error)),
            ),
        ],
      );
    },
  );
}
