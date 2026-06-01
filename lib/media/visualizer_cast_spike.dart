import 'dart:async';

import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';

import '../singletons/cast_manager.dart';
import 'cast_log.dart';

/// SPIKE / Phase 0b validation: cast a pre-rendered video [url] to the first
/// discovered Chromecast, decoupled from the queue-based cast backend.
///
/// This exists only to prove the cast-video path end-to-end — that
/// [LocalMediaServer] can serve the transcoded visualizer and a Chromecast will
/// play our H.264/AAC over the LAN — before investing in the live MPEG-TS/HLS
/// muxer. The real feature will drive video through the cast backend + picker;
/// this throwaway just connects to the first device and loads the URL.
///
/// Returns null on success, or a short human-readable error.
Future<String?> castVideoToFirstChromecast(
  Uri url, {
  String? title,
  String? subtitle,
}) async {
  // Reuse the registered discoverers (this also initializes the Cast context
  // with the Default Media Receiver app id; see ChromecastDeviceDiscoverer).
  await CastManager().startDiscovery();

  GoogleCastDevice? device;
  for (var i = 0; i < 16 && device == null; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 500));
    final devices = GoogleCastDiscoveryManager.instance.devices;
    if (devices.isNotEmpty) device = devices.first;
  }
  if (device == null) return 'No Chromecast found on the network';

  final sessions = GoogleCastSessionManager.instance;
  try {
    if (!sessions.hasConnectedSession) {
      await sessions.startSessionWithDevice(device);
      if (!sessions.hasConnectedSession) {
        await sessions.currentSessionStream
            .firstWhere((_) => sessions.hasConnectedSession)
            .timeout(const Duration(seconds: 12));
      }
    }
    await GoogleCastRemoteMediaClient.instance.loadMedia(
      GoogleCastMediaInformation(
        contentId: url.toString(),
        contentUrl: url,
        streamType: CastMediaStreamType.buffered,
        contentType: 'video/mp4',
        metadata: GoogleCastGenericMediaMetadata(
          title: title,
          subtitle: subtitle,
        ),
      ),
      autoPlay: true,
    );
    return null;
  } catch (e) {
    castLog('Spike video cast failed', error: e);
    return 'Cast failed: $e';
  }
}
