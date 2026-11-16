import 'dart:async';

import 'package:flutter/services.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';

/// just_audio's platform, served by the in-repo Media3 engine
/// (android/…/EnginePlayer.kt) instead of just_audio's own Android code.
///
/// just_audio's Dart player talks to "the platform" through
/// [JustAudioPlatform]: [init] makes a native player and hands back the
/// [AudioPlayerPlatform] that drives it. This is that pair on the engine's
/// channels, so everything above — just_audio's playlist, its idle and load
/// handling, its position clock, and the app tuned against all of it — runs
/// unchanged on a player this repo owns.
///
/// Nothing here installs itself. just_audio asks [JustAudioPlatform.instance]
/// for a platform each time it needs a native player, and the app decides
/// what answers (see lib/media/playback_engine.dart).
///
/// Android only: the plugin registers no other platform, so on anything else
/// every call fails with a MissingPluginException.
class Media3JustAudio extends JustAudioPlatform {
  /// The plugin's main channel; a player's own are `…/methods/<id>` and
  /// `…/events/<id>`.
  static const String channelName = 'mstream/media3_player';

  static const MethodChannel _main = MethodChannel(channelName);

  @override
  Future<AudioPlayerPlatform> init(InitRequest request) async {
    await _main.invokeMethod<void>('init', request.toMap());
    return Media3AudioPlayer(request.id);
  }

  @override
  Future<DisposePlayerResponse> disposePlayer(
          DisposePlayerRequest request) async =>
      DisposePlayerResponse.fromMap((await _main
          .invokeMethod<Map<dynamic, dynamic>>(
              'disposePlayer', request.toMap()))!);

  @override
  Future<DisposeAllPlayersResponse> disposeAllPlayers(
          DisposeAllPlayersRequest request) async =>
      DisposeAllPlayersResponse.fromMap((await _main
          .invokeMethod<Map<dynamic, dynamic>>(
              'disposeAllPlayers', request.toMap()))!);
}

/// One native player of the engine. The method names and the maps are
/// just_audio's own (each request's `toMap`, each response's `fromMap`); only
/// the channel differs.
class Media3AudioPlayer extends AudioPlayerPlatform {
  final MethodChannel _channel;

  Media3AudioPlayer(super.id)
      : _channel = MethodChannel('${Media3JustAudio.channelName}/methods/$id');

  Future<Map<dynamic, dynamic>> _invoke(
          String method, Map<dynamic, dynamic> arguments) async =>
      (await _channel.invokeMethod<Map<dynamic, dynamic>>(method, arguments))!;

  @override
  Stream<PlaybackEventMessage> get playbackEventMessageStream =>
      EventChannel('${Media3JustAudio.channelName}/events/$id')
          .receiveBroadcastStream()
          .cast<Map<dynamic, dynamic>>()
          .map(PlaybackEventMessage.fromMap);

  // playerDataMessageStream keeps the interface's empty default: like
  // just_audio's own Android code, the engine reports everything through
  // playback events.

  @override
  Future<LoadResponse> load(LoadRequest request) async =>
      LoadResponse.fromMap(await _invoke('load', request.toMap()));

  @override
  Future<PlayResponse> play(PlayRequest request) async =>
      PlayResponse.fromMap(await _invoke('play', request.toMap()));

  @override
  Future<PauseResponse> pause(PauseRequest request) async =>
      PauseResponse.fromMap(await _invoke('pause', request.toMap()));

  @override
  Future<SetVolumeResponse> setVolume(SetVolumeRequest request) async =>
      SetVolumeResponse.fromMap(await _invoke('setVolume', request.toMap()));

  @override
  Future<SetSpeedResponse> setSpeed(SetSpeedRequest request) async =>
      SetSpeedResponse.fromMap(await _invoke('setSpeed', request.toMap()));

  @override
  Future<SetPitchResponse> setPitch(SetPitchRequest request) async =>
      SetPitchResponse.fromMap(await _invoke('setPitch', request.toMap()));

  @override
  Future<SetSkipSilenceResponse> setSkipSilence(
          SetSkipSilenceRequest request) async =>
      SetSkipSilenceResponse.fromMap(
          await _invoke('setSkipSilence', request.toMap()));

  @override
  Future<SetLoopModeResponse> setLoopMode(SetLoopModeRequest request) async =>
      SetLoopModeResponse.fromMap(
          await _invoke('setLoopMode', request.toMap()));

