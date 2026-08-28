import 'dart:io';

import 'package:flutter/services.dart';

/// Both directions of the `mstream/torrent` platform channel: torrents
/// arriving from an Android intent, and torrents being handed back out to
/// another app. One owner, because a Dart MethodChannel handler is registered
/// per channel *name* — two classes setting a handler on this name would mean
/// whichever ran last silently wins.

/// A torrent that reached the app from outside — a browser download tapped in
/// a notification, a file manager, the share sheet, or a magnet link. Exactly
/// one of [bytes] / [magnet] is set.
class IncomingTorrent {
  const IncomingTorrent({this.bytes, this.filename, this.magnet});

  final Uint8List? bytes;
  final String? filename;
  final String? magnet;

  bool get hasFile => bytes != null && bytes!.isNotEmpty;
  bool get hasMagnet => magnet != null && magnet!.isNotEmpty;

  static IncomingTorrent? fromPlatform(Object? raw) {
    if (raw is! Map) return null;
    final bytes = raw['bytes'];
    final magnet = raw['magnet'];
    final t = IncomingTorrent(
      bytes: bytes is Uint8List ? bytes : null,
      filename: raw['filename'] is String ? raw['filename'] as String : null,
      magnet: magnet is String ? magnet : null,
    );
    return (t.hasFile || t.hasMagnet) ? t : null;
  }
}

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

class TorrentChannel {
  static const _channel = MethodChannel('mstream/torrent');

  /// Only Android implements either direction. Everywhere else the hand-off
  /// button stays off screen and nothing ever arrives by intent.
  static bool get isSupported => Platform.isAndroid;

  /// Hands a picked `.torrent` to some other app instead of adding it to an
  /// mStream server.
  ///
  /// The native side stages the bytes in its own FileProvider rather than
  /// forwarding the picker's URI (a received grant is not reliably
  /// re-delegatable) and prefers an ACTION_VIEW chooser, falling back to
  /// ACTION_SEND when no torrent client is installed.
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

  /// Opens Android's per-app "open by default" screen, where the user can
  /// make mStream the app that handles torrents (or hand that back to another
  /// app). An app cannot set this itself — taking the user there is the most
  /// it may do. False when no settings screen would open at all.
  static Future<bool> openDefaultSettings() async {
    if (!isSupported) return false;
    try {
      return await _channel.invokeMethod<bool>('openDefaultSettings') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Take whatever arrived by intent, or null when nothing is waiting (the
  /// normal launch). Draining is one-shot on the native side, so calling this
  /// from both the cold-start path and the warm notification can't
  /// double-deliver the same torrent.
  static Future<IncomingTorrent?> takePending() async {
    if (!isSupported) return null;
    try {
      final raw = await _channel.invokeMethod<Object?>('getInitialTorrent');
      return IncomingTorrent.fromPlatform(raw);
    } on PlatformException {
      return null;
    } on MissingPluginException {
      return null;
    }
  }

  /// Fires when an intent stages a torrent while the app is already running.
  /// The callback should [takePending] — the payload is not pushed, so there
  /// is only ever one delivery path.
  static void onTorrentWaiting(void Function() callback) {
    if (!isSupported) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'torrentWaiting') callback();
      return null;
    });
  }
}
