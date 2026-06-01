import 'package:audio_service/audio_service.dart' show MediaItem;

/// Helpers for the metadata the cast backends (DLNA / Chromecast) send to a
/// renderer, derived from a queued [MediaItem].

/// Full-resolution album-art URL for casting to a TV / big screen.
///
/// A queued item's art URL points at the server's `/album-art/` endpoint with
/// a `compress=<size>` param (l/m/s) — a downscaled image that looks fine on
/// the phone but blurry on a TV. This drops the `compress` param so the
/// renderer fetches the original full-resolution art, while preserving the
/// auth `token` (and anything else) in the URL. Returns null if the item has
/// no art, and the URL unchanged if it has no `compress` param.
String? castArtUrl(MediaItem item) {
  final raw = item.artUri?.toString() ?? item.extras?['artUrl'] as String?;
  if (raw == null) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null || !uri.queryParameters.containsKey('compress')) return raw;
  final params = Map<String, String>.from(uri.queryParameters)
    ..remove('compress');
  return uri
      .replace(queryParameters: params.isEmpty ? null : params)
      .toString();
}

/// Reads an integer from a queued item's extras (e.g. track / disc / year),
/// tolerating int or num storage. Returns null if absent or non-numeric.
int? intExtra(MediaItem item, String key) {
  final v = item.extras?[key];
  if (v is int) return v;
  if (v is num) return v.toInt();
  return null;
}

/// Release date (year only) from a queued item's extras, for cast metadata.
/// Null when the year is missing or non-positive.
DateTime? releaseDateFor(MediaItem item) {
  final y = intExtra(item, 'year');
  return (y != null && y > 0) ? DateTime(y) : null;
}

/// Best-effort audio MIME type from a file path or URL, by extension. Used for
/// the renderer's contentType (Chromecast) and the on-device media server's
/// Content-Type header. Falls back to audio/mpeg.
String mimeForPath(String pathOrUrl) {
  var p = pathOrUrl.toLowerCase();
  final q = p.indexOf('?'); // drop any URL query string
  if (q >= 0) p = p.substring(0, q);
  if (p.endsWith('.flac')) return 'audio/flac';
  if (p.endsWith('.wav')) return 'audio/wav';
  if (p.endsWith('.m4a') || p.endsWith('.aac') || p.endsWith('.mp4')) {
    return 'audio/mp4';
  }
  if (p.endsWith('.ogg') || p.endsWith('.opus')) return 'audio/ogg';
  if (p.endsWith('.aif') || p.endsWith('.aiff')) return 'audio/aiff';
  return 'audio/mpeg';
}
