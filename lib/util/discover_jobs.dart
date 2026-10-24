/// The Discover job rows' pure half, ported from the mStream webapp's
/// `webapp/alpha/discover-jobs.js` (its cases in
/// `test/unit/webapp-discover-jobs.test.mjs` are ported in
/// test/util/discover_jobs_test.dart): what a plug-in job looks like as a
/// row, where a collection copy will land for the layout being typed, and
/// what the Copies list holds.
///
/// A path not landed yet draws a per-song variable it cannot promise one
/// value for as a slot ([scopeTarget]).
///
/// Nothing here speaks English: a row carries [JobPhrase]s with their
/// numbers ([JobText]) and the UI translates them; the server's own words
/// (a job's status line, its error) travel verbatim as [JobText.server].
///
/// Where the phone departs from the webapp it says so at the spot (the
/// Copies list keeps a finished copy that failed or stopped; an album job's
/// title names a compilation's album artist).
library;

import 'dart:math' as math;

import '../objects/discovery_plugins.dart';

// ── the layout engine, mirrored ──────────────────────────────────────────
// mStream src/torrent/path-template.js + src/discovery-plugins/destination.js
// (through the webapp's copy). The server renders the real path and has the
// last word; this renders the same thing as the user types so the picker's
// preview never lies. The unit test holds it to golden values the server's
// own engine produced.

const List<String> kLayoutVars = [
  'ARTIST',
  'ALBUM',
  'YEAR',
  'GENRE',
  'ALBUMARTIST',
  'PEER',
  'SERVERFOLDER',
];
const String kDefaultLayout = kDefaultCopyLayout;

/// The longest layout the server takes (UTF-16 units, as JS counts).
const int kMaxLayoutLength = 500;

/// The longest path a layout may render for a song: past it the server
/// refuses the copy (path_too_long).
const int kMaxPathLength = 500;
const int _maxSegmentLen = 200;
final RegExp _tokenRe = RegExp(r'\{\{\s*([A-Za-z_][A-Za-z0-9_]*)\s*\}\}');

/// The sample the server validates a layout against (SAMPLE_METADATA + peer
/// + serverfolder).
const Map<String, String> kSampleTags = {
  'artist': 'Pink Floyd',
  'album': 'The Dark Side of the Moon',
  'year': '1973',
  'genre': 'Progressive Rock',
  'albumartist': 'Pink Floyd',
};
const String kSamplePeer = "Sam's server";

/// {{SERVERFOLDER}}'s sample: two folders, as a song in a peer's library
/// usually sits, so a layout of just {{SERVERFOLDER}} validates.
const String kSampleServerFolder = 'Pink Floyd/The Dark Side of the Moon';

final RegExp _badSegmentChars = RegExp(r'[/\\:*?<>|"\x00-\x1f]+');
final RegExp _spaces = RegExp(r'\s+');
final RegExp _edgeDots = RegExp(r'^[.\s]+|[.\s]+$');
final RegExp _controlChars = RegExp(r'[\x00-\x1f]');
final RegExp _driveLetter = RegExp(r'^[a-zA-Z]:');
final RegExp _homeString = RegExp(r'\$\{HOME\}|\$HOME\b|~');

/// JS `String(v)` for the values a tag carries.
String _jsString(Object? v) {
  if (v is double && v == v.roundToDouble() && v.isFinite) {
    return v.toInt().toString();
  }
  return '$v';
}

/// JS `String.prototype.trim`. Dart's [String.trim] strips U+0085 (NEL) too,
/// which the server keeps: a folder named "a\u0085" stays that folder.
String _jsTrim(String s) => s.replaceAll(_jsEdgeSpace, '');
final RegExp _jsEdgeSpace = RegExp(r'^\s+|\s+$');

/// JS truthiness for a tag value (`a || b`).
bool _truthy(Object? v) =>
    v != null && v != '' && v != 0 && v != false && !(v is double && v.isNaN);

String sanitizeSegment(Object? raw) {
  if (raw == null) return '';
  var s = _jsString(raw);
  s = s.replaceAll(_badSegmentChars, '-');
  // A "~" or "$HOME" in a tag is a name, not a shell string: folded, as the
  // server's own sanitizeSegment folds it (the rendered path would otherwise
  // be refused).
  s = s.replaceAll(_homeString, '-');
  s = s.replaceAll(_spaces, ' ');
  s = s.replaceAll(_edgeDots, '');
  if (s.length > _maxSegmentLen) s = s.substring(0, _maxSegmentLen);
  return s;
}

/// A value that is a path of folders ({{SERVERFOLDER}}): split on either
/// separator, each folder made safe as [sanitizeSegment] makes a value, the
/// ones that come out empty dropped ('', '.', '..'), joined with '/'. So it
/// may add folders to a rendered path, never climb out of it.
String sanitizeFolders(Object? raw) {
  if (raw == null) return '';
  return _jsString(raw)
      .split(RegExp(r'[/\\]+'))
      .map(sanitizeSegment)
      .where((s) => s.isNotEmpty)
      .join('/');
}

/// A path on a peer as the server reads it (recommendation.js
/// normalizePeerPath): forward slashes, names trimmed, no empty or '.'
/// folders, the case kept ('..' kept too: [sanitizeFolders] drops it).
String normalizePeerPath(Object? p) => (p == null ? '' : _jsString(p))
    .replaceAll('\\', '/')
    .split('/')
    .map(_jsTrim)
    .where((s) => s.isNotEmpty && s != '.')
    .join('/');

String _peerPath(Object? p) => normalizePeerPath(p);

/// {{SERVERFOLDER}} of the song at [filepath], its path on the connected
/// server (federation-copy.js serverFolderOf): the folder its file sits in,
/// the peer's library (the first folder) dropped, each folder made safe. It
/// may be several folders ("Boukmanflow/Borrowed Tapes"); '' for a song at
/// the library's root (or no path: a download), which drops the variable's
/// folder like any empty one.
String serverFolderOf(Object? filepath) {
  final segs = _peerPath(filepath).split('/');
  if (segs.length < 3) return '';
  return sanitizeFolders(segs.sublist(1, segs.length - 1).join('/'));
}

/// A rendered layout: the path, and the variables this song had no value
/// for (their segments drop out).
class ResolvedLayout {
  final String path;
  final List<String> missingVars;
  const ResolvedLayout(this.path, this.missingVars);
}

/// [meta] keys: artist, album, year, genre, albumartist, peer, serverfolder
/// (the one value that may be several folders: [sanitizeFolders]). A path
/// past 500 characters is cut to them, as the server's resolveTemplate cuts
/// it; [truncate] false returns it whole, for [previewTarget] to refuse as
/// the server's renderTarget does.
ResolvedLayout resolveLayout(
  Object? layout,
  Map<String, Object?>? meta, {
  bool truncate = true,
}) {
  if (layout is! String || layout.isEmpty) return const ResolvedLayout('', []);
  final m = meta ?? const {};
  final lookup = <String, String>{
    'ARTIST': sanitizeSegment(m['artist']),
    'ALBUM': sanitizeSegment(m['album']),
    'YEAR': sanitizeSegment(m['year']),
    'GENRE': sanitizeSegment(m['genre']),
    'ALBUMARTIST': sanitizeSegment(
        _truthy(m['albumartist']) ? m['albumartist'] : m['artist']),
    'PEER': sanitizeSegment(m['peer']),
    // Several folders, each made safe: inside literal text ("Copy of
    // {{SERVERFOLDER}}") the value's own folders follow the literal's.
    'SERVERFOLDER': sanitizeFolders(m['serverfolder']),
  };
  final missing = <String>[];
  final substituted = layout.replaceAllMapped(_tokenRe, (match) {
    final key = match.group(1)!.toUpperCase();
    final v = lookup[key];
    if (v == null || v.isEmpty) {
      if (!missing.contains(key)) missing.add(key);
      return '';
    }
    return v;
  });
  final segments = substituted
      .split(RegExp(r'[/\\]+'))
      .map(_jsTrim)
      .where((s) => s.isNotEmpty);
  var path = segments.join('/');
  if (truncate && path.length > kMaxPathLength) {
    path = path.substring(0, kMaxPathLength);
  }
  return ResolvedLayout(path, missing);
}

/// valid, or the server's error code (one translation table serves both),
/// with the offending variable for `unknown_variable`: its [variable] name
/// upper-cased, and its [token] as it was typed (the server's message names
/// that one).
class LayoutCheck {
  final bool valid;
  final String? error;
  final String? variable;
  final String? token;
  const LayoutCheck.ok()
      : valid = true,
        error = null,
        variable = null,
        token = null;
  const LayoutCheck.bad(this.error, {this.variable, this.token})
      : valid = false;
}

LayoutCheck validateResolvedPath(Object? path) {
  if (path is! String) return const LayoutCheck.bad('invalid_type');
  if (path.isEmpty) return const LayoutCheck.bad('empty_path');
  if (path.length > kMaxPathLength) return const LayoutCheck.bad('path_too_long');
  if (_controlChars.hasMatch(path)) return const LayoutCheck.bad('invalid_chars');
  if (path.startsWith('/') || path.startsWith('\\')) {
    return const LayoutCheck.bad('absolute_path');
  }
  if (_driveLetter.hasMatch(path)) return const LayoutCheck.bad('drive_letter');
  if (path.contains('~') ||
      RegExp(r'\$HOME\b').hasMatch(path) ||
      path.contains(r'${HOME}')) {
    return const LayoutCheck.bad('home_string');
  }
  for (final seg in path.split(RegExp(r'[/\\]'))) {
    if (seg == '..') return const LayoutCheck.bad('traversal');
    if (_driveLetter.hasMatch(seg)) {
      return const LayoutCheck.bad('drive_letter_segment');
    }
  }
  return const LayoutCheck.ok();
}

