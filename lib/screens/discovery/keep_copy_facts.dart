import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';

import '../../objects/discovery.dart';
import '../../objects/display_item.dart';
import '../../objects/metadata.dart';
import '../../objects/server.dart';
import '../../singletons/api.dart';
import '../../theme/velvet_theme.dart';
import '../../util/album_songs_body.dart';
import '../../util/browse_keep_leads.dart'
    show AlbumCreditResolver, ResolvedCredit;
import '../../util/discover_badges.dart' show nameKey;
import '../../util/discover_jobs.dart' show LayoutSong, serverFolderOf;
import '../../util/plan_artist_albums.dart';

/// The sizes a connected server's song and album sheets show beside the
/// Keep a copy choices, and the Listen verbs' songs: the album on that
/// server (its songs, their length), the artist's albums there, and the
/// artist's albums in the user's own library — "3 songs", "1 album · you
/// have 3", "Only the 1 album you don't have", "not in your library".
///
/// Asked once per sheet, headless (no browser loading bar) and straight to
/// the server named: the album and the peer's artist list THROUGH the
/// connected server ([Server.apiUri] rewrites a peer's virtual Server onto
/// the parent's federation proxy, or its own tunnel while direct), the
/// library's list on the user's own server. Nothing here blocks Keep a
/// copy: the copy job asks the peer itself.
///
/// "You don't have" matches album NAMES (src/db/name-key.js, [nameKey]),
/// never counts: the server counts an album as owned when any of its songs
/// is in the library, and the artist-missing copy skips by name too.
class KeepFacts {
  /// The album's songs on the connected server ([DisplayItem]s on its
  /// virtual Server — what Play album / Queue album take). Null until it
  /// answers, or when it did not.
  final List<DisplayItem>? albumSongs;

  /// The connected server's albums by the artist (names, the singles entry
  /// left out). Null until it answers, or when it did not.
  final List<String>? peerAlbums;

  /// The year that list gives each of those albums, by name ([nameKey]):
  /// the folder "Files go to" names for the one album an only-missing copy
  /// takes. Null until it answers.
  final Map<String, int>? peerAlbumYears;

  /// The user's own library's albums by the artist (names). Null until it
  /// answers, or when it did not.
  final List<String>? libraryAlbums;

  /// The connected server did not answer one of its two calls: the sheet
  /// says it is "not answering" and leaves its sizes blank.
  final bool peerFailed;

  /// The connected server's `artists-albums` answer for the artist as it
  /// came — each album's `album_artist`, `artists`, `compilation`, and the
  /// singles bucket (`name: null`) — what an artist copy is planned from
  /// ([planFor]). Null until it answers, or when it did not.
  final List<Map<String, dynamic>>? peerListing;

  const KeepFacts({
    this.albumSongs,
    this.peerAlbums,
    this.peerAlbumYears,
    this.libraryAlbums,
    this.peerFailed = false,
    this.peerListing,
  });

  /// What an artist copy of [artist] takes and leaves out, as the copy
  /// plans it ([planArtistAlbums]): their own albums — not the ones they
  /// only appear on — and, with [onlyMissing], not the ones the library has
  /// by name. Null until the peer's list (and, for [onlyMissing], the
  /// library's) answered.
  ArtistAlbumsPlan? planFor(String artist, {bool onlyMissing = false}) {
    final listing = peerListing;
    if (listing == null) return null;
    final mine = libraryAlbums;
    if (onlyMissing && mine == null) return null;
    return planArtistAlbums(
      listing,
      artist,
      localKeys: {for (final n in mine ?? const <String>[]) nameKey(n)},
      onlyMissing: onlyMissing,
    );
  }

  /// The artist copy's "left out" line ([artistLeftOut]); null when nothing
  /// is left out, or the peer's list has not answered.
  ArtistLeftOut? leftOutFor(String artist) =>
      artistLeftOut(peerListing, artist);

  /// [artist]'s own albums there, as an artist copy takes them ([planFor]):
  /// what a browse sheet's Artist choice counts ("3 albums" — never the
  /// ones they only appear on). Null until the peer's list answered.
  List<String>? theirsOf(String artist) =>
      planFor(artist)?.plan.map((a) => a.name).toList();

  /// Their albums the library lacks by name — what "Only the 2 albums you
  /// don't have" copies from a browse sheet. Null until both lists
  /// answered.
  List<String>? missingTheirs(String artist) =>
      planFor(artist, onlyMissing: true)?.plan.map((a) => a.name).toList();

