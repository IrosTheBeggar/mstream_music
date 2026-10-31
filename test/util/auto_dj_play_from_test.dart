// Where Auto DJ starts (util/auto_dj_play_from.dart): the Auto DJ screen's
// Play from choice while the picker still offers that server, else the one
// being browsed. Start, the queue's Auto DJ button and CarPlay all arm the DJ
// through it.

import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/singletons/auto_dj_manager.dart';
import 'package:mstream_music/singletons/server_list.dart';
import 'package:mstream_music/util/auto_dj_play_from.dart';

Server _server(String name) =>
    Server('https://$name.example.com', 'u', 'p', 'JWT', name);

Server _peer(String name, {bool hidden = false, bool missing = false}) =>
    Server('federated://home/$name', null, null, null, name)
      ..federationParent = 'home'
      ..federationPeerId = 3
      ..federationPeerName = 'Basement'
      ..federationHidden = hidden
      ..federationMissing = missing;

void main() {
  final home = _server('home');
  final office = _server('office');

  group('resolvePlayFrom', () {
    test('a stored server the picker offers wins over the browsed one', () {
      expect(resolvePlayFrom('office', [home, office], home), same(office));
      expect(resolvePlayFrom('home', [home, office], office), same(home));
    });

    test('a stored peer that is still listed is a choice like any other', () {
      final peer = _peer('peer-basement');
      expect(resolvePlayFrom('peer-basement', [home, peer], home), same(peer));
    });

    test('nothing stored: the browsed server stands in', () {
      expect(resolvePlayFrom(null, [home, office], office), same(office));
      expect(resolvePlayFrom(null, [home, office], null), isNull);
    });

    test('a stored server that was removed falls back to the browsed one',
        () {
      expect(resolvePlayFrom('gone', [home, office], office), same(office));
      expect(resolvePlayFrom('gone', const [], home), same(home));
      expect(resolvePlayFrom('gone', [home], null), isNull);
    });

    test('a stored peer that is hidden, or its parent stopped listing, falls '
        'back — the picker does not offer it', () {
      final hidden = _peer('peer-hidden', hidden: true);
      final missing = _peer('peer-missing', missing: true);
      expect(hidden.isSelectable, isFalse);
      expect(missing.isSelectable, isFalse);
      expect(resolvePlayFrom('peer-hidden', [home, hidden], home), same(home));
      expect(
          resolvePlayFrom('peer-missing', [home, missing], office), same(office));
      expect(resolvePlayFrom('peer-hidden', [hidden], null), isNull);
    });

    test('matched by localname, not by object or url', () {
      final twin = Server('https://office.example.com', 'u', 'p', 'JWT', 'twin');
      expect(resolvePlayFrom('office', [twin, office], home), same(office));
      expect(resolvePlayFrom('https://office.example.com', [office], home),
          same(home));
    });
  });

  group('autoDjPlayFrom (the live lists)', () {
    final mgr = AutoDJManager();
    String? saved;

    setUp(() {
      saved = mgr.playFromServer;
      ServerManager().serverList
        ..clear()
        ..addAll([home, office]);
      ServerManager().currentServer = home;
    });
    tearDown(() {
      mgr.playFromServer = saved;
      ServerManager().serverList.clear();
      ServerManager().currentServer = null;
    });

    test('reads AutoDJManager.playFromServer against ServerManager', () {
      mgr.playFromServer = 'office';
      expect(autoDjPlayFrom(), same(office));
      mgr.playFromServer = null;
      expect(autoDjPlayFrom(), same(home));
      mgr.playFromServer = 'gone';
      expect(autoDjPlayFrom(), same(home));
    });
  });
}
