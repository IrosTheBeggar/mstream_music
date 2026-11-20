// The Peer Recommendations page's colours (mStream
// docs/peer-recommendations-plan.md §4.2 PH3 and §5.1), read from the active
// VelvetColors palette so a theme switch repaints them.
//
// The tiles and circles are drawn from the hue the server stamps on each lead
// and peer: clients never compute the hue themselves (§5.1), they only turn it
// into a colour here. The rest are the approved boards' tokens: the Light board
// darkens the ring, the ink and the online dot, because amber and the app's
// light green sit under 3:1 on its light ground.

import 'package:material_ui/material_ui.dart';

import '../screens/discovery/keep_copy_ui.dart' show keepInkOnPage;
import '../theme/velvet_theme.dart';

/// The page ground is light (the Light palette). It is the theme's own
/// brightness, the one the app's ThemeData is built from, read without a
/// context so painters can use it too.
bool peerLightGround() => VelvetColors.brightness == Brightness.light;

/// A server hue as the 0–359 HSLColor takes, the way the webapp's `hueOf`
/// folds one (webapp/alpha/peer-recs.js).
double _hue(int hue) => (hue % 360).toDouble();

Color _hsl(int hue, double s, double l, {double alpha = 1}) =>
    HSLColor.fromAHSL(alpha, _hue(hue), s, l).toColor();

/// A generated tile's field: hsl(H 22% 24%) on a dark page, hsl(H 28% 86%) on
/// a light one (§5.1).
Color peerTileField(int hue, {required bool light}) =>
    light ? _hsl(hue, .28, .86) : _hsl(hue, .22, .24);

/// A generated tile's letter: hsl(H 30% 72%) on a dark page, hsl(H 30% 32%) on
/// a light one (§5.1).
Color peerTileInk(int hue, {required bool light}) =>
    light ? _hsl(hue, .30, .32) : _hsl(hue, .30, .72);

/// A peer circle on the strip while the peer is online. The same in every
/// theme.
Color peerCircleOnline(int hue) => _hsl(hue, .55, .72);

/// A peer circle while the peer is offline.
Color peerCircleOffline(int hue) => _hsl(hue, .30, .44);

/// A peer circle while its database is being added: the online colour at
/// 35 % alpha.
Color peerCircleAdding(int hue) => _hsl(hue, .55, .72, alpha: .35);

/// The selected circle's ring and the dashed "+" circle's ink.
Color peerRing() =>
    peerLightGround() ? VelvetColors.textPrimary : VelvetColors.primary;

/// The All circle's glyph, a live card's title and the band's progress: the Keep
/// ink on the page in a dark theme (amber in Dark, Velvet's blue in Velvet).
Color peerInk() =>
    peerLightGround() ? VelvetColors.textPrimary : keepInkOnPage();

/// The online dot on a peer circle. The Light board's green, because the
/// app's light success green is too pale on the light ground.
Color peerOnlineDot() =>
    peerLightGround() ? const Color(0xFF16A34A) : VelvetColors.success;

/// The All circle's fill.
Color peerAllFill() =>
    peerLightGround() ? VelvetColors.card : VelvetColors.raised;

/// The shadow under the circles and the play buttons: black at 28 % on a
/// light page, 50 % on a dark one.
Color peerShadow() =>
    peerLightGround() ? const Color(0x47000000) : const Color(0x80000000);
