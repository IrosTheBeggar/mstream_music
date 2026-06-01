import 'dart:async';

import 'package:flutter_chrome_cast/flutter_chrome_cast.dart';

import '../native/visualizer_bridge.dart';
import '../singletons/cast_manager.dart';
import 'cast_log.dart';
import 'local_media_server.dart';

// Tears down the live transcode + local server when the cast session ends, so
// we don't keep encoding (battery/thermal) or leave the HTTP server running
// after the user stops casting. One active watcher; a re-cast cancels the prior.
StreamSubscription<dynamic>? _sessionWatch;

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
  String contentType = 'video/mp4',
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
        contentType: contentType,
        metadata: GoogleCastGenericMediaMetadata(
          title: title,
          subtitle: subtitle,
        ),
      ),
      autoPlay: true,
    );
    _watchSessionEnd();
    return null;
  } catch (e) {
    castLog('Spike video cast failed', error: e);
    return 'Cast failed: $e';
  }
}

/// Stop the transcode + local server once the cast session disconnects. The
/// session stream replays the current (connected) state on listen, so the
/// teardown only fires on a later transition to no-connected-session.
void _watchSessionEnd() {
  final sessions = GoogleCastSessionManager.instance;
  _sessionWatch?.cancel();
  _sessionWatch = sessions.currentSessionStream.listen((_) async {
    if (!sessions.hasConnectedSession) {
      await _sessionWatch?.cancel();
      _sessionWatch = null;
      await VisualizerBridge.stopTranscode();
      await LocalMediaServer().stop();
    }
  });
}
