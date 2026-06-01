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

/// Canonicalize a Various-Artists marker (scene releases use "VA"; trackers use
/// "Various Artists") so compilations resolve consistently.
String _canonicalArtist(String artist) {
  final low = artist.trim().toLowerCase().replaceAll('.', '');
  if (low == 'va' || low == 'various' || low == 'various artists') {
    return 'Various Artists';
  }
  return artist.trim();
}

/// Strip a featured-artist clause from an album title — "Album (feat. X)" or
/// "Album feat. X & Y" -> "Album". Conservative: bare "with" is left alone (it's
/// common in real titles); only its bracketed form is removed.
String _stripFeat(String album) {
  return album
      .replaceAll(
          RegExp(r'\s*[\(\[]\s*(?:featuring|feat|ft|with)\.?\s[^\)\]]*[\)\]]',
              caseSensitive: false),
          '')
      .replaceAll(
          RegExp(r'\s+(?:featuring|feat|ft)\.?\s.*$', caseSensitive: false),
          '')
      .trim();
}

/// Scene dirnames use a documented two-tier grammar — '_' (and '.') is the
/// space *inside* a field and '-' separates fields:
///   Artist-Title-(Cat)-TYPE-SOURCE-FORMAT-YEAR-GROUP   (no spaces anywhere).
/// That makes the multi-word artist/album split *deterministic*, which the
/// spaced/dot heuristics can't manage. Returns null when the name isn't
/// scene-shaped, so the heuristics run instead. Ref: scenerules.org FLAC/MP3.
TorrentMeta? _parseSceneName(String raw) {
  final name = raw.trim();
  // A space means the human-readable display form, not a scene dirname.
  if (name.isEmpty || name.contains(' ') || !name.contains('-')) return null;
  final fields = name.split('-');
  if (fields.length < 3) return null;
  // The standalone YEAR field (rightmost) is the anchor: everything after it is
  // the release group, everything between title and year is source/format/type.
  int yearIdx = -1;
  for (int i = fields.length - 1; i >= 0; i--) {
    if (RegExp(r'^(?:19|20)\d{2}$').hasMatch(fields[i])) {
      yearIdx = i;
      break;
    }
  }
  if (yearIdx < 2) return null; // need an artist + a title field before the year
  String field(int i) => fields[i]
      .replaceAll(RegExp(r'[_.]'), ' ')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();
  final artist = field(0);
  final album = field(1);
  if (artist.isEmpty || album.isEmpty) return null;
  return TorrentMeta(artist, album, fields[yearIdx], 'high');
}

/// Best-effort artist/album/year extraction from a music release name. Tries the
/// deterministic scene-dirname grammar first, then a ladder of spaced/dot
/// heuristics; ~70–80% of well-named releases parse, the rest fall through to
/// manual entry. Various-Artists + featured-artist noise are normalized.
TorrentMeta parseMusicTorrentName(String rawName) {
  if (rawName.trim().isEmpty) return const TorrentMeta('', '', '', 'none');
  final r = _parseCore(rawName);
  return TorrentMeta(
      _canonicalArtist(r.artist), _stripFeat(r.album), r.year, r.confidence);
}

