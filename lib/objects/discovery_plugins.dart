/// Models for the server's discovery plug-in API (mStream
/// `src/api/discovery-plugins.js`, `discovery-plugin-jobs.js`,
/// `discovery-collection.js`; docs/openapi.yaml): the plug-in listing, a
/// plug-in job, the batch lookup's answer, the collection destination and
/// the links plug-in's answer.
///
/// Every route is the user's OWN server's (the parent of a connected
/// server's virtual Server), never a peer's: the plug-ins act on a
/// recommendation the caller already holds — a Discover row, forwarded
/// unchanged.
///
/// Every parser is defensive about wire shapes, as discovery.dart's are: a
/// malformed entry is dropped, a malformed field is read as absent, nothing
/// throws.
library;

/// The copy plug-in: a connected server's song, album or artist into a
/// library on the user's own server.
const String kCopyPlugin = 'federation-copy';

/// The "Open elsewhere" plug-in.
const String kLinksPlugin = 'links';

/// A job's scope (the server's JOB_SCOPES). A song job carries no scope in
/// its params. Discover never offers [kScopeFolder].
const String kScopeSong = 'song';
const String kScopeAlbum = 'album';
const String kScopeArtist = 'artist';
const String kScopeArtistMissing = 'artist-missing';
const String kScopeFolder = 'folder';

/// The scopes a Discover row can carry a job for (folder never: a row's
/// filepath names a file, and the folder key a row's lookup answers is that
/// file's own).
const List<String> kDiscoverJobScopes = [
  kScopeSong,
  kScopeAlbum,
  kScopeArtist,
  kScopeArtistMissing,
];

/// The scopes the phone keeps a copy of: Discover's, and a connected
/// server's folder — offered only from that server's file explorer
/// (util/discover_copy_gate.dart KeepEntry.explorer).
const List<String> kKeepJobScopes = [...kDiscoverJobScopes, kScopeFolder];

/// The server's default collection layout (src/discovery-plugins/
/// destination.js DEFAULT_LAYOUT): by the album's credit, so a compilation
/// copied whole lands in one folder (`Various Artists/<album>`); ALBUMARTIST
/// falls back to the song's artist, so an ordinary album lands as it did
/// under {{ARTIST}}/{{ALBUM}}.
const String kDefaultCopyLayout = '{{ALBUMARTIST}}/{{ALBUM}}';

/// One enabled plug-in, as `GET /api/v1/discovery/plugins` lists it. A
/// plug-in whose probe failed is simply not listed to a user; [available]
/// is read anyway (an admin's listing carries false).
class DiscoveryPlugin {
  final String name;
  final String title;
  final String description;

  /// links · preview · play · acquire · handoff · lookup
  final List<String> capabilities;

  /// The job scopes a runnable plug-in acts on: `song` always, plus album /
  /// artist / artist-missing / folder where it copies more at once.
  final List<String> scopes;

  /// The per-user setting keys it keeps.
  final List<String> settings;
  final bool available;

  const DiscoveryPlugin({
    required this.name,
    this.title = '',
    this.description = '',
    this.capabilities = const [],
    this.scopes = const [],
    this.settings = const [],
    this.available = true,
  });

  static DiscoveryPlugin? fromServerMap(dynamic m) {
    if (m is! Map) return null;
    final name = _str(m['name'], max: 64);
    if (name == null) return null;
    return DiscoveryPlugin(
      name: name,
      title: _str(m['title']) ?? name,
      description: _str(m['description'], max: 4096) ?? '',
      capabilities: _strings(m['capabilities']),
      scopes: _strings(m['scopes']),
      settings: _strings(m['settings']),
      available: m['available'] is bool ? m['available'] as bool : true,
    );
  }

  bool hasCapability(String c) => capabilities.contains(c);
  bool hasScope(String s) => scopes.contains(s);
}

