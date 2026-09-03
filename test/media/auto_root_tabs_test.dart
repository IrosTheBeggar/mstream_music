// The car tree's root for a federated peer: read-only, no DJ. Shuffle All
// hands the library to Auto DJ (random-songs, off the federation allowlist)
// and Playlists lists routes the allowlist refuses, so a peer's root has
// neither; a plain server keeps both.

import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/media/auto_browse.dart';
import 'package:mstream_music/objects/server.dart';

void main() {
  List<String> titles(Server s) =>
      AutoBrowse.rootTabs(s).map((m) => m.title).toList();

  test('a plain server offers Shuffle All and Playlists', () {
    final s = Server('https://music.example.com', null, null, 'jwt', 'home');
    expect(titles(s), containsAll(['Shuffle All', 'Playlists', 'Albums']));
  });

  test('a federated peer offers neither', () {
    final parent = Server('https://home.example.com', null, null, 'jwt', 'home');
    final peer = Server('federated://home/3', null, null, null, 'peer-b')
      ..federationParent = 'home'
      ..federationPeerId = 3
      ..parentServer = parent;
    final t = titles(peer);
    expect(t, isNot(contains('Shuffle All')));
    expect(t, isNot(contains('Playlists')));
    expect(t, containsAll(['Recently Added', 'Albums', 'Artists', 'Files']));
  });
}
