/// Keep a copy while browsing a connected server: the recommendation each
/// way in sends (the phone spec's "what each door passes"), the folder a way
/// in names ([FolderRef]), the album page's credit ([AlbumCreditResolver]),
/// the queue's rule ([queueKeepPeer]) and what the Keep sheet is opened with
/// ([BrowseKeepRequest]).
///
/// A browse row is a connected server's own row: it carries the server (a
/// peer's virtual Server, [DisplayItem.server]) and the song's tags, never a
/// Discover lead. Its recommendation is built here exactly as Discover's
/// rows are sent — the source, the peer `{id, name}`, the peer's path with
/// no leading slash, the PRIMARY artist, title and album — so the server
/// keys it as it keys theirs and a copy started on one shows on the other.
/// The jobs, the gate and the destination are the user's own server's
/// ([Server.parentServer]), never the peer's.
library;

import 'package:audio_service/audio_service.dart' show MediaItem;

import '../objects/discovery.dart';
import '../objects/display_item.dart';
import '../objects/metadata.dart';
import '../objects/server.dart';
import '../singletons/api.dart';
import 'album_songs_body.dart' show albumArtistOf, albumYearOf;
import 'discover_badges.dart' show nameKey;
import 'discover_copy_gate.dart' show kVariousArtistsKey;
import 'discover_jobs.dart' show normalizePeerPath;
import 'media_item_credits.dart';

/// A recommendation's `source` for a connected server's song.
const String kFederationSource = 'federation';

/// [server] is a connected server Keep a copy can copy from: a peer its own
/// server still lists, not hidden, its parent linked (the spec's "usable
/// connected server"). The own server is [Server.parentServer].
bool isKeepPeer(Server? server) =>
    server != null &&
    server.isFederated &&
    server.isSelectable &&
    !server.federationMissing &&
    server.parentServer != null;

/// The recommendation's `peer`: the peer's row id on the user's own server
/// and its name there.
Map<String, dynamic> keepPeerOf(Server peer) => {
      'id': peer.federationPeerId,
      'name': peer.federationPeerName ?? peer.displayName,
    };

Map<String, dynamic> _base(Server peer) =>
    {'source': kFederationSource, 'peer': keepPeerOf(peer)};

String? _text(Object? v) => v is String && v.trim().isNotEmpty ? v : null;

String _bare(String path) => path.startsWith('/') ? path.substring(1) : path;

/// A year the route takes (1000–9999); anything else is left out — one out
/// of range would refuse the whole start.
int? _year(Object? v) {
  final y = albumYearOf(v);
  return y != null && y >= 1000 && y <= 9999 ? y : null;
}

// ── a folder ─────────────────────────────────────────────────────────────

/// A folder on a connected server below its library's root — the only kind
/// Keep a copy offers (a library root, or `/` of a server with several
/// libraries, is never one).
class FolderRef {
  /// Its path there as the file explorer names it: a leading slash, no
  /// trailing one ("/music/Boukmanflow/Borrowed Tapes").
  final String path;

  /// Its own name ("Borrowed Tapes") and the library it is in ("music").
  final String name;
  final String library;

  const FolderRef._(this.path, this.name, this.library);

  /// [path] as a folder Keep a copy can take (either separator, a slash at
  /// either end or none), or null when it is a library's root or `/`.
  static FolderRef? of(String? path) {
    final segs = normalizePeerPath(path).split('/').where((s) => s.isNotEmpty).toList();
    if (segs.length < 2) return null;
    return FolderRef._('/${segs.join('/')}', segs.last, segs.first);
  }

  /// The folder the file at [filePath] sits in, or null when the file sits
  /// at its library's root.
  static FolderRef? parentOf(String? filePath) {
    final segs = normalizePeerPath(filePath).split('/').where((s) => s.isNotEmpty).toList();
    if (segs.length < 3) return null;
    return of(segs.sublist(0, segs.length - 1).join('/'));
  }

  /// Its folders, library first.
  List<String> get segments => path.substring(1).split('/');

