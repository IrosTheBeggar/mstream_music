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
    audioHandler = await AudioService.init<AudioPlayerHandler>(
      builder: () => AudioPlayerHandler(),
      config: AudioServiceConfig(
        androidNotificationChannelName: 'mStream Music',
        androidNotificationOngoing: true,
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

    // DLNA casting discovery is Android-only (media_cast_dlna has no other
    // platform impl). Registering the discoverer is cheap — it only starts
    // scanning when the cast picker opens (CastManager.startDiscovery).
    if (Platform.isAndroid) {
      CastManager().registerDiscoverer(DlnaDeviceDiscoverer());
      CastManager().registerDiscoverer(ChromecastDeviceDiscoverer());
    }
  }
}
