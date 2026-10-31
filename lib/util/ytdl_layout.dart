/// Where an Add from YouTube song lands: the folder layouts the screen and
/// the explorer sheet offer, the YouTube allow-list a typed layout must
/// pass, and the folder the request names (spec §4, §7).
///
/// The server's `/ytdl` takes a finished directory and renders nothing, so
/// the phone renders the layout itself with the Discover picker's copy of
/// the server's template engine ([previewTarget]): the folders the user
/// sees are the folders mkdir makes and the add names.
library;

import 'discover_jobs.dart';

const kYtdlVars = ['ARTIST', 'ALBUMARTIST', 'ALBUM', 'YEAR']; // chip order
const kYtdlNeverVars = ['GENRE', 'PEER', 'SERVERFOLDER']; // always empty for YouTube songs
const kYtdlLayoutArtistAlbum = '{{ALBUMARTIST}}/{{ALBUM}}';
const kYtdlLayoutArtist = '{{ALBUMARTIST}}';
const kYtdlLayoutAlbum = '{{ALBUM}}';

/// "Top of the library" / "Right here": no folders (never passed to
/// [previewTarget], which refuses an empty layout).
const kYtdlLayoutTop = '';

/// The engine's token pattern (discover_jobs.dart keeps its own private).
final RegExp _tokenRe = RegExp(r'\{\{\s*([A-Za-z_][A-Za-z0-9_]*)\s*\}\}');

/// Characters a folder name cannot hold on Windows. The engine folds them
/// out of tag values but keeps them in literal text, and the mkdir route
/// only normalises the path, so a Windows server would answer a bare 500.
final RegExp _badLiteral = RegExp(r'[:*?"<>|]');

enum YtdlLayoutIssue { none, unknownVariable, neverVariable, badChars, engine }

class YtdlLayoutCheck {
  final YtdlLayoutIssue issue;

  /// The token as typed, e.g. "{{TITLE}}" / "{{GENRE}}"; for [YtdlLayoutIssue.badChars]
  /// the first character refused.
  final String? token;

  /// validateLayout's result when issue == engine.
  final LayoutCheck? engine;

  const YtdlLayoutCheck._(this.issue, {this.token, this.engine});

  bool get valid => issue == YtdlLayoutIssue.none;

  @override
  String toString() => 'YtdlLayoutCheck(${issue.name}, $token)';
}

/// validateLayout (discover_jobs.dart) first (an unknown_variable there → unknownVariable with its token),
/// then the YouTube allow-list (GENRE/PEER/SERVERFOLDER → neverVariable), then literal : * ? " < > | in
/// the non-token text → badChars. '' is valid here (Top of the library) — callers special-case it.
YtdlLayoutCheck ytdlLayoutCheck(String layout) {
  if (layout.isEmpty) return const YtdlLayoutCheck._(YtdlLayoutIssue.none);
  final check = validateLayout(layout);
  if (!check.valid) {
    if (check.error == 'unknown_variable') {
      return YtdlLayoutCheck._(YtdlLayoutIssue.unknownVariable,
          token: check.token ?? '{{${check.variable}}}');
    }
    return YtdlLayoutCheck._(YtdlLayoutIssue.engine, engine: check);
  }
  for (final m in _tokenRe.allMatches(layout)) {
    if (kYtdlNeverVars.contains(m[1]!.toUpperCase())) {
      return YtdlLayoutCheck._(YtdlLayoutIssue.neverVariable, token: m[0]);
    }
  }
  final bad = _badLiteral.firstMatch(layout.replaceAll(_tokenRe, ''));
  if (bad != null) {
    return YtdlLayoutCheck._(YtdlLayoutIssue.badChars, token: bad[0]);
  }
  return const YtdlLayoutCheck._(YtdlLayoutIssue.none);
}

/// The song's tags as the layout reads them: ALBUMARTIST and ARTIST both
/// are [artist] (the card has one Artist field).
class YtdlTags {
  final String artist, album, year;
  const YtdlTags({this.artist = '', this.album = '', this.year = ''});

  /// previewTarget's tags; GENRE and the rest have no value for a YouTube
  /// song, so they land in missingVars.
  Map<String, Object?> get _meta => {
        'artist': artist,
        'album': album,
        'year': year,
        'albumartist': artist,
        'genre': null,
      };
}

enum YtdlTrapKind {
  /// The folder is nothing but brackets or separators: "()".
  emptyFolder,

