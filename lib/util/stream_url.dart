import 'package:uuid/uuid.dart';

import '../objects/server.dart';
import '../singletons/transcode.dart';

/// Single source of truth for a server file's streaming URL.
///
/// [path] is the leading-slash data path, e.g. "/Music/foo.mp3". When
/// transcoding is on this targets the server's `/transcode` endpoint and
/// appends the chosen `codec` / `bitrate` (each omitted when null, so the
/// server falls back to its configured default — matching the official mStream
/// web client); otherwise it hits the plain `/media` endpoint. A fresh
/// cache-busting `app_uuid` and the server token are always appended.
///
/// Used by the browse-time MediaItem builder, the queue-restore rebuild, the
/// recursive "add folder" path, and AutoDJ — so every playback path honors the
/// transcode settings identically and a rebuilt URL always carries the CURRENT
/// token (a saved URL's token can go stale between sessions).
String buildServerStreamUrl(Server server, String path) {
  String p = '';
  for (final element in path.split('/')) {
    if (element.isEmpty) continue;
    p += '/' + Uri.encodeComponent(element);
  }
  final tm = TranscodeManager();
  final String token = server.jwt == null ? '' : '&token=' + server.jwt!;
  if (tm.transcodeOn != true) {
    return server.url + '/media' + p + '?app_uuid=' + Uuid().v4() + token;
  }
  final sb = StringBuffer(server.url)
    ..write('/transcode')
    ..write(p)
    ..write('?app_uuid=')
    ..write(Uuid().v4())
    ..write(token);
  if (tm.codec != null) sb.write('&codec=' + tm.codec!);
  if (tm.bitrate != null) sb.write('&bitrate=' + tm.bitrate!);
  return sb.toString();
}