/// `GET /api/v1/discovery/plugins`: the enabled plug-ins, whether THIS
/// caller may start jobs (`jobs.allowed`, the acquisition gate), and the
/// most songs one folder copy takes here (`jobs.maxFolderSongs`).
class PluginListing {
  final List<DiscoveryPlugin> plugins;
  final bool jobsAllowed;

  /// The admin's discoveryJobs.maxFolderSongs, a whole number ≥ 1 (mStream
  /// since 2026-10-23); null when the listing does not say — an older
  /// server: no cap is known, and a folder job past it fails in the server's
  /// own words (the webapp's maxFolderSongs).
  final int? maxFolderSongs;

  const PluginListing(this.plugins,
      {this.jobsAllowed = false, this.maxFolderSongs});

  factory PluginListing.fromServerMap(Map m) {
    final jobs = m['jobs'];
    return PluginListing(
      _listOf(m['plugins'], DiscoveryPlugin.fromServerMap),
      jobsAllowed: jobs is Map && jobs['allowed'] == true,
      maxFolderSongs: jobs is Map ? _cap(jobs['maxFolderSongs']) : null,
    );
  }

  /// JS `Math.floor(Number(v))` when that is a finite number ≥ 1.
  static int? _cap(dynamic v) {
    final n = v is num
        ? v
        : (v is String ? num.tryParse(v.trim()) : null);
    if (n == null || !n.isFinite || n < 1) return null;
    return n.floor();
  }

  /// The listed plug-in [name] that can run, or null.
  DiscoveryPlugin? plugin(String name) {
    for (final p in plugins) {
      if (p.name == name && p.available) return p;
    }
    return null;
  }

  DiscoveryPlugin? get copy => plugin(kCopyPlugin);
  DiscoveryPlugin? get links => plugin(kLinksPlugin);
}

/// A job's state on the wire. Anything else parses to null (and reads as no
/// job at all — the webapp's jobRowState does the same).
enum JobState {
  queued,
  running,
  done,
  failed,
  cancelled;

  static JobState? parse(dynamic v) =>
      v is String ? JobState.values.asNameMap()[v] : null;

  bool get live => this == queued || this == running;
}

/// One thing a plug-in was asked to do with a recommendation
/// (`DiscoveryPluginJob` in docs/openapi.yaml). Timestamps are ms epochs.
///
/// [recommendation] is the normalised recommendation the job was started
/// with — what Retry sends again, and where a connected server's job names
/// its server (`recommendation.peer.id`). [result] stays the wire map: its
/// shape is the plug-in's (a song copy's `copied` / `skipped`, an album or
/// artist copy's `songs` / `counts` / `albums` / `skippedAlbums` /
/// `stopped`); read it through [JobResultView] or the pure helpers in
/// util/discover_jobs.dart.
class DiscoveryJob {
  final int id;
  final String plugin;
  final int? userId;
  final String? key;
  final Map<String, dynamic> recommendation;

  /// `params` as sent: `scope` (absent for a song job), `choice`, `landing`
  /// — and `destination`, the place the server pinned the job to at start.
  final Map<String, dynamic>? params;
  final JobState? state;

  /// 0..1, or null while the plug-in cannot say.
  final double? progress;
  final String? statusText;
  final Map<String, dynamic>? result;
  final String? error;
  final int attempts;
  final bool cancelRequested;
  final int? createdAt;
  final int? updatedAt;
  final int? startedAt;
  final int? finishedAt;

  const DiscoveryJob({
    required this.id,
    required this.plugin,
    this.userId,
    this.key,
    this.recommendation = const {},
    this.params,
    this.state,
    this.progress,
    this.statusText,
    this.result,
    this.error,
    this.attempts = 0,
    this.cancelRequested = false,
    this.createdAt,
    this.updatedAt,
    this.startedAt,
    this.finishedAt,
  });

