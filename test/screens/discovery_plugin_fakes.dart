// A scripted mStream plug-in API for the Discover jobs tests: the listing,
// the destination, the job list, starts, cancels, clear and the batch
// lookup — each answered from state the test sets, every request recorded.
// The batch lookup answers as the server's does: each recommendation's
// keys, and the caller's jobs under any of them, with album and artist keys
// that carry no server (two connected servers' "Borrowed Tapes" share one).
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

/// The server's jobKeysFor, in shape.
Map<String, String> fakeKeysOf(Map rec, [String? scope]) {
  final keys = <String, String>{
    'song': 'text:${_norm(rec['artist'])}|${_norm(rec['title'])}|${_norm(rec['album'])}',
    if (_has(rec['album']))
      'album': 'album:${_norm(_has(rec['albumArtist']) ? rec['albumArtist'] : rec['artist'])}|${_norm(rec['album'])}',
    if (_has(rec['artist'])) 'artist': 'artist:${_norm(rec['artist'])}',
    if (_has(rec['artist'])) 'artist-missing': 'artist-missing:${_norm(rec['artist'])}',
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

class FakePluginServer {
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
    'variables': ['ARTIST', 'ALBUM', 'YEAR', 'GENRE', 'ALBUMARTIST', 'PEER'],
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

  int count(String method, String pathSuffix) =>
      requests.where((r) => r.method == method && r.url.path.endsWith(pathSuffix)).length;

  List<http.Request> calls(String method, String pathSuffix) =>
      requests.where((r) => r.method == method && r.url.path.endsWith(pathSuffix)).toList();

  Map<String, dynamic> job(int id) => jobs.firstWhere((j) => j['id'] == id);

  Map<String, dynamic> addJob(Map rec, {String? scope, String state = 'queued', int? id, Map<String, dynamic>? result, double? progress, String? statusText}) {
    final j = <String, dynamic>{
      'id': id ?? _nextId++,
      'plugin': 'federation-copy',
      'key': fakeKeysOf(rec)[scope ?? 'song'],
      'recommendation': rec,
      'params': scope == null || scope == 'song' ? null : {'scope': scope},
      'state': state,
      'progress': progress,
      'statusText': statusText,
      'result': result,
      'error': null,
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
        destination = {
          ...destination,
          'destination': d == null
              ? {'vpath': 'copies', 'base': '', 'layout': '{{ALBUMARTIST}}/{{ALBUM}}', 'source': 'default'}
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
    if (req.method == 'POST' && path.endsWith('/plugins/federation-copy/jobs')) {
      if (startGate != null) await startGate!.future;
      final body = jsonDecode(req.body) as Map;
      final answer = startAnswer;
      if (answer != null) return _json(answer.$2, answer.$1);
      final shown = body.containsKey('destination');
      if (shown && rejectsDestination) {
        return _json({'error': '"destination" is not allowed'}, 400);
      }
      if (existing != null) return _json({'job': existing, 'created': false});
      // The jobs route's check: the place the client showed must still be
      // where files land; every new job is pinned to the one in force.
      final effective = destination['destination'] as Map?;
      if (shown && !fakeSamePlace(body['destination'] as Map?, effective)) {
        return _json({
          'error': 'destination_changed',
          'message': 'your collection destination has changed — check where this will land and ask again',
          'destination': effective,
        }, 409);
      }
      final j = addJob(body['recommendation'] as Map, scope: body['scope'] as String?);
      j['params'] = {...?j['params'] as Map?, 'destination': effective};
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
        'results': [
          for (final r in recs)
            () {
              final keys = fakeKeysOf(r as Map);
              final own = keys.values.toSet();
              // the newest job per plug-in and scope under any key
              final seen = <String>{};
              final mine = <Map<String, dynamic>>[];
              for (final j in jobs) {
                if (!own.contains(j['key'])) continue;
                final slot = '${j['plugin']}@${(j['params'] as Map?)?['scope'] ?? 'song'}';
                if (seen.add(slot)) mine.add(j);
              }
              return {'key': keys['song'], 'keys': keys, 'jobs': mine};
            }(),
        ]
      });
    }
    return _json({'error': 'no route $path'}, 404);
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
