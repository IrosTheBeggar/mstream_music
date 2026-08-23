import 'package:flutter/material.dart';

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

  /// The screen to re-push on a capture (and on Cancel), or null to stay put.
  ///
  /// Re-push, not pop: arming drops all the way back to the home browser, so
  /// the asking route is gone by the time a row is tapped. Its state has to
  /// live somewhere outside the widget — SonicPathState for the path,
  /// AutoDJManager for the DJ seed.
  ///
  /// Null when there is nothing to go back TO. Sonic path was mid-setup and
  /// the user has to see the result, but the Auto DJ button in the player bar
  /// asks its question from a sheet over the browser — pushing the Auto DJ
  /// screen after the pick would land the user on a settings page they never
  /// opened, on top of the music they just started.
  final WidgetBuilder? returnScreen;

  final void Function(DisplayItem) onPicked;

  TrackCaptureRequest(
      {required this.server,
      required this.bannerLabel,
      this.returnScreen,
      required this.onPicked});
}

/// App-wide browse-to-pick mode. Armed by the sonic path setup cards and the
/// Auto DJ seed card;
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
