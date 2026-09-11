import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/metadata.dart';
import 'package:mstream_music/objects/server.dart';

void main() {
  group('Server.statsVersion', () {
    test('persists through toJson/fromJson and tolerates a non-integer', () {
      final s = Server('http://a', 'u', 'p', 'jwt', 'home');
      expect(s.statsVersion, null);
      expect(s.statsCapable, false);
      s.statsVersion = 2;
      final back = Server.fromJson(s.toJson());
      expect(back.statsVersion, 2);
      expect(back.statsCapable, true);
      final j = s.toJson()..['statsVersion'] = 'two';
      expect(Server.fromJson(j).statsVersion, null);
      final one = Server.fromJson(s.toJson()..['statsVersion'] = 1);
      expect(one.statsCapable, false, reason: 'v1 never shipped a play write');
    });

    test('a federated peer answers with its parent\'s capability', () {
      final parent = Server('http://p', 'u', 'p', 'jwt', 'parent')..statsVersion = 2;
      final peer = Server('federated://parent/3', null, null, null, 'peer-bob')
        ..federationParent = 'parent'
        ..federationPeerId = 3
        ..parentServer = parent;
      expect(peer.isFederated, true);
      expect(peer.statsVersion, null);
      expect(peer.statsServer, same(parent));
      expect(peer.statsCapable, true);
      parent.statsVersion = null;
      expect(peer.statsCapable, false);
      final orphan = Server('federated://gone/3', null, null, null, 'peer-x')..federationParent = 'gone';
      expect(orphan.statsServer, null);
      expect(orphan.statsCapable, false);
    });
  });

  group('MusicMetadata.lastPlayed', () {
    test('parses ISO and SQLite text as UTC, carries it in the queue extras and JSON', () {
      final m = MusicMetadata.fromServerMap({'title': 'T', 'hash': 'h', 'play-count': 3, 'last-played': '2026-09-03 11:00:00.000'});
      expect(m.lastPlayed, DateTime.utc(2026, 9, 3, 11));
      expect(MusicMetadata.fromServerMap({'last-played': '2026-09-03T11:00:00.000Z'}).lastPlayed, DateTime.utc(2026, 9, 3, 11));
      expect(MusicMetadata.fromServerMap({'last-played': '2026-09-03T13:00:00+02:00'}).lastPlayed, DateTime.utc(2026, 9, 3, 11));
      expect(MusicMetadata.fromServerMap({'last-played': null}).lastPlayed, null);
      expect(MusicMetadata.fromServerMap({'last-played': 'garbage'}).lastPlayed, null);
      expect(MusicMetadata.fromServerMap({}).lastPlayed, null);
      final extras = queueExtras(m, server: 'home', path: '/x.mp3');
      expect(extras['lastPlayed'], '2026-09-03T11:00:00.000Z');
      expect(extras['playCount'], 3);
      final round = MusicMetadata.fromJson(m.toJson());
      expect(round.lastPlayed, m.lastPlayed);
      expect(MusicMetadata.utcOrNull(''), null);
    });
  });
}