  /// Of their albums, the ones the library has by name ("you have 1").
  /// Null until both lists answered.
  int? haveTheirs(String artist) {
    final theirs = theirsOf(artist);
    final missing = missingTheirs(artist);
    if (theirs == null || missing == null) return null;
    return theirs.length - missing.length;
  }

  /// A song's album credit from the peer's list (the album page's step 3,
  /// [AlbumCreditResolver.fromArtistAlbums]): the one album of [album]'s
  /// name — and [year] — gives it. Unknown until the list answered.
  ResolvedCredit creditOf(String? album, {int? year}) {
    final listing = peerListing;
    if (listing == null || album == null || album.trim().isEmpty) {
      return ResolvedCredit.unknown;
    }
    return AlbumCreditResolver.fromArtistAlbums(
      {'albums': listing},
      album: album,
      year: year,
    );
  }

  /// How many songs the album has there; null until it answered, or when
  /// it answered none (no album of that name to take).
  int? get albumSongCount {
    final n = albumSongs?.length;
    return n == null || n == 0 ? null : n;
  }

  /// The album's length (null when no song says how long it is).
  Duration? get albumLength {
    final songs = albumSongs;
    if (songs == null || songs.isEmpty) return null;
    var total = 0.0;
    var any = false;
    for (final s in songs) {
      final d = s.metadata?.durationSeconds;
      if (d != null && d.isFinite && d > 0) {
        total += d;
        any = true;
      }
    }
    return any ? Duration(milliseconds: (total * 1000).round()) : null;
  }

