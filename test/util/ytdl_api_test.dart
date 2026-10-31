// YtdlApi against a MockClient: each route's request on the wire (method,
// path — the add's own trailing slash included — headers, body keys, query
// encoding), its answer read (the lookup's numeric year as a string, the
// download record narrowed to the ytdl rows), the status and the server's
// words kept on every failure (a JSON 404 told from Express's HTML one), a
// client bound that runs out read as status 0 + timedOut, and the retry
// rule: a call with no answer over a tunnel is sent once more after the
// tunnel is back — never the add, which would start a second download.

import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/singletons/api.dart';
import 'package:mstream_music/util/ytdl_api.dart';

final home = Server('http://music.example', null, null, 'JWT', 'home')
  ..autoDJPaths = {'Music': true};

/// A Quick Connect server with its tunnel up: every request rides the
/// loopback with the tunnel's token.
Server irohServer() => Server('iroh://home', null, null, 'JWT', 'qc')
  ..connectionType = 'iroh'
  ..tunnelPort = 4242
  ..tunnelToken = 'tok';

http.Response json(Object body, [int status = 200]) => http.Response(
    jsonEncode(body), status,
    headers: {'content-type': 'application/json'});

/// Express's own answer for a route it does not have.
http.Response html404() => http.Response(
    '<!DOCTYPE html><html><body><pre>Cannot GET /api/v1/discovery/downloads</pre></body></html>',
    404,
    headers: {'content-type': 'text/html; charset=utf-8'});

