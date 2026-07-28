import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../objects/display_item.dart';
import '../objects/server.dart';

/// Outcome of a tap while capture may be armed: [pass] — not armed, run the
/// normal tap handling; [captured] — consumed, the pick landed; [rejected]
/// — consumed, but the row can't seed the path (wrong server / local file).
enum CaptureResult { pass, captured, rejected }

/// One armed "pick a song from the library" request (the webapp's
/// songCapture): which server the pick must come from, which endpoint card
/// it fills (drives the banner copy), and where the picked row goes.
class TrackCaptureRequest {
  final Server server;
  final bool isStart;
  final void Function(DisplayItem) onPicked;

  TrackCaptureRequest(
      {required this.server, required this.isStart, required this.onPicked});
}

/// App-wide browse-to-pick mode. Armed by the sonic path setup cards;
/// checked at the top of the browser / album-detail tap handlers BEFORE
/// tap-behavior dispatch, so a pick can never queue (or play-from-here)
/// the tapped track. [active] doubles as the home banner's listenable.
class TrackCapture {
  TrackCapture._();

  static final ValueNotifier<TrackCaptureRequest?> active =
      ValueNotifier(null);

  static void arm(TrackCaptureRequest req) => active.value = req;

  static void cancel() => active.value = null;

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