  /// The year the album's songs carry most (null when none does).
  int? get albumYear {
    final counts = <int, int>{};
    for (final s in albumSongs ?? const <DisplayItem>[]) {
      final y = s.metadata?.year;
      if (y != null && y > 0) counts[y] = (counts[y] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;
    return counts.entries.reduce((a, b) => b.value > a.value ? b : a).key;
  }

  /// The album's songs as a copy files them ([LayoutSong], what "Files go
  /// to" reads an album copy's {{ARTIST}}, {{YEAR}}, {{GENRE}} and
  /// {{SERVERFOLDER}} from): each one's ARTIST tag as written ("A feat. B"
  /// files under that, not under A), its year, its genre when the listing
  /// tells the file's — a single one: the library splits a tag like
  /// "Hip-Hop/Rap" in two, while a copy files under the tag as written —
  /// and the folders its file sits in on the connected server (its path
  /// there, the library dropped). Null until the album answered.
  List<LayoutSong>? get layoutSongs =>
      albumSongs == null ? null : [for (final s in albumSongs!) _layout(s)];

  /// The genre [filepath]'s file carries (the peer's path), when the
  /// album's listing holds that song and tells it ([layoutSongs]).
  String? genreOf(String? filepath) => _songAt(filepath)?.genre;

  /// The ARTIST tag [filepath]'s file carries as written ("A feat. B" — a
  /// copy of it files there, where the row names A alone), when the album's
  /// listing holds that song and tells it ([layoutSongs]).
  String? artistOf(String? filepath) {
    final a = _songAt(filepath)?.artist;
    return a is String && a.trim().isNotEmpty ? a : null;
  }

  LayoutSong? _songAt(String? filepath) {
    final want = _bare(filepath);
    if (want.isEmpty) return null;
    for (final s in albumSongs ?? const <DisplayItem>[]) {
      if (_bare(s.data) == want) return _layout(s);
    }
    return null;
  }

  static String _bare(String? path) =>
      (path ?? '').replaceFirst(RegExp(r'^/+'), '');

  static LayoutSong _layout(DisplayItem s) {
    final m = s.metadata;
    final genres = m?.genres ?? const <String>[];
    return LayoutSong(
      artist: m?.artistDisplay ?? m?.artist,
      year: m?.year,
      genre: genres.length == 1 ? genres.first : null,
      serverFolder: serverFolderOf(s.data),
    );
  }

  /// The connected server's albums by the artist that no album of the
  /// library carries the name of — what "Only the albums you don't have"
  /// copies. Null until both lists answered.
  List<String>? get missing {
    final peer = peerAlbums;
    final mine = libraryAlbums;
    if (peer == null || mine == null) return null;
    final have = {for (final n in mine) nameKey(n)};
    final seen = <String>{};
    return [
      for (final n in peer)
        if (!have.contains(nameKey(n)) && seen.add(nameKey(n))) n,
    ];
  }

  /// Whether the library holds an album of [album]'s name by the artist
  /// (null until the library's list answered).
  bool? libraryHas(String? album) {
    final mine = libraryAlbums;
    if (mine == null || album == null || album.trim().isEmpty) return null;
    final want = nameKey(album);
    return mine.any((n) => nameKey(n) == want);
  }

  KeepFacts _with({
    List<DisplayItem>? albumSongs,
    List<String>? peerAlbums,
    Map<String, int>? peerAlbumYears,
    List<String>? libraryAlbums,
    bool? peerFailed,
    List<Map<String, dynamic>>? peerListing,
  }) => KeepFacts(
    albumSongs: albumSongs ?? this.albumSongs,
    peerAlbums: peerAlbums ?? this.peerAlbums,
    peerAlbumYears: peerAlbumYears ?? this.peerAlbumYears,
    libraryAlbums: libraryAlbums ?? this.libraryAlbums,
    peerFailed: peerFailed ?? this.peerFailed,
    peerListing: peerListing ?? this.peerListing,
  );
}

/// One POST to [server] (its [Server.apiUri]), JSON both ways; throws on a
/// non-2xx answer or a transport failure. Tests inject their own.
typedef KeepFactsFetch =
    Future<dynamic> Function(
      Server server,
      String location,
      Map<String, dynamic> body,
    );

/// The fetch a loader uses when it is given none (tests swap it for a
/// scripted one).
KeepFactsFetch keepFactsFetch = keepFactsPost;

/// The default [KeepFactsFetch]: ApiManager's pooled direct client, the
/// server's own token (a peer's virtual Server carries the parent's), 15 s.
Future<dynamic> keepFactsPost(
  Server server,
  String location,
  Map<String, dynamic> body,
) async {
  final res = await ApiManager().directClient
      .post(
        server.apiUri(location),
        headers: {
          'Content-Type': 'application/json',
          'x-access-token': server.authToken ?? '',
        },
        body: jsonEncode(body),
      )
      .timeout(const Duration(seconds: 15));
  if (res.statusCode < 200 || res.statusCode > 299) {
    throw http.ClientException('HTTP ${res.statusCode}', res.request?.url);
  }
  return jsonDecode(res.body);
}

/// Loads [KeepFacts] for one sheet (see there). [peer] is the connected
/// server's virtual Server, [own] the user's server. [album] null asks no
/// album; [artist] empty asks no artist lists. [albumArtist] is the album's
/// credit — a compilation's album songs are asked by it, so they are the
/// whole album, what its album copy takes. [peerListing] is an answer the
/// page already holds (an artist page's own `artists-albums`): the peer is
/// not asked again.
class KeepFactsLoader extends ChangeNotifier {
  final Server? peer;
  final Server? own;
  final String? album;
  final String? albumArtist;
  final String artist;

  /// Whether to ask the artist lists at all (a compilation offers no artist
  /// copy, so its sheet needs none).
  final bool wantArtist;
  final List<Map<String, dynamic>>? peerListing;
  final KeepFactsFetch _fetch;

  KeepFactsLoader({
    required this.peer,
    required this.own,
    required this.album,
    required this.artist,
    this.albumArtist,
    this.wantArtist = true,
    this.peerListing,
    KeepFactsFetch? fetch,
  }) : _fetch = fetch ?? keepFactsFetch,
       _credit = albumArtist;

  /// For a connected server's row.
  factory KeepFactsLoader.forLead(
    DiscoveryLead lead, {
    required Server? peer,
    required Server? own,
    bool wantArtist = true,
    KeepFactsFetch? fetch,
  }) => KeepFactsLoader(
    peer: peer,
    own: own,
    album: lead.album,
    albumArtist: lead.albumArtist,
    artist: lead.artist,
    wantArtist: wantArtist,
    fetch: fetch,
  );

  KeepFacts facts = const KeepFacts();
  bool _albumOut = false;
  bool _artistOut = false;
  bool _started = false;
  bool _disposed = false;
  Future<void>? _albumDone;

  /// The credit the album's songs are asked by ([albumArtist], or one
  /// learnt since: [albumCreditKnown]); the latest ask's number.
  String? _credit;
  int _albumAsk = 0;

  bool get loadingAlbum => _albumOut;
  bool get loadingArtist => _artistOut;
  bool get loading => _albumOut || _artistOut;
  bool get asksAlbum => (album ?? '').trim().isNotEmpty && peer != null;
  bool get asksArtist => wantArtist && artist.trim().isNotEmpty;

  /// Ask everything once (later calls are no-ops).
  void load() {
    if (_started || _disposed) return;
    _started = true;
    if (asksAlbum) {
      _albumOut = true;
      _albumDone = _loadAlbum();
    }
    if (asksArtist) {
      _artistOut = true;
      unawaited(_loadArtist());
    }
    _notify();
  }

  /// The album's songs on the connected server, once they answered (null
  /// when they did not, or the sheet has no album) — Play album / Queue
  /// album wait on it.
  Future<List<DisplayItem>?> albumSongs() async {
    load();
    await _albumDone;
    return facts.albumSongs;
  }

  /// The album's credit became known after its songs were asked by the
  /// artist (a browse sheet's song: its own tags, or the peer's album
  /// list): they are asked again by the credit — a compilation's whole
  /// album, what its album copy takes. Nothing when they were asked by it
  /// already, or the sheet has no album.
  void albumCreditKnown(String credit) {
    final c = credit.trim();
    if (_disposed || !asksAlbum || c.isEmpty) return;
    if (nameKey(c) == nameKey(_credit)) return;
    _credit = c;
    if (!_started) return;
    _albumOut = true;
    _albumDone = _loadAlbum();
    _notify();
  }

  Future<void> _loadAlbum() async {
    final p = peer!;
    final ask = ++_albumAsk;
    final credit = _credit?.trim();
    final hasCredit = credit != null && credit.isNotEmpty;
    try {
      final res = await _fetch(
        p,
        '/api/v1/db/album-songs',
        albumSongsBody(
          album,
          albumArtist: hasCredit ? credit : null,
          artist: hasCredit ? null : artist,
        ),
      );
      final songs = <DisplayItem>[];
      if (res is List) {
        for (final e in res) {
          if (e is! Map || e['filepath'] is! String) continue;
          final fp = e['filepath'] as String;
          final row = DisplayItem(
            p,
            fp,
            'file',
            '/$fp',
            Icon(Icons.music_note, color: VelvetColors.accent),
            null,
          );
          row.metadata = MusicMetadata.fromServerMap(e['metadata']);
          songs.add(row);
        }
      }
      if (_disposed || ask != _albumAsk) return;
      facts = facts._with(albumSongs: List.unmodifiable(songs));
    } catch (_) {
      if (_disposed || ask != _albumAsk) return;
      facts = facts._with(peerFailed: true);
    } finally {
      // An ask overtaken by a later one leaves the answer to it.
      if (ask == _albumAsk) {
        _albumOut = false;
        _notify();
      }
    }
  }

  static List<String> _names(dynamic res) {
    final albums = res is Map ? res['albums'] : null;
    if (albums is! List) return const [];
    final out = <String>[];
    for (final a in albums) {
      final n = a is Map ? a['name'] : null;
      if (n is String && n.trim().isNotEmpty) out.add(n);
    }
    return List.unmodifiable(out);
  }

  /// Each named album's year in an artists-albums answer, by [nameKey].
  static Map<String, int> _years(dynamic res) {
    final albums = res is Map ? res['albums'] : null;
    if (albums is! List) return const {};
    final out = <String, int>{};
    for (final a in albums) {
      final n = a is Map ? a['name'] : null;
      final y = a is Map ? a['year'] : null;
      if (n is String && n.trim().isNotEmpty && y is num && y > 0) {
        out.putIfAbsent(nameKey(n), () => y.toInt());
      }
    }
    return Map.unmodifiable(out);
  }

  /// An artists-albums answer's albums as they came (the maps).
  static List<Map<String, dynamic>> _listing(dynamic res) {
    final albums = res is Map ? res['albums'] : null;
    if (albums is! List) return const [];
    return List.unmodifiable([
      for (final a in albums)
        if (a is Map)
          Map<String, dynamic>.unmodifiable({
            for (final e in a.entries)
              if (e.key is String) e.key as String: e.value,
          }),
    ]);
  }

  Future<void> _loadArtist() async {
    final body = {'artist': artist};
    final p = peer;
    final o = own;
    final held = peerListing;
    if (held != null) {
      final res = {'albums': held};
      facts = facts._with(
        peerAlbums: _names(res),
        peerAlbumYears: _years(res),
        peerListing: _listing(res),
      );
    }
    await Future.wait([
      if (p != null && held == null)
        () async {
          try {
            final res = await _fetch(p, '/api/v1/db/artists-albums', body);
            if (_disposed) return;
            facts = facts._with(
              peerAlbums: _names(res),
              peerAlbumYears: _years(res),
              peerListing: _listing(res),
            );
          } catch (_) {
            if (_disposed) return;
            facts = facts._with(peerFailed: true);
          }
        }(),
      if (o != null)
        () async {
          try {
            final names = _names(
              await _fetch(o, '/api/v1/db/artists-albums', body),
            );
            if (_disposed) return;
            facts = facts._with(libraryAlbums: names);
          } catch (_) {
            // The library's list is only the "you have" part: without it
            // the sizes say less, nothing more.
          }
        }(),
    ]);
    _artistOut = false;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
