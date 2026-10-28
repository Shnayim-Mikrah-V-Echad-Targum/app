import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// The tabs that show a week and its haftarah within themselves, at
/// 'week/:id' and 'haftarah/:id', so their navigation bar stays.
const weekTabs = {'/today', '/parsha', '/progress'};

/// [page] ('week/…' or 'haftarah/…') within [tab]; on its own, over the
/// tabs, when [tab] has no such pages.
String _inTab(String? tab, String page) => weekTabs.contains(tab) ? '$tab/$page' : '/$page';

/// The haftarah of the week [weekId], within the tab [context] is shown in.
/// From a page shown over the tabs (a week opened from a notification, say),
/// it opens over them too.
String haftarahPath(BuildContext context, String weekId) {
  final shell = StatefulNavigationShell.maybeOf(context);
  return _inTab(shell?.route.branches[shell.currentIndex].defaultRoute?.path, 'haftarah/$weekId');
}

/// The policy [doc] ('privacy', 'guidelines'…) from [context], a page that
/// can be shown within a tab or over them (the account, a new discussion):
/// within the tab [context] is shown in, so that its navigation bar or rail
/// stays; on its own from a page shown over the tabs (signing in from the
/// welcome, a question asked over the reader), which can't have a tab's page
/// above it.
///
/// Within a tab, the address names the page beneath, as the stack has it, so
/// that a reload or a shared link puts back the same page under the policy:
/// the account's own in the Account tab ('/account/legal/privacy'), About's
/// in Settings, and otherwise Community's (a new discussion, or signing in
/// before one).
String policyPath(BuildContext context, String doc) {
  final shell = StatefulNavigationShell.maybeOf(context);
  if (shell == null) return '/legal/$doc';
  return switch (shell.route.branches[shell.currentIndex].defaultRoute?.path) {
    '/account' => '/account/legal/$doc',
    '/settings' => '/settings/about/legal/$doc',
    _ => '/community/legal/$doc',
  };
}

/// Opens [location], a page within a tab, from [context]: pushed within the
/// tab [context] is shown in, so it goes back there. A page shown over the
/// tabs (a week opened from a notification, say) can't have a tab's page
/// above it, so from there it goes to the page in its own tab instead.
void openTabPage(BuildContext context, String location) {
  if (StatefulNavigationShell.maybeOf(context) == null) {
    context.go(location);
  } else {
    context.push(location);
  }
}

/// Replaces the page on top, which is shown over the tabs (the reader), with
/// [page] ('week/…' or 'haftarah/…'). It opens within the tab beneath, so
/// the navigation bar comes back. Above another page shown over the tabs it
/// stays over them too; with nothing beneath (a reader opened from a link),
/// it opens within Today, with a way back to it.
void replaceWithWeekPage(BuildContext context, String page) {
  final router = GoRouter.of(context);
  final matches = router.routerDelegate.currentConfiguration.matches;
  final beneath = matches.length > 1 ? matches[matches.length - 2] : null;
  if (beneath == null) {
    router.go('/today/$page');
  } else if (beneath case ShellRouteMatch(route: final StatefulShellRoute shell)) {
    final branch = shell.branches.firstWhere((b) => b.navigatorKey == beneath.navigatorKey);
    router.pushReplacement(_inTab(branch.defaultRoute?.path, page));
  } else {
    router.pushReplacement('/$page');
  }
}
