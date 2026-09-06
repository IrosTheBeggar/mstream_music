import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/media/audio_stuff.dart';
import 'package:mstream_music/objects/server.dart';

// Who may take part in a multi-server Auto DJ session (mStream #929/#946):
// the pure predicate behind AudioPlayerHandler.multiServerCandidates.

Server _server(String name, {String? version = '6.26.0', bool? discovery = true}) =>
    Server('https://$name.example.com', 'u', 'p', 'JWT', name)
      ..serverVersion = version
      ..discoveryAvailable = discovery;

Server _peer({bool hidden = false, bool missing = false}) =>
    Server('federated://home/3', null, null, null, 'peer-basement')
      ..federationParent = 'home'
      ..federationPeerId = 3
      ..federationPeerName = 'Basement'
      ..serverVersion = '6.26.0'
      ..discoveryAvailable = true
      ..federationHidden = hidden
      ..federationMissing = missing;

void main() {
  group('AudioPlayerHandler.canJoinMultiServer', () {
    test('discovery on and a version carrying the vector seed joins', () {
      expect(AudioPlayerHandler.canJoinMultiServer(_server('a'), {}), isTrue);
    });

    test('an unknown version is offered the session and answers for itself',
        () {
      expect(
          AudioPlayerHandler.canJoinMultiServer(
              _server('a', version: null), {}),
          isTrue);
    });

    test('a version known to predate the vector seed sits out', () {
      expect(
          AudioPlayerHandler.canJoinMultiServer(
              _server('a', version: '6.25.0'), {}),
          isFalse);
    });

    test('discovery off — or never reported — sits out', () {
      expect(
          AudioPlayerHandler.canJoinMultiServer(
              _server('a', discovery: false), {}),
          isFalse);
      expect(
          AudioPlayerHandler.canJoinMultiServer(
              _server('a', discovery: null), {}),
          isFalse);
    });

    test('a never-reported discovery flag passes only for the tunnel targets',
        () {
      // Reaching the server is what fills the flag in, so the targets may
      // include it; a pick never asks it until the flag says yes.
      expect(
          AudioPlayerHandler.canJoinMultiServer(_server('a', discovery: null), {},
              allowUnknownDiscovery: true),
          isTrue);
      expect(
          AudioPlayerHandler.canJoinMultiServer(
              _server('a', discovery: false), {},
              allowUnknownDiscovery: true),
          isFalse);
    });

    test('a server dropped this session (model mismatch, no vector seed) '
        'stays out', () {
      expect(AudioPlayerHandler.canJoinMultiServer(_server('a'), {'a'}),
          isFalse);
      expect(AudioPlayerHandler.canJoinMultiServer(_server('a'), {'b'}),
          isTrue);
    });

    test('a federated peer joins like any other server', () {
      expect(AudioPlayerHandler.canJoinMultiServer(_peer(), {}), isTrue);
    });

    test('a peer joins even with its discovery flag pinned false — health '
        'decides for it', () {
      // ServerManager._applyFederatedDefaults pins the flag; the two routes
      // the fan-out uses are allowlisted regardless, and the model handshake
      // asks the peer before anything is sent.
      expect(
          AudioPlayerHandler.canJoinMultiServer(
              _peer()..discoveryAvailable = false, {}),
          isTrue);
      expect(
          AudioPlayerHandler.canJoinMultiServer(
              _server('a', discovery: false), {}),
          isFalse,
          reason: 'a plain server still needs the flag');
    });

    test('a hidden peer, or one its parent stopped listing, sits out', () {
      expect(AudioPlayerHandler.canJoinMultiServer(_peer(hidden: true), {}),
          isFalse);
      expect(AudioPlayerHandler.canJoinMultiServer(_peer(missing: true), {}),
          isFalse);
    });
  });
}