const link = 'https://www.youtube.com/watch?v=FGBhQbmPwH8';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<http.Request> seen;
  late Future<http.Response> Function(http.Request) handler;
  late int tunnelWaits;
  late bool tunnelBack;

  YtdlApi api(
          [Server? s,
          Duration timeout = const Duration(seconds: 30),
          Duration irohTry = const Duration(seconds: 20)]) =>
      YtdlApi(s ?? home,
          client: MockClient((req) async {
            seen.add(req);
            return handler(req);
          }),
          timeout: timeout,
          irohTry: irohTry, awaitTunnel: (_) async {
        tunnelWaits++;
        return tunnelBack;
      });

  setUp(() {
    seen = [];
    handler = (_) async => json({});
    tunnelWaits = 0;
    tunnelBack = true;
  });

  group('the lookup', () {
    test('GETs the metadata route with the link as one encoded query value',
        () async {
      handler = (_) async => json({
            'title': 'One More Time',
            'artist': 'Daft Punk - Topic',
            'album': 'Discovery',
            'year': 2001,
            'thumbnail': 'https://i.ytimg.com/vi/FGBhQbmPwH8/hq.jpg',
          });
      const asked = 'https://www.youtube.com/watch?v=FGBhQbmPwH8&list=RD1#t=3';
      final m = await api().metadata(asked);
      final req = seen.single;
      expect(req.method, 'GET');
      expect(req.url.path, '/api/v1/ytdl/metadata');
      expect(req.url.queryParameters, {'url': asked},
          reason: 'the link\'s own ? & = # stay inside the one value');
      expect(req.url.query,
          'url=https%3A%2F%2Fwww.youtube.com%2Fwatch%3Fv%3DFGBhQbmPwH8%26list%3DRD1%23t%3D3');
      expect(req.headers['x-access-token'], 'JWT');
      expect(m.title, 'One More Time');
      expect(m.artist, 'Daft Punk - Topic');
      expect(m.album, 'Discovery');
      expect(m.year, '2001', reason: 'release_year arrives as a number');
      expect(m.thumbnail, 'https://i.ytimg.com/vi/FGBhQbmPwH8/hq.jpg');
    });

    test('every key may be null; empty strings read as null', () async {
      handler = (_) async => json({
            'title': 'Gorillaz - Feel Good Inc. (Official Video) [HD]',
            'artist': 'Gorillaz',
            'album': null,
            'year': null,
            'thumbnail': '',
          });
      final m = await api().metadata(link);
      expect(m.title, 'Gorillaz - Feel Good Inc. (Official Video) [HD]');
      expect(m.album, isNull);
      expect(m.year, isNull);
      expect(m.thumbnail, isNull);
    });

    test('a year as a string stays as sent; a fraction or junk is no year',
        () async {
      for (final (wire, read) in [
        ('2005', '2005'),
        (2005.0, '2005'),
        (2005.5, null),
        (true, null),
        ([2005], null),
      ]) {
        handler = (_) async => json({'title': 't', 'year': wire});
        expect((await api().metadata(link)).year, read, reason: '$wire');
      }
    });

    test('a 200 this client cannot read throws with that status, no words',
        () async {
      handler = (_) async => http.Response('<html>ok</html>', 200);
      await expectLater(
          api().metadata(link),
          throwsA(isA<YtdlApiException>()
              .having((e) => e.status, 'status', 200)
              .having((e) => e.message, 'message', '')
              .having((e) => e.fromServer, 'fromServer', isFalse)));
      handler = (_) async => json(['not', 'a', 'map']);
      await expectLater(api().metadata(link),
          throwsA(isA<YtdlApiException>().having((e) => e.status, 'status', 200)));
    });
  });

  group('the add', () {
    test('POSTs /api/v1/ytdl/ — the trailing slash is the route\'s', () async {
      handler = (_) async => json({'message': 'Download started'});
      await api().add(
        directory: '/Music/Daft Punk/Discovery/',
        url: link,
        codec: 'mp3',
        metadata: const {
          'title': 'One More Time',
          'artist': 'Daft Punk',
          'album': 'Discovery',
          'year': '2001',
        },
      );
      final req = seen.single;
      expect(req.method, 'POST');
      expect(req.url.toString(), 'http://music.example/api/v1/ytdl/');
      expect(req.headers['content-type'], startsWith('application/json'));
      expect(req.headers['x-access-token'], 'JWT');
      expect(jsonDecode(req.body), {
        'directory': '/Music/Daft Punk/Discovery/',
        'url': link,
        'outputCodec': 'mp3',
        'metadata': {
          'title': 'One More Time',
          'artist': 'Daft Punk',
          'album': 'Discovery',
          'year': '2001',
        },
      });
    });

    test('only non-blank tags, only the four keys the schema takes', () async {
      await api().add(
        directory: '/Music/',
        url: link,
        codec: 'opus',
        metadata: const {
          'title': 'Feel Good Inc.',
          'artist': '',
          'album': '   ',
          'genre': 'Pop',
        },
      );
      expect(jsonDecode(seen.single.body)['metadata'], {'title': 'Feel Good Inc.'},
          reason: 'Joi refuses an unknown key, and with it the whole add');
    });

    test('no tags left: no metadata key at all', () async {
      await api().add(
          directory: '/Music/',
          url: link,
          codec: 'mp3',
          metadata: const {'title': '', 'year': ''});
      final body = jsonDecode(seen.single.body) as Map;
      expect(body.keys, unorderedEquals(['directory', 'url', 'outputCodec']));
      await api().add(directory: '/Music/', url: link, codec: 'mp3');
      expect((jsonDecode(seen.last.body) as Map).containsKey('metadata'), isFalse);
    });

    test('any 2xx is "started", whatever its body', () async {
      handler = (_) async => http.Response('Download started', 200);
      await api().add(directory: '/Music/', url: link, codec: 'mp3');
      handler = (_) async => http.Response('', 204);
      await api().add(directory: '/Music/', url: link, codec: 'mp3');
      expect(seen, hasLength(2));
    });

    test("a refusal keeps the status and the server's words", () async {
      for (final (status, words) in [
        (403, 'Uploading Disabled'),
        (500, 'FFmpeg is not available yet'),
        (500, 'yt-dlp is not installed'),
        (400, '"outputCodec" must be one of [mp3, flac, wav, ogg, aac, m4a, m4b, opus]'),
        (404, "Library 'Music' not found"),
        (404, 'User does not have access to path Music'),
        (500, 'Server Error'),
      ]) {
        handler = (_) async => json({'error': words}, status);
        await expectLater(
            api().add(directory: '/Music/', url: link, codec: 'mp3'),
            throwsA(isA<YtdlApiException>()
                .having((e) => e.status, 'status', status)
                .having((e) => e.message, 'message', words)
                .having((e) => e.fromServer, 'fromServer', isTrue)
                .having((e) => e.timedOut, 'timedOut', isFalse)));
      }
    });
  });

  group('the tracker', () {
    test('GETs /api/v1/ytdl/downloads and reads every usable entry', () async {
      handler = (_) async => json({
            'downloads': [
              {
                'pid': 4711,
                'url': link,
                'directory': '/Music/Daft Punk/Discovery/',
                'outputCodec': 'mp3',
                'status': 'downloading',
                'startTime': 1793450000000,
              },
              {
                'pid': 4712,
                'url': 'https://www.youtube.com/watch?v=HyHNuVaZJ-k',
                'directory': '/Music/',
                'outputCodec': 'opus',
                'status': 'complete',
                'startTime': 1793450001000,
              },
              {'pid': 'x', 'url': link, 'directory': '/Music/'},
              {'url': link, 'directory': '/Music/'},
              'junk',
            ]
          });
      final jobs = await api().jobs();
      expect(seen.single.method, 'GET');
      expect(seen.single.url.path, '/api/v1/ytdl/downloads');
      expect(jobs, hasLength(2));
      expect(jobs.first.pid, 4711);
      expect(jobs.first.url, link);
      expect(jobs.first.directory, '/Music/Daft Punk/Discovery/');
      expect(jobs.first.outputCodec, 'mp3');
      expect(jobs.first.downloading, isTrue);
      expect(jobs.first.startTime, 1793450000000);
      expect(jobs.last.complete, isTrue);
      expect(jobs.last.failed, isFalse);
    });

    test('an unknown status is kept raw; an empty tracker is an empty list',
        () async {
      handler = (_) async => json({
            'downloads': [
              {'pid': 1, 'url': link, 'directory': '/Music/', 'status': 'paused'}
            ]
          });
      final job = (await api().jobs()).single;
      expect(job.status, 'paused');
      expect([job.downloading, job.complete, job.failed], [false, false, false]);
      expect(job.outputCodec, '');
      expect(job.startTime, 0);
      handler = (_) async => json({'downloads': []});
      expect(await api().jobs(), isEmpty);
      handler = (_) async => json({});
      expect(await api().jobs(), isEmpty);
    });
  });

  group('folders', () {
    test('a listing POSTs the folder without metadata and reads names', () async {
      handler = (_) async => json({
            'path': '/Music/Daft Punk/',
            'directories': [
              {'name': 'Discovery'},
              {'name': 'Homework'},
            ],
            'files': [
              {'type': 'mp3', 'name': 'One_More_Time.mp3'},
              {'type': 'm3u', 'name': 'favs.m3u'},
              {'type': 'mp3'},
            ],
          });
      final l = await api().list('/Music/Daft Punk');
      final req = seen.single;
      expect(req.method, 'POST');
      expect(req.url.path, '/api/v1/file-explorer');
      expect(req.headers['content-type'], startsWith('application/json'));
      expect(jsonDecode(req.body),
          {'directory': '/Music/Daft Punk', 'pullMetadata': false});
      expect(l.path, '/Music/Daft Punk/');
      expect(l.directories, ['Discovery', 'Homework']);
      expect(l.files, ['One_More_Time.mp3', 'favs.m3u']);
    });

    test('a listing with no path names the folder asked for', () async {
      handler = (_) async => json({'directories': [], 'files': []});
      expect((await api().list('/Music/')).path, '/Music/');
    });

    test('a folder that is not there: 404 with the server\'s words', () async {
      handler = (_) async =>
          json({'error': 'Cannot read directory "/Music/Nope/" (ENOENT)'}, 404);
      await expectLater(
          api().list('/Music/Nope/'),
          throwsA(isA<YtdlApiException>()
              .having((e) => e.status, 'status', 404)
              .having((e) => e.fromServer, 'fromServer', isTrue)
              .having((e) => e.message, 'message',
                  'Cannot read directory "/Music/Nope/" (ENOENT)')));
    });

    test('mkdir POSTs {directory} only; any 2xx means the folder is there',
        () async {
      await api().mkdir('/Music/Daft Punk/Discovery/');
      final req = seen.single;
      expect(req.method, 'POST');
      expect(req.url.path, '/api/v1/file-explorer/mkdir');
      expect(jsonDecode(req.body), {'directory': '/Music/Daft Punk/Discovery/'});
      handler = (_) async => http.Response('', 200);
      await api().mkdir('/Music/x/');
    });

    test("mkdir's 403 keeps its words", () async {
      handler = (_) async => json({'error': 'Create Folder Disabled'}, 403);
      await expectLater(
          api().mkdir('/Music/x/'),
          throwsA(isA<YtdlApiException>()
              .having((e) => e.status, 'status', 403)
              .having((e) => e.message, 'message', 'Create Folder Disabled')));
    });
  });

  group('the download record', () {
    Map<String, dynamic> row(int id, String plugin, {String? origin}) => {
          'id': id,
          'plugin': plugin,
          'userId': 3,
          'jobId': plugin == 'ytdl' ? null : 12,
          'vpath': 'Music',
          'filepath': 'Music/Daft Punk/Discovery/One_More_Time.mp3',
          'relativePath': 'Daft Punk/Discovery/One_More_Time.mp3',
          'fileHash': 'abc',
          'origin': origin ?? link,
          'title': 'One More Time',
          'artist': 'Daft Punk',
          'album': 'Discovery',
          'bytes': 8400000,
          'downloadedAt': 1793450100000,
          'removedAt': null,
          'removedBy': null,
          'present': true,
          'trackId': 991,
        };

    test('GETs limit=20 by default, then before=<id> for older rows',
        () async {
      handler = (_) async => json({'downloads': []});
      await api().records();
      expect(seen.last.method, 'GET');
      expect(seen.last.url.path, '/api/v1/discovery/downloads');
      expect(seen.last.url.query, 'limit=20');
      await api().records(limit: 5, before: 42);
      expect(seen.last.url.queryParameters, {'limit': '5', 'before': '42'});
      await api().records(limit: 0);
      expect(seen.last.url.queryParameters['limit'], '1');
      await api().records(limit: 900);
      expect(seen.last.url.queryParameters['limit'], '500',
          reason: 'the route refuses more than 500');
      expect(seen.every((r) => r.headers['x-access-token'] == 'JWT'), isTrue);
    });

    test('only the ytdl rows, every field read', () async {
      handler = (_) async => json({
            'downloads': [
              row(9, 'ytdl'),
              row(8, 'youtube'),
              row(7, 'federation-copy'),
              {...row(6, 'ytdl'), 'present': false, 'trackId': null, 'bytes': null},
              {'plugin': 'ytdl'},
            ]
          });
      final rows = (await api().records())!;
      expect(rows.map((r) => r.id), [9, 6]);
      final r = rows.first;
      expect(r.vpath, 'Music');
      expect(r.filepath, 'Music/Daft Punk/Discovery/One_More_Time.mp3');
      expect(r.relativePath, 'Daft Punk/Discovery/One_More_Time.mp3');
      expect(r.origin, link);
      expect([r.title, r.artist, r.album], ['One More Time', 'Daft Punk', 'Discovery']);
      expect(r.bytes, 8400000);
      expect(r.downloadedAt, 1793450100000);
      expect(r.present, isTrue);
      expect(r.trackId, 991);
      expect(rows.last.present, isFalse);
      expect(rows.last.trackId, isNull);
      expect(rows.last.bytes, isNull);
    });

    test("Express's HTML 404 is a server before 6.30: null, not an error",
        () async {
      handler = (_) async => html404();
      expect(await api().records(), isNull);
      handler = (_) async => http.Response('', 404);
      expect(await api().records(), isNull);
    });

    test('a 404 carrying the server\'s words, a 403 and a 500 throw',
        () async {
      handler = (_) async => json({'error': 'download not found'}, 404);
      await expectLater(api().records(),
          throwsA(isA<YtdlApiException>().having((e) => e.status, 'status', 404)));
      handler = (_) async =>
          json({'error': 'not available in a jukebox session'}, 403);
      await expectLater(
          api().records(),
          throwsA(isA<YtdlApiException>().having(
              (e) => e.message, 'message', 'not available in a jukebox session')));
      handler = (_) async => json({'error': 'Server Error'}, 500);
      await expectLater(api().records(),
          throwsA(isA<YtdlApiException>().having((e) => e.status, 'status', 500)));
    });
  });

  group('failures keep the status and the body', () {
    test("a JSON 404 has the server's words; Express's HTML 404 has none",
        () async {
      handler = (_) async => json({'error': "Library 'Music' not found"}, 404);
      await expectLater(
          api().add(directory: '/Music/', url: link, codec: 'mp3'),
          throwsA(isA<YtdlApiException>()
              .having((e) => e.fromServer, 'fromServer', isTrue)
              .having((e) => e.message, 'message', "Library 'Music' not found")));
      handler = (_) async => html404();
      await expectLater(
          api().add(directory: '/Music/', url: link, codec: 'mp3'),
          throwsA(isA<YtdlApiException>()
              .having((e) => e.status, 'status', 404)
              .having((e) => e.fromServer, 'fromServer', isFalse)
              .having((e) => e.message, 'message', '')));
    });

    test('a body with no usable error text has no words', () async {
      for (final res in [
        http.Response('', 502),
        json({'message': 'nope'}, 500),
        json({'error': '  '}, 500),
        json({'error': 42}, 500),
      ]) {
        handler = (_) async => res;
        await expectLater(
            api().jobs(),
            throwsA(isA<YtdlApiException>()
                .having((e) => e.status, 'status', res.statusCode)
                .having((e) => e.message, 'message', '')
                .having((e) => e.fromServer, 'fromServer', isFalse)));
      }
    });

    test('the bound running out: status 0, timedOut', () async {
      handler = (_) => Completer<http.Response>().future; // never answers
      await expectLater(
          api(null, const Duration(milliseconds: 20)).metadata(link),
          throwsA(isA<YtdlApiException>()
              .having((e) => e.status, 'status', 0)
              .having((e) => e.timedOut, 'timedOut', isTrue)
              .having((e) => e.message, 'message', '')));
    });

    test('a transport failure: status 0, not a timeout, the cause kept',
        () async {
      handler = (_) async => throw http.ClientException('Connection refused');
      await expectLater(
          api().jobs(),
          throwsA(isA<YtdlApiException>()
              .having((e) => e.status, 'status', 0)
              .having((e) => e.timedOut, 'timedOut', isFalse)
              .having((e) => e.cause, 'cause', isA<http.ClientException>())));
    });
  });

  group('retries', () {
    test('plain HTTP never retries, a GET included', () async {
      handler = (_) async => throw http.ClientException('reset');
      await expectLater(api().metadata(link), throwsA(isA<YtdlApiException>()));
      expect(seen, hasLength(1));
      expect(tunnelWaits, 0);
    });

    test('over a tunnel: a GET with no answer is sent once more, on the '
        'loopback with its token', () async {
      var calls = 0;
      handler = (_) async {
        if (calls++ == 0) throw http.ClientException('tunnel reset');
        return json({'title': 'One More Time', 'year': 2001});
      };
      final m = await api(irohServer()).metadata(link);
      expect(m.year, '2001');
      expect(seen, hasLength(2));
      expect(tunnelWaits, 1);
      for (final req in seen) {
        expect(req.url.host, '127.0.0.1');
        expect(req.url.port, 4242);
        expect(req.url.queryParameters, {'url': link, '__lt': 'tok'});
      }
    });

    test('over a tunnel the add is NEVER sent twice — no answer, or a timeout',
        () async {
      handler = (_) async => throw http.ClientException('tunnel reset');
      await expectLater(
          api(irohServer()).add(directory: '/Music/', url: link, codec: 'mp3'),
          throwsA(isA<YtdlApiException>()
              .having((e) => e.status, 'status', 0)
              .having((e) => e.timedOut, 'timedOut', isFalse)));
      expect(seen, hasLength(1));
      expect(tunnelWaits, 0, reason: 'nothing to wait for: no second send');

      seen.clear();
      handler = (_) => Completer<http.Response>().future;
      await expectLater(
          api(irohServer(), const Duration(seconds: 30),
                  const Duration(milliseconds: 20))
              .add(directory: '/Music/', url: link, codec: 'mp3'),
          throwsA(isA<YtdlApiException>().having((e) => e.timedOut, 'timedOut', isTrue)));
      expect(seen, hasLength(1));
      expect(tunnelWaits, 0);
    });

    test('the tracker, a listing, mkdir and the record retry once too',
        () async {
      final calls = <String, int>{};
      handler = (req) async {
        final n = calls[req.url.path] = (calls[req.url.path] ?? 0) + 1;
        if (n == 1) throw http.ClientException('tunnel reset');
        return req.url.path.endsWith('/file-explorer')
            ? json({'path': '/Music/', 'directories': [], 'files': []})
            : json({'downloads': []});
      };
      final a = api(irohServer());
      await a.jobs();
      await a.list('/Music/');
      await a.mkdir('/Music/New/');
      await a.records();
      expect(calls, {
        '/api/v1/ytdl/downloads': 2,
        '/api/v1/file-explorer': 2,
        '/api/v1/file-explorer/mkdir': 2,
        '/api/v1/discovery/downloads': 2,
      });
      expect(tunnelWaits, 4);
    });

    test('a tunnel that does not come back: no second send', () async {
      tunnelBack = false;
      handler = (_) async => throw http.ClientException('tunnel reset');
      await expectLater(
          api(irohServer()).jobs(),
          throwsA(isA<YtdlApiException>().having((e) => e.status, 'status', 0)));
      expect(seen, hasLength(1));
      expect(tunnelWaits, 1);
    });

    test("an HTTP error is the server's answer: not retried", () async {
      handler = (_) async => json({'error': 'Server Error'}, 500);
      await expectLater(api(irohServer()).metadata(link),
          throwsA(isA<YtdlApiException>().having((e) => e.status, 'status', 500)));
      expect(seen, hasLength(1));
      expect(tunnelWaits, 0);
    });

    test('over a tunnel each try is bounded by irohTry; a second timeout '
        'stands', () async {
      handler = (_) => Completer<http.Response>().future;
      await expectLater(
          api(irohServer(), const Duration(seconds: 30),
                  const Duration(milliseconds: 20))
              .jobs(),
          throwsA(isA<YtdlApiException>()
              .having((e) => e.status, 'status', 0)
              .having((e) => e.timedOut, 'timedOut', isTrue)));
      expect(seen, hasLength(2));
    });

    test('with no wait injected it asks ServerManager (no tunnel to wait for '
        'in a test VM: true at once)', () async {
      var calls = 0;
      final a = YtdlApi(irohServer(), client: MockClient((req) async {
        seen.add(req);
        if (calls++ == 0) throw http.ClientException('tunnel reset');
        return json({'downloads': []});
      }));
      expect(await a.jobs(), isEmpty);
      expect(seen, hasLength(2));
    });
  });

  group('the server it is given', () {
    test("a peer stays the peer — never swapped for its parent", () async {
      final peer = Server('federated://home/1', null, null, null, 'peer-1')
        ..federationParent = 'home'
        ..federationPeerId = 1
        ..parentServer = home;
      final a = api(peer);
      expect(identical(a.server, peer), isTrue);
      handler = (_) async => json({'downloads': []});
      await a.jobs();
      expect(seen.single.url.path,
          '/api/v1/federation/peers/1/api/api/v1/ytdl/downloads',
          reason: "the peer's own route, through its parent's proxy");
    });

    test("ApiManager's pooled client by default", () async {
      final pooled = <http.Request>[];
      try {
        await http.runWithClient(() async {
          ApiManager().resetDirectClient();
          await YtdlApi(home).jobs();
        }, () => MockClient((req) async {
              pooled.add(req);
              return json({'downloads': []});
            }));
      } finally {
        ApiManager().resetDirectClient();
      }
      expect(pooled.single.url.toString(),
          'http://music.example/api/v1/ytdl/downloads');
    });
  });
}
