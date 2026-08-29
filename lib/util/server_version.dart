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

  /// random-songs: track-length window. Both bounds are independent and
  /// optional; allowUnknownDuration decides whether rows the scanner never
  /// read a length for survive the filter.
  minDuration,
  maxDuration,
  allowUnknownDuration,

  /// random-songs: a sonic seed carried from ANOTHER server, as a raw
  /// vector rather than a filepath (which only names a row on the server
  /// that holds it). Paired with the /discovery/local/embeddings route that
  /// reads the vector out in the first place — a server needs both or
  /// neither, so one floor covers the pair.
  similarToVector,
  similarToModelId,

  /// db/search: restrict the lyrics category. The endpoint's other four
  /// `no*` flags all date to 4.7.0 — below the support floor, so they are
  /// never worth gating; this one arrived at 6.13.1 and is the only search
  /// parameter that can 400 a server we still support.
  noLyrics,
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
  ServerParam.noLyrics: ServerVersion(6, 13, 1, '6.13.1'),
  // ASSUMPTION — the duration params are merged on the server's master but
  // NOT in any tag yet (v6.24.0 is the newest, and they landed after it), so
  // 6.25.0 is the expected next minor rather than an observed floor. If the
  // release that carries them is numbered differently, these three are the
  // only thing to change. Erring high is the safe direction: too high hides a
  // working control, too low sends a parameter that 400s the whole request —
  // though ServerCapabilities would then learn and drop it.
  // Same unreleased-floor caveat as the duration params below: the vector
  // seed is merged on the server's master but carried by no tag yet.
  ServerParam.similarToVector: ServerVersion(6, 25, 0, '6.25.0'),
  ServerParam.similarToModelId: ServerVersion(6, 25, 0, '6.25.0'),
  ServerParam.minDuration: ServerVersion(6, 25, 0, '6.25.0'),
  ServerParam.maxDuration: ServerVersion(6, 25, 0, '6.25.0'),
  ServerParam.allowUnknownDuration: ServerVersion(6, 25, 0, '6.25.0'),
};

/// Whether [v] is known to be too old for [p].
///
/// False for an unknown version and false for a fork: neither can be compared,
/// so neither is *known* to be too old. Both then fall through to sending the
/// parameter and learning from the answer — which is the correct order, since
/// a fork may well support something upstream added later, or vice versa.
bool paramKnownUnsupported(ServerVersion? v, ServerParam p) {
  final floor = _paramFloor[p];
  return floor != null && knownOlderThan(v, floor);
}

/// True only when [v] can be compared to [floor] AND falls below it.
///
/// The double negative matters: this answers "known to be too old", not "not
/// known to be new enough". An unknown version and a fork both return false —
/// neither can be compared to an upstream milestone, so neither is KNOWN to
/// be anything, and the caller should send the request (or show the control)
/// and let the server answer. Guessing the other way hides working features
/// on forks that may well support them.
bool knownOlderThan(ServerVersion? v, ServerVersion floor) =>
    v != null && v.isUpstream && v < floor;

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

/// The Auto DJ track-length window. True when the server is KNOWN to predate
/// it, which is the cue to hide the control rather than let it claim to work
/// — the app strips the parameters before sending, so a visible switch would
/// sit there saying "on" while every pick ignored it.
///
/// Same fork/unknown rule as the rest: neither is known to be too old, so both
/// keep the control and learn from a rejection instead.
bool autoDjDurationKnownUnsupported(ServerVersion? v) =>
    paramKnownUnsupported(v, ServerParam.minDuration);

/// True when the server is KNOWN to predate portable sonic seeds — the
/// /discovery/local/embeddings route and random-songs' vector seed, which
/// ship together. Such a server can still run Auto DJ on its own; it just
/// can't take part in a session seeded from somewhere else.
///
/// Same fork/unknown rule as every other gate: neither is known to be too
/// old, so both are offered the session and answer for themselves.
bool crossServerSeedKnownUnsupported(ServerVersion? v) =>
    paramKnownUnsupported(v, ServerParam.similarToVector);

/// `POST /api/v1/db/metadata/batch` arrived at 5.11.0 — many filepaths in
/// one request instead of one per track.
///
/// A floor, not a capability check: the endpoint returns the SAME object the
/// single-track route does at every version that has it (6.11+ builds it in
/// one query; 5.16..6.10 literally looped pullMetaData), so there is nothing
/// to degrade — either it is there or it 404s. The batch caller treats a 404
/// as "fall back to per-track" anyway, so this only saves a request whose
/// answer is already known.
///
/// The version is the one in package.json at the introducing commit, i.e. the
/// release then in development, so the true floor is this or the next one —
/// which is exactly why the fallback, not this constant, is load-bearing.
const ServerVersion metadataBatchFloor = ServerVersion(5, 11, 0, '5.11.0');

/// True when the server is known to predate batched metadata.
bool metadataBatchKnownUnsupported(ServerVersion? v) =>
    knownOlderThan(v, metadataBatchFloor);

/// `POST /api/v1/playlist/rename` arrived at 5.16.0 — the only ENDPOINT the
/// app calls that lands above the support floor without a ping flag to
/// advertise it. Everything else it talks to either predates 5.5 or is
/// announced on ping, which is why this is a lone constant rather than a
/// second table.
const ServerVersion playlistRenameFloor = ServerVersion(5, 16, 0, '5.16.0');

/// True when the server is known to predate playlist rename — the cue to
/// leave the item out of the menu. Offering it there produced a generic
/// "playlist error" on the 404, which reads as an app bug rather than as an
/// old server.
bool playlistRenameKnownUnsupported(ServerVersion? v) =>
    knownOlderThan(v, playlistRenameFloor);

/// Sonic similarity needs 6.15.2. Separate from the block above because it
/// landed two months later — a 6.7.1..6.14 server has the filters but not
/// this, which is the band where the switch is shown but disabled.
bool sonicKnownUnsupported(ServerVersion? v) =>
    paramKnownUnsupported(v, ServerParam.similarTo);
