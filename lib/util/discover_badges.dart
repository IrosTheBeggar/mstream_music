/// What the user already did with a Discover lead — "copying…", "in your
/// collection", "failed" — from the plug-in jobs, matched by recommendation
/// key. Ported from the mStream webapp's `webapp/alpha/discovery-page.js`
/// (lookupChunks, badgeOf, nameKey, jobForAlbum, jobBadges,
/// peerAlbumBadges, anyLiveBadge; its cases in
/// `test/unit/webapp-discovery-page.test.mjs` are ported in
/// test/util/discover_badges_test.dart), plus the phone's markers: a word
/// and a glyph per row and card, the row's 4 px strip as the copy's
/// fraction, and a copying card's "copying 2 of 3".
///
/// The keys are the server's (recommendationKey): the batch lookup answers
/// them per row, so they are never computed here.
library;

import '../objects/discovery_plugins.dart';
import 'discover_jobs.dart';

/// The batch lookup's cap per call (the route's `.max(100)`).
const int kLookupBatchMax = 100;

/// The raw recommendations for `POST …/plugin-jobs/lookup/batch`, in chunks
/// the route takes (≤ 100); the answers concatenate back in row order.
List<List<Map<String, dynamic>>> lookupChunks(
    Iterable<Map<String, dynamic>?> raws) {
  final recs = raws.whereType<Map<String, dynamic>>().toList();
  return [
    for (var i = 0; i < recs.length; i += kLookupBatchMax)
      recs.sublist(i, i + kLookupBatchMax > recs.length ? recs.length : i + kLookupBatchMax),
  ];
}

/// One row's badge: the row a sheet would show for the job (jobRowState)
/// plus which job that is.
class JobBadge {
  final JobRow row;
  final String slot;
  final String plugin;
  final String scope;
  final JobKind? kind;
  final int jobId;

  /// The job the badge speaks for (for an artist job on one album: its
  /// account of that album — jobForAlbum).
  final DiscoveryJob job;

  const JobBadge({
    required this.row,
    required this.slot,
    required this.plugin,
    required this.scope,
    required this.kind,
    required this.jobId,
    required this.job,
  });

  JobRowKind get kindOfRow => row.kind;
  bool get live => row.live;
}

// Which job a row shows: a live one first (running, then queued), then a
// failure (it wants the user), then a finished one; the newest on a tie. A
// cancelled job is over — the row is back to its verbs. A folder job never
// badges a Discover row, and the slots in `skip` (another server's album and
// artist jobs) never do either.
const Map<JobState, int> _badgeRank = {
  JobState.running: 0,
  JobState.queued: 1,
  JobState.failed: 2,
  JobState.done: 3,
};

JobBadge? badgeOf(Map<String, DiscoveryJob> held, {List<String>? skip}) {
  DiscoveryJob? best;
  String? bestSlot;
  for (final e in held.entries) {
    final job = e.value;
    final r = _badgeRank[job.state];
    if (r == null) continue;
    if (!kDiscoverJobScopes.contains(jobScope(job))) continue;
    if (skip != null && skip.contains(e.key)) continue;
    final br = best == null ? 1 << 30 : _badgeRank[best.state]!;
    if (r < br || (r == br && job.id > best!.id)) {
      best = job;
      bestSlot = e.key;
    }
  }
  if (best == null) return null;
  return JobBadge(
    row: jobRowState(best, plugin: best.plugin),
    slot: bestSlot!,
    plugin: best.plugin,
    scope: jobScope(best),
    kind: jobKind(best),
    jobId: best.id,
    job: best,
  );
}

/// mStream src/db/name-key.js, mirrored: how the copy matches album names
/// (the artist walk's planArtistAlbums and owned.js fold names this way).
String nameKey(Object? raw) {
  if (raw == null) return '';
  return jsLowerCase('$raw'
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim()
      .replaceAll(RegExp('[‘’‚‛′]'), "'")
      .replaceAll(RegExp('[“”„‟″]'), '"')
      .replaceAll(RegExp('[‐‑‒–—―−]'), '-'));
}

