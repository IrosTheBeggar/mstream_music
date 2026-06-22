import 'package:audio_service/audio_service.dart' show MediaItem;

import '../objects/server.dart';
import '../singletons/server_list.dart';
import 'cast_art.dart';
import 'local_media_server.dart';

/// Casting helpers for iroh servers.
///
/// A cast renderer (DLNA / Chromecast) fetches media by URL itself, but an iroh
/// server's stream + art URLs point at `http://127.0.0.1:<tunnelPort>` — the
/// phone's loopback tunnel, which a device across the LAN can't reach. These
/// helpers detect such a track and re-origin its URLs through [LocalMediaServer],
/// which relays the bytes to the renderer from the phone's LAN address over the
/// tunnel (Range forwarded, so seeking still works).

/// The iroh [Server] a queued [item] belongs to, or null when the item isn't
/// from an iroh server (a plain HTTP server's URLs are already routable).
Server? irohServerFor(MediaItem item) {
  final s = ServerManager().byLocalname(item.extras?['server'] as String?);
  return (s != null && s.isIroh) ? s : null;
}

/// Re-origin a loopback iroh URL through the LAN proxy so a renderer can reach
/// it. [loopback] is a stored `http://127.0.0.1:<port>/...` URL; its path/query
/// are rebound to [server]'s LIVE tunnel — current port + `__lt` token — so a
/// port/token that went stale since the URL was built self-heals, and the
/// loopback token never appears in the LAN-facing URL. The caller must have
/// started [LocalMediaServer] first ([LocalMediaServer.ensureStarted]).
Uri irohProxyUri(Server server, String loopback) {
  final u = Uri.parse(loopback);
  final base = Uri.parse(server.effectiveBaseUrl); // http://127.0.0.1:<livePort>
  final q = Map<String, String>.from(u.queryParameters);
  if (server.tunnelToken != null) q['__lt'] = server.tunnelToken!;
  final upstream = u.replace(
    scheme: base.scheme,
    host: base.host,
    port: base.port,
    queryParameters: q.isEmpty ? null : q,
  );
  return LocalMediaServer().registerProxy(upstream);
}

/// The album-art URL to hand a renderer: full-resolution [castArtUrl], re-
/// originated through the LAN proxy when the track is from an iroh server.
/// Returns null when the item has no art. For the iroh case [LocalMediaServer]
/// must already be running — the load path starts it when resolving the stream
/// URL, which always happens before the art is read.
String? castArtUriFor(MediaItem item) {
  final art = castArtUrl(item);
  if (art == null) return null;
  final server = irohServerFor(item);
  return server == null ? art : irohProxyUri(server, art).toString();
}
