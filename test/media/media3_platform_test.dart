// The Dart half of the in-repo Media3 engine (packages/media3_player): it is
// just_audio's platform on the engine's own channels. These pin the contract
// the Kotlin half (EnginePlayer.kt) is written against — the channel names,
// just_audio's method names and maps going out, its maps coming back — since
// a mismatch there shows up only as a player that never loads.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';
import 'package:media3_player/media3_player.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  const main = MethodChannel('mstream/media3_player');
  final mainCalls = <MethodCall>[];

  setUp(() {
    mainCalls.clear();
    messenger.setMockMethodCallHandler(main, (call) async {
      mainCalls.add(call);
      return call.method == 'init' ? null : <String, Object?>{};
    });
  });
  tearDown(() => messenger.setMockMethodCallHandler(main, null));

  // Answer one player's method channel from [reply], recording the calls.
  List<MethodCall> servePlayer(String id,
      Object? Function(MethodCall call) reply) {
    final calls = <MethodCall>[];
    final channel = MethodChannel('mstream/media3_player/methods/$id');
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return reply(call);
    });
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    return calls;
  }

  test('init makes the native player on the main channel and hands back '
      'its platform', () async {
    final player = await Media3JustAudio().init(InitRequest(
      id: 'p1',
      androidAudioEffects: [AndroidEqualizerMessage(enabled: true, parameters: null)],
    ));

    expect(player.id, 'p1');
    expect(mainCalls.single.method, 'init');
    final args = mainCalls.single.arguments as Map;
    expect(args['id'], 'p1');
    expect(args['useLazyPreparation'], isTrue);
    expect((args['androidAudioEffects'] as List).single,
        containsPair('type', 'AndroidEqualizer'));
  });

  test('disposing goes to the main channel too', () async {
    final engine = Media3JustAudio();
    await engine.disposePlayer(DisposePlayerRequest(id: 'p1'));
    await engine.disposeAllPlayers(DisposeAllPlayersRequest());
    expect(mainCalls.map((c) => c.method),
        ['disposePlayer', 'disposeAllPlayers']);
    expect((mainCalls.first.arguments as Map)['id'], 'p1');
  });

  test('a load carries just_audio\'s source map out and the duration back',
      () async {
    final calls = servePlayer('p1',
        (call) => call.method == 'load' ? {'duration': 187000000} : {});
    final player = await Media3JustAudio().init(InitRequest(id: 'p1'));

    final response = await player.load(LoadRequest(
      audioSourceMessage: ConcatenatingAudioSourceMessage(
        id: '',
        children: [
          ProgressiveAudioSourceMessage(
              id: 'a', uri: 'http://10.0.2.2:3121/media/demo/a.flac?token=t'),
          ProgressiveAudioSourceMessage(id: 'b', uri: 'file:///sdcard/b.mp3'),
        ],
        useLazyPreparation: true,
        shuffleOrder: const [1, 0],
      ),
      initialIndex: 1,
      initialPosition: const Duration(seconds: 42),
    ));

    expect(response.duration, const Duration(seconds: 187));
    final args = calls.single.arguments as Map;
    expect(calls.single.method, 'load');
    expect(args['initialIndex'], 1);
    expect(args['initialPosition'], 42000000, reason: 'microseconds');
    final source = args['audioSource'] as Map;
    // The root playlist's id is the empty string; the engine keys on that.
    expect(source['id'], '');
    expect(source['shuffleOrder'], [1, 0]);
    final children = source['children'] as List;
    expect(children.map((c) => (c as Map)['type']), everyElement('progressive'));
    expect((children.first as Map)['uri'],
        'http://10.0.2.2:3121/media/demo/a.flac?token=t');
  });

  test('transport and playlist calls keep just_audio\'s names and fields',
      () async {
    final calls = servePlayer('p1', (_) => <String, Object?>{});
    final player = await Media3JustAudio().init(InitRequest(id: 'p1'));

    await player.play(PlayRequest());
    await player.pause(PauseRequest());
    await player.seek(
        SeekRequest(position: const Duration(milliseconds: 1500), index: 3));
    await player.setVolume(SetVolumeRequest(volume: 0.5));
    await player.setSpeed(SetSpeedRequest(speed: 1.25));
    await player.setLoopMode(SetLoopModeRequest(loopMode: LoopModeMessage.all));
    await player.setShuffleMode(
        SetShuffleModeRequest(shuffleMode: ShuffleModeMessage.all));
    await player.concatenatingInsertAll(ConcatenatingInsertAllRequest(
      id: '',
      index: 2,
      children: [ProgressiveAudioSourceMessage(id: 'c', uri: 'http://x/c.ogg')],
      shuffleOrder: const [2, 0, 1],
    ));
    await player.concatenatingRemoveRange(ConcatenatingRemoveRangeRequest(
        id: '', startIndex: 0, endIndex: 1, shuffleOrder: const [1, 0]));
    await player.concatenatingMove(ConcatenatingMoveRequest(
        id: '', currentIndex: 0, newIndex: 1, shuffleOrder: const [0, 1]));
    await player.setAndroidAudioAttributes(SetAndroidAudioAttributesRequest(
        contentType: 2, flags: 0, usage: 1));

    Map args(String method) =>
        calls.singleWhere((c) => c.method == method).arguments as Map;
    expect(calls.map((c) => c.method), [
      'play',
      'pause',
      'seek',
      'setVolume',
      'setSpeed',
      'setLoopMode',
      'setShuffleMode',
      'concatenatingInsertAll',
      'concatenatingRemoveRange',
      'concatenatingMove',
      'setAndroidAudioAttributes',
    ]);
    expect(args('seek'), {'position': 1500000, 'index': 3});
    expect(args('setVolume'), {'volume': 0.5});
    expect(args('setSpeed'), {'speed': 1.25});
    // The engine reads these two as ExoPlayer's own values: 0 off, 1 one,
    // 2 all; and shuffle on is 1.
    expect(args('setLoopMode'), {'loopMode': 2});
    expect(args('setShuffleMode'), {'shuffleMode': 1});
    expect(args('concatenatingInsertAll')['index'], 2);
    expect(args('concatenatingInsertAll')['shuffleOrder'], [2, 0, 1]);
    expect(args('concatenatingRemoveRange'),
        {'id': '', 'startIndex': 0, 'endIndex': 1, 'shuffleOrder': [1, 0]});
    expect(args('concatenatingMove'),
        {'id': '', 'currentIndex': 0, 'newIndex': 1, 'shuffleOrder': [0, 1]});
    expect(args('setAndroidAudioAttributes'),
        {'contentType': 2, 'flags': 0, 'usage': 1});
  });

  test('the five-band equalizer\'s calls and its parameters', () async {
    final calls = servePlayer(
        'p1',
        (call) => call.method == 'androidEqualizerGetParameters'
            ? {
                'parameters': {
                  'minDecibels': -15.0,
                  'maxDecibels': 15.0,
                  'bands': [
                    {
                      'index': 0,
                      'lowerFrequency': 30.0,
                      'upperFrequency': 120.0,
                      'centerFrequency': 60.0,
                      'gain': 3.0,
                    },
                  ],
                },
              }
            : {});
    final player = await Media3JustAudio().init(InitRequest(id: 'p1'));

    await player.audioEffectSetEnabled(
        AudioEffectSetEnabledRequest(type: 'AndroidEqualizer', enabled: true));
    final got = await player
        .androidEqualizerGetParameters(AndroidEqualizerGetParametersRequest());
    await player.androidEqualizerBandSetGain(
        AndroidEqualizerBandSetGainRequest(bandIndex: 0, gain: -4.5));

    expect(got.parameters.minDecibels, -15.0);
    expect(got.parameters.bands.single.centerFrequency, 60.0);
    expect(got.parameters.bands.single.gain, 3.0);
    expect(calls.first.arguments, {'type': 'AndroidEqualizer', 'enabled': true});
    expect(calls.last.method, 'androidEqualizerBandSetGain');
    expect(calls.last.arguments, {'bandIndex': 0, 'gain': -4.5});
  });

  test('playback events come off the player\'s own event channel', () async {
    const events = EventChannel('mstream/media3_player/events/p1');
    messenger.setMockStreamHandler(
        events,
        MockStreamHandler.inline(onListen: (_, sink) {
          // What EnginePlayer.createEvent sends: times in microseconds
          // except updateTime, an epoch in milliseconds.
          sink.success({
            'processingState': 3,
            'updatePosition': 12000000,
            'updateTime': 1700000000000,
            'bufferedPosition': 30000000,
            'icyMetadata': <String, Object?>{},
            'duration': 200000000,
            'currentIndex': 4,
            'androidAudioSessionId': 1337,
            'errorCode': null,
            'errorMessage': null,
          });
        }));
    addTearDown(() => messenger.setMockStreamHandler(events, null));
    final player = await Media3JustAudio().init(InitRequest(id: 'p1'));

    final event = await player.playbackEventMessageStream.first;

    expect(event.processingState, ProcessingStateMessage.ready);
    expect(event.updatePosition, const Duration(seconds: 12));
    expect(event.bufferedPosition, const Duration(seconds: 30));
    expect(event.duration, const Duration(seconds: 200));
    expect(event.currentIndex, 4);
    expect(event.androidAudioSessionId, 1337);
    expect(event.errorCode, isNull);
  });

  test('a failed call surfaces as the PlatformException just_audio reads',
      () async {
    servePlayer(
        'p1',
        (_) => throw PlatformException(
            code: '0', message: 'Source error', details: {'index': 2}));
    final player = await Media3JustAudio().init(InitRequest(id: 'p1'));

    await expectLater(
        player.load(LoadRequest(
            audioSourceMessage: ConcatenatingAudioSourceMessage(
                id: '',
                children: const [],
                useLazyPreparation: true,
                shuffleOrder: const []))),
        throwsA(isA<PlatformException>()
            .having((e) => e.code, 'code', '0')
            .having((e) => e.message, 'message', 'Source error')));
  });
}
