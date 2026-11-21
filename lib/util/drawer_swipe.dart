/// Whether the app drawer opens from an edge swipe.
///
/// Android's gesture navigation keeps the screen's side edges for its Back
/// swipe and reports them as system gesture insets. A drawer edge drag there
/// catches that swipe too: it pulls the drawer open, and the root PopScope
/// then spends Back on closing it, so Back stops going back. Where the system
/// keeps the drawer's edge, the drawer opens from the hamburger only. iOS and
/// 3-button Android report no side insets, so they keep the swipe.
library;

import 'package:material_ui/material_ui.dart';

/// [Scaffold.drawerEnableOpenDragGesture] for a start-side drawer under
/// [context]: false when the system keeps that edge (the left one, or the
/// right one in a right-to-left language).
bool drawerEdgeSwipeAllowed(BuildContext context) {
  final insets = MediaQuery.systemGestureInsetsOf(context);
  final edge = switch (Directionality.of(context)) {
    TextDirection.ltr => insets.left,
    TextDirection.rtl => insets.right,
  };
  return edge == 0;
}
