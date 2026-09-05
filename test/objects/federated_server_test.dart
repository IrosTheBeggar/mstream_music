// A federated server is one PEER of another configured server, addressed
// through that parent's browse proxy (mStream #927) instead of by a URL of its
// own. Everything below pins the rewrite: the app's three URL builders are the
// only places that know federation exists, so if they are right the browse and
// playback paths follow.

import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/singletons/server_list.dart';
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

  group('selectable', () {
    // Phase 3: the picker and the car offer a peer only while its parent
    // still lists it and the user has not hidden it.
    test('a listed, unhidden peer is selectable', () {
      expect(_pair().peer.isSelectable, isTrue);
    });

    test('a peer the parent stopped listing is not', () {
      expect((_pair().peer..federationMissing = true).isSelectable, isFalse);
    });

    test('a hidden peer is not, and the flag survives a round trip', () {
      final peer = _pair().peer..federationHidden = true;
      expect(peer.isSelectable, isFalse);
      final back = Server.fromJson(peer.toJson());
      expect(back.federationHidden, isTrue);
      expect(back.isSelectable, isFalse);
    });

    test('a plain server is always selectable', () {
      final s = Server('https://music.example.com', null, null, null, 'main');
      expect(s.isSelectable, isTrue);
    });
  });

  group('reconcile helpers', () {
    Server child(String name, int id) =>
        Server('federated://home/$id', null, null, null, 'peer-$id')
          ..federationParent = 'home'
          ..federationPeerId = id
          ..federationPeerName = name;

    test('a re-added peer is adopted by its old record, by name', () {
      // The admin removed "Basement" (id 3) and re-added it: the parent now
      // lists id 7 under the same name and nobody holds 7.
      final old = child('Basement', 3);
      final other = child('Attic', 4);
      expect(ServerManager.adoptablePeer([old, other], 'Basement', {7, 4}),
          same(old));
    });

    test('a child whose id is still listed is never adopted', () {
      // Two peers can share a name; the one the parent still lists stays.
      final live = child('Basement', 3);
      expect(ServerManager.adoptablePeer([live], 'Basement', {3, 7}), isNull);
    });

    test('a different name is never adopted', () {
      expect(
          ServerManager.adoptablePeer([child('Attic', 4)], 'Basement', {7}),
          isNull);
    });

    test('the default skips a hidden or missing peer at index 0', () {
      final parent = Server('https://home.example.com', null, null, 'j', 'home');
      final hidden = child('Basement', 3)
        ..parentServer = parent
        ..federationHidden = true;
      final missing = child('Attic', 4)
        ..parentServer = parent
        ..federationMissing = true;
      expect(ServerManager.firstSelectable([hidden, missing, parent]),
          same(parent));
      // Nothing selectable at all: fall back to the first, never crash.
      expect(ServerManager.firstSelectable([hidden]), same(hidden));
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

  group('albumArtFileFromUrl', () {
    // Queue restore and playlists re-origin a persisted art URL against the
    // live tunnel by pulling the file out of it; a peer's URL is the parent's
    // art proxy, a different shape with the same durable part.
    test("reads a server's own /album-art URL", () {
      expect(
          albumArtFileFromUrl(
              'http://127.0.0.1:4111/album-art/abc.jpeg?compress=l&token=t'),
          'abc.jpeg');
    });

    test("reads a peer's proxied art URL", () {
      expect(
          albumArtFileFromUrl('http://127.0.0.1:4111/api/v1/federation/peers/3'
              '/art/abc%20d.jpeg?compress=s&token=t&__lt=x'),
          'abc d.jpeg');
    });

    test('anything else is not an art URL', () {
      expect(albumArtFileFromUrl('http://127.0.0.1:4111/media/a.mp3'), isNull);
      expect(
          albumArtFileFromUrl(
              'http://h/api/v1/federation/peers/3/stream/a.mp3'),
          isNull);
      expect(albumArtFileFromUrl('not a url at all ::'), isNull);
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

  group('direct access (issue #143)', () {
    test('a peer is direct exactly while it holds a tunnel port of its own', () {
      final (parent: parent, peer: peer) = _pair();
      expect(peer.isDirect, isFalse);
      expect(peer.ownsTunnel, isFalse);
      expect(peer.transportServer, same(parent));
      expect(peer.isIrohTransport, isFalse, reason: 'an HTTP parent has no tunnel');

      peer
        ..tunnelPort = 40123
        ..tunnelToken = 'peerlt'
        ..directGuestToken = 'GUEST-JWT';
      expect(peer.isDirect, isTrue);
      expect(peer.ownsTunnel, isTrue);
      expect(peer.transportServer, same(peer));
      expect(peer.isIrohTransport, isTrue);
      expect(peer.isIroh, isFalse, reason: 'identity stays federated');
    });

    test('direct: own loopback, own __lt, the guest token — never the parent\'s', () {
      final (parent: parent, peer: peer) = _pair(iroh: true, tunnelPort: 5001, tunnelToken: 'parentlt');
      expect(parent.effectiveBaseUrl, 'http://127.0.0.1:5001');
      peer
        ..tunnelPort = 40123
        ..tunnelToken = 'peerlt'
        ..directGuestToken = 'GUEST-JWT';
      expect(peer.effectiveBaseUrl, 'http://127.0.0.1:40123');
      expect(peer.authToken, 'GUEST-JWT');
      expect(peer.localTokenQuery, '&__lt=peerlt');
      final u = peer.apiUri('/api/v1/db/albums');
      expect(u.toString(), 'http://127.0.0.1:40123/api/v1/db/albums?__lt=peerlt');
      expect(u.toString(), isNot(contains('federation')));
      expect(u.toString(), isNot(contains('parentlt')));
    });

    test('proxy: the parent\'s everything, as before', () {
      final (parent: parent, peer: peer) = _pair(iroh: true, tunnelPort: 5001, tunnelToken: 'parentlt');
      peer.directGuestToken = 'GUEST-JWT'; // held but unused without a tunnel
      expect(peer.isDirect, isFalse);
      expect(peer.authToken, parent.jwt);
      expect(peer.effectiveBaseUrl, 'http://127.0.0.1:5001');
      expect(peer.apiUri('/api/v1/db/albums').toString(),
          'http://127.0.0.1:5001/api/v1/federation/peers/3/api/api/v1/db/albums?__lt=parentlt');
    });

    test('the direct material is runtime-only; the parent\'s flag persists', () {
      final peer = _pair().peer
        ..directTicket = 'mstrfedg1:x'
        ..directGuestToken = 'g'
        ..directDenied = true
        ..tunnelPort = 1;
      final back = Server.fromJson(peer.toJson());
      expect(back.directTicket, isNull);
      expect(back.directGuestToken, isNull);
      expect(back.directDenied, isFalse);
      expect(back.tunnelPort, isNull);
      expect(back.isDirect, isFalse);

      final parent = _pair().parent..federationDirectAvailable = true;
      expect(Server.fromJson(parent.toJson()).federationDirectAvailable, isTrue);
      expect(Server.fromJson({'url': 'https://x', 'localname': 'x'}).federationDirectAvailable, isNull);
    });
  });
}
