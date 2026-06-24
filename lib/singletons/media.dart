import 'dart:io' show Platform;

import 'package:audio_service/audio_service.dart';
import '../media/audio_stuff.dart';
import '../media/dlna_discoverer.dart';
import '../media/chromecast_discoverer.dart';
import 'cast_manager.dart';

class MediaManager {
  MediaManager._privateConstructor();
  static final MediaManager _instance = MediaManager._privateConstructor();
  factory MediaManager() {
    return _instance;
  }

  late AudioPlayerHandler audioHandler;

  Future<void> start() async {
    // audio_service only has a platform implementation on Android, iOS, macOS,
    // and web — there's no Windows/Linux background service. On those desktop
    // platforms AudioService.init would fail (or hang on a missing channel), so
    // construct the handler directly: in-app playback works the same (the UI
    // reads the handler's playbackState/mediaItem/queue streams either way), we
    // just don't get OS media-session integration (media keys / SMTC / MPRIS).
    if (Platform.isAndroid || Platform.isIOS || Platform.isMacOS) {
      audioHandler = await AudioService.init<AudioPlayerHandler>(
        builder: () => AudioPlayerHandler(),
        config: AudioServiceConfig(
          androidNotificationChannelName: 'mStream Music',
          // Keep the foreground service alive across a pause instead of detaching
          // it (the default). On Samsung One UI, a detached/background service is
          // reaped within minutes by app-sleep/Doze, so a brief pause — including
          // an interruption-driven auto-pause — could leave the process dead and
          // playback unable to resume. Staying foreground while paused prevents
          // that. (androidNotificationOngoing must be dropped: audio_service
          // asserts !ongoing || stopForegroundOnPause.)
          androidStopForegroundOnPause: false,
          // White, tintable status-bar / Android Auto icon. Without this the
          // colored launcher icon renders as a white square in the notification.
          androidNotificationIcon: 'drawable/ic_stat_music',
          // Bound the memory used decoding remote album art for the notification,
          // lock screen, and Android Auto now-playing.
          artDownscaleWidth: 384,
          artDownscaleHeight: 384,
          // Android Auto content-style hints, returned in onGetRoot: albums look
          // best as a grid, tracks as a list. Harmless until the browse tree
          // (AudioPlayerHandler.getChildren) lands; per-node MediaItem.extras can
          // override these per category.
          androidBrowsableRootExtras: <String, dynamic>{
            AndroidContentStyle.supportedKey: true,
            AndroidContentStyle.browsableHintKey:
                AndroidContentStyle.gridItemHintValue,
            AndroidContentStyle.playableHintKey:
                AndroidContentStyle.listItemHintValue,
          },
        ),
      );
    } else {
      audioHandler = AudioPlayerHandler();
    }

    // DLNA casting discovery is Android-only (media_cast_dlna has no other
    // platform impl). Registering the discoverer is cheap — it only starts
    // scanning when the cast picker opens (CastManager.startDiscovery).
    if (Platform.isAndroid) {
      CastManager().registerDiscoverer(DlnaDeviceDiscoverer());
      CastManager().registerDiscoverer(ChromecastDeviceDiscoverer());
    }
  }
}
