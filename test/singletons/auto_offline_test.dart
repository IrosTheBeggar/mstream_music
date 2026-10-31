import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:library_mirror/library_mirror.dart';
import 'package:path/path.dart' as p;

import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/singletons/library_index.dart';
import 'package:mstream_music/singletons/server_list.dart';

/// A proxy configured on the host would answer for any address (an HTTP
/// error is still an answer): go direct, so a closed port refuses outright.
class _NoProxy extends HttpOverrides {
  @override
  String findProxyFromEnvironment(Uri url, Map<String, String>? environment) =>
      'DIRECT';
}

/// A port nothing listens on: bound once and released.
Future<int> _closedPort() async {
  final sock = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  final port = sock.port;
  await sock.close();
  return port;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory tmp;
  late int port;
  setUp(() async {
    HttpOverrides.global = _NoProxy();
    port = await _closedPort();
    tmp = Directory.systemTemp.createTempSync('auto_offline_');
    await LibraryIndexManager().open(path: p.join(tmp.path, 'index.db'));
    ServerManager.autoOfflineRetry = const Duration(seconds: 3);
  });
  tearDown(() {
    HttpOverrides.global = null;
    ServerManager.autoOfflineRetry = const Duration(seconds: 6);
    ServerManager().serverList.clear();
    LibraryIndexManager().close();
    try {
      tmp.deleteSync(recursive: true);
    } catch (_) {}
  });

  test('one failed ping only schedules a retry; the retry failing switches to the copy', () async {
    // A closed port refuses at once: every ping fails fast.
    final s = Server('http://127.0.0.1:$port', null, null, null, 'home');
    ServerManager().serverList.add(s);
    LibraryIndexManager().index!.upsertTracks(
        'home', [const RemoteTrack(id: 1, path: '/m/a.mp3')], 'r1');

    await ServerManager().getServerPaths(s);
    expect(s.browseOffline, isFalse, reason: 'a suspicion, not a verdict');
    expect(s.offlineAuto, isFalse);

    // A second failure while the retry is still due changes nothing.
    await ServerManager().getServerPaths(s);
    expect(s.browseOffline, isFalse);

    await Future<void>.delayed(const Duration(milliseconds: 4500));
    expect(s.browseOffline, isTrue, reason: 'the retry failed too');
    expect(s.offlineAuto, isTrue);
  });

  test('the network coming back asks again only the servers the copy stands in for', () async {
    // One listener per server, so each one's pings are counted apart.
    final hits = <String, int>{};
    final listeners = <HttpServer>[];
    Future<Server> serverNamed(String name) async {
      final http = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      listeners.add(http);
      http.listen((req) {
        hits[name] = (hits[name] ?? 0) + 1;
        req.response
          ..statusCode = 503
          ..close();
      });
      return Server('http://127.0.0.1:${http.port}', null, null, null, name);
    }

    final away = (await serverNamed('away'))
      ..browseOffline = true
      ..offlineAuto = true;
    final chosen = (await serverNamed('chosen'))..browseOffline = true;
    final online = await serverNamed('online');
    ServerManager().serverList.addAll([away, chosen, online]);

    ServerManager().recheckOffline();
    await Future<void>.delayed(const Duration(milliseconds: 800));
    expect(hits['away'], greaterThan(0), reason: 'switched automatically: asked');
    expect(hits['chosen'], isNull, reason: 'browsed by choice: left alone');
    expect(hits['online'], isNull, reason: 'not on the copy at all');
    // Any HTTP answer, an error included, means the server is there again.
    expect(away.offlineAuto, isFalse, reason: 'it answered: back online');
    expect(away.browseOffline, isFalse);
    expect(chosen.browseOffline, isTrue);
    for (final l in listeners) {
      await l.close(force: true);
    }
  });

  test('without index rows a failed ping never switches', () async {
    final s = Server('http://127.0.0.1:$port', null, null, null, 'empty');
    ServerManager().serverList.add(s);
    await ServerManager().getServerPaths(s);
    await Future<void>.delayed(const Duration(milliseconds: 3500));
    expect(s.browseOffline, isFalse);
  });
}
