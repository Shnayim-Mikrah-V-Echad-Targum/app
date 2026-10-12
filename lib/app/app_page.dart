import 'package:flutter/material.dart';

/// A page of the app's router: a [MaterialPage], with the theme's
/// transitions (docs/DESIGN_SYSTEM.md §8), whose back swipe only the page on
/// show answers.
///
/// Android's predictive back gesture goes to every page whose transition
/// listens for it and that is the top one of its own navigator. Each tab
/// keeps a navigator of its own, so without this the top page of a tab out
/// of sight, or of a tab beneath a page over the tabs, or beneath a dialog,
/// would be swiped away too, unseen, instead of (or as well as) the one on
/// show. Such a page takes no back gesture, which goes to the page on show,
/// or to the app's Back when none takes it.
class AppPage<T> extends MaterialPage<T> {
  const AppPage({super.key, super.name, required super.child});

  @override
  Route<T> createRoute(BuildContext context) => _AppPageRoute<T>(page: this);
}

/// As the framework's own route for a [MaterialPage].
class _AppPageRoute<T> extends PageRoute<T> with MaterialRouteTransitionMixin<T> {
  _AppPageRoute({required AppPage<T> page}) : super(settings: page, allowSnapshotting: page.allowSnapshotting);

  AppPage<T> get _page => settings as AppPage<T>;

  @override
  Widget buildContent(BuildContext context) => _page.child;

  @override
  bool get maintainState => _page.maintainState;

  @override
  bool get fullscreenDialog => _page.fullscreenDialog;

  @override
  String get debugLabel => '${super.debugLabel}(${_page.name})';

  @override
  bool get popGestureEnabled => super.popGestureEnabled && _onShow;

  /// Whether this page is the one on show: its tickers run (a hidden tab's,
  /// and a page covered by another, have them stopped), and every route its
  /// navigator lies within is the top one of its own navigator (no dialog,
  /// sheet or page over the tabs covers it).
  bool get _onShow {
    final context = subtreeContext;
    if (context == null || !TickerMode.getValuesNotifier(context).value.enabled) return false;
    for (var navigator = this.navigator; navigator != null;) {
      final outer = ModalRoute.of(navigator.context);
      if (outer == null) break;
      if (!outer.isCurrent) return false;
      navigator = outer.navigator;
    }
    return true;
  }
}
