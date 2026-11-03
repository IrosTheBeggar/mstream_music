/// The file name a YouTube download lands under, predicted on the phone.
///
/// The server hands yt-dlp `-o '%(title)s.%(ext)s' --restrict-filenames`
/// (mStream src/util/yt-dlp.js downloadArgs) and never says what the file
/// will be called until it has landed. "Saves to" shows that name ("about
/// One_More_Time.mp3") and the name check looks for it in the target folder,
/// so this ports yt-dlp's sanitize_filename(restricted=True) for the title
/// field: test/util/ytdl_filename_test.dart holds it to names the real
/// yt-dlp (2026.08.19) produced.
///
/// Dart has no Unicode normaliser, so the NFKC step yt-dlp starts with is
/// done for the part that changes a restricted name: compatibility forms
/// that land on ASCII (fullwidth, ligatures, super- and subscripts, "…",
/// "™", circled and "fancy" math letters), and canonical composition of
/// Latin letters with combining marks ("e" + U+0301 is "é", which keeps its
/// "e"; "a" + U+0304 is "ā", which does not). Every other compatibility
/// form becomes "_" or nothing either way — or is too rare to carry (the
/// CJK squared words, U+3200–33FF and U+1F200–1F2FF, and the squared
/// abbreviations of U+1F12A–1F1FF).
library;

import 'dart:math' as math;

/// yt-dlp's sanitize_filename(restricted=True, is_id=NO_DEFAULT) for the
/// %(title)s field: accented Latin letters transliterated, every other
/// letter outside A–Z made '_' (a title written fully in Cyrillic is "_"),
/// a run of the same substitute squeezed to one and substitutes trimmed off
/// the ends — the title's own '_' and '-' are left as they are.
String ytdlpRestrictedName(String title) {
  // sanitize_filename's own first line (a YouTube title is never empty).
  if (title.isEmpty) return '';
  var s = String.fromCharCodes(_nfkc(title));
  // "12:34" keeps its digits apart as "12_34", not "12_-34".
  s = s.replaceAllMapped(_timestamp, (m) => m[0]!.replaceAll(':', '_'));
  final out = StringBuffer();
  for (final r in s.runes) {
    out.write(_replaceInsane(r));
  }
  var result = out.toString();
  result = result.replaceAllMapped(_sameSubstitutes, (m) => m[1]!);
  result = result.replaceAll(_edgeSubstitutes, '');
  result = result.replaceAll('\x00', '');
  return result.isEmpty ? '_' : result;
}

/// The extension the finished file gets: yt-dlp writes AAC into an .m4a
/// (mStream's OUTPUT_EXT_MAP) and is asked for m4a when the codec is m4b
/// (AUDIO_FORMAT_MAP); every other codec names its own extension.
String ytdlOutputExtension(String codec) => switch (codec) {
      'aac' || 'm4b' => 'm4a',
      _ => codec,
    };

/// `<restricted title>.<ext>`: the name the server's yt-dlp gives the file
/// for [rawTitle] (the video's own title, never the edited one: the route
/// re-tags the file, it does not rename it).
String ytdlPredictedFileName(String rawTitle, String codec) =>
    '${ytdlpRestrictedName(rawTitle)}.${ytdlOutputExtension(codec)}';

/// Whether the restricted rule loses letters of [rawTitle]: a letter that
/// is neither ASCII nor one yt-dlp transliterates (after the same NFKC
/// step) becomes '_' or goes. Drives "letters outside A–Z are dropped from
/// file names".
bool ytdlNameDropsLetters(String rawTitle) {
  for (final r in _nfkc(rawTitle)) {
    if (r > 127 &&
        !_accentChars.containsKey(r) &&
        _letter.hasMatch(String.fromCharCode(r))) {
      return true;
    }
  }
  return false;
}

