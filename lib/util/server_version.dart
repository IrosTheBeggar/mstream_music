/// Server-version parsing and the support/update bands the UI reads.
///
/// The version comes from `GET /api/` (public, no auth), which mStream has
/// served since **5.4.2** (2021-09-27). Older servers 404 there and cannot
/// identify themselves at all — which is exactly why [supportFloor] is 5.5.0,
/// two days later: "can't report a version" and "below the floor" become the
/// same set, so an unknown version needs no separate handling anywhere.
library;

/// A parsed `major.minor.patch`. Extra components and any pre-release suffix
/// are ignored — mStream forks tag things like `6.4.2-velvet`, and the fork
/// still answers for the features of its base version.
class ServerVersion implements Comparable<ServerVersion> {
  final int major;
  final int minor;
  final int patch;

  /// The string exactly as the server reported it, for display. A fork's
  /// suffix is preserved here even though it is ignored for comparison.
  final String raw;

  const ServerVersion(this.major, this.minor, this.patch, this.raw);

  /// Null when [raw] carries no leading `major.minor` — an empty body, an HTML
  /// error page, or a shape this parser was never told about. Callers treat
  /// null the same as a 404: below the floor.
  static ServerVersion? tryParse(String? raw) {
    if (raw == null) return null;
    final m = RegExp(r'^\s*v?(\d+)\.(\d+)(?:\.(\d+))?').firstMatch(raw);
    if (m == null) return null;
    return ServerVersion(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.tryParse(m.group(3) ?? '0') ?? 0,
      raw.trim(),
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