  @override
  Future<SetShuffleModeResponse> setShuffleMode(
          SetShuffleModeRequest request) async =>
      SetShuffleModeResponse.fromMap(
          await _invoke('setShuffleMode', request.toMap()));

  @override
  Future<SetShuffleOrderResponse> setShuffleOrder(
          SetShuffleOrderRequest request) async =>
      SetShuffleOrderResponse.fromMap(
          await _invoke('setShuffleOrder', request.toMap()));

  @override
  Future<SetAutomaticallyWaitsToMinimizeStallingResponse>
      setAutomaticallyWaitsToMinimizeStalling(
              SetAutomaticallyWaitsToMinimizeStallingRequest request) async =>
          SetAutomaticallyWaitsToMinimizeStallingResponse.fromMap(await _invoke(
              'setAutomaticallyWaitsToMinimizeStalling', request.toMap()));

  @override
  Future<SetCanUseNetworkResourcesForLiveStreamingWhilePausedResponse>
      setCanUseNetworkResourcesForLiveStreamingWhilePaused(
              SetCanUseNetworkResourcesForLiveStreamingWhilePausedRequest
                  request) async =>
          SetCanUseNetworkResourcesForLiveStreamingWhilePausedResponse.fromMap(
              await _invoke(
                  'setCanUseNetworkResourcesForLiveStreamingWhilePaused',
                  request.toMap()));

  @override
  Future<SetPreferredPeakBitRateResponse> setPreferredPeakBitRate(
          SetPreferredPeakBitRateRequest request) async =>
      SetPreferredPeakBitRateResponse.fromMap(
          await _invoke('setPreferredPeakBitRate', request.toMap()));

  @override
  Future<SetAllowsExternalPlaybackResponse> setAllowsExternalPlayback(
          SetAllowsExternalPlaybackRequest request) async =>
      SetAllowsExternalPlaybackResponse.fromMap(
          await _invoke('setAllowsExternalPlayback', request.toMap()));

  @override
  Future<SeekResponse> seek(SeekRequest request) async =>
      SeekResponse.fromMap(await _invoke('seek', request.toMap()));

  @override
  Future<SetAndroidAudioAttributesResponse> setAndroidAudioAttributes(
          SetAndroidAudioAttributesRequest request) async =>
      SetAndroidAudioAttributesResponse.fromMap(
          await _invoke('setAndroidAudioAttributes', request.toMap()));

  @override
  Future<DisposeResponse> dispose(DisposeRequest request) async =>
      DisposeResponse.fromMap(await _invoke('dispose', request.toMap()));

  @override
  Future<ConcatenatingInsertAllResponse> concatenatingInsertAll(
          ConcatenatingInsertAllRequest request) async =>
      ConcatenatingInsertAllResponse.fromMap(
          await _invoke('concatenatingInsertAll', request.toMap()));

  @override
  Future<ConcatenatingRemoveRangeResponse> concatenatingRemoveRange(
          ConcatenatingRemoveRangeRequest request) async =>
      ConcatenatingRemoveRangeResponse.fromMap(
          await _invoke('concatenatingRemoveRange', request.toMap()));

  @override
  Future<ConcatenatingMoveResponse> concatenatingMove(
          ConcatenatingMoveRequest request) async =>
      ConcatenatingMoveResponse.fromMap(
          await _invoke('concatenatingMove', request.toMap()));

  @override
  Future<AudioEffectSetEnabledResponse> audioEffectSetEnabled(
          AudioEffectSetEnabledRequest request) async =>
      AudioEffectSetEnabledResponse.fromMap(
          await _invoke('audioEffectSetEnabled', request.toMap()));

  @override
  Future<AndroidLoudnessEnhancerSetTargetGainResponse>
      androidLoudnessEnhancerSetTargetGain(
              AndroidLoudnessEnhancerSetTargetGainRequest request) async =>
          AndroidLoudnessEnhancerSetTargetGainResponse.fromMap(await _invoke(
              'androidLoudnessEnhancerSetTargetGain', request.toMap()));

  @override
  Future<AndroidEqualizerGetParametersResponse> androidEqualizerGetParameters(
          AndroidEqualizerGetParametersRequest request) async =>
      AndroidEqualizerGetParametersResponse.fromMap(
          await _invoke('androidEqualizerGetParameters', request.toMap()));

  @override
  Future<AndroidEqualizerBandSetGainResponse> androidEqualizerBandSetGain(
          AndroidEqualizerBandSetGainRequest request) async =>
      AndroidEqualizerBandSetGainResponse.fromMap(
          await _invoke('androidEqualizerBandSetGain', request.toMap()));
}