/// [fileName] cut in the middle to at most [max] characters, keeping its
/// start, and its end with the extension and up to eight characters before
/// it: "Gorillaz_-_Feel_Good…Video_HD.mp3". Unchanged when it already fits.
/// Counts code points, so an emoji is never split.
String ytdlMiddleEllipsis(String fileName, int max) {
  final runes = fileName.runes.toList();
  if (runes.length <= max) return fileName;
  if (max <= 0) return '';
  final keep = max - 1; // one goes to the ellipsis
  final dot = runes.lastIndexOf(0x2E);
  // ".mp3", ".opus": a dot further back is part of the title.
  final extLen = dot > 0 && runes.length - dot <= 6 ? runes.length - dot : 0;
  String end(int n) => String.fromCharCodes(runes.sublist(runes.length - n));
  if (keep <= extLen) return '…${end(keep)}';
  // The extension and up to eight characters before it, but not more than
  // half of what fits, so a short limit still shows how the name starts.
  final tail =
      math.min(math.min(extLen + 8, math.max(extLen + 2, keep ~/ 2)), keep - 1);
  return '${String.fromCharCodes(runes.sublist(0, keep - tail))}…${end(tail)}';
}

// ── sanitize_filename, restricted ────────────────────────────────────────

final RegExp _timestamp = RegExp(r'[0-9]+(?::[0-9]+)+');

/// A run of the same substitute ('\0_' or '\0-') becomes one.
final RegExp _sameSubstitutes = RegExp(r'(\x00.)(?:(?=\1)..)+');

/// Substitutes, with any literal ' ', '_' or '-' next to them, at either end
/// — only where the end itself is a substitute ("-Leading dash" keeps its
/// '-', "_underscores_" its '_').
final RegExp _edgeSubstitutes =
    RegExp(r'^\x00.(?:\x00.|[ _-])*|(?:\x00.|[ _-])*\x00.$');

/// Unicode categories C (control, format, private use, unassigned) and M
/// (combining marks): dropped, where any other character outside ASCII is
/// replaced.
final RegExp _otherOrMark = RegExp(r'^[\p{C}\p{M}]$', unicode: true);
final RegExp _letter = RegExp(r'^\p{L}$', unicode: true);

/// yt-dlp's replace_insane for restricted names. '\0' marks a substitute,
/// so a run of them can be squeezed and trimmed without touching the
/// title's own '_' and '-'.
String _replaceInsane(int r) {
  final accent = _accentChars[r];
  if (accent != null) return accent;
  if (r == 0x3F || r < 32 || r == 127) return ''; // '?' and controls
  final c = String.fromCharCode(r);
  if (c == '"') return '';
  if (c == ':') return '\x00_\x00-'; // "Björk: Army of Me" → Bjork_-_Army_of_Me
  if (r < 128 && r'\/|*<>'.contains(c)) return '\x00_';
  if (r > 127 || c == ' ' || r"!&'()[]{}$;`^,#".contains(c)) {
    return _otherOrMark.hasMatch(c) ? '' : '\x00_';
  }
  return c;
}

/// yt-dlp's ACCENT_CHARS, zipped the way it zips them.
final Map<int, String> _accentChars = Map.fromIterables(
  'ÂÃÄÀÁÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖŐØŒÙÚÛÜŰÝÞßàáâãäåæçèéêëìíîïðñòóôõöőøœùúûüűýþÿ'
      .runes,
  [
    ...'AAAAAA'.split(''), 'AE', ...'CEEEEIIIIDNOOOOOOO'.split(''), 'OE',
    ...'UUUUUY'.split(''), 'TH', 'ss', ...'aaaaaa'.split(''), 'ae',
    ...'ceeeeiiiionooooooo'.split(''), 'oe', ...'uuuuuy'.split(''), 'th', 'y',
  ],
);

// ── NFKC, the part that matters here ─────────────────────────────────────

/// [s] as code points after the compatibility mappings below, with Latin
/// letters and their combining marks decomposed, the marks put in canonical
/// order and composed again — NFKC for every character that changes a
/// restricted name.
List<int> _nfkc(String s) {
  final decomposed = <int>[];
  for (final r in s.runes) {
    final compat = _compat(r);
    if (compat == null) {
      _decompose(r, decomposed);
    } else {
      for (final c in compat.runes) {
        _decompose(c, decomposed);
      }
    }
  }
  _canonicalOrder(decomposed);
  return _compose(decomposed);
}

