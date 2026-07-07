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

/// Rebind a stored loopback iroh URL to [server]'s LIVE tunnel — current port +
/// `__lt` token — so a port/token that went stale since the URL was built
/// self-heals. [stored] is a `http://127.0.0.1:<port>/...` URL. Returns the live
/// loopback URL; the caller decides whether to relay it through the LAN proxy
/// ([irohProxyUri], for a renderer that can't reach loopback) or hand it to an
/// on-device consumer that can (the visualizer transcoder).
Uri irohLoopbackUri(Server server, String stored) {
  final u = Uri.parse(stored);
  final base = Uri.parse(server.effectiveBaseUrl); // http://127.0.0.1:<livePort>
  final q = Map<String, String>.from(u.queryParameters);
  if (server.tunnelToken != null) q['__lt'] = server.tunnelToken!;
  return u.replace(
    scheme: base.scheme,
    host: base.host,
    port: base.port,
    queryParameters: q.isEmpty ? null : q,
  );
}

/// Re-origin a loopback iroh URL through the LAN proxy so a renderer can reach
/// it. [loopback] is a stored `http://127.0.0.1:<port>/...` URL, rebound to the
/// LIVE tunnel ([irohLoopbackUri]) so a stale port/token self-heals; the loopback
/// `__lt` token rides only the inward leg and never appears in the LAN-facing
/// URL. The caller must have started [LocalMediaServer] first
/// ([LocalMediaServer.ensureStarted]).
Uri irohProxyUri(Server server, String loopback) {
  // Fail fast when the tunnel isn't live: handing the renderer a proxy URL
  // whose upstream can't answer leaves the receiver stuck 'loading' (observed
  // on-device on a demo→iroh queue jump with the server down). Throwing here
  // fails the load, which feeds the bounded cast failure walk immediately —
  // and the walk's renderer-lost fallback lands on the phone, whose local
  // iroh recovery owns waiting for the tunnel.
  if (!ServerManager().tunnelServes(server)) {
    throw StateError('iroh tunnel is not serving ${server.localname}');
  }
  return LocalMediaServer().registerProxy(irohLoopbackUri(server, loopback));
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