  /// The path a folder job's recommendation carries: no leading slash
  /// ("music/Boukmanflow/Borrowed Tapes").
  String get filepath => path.substring(1);

  /// The folder's recommendation: its path there and its name.
  Map<String, dynamic> rec(Server peer) =>
      {..._base(peer), 'filepath': filepath, 'title': name};

  @override
  bool operator ==(Object other) => other is FolderRef && other.path == path;

  @override
  int get hashCode => path.hashCode;

  @override
  String toString() => 'FolderRef($path)';
}

// ── recommendations ──────────────────────────────────────────────────────

/// A song row's recommendation (an album page's song, an explorer file, a
/// Recent row, a search song / file / lyric hit, an M3U row): the peer's
/// path, title, primary artist, album, the album page's known credit
/// ([albumCredit]), year, length and cover. Never the song's own
/// `album-artist`: each half of a split album names its own artist, so an
/// album copy keyed on it would take that half — the sheet holds it as a
/// candidate until the peer's album list bears it out
/// ([BrowseKeepRequest.songCredit]). A row with no tags is its path and
/// file name until a metadata read merges in. Null for anything but a
/// connected server's file.
Map<String, dynamic>? songLeadOf(DisplayItem row, {String? albumCredit}) {
  final data = row.data;
  final peer = row.server;
  if (row.type != 'file' || data == null || !isKeepPeer(peer)) return null;
  return songLeadFor(peer!, data, row.metadata,
      albumCredit: albumCredit, albumArt: row.altAlbumArt);
}

/// [songLeadOf] for the file at [path] on [peer] with the tags [m] — the
/// sheet's own metadata read merged in, for a row that had none (an
/// explorer file with the metadata setting off, an M3U row). [albumArt]
/// stands in for a cover the tags do not name.
Map<String, dynamic> songLeadFor(
  Server peer,
  String path,
  MusicMetadata? m, {
  String? albumCredit,
  String? albumArt,
}) {
  final filepath = _bare(path);
  final title = _text(m?.title);
  if (m == null || title == null) {
    return {..._base(peer), 'filepath': filepath, 'title': path.split('/').last};
  }
  final credit = _text(albumCredit);
  final art = _text(m.albumArt) ?? _text(albumArt);
  return {
    ..._base(peer),
    'filepath': filepath,
    'title': title,
    'artist': ?_text(m.artist),
    'album': ?_text(m.album),
    'albumArtist': ?credit,
    'year': ?_year(m.year),
    'duration': ?m.durationSeconds,
    'albumArt': ?art,
  };
}

/// Whether [album] with credit [credit] is a compilation — copied whole
/// and nobody's artist copy — as the webapp reads one (its album page's
/// head, its cards): a credit of Various Artists, whatever the listing says
/// (one whose files carry no compilation flag lists it as `compilation:
/// false`); the listing's own word when it says so; else a credit none of
/// its artists carries — [artists] (an album page's loaded songs' own) or
/// the listing's. Artists that say nothing say nothing.
bool albumIsCompilation(DisplayItem album, String credit,
    {Iterable<String>? artists}) {
  final key = nameKey(credit);
  if (key == kVariousArtistsKey || album.compilation == true) return true;
  final names = [
    for (final a in artists ?? album.artists)
      if (_text(a) != null) a,
  ];
  return key.isNotEmpty &&
      names.isNotEmpty &&
      !names.any((a) => nameKey(a) == key);
}

