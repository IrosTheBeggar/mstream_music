import 'dart:convert';

/// Client-side helpers backing the "smart" Add Torrent flow — direct
/// ports of the mStream webapp's torrent-panel logic. The template
/// resolver/sanitizer mirror the server's `src/torrent/path-template.js`
/// so the live path preview matches what `/torrent/add` will accept (the
/// server re-validates, so any drift surfaces as a save-time error).

/// Pull the suggested folder name out of a .torrent file's info dict:
/// scan the bencode bytes for "4:info" then "4:name<len>:<value>".
/// Returns '' on any parse failure (the user can still type a name).
String extractTorrentName(List<int> bytes) {
  int i = 0;
  while (i < bytes.length - 8) {
    // "4:info"
    if (bytes[i] == 0x34 &&
        bytes[i + 1] == 0x3a &&
        bytes[i + 2] == 0x69 &&
        bytes[i + 3] == 0x6e &&
        bytes[i + 4] == 0x66 &&
        bytes[i + 5] == 0x6f) {
      if (bytes[i + 6] != 0x64) {
        i++;
        continue; // expect a dict opener 'd'
      }
      for (int j = i + 7; j < bytes.length - 8; j++) {
        // "4:name"
        if (bytes[j] == 0x34 &&
            bytes[j + 1] == 0x3a &&
            bytes[j + 2] == 0x6e &&
            bytes[j + 3] == 0x61 &&
            bytes[j + 4] == 0x6d &&
            bytes[j + 5] == 0x65) {
          int k = j + 6;
          final lenBuf = StringBuffer();
          while (k < bytes.length && bytes[k] != 0x3a) {
            lenBuf.writeCharCode(bytes[k]);
            k++;
          }
          final len = int.tryParse(lenBuf.toString());
          if (len == null || len <= 0 || len > 1024) return '';
          final start = k + 1;
          if (start + len > bytes.length) return '';
          return utf8.decode(bytes.sublist(start, start + len),
              allowMalformed: true);
        }
      }
      return '';
    }
    i++;
  }
  return '';
}

/// Metadata parsed from a torrent name. [confidence] is 'high'|'low'|'none'.
class TorrentMeta {
  final String artist;
  final String album;
  final String year;
  final String confidence;
  const TorrentMeta(this.artist, this.album, this.year, this.confidence);

  TorrentMeta copyWith({String? artist, String? album, String? year}) =>
      TorrentMeta(artist ?? this.artist, album ?? this.album,
          year ?? this.year, confidence);
}

