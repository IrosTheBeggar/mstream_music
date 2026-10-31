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

  test('without index rows a failed ping never switches', () async {
    final s = Server('http://127.0.0.1:$port', null, null, null, 'empty');
    ServerManager().serverList.add(s);
    await ServerManager().getServerPaths(s);
    await Future<void>.delayed(const Duration(milliseconds: 3500));
    expect(s.browseOffline, isFalse);
  });
}