  static DiscoveryJob? fromServerMap(dynamic m) {
    if (m is! Map) return null;
    final id = _int(m['id']);
    final plugin = _str(m['plugin'], max: 64);
    if (id == null || plugin == null) return null;
    final progress = m['progress'];
    return DiscoveryJob(
      id: id,
      plugin: plugin,
      userId: _int(m['userId']),
      key: _str(m['key'], max: 1024),
      recommendation: _map(m['recommendation']) ?? const {},
      params: _map(m['params']),
      state: JobState.parse(m['state']),
      progress: progress is num && progress.isFinite
          ? progress.toDouble().clamp(0.0, 1.0)
          : null,
      statusText: _str(m['statusText'], max: 4096),
      result: _map(m['result']),
      error: _str(m['error'], max: 4096),
      attempts: _int(m['attempts']) ?? 0,
      cancelRequested: m['cancelRequested'] == true,
      createdAt: _int(m['createdAt']),
      updatedAt: _int(m['updatedAt']),
      startedAt: _int(m['startedAt']),
      finishedAt: _int(m['finishedAt']),
    );
  }

  /// The job's scope: `params.scope`, else `song`.
  String get scope {
    final s = params?['scope'];
    return s is String && s.isNotEmpty ? s : kScopeSong;
  }

  /// A folder job's landing as it was started (`params.landing`, the
  /// route's validateLanding): `{vpath, path}`, `{tags: true}`, or null — as
  /// on the connected server. What Retry and Add again send again.
  Map<String, dynamic>? get landing {
    final l = params?['landing'];
    return l is Map ? _map(l) : null;
  }

  bool get live => state?.live == true;

  /// Where the copy lands: the destination pinned on it at start
  /// (`params.destination`, mStream since 2026-10-21), else the one its
  /// result names (a job from before the pin). Null when it names neither,
  /// or was pinned to nowhere.
  CollectionDestination? get destination => pinnedNowhere
      ? null
      : CollectionDestination.fromServerMap(params?['destination']) ??
          CollectionDestination.fromServerMap(result?['destination']);

  /// Pinned to nowhere at start (`params.destination` null): no library
  /// took the account's files then.
  bool get pinnedNowhere {
    final p = params;
    return p != null && p.containsKey('destination') && p['destination'] == null;
  }

  /// The place the copy ran with, as a start again from a list that shows
  /// no place sends it: its pin — nowhere included — else its result's;
  /// null when it names neither (a copy from before the pin that never
  /// landed).
  ShownPlace? get ranWith {
    if (pinnedNowhere) return const ShownPlace(null);
    final d = destination;
    return d == null ? null : ShownPlace(d);
  }

  /// The connected server the recommendation came from
  /// (`recommendation.peer.id`), or null for a job that names none.
  int? get peerId {
    final peer = recommendation['peer'];
    return peer is Map ? _int(peer['id']) : null;
  }

  String? get peerName {
    final peer = recommendation['peer'];
    return peer is Map ? _str(peer['name']) : null;
  }

  JobResultView get view => JobResultView(result);

  /// The same job with another [result] (an artist job's account of one
  /// album — util/discover_jobs.dart jobForAlbum).
  DiscoveryJob withResult(Map<String, dynamic>? result) => DiscoveryJob(
        id: id,
        plugin: plugin,
        userId: userId,
        key: key,
        recommendation: recommendation,
        params: params,
        state: state,
        progress: progress,
        statusText: statusText,
        result: result,
        error: error,
        attempts: attempts,
        cancelRequested: cancelRequested,
        createdAt: createdAt,
        updatedAt: updatedAt,
        startedAt: startedAt,
        finishedAt: finishedAt,
      );

  /// What the poll compares: a change in any of these is news.
  String get signature =>
      '$id|${state?.name}|$progress|$statusText|$cancelRequested|$updatedAt|$finishedAt';
}