final RegExp _cased = RegExp(r'[\p{Lu}\p{Ll}\p{Lt}]', unicode: true);
final RegExp _caseIgnorable = RegExp(
    r"[\p{Mn}\p{Me}\p{Cf}\p{Lm}\p{Sk}'.:·‘’․‧︓﹒﹕＇．：]",
    unicode: true);

/// JavaScript's `toLowerCase` where Dart's differs — the language-neutral
/// special casings: 'İ' (U+0130) becomes 'i' + U+0307, and a capital sigma
/// that ends a word becomes 'ς' (Final_Sigma; Greek album names end in it
/// all the time). Everything else is Dart's own (the same simple mappings).
String jsLowerCase(String s) {
  if (!s.contains('İ') && !s.contains('Σ')) return s.toLowerCase();
  final runes = s.runes.toList();
  bool test(RegExp re, int i) => re.hasMatch(String.fromCharCode(runes[i]));
  bool finalSigma(int i) {
    var before = false;
    for (var j = i - 1; j >= 0; j--) {
      if (test(_caseIgnorable, j)) continue;
      before = test(_cased, j);
      break;
    }
    if (!before) return false;
    for (var j = i + 1; j < runes.length; j++) {
      if (test(_caseIgnorable, j)) continue;
      return !test(_cased, j);
    }
    return true;
  }

  final out = StringBuffer();
  for (var i = 0; i < runes.length; i++) {
    final r = runes[i];
    if (r == 0x0130) {
      out.write('i̇');
    } else if (r == 0x03A3) {
      out.write(finalSigma(i) ? 'ς' : 'σ');
    } else {
      out.write(String.fromCharCode(r).toLowerCase());
    }
  }
  return out.toString();
}

List _arr(Object? v) => v is List ? v : const [];

/// "Done" is not "kept", album by album. An artist job's key sits on every
/// row and card of the artist on that server, but its walk copies only the
/// artist's own albums (result.albums) and leaves out the ones they only
/// appear on and — only-missing — the ones the library had
/// (result.skippedAlbums). So a FINISHED artist or artist-missing job speaks
/// for one [album] only as that album came out of the walk:
///   walked, no error            that album's own account
///   its listing failed          nothing — unless the run stopped there:
///                               stopped
///   left out as 'owned'         already yours
///   left out as 'appearance',
///   never walked, no album      nothing (null)
/// A live or failed artist job, and every other scope, is the job itself.
DiscoveryJob? jobForAlbum(DiscoveryJob job, String? album) {
  final scope = jobScope(job);
  if ((scope != kScopeArtist && scope != kScopeArtistMissing) ||
      job.state != JobState.done) {
    return job;
  }
  final res = job.result ?? const <String, dynamic>{};
  final walked = _arr(res['albums']).whereType<Map>().toList();
  final left = _arr(res['skippedAlbums']).whereType<Map>().toList();
  final want = nameKey(album);
  if (want.isEmpty ||
      (res['albums'] is! List && res['skippedAlbums'] is! List)) {
    return null;
  }
  final at = walked.indexWhere((a) => nameKey(a['name']) == want);
  DiscoveryJob view(Map songs, Object? stopped, [Map<String, dynamic>? extra]) {
    int n(String k) => _arr(songs[k]).length;
    final t = songs['total'];
    final total = t is num && t.isFinite
        ? t.toInt()
        : n('copied') + n('skipped') + n('failed');
    final stop = stopped is String && stopped.isNotEmpty ? stopped : null;
    return job.withResult(Map.unmodifiable(<String, dynamic>{
      'scope': res['scope'] ?? scope,
      'songs': {
        'total': total,
        'copied': _arr(songs['copied']),
        'skipped': _arr(songs['skipped']),
        'failed': _arr(songs['failed']),
      },
      'counts': {
        'total': total,
        'copied': n('copied'),
        'skipped': n('skipped'),
        'failed': n('failed'),
      },
      'stopped': stop,
      'peer': res['peer'],
      ...?extra,
    }));
  }

  if (at != -1) {
    final one = walked[at];
    final last = at == walked.length - 1;
    final err = one['error'];
    if (err != null && err != '' && err != false) {
      final stopped = res['stopped'];
      return stopped is String && stopped.isNotEmpty && last
          ? view(const {}, stopped)
          : null;
    }
    // No per-album account: the walk's.
    if (one['songs'] is! Map) return job;
    return view(one['songs'] as Map, one['stopped']);
  }
  Map? skipped;
  for (final a in left) {
    if (nameKey(a['name']) == want) {
      skipped = a;
      break;
    }
  }
  if (skipped != null && skipped['why'] == 'owned') {
    return view(const {}, null, {
      'skippedAlbums': [skipped]
    });
  }
  return null;
}

