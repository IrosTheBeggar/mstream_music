import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/media/audio_stuff.dart';
import 'package:mstream_music/media/playback_backend.dart';

void main() {
  group('AudioPlayerHandler.shouldHoldWifiLock', () {
    // The lock is the Wi-Fi half of ExoPlayer's WAKE_MODE_NETWORK: held ONLY
    // while the phone actively moves audio bytes over the network. Holding it
    // any longer (paused, parked, on-disk files) is a battery bug; holding it
    // any less re-opens the screen-off power-save stall this exists to
    // prevent.

    test('local player streaming a network source → hold', () {
      for (final state in [
        BackendProcessingState.loading,
        BackendProcessingState.buffering,
        BackendProcessingState.ready,
      ]) {
        expect(
          AudioPlayerHandler.shouldHoldWifiLock(
              playing: true,
              onLocalBackend: true,
              processingState: state,
              itemIsNetworkSource: true,
              castRelaysViaPhone: false),
          isTrue,
          reason: 'playing a network source in $state must hold the lock',
        );
      }
    });

    test('paused → release, regardless of everything else', () {
      expect(
        AudioPlayerHandler.shouldHoldWifiLock(
            playing: false,
            onLocalBackend: true,
            processingState: BackendProcessingState.ready,
            itemIsNetworkSource: true,
            castRelaysViaPhone: false),
        isFalse,
      );
      expect(
        AudioPlayerHandler.shouldHoldWifiLock(
            playing: false,
            onLocalBackend: false,
            processingState: BackendProcessingState.ready,
            itemIsNetworkSource: true,
            castRelaysViaPhone: true),
        isFalse,
        reason: 'a paused cast relay moves no bytes',
      );
    });

    test('on-disk file → never (no network to keep awake)', () {
      expect(
        AudioPlayerHandler.shouldHoldWifiLock(
            playing: true,
            onLocalBackend: true,
            processingState: BackendProcessingState.ready,
            itemIsNetworkSource: false,
            castRelaysViaPhone: false),
        isFalse,
      );
    });

    test('parked (idle) or completed → release even with play still set', () {
      for (final state in [
        BackendProcessingState.idle,
        BackendProcessingState.completed,
      ]) {
        expect(
          AudioPlayerHandler.shouldHoldWifiLock(
              playing: true,
              onLocalBackend: true,
              processingState: state,
              itemIsNetworkSource: true,
              castRelaysViaPhone: false),
          isFalse,
          reason: '$state moves no bytes — holding would drain battery',
        );
      }
    });

    test('cast fed from the phone (iroh relay / local file / viz HLS) → hold',
        () {
      // itemIsNetworkSource false here mirrors the local-file cast: the item
      // plays from disk, but the PHONE is still the renderer's byte origin.
      expect(
        AudioPlayerHandler.shouldHoldWifiLock(
            playing: true,
            onLocalBackend: false,
            processingState: BackendProcessingState.ready,
            itemIsNetworkSource: false,
            castRelaysViaPhone: true),
        isTrue,
      );
    });

    test('casting a plain HTTP track (renderer streams direct) → release', () {
      expect(
        AudioPlayerHandler.shouldHoldWifiLock(
            playing: true,
            onLocalBackend: false,
            processingState: BackendProcessingState.ready,
            itemIsNetworkSource: true,
            castRelaysViaPhone: false),
        isFalse,
      );
    });
  });
}