void _decompose(int r, List<int> out) {
  final pair = _latinDecomposition[r];
  if (pair == null) {
    out.add(r);
  } else {
    _decompose(pair.$1, out);
    out.add(pair.$2);
  }
}

/// Each run of combining marks sorted by combining class, stably.
void _canonicalOrder(List<int> s) {
  for (var i = 1; i < s.length; i++) {
    final c = _combiningClass(s[i]);
    if (c == 0) continue;
    var j = i;
    while (j > 0) {
      final before = _combiningClass(s[j - 1]);
      if (before <= c) break;
      final t = s[j - 1];
      s[j - 1] = s[j];
      s[j] = t;
      j--;
    }
  }
}

/// Unicode's canonical composition: a mark joins the last starter unless a
/// mark of the same or a higher class stands between them.
List<int> _compose(List<int> s) {
  final out = <int>[];
  var starter = -1;
  var lastClass = 0;
  for (final r in s) {
    final cls = _combiningClass(r);
    if (starter >= 0) {
      final composite = _latinComposition[(out[starter], r)];
      if (composite != null &&
          (out.length == starter + 1 || lastClass < cls)) {
        out[starter] = composite;
        continue;
      }
    }
    if (cls == 0) {
      starter = out.length;
      lastClass = 0;
    } else {
      lastClass = cls;
    }
    out.add(r);
  }
  return out;
}

/// Canonical combining classes of U+0300–036F (UnicodeData); every other
/// character counts as a starter here (the marks of other scripts never
/// compose with a Latin letter).
int _combiningClass(int r) {
  if (r < 0x300 || r > 0x36F) return 0;
  for (final (from, to, cls) in _markClasses) {
    if (r >= from && r <= to) return cls;
  }
  return 0;
}

const List<(int, int, int)> _markClasses = [
  (0x300, 0x314, 230), (0x315, 0x315, 232), (0x316, 0x319, 220),
  (0x31A, 0x31A, 232), (0x31B, 0x31B, 216), (0x31C, 0x320, 220),
  (0x321, 0x322, 202), (0x323, 0x326, 220), (0x327, 0x328, 202),
  (0x329, 0x333, 220), (0x334, 0x338, 1), (0x339, 0x33C, 220),
  (0x33D, 0x344, 230), (0x345, 0x345, 240), (0x346, 0x346, 230),
  (0x347, 0x349, 220), (0x34A, 0x34C, 230), (0x34D, 0x34E, 220),
  (0x34F, 0x34F, 0), (0x350, 0x352, 230), (0x353, 0x356, 220),
  (0x357, 0x357, 230), (0x358, 0x358, 232), (0x359, 0x35A, 220),
  (0x35B, 0x35B, 230), (0x35C, 0x35C, 233), (0x35D, 0x35E, 234),
  (0x35F, 0x35F, 233), (0x360, 0x361, 234), (0x362, 0x362, 233),
  (0x363, 0x36F, 230),
];

