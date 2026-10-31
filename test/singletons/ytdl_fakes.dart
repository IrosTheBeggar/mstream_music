// A scripted mStream for Add from YouTube, shared by the hub, draft and UI
// tests: the lookup, the add, the server's job tracker, folder listings and
// mkdir over an in-memory tree, the download record (or a server too old to
// have one), and the account presets — each answered from state the test
// sets, held on a Completer when it asks, refused with a status and the
// server's words, every request logged. And the time the hub and the draft
// run on: a clock the test moves and timers that fire as it passes.
//
// The usual setUp is one line — `h = YtdlHarness()..wire();` — and the
// tearDown `h.unwire();`. In a widget test (fake async) wrap the waits in
// `tester.runAsync`, or pump: the fake answers through MockClient.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart' show Locale;
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mstream_music/l10n/app_localizations.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/singletons/ytdl_hub.dart';
import 'package:mstream_music/util/discovery_plugins_api.dart';
import 'package:mstream_music/util/ytdl_api.dart';
import 'package:mstream_music/util/ytdl_filename.dart';

/// "One More Time" (a YouTube Music track: album Discovery, 2001, the
/// artist yt-dlp reads off the track rather than the "- Topic" channel):
/// the main flow.
const kOneMoreTime = 'https://www.youtube.com/watch?v=FGBhQbmPwH8';
const kOneMoreTimeVideo = {
  'title': 'One More Time',
  'artist': 'Daft Punk',
  'album': 'Discovery',
  'year': 2001,
  'thumbnail': 'https://i.ytimg.com/vi/FGBhQbmPwH8/hq.jpg',
};

/// "Gorillaz - Feel Good Inc. (Official Video) [HD]" (no album): cleaning
/// and the split.
const kFeelGood = 'https://www.youtube.com/watch?v=HyHNuVaZJ-k';
const kFeelGoodVideo = {
  'title': 'Gorillaz - Feel Good Inc. (Official Video) [HD]',
  'artist': 'Gorillaz',
  'album': null,
  'year': null,
  'thumbnail': 'https://i.ytimg.com/vi/HyHNuVaZJ-k/hq.jpg',
};

/// "Sweater Weather (Official Video)" from a VEVO channel, no album and no
/// split: the YouTube-artist tier.
const kSweater = 'https://www.youtube.com/watch?v=GCdwKhTtNNw';
const kSweaterVideo = {
  'title': 'Sweater Weather (Official Video)',
  'artist': 'TheNeighbourhoodVEVO',
  'album': null,
  'year': null,
  'thumbnail': null,
};

/// An own server with [libraries] (the gates want at least one).
Server ytdlServer({
  List<String> libraries = const ['Music'],
  bool? noMkdir,
  bool? noUpload,
  bool? transcode,
  List<String>? formats,
}) =>
    Server('http://music.example', null, null, 'JWT', 'home')
      ..autoDJPaths = {for (final l in libraries) l: true}
      ..noMkdir = noMkdir
      ..noUpload = noUpload
      ..transcodeAvailable = transcode
      ..supportedAudioFormats = formats;

/// A Quick Connect server; [tunnelUp] false = before its tunnel came up
/// (its requests would be refused on the phone).
Server ytdlIrohServer({bool tunnelUp = true}) =>
    Server('iroh://home', null, null, 'JWT', 'qc')
      ..connectionType = 'iroh'
      ..tunnelPort = tunnelUp ? 4242 : null
      ..tunnelToken = tunnelUp ? 'tok' : null
      ..autoDJPaths = {'Music': true};

/// A connected server's virtual Server under [parent].
Server ytdlPeerOf(Server parent) =>
    Server('federated://home/3', null, null, null, 'peer-basement')
      ..federationParent = parent.localname
      ..federationPeerId = 3
      ..parentServer = parent
      ..autoDJPaths = {'Shared': true};

/// The phone's clock, moved by the test.
class FakeClock {
  DateTime current;
  FakeClock([DateTime? start]) : current = start ?? DateTime(2026, 10, 31, 12);
  DateTime now() => current;
  void advance(Duration d) => current = current.add(d);
}

/// A timer that fires when [FakeYtdlTimers.elapse] passes its [due] time
/// (or when the test fires it).
class FakeYtdlTimer implements Timer {
  final Duration delay;
  final DateTime due;
  final void Function() _fire;
  bool _active = true;
  FakeYtdlTimer(this.delay, this.due, this._fire);

  void fire() {
    if (!_active) return;
    _active = false;
    _fire();
  }

