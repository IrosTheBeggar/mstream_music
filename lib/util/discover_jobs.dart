/// The Discover job rows' pure half, ported from the mStream webapp's
/// `webapp/alpha/discover-jobs.js` (its cases in
/// `test/unit/webapp-discover-jobs.test.mjs` are ported in
/// test/util/discover_jobs_test.dart): what a plug-in job looks like as a
/// row, where a collection copy will land for the layout being typed, and
/// what the Copies list holds.
///
/// Nothing here speaks English: a row carries [JobPhrase]s with their
/// numbers ([JobText]) and the UI translates them; the server's own words
/// (a job's status line, its error) travel verbatim as [JobText.server].
///
/// Where the phone departs from the webapp it says so at the spot (the
/// Copies list keeps a finished copy that failed or stopped; an album job's
/// title names a compilation's album artist).
library;

import 'dart:math' as math;

import '../objects/discovery_plugins.dart';

// ── the layout engine, mirrored ──────────────────────────────────────────
// mStream src/torrent/path-template.js + src/discovery-plugins/destination.js
// (through the webapp's copy). The server renders the real path and has the
// last word; this renders the same thing as the user types so the picker's
// preview never lies. The unit test holds it to golden values the server's
// own engine produced.

const List<String> kLayoutVars = [
  'ARTIST',
  'ALBUM',
  'YEAR',
  'GENRE',
  'ALBUMARTIST',
  'PEER',
];
const String kDefaultLayout = kDefaultCopyLayout;
const int _maxTemplateLen = 500;
const int _maxResolvedLen = 500;
const int _maxSegmentLen = 200;
final RegExp _tokenRe = RegExp(r'\{\{\s*([A-Za-z_][A-Za-z0-9_]*)\s*\}\}');

/// The sample the server validates a layout against (SAMPLE_METADATA + peer).
const Map<String, String> kSampleTags = {
  'artist': 'Pink Floyd',
  'album': 'The Dark Side of the Moon',
  'year': '1973',
  'genre': 'Progressive Rock',
  'albumartist': 'Pink Floyd',
};
const String kSamplePeer = "Sam's server";

final RegExp _badSegmentChars = RegExp(r'[/\\:*?<>|"\x00-\x1f]+');
final RegExp _spaces = RegExp(r'\s+');
final RegExp _edgeDots = RegExp(r'^[.\s]+|[.\s]+$');
final RegExp _controlChars = RegExp(r'[\x00-\x1f]');
final RegExp _driveLetter = RegExp(r'^[a-zA-Z]:');

/// JS `String(v)` for the values a tag carries.
String _jsString(Object? v) {
  if (v is double && v == v.roundToDouble() && v.isFinite) {
    return v.toInt().toString();
  }
  return '$v';
}

/// JS truthiness for a tag value (`a || b`).
bool _truthy(Object? v) =>
    v != null && v != '' && v != 0 && v != false && !(v is double && v.isNaN);

String sanitizeSegment(Object? raw) {
  if (raw == null) return '';
  var s = _jsString(raw);
  s = s.replaceAll(_badSegmentChars, '-');
  s = s.replaceAll(_spaces, ' ');
  s = s.replaceAll(_edgeDots, '');
  if (s.length > _maxSegmentLen) s = s.substring(0, _maxSegmentLen);
  return s;
}

/// A rendered layout: the path, and the variables this song had no value
/// for (their segments drop out).
class ResolvedLayout {
  final String path;
  final List<String> missingVars;
  const ResolvedLayout(this.path, this.missingVars);
}

