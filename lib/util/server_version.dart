/// Server-version parsing and the support/update bands the UI reads.
///
/// The version comes from `GET /api/` (public, no auth), which mStream has
/// served since **5.4.2** (2021-09-27). Older servers 404 there and cannot
/// identify themselves at all — which is exactly why [supportFloor] is 5.5.0,
/// two days later: "can't report a version" and "below the floor" become the
/// same set, so an unknown version needs no separate handling anywhere.
library;

/// A parsed `major.minor.patch`, plus whether the build is upstream mStream.
///
/// A suffix is NOT cosmetic. The velvet fork numbers its releases on its own
/// line — velvet 6.14.7 shipped 2026-05-02, ten days BEFORE upstream 6.7.1 —
/// so comparing a fork's number against upstream milestones is meaningless in
/// both directions. [isUpstream] is false for anything carrying a suffix, and
/// the feature table refuses to answer for those: they fall through to
/// probing, which asks the server itself instead of guessing from a number.
class ServerVersion implements Comparable<ServerVersion> {
  final int major;
  final int minor;
  final int patch;

  /// The string exactly as the server reported it, for display.
  final String raw;

  /// False when [raw] carried a `-suffix` — a fork or pre-release, whose
  /// numbering cannot be compared against upstream milestones.
  final bool isUpstream;

  const ServerVersion(this.major, this.minor, this.patch, this.raw,
      {this.isUpstream = true});

  /// Null when [raw] carries no leading `major.minor` — an empty body, an HTML
  /// error page, or a shape this parser was never told about. Callers treat
  /// null the same as a 404: below the floor.
  static ServerVersion? tryParse(String? raw) {
    if (raw == null) return null;
    final t = raw.trim();
    final m = RegExp(r'^v?(\d+)\.(\d+)(?:\.(\d+))?(.*)$').firstMatch(t);
    if (m == null) return null;
    // Anything trailing the numbers — `-velvet`, `-rc1`, `-beta` — marks a
    // build whose numbering is not upstream's.
    final tail = (m.group(4) ?? '').trim();
    return ServerVersion(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.tryParse(m.group(3) ?? '0') ?? 0,
      t,
      isUpstream: tail.isEmpty,
    );
  }

  @override
  int compareTo(ServerVersion o) {
    if (major != o.major) return major.compareTo(o.major);
    if (minor != o.minor) return minor.compareTo(o.minor);
    return patch.compareTo(o.patch);
  }

  bool operator >=(ServerVersion o) => compareTo(o) >= 0;
  bool operator <(ServerVersion o) => compareTo(o) < 0;

  @override
  String toString() => raw;

  @override
  bool operator ==(Object other) =>
      other is ServerVersion &&
      major == other.major &&
      minor == other.minor &&
      patch == other.patch;

  @override
  int get hashCode => Object.hash(major, minor, patch);
}

/// Oldest version this app claims to work against. See the library comment for
/// why it is 5.5 and not 5.0.
const ServerVersion supportFloor = ServerVersion(5, 5, 0, '5.5.0');

/// Anything below this is far enough behind to be worth nudging about.
const ServerVersion updateUrgent = ServerVersion(6, 0, 0, '6.0.0');

/// Below this is behind, but only mildly.
const ServerVersion updateSuggested = ServerVersion(6, 15, 0, '6.15.0');

/// Where the update flag sends people.
const String serverDownloadUrl = 'https://mstream.io/server';

/// How out of date a server is, for the flag in the nav drawer.
enum UpdateBand {
  /// On 5.x (or too old to say) — below the support floor or close to it.
  urgent,

  /// A 6.x release, but behind 6.15.
  suggested,

  /// Current enough; show nothing.
  none,
}

/// Which flag (if any) to show for [v]. A null version means the server never
/// answered `/api/`, which puts it before 5.4.2 — the most out of date there
/// is, so it gets the loudest band.
UpdateBand updateBandFor(ServerVersion? v) {
  if (v == null || v < updateUrgent) return UpdateBand.urgent;
  if (v < updateSuggested) return UpdateBand.suggested;
  return UpdateBand.none;
}

/// True when the server is older than this app supports — the add-server
/// warning, and the reason a null version is not treated as "probably fine".
bool isBelowSupportFloor(ServerVersion? v) => v == null || v < supportFloor;


// ---------------------------------------------------------------------------
// Feature table
// ---------------------------------------------------------------------------

