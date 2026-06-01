import 'package:audio_service/audio_service.dart' show MediaItem;

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
