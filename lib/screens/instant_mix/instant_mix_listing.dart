import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../../objects/display_item.dart';
import '../../objects/instant_mix.dart';
import '../../objects/mix_filters.dart';
import '../../singletons/browser_list.dart';
import 'instant_mix_controller.dart';

/// Instant mix as a browser listing, the way Discover is one
/// (discovery_listing.dart): choosing Instant mix pushes a browser frame,
/// so the mini-player stays docked, the rows are the browser's own song
/// rows (tap follows the tap setting, long-press opens the track sheet —
/// where Instant mix chains), and Back returns to where it was opened.
/// Nothing plays until a verb in the toolbar is pressed.
///
/// The frame is the list [instantMixListingItems] builds from an
/// [InstantMixController]:
///
///   * the banner item ([kMixBanner], always first): browser.dart draws
///     the seed's banner from the controller, fixed above the rows;
///   * then a state item ([kMixState]) while there is no song to show —
///     loading, an empty state, off, failed — or the answer's song rows.
///
/// [InstantMixListing] swaps the frame in place each time the controller
/// changes.
const String kMixBanner = 'mixBanner';
const String kMixState = 'mixState';

/// The toolbar's label on a mix frame (browserChromeLabel translates it).
const String kInstantMixLabel = 'Instant mix';

/// The browser items a mix frame shows for [c]'s state, in order. Pure:
/// the song rows are the controller's own (built once per answer).
List<DisplayItem> instantMixListingItems(InstantMixController c) {
  final server = c.server;
  final state = c.state;
  return [
    DisplayItem(server, c.seed.title, kMixBanner, null, null, null),
    if (state == InstantMixState.ready)
      ...c.rows
    else
      DisplayItem(server, state.name, kMixState, state.name, null, null),
  ];
}

/// Open Instant mix for [seed] from wherever its entry sits — a track
/// sheet, the queue, Song Info, an album's, a playlist's or an artist's
/// toolbar. The page is a browser frame, so whatever covers the browser
/// makes way first: pushed routes go (Song Info, More like this), the
/// expanded player collapses, an open search closes (it would win the
/// toolbar), and an open album detail closes too — Back from the mix
/// opens it again. [controller] is injected by tests.
void openInstantMix(BuildContext context, MixSeed seed,
    {InstantMixController? controller}) {
  Navigator.of(context).popUntil((r) => r.isFirst);
  final browser = BrowserManager();
  browser.requestReveal();
  browser.closeSearch();
  final album = browser.albumDetail;
  browser.closeAlbumDetail();
  InstantMixListing().open(seed, returnAlbum: album, controller: controller);
}

/// Owns the controllers behind the mix frames on the browser stack and
/// keeps each frame in step with its controller. A stack, not Discover's
/// one at a time: a mix of a mix's song keeps the first mix alive under
/// it. A controller lives as long as its frame: each mix watches the
/// browser stack, and the moment its frame is gone (Back, a server switch
/// reset the stack) it is let go.
///
/// The browser keeps one label, not one per frame: whenever a mix frame is
/// back on top it names the toolbar "Instant mix" again, and Back from a
/// mix puts back the label that was showing under it.
class InstantMixListing {
  InstantMixListing._();
  static final InstantMixListing _instance = InstantMixListing._();
  factory InstantMixListing() => _instance;

  final List<_MixEntry> _entries = [];

  /// Whether [list] is a mix frame: its first item is the banner, which
  /// only a mix draws.
  static bool isListing(List<DisplayItem> list) =>
      list.isNotEmpty && list.first.type == kMixBanner;

  /// The controller behind the mix frame on top of the browser stack, or
  /// null when the top frame is not a mix.
  InstantMixController? get controller => _top?.controller;

  _MixEntry? get _top {
    final stack = BrowserManager().browserCache;
    if (stack.isEmpty) return null;
    for (final e in _entries) {
      if (identical(e.frame, stack.last)) return e;
    }
    return null;
  }

