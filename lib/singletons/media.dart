import 'package:audio_service/audio_service.dart';
import '../media/audio_stuff.dart';

class MediaManager {
  MediaManager._privateConstructor();
  static final MediaManager _instance = MediaManager._privateConstructor();
  factory MediaManager() {
    return _instance;
  }

  late AudioHandler audioHandler;

  start() async {
    audioHandler = await AudioService.init(
      builder: () => AudioPlayerHandler(),
      config: AudioServiceConfig(
        androidNotificationChannelName: 'mStream Music',
        androidNotificationOngoing: true,
      ),
    );
  }
}