/// [held] (slot → job) as it speaks for one album (jobForAlbum); the slots
/// that say nothing about it are left out.
Map<String, DiscoveryJob> heldForAlbum(
    Map<String, DiscoveryJob> held, String? album) {
  final out = <String, DiscoveryJob>{};
  for (final e in held.entries) {
    final job = jobForAlbum(e.value, album);
    if (job != null) out[e.key] = job;
  }
  return out;
}

/// Album and artist job keys carry no server (the same album on two
/// connected servers is one key, and a live job dedupes across them), so the
/// lookup can hand a connected server's row another server's album or artist
/// copy. True when [job] is an album / artist / artist-missing job whose
/// recommendation names a server other than [peerId]. A song job is the
/// recording wherever it came from; a job that names no server, or a row
/// with none, is never another's.
bool otherPeerJob(DiscoveryJob? job, int? peerId) {
  if (peerId == null || job == null || jobScope(job) == kScopeSong) {
    return false;
  }
  final id = job.peerId;
  if (id == null) return false;
  return id != peerId;
}

/// One row as the badges see it: its raw recommendation (identity matters:
/// a card finds its rows by it), its server and album, and what the
/// lookups said — the keys, its jobs by slot, the slots holding another
/// server's album or artist job ([otherPeer], kept in [jobs], never the
/// badge) and the badge.
class BadgeRow {
  final Map<String, dynamic> raw;
  final int? peerId;
  final String? album;
  final String? recKey;
  final List<String> recKeys;
  final Map<String, DiscoveryJob> jobs;
  final List<String> otherPeer;
  final JobBadge? badge;

  const BadgeRow({
    required this.raw,
    this.peerId,
    this.album,
    this.recKey,
    this.recKeys = const [],
    this.jobs = const {},
    this.otherPeer = const [],
    this.badge,
  });

  /// A row before any lookup: no keys, no jobs.
  factory BadgeRow.of(Map<String, dynamic> raw, {int? peerId}) {
    final album = raw['album'];
    final peer = raw['peer'];
    final id = peer is Map ? peer['id'] : null;
    return BadgeRow(
      raw: raw,
      peerId: peerId ?? (id is int ? id : (id is num ? id.toInt() : null)),
      album: album is String ? album : null,
    );
  }

  /// A row's album tag: its raw recommendation's, else the row's own.
  String? get rowAlbum {
    final a = raw['album'];
    return a is String ? a : album;
  }

  /// The job a sheet shows for [scope] on this row (this server's or
  /// another's — [isOtherPeer] says which).
  DiscoveryJob? jobFor(String plugin, String scope) => jobs[jobSlot(plugin, scope)];
  bool isOtherPeer(String plugin, String scope) =>
      otherPeer.contains(jobSlot(plugin, scope));
}

/// Merge jobs onto rows → new rows with keys, jobs (by slot), otherPeer and
/// badge. [results] — the batch lookup's answers, aligned with [rows]
/// (concatenated across lookupChunks; a null entry is a row whose chunk
/// failed) — set each row's keys and its jobs from scratch. [jobs] — a flat
/// job list (the poll, or a job just started) — merges onto rows that know
/// their keys, a newer job (higher id) replacing the one held.
List<BadgeRow> jobBadges(List<BadgeRow> rows,
    {List<JobLookup?>? results, List<DiscoveryJob>? jobs}) {
  return [
    for (var i = 0; i < rows.length; i++)
      _badgeOne(rows[i],
          results != null && i < results.length ? results[i] : null, jobs),
  ];
}

