import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/features/about/about_screen.dart';
import 'package:shnayim_mikra/features/about/guide_screen.dart';
import 'package:shnayim_mikra/features/about/legal_screen.dart';
import 'package:shnayim_mikra/features/about/sources_screen.dart';
import 'package:shnayim_mikra/features/community/ui/community_screen.dart';
import 'package:shnayim_mikra/features/onboarding/onboarding_screen.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/features/settings/screens/accessibility_settings_screen.dart';
import 'package:shnayim_mikra/features/settings/screens/settings_screen.dart';
import 'package:shnayim_mikra/features/today/today_screen.dart';
import 'package:shnayim_mikra/ui/widgets/common.dart';

import '../helpers.dart';

/// Friday of Bereshit 5787.
final _now = DateTime(2026, 10, 9, 11);

/// The app on a phone, for its navigation bar, or on a desktop, for its
/// rail; onboarded unless [settings] say otherwise.
Future<GoRouter> _pump(
  WidgetTester tester, {
  Size size = const Size(412, 915),
  AppSettings settings = const AppSettings(onboardingComplete: true),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final c = await pumpApp(tester, settings: settings, now: _now);
  await tester.pumpAndSettle();
  return c.read(routerProvider);
}

/// Settles a page that loads its texts from assets, which takes real time.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  for (var i = 0; i < 20 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

/// A page's own heading, in its body: a policy's title.
Finder _pageHeading(String text) => find.widgetWithText(PageBody, text);

final _home = find.widgetWithIcon(IconButton, Icons.home_outlined);

/// The tab whose navigation bar is on show, or null for none: a page over
/// the tabs covers it.
int? _tabShown() {
  final bar = find.byType(NavigationBar);
  return bar.evaluate().isEmpty ? null : (bar.evaluate().single.widget as NavigationBar).selectedIndex;
}

void main() {
  group('within the tabs', () {
    // Each copy of the guide, the sources and a policy, the tab it is in, and
    // the page it goes back to.
    for (final (path, page, heading, tab, parent) in [
      ('/today/guide', GuideScreen, null, 0, TodayScreen),
      ('/community/legal/privacy', LegalScreen, 'Privacy', 3, CommunityScreen),
      ('/community/legal/guidelines', LegalScreen, 'Community guidelines', 3, CommunityScreen),
      ('/settings/guide', GuideScreen, null, 4, SettingsScreen),
      ('/settings/accessibility/legal/accessibility', LegalScreen, 'Accessibility statement', 4,
          AccessibilitySettingsScreen),
      ('/settings/about/sources', SourcesScreen, null, 4, AboutScreen),
      ('/settings/about/legal/privacy', LegalScreen, 'Privacy', 4, AboutScreen),
      ('/settings/about/legal/terms', LegalScreen, 'Terms of use', 4, AboutScreen),
      ('/settings/about/legal/guidelines', LegalScreen, 'Community guidelines', 4, AboutScreen),
      ('/settings/about/legal/accessibility', LegalScreen, 'Accessibility statement', 4, AboutScreen),
    ]) {
      testWidgets('$path keeps the navigation bar, and goes back to the page beneath', (tester) async {
        final router = await _pump(tester);
        router.go(path);
        await _settle(tester);
        expect(find.byType(page), findsOneWidget);
        if (heading != null) expect(_pageHeading(heading), findsOneWidget);
        expect(_tabShown(), tab);
        expect(_home, findsNothing, reason: 'the page beneath is the way back');

        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.byType(parent), findsOneWidget);
        expect(_tabShown(), tab);
      });
    }

    for (final path in ['/settings/guide', '/settings/about/legal/privacy']) {
      testWidgets('$path keeps the rail on a desktop', (tester) async {
        final router = await _pump(tester, size: const Size(1280, 800));
        router.go(path);
        await _settle(tester);
        expect(find.byType(path.endsWith('guide') ? GuideScreen : LegalScreen), findsOneWidget);
        expect(tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex, 4);
      });
    }

    for (final path in [
      '/community/legal/term',
      '/settings/accessibility/legal/term',
      '/settings/about/legal/term',
    ]) {
      testWidgets('$path, a policy that does not exist, says so within its tab', (tester) async {
        final router = await _pump(tester);
        router.go(path);
        await _settle(tester);
        expect(find.text('Page not found'), findsOneWidget);
        expect(find.byType(LegalScreen), findsNothing, reason: 'no policy stands in for the one asked for');
        expect(_tabShown(), isNotNull);
      });
    }
  });

  group('on their own, over the tabs', () {
    const pages = [('/guide', GuideScreen), ('/sources', SourcesScreen), ('/legal/privacy', LegalScreen)];
    for (final (path, page) in pages) {
      testWidgets('$path still opens, with a way home', (tester) async {
        final router = await _pump(tester);
        router.go(path);
        await _settle(tester);
        expect(find.byType(page), findsOneWidget);
        expect(_tabShown(), isNull);
        expect(_home, findsOneWidget);
      });
    }

    testWidgets('/legal/term, a policy that does not exist, says so', (tester) async {
      final router = await _pump(tester);
      router.go('/legal/term');
      await _settle(tester);
      expect(find.text('Page not found'), findsOneWidget);
      expect(find.byType(LegalScreen), findsNothing);
    });
  });

  group('before onboarding', () {
    const firstVisit = AppSettings();

    const pages = [('/guide', GuideScreen), ('/sources', SourcesScreen), ('/legal/privacy', LegalScreen)];
    for (final (path, page) in pages) {
      testWidgets('$path is open', (tester) async {
        final router = await _pump(tester, settings: firstVisit);
        router.go(path);
        await _settle(tester);
        expect(find.byType(page), findsOneWidget);
        expect(router.state.uri.path, path);
      });
    }

    // The tabs wait for onboarding, so their copies lead to the pages of
    // their own; the addresses the sources and policies had in About among
    // them.
    for (final (path, own, page) in [
      ('/today/guide', '/guide', GuideScreen),
      ('/settings/guide', '/guide', GuideScreen),
      ('/settings/about/sources', '/sources', SourcesScreen),
      ('/settings/about/legal/privacy', '/legal/privacy', LegalScreen),
      ('/settings/accessibility/legal/accessibility', '/legal/accessibility', LegalScreen),
      ('/community/legal/guidelines', '/legal/guidelines', LegalScreen),
    ]) {
      testWidgets('$path leads to $own, without the tabs', (tester) async {
        final router = await _pump(tester, settings: firstVisit);
        router.go(path);
        await _settle(tester);
        expect(find.byType(page), findsOneWidget);
        expect(router.state.uri.path, own);
        expect(_tabShown(), isNull);
      });
    }

    for (final path in ['/settings', '/settings/about', '/community/forum/guide', '/settings/about/sources/x']) {
      testWidgets('$path waits for onboarding', (tester) async {
        final router = await _pump(tester, settings: firstVisit);
        router.go(path);
        await _settle(tester);
        expect(find.byType(OnboardingScreen), findsOneWidget);
        expect(router.state.uri.path, '/welcome');
      });
    }
  });
}
