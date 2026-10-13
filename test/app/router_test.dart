import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/features/about/about_screen.dart';
import 'package:shnayim_mikra/features/about/guide_screen.dart';
import 'package:shnayim_mikra/features/about/legal_screen.dart';
import 'package:shnayim_mikra/features/about/sources_screen.dart';
import 'package:shnayim_mikra/features/community/ui/account_screen.dart';
import 'package:shnayim_mikra/features/community/ui/community_screen.dart';
import 'package:shnayim_mikra/features/onboarding/onboarding_screen.dart';
import 'package:shnayim_mikra/features/progress/progress_screen.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/features/settings/screens/accessibility_settings_screen.dart';
import 'package:shnayim_mikra/features/settings/screens/settings_screen.dart';
import 'package:shnayim_mikra/features/today/today_screen.dart';
import 'package:shnayim_mikra/services/feedback.dart';
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
      ('/community/account/legal/privacy', LegalScreen, 'Privacy', 3, AccountScreen),
      ('/settings/account/legal/privacy', LegalScreen, 'Privacy', 4, AccountScreen),
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

    for (final (path, tab) in [
      ('/community/legal/term', 3),
      ('/settings/accessibility/legal/term', 4),
      ('/settings/account/legal/term', 4),
      ('/settings/about/legal/term', 4),
    ]) {
      testWidgets('$path, a policy that does not exist, says so within its tab', (tester) async {
        final router = await _pump(tester);
        router.go(path);
        await _settle(tester);
        expect(find.text('Page not found'), findsOneWidget);
        expect(find.byType(LegalScreen), findsNothing, reason: 'no policy stands in for the one asked for');
        expect(_tabShown(), tab);
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
      ('/community/account/legal/privacy', '/legal/privacy', LegalScreen),
      ('/settings/account/legal/privacy', '/legal/privacy', LegalScreen),
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

  group('a tab chosen', () {
    /// The opacity [finder]'s widget is painted at: the product of the fades
    /// above it.
    double opacityOf(WidgetTester tester, Finder finder) {
      var opacity = 1.0;
      tester.element(finder).visitAncestorElements((e) {
        final w = e.widget;
        if (w is FadeTransition) opacity *= w.opacity.value;
        if (w is Opacity) opacity *= w.opacity;
        return true;
      });
      return opacity;
    }

    StatefulNavigationShell shell(WidgetTester tester) =>
        tester.widget<StatefulNavigationShell>(find.byType(StatefulNavigationShell));

    testWidgets('fades in over 150 ms, and the tab left goes at once', (tester) async {
      await _pump(tester);
      expect(opacityOf(tester, find.byType(TodayScreen)), 1, reason: 'the first tab shown is simply there');
      for (final (branch, page, left) in [
        (2, find.byType(ProgressScreen), find.byType(TodayScreen)),
        (0, find.byType(TodayScreen), find.byType(ProgressScreen)),
      ]) {
        shell(tester).goBranch(branch);
        await tester.pump();
        expect(find.byType(TodayScreen, skipOffstage: false), findsOneWidget);
        expect(left.hitTestable(), findsNothing);
        await tester.pump(const Duration(milliseconds: 50));
        expect(opacityOf(tester, page), inExclusiveRange(0, 1));
        await tester.pump(const Duration(milliseconds: 150));
        expect(opacityOf(tester, page), 1);
      }
    }, variant: TargetPlatformVariant({TargetPlatform.android, TargetPlatform.windows, TargetPlatform.linux}));

    testWidgets('is there at once on Apple platforms', (tester) async {
      await _pump(tester);
      shell(tester).goBranch(2);
      await tester.pump();
      expect(opacityOf(tester, find.byType(ProgressScreen)), 1);
    }, variant: TargetPlatformVariant({TargetPlatform.iOS, TargetPlatform.macOS}));

    testWidgets('is there at once with Reduce Motion', (tester) async {
      await _pump(tester, settings: const AppSettings(onboardingComplete: true, reduceMotion: true));
      shell(tester).goBranch(2);
      await tester.pump();
      expect(opacityOf(tester, find.byType(ProgressScreen)), 1);
    });

    testWidgets("is there at once with the system's Reduce Motion", (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await _pump(tester);
      shell(tester).goBranch(2);
      await tester.pump();
      expect(opacityOf(tester, find.byType(ProgressScreen)), 1);
    });

    test('fades in a browser whatever its host, but not in an iOS or macOS app', () {
      for (final platform in TargetPlatform.values) {
        expect(tabsFadeOn(platform, web: true), isTrue, reason: '$platform, in a browser');
      }
      expect(tabsFadeOn(TargetPlatform.iOS, web: false), isFalse);
      expect(tabsFadeOn(TargetPlatform.macOS, web: false), isFalse);
      for (final platform in [TargetPlatform.android, TargetPlatform.windows, TargetPlatform.linux]) {
        expect(tabsFadeOn(platform, web: false), isTrue, reason: '$platform');
      }
    });

    group('on a desktop', () {
      testWidgets('fades in too', (tester) async {
        await _pump(tester, size: const Size(1024, 800));
        shell(tester).goBranch(2);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(opacityOf(tester, find.byType(ProgressScreen)), inExclusiveRange(0, 1));
        await tester.pumpAndSettle();
      }, variant: TargetPlatformVariant.only(TargetPlatform.windows));

      testWidgets('is there at once while a status message is on show, which carries across unbroken', (tester) async {
        await _pump(tester, size: const Size(1024, 800));
        showStatus(tester.element(find.byType(TodayScreen)), 'Logged');
        await tester.pumpAndSettle();
        expect(find.text('Logged'), findsOneWidget);

        shell(tester).goBranch(2);
        await tester.pump();
        final message = find.descendant(of: find.byType(ProgressScreen), matching: find.text('Logged'));
        expect(message, findsOneWidget, reason: 'shown by the page on show, as each page shows it');
        expect(opacityOf(tester, find.byType(ProgressScreen)), 1);
        expect(opacityOf(tester, message), 1);
        await tester.pump(const Duration(milliseconds: 50));
        expect(opacityOf(tester, message), 1);

        // Once it has gone, the tabs fade in again.
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
        expect(find.text('Logged'), findsNothing);
        shell(tester).goBranch(0);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(opacityOf(tester, find.byType(TodayScreen)), inExclusiveRange(0, 1));
        await tester.pumpAndSettle();
      }, variant: TargetPlatformVariant.only(TargetPlatform.windows));
    });
  });
}