/// An album's recommendation (a page pill, a card ⋯ or long-press, an album
/// row): its name, its credit ([credit], else [DisplayItem.albumArtist]
/// when [DisplayItem.creditState] is known) as `albumArtist` and — unless
/// it is a compilation ([albumIsCompilation], by [artists] when the page
/// has its songs), whose credit is no one's own — as `artist`, its year and
/// cover; [card] adds `compilation` (the album sheet's Artist choice reads
/// it). Null when no credit is known (no Album copy then), for the singles
/// bucket, and for anything but a connected server's album.
Map<String, dynamic>? albumLeadOf(DisplayItem album,
    {String? credit, bool card = false, Iterable<String>? artists}) {
  final name = _text(album.data);
  final peer = album.server;
  if (album.type != 'album' || name == null || !isKeepPeer(peer)) return null;
  final c = _text(credit) ??
      (album.creditState == AlbumCredit.known ? _text(album.albumArtist) : null);
  if (c == null) return null;
  final compilation = albumIsCompilation(album, c, artists: artists);
  return {
    ..._base(peer!),
    'album': name,
    'albumArtist': c,
    if (!compilation) 'artist': c,
    'year': ?_year(album.year ?? album.yearHint),
    'albumArt': ?_text(album.altAlbumArt),
    if (card) 'compilation': compilation,
  };
}

/// An artist's recommendation (the artist page's pill): the artist alone.
/// Null for Various Artists, and off a connected server.
Map<String, dynamic>? artistLeadOf(ArtistContext artist) {
  final peer = artist.server;
  final name = _text(artist.name);
  if (name == null || !isKeepPeer(peer)) return null;
  if (nameKey(name) == kVariousArtistsKey) return null;
  return {..._base(peer!), 'artist': name};
}

/// A queued connected-server track's recommendation (the queue's "Keep a
/// copy…"), from its extras: its path there, title, primary artist, album,
/// year, length. [peer] is the track's own server (by its extras'
/// `server`). The album credit the queue kept is the song's own, so — as a
/// song row's ([songLeadOf]) — only the sheet's candidate
/// ([BrowseKeepRequest.songCredit]), never the recommendation's.
Map<String, dynamic> queueLeadOf(MediaItem item, Server peer) {
  final x = item.extras ?? const <String, dynamic>{};
  final path = x['path'];
  final d = item.duration;
  return {
    ..._base(peer),
    'filepath': ?(path is String ? _bare(path) : null),
    'title': item.title,
    'artist': ?_text(primaryArtistOf(item)),
    'album': ?_text(item.album),
    'year': ?_year(x['year']),
    'duration': ?(d == null ? null : d.inMilliseconds / 1000),
  };
}

/// The connected server whose "Keep a copy…" a queued track offers: its
/// server by the queue's own record ([byLocalname] of `extras['server']`)
/// when that is a usable connected server ([isKeepPeer]) and — [gateOpen],
/// asked of it — the song scope's gate is open on its own server. A track
/// downloaded to this phone still is that server's song: it qualifies.
/// Null for a track of the user's own server, a file on this phone (no
/// `server` in its extras), a peer its server no longer lists or the user
/// hid, and a closed gate.
Server? queueKeepPeer(
  MediaItem item, {
  required Server? Function(String localname) byLocalname,
  bool Function(Server peer)? gateOpen,
}) {
  final name = item.extras?['server'];
  if (name is! String || name.isEmpty) return null;
  final path = item.extras?['path'];
  if (path is! String || path.isEmpty) return null;
  final server = byLocalname(name);
  if (!isKeepPeer(server)) return null;
  if (gateOpen != null && !gateOpen(server!)) return null;
  return server;
}

/// [rec] as a [DiscoveryLead] — what the Keep card reads ([DiscoveryLead.raw]
/// is sent unchanged). Unlike [DiscoveryLead.fromServerMap] it takes a
/// recommendation with no title (an album's, an artist's, a folder's).
DiscoveryLead leadOfRec(Map<String, dynamic> rec) {
  final peer = rec['peer'];
  final duration = rec['duration'];
  final id = peer is Map ? peer['id'] : null;
  return DiscoveryLead(
    _text(rec['artist']) ?? '',
    _text(rec['title']) ?? '',
    0,
    duration is num && duration.isFinite && duration > 0
        ? duration.toDouble()
        : null,
    null,
    const [],
    peer is Map ? _text(peer['name']) : null,
    album: _text(rec['album']),
    albumArtist: _text(rec['albumArtist']),
    year: albumYearOf(rec['year']),
    filepath: _text(rec['filepath']),
    peerId: id is int ? id : (id is num ? id.toInt() : null),
    source: _text(rec['source']),
    raw: Map.unmodifiable(rec),
  );
}

