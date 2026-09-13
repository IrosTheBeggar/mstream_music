import 'package:library_mirror/library_mirror.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as path;

import '../objects/display_item.dart';
import '../objects/metadata.dart';
import '../objects/server.dart';
import '../theme/velvet_theme.dart';
import '../util/media_format.dart';
import 'api.dart';
import 'server_capabilities.dart';
import 'settings.dart';

/// One level of the file explorer: the server's own path for the header and
/// the rows under it.
class FileListing {
  final String path;
  final List<DisplayItem> items;
  const FileListing(this.path, this.items);
}

/// Where the browser's lists come from. Every implementation produces the
/// same `DisplayItem` rows, so the screens never know which one answered:
/// [HttpLibrarySource] is the server (the mappings that used to live inline
/// in ApiManager), [LocalLibrarySource] the library index on this device
/// (A4 of BACKUP_SYNC_IMPLEMENTATION.md — offline browsing).
abstract class LibrarySource {
  Future<List<DisplayItem>> albums(Server s);
  Future<List<DisplayItem>> artists(Server s);
  Future<List<DisplayItem>> artistAlbums(Server s, String artist);
  Future<List<DisplayItem>> albumSongs(Server s, String? album);
  Future<FileListing> fileList(Server s, String directory);
  Future<List<DisplayItem>> playlists(Server s);
  Future<List<DisplayItem>> playlistContents(Server s, String playlist);
  Future<List<DisplayItem>> rated(Server s);
  Future<List<DisplayItem>> recent(Server s);
  Future<List<DisplayItem>> search(Server s, String term);
}

/// The server, over the same calls the browser always made.
class HttpLibrarySource implements LibrarySource {
  final ApiManager api;
  HttpLibrarySource(this.api);

  @override
  Future<List<DisplayItem>> albums(Server s) async {
    final res = await api.makeServerCall(s, '/api/v1/db/albums', {}, 'GET');
    final List<DisplayItem> newList = [];
    res['albums'].forEach((e) {
      // Newer servers include `album_artist`; fold it into the subtitle as
      // "Artist · Year" for the browse card/list. Older servers omit it, so
      // the subtitle gracefully falls back to just the year.
      final artist = (e['album_artist'] ?? e['albumArtist'] ?? e['artist'])
          ?.toString()
          .trim();
      final year = e['year']?.toString().trim();
      final subtitle = [
        if (artist != null && artist.isNotEmpty) artist,
        if (year != null && year.isNotEmpty) year,
      ].join(' · ');
      DisplayItem newItem = DisplayItem(s, e['name'], 'album', e['name'],
          Icon(Icons.album, color: VelvetColors.textSecondary), subtitle);
      newItem.altAlbumArt = e['album_art_file'];
      newList.add(newItem);
    });
    return newList;
  }

  @override
  Future<List<DisplayItem>> artists(Server s) async {
    final res = await api.makeServerCall(s, '/api/v1/db/artists', {}, 'GET');
    final List<DisplayItem> newList = [];
    res['artists'].forEach((e) {
      newList.add(DisplayItem(s, e, 'artist', e,
          Icon(Icons.library_music, color: VelvetColors.textSecondary), null));
    });
    return newList;
  }

  @override
  Future<List<DisplayItem>> artistAlbums(Server s, String artist) async {
    final res = await api.makeServerCall(
        s, '/api/v1/db/artists-albums', {'artist': artist}, 'POST');
    final List<DisplayItem> newList = [];
    res['albums'].forEach((e) {
      String name = e['name'] ?? 'SINGLES';
      // TODO: Errors on singles
      DisplayItem newItem = DisplayItem(
          s,
          name,
          'album',
          e['name'],
          Icon(Icons.album, color: VelvetColors.textSecondary),
          e['year']?.toString() ?? '');
      newItem.altAlbumArt = e['album_art_file'];
      newList.add(newItem);
    });
    return newList;
  }

  @override
  Future<List<DisplayItem>> albumSongs(Server s, String? album) async {
    final res = await api.makeServerCall(
        s, '/api/v1/db/album-songs', {'album': album}, 'POST');
    final List<DisplayItem> newList = [];
    res.forEach((e) {
      MusicMetadata m = MusicMetadata.fromServerMap(e['metadata']);
      DisplayItem newItem = DisplayItem(s, e['filepath'], 'file',
          '/${e['filepath']}', Icon(Icons.music_note, color: VelvetColors.accent), null);
      newItem.metadata = m;
      newList.add(newItem);
    });
    return newList;
  }

