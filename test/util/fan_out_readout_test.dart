import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/util/fan_out_readout.dart';

// The participants readout's second line: which candidates ride a tunnel
// that is not live yet.

Server _http(String n) => Server('https://$n.example.com', 'u', 'p', 'J', n);
Server _iroh(String n) => Server('iroh://$n', 'u', 'p', 'J', n)
  ..connectionType = 'iroh';

void main() {
  test('an HTTP server never counts as connecting', () {
    expect(fanOutConnecting([_http('a')], (_) => false), isEmpty);
  });

  test('a Quick Connect server counts until its tunnel serves', () {
    final qc = _iroh('b');
    expect(fanOutConnecting([_http('a'), qc], (_) => false), [qc]);
    expect(fanOutConnecting([_http('a'), qc], (s) => s == qc), isEmpty);
  });

  test('a peer on a Quick Connect parent rides that tunnel', () {
    final parent = _iroh('home');
    final peer = Server('federated://home/3', null, null, null, 'peer')
      ..federationParent = 'home'
      ..federationPeerId = 3
      ..parentServer = parent;
    expect(fanOutConnecting([peer], (_) => false), [peer]);
    expect(fanOutConnecting([peer], (_) => true), isEmpty);
  });
}
