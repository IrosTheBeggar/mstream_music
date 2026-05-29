import 'dart:io' show Platform;

import 'package:audio_service/audio_service.dart';
import '../media/audio_stuff.dart';
import '../media/dlna_discoverer.dart';
import 'cast_manager.dart';

class MediaManager {
  MediaManager._privateConstructor();
  static final MediaManager _instance = MediaManager._privateConstructor();
  factory MediaManager() {
    return _instance;
  }

  late AudioPlayerHandler audioHandler;

  start() async {
    audioHandler = await AudioService.init<AudioPlayerHandler>(
      builder: () => AudioPlayerHandler(),
      config: AudioServiceConfig(
        androidNotificationChannelName: 'mStream Music',
        androidNotificationOngoing: true,
      ),
    );

    // DLNA casting discovery is Android-only (media_cast_dlna has no other
    // platform impl). Registering the discoverer is cheap — it only starts
    // scanning when the cast picker opens (CastManager.startDiscovery).
    if (Platform.isAndroid) {
      CastManager().registerDiscoverer(DlnaDeviceDiscoverer());
    }
  }
}
