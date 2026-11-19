// A scripted mStream plug-in API for the Discover jobs tests: the listing,
// the destination, the job list, one job, starts (any plug-in's: the
// copy's, YouTube's), cancels, clear, the single and the batch lookup, and
// the links, preview and YouTube resolves — each answered from state the
// test sets, every request recorded. The lookups answer as the server's
// do: each recommendation's keys, and the caller's jobs under any of them,
// with album and artist keys that carry no server (two connected servers'
// "Borrowed Tapes" share one).
//
// And manual timers: the jobs controller's poll is a timer the test reads
// (its delay) and fires itself.

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/util/discovery_plugins_api.dart';

String _norm(Object? v) => '${v ?? ''}'.trim().toLowerCase();
bool _has(Object? v) => v is String && v.trim().isNotEmpty;

/// A YouTube page, roughly as youtube.js isYouTubeUrl takes it (the fake
/// checks the host only).
final RegExp _youtubeLink = RegExp(r'^https?://((www\.|m\.|music\.)?youtube\.com|youtu\.be)/');

/// The server's jobKeysFor, in shape. A folder's recommendation (a path and
/// its name, no artist) also gets the folder key — the peer and the path,
/// case kept (the server gives every rec with a path and a peer one; a
/// song's is meaningless and left out here).
Map<String, String> fakeKeysOf(Map rec, [String? scope]) {
  final peer = rec['peer'];
  final folder = _has(rec['filepath']) && !_has(rec['artist']) && peer is Map;
  final keys = <String, String>{
    'song': 'text:${_norm(rec['artist'])}|${_norm(rec['title'])}|${_norm(rec['album'])}',
    if (_has(rec['album']))
      'album': 'album:${_norm(_has(rec['albumArtist']) ? rec['albumArtist'] : rec['artist'])}|${_norm(rec['album'])}',
    if (_has(rec['artist'])) 'artist': 'artist:${_norm(rec['artist'])}',
    if (_has(rec['artist'])) 'artist-missing': 'artist-missing:${_norm(rec['artist'])}',
    if (folder)
      'folder': 'folder:${peer['id']}|${'${rec['filepath']}'.replaceAll(RegExp(r'^/+|/+$'), '')}',
  };
  return keys;
}

