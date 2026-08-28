import 'dart:io';

import 'package:flutter/services.dart';

/// What the platform side ended up showing for a hand-off.
enum TorrentPassOff {
  /// A real torrent client is installed — the ACTION_VIEW chooser opened.
  view,

  /// None is, so the share sheet opened instead (mail, Bluetooth, Phone Link…).
  send,

  /// Nothing on the device will take a .torrent at all; no chooser opened.
  none,

  /// The hand-off failed, or the platform has no implementation.
  error,
}

/// Hands a picked `.torrent` to some other app instead of adding it to an
/// mStream server — the escape hatch on the Add Torrent screen.
///
/// Android only. The native side stages the bytes in its own FileProvider
/// rather than forwarding the picker's URI (a received grant is not reliably
/// re-delegatable) and prefers an ACTION_VIEW chooser, falling back to
/// ACTION_SEND when no torrent client is installed.
class TorrentPassOffChannel {
  static const _channel = MethodChannel('mstream/torrent');

  /// Only Android implements the hand-off; everywhere else the button that
  /// calls this should not be on screen at all.
  static bool get isSupported => Platform.isAndroid;

  static Future<TorrentPassOff> openWith(
      Uint8List bytes, String? filename) async {
    if (!isSupported) return TorrentPassOff.error;
    try {
      final r = await _channel.invokeMethod<String>(
          'openWith', {'bytes': bytes, 'filename': filename});
      return switch (r) {
        'view' => TorrentPassOff.view,
        'send' => TorrentPassOff.send,
        'none' => TorrentPassOff.none,
        _ => TorrentPassOff.error,
      };
    } on PlatformException {
      return TorrentPassOff.error;
    } on MissingPluginException {
      return TorrentPassOff.error;
    }
  }
}
