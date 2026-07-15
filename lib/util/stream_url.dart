import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show mapEquals;
import 'package:uuid/uuid.dart';

import '../objects/server.dart';
import '../singletons/transcode.dart';

/// Containers/codecs AVPlayer — iOS's only audio engine — cannot decode.
/// ExoPlayer (Android) and media_kit (desktop) play them natively, so this
/// list only matters behind the iOS gate below. Extension-based, matching the
/// server's file-path-centric model.
const Set<String> _avPlayerUnplayable = {
  'ogg', 'oga', 'opus', 'spx', // Xiph containers (vorbis/opus/speex)
  'wma', // Windows Media
  'ape', 'mpc', 'wv', 'tta', 'shn', // exotic lossless/lossy
  'mka', // Matroska audio
  'dsf', 'dff', // DSD
};

/// Whether [path] must be transcoded to play on iOS: AVPlayer can't decode
/// its format and the server isn't known to lack ffmpeg (null = not pinged
/// yet → optimistic, matching [buildServerStreamUrl]'s existing policy).
/// Pure; unit-tested — callers pass `Platform.isIOS` for [isIOS].
bool needsIosTranscodeFallback(String path,
    {required bool isIOS, required bool? transcodeAvailable}) {
  if (!isIOS || transcodeAvailable == false) return false;
  final dot = path.lastIndexOf('.');
  if (dot < 0) return false;
  return _avPlayerUnplayable.contains(path.substring(dot + 1).toLowerCase());
}

/// The transcode codec actually sent: iOS pins everything except aac to mp3,
/// because AVPlayer can't decode opus — honoring an explicit opus choice (or
/// a null that lets a server configured for opus pick) would swap one
/// unplayable stream for another. Other platforms pass the user's choice
/// through untouched. Pure; unit-tested.
String? effectiveTranscodeCodec(String? userCodec, {required bool isIOS}) {
  if (!isIOS) return userCodec;
  return userCodec == 'aac' ? 'aac' : 'mp3';
}

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
  // iOS codec fallback: formats AVPlayer can't decode (ogg/opus & co) stream
  // through /transcode even with the user's transcode setting OFF — the
  // alternative is a track that silently fails. Device-verified that AVPlayer
  // plays the endpoint's chunked no-Range transport. Android/desktop never
  // take this branch (their players decode these formats natively).
  final iosFallback = tm.transcodeOn != true &&
      needsIosTranscodeFallback(path,
          isIOS: Platform.isIOS,
          transcodeAvailable: server.transcodeAvailable);
  // Use /transcode only when the user enabled it AND this server isn't known to
  // lack ffmpeg. transcodeAvailable: true = confirmed capable; false = confirmed
  // incapable (stream the original, never 500); null = not pinged yet →
  // optimistic (use /transcode) so a capable server works immediately at launch
  // without waiting for the ping. A queue mixing capable + incapable servers
  // resolves to the right endpoint per track once each server is pinged.
  if ((tm.transcodeOn != true || server.transcodeAvailable == false) &&
      !iosFallback) {
    return '${server.effectiveBaseUrl}/media$p?app_uuid=${Uuid().v4()}$token${server.localTokenQuery}';
  }
  final codec = effectiveTranscodeCodec(tm.codec, isIOS: Platform.isIOS);
  final sb = StringBuffer(server.effectiveBaseUrl)
    ..write('/transcode')
    ..write(p)
    ..write('?app_uuid=')
    ..write(Uuid().v4())
    ..write(token);
  if (codec != null) sb.write('&codec=$codec');
  if (tm.bitrate != null) sb.write('&bitrate=${tm.bitrate!}');
  sb.write(server.localTokenQuery);
  return sb.toString();
}

/// Whether two stream URLs point at the same stream. [buildServerStreamUrl]
/// stamps a fresh cache-busting `app_uuid` on EVERY call, so a raw string
/// compare sees every rebuild as a change — and rebuild paths would reload
/// the whole queue (dumping the player's buffer, or clobbering an active
/// cast) even when endpoint, port and token are identical. Lives here, next
/// to the builder that mints the cache-buster it ignores.
bool sameStreamUrl(String a, String b) {
  if (a == b) return true;
  final ua = Uri.tryParse(a);
  final ub = Uri.tryParse(b);
  if (ua == null || ub == null) return false;
  if (ua.scheme != ub.scheme ||
      ua.host != ub.host ||
      ua.port != ub.port ||
      ua.path != ub.path) {
    return false;
  }
  final qa = Map.of(ua.queryParameters)..remove('app_uuid');
  final qb = Map.of(ub.queryParameters)..remove('app_uuid');
  return mapEquals(qa, qb);
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
