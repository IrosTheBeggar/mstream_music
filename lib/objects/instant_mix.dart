// instant_mix.dart — Instant Mix (mStream's POST /api/v1/discovery/local/mix):
// about 50 songs that sound like a song, an album, an artist or a playlist,
// in play order, on a page of their own (screens/instant_mix/).
//
// The request names the item in `from` — exactly one of `song` (its path),
// `album` (the album-songs identity: name, plus the album artist, the year
// and a track artist when the list knew them), `artist` or `playlist` (a
// name) — beside `limit` and the filters (MixFilters.toRequest builds it).
// The answer's songs come in the order to play them: a song mix leads with
// the seed itself, unless a filter left it out. The empty states are
// answers too: `notAnalyzed` when the seed (or every song of the item) has
// no sound yet; no song beyond the seed, with `filteredOut` saying whether
// the filters emptied it or nothing sounds like it yet. `moods` echoes the
// mood filter applied ({} for none), and is absent when the server has no
// mood scores. The rest of the answer (`seed`, `short`, `capped`,
// `relaxed`, `floor`) is for the server's tests and is never drawn.

import 'package:audio_service/audio_service.dart' show MediaItem;
import 'package:material_ui/material_ui.dart';

import '../theme/velvet_theme.dart';
import '../util/album_songs_body.dart';
import '../util/camelot.dart';
import '../util/stream_url.dart';
import 'discovery.dart';
import 'display_item.dart';
import 'server.dart';

/// Songs a mix asks for.
const int kInstantMixLimit = 50;

/// What a mix is made from. Each kind has its own banner tile: a cover for
/// a song or an album, a round person for an artist, a playlist glyph.
enum MixSeedKind { song, album, artist, playlist }

/// The item a mix is made from: the request's `from`, and what the page's
/// banner shows before any answer lands.
class MixSeed {
  final MixSeedKind kind;
  final Server server;

  /// The request's `from`.
  final Map<String, dynamic> from;
  final String title;

  /// The banner's second line: a song's artist, an album's credit. Null for
  /// an artist or a playlist, whose title says it all.
  final String? subtitle;

  /// A song's or an album's cover, null for none (the banner draws the
  /// placeholder tile).
  final String? artUrl;

  /// A song seed's app path (leading slash, whichever form its row or queue
  /// item had: an Auto DJ pick's has none): a song mix leads with it, so a
  /// row on this path is not "beyond the seed".
  final String? path;

  /// A song seed's own tempo and key — what Beat matching and Harmonic
  /// mixing are built around. Null for the other kinds: an album, an
  /// artist or a playlist has no single tempo or key.
  final int? bpm;
  final String? musicalKey;

  /// Whether the seed has a tempo for Beat matching to keep to.
  bool get hasBpm => (bpm ?? 0) > 0;

  /// The seed's key on the Camelot wheel ("3A"), or null — none, or one the
  /// wheel can't place: Harmonic mixing needs one.
  String? get camelotKey => toCamelotCode(musicalKey);

  const MixSeed._({
    required this.kind,
    required this.server,
    required this.from,
    required this.title,
    this.subtitle,
    this.artUrl,
    this.path,
    this.bpm,
    this.musicalKey,
  });

  /// A browsed song row ([DisplayItem.server] and [DisplayItem.data] set:
  /// callers offer Instant mix on server tracks only).
  factory MixSeed.song(DisplayItem item) {
    final server = item.server!;
    final path = item.data!;
    final m = item.metadata;
    final art = item.altAlbumArt ?? m?.albumArt;
    return MixSeed._(
      kind: MixSeedKind.song,
      server: server,
      from: {'song': _wirePath(path)},
      title: m?.title ?? path.split('/').last,
      subtitle: _orNull(m?.artistDisplay ?? m?.artist),
      artUrl: art == null ? null : buildAlbumArtUrl(server, art, compress: 'l'),
      path: _appPath(path),
      bpm: m?.bpm,
      musicalKey: _orNull(m?.musicalKey),
    );
  }

  /// A queued track on [server] (the queue, Song Info): its path, cover,
  /// tempo and key from the extras the queue builds (queueExtras) — callers
  /// offer Instant mix only when `extras['path']` is there.
  factory MixSeed.queued(Server server, MediaItem item) {
    final extras = item.extras ?? const <String, dynamic>{};
    final path = extras['path'] as String;
    final bpm = extras['bpm'];
    final key = extras['musicalKey'];
    // A track with no title tag is queued under its path: the file's name.
    final untitled = item.title == path || item.title == _wirePath(path);
    return MixSeed._(
      kind: MixSeedKind.song,
      server: server,
      from: {'song': _wirePath(path)},
      title: untitled ? path.split('/').last : item.title,
      subtitle: _orNull(item.artist),
      artUrl: extras['artUrl'] as String? ?? item.artUri?.toString(),
      path: _appPath(path),
      bpm: bpm is int ? bpm : null,
      musicalKey: key is String ? _orNull(key) : null,
    );
  }

