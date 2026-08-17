import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/singletons/server_list.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('mstream/insecure_tls');
  final calls = <MethodCall>[];

  Server server(String url, {bool selfSigned = false}) {
    final s = Server(url, 'user', 'pw', 'jwt', 'local-$url');
    s.allowSelfSigned = selfSigned;
    return s;
  }

  setUp(() {
    calls.clear();
    ServerManager().serverList.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return null;
    });
  });

  tearDown(() {
    ServerManager().serverList.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  group('ServerManager.syncInsecureTls', () {
    test('sends only the hosts of servers that opted into self-signed',
        () async {
      ServerManager().serverList.addAll([
        server('https://valid.example.com'), // no opt-in → must NOT be sent
        server('https://Self1.Example.com:8443', selfSigned: true),
        server('https://192.168.1.7:3000', selfSigned: true),
        server('iroh://abcdef0123'), // iroh, no opt-in
      ]);

      ServerManager().syncInsecureTls();
      await pumpEventQueue();

      expect(calls, hasLength(1));
      expect(calls.single.method, 'setAllowedHosts');
      final hosts =
          (calls.single.arguments['hosts'] as List).cast<String>().toSet();
      // Uri.parse lowercases the host; the valid-cert and iroh servers are
      // excluded — this is the per-host scoping the fix is about.
      expect(hosts, {'self1.example.com', '192.168.1.7'});
    });

    test('duplicate hosts are sent once', () async {
      ServerManager().serverList.addAll([
        server('https://nas.local:8443', selfSigned: true),
        server('https://nas.local:9443', selfSigned: true),
      ]);

      ServerManager().syncInsecureTls();
      await pumpEventQueue();

      expect(
          (calls.single.arguments['hosts'] as List).cast<String>(),
          ['nas.local']);
    });

    test('no opted-in servers → empty host list (restores platform TLS)',
        () async {
      ServerManager().serverList.add(server('https://valid.example.com'));

      ServerManager().syncInsecureTls();
      await pumpEventQueue();

      expect(calls.single.method, 'setAllowedHosts');
      expect(calls.single.arguments['hosts'], isEmpty);
    });

    test('missing native handler is swallowed (Play build / iOS / tests)',
        () async {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null); // no handler registered
      ServerManager()
          .serverList
          .add(server('https://nas.local', selfSigned: true));

      // Must not throw even though the channel has no handler.
      ServerManager().syncInsecureTls();
      await pumpEventQueue();
    });
  });
}