  @override
  Future<List<DisplayItem>> playlists(Server s) async {
    final res = await api.makeServerCall(s, '/api/v1/playlist/getall', {}, 'GET');
    return [
      for (final e in res as List)
        DisplayItem(s, e['name'], 'playlist', e['name'],
            Icon(Icons.queue_music, color: VelvetColors.textSecondary), null),
    ];
  }

  @override
  Future<List<DisplayItem>> playlistContents(Server s, String playlist) async {
    final res = await api.makeServerCall(
        s, '/api/v1/playlist/load', {'playlistname': playlist}, 'POST');
    return _trackRows(s, res, subtitle: (_) => null);
  }

  @override
  Future<List<DisplayItem>> rated(Server s) async {
    final res = await api.makeServerCall(s, '/api/v1/db/rated', {}, 'GET');
    return _trackRows(s, res, subtitle: (m) => m.artist);
  }

  @override
  Future<List<DisplayItem>> recent(Server s) async {
    final res = await api.makeServerCall(
        s, '/api/v1/db/recent/added', {'limit': 100}, 'POST');
    return _trackRows(s, res, subtitle: (_) => null);
  }

  /// The `[{filepath, metadata}]` rows the playlist, rated and recent
  /// endpoints share.
  List<DisplayItem> _trackRows(Server s, dynamic res,
      {required String? Function(MusicMetadata) subtitle}) {
    final List<DisplayItem> out = [];
    for (final e in res as List) {
      final m = MusicMetadata.fromServerMap(e['metadata']);
      out.add(DisplayItem(s, e['filepath'], 'file', '/${e['filepath']}',
          Icon(Icons.music_note, color: VelvetColors.accent), subtitle(m))
        ..metadata = m);
    }
    return out;
  }

  /// The server's grouped search: artists, albums, tracks, then file and
  /// lyric hits when those categories are ticked. The ticked categories map
  /// 1:1 onto the endpoint's five `no*` flags, so the server only does the
  /// work that is asked for. `noLyrics` (6.13.1) is the one flag worth
  /// gating through the capability filter: an unknown key 400s the whole
  /// search on an older server, and the other four predate the support
  /// floor.
  @override
  Future<List<DisplayItem>> search(Server s, String term) async {
    final cats = SettingsManager().searchCategories;
    final payload = <String, dynamic>{
      'search': term,
      'noArtists': !cats.contains(SearchCategory.artists),
      'noAlbums': !cats.contains(SearchCategory.albums),
      'noTitles': !cats.contains(SearchCategory.songs),
      'noFiles': !cats.contains(SearchCategory.files),
      'noLyrics': !cats.contains(SearchCategory.lyrics),
    };
    final res = await api.makeServerCall(s, '/api/v1/db/search',
        ServerCapabilities().filter(s, payload).body, 'POST');
    final List<DisplayItem> out = [];
    res['artists'].forEach((e) {
      out.add(DisplayItem(s, e['name'], 'artist', e['name'],
          Icon(Icons.library_music, color: VelvetColors.textSecondary), 'artist')
        ..altAlbumArt = e['album_art_file']);
    });
    res['albums'].forEach((e) {
      out.add(DisplayItem(s, e['name'], 'album', e['name'],
          Icon(Icons.library_music, color: VelvetColors.textSecondary), 'album')
        ..altAlbumArt = e['album_art_file']);
    });
    // Track hits carry the LITE metadata subset (PR #685, same kebab-case
    // keys as the full block). Attached so the row renders a real card and
    // flagged partial so the queue refetches the full block on enqueue; an
    // older server omits the key → metadata stays null (still partial).
    res['title'].forEach((e) {
      final md = e['metadata'];
      final meta = md is Map ? MusicMetadata.fromServerMap(md) : null;
      out.add(DisplayItem(s, e['name'], 'file', '/${e['filepath']}',
          Icon(Icons.music_note, color: VelvetColors.accent),
          meta != null ? null : 'song')
        ..altAlbumArt = e['album_art_file']
        ..metadata = meta
        ..partialMetadata = true);
    });
    // File (path) matches keep the folder as the subtitle — the match
    // context; `?.` because older servers omit the key entirely.
    res['files']?.forEach((e) {
      final String fp = e['filepath'];
      final int slash = fp.lastIndexOf('/');
      final md = e['metadata'];
      final item = DisplayItem(s, e['name'], 'file', '/$fp',
          Icon(Icons.insert_drive_file, color: VelvetColors.accent),
          slash > 0 ? fp.substring(0, slash) : null)
        ..altAlbumArt = e['album_art_file']
        ..partialMetadata = true;
      if (md is Map) item.metadata = MusicMetadata.fromServerMap(md);
      out.add(item);
    });
    // Lyric matches keep the snippet as the subtitle so the user sees WHY it
    // matched; null on the LIKE / non-FTS path → plain label.
    res['lyrics']?.forEach((e) {
      final snippet = (e['snippet'] as String?)?.trim();
      final md = e['metadata'];
      final item = DisplayItem(s, e['name'], 'file', '/${e['filepath']}',
          Icon(Icons.lyrics, color: VelvetColors.accent),
          snippet != null && snippet.isNotEmpty ? snippet : 'lyrics')
        ..altAlbumArt = e['album_art_file']
        ..partialMetadata = true;
      if (md is Map) item.metadata = MusicMetadata.fromServerMap(md);
      out.add(item);
    });
    return out;
  }

