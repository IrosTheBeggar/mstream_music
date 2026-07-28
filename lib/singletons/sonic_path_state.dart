import '../objects/server.dart';

/// One end of the journey. [artUrl] is a ready-to-load album-art URL when
/// the pick carried one (setup-card thumbnail); title/artist may be null
/// until a built path's seed rows backfill them from the server's metadata.
class SonicPathEndpoint {
  String path;
  String? title;
  String? artist;
  String? artUrl;

  SonicPathEndpoint(this.path, {this.title, this.artist, this.artUrl});
}

/// Module-level state for the sonic path builder — the mobile analog of the
/// webapp's SONICPATH object. It must outlive the screen: "Browse library"
/// picking pops the route (the file browser is the home scaffold's body,
/// not a route) and re-pushes it after the captured tap, and Start over
/// returns to a setup view that still shows the last-picked endpoints.
class SonicPathState {
  SonicPathState._();
  static final SonicPathState _instance = SonicPathState._();
  factory SonicPathState() => _instance;

  /// The server both endpoints must belong to; set on every entry.
  Server? server;
  SonicPathEndpoint? start;
  SonicPathEndpoint? end;

  /// Requested total rows including both seeds (server clamps 4..32).
  int length = 14;

  bool get ready => server != null && start != null && end != null;

  /// Drawer entry: bind to [s], keeping any endpoints already picked there
  /// (re-entry continuity) — a server switch invalidates them.
  void beginSetup(Server s) {
    if (!identical(server, s)) {
      start = null;
      end = null;
      length = 14;
    }
    server = s;
  }

  /// Discover entry: both ends known up front (seed → destination).
  void beginJourney(Server s, SonicPathEndpoint from, SonicPathEndpoint to) {
    server = s;
    start = from;
    end = to;
    length = 14;
  }

  /// Start over — pristine setup on the same server.
  void reset() {
    start = null;
    end = null;
    length = 14;
  }
}