BadgeRow _badgeOne(BadgeRow row, JobLookup? found, List<DiscoveryJob>? jobs) {
  var held = Map<String, DiscoveryJob>.of(row.jobs);
  var recKey = row.recKey;
  var recKeys = List<String>.of(row.recKeys);
  if (found != null) {
    recKey = found.key;
    recKeys = found.allKeys;
    held = Map.of(jobsBySlot(found.jobs));
  }
  if (jobs != null && recKeys.isNotEmpty) {
    final mine = jobsBySlot(jobs.where((j) => recKeys.contains(j.key)));
    for (final e in mine.entries) {
      final have = held[e.key];
      if (have == null || e.value.id >= have.id) held[e.key] = e.value;
    }
  }
  final otherPeer = [
    for (final e in held.entries)
      if (otherPeerJob(e.value, row.peerId)) e.key,
  ];
  return BadgeRow(
    raw: row.raw,
    peerId: row.peerId,
    album: row.album,
    recKey: recKey,
    recKeys: recKeys,
    jobs: held,
    otherPeer: otherPeer,
    // An artist copy speaks for the row as the walk did for its album.
    badge: badgeOf(heldForAlbum(held, row.rowAlbum), skip: otherPeer),
  );
}

/// A connected server's album card as the badges see it: its server, its
/// album, and its rows' raw recommendations, best first.
class BadgeCard {
  final int? peerId;
  final String? album;
  final List<Map<String, dynamic>> raws;
  const BadgeCard({this.peerId, this.album, this.raws = const []});
}

/// A connected server's album cards' badges, from their rows' jobs (the rows
/// jobBadges answered, matched to a card by raw row): the album and artist
/// copies of THAT server — an album job sits on every row of the card, an
/// artist job on every row by the artist, and a finished one speaks for the
/// card's album only as its walk did. Never a song job (one song of the
/// album is not the album), never another server's copy of the same album.
/// Ranked as a row's badge is. → aligned with [cards].
List<JobBadge?> peerAlbumBadges(List<BadgeCard?>? cards, List<BadgeRow> rows) {
  final byRaw = Map<Map<String, dynamic>, BadgeRow>.identity();
  for (final r in rows) {
    byRaw.putIfAbsent(r.raw, () => r);
  }
  return [
    for (final card in cards ?? const <BadgeCard?>[])
      if (card == null) null else _cardBadge(card, byRaw),
  ];
}

JobBadge? _cardBadge(
    BadgeCard card, Map<Map<String, dynamic>, BadgeRow> byRaw) {
  final held = <String, DiscoveryJob>{};
  for (final raw in card.raws) {
    final row = byRaw[raw];
    if (row == null) continue;
    for (final e in row.jobs.entries) {
      final job = e.value;
      if (jobScope(job) == kScopeSong || otherPeerJob(job, card.peerId)) {
        continue;
      }
      final have = held[e.key];
      if (have == null || job.id > have.id) held[e.key] = job;
    }
  }
  return badgeOf(heldForAlbum(held, card.album));
}

/// Is any badge still moving (the page keeps listening to the poll)?
bool anyLiveBadge(Iterable<BadgeRow?> rows) =>
    rows.any((r) => r?.badge?.live == true);

// ── the Keep card's narrower choices ─────────────────────────────────────
// The Keep card shows, for each choice (This song | Album | Artist), the
// row's job of THAT scope. A wider copy that finished speaks for a
// narrower choice as well — the way the markers read it — when it is this
// server's (never another connected server's) and newer than the choice's
// own job:
//   Album      the newest finished artist / artist-missing job, as its walk
//              came out for this album (jobForAlbum): walked → that album's
//              own account, left out as 'owned' → already yours,
//              'appearance' or never walked → nothing
//   This song  a finished album job, or a finished artist job's account of
//              the row's album, whose song lists name this song's file on
//              the connected server (`from`): copied → in your collection,
//              skipped 'owned' → already yours, skipped 'exists' → skipped;
//              failed or not listed → nothing
// A live job of the choice's own always wins, and so does a finished one
// newer than the wider copy; a live wider job stays on its own choice.

