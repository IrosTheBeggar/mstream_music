// What covers the browser, for the browser's pages that must know when they
// are out of sight (mStream docs/peer-recommendations-plan.md §2 item 14: the
// Peer Recommendations page stops its preview when it is covered).

import 'package:material_ui/material_ui.dart';

/// The app navigator's observer (main.dart). It is a RouteObserver for
/// RouteAware widgets, and it also counts the page routes on the navigator.
/// Flutter's RouteObserver only tells a route about a page route pushed
/// straight over it, so a page pushed over a sheet (Find similar from the
/// seeds sheet) would go unseen. The count sees it.
class AppRouteObserver extends RouteObserver<PageRoute<dynamic>> {
  final List<Route<dynamic>> _pages = [];

  /// A page route is over the home (drawer screens, Auto DJ, settings, Find
  /// similar), pushed straight over it or over a sheet or dialog. A modal
  /// bottom sheet or a dialog is a PopupRoute and never counts.
  final ValueNotifier<bool> pageRouteOverHome = ValueNotifier<bool>(false);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    // A navigator's first route. A new navigator starts the count again.
    if (previousRoute == null) _pages.clear();
    _add(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPop(route, previousRoute);
    _drop(route);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didRemove(route, previousRoute);
    _drop(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    if (oldRoute != null) _pages.remove(oldRoute);
    if (newRoute != null) {
      _add(newRoute);
    } else {
      _sync();
    }
  }

  void _add(Route<dynamic> route) {
    if (route is PageRoute && !_pages.contains(route)) _pages.add(route);
    _sync();
  }

  void _drop(Route<dynamic> route) {
    _pages.remove(route);
    _sync();
  }

  void _sync() => pageRouteOverHome.value = _pages.length > 1;

  /// Forget every route (tests: a test's navigator is torn down without
  /// telling its observers).
  @visibleForTesting
  void debugReset() {
    _pages.clear();
    pageRouteOverHome.value = false;
  }
}

/// The app's one route observer, on main.dart's navigator.
final AppRouteObserver appRouteObserver = AppRouteObserver();

/// The player panel is expanded (Now Playing covers the browser); set by
/// PlayerPanelState.
final ValueNotifier<bool> nowPlayingExpanded = ValueNotifier<bool>(false);

/// The app drawer is open; set by main.dart's outer Scaffold. It slides over
/// the browser, so the browser's pages count it as a cover.
final ValueNotifier<bool> appDrawerOpen = ValueNotifier<bool>(false);
