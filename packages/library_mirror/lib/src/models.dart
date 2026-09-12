import 'dart:convert';

import 'package:meta/meta.dart';

int? _int(Object? v) => v is num ? v.toInt() : null;
double? _double(Object? v) => v is num ? v.toDouble() : null;
String? _str(Object? v) => v is String ? v : null;

/// One track as the server's manifest describes it. `path` is the app's
/// data path — `'/<vpath>/<rel>'` with the leading slash the browser,
/// queue extras and download tree all use — so it joins directly against
/// `LocalFile.path` and `localCopyCandidates`.
@immutable
class RemoteTrack {
  final int id;
  final String path;
  final int? size;
  final int? modified;
  final String? hash;
  final String? audioHash;
  final int? hashV;
  final int? albumId;
  final int? artistId;
  final String? art;
  final String? createdAt;
  final String? title;
  final String? artist;
  final String? album;
  final int? track;
  final int? disc;
  final int? year;
  final double? duration;
  final String? format;
  final List<String> genres;
  final int? rating;

  const RemoteTrack({
    required this.id,
    required this.path,
    this.size,
    this.modified,
    this.hash,
    this.audioHash,
    this.hashV,
    this.albumId,
    this.artistId,
    this.art,
    this.createdAt,
    this.title,
    this.artist,
    this.album,
    this.track,
    this.disc,
    this.year,
    this.duration,
    this.format,
    this.genres = const [],
    this.rating,
  });

  /// Parses one `entries[]` element of `POST /api/v1/sync/manifest`: the lite
  /// `{filepath, metadata}` row every list endpoint returns, plus the
  /// kebab-cased sync fields beside it (mStream #984).
  factory RemoteTrack.fromManifestEntry(Map<String, dynamic> e) {
    final m = (e['metadata'] as Map?)?.cast<String, dynamic>() ?? const {};
    final fp = e['filepath'] as String;
    return RemoteTrack(
      id: (e['id'] as num).toInt(),
      path: fp.startsWith('/') ? fp : '/$fp',
      size: _int(e['file-size']),
      modified: _int(e['modified']),
      hash: _str(e['hash']),
      audioHash: _str(e['audio-hash']),
      hashV: _int(e['hash-v']),
      albumId: _int(e['album-id']),
      artistId: _int(e['artist-id']),
      art: _str(m['album-art']),
      createdAt: _str(e['created-at']),
      title: _str(m['title']),
      artist: _str(m['artist']),
      album: _str(m['album']),
      track: _int(m['track']),
      disc: _int(m['disk']),
      year: _int(m['year']),
      duration: _double(m['duration']),
      format: _str(e['format']),
      genres: [for (final g in (m['genres'] as List?) ?? const []) '$g'],
      rating: _int(m['rating']),
    );
  }

  factory RemoteTrack.fromRow(Map<String, Object?> r) => RemoteTrack(
        id: r['id'] as int,
        path: r['path'] as String,
        size: _int(r['size']),
        modified: _int(r['modified']),
        hash: _str(r['hash']),
        audioHash: _str(r['audio_hash']),
        hashV: _int(r['hash_v']),
        albumId: _int(r['album_id']),
        artistId: _int(r['artist_id']),
        art: _str(r['art']),
        createdAt: _str(r['created_at']),
        title: _str(r['title']),
        artist: _str(r['artist']),
        album: _str(r['album']),
        track: _int(r['track']),
        disc: _int(r['disc']),
        year: _int(r['year']),
        duration: _double(r['duration']),
        format: _str(r['format']),
        genres: [for (final g in jsonDecode(r['genres'] as String? ?? '[]')) '$g'],
        rating: _int(r['rating']),
      );
}

/// Lifecycle of a local copy.
abstract final class LocalState {
  static const pending = 'pending';
  static const downloading = 'downloading';
  static const ok = 'ok';
  static const stale = 'stale';
  static const trashed = 'trashed';
  static const failed = 'failed';
}