/// [a] ended after [b]: their finish times, else their update times (ms),
/// else the newer id.
bool jobNewer(DiscoveryJob a, DiscoveryJob b) {
  final fa = a.finishedAt, fb = b.finishedAt;
  if (fa != null && fb != null && fa != fb) return fa > fb;
  final ua = a.updatedAt, ub = b.updatedAt;
  if (ua != null && ub != null && ua != ub) return ua > ub;
  return a.id > b.id;
}

String _peerPath(Object? p) =>
    p is String ? p.trim().replaceFirst(RegExp(r'^/+'), '') : '';

/// A many-song account ([view]: an album job, or an artist job's account of
/// one album) as it speaks for the one song whose file on the connected
/// server is [filepath] — its entry in the song lists, made the shape a song
/// copy answers. Null unless an entry names that file.
DiscoveryJob? _songView(DiscoveryJob view, String filepath) {
  final res = view.result ?? const <String, dynamic>{};
  final songs = res['songs'];
  final want = _peerPath(filepath);
  if (songs is! Map || want.isEmpty) return null;
  Map? entry(String list) {
    for (final e in _arr(songs[list])) {
      if (e is Map && _peerPath(e['from']) == want) return e;
    }
    return null;
  }

  final copied = entry('copied');
  if (copied != null) {
    final at = copied['filepath'];
    if (at is! String || at.trim().isEmpty) return null;
    return view.withResult(Map.unmodifiable(<String, dynamic>{
      'copied': {
        for (final e in copied.entries)
          if (e.key != 'from') '${e.key}': e.value,
      },
      'peer': res['peer'],
    }));
  }
  final skipped = entry('skipped');
  if (skipped == null) return null;
  final at = skipped['at'] is String && (skipped['at'] as String).trim().isNotEmpty
      ? skipped['at'] as String
      : null;
  return switch (skipped['why']) {
    'owned' => view.withResult(Map.unmodifiable(<String, dynamic>{
        'skipped': 'owned',
        if (at != null) 'existing': {'filepath': at},
        'peer': res['peer'],
      })),
    'exists' => view.withResult(Map.unmodifiable(<String, dynamic>{
        'skipped': 'exists',
        'filepath': ?at,
        'peer': res['peer'],
      })),
    _ => null,
  };
}

/// The newest finished copy wider than [scope] (album or song) among
/// [held], from server [peerId], as it speaks for this choice — the album
/// [album], the song whose file on that server is [filepath] — or null when
/// none does.
DiscoveryJob? widerChoiceView(
  String scope,
  Iterable<DiscoveryJob> held, {
  int? peerId,
  String? album,
  String? filepath,
}) {
  if (scope != kScopeAlbum && scope != kScopeSong) return null;
  DiscoveryJob? best;
  for (final job in held) {
    if (job.plugin != kCopyPlugin || job.state != JobState.done) continue;
    if (otherPeerJob(job, peerId)) continue;
    final s = jobScope(job);
    final artist = s == kScopeArtist || s == kScopeArtistMissing;
    if (!artist && !(scope == kScopeSong && s == kScopeAlbum)) continue;
    final forAlbum = artist ? jobForAlbum(job, album) : job;
    if (forAlbum == null) continue;
    final DiscoveryJob? view;
    if (scope == kScopeAlbum) {
      view = forAlbum;
    } else {
      view = filepath == null ? null : _songView(forAlbum, filepath);
    }
    if (view == null) continue;
    if (best == null || jobNewer(view, best)) best = view;
  }
  return best;
}

/// What one Keep card choice shows: [job] (another server's when
/// [fromOtherPeer]), and whether it is a wider copy's account ([wider]:
/// its Retry starts the choice's own scope, not the wider copy again).
class KeepChoiceJob {
  final DiscoveryJob job;
  final bool fromOtherPeer;
  final bool wider;
  const KeepChoiceJob(this.job, {this.fromOtherPeer = false, this.wider = false});
}