/// The server's sameDestination, in shape: the library, the base folder's
/// names, the layout; `source` ignored; null matches only null.
bool fakeSamePlace(Map? a, Map? b) {
  if (a == null || b == null) return a == null && b == null;
  String base(Object? v) => '${v ?? ''}'
      .split(RegExp(r'[/\\]'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .join('/');
  return a['vpath'] == b['vpath'] &&
      base(a['base']) == base(b['base']) &&
      a['layout'] == b['layout'];
}

/// The server's searchPhrase: "Artist Title", each part trimmed.
String fakePhraseOf(Map rec) =>
    [rec['artist'], rec['title']].whereType<String>().map((s) => s.trim()).where((s) => s.isNotEmpty).join(' ');

class FakePluginServer {
  /// The listing entries of the network-lead sheet's plug-ins, as the
  /// server lists them (registry.js listPlugins).
  static const Map<String, dynamic> youtubePlugin = {
    'name': 'youtube',
    'title': 'YouTube',
    'capabilities': ['acquire', 'lookup'],
    'scopes': ['song'],
  };
  static const Map<String, dynamic> deezerPlugin = {
    'name': 'deezer',
    'title': 'Preview on Deezer',
    'capabilities': ['preview'],
    'scopes': ['song'],
  };
  static const Map<String, dynamic> itunesPlugin = {
    'name': 'itunes',
    'title': 'Preview on iTunes',
    'capabilities': ['preview'],
    'scopes': ['song'],
  };

  final List<http.Request> requests = [];

  Map<String, dynamic> listing = {
    'plugins': [
      {'name': 'links', 'title': 'Open elsewhere', 'capabilities': ['links'], 'scopes': ['song']},
      {
        'name': 'federation-copy',
        'title': 'Add to your collection',
        'capabilities': ['acquire'],
        'scopes': ['song', 'album', 'artist', 'artist-missing', 'folder'],
      },
    ],
    'jobs': {'allowed': true},
  };

  Map<String, dynamic> destination = {
    'destination': {'vpath': 'copies', 'base': '', 'layout': '{{ALBUMARTIST}}/{{ALBUM}}', 'source': 'default'},
    'saved': null,
    'libraries': [
      {'vpath': 'copies', 'template': null}
    ],
    'defaultLayout': '{{ALBUMARTIST}}/{{ALBUM}}',
    'variables': ['ARTIST', 'ALBUM', 'YEAR', 'GENRE', 'ALBUMARTIST', 'PEER', 'SERVERFOLDER'],
  };

  /// The caller's jobs, newest first (wire maps).
  List<Map<String, dynamic>> jobs = [];

  /// Answers a route with this status and `{error}` instead (path suffix →
  /// [status, words]).
  final Map<String, (int, String)> refuse = {};

  /// The same, for one method only ('PUT /api/v1/…' → [status, words]).
  final Map<String, (int, String)> refuseOn = {};

  /// Holds every destination read or save until the test completes it.
  Completer<void>? destinationGate;

  /// Holds each destination read on its own until the test completes its
  /// entry in [heldReads] (in any order); it answers the destination as it
  /// was when asked.
  bool holdReads = false;
  final List<Completer<void>> heldReads = [];

  /// A server from before a start's `destination` (mStream before
  /// 2026-10-21): a start that sends one is refused with Joi's 400.
  bool rejectsDestination = false;

  /// Answers every start with this status and body instead.
  (int, Map<String, dynamic>)? startAnswer;

  /// The links plug-in's answer (wire link maps, in the server's order).
  List<Map<String, dynamic>> links = [];

  /// Holds every links resolve until the test completes it.
  Completer<void>? linksGate;

  /// The preview plug-ins' clips: plug-in name → its `result.preview` (a
  /// wire map, as deezer.js / itunes.js choose answers it). A plug-in not
  /// here answers `preview: null` ("No preview found").
  final Map<String, Map<String, dynamic>> previews = {};

  /// The YouTube lookup's `result.lookup`: its candidates (wire maps, best
  /// first), the library's own copy (`{vpath, filepath, by}`, answered
  /// instead) and its bar. The query is the recommendation's phrase, as
  /// the server's.
  List<Map<String, dynamic>> youtubeCandidates = [];
  Map<String, dynamic>? youtubeOwned;
  double youtubeMinScore = 0.62;

  /// Holds one plug-in's resolves (a preview's or YouTube's, by plug-in
  /// name) until the test completes its gate.
  final Map<String, Completer<void>> resolveGates = {};

  /// Answers a start with this job instead of a new one (200, created
  /// false).
  Map<String, dynamic>? existing;

  /// Holds every lookup/batch until the test completes it.
  Completer<void>? lookupGate;

  /// Holds every job list read until the test completes it.
  Completer<void>? listGate;

  /// Holds every start until the test completes it.
  Completer<void>? startGate;

  /// Jobs the list leaves out (past its newest 100) — the lookups still
  /// answer them.
  final Set<int> unlisted = {};

  int _nextId = 100;

  /// The requests whose path ends with [pathSuffix]. A start's suffix names
  /// its plug-in ('/plugins/federation-copy/jobs', '/plugins/youtube/jobs'):
  /// a bare '/jobs' matches every plug-in's starts.
  int count(String method, String pathSuffix) =>
      requests.where((r) => r.method == method && r.url.path.endsWith(pathSuffix)).length;

  List<http.Request> calls(String method, String pathSuffix) =>
      requests.where((r) => r.method == method && r.url.path.endsWith(pathSuffix)).toList();

  /// The starts sent to [plugin]'s jobs route, and their bodies.
  List<Map<String, dynamic>> starts(String plugin) => [
        for (final r in requests)
          if (r.method == 'POST' && r.url.path.endsWith('/api/v1/discovery/plugins/$plugin/jobs'))
            (jsonDecode(r.body) as Map).cast<String, dynamic>(),
      ];

  /// The resolves sent to [plugin] (its recommendation bodies).
  List<Map<String, dynamic>> resolves(String plugin) => [
        for (final r in requests)
          if (r.method == 'POST' && r.url.path.endsWith('/api/v1/discovery/plugins/$plugin/resolve'))
            (jsonDecode(r.body) as Map).cast<String, dynamic>(),
      ];

  Map<String, dynamic> job(int id) => jobs.firstWhere((j) => j['id'] == id);

  /// List the network-lead sheet's plug-ins beside the default two.
  void listLeadPlugins({bool youtube = true, bool deezer = true, bool itunes = true}) {
    listing = {
      ...listing,
      'plugins': <dynamic>[
        ...(listing['plugins'] as List? ?? const []),
        if (youtube) youtubePlugin,
        if (deezer) deezerPlugin,
        if (itunes) itunesPlugin,
      ],
    };
  }

  /// A job of [plugin]'s (the copy's by default; a YouTube add's with its
  /// pick in `params.choice`) at the head of the list.
  Map<String, dynamic> addJob(Map rec, {String? scope, String state = 'queued', int? id, Map<String, dynamic>? result, double? progress, String? statusText, String plugin = 'federation-copy', Map<String, dynamic>? choice, String? error}) {
    final params = <String, dynamic>{
      if (scope != null && scope != 'song') 'scope': scope,
      'choice': ?choice,
    };
    final j = <String, dynamic>{
      'id': id ?? _nextId++,
      'plugin': plugin,
      'key': fakeKeysOf(rec)[scope ?? 'song'],
      'recommendation': rec,
      'params': params.isEmpty ? null : params,
      'state': state,
      'progress': progress,
      'statusText': statusText,
      'result': result,
      'error': error,
      'attempts': 0,
      'cancelRequested': false,
      'createdAt': 1760900000000 + (id ?? _nextId),
    };
    jobs.insert(0, j);
    return j;
  }

  http.Response _json(Object body, [int status = 200]) =>
      http.Response(jsonEncode(body), status, headers: {'content-type': 'application/json'});

  Future<http.Response> handle(http.Request req) async {
    requests.add(req);
    final path = req.url.path;
    for (final e in refuse.entries) {
      if (path.endsWith(e.key)) return _json({'error': e.value.$2}, e.value.$1);
    }
    for (final e in refuseOn.entries) {
      final sp = e.key.indexOf(' ');
      if (req.method == e.key.substring(0, sp) &&
          path.endsWith(e.key.substring(sp + 1))) {
        return _json({'error': e.value.$2}, e.value.$1);
      }
    }
    if (req.method == 'POST' && path.endsWith('/plugins/links/resolve')) {
      if (linksGate != null) await linksGate!.future;
      return _json({
        'plugin': 'links',
        'result': {'links': links},
      });
    }
    final resolve = RegExp(r'/api/v1/discovery/plugins/([^/]+)/resolve$').firstMatch(path);
    if (req.method == 'POST' && resolve != null) {
      final name = resolve.group(1)!;
      final gate = resolveGates[name];
      if (gate != null) await gate.future;
      final rec = (jsonDecode(req.body) as Map)['recommendation'] as Map;
      final answer = <String, dynamic>{
        'plugin': name,
        'key': fakeKeysOf(rec)['song'],
        'recommendation': rec,
      };
      if (name == 'youtube') {
        return _json({
          ...answer,
          'capabilities': ['acquire', 'lookup'],
          'result': {
            'lookup': {
              'query': fakePhraseOf(rec),
              'minScore': youtubeMinScore,
              // The library's own copy is answered before YouTube is asked.
              'candidates': youtubeOwned == null ? youtubeCandidates : [],
              'owned': youtubeOwned,
            }
          },
        });
      }
      return _json({
        ...answer,
        'capabilities': ['preview'],
        'result': {'preview': previews[name]},
      });
    }
    if (req.method == 'GET' && path.endsWith('/api/v1/discovery/plugins')) return _json(listing);
    if (path.endsWith('/api/v1/discovery/collection/destination')) {
      if (req.method == 'GET' && holdReads) {
        final asked = destination;
        final hold = Completer<void>();
        heldReads.add(hold);
        await hold.future;
        return _json(asked);
      }
      if (destinationGate != null) await destinationGate!.future;
      if (req.method == 'PUT') {
        final d = (jsonDecode(req.body) as Map)['destination'];
        // The library default, as destination.js destinationFor: the first
        // library, with its own Path Template or the server's default layout.
        final first = (destination['libraries'] as List).first as Map;
        final template = first['template'] as String?;
        destination = {
          ...destination,
          'destination': d == null
              ? {
                  'vpath': first['vpath'],
                  'base': '',
                  'layout': template != null && template.isNotEmpty ? template : '{{ALBUMARTIST}}/{{ALBUM}}',
                  'source': 'default',
                }
              : {...d as Map, 'source': 'user'},
          'saved': d,
        };
      }
      return _json(destination);
    }
    if (req.method == 'GET' && path.endsWith('/api/v1/discovery/plugin-jobs')) {
      if (listGate != null) await listGate!.future;
      return _json({
        'jobs': [for (final j in jobs) if (!unlisted.contains(j['id'])) j],
        'runner': {'running': 0, 'active': true},
      });
    }
    // Any plug-in's start, matched on its whole path: the copy's
    // (federation-copy) and the YouTube add's share everything but the
    // pick, which only a plug-in with a lookup takes.
    final start = RegExp(r'/api/v1/discovery/plugins/([^/]+)/jobs$').firstMatch(path);
    if (req.method == 'POST' && start != null) {
      final plugin = start.group(1)!;
      if (startGate != null) await startGate!.future;
      final body = jsonDecode(req.body) as Map;
      final answer = startAnswer;
      if (answer != null) return _json(answer.$2, answer.$1);
      final choice = body['choice'];
      if (choice != null && plugin != 'youtube') {
        return _json({'error': 'plug-in $plugin takes no choice — it has no lookup'}, 400);
      }
      if (choice != null && (choice is! Map || !_youtubeLink.hasMatch('${choice['url']}'))) {
        return _json({'error': 'the chosen upload must be a YouTube link'}, 400);
      }
      final shown = body.containsKey('destination');
      if (shown && rejectsDestination) {
        return _json({'error': '"destination" is not allowed'}, 400);
      }
      if (existing != null) return _json({'job': existing, 'created': false});
      // The jobs route's check: the place the client showed must still be
      // where files land; every new job is pinned to the one in force.
      final effective = destination['destination'] as Map?;
      // A folder given a library and a folder of its own reads none of the
      // destination (destination.js sameDestinationFor).
      final land = body['landing'];
      final ownPlace = land is Map && land['tags'] != true && land['path'] is String && land['vpath'] is String;
      if (shown && !ownPlace && !fakeSamePlace(body['destination'] as Map?, effective)) {
        return _json({
          'error': 'destination_changed',
          'message': 'your collection destination has changed — check where this will land and ask again',
          'destination': effective,
        }, 409);
      }
      final j = addJob(body['recommendation'] as Map,
          scope: body['scope'] as String?, plugin: plugin, choice: choice == null ? null : {'url': (choice as Map)['url']});
      j['params'] = {
        ...?j['params'] as Map?,
        'destination': effective,
        // validateLanding's form: a library of its own or none (null)
        if (body['landing'] is Map)
          'landing': (body['landing'] as Map)['tags'] == true
              ? {'tags': true}
              : {'vpath': (body['landing'] as Map)['vpath'], 'path': (body['landing'] as Map)['path'] ?? ''},
      };
      return _json({'job': j, 'created': true}, 202);
    }
    final cancel = RegExp(r'/plugin-jobs/(\d+)/cancel$').firstMatch(path);
    if (cancel != null) {
      final j = job(int.parse(cancel.group(1)!));
      if (j['state'] == 'queued') {
        j['state'] = 'cancelled';
        return _json({'job': j, 'outcome': 'cancelled'});
      }
      if (j['state'] == 'running') {
        j['cancelRequested'] = true;
        return _json({'job': j, 'outcome': 'requested'});
      }
      return _json({'error': 'job ${j['id']} is already ${j['state']}'}, 409);
    }
    if (path.endsWith('/plugin-jobs/clear')) {
      final before = jobs.length;
      jobs = [for (final j in jobs) if (j['state'] == 'queued' || j['state'] == 'running') j];
      return _json({'removed': before - jobs.length});
    }
    if (path.endsWith('/plugin-jobs/lookup/batch')) {
      if (lookupGate != null) await lookupGate!.future;
      final recs = (jsonDecode(req.body) as Map)['recommendations'] as List;
      return _json({
        'results': [for (final r in recs) _lookup(r as Map)]
      });
    }
    // The single lookup (older than the batch): the same answer for one.
    if (req.method == 'POST' && path.endsWith('/plugin-jobs/lookup')) {
      if (lookupGate != null) await lookupGate!.future;
      return _json(_lookup((jsonDecode(req.body) as Map)['recommendation'] as Map));
    }
    final one = RegExp(r'/plugin-jobs/(\d+)$').firstMatch(path);
    if (req.method == 'GET' && one != null) {
      final id = int.parse(one.group(1)!);
      final j = jobs.where((j) => j['id'] == id).firstOrNull;
      return j == null ? _json({'error': 'job not found'}, 404) : _json({'job': j});
    }
    return _json({'error': 'no route $path'}, 404);
  }

  /// A lookup's answer for [rec]: its keys, and the newest job per plug-in
  /// and scope under any of them.
  Map<String, dynamic> _lookup(Map rec) {
    final keys = fakeKeysOf(rec);
    final own = keys.values.toSet();
    final seen = <String>{};
    final mine = <Map<String, dynamic>>[];
    for (final j in jobs) {
      if (!own.contains(j['key'])) continue;
      final slot = '${j['plugin']}@${(j['params'] as Map?)?['scope'] ?? 'song'}';
      if (seen.add(slot)) mine.add(j);
    }
    return {'key': keys['song'], 'keys': keys, 'jobs': mine};
  }

  DiscoveryPluginsApi api(Server server) => DiscoveryPluginsApi(server, client: MockClient(handle));
}

/// A timer the test fires itself.
class FakeTimer implements Timer {
  final Duration delay;
  final void Function() _fire;
  bool _active = true;
  FakeTimer(this.delay, this._fire);

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

class FakeTimers {
  final List<FakeTimer> made = [];
  Timer call(Duration d, void Function() fire) {
    final t = FakeTimer(d, fire);
    made.add(t);
    return t;
  }

  /// The one poll scheduled now, or null.
  FakeTimer? get active {
    final live = made.where((t) => t.isActive).toList();
    return live.isEmpty ? null : live.last;
  }
}

/// Let every pending request and microtask run.
Future<void> settle() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}