LayoutCheck validateLayout(Object? layout) {
  if (layout is! String) return const LayoutCheck.bad('invalid_type');
  if (layout.isEmpty) return const LayoutCheck.bad('empty_template');
  if (layout.length > kMaxLayoutLength) {
    return const LayoutCheck.bad('template_too_long');
  }
  final tokens = [
    for (final m in _tokenRe.allMatches(layout))
      (raw: m.group(0)!, name: m.group(1)!.toUpperCase()),
  ];
  var stripped = layout;
  for (final tok in tokens) {
    stripped = stripped.replaceFirst(tok.raw, '');
  }
  if (stripped.contains('{') || stripped.contains('}')) {
    return const LayoutCheck.bad('unbalanced_braces');
  }
  for (final tok in tokens) {
    if (!kLayoutVars.contains(tok.name)) {
      return LayoutCheck.bad(
        'unknown_variable',
        variable: tok.name,
        token: tok.raw,
      );
    }
  }
  if (_controlChars.hasMatch(layout)) return const LayoutCheck.bad('invalid_chars');
  if (layout.startsWith('/') || layout.startsWith('\\')) {
    return const LayoutCheck.bad('absolute_template');
  }
  final sample = resolveLayout(layout, {
    ...kSampleTags,
    'peer': kSamplePeer,
    'serverfolder': kSampleServerFolder,
  }).path;
  return validateResolvedPath(sample);
}

/// A base folder, normalised ('' = the library root), or the error code.
class BaseCheck {
  final bool valid;
  final String base;
  final String? error;
  const BaseCheck.ok(this.base)
      : valid = true,
        error = null;
  const BaseCheck.bad(this.error)
      : valid = false,
        base = '';
}

BaseCheck normalizeBase(Object? base) {
  final raw = _baseFolders(base);
  if (raw.isEmpty) return const BaseCheck.ok('');
  final check = validateResolvedPath(raw);
  return check.valid ? BaseCheck.ok(raw) : BaseCheck.bad(check.error);
}

/// [base]'s folders as the server reads them, not yet checked: either
/// separator, names trimmed, empty ones gone.
String _baseFolders(Object? base) => (base == null ? '' : _jsString(base))
    .replaceAll('\\', '/')
    .split('/')
    .map(_jsTrim)
    .where((s) => s.isNotEmpty)
    .join('/');

/// [layout] with the base folder [base] in front of it: the phone keeps no
/// base folder of its own (the webapp and the terminal do, on the one
/// setting the account has), so it holds a destination's as the start of
/// the layout. The server files a song at base folder / rendered layout,
/// and so files it at the same place from base '' and this layout — except
/// where a folder's name has a brace ([bracedFolder]): a stray brace or an
/// unknown variable [validateLayout] refuses, a known one ({{ARTIST}})
/// renders as the variable; and past 500 characters, where the layout is
/// refused or its render cut where the server's base + render is not. A
/// base [normalizeBase] refuses comes in front as read, for
/// [validateLayout] to name. No base folder: [layout] as it is.
String foldBase(Object? base, String layout) {
  final folders = _baseFolders(base);
  return folders.isEmpty ? layout : '$folders/$layout';
}

/// The first of [base]'s folders a layout cannot hold as that folder: one
/// whose name has a brace, which a layout reads as a variable ("{{PEER}}"
/// files under the server's name) or refuses. null when there is none.
String? bracedFolder(Object? base) {
  for (final folder in _baseFolders(base).split('/')) {
    if (folder.contains('{') || folder.contains('}')) return folder;
  }
  return null;
}

/// A layout's leading folders that name no variable — where every copy
/// lands whatever its tags ("From friends/{{ARTIST}}" → "From friends",
/// each trimmed, joined with '/') — and the rest of it as typed
/// ("{{ARTIST}}"): destination.js layoutLead, the webapp's.
({String folders, String rest}) layoutLead(Object? layout) {
  final s = layout == null ? '' : _jsString(layout);
  // Split keeping the separators, as the webapp's /([/\\]+)/ does.
  final parts = <String>[];
  var at = 0;
  for (final m in RegExp(r'[/\\]+').allMatches(s)) {
    parts
      ..add(s.substring(at, m.start))
      ..add(m.group(0)!);
    at = m.end;
  }
  parts.add(s.substring(at));
  final folders = <String>[];
  var i = 0;
  for (; i < parts.length; i += 2) {
    final seg = _jsTrim(parts[i]);
    if (seg.contains('{') || seg.contains('}')) break;
    if (seg.isNotEmpty) folders.add(seg);
  }
  return (
    folders: folders.join('/'),
    rest: i < parts.length ? parts.sublist(i).join() : '',
  );
}

/// Whether two destinations put files in the same place — the jobs route's
/// own test for a start's `destination_changed` (destination.js
/// sameDestination, the webapp's discover-jobs.js): the library, the base
/// folder as [normalizeBase] reads it, the layout character for character.
/// `source` is not compared; null matches only null.
bool sameDestination(CollectionDestination? a, CollectionDestination? b) {
  if (a == null || b == null) return a == null && b == null;
  final x = normalizeBase(a.base);
  final y = normalizeBase(b.base);
  return a.vpath == b.vpath &&
      x.valid &&
      y.valid &&
      x.base == y.base &&
      a.layout == b.layout;
}

String safeFileName(Object? filePath) {
  final parts = _jsString(filePath ?? '').split('/').where((s) => s.isNotEmpty);
  final last = parts.isEmpty ? '' : parts.last;
  var name = last
      .replaceAll(_badSegmentChars, '-')
      .replaceAll(_spaces, ' ')
      .replaceAll(_edgeDots, '');
  if (name.isEmpty || name == '..') name = 'track';
  return name;
}

/// Where one song lands: the library, the base folder, what the layout
/// rendered from the tags, the file. [error] is set (and [rendered] empty)
/// when the layout or the base folder would be refused, [field] names
/// which; [missingVars] names the variables this song has no value for.
class PreviewTarget {
  final bool valid;
  final String? error;
  final String? variable;

  /// `base` | `layout` | null
  final String? field;
  final String library;
  final String base;
  final String rendered;
  final String file;
  final String relDir;
  final String relPath;
  final List<String> missingVars;

  const PreviewTarget({
    required this.valid,
    this.error,
    this.variable,
    this.field,
    required this.library,
    required this.base,
    required this.rendered,
    required this.file,
    this.relDir = '',
    required this.relPath,
    this.missingVars = const [],
  });

  /// The line the Keep card draws: library › folders (no file).
  List<String> get crumbs => [
        if (library.isNotEmpty) library,
        ...pathCrumbs(relDir),
      ];

  /// A layout the server takes renders this song a path past
  /// [kMaxPathLength] (long tags, deep folders on the connected server):
  /// the server refuses the copy, though nothing is wrong with the layout.
  bool get tooLong => field == 'layout' && error == 'path_too_long';
}

/// [tags] keys: artist, album, year, genre, albumartist. [serverFolder] is
/// {{SERVERFOLDER}}: the folders the song sits in on the connected server
/// ([serverFolderOf]; none for a download), as destination.js renderTarget
/// takes it. The layout renders whole, as there: a path past 500
/// characters is refused (path_too_long), never cut mid-folder.
PreviewTarget previewTarget({
  String? vpath,
  Object? base,
  Object? layout,
  Map<String, Object?>? tags,
  String? peerName,
  Object? serverFolder,
  String? fileName,
}) {
  final t = tags ?? const {};
  final b = normalizeBase(base);
  final l = validateLayout(layout);
  final file = safeFileName(fileName);
  final lib = vpath ?? '';
  if (!b.valid) {
    return PreviewTarget(
        valid: false,
        error: b.error,
        field: 'base',
        library: lib,
        base: '',
        rendered: '',
        file: file,
        relPath: '');
  }
  if (!l.valid) {
    return PreviewTarget(
        valid: false,
        error: l.error,
        variable: l.variable,
        field: 'layout',
        library: lib,
        base: b.base,
        rendered: '',
        file: file,
        relPath: '');
  }
  final r = resolveLayout(layout, {
    'artist': t['artist'],
    'album': t['album'],
    'year': t['year'],
    'genre': t['genre'],
    'albumartist': t['albumartist'],
    'peer': peerName,
    'serverfolder': serverFolder,
  }, truncate: false);
  if (r.path.isNotEmpty) {
    final check = validateResolvedPath(r.path);
    if (!check.valid) {
      return PreviewTarget(
          valid: false,
          error: check.error,
          field: 'layout',
          library: lib,
          base: b.base,
          rendered: '',
          file: file,
          relPath: '',
          missingVars: r.missingVars);
    }
  }
  final relDir = [b.base, r.path].where((s) => s.isNotEmpty).join('/');
  return PreviewTarget(
    valid: true,
    library: lib,
    base: b.base,
    rendered: r.path,
    file: file,
    relDir: relDir,
    relPath: relDir.isNotEmpty ? '$relDir/$file' : file,
    missingVars: r.missingVars,
  );
}

/// "music/A/B/c.mp3" → ['music', 'A', 'B', 'c.mp3'], for a breadcrumb.
List<String> pathCrumbs(String? filepath) =>
    (filepath ?? '').split('/').where((s) => s.isNotEmpty).toList();

// ── where a copy of one scope lands ──────────────────────────────────────
// The webapp's scopeTarget. "Files go to", the Retry / Add again lines, the
// every-album question and the destination picker's preview render the
// base folder and the layout with the tags of what the scope copies. The
// server files EACH SONG by the copied file's own tags (destination.js
// tagsForLayout: artist, album, year, genre, albumartist — artist and album
// fall back to the song the copy was handed, genre and albumartist do not,
// and nor does the year: neither a song's copy nor an album's listing
// hands one in, federation-copy listAlbumSongs), so {{ARTIST}}, {{YEAR}}
// and {{GENRE}} are per song, and so is {{SERVERFOLDER}} (where the song's
// file sits on the connected server, federation-copy serverFolderOf: no tag
// changes it), while {{ALBUM}}, {{ALBUMARTIST}} (the album's credit) and
// {{PEER}} are one value for every song of an album. A per-song variable
// this client cannot promise one value for stands as a SLOT inside its
// folder ("From friends › ‹artist›"), the folder's own text kept — never
// one song's value for them all:
//   song            the song's own values (its own folder on the server
//                   too); {{GENRE}} its genre only when this client has
//                   it, else the slot
//   album           {{ARTIST}} / {{YEAR}} the value only when every song of
//                   the album's listing agrees (a song with no artist tag
//                   files under the album's credit; one with no year
//                   without the year folder, a place of its own); until
//                   the listing answers, the row's own unless it is a
//                   compilation (its credit is not its artist), else the
//                   slot. {{GENRE}} the slot unless every song's genre is
//                   known and agrees. {{SERVERFOLDER}} the folders when
//                   every song of the listing sits in the same one, else
//                   the slot; until the listing answers, the row's own
//   artist          the artist as ARTIST and ALBUMARTIST, no album: the
//                   first folder that names an album ({{ALBUM}}, or
//                   {{YEAR}} or {{SERVERFOLDER}} — each album has its own)
//                   and every folder after it are "one folder per album"
//                   ([perAlbum]); a {{GENRE}} before it is the slot
//   artist-missing  the same — or, when exactly one album is missing
//                   ([oneAlbum]: its name and year), that album's folder;
//                   {{SERVERFOLDER}} the slot (each album sits in folders
//                   of its own on the server)
// A path that has landed (a finished copy's files) is the server's own
// filepath: no slots there.