/// The songs of a many-song result, as whole numbers.
class JobCounts {
  final int total;
  final int copied;
  final int skipped;
  final int failed;
  const JobCounts(
      {this.total = 0, this.copied = 0, this.skipped = 0, this.failed = 0});

  /// Songs accounted for so far.
  int get done => copied + skipped + failed;
}

/// One album an artist job walked: its own songs' account, or the error its
/// listing met.
class WalkedAlbum {
  final String name;
  final int? year;
  final String? error;
  final String? stopped;
  final Map<String, dynamic> songs;
  const WalkedAlbum(this.name,
      {this.year, this.error, this.stopped, this.songs = const {}});

  static WalkedAlbum? fromServerMap(dynamic m) {
    if (m is! Map) return null;
    return WalkedAlbum(
      m['name'] is String ? m['name'] as String : '',
      year: _int(m['year']),
      error: _str(m['error'], max: 4096),
      stopped: _str(m['stopped'], max: 32),
      songs: _map(m['songs']) ?? const {},
    );
  }
}

/// An album an artist job left out, with why: `owned` (artist-missing: the
/// library has it) or `appearance` (the artist only guests on it).
class LeftOutAlbum {
  final String name;
  final int? year;
  final String? why;
  const LeftOutAlbum(this.name, {this.year, this.why});

  static LeftOutAlbum? fromServerMap(dynamic m) {
    if (m is! Map) return null;
    return LeftOutAlbum(
      m['name'] is String ? m['name'] as String : '',
      year: _int(m['year']),
      why: _str(m['why'], max: 32),
    );
  }
}

/// A typed read of a job's `result` (federation-copy's shapes):
///
///   song     { copied: { vpath, filepath, trackId, bytes, … } }
///            | { skipped: 'owned', existing: { filepath } }
///            | { skipped: 'exists', filepath }
///   many     { scope, songs: { total, copied[], skipped[], failed[] },
///              counts: { total, copied, skipped, failed }, albums[],
///              skippedAlbums[], bytes, stopped, peer, truncated? }
///
/// The per-song lists stop at 500 entries (federation-copy's
/// RESULT_LIST_CAP): numbers come from `counts`, never list lengths.
class JobResultView {
  final Map<String, dynamic>? raw;
  const JobResultView(this.raw);

  Map<String, dynamic> get _r => raw ?? const {};

  /// An album's or an artist's copy: every song accounted for (`songs.total`
  /// or `counts.total` is a number).
  bool get isMany {
    final songs = _r['songs'];
    final counts = _r['counts'];
    return (songs is Map && songs['total'] is num) ||
        (counts is Map && counts['total'] is num);
  }

  /// A many-song result's songs as whole numbers: `counts` (the lists stop
  /// at 500 entries), else the lists' lengths (an older server).
  JobCounts get counts {
    final c = _r['counts'] is Map ? _r['counts'] as Map : const {};
    final s = _r['songs'] is Map ? _r['songs'] as Map : const {};
    int n(String k) {
      final v = c[k];
      if (v is num && v.isFinite && v >= 0) return v.toInt();
      final list = s[k];
      return list is List ? list.length : 0;
    }

    final t = c['total'] ?? s['total'];
    return JobCounts(
      total: t is num && t.isFinite && t >= 0 ? t.toInt() : n('copied') + n('skipped') + n('failed'),
      copied: n('copied'),
      skipped: n('skipped'),
      failed: n('failed'),
    );
  }

  /// The library file a song copy landed as.
  String? get copiedFilepath {
    final c = _r['copied'];
    return c is Map ? _str(c['filepath'], max: 4096) : null;
  }

  int? get copiedBytes {
    final c = _r['copied'];
    return c is Map ? _int(c['bytes']) : null;
  }

  /// `owned` | `exists` for a song copy that wrote nothing.
  String? get skipped => _str(_r['skipped'], max: 32);

  /// The library song a skipped-as-owned copy matched.
  String? get existingFilepath {
    final e = _r['existing'];
    return e is Map ? _str(e['filepath'], max: 4096) : null;
  }