// ── the album page's credit ──────────────────────────────────────────────

/// What [AlbumCreditResolver] found: [state], and [credit] when known —
/// with [compilation] when the peer's album list it came from called the
/// album one (it rides along: two answers of one credit are one credit).
class ResolvedCredit {
  final AlbumCredit state;
  final String? credit;
  final bool compilation;
  const ResolvedCredit._(this.state)
      : credit = null,
        compilation = false;

  const ResolvedCredit.known(String this.credit, {this.compilation = false})
      : state = AlbumCredit.known;
  static const ResolvedCredit disagree = ResolvedCredit._(AlbumCredit.disagree);
  static const ResolvedCredit unknown = ResolvedCredit._(AlbumCredit.unknown);

  @override
  bool operator ==(Object other) =>
      other is ResolvedCredit && other.state == state && other.credit == credit;

  @override
  int get hashCode => Object.hash(state, credit);

  @override
  String toString() =>
      'ResolvedCredit(${state.name}${credit != null ? ', $credit' : ''})';
}

/// One headless POST to a server (its [Server.apiUri]), JSON both ways;
/// throws on a non-2xx answer or a transport failure. Tests inject theirs.
typedef KeepPost = Future<dynamic> Function(
    Server server, String location, Map<String, dynamic> body);

/// A connected server's album credit — the album artist its album copy is
/// keyed on — for its album page, in order:
///   1. the opener ([fromOpener]): an Albums or artist-page item whose
///      listing named `album_artist` (known, or null: disagree); a Discover
///      card that knew its credit. A search hit's `album_artist` is only a
///      hint (before mStream #1076 it is the album's primary artist), so it
///      goes on to 2
///   2. the songs' own `album-artist` ([fromSongs]): all agree (by
///      [nameKey], spelled as the first song spells it) → known; two differ
///      → disagree; one lacks it (an older server) → 3
///   3. the peer's albums by the first song's primary artist
///      ([fromArtistAlbums]): exactly one of the page's name — and year,
///      when the page has one — gives its `album_artist` (null: disagree);
///      none, several, a failed read or [timeout] → unknown
/// [resolve] stores the answer on the album item ([DisplayItem.creditState]
/// and, when known, [DisplayItem.albumArtist]), so Back reuses it.
class AlbumCreditResolver {
  final KeepPost _post;
  final Duration timeout;

  AlbumCreditResolver(
      {KeepPost? post, this.timeout = const Duration(seconds: 8)})
      : _post = post ?? ApiManager().headlessPost;

  /// Step 1: what the opener said, or null to go on. The singles bucket
  /// (an artist page's album with no name) is no album: unknown, nothing
  /// asked.
  static ResolvedCredit? fromOpener(DisplayItem album) {
    if (_text(album.data) == null) return ResolvedCredit.unknown;
    switch (album.creditState) {
      case AlbumCredit.known:
        final c = _text(album.albumArtist);
        return c == null ? null : ResolvedCredit.known(c);
      case AlbumCredit.disagree:
        return ResolvedCredit.disagree;
      case AlbumCredit.unknown:
        // A card that knew its credit without a listing to say so
        // (Discover's connected-server albums by credit).
        final c = _text(album.albumArtist);
        return c == null ? null : ResolvedCredit.known(c);
    }
  }

  /// Step 2: the songs' own `album-artist`, or null to go on.
  static ResolvedCredit? fromSongs(Iterable<DisplayItem> songs) {
    String? first;
    String? key;
    var lacking = false;
    var any = false;
    for (final s in songs) {
      any = true;
      final c = _text(s.metadata?.albumArtist);
      if (c == null) {
        lacking = true;
        continue;
      }
      final k = nameKey(c);
      if (key == null) {
        key = k;
        first = c;
      } else if (k != key) {
        return ResolvedCredit.disagree;
      }
    }
    if (!any || lacking || first == null) return null;
    return ResolvedCredit.known(first);
  }

