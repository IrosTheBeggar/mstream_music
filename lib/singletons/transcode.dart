import 'dart:async';
import 'package:rxdart/rxdart.dart';

/// Holds the user's transcoding preferences, sent to the mStream `/transcode`
/// endpoint when streaming. See the server's src/api/transcode.js for the
/// accepted values; [codec] / [bitrate] are passed as `&codec=` / `&bitrate=`
/// query params and a null value omits the param (server uses its default).
class TranscodeManager {
  bool transcodeOn = false;

  /// Selected codec, one of [codecs], or null = let the server pick its
  /// configured default.
  String? codec;

  /// Selected bitrate, one of [bitrates], or null = server default.
  String? bitrate;

  /// Values the mStream `/transcode` endpoint accepts (codecMap / bitrateSet in
  /// the server's src/api/transcode.js).
  static const List<String> codecs = ['mp3', 'opus', 'aac'];
  static const List<String> bitrates = ['64k', '96k', '128k', '192k'];

  late final BehaviorSubject<bool> _transcodeOnStream =
      BehaviorSubject<bool>.seeded(transcodeOn);

  TranscodeManager._privateConstructor();
  static final TranscodeManager _instance =
      TranscodeManager._privateConstructor();

  factory TranscodeManager() {
    return _instance;
  }

  void dispose() {
    _transcodeOnStream.close();
  } //initializes the subject with element already;

  Stream<bool> get currentServerStream => _transcodeOnStream.stream;
}
