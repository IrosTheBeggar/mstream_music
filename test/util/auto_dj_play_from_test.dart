// Where Auto DJ plays from (util/auto_dj_play_from.dart): the servers the
// Auto DJ screen's Play from names while the picker still offers them — any
// set, or All servers — else the one being browsed; and which of them the
// session runs on. Start, the queue's Auto DJ button and CarPlay all arm the
// DJ through it.

import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/media/audio_stuff.dart' show FanOutSitOut;
import 'package:mstream_music/objects/server.dart';
import 'package:mstream_music/singletons/auto_dj_manager.dart';
import 'package:mstream_music/singletons/server_list.dart';
import 'package:mstream_music/util/auto_dj_play_from.dart';

Server _server(String name) =>
    Server('https://$name.example.com', 'u', 'p', 'JWT', name);

/// A server that can lead a session across several: discovery on with
/// vectors ready, new enough to send a vector seed.
Server _sonic(String name) => _server(name)
  ..serverVersion = '6.26.0'
  ..discoveryEnabled = true;

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

  group('resolvePlayFromSet', () {
    final basement = _peer('peer-basement');
    final offered = [home, basement, office];

    test('the chosen servers, in the list\'s order', () {
      expect(
          resolvePlayFromSet(
              all: false, chosen: ['office', 'home'], offered: offered),
          [home, office]);
      expect(
          resolvePlayFromSet(
              all: false, chosen: ['peer-basement'], offered: offered),
          [basement]);
    });

    test('All servers is every server offered, whatever is chosen', () {
      expect(resolvePlayFromSet(all: true, chosen: ['home'], offered: offered),
          offered);
      expect(resolvePlayFromSet(all: true, chosen: const [], offered: offered),
          offered);
    });

    test('a peer hidden, or no longer listed, sits out until it is back — '
        'for All servers too', () {
      final hidden = _peer('peer-hidden', hidden: true);
      final missing = _peer('peer-missing', missing: true);
      final list = [home, hidden, missing, office];
      expect(
          resolvePlayFromSet(
              all: false,
              chosen: ['home', 'peer-hidden', 'peer-missing'],
              offered: list),
          [home]);
      expect(resolvePlayFromSet(all: true, chosen: const [], offered: list),
          [home, office]);
    });

    test('nothing chosen, or nothing chosen left: the fallback alone', () {
      expect(
          resolvePlayFromSet(
              all: false, chosen: const [], offered: offered, fallback: office),
          [office]);
      expect(
          resolvePlayFromSet(
              all: false, chosen: ['gone'], offered: offered, fallback: home),
          [home]);
      expect(
          resolvePlayFromSet(all: false, chosen: ['gone'], offered: offered),
          isEmpty);
      expect(
          resolvePlayFromSet(
              all: true, chosen: const [], offered: const [], fallback: home),
          [home]);
    });

    test('a fallback is only for when nothing is left', () {
      expect(
          resolvePlayFromSet(
              all: false, chosen: ['home'], offered: offered, fallback: office),
          [home]);
    });
  });

  group('resolvePlayFromHome', () {
    final a = _sonic('a');
    final b = _sonic('b');
    final c = _sonic('c');
    bool all(Server _) => true;
    bool none(Server _) => false;

    test('one server is the home, whatever it can do', () {
      expect(resolvePlayFromHome([a], b, none), same(a));
      expect(resolvePlayFromHome([a], null, none), same(a));
    });

    test('nothing at all: the preferred server, or none', () {
      expect(resolvePlayFromHome(const [], a, all), same(a));
      expect(resolvePlayFromHome(const [], null, all), isNull);
    });

    test('with several, the preferred one while it is among them and can '
        'lead', () {
      expect(resolvePlayFromHome([a, b, c], b, all), same(b));
      expect(resolvePlayFromHome([a, b, c], c, all), same(c));
    });

    test('a preferred one outside the set gives way to the first that can '
        'lead', () {
      expect(resolvePlayFromHome([a, b], c, all), same(a));
      expect(resolvePlayFromHome([a, b], null, (s) => s == b), same(b));
    });

    test('a preferred one that cannot lead gives way to one that can', () {
      expect(resolvePlayFromHome([a, b, c], a, (s) => s != a), same(b));
    });

    test('when none can lead, the preferred one (or the first) anyway', () {
      expect(resolvePlayFromHome([a, b], b, none), same(b));
      expect(resolvePlayFromHome([a, b], c, none), same(a));
    });
  });

  group('fanOutHomeBlocked', () {
    test('a server running sonic, new enough for a vector seed, can lead', () {
      expect(fanOutHomeBlocked(_sonic('a')), isNull);
      expect(fanOutHomeBlocked(_sonic('a')..discoveryReady = true), isNull);
    });

    test('discovery off, or not reported, cannot', () {
      expect(fanOutHomeBlocked(_sonic('a')..discoveryEnabled = false),
          FanOutSitOut.discoveryOff);
      expect(fanOutHomeBlocked(_server('a')..serverVersion = '6.26.0'),
          FanOutSitOut.unreachable);
    });

    test('still scanning cannot', () {
      expect(fanOutHomeBlocked(_sonic('a')..discoveryReady = false),
          FanOutSitOut.scanning);
    });

    test('a version from before the vector seed cannot', () {
      expect(fanOutHomeBlocked(_sonic('a')..serverVersion = '6.25.0'),
          FanOutSitOut.olderServer);
    });

    test('a peer whose discovery is not known yet cannot lead — it may only '
        'answer', () {
      expect(fanOutHomeBlocked(_peer('peer-basement')..serverVersion = '6.26.0'),
          FanOutSitOut.discoveryOff);
    });
  });

  group('autoDjPlayFrom / autoDjPlayFromSet (the live lists)', () {
    final mgr = AutoDJManager();
    String? saved;
    late bool savedAll;
    late List<String> savedServers;

    setUp(() {
      saved = mgr.playFromServer;
      savedAll = mgr.playFromAll;
      savedServers = mgr.playFromServers;
      mgr
        ..playFromAll = false
        ..playFromServers = const [];
      ServerManager().serverList
        ..clear()
        ..addAll([home, office]);
      ServerManager().currentServer = home;
    });
    tearDown(() {
      mgr
        ..playFromServer = saved
        ..playFromAll = savedAll
        ..playFromServers = savedServers;
      ServerManager().serverList.clear();
      ServerManager().currentServer = null;
    });

    test('reads AutoDJManager.playFromServer against ServerManager', () {
      mgr.playFromServer = 'office';
      expect(autoDjPlayFrom(), same(office));
      expect(autoDjPlayFromSet(), [office]);
      mgr.playFromServer = null;
      expect(autoDjPlayFrom(), same(home));
      expect(autoDjPlayFromSet(), [home]);
      mgr.playFromServer = 'gone';
      expect(autoDjPlayFrom(), same(home));
      expect(autoDjPlayFromSet(), [home]);
    });

    test('a chosen set, home among it, in the list\'s order', () {
      final den = _sonic('den');
      final lab = _sonic('lab');
      ServerManager().serverList.addAll([den, lab]);
      mgr
        ..playFromServers = ['lab', 'den']
        ..playFromServer = 'lab';
      expect(autoDjPlayFromSet(), [den, lab]);
      expect(autoDjPlayFrom(), same(lab));
    });

    test('a home that cannot lead hands the session to one that can', () {
      final den = _sonic('den');
      final lab = _sonic('lab')..discoveryEnabled = false;
      ServerManager().serverList.addAll([den, lab]);
      mgr
        ..playFromServers = ['den', 'lab']
        ..playFromServer = 'lab';
      expect(autoDjPlayFrom(), same(den));
    });

    test('All servers: every server, the home the stored one', () {
      mgr
        ..playFromAll = true
        ..playFromServer = 'office';
      expect(autoDjPlayFromSet(), [home, office]);
      expect(autoDjPlayFrom(), same(office),
          reason: 'neither can lead, so the stored home stays');
    });

    test('every chosen server gone: the browsed one alone', () {
      mgr
        ..playFromServers = ['gone', 'also-gone']
        ..playFromServer = 'gone';
      expect(autoDjPlayFromSet(), [home]);
      expect(autoDjPlayFrom(), same(home));
    });
  });
}