/// A per-song variable a path cannot promise one value for ([albumArtist]:
/// a folder copy's songs that name different album credits, or only some
/// name one — the copy files each under its own, the rest under their
/// artist).
enum LayoutSlot { artist, year, genre, serverFolder, albumArtist }

/// [slot]'s mark inside a rendered path: private-use characters no tag
/// brings and the layout engine leaves alone. The UI draws the slot's word
/// in its place ([slotParts], [slotText]).
String slotMark(LayoutSlot slot) => '\uE000${slot.name}\uE001';

final RegExp _slotRe = RegExp(
  '\uE000(${LayoutSlot.values.map((s) => s.name).join('|')})\uE001',
);
final RegExp _strayMark = RegExp('[\uE000\uE001]');

/// [s] cut at its slots, in order: plain text ([slot] null) and slots.
List<({String text, LayoutSlot? slot})> slotParts(String s) {
  final out = <({String text, LayoutSlot? slot})>[];
  void text(String t) {
    // A mark a 500-character cut split in two is no slot: left out.
    final plain = t.replaceAll(_strayMark, '');
    if (plain.isNotEmpty) out.add((text: plain, slot: null));
  }

  var at = 0;
  for (final m in _slotRe.allMatches(s)) {
    text(s.substring(at, m.start));
    out.add((text: '', slot: LayoutSlot.values.byName(m.group(1)!)));
    at = m.end;
  }
  text(s.substring(at));
  return out;
}

/// [s] as read, each slot as [word] names it.
String slotText(String s, String Function(LayoutSlot slot) word) =>
    [for (final p in slotParts(s)) p.slot == null ? p.text : word(p.slot!)]
        .join();

/// The slots [crumbs] show, in [LayoutSlot] order.
List<LayoutSlot> slotsIn(Iterable<String> crumbs) => [
      for (final slot in LayoutSlot.values)
        if (crumbs.any((c) => c.contains(slotMark(slot)))) slot,
    ];

/// One song of an album copy as the album's listing tells it: its ARTIST
/// tag as written, its year, its genre when this client can tell the one
/// its file carries (null when it cannot), and the folders its file sits in
/// on the connected server ([serverFolderOf] of the listing's path; '' at
/// the library's root). A missing artist falls back to the album's credit,
/// as the server's listing does; a missing year is none — the copy has
/// nothing to fall back to.
class LayoutSong {
  final Object? artist;
  final Object? year;
  final String? genre;
  final String serverFolder;
  const LayoutSong({
    this.artist,
    this.year,
    this.genre,
    this.serverFolder = '',
  });
}

/// Where a copy of one scope lands: [target] holds previewTarget's checks
/// (valid, error, field, the file, missingVars); [rendered] is what the
/// layout rendered — for an artist copy, up to the first album's folder.
class ScopeTarget {
  final PreviewTarget target;
  final String rendered;

  /// An artist copy — or a folder copy by the layout whose songs sit in
  /// more than one album — one folder per album under [rendered].
  final bool perAlbum;

  /// A folder copy: how it lands ([FolderLanding]); null for every other
  /// scope.
  final FolderLanding? landing;

  /// A folder copy whose path is one folder: where its files land below it
  /// ([folderFiles]); null while uncounted, and wherever the path is not
  /// exact (a slot, one folder per album).
  final FolderFiles? files;

  /// Into a folder…: the chosen folder is not named as the pressed one (or
  /// is the library's root), so the pressed folder's files go straight into
  /// [folder] with no folder of their own named [name]; null otherwise.
  final ({String folder, String name})? straightIn;

  const ScopeTarget(
    this.target,
    this.rendered, {
    this.perAlbum = false,
    this.landing,
    this.files,
    this.straightIn,
  });

  bool get valid => target.valid;

  /// The line the Keep card draws: library › base folders › what the layout
  /// rendered (slot marks inside), no file.
  List<String> get crumbs => [
        if (target.library.isNotEmpty) target.library,
        ...pathCrumbs(target.base),
        ...pathCrumbs(rendered),
      ];

  /// The slots the path shows, in [LayoutSlot] order.
  List<LayoutSlot> get slots => slotsIn(crumbs);
}

/// A row whose album credit is not its own artist ("Various Artists" over
/// one track artist): its album's songs are other artists' too (the album
/// card's own test, discoveryCardIsCompilation).
bool _compilation(Object? artist, Object? credit) {
  final c = _truthy(credit) ? _jsString(credit).trim().toLowerCase() : '';
  final a = _truthy(artist) ? _jsString(artist).trim().toLowerCase() : '';
  return c.isNotEmpty && c != a;
}

/// The value every one of [values] files under (the first as given), or
/// [slot]'s mark when two would make different folders ([folders]: as
/// [sanitizeFolders] makes them — "a/b" is two folders, never "a-b").
Object? _agreed(Iterable<Object?> values, LayoutSlot slot,
    {String Function(Object?) folders = sanitizeSegment}) {
  Object? first;
  String? key;
  for (final v in values) {
    final k = folders(v);
    if (key == null) {
      key = k;
      first = v;
    } else if (k != key) {
      return slotMark(slot);
    }
  }
  return first;
}

/// The value every one of [values] files under (the first as given), or
/// null when two would make different folders.
({Object? value})? _shared(Iterable<Object?> values) {
  Object? first;
  String? key;
  for (final v in values) {
    final k = sanitizeSegment(v);
    if (key == null) {
      key = k;
      first = v;
    } else if (k != key) {
      return null;
    }
  }
  return (value: first);
}

final RegExp _albumFolderRe = RegExp(
  r'\{\{\s*(album|year|serverfolder)\s*\}\}',
  caseSensitive: false,
);

/// Where a copy of [scope] lands (see above). [tags] are the row's (artist,
/// album, year, albumartist) and, for a song, its genre when this client has
/// it; [serverFolder] the row's own folders on the connected server
/// ([serverFolderOf] of its path); [albumSongs] the album's listing (null
/// until it answers); [oneAlbum] the one album an artist-missing copy
/// takes, when only one is missing.
///
/// A folder copy ([kScopeFolder]) lands by its [landing] — as on the
/// connected server (none), into a folder (`{vpath, path}`), or by the
/// layout (`{tags: true}`): [folder] is the pressed folder's path there,
/// [folderSongs] what the copy takes ([planFolder]; null until counted) and
/// [folderTags] the songs' own tags for "By your layout" ([folderSongTags]
/// of the peer's metadata batch; null when none were read). See
/// [folderTarget].
ScopeTarget scopeTarget({
  String? vpath,
  Object? base,
  Object? layout,
  String scope = kScopeSong,
  Map<String, Object?>? tags,
  String? serverFolder,
  List<LayoutSong>? albumSongs,
  ({String name, Object? year})? oneAlbum,
  String? peerName,
  String? fileName,
  Object? landing,
  String? folder,
  List<FolderSong>? folderSongs,
  List<FolderSongTags>? folderTags,
}) {
  if (scope == kScopeFolder) {
    return folderTarget(
      vpath: vpath,
      base: base,
      layout: layout,
      landing: landing,
      folder: folder,
      songs: folderSongs,
      tags: folderTags,
      peerName: peerName,
    );
  }
  final t = tags ?? const <String, Object?>{};
  final artistScope = scope == kScopeArtist || scope == kScopeArtistMissing;
  final one = scope == kScopeArtistMissing ? oneAlbum : null;
  final wide = artistScope && one == null;
  final genre = slotMark(LayoutSlot.genre);
  final Map<String, Object?> v;
  final Object? onServer;
  if (artistScope) {
    // Each album's songs sit in folders of their own on the server: the
    // slot (an every-album copy cuts its path before it — "one folder per
    // album").
    onServer = slotMark(LayoutSlot.serverFolder);
    v = {
      'artist': t['artist'],
      'album': one?.name,
      'year': one?.year,
      'genre': genre,
      // The artist walk copies the artist's own albums, credited to the
      // artist (federation-copy asks album-songs by albumArtist = the
      // artist): ALBUMARTIST falls back to the artist, never this row's
      // compilation credit ("Various Artists").
      'albumartist': null,
    };
  } else if (scope == kScopeAlbum) {
    final artist = t['artist'];
    final year = t['year'];
    final credit = t['albumartist'];
    // The album's credit, one for every song: never the slot ARTIST may be.
    final albumCredit = _truthy(credit) ? credit : artist;
    final songs = albumSongs;
    final listed = songs != null && songs.isNotEmpty;
    final various = _compilation(artist, credit);
    // Where the listed songs sit on the server: their folders when they all
    // sit in the same ones, else the slot; the row's own until the listing
    // answers.
    onServer = listed
        ? _agreed(
            songs.map((s) => s.serverFolder),
            LayoutSlot.serverFolder,
            folders: sanitizeFolders,
          )
        : serverFolder;
    v = {
      // A listed song with no artist tag files under the credit the listing
      // was asked by (federation-copy listAlbumSongs' fallbackArtist).
      'artist': listed
          ? _agreed(
              songs.map((s) => _truthy(s.artist) ? s.artist : albumCredit),
              LayoutSlot.artist,
            )
          : (various ? slotMark(LayoutSlot.artist) : artist),
      'album': t['album'],
      // A listed song's year as the listing gives it: one with none files
      // without the year folder (the copy has no year to fall back to).
      'year': listed
          ? _agreed(songs.map((s) => s.year), LayoutSlot.year)
          : (various ? slotMark(LayoutSlot.year) : year),
      'genre': listed && songs.every((s) => _truthy(s.genre))
          ? _agreed(songs.map((s) => s.genre), LayoutSlot.genre)
          : genre,
      'albumartist': albumCredit,
    };
  } else {
    onServer = serverFolder;
    v = {
      'artist': t['artist'],
      'album': t['album'],
      'year': t['year'],
      'genre': _truthy(t['genre']) ? t['genre'] : genre,
      'albumartist': t['albumartist'],
    };
  }
  final target = previewTarget(
    vpath: vpath,
    base: base,
    layout: layout,
    tags: v,
    peerName: peerName,
    serverFolder: onServer,
    fileName: fileName,
  );
  if (!target.valid || !wide) return ScopeTarget(target, target.rendered);
  final folders = (layout as String).split(RegExp(r'[/\\]+'));
  final at = folders.indexWhere(_albumFolderRe.hasMatch);
  if (at == -1) return ScopeTarget(target, target.rendered);
  final head = resolveLayout(folders.sublist(0, at).join('/'), {
    'artist': v['artist'],
    'genre': genre,
    'peer': peerName,
  });
  return ScopeTarget(target, head.path, perAlbum: true);
}

