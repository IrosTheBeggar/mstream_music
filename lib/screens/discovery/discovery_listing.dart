import 'dart:async';

import '../../objects/display_item.dart';
import '../../objects/server.dart';
import '../../singletons/browser_list.dart';
import '../../singletons/media.dart';
import 'discovery_page_controller.dart';

/// Discover as a browser listing (mStream plan §2.13, 2026-10-11 — the
/// play-now page). Tapping the home's Discover card pushes a browser frame
/// the way Albums or Recent do, so Discover looks and behaves like the rest
/// of the library: the browser's own album items and song rows, its tap
/// behaviours and long-press track sheet, Back to the server home. The frame
/// is the list [discoveryListingItems] builds from a
/// [DiscoveryPageController]; [DiscoveryListing] swaps it in place each time
/// the controller changes (an answer lands, the window changes, a refresh).
///
/// It shows only songs you can play now, with no counts, percentages or
/// play facts:
///
///   * the gray configuration bar ([kDiscoverBar], always first);
///   * a state card when there is one ([kDiscoverState]);
///   * "Albums from your library", then "Albums from {server}" /
///     "… connected servers" (album items);
///   * "Songs from your library" (file items) and its footer
///     ([kDiscoverFoot]: Queue all · Shuffle · Save as playlist);
///   * "Songs from {server}" / "… connected servers" (file items on each
///     peer's virtual Server, which play through your own server) and its
///     footer (Queue all).
///
/// Section headers are 'section' items whose `data` is a
/// [DiscoverySection] name and whose `subtext` is the one connected
/// server's name, when one answered.
const String kDiscoverBar = 'discoverBar';
const String kDiscoverState = 'discoverState';
const String kDiscoverFoot = 'discoverFoot';

/// The toolbar's label on the Discover frame (browserChromeLabel
/// translates it).
const String kDiscoverLabel = 'Discover';

/// The listing's headers ('section' items, by `data`).
enum DiscoverySection { albumsLibrary, albumsPeers, songsLibrary, songsPeers }

/// What a [kDiscoverState] item draws (its `data`).
enum DiscoveryListingState {
  /// No answer yet: placeholder album tiles and song rows, no words.
  loading,

  /// The library call failed: one line and Try again.
  failed,

  /// Discovery was switched off since the card was drawn.
  off,

  /// Nothing is analyzed yet: the scan-pending card with Check again.
  scanPending,

  /// Nothing finished yet — the seeds are a random pick: Another pick /
  /// Choose a song… / Browse your library.
  random,

  /// The library answered no songs: one line.
  libraryEmpty,

  /// The connected servers are still being asked: placeholder rows.
  peersLoading,

  /// Connected servers answered nothing playable.
  peersQuiet,
}

/// A [kDiscoverFoot] item's `data`: which song list its verbs act on.
const String kDiscoverFootLibrary = 'library';
const String kDiscoverFootPeers = 'peers';

/// The now-playing song, when it is on [server] — pinned once at open
/// (plan §2.3). Null before the audio service is up (widget tests, a cold
/// start), for a song on another server (a federated peer's included: its
/// tracks are a different Server), and for a local file.
String? discoveryNowPlayingPin(Server server) {
  try {
    final extras = MediaManager().audioHandler.mediaItem.value?.extras;
    if (extras?['server'] != server.localname) return null;
    final path = extras?['path'];
    return path is String && path.isNotEmpty ? path : null;
  } catch (_) {
    // audioHandler is `late` and unset until MediaManager().start().
    return null;
  }
}