/// The job the Keep card's [scope] choice shows: [own] — the row's job of
/// that scope ([ownFromOtherPeer]: another server's copy of the same album
/// or artist, shown only while it runs) — or, for the Album and This song
/// choices, the account a finished wider copy among [held] gives
/// ([widerChoiceView]) when [own] is not live and not newer. Null: the
/// choice's own pill.
KeepChoiceJob? keepChoiceJob(
  String scope, {
  DiscoveryJob? own,
  bool ownFromOtherPeer = false,
  Iterable<DiscoveryJob> held = const [],
  int? peerId,
  String? album,
  String? filepath,
}) {
  if (own != null && own.live) {
    return KeepChoiceJob(own, fromOtherPeer: ownFromOtherPeer);
  }
  // Another server's copy that ended says nothing here.
  final mine = own == null || ownFromOtherPeer ? null : own;
  final wider = widerChoiceView(scope, held,
      peerId: peerId, album: album, filepath: filepath);
  if (wider != null && (mine == null || jobNewer(wider, mine))) {
    return KeepChoiceJob(wider, wider: true);
  }
  return mine == null ? null : KeepChoiceJob(mine);
}

// ── the phone's markers ──────────────────────────────────────────────────
// Words and glyphs only on the page (no percentages): a song row's glyph +
// word lead its subtitle and its 4 px strip fills with the copy's fraction;
// an album card carries a badge inside its cover, "copying 2 of 3" while it
// copies (songs done of total). Which marker a job shows (the canvas's
// table — done is not kept):
//   queued                                        waiting
//   running                                       copying…
//   running, cancel asked                         stopping…
//   song copied, or album/artist copied > 0       in your collection
//     and not stopped
//   copied 0 and skipped > 0, or nothing to copy  already yours
//   done but stopped (limit, busy, peer gone)     stopped
//   done but stopped, refused copies              refused
//   failed, or done with copied 0 and failed > 0  failed
//   skipped, a file is already at the path        skipped
//   cancelled, or nothing of theirs to copy       no marker
//   another server's album or artist job          no marker

enum CopyMarkerKind {
  waiting,
  copying,
  stopping,
  inCollection,
  alreadyYours,
  stopped,
  refused,
  failed,
  skipped,
}

class CopyMarker {
  final CopyMarkerKind kind;

  /// The copy's fraction for the row's strip (0..1) while it copies or
  /// stops; null while the server cannot say (a sliding segment).
  final double? fraction;

  /// A copying card's "copying [done] of [total]" (songs accounted for of
  /// the album's); null when the server's line does not say.
  final int? done;
  final int? total;

  const CopyMarker(this.kind, {this.fraction, this.done, this.total});

  bool get live =>
      kind == CopyMarkerKind.waiting ||
      kind == CopyMarkerKind.copying ||
      kind == CopyMarkerKind.stopping;

  /// The row's strip fills only while the copy moves.
  bool get showsStrip =>
      kind == CopyMarkerKind.copying || kind == CopyMarkerKind.stopping;
}

/// The marker for a badge (null = no marker). [album] is the card's or the
/// row's album: an artist job's running line names the album it is on, and
/// a card counts only its own.
CopyMarker? copyMarkerOf(JobBadge? badge, {String? album}) {
  if (badge == null) return null;
  final row = badge.row;
  final job = badge.job;
  switch (row.kind) {
    case JobRowKind.queued:
      return const CopyMarker(CopyMarkerKind.waiting);
    case JobRowKind.running:
      final counts = copyingCounts(job, album: album);
      return CopyMarker(
        job.cancelRequested ? CopyMarkerKind.stopping : CopyMarkerKind.copying,
        fraction: job.progress,
        done: counts?.$1,
        total: counts?.$2,
      );
    case JobRowKind.copied:
    case JobRowKind.copiedMany:
    case JobRowKind.downloaded:
      return const CopyMarker(CopyMarkerKind.inCollection);
    case JobRowKind.owned:
      return const CopyMarker(CopyMarkerKind.alreadyYours);
    case JobRowKind.nothing:
      // "You have it all" reads as already yours; an artist only ever
      // featured on that server ("nothing of theirs to copy") shows nothing.
      return row.leadPhrase == JobPhrase.onlyAppearances
          ? null
          : const CopyMarker(CopyMarkerKind.alreadyYours);
    case JobRowKind.stopped:
      return CopyMarker(row.leadPhrase == JobPhrase.stoppedRefused
          ? CopyMarkerKind.refused
          : CopyMarkerKind.stopped);
    case JobRowKind.failed:
      return const CopyMarker(CopyMarkerKind.failed);
    case JobRowKind.exists:
      return const CopyMarker(CopyMarkerKind.skipped);
    case JobRowKind.idle:
    case JobRowKind.cancelled:
    case JobRowKind.done:
      return null;
  }
}