// ── a folder from a connected server ─────────────────────────────────────
// federation-copy's folder half, mirrored through the webapp's
// discover-jobs.js: what a folder copy takes (planFolder) and where it lands
// (landingFor), so the sheet counts, lists and places the folder the way the
// copy will. Any change to the rules there has to be made here too — the
// webapp's cases are ported in test/util/discover_jobs_folder_test.dart.

/// A folder's path inside the peer's library: its first folder (the
/// library's own name) dropped, each folder made safe, the empty ones gone —
/// what a mirrored folder lands as (federation-copy insidePeerLibrary;
/// [serverFolderOf] is a song's: the folder its file sits in).
String insidePeerLibrary(Object? folder) => sanitizeFolders(
    normalizePeerPath(folder).split('/').skip(1).join('/'));

// src/db/scan-ignore.js isIgnoredRelPath (the scanner's defaults): a path
// through a folder the scanner never walks — a recycle bin, a snapshot, VCS
// or OS litter, a dot folder — or to a dot file. A dot entry is ONE leading
// dot ("...Trilogy" is a name).
const Set<String> kIgnoredDirNames = {
  r'$recycle.bin',
  '#recycle',
  '@recycle',
  '@recently-snapshot',
  '#snapshot',
  '.git',
  'lost+found',
  '.stfolder',
  '.stversions',
  'system volume information',
};

bool _dotEntry(String name) => name.startsWith('.') && !name.startsWith('..');

bool isIgnoredRelPath(String relPath) {
  final segs = relPath.split('/');
  for (var i = 0; i < segs.length; i++) {
    final seg = segs[i];
    if (seg.isEmpty) continue;
    final ignored = i == segs.length - 1
        ? _dotEntry(seg)
        : kIgnoredDirNames.contains(seg.toLowerCase()) || _dotEntry(seg);
    if (ignored) return true;
  }
  return false;
}

/// destination.js isSupportedAudioFile, by the ping's supportedAudioFiles
/// (`{mp3: true, …}`): the file's extension, any case. No map: nothing is
/// known to play.
bool isSupportedAudioFile(Object? fileName, Map<String, bool>? supported) {
  final last = (fileName == null ? '' : _jsString(fileName)).split('/').last;
  final dots = last.split('.');
  final ext = dots.length > 1 ? dots.last : '';
  return ext.isNotEmpty &&
      supported != null &&
      supported[ext.toLowerCase()] == true;
}

/// One song a folder copy takes: its path on the connected server (as
/// [normalizePeerPath] reads it) and the folder it sits in relative to the
/// pressed one, each folder made safe ('' when it sits in the folder
/// itself).
class FolderSong {
  final String filepath;
  final String relDir;
  const FolderSong(this.filepath, {this.relDir = ''});

  @override
  bool operator ==(Object other) =>
      other is FolderSong && other.filepath == filepath && other.relDir == relDir;

  @override
  int get hashCode => Object.hash(filepath, relDir);

  @override
  String toString() => 'FolderSong($filepath${relDir.isEmpty ? '' : ', $relDir'})';
}

/// What a folder copy takes ([songs], in path order) and leaves out
/// ([skipped]: each listed entry as sent, with why — `outside`, `ignored`,
/// `unsupported`).
class FolderPlan {
  final List<FolderSong> songs;
  final List<({Object? from, String why})> skipped;
  const FolderPlan({this.songs = const [], this.skipped = const []});
}

/// JS `a.localeCompare(b, undefined, {numeric: true, sensitivity: 'base'})`
/// — ICU's root order, near enough for a folder's paths: character by
/// character, spaces first, then punctuation and symbols in ICU's own
/// sequence ([_marks]), then a run of digits by its number, then letters
/// case- and accent-folded (Latin-1 and Latin Extended-A; ß as "ss", æ as
/// "ae", œ as "oe"). Equal at that level is equal: the caller's sort keeps
/// the listed order then, as JS's stable sort does.
int _pathOrder(String a, String b) {
  final x = _collation(a), y = _collation(b);
  for (var i = 0; i < x.length && i < y.length; i++) {
    final p = x[i], q = y[i];
    if (p.rank != q.rank) return p.rank - q.rank;
    final c = p.rank == _digits
        ? p.number!.compareTo(q.number!)
        : p.weight - q.weight;
    if (c != 0) return c;
  }
  return x.length - y.length;
}

// The classes of ICU's root order, lowest first.
const int _space = 0, _mark = 1, _digits = 2, _letter = 3;

/// ICU root's punctuation and symbols in its order; the characters of one
/// entry weigh the same ('‘’ as ', “” as ").
const List<String> _marks = [
  '_', '-', '–', '—', ',', ';', ':', '!', '¡', '?', '¿', '.', '…', '·', //
  "'‘’", '"“”', '«', '»', '(', ')', '[', ']', '{', '}', '§', '¶', '@', //
  '*', '/', r'\', '&', '#', '%', '`', '´', '^', '¯', '¨', '¸', '°', '©', //
  '®', '+', '±', '÷', '×', '<', '=', '>', '¬', '|', '¦', '~', '¤', '¢', //
  r'$', '£', '¥', '€',
];

final Map<int, int> _markWeight = {
  for (var g = 0; g < _marks.length; g++)
    for (final r in _marks[g].runes) r: g,
};

/// Lower-case Latin letters with a mark, and the letter each folds to.
const String _accented =
    'àáâãäåçèéêëìíîïðñòóôõöøùúûüýÿāăąćĉċčďđēĕėęěĝğġģĥħĩīĭįĵķĺļľŀł'
    'ńņňōŏőŕŗřśŝşšţťũūŭůűųŵŷźżžſ';
const String _plain =
    'aaaaaaceeeeiiiidnoooooouuuuyyaaaccccddeeeeegggghhiiiiijklllll'
    'nnnooorrrssssttuuuuuuwyzzzs';
const Map<String, String> _expanded = {'ß': 'ss', 'æ': 'ae', 'œ': 'oe'};

/// [s] as ICU's root order compares it at its base level: one element a
/// character, a run of digits one element of its number.
List<({int rank, int weight, BigInt? number})> _collation(String s) {
  final folded = StringBuffer();
  for (final ch in s.toLowerCase().split('')) {
    final i = _accented.indexOf(ch);
    folded.write(_expanded[ch] ?? (i == -1 ? ch : _plain[i]));
  }
  final out = <({int rank, int weight, BigInt? number})>[];
  final runes = folded.toString().runes.toList();
  for (var i = 0; i < runes.length; i++) {
    final r = runes[i];
    if (r >= 0x30 && r <= 0x39) {
      var j = i;
      while (j < runes.length && runes[j] >= 0x30 && runes[j] <= 0x39) {
        j++;
      }
      out.add((
        rank: _digits,
        weight: 0,
        number: BigInt.parse(String.fromCharCodes(runes.sublist(i, j))),
      ));
      i = j - 1;
    } else if (r == 0x20 || r == 0xA0 || r == 0x09) {
      out.add((rank: _space, weight: 0, number: null));
    } else if (_markWeight.containsKey(r)) {
      out.add((rank: _mark, weight: _markWeight[r]!, number: null));
    } else {
      out.add((rank: _letter, weight: r, number: null));
    }
  }
  return out;
}

/// What a folder copy takes (federation-copy planFolder): every file the
/// peer's recursive [listing] names under [folderPath] (its library first),
/// in path order, each with the folder it sits in relative to the pressed
/// one, and what it leaves out, with why — `outside` (not under the folder,
/// or climbing), `ignored` (the scanner's rules), `unsupported` (a file this
/// server does not play: [supported] is the own server's
/// supportedAudioFiles; without it every file the listing names is taken).
/// One entry per path.
FolderPlan planFolder(Object? listing, Object? folderPath,
    {Map<String, bool>? supported}) {
  final dir = normalizePeerPath(folderPath);
  final prefix = dir.isEmpty ? '' : '$dir/';
  final songs = <FolderSong>[];
  final skipped = <({Object? from, String why})>[];
  final seen = <String>{};
  for (final raw in listing is List ? listing : const []) {
    if (raw is! String) continue;
    final p = normalizePeerPath(raw);
    if (p.isEmpty || !seen.add(p)) continue;
    if (prefix.isNotEmpty && !p.startsWith(prefix)) {
      skipped.add((from: raw, why: 'outside'));
      continue;
    }
    final rel = prefix.isEmpty ? p : p.substring(prefix.length);
    final segs = rel.split('/');
    if (segs.any((x) => x == '..')) {
      skipped.add((from: raw, why: 'outside'));
      continue;
    }
    if (isIgnoredRelPath(rel)) {
      skipped.add((from: raw, why: 'ignored'));
      continue;
    }
    if (supported != null && !isSupportedAudioFile(segs.last, supported)) {
      skipped.add((from: raw, why: 'unsupported'));
      continue;
    }
    songs.add(FolderSong(
      p,
      relDir: segs
          .sublist(0, segs.length - 1)
          .map(sanitizeSegment)
          .where((x) => x.isNotEmpty)
          .join('/'),
    ));
  }
  // A stable sort, as JS's: by path, then the order listed.
  final indexed = [for (var i = 0; i < songs.length; i++) (songs[i], i)];
  indexed.sort((a, b) {
    final c = _pathOrder(a.$1.filepath, b.$1.filepath);
    return c != 0 ? c : a.$2 - b.$2;
  });
  return FolderPlan(
    songs: List.unmodifiable([for (final x in indexed) x.$1]),
    skipped: List.unmodifiable(skipped),
  );
}

