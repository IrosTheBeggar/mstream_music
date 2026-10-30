// The per-output router over a scripted route and store: outputs are keyed
// by kind or by a hash of a Bluetooth address, profiles round-trip through
// JSON, and the router follows the route only while the feature is on —
// adopting the live curve when switched on, starting a new output from Flat,
// restoring a known one, recording saves against the output in use, and
// settling route flaps to the last one.

import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/media/eq_output_router.dart';

import '../screens/eq_fakes.dart';

Future<void> settle([int ms = 5]) =>
    Future<void>.delayed(Duration(milliseconds: ms));

void main() {
  group('EqOutput.fromRoute', () {
    test('a Bluetooth device is its own output, keyed by a hash, named', () {
      final a = EqOutput.fromRoute(
          route('bluetooth', name: ' Mazda ', address: 'AA:BB:CC'));
      final b = EqOutput.fromRoute(
          route('bluetooth', name: 'Mazda', address: 'AA:BB:CC'));
      final c = EqOutput.fromRoute(
          route('bluetooth', name: 'Buds', address: '11:22:33'));
      expect(a.key, b.key);
      expect(a.key, startsWith('bluetooth:'));
      expect(a.key, isNot(contains('AA')));
      expect(a.name, 'Mazda');
      expect(c.key, isNot(a.key));
      expect(EqOutput.fromRoute(route('bluetooth')).key, 'bluetooth',
          reason: 'no address: one bucket');
    });

    test('other kinds are one output each and unnamed; unknown is other', () {
      final s = EqOutput.fromRoute(route('speaker', name: 'sdk_gphone'));
      expect(s.key, 'speaker');
      expect(s.name, '');
      expect(EqOutput.fromRoute(route('wired')).kind, EqOutputKind.wired);
      expect(EqOutput.fromRoute(route('usb')).kind, EqOutputKind.usb);
      expect(EqOutput.fromRoute(route('hdmi')).kind, EqOutputKind.hdmi);
      expect(EqOutput.fromRoute(route('pigeon')).kind, EqOutputKind.other);
      expect(EqOutput.fromRoute(const {}).kind, EqOutputKind.other);
    });
  });

  group('EqOutputProfile', () {
    test('JSON round trip; malformed entries read as nothing', () {
      final p = EqOutputProfile(
          key: 'bluetooth:abcd',
          kind: EqOutputKind.bluetooth,
          name: 'Mazda',
          gains: const [1, 2.5, -3],
          lastUsed: DateTime.utc(2026, 10, 30, 12));
      final back = EqOutputProfile.fromJson(p.toJson())!;
      expect(back.key, p.key);
      expect(back.kind, EqOutputKind.bluetooth);
      expect(back.name, 'Mazda');
      expect(back.gains, [1, 2.5, -3]);
      expect(back.lastUsed, p.lastUsed);
      expect(EqOutputProfile.fromJson(null), isNull);
      expect(EqOutputProfile.fromJson({'key': 'x'}), isNull);
      expect(EqOutputProfile.fromJson({'key': '', 'gains': [1]}), isNull);
      expect(EqOutputProfile.fromJson({'key': 'x', 'gains': []}), isNull);
      expect(EqOutputProfile.fromJson({'key': 'x', 'gains': ['a']}), isNull);
      final loose = EqOutputProfile.fromJson({'key': 'x', 'gains': [1]})!;
      expect(loose.kind, EqOutputKind.other);
      expect(loose.name, '');
      expect(loose.lastUsed, DateTime.fromMillisecondsSinceEpoch(0));
    });
  });

  group('EqOutputRouter', () {
    late FakeRoutePort port;
    late FakeOutputStore store;
    late List<List<double>> applied;
    late List<double> live;

    EqOutputRouter make() => EqOutputRouter(
          port: port,
          store: store,
          applyGains: (g) async {
            applied.add(List<double>.of(g));
            live = List<double>.of(g);
          },
          readGains: () => live,
          frequencies: const [60, 230, 910, 3600, 14000],
          minDb: -15,
          maxDb: 15,
          settle: const Duration(milliseconds: 1),
        );

    setUp(() {
      port = FakeRoutePort(route('speaker'));
      store = FakeOutputStore();
      applied = [];
      live = [1, 2, 3, 4, 5];
    });

    test('off: follows the route, applies nothing, remembers nothing',
        () async {
      final r = make();
      await r.start();
      expect(r.current!.key, 'speaker');
      expect(applied, isEmpty);
      expect(store.profiles, isEmpty);
      port.emit(route('bluetooth', name: 'Mazda', address: 'A'));
      await settle();
      expect(r.current!.name, 'Mazda');
      expect(applied, isEmpty);
      r.dispose();
    });

    test('switching on adopts the curve in use for the output in use',
        () async {
      final r = make();
      await r.start();
      var notified = 0;
      r.addListener(() => notified++);
      await r.setEnabled(true);
      expect(store.perOutput, isTrue);
      expect(store.profiles.single.key, 'speaker');
      expect(store.profiles.single.gains, [1, 2, 3, 4, 5]);
      expect(applied, isEmpty, reason: 'nothing changes under the ears');
      expect(notified, 1);
      r.dispose();
    });

    test('a new output starts from Flat, a known one gets its curve back, names refresh',
        () async {
      store.perOutput = true;
      final r = make();
      await r.start();
      expect(applied, [
        [0, 0, 0, 0, 0]
      ], reason: 'the speaker was unknown');
      live = [3, 0, 0, 0, 3];
      await r.recordGains(live);
      port.emit(route('bluetooth', name: 'Mazda', address: 'A'));
      await settle();
      expect(applied.last, [0, 0, 0, 0, 0]);
      expect(r.current!.key, startsWith('bluetooth:'));
      live = [5, 3, -1, 3, 5];
      await r.recordGains(live);
      port.emit(route('speaker'));
      await settle();
      expect(applied.last, [3, 0, 0, 0, 3]);
      port.emit(route('bluetooth', name: 'Mazda CX-5', address: 'A'));
      await settle();
      expect(applied.last, [5, 3, -1, 3, 5]);
      expect(r.profileOf(r.current!.key)!.name, 'Mazda CX-5');
      expect(r.profiles.first.key, r.current!.key,
          reason: 'most recently used first');
      expect(r.profiles, hasLength(2));
      r.dispose();
    });

    test('route flaps settle to the last one', () async {
      store.perOutput = true;
      final r = make();
      await r.start();
      applied.clear();
      port.emit(route('bluetooth', name: 'A', address: 'A'));
      port.emit(route('speaker'));
      port.emit(route('bluetooth', name: 'B', address: 'B'));
      await settle();
      expect(applied, hasLength(1));
      expect(r.current!.name, 'B');
      r.dispose();
    });

    test('recordGains only while on, against the output in use', () async {
      final r = make();
      await r.start();
      await r.recordGains([9, 9, 9, 9, 9]);
      expect(store.profiles, isEmpty);
      await r.setEnabled(true);
      await r.recordGains([9, 9, 9, 9, 9]);
      expect(r.profileOf('speaker')!.gains, [9, 9, 9, 9, 9]);
      r.dispose();
    });

    test('a curve picked for an output is live only for the one in use; forget drops it',
        () async {
      store.perOutput = true;
      final r = make();
      await r.start();
      port.emit(route('bluetooth', name: 'Mazda', address: 'A'));
      await settle();
      final car = r.current!.key;
      applied.clear();
      await r.setProfileGains('speaker', [1, 1, 1, 1, 1]);
      expect(r.profileOf('speaker')!.gains, [1, 1, 1, 1, 1]);
      expect(applied, isEmpty);
      await r.setProfileGains(car, [2, 2, 2, 2, 2]);
      expect(applied, [
        [2, 2, 2, 2, 2]
      ]);
      await r.setProfileGains('nope', [3, 3, 3, 3, 3]);
      expect(applied, hasLength(1));
      await r.forget('speaker');
      expect(r.profileOf('speaker'), isNull);
      expect(r.profiles.map((p) => p.key), [car]);
      r.dispose();
    });

    test('a failing apply is logged, not thrown; a route after dispose is ignored',
        () async {
      store.perOutput = true;
      final r = EqOutputRouter(
        port: port,
        store: store,
        applyGains: (_) async => throw StateError('no engine'),
        readGains: () => live,
        frequencies: const [60, 230, 910, 3600, 14000],
        settle: const Duration(milliseconds: 1),
      );
      await r.start();
      expect(r.current!.key, 'speaker');
      expect(store.profiles.single.key, 'speaker');
      r.dispose();
      port.emit(route('wired'));
      await settle();
      expect(store.profiles.map((p) => p.key), ['speaker']);
    });
  });
}
