// User-created local playlist.
//
// Stored as JSON in the app's documents directory; entries are denormalized
// MediaItem fields (id/title/artist/album/duration/extras) so playback can
// rebuild MediaItems without a server round-trip.

import 'package:audio_service/audio_service.dart';

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

  MediaItem toMediaItem() => MediaItem(
        id: id,
        title: title,
        artist: artist,
        album: album,
        duration:
            durationMs == null ? null : Duration(milliseconds: durationMs!),
        extras: Map<String, dynamic>.from(extras),
      );
}
