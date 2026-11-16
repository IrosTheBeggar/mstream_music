// The engine switch in front of just_audio's platform: a native player is
// made on the engine chosen at that moment and torn down by the engine that
// made it; a Media3 engine that cannot make one costs that player nothing
// but a log line; and the dispose-all just_audio fires before its first
// player reaches both engines ahead of that player's init.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:mstream_music/media/playback_engine.dart';

class FakeEngine extends JustAudioPlatform {
  FakeEngine(this.name, this.calls);

  final String name;
  // Shared between the two fakes, so it is the order the calls were MADE in:
  // each entry is added before the method's first await.
  final List<String> calls;
  Object? initError;
  Object? disposeAllError;

  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async {
    calls.add('$name.init:${request.id}');
    final error = initError;
    if (error != null) throw error;
    return _FakePlayer(request.id, name);
  }

  @override
  Future<DisposePlayerResponse> disposePlayer(
      DisposePlayerRequest request) async {
    calls.add('$name.dispose:${request.id}');
    return DisposePlayerResponse();
  }

  @override
  Future<DisposeAllPlayersResponse> disposeAllPlayers(
      DisposeAllPlayersRequest request) async {
    calls.add('$name.disposeAll');
    final error = disposeAllError;
    if (error != null) throw error;
    return DisposeAllPlayersResponse();
  }
}

class _FakePlayer extends AudioPlayerPlatform {
  _FakePlayer(super.id, this.engine);
  final String engine;
}

void main() {
  late List<String> calls;
  late List<String> log;
  late FakeEngine justAudio;
  late FakeEngine media3;
  late PlaybackEngineSwitch engines;

  setUp(() {
    calls = [];
    log = [];
    justAudio = FakeEngine('ja', calls);
    media3 = FakeEngine('m3', calls);
    engines = PlaybackEngineSwitch(
        justAudio: justAudio, media3: media3, log: log.add);
  });

  String engineOf(AudioPlayerPlatform p) => (p as _FakePlayer).engine;

  test('a player is made on the engine chosen when it is made', () async {
    expect(engineOf(await engines.init(InitRequest(id: 'a'))), 'ja');
    engines.useMedia3 = true;
    expect(engineOf(await engines.init(InitRequest(id: 'b'))), 'm3');
    engines.useMedia3 = false;
    expect(engineOf(await engines.init(InitRequest(id: 'c'))), 'ja');
    expect(calls, ['ja.init:a', 'm3.init:b', 'ja.init:c']);
    expect(log, isEmpty);
  });

  test('a player is disposed by the engine that made it, whatever the '
      'choice is by then', () async {
    engines.useMedia3 = true;
    await engines.init(InitRequest(id: 'on-media3'));
    engines.useMedia3 = false;
    await engines.init(InitRequest(id: 'on-just-audio'));
    calls.clear();

    // The hand-over: the old player goes after the choice has moved.
    await engines.disposePlayer(DisposePlayerRequest(id: 'on-media3'));
    engines.useMedia3 = true;
    await engines.disposePlayer(DisposePlayerRequest(id: 'on-just-audio'));

    expect(calls, ['m3.dispose:on-media3', 'ja.dispose:on-just-audio']);
  });

  test('an id no engine is known to hold is disposed through just_audio',
      () async {
    engines.useMedia3 = true;
    await engines.disposePlayer(DisposePlayerRequest(id: 'never-made'));
    // And a second dispose of a real one: the first forgot it.
    await engines.init(InitRequest(id: 'a'));
    await engines.disposePlayer(DisposePlayerRequest(id: 'a'));
    await engines.disposePlayer(DisposePlayerRequest(id: 'a'));
    expect(calls, [
      'ja.dispose:never-made',
      'm3.init:a',
      'm3.dispose:a',
      'ja.dispose:a',
    ]);
  });

  test('a Media3 engine that cannot make a player costs that player only '
      'a log line', () async {
    engines.useMedia3 = true;
    media3.initError = MissingPluginException('no media3_player');

    final player = await engines.init(InitRequest(id: 'a'));

    expect(engineOf(player), 'ja', reason: 'playback goes on, on just_audio');
    expect(log.single, contains('media3 engine could not make a player'));
    expect(engines.useMedia3, isTrue, reason: 'the choice stands');
    // Its teardown follows where it really is.
    await engines.disposePlayer(DisposePlayerRequest(id: 'a'));
    expect(calls, ['m3.init:a', 'ja.init:a', 'ja.dispose:a']);

    // And the next player tries the engine again.
    media3.initError = null;
    expect(engineOf(await engines.init(InitRequest(id: 'b'))), 'm3');
  });

  test('a just_audio failure is the caller\'s, as it was without the switch',
      () async {
    justAudio.initError = PlatformException(code: 'boom');
    await expectLater(engines.init(InitRequest(id: 'a')),
        throwsA(isA<PlatformException>()));
    // Nothing recorded for it: a later dispose falls to just_audio anyway.
    engines.useMedia3 = true;
    media3.initError = StateError('down');
    await expectLater(engines.init(InitRequest(id: 'b')),
        throwsA(isA<PlatformException>()));
  });

  test('dispose-all leaves for both engines before the init behind it',
      () async {
    // just_audio's own order: the dispose-all un-awaited, the init straight
    // after. A dispose-all still waiting on the other engine's reply would
    // land behind the init and destroy the player it had just made.
    final cleared = engines.disposeAllPlayers(DisposeAllPlayersRequest());
    final made = engines.init(InitRequest(id: 'first'));

    expect(calls, ['m3.disposeAll', 'ja.disposeAll', 'ja.init:first']);
    await cleared;
    await made;
  });

  test('dispose-all forgets who held what, and survives an engine that '
      'is not there', () async {
    engines.useMedia3 = true;
    await engines.init(InitRequest(id: 'a'));
    media3.disposeAllError = MissingPluginException('no media3_player');
    calls.clear();

    await engines.disposeAllPlayers(DisposeAllPlayersRequest());
    await engines.disposePlayer(DisposePlayerRequest(id: 'a'));

    expect(calls, ['m3.disposeAll', 'ja.disposeAll', 'ja.dispose:a']);
  });

  test('off Android there is nothing to choose', () {
    // The VM running this is not Android, so install() must leave
    // just_audio's platform exactly as it found it.
    final before = JustAudioPlatform.instance;
    PlaybackEngine.install(useMedia3: true);
    expect(JustAudioPlatform.instance, same(before));
    expect(PlaybackEngine.selectable, isFalse);
    expect(PlaybackEngine.usesMedia3, isFalse);
    PlaybackEngine.usesMedia3 = true;
    expect(PlaybackEngine.usesMedia3, isFalse);
  });
}