/// Every precomposed letter of Latin-1, Latin Extended-A/B and Latin
/// Extended Additional with its two-character canonical decomposition
/// (UnicodeData, composition exclusions left out), keyed by the mark:
/// pairs of base, composite. Bases may be composites themselves (Vietnamese
/// "ệ" is "ẹ" + U+0302).
const Map<int, String> _latinPairs = {
  0x300: 'AÀEÈIÌOÒUÙaàeèiìoòuùÜǛüǜNǸnǹĒḔēḕŌṐōṑWẀwẁÂẦâầĂẰăằÊỀêềÔỒôồƠỜơờƯỪưừYỲyỳ',
  0x301: 'AÁEÉIÍOÓUÚYÝaáeéiíoóuúyýCĆcćLĹlĺNŃnńRŔrŕSŚsśZŹzźÜǗüǘGǴgǵÅǺåǻÆǼæǽØǾøǿ'
      'ÇḈçḉĒḖēḗÏḮïḯKḰkḱMḾmḿÕṌõṍŌṒōṓPṔpṕŨṸũṹWẂwẃÂẤâấĂẮăắÊẾêếÔỐôốƠỚơớƯỨưứ',
  0x302: 'AÂEÊIÎOÔUÛaâeêiîoôuûCĈcĉGĜgĝHĤhĥJĴjĵSŜsŝWŴwŵYŶyŷZẐzẑẠẬạậẸỆẹệỌỘọộ',
  0x303: 'AÃNÑOÕaãnñoõIĨiĩUŨuũVṼvṽÂẪâẫĂẴăẵEẼeẽÊỄêễÔỖôỗƠỠơỡƯỮưữYỸyỹ',
  0x304: 'AĀaāEĒeēIĪiīOŌoōUŪuūÜǕüǖÄǞäǟȦǠȧǡÆǢæǣǪǬǫǭÖȪöȫÕȬõȭȮȰȯȱYȲyȳGḠgḡḶḸḷḹṚṜṛṝ',
  0x306: 'AĂaăEĔeĕGĞgğIĬiĭOŎoŏUŬuŭȨḜȩḝẠẶạặ',
  0x307: 'CĊcċEĖeėGĠgġIİZŻzżAȦaȧOȮoȯBḂbḃDḊdḋFḞfḟHḢhḣMṀmṁNṄnṅPṖpṗRṘrṙSṠsṡŚṤśṥ'
      'ŠṦšṧṢṨṣṩTṪtṫWẆwẇXẊxẋYẎyẏſẛ',
  0x308: 'AÄEËIÏOÖUÜaäeëiïoöuüyÿYŸHḦhḧÕṎõṏŪṺūṻWẄwẅXẌxẍtẗ',
  0x309: 'AẢaảÂẨâẩĂẲăẳEẺeẻÊỂêểIỈiỉOỎoỏÔỔôổƠỞơởUỦuủƯỬưửYỶyỷ',
  0x30A: 'AÅaåUŮuůwẘyẙ',
  0x30B: 'OŐoőUŰuű',
  0x30C: 'CČcčDĎdďEĚeěLĽlľNŇnňRŘrřSŠsšTŤtťZŽzžAǍaǎIǏiǐOǑoǒUǓuǔÜǙüǚGǦgǧKǨkǩƷǮʒǯ'
      'jǰHȞhȟ',
  0x30F: 'AȀaȁEȄeȅIȈiȉOȌoȍRȐrȑUȔuȕ',
  0x311: 'AȂaȃEȆeȇIȊiȋOȎoȏRȒrȓUȖuȗ',
  0x31B: 'OƠoơUƯuư',
  0x323: 'BḄbḅDḌdḍHḤhḥKḲkḳLḶlḷMṂmṃNṆnṇRṚrṛSṢsṣTṬtṭVṾvṿWẈwẉZẒzẓAẠaạEẸeẹIỊiịOỌoọ'
      'ƠỢơợUỤuụƯỰưựYỴyỵ',
  0x324: 'UṲuṳ',
  0x325: 'AḀaḁ',
  0x326: 'SȘsșTȚtț',
  0x327: 'CÇcçGĢgģKĶkķLĻlļNŅnņRŖrŗSŞsşTŢtţEȨeȩDḐdḑHḨhḩ',
  0x328: 'AĄaąEĘeęIĮiįUŲuųOǪoǫ',
  0x32D: 'DḒdḓEḘeḙLḼlḽNṊnṋTṰtṱUṶuṷ',
  0x32E: 'HḪhḫ',
  0x330: 'EḚeḛIḬiḭUṴuṵ',
  0x331: 'BḆbḇDḎdḏKḴkḵLḺlḻNṈnṉRṞrṟTṮtṯZẔzẕhẖ',
};

Iterable<(int base, int mark, int composite)> _latinTriples() sync* {
  for (final MapEntry(key: mark, value: pairs) in _latinPairs.entries) {
    final runes = pairs.runes.toList();
    for (var i = 0; i + 1 < runes.length; i += 2) {
      yield (runes[i], mark, runes[i + 1]);
    }
  }
}

final Map<int, (int, int)> _latinDecomposition = {
  for (final (base, mark, composite) in _latinTriples()) composite: (base, mark),
};