  /// Where a skipped-as-exists copy would have written.
  String? get filepath => _str(_r['filepath'], max: 4096);

  /// A download plug-in's landed file.
  String? get downloadedFilepath {
    final d = _r['downloaded'];
    return d is Map ? _str(d['filepath'], max: 4096) : null;
  }

  /// quota · busy · peer · refused · cancelled · null
  String? get stopped => _str(_r['stopped'], max: 32);

  String? get peerName {
    final p = _r['peer'];
    return p is Map ? _str(p['name']) : null;
  }

  List<WalkedAlbum> get albums =>
      _listOf(_r['albums'], WalkedAlbum.fromServerMap);
  List<LeftOutAlbum> get skippedAlbums =>
      _listOf(_r['skippedAlbums'], LeftOutAlbum.fromServerMap);

  int? get bytes => _int(_r['bytes']);
  bool get truncated => _r['truncated'] == true;

  /// Where a folder copy's files went, by its own account of the folder
  /// (`result.folder.landed`): the library and folders, '/'-joined
  /// ("copies/Boukmanflow/Borrowed Tapes"); null for a copy by the layout,
  /// whose songs each went their own way.
  String? get folderLanded {
    final f = _r['folder'];
    return f is Map ? _str(f['landed'], max: 4096) : null;
  }

  /// Where a finished folder copy's files are (its "In copies › …" line,
  /// "Show in your library"): where it landed once it copied a song. One
  /// that copied none — every song already here — never made that folder,
  /// so the folder the songs it found share instead (their `at`, '/'-joined
  /// from the library). Null for a copy by the layout, and when they share
  /// none or the list stopped short of naming them all.
  String? get folderFilesAt {
    final landed = folderLanded;
    if (landed == null || counts.copied > 0) return landed;
    final s = _r['songs'];
    final found =
        s is Map && s['skipped'] is List ? s['skipped'] as List : const [];
    if (found.isEmpty || truncated) return null;
    List<String>? shared;
    for (final e in found) {
      final at = e is Map ? _str(e['at'], max: 4096) : null;
      final parts = (at ?? '').split('/').where((p) => p.isNotEmpty).toList();
      // A library and a file, at the least.
      if (parts.length < 2) return null;
      final dir = parts.sublist(0, parts.length - 1);
      if (shared == null) {
        shared = dir;
        continue;
      }
      var n = 0;
      while (n < shared.length && n < dir.length && shared[n] == dir[n]) {
        n++;
      }
      if (n == 0) return null;
      shared = shared.sublist(0, n);
    }
    return shared!.join('/');
  }

  /// The files a folder copy left out (`skippedFiles`: not music this
  /// server plays, the scanner's ignored folders, a path that climbs) — how
  /// many the list names (it stops at 500).
  int get skippedFiles {
    final s = _r['skippedFiles'];
    return s is List ? s.length : 0;
  }
}

/// One answer of `POST /plugin-jobs/lookup` (and each entry of
/// `lookup/batch`): the recommendation's song key, every scope's key, and
/// the caller's newest job per plug-in and scope under any of them.
class JobLookup {
  /// The song key (`keys.song`).
  final String? key;

  /// scope → key (song, album, artist, artist-missing, folder — a scope the
  /// recommendation lacks a field for is absent).
  final Map<String, String> keys;
  final List<DiscoveryJob> jobs;

  const JobLookup({this.key, this.keys = const {}, this.jobs = const []});

  static JobLookup? fromServerMap(dynamic m) {
    if (m is! Map) return null;
    final keys = m['keys'];
    return JobLookup(
      key: _str(m['key'], max: 1024),
      keys: {
        if (keys is Map)
          for (final e in keys.entries)
            if (e.key is String && e.value is String && (e.value as String).isNotEmpty)
              e.key as String: e.value as String,
      },
      jobs: _listOf(m['jobs'], DiscoveryJob.fromServerMap),
    );
  }