final RegExp _songsOf = RegExp(r'(\d+) of (\d+) songs');
final RegExp _albumHead = RegExp(r'^album \d+ of \d+ · (.+?) · \d+ of \d+ songs');

/// A running copy's songs done of total, read off the server's progress line
/// (federation-copy's copySongs: "1 of 3 songs · 7.4 MB · …"; an artist
/// walk's "album 2 of 5 · Night Ferry · 3 of 11 songs · …"). With [album],
/// an artist walk counts only while it is on that album. Null when the line
/// says no such thing (still asking the peer, an artist walk's summary).
(int, int)? copyingCounts(DiscoveryJob job, {String? album}) {
  if (job.state != JobState.running) return null;
  final text = job.statusText ?? '';
  final matches = _songsOf.allMatches(text).toList();
  if (matches.isEmpty) return null;
  final head = _albumHead.firstMatch(text);
  if (head != null && album != null && nameKey(head.group(1)) != nameKey(album)) {
    return null;
  }
  final m = matches.first;
  final done = int.tryParse(m.group(1)!);
  final total = int.tryParse(m.group(2)!);
  if (done == null || total == null || total <= 0 || done > total) return null;
  return (done, total);
}

// ── a connected server's pages, while browsing it ────────────────────────
// What a browse page marks (the phone spec's "which job a mark shows"):
// each mark its own scope's newest job of the user's server, read through
// the same rules as Discover's — album and artist jobs only when their
// recommendation names THIS server ([otherPeerJob]), a song job from any
// server (it is the recording), a folder job by its key (which names the
// server). Discover's own markers ([badgeOf], its rows and cards) are left
// as they were: they never show a folder copy.

JobBadge _badgeFor(DiscoveryJob job) => JobBadge(
      row: jobRowState(job, plugin: job.plugin),
      slot: jobSlot(job.plugin, jobScope(job)),
      plugin: job.plugin,
      scope: jobScope(job),
      kind: jobKind(job),
      jobId: job.id,
      job: job,
    );

/// The marker [job] speaks for, whatever its scope (a folder copy's too):
/// null for none, a cancelled job, nothing of theirs to copy.
CopyMarker? markerOfJob(DiscoveryJob? job, {String? album}) =>
    job == null ? null : copyMarkerOf(_badgeFor(job), album: album);

/// The job a page pill of [scope] shows among [held] (a page lookup's jobs
/// by slot): the artist pill reads both artist scopes, a live one first,
/// else the newer. This server's live job first; another server's only
/// while it runs ([KeepChoiceJob.fromOtherPeer]: "Copying from {peer}");
/// else this server's last one (a cancelled one is the idle pill). Null:
/// the idle pill.
KeepChoiceJob? pagePillJob(Map<String, DiscoveryJob> held, String scope,
    {int? peerId}) {
  final artist = scope == kScopeArtist || scope == kScopeArtistMissing;
  bool ours(DiscoveryJob j) => artist
      ? (jobScope(j) == kScopeArtist || jobScope(j) == kScopeArtistMissing)
      : jobScope(j) == scope;
  bool before(DiscoveryJob a, DiscoveryJob b) =>
      a.live != b.live ? a.live : a.id > b.id;
  DiscoveryJob? mine;
  DiscoveryJob? other;
  for (final job in held.values) {
    if (!isKeepCopy(job) || !ours(job)) continue;
    if (otherPeerJob(job, peerId)) {
      if (job.live && (other == null || job.id > other.id)) other = job;
      continue;
    }
    if (mine == null || before(job, mine)) mine = job;
  }
  if (mine != null && mine.live) return KeepChoiceJob(mine);
  if (other != null) return KeepChoiceJob(other, fromOtherPeer: true);
  return mine == null ? null : KeepChoiceJob(mine);
}

