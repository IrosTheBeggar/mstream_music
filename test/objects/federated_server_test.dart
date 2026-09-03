// A federated server is one PEER of another configured server, addressed
// through that parent's browse proxy (mStream #927) instead of by a URL of its
// own. Everything below pins the rewrite: the app's three URL builders are the
// only places that know federation exists, so if they are right the browse and
// playback paths follow.

import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/util/stream_url.dart';

/// A parent + one peer of it, wired the way ServerManager wires them.
({Server parent, Server peer}) _pair({
  String parentUrl = 'https://home.example.com',
  String? jwt = 'PARENT-JWT',
  bool iroh = false,
  int? tunnelPort,
  String? tunnelToken,
}) {
  final parent = Server(parentUrl, 'alice', 'secret', jwt, 'home');
  if (iroh) {
    parent.connectionType = 'iroh';
    parent.tunnelPort = tunnelPort;
    parent.tunnelToken = tunnelToken;
  }
  final peer = Server('federated://home/3', null, null, null, 'peer-basement')
    ..federationParent = 'home'
    ..federationPeerId = 3
    ..federationPeerName = 'Basement'
    ..parentServer = parent;
  return (parent: parent, peer: peer);
}

void main() {
  group('identity', () {
    test('a plain server is not federated and shows its URL', () {
      final s = Server('https://music.example.com', null, null, null, 'main');
      expect(s.isFederated, isFalse);
      expect(s.displayName, 'https://music.example.com');
    });

    test('a peer is federated and shows the name the parent reported', () {
      final peer = _pair().peer;
      expect(peer.isFederated, isTrue);
      expect(peer.displayName, 'Basement');
    });

    test('falls back to the peer id when the name has not arrived', () {
      final peer = _pair().peer..federationPeerName = null;
      expect(peer.displayName, 'Peer 3');
    });

    test('survives a JSON round trip', () {
      final peer = _pair().peer..federationMissing = true;
      final back = Server.fromJson(peer.toJson());
      expect(back.federationParent, 'home');
      expect(back.federationPeerId, 3);
      expect(back.federationPeerName, 'Basement');
      expect(back.federationMissing, isTrue);
      expect(back.isFederated, isTrue);
      // The parent link is runtime-only — it is never persisted, and
      // ServerManager re-establishes it after the list loads.
      expect(back.parentServer, isNull);
    });

    test('a server file written before federation loads as non-federated', () {
      final s = Server.fromJson({
        'url': 'https://music.example.com',
        'username': null,
        'password': null,
        'jwt': null,
        'localname': 'home',
      });
      expect(s.isFederated, isFalse);
      expect(s.federationMissing, isFalse);
    });
  });

  group('transport', () {
    // Two questions hide behind "is this an iroh server?": identity (isIroh)
    // and transport (whose tunnel carries the bytes). ServerManager picks the
    // tunnel target, the launch wait and the queue's tunnel from the transport.
    test('a plain server is its own transport', () {
      final s = Server('https://music.example.com', null, null, null, 'main');
      expect(identical(s.transportServer, s), isTrue);
      expect(s.isIrohTransport, isFalse);
    });

    test('an iroh server is its own iroh transport', () {
      final s = Server('iroh://placeholder', null, null, null, 'quick')
        ..connectionType = 'iroh';
      expect(identical(s.transportServer, s), isTrue);
      expect(s.isIrohTransport, isTrue);
    });

    test('a peer of an HTTP parent rides the parent, not a tunnel', () {
      final pair = _pair();
      expect(identical(pair.peer.transportServer, pair.parent), isTrue);
      expect(pair.peer.isIroh, isFalse);
      expect(pair.peer.isIrohTransport, isFalse);
    });

    test('a peer of an iroh parent is an iroh transport without being iroh',
        () {
      final pair = _pair(iroh: true, tunnelPort: 41773, tunnelToken: 'lt');
      expect(identical(pair.peer.transportServer, pair.parent), isTrue);
      expect(pair.peer.isIroh, isFalse);
      expect(pair.peer.isIrohTransport, isTrue);
    });

    test('an unlinked peer has no transport and is not an iroh transport', () {
      final peer = _pair(iroh: true).peer..parentServer = null;
      expect(peer.transportServer, isNull);
      expect(peer.isIrohTransport, isFalse);
    });
  });

  group('credentials', () {
    test('a peer authenticates with the parent token, never its own', () {
      final p = _pair();
      expect(p.peer.jwt, isNull);
      expect(p.peer.authToken, 'PARENT-JWT');
    });

    test('a public parent gives a peer no token at all', () {
      final p = _pair(jwt: null);
      expect(p.peer.authToken, isNull);
    });

    test('a plain server still uses its own token', () {
      final p = _pair();
      expect(p.parent.authToken, 'PARENT-JWT');
    });
  });

  group('apiUri', () {
    test('rewrites onto the parent browse proxy', () {
      final peer = _pair().peer;
      expect(peer.apiUri('/api/v1/db/albums').toString(),
          'https://home.example.com/api/v1/federation/peers/3/api/api/v1/db/albums');
    });

    test('the capability call lands on an allowlisted spelling', () {
      final peer = _pair().peer;
      // Both `GET /api` and `GET /api/` are on the federation allowlist
      // (mStream #932), so either survives the proxy's segment join.
      expect(peer.apiUri('/api/').toString(),
          'https://home.example.com/api/v1/federation/peers/3/api/api/');
    });

    test('an unlinked parent yields an unroutable origin, not the peer url',
        () {
      final peer = _pair().peer..parentServer = null;
      final uri = peer.apiUri('/api/v1/db/albums');
      expect(uri.host, '127.0.0.1');
      expect(uri.port, 0);
    });

    test('an iroh parent contributes its loopback origin and token once', () {
      final p = _pair(
          iroh: true, tunnelPort: 41234, tunnelToken: 'LT', parentUrl: 'iroh://abc');
      final uri = p.peer.apiUri('/api/v1/db/albums');
      expect(uri.host, '127.0.0.1');
      expect(uri.port, 41234);
      expect(uri.path,
          '/api/v1/federation/peers/3/api/api/v1/db/albums');
      expect(uri.queryParameters['__lt'], 'LT');
    });
  });

  group('stream urls', () {
    test('a peer track streams through the parent byte proxy', () {
      final peer = _pair().peer;
      final url = buildServerStreamUrl(peer, '/Music/Icarus/track 01.mp3');
      expect(
          url,
          startsWith('https://home.example.com/api/v1/federation/peers/3'
              '/stream/Music/Icarus/track%2001.mp3?app_uuid='));
      expect(url, contains('&token=PARENT-JWT'));
      // /transcode is off the federation allowlist entirely.
      expect(url, isNot(contains('/transcode')));
    });

    test('a peer download takes the same proxy, never transcoded', () {
      final peer = _pair().peer;
      expect(
          buildServerDownloadUrl(peer, '/Music/a.flac'),
          'https://home.example.com/api/v1/federation/peers/3'
          '/stream/Music/a.flac?token=PARENT-JWT');
    });

    test('a download from a public iroh server needs no leading ampersand', () {
      // No token and a loopback token is the one combination that used to
      // produce `?&__lt=…`.
      final s = Server('iroh://abc', null, null, null, 'tunnel')
        ..connectionType = 'iroh'
        ..tunnelPort = 41234
        ..tunnelToken = 'LT';
      expect(buildServerDownloadUrl(s, '/Music/a.flac'),
          'http://127.0.0.1:41234/media/Music/a.flac?__lt=LT');
    });

    test('a plain server is untouched by any of this', () {
      final parent = _pair().parent;
      final url = buildServerStreamUrl(parent, '/Music/a.mp3');
      expect(url, startsWith('https://home.example.com/media/Music/a.mp3?'));
      expect(url, isNot(contains('federation')));
    });
  });

  group('album art', () {
    test('a peer cover goes through the art proxy with compress forwarded', () {
      final peer = _pair().peer;
      expect(
          buildAlbumArtUrl(peer, 'abc123.jpg', compress: 'm'),
          'https://home.example.com/api/v1/federation/peers/3/art/abc123.jpg'
          '?compress=m&token=PARENT-JWT');
    });

    test('the art file is escaped as ONE segment', () {
      // The peer serves /album-art/:file — a single hash name — and the proxy
      // joins wildcard segments, so a stray slash must not become one.
      final peer = _pair().peer;
      expect(buildAlbumArtUrl(peer, 'a b/c.jpg'),
          contains('/art/a%20b%2Fc.jpg?'));
    });

    test('a plain server keeps whole-URL escaping', () {
      final parent = _pair().parent;
      expect(buildAlbumArtUrl(parent, 'abc123.jpg'),
          'https://home.example.com/album-art/abc123.jpg?compress=s&token=PARENT-JWT');
    });
  });
}
