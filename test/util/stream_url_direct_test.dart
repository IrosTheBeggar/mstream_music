// A federated peer reached DIRECTLY (issue #143) serves /media and
// /album-art itself over a tunnel of its own, with the guest token in the
// ordinary token slot; on the proxy path the same peer's URLs go through the
// parent. The flip is the peer's own tunnel port, nothing else.

import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/singletons/transcode.dart';
import 'package:mstream_music/util/stream_url.dart';

({Server parent, Server peer}) _pair() {
  final parent = Server('https://home.example.com', 'alice', 'secret', 'PARENT-JWT', 'home');
  final peer = Server('federated://home/3', null, null, null, 'peer-basement')
    ..federationParent = 'home'
    ..federationPeerId = 3
    ..federationPeerName = 'Basement'
    ..parentServer = parent
    ..transcodeAvailable = false;
  return (parent: parent, peer: peer);
}

void main() {
  setUp(() => TranscodeManager().transcodeOn = false);

  test('proxy path: stream, download and art go through the parent', () {
    final peer = _pair().peer;
    expect(buildServerStreamUrl(peer, '/Music/a.mp3'),
        startsWith('https://home.example.com/api/v1/federation/peers/3/stream/Music/a.mp3?app_uuid='));
    expect(buildServerStreamUrl(peer, '/Music/a.mp3'), contains('&token=PARENT-JWT'));
    expect(buildServerDownloadUrl(peer, '/Music/a.mp3'),
        'https://home.example.com/api/v1/federation/peers/3/stream/Music/a.mp3?token=PARENT-JWT');
    expect(buildAlbumArtUrl(peer, 'abc.jpg', compress: 'm'),
        'https://home.example.com/api/v1/federation/peers/3/art/abc.jpg?compress=m&token=PARENT-JWT');
  });

  test('direct: the peer\'s own loopback, /media and /album-art, the guest token, the peer\'s __lt', () {
    final peer = _pair().peer
      ..tunnelPort = 40123
      ..tunnelToken = 'peerlt'
      ..directGuestToken = 'GUEST-JWT';
    expect(peer.isDirect, isTrue);
    final stream = buildServerStreamUrl(peer, '/Music/a.mp3');
    expect(stream, startsWith('http://127.0.0.1:40123/media/Music/a.mp3?app_uuid='));
    expect(stream, contains('&token=GUEST-JWT'));
    expect(stream, endsWith('&__lt=peerlt'));
    expect(stream, isNot(contains('PARENT-JWT')));
    expect(stream, isNot(contains('federation')));
    expect(buildServerDownloadUrl(peer, '/Music/a.mp3'),
        'http://127.0.0.1:40123/media/Music/a.mp3?token=GUEST-JWT&__lt=peerlt');
    final art = buildAlbumArtUrl(peer, 'abc.jpg', compress: 'l');
    expect(art, 'http://127.0.0.1:40123/album-art/abc.jpg?compress=l&token=GUEST-JWT&__lt=peerlt');
    expect(albumArtFileFromUrl(art), 'abc.jpg', reason: 'the extractor reads the plain shape');
  });

  test('losing the tunnel puts the same peer back on the proxy shapes', () {
    final peer = _pair().peer
      ..tunnelPort = 40123
      ..tunnelToken = 'peerlt'
      ..directGuestToken = 'GUEST-JWT';
    peer.tunnelPort = null;
    peer.tunnelToken = null;
    expect(peer.isDirect, isFalse);
    expect(buildServerStreamUrl(peer, '/Music/a.mp3'), contains('/api/v1/federation/peers/3/stream/'));
    expect(buildServerStreamUrl(peer, '/Music/a.mp3'), contains('&token=PARENT-JWT'));
  });
}