/// A browse page's album card: the copies of its [album] on THIS server —
/// its album jobs, and a FINISHED artist job as its walk saw that album
/// ([jobForAlbum]) — ranked as a row's badge is. Never a live artist job
/// (a walk names only the album it is on in words, so no card guesses
/// while it runs), a song job, a folder job, or another server's copy.
JobBadge? pageCardBadge(Map<String, DiscoveryJob> held,
    {String? album, int? peerId}) {
  final mine = <String, DiscoveryJob>{};
  for (final e in held.entries) {
    final job = e.value;
    if (!isKeepCopy(job) || otherPeerJob(job, peerId)) continue;
    final s = jobScope(job);
    final artist = s == kScopeArtist || s == kScopeArtistMissing;
    if (s == kScopeAlbum || (artist && job.state == JobState.done)) {
      mine[e.key] = job;
    }
  }
  return badgeOf(heldForAlbum(mine, album));
}

/// [pageCardBadge] as its marker.
CopyMarker? pageCardMarker(Map<String, DiscoveryJob> held,
        {String? album, int? peerId}) =>
    copyMarkerOf(pageCardBadge(held, album: album, peerId: peerId),
        album: album);

/// What a finished many-song copy ([view]: an album job) says of the one
/// song whose file on the connected server is [filepath] — its entry in the
/// song lists: copied → in your collection, skipped as owned → already
/// yours, skipped as a file already there → skipped, failed → failed. Null
/// when no list names it.
CopyMarker? _listedMark(DiscoveryJob view, String filepath) {
  final songs = view.result?['songs'];
  final want = _peerPath(filepath);
  if (songs is! Map || want.isEmpty) return null;
  bool named(String list) => _arr(songs[list])
      .any((e) => e is Map && _peerPath(e['from']) == want);
  if (named('copied')) return const CopyMarker(CopyMarkerKind.inCollection);
  if (named('failed')) return const CopyMarker(CopyMarkerKind.failed);
  for (final e in _arr(songs['skipped'])) {
    if (e is! Map || _peerPath(e['from']) != want) continue;
    return e['why'] == 'exists'
        ? const CopyMarker(CopyMarkerKind.skipped)
        : const CopyMarker(CopyMarkerKind.alreadyYours);
  }
  return null;
}

/// An album page's song row ([song]: the row's own job, from any server;
/// [album]: the page's album job of THIS server; [filepath] the row's file
/// on the connected server): nothing while the album copy runs (its rows
/// cannot say which song it is on), else the newer of the song's own marker
/// and what the finished album copy says of this song — a song in a job's
/// failed list never reads "in your collection". A live song job always
/// wins.
CopyMarker? pageSongMarker(
    {DiscoveryJob? song, DiscoveryJob? album, String? filepath}) {
  if (album != null && album.live) return null;
  final own = markerOfJob(song);
  if (song != null && song.live) return own;
  final listed = album == null ||
          album.state != JobState.done ||
          filepath == null
      ? null
      : _listedMark(album, filepath);
  if (own == null) return listed;
  if (listed == null) return own;
  return jobNewer(album!, song!) ? listed : own;
}

/// A folder row's marker: its folder copies only (a folder kept as an album
/// or an artist shows nothing). [held] is the folder's lookup jobs by slot.
CopyMarker? pageFolderMarker(Map<String, DiscoveryJob> held) {
  final job = held[jobSlot(kCopyPlugin, kScopeFolder)];
  return isKeepCopy(job) ? markerOfJob(job) : null;
}
