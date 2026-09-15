import 'package:audio_service/audio_service.dart' show MediaItem;

/// The primary artist of a queued track, for the server lookups that key on
/// an artist NAME (Discover's similar-artists seed).
///
/// [MediaItem.artist] carries the ARTIST tag as written ("Ann feat. Bob") so
/// the now-playing strip, the notification and Android Auto show it; the
/// primary artist rides in `extras['artist']` (see queueExtras). An entry
/// persisted by an older build has no such key — its [MediaItem.artist] is the
/// primary artist anyway, so it is the fallback.
String? primaryArtistOf(MediaItem item) {
  final primary = item.extras?['artist'];
  if (primary is String && primary.trim().isNotEmpty) return primary.trim();
  return item.artist;
}