  /// An album as the album detail opened it: the same album-songs identity
  /// (albumSongsBody), so the mix is made from the songs the detail lists.
  /// Its credit when the list gave one, else the [songs]' artist when they
  /// agree.
  factory MixSeed.album(DisplayItem album,
      {List<DisplayItem> songs = const []}) {
    final server = album.server!;
    final art = album.altAlbumArt;
    final artists = {
      for (final s in songs)
        if ((s.metadata?.artist ?? '').trim().isNotEmpty)
          s.metadata!.artist!.trim(),
    };
    return MixSeed._(
      kind: MixSeedKind.album,
      server: server,
      from: {
        'album': albumSongsBody(album.data,
            year: album.year,
            albumArtist: album.albumArtist,
            artist: album.trackArtist),
      },
      title: album.name,
      subtitle: _orNull(album.albumArtist) ??
          _orNull(album.trackArtist) ??
          (artists.length == 1 ? artists.single : null),
      artUrl: art == null ? null : buildAlbumArtUrl(server, art, compress: 'l'),
    );
  }

  /// An artist, by the name the Artists list gave it.
  factory MixSeed.artist(Server server, String name) => MixSeed._(
      kind: MixSeedKind.artist,
      server: server,
      from: {'artist': name},
      title: name);

  /// One of the account's playlists on [server], by name.
  factory MixSeed.playlist(Server server, String name) => MixSeed._(
      kind: MixSeedKind.playlist,
      server: server,
      from: {'playlist': name},
      title: name);

  static String _wirePath(String p) => p.startsWith('/') ? p.substring(1) : p;
  static String _appPath(String p) => '/${_wirePath(p)}';

  static String? _orNull(String? s) {
    final t = s?.trim();
    return t == null || t.isEmpty ? null : t;
  }
}

/// One mix answer, its songs as the file rows the browser draws and every
/// queue action takes.
class MixAnswer {
  /// The songs in play order: `file` DisplayItems on the mix's server with
  /// the route's LITE metadata, so flagged partial — the queue fetches the
  /// full block first (More like this's rows, discover_screen.dart).
  final List<DisplayItem> rows;

  /// The seed, or every song of the item, has no sound to compare yet.
  final bool notAnalyzed;

  /// Nothing beyond the seed survived the filters, though songs sounded
  /// like it: "No songs match your filters", not "Nothing similar yet".
  final bool filteredOut;

  /// The mood filter the server applied, as it echoed it ({} for none);
  /// null when the server has no mood scores, so no mood was applied.
  final Map? moods;

  const MixAnswer({
    this.rows = const [],
    this.notAnalyzed = false,
    this.filteredOut = false,
    this.moods,
  });

  factory MixAnswer.fromServerMap(Server server, Map m) {
    final songs = m['songs'];
    final moods = m['moods'];
    return MixAnswer(
      rows: [
        if (songs is List)
          for (final s in songs)
            if (DiscoveryTrack.fromServerMap(s) case final t?) _row(server, t),
      ],
      notAnalyzed: m['notAnalyzed'] == true,
      filteredOut: m['filteredOut'] == true,
      moods: moods is Map ? moods : null,
    );
  }

  /// Whether any row is a song beyond [seed] itself — the rule both
  /// clients count by: a row on the seed's own path is the seed leading
  /// its mix, not a song that sounds like it.
  bool beyond(MixSeed seed) => rows.any((r) => r.data != seed.path);

  /// The route's paths carry no leading slash; the app's do.
  static DisplayItem _row(Server server, DiscoveryTrack t) {
    final row = DisplayItem(server, t.filepath, 'file', '/${t.filepath}',
        Icon(Icons.music_note, color: VelvetColors.accent), null);
    row.metadata = t.metadata;
    row.partialMetadata = true;
    return row;
  }
}

/// The name a mix is saved as by default: [base] ("Dolo Mix"), or the first
/// of "Dolo Mix 2", "Dolo Mix 3"… that [existing] does not hold —
/// playlist/save overwrites a playlist by name, so a default must never
/// land on one. Names compare exactly, as the server matches them.
String mixPlaylistName(String base, Iterable<String> existing) {
  final taken = existing.toSet();
  if (!taken.contains(base)) return base;
  for (var n = 2;; n++) {
    final name = '$base $n';
    if (!taken.contains(name)) return name;
  }
}