  /// Every key the lookup named, song first (the webapp's keysOf).
  List<String> get allKeys {
    final out = <String>[];
    if (key != null) out.add(key!);
    for (final v in keys.values) {
      if (!out.contains(v)) out.add(v);
    }
    return out;
  }
}

/// `GET /api/v1/discovery/plugin-jobs`.
class JobList {
  final List<DiscoveryJob> jobs;

  /// The runner's busy count, and whether it is running at all.
  final int? running;
  final bool? active;

  const JobList(this.jobs, {this.running, this.active});

  factory JobList.fromServerMap(Map m) {
    final runner = m['runner'];
    return JobList(
      _listOf(m['jobs'], DiscoveryJob.fromServerMap),
      running: runner is Map ? _int(runner['running']) : null,
      active: runner is Map && runner['active'] is bool
          ? runner['active'] as bool
          : null,
    );
  }
}

/// `POST /plugins/:name/jobs`: 202 with a new job (`created`), or 200 with
/// the caller's own live job for the same key.
class StartedJob {
  final DiscoveryJob job;
  final bool created;
  const StartedJob(this.job, {required this.created});
}

/// How a cancel went: `cancelled` (it was queued: gone at once),
/// `requested` (it was running: it stops at its next check),
/// [alreadyFinished] (409: it ended before the cancel reached it), or —
/// the jobs controller's — [failed] (the call itself failed; the message
/// says why).
enum CancelOutcome { cancelled, requested, alreadyFinished, failed }

class CancelResult {
  final CancelOutcome outcome;

  /// The job as the server holds it after the cancel; null for a 409.
  final DiscoveryJob? job;

  /// The server's own words for a 409 ("job 7 is already done").
  final String? message;
  const CancelResult(this.outcome, {this.job, this.message});
}

/// Where the files a plug-in brings in are put: a library, a base folder
/// inside it, and a layout rendered per song (torrent path-template syntax).
class CollectionDestination {
  final String vpath;
  final String base;
  final String layout;

  /// `user` = the saved one is in force; `default` = the library default.
  /// Null on a `saved` record and on what a client sends.
  final String? source;

  const CollectionDestination(
      {required this.vpath, this.base = '', required this.layout, this.source});

  static CollectionDestination? fromServerMap(dynamic m) {
    if (m is! Map) return null;
    final vpath = _str(m['vpath'], max: 200);
    final layout = _str(m['layout'], max: 500);
    if (vpath == null || layout == null) return null;
    return CollectionDestination(
      vpath: vpath,
      base: m['base'] is String ? m['base'] as String : '',
      layout: layout,
      source: _str(m['source'], max: 32),
    );
  }

  bool get isDefault => source == 'default';

  /// The PUT body's `destination`, and a start's (the place it showed).
  Map<String, dynamic> toJson() =>
      {'vpath': vpath, 'base': base, 'layout': layout};
}

/// Where a surface showed the files going, as a start sends it (its
/// `destination`): [destination], or null — it showed nowhere, sent as an
/// explicit `null`, which the server refuses with 409
/// `destination_changed` whenever the account has a place. A start given
/// no [ShownPlace] sends no key, and nothing is checked.
class ShownPlace {
  final CollectionDestination? destination;
  const ShownPlace(this.destination);

  /// The start's `destination`: `{vpath, base, layout}` (its `source` left
  /// out), or null.
  Map<String, dynamic>? toJson() => destination?.toJson();
}

/// A library the caller may put files into, with its admin Path Template.
class WritableLibrary {
  final String vpath;
  final String? template;
  const WritableLibrary(this.vpath, {this.template});

  static WritableLibrary? fromServerMap(dynamic m) {
    if (m is! Map) return null;
    final vpath = _str(m['vpath'], max: 200);
    if (vpath == null) return null;
    return WritableLibrary(vpath, template: _str(m['template'], max: 500));
  }
}

