/// Reading a YouTube lookup into tags: the title cleaned of upload noise,
/// the artist taken from "Artist - Title" or from YouTube's artist field,
/// and every removal kept so it can be put back.
///
/// The four readers at the top are the server's own (mStream
/// src/discovery-plugins/plugins/youtube.js), ported verbatim — Dart's
/// RegExp has JS semantics — and held to the server's test values, so
/// Discover and the phone read a title the same way. [ytdlGuess] adds the
/// phone's deliberate differences (spec §3 Auto-fill): 【…】 groups and
/// the word MV count as noise, a noise group that also says Remix, Live,
/// Remaster(ed) or Version keeps those words, and a trailing "ft. X"
/// becomes "(feat. X)".
library;

// ── the server's title readers, verbatim ─────────────────────────────────

// Bracketed or trailing edition noise YouTube uploads carry that a
// catalogue title never does.
final RegExp _bracketNoise = RegExp(
  r'[([][^)\]]*\b(official|lyrics?|audio|video|visuali[sz]er|hd|hq|4k|1080p|720p|explicit|clean|full\s+(song|track))\b[^)\]]*[)\]]',
  caseSensitive: false,
);
final RegExp _trailingNoise = RegExp(
  r'\s*[-–—|:]\s*(official\s+)?(hd\s+|hq\s+)?(music\s+video|lyric\s+video|lyrics?|audio|video|visuali[sz]er|audio\s+only)\s*$',
  caseSensitive: false,
);
final RegExp _artistTitle = RegExp(r'^(.{1,80}?)\s+([-–—:])\s+(.{1,160})$');
final RegExp _topic = RegExp(r'-\s*Topic$', caseSensitive: false);
final RegExp _topicSuffix = RegExp(r'\s*-\s*Topic$', caseSensitive: false);

String cleanTitle(Object? raw) {
  var s = _jsString(raw);
  s = s.replaceAll(_bracketNoise, ' ');
  s = s.replaceFirst(_trailingNoise, '');
  return _squeeze(s);
}

/// "Artist - Title" → (artist, title), else null.
({String artist, String title})? splitArtistTitle(Object? title) {
  final m = _artistTitle.firstMatch(_jsTrim(_jsString(title)));
  return m == null ? null : (artist: _jsTrim(m[1]!), title: _jsTrim(m[3]!));
}

bool isTopicChannel(Object? channel) =>
    _topic.hasMatch(_jsTrim(_jsString(channel)));

String? channelArtist(Object? channel) {
  final s = _jsTrim(_jsString(channel).replaceFirst(_topicSuffix, ''));
  return s.isEmpty ? null : s;
}

/// JS `String(v || '')`.
String _jsString(Object? v) =>
    v == null || v == false || v == 0 || v == '' || (v is double && v.isNaN)
        ? ''
        : '$v';

/// JS `String.prototype.trim` (Dart's [String.trim] also strips U+0085).
String _jsTrim(String s) => s.replaceAll(_jsEdgeSpace, '');
final RegExp _jsEdgeSpace = RegExp(r'^\s+|\s+$');
final RegExp _spaces = RegExp(r'\s+');
final RegExp _space = RegExp(r'^\s$');

/// `s.replace(/\s+/g, ' ').trim()`, the server's last step.
String _squeeze(String s) => _jsTrim(s.replaceAll(_spaces, ' '));

// ── the phone's reading ──────────────────────────────────────────────────

/// Where the tags came from, which decides the card's source line.
enum YtdlTier {
  /// The lookup had an album (yt-dlp sets one only for music tracks):
  /// "Tags from YouTube Music".
  music,

  /// "Artist - Title" in the video title: "Artist and title from the
  /// video title".
  split,

  /// YouTube's artist field, possibly the channel: "Artist may be the
  /// channel name — check it".
  youtubeArtist,

  /// No lookup: the fields are the user's.
  none,
}

enum YtdlCut {
  /// Upload noise: a bracket group or a trailing " - Official Video".
  noise,

  /// The separator the artist was split off at.
  split,
}