/// Who put a local copy on disk — decides who may remove it. Only `mirror`
/// rows are the mirror engine's to trash; `manual` is a user download,
/// `auto` the keep-queue-offline cache, `external` a file found under the
/// server's mirror root (never touched).
abstract final class LocalOrigin {
  static const mirror = 'mirror';
  static const manual = 'manual';
  static const auto = 'auto';
  static const external = 'external';
}

@immutable
class LocalFile {
  final String server;
  final String path;
  final String quality;
  final String localPath;
  final int? size;
  final int? mtime;
  final String? hash;
  final String state;
  final String origin;
  final int? verifiedAt;
  final String? error;

  const LocalFile({
    required this.server,
    required this.path,
    required this.localPath,
    required this.state,
    required this.origin,
    this.quality = 'original',
    this.size,
    this.mtime,
    this.hash,
    this.verifiedAt,
    this.error,
  });

  factory LocalFile.fromRow(Map<String, Object?> r) => LocalFile(
        server: r['server'] as String,
        path: r['path'] as String,
        quality: r['quality'] as String,
        localPath: r['local_path'] as String,
        size: _int(r['size']),
        mtime: _int(r['mtime']),
        hash: _str(r['hash']),
        state: r['state'] as String,
        origin: r['origin'] as String,
        verifiedAt: _int(r['verified_at']),
        error: _str(r['error']),
      );
}

@immutable
class Subscription {
  final int? id;
  final String server;
  final String kind;
  final String key;
  final String quality;
  final bool wifiOnly;
  final bool enabled;
  final int? lastRun;

  const Subscription({
    this.id,
    required this.server,
    required this.kind,
    required this.key,
    this.quality = 'original',
    this.wifiOnly = false,
    this.enabled = true,
    this.lastRun,
  });

  factory Subscription.fromRow(Map<String, Object?> r) => Subscription(
        id: r['id'] as int,
        server: r['server'] as String,
        kind: r['kind'] as String,
        key: r['key'] as String,
        quality: r['quality'] as String,
        wifiOnly: r['wifi_only'] == 1,
        enabled: r['enabled'] == 1,
        lastRun: _int(r['last_run']),
      );
}

@immutable
class SyncRun {
  final int? id;
  final String server;
  final int started;
  final int? finished;
  final String? trigger;
  final int downloaded, replaced, renamed, trashed, unchanged, failed, conflicts;
  final int bytes;
  final String? error;

  const SyncRun({
    this.id,
    required this.server,
    required this.started,
    this.finished,
    this.trigger,
    this.downloaded = 0,
    this.replaced = 0,
    this.renamed = 0,
    this.trashed = 0,
    this.unchanged = 0,
    this.failed = 0,
    this.conflicts = 0,
    this.bytes = 0,
    this.error,
  });

  factory SyncRun.fromRow(Map<String, Object?> r) => SyncRun(
        id: r['id'] as int,
        server: r['server'] as String,
        started: r['started'] as int,
        finished: _int(r['finished']),
        trigger: _str(r['trigger']),
        downloaded: r['downloaded'] as int,
        replaced: r['replaced'] as int,
        renamed: r['renamed'] as int,
        trashed: r['trashed'] as int,
        unchanged: r['unchanged'] as int,
        failed: r['failed'] as int,
        conflicts: r['conflicts'] as int,
        bytes: r['bytes'] as int,
        error: _str(r['error']),
      );
}

/// One row of the server's `db/albums` list, keyed by name like the API.
@immutable
class AlbumRow {
  final String name;
  final String? albumArtist;
  final int? year;
  final String? art;
  const AlbumRow({required this.name, this.albumArtist, this.year, this.art});

  factory AlbumRow.fromRow(Map<String, Object?> r) => AlbumRow(
        name: r['name'] as String,
        albumArtist: _str(r['album_artist']),
        year: _int(r['year']),
        art: _str(r['art']),
      );
}

/// A playlist with its tracks' data paths in order.
@immutable
class PlaylistRow {
  final String id;
  final String name;
  final List<String> paths;
  const PlaylistRow({required this.id, required this.name, this.paths = const []});
}