/// A planned folder's numbers for the sheet's header ("9 songs · 3
/// subfolders"): its songs, and the subfolders that hold any — every folder
/// on a song's way down from the pressed one, counted once.
({int songs, int subfolders}) folderCounts(List<FolderSong>? songs) {
  final list = songs ?? const <FolderSong>[];
  final folders = <String>{};
  for (final song in list) {
    final segs = song.relDir.split('/').where((x) => x.isNotEmpty).toList();
    for (var i = 1; i <= segs.length; i++) {
      folders.add(segs.sublist(0, i).join('/'));
    }
  }
  return (songs: list.length, subfolders: folders.length);
}

/// One song of a folder as "By your layout" files it (the webapp's
/// folderSongTags, from the peer's metadata batch): its ARTIST tag as
/// written, its year, its one genre (the library splits a "Hip-Hop/Rap" tag
/// in two while a copy files under it as written: more than one, or none, is
/// unknown), the folder its file sits in on the server, its album, and the
/// album's credit (`album-artist`: none from a peer before 2026-10-23, and
/// for a song in no album).
class FolderSongTags {
  final String? artist;
  final int? year;
  final String? genre;
  final String serverFolder;
  final String? album;
  final String? albumArtist;
  const FolderSongTags({
    this.artist,
    this.year,
    this.genre,
    this.serverFolder = '',
    this.album,
    this.albumArtist,
  });
}

String? _text(String? s) => s != null && s.isNotEmpty ? s : null;

/// [filepath]'s song (its path on the connected server) as "By your layout"
/// files it, from its metadata — [artist] / [artistDisplay] / [year] /
/// [genres] / [album] / [albumArtist], as MusicMetadata holds them (none: a
/// path the peer has no row for).
FolderSongTags folderSongTags(
  String filepath, {
  String? artist,
  String? artistDisplay,
  int? year,
  List<String> genres = const [],
  String? album,
  String? albumArtist,
}) {
  final named = genres.where((g) => g.trim().isNotEmpty).toList();
  return FolderSongTags(
    artist: _text(artistDisplay) ?? _text(artist),
    year: year == null || year == 0 ? null : year,
    genre: named.length == 1 ? named.first : null,
    serverFolder: serverFolderOf(filepath),
    album: _text(album),
    albumArtist: _text(albumArtist),
  );
}

/// How a folder copy lands (its `landing`, destination.js validateLanding):
/// as on the connected server (none), into a folder the user picked
/// (`{vpath?, path}`: the pressed folder's files there, its subfolders
/// beneath), or song by song by the layout like any other copy
/// (`{tags: true}`).
enum FolderLanding { mirror, folder, tags }

/// The mode a landing on the wire (a job's `params.landing`, a start's)
/// reads as.
FolderLanding landingMode(Object? landing) {
  if (landing is! Map) return FolderLanding.mirror;
  if (landing['tags'] == true) return FolderLanding.tags;
  final vpath = landing['vpath'];
  if (landing['path'] is String || (vpath is String && vpath.isNotEmpty)) {
    return FolderLanding.folder;
  }
  return FolderLanding.mirror;
}

/// The landing a start sends for [mode]: null for a mirror (sent as none),
/// `{vpath, path}` for a folder ([vpath] null = the destination's library;
/// [path] '' its root), `{tags: true}`.
Map<String, dynamic>? folderLanding(FolderLanding mode,
        {String? vpath, String? path}) =>
    switch (mode) {
      FolderLanding.mirror => null,
      FolderLanding.tags => const {'tags': true},
      FolderLanding.folder => {'vpath': vpath, 'path': path ?? ''},
    };

/// [landing] as a start's body carries it (the webapp's discoveryJobStart):
/// `{tags: true}`, `{vpath, path}` or `{path}` (no library of its own: the
/// destination's), or nothing for a mirror. The route takes no null library.
Map<String, dynamic>? wireLanding(Object? landing) {
  switch (landingMode(landing)) {
    case FolderLanding.mirror:
      return null;
    case FolderLanding.tags:
      return const {'tags': true};
    case FolderLanding.folder:
      final l = landing as Map;
      final vpath = l['vpath'];
      final path = l['path'] is String ? l['path'] as String : '';
      return vpath is String && vpath.isNotEmpty
          ? {'vpath': vpath, 'path': path}
          : {'path': path};
  }
}

/// "Into a folder…"'s first place: a new folder in [destination]'s library
/// named as the pressed [folder], its name made safe as a mirror writes it
/// ("copies › Borrowed Tapes"), so the folder keeps its name unless the user
/// goes elsewhere. A brace is kept (the sheet says why it cannot be used).
({String? vpath, String path}) folderIntoDefault(
        CollectionDestination? destination, Object? folder) =>
    (
      vpath: destination?.vpath,
      path: sanitizeSegment(normalizePeerPath(folder).split('/').last),
    );

/// The most file lines a folder's preview draws.
const int kFolderFileLines = 3;

/// At most [kFolderFileLines] of a folder's songs as where each lands below
/// the path drawn ([lines]) and how many more there are ([more]).
class FolderFiles {
  final List<String> lines;
  final int more;
  const FolderFiles(this.lines, this.more);

  @override
  bool operator ==(Object other) =>
      other is FolderFiles &&
      other.more == more &&
      other.lines.length == lines.length &&
      [for (var i = 0; i < lines.length; i++) other.lines[i] == lines[i]]
          .every((x) => x);

  @override
  int get hashCode => Object.hash(Object.hashAll(lines), more);

  @override
  String toString() => 'FolderFiles($lines, more: $more)';
}

/// [songs] ([planFolder]'s, in path order) as [FolderFiles]: each line its
/// folder relative to the pressed one first ("Harbour Lights/01 - Tide.mp3")
/// — or, [flat] ("By your layout", where every song files by the layout),
/// its file name alone — written as the copy writes it ([safeFileName]).
/// Null without songs (not counted yet).
FolderFiles? folderFiles(List<FolderSong>? songs, {bool flat = false}) {
  if (songs == null) return null;
  final lines = [
    for (final x in songs.take(kFolderFileLines))
      flat
          ? safeFileName(x.filepath)
          : [x.relDir, safeFileName(x.filepath)]
              .where((p) => p.isNotEmpty)
              .join('/'),
  ];
  return FolderFiles(List.unmodifiable(lines), songs.length - lines.length);
}

PreviewTarget _refused(String? error, String field, String library) =>
    PreviewTarget(
      valid: false,
      error: error,
      field: field,
      library: library,
      base: '',
      rendered: '',
      file: '',
      relPath: '',
    );

/// Where a folder copy lands (federation-copy landingFor), by its
/// [landing]:
///   mirror  the destination's library, its base folder, the layout's
///           leading folders that name no variable ([layoutLead]: "From
///           friends/{{ALBUMARTIST}}/{{ALBUM}}" → "From friends"), then the
///           folder's path inside the peer's library, the library's own name
///           dropped ([insidePeerLibrary]) — never through the rest of the
///           layout
///   folder  the chosen library (`landing.vpath`, else the destination's)
///           and folder (`landing.path`, under the base folder's rules; ''
///           its root): the pressed folder's files go straight in, its
///           subfolders beneath — [ScopeTarget.straightIn] says so when that
///           folder is not named as the pressed one
///   tags    the layout, by the songs' own tags ([tags], ≤ 100 of them read
///           once): {{ARTIST}}, {{YEAR}}, {{GENRE}} (known for every song)
///           and {{SERVERFOLDER}} the value every song agrees on, else its
///           slot; {{ALBUM}} the album every song agrees on, else the first
///           folder that names an album ({{ALBUM}}, {{YEAR}} or
///           {{SERVERFOLDER}}) and every one after it are "one folder per
///           album" ([ScopeTarget.perAlbum]); {{ALBUMARTIST}} the songs'
///           album credit when every one names it and they agree, as
///           {{ARTIST}} when none names one (a peer before 2026-10-23: the
///           engine's own fallback), else its own ‹album artist› slot, as the
///           webapp's — the copy files each song under its own album's
///           credit, the rest under their artist. No tags
///           (past 100 songs, or no answer): every one a slot, and one folder
///           per album
/// A place the copy would refuse is refused here ([PreviewTarget.field]
/// `base`, `landing` or `layout`). The file list ([ScopeTarget.files]) only
/// where the path is one exact folder.
ScopeTarget folderTarget({
  String? vpath,
  Object? base,
  Object? layout,
  Object? landing,
  String? folder,
  List<FolderSong>? songs,
  List<FolderSongTags>? tags,
  String? peerName,
}) {
  final mode = landingMode(landing);
  if (mode == FolderLanding.tags) {
    return _taggedFolder(
      vpath: vpath,
      base: base,
      layout: layout,
      songs: songs,
      tags: tags,
      peerName: peerName,
    );
  }
  var library = vpath ?? '';
  var baseOut = '';
  final String fixed;
  var peerPath = '';
  ({String folder, String name})? straightIn;
  if (mode == FolderLanding.folder) {
    final l = landing as Map;
    final lv = l['vpath'];
    if (lv is String && lv.isNotEmpty) library = lv;
    final chosen = normalizeBase(l['path']);
    if (!chosen.valid) {
      return ScopeTarget(_refused(chosen.error, 'landing', library), '',
          landing: mode);
    }
    fixed = normalizePeerPath(chosen.base);
    final name = normalizePeerPath(folder).split('/').last;
    final into = fixed.split('/').last;
    if (sanitizeSegment(into).toLowerCase() !=
        sanitizeSegment(name).toLowerCase()) {
      straightIn = (folder: into.isNotEmpty ? into : library, name: name);
    }
  } else {
    final b = normalizeBase(base);
    if (!b.valid) {
      return ScopeTarget(_refused(b.error, 'base', library), '', landing: mode);
    }
    baseOut = b.base;
    fixed = [b.base, layoutLead(layout).folders]
        .where((x) => x.isNotEmpty)
        .join('/');
    peerPath = insidePeerLibrary(folder);
  }
  final dir = [fixed, peerPath].where((x) => x.isNotEmpty).join('/');
  if (dir.isNotEmpty) {
    final check = validateResolvedPath(dir);
    if (!check.valid) {
      return ScopeTarget(_refused(check.error, 'landing', library), '',
          landing: mode);
    }
  }
  final rendered = baseOut.isEmpty
      ? dir
      : (dir.length > baseOut.length ? dir.substring(baseOut.length + 1) : '');
  return ScopeTarget(
    PreviewTarget(
      valid: true,
      library: library,
      base: baseOut,
      rendered: rendered,
      file: '',
      relDir: dir,
      relPath: dir,
    ),
    rendered,
    landing: mode,
    files: folderFiles(songs),
    straightIn: straightIn,
  );
}