  /// Only the year came out empty: "Discovery ()".
  missingYear,

  /// Another empty variable left an empty pair or a dangling separator:
  /// "Gorillaz -".
  other,
}

/// A folder an empty variable left as brackets or separators (spec §4's
/// bracket warning), as it will be named.
class YtdlTrap {
  final YtdlTrapKind kind;

  /// As rendered, e.g. "()" or "Discovery ()".
  final String folder;
  const YtdlTrap(this.kind, this.folder);

  @override
  bool operator ==(Object other) =>
      other is YtdlTrap && other.kind == kind && other.folder == folder;

  @override
  int get hashCode => Object.hash(kind, folder);

  @override
  String toString() => 'YtdlTrap(${kind.name}, $folder)';
}

class YtdlTarget {
  final bool valid;

  /// The vpath.
  final String library;

  /// Folders below the library (base + rendered), may be empty.
  final List<String> segments;

  /// segments.join('/').
  final String relDir;

  /// What POST /ytdl gets: `/<vpath>/<relDir>/` or `/<vpath>/` ('' when
  /// not [valid]).
  final String directory;

  /// From previewTarget, upper-case, excluding kYtdlNeverVars.
  final List<String> missingVars;

  /// kYtdlNeverVars tokens present in the layout.
  final List<String> neverVars;

  /// Bracket trap (spec §4): a segment made only of brackets/separators,
  /// or one ending in an empty bracket pair or a dangling separator.
  final YtdlTrap? trap;

  /// previewTarget/validate error code when !valid ('bad_chars' for a
  /// literal ytdlLayoutCheck refuses).
  final String? error;

  const YtdlTarget._invalid({
    required this.library,
    this.missingVars = const [],
    this.neverVars = const [],
    required this.error,
  })  : valid = false,
        segments = const [],
        relDir = '',
        directory = '',
        trap = null;

  YtdlTarget._at({
    required this.library,
    required this.segments,
    required this.directory,
    this.missingVars = const [],
    this.neverVars = const [],
    this.trap,
  })  : valid = true,
        relDir = segments.join('/'),
        error = null;

  List<String> get crumbs => [library, ...segments];

  @override
  String toString() =>
      'YtdlTarget(${valid ? directory : 'invalid: $error'}, missing $missingVars, never $neverVars, $trap)';
}

/// The home screen's target: [base] = Discover's base folders for "Same as Discover" ('' otherwise).
/// layout '' → Top of the library (segments = base folders only, never calls previewTarget with '').
YtdlTarget ytdlTarget({
  required String vpath,
  String base = '',
  required String layout,
  required YtdlTags tags,
}) {
  if (layout.isEmpty) {
    final b = normalizeBase(base);
    if (!b.valid) {
      return YtdlTarget._invalid(
        library: vpath, error: b.error);
    }
    final segments = pathCrumbs(b.base);
    return YtdlTarget._at(
        library: vpath, segments: segments, directory: _dir(vpath, segments));
  }
  final never = _neverIn(layout);
  if (ytdlLayoutCheck(layout).issue == YtdlLayoutIssue.badChars) {
    return YtdlTarget._invalid(
        library: vpath, neverVars: never, error: 'bad_chars');
  }
  final p = previewTarget(
      vpath: vpath, base: base, layout: layout, tags: tags._meta);
  final missing = _missing(p.missingVars);
  if (!p.valid) {
    return YtdlTarget._invalid(
        library: vpath,
        missingVars: missing,
        neverVars: never,
        error: p.error);
  }
  final segments = pathCrumbs(p.relDir);
  return YtdlTarget._at(
    library: vpath,
    segments: segments,
    directory: _dir(vpath, segments),
    missingVars: missing,
    neverVars: never,
    trap: _trapIn(layout, tags),
  );
}