  @override
  void cancel() => _active = false;
  @override
  bool get isActive => _active;
  @override
  int get tick => 0;
}

class FakeYtdlTimers {
  final FakeClock clock;
  final List<FakeYtdlTimer> made = [];
  FakeYtdlTimers(this.clock);

  Timer call(Duration delay, void Function() fire) {
    final t = FakeYtdlTimer(delay, clock.current.add(delay), fire);
    made.add(t);
    return t;
  }

  List<FakeYtdlTimer> get active => [for (final t in made) if (t.isActive) t];

  /// The live timer with [delay], newest first; null when none.
  FakeYtdlTimer? withDelay(Duration delay) =>
      active.where((t) => t.delay == delay).lastOrNull;

  bool hasActive(Duration delay) => withDelay(delay) != null;

  /// Move the clock by [d], firing each timer as its time comes (in order,
  /// settling after each), then settle.
  Future<void> elapse(Duration d) async {
    final end = clock.current.add(d);
    while (true) {
      final due = active.where((t) => !t.due.isAfter(end)).toList()
        ..sort((a, b) => a.due.compareTo(b.due));
      if (due.isEmpty) break;
      final t = due.first;
      if (t.due.isAfter(clock.current)) clock.current = t.due;
      t.fire();
      await ytdlSettle();
    }
    clock.current = end;
    await ytdlSettle();
  }
}