  @override
  Future<FileListing> fileList(Server s, String directory) async {
    final res = await api.makeServerCall(s, '/api/v1/file-explorer', {
      "directory": directory,
      // Server defaults this to false (cheap listing). When the user
      // has the setting on, the server returns a `metadata` field on
      // each file entry — we attach it to the DisplayItem below so
      // that when the user taps to queue, browser.dart's addFile
      // sees a populated metadata object and the resulting MediaItem
      // carries title/artist/album/art into the player and the
      // notification.
      "pullMetadata": SettingsManager().fileExplorerMetadata,
    }, 'POST');

    final List<DisplayItem> newList = [];
    res['directories'].forEach((e) {
      newList.add(DisplayItem(s, e['name'], 'directory',
          path.join(res['path'], e['name']),
          Icon(Icons.folder, color: VelvetColors.warning), null));
    });
    res['files'].forEach((e) {
      // A playlist file opens a list rather than playing, so it should not
      // wear the same icon as the tracks around it.
      final isPlaylistFile = isM3u(e['name']?.toString());
      DisplayItem newItem = DisplayItem(
          s,
          e['name'],
          'file',
          path.join(res['path'], e['name']),
          Icon(isPlaylistFile ? Icons.queue_music : Icons.music_note,
              color: VelvetColors.accent),
          null);
      // The server wraps each file's metadata as { filepath, metadata:
      // {…actual fields…} } — drill in one level. Only set when
      // pullMetadata=true was sent AND the file is in the library DB
      // (unscanned files still arrive without an inner metadata
      // object; we tolerate that and fall back to filename display).
      final outer = e['metadata'];
      final inner = outer is Map ? outer['metadata'] : null;
      if (inner is Map) {
        newItem.metadata = MusicMetadata.fromServerMap(inner);
      }
      newList.add(newItem);
    });
    return FileListing(res['path'], newList);
  }
}

/// The library index on this device. Rows are shaped exactly like the
/// server's so every screen downstream is unchanged; only the files this
/// device holds can play, which the existing local-copy resolution already
/// decides per row.
class LocalLibrarySource implements LibrarySource {
  final LibraryIndex index;
  LocalLibrarySource(this.index);

  /// The file explorer's root marker maps to the library root.
  static String dirPath(String directory) {
    if (directory == '~' || directory.isEmpty) return '/';
    return directory.endsWith('/') ? directory : '$directory/';
  }

  @override
  Future<List<DisplayItem>> albums(Server s) async => [
        for (final a in index.albums(s.localname))
          DisplayItem(s, a.name, 'album', a.name,
              Icon(Icons.album, color: VelvetColors.textSecondary), [
            if (a.albumArtist != null && a.albumArtist!.trim().isNotEmpty)
              a.albumArtist!.trim(),
            if (a.year != null) '${a.year}',
          ].join(' · '))
            ..altAlbumArt = a.art,
      ];

  @override
  Future<List<DisplayItem>> artists(Server s) async => [
        for (final name in index.artists(s.localname))
          DisplayItem(s, name, 'artist', name,
              Icon(Icons.library_music, color: VelvetColors.textSecondary), null),
      ];

  @override
  Future<List<DisplayItem>> artistAlbums(Server s, String artist) async => [
        for (final a in index.artistAlbums(s.localname, artist))
          DisplayItem(s, a.name, 'album', a.name,
              Icon(Icons.album, color: VelvetColors.textSecondary),
              a.year?.toString() ?? '')
            ..altAlbumArt = a.art,
      ];