  /// Push a mix for [seed] onto the browser stack and ask the server, under
  /// the filters the last mix page applied (MixFilterStore). [returnAlbum]
  /// is the album detail the opening closed, reopened by Back; [controller]
  /// is injected by tests.
  void open(MixSeed seed,
      {DisplayItem? returnAlbum, InstantMixController? controller}) {
    final browser = BrowserManager();
    // Mixes whose frames went while nothing was watching: gone.
    for (final e in List.of(_entries)) {
      if (!browser.browserCache.any((f) => identical(f, e.frame))) {
        _drop(e, restoreLabel: false);
      }
    }
    final c = controller ??
        InstantMixController(seed: seed, filters: MixFilterStore().of(seed));
    final entry = _MixEntry(
      controller: c,
      labelUnder: browser.listName,
      depth: browser.browserCache.length + 1,
      frame: instantMixListingItems(c),
    );
    _entries.add(entry);
    browser.setBrowserLabel(kInstantMixLabel);
    browser.addListToStack(entry.frame, returnAlbum: returnAlbum);
    entry.onChange = () => _onChange(entry);
    c.addListener(entry.onChange!);
    entry.stackSub =
        browser.browserListStream.listen((_) => _onStack(entry));
    unawaited(c.load());
  }

  /// Every browser-stack change: let go of the mix once its frame is off
  /// the stack, and name the toolbar when it is the top again.
  void _onStack(_MixEntry e) {
    final browser = BrowserManager();
    final stack = browser.browserCache;
    if (!stack.any((f) => identical(f, e.frame))) {
      // Back took it when the stack is one frame shorter than it was then;
      // a reset (a server switch) labels the stack itself.
      _drop(e, restoreLabel: stack.length == e.depth - 1);
      return;
    }
    if (identical(stack.last, e.frame) &&
        browser.listName != kInstantMixLabel) {
      browser.setBrowserLabel(kInstantMixLabel);
    }
  }

  void _onChange(_MixEntry e) {
    final browser = BrowserManager();
    final old = e.frame;
    final next = instantMixListingItems(e.controller);
    // Set before the swap: its stack event may arrive at once.
    e.frame = next;
    // A new answer starts at its first row (the rows replace the old ones
    // in place, the list scrolled wherever it was).
    final rows = e.controller.rows;
    if (!identical(rows, e.rowsShown)) {
      e.rowsShown = rows;
      if (browser.browserCache.isNotEmpty &&
          identical(browser.browserCache.last, old) &&
          browser.sc.hasClients) {
        browser.sc.jumpTo(0);
      }
    }
    if (!browser.replaceFrame(old, next)) _drop(e, restoreLabel: false);
  }

  void _drop(_MixEntry e, {required bool restoreLabel}) {
    if (!_entries.remove(e)) return;
    final c = e.controller;
    final onChange = e.onChange;
    if (onChange != null) c.removeListener(onChange);
    // Possibly inside this subscription's own event: cancelling there is
    // safe, it only stops later events.
    unawaited(e.stackSub?.cancel());
    // The home names itself (popBrowser).
    if (restoreLabel && BrowserManager().browserCache.length > 1) {
      BrowserManager().setBrowserLabel(e.labelUnder);
    }
    // Possibly inside the controller's own notifyListeners (a change found
    // the frame gone), where disposing would assert: after it returns.
    scheduleMicrotask(c.dispose);
  }
}

/// One mix frame on the stack: its controller, the frame as last pushed or
/// swapped, and what Back puts back.
class _MixEntry {
  final InstantMixController controller;

  /// The toolbar's label when the mix was opened.
  final String labelUnder;

  /// The stack's length with this frame on top.
  final int depth;
  List<DisplayItem> frame;

  /// The rows the frame last showed: a new answer's scroll to the top.
  List<DisplayItem>? rowsShown;
  VoidCallback? onChange;
  StreamSubscription<List<DisplayItem>>? stackSub;

  _MixEntry({
    required this.controller,
    required this.labelUnder,
    required this.depth,
    required this.frame,
  });
}