  // An album row holds [year] within its years, else at its year; one
  // that names no year holds any (the webapp's browseAlbumMatch).
  static bool _holds(Map row, int year) {
    final lo = albumYearOf(row['year_min']);
    final hi = albumYearOf(row['year_max']);
    if (lo != null && hi != null) return year >= lo && year <= hi;
    final y = albumYearOf(row['year']);
    return y == null || y == year;
  }

  /// Step 3, the answer's half: the peer's `artists-albums` [answer] matched
  /// to the page's [album] (by [nameKey]) and [year] (within an album's
  /// `year_min`..`year_max`, else its `year`; one naming no year holds
  /// any). [hint] — a search hit's credit — only tells two matches apart,
  /// never stands alone.
  static ResolvedCredit fromArtistAlbums(Object? answer,
      {required String album, int? year, String? hint}) {
    final rows = answer is Map && answer['albums'] is List
        ? answer['albums'] as List
        : const [];
    final want = nameKey(album);
    var matches = [
      for (final r in rows)
        if (r is Map &&
            r['name'] is String &&
            nameKey(r['name']) == want &&
            (year == null || _holds(r, year)))
          r,
    ];
    final h = _text(hint);
    if (matches.length > 1 && h != null) {
      final named =
          matches.where((r) => nameKey(r['album_artist']) == nameKey(h)).toList();
      if (named.length == 1) matches = named;
    }
    if (matches.length != 1) return ResolvedCredit.unknown;
    final m = matches.single;
    // A server too old to name credits says nothing either way.
    if (!m.containsKey('album_artist')) return ResolvedCredit.unknown;
    final c = albumArtistOf(m['album_artist']);
    return c == null
        ? ResolvedCredit.disagree
        : ResolvedCredit.known(c, compilation: m['compilation'] == true);
  }

  /// The whole resolution for [album]'s page once its [songs] loaded.
  Future<ResolvedCredit> resolve(DisplayItem album, List<DisplayItem> songs) async {
    final said = fromOpener(album) ?? fromSongs(songs);
    if (said != null) return _store(album, said);
    final peer = album.server;
    final name = _text(album.data);
    String? artist;
    for (final s in songs) {
      artist = _text(s.metadata?.artist);
      if (artist != null) break;
    }
    if (peer == null || name == null || artist == null) {
      return _store(album, ResolvedCredit.unknown);
    }
    try {
      final res = await _post(peer, '/api/v1/db/artists-albums', {'artist': artist})
          .timeout(timeout);
      return _store(
        album,
        fromArtistAlbums(res,
            album: name,
            year: album.year ?? album.yearHint,
            hint: album.creditHint),
      );
    } catch (_) {
      return _store(album, ResolvedCredit.unknown);
    }
  }

  static ResolvedCredit _store(DisplayItem album, ResolvedCredit r) {
    album.creditState = r.state;
    if (r.state == AlbumCredit.known) album.albumArtist = r.credit;
    // The list's word that it is a compilation (no listing said so before).
    if (r.compilation) album.compilation = true;
    return r;
  }
}

// ── what the Keep sheet is opened with ───────────────────────────────────

/// What a browse-entered Keep sheet copies.
enum KeepSubject { song, album, artist, folder }

/// Which of the sheet's three shapes it takes (the spec's V-page / V-item /
/// V-menu): from a page pill (header, Listen for an album or a folder, Keep
/// a copy), from a card or an album row (header, Listen with Open album ›,
/// Keep a copy), or from a menu row that just closed (header and Keep a copy
/// only — its menu held the queue verbs).
enum KeepVariant { page, item, menu }

/// The sheet's links that would point at the page right behind it, left
/// out: Open album on the album page. (The sheet draws no Open artist.)
enum KeepHiddenLink { openAlbum }

