import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/native/iroh_tunnel.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/singletons/tunnel_handle.dart';

Server _iroh(String name, String code) =>
    Server('iroh://$name', null, null, null, name)
      ..connectionType = 'iroh'
      ..irohPairingCode = code;

Server _http(String name) => Server('https://$name', null, null, null, name);

void main() {
  group('TunnelHandle', () {
    test('a Quick Connect server keys by its pairing code, anything else by localname', () {
      expect(TunnelHandle.keyFor(_iroh('qc', 'mstr1:abc')), 'mstr1:abc');
      expect(TunnelHandle.keyFor(_http('home')), 'home');
      final peer = Server('federated://home/3', null, null, null, 'peer-x')
        ..federationParent = 'home'
        ..federationPeerId = 3;
      expect(TunnelHandle.keyFor(peer), 'peer-x');
    });

    test('bind mirrors the port and token onto the server; clear forgets both', () {
      final s = _iroh('qc', 'mstr1:abc');
      final h = TunnelHandle(s);
      expect(h.assigned, isFalse);
      h.bind(key: 'mstr1:abc', credential: 'mstr1:abc', localPort: 4242, localToken: 'tok');
      expect(h.assigned, isTrue);
      expect(s.tunnelPort, 4242);
      expect(s.tunnelToken, 'tok');
      expect(s.effectiveBaseUrl, 'http://127.0.0.1:4242');
      h.clearRuntime();
      expect(h.assigned, isFalse);
      expect(s.tunnelPort, isNull);
      expect(s.tunnelToken, isNull);
    });

    test('sameTunnel re-checks code, port and the server\'s current code', () {
      final s = _iroh('qc', 'mstr1:abc');
      final h = TunnelHandle(s)
        ..bind(key: 'mstr1:abc', credential: 'mstr1:abc', localPort: 4242, localToken: 't');
      expect(h.sameTunnel('mstr1:abc', 4242), isTrue);
      expect(h.sameTunnel('mstr1:abc', 4243), isFalse, reason: 'port rotated');
      expect(h.sameTunnel(null, 4242), isFalse);
      // A re-pair swapped the server's code under a probe: not the same tunnel.
      s.irohPairingCode = 'mstr1:new';
      expect(h.sameTunnel('mstr1:abc', 4242), isFalse);
    });

    test('the key survives a code swap until the tunnel is stopped', () {
      // A repair changes the server's code BEFORE the old tunnel is stopped;
      // the stop must use the key the tunnel was started under.
      final s = _iroh('qc', 'mstr1:old');
      final h = TunnelHandle(s)
        ..bind(key: 'mstr1:old', credential: 'mstr1:old', localPort: 1, localToken: null);
      s.irohPairingCode = 'mstr1:new';
      expect(h.nativeKey, 'mstr1:old');
      expect(TunnelHandle.keyFor(s), 'mstr1:new', reason: 'the NEXT start keys by the new code');
    });
  });

  group('direct peers', () {
    Server peerOf(Server parent) => Server('federated://home/3', null, null, null, 'peer-x')
      ..federationParent = 'home'
      ..federationPeerId = 3
      ..parentServer = parent;

    test('a peer keys by localname and dials with its guest ticket', () {
      final peer = peerOf(_http('home'));
      expect(TunnelHandle.keyFor(peer), 'peer-x');
      expect(TunnelHandle.credentialFor(peer), isNull, reason: 'nothing until the parent hands one out');
      peer.directTicket = 'mstrfedg1:abc';
      expect(TunnelHandle.credentialFor(peer), 'mstrfedg1:abc');
      expect(TunnelHandle.credentialFor(_iroh('qc', 'mstr1:code')), 'mstr1:code');
    });

    test('binding a peer handle makes the peer direct; clearing it puts it back on the proxy', () {
      final parent = _http('home');
      final peer = peerOf(parent);
      expect(peer.transportServer, same(parent));
      final h = TunnelHandle(peer)
        ..bind(key: 'peer-x', credential: 'mstrfedg1:abc', localPort: 5000, localToken: 'lt');
      expect(peer.isDirect, isTrue);
      expect(peer.transportServer, same(peer));
      expect(peer.isIrohTransport, isTrue);
      expect(h.sameTunnel('mstrfedg1:abc', 5000), isFalse, reason: 'the server holds no ticket yet');
      peer.directTicket = 'mstrfedg1:abc';
      expect(h.sameTunnel('mstrfedg1:abc', 5000), isTrue);
      h.clearRuntime();
      expect(peer.isDirect, isFalse);
      expect(peer.transportServer, same(parent));
    });

    test('the strip follows a browsed direct peer over its own tunnel', () {
      final peer = peerOf(_http('home'))..tunnelPort = 5000;
      expect(bannerTargetAmong(browsed: peer.transportServer, background: const []), same(peer));
    });
  });

  group('bannerTargetAmong', () {
    final qc = _iroh('qc', 'mstr1:a');
    final other = _iroh('other', 'mstr1:b');
    final home = _http('home');

    test('the browsed tunnel server wins whatever its state', () {
      expect(
          bannerTargetAmong(browsed: qc, background: [
            (server: other, status: IrohTunnelStatus.rejected),
            (server: qc, status: IrohTunnelStatus.connected),
          ]),
          same(qc));
    });

    test('browsing a standard server: the background tunnel in the worst state', () {
      expect(
          bannerTargetAmong(browsed: home, background: [
            (server: qc, status: IrohTunnelStatus.connected),
            (server: other, status: IrohTunnelStatus.reconnecting),
          ]),
          same(other));
      expect(
          bannerTargetAmong(browsed: home, background: [
            (server: qc, status: IrohTunnelStatus.down),
            (server: other, status: IrohTunnelStatus.reconnecting),
          ]),
          same(qc));
    });

    test('nothing to serve → null; a browsed standard server alone → null', () {
      expect(bannerTargetAmong(browsed: null, background: const []), isNull);
      expect(bannerTargetAmong(browsed: home, background: const []), isNull);
    });

    test('severity orders rejected > down > reconnecting > connecting > connected', () {
      final order = [
        IrohTunnelStatus.connected,
        IrohTunnelStatus.connecting,
        IrohTunnelStatus.reconnecting,
        IrohTunnelStatus.down,
        IrohTunnelStatus.rejected,
      ];
      for (var i = 1; i < order.length; i++) {
        expect(statusSeverity(order[i]), greaterThan(statusSeverity(order[i - 1])));
      }
    });
  });
}