  @override
  Future<List<DisplayItem>> albumSongs(Server s, String? album) async => [
        for (final t in index.albumSongs(s.localname, album ?? ''))
          _track(s, t),
      ];

  @override
  Future<FileListing> fileList(Server s, String directory) async {
    final dir = dirPath(directory);
    final listing = index.directoryListing(s.localname, dir);
    return FileListing(dir, [
      for (final name in listing.dirs)
        DisplayItem(s, name, 'directory', '$dir$name',
            Icon(Icons.folder, color: VelvetColors.warning), null),
      for (final t in listing.files)
        DisplayItem(
            s,
            path.basename(t.path),
            'file',
            t.path,
            Icon(isM3u(t.path) ? Icons.queue_music : Icons.music_note,
                color: VelvetColors.accent),
            null)
          ..metadata = metadataOf(t),
    ]);
  }

  @override
  Future<List<DisplayItem>> playlists(Server s) async => [
        for (final p in index.playlists(s.localname))
          DisplayItem(s, p.name, 'playlist', p.name,
              Icon(Icons.queue_music, color: VelvetColors.textSecondary), null),
      ];

  /// A slot whose file the manifest no longer lists keeps its place with
  /// no metadata, as the server's own answer does.
  @override
  Future<List<DisplayItem>> playlistContents(Server s, String playlist) async => [
        for (final i in index.playlistItems(s.localname, playlist))
          i.track != null
              ? _track(s, i.track!)
              : DisplayItem(s, i.path.substring(1), 'file', i.path,
                  Icon(Icons.music_note, color: VelvetColors.accent), null),
      ];

  @override
  Future<List<DisplayItem>> rated(Server s) async => [
        for (final t in index.rated(s.localname)) _track(s, t, subtitle: t.artist),
      ];

  @override
  Future<List<DisplayItem>> recent(Server s) async => [
        for (final t in index.recent(s.localname)) _track(s, t),
      ];

  /// The grouped search over the index — artists, albums, then tracks by
  /// title / artist / album / path prefix — honouring the same category
  /// switches as the server search. Lyrics are not indexed. Track rows
  /// carry full metadata, so nothing is refetched on enqueue.
  @override
  Future<List<DisplayItem>> search(Server s, String term) async {
    final cats = SettingsManager().searchCategories;
    final n = s.localname;
    return [
      if (cats.contains(SearchCategory.artists))
        for (final a in index.artistsMatching(n, term))
          DisplayItem(s, a, 'artist', a,
              Icon(Icons.library_music, color: VelvetColors.textSecondary),
              'artist'),
      if (cats.contains(SearchCategory.albums))
        for (final a in index.albumsMatching(n, term))
          DisplayItem(s, a.name, 'album', a.name,
              Icon(Icons.library_music, color: VelvetColors.textSecondary),
              'album')
            ..altAlbumArt = a.art,
      if (cats.contains(SearchCategory.songs) ||
          cats.contains(SearchCategory.files))
        for (final t in index.search(n, term)) _track(s, t),
    ];
  }

  /// Every track under [directory]: the paths plus their metadata keyed the
  /// way the batch endpoint keys it (no leading slash), for "play all".
  Future<(List<String>, Map<String, MusicMetadata>)> recursiveTracks(
      Server s, String directory) async {
    final tracks = index.tracksUnder(s.localname, dirPath(directory));
    return (
      [for (final t in tracks) t.path],
      {for (final t in tracks) t.path.substring(1): metadataOf(t)},
    );
  }

  DisplayItem _track(Server s, RemoteTrack t, {String? subtitle}) =>
      DisplayItem(
          s,
          t.path.substring(1),
          'file',
          t.path,
          Icon(Icons.music_note, color: VelvetColors.accent),
          subtitle)
        ..metadata = metadataOf(t);

  /// The index row as the server's metadata map, so the one parser the app
  /// already has builds the object — same keys, same kebab-casing.
  static MusicMetadata metadataOf(RemoteTrack t) => MusicMetadata.fromServerMap({
        'title': t.title,
        'artist': t.artist,
        'album': t.album,
        'track': t.track,
        'disk': t.disc,
        'year': t.year,
        'hash': t.hash ?? '',
        'audio-hash': t.audioHash,
        'album-art': t.art,
        'duration': t.duration,
        'rating': t.rating,
        'genres': t.genres,
        'format': t.format,
        'file-size': t.size,
      });
}