/// Everything a browse way in hands the Keep sheet: what it copies
/// ([subject]) and from where ([variant]), the recommendation ([lead], sent
/// unchanged), the connected server ([peer]) and the user's own ([own]: its
/// jobs, gate and destination — `CopiesHub().jobsFor(peer)`), the links to
/// leave out ([hidden]), the folder ([folder]: folder focus's, or a file
/// row's Folder chip), the artist page's own answer ([artist]: artist focus
/// plans from it, never asking again), whether an album is a compilation
/// ([compilation]: no Artist choice), the row or album it came from
/// ([item]: its cover and songs), and the opener's stable key for the focus
/// to go back to when the sheet closes ([focusKey], `{peerId}|{kind}|…`).
class BrowseKeepRequest {
  final KeepSubject subject;
  final KeepVariant variant;
  final Map<String, dynamic> lead;
  final Server peer;
  final Server own;
  final Set<KeepHiddenLink> hidden;
  final FolderRef? folder;
  final ArtistContext? artist;
  final bool compilation;
  final DisplayItem? item;
  final String focusKey;

  /// A song's own album credit (its `album-artist` tag, the one a queued
  /// track kept): a candidate only. The sheet keys Album on it once the
  /// connected server's album list bears it out — exactly one album of the
  /// song's album's name (and year): its credit wins, and one whose songs
  /// name different album artists leaves the credit out — or says nothing
  /// (none or several match, no list). Never in [lead].
  final String? songCredit;

  /// An album page's word on its credit when it is no credit: its songs
  /// name different album artists ([AlbumCredit.disagree]) or none was
  /// found ([AlbumCredit.unknown]). The sheet then offers no Album and
  /// looks for no credit of its own. Null off an album page, or while its
  /// credit still resolves.
  final AlbumCredit? pageCredit;

  /// The album page's songs, loaded (Play album and Queue album take them
  /// rather than asking again).
  final List<DisplayItem>? songs;

  /// A cover to draw when the request names no [item] (a queued track's
  /// own art).
  final String? coverUrl;

  const BrowseKeepRequest({
    required this.subject,
    required this.variant,
    required this.lead,
    required this.peer,
    required this.own,
    this.hidden = const {},
    this.folder,
    this.artist,
    this.compilation = false,
    this.item,
    required this.focusKey,
    this.songCredit,
    this.pageCredit,
    this.songs,
    this.coverUrl,
  });

  /// The connected server's name as the sheet's header says it.
  String get peerName => peer.federationPeerName ?? peer.displayName;
  int? get peerId => peer.federationPeerId;

  /// [lead] as the Keep card reads it.
  DiscoveryLead get discoveryLead => leadOfRec(lead);

  /// The choice the sheet opens on.
  String get initialScope => switch (subject) {
        KeepSubject.song => 'song',
        KeepSubject.album => 'album',
        KeepSubject.artist => 'artist',
        KeepSubject.folder => 'folder',
      };

  /// An album: its page pill ([KeepVariant.page], Open album left out), a
  /// card or an album row ([KeepVariant.item]). [credit] is the resolved
  /// one when the page holds it, [artists] and [songs] its loaded songs'
  /// own artists and the songs themselves. Null with no known credit, or
  /// off a connected server.
  static BrowseKeepRequest? album(
    DisplayItem album, {
    required KeepVariant variant,
    String? credit,
    Iterable<String>? artists,
    List<DisplayItem>? songs,
    Set<KeepHiddenLink>? hidden,
  }) {
    final lead = albumLeadOf(album,
        credit: credit, card: variant != KeepVariant.page, artists: artists);
    if (lead == null) return null;
    final c = lead['albumArtist'] as String;
    return BrowseKeepRequest(
      subject: KeepSubject.album,
      variant: variant,
      lead: lead,
      peer: album.server!,
      own: album.server!.parentServer!,
      hidden: hidden ??
          (variant == KeepVariant.page
              ? const {KeepHiddenLink.openAlbum}
              : const {}),
      compilation: albumIsCompilation(album, c, artists: artists),
      item: album,
      songs: songs,
      focusKey: browseKeepFocusKey(
          album.server!, KeepSubject.album, '${album.data}|$c'),
    );
  }