/// One piece the guess removed from the raw title; restoring it puts it back.
class YtdlFragment {
  /// As shown on the chip: "(Official Video)", "[HD]", "-" for the split.
  final String text;
  final YtdlCut kind;
  const YtdlFragment(this.text, this.kind);

  @override
  bool operator ==(Object other) =>
      other is YtdlFragment && other.text == text && other.kind == kind;

  @override
  int get hashCode => Object.hash(text, kind);

  @override
  String toString() => 'YtdlFragment(${kind.name}, $text)';
}

/// The raw title cut into runs: kept text (owner -1), or a run of one
/// fragment's text with what stands in for it while it is out.
class _Piece {
  final String text;
  final int owner;
  final String stand;
  const _Piece(this.text, this.owner, this.stand);
}

class YtdlGuess {
  final YtdlTier tier;

  /// The lookup's title, untouched.
  final String rawTitle;

  /// Cleaned (and the right half after a split).
  final String title;

  /// '' when none.
  final String artist;

  /// '' when none.
  final String album;

  /// Four digits or ''.
  final String year;

  /// In the order they appear in [rawTitle]; [titleWith] and [artistWith]
  /// take indexes into it.
  final List<YtdlFragment> fragments;

  /// The lookup's artist as given ('' when null), e.g.
  /// "TheNeighbourhoodVEVO".
  final String youtubeArtistRaw;

  /// [youtubeArtistRaw] without a trailing " - Topic", "VEVO" or word
  /// "Official". Computed in every tier; it is the artist only in
  /// [YtdlTier.youtubeArtist] (and the split tier's "Or YouTube's artist").
  final String youtubeArtist;

  /// "VEVO" | "- Topic" | "Official" when a strip happened (for "↶ VEVO").
  final String? artistStrip;

  /// Split tier: [youtubeArtist] is the split artist, ignoring case.
  final bool artistAgrees;

  final List<_Piece> _pieces;

  /// The split's index in [fragments], -1 without one.
  final int _split;

  const YtdlGuess._({
    required this.tier,
    this.rawTitle = '',
    this.title = '',
    this.artist = '',
    this.album = '',
    this.year = '',
    this.fragments = const [],
    this.youtubeArtistRaw = '',
    this.youtubeArtist = '',
    this.artistStrip,
    this.artistAgrees = false,
    this._pieces = const [],
    this._split = -1,
  });

  /// The empty guess, for details entered by hand.
  static const YtdlGuess none = YtdlGuess._(tier: YtdlTier.none);

  bool get cleaned => fragments.isNotEmpty;

  /// The title with [restored] fragment indexes put back (others still
  /// removed). With every fragment back it is the video's own title (its
  /// spacing squeezed), "ft." and all.
  String titleWith(Set<int> restored) =>
      _titleOf(rawTitle, fragments.length, _pieces, _split, restored);

  /// The artist when the split fragment is restored (YouTube's artist,
  /// stripped) or not (the text left of the separator, with any of its
  /// [restored] fragments back). Outside the split tier: [artist].
  String artistWith(Set<int> restored) {
    if (tier != YtdlTier.split) return artist;
    if (restored.contains(_split)) return youtubeArtist;
    return _squeeze(_rebuild(_pieces, _split, restored).left);
  }

  // The pieces follow from rawTitle, the tier and the fragments, so the
  // public fields decide equality (a late lookup that read the same).
  @override
  bool operator ==(Object other) =>
      other is YtdlGuess &&
      other.tier == tier &&
      other.rawTitle == rawTitle &&
      other.title == title &&
      other.artist == artist &&
      other.album == album &&
      other.year == year &&
      _sameFragments(other.fragments, fragments) &&
      other.youtubeArtistRaw == youtubeArtistRaw &&
      other.youtubeArtist == youtubeArtist &&
      other.artistStrip == artistStrip &&
      other.artistAgrees == artistAgrees;

  @override
  int get hashCode => Object.hash(tier, rawTitle, title, artist, album, year,
      Object.hashAll(fragments), youtubeArtistRaw, artistStrip, artistAgrees);