final Map<(int, int), int> _latinComposition = {
  for (final (base, mark, composite) in _latinTriples()) (base, mark): composite,
};

/// NFKC's compatibility mappings that change a restricted name, as
/// UnicodeData gives them; null for a character NFKC keeps (or maps to
/// something that becomes '_' or nothing just the same).
String? _compat(int r) {
  final one = _compatOne[r];
  if (one != null) return String.fromCharCode(one);
  final many = _compatMany[r];
  if (many != null) return many;
  // Fullwidth ASCII: "（Ｌｉｖｅ）" is "(Live)".
  if (r >= 0xFF01 && r <= 0xFF5E) return String.fromCharCode(r - 0xFEE0);
  // Roman numerals: "Ⅶ" is "VII".
  if (r >= 0x2160 && r <= 0x217F) {
    final n = _roman[(r - 0x2160) % 16];
    return r < 0x2170 ? n : n.toLowerCase();
  }
  if (r >= 0x2460 && r <= 0x24EA) return _enclosed(r);
  // Mathematical letters, the "fancy font" of a title: 13 alphabets of
  // A–Z a–z, with holes where the letter lives in Letterlike Symbols.
  if (r >= 0x1D400 && r <= 0x1D6A3 && !_mathHoles.contains(r)) {
    final i = (r - 0x1D400) % 52;
    return String.fromCharCode(i < 26 ? 0x41 + i : 0x61 + i - 26);
  }
  if (r >= 0x1D7CE && r <= 0x1D7FF) return '${(r - 0x1D7CE) % 10}';
  if (r == 0x1F100) return '0.';
  if (r >= 0x1F101 && r <= 0x1F10A) return '${r - 0x1F101},';
  if (r >= 0x1F110 && r <= 0x1F129) {
    return '(${String.fromCharCode(0x41 + r - 0x1F110)})';
  }
  if (r >= 0x1F130 && r <= 0x1F149) return String.fromCharCode(0x41 + r - 0x1F130);
  if (r >= 0x1FBF0 && r <= 0x1FBF9) return '${r - 0x1FBF0}';
  return null;
}

/// ①–⑳, ⑴–⒇, ⒈–⒛, ⒜–⒵, Ⓐ–ⓩ and ⓪.
String _enclosed(int r) {
  if (r <= 0x2473) return '${r - 0x2460 + 1}';
  if (r <= 0x2487) return '(${r - 0x2474 + 1})';
  if (r <= 0x249B) return '${r - 0x2488 + 1}.';
  if (r <= 0x24B5) return '(${String.fromCharCode(0x61 + r - 0x249C)})';
  if (r <= 0x24CF) return String.fromCharCode(0x41 + r - 0x24B6);
  if (r <= 0x24E9) return String.fromCharCode(0x61 + r - 0x24D0);
  return '0';
}

const List<String> _roman = [
  'I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII', 'IX', 'X', 'XI', 'XII', //
  'L', 'C', 'D', 'M',
];

const Set<int> _mathHoles = {
  0x1D455, 0x1D49D, 0x1D4A0, 0x1D4A1, 0x1D4A3, 0x1D4A4, 0x1D4A7, 0x1D4A8,
  0x1D4AD, 0x1D4BA, 0x1D4BC, 0x1D4C4, 0x1D506, 0x1D50B, 0x1D50C, 0x1D515,
  0x1D51D, 0x1D53A, 0x1D53F, 0x1D545, 0x1D547, 0x1D548, 0x1D549, 0x1D551,
};