TorrentMeta _parseCore(String rawName) {
  // Deterministic scene grammar first.
  final scene = _parseSceneName(rawName);
  if (scene != null) return scene;

  // Format/quality/codec tokens (safe to strip anywhere). The bracketed set
  // also covers editions/types; the bare trailing-strip set omits those, since
  // an album can be named "Live"/"Bonus"/"Deluxe" — but not "FLAC".
  const fmt =
      'FLAC|WEBFLAC|MP3|AAC|M4A|M4B|MP4A|OGG|OGA|Vorbis|OPUS|ALAC|APE|WV|'
      'WavPack|WAV|PCM|AIFF|WMA|AC3|DTS|TAK|TTA|DSD|320|256|224|192|160|128|'
      r'V0|V1|V2|CBR|VBR|APS|APX|Q[5-9]|Q10|Lossless|Hi-?Res|'
      r'24[\s-]?bit|16[\s-]?bit|\d+(?:\.\d+)?\s?kHz';
  const src =
      'WEB|CDRip|CDS|CDM|MCD|CDR|CD|VINYL|VLS|LP|SACD|HDCD|BLURAY|BD|DVDA|DVD|'
      'HDDVD|TAPE|CASSETTE|DAT';
  const disc = r'\d+x?CD|CD\d+|Dis[ck]\s?\d+';
  const status = 'PROPER|REPACK|DIRFIX|NFOFIX|RERIP|READNFO|INTERNAL|iNT|INT';
  const edition =
      'Retail|Reissue|Remaster(?:ed)?|Remix(?:ed)?|Promo|Advance|Sampler|Bonus|'
      'Bootleg|Live|Demo|Deluxe|Anniversary|Mono|Stereo|Limited|Special|'
      'Collectors?|Edition|Explicit|Clean|OST|Soundtrack';
  final bracketed = '$fmt|$src|$disc|$status|$edition';
  final bare = '$fmt|$src|$disc|$status';

  final cleaned = rawName
      .replaceAll(
          RegExp('\\[(?:$bracketed)[^\\]]*\\]', caseSensitive: false), '')
      .replaceAll(
          RegExp('\\((?:$bracketed)[^)]*\\)', caseSensitive: false), '')
      // Strip a trailing run of bare format/source tags ("… 2020 FLAC WEB").
      .replaceAll(
          RegExp('(?:[\\s._-]+(?:$bare))+[\\s._-]*\$', caseSensitive: false),
          '')
      .replaceAll(RegExp(r'\s{2,}'), ' ')
      .trim();

  String t(String? s) => (s ?? '').trim();
  String dot(String? s) => (s ?? '').replaceAll('.', ' ').trim();

  final patterns = <(RegExp, TorrentMeta Function(Match))>[
    // "Artist - Album (1973)". The separator requires surrounding spaces so a
    // hyphenated artist (Jay-Z, AC-DC) isn't split on its own dash.
    (RegExp(r'^(.+?)\s+-\s+(.+?)\s*\((\d{4})\)\s*$'),
        (m) => TorrentMeta(t(m[1]), t(m[2]), t(m[3]), 'high')),
    // "Artist - Album [1973]"
    (RegExp(r'^(.+?)\s+-\s+(.+?)\s*\[(\d{4})\]\s*$'),
        (m) => TorrentMeta(t(m[1]), t(m[2]), t(m[3]), 'high')),
    // "Artist - 1973 - Album"
    (RegExp(r'^(.+?)\s+-\s+(\d{4})\s+-\s+(.+?)\s*$'),
        (m) => TorrentMeta(t(m[1]), t(m[3]), t(m[2]), 'high')),
    // "Artist - Album - 1973"
    (RegExp(r'^(.+?)\s+-\s+(.+?)\s+-\s+(\d{4})\s*$'),
        (m) => TorrentMeta(t(m[1]), t(m[2]), t(m[3]), 'high')),
    // "Artist - Album 1973" (trailing year, space-separated; 19xx/20xx only).
    (RegExp(r'^(.+?)\s+-\s+(.+?)\s+((?:19|20)\d{2})\s*$'),
        (m) => TorrentMeta(t(m[1]), t(m[2]), t(m[3]), 'high')),
    // "Artist.Album.1973" (dot-separated)
    (RegExp(r'^([^.]+)\.([^.]+(?:\.[^.\d][^.]*)*)\.(\d{4})\s*$'),
        (m) => TorrentMeta(dot(m[1]), dot(m[2]), t(m[3]), 'high')),
    // bare "Artist - Album" (low — software/etc. also match)
    (RegExp(r'^(.+?)\s+-\s+(.+?)\s*$'),
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
      // Strip leading/trailing separator junk so a template literal left
      // dangling by an empty variable (e.g. "{{ARTIST}} - {{ALBUM}}" with no
      // album -> "Artist -", or both empty -> "-") doesn't become a folder
      // name. Only ASCII separators are stripped, so unicode names survive.
      .map((s) => s.replaceAll(RegExp(r'^[\s._-]+|[\s._-]+$'), ''))
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
