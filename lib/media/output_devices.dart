// audio_session marks its device API @experimental. Its shape has been stable
// across 0.1.x → 0.2.x, and this is the one place that names the enum, so the
// warning is silenced here rather than sprinkled through the audio handler.
// ignore_for_file: experimental_member_use
import 'package:audio_session/audio_session.dart' show AudioDeviceType;

/// An output a person plugs in or pairs — the ones whose arrival means the
/// next media-button toggle is theirs again (see AudioPlayerHandler.click).
/// The built-in speaker "appearing" after a Bluetooth drop is only the route
/// falling back and must not count.
bool isExternalOutput(AudioDeviceType t) => switch (t) {
      AudioDeviceType.wiredHeadset ||
      AudioDeviceType.wiredHeadphones ||
      AudioDeviceType.lineAnalog ||
      AudioDeviceType.lineDigital ||
      AudioDeviceType.bluetoothA2dp ||
      AudioDeviceType.bluetoothSco ||
      AudioDeviceType.bluetoothLe ||
      AudioDeviceType.usbAudio ||
      AudioDeviceType.dock ||
      AudioDeviceType.hdmi ||
      AudioDeviceType.hdmiArc ||
      AudioDeviceType.displayPort ||
      AudioDeviceType.hearingAid ||
      AudioDeviceType.carAudio ||
      AudioDeviceType.auxLine ||
      AudioDeviceType.airPlay =>
        true,
      _ => false,
    };
