import 'package:audio_service/audio_service.dart';
import '../media/audio_stuff.dart';

class LolManager {
  LolManager._privateConstructor();
  static final LolManager _instance = LolManager._privateConstructor();
  factory LolManager() {
    return _instance;
  }

  late AudioHandler audioHandler;

  start() async {
    audioHandler = await AudioService.init(
      builder: () => AudioPlayerHandler(),
      config: AudioServiceConfig(
        androidNotificationChannelName: 'Audio Service Demo',
        androidNotificationOngoing: true,
        androidEnableQueue: true,
      ),
    );
  }
}