  @override
  String toString() =>
      'YtdlGuess(${tier.name}, "$title" by "$artist", "$album", "$year", $fragments)';
}

bool _sameFragments(List<YtdlFragment> a, List<YtdlFragment> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Read a `GET /ytdl/metadata` answer. [year] may come as an int
/// (release_year) or a string (release_date's first four characters).
YtdlGuess ytdlGuess({String? title, String? artist, String? album, Object? year}) {
  final rawTitle = title ?? '';
  final youtubeArtistRaw = artist ?? '';
  final albumIn = _squeeze(album ?? '');
  final y = _year(year);
  final (youtubeArtist, strip) = _stripArtist(youtubeArtistRaw);

  if (_squeeze(rawTitle).isEmpty &&
      _squeeze(youtubeArtistRaw).isEmpty &&
      albumIn.isEmpty) {
    return y.isEmpty ? YtdlGuess.none : YtdlGuess._(tier: YtdlTier.none, year: y);
  }

  final cut = _Cut(rawTitle);
  // The split tier needs no album and a title the server's rule splits.
  final tier = albumIn.isNotEmpty
      ? YtdlTier.music
      : cut.split()
          ? YtdlTier.split
          : YtdlTier.youtubeArtist;
  final (fragments, pieces, split) = cut.laidOut();
  final artistNow = switch (tier) {
    YtdlTier.music => _squeeze(youtubeArtistRaw),
    YtdlTier.split => _squeeze(_rebuild(pieces, split, const {}).left),
    _ => youtubeArtist,
  };
  return YtdlGuess._(
    tier: tier,
    rawTitle: rawTitle,
    title: _titleOf(rawTitle, fragments.length, pieces, split, const {}),
    artist: artistNow,
    album: albumIn,
    year: y,
    fragments: fragments,
    youtubeArtistRaw: youtubeArtistRaw,
    youtubeArtist: youtubeArtist,
    artistStrip: strip,
    artistAgrees: tier == YtdlTier.split &&
        youtubeArtist.isNotEmpty &&
        youtubeArtist.toLowerCase() == artistNow.toLowerCase(),
    pieces: pieces,
    split: split,
  );
}

/// The title half of the rebuilt title, "ft. X" made "(feat. X)" — or,
/// with all [count] fragments back, the raw title itself.
String _titleOf(String rawTitle, int count, List<_Piece> pieces, int split,
    Set<int> restored) {
  if (count > 0 && restored.containsAll(List.generate(count, (i) => i))) {
    return _squeeze(rawTitle);
  }
  return _featured(_squeeze(_rebuild(pieces, split, restored).right));
}

/// The raw title rebuilt from [pieces] with [restored] fragments back, cut
/// at the separator (the fragment [split]) while the split is out.
({String left, String right}) _rebuild(
    List<_Piece> pieces, int split, Set<int> restored) {
  final splitOut = split >= 0 && !restored.contains(split);
  final left = StringBuffer();
  final right = StringBuffer();
  var past = !splitOut;
  for (final p in pieces) {
    if (splitOut && p.owner == split) {
      past = true;
      continue;
    }
    final out = past ? right : left;
    out.write(p.owner < 0 || restored.contains(p.owner) ? p.text : p.stand);
  }
  return (left: left.toString(), right: right.toString());
}

final RegExp _fourDigits = RegExp(r'^\d{4}$');

String _year(Object? year) {
  if (year == null) return '';
  final s = year.toString().trim();
  return _fourDigits.hasMatch(s) ? s : '';
}

final RegExp _vevo = RegExp(r'^(.*?\S)\s*VEVO$', caseSensitive: false);
final RegExp _official =
    RegExp(r'^(.*?\S)\s+(?:[-–—|:·]\s+)?Official$', caseSensitive: false);

/// YouTube's artist field with a trailing " - Topic", "VEVO" or word
/// "Official" removed, and which one. A leading "Official" is a name
/// ("Official髭男dism"), never removed.
(String, String?) _stripArtist(String raw) {
  final s = _squeeze(raw);
  if (isTopicChannel(s)) {
    final a = channelArtist(s);
    return a == null ? (s, null) : (a, '- Topic');
  }
  final vevo = _vevo.firstMatch(s);
  if (vevo != null) return (vevo[1]!, 'VEVO');
  final official = _official.firstMatch(s);
  if (official != null) return (official[1]!, 'Official');
  return (s, null);
}

// The phone's noise: the server's bracket rule plus 【…】 groups and the
// word MV (M/V).
final RegExp _phoneGroup = RegExp(
  r'[([][^)\]]*\b(?:official|lyrics?|audio|video|visuali[sz]er|hd|hq|4k|1080p|720p|explicit|clean|full\s+(?:song|track)|mv|m/v)\b[^)\]]*[)\]]'
  r'|【[^】]*\b(?:official|lyrics?|audio|video|visuali[sz]er|hd|hq|4k|1080p|720p|explicit|clean|full\s+(?:song|track)|mv|m/v)\b[^】]*】',
  caseSensitive: false,
);
final RegExp _phoneTrailing = RegExp(
  r'\s*[-–—|:]\s*(official\s+)?(hd\s+|hq\s+)?(music\s+video|lyric\s+video|lyrics?|audio|video|visuali[sz]er|audio\s+only|mv|m/v)\s*$',
  caseSensitive: false,
);

/// A word that makes a noise group worth keeping in part.
final RegExp _keepWord =
    RegExp(r'\b(?:remix|live|remaster(?:ed)?|version)\b', caseSensitive: false);
final RegExp _noisePhrase = RegExp(
  r'\b(?:official|full\s+(?:song|track)|(?:music|lyrics?)\s+video|audio\s+only|lyrics?|audio|video|visuali[sz]er|hd|hq|4k|1080p|720p|explicit|clean|mv|m/v)\b',
  caseSensitive: false,
);
final RegExp _separatorRun = RegExp(r'\s*([-–—|:,/&+·])(?:\s*[-–—|:,/&+·])+');
final RegExp _edgeSeparators =
    RegExp(r'^[\s\-–—|:,/&+·]+|[\s\-–—|:,/&+·]+$');

/// What a noise group keeps: "(Official Live Video)" → "(Live)". null when
/// it goes whole — no keep word, or nothing but "Version" left ("(Clean
/// Version)" says nothing once "Clean" is gone).
String? _keepOf(String group) {
  final inner = group.substring(1, group.length - 1);
  if (!_keepWord.hasMatch(inner)) return null;
  var kept = inner.replaceAll(_noisePhrase, ' ');
  kept = kept.replaceAllMapped(_separatorRun, (m) => ' ${m[1]} ');
  kept = _squeeze(kept).replaceAll(_edgeSeparators, '');
  if (kept.isEmpty || kept.toLowerCase() == 'version') return null;
  return '${group[0]}$kept${group[group.length - 1]}';
}

final RegExp _featTail = RegExp(
  r'^(.*?\S)\s+(?:feat\.|ft\.|featuring)\s+([^()\[\]【】]+)$',
  caseSensitive: false,
);

/// "Song ft. X" → "Song (feat. X)", only for a credit at the very end and
/// outside brackets. "feat" and "ft" need their dots: "A Feat of Strength"
/// and "6 ft under" are titles, and the rewrite has no chip to undo it.
String _featured(String title) {
  final m = _featTail.firstMatch(title);
  if (m == null) return title;
  final who = _jsTrim(m[2]!);
  return who.isEmpty ? title : '${m[1]} (feat. $who)';
}

/// The cutting of one raw title: which code units each fragment owns.
class _Cut {
  final String raw;

  /// Per code unit of [raw]: the fragment that owns it (an index into
  /// [_kinds]), or -1.
  final List<int> _owner;
  final List<YtdlCut> _kinds = [];
  final List<String> _texts = [];
  final List<String> _stands = [];
  final List<int> _starts = [];

  _Cut(this.raw) : _owner = List.filled(raw.length, -1) {
    for (final m in _phoneGroup.allMatches(raw)) {
      final f = _add(YtdlCut.noise, m[0]!, _keepOf(m[0]!) ?? ' ', m.start);
      _owner.fillRange(m.start, m.end, f);
    }
    // The trailing rule reads the title with its groups replaced, as the
    // server's second step does; what it matches goes back to the raw
    // characters it came from.
    final (text, from) = _render(_owner);
    final trailing = _phoneTrailing.firstMatch(text);
    if (trailing != null) {
      final owned = [
        for (var j = trailing.start; j < trailing.end; j++)
          if (from[j] >= 0) from[j],
      ];
      if (owned.isNotEmpty) {
        final f = _add(YtdlCut.noise,
            _squeeze(owned.map((i) => raw[i]).join()), ' ', owned.first);
        for (final i in owned) {
          _owner[i] = f;
        }
      }
    }
  }

  int _add(YtdlCut kind, String text, String stand, int start) {
    _kinds.add(kind);
    _texts.add(text);
    _stands.add(stand);
    _starts.add(start);
    return _kinds.length - 1;
  }

  /// [raw] with every fragment replaced by what stands in for it, and for
  /// each code unit the raw index it came from (-1: stand-in text).
  (String, List<int>) _render(List<int> owner) {
    final out = StringBuffer();
    final from = <int>[];
    for (var i = 0; i < raw.length; i++) {
      final f = owner[i];
      if (f < 0) {
        out.write(raw[i]);
        from.add(i);
      } else if (i == 0 || owner[i - 1] != f) {
        final stand = i == _starts[f] ? _stands[f] : ' ';
        out.write(stand);
        from.addAll(List.filled(stand.length, -1));
      }
    }
    return (out.toString(), from);
  }

  /// The server's split, run on the cleaned title: the separator becomes a
  /// fragment. false when the title does not split (or would split at a
  /// separator inside kept bracket text, which the raw title does not have).
  bool split() {
    final (text, from) = _render(_owner);
    // The cleaned title keeping each character's raw index: whitespace
    // runs squeezed, the ends trimmed.
    final chars = StringBuffer();
    final at = <int>[];
    var gap = false;
    for (var j = 0; j < text.length; j++) {
      if (_space.hasMatch(text[j])) {
        gap = chars.isNotEmpty;
        continue;
      }
      if (gap) {
        chars.write(' ');
        at.add(-1);
        gap = false;
      }
      chars.write(text[j]);
      at.add(from[j]);
    }
    final cleaned = chars.toString();
    final m = _artistTitle.firstMatch(cleaned);
    if (m == null) return false;
    var k = m[1]!.length;
    while (_space.hasMatch(cleaned[k])) {
      k++;
    }
    final p = at[k];
    if (p < 0) return false;
    _owner[p] = _add(YtdlCut.split, m[2]!, '', p);
    return true;
  }

  /// The fragments in raw order, the pieces [YtdlGuess] rebuilds titles
  /// from, and the split's index among the fragments (-1 without one).
  (List<YtdlFragment>, List<_Piece>, int) laidOut() {
    final order = List.generate(_kinds.length, (i) => i)
      ..sort((a, b) => _starts[a].compareTo(_starts[b]));
    final rank = List.filled(order.length, 0);
    for (var r = 0; r < order.length; r++) {
      rank[order[r]] = r;
    }
    final pieces = <_Piece>[];
    var i = 0;
    while (i < raw.length) {
      final f = _owner[i];
      var j = i + 1;
      while (j < raw.length && _owner[j] == f) {
        j++;
      }
      pieces.add(f < 0
          ? _Piece(raw.substring(i, j), -1, '')
          : _Piece(raw.substring(i, j), rank[f],
              i == _starts[f] ? _stands[f] : ' '));
      i = j;
    }
    final split = _kinds.indexOf(YtdlCut.split);
    return (
      [for (final f in order) YtdlFragment(_texts[f], _kinds[f])],
      pieces,
      split < 0 ? -1 : rank[split],
    );
  }
}