/// One character for one: superscript and subscript letters and digits,
/// letterlike symbols (the Kelvin and Ångström signs included), small and
/// vertical presentation forms, half-width sound marks.
final Map<int, int> _compatOne = Map.fromIterables(
  'ª\u{B2}\u{B3}\u{B9}ºſʰʲʳʷʸˡˢˣᴬᴭᴮᴰᴱᴳᴴᴵᴶᴷᴸᴹᴺᴼᴾᴿᵀᵁᵂᵃᵇᵈᵉᵍᵏᵐᵒᵖᵗᵘᵛᵢᵣᵤᵥᶜᶞᶠᶻ'
          '\u{2024}\u{2070}ⁱ\u{2074}\u{2075}\u{2076}\u{2077}\u{2078}\u{2079}'
          '\u{207A}\u{207C}ⁿ\u{2080}\u{2081}\u{2082}\u{2083}\u{2084}\u{2085}'
          '\u{2086}\u{2087}\u{2088}\u{2089}\u{208A}\u{208C}ₐₑₒₓₕₖₗₘₙₚₛₜ'
          'ℂℊℋℌℍℎℐℑℒℓℕℙℚℛℜℝℤℨ\u{212A}\u{212B}ℬℭℯℰℱℳℴℹⅅⅆⅇⅈⅉⱼⱽꟹ'
          '\u{FB29}\u{FE13}\u{FE16}\u{FE33}\u{FE34}\u{FE4D}\u{FE4E}\u{FE4F}'
          '\u{FE52}\u{FE55}\u{FE56}\u{FE62}\u{FE63}\u{FE66}\u{FE6A}\u{FE6B}ﾞﾟ'
      .runes,
  'a231oshjrwylsxAÆBDEGHIJKLMNOPRTUWabdegkmoptuviruvcðfz'
          '.0i456789'
          '+=n012345'
          '6789+=aeoxhklmnpst'
          'CgHHHhIILlNPQRRRZZKÅBCeEFMoiDdeijjVœ'
          '+:?_____'
          '.:?+-=%@\u{3099}\u{309A}'
      .runes,
);

/// One character for several: fractions, ligatures, "…", "™", "№".
const Map<int, String> _compatMany = {
  0x00BC: '1\u{2044}4', 0x00BD: '1\u{2044}2', 0x00BE: '3\u{2044}4',
  0x0132: 'IJ', 0x0133: 'ij', 0x013F: 'L\u{B7}', 0x0140: 'l\u{B7}',
  0x0149: 'ʼn', 0x01C4: 'DŽ', 0x01C5: 'Dž', 0x01C6: 'dž', 0x01C7: 'LJ',
  0x01C8: 'Lj', 0x01C9: 'lj', 0x01CA: 'NJ', 0x01CB: 'Nj', 0x01CC: 'nj',
  0x01F1: 'DZ', 0x01F2: 'Dz', 0x01F3: 'dz', 0x1E9A: 'aʾ',
  0x2025: '..', 0x2026: '...', 0x2047: '??', 0x20A8: 'Rs',
  0x2100: 'a/c', 0x2101: 'a/s', 0x2103: '\u{B0}C', 0x2105: 'c/o',
  0x2106: 'c/u', 0x2109: '\u{B0}F', 0x2116: 'No', 0x2120: 'SM',
  0x2121: 'TEL', 0x2122: 'TM', 0x213B: 'FAX',
  0x2150: '1\u{2044}7', 0x2151: '1\u{2044}9', 0x2152: '1\u{2044}10',
  0x2153: '1\u{2044}3', 0x2154: '2\u{2044}3', 0x2155: '1\u{2044}5',
  0x2156: '2\u{2044}5', 0x2157: '3\u{2044}5', 0x2158: '4\u{2044}5',
  0x2159: '1\u{2044}6', 0x215A: '5\u{2044}6', 0x215B: '1\u{2044}8',
  0x215C: '3\u{2044}8', 0x215D: '5\u{2044}8', 0x215E: '7\u{2044}8',
  0x215F: '1\u{2044}', 0x2189: '0\u{2044}3',
  0x2A74: '::=', 0x2A75: '==', 0x2A76: '===',
  0xFB00: 'ff', 0xFB01: 'fi', 0xFB02: 'fl', 0xFB03: 'ffi', 0xFB04: 'ffl',
  0xFB05: 'st', 0xFB06: 'st', 0xFE19: '...', 0xFE30: '..',
  // The tone-mark singletons are canonical, not compatibility, mappings,
  // but NFKC makes them the plain marks before composing: "n" + U+0341 is
  // "ń" (a substitute), not "n".
  0x0340: '\u{300}', 0x0341: '\u{301}', 0x0343: '\u{313}',
  0x0344: '\u{308}\u{301}',
};