ScopeTarget _taggedFolder({
  String? vpath,
  Object? base,
  Object? layout,
  List<FolderSong>? songs,
  List<FolderSongTags>? tags,
  String? peerName,
}) {
  final listed = tags != null && tags.isNotEmpty ? tags : null;
  // The value every song agrees on, else [slot]'s mark (none read: the
  // mark).
  Object? agree(
    Iterable<Object?> Function(List<FolderSongTags>) values,
    LayoutSlot slot, {
    String Function(Object?) folders = sanitizeSegment,
  }) =>
      listed == null
          ? slotMark(slot)
          : _agreed(values(listed), slot, folders: folders);
  bool known(Iterable<Object?> values) =>
      values.every((v) => sanitizeSegment(v).isNotEmpty);

  // {{ALBUM}}: the one album every song is on, else none here — one folder
  // per album below the cut.
  final shared = listed == null ? null : _shared(listed.map((x) => x.album));
  final byAlbum = shared == null;
  final artist = agree((l) => l.map((x) => x.artist), LayoutSlot.artist);
  final genre = listed != null && known(listed.map((x) => x.genre))
      ? _agreed(listed.map((x) => x.genre), LayoutSlot.genre)
      : slotMark(LayoutSlot.genre);
  // The songs' album credit: every one names it and they agree → it; none
  // names one (or none was read) → none, the engine files under ARTIST;
  // else — credits that disagree, or only some named — its own slot (the
  // webapp's ‹ALBUMARTIST›): the copy files each song under its own album's
  // credit, the rest under their artist.
  Object? albumArtist;
  if (listed != null) {
    final named =
        listed.where((x) => sanitizeSegment(x.albumArtist).isNotEmpty).length;
    if (named == listed.length) {
      albumArtist =
          _agreed(listed.map((x) => x.albumArtist), LayoutSlot.albumArtist);
    } else if (named > 0) {
      albumArtist = slotMark(LayoutSlot.albumArtist);
    }
  }
  final v = <String, Object?>{
    'artist': artist,
    'album': shared?.value,
    'year': agree((l) => l.map((x) => x.year), LayoutSlot.year),
    'genre': genre,
    'albumartist': albumArtist,
  };
  final onServer = agree((l) => l.map((x) => x.serverFolder),
      LayoutSlot.serverFolder,
      folders: sanitizeFolders);
  final target = previewTarget(
    vpath: vpath,
    base: base,
    layout: layout,
    tags: v,
    peerName: peerName,
    serverFolder: onServer,
  );
  if (!target.valid) {
    return ScopeTarget(target, target.rendered, landing: FolderLanding.tags);
  }
  if (byAlbum) {
    final folders = (layout as String).split(RegExp(r'[/\\]+'));
    final at = folders.indexWhere(_albumFolderRe.hasMatch);
    if (at != -1) {
      final head = resolveLayout(folders.sublist(0, at).join('/'), {
        'artist': artist,
        'genre': genre,
        'albumartist': albumArtist,
        'peer': peerName,
      });
      return ScopeTarget(target, head.path,
          perAlbum: true, landing: FolderLanding.tags);
    }
  }
  final out = ScopeTarget(target, target.rendered, landing: FolderLanding.tags);
  return out.slots.isEmpty
      ? ScopeTarget(target, target.rendered,
          landing: FolderLanding.tags, files: folderFiles(songs, flat: true))
      : out;
}

// ── a job as a row ───────────────────────────────────────────────────────

bool isLive(DiscoveryJob? job) => job?.live == true;

String fmtBytes(num? n) {
  if (n == null || !n.isFinite || n <= 0) return '';
  final b = n.toDouble();
  if (b < 1024) return '${b.round()} B';
  if (b < 1024 * 1024) return '${(b / 1024).round()} KB';
  final mb = b / (1024 * 1024);
  if (mb < 1024) return '${mb < 10 ? mb.toStringAsFixed(1) : mb.round()} MB';
  return '${(mb / 1024).toStringAsFixed(1)} GB';
}

/// What a row is, after its job's state and the shape of its result.
enum JobRowKind {
  idle,
  queued,
  running,
  failed,
  cancelled,

  /// A many-song job that ended early: the peer's transfer limit, busy, the
  /// peer going away, or the peer refusing copies.
  stopped,

  /// A many-song job that copied something and was not stopped.
  copiedMany,

  /// A song copy that landed.
  copied,

  /// Nothing copied, the library already had it.
  owned,

  /// A song copy skipped: a file is already at the path.
  exists,

  /// A many-song job with nothing to copy at all.
  nothing,

  /// A download plug-in's landed file.
  downloaded,

  /// Done, with a result this client cannot read.
  done,
}

/// The words a row carries, by meaning (the webapp's `discover.job.*` keys,
/// one for one). The UI maps each to its localized string.
enum JobPhrase {
  queued,
  queuedSub,
  stopping,
  copying,
  downloading,
  starting,
  failed,
  failedSub,
  cancelled,
  cancelledMany,
  cancelledSub,
  cancelledCopySub,
  stopped,
  stoppedQuota,
  stoppedBusy,
  stoppedPeer,
  stoppedRefused,
  inCollection,
  owned,
  ownedSub,
  skipped,
  existsSub,
  nothing,
  nothingToCopy,
  onlyAppearances,
  done,
  savedTo,
  albumsCount,
  copiedCount,
  ownedCount,
  failedCount,
  albumsFailed,
  albumsLeftOut,
}

/// One part of a row's line: a phrase with its numbers, or the server's own
/// words ([server]), verbatim.
class JobText {
  final JobPhrase? phrase;
  final String? server;
  final int? count;
  final String? peer;
  final String? path;

  const JobText(JobPhrase this.phrase, {this.count, this.peer, this.path})
      : server = null;
  const JobText.server(String this.server)
      : phrase = null,
        count = null,
        peer = null,
        path = null;

  @override
  bool operator ==(Object other) =>
      other is JobText &&
      other.phrase == phrase &&
      other.server == server &&
      other.count == count &&
      other.peer == peer &&
      other.path == path;

  @override
  int get hashCode => Object.hash(phrase, server, count, peer, path);

  @override
  String toString() => server != null
      ? 'JobText.server($server)'
      : 'JobText($phrase${count != null ? ', count: $count' : ''}'
          '${peer != null ? ', peer: $peer' : ''}'
          '${path != null ? ', path: $path' : ''})';
}

/// The buttons a row offers (the window maps each to one).
enum JobAction { start, cancel, retry, play, queue }

enum JobIcon { folder, download, clock, warn, close, check }

/// A row's colour role: `src` (live), `err`, `ok`, or plain.
enum JobTone { plain, live, error, ok }

/// What one plug-in's row shows for the job the caller last ran with it.
class JobRow {
  final JobRowKind kind;
  final JobPhrase? tag;
  final JobTone tagTone;
  final JobIcon icon;
  final JobTone iconTone;
  final bool muted;

  /// Whole percent while running; null otherwise ([indeterminate] while
  /// running without a number).
  final int? progress;
  final bool indeterminate;

  /// The second line, part by part (the UI joins them with " · "); null for
  /// none.
  final List<JobText>? sub;
  final List<JobAction> actions;

  /// The library file a finished song lands as (Play / Add to queue).
  final String? filepath;
  final bool live;

  /// A folder copy's own account (its result's `folder.landed`): where its
  /// files went, '/'-joined from the library ("copies/Boukmanflow/Borrowed
  /// Tapes") — the "In copies › …" line. Null for every other copy, and
  /// for a folder filed by the layout (each song went its own way).
  final String? landed;

  /// The files a folder copy left out (its result's `skippedFiles`: not
  /// music this server plays, or hidden) — "2 files left out: …"; 0 for
  /// every other copy.
  final int skippedFiles;

  const JobRow({
    this.kind = JobRowKind.idle,
    this.tag,
    this.tagTone = JobTone.plain,
    this.icon = JobIcon.download,
    this.iconTone = JobTone.plain,
    this.muted = false,
    this.progress,
    this.indeterminate = false,
    this.sub,
    this.actions = const [JobAction.start],
    this.filepath,
    this.live = false,
    this.landed,
    this.skippedFiles = 0,
  });

  JobRow _with({
    JobRowKind? kind,
    JobPhrase? tag,
    JobTone? tagTone,
    JobIcon? icon,
    JobTone? iconTone,
    bool? muted,
    int? progress,
    bool? indeterminate,
    List<JobText>? sub,
    List<JobAction>? actions,
    String? filepath,
  }) =>
      JobRow(
        kind: kind ?? this.kind,
        tag: tag ?? this.tag,
        tagTone: tagTone ?? this.tagTone,
        icon: icon ?? this.icon,
        iconTone: iconTone ?? this.iconTone,
        muted: muted ?? this.muted,
        progress: progress ?? this.progress,
        indeterminate: indeterminate ?? this.indeterminate,
        sub: sub ?? this.sub,
        actions: actions ?? this.actions,
        filepath: filepath ?? this.filepath,
        live: live,
        landed: landed,
        skippedFiles: skippedFiles,
      );

  /// The first part's phrase (what a marker reads the reason from).
  JobPhrase? get leadPhrase =>
      sub == null || sub!.isEmpty ? null : sub!.first.phrase;
}