/// Request parameters the app sends that older servers reject outright.
///
/// mStream validates request bodies with Joi and no `allowUnknown`, so an
/// unrecognised key is a hard 400 — verified against 6.22:
/// `{"error":"\"totallyMadeUpParam\" is not allowed"}`. That is what makes a
/// version table worth having at all: the cost of guessing wrong is a failed
/// request, not a silently ignored field.
///
/// Dates come from the first commit on mStream's **master** that introduced
/// each key under `src/`. Restricting to master matters — searching all refs
/// picks up the velvet fork's independent numbering and dates things years
/// wrong. The version recorded is the one in package.json at that commit, i.e.
/// the release then in development, so the true floor is that release or the
/// next one; treat these as lower bounds.
///
/// This table is an OPTIMISATION, not the source of truth. It exists to avoid
/// a wasted round trip against a server we can already tell is too old. The
/// authority is [ServerCapabilities], which learns from the server's own
/// rejection — so an entry being slightly wrong costs one 400, not a broken
/// feature.
enum ServerParam {
  /// random-songs: exclude whole vpaths.
  ignoreVPaths,

  /// random-songs: genre whitelist/blacklist values.
  genres,

  /// random-songs: which way `genres` applies.
  genreMode,

  /// random-songs: BPM-continuity windows and their relaxation step.
  bpmRanges,
  bpmRangesWide,
  requireBpm,

  /// random-songs: harmonic-mixing Camelot codes.
  musicalKeys,
  requireMusicalKey,

  /// random-songs: artist cooldown.
  ignoreArtists,

  /// random-songs: sonic-similarity constraint. Also ping-flagged via
  /// `discovery`, so the flag is consulted first and this is the backstop.
  similarTo,
  minSimilarity,
}

/// Wire name for [p] — what actually goes in the JSON body, and what the
/// server names back at us in a rejection.
String paramWireName(ServerParam p) => p.name;

/// Lowest upstream version known to accept each parameter. See the doc on
/// [ServerParam] for how these were derived and why they are lower bounds.
const Map<ServerParam, ServerVersion> _paramFloor = {
  ServerParam.ignoreVPaths: ServerVersion(4, 6, 0, '4.6.0'),
  // 6.7.1, not 5.16.0: the earlier date was the word 'genres' appearing in
  // an unrelated sqlite/rust-parser commit. It entered the random-songs
  // SCHEMA in the same 'backend for genre filter' change as genreMode.
  ServerParam.genres: ServerVersion(6, 7, 1, '6.7.1'),
  ServerParam.genreMode: ServerVersion(6, 7, 1, '6.7.1'),
  ServerParam.bpmRanges: ServerVersion(6, 7, 1, '6.7.1'),
  ServerParam.bpmRangesWide: ServerVersion(6, 7, 1, '6.7.1'),
  ServerParam.requireBpm: ServerVersion(6, 7, 1, '6.7.1'),
  ServerParam.musicalKeys: ServerVersion(6, 7, 1, '6.7.1'),
  ServerParam.requireMusicalKey: ServerVersion(6, 7, 1, '6.7.1'),
  ServerParam.ignoreArtists: ServerVersion(6, 7, 1, '6.7.1'),
  ServerParam.similarTo: ServerVersion(6, 15, 2, '6.15.2'),
  ServerParam.minSimilarity: ServerVersion(6, 15, 2, '6.15.2'),
};

/// Whether [v] is known to be too old for [p].
///
/// False for an unknown version and false for a fork: neither can be compared,
/// so neither is *known* to be too old. Both then fall through to sending the
/// parameter and learning from the answer — which is the correct order, since
/// a fork may well support something upstream added later, or vice versa.
bool paramKnownUnsupported(ServerVersion? v, ServerParam p) {
  if (v == null || !v.isUpstream) return false;
  final floor = _paramFloor[p];
  return floor != null && v < floor;
}

/// The Auto DJ continuity/filter block — BPM continuity, harmonic mixing and
/// the genre filter — all arrived together in 6.7.1. True when the server is
/// KNOWN to predate them, which is the cue to hide those controls rather than
/// let them claim to work.
///
/// False for a fork or an unknown version: neither can be compared, so neither
/// is known to be too old, and hiding a control a server might well support
/// would be worse than offering it and learning from a rejection.
bool autoDjFiltersKnownUnsupported(ServerVersion? v) =>
    paramKnownUnsupported(v, ServerParam.bpmRanges);

/// Sonic similarity needs 6.15.2. Separate from the block above because it
/// landed two months later — a 6.7.1..6.14 server has the filters but not
/// this, which is the band where the switch is shown but disabled.
bool sonicKnownUnsupported(ServerVersion? v) =>
    paramKnownUnsupported(v, ServerParam.similarTo);
