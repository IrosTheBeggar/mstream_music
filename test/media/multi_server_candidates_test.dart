import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/media/audio_stuff.dart';
import 'package:mstream_music/objects/server.dart';

// Who may take part in a multi-server Auto DJ session (mStream #929/#946):
// the pure predicate behind AudioPlayerHandler.multiServerCandidates, and
// the servers Play from names, which bound it.

Server _server(String name,
        {String? version = '6.26.0', bool? discovery = true, bool? ready}) =>
    Server('https://$name.example.com', 'u', 'p', 'JWT', name)
      ..serverVersion = version
      ..discoveryEnabled = discovery
      ..discoveryReady = ready;

Server _quickConnect(String name, {bool? discovery = true}) =>
    Server('iroh://$name', 'u', 'p', 'JWT', name)
      ..connectionType = 'iroh'
      ..serverVersion = '6.26.0'
      ..discoveryEnabled = discovery;

Server _peer({bool hidden = false, bool missing = false}) =>
    Server('federated://home/3', null, null, null, 'peer-basement')
      ..federationParent = 'home'
      ..federationPeerId = 3
      ..federationPeerName = 'Basement'
      ..serverVersion = '6.26.0'
      ..discoveryAvailable = false // pinned by the app for every peer
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

    test('a peer joins with its UI flag pinned false — the raw flags and '
        'health decide for it', () {
      // ServerManager._applyFederatedDefaults pins the UI flag; the two
      // routes the fan-out uses are allowlisted regardless. Unknown raw
      // flags: the model handshake asks the peer before anything is sent.
      expect(AudioPlayerHandler.canJoinMultiServer(_peer(), {}), isTrue);
      expect(
          AudioPlayerHandler.canJoinMultiServer(
              _peer()..discoveryEnabled = false, {}),
          isFalse,
          reason: 'the peer itself says discovery is off');
      expect(
          AudioPlayerHandler.canJoinMultiServer(
              _server('a', discovery: false), {}),
          isFalse,
          reason: 'a plain server still needs the flag');
    });

    test('discovery on but nothing analysed yet (discoveryReady false) sits '
        'out — plain server and peer alike', () {
      expect(
          AudioPlayerHandler.canJoinMultiServer(
              _server('a', ready: false), {}),
          isFalse);
      expect(
          AudioPlayerHandler.canJoinMultiServer(
              _server('a', ready: false), {},
              allowUnknownDiscovery: true),
          isFalse,
          reason: 'not unknown — the server said no');
      expect(
          AudioPlayerHandler.canJoinMultiServer(
              _peer()..discoveryReady = false, {}),
          isFalse);
      expect(
          AudioPlayerHandler.canJoinMultiServer(_server('a', ready: true), {}),
          isTrue);
    });

    test('a record from before the raw flag falls back to the UI flag', () {
      final old = Server('https://old.example.com', 'u', 'p', 'JWT', 'old')
        ..serverVersion = '6.26.0'
        ..discoveryAvailable = true;
      expect(AudioPlayerHandler.canJoinMultiServer(old, {}), isTrue);
    });

    test('a hidden peer, or one its parent stopped listing, sits out', () {
      expect(AudioPlayerHandler.canJoinMultiServer(_peer(hidden: true), {}),
          isFalse);
      expect(AudioPlayerHandler.canJoinMultiServer(_peer(missing: true), {}),
          isFalse);
    });

    // A mood (mStream #1096) only means something on a server that can
    // filter by it; any other would answer from outside the mood.
    group('while a mood is set', () {
      test('only a server that can filter by it joins', () {
        final can = _server('a')..moodFiltersAvailable = true;
        final cannot = _server('b')..moodFiltersAvailable = false;
        expect(AudioPlayerHandler.canJoinMultiServer(can, {}, moodSet: true),
            isTrue);
        expect(
            AudioPlayerHandler.canJoinMultiServer(cannot, {}, moodSet: true),
            isFalse);
        expect(AudioPlayerHandler.canJoinMultiServer(cannot, {}), isTrue,
            reason: 'without a mood the flag does not matter');
      });

      test('a peer, whose flag the app pins off, sits out', () {
        final peer = _peer()..moodFiltersAvailable = false;
        expect(AudioPlayerHandler.canJoinMultiServer(peer, {}, moodSet: true),
            isFalse);
        expect(
            AudioPlayerHandler.canJoinMultiServer(peer, {},
                moodSet: true, allowUnknownDiscovery: true),
            isFalse,
            reason: 'a known "cannot" is not dialed either');
      });

      test('an unreported server waits for its flags — except as a tunnel '
          'target, where reaching it is what fills them in', () {
        final unknown = _server('a'); // moodFiltersAvailable: null
        expect(
            AudioPlayerHandler.canJoinMultiServer(unknown, {}, moodSet: true),
            isFalse);
        expect(
            AudioPlayerHandler.canJoinMultiServer(unknown, {},
                moodSet: true, allowUnknownDiscovery: true),
            isTrue);
      });
    });
  });

  // The reason behind each "sits out" above, for the Auto DJ screen's Play
  // from sheet (one short word per server). canJoinMultiServer is now this
  // with the reason thrown away.
  group('AudioPlayerHandler.sitOutReason', () {
    FanOutSitOut? why(Server s,
            {Set<String> excluded = const {},
            Map<String, FanOutSitOut> reasons = const {},
            bool allowUnknownDiscovery = false,
            bool moodSet = false}) =>
        AudioPlayerHandler.sitOutReason(s, excluded,
            why: reasons,
            allowUnknownDiscovery: allowUnknownDiscovery,
            moodSet: moodSet);

    test('a server that may take part has no reason', () {
      expect(why(_server('a')), isNull);
      expect(why(_server('a', version: null)), isNull);
      expect(why(_server('a', ready: true)), isNull);
      expect(why(_peer()), isNull);
      expect(why(_server('a', discovery: null), allowUnknownDiscovery: true),
          isNull);
      expect(why(_server('a')..moodFiltersAvailable = true, moodSet: true),
          isNull);
    });

    test('discovery switched off', () {
      expect(why(_server('a', discovery: false)), FanOutSitOut.discoveryOff);
      expect(why(_peer()..discoveryEnabled = false), FanOutSitOut.discoveryOff);
      expect(
          why(_server('a', discovery: false), allowUnknownDiscovery: true),
          FanOutSitOut.discoveryOff);
    });

    test('discovery on but nothing analysed yet', () {
      expect(why(_server('a', ready: false)), FanOutSitOut.scanning);
      expect(why(_peer()..discoveryReady = false), FanOutSitOut.scanning);
      expect(why(_server('a', ready: false), allowUnknownDiscovery: true),
          FanOutSitOut.scanning);
    });

    test('a version known to predate the vector seed', () {
      expect(why(_server('a', version: '6.25.0')), FanOutSitOut.olderServer);
      expect(why(_server('a', version: '5.0.0')), FanOutSitOut.olderServer);
      expect(why(_server('a', version: '6.4.2-velvet')), isNull,
          reason: 'a fork is not known to be anything');
    });

    test('a mood nothing on the server can filter by', () {
      expect(why(_server('a')..moodFiltersAvailable = false, moodSet: true),
          FanOutSitOut.noMood);
      expect(why(_server('a'), moodSet: true), FanOutSitOut.noMood,
          reason: 'never reported its mood flag');
      expect(why(_peer()..moodFiltersAvailable = false, moodSet: true),
          FanOutSitOut.noMood);
      expect(
          why(_peer()..moodFiltersAvailable = false,
              moodSet: true, allowUnknownDiscovery: true),
          FanOutSitOut.noMood);
      expect(why(_server('a'), moodSet: true, allowUnknownDiscovery: true),
          isNull,
          reason: 'a tunnel target is dialed to learn its flags');
      expect(why(_server('a')..moodFiltersAvailable = false), isNull,
          reason: 'without a mood the flag does not matter');
    });

    test('unreachable: never reported, hidden or no longer listed', () {
      expect(why(_server('a', discovery: null)), FanOutSitOut.unreachable);
      expect(why(_peer(hidden: true)), FanOutSitOut.unreachable);
      expect(why(_peer(missing: true)), FanOutSitOut.unreachable);
    });

    test('dropped this session: the why map names it, unreachable without '
        'one', () {
      expect(why(_server('a'), excluded: {'a'}), FanOutSitOut.unreachable);
      expect(
          why(_server('a'),
              excluded: {'a'}, reasons: {'a': FanOutSitOut.otherModel}),
          FanOutSitOut.otherModel);
      expect(
          why(_server('a'),
              excluded: {'a'}, reasons: {'a': FanOutSitOut.olderServer}),
          FanOutSitOut.olderServer);
      expect(
          why(_server('a'), excluded: {'b'}, reasons: {'b': FanOutSitOut.otherModel}),
          isNull,
          reason: "another server's reason is not this one's");
      expect(why(_server('a'), reasons: {'a': FanOutSitOut.otherModel}), isNull,
          reason: 'a reason without the exclusion means nothing');
    });

    test('the session drop is checked first, then the listing, then the '
        'flags, then the mood, then the version', () {
      // Every rule failing at once: the earliest one names it.
      Server worst() => _peer(hidden: true)
        ..discoveryEnabled = false
        ..discoveryReady = false
        ..moodFiltersAvailable = false
        ..serverVersion = '6.25.0';
      expect(
          why(worst(),
              excluded: {'peer-basement'},
              reasons: {'peer-basement': FanOutSitOut.otherModel},
              moodSet: true),
          FanOutSitOut.otherModel);
      expect(why(worst(), moodSet: true), FanOutSitOut.unreachable);
      expect(why(worst()..federationHidden = false, moodSet: true),
          FanOutSitOut.discoveryOff);
      expect(
          why(worst()
                ..federationHidden = false
                ..discoveryEnabled = true,
              moodSet: true),
          FanOutSitOut.scanning);
      expect(
          why(worst()
                ..federationHidden = false
                ..discoveryEnabled = true
                ..discoveryReady = true,
              moodSet: true),
          FanOutSitOut.noMood);
      expect(
          why(worst()
                ..federationHidden = false
                ..discoveryEnabled = true
                ..discoveryReady = true,
              moodSet: false),
          FanOutSitOut.olderServer);
    });

    test('canJoinMultiServer is exactly "no reason" across every fixture', () {
      final fixtures = <String, Server Function()>{
        'plain': () => _server('a'),
        'unknown version': () => _server('a', version: null),
        'old version': () => _server('a', version: '6.25.0'),
        'fork': () => _server('a', version: '6.4.2-velvet'),
        'discovery off': () => _server('a', discovery: false),
        'discovery unreported': () => _server('a', discovery: null),
        'scanning': () => _server('a', ready: false),
        'ready': () => _server('a', ready: true),
        'mood can': () => _server('a')..moodFiltersAvailable = true,
        'mood cannot': () => _server('a')..moodFiltersAvailable = false,
        'peer': () => _peer(),
        'peer discovery off': () => _peer()..discoveryEnabled = false,
        'peer scanning': () => _peer()..discoveryReady = false,
        'peer mood pinned off': () => _peer()..moodFiltersAvailable = false,
        'hidden peer': () => _peer(hidden: true),
        'missing peer': () => _peer(missing: true),
        'legacy UI flag': () =>
            Server('https://old.example.com', 'u', 'p', 'JWT', 'old')
              ..serverVersion = '6.26.0'
              ..discoveryAvailable = true,
      };
      final exclusions = <Set<String>>[
        {},
        {'a'},
        {'b'},
        {'peer-basement'},
        {'old'},
      ];
      var checked = 0;
      for (final f in fixtures.entries) {
        for (final ex in exclusions) {
          for (final unknown in [false, true]) {
            for (final mood in [false, true]) {
              final s = f.value();
              final can = AudioPlayerHandler.canJoinMultiServer(s, ex,
                  allowUnknownDiscovery: unknown, moodSet: mood);
              final reason = AudioPlayerHandler.sitOutReason(s, ex,
                  allowUnknownDiscovery: unknown, moodSet: mood);
              expect(can, reason == null,
                  reason: '${f.key}, excluded $ex, unknown $unknown, '
                      'mood $mood: $reason');
              checked++;
            }
          }
        }
      }
      expect(checked, fixtures.length * exclusions.length * 4);
    });
  });

  // The same reasons as the Auto DJ screen shows them (the Play from sheet,
  // the participants readout): a Quick Connect server nothing has dialed yet
  // has had no chance to report its flags.
  group('AudioPlayerHandler.shownSitOut', () {
    FanOutSitOut? shown(Server s,
            {bool tunnelUp = false,
            Set<String> excluded = const {},
            Map<String, FanOutSitOut> reasons = const {},
            bool moodSet = false}) =>
        AudioPlayerHandler.shownSitOut(s, excluded,
            why: reasons, tunnelUp: (_) => tunnelUp, moodSet: moodSet);

    test('a Quick Connect server not reached yet is on its way, not '
        'unreachable', () {
      expect(shown(_quickConnect('b', discovery: null)), isNull);
      expect(shown(_quickConnect('b', discovery: null), moodSet: true), isNull,
          reason: 'its mood flag is just as unreported');
    });

    test('once its tunnel is up, flags it still has not reported count', () {
      expect(shown(_quickConnect('b', discovery: null), tunnelUp: true),
          FanOutSitOut.unreachable);
    });

    test('a standard server that never reported is unreachable — its ping is '
        'its chance', () {
      expect(shown(_server('a', discovery: null)), FanOutSitOut.unreachable);
      expect(shown(_server('a', discovery: null), tunnelUp: true),
          FanOutSitOut.unreachable);
    });

    test('what is known still shows while the tunnel is down', () {
      expect(shown(_quickConnect('b', discovery: false)),
          FanOutSitOut.discoveryOff);
      expect(shown(_quickConnect('b')..serverVersion = '6.25.0'),
          FanOutSitOut.olderServer);
      expect(
          shown(_quickConnect('b')..moodFiltersAvailable = false,
              moodSet: true),
          FanOutSitOut.noMood);
      expect(
          shown(_quickConnect('b'),
              excluded: {'b'}, reasons: {'b': FanOutSitOut.otherModel}),
          FanOutSitOut.otherModel,
          reason: 'dropped this session, reconnecting or not');
    });

    test('a Quick Connect server that has reported reads like any other', () {
      expect(shown(_quickConnect('b')), isNull);
      expect(shown(_quickConnect('b'), tunnelUp: true), isNull);
    });
  });

  // Play from names any set of servers; only those are asked, whatever the
  // others could do. All servers takes in every one, and the DJ's own server
  // is always in its session.
  group('AudioPlayerHandler.fanOutCandidates', () {
    final a = _server('a');
    final b = _server('b');
    final c = _server('c');
    final off = _server('off', discovery: false);
    List<String> names(List<Server> got) =>
        [for (final s in got) s.localname];
    List<String> ask(List<Server> servers,
            {bool all = false,
            List<String> chosen = const [],
            String? dj,
            Set<String> excluded = const {},
            bool allowUnknownDiscovery = false,
            bool moodSet = false}) =>
        names(AudioPlayerHandler.fanOutCandidates(servers,
            all: all,
            chosen: chosen,
            dj: dj,
            excluded: excluded,
            allowUnknownDiscovery: allowUnknownDiscovery,
            moodSet: moodSet));

    test('only the chosen servers are asked, in the list\'s order', () {
      expect(ask([a, b, c], chosen: ['c', 'a']), ['a', 'c']);
      expect(ask([a, b, c], chosen: ['b']), ['b']);
    });

    test('All servers asks every server that may take part', () {
      expect(ask([a, b, c, off], all: true), ['a', 'b', 'c']);
      expect(ask([a, b, c], all: true, chosen: ['a']), ['a', 'b', 'c'],
          reason: 'the chosen set does not narrow All servers');
    });

    test("the DJ's own server is in its session even when not chosen", () {
      expect(ask([a, b, c], chosen: ['a', 'b'], dj: 'c'), ['a', 'b', 'c']);
      expect(ask([a, b, c], dj: 'b'), ['b']);
    });

    test('a chosen server still has to be able to take part', () {
      expect(ask([a, off, c], chosen: ['a', 'off', 'c']), ['a', 'c']);
      expect(ask([a, b], chosen: ['a', 'b'], excluded: {'b'}), ['a'],
          reason: 'dropped this session');
      expect(ask([a, off], chosen: ['a', 'off'], dj: 'off'), ['a'],
          reason: 'not even the DJ\'s own, when it cannot');
    });

    test('a chosen name with no server behind it asks nobody', () {
      expect(ask([a, b], chosen: ['gone', 'a']), ['a']);
      expect(ask(const [], chosen: ['a'], dj: 'a'), isEmpty);
    });

    test('the tunnel targets and a mood pass through to the rule', () {
      final unreported = _server('u', discovery: null);
      expect(ask([a, unreported], chosen: ['a', 'u']), ['a']);
      expect(
          ask([a, unreported], chosen: ['a', 'u'], allowUnknownDiscovery: true),
          ['a', 'u']);
      final mood = _server('m')..moodFiltersAvailable = true;
      expect(ask([a, mood], chosen: ['a', 'm'], moodSet: true), ['m']);
    });
  });
}