/// What one plug-in's row shows for [job] (null = never asked). [plugin]
/// names the row's plug-in when there is no job.
JobRow jobRowState(DiscoveryJob? job, {String? plugin}) {
  final copy = (plugin ?? job?.plugin) == kCopyPlugin;
  final idle = JobRow(
    icon: copy ? JobIcon.folder : JobIcon.download,
    live: job != null && isLive(job),
    landed: job?.view.folderLanded,
    skippedFiles: job?.view.skippedFiles ?? 0,
  );
  if (job == null) return idle;
  final row = idle;

  if (job.state == JobState.queued) {
    return row._with(
      kind: JobRowKind.queued,
      tag: JobPhrase.queued,
      icon: JobIcon.clock,
      sub: const [JobText(JobPhrase.queuedSub)],
      actions: const [JobAction.cancel],
    );
  }
  if (job.state == JobState.running) {
    final stopping = job.cancelRequested;
    final p = job.progress;
    final pct = p == null ? null : (p * 100).round();
    final text = job.statusText ?? '';
    final List<JobText> sub;
    if (text.isNotEmpty) {
      // A status line that already carries a percentage says enough.
      sub = [
        JobText.server(
            pct == null || text.contains('%') ? text : '$text · $pct%')
      ];
    } else {
      sub = pct == null
          ? const [JobText(JobPhrase.starting)]
          : [JobText.server('$pct%')];
    }
    return JobRow(
      kind: JobRowKind.running,
      tag: stopping
          ? JobPhrase.stopping
          : (copy ? JobPhrase.copying : JobPhrase.downloading),
      tagTone: JobTone.live,
      icon: row.icon,
      iconTone: JobTone.live,
      progress: pct,
      indeterminate: pct == null,
      sub: sub,
      actions: stopping ? const [] : const [JobAction.cancel],
      live: true,
      landed: row.landed,
      skippedFiles: row.skippedFiles,
    );
  }
  if (job.state == JobState.failed) {
    return row._with(
      kind: JobRowKind.failed,
      tag: JobPhrase.failed,
      tagTone: JobTone.error,
      icon: JobIcon.warn,
      iconTone: JobTone.error,
      sub: job.error != null
          ? [JobText.server(job.error!)]
          : const [JobText(JobPhrase.failedSub)],
      actions: const [JobAction.retry],
    );
  }
  // An album's or an artist's copy: every song accounted for.
  final res = job.result;
  final many = job.view.isMany ? res : null;
  if (job.state == JobState.cancelled) {
    if (many != null) {
      return row._with(
        kind: JobRowKind.cancelled,
        tag: JobPhrase.cancelled,
        icon: JobIcon.close,
        muted: true,
        sub: [const JobText(JobPhrase.cancelledMany), ...manyParts(many)],
        actions: const [JobAction.start],
      );
    }
    return row._with(
      kind: JobRowKind.cancelled,
      tag: JobPhrase.cancelled,
      icon: JobIcon.close,
      muted: true,
      sub: [
        JobText(copy ? JobPhrase.cancelledCopySub : JobPhrase.cancelledSub)
      ],
      actions: const [JobAction.start],
    );
  }
  if (job.state != JobState.done) return row;

  // A many-song job ends 'done' however it went — "done" is not "kept".
  // What it says comes from result.stopped and result.counts:
  //   stopped (quota · busy · peer · refused)  stopped, with the reason
  //   copied > 0                               in your collection
  //   nothing copied, something failed         failed (Retry)
  //   nothing copied, all already here         already yours
  //   nothing at all                           nothing to copy (an artist
  //                                            who only appears on the
  //                                            peer's albums says so)
  if (many != null) {
    final view = JobResultView(many);
    final peer = view.peerName ?? '';
    final n = manyCounts(many);
    final why = _stoppedWhy[view.stopped];
    // The peer's transfer limit or the peer going away ended it: what landed
    // is in, and starting again takes only the gaps. A peer that refuses
    // copies refuses them again — no Retry.
    if (why != null) {
      return row._with(
        kind: JobRowKind.stopped,
        tag: JobPhrase.stopped,
        tagTone: JobTone.error,
        icon: JobIcon.warn,
        iconTone: JobTone.error,
        sub: [JobText(why, peer: peer), ...manyParts(many)],
        actions: view.stopped == 'refused' ? const [] : const [JobAction.retry],
      );
    }
    // Startable again: the copy is idempotent, so a second run takes only
    // what the library lacks by then.
    if (n.copied > 0) {
      return row._with(
        kind: JobRowKind.copiedMany,
        tag: JobPhrase.inCollection,
        tagTone: JobTone.ok,
        icon: JobIcon.check,
        iconTone: JobTone.ok,
        sub: manyParts(many),
        actions: const [JobAction.start],
      );
    }
    if (n.failed > 0 || n.albumsFailed > 0) {
      return row._with(
        kind: JobRowKind.failed,
        tag: JobPhrase.failed,
        tagTone: JobTone.error,
        icon: JobIcon.warn,
        iconTone: JobTone.error,
        sub: manyParts(many),
        actions: const [JobAction.retry],
      );
    }
    if (n.skipped > 0 || n.albumsOwned > 0) {
      return row._with(
        kind: JobRowKind.owned,
        tag: JobPhrase.owned,
        tagTone: JobTone.ok,
        icon: JobIcon.check,
        iconTone: JobTone.ok,
        sub: manyParts(many),
        actions: const [JobAction.start],
      );
    }
    final parts = n.albumsAppearance > 0
        ? [JobText(JobPhrase.onlyAppearances, count: n.albumsAppearance)]
        : [const JobText(JobPhrase.nothingToCopy), ...manyParts(many)];
    return row._with(
      kind: JobRowKind.nothing,
      tag: JobPhrase.nothing,
      icon: JobIcon.folder,
      muted: true,
      sub: parts,
      actions: const [JobAction.start],
    );
  }

  final view = job.view;
  // A song the peer refuses to copy (mStream since 2026-10-21 ends its job
  // done with `stopped: 'refused'` and nothing copied): it would be refused
  // again, so no Retry.
  if (view.stopped == 'refused') {
    return row._with(
      kind: JobRowKind.stopped,
      tag: JobPhrase.stopped,
      tagTone: JobTone.error,
      icon: JobIcon.warn,
      iconTone: JobTone.error,
      sub: [JobText(JobPhrase.stoppedRefused, peer: view.peerName ?? '')],
      actions: const [],
    );
  }
  // A download that landed in the collection.
  final at = view.downloadedFilepath;
  if (at != null) {
    return row._with(
      kind: JobRowKind.downloaded,
      tag: JobPhrase.done,
      tagTone: JobTone.ok,
      icon: JobIcon.check,
      iconTone: JobTone.ok,
      sub: [JobText(JobPhrase.savedTo, path: pathCrumbs(at).join(' / '))],
      actions: const [JobAction.play, JobAction.queue],
      filepath: at,
    );
  }
  final copied = view.copiedFilepath;
  if (copied != null) {
    return row._with(
      kind: JobRowKind.copied,
      tag: JobPhrase.inCollection,
      tagTone: JobTone.ok,
      icon: JobIcon.check,
      iconTone: JobTone.ok,
      sub: [JobText.server(pathCrumbs(copied).join(' / '))],
      actions: const [JobAction.play, JobAction.queue],
      filepath: copied,
    );
  }
  if (view.skipped == 'owned') {
    final existing = view.existingFilepath;
    return row._with(
      kind: JobRowKind.owned,
      tag: JobPhrase.owned,
      tagTone: JobTone.ok,
      icon: JobIcon.check,
      iconTone: JobTone.ok,
      sub: existing != null
          ? [JobText.server(pathCrumbs(existing).join(' / '))]
          : const [JobText(JobPhrase.ownedSub)],
      actions:
          existing != null ? const [JobAction.play, JobAction.queue] : const [],
      filepath: existing,
    );
  }
  if (view.skipped == 'exists') {
    return row._with(
      kind: JobRowKind.exists,
      tag: JobPhrase.skipped,
      icon: JobIcon.warn,
      sub: [
        JobText(JobPhrase.existsSub,
            path: pathCrumbs(view.filepath).join(' / '))
      ],
      actions: const [JobAction.retry],
    );
  }
  return row._with(
    kind: JobRowKind.done,
    tag: JobPhrase.done,
    tagTone: JobTone.ok,
    icon: JobIcon.check,
    iconTone: JobTone.ok,
    actions: const [],
  );
}

/// Why a many-song job stopped early, as its line's first part.
const Map<String?, JobPhrase> _stoppedWhy = {
  'quota': JobPhrase.stoppedQuota,
  'busy': JobPhrase.stoppedBusy,
  'peer': JobPhrase.stoppedPeer,
  'refused': JobPhrase.stoppedRefused,
};

/// A many-song result's numbers. Songs from `result.counts` — the whole
/// numbers: the per-song lists stop at 500 entries — else the lists (an
/// older server sends no counts). Albums from an artist job's walk: copied
/// from (no error), whose listing failed, and left out — already here
/// ('owned', artist-missing) or only a guest spot ('appearance').
class ManyCounts {
  final int copied;
  final int skipped;
  final int failed;
  final int albums;
  final int albumsFailed;
  final int albumsLeftOut;
  final int albumsOwned;
  final int albumsAppearance;
  const ManyCounts({
    this.copied = 0,
    this.skipped = 0,
    this.failed = 0,
    this.albums = 0,
    this.albumsFailed = 0,
    this.albumsLeftOut = 0,
    this.albumsOwned = 0,
    this.albumsAppearance = 0,
  });
}

ManyCounts manyCounts(Map<String, dynamic> many) {
  final s = many['songs'] is Map ? many['songs'] as Map : const {};
  final c = many['counts'] is Map ? many['counts'] as Map : null;
  // JS Number(): a present null counts 0, a numeric string its number,
  // anything else (absent, NaN, negative) falls back to the list.
  int count(String k) {
    if (c != null && c.containsKey(k)) {
      final raw = c[k];
      final v = raw == null
          ? 0
          : (raw is num ? raw : (raw is String ? num.tryParse(raw.trim()) : null));
      if (v != null && v.isFinite && v >= 0) return v.toInt();
    }
    final list = s[k];
    return list is List ? list.length : 0;
  }

  final albums = (many['albums'] is List ? many['albums'] as List : const [])
      .whereType<Map>()
      .toList();
  final left =
      (many['skippedAlbums'] is List ? many['skippedAlbums'] as List : const [])
          .whereType<Map>()
          .toList();
  bool hasError(Map a) => _truthy(a['error']);
  return ManyCounts(
    copied: count('copied'),
    skipped: count('skipped'),
    failed: count('failed'),
    albums: albums.where((a) => !hasError(a)).length,
    albumsFailed: albums.where(hasError).length,
    albumsLeftOut: left.length,
    albumsOwned: left.where((a) => a['why'] == 'owned').length,
    albumsAppearance: left.where((a) => a['why'] == 'appearance').length,
  );
}