/// Let every pending request and microtask run.
Future<void> ytdlSettle() async {
  for (var i = 0; i < 60; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

/// A route answered with this status and `{error}` ([words] null: no JSON
/// body, as Express's own 404 or a proxy's page).
typedef YtdlRefusal = (int status, String? words);

class FakeYtdlServer {
  final List<http.Request> requests = [];

  int count(String method, String pathSuffix) => calls(method, pathSuffix).length;

  List<http.Request> calls(String method, String pathSuffix) => [
        for (final r in requests)
          if (r.method == method && r.url.path.endsWith(pathSuffix)) r
      ];

  /// The JSON bodies of [method] [pathSuffix] requests, in order.
  List<Map<String, dynamic>> bodies(String method, String pathSuffix) => [
        for (final r in calls(method, pathSuffix))
          jsonDecode(r.body) as Map<String, dynamic>
      ];

  /// Any route whose path ends with the key answers its refusal instead.
  final Map<String, YtdlRefusal> refuse = {};

  /// The server's own clock (ms epoch): the tracker's startTime and the
  /// record's downloadedAt. Each use moves it on.
  int serverNow = 1793450000000;
  int _tick() => serverNow += 1000;

  // ── the lookup ──────────────────────────────────────────────────────────

  /// What yt-dlp reads off each link; [video] for any other.
  final Map<String, Map<String, Object?>> videos = {
    kOneMoreTime: kOneMoreTimeVideo,
    kFeelGood: kFeelGoodVideo,
    kSweater: kSweaterVideo,
  };
  Map<String, Object?> video = kOneMoreTimeVideo;

  YtdlRefusal? lookupRefusal;

  /// Thrown by the transport instead of an answer (TimeoutException,
  /// SocketException, http.ClientException …).
  Object? lookupThrows;

  /// Hold every lookup until the test completes the Completer it adds to
  /// [heldLookups] (in any order); each answers as [videos] says then.
  bool holdLookups = false;
  final List<Completer<void>> heldLookups = [];

  // ── the add ─────────────────────────────────────────────────────────────

  YtdlRefusal? addRefusal;
  Object? addThrows;
  Completer<void>? addGate;

  /// A 200 add starts a tracker entry (false: the server took it and the
  /// entry never shows — an older server's quirk, a crash).
  bool addStartsEntry = true;

  // ── the tracker (GET /ytdl/downloads) ───────────────────────────────────

  /// Every account's entries, as the route lists them.
  final List<Map<String, dynamic>> tracker = [];
  int nextPid = 5000;
  Object? jobsThrows;
  YtdlRefusal? jobsRefusal;

  Map<String, dynamic> entry(int pid) => tracker.firstWhere((e) => e['pid'] == pid);

  /// The newest entry for [url] (and [directory] when given).
  Map<String, dynamic> entryFor(String url, {String? directory}) =>
      tracker.lastWhere((e) =>
          e['url'] == url && (directory == null || e['directory'] == directory));

  /// An entry another device or account started.
  Map<String, dynamic> addEntry({
    required String url,
    required String directory,
    String codec = 'mp3',
    String status = 'downloading',
    int? startTime,
    int? pid,
  }) {
    final e = <String, dynamic>{
      'pid': pid ?? nextPid++,
      'url': url,
      'directory': directory,
      'outputCodec': codec,
      'status': status,
      'startTime': startTime ?? _tick(),
    };
    tracker.add(e);
    return e;
  }

  /// [pid] finished: the file lands in its folder ([land]) and, on a
  /// server with the record, a row is written ([record]).
  void finish(int pid, {bool land = true, bool record = true, String? fileName}) {
    final e = entry(pid)..['status'] = 'complete';
    final name = fileName ?? predictedFor(e);
    if (land) file(e['directory'] as String, name);
    if (record && hasRecords) {
      final crumbs = (e['directory'] as String)
          .split('/')
          .where((s) => s.isNotEmpty)
          .toList();
      addRecord(
        vpath: crumbs.first,
        relativePath: [...crumbs.skip(1), name].join('/'),
        origin: e['url'] as String,
        title: videos[e['url']]?['title'] as String?,
      );
    }
  }

  /// [pid] ended in `error` (the route keeps no reason).
  void fail(int pid) => entry(pid)['status'] = 'error';

  /// [pid] left the tracker (30 s after it settled, or a server restart).
  void forget(int pid) => tracker.removeWhere((e) => e['pid'] == pid);

  /// yt-dlp's name for an entry's video in its format.
  String predictedFor(Map<String, dynamic> e) => ytdlPredictedFileName(
      (videos[e['url']] ?? video)['title'] as String? ?? 'video',
      e['outputCodec'] as String? ?? 'mp3');

  // ── folders ─────────────────────────────────────────────────────────────

  /// Folder path ('/Music/Daft Punk/') → its file names. A folder's parents
  /// are folders too; subfolders are read off the keys.
  final Map<String, Set<String>> tree = {'/Music/': {}};

  /// Folders that answer a network failure instead of their listing.
  final Set<String> listFails = {};

  /// 6.26–6.28.0: a missing folder lists as 500 "Server Error".
  bool missingIs500 = false;

  YtdlRefusal? mkdirRefusal;
  Object? mkdirThrows;
  Completer<void>? mkdirGate;

  static String norm(String path) {
    final parts = path.split('/').where((s) => s.isNotEmpty);
    return parts.isEmpty ? '/' : '/${parts.join('/')}/';
  }

  /// Make [path] and its parents, with [files] in it.
  void folder(String path, {List<String> files = const []}) {
    final parts = norm(path).split('/').where((s) => s.isNotEmpty).toList();
    for (var i = 1; i <= parts.length; i++) {
      tree.putIfAbsent('/${parts.take(i).join('/')}/', () => {});
    }
    tree[norm(path)]!.addAll(files);
  }

  void file(String dir, String name) => folder(dir, files: [name]);

  bool exists(String path) => tree.containsKey(norm(path));

  List<String> _subfolders(String path) {
    final p = norm(path);
    return [
      for (final k in tree.keys)
        if (k.startsWith(p) && k != p && !k.substring(p.length, k.length - 1).contains('/'))
          k.substring(p.length, k.length - 1),
    ];
  }

  /// [path] names a file in its parent folder (ENOTDIR).
  bool _isFile(String path) {
    final parts = norm(path).split('/').where((s) => s.isNotEmpty).toList();
    if (parts.length < 2) return false;
    final parent = '/${parts.take(parts.length - 1).join('/')}/';
    return tree[parent]?.contains(parts.last) ?? false;
  }

  // ── the download record (6.30+) ─────────────────────────────────────────

  /// False: a server before 6.30, whose Express answers the route with its
  /// own HTML 404.
  bool hasRecords = true;

  /// Every plug-in's rows, newest first.
  final List<Map<String, dynamic>> records = [];
  int nextRecordId = 100;
  Object? recordsThrows;
  YtdlRefusal? recordsRefusal;

  Map<String, dynamic> addRecord({
    String plugin = 'ytdl',
    String vpath = 'Music',
    required String relativePath,
    String origin = kOneMoreTime,
    String? title,
    String? artist,
    String? album,
    int bytes = 8400000,
    int? downloadedAt,
    bool present = true,
    int? trackId,
    int? id,
  }) {
    final rid = id ?? nextRecordId++;
    final r = <String, dynamic>{
      'id': rid,
      'plugin': plugin,
      'userId': 1,
      'jobId': null,
      'vpath': vpath,
      'filepath': '$vpath/$relativePath',
      'relativePath': relativePath,
      'fileHash': 'h$rid',
      'origin': origin,
      'title': title,
      'artist': artist,
      'album': album,
      'bytes': bytes,
      'downloadedAt': downloadedAt ?? _tick(),
      'removedAt': null,
      'present': present,
      'trackId': trackId ?? 900 + rid,
    };
    records.insert(0, r);
    return r;
  }

  // ── the account presets ─────────────────────────────────────────────────

  /// `GET /discovery/collection/destination`'s answer (null: 404).
  Map<String, dynamic>? destination;

  /// `GET /torrent/path-templates`'s answer (null: 404).
  Map<String, dynamic>? pathTemplates;

  /// Discover's destination as the user saved it.
  void discoverAt(String vpath,
      {String base = '', String layout = '{{ALBUMARTIST}}/{{ALBUM}}', String source = 'user'}) {
    destination = {
      'destination': {'vpath': vpath, 'base': base, 'layout': layout, 'source': source},
      'saved': source == 'user' ? {'vpath': vpath, 'base': base, 'layout': layout} : null,
      'libraries': [
        {'vpath': vpath, 'template': null}
      ],
      'defaultLayout': '{{ALBUMARTIST}}/{{ALBUM}}',
      'variables': ['ARTIST', 'ALBUM', 'YEAR', 'GENRE', 'ALBUMARTIST', 'PEER', 'SERVERFOLDER'],
    };
  }

  // ── transport ───────────────────────────────────────────────────────────

  static http.Response _json(Object? body, [int status = 200]) => http.Response(
      jsonEncode(body), status,
      headers: {'content-type': 'application/json'});

  static http.Response _refused(YtdlRefusal r) {
    final (status, words) = r;
    if (words == null) {
      return http.Response('<!DOCTYPE html><html><body><pre>Cannot GET</pre></body></html>',
          status,
          headers: {'content-type': 'text/html; charset=utf-8'});
    }
    return _json({'error': words}, status);
  }

  Future<http.Response> handle(http.Request req) async {
    requests.add(req);
    final path = req.url.path;
    for (final e in refuse.entries) {
      if (path.endsWith(e.key)) return _refused(e.value);
    }
    if (req.method == 'GET' && path.endsWith('/api/v1/ytdl/metadata')) {
      final url = req.url.queryParameters['url'] ?? '';
      if (holdLookups) {
        final hold = Completer<void>();
        heldLookups.add(hold);
        await hold.future;
      }
      final t = lookupThrows;
      if (t != null) throw t;
      final r = lookupRefusal;
      if (r != null) return _refused(r);
      return _json(videos[url] ?? video);
    }
    if (req.method == 'POST' && path.endsWith('/api/v1/ytdl/')) {
      final gate = addGate;
      if (gate != null) await gate.future;
      final t = addThrows;
      if (t != null) throw t;
      final r = addRefusal;
      if (r != null) return _refused(r);
      final body = jsonDecode(req.body) as Map;
      if (addStartsEntry) {
        addEntry(
          url: body['url'] as String,
          directory: body['directory'] as String,
          codec: body['outputCodec'] as String? ?? 'mp3',
        );
      }
      return _json({'message': 'Download started'});
    }
    if (req.method == 'GET' && path.endsWith('/api/v1/ytdl/downloads')) {
      final t = jobsThrows;
      if (t != null) throw t;
      final r = jobsRefusal;
      if (r != null) return _refused(r);
      return _json({'downloads': tracker});
    }
    if (req.method == 'POST' && path.endsWith('/api/v1/file-explorer/mkdir')) {
      final gate = mkdirGate;
      if (gate != null) await gate.future;
      final t = mkdirThrows;
      if (t != null) throw t;
      final r = mkdirRefusal;
      if (r != null) return _refused(r);
      final dir = (jsonDecode(req.body) as Map)['directory'] as String;
      if (_isFile(dir)) return _json({'error': 'Server Error'}, 500);
      folder(dir);
      return _json({});
    }
    if (req.method == 'POST' && path.endsWith('/api/v1/file-explorer')) {
      final dir = norm((jsonDecode(req.body) as Map)['directory'] as String);
      if (listFails.contains(dir)) {
        throw http.ClientException('Connection closed before full header was received');
      }
      if (!exists(dir)) {
        if (missingIs500) return _json({'error': 'Server Error'}, 500);
        final why = _isFile(dir) ? 'ENOTDIR' : 'ENOENT';
        return _json({'error': 'Cannot read directory "$dir" ($why)'}, 404);
      }
      return _json({
        'path': dir,
        'directories': [for (final d in _subfolders(dir)) {'name': d}],
        'files': [
          for (final f in tree[dir]!) {'type': f.split('.').last.toLowerCase(), 'name': f}
        ],
      });
    }
    if (req.method == 'GET' && path.endsWith('/api/v1/discovery/downloads')) {
      if (!hasRecords) return _refused((404, null));
      final t = recordsThrows;
      if (t != null) throw t;
      final r = recordsRefusal;
      if (r != null) return _refused(r);
      final q = req.url.queryParameters;
      final limit = int.tryParse(q['limit'] ?? '') ?? 100;
      final before = int.tryParse(q['before'] ?? '');
      final rows = [
        for (final row in records)
          if (before == null || (row['id'] as int) < before) row
      ].take(limit).toList();
      return _json({'downloads': rows});
    }
    if (req.method == 'GET' && path.endsWith('/api/v1/discovery/collection/destination')) {
      final d = destination;
      return d == null ? _refused((404, null)) : _json(d);
    }
    if (req.method == 'GET' && path.endsWith('/api/v1/torrent/path-templates')) {
      final t = pathTemplates;
      return t == null ? _json({'error': 'Not Found'}, 404) : _json(t);
    }
    return _json({'error': 'no route $path'}, 404);
  }

  late final MockClient client = MockClient(handle);

  /// Whether the tunnel comes back when a client waits for it.
  bool tunnelBack = true;

  YtdlApi api(Server server) => YtdlApi(server,
      client: client, awaitTunnel: (_) async => tunnelBack);
}

/// Everything a hub or draft test wires: the fake server, the clock and
/// timers, and what the hub hands out (toasts, persists, re-pings, the
/// clipboard, the tunnel wait).
class YtdlHarness {
  final FakeClock clock = FakeClock();
  late final FakeYtdlTimers timers = FakeYtdlTimers(clock);
  final FakeYtdlServer fake = FakeYtdlServer();

  final List<({String message, bool success})> toasts = [];
  final List<Server> persisted = [];
  final List<Server> repings = [];

  /// The clipboard's text (null: empty).
  String? clipboard;

  /// What the add's tunnel wait answers, and how many waits there were.
  bool tunnelReady = true;
  int tunnelWaits = 0;

  final AppLocalizations l = lookupAppLocalizations(const Locale('en'));

  YtdlHub get hub => YtdlHub();

  /// Point the hub's seams here (setUp).
  void wire() {
    final hub = this.hub;
    hub.makeApi = fake.api;
    hub.timer = timers.call;
    hub.now = clock.now;
    hub.toast = (m, {success = false}) => toasts.add((message: m, success: success));
    hub.l10n = () => l;
    hub.persist = (s) async => persisted.add(s);
    hub.reping = (s) async => repings.add(s);
    hub.clipboardHasText = () async => (clipboard ?? '').isNotEmpty;
    hub.clipboardText = () async => clipboard;
    hub.awaitTunnel = (s) async {
      tunnelWaits++;
      return tunnelReady;
    };
    hub.destinationOf = (s) => DiscoveryPluginsApi(s, client: fake.client).destination();
    hub.pathTemplatesOf = (s) async {
      final res = await fake.client.get(s.apiUri('/api/v1/torrent/path-templates'));
      if (res.statusCode != 200) throw Exception('Could not load path templates');
      return jsonDecode(res.body) as Map<String, dynamic>;
    };
    hub.watchLifecycle = false;
  }

  /// Let the hub go (tearDown).
  void unwire() => hub.reset();

  List<String> get toastTexts => [for (final t in toasts) t.message];

  /// A request for the same video as the draft would send it.
  YtdlStartRequest request({
    String url = kOneMoreTime,
    String directory = '/Music/Daft Punk/Discovery/',
    String codec = 'mp3',
    Map<String, String> metadata = const {
      'title': 'One More Time',
      'artist': 'Daft Punk',
      'album': 'Discovery',
      'year': '2001',
    },
    String title = 'One More Time',
    String predictedName = 'One_More_Time.mp3',
    String? mkdir,
    bool Function()? inline,
  }) =>
      YtdlStartRequest(
        url: url,
        directory: directory,
        codec: codec,
        metadata: metadata,
        title: title,
        predictedName: predictedName,
        mkdir: mkdir,
        origin: 'screen',
        inline: inline,
      );
}
