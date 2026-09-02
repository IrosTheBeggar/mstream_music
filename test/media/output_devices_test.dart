// ignore_for_file: experimental_member_use
import 'package:audio_session/audio_session.dart' show AudioDeviceType;
import 'package:flutter_test/flutter_test.dart';
import 'package:mstream_music/media/output_devices.dart';

void main() {
  group('isExternalOutput', () {
    test('things a person pairs or plugs in end the toggle window', () {
      for (final t in [
        AudioDeviceType.bluetoothA2dp,
        AudioDeviceType.bluetoothLe,
        AudioDeviceType.wiredHeadphones,
        AudioDeviceType.usbAudio,
        AudioDeviceType.carAudio,
      ]) {
        expect(isExternalOutput(t), isTrue, reason: '$t');
      }
    });

    test('the built-in speaker falling back does not', () {
      for (final t in [
        AudioDeviceType.builtInSpeaker,
        AudioDeviceType.builtInEarpiece,
        AudioDeviceType.builtInSpeakerSafe,
        AudioDeviceType.telephony,
        AudioDeviceType.remoteSubmix,
        AudioDeviceType.unknown,
      ]) {
        expect(isExternalOutput(t), isFalse, reason: '$t');
      }
    });
  });
}
