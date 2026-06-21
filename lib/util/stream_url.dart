import 'package:uuid/uuid.dart';

import '../objects/server.dart';
import '../singletons/transcode.dart';

/// Single source of truth for a server file's streaming URL.
///
/// [path] is the leading-slash data path, e.g. "/Music/foo.mp3". When
/// transcoding is on AND this server supports it, this targets the server's
/// `/transcode` endpoint and appends the chosen `codec` / `bitrate` (each
/// omitted when null, so the server falls back to its configured default —
/// matching the official mStream web client); otherwise it hits the plain
/// `/media` endpoint. A fresh cache-busting `app_uuid` and the server token are
/// always appended.
///
/// Used by the browse-time MediaItem builder, the queue-restore rebuild, the
/// recursive "add folder" path, and AutoDJ — so every playback path honors the
/// transcode settings identically and a rebuilt URL always carries the CURRENT
/// token (a saved URL's token can go stale between sessions).
String buildServerStreamUrl(Server server, String path) {
  String p = '';
  for (final element in path.split('/')) {
    if (element.isEmpty) continue;
    p += '/${Uri.encodeComponent(element)}';
  }
  final tm = TranscodeManager();
  final String token = server.jwt == null ? '' : '&token=${server.jwt!}';
  // Use /transcode only when the user enabled it AND this server isn't known to
  // lack ffmpeg. transcodeAvailable: true = confirmed capable; false = confirmed
  // incapable (stream the original, never 500); null = not pinged yet →
  // optimistic (use /transcode) so a capable server works immediately at launch
  // without waiting for the ping. A queue mixing capable + incapable servers
  // resolves to the right endpoint per track once each server is pinged.
  if (tm.transcodeOn != true || server.transcodeAvailable == false) {
    return '${server.effectiveBaseUrl}/media$p?app_uuid=${Uuid().v4()}$token${server.localTokenQuery}';
  }
  final sb = StringBuffer(server.effectiveBaseUrl)
    ..write('/transcode')
    ..write(p)
    ..write('?app_uuid=')
    ..write(Uuid().v4())
    ..write(token);
  if (tm.codec != null) sb.write('&codec=${tm.codec!}');
  if (tm.bitrate != null) sb.write('&bitrate=${tm.bitrate!}');
  sb.write(server.localTokenQuery);
  return sb.toString();
}

/// Single source of truth for a server's album-art URL.
///
/// [artFile] is the `album_art_file` / metadata `album-art` value. [compress]
/// picks the server's render size — 's' for list thumbnails, 'm' for grid
/// cards, 'l' for full art. The token is appended only when present (omitted
/// when null, matching [buildServerStreamUrl]) and the whole URL is
/// percent-encoded. Assumes [Server.url] carries no trailing slash — the app's
/// stored convention, shared with the stream-URL builder above.
String buildAlbumArtUrl(Server server, String artFile, {String compress = 's'}) {
  final String token = server.jwt == null ? '' : '&token=${server.jwt!}';
  return Uri.encodeFull(
      '${server.effectiveBaseUrl}/album-art/$artFile?compress=$compress$token${server.localTokenQuery}');
}
