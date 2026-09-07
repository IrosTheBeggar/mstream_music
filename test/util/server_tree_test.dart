import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/util/server_tree.dart';

// The server lists' display order: a peer directly under its parent.

Server _own(String n) => Server('https://$n.example.com', 'u', 'p', 'J', n);
Server _peer(String n, String parent, int id) =>
    Server('federated://$parent/$id', null, null, null, n)
      ..federationParent = parent
      ..federationPeerId = id;

List<String> _names(List<Server> l) => l.map((s) => s.localname).toList();

void main() {
  test('own servers keep their stored order', () {
    expect(_names(serversGrouped([_own('a'), _own('b')])), ['a', 'b']);
  });

  test('a peer moves from the end of the list to under its parent', () {
    // The reconcile appends peers after every stored server.
    final l = [_own('home'), _own('other'), _peer('peer-x', 'home', 3)];
    expect(_names(serversGrouped(l)), ['home', 'peer-x', 'other']);
  });

  test('several peers keep their own order under the parent; parents keep '
      'theirs', () {
    final l = [
      _own('b'),
      _own('a'),
      _peer('a-2', 'a', 2),
      _peer('b-1', 'b', 1),
      _peer('a-1', 'a', 1),
    ];
    expect(_names(serversGrouped(l)), ['b', 'b-1', 'a', 'a-2', 'a-1']);
  });

  test('a peer whose parent is gone stays at the end', () {
    final l = [_peer('orphan', 'gone', 9), _own('a')];
    expect(_names(serversGrouped(l)), ['a', 'orphan']);
  });

  test('every server appears exactly once', () {
    final l = [_own('a'), _peer('a-1', 'a', 1), _own('b'), _peer('x', 'z', 1)];
    final g = serversGrouped(l);
    expect(g.length, l.length);
    expect(g.toSet().length, l.length);
  });
}