/// `GET` / `PUT /api/v1/discovery/collection/destination`: the effective
/// destination — null when the caller may not put files anywhere (uploads
/// off, or no library takes them; the ping's noUpload tells which) — what
/// is saved, and what the picker needs.
class DestinationView {
  final CollectionDestination? destination;
  final CollectionDestination? saved;
  final List<WritableLibrary> libraries;
  final String defaultLayout;
  final List<String> variables;

  const DestinationView({
    this.destination,
    this.saved,
    this.libraries = const [],
    this.defaultLayout = kDefaultCopyLayout,
    this.variables = const [],
  });

  factory DestinationView.fromServerMap(Map m) => DestinationView(
        destination: CollectionDestination.fromServerMap(m['destination']),
        saved: CollectionDestination.fromServerMap(m['saved']),
        libraries: _listOf(m['libraries'], WritableLibrary.fromServerMap),
        defaultLayout:
            _str(m['defaultLayout'], max: 500) ?? kDefaultCopyLayout,
        variables: _strings(m['variables']),
      );

  /// The same view with another effective [destination] (a start's 409
  /// `destination_changed` names only that; the rest is read again).
  DestinationView withDestination(CollectionDestination? destination) =>
      DestinationView(
        destination: destination,
        saved: saved,
        libraries: libraries,
        defaultLayout: defaultLayout,
        variables: variables,
      );
}

/// One "Open elsewhere" link (the links plug-in): `canonical` (the exact
/// MusicBrainz recording / release group / ISRC page) before `search`.
class PluginLink {
  final String id;
  final String label;
  final String url;
  final String kind;
  const PluginLink(
      {required this.id,
      required this.label,
      required this.url,
      this.kind = 'search'});

  static PluginLink? fromServerMap(dynamic m) {
    if (m is! Map) return null;
    final url = _str(m['url'], max: 4096);
    if (url == null) return null;
    final uri = Uri.tryParse(url);
    // Only a web page leaves the app.
    if (uri == null || (uri.scheme != 'https' && uri.scheme != 'http')) {
      return null;
    }
    return PluginLink(
      id: _str(m['id'], max: 64) ?? url,
      label: _str(m['label']) ?? url,
      url: url,
      kind: m['kind'] == 'canonical' ? 'canonical' : 'search',
    );
  }

  bool get canonical => kind == 'canonical';
}

/// The links plug-in's answer, canonical links first (the server's order
/// within each tier).
List<PluginLink> pluginLinksOf(dynamic resolveAnswer) {
  final result = resolveAnswer is Map ? resolveAnswer['result'] : null;
  final links = _listOf(result is Map ? result['links'] : null,
      PluginLink.fromServerMap);
  return [
    ...links.where((l) => l.canonical),
    ...links.where((l) => !l.canonical),
  ];
}

// ─── Wire sanitisers ─────────────────────────────────────────────────────

String? _str(dynamic v, {int max = 512}) =>
    v is String && v.trim().isNotEmpty && v.length <= max ? v : null;

int? _int(dynamic v) {
  if (v is int) return v;
  if (v is num) return v.isFinite ? v.round() : null;
  if (v is String) return int.tryParse(v.trim());
  return null;
}

List<String> _strings(dynamic v) =>
    v is List ? v.whereType<String>().where((s) => s.isNotEmpty).toList() : const [];

List<T> _listOf<T>(dynamic v, T? Function(dynamic) parse) =>
    v is List ? v.map(parse).whereType<T>().toList() : <T>[];

/// A wire object as a read-only string-keyed map (nested values as sent).
Map<String, dynamic>? _map(dynamic v) => v is Map
    ? Map.unmodifiable(<String, dynamic>{
        for (final e in v.entries)
          if (e.key is String) e.key as String: e.value,
      })
    : null;
