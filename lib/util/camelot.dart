// Camelot wheel utilities for harmonic-mixing AutoDJ.
//
// The Camelot wheel encodes the 24 musical keys (12 major + 12
// minor) as positions 1–12, with A = minor and B = major. Tracks
// in keys that are "neighbours" on the wheel mix harmonically:
// same number (relative major/minor), ±1 same letter (perfect 5th
// up/down), or ±1 opposite letter (energy-shift mixes).
//
// The mStream server's POST /api/v1/db/random-songs accepts Camelot
// codes ("8A", "12B") in the `musicalKeys` field and expands each
// internally to the raw key spellings it might find in the library
// (so "8A" matches songs tagged "8A" or "A minor" or "Amin" or
// "Am"). The reverse — raw → Camelot — has to happen client-side
// because the server only accepts codes, not raw keys.

/// Common raw key strings to their Camelot wheel codes. Keys here
/// are case-sensitive — callers should pass keys verbatim from the
/// server response. Library tags in practice come back as short
/// forms like "Am" / "C" / "F#m"; the long forms ("A minor", etc.)
/// are included for robustness.
const Map<String, String> _rawKeyToCamelot = {
  // Minor keys — A side of the wheel
  'G#m': '1A', 'Abm': '1A', 'G# minor': '1A', 'Ab minor': '1A',
  'D#m': '2A', 'Ebm': '2A', 'D# minor': '2A', 'Eb minor': '2A',
  'A#m': '3A', 'Bbm': '3A', 'A# minor': '3A', 'Bb minor': '3A',
  'Fm': '4A', 'F minor': '4A', 'Fmin': '4A',
  'Cm': '5A', 'C minor': '5A', 'Cmin': '5A',
  'Gm': '6A', 'G minor': '6A', 'Gmin': '6A',
  'Dm': '7A', 'D minor': '7A', 'Dmin': '7A',
  'Am': '8A', 'A minor': '8A', 'Amin': '8A',
  'Em': '9A', 'E minor': '9A', 'Emin': '9A',
  'Bm': '10A', 'B minor': '10A', 'Bmin': '10A',
  'F#m': '11A', 'Gbm': '11A', 'F# minor': '11A', 'Gb minor': '11A',
  'C#m': '12A', 'Dbm': '12A', 'C# minor': '12A', 'Db minor': '12A',

  // Major keys — B side of the wheel
  'B': '1B', 'B major': '1B', 'Bmaj': '1B',
  'F#': '2B', 'Gb': '2B', 'F# major': '2B', 'Gb major': '2B',
  'C#': '3B', 'Db': '3B', 'C# major': '3B', 'Db major': '3B',
  'G#': '4B', 'Ab': '4B', 'G# major': '4B', 'Ab major': '4B',
  'D#': '5B', 'Eb': '5B', 'D# major': '5B', 'Eb major': '5B',
  'A#': '6B', 'Bb': '6B', 'A# major': '6B', 'Bb major': '6B',
  'F': '7B', 'F major': '7B', 'Fmaj': '7B',
  'C': '8B', 'C major': '8B', 'Cmaj': '8B',
  'G': '9B', 'G major': '9B', 'Gmaj': '9B',
  'D': '10B', 'D major': '10B', 'Dmaj': '10B',
  'A': '11B', 'A major': '11B', 'Amaj': '11B',
  'E': '12B', 'E major': '12B', 'Emaj': '12B',
};

final RegExp _camelotRe = RegExp(r'^([1-9]|1[0-2])[AB]$');

/// Returns the Camelot code (e.g. "8A") for [raw], or null if the
/// raw key isn't recognised. Strings that already look like Camelot
/// codes pass through unchanged.
String? toCamelotCode(String? raw) {
  if (raw == null) return null;
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  if (_camelotRe.hasMatch(trimmed)) return trimmed;
  return _rawKeyToCamelot[trimmed];
}

/// Returns the 6 Camelot codes that mix harmonically with [anchor]:
/// the anchor itself, ±1 on the same letter (perfect-fifth moves),
/// the opposite letter at the same number (relative major/minor),
/// and ±1 on the opposite letter (energy shifts). Wraps around the
/// 12/1 boundary.
///
/// Returns [anchor] alone if it isn't a valid Camelot code.
List<String> camelotNeighbours(String anchor) {
  final match = _camelotRe.firstMatch(anchor);
  if (match == null) return [anchor];
  final n = int.parse(match.group(1)!);
  final letter = match.group(2)!;
  final prev = n == 1 ? 12 : n - 1;
  final next = n == 12 ? 1 : n + 1;
  final other = letter == 'A' ? 'B' : 'A';
  return [
    '$n$letter',
    '$prev$letter',
    '$next$letter',
    '$n$other',
    '$prev$other',
    '$next$other',
  ];
}
