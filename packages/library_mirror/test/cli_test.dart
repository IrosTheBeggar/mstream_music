import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:library_mirror/library_mirror.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// A tiny mStream: one library with two files, no art, empty lists.
class FakeMStream {
  final Map<String, List<int>> files = {
    '/music/a.mp3': utf8.encode('abc'),
    '/music/b.mp3': utf8.encode('defg'),
  };
  String revision = 'r1';
  int manifestCalls = 0;
  int mediaCalls = 0;

  Future<http.Response> handle(http.Request r) async {
    final path = Uri.decodeComponent(r.url.path);
    if (path.endsWith('/sync/manifest')) {
      manifestCalls++;
      if (r.headers['If-None-Match'] == '"$revision"') {
        return http.Response('', 304);
      }
      var id = 0;
      return http.Response(
          jsonEncode({
            'revision': revision,
            'scanning': false,
            'next': null,
            'entries': [
              for (final e in files.entries)
                {
                  'filepath': e.key.substring(1),
                  'id': ++id,
                  'file-size': e.value.length,
                  'modified': 1700000000000,
                  'hash': md5.convert(e.value).toString(),
                  'hash-v': 2,
                  'metadata': {'title': p.basename(e.key)},
                }
            ],
          }),
          200);
    }
    if (path.startsWith('/media/')) {
      mediaCalls++;
      final bytes = files[path.substring('/media'.length)];
      return bytes == null
          ? http.Response('nope', 404)
          : http.Response.bytes(bytes, 200);
    }
    if (path.endsWith('/db/albums')) return http.Response('{"albums":[]}', 200);
    if (path.endsWith('/db/artists')) return http.Response('{"artists":[]}', 200);
    if (path.endsWith('/db/genres')) return http.Response('{"genres":[]}', 200);
    if (path.endsWith('/playlist/getall')) return http.Response('[]', 200);
    if (path.endsWith('/db/rated')) return http.Response('[]', 200);
    return http.Response('unknown $path', 404);
  }
}

void main() {
  test('parseRule accepts kind:key and rejects the rest', () {
    expect(parseRule('library:music'), (kind: 'library', key: 'music'));
    expect(parseRule('album:Be Somebody'), (kind: 'album', key: 'Be Somebody'));
    expect(parseRule('folder:/music/Live: 1999'),
        (kind: 'folder', key: '/music/Live: 1999'));
    expect(() => parseRule('music'), throwsFormatException);
    expect(() => parseRule('genre:Rock'), throwsFormatException);
    expect(() => parseRule('album:'), throwsFormatException);
  });

  test('--help and missing arguments', () async {
    final out = StringBuffer();
    final err = StringBuffer();
    expect(await runCli(['--help'], out: out, err: err), CliExit.ok);
    expect(out.toString(), contains('--server'));
    expect(await runCli(['--dest', 'x'], out: out, err: err), CliExit.fatal);
    expect(err.toString(), contains('--server and --dest are required'));
  });

  test('a copy from the command line: first run, 304 run, a dropped rule', () async {
    final tmp = Directory.systemTemp.createTempSync('cli_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final srv = FakeMStream();
    final client = MockClient(srv.handle);
    final base = ['--server', 'http://h:3000', '--dest', tmp.path, '--name', 's', '--quiet'];
    final out = StringBuffer();
    final err = StringBuffer();

    expect(await runCli([...base, '--keep', 'library:music'], client: client, out: out, err: err),
        CliExit.ok, reason: err.toString());
    expect(out.toString(), contains('2 new'));
    expect(File(p.join(tmp.path, 'media', 's', 'music', 'a.mp3')).readAsStringSync(), 'abc');
    expect(File(p.join(tmp.path, 'media', 's', 'music', 'b.mp3')).readAsStringSync(), 'defg');
    expect(File(p.join(tmp.path, '.mstream-index.db')).existsSync(), isTrue);
    expect(srv.mediaCalls, 2);

    // The rule lives in the index: a bare second run is one 304 and nothing else.
    out.clear();
    expect(await runCli(base, client: client, out: out, err: err), CliExit.ok);
    expect(out.toString(), contains('0 new'));
    expect(out.toString(), contains('2 unchanged'));
    expect(srv.mediaCalls, 2);

    out.clear();
    expect(await runCli([...base, '--list-rules'], client: client, out: out, err: err), CliExit.ok);
    expect(out.toString().trim(), 'library:music');

    // Dropping the rule trashes the copy, into the dated bucket.
    out.clear();
    expect(await runCli([...base, '--drop', 'library:music'], client: client, out: out, err: err), CliExit.ok);
    expect(out.toString(), contains('2 trashed'));
    expect(File(p.join(tmp.path, 'media', 's', 'music', 'a.mp3')).existsSync(), isFalse);
    expect(Directory(p.join(tmp.path, '.mstream-trash', 's')).listSync(), isNotEmpty);
  });

  test('an unreachable server is a fatal exit with the reason on stderr', () async {
    final tmp = Directory.systemTemp.createTempSync('cli_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final client = MockClient((_) async => throw const SocketException('down'));
    final out = StringBuffer();
    final err = StringBuffer();
    expect(await runCli(['--server', 'http://h', '--dest', tmp.path, '--quiet'],
        client: client, out: out, err: err), CliExit.fatal);
    expect(out.toString(), contains('failed:'));
  });
}