/// The explorer sheet's target under the folder on screen. [currentPath] is the explorer path
/// ('/Music/Daft Punk/'); layout '' = "Right here" → directory == currentPath unchanged.
///
/// The folder on screen exists, so its names go in front of the rendered
/// layout as they are, unchecked: the base-folder rules are for folders a
/// layout would create.
YtdlTarget ytdlFolderTarget({
  required String currentPath,
  required String layout,
  required YtdlTags tags,
}) {
  final here = pathCrumbs(currentPath);
  final library = here.isEmpty ? '' : here.first;
  final below = here.skip(1).toList();
  if (layout.isEmpty) {
    return YtdlTarget._at(
        library: library, segments: below, directory: currentPath);
  }
  final never = _neverIn(layout);
  if (ytdlLayoutCheck(layout).issue == YtdlLayoutIssue.badChars) {
    return YtdlTarget._invalid(
        library: library, neverVars: never, error: 'bad_chars');
  }
  final p = previewTarget(vpath: library, layout: layout, tags: tags._meta);
  final missing = _missing(p.missingVars);
  if (!p.valid) {
    return YtdlTarget._invalid(
        library: library,
        missingVars: missing,
        neverVars: never,
        error: p.error);
  }
  final rendered = pathCrumbs(p.relDir);
  final prefix = currentPath.endsWith('/') ? currentPath : '$currentPath/';
  return YtdlTarget._at(
    library: library,
    segments: [...below, ...rendered],
    directory: rendered.isEmpty ? currentPath : '$prefix${rendered.join('/')}/',
    missingVars: missing,
    neverVars: never,
    trap: _trapIn(layout, tags),
  );
}

String _dir(String vpath, List<String> segments) =>
    segments.isEmpty ? '/$vpath/' : '/$vpath/${segments.join('/')}/';

List<String> _missing(List<String> vars) =>
    [for (final v in vars) if (!kYtdlNeverVars.contains(v)) v];

List<String> _neverIn(String layout) {
  final out = <String>[];
  for (final m in _tokenRe.allMatches(layout)) {
    final name = m[1]!.toUpperCase();
    if (kYtdlNeverVars.contains(name) && !out.contains(name)) out.add(name);
  }
  return out;
}

final RegExp _separators = RegExp(r'[/\\]+');
final RegExp _jsEdgeSpace = RegExp(r'^\s+|\s+$');
final RegExp _onlyBrackets = RegExp(r'^[\s()\[\]{}【】\-–—_.,·&+]+$');
final RegExp _emptyPair = RegExp(r'[(\[{【]\s*[)\]}】]');
final RegExp _danglingEdge = RegExp(r'^[-–—_,·&+]|[-–—_,·&+]$');

/// A folder made only of brackets and separators ("()", "【】", "-"): what
/// an empty variable can leave of a folder — the bracket warning's first
/// case, and how such a folder is read aloud ("empty brackets").
bool ytdlOnlyBrackets(String folder) =>
    folder.trim().isNotEmpty && _onlyBrackets.hasMatch(folder);

/// [folder] with its empty bracket pairs taken out ("() Discovery",
/// "Discovery 【】" → "Discovery"), or null when it has none: the name a
/// folder the bracket warning flags is read aloud with ("Discovery with
/// empty brackets").
String? ytdlWithoutEmptyPairs(String folder) {
  if (!_emptyPair.hasMatch(folder)) return null;
  return folder
      .replaceAll(_emptyPair, ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// The first folder of [layout] an empty variable leaves as only brackets
/// or separators, or with an empty bracket pair or a separator at its edge.
/// Each folder renders as the engine renders it (a value never holds a
/// '/', so a template folder is one rendered folder); one with no empty
/// variable in it is the user's own text and never a trap.
YtdlTrap? _trapIn(String layout, YtdlTags tags) {
  final values = {
    'ARTIST': sanitizeSegment(tags.artist),
    'ALBUMARTIST': sanitizeSegment(tags.artist),
    'ALBUM': sanitizeSegment(tags.album),
    'YEAR': sanitizeSegment(tags.year),
  };
  for (final folder in layout.split(_separators)) {
    final emptied = <String>[];
    final rendered = folder.replaceAllMapped(_tokenRe, (m) {
      final name = m[1]!.toUpperCase();
      final v = values[name] ?? '';
      if (v.isEmpty) emptied.add(name);
      return v;
    }).replaceAll(_jsEdgeSpace, '');
    if (rendered.isEmpty || emptied.isEmpty) continue;
    if (_onlyBrackets.hasMatch(rendered)) {
      return YtdlTrap(YtdlTrapKind.emptyFolder, rendered);
    }
    if (_emptyPair.hasMatch(rendered) || _danglingEdge.hasMatch(rendered)) {
      final onlyYear = emptied.every((n) => n == 'YEAR');
      return YtdlTrap(
          onlyYear ? YtdlTrapKind.missingYear : YtdlTrapKind.other, rendered);
    }
  }
  return null;
}
