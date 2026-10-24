// What a browse-entered Keep sheet reads off its facts: the artist's OWN
// albums there ("theirs", as the artist copy plans them — never the ones
// they only appear on), the ones the library lacks by name, the ones it has,
// a planned album's year; and a song's album songs asked again by its
// credit once the credit is known (a compilation's whole album).

import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/screens/discovery/keep_copy_facts.dart';

import 'browse_keep_sheet_fixtures.dart';

void main() {
  final facts = BrowseFacts();
  final own = Server('http://music.example', null, null, 'JWT', 'home');
  final peer = Server('federated://home/1', null, null, null, 'peer-1')
    ..federationParent = 'home'
    ..federationPeerId = 1
    ..federationPeerName = 'Stage Peer B'
    ..parentServer = own;

  Future<KeepFactsLoader> loaded(KeepFactsLoader l) async {
    l.load();
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    return l;
  }

  test("theirs, the missing and the ones you have, from the peer's list as "
      'the copy plans it', () async {
    final l = await loaded(
      KeepFactsLoader(
        peer: peer,
        own: own,
        album: null,
        artist: 'Boukmanflow',
        fetch: facts.call,
      ),
    );
    final f = l.facts;
    expect(f.theirsOf('Boukmanflow'), [
      'Borrowed Tapes',
      'Harbour Lights',
      'Second Shift',
    ]);
    expect(f.missingTheirs('Boukmanflow'), ['Borrowed Tapes', 'Second Shift']);
    expect(f.haveTheirs('Boukmanflow'), 1);
    expect(f.theirsOf('Lantern Choir'), isEmpty);
    l.dispose();
  });

  test('unknown until the lists answer; the library lacking says nothing of '
      'the missing', () async {
    const f = KeepFacts();
    expect(f.theirsOf('Boukmanflow'), isNull);
    expect(f.missingTheirs('Boukmanflow'), isNull);
    expect(f.haveTheirs('Boukmanflow'), isNull);
    final l = await loaded(
      KeepFactsLoader(
        peer: peer,
        own: null,
        album: null,
        artist: 'Boukmanflow',
        fetch: facts.call,
      ),
    );
    expect(l.facts.theirsOf('Boukmanflow'), hasLength(3));
    expect(l.facts.missingTheirs('Boukmanflow'), isNull);
    l.dispose();
  });

  test("a song's album asked again by its credit once known — the whole "
      'compilation, not the track artist\'s one song', () async {
    final l = await loaded(
      KeepFactsLoader(
        peer: peer,
        own: own,
        album: 'Night Market Sampler',
        artist: 'Boukmanflow',
        fetch: facts.call,
      ),
    );
    expect(l.facts.albumSongCount, 1);
    l.albumCreditKnown('Various Artists');
    expect(l.loadingAlbum, isTrue);
    for (var i = 0; i < 20; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(l.facts.albumSongCount, 3);
    final asks = facts.asked.where((a) => a.contains('album-songs')).toList();
    expect(asks.last, contains('"album_artist":"Various Artists"'));
    // The same credit again asks nothing.
    final before = facts.asked.length;
    l.albumCreditKnown('various artists');
    expect(facts.asked.length, before);
    l.dispose();
  });
}
