// User-created local playlist.
//
// Stored as JSON in the app's documents directory; entries are denormalized
// MediaItem fields (id/title/artist/album/duration/extras) so playback can
// rebuild MediaItems without a server round-trip.

import 'package:audio_service/audio_service.dart';

import '../singletons/server_list.dart';
import '../util/stream_url.dart';

class Playlist {
  String name;
  final List<PlaylistEntry> entries;
  final DateTime createdAt;

  Playlist({
    required this.name,
    required this.entries,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Playlist.fromJson(Map<String, dynamic> json)
      : name = json['name'] as String,
        entries = (json['entries'] as List? ?? [])
            .map((e) => PlaylistEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        createdAt = DateTime.tryParse(json['createdAt'] ?? '') ??
            DateTime.now();

  Map<String, dynamic> toJson() => {
        'name': name,
        'entries': entries.map((e) => e.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
      };
}

class PlaylistEntry {
  final String id;
  final String title;
  final String? artist;
  final String? album;
  final int? durationMs;
  final Map<String, dynamic> extras;

  PlaylistEntry({
    required this.id,
    required this.title,
    this.artist,
    this.album,
    this.durationMs,
    this.extras = const {},
  });

  PlaylistEntry.fromJson(Map<String, dynamic> json)
      : id = json['id'] as String,
        title = json['title'] as String,
        artist = json['artist'] as String?,
        album = json['album'] as String?,
        durationMs = json['durationMs'] as int?,
        extras = Map<String, dynamic>.from(json['extras'] ?? const {});

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'album': album,
        'durationMs': durationMs,
        'extras': extras,
      };

  factory PlaylistEntry.fromMediaItem(MediaItem item) => PlaylistEntry(
        id: item.id,
        title: item.title,
        artist: item.artist,
        album: item.album,
        durationMs: item.duration?.inMilliseconds,
        extras: Map<String, dynamic>.from(item.extras ?? const {}),
      );

  MediaItem toMediaItem() {
    final extrasMap = Map<String, dynamic>.from(extras);
    // Artwork for the lock screen / Android Auto, from the stored /album-art URL.
    // For an iroh server that URL carries a previous session's loopback port +
    // token, so re-origin it against the live tunnel (mirrors queue_store); HTTP
    // servers keep the persisted URL (their host:port is durable).
    String? artUrl = extrasMap['artUrl'] as String?;
    final server = ServerManager().byLocalname(extrasMap['server'] as String?);
    if (artUrl != null && server != null && server.isIroh) {
      final u = Uri.tryParse(artUrl);
      if (u != null &&
          u.pathSegments.length >= 2 &&
          u.pathSegments.first == 'album-art') {
        artUrl = buildAlbumArtUrl(server, u.pathSegments.sublist(1).join('/'),
            compress: u.queryParameters['compress'] ?? 's');
        extrasMap['artUrl'] = artUrl;
      }
    }
    return MediaItem(
      id: id,
      title: title,
      artist: artist,
      album: album,
      artUri: artUrl != null ? Uri.tryParse(artUrl) : null,
      duration: durationMs == null ? null : Duration(milliseconds: durationMs!),
      extras: extrasMap,
    );
  }
}