/// [meta] keys: artist, album, year, genre, albumartist, peer.
ResolvedLayout resolveLayout(Object? layout, Map<String, Object?>? meta) {
  if (layout is! String || layout.isEmpty) return const ResolvedLayout('', []);
  final m = meta ?? const {};
  final lookup = <String, String>{
    'ARTIST': sanitizeSegment(m['artist']),
    'ALBUM': sanitizeSegment(m['album']),
    'YEAR': sanitizeSegment(m['year']),
    'GENRE': sanitizeSegment(m['genre']),
    'ALBUMARTIST': sanitizeSegment(
        _truthy(m['albumartist']) ? m['albumartist'] : m['artist']),
    'PEER': sanitizeSegment(m['peer']),
  };
  final missing = <String>[];
  final substituted = layout.replaceAllMapped(_tokenRe, (match) {
    final key = match.group(1)!.toUpperCase();
    final v = lookup[key];
    if (v == null || v.isEmpty) {
      if (!missing.contains(key)) missing.add(key);
      return '';
    }
    return v;
  });
  final segments = substituted
      .split(RegExp(r'[/\\]+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty);
  var path = segments.join('/');
  if (path.length > _maxResolvedLen) path = path.substring(0, _maxResolvedLen);
  return ResolvedLayout(path, missing);
}

/// valid, or the server's error code (one translation table serves both),
/// with the offending variable for `unknown_variable`.
class LayoutCheck {
  final bool valid;
  final String? error;
  final String? variable;
  const LayoutCheck.ok()
      : valid = true,
        error = null,
        variable = null;
  const LayoutCheck.bad(this.error, {this.variable}) : valid = false;
}

LayoutCheck validateResolvedPath(Object? path) {
  if (path is! String) return const LayoutCheck.bad('invalid_type');
  if (path.isEmpty) return const LayoutCheck.bad('empty_path');
  if (path.length > _maxResolvedLen) return const LayoutCheck.bad('path_too_long');
  if (_controlChars.hasMatch(path)) return const LayoutCheck.bad('invalid_chars');
  if (path.startsWith('/') || path.startsWith('\\')) {
    return const LayoutCheck.bad('absolute_path');
  }
  if (_driveLetter.hasMatch(path)) return const LayoutCheck.bad('drive_letter');
  if (path.contains('~') ||
      RegExp(r'\$HOME\b').hasMatch(path) ||
      path.contains(r'${HOME}')) {
    return const LayoutCheck.bad('home_string');
  }
  for (final seg in path.split(RegExp(r'[/\\]'))) {
    if (seg == '..') return const LayoutCheck.bad('traversal');
    if (_driveLetter.hasMatch(seg)) {
      return const LayoutCheck.bad('drive_letter_segment');
    }
  }
  return const LayoutCheck.ok();
}

LayoutCheck validateLayout(Object? layout) {
  if (layout is! String) return const LayoutCheck.bad('invalid_type');
  if (layout.isEmpty) return const LayoutCheck.bad('empty_template');
  if (layout.length > _maxTemplateLen) {
    return const LayoutCheck.bad('template_too_long');
  }
  final tokens = [
    for (final m in _tokenRe.allMatches(layout))
      (raw: m.group(0)!, name: m.group(1)!.toUpperCase()),
  ];
  var stripped = layout;
  for (final tok in tokens) {
    stripped = stripped.replaceFirst(tok.raw, '');
  }
  if (stripped.contains('{') || stripped.contains('}')) {
    return const LayoutCheck.bad('unbalanced_braces');
  }
  for (final tok in tokens) {
    if (!kLayoutVars.contains(tok.name)) {
      return LayoutCheck.bad('unknown_variable', variable: tok.name);
    }
  }
  if (_controlChars.hasMatch(layout)) return const LayoutCheck.bad('invalid_chars');
  if (layout.startsWith('/') || layout.startsWith('\\')) {
    return const LayoutCheck.bad('absolute_template');
  }
  final sample =
      resolveLayout(layout, {...kSampleTags, 'peer': kSamplePeer}).path;
  return validateResolvedPath(sample);
}

/// A base folder, normalised ('' = the library root), or the error code.
class BaseCheck {
  final bool valid;
  final String base;
  final String? error;
  const BaseCheck.ok(this.base)
      : valid = true,
        error = null;
  const BaseCheck.bad(this.error)
      : valid = false,
        base = '';
}

BaseCheck normalizeBase(Object? base) {
  final raw = (base == null ? '' : _jsString(base))
      .replaceAll('\\', '/')
      .split('/')
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .join('/');
  if (raw.isEmpty) return const BaseCheck.ok('');
  final check = validateResolvedPath(raw);
  return check.valid ? BaseCheck.ok(raw) : BaseCheck.bad(check.error);
}

String safeFileName(Object? filePath) {
  final parts = _jsString(filePath ?? '').split('/').where((s) => s.isNotEmpty);
  final last = parts.isEmpty ? '' : parts.last;
  var name = last
      .replaceAll(_badSegmentChars, '-')
      .replaceAll(_spaces, ' ')
      .replaceAll(_edgeDots, '');
  if (name.isEmpty || name == '..') name = 'track';
  return name;
}

/// Where one song lands: the library, the base folder, what the layout
/// rendered from the tags, the file. [error] is set (and [rendered] empty)
/// when the layout or the base folder would be refused, [field] names
/// which; [missingVars] names the variables this song has no value for.
class PreviewTarget {
  final bool valid;
  final String? error;
  final String? variable;

  /// `base` | `layout` | null
  final String? field;
  final String library;
  final String base;
  final String rendered;
  final String file;
  final String relDir;
  final String relPath;
  final List<String> missingVars;

  const PreviewTarget({
    required this.valid,
    this.error,
    this.variable,
    this.field,
    required this.library,
    required this.base,
    required this.rendered,
    required this.file,
    this.relDir = '',
    required this.relPath,
    this.missingVars = const [],
  });

  /// The line the Keep card draws: library › folders (no file).
  List<String> get crumbs => [
        if (library.isNotEmpty) library,
        ...pathCrumbs(relDir),
      ];
}

/// [tags] keys: artist, album, year, genre, albumartist.
PreviewTarget previewTarget({
  String? vpath,
  Object? base,
  Object? layout,
  Map<String, Object?>? tags,
  String? peerName,
  String? fileName,
}) {
  final t = tags ?? const {};
  final b = normalizeBase(base);
  final l = validateLayout(layout);
  final file = safeFileName(fileName);
  final lib = vpath ?? '';
  if (!b.valid) {
    return PreviewTarget(
        valid: false,
        error: b.error,
        field: 'base',
        library: lib,
        base: '',
        rendered: '',
        file: file,
        relPath: '');
  }
  if (!l.valid) {
    return PreviewTarget(
        valid: false,
        error: l.error,
        variable: l.variable,
        field: 'layout',
        library: lib,
        base: b.base,
        rendered: '',
        file: file,
        relPath: '');
  }
  final r = resolveLayout(layout, {
    'artist': t['artist'],
    'album': t['album'],
    'year': t['year'],
    'genre': t['genre'],
    'albumartist': t['albumartist'],
    'peer': peerName,
  });
  if (r.path.isNotEmpty) {
    final check = validateResolvedPath(r.path);
    if (!check.valid) {
      return PreviewTarget(
          valid: false,
          error: check.error,
          field: 'layout',
          library: lib,
          base: b.base,
          rendered: '',
          file: file,
          relPath: '',
          missingVars: r.missingVars);
    }
  }
  final relDir = [b.base, r.path].where((s) => s.isNotEmpty).join('/');
  return PreviewTarget(
    valid: true,
    library: lib,
    base: b.base,
    rendered: r.path,
    file: file,
    relDir: relDir,
    relPath: relDir.isNotEmpty ? '$relDir/$file' : file,
    missingVars: r.missingVars,
  );
}

/// "music/A/B/c.mp3" → ['music', 'A', 'B', 'c.mp3'], for a breadcrumb.
List<String> pathCrumbs(String? filepath) =>
    (filepath ?? '').split('/').where((s) => s.isNotEmpty).toList();

// ── a job as a row ───────────────────────────────────────────────────────

bool isLive(DiscoveryJob? job) => job?.live == true;

String fmtBytes(num? n) {
  if (n == null || !n.isFinite || n <= 0) return '';
  final b = n.toDouble();
  if (b < 1024) return '${b.round()} B';
  if (b < 1024 * 1024) return '${(b / 1024).round()} KB';
  final mb = b / (1024 * 1024);
  if (mb < 1024) return '${mb < 10 ? mb.toStringAsFixed(1) : mb.round()} MB';
  return '${(mb / 1024).toStringAsFixed(1)} GB';
}

/// What a row is, after its job's state and the shape of its result.
enum JobRowKind {
  idle,
  queued,
  running,
  failed,
  cancelled,

  /// A many-song job that ended early: the peer's transfer limit, busy, the
  /// peer going away, or the peer refusing copies.
  stopped,

  /// A many-song job that copied something and was not stopped.
  copiedMany,

  /// A song copy that landed.
  copied,

  /// Nothing copied, the library already had it.
  owned,

  /// A song copy skipped: a file is already at the path.
  exists,

  /// A many-song job with nothing to copy at all.
  nothing,

  /// A download plug-in's landed file.
  downloaded,

  /// Done, with a result this client cannot read.
  done,
}

/// The words a row carries, by meaning (the webapp's `discover.job.*` keys,
/// one for one). The UI maps each to its localized string.
enum JobPhrase {
  queued,
  queuedSub,
  stopping,
  copying,
  downloading,
  starting,
  failed,
  failedSub,
  cancelled,
  cancelledMany,
  cancelledSub,
  cancelledCopySub,
  stopped,
  stoppedQuota,
  stoppedBusy,
  stoppedPeer,
  stoppedRefused,
  inCollection,
  owned,
  ownedSub,
  skipped,
  existsSub,
  nothing,
  nothingToCopy,
  onlyAppearances,
  done,
  savedTo,
  albumsCount,
  copiedCount,
  ownedCount,
  failedCount,
  albumsFailed,
  albumsLeftOut,
}

/// One part of a row's line: a phrase with its numbers, or the server's own
/// words ([server]), verbatim.
class JobText {
  final JobPhrase? phrase;
  final String? server;
  final int? count;
  final String? peer;
  final String? path;

  const JobText(JobPhrase this.phrase, {this.count, this.peer, this.path})
      : server = null;
  const JobText.server(String this.server)
      : phrase = null,
        count = null,
        peer = null,
        path = null;

  @override
  bool operator ==(Object other) =>
      other is JobText &&
      other.phrase == phrase &&
      other.server == server &&
      other.count == count &&
      other.peer == peer &&
      other.path == path;

  @override
  int get hashCode => Object.hash(phrase, server, count, peer, path);

  @override
  String toString() => server != null
      ? 'JobText.server($server)'
      : 'JobText($phrase${count != null ? ', count: $count' : ''}'
          '${peer != null ? ', peer: $peer' : ''}'
          '${path != null ? ', path: $path' : ''})';
}

/// The buttons a row offers (the window maps each to one).
enum JobAction { start, cancel, retry, play, queue }

enum JobIcon { folder, download, clock, warn, close, check }

/// A row's colour role: `src` (live), `err`, `ok`, or plain.
enum JobTone { plain, live, error, ok }

/// What one plug-in's row shows for the job the caller last ran with it.
class JobRow {
  final JobRowKind kind;
  final JobPhrase? tag;
  final JobTone tagTone;
  final JobIcon icon;
  final JobTone iconTone;
  final bool muted;

  /// Whole percent while running; null otherwise ([indeterminate] while
  /// running without a number).
  final int? progress;
  final bool indeterminate;

  /// The second line, part by part (the UI joins them with " · "); null for
  /// none.
  final List<JobText>? sub;
  final List<JobAction> actions;

  /// The library file a finished song lands as (Play / Add to queue).
  final String? filepath;
  final bool live;

  const JobRow({
    this.kind = JobRowKind.idle,
    this.tag,
    this.tagTone = JobTone.plain,
    this.icon = JobIcon.download,
    this.iconTone = JobTone.plain,
    this.muted = false,
    this.progress,
    this.indeterminate = false,
    this.sub,
    this.actions = const [JobAction.start],
    this.filepath,
    this.live = false,
  });

  JobRow _with({
    JobRowKind? kind,
    JobPhrase? tag,
    JobTone? tagTone,
    JobIcon? icon,
    JobTone? iconTone,
    bool? muted,
    int? progress,
    bool? indeterminate,
    List<JobText>? sub,
    List<JobAction>? actions,
    String? filepath,
  }) =>
      JobRow(
        kind: kind ?? this.kind,
        tag: tag ?? this.tag,
        tagTone: tagTone ?? this.tagTone,
        icon: icon ?? this.icon,
        iconTone: iconTone ?? this.iconTone,
        muted: muted ?? this.muted,
        progress: progress ?? this.progress,
        indeterminate: indeterminate ?? this.indeterminate,
        sub: sub ?? this.sub,
        actions: actions ?? this.actions,
        filepath: filepath ?? this.filepath,
        live: live,
      );

  /// The first part's phrase (what a marker reads the reason from).
  JobPhrase? get leadPhrase =>
      sub == null || sub!.isEmpty ? null : sub!.first.phrase;
}

/// What one plug-in's row shows for [job] (null = never asked). [plugin]
/// names the row's plug-in when there is no job.
JobRow jobRowState(DiscoveryJob? job, {String? plugin}) {
  final copy = (plugin ?? job?.plugin) == kCopyPlugin;
  final idle = JobRow(
    icon: copy ? JobIcon.folder : JobIcon.download,
    live: job != null && isLive(job),
  );
  if (job == null) return idle;
  final row = idle;

  if (job.state == JobState.queued) {
    return row._with(
      kind: JobRowKind.queued,
      tag: JobPhrase.queued,
      icon: JobIcon.clock,
      sub: const [JobText(JobPhrase.queuedSub)],
      actions: const [JobAction.cancel],
    );
  }
  if (job.state == JobState.running) {
    final stopping = job.cancelRequested;
    final p = job.progress;
    final pct = p == null ? null : (p * 100).round();
    final text = job.statusText ?? '';
    final List<JobText> sub;
    if (text.isNotEmpty) {
      // A status line that already carries a percentage says enough.
      sub = [
        JobText.server(
            pct == null || text.contains('%') ? text : '$text · $pct%')
      ];
    } else {
      sub = pct == null
          ? const [JobText(JobPhrase.starting)]
          : [JobText.server('$pct%')];
    }
    return JobRow(
      kind: JobRowKind.running,
      tag: stopping
          ? JobPhrase.stopping
          : (copy ? JobPhrase.copying : JobPhrase.downloading),
      tagTone: JobTone.live,
      icon: row.icon,
      iconTone: JobTone.live,
      progress: pct,
      indeterminate: pct == null,
      sub: sub,
      actions: stopping ? const [] : const [JobAction.cancel],
      live: true,
    );
  }
  if (job.state == JobState.failed) {
    return row._with(
      kind: JobRowKind.failed,
      tag: JobPhrase.failed,
      tagTone: JobTone.error,
      icon: JobIcon.warn,
      iconTone: JobTone.error,
      sub: job.error != null
          ? [JobText.server(job.error!)]
          : const [JobText(JobPhrase.failedSub)],
      actions: const [JobAction.retry],
    );
  }
  // An album's or an artist's copy: every song accounted for.
  final res = job.result;
  final many = job.view.isMany ? res : null;
  if (job.state == JobState.cancelled) {
    if (many != null) {
      return row._with(
        kind: JobRowKind.cancelled,
        tag: JobPhrase.cancelled,
        icon: JobIcon.close,
        muted: true,
        sub: [const JobText(JobPhrase.cancelledMany), ...manyParts(many)],
        actions: const [JobAction.start],
      );
    }
    return row._with(
      kind: JobRowKind.cancelled,
      tag: JobPhrase.cancelled,
      icon: JobIcon.close,
      muted: true,
      sub: [
        JobText(copy ? JobPhrase.cancelledCopySub : JobPhrase.cancelledSub)
      ],
      actions: const [JobAction.start],
    );
  }
  if (job.state != JobState.done) return row;

  // A many-song job ends 'done' however it went — "done" is not "kept".
  // What it says comes from result.stopped and result.counts:
  //   stopped (quota · busy · peer · refused)  stopped, with the reason
  //   copied > 0                               in your collection
  //   nothing copied, something failed         failed (Retry)
  //   nothing copied, all already here         already yours
  //   nothing at all                           nothing to copy (an artist
  //                                            who only appears on the
  //                                            peer's albums says so)
  if (many != null) {
    final view = JobResultView(many);
    final peer = view.peerName ?? '';
    final n = manyCounts(many);
    final why = _stoppedWhy[view.stopped];
    // The peer's transfer limit or the peer going away ended it: what landed
    // is in, and starting again takes only the gaps. A peer that refuses
    // copies refuses them again — no Retry.
    if (why != null) {
      return row._with(
        kind: JobRowKind.stopped,
        tag: JobPhrase.stopped,
        tagTone: JobTone.error,
        icon: JobIcon.warn,
        iconTone: JobTone.error,
        sub: [JobText(why, peer: peer), ...manyParts(many)],
        actions: view.stopped == 'refused' ? const [] : const [JobAction.retry],
      );
    }
    // Startable again: the copy is idempotent, so a second run takes only
    // what the library lacks by then.
    if (n.copied > 0) {
      return row._with(
        kind: JobRowKind.copiedMany,
        tag: JobPhrase.inCollection,
        tagTone: JobTone.ok,
        icon: JobIcon.check,
        iconTone: JobTone.ok,
        sub: manyParts(many),
        actions: const [JobAction.start],
      );
    }
    if (n.failed > 0 || n.albumsFailed > 0) {
      return row._with(
        kind: JobRowKind.failed,
        tag: JobPhrase.failed,
        tagTone: JobTone.error,
        icon: JobIcon.warn,
        iconTone: JobTone.error,
        sub: manyParts(many),
        actions: const [JobAction.retry],
      );
    }
    if (n.skipped > 0 || n.albumsOwned > 0) {
      return row._with(
        kind: JobRowKind.owned,
        tag: JobPhrase.owned,
        tagTone: JobTone.ok,
        icon: JobIcon.check,
        iconTone: JobTone.ok,
        sub: manyParts(many),
        actions: const [JobAction.start],
      );
    }
    final parts = n.albumsAppearance > 0
        ? [JobText(JobPhrase.onlyAppearances, count: n.albumsAppearance)]
        : [const JobText(JobPhrase.nothingToCopy), ...manyParts(many)];
    return row._with(
      kind: JobRowKind.nothing,
      tag: JobPhrase.nothing,
      icon: JobIcon.folder,
      muted: true,
      sub: parts,
      actions: const [JobAction.start],
    );
  }

  final view = job.view;
  // A song the peer refuses to copy (mStream since 2026-10-21 ends its job
  // done with `stopped: 'refused'` and nothing copied): it would be refused
  // again, so no Retry.
  if (view.stopped == 'refused') {
    return row._with(
      kind: JobRowKind.stopped,
      tag: JobPhrase.stopped,
      tagTone: JobTone.error,
      icon: JobIcon.warn,
      iconTone: JobTone.error,
      sub: [JobText(JobPhrase.stoppedRefused, peer: view.peerName ?? '')],
      actions: const [],
    );
  }
  // A download that landed in the collection.
  final at = view.downloadedFilepath;
  if (at != null) {
    return row._with(
      kind: JobRowKind.downloaded,
      tag: JobPhrase.done,
      tagTone: JobTone.ok,
      icon: JobIcon.check,
      iconTone: JobTone.ok,
      sub: [JobText(JobPhrase.savedTo, path: pathCrumbs(at).join(' / '))],
      actions: const [JobAction.play, JobAction.queue],
      filepath: at,
    );
  }
  final copied = view.copiedFilepath;
  if (copied != null) {
    return row._with(
      kind: JobRowKind.copied,
      tag: JobPhrase.inCollection,
      tagTone: JobTone.ok,
      icon: JobIcon.check,
      iconTone: JobTone.ok,
      sub: [JobText.server(pathCrumbs(copied).join(' / '))],
      actions: const [JobAction.play, JobAction.queue],
      filepath: copied,
    );
  }
  if (view.skipped == 'owned') {
    final existing = view.existingFilepath;
    return row._with(
      kind: JobRowKind.owned,
      tag: JobPhrase.owned,
      tagTone: JobTone.ok,
      icon: JobIcon.check,
      iconTone: JobTone.ok,
      sub: existing != null
          ? [JobText.server(pathCrumbs(existing).join(' / '))]
          : const [JobText(JobPhrase.ownedSub)],
      actions:
          existing != null ? const [JobAction.play, JobAction.queue] : const [],
      filepath: existing,
    );
  }
  if (view.skipped == 'exists') {
    return row._with(
      kind: JobRowKind.exists,
      tag: JobPhrase.skipped,
      icon: JobIcon.warn,
      sub: [
        JobText(JobPhrase.existsSub,
            path: pathCrumbs(view.filepath).join(' / '))
      ],
      actions: const [JobAction.retry],
    );
  }
  return row._with(
    kind: JobRowKind.done,
    tag: JobPhrase.done,
    tagTone: JobTone.ok,
    icon: JobIcon.check,
    iconTone: JobTone.ok,
    actions: const [],
  );
}

/// Why a many-song job stopped early, as its line's first part.
const Map<String?, JobPhrase> _stoppedWhy = {
  'quota': JobPhrase.stoppedQuota,
  'busy': JobPhrase.stoppedBusy,
  'peer': JobPhrase.stoppedPeer,
  'refused': JobPhrase.stoppedRefused,
};

/// A many-song result's numbers. Songs from `result.counts` — the whole
/// numbers: the per-song lists stop at 500 entries — else the lists (an
/// older server sends no counts). Albums from an artist job's walk: copied
/// from (no error), whose listing failed, and left out — already here
/// ('owned', artist-missing) or only a guest spot ('appearance').
class ManyCounts {
  final int copied;
  final int skipped;
  final int failed;
  final int albums;
  final int albumsFailed;
  final int albumsLeftOut;
  final int albumsOwned;
  final int albumsAppearance;
  const ManyCounts({
    this.copied = 0,
    this.skipped = 0,
    this.failed = 0,
    this.albums = 0,
    this.albumsFailed = 0,
    this.albumsLeftOut = 0,
    this.albumsOwned = 0,
    this.albumsAppearance = 0,
  });
}

ManyCounts manyCounts(Map<String, dynamic> many) {
  final s = many['songs'] is Map ? many['songs'] as Map : const {};
  final c = many['counts'] is Map ? many['counts'] as Map : null;
  // JS Number(): a present null counts 0, a numeric string its number,
  // anything else (absent, NaN, negative) falls back to the list.
  int count(String k) {
    if (c != null && c.containsKey(k)) {
      final raw = c[k];
      final v = raw == null
          ? 0
          : (raw is num ? raw : (raw is String ? num.tryParse(raw.trim()) : null));
      if (v != null && v.isFinite && v >= 0) return v.toInt();
    }
    final list = s[k];
    return list is List ? list.length : 0;
  }

  final albums = (many['albums'] is List ? many['albums'] as List : const [])
      .whereType<Map>()
      .toList();
  final left =
      (many['skippedAlbums'] is List ? many['skippedAlbums'] as List : const [])
          .whereType<Map>()
          .toList();
  bool hasError(Map a) => _truthy(a['error']);
  return ManyCounts(
    copied: count('copied'),
    skipped: count('skipped'),
    failed: count('failed'),
    albums: albums.where((a) => !hasError(a)).length,
    albumsFailed: albums.where(hasError).length,
    albumsLeftOut: left.length,
    albumsOwned: left.where((a) => a['why'] == 'owned').length,
    albumsAppearance: left.where((a) => a['why'] == 'appearance').length,
  );
}

/// The counts of a many-song result as the parts of a line (the caller
/// translates each and joins them): the albums an artist job walked, songs
/// copied, already yours, failed, albums whose listing failed, albums left
/// out — zeroes left out (empty when nothing happened at all: the caller
/// says why).
List<JobText> manyParts(Map<String, dynamic> many) {
  final n = manyCounts(many);
  final parts = <JobText>[];
  void add(JobPhrase p, int count) {
    if (count != 0) parts.add(JobText(p, count: count));
  }

  add(JobPhrase.albumsCount, n.albums);
  add(JobPhrase.copiedCount, n.copied);
  add(JobPhrase.ownedCount, n.skipped);
  add(JobPhrase.failedCount, n.failed);
  add(JobPhrase.albumsFailed, n.albumsFailed);
  add(JobPhrase.albumsLeftOut, n.albumsLeftOut);
  return parts;
}

// ── scopes ───────────────────────────────────────────────────────────────
// What a job acts on (the server's JOB_SCOPES): the song, its album, its
// artist's albums, or only the ones the library lacks. A row keeps one job
// per plug-in AND scope, under a slot: the plug-in's name for a song job,
// "<plugin>@<scope>" for the others.

const List<String> kJobScopes = kDiscoverJobScopes;

String jobScope(DiscoveryJob? job) => job?.scope ?? kScopeSong;

String jobSlot(String plugin, [String? scope]) =>
    scope == null || scope.isEmpty || scope == kScopeSong
        ? plugin
        : '$plugin@$scope';

/// A lookup answer (the newest job per plug-in and scope) by slot — the
/// first seen per slot, in the server's order.
Map<String, DiscoveryJob> jobsBySlot(Iterable<DiscoveryJob>? jobs) {
  final out = <String, DiscoveryJob>{};
  for (final job in jobs ?? const <DiscoveryJob>[]) {
    out.putIfAbsent(jobSlot(job.plugin, jobScope(job)), () => job);
  }
  return out;
}

/// What a job acts on beyond a song, for the Copies list's kind label.
enum JobKind { album, artist, artistMissing }

JobKind? jobKind(DiscoveryJob? job) => switch (jobScope(job)) {
      kScopeAlbum => JobKind.album,
      kScopeArtist => JobKind.artist,
      kScopeArtistMissing => JobKind.artistMissing,
      _ => null,
    };

/// A lookup answer indexed by plug-in name, for one scope (song rows by
/// default).
Map<String, DiscoveryJob> jobsByPlugin(Iterable<DiscoveryJob>? jobs,
    [String scope = kScopeSong]) {
  final out = <String, DiscoveryJob>{};
  for (final job in jobs ?? const <DiscoveryJob>[]) {
    if (out.containsKey(job.plugin)) continue;
    if (jobScope(job) == scope) out[job.plugin] = job;
  }
  return out;
}

// ── the Copies list (the webapp's downloads strip) ───────────────────────
// It holds what still wants the user: live jobs and failures. A finished
// copy is settled — it is a library song — and a cancelled job is over;
// both leave the list by themselves ("Clear finished" drops their rows on
// the server).
//
// The phone also keeps a FINISHED copy whose outcome is a failure or a
// stop (done with copied 0 and failed > 0, or stopped quota / busy / peer /
// refused): it wants Retry or Clear finished as much as a failed job does,
// and the Copies strip counts it ("1 failed" = the failed or stopped ones
// left). The webapp's trayRows keeps only state 'failed'.

/// A copy the phone carries — its Copies list, its markers, its Retry: Keep
/// a copy's own plug-in, with a scope Discover offers, started as Discover
/// starts it (no landing, no choice). `GET /plugin-jobs` answers every
/// plug-in's jobs; the others — a YouTube download, the webapp's folder copy
/// with the landing chosen there — stay the webapp's: the phone could not
/// draw them right, and its Retry (`{recommendation, scope}` to
/// federation-copy) would not start them again as they were started.
bool isDiscoverCopy(DiscoveryJob? job) {
  if (job == null || job.plugin != kCopyPlugin) return false;
  if (!kDiscoverJobScopes.contains(jobScope(job))) return false;
  final p = job.params;
  return p == null || (p['landing'] == null && p['choice'] == null);
}

int _trayRank(DiscoveryJob job) => job.state == JobState.running
    ? 0
    : (job.state == JobState.queued ? 1 : 2);

/// A job that ended badly: failed, or done but failed or stopped.
bool wantsAttention(DiscoveryJob? job) {
  if (job == null) return false;
  if (job.state == JobState.failed) return true;
  if (job.state != JobState.done || !job.view.isMany) return false;
  final kind = jobRowState(job).kind;
  return kind == JobRowKind.failed || kind == JobRowKind.stopped;
}

bool inTray(DiscoveryJob? job) => isLive(job) || wantsAttention(job);

List<DiscoveryJob> trayRows(Iterable<DiscoveryJob>? jobs) {
  final list = (jobs ?? const <DiscoveryJob>[]).toList();
  // A failure the user already retried is old news: a newer job for the same
  // plug-in and recommendation (whatever became of it) supersedes it.
  final newest = <String, int>{};
  for (final job in list) {
    final k = '${job.plugin}|${job.key}';
    final have = newest[k];
    if (have == null || job.id > have) newest[k] = job.id;
  }
  bool superseded(DiscoveryJob job) =>
      wantsAttention(job) &&
      job.key != null &&
      (newest['${job.plugin}|${job.key}'] ?? -1) > job.id;
  final rows = list.where((j) => inTray(j) && !superseded(j)).toList();
  // A stable sort: by rank, then newest first.
  final indexed = [for (var i = 0; i < rows.length; i++) (rows[i], i)];
  indexed.sort((a, b) {
    final byRank = _trayRank(a.$1) - _trayRank(b.$1);
    if (byRank != 0) return byRank;
    final byTime = (b.$1.createdAt ?? 0) - (a.$1.createdAt ?? 0);
    if (byTime != 0) return byTime;
    final byId = b.$1.id - a.$1.id;
    if (byId != 0) return byId;
    return a.$2 - b.$2;
  });
  return [for (final x in indexed) x.$1];
}

/// "Copying 2 · 1 failed": the copies running or waiting, and the failed or
/// stopped ones left. [live] tells the poller whether to keep its short
/// interval; [clearable] whether "Clear finished" has anything to drop.
class TraySummary {
  final int total;
  final int running;
  final int failed;
  const TraySummary({this.total = 0, this.running = 0, this.failed = 0});

  bool get live => running > 0;
  bool get clearable => failed > 0;

  /// The strip shows only while something is live or failed.
  bool get shown => total > 0;
}

TraySummary traySummary(Iterable<DiscoveryJob>? jobs) {
  final rows = trayRows(jobs);
  var running = 0;
  var failed = 0;
  for (final job in rows) {
    if (isLive(job)) {
      running += 1;
    } else {
      failed += 1;
    }
  }
  return TraySummary(total: rows.length, running: running, failed: failed);
}

/// A job's one-line title: "Title — Artist" for a song, "Album — Artist"
/// for an album (a compilation's album artist when the row names one —
/// the phone's departure: the webapp names the track artist), the artist's
/// name for the artist scopes.
String jobTitle(DiscoveryJob? job) {
  final rec = job?.recommendation ?? const <String, dynamic>{};
  String? s(String k) => _truthy(rec[k]) ? '${rec[k]}' : null;
  final scope = jobScope(job);
  if (scope == kScopeAlbum) {
    return [s('album'), s('albumArtist') ?? s('artist')].whereType<String>().join(' — ');
  }
  if (scope == kScopeArtist || scope == kScopeArtistMissing) {
    return s('artist') ?? '';
  }
  return [s('title'), s('artist')].whereType<String>().join(' — ');
}

/// What changed between two polls, for the toasts: only a job this client
/// SAW live and now sees finished is news (a page load is not).
List<DiscoveryJob> finishedSince(
    Iterable<DiscoveryJob>? before, Iterable<DiscoveryJob>? after) {
  final was = <int>{
    for (final job in before ?? const <DiscoveryJob>[])
      if (isLive(job)) job.id,
  };
  return [
    for (final job in after ?? const <DiscoveryJob>[])
      if (was.contains(job.id) && !isLive(job)) job,
  ];
}

/// A failed copy whose peer was re-paired since the row was drawn: asking
/// Discover again (New seeds) is the fix, not Retry — the stale row names a
/// peer id this server no longer holds.
bool jobNeedsNewSeeds(DiscoveryJob? job) =>
    job != null &&
    job.state == JobState.failed &&
    RegExp('no longer paired', caseSensitive: false).hasMatch(job.error ?? '');

/// The phone's poll beat (the webapp's: 1.5 s with a live job on an open
/// surface, 4 s otherwise; doubled per failure up to 60 s).
Duration pollDelay(Duration beat, int failures) {
  final ms = beat.inMilliseconds * math.pow(2, math.min(failures, 6));
  return Duration(milliseconds: math.min(60000, ms.round()));
}