  /// A song row's menu row ([KeepVariant.menu]): [albumCredit] the album
  /// page's known credit, [pageCredit] its word when it has none (its songs
  /// disagree, none found); [folder] the explorer file row's folder (the
  /// Folder chip; none at a library's root). Off an album page the song's
  /// own `album-artist` is the sheet's candidate ([songCredit]). Null off a
  /// connected server.
  static BrowseKeepRequest? song(
    DisplayItem row, {
    String? albumCredit,
    AlbumCredit? pageCredit,
    FolderRef? folder,
    KeepVariant variant = KeepVariant.menu,
    Set<KeepHiddenLink> hidden = const {},
  }) {
    final lead = songLeadOf(row, albumCredit: albumCredit);
    if (lead == null) return null;
    final onPage = _text(albumCredit) != null ||
        (pageCredit != null && pageCredit != AlbumCredit.known);
    return BrowseKeepRequest(
      subject: KeepSubject.song,
      variant: variant,
      lead: lead,
      peer: row.server!,
      own: row.server!.parentServer!,
      hidden: hidden,
      folder: folder,
      item: row,
      songCredit: onPage ? null : _text(row.metadata?.albumArtist),
      pageCredit: onPage && _text(albumCredit) == null ? pageCredit : null,
      focusKey: browseKeepFocusKey(
          row.server!, KeepSubject.song, lead['filepath'] as String),
    );
  }

  /// The artist page's pill ([KeepVariant.page]).
  static BrowseKeepRequest? artistPage(ArtistContext artist) {
    final lead = artistLeadOf(artist);
    if (lead == null) return null;
    return BrowseKeepRequest(
      subject: KeepSubject.artist,
      variant: KeepVariant.page,
      lead: lead,
      peer: artist.server!,
      own: artist.server!.parentServer!,
      artist: artist,
      focusKey:
          browseKeepFocusKey(artist.server!, KeepSubject.artist, artist.name),
    );
  }

  /// A folder: the open folder's pill ([KeepVariant.page]) or a folder row's
  /// menu row ([KeepVariant.menu]). Null off a connected server.
  static BrowseKeepRequest? ofFolder(
    FolderRef folder,
    Server? peer, {
    required KeepVariant variant,
  }) {
    if (!isKeepPeer(peer)) return null;
    return BrowseKeepRequest(
      subject: KeepSubject.folder,
      variant: variant,
      lead: folder.rec(peer!),
      peer: peer,
      own: peer.parentServer!,
      folder: folder,
      focusKey: browseKeepFocusKey(peer, KeepSubject.folder, folder.path),
    );
  }

  /// A queued track's pane action ([KeepVariant.menu], on the track's own
  /// server — [queueKeepPeer] found it): its kept album credit the sheet's
  /// candidate, its cover the queue's own.
  static BrowseKeepRequest? queued(MediaItem item, Server peer) {
    if (!isKeepPeer(peer)) return null;
    final lead = queueLeadOf(item, peer);
    final x = item.extras ?? const <String, dynamic>{};
    final art = x['artUrl'];
    return BrowseKeepRequest(
      subject: KeepSubject.song,
      variant: KeepVariant.menu,
      lead: lead,
      peer: peer,
      own: peer.parentServer!,
      songCredit: _text(albumArtistOf(x['albumArtist'])),
      coverUrl: _text(art) ?? item.artUri?.toString(),
      focusKey: browseKeepFocusKey(
          peer, KeepSubject.song, '${lead['filepath'] ?? item.id}'),
    );
  }
}

/// An opener's stable key (the spec's focus return): `{peerId}|{kind}|…` —
/// the path of a song or a folder, the album and its credit, the artist —
/// so a pill or a row rebuilt by a poll is found again.
String browseKeepFocusKey(Server peer, KeepSubject kind, String value) =>
    '${peer.federationPeerId}|${kind.name}|$value';
