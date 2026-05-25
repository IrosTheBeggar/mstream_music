import 'package:audio_service/audio_service.dart';
import '../media/audio_stuff.dart';

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
  }
}
