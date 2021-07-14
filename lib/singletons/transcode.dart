import 'dart:async';
import 'package:rxdart/rxdart.dart';

class TranscodeManager {
  bool transcodeOn = false;

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

  Stream<bool> get curentServerStream => _transcodeOnStream.stream;
}
