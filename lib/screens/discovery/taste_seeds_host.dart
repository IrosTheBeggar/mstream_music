import 'package:material_ui/material_ui.dart';

import '../../objects/discovery.dart';
import '../../objects/server.dart';

/// What Discover's configuration bar ([DiscoveryConfigBar]) and its seeds
/// sheet ([DiscoverySeedsSheet]) read and call. Discover's controller is
/// one; Peer Recommendations' controller is the other (mStream plan §4.2:
/// the same bar on both pages, and the window is shared — both read and
/// save the one window remembered on this phone).
///
/// A change to any of these is a notify: the bar and the sheet redraw from
/// the host.
abstract interface class TasteSeedsHost implements Listenable {
  /// The server every call goes to; the seeds sheet draws its rows' art
  /// and picks its songs from it.
  Server get server;

  /// The window every call asks for (days; 0 = all time), as the bar
  /// shows it, and the bar's chooser: remembered, then asked again.
  int get window;
  Future<void> setWindow(int w);

  /// A call is out: the bar's controls are off, and its thin line shows
  /// while [answerShown].
  bool get loading;

  /// An answer is on screen, so a call out shows the thin line over it.
  /// The first call has nothing on screen yet and shows no line. This is
  /// not [seeded]: a page may let go of its seeds while a call is out and
  /// still show the old answer until the new one lands.
  bool get answerShown;

  /// The route refused (the 403 latch): nothing would be asked, so the
  /// bar's controls are off.
  bool get disabled;

  /// The answer the seeds sheet shows: its batch of seeds, and the window
  /// it widened from. Null until one lands ("More options" is off then).
  TasteResponse? get seeded;

  /// The batch's seeds, the visit's pins (app paths) and the seeds the
  /// user left out that the answer resolved.
  List<TasteSeed> get seeds;
  List<String> get pins;
  List<TasteExcluded> get excluded;

  /// The answer was seeded from a random song, not the history.
  bool get isRandom;

  /// The clock for the sheet's "finished 8 months ago". A getter, not a
  /// method: Discover's `now` is a field (discovery_page_controller.dart),
  /// and a field cannot implement a method. Call sites read `c.now()`.
  DateTime Function() get now;

  /// The seeds sheet's "Use these N": [drop] seed hashes left out for the
  /// visit, [restore] dropped ones used again, [pins] the visit's pins from
  /// now on. Then one new call.
  Future<void> applySeeds({
    Set<String> drop = const {},
    Set<String> restore = const {},
    required List<String> pins,
  });
}

/// The toolbar's New seeds (browser_toolbar.dart `_newSeedsButton`): on
/// while [canRefresh], and a tap asks again ([refresh]).
abstract interface class TasteRefreshable implements Listenable {
  bool get canRefresh;
  Future<void> refresh();
}
