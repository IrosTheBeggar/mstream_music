import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/media/cast_origin.dart';
import 'package:mstream_music/objects/server.dart';

Server _iroh({int? port = 52345, String? token = 'newtok'}) {
  final s = Server('iroh://placeholder', null, null, 'jwt', 'home');
  s.connectionType = 'iroh';
  s.tunnelPort = port;
  s.tunnelToken = token;
  return s;
}

MediaItem _item({String? art, String? extraArt, String? localPath}) =>
    MediaItem(
      id: 'http://127.0.0.1:34113/media/a.mp3?token=jwt&__lt=oldtok',
      title: 'a',
      artUri: art == null ? null : Uri.parse(art),
      extras: {
        'server': 'home',
        'path': 'a.mp3',
        'artUrl': ?extraArt,
        'localPath': ?localPath,
      },
    );

void main() {
  const stale =
      'http://127.0.0.1:34113/album-art/abc.jpeg?compress=l&token=jwt&__lt=oldtok';

  group('rebindLoopbackArt', () {
    // The regression this exists for: after a tunnel rebuild the queue's
    // stream URLs were rebound but the art kept the dead port + token, so the
    // notification fetched "Connection refused" every ~30s for minutes.
    test('rebinds a stale loopback artUri and extras artUrl', () {
      final out = rebindLoopbackArt(_item(art: stale, extraArt: stale), _iroh());
      expect(out.artUri!.port, 52345);
      expect(out.artUri!.queryParameters['__lt'], 'newtok');
      expect(out.artUri!.path, '/album-art/abc.jpeg');
      expect(out.artUri!.queryParameters['token'], 'jwt');
      final extra = Uri.parse(out.extras!['artUrl'] as String);
      expect(extra.port, 52345);
      expect(extra.queryParameters['__lt'], 'newtok');
      // Untouched fields survive the copy.
      expect(out.id, startsWith('http://127.0.0.1:34113/media/a.mp3'));
      expect(out.extras!['path'], 'a.mp3');
    });

    test('downloaded items are rebound too (the notification fetches art)', () {
      final out = rebindLoopbackArt(
          _item(art: stale, localPath: '/data/a.mp3'), _iroh());
      expect(out.artUri!.port, 52345);
      expect(out.extras!['localPath'], '/data/a.mp3');
    });

    test('same instance when the art already matches the live tunnel', () {
      final live =
          'http://127.0.0.1:52345/album-art/abc.jpeg?compress=l&token=jwt&__lt=newtok';
      final item = _item(art: live, extraArt: live);
      expect(identical(rebindLoopbackArt(item, _iroh()), item), isTrue);
    });

    test('same instance for an HTTP server, no art, or a tunnel not up', () {
      final http = Server('https://music.example', null, null, 'jwt', 'home');
      final item = _item(art: stale);
      expect(identical(rebindLoopbackArt(item, http), item), isTrue);
      expect(identical(rebindLoopbackArt(_item(), _iroh()), _item()), isFalse,
          reason: 'sanity: distinct instances are distinct');
      final noArt = _item();
      expect(identical(rebindLoopbackArt(noArt, _iroh()), noArt), isTrue);
      expect(identical(rebindLoopbackArt(item, _iroh(port: null)), item), isTrue);
    });

    test('non-loopback art (an HTTP server\'s URL on a mixed item) is left alone',
        () {
      const remote = 'https://music.example/album-art/abc.jpeg?compress=l';
      final item = _item(art: remote);
      expect(identical(rebindLoopbackArt(item, _iroh()), item), isTrue);
    });
  });

  group('a federated peer of an iroh parent', () {
    // A peer's art URL is the parent's art proxy on the parent's loopback, so
    // it goes stale with the parent's port + token and must be rebound to
    // THEM — the peer itself has no tunnel, port or token of its own.
    Server peerOf(Server parent) =>
        Server('federated://home/3', null, null, null, 'peer-basement')
          ..federationParent = 'home'
          ..federationPeerId = 3
          ..parentServer = parent;
    const staleProxied =
        'http://127.0.0.1:34113/api/v1/federation/peers/3/art/abc.jpeg'
        '?compress=l&token=jwt&__lt=oldtok';

    test('rebinds to the parent tunnel and keeps the proxied path', () {
      final peer = peerOf(_iroh());
      final out = rebindLoopbackArt(
          _item(art: staleProxied, extraArt: staleProxied), peer);
      expect(out.artUri!.port, 52345);
      expect(out.artUri!.queryParameters['__lt'], 'newtok');
      expect(out.artUri!.path, '/api/v1/federation/peers/3/art/abc.jpeg');
      expect(Uri.parse(out.extras!['artUrl'] as String).port, 52345);
    });

    test('irohLoopbackUri resolves the parent port and token', () {
      final peer = peerOf(_iroh());
      final live = irohLoopbackUri(peer, staleProxied);
      expect(live.port, 52345);
      expect(live.queryParameters['__lt'], 'newtok');
      expect(live.path, '/api/v1/federation/peers/3/art/abc.jpeg');
    });

    test('a peer of an HTTP parent is left alone', () {
      final http = Server('https://music.example', null, null, 'jwt', 'home');
      final item = _item(art: staleProxied);
      expect(identical(rebindLoopbackArt(item, peerOf(http)), item), isTrue);
    });

    test('an unlinked peer is left alone', () {
      final peer = peerOf(_iroh())..parentServer = null;
      final item = _item(art: staleProxied);
      expect(identical(rebindLoopbackArt(item, peer), item), isTrue);
    });
  });
}