/// The browser items Discover shows for [c]'s state, in order. Pure: the
/// song and album items are the controller's own (built once per answer, so
/// a rebuild hands the browser the same row objects).
List<DisplayItem> discoveryListingItems(DiscoveryPageController c) {
  final server = c.server;
  DisplayItem state(DiscoveryListingState s) =>
      DisplayItem(server, s.name, kDiscoverState, s.name, null, null);
  DisplayItem section(DiscoverySection s, String english, {String? name}) =>
      DisplayItem(server, english, 'section', s.name, null, name);
  DisplayItem foot(String which) =>
      DisplayItem(server, which, kDiscoverFoot, which, null, null);

  // Switched off while the card was up: one line, nothing to configure.
  if (!c.available) return [state(DiscoveryListingState.off)];

  final out = <DisplayItem>[
    DisplayItem(server, 'Discover', kDiscoverBar, null, null, null),
  ];
  final seeded = c.seeded;
  if (seeded == null) {
    if (c.scanPending) {
      out.add(state(DiscoveryListingState.scanPending));
    } else {
      // Placeholders only while something is actually in flight: any other
      // way to reach here with no answer (a failed call, a stale guard)
      // gets Try again, never a skeleton nothing will replace.
      out.add(state(c.loading
          ? DiscoveryListingState.loading
          : DiscoveryListingState.failed));
    }
    return out;
  }

  if (c.scanPending) out.add(state(DiscoveryListingState.scanPending));
  if (c.error) out.add(state(DiscoveryListingState.failed));
  if (c.isRandom) out.add(state(DiscoveryListingState.random));
  // While no seed is analyzed the server answers every source empty on
  // purpose; the scan-pending card already says why, so no empty lines.
  final waiting = seeded.notAnalyzed;
  final peerName = c.connectedServerName;

  if (c.albumItems.isNotEmpty) {
    out.add(section(DiscoverySection.albumsLibrary, 'Albums from your library'));
    out.addAll(c.albumItems);
  }
  if (c.peerAlbumItems.isNotEmpty) {
    out.add(section(DiscoverySection.albumsPeers,
        peerName == null ? 'Albums from connected servers' : 'Albums from $peerName',
        name: peerName));
    out.addAll(c.peerAlbumItems);
  }

  if (c.library != null && !(waiting && c.libraryRows.isEmpty)) {
    out.add(section(DiscoverySection.songsLibrary, 'Songs from your library'));
    if (c.libraryRows.isEmpty) {
      out.add(state(DiscoveryListingState.libraryEmpty));
    } else {
      out.addAll(c.libraryRows);
      out.add(foot(kDiscoverFootLibrary));
    }
  }

  if (c.hasConnectedServers && !(waiting && c.peerRows.isEmpty)) {
    if (c.peers == null) {
      out.add(state(DiscoveryListingState.peersLoading));
    } else {
      out.add(section(
          DiscoverySection.songsPeers,
          peerName == null
              ? 'Songs from connected servers'
              : 'Songs from $peerName',
          name: peerName));
      if (c.peerRows.isEmpty) {
        out.add(state(DiscoveryListingState.peersQuiet));
      } else {
        out.addAll(c.peerRows);
        out.add(foot(kDiscoverFootPeers));
      }
    }
  }
  return out;
}

/// Owns the controller behind the Discover frame on the browser stack and
/// keeps that frame in step with it. One at a time: opening Discover again
/// (another server, or the same one after Back) replaces it. The controller
/// lives as long as its frame: it watches the browser stack, and the moment
/// the frame is gone (Back, a server switch reset the stack) it lets go,
/// and with it the visit's pins and drops: the next open is a fresh visit
/// that asks again.
/// Whenever the frame is back on top (Back from a list opened over it, such
/// as "Browse your library"'s File Explorer) it names the toolbar
/// "Discover" again: the browser keeps one label, not one per frame.
class DiscoveryListing {
  DiscoveryListing._();
  static final DiscoveryListing _instance = DiscoveryListing._();
  factory DiscoveryListing() => _instance;

  DiscoveryPageController? _c;
  List<DisplayItem>? _frame;
  StreamSubscription<List<DisplayItem>>? _stackSub;

  /// The controller behind the open Discover frame, or null.
  DiscoveryPageController? get controller => _c;

  /// Whether [list] is a Discover frame: its first item is one only
  /// Discover draws (the bar, or the switched-off line).
  static bool isListing(List<DisplayItem> list) =>
      list.isNotEmpty &&
      (list.first.type == kDiscoverBar || list.first.type == kDiscoverState);

  /// Push Discover for [server] onto the browser stack and ask the server.
  /// [controller] is injected by tests.
  void open(Server server, {DiscoveryPageController? controller}) {
    _detach();
    final c = controller ??
        DiscoveryPageController(
          server: server,
          pinAtOpen: discoveryNowPlayingPin(server),
        );
    _c = c;
    final items = discoveryListingItems(c);
    _frame = items;
    BrowserManager().setBrowserLabel(kDiscoverLabel);
    BrowserManager().addListToStack(items);
    c.addListener(_onChange);
    _stackSub = BrowserManager().browserListStream.listen((_) => _onStack());
    unawaited(c.load());
  }

  /// Every browser-stack change: let go once the frame is off the stack,
  /// and put the toolbar's label back when the frame is the top again.
  void _onStack() {
    final frame = _frame;
    if (frame == null) return;
    final stack = BrowserManager().browserCache;
    if (!stack.any((f) => identical(f, frame))) {
      _detach();
      return;
    }
    if (identical(stack.last, frame) &&
        BrowserManager().listName != kDiscoverLabel) {
      BrowserManager().setBrowserLabel(kDiscoverLabel);
    }
  }

  void _onChange() {
    final c = _c;
    final frame = _frame;
    if (c == null || frame == null) return;
    final next = discoveryListingItems(c);
    if (!BrowserManager().replaceFrame(frame, next)) {
      _detach();
      return;
    }
    _frame = next;
  }

  void _detach() {
    final c = _c;
    _c = null;
    _frame = null;
    final sub = _stackSub;
    _stackSub = null;
    // Possibly inside this subscription's own event: cancelling there is
    // safe, it only stops later events.
    unawaited(sub?.cancel());
    if (c == null) return;
    c.removeListener(_onChange);
    // Possibly inside the controller's own notifyListeners (a change found
    // the frame gone), where disposing would assert: after it returns.
    scheduleMicrotask(c.dispose);
  }
}