/// The counts of a many-song result as the parts of a line (the caller
/// translates each and joins them): the albums an artist job walked, songs
/// copied, already yours, failed, albums whose listing failed, albums left
/// out — zeroes left out (empty when nothing happened at all: the caller
/// says why).
List<JobText> manyParts(Map<String, dynamic> many) {
  final n = manyCounts(many);
  final parts = <JobText>[];
  void add(JobPhrase p, int count) {
    if (count != 0) parts.add(JobText(p, count: count));
  }

  add(JobPhrase.albumsCount, n.albums);
  add(JobPhrase.copiedCount, n.copied);
  add(JobPhrase.ownedCount, n.skipped);
  add(JobPhrase.failedCount, n.failed);
  add(JobPhrase.albumsFailed, n.albumsFailed);
  add(JobPhrase.albumsLeftOut, n.albumsLeftOut);
  return parts;
}

// ── scopes ───────────────────────────────────────────────────────────────
// What a job acts on (the server's JOB_SCOPES): the song, its album, its
// artist's albums, or only the ones the library lacks. A row keeps one job
// per plug-in AND scope, under a slot: the plug-in's name for a song job,
// "<plugin>@<scope>" for the others.

const List<String> kJobScopes = kDiscoverJobScopes;

String jobScope(DiscoveryJob? job) => job?.scope ?? kScopeSong;

String jobSlot(String plugin, [String? scope]) =>
    scope == null || scope.isEmpty || scope == kScopeSong
        ? plugin
        : '$plugin@$scope';

/// A lookup answer (the newest job per plug-in and scope) by slot — the
/// first seen per slot, in the server's order.
Map<String, DiscoveryJob> jobsBySlot(Iterable<DiscoveryJob>? jobs) {
  final out = <String, DiscoveryJob>{};
  for (final job in jobs ?? const <DiscoveryJob>[]) {
    out.putIfAbsent(jobSlot(job.plugin, jobScope(job)), () => job);
  }
  return out;
}

/// What a job acts on beyond a song, for the Copies list's kind label.
enum JobKind { album, artist, artistMissing, folder }

JobKind? jobKind(DiscoveryJob? job) => switch (jobScope(job)) {
      kScopeAlbum => JobKind.album,
      kScopeArtist => JobKind.artist,
      kScopeArtistMissing => JobKind.artistMissing,
      kScopeFolder => JobKind.folder,
      _ => null,
    };

/// A lookup answer indexed by plug-in name, for one scope (song rows by
/// default).
Map<String, DiscoveryJob> jobsByPlugin(Iterable<DiscoveryJob>? jobs,
    [String scope = kScopeSong]) {
  final out = <String, DiscoveryJob>{};
  for (final job in jobs ?? const <DiscoveryJob>[]) {
    if (out.containsKey(job.plugin)) continue;
    if (jobScope(job) == scope) out[job.plugin] = job;
  }
  return out;
}

// ── the Copies list (the webapp's downloads strip) ───────────────────────
// It holds what still wants the user: live jobs and failures. A finished
// copy is settled — it is a library song — and a cancelled job is over;
// both leave the list by themselves ("Clear finished" drops their rows on
// the server).
//
// The phone also keeps a FINISHED copy whose outcome is a failure or a
// stop (done with copied 0 and failed > 0, or stopped quota / busy / peer /
// refused): it wants Retry or Clear finished as much as a failed job does,
// and the Copies strip counts it ("1 failed" = the failed or stopped ones
// left). The webapp's trayRows keeps only state 'failed'.

/// A copy the phone carries — its Copies list, its markers, its Retry: Keep
/// a copy's own plug-in, with a scope Discover offers, started as Discover
/// starts it (no landing, no choice). `GET /plugin-jobs` answers every
/// plug-in's jobs; the others — a YouTube download, the webapp's folder copy
/// with the landing chosen there — stay the webapp's: the phone could not
/// draw them right, and its Retry (`{recommendation, scope}` to
/// federation-copy) would not start them again as they were started.
bool isDiscoverCopy(DiscoveryJob? job) {
  if (job == null || job.plugin != kCopyPlugin) return false;
  if (!kDiscoverJobScopes.contains(jobScope(job))) return false;
  final p = job.params;
  return p == null || (p['landing'] == null && p['choice'] == null);
}

/// A copy the phone carries now that it keeps a copy while browsing a
/// connected server too ([isDiscoverCopy]'s, plus a folder copy with
/// whatever landing it was started with): its Copies list, the strip's and
/// the home card's counts, the polls, the end toasts, and Retry / Add again
/// (which send the job's own landing back). Discover's own row and card
/// markers still read [isDiscoverCopy] — Discover never offers a folder.
/// A landing on any other scope, or a lookup plug-in's `choice`, is not the
/// phone's to start again.
bool isKeepCopy(DiscoveryJob? job) {
  if (job == null || job.plugin != kCopyPlugin) return false;
  final scope = jobScope(job);
  if (!kKeepJobScopes.contains(scope)) return false;
  final p = job.params;
  if (p == null) return true;
  if (p['choice'] != null) return false;
  return p['landing'] == null || scope == kScopeFolder;
}

int _trayRank(DiscoveryJob job) => job.state == JobState.running
    ? 0
    : (job.state == JobState.queued ? 1 : 2);

/// A job that ended badly: failed, or done but failed or stopped.
bool wantsAttention(DiscoveryJob? job) {
  if (job == null) return false;
  if (job.state == JobState.failed) return true;
  if (job.state != JobState.done || !job.view.isMany) return false;
  final kind = jobRowState(job).kind;
  return kind == JobRowKind.failed || kind == JobRowKind.stopped;
}

bool inTray(DiscoveryJob? job) => isLive(job) || wantsAttention(job);

List<DiscoveryJob> trayRows(Iterable<DiscoveryJob>? jobs) {
  final list = (jobs ?? const <DiscoveryJob>[]).toList();
  // A failure the user already retried is old news: a newer job for the same
  // plug-in and recommendation (whatever became of it) supersedes it.
  final newest = <String, int>{};
  for (final job in list) {
    final k = '${job.plugin}|${job.key}';
    final have = newest[k];
    if (have == null || job.id > have) newest[k] = job.id;
  }
  bool superseded(DiscoveryJob job) =>
      wantsAttention(job) &&
      job.key != null &&
      (newest['${job.plugin}|${job.key}'] ?? -1) > job.id;
  final rows = list.where((j) => inTray(j) && !superseded(j)).toList();
  // A stable sort: by rank, then newest first.
  final indexed = [for (var i = 0; i < rows.length; i++) (rows[i], i)];
  indexed.sort((a, b) {
    final byRank = _trayRank(a.$1) - _trayRank(b.$1);
    if (byRank != 0) return byRank;
    final byTime = (b.$1.createdAt ?? 0) - (a.$1.createdAt ?? 0);
    if (byTime != 0) return byTime;
    final byId = b.$1.id - a.$1.id;
    if (byId != 0) return byId;
    return a.$2 - b.$2;
  });
  return [for (final x in indexed) x.$1];
}

/// "Copying 2 · 1 failed": the copies running or waiting, and the failed or
/// stopped ones left. [live] tells the poller whether to keep its short
/// interval; [clearable] whether "Clear finished" has anything to drop.
class TraySummary {
  final int total;
  final int running;
  final int failed;
  const TraySummary({this.total = 0, this.running = 0, this.failed = 0});

  bool get live => running > 0;
  bool get clearable => failed > 0;

  /// The strip shows only while something is live or failed.
  bool get shown => total > 0;
}

TraySummary traySummary(Iterable<DiscoveryJob>? jobs) {
  final rows = trayRows(jobs);
  var running = 0;
  var failed = 0;
  for (final job in rows) {
    if (isLive(job)) {
      running += 1;
    } else {
      failed += 1;
    }
  }
  return TraySummary(total: rows.length, running: running, failed: failed);
}

/// A job's one-line title: "Title — Artist" for a song, "Album — Artist"
/// for an album (a compilation's album artist when the row names one —
/// the phone's departure: the webapp names the track artist), the artist's
/// name for the artist scopes.
String jobTitle(DiscoveryJob? job) {
  final rec = job?.recommendation ?? const <String, dynamic>{};
  String? s(String k) => _truthy(rec[k]) ? '${rec[k]}' : null;
  final scope = jobScope(job);
  if (scope == kScopeAlbum) {
    return [s('album'), s('albumArtist') ?? s('artist')].whereType<String>().join(' — ');
  }
  if (scope == kScopeArtist || scope == kScopeArtistMissing) {
    return s('artist') ?? '';
  }
  if (scope == kScopeFolder) return folderTitle(rec);
  return [s('title'), s('artist')].whereType<String>().join(' — ');
}

/// A folder copy's name: its recommendation's title, else the last folder
/// of its path on the connected server.
String folderTitle(Map<String, dynamic> rec) {
  final t = rec['title'];
  if (t is String && t.trim().isNotEmpty) return t.trim();
  return normalizePeerPath(rec['filepath']).split('/').last;
}

/// What changed between two polls, for the toasts: only a job this client
/// SAW live and now sees finished is news (a page load is not).
List<DiscoveryJob> finishedSince(
    Iterable<DiscoveryJob>? before, Iterable<DiscoveryJob>? after) {
  final was = <int>{
    for (final job in before ?? const <DiscoveryJob>[])
      if (isLive(job)) job.id,
  };
  return [
    for (final job in after ?? const <DiscoveryJob>[])
      if (was.contains(job.id) && !isLive(job)) job,
  ];
}

/// A failed copy whose peer was re-paired since the row was drawn: asking
/// Discover again (New seeds) is the fix, not Retry — the stale row names a
/// peer id this server no longer holds.
bool jobNeedsNewSeeds(DiscoveryJob? job) =>
    job != null &&
    job.state == JobState.failed &&
    RegExp('no longer paired', caseSensitive: false).hasMatch(job.error ?? '');

/// The phone's poll beat (the webapp's: 1.5 s with a live job on an open
/// surface, 4 s otherwise; doubled per failure up to 60 s).
Duration pollDelay(Duration beat, int failures) {
  final ms = beat.inMilliseconds * math.pow(2, math.min(failures, 6));
  return Duration(milliseconds: math.min(60000, ms.round()));
}
