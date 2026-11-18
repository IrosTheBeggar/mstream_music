import 'package:material_ui/material_ui.dart';

import '../l10n/app_localizations.dart';
import '../objects/display_item.dart';
import '../objects/server.dart';

/// Outcome of a tap while capture may be armed: [pass] — not armed, run the
/// normal tap handling; [captured] — consumed, the pick landed; [rejected]
/// — consumed, but the row can't seed the path (wrong server / local file).
enum CaptureResult { pass, captured, rejected }

/// One armed "pick a song from the library" request (the webapp's
/// songCapture): which server the pick must come from, where the picked row
/// goes, and — since browse-to-pick tears the asking screen down — what the
/// banner says while armed and how to get back once a row lands.
class TrackCaptureRequest {
  final Server server;

  /// Banner copy while armed. A callback, not a string, so the strip picks up
  /// a locale change and callers don't resolve AppLocalizations at arm time.
  final String Function(AppLocalizations) bannerLabel;

  /// The screens to put back on a capture (and on Cancel), bottom first, the
  /// asking screen last; empty to stay put. [TrackCapture.goBack] pushes them.
  ///
  /// Put back, not popped to: arming drops back to the home browser, so the
  /// asking route is gone by the time a row is tapped, and so is any route it
  /// was opened over. A screen that sat two deep (the Seeds page over the
  /// Auto DJ screen) lists both, so Back from it leads where it led before
  /// the pick; so does the home, which opens the player again under them
  /// when arming closed it ([TrackCapture.onHomeCovered]). Their state has
  /// to live somewhere outside the widgets — SonicPathState for the path,
  /// the audio handler's seeds for the Seeds page.
  ///
  /// Empty when there is nothing to go back TO. Sonic path was mid-setup and
  /// the user has to see the result, but the Auto DJ button in the player bar
  /// asks its question from a sheet over the browser — pushing the Auto DJ
  /// screen after the pick would land the user on a settings page they never
  /// opened, on top of the music they just started.
  final List<WidgetBuilder> returnStack;

  final void Function(DisplayItem) onPicked;

  TrackCaptureRequest(
      {required this.server,
      required this.bannerLabel,
      this.returnStack = const [],
      required this.onPicked});
}

/// App-wide browse-to-pick mode. Armed by the sonic path setup cards, the
/// Auto DJ start's pick from the library and the Seeds page's Add song;
/// checked at the top of the browser / album-detail tap handlers BEFORE
/// tap-behavior dispatch, so a pick can never queue (or play-from-here)
/// the tapped track. [active] doubles as the home banner's listenable.
class TrackCapture {
  TrackCapture._();

  static final ValueNotifier<TrackCaptureRequest?> active =
      ValueNotifier(null);

  static void arm(TrackCaptureRequest req) => active.value = req;

  static void cancel() => active.value = null;

  /// The request a tap would run against — read this BEFORE [tryCapture],
  /// which clears it on a capture.
  static TrackCaptureRequest? get pending => active.value;

  /// Runs the armed request against a tapped row. Only a server track on
  /// the request's server is captured; the request stays armed on a
  /// rejection so the user can keep browsing to a valid row.
  static CaptureResult tryCapture(DisplayItem item) {
    final req = active.value;
    if (req == null) return CaptureResult.pass;
    if (item.type != 'file' ||
        item.data == null ||
        item.server?.localname != req.server.localname) {
      return CaptureResult.rejected;
    }
    active.value = null;
    req.onPicked(item);
    return CaptureResult.captured;
  }

  /// Told when a way back ([goBack]) has covered the home: the screens are
  /// back over it and the top one has slid in, or was popped before it had.
  /// The home's cue to put back, out of sight, what isn't a route: the
  /// player it closed to show the library for [req]. Set by the home.
  static void Function(TrackCaptureRequest req)? onHomeCovered;

  /// Takes the user back to where [req] was armed, once a row lands or the
  /// banner's Cancel is tapped: pushes its [TrackCaptureRequest.returnStack]
  /// onto [navigator], bottom first. Only the top screen slides in, as the
  /// asking screen did when it was opened; the ones under it are back at
  /// once, and leave as any page does. [onHomeCovered] is told once the top
  /// one has slid in. Every way back goes through here: the browser's and
  /// the album page's taps, and the banner's Cancel ([cancelAndGoBack]).
  static void goBack(NavigatorState navigator, TrackCaptureRequest req) {
    final stack = req.returnStack;
    if (stack.isEmpty) return;
    for (final under in stack.take(stack.length - 1)) {
      navigator.push(_PutBackRoute<void>(builder: under));
    }
    navigator.push(_PutBackOnTopRoute<void>(
        builder: stack.last, onCovered: () => onHomeCovered?.call(req)));
  }

  /// The banner's Cancel: disarms the pick and takes the same way back as a
  /// row that lands ([goBack]). With nothing armed, as under a banner drawn
  /// for a pick that is already gone, it does nothing.
  static void cancelAndGoBack(NavigatorState navigator) {
    final req = active.value;
    if (req == null) return;
    cancel();
    goBack(navigator, req);
  }
}

/// A screen [TrackCapture.goBack] puts back under the one that slides in:
/// there at once, with no transition of its own, and popped as any page is.
class _PutBackRoute<T> extends MaterialPageRoute<T> {
  _PutBackRoute({required super.builder});

  @override
  Duration get transitionDuration => Duration.zero;
}

/// The asking screen [TrackCapture.goBack] puts back on top: it slides in
/// as any page does, and runs [onCovered] once that is done, or cut short
/// by a pop. Timed by the push's own ticker: [animation] reads as complete
/// during the first frame, while heroes are measured.
class _PutBackOnTopRoute<T> extends MaterialPageRoute<T> {
  _PutBackOnTopRoute({required super.builder, required this.onCovered});

  final VoidCallback onCovered;

  @override
  TickerFuture didPush() => super.didPush()..whenCompleteOrCancel(onCovered);
}

/// Shared toast for a rejected capture tap — names the server the pick has
/// to come from (local files and other servers can't seed the path).
void showCaptureRejectedToast(BuildContext context) {
  final req = TrackCapture.active.value;
  if (req == null) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
    content: Text(
        AppLocalizations.of(context).pathPickOnServer(req.server.localname)),
    behavior: SnackBarBehavior.floating,
  ));
}