/// Best-effort artist/album/year extraction from a release name (port of
/// the webapp's parseMusicTorrentName). Strips format/quality tags, then
/// tries six patterns; ~70–80% of well-named music releases parse, the
/// rest fall through to manual entry.
TorrentMeta parseMusicTorrentName(String rawName) {
  if (rawName.trim().isEmpty) return const TorrentMeta('', '', '', 'none');
  const tags =
      'FLAC|MP3|320|256|192|V0|V2|AAC|OGG|OPUS|ALAC|DSD|24[Bb]it|16[Bb]it|'
      'Lossless|Hi-?Res|WEB|CDRip|VINYL|LP|EP|SACD|Remaster(?:ed)?';
  final cleaned = rawName
      .replaceAll(RegExp('\\[($tags)[^\\]]*\\]', caseSensitive: false), '')
      .replaceAll(RegExp('\\(($tags)[^)]*\\)', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();

  String t(String? s) => (s ?? '').trim();
  String dot(String? s) => (s ?? '').replaceAll('.', ' ').trim();

  final patterns = <(RegExp, TorrentMeta Function(Match))>[
    // "Artist - Album (1973)"
    (RegExp(r'^(.+?)\s*-\s*(.+?)\s*\((\d{4})\)\s*$'),
        (m) => TorrentMeta(t(m[1]), t(m[2]), t(m[3]), 'high')),
    // "Artist - Album [1973]"
    (RegExp(r'^(.+?)\s*-\s*(.+?)\s*\[(\d{4})\]\s*$'),
        (m) => TorrentMeta(t(m[1]), t(m[2]), t(m[3]), 'high')),
    // "Artist - 1973 - Album"
    (RegExp(r'^(.+?)\s*-\s*(\d{4})\s*-\s*(.+?)\s*$'),
        (m) => TorrentMeta(t(m[1]), t(m[3]), t(m[2]), 'high')),
    // "Artist - Album - 1973"
    (RegExp(r'^(.+?)\s*-\s*(.+?)\s*-\s*(\d{4})\s*$'),
        (m) => TorrentMeta(t(m[1]), t(m[2]), t(m[3]), 'high')),
    // "Artist.Album.1973" (dot-separated)
    (RegExp(r'^([^.]+)\.([^.]+(?:\.[^.\d][^.]*)*)\.(\d{4})\s*$'),
        (m) => TorrentMeta(dot(m[1]), dot(m[2]), t(m[3]), 'high')),
    // bare "Artist - Album" (low — software/etc. also match)
    (RegExp(r'^(.+?)\s*-\s*(.+?)\s*$'),
        (m) => TorrentMeta(t(m[1]), t(m[2]), '', 'low')),
  ];

  for (final (re, map) in patterns) {
    final m = re.firstMatch(cleaned);
    if (m != null) return map(m);
  }
  // Fallback: treat the whole name as the album.
  return TorrentMeta('', cleaned, '', 'none');
}

/// Strip filesystem-illegal chars from a path segment (mirror of the
/// server's path-template.js sanitizeSegment).
String sanitizeTorrentSegment(String? s) {
  if (s == null) return '';
  var v = s;
  v = v.replaceAll(RegExp(r'[/\\:*?<>|"\x00-\x1f]+'), '-');
  v = v.replaceAll(RegExp(r'\s+'), ' ');
  v = v.replaceAll(RegExp(r'^[.\s]+|[.\s]+$'), '');
  if (v.length > 200) v = v.substring(0, 200);
  return v;
}

/// Substitute {{ARTIST}} / {{ALBUM}} / {{YEAR}} / {{GENRE}} /
/// {{ALBUMARTIST}} into [template] (sanitized), then normalize slashes.
String resolveTorrentTemplate(String template, TorrentMeta meta,
    {String? genre}) {
  if (template.isEmpty) return '';
  final lookup = {
    'ARTIST': sanitizeTorrentSegment(meta.artist),
    'ALBUM': sanitizeTorrentSegment(meta.album),
    'YEAR': sanitizeTorrentSegment(meta.year),
    'GENRE': sanitizeTorrentSegment(genre),
    'ALBUMARTIST': sanitizeTorrentSegment(meta.artist),
  };
  final subst = template.replaceAllMapped(
    RegExp(r'\{\{\s*([A-Za-z_][A-Za-z0-9_]*)\s*\}\}'),
    (m) => lookup[m[1]!.toUpperCase()] ?? '',
  );
  final segs = subst
      .split(RegExp(r'[/\\]+'))
      .map((s) => s.trim())
      .where((s) => s.isNotEmpty)
      .toList();
  return segs.join('/');
}

/// Compute the destination path: per-vpath [template] if configured,
/// else the legacy `artist/album` layout.
String computeTorrentPath(String? template, TorrentMeta meta, {String? genre}) {
  if (template != null && template.isNotEmpty) {
    return resolveTorrentTemplate(template, meta, genre: genre);
  }
  final a = sanitizeTorrentSegment(meta.artist);
  final b = sanitizeTorrentSegment(meta.album);
  if (a.isNotEmpty && b.isNotEmpty) return '$a/$b';
  if (b.isNotEmpty) return b;
  if (a.isNotEmpty) return a;
  return '';
}

/// Split a computed path for /torrent/add: last segment is the
/// directoryName, everything before it is the subPath.
({String subPath, String directoryName}) splitTorrentPath(String path) {
  // Sanitize every segment so a hand-typed or torrent-supplied '..', '\',
  // control char, etc. can't escape the library — defense in depth even
  // though the server re-validates. sanitizeTorrentSegment maps '..' and
  // separator-only segments to '', which are then dropped. Split on both
  // separators (a backslash is a path separator on a Windows server).
  final segs = path
      .split(RegExp(r'[/\\]+'))
      .map(sanitizeTorrentSegment)
      .where((s) => s.isNotEmpty)
      .toList();
  if (segs.isEmpty) return (subPath: '', directoryName: '');
  return (
    subPath: segs.length > 1 ? segs.sublist(0, segs.length - 1).join('/') : '',
    directoryName: segs.last,
  );
}
