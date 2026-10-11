import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/app/routes.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/features/about/about_screen.dart';
import 'package:shnayim_mikra/features/about/guide_screen.dart';
import 'package:shnayim_mikra/features/about/legal_screen.dart';
import 'package:shnayim_mikra/features/about/sources_screen.dart';
import 'package:shnayim_mikra/features/community/data/demo_forum_repository.dart';
import 'package:shnayim_mikra/features/community/data/forum_repository.dart';
import 'package:shnayim_mikra/features/community/data/models.dart';
import 'package:shnayim_mikra/features/community/ui/account_screen.dart';
import 'package:shnayim_mikra/features/community/ui/community_screen.dart';
import 'package:shnayim_mikra/features/community/ui/forum_screen.dart';
import 'package:shnayim_mikra/features/community/ui/moderation_screen.dart';
import 'package:shnayim_mikra/features/community/ui/thread_screen.dart';
import 'package:shnayim_mikra/features/parsha/browse_screen.dart';
import 'package:shnayim_mikra/features/parsha/week_overview_screen.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikra/features/progress/progress_screen.dart';
import 'package:shnayim_mikra/features/reader/haftarah_screen.dart';
import 'package:shnayim_mikra/features/reader/reader_screen.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/features/settings/screens/accessibility_settings_screen.dart';
import 'package:shnayim_mikra/features/settings/screens/display_settings_screen.dart';
import 'package:shnayim_mikra/features/settings/screens/settings_screen.dart';
import 'package:shnayim_mikra/features/today/today_screen.dart';
import 'package:shnayim_mikra/services/notifications.dart';

import '../helpers.dart';

/// Friday of Bereshit 5787.
final _now = DateTime(2026, 10, 9, 11);
const _week = '/week/5787:1';

/// A backend whose forums don't load until it is [online].
class _Offline extends DemoForumRepository {
  bool online = false;

  @override
  Future<List<Forum>> forums() async => online ? super.forums() : throw Exception('offline');
}

/// A backend on a server, whose posts reach the community.
class _Server extends DemoForumRepository {
  @override
  bool get isDemo => false;
}

final _home = find.widgetWithIcon(IconButton, Icons.home_outlined);

/// The app on a phone, for its navigation bar, on [_now].
Future<GoRouter> _pump(
  WidgetTester tester, {
  NotificationService? notifications,
  ForumRepository? forums,
  ProgressState? progress,
}) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final c = await pumpApp(tester, now: _now, notifications: notifications, forums: forums, progress: progress);
  await tester.pumpAndSettle();
  return c.read(routerProvider);
}

/// Settles a page that loads its texts from assets, which takes real time.
Future<void> _loadTexts(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  for (var i = 0; i < 20 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

void main() {
  int? selectedTab(WidgetTester tester) => tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

  Future<void> goBack(WidgetTester tester) async {
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
  }

  group('a notification', () {
    for (final (payload, scheduledBy) in [('/today/week/5787:1', 'this version'), (_week, 'an earlier version')]) {
      testWidgets('for a week, as $scheduledBy names it, opens it within Today, with the navigation bar and a way back',
          (tester) async {
        final notifications = NotificationService.disabled();
        final router = await _pump(tester, notifications: notifications);
        router.go('/settings');
        await tester.pumpAndSettle();

        notifications.handleTap(payload);
        await tester.pumpAndSettle();
        expect(find.byType(WeekOverviewScreen), findsOneWidget);
        expect(router.state.uri.toString(), '/today/week/5787:1');
        expect(find.byType(BackButton), findsOneWidget);
        expect(_home, findsNothing);
        expect(selectedTab(tester), 0);

        await goBack(tester);
        expect(find.byType(TodayScreen), findsOneWidget);
        expect(selectedTab(tester), 0);
      });
    }

    testWidgets('opens its page each time, even the same page as the last', (tester) async {
      final notifications = NotificationService.disabled();
      final router = await _pump(tester, notifications: notifications);
      notifications.handleTap(_week);
      await tester.pumpAndSettle();
      await goBack(tester);
      router.go('/progress');
      await tester.pumpAndSettle();

      notifications.handleTap(_week);
      await tester.pumpAndSettle();
      expect(find.byType(WeekOverviewScreen), findsOneWidget);
    });

    testWidgets('for a tab opens the tab in place', (tester) async {
      final notifications = NotificationService.disabled();
      final router = await _pump(tester, notifications: notifications);
      router.go('/settings');
      await tester.pumpAndSettle();

      notifications.handleTap('/today');
      await tester.pumpAndSettle();
      expect(find.byType(TodayScreen), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
      expect(selectedTab(tester), 0);
    });

    testWidgets('that launched the app opens within Today, once', (tester) async {
      final notifications = NotificationService.disabled()..launchRoute = '/today/week/5787:1';
      await _pump(tester, notifications: notifications);
      expect(find.byType(WeekOverviewScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(notifications.launchRoute, isNull);

      await goBack(tester);
      expect(find.byType(TodayScreen), findsOneWidget);
      expect(selectedTab(tester), 0);
    });
  });

  group('a page opened with nothing beneath it', () {
    testWidgets('such as a reloaded week, has a home button to Today', (tester) async {
      final router = await _pump(tester);
      router.go(_week);
      await tester.pumpAndSettle();
      expect(find.byType(WeekOverviewScreen), findsOneWidget);
      expect(find.byType(BackButton), findsNothing);
      expect(find.byTooltip('Today'), findsOneWidget);

      await tester.tap(_home);
      await tester.pumpAndSettle();
      expect(find.byType(TodayScreen), findsOneWidget);
      expect(selectedTab(tester), 0);
    });

    testWidgets('has the usual back button instead when opened from the app', (tester) async {
      final router = await _pump(tester);
      router.push(_week);
      await tester.pumpAndSettle();
      expect(find.byType(BackButton), findsOneWidget);
      expect(_home, findsNothing);
    });

    for (final link in ['/week/nonsense', '/read/nonsense/0', '/haftarah/nonsense', '/today/week/5787:99', '/legal/term']) {
      testWidgets('such as $link, which leads nowhere, says so, with a way to Today', (tester) async {
        final router = await _pump(tester);
        router.go(link);
        await _loadTexts(tester);
        expect(find.text('Page not found'), findsOneWidget);
        expect(find.text('This link leads nowhere in the app.'), findsOneWidget);
        expect(find.byType(LegalScreen), findsNothing, reason: 'no policy stands in for the one asked for');

        await tester.tap(find.text('Go to Today'));
        await tester.pumpAndSettle();
        expect(find.byType(TodayScreen), findsOneWidget);
      });
    }

    testWidgets('such as the guide, has a home button too', (tester) async {
      final router = await _pump(tester);
      router.go('/guide');
      await tester.pumpAndSettle();
      expect(find.byType(GuideScreen), findsOneWidget);
      expect(_home, findsOneWidget);
    });

    testWidgets('the Parsha tab has no home button', (tester) async {
      final router = await _pump(tester);
      router.go('/parsha');
      await tester.pumpAndSettle();
      expect(find.text('Parshat Bereshit'), findsOneWidget);
      expect(_home, findsNothing);
    });
  });

  testWidgets('a link that leads nowhere says so, with a way to Today', (tester) async {
    final router = await _pump(tester);
    router.go('/nope');
    await tester.pumpAndSettle();
    expect(find.text('Page not found'), findsOneWidget);
    expect(find.text('This link leads nowhere in the app.'), findsOneWidget);

    // The page's one action, a Tonal button (DESIGN_SYSTEM.md §6.22), in
    // primaryContainer: gold is never a button (§6.5).
    final button = find.ancestor(of: find.text('Go to Today'), matching: find.bySubtype<FilledButton>());
    final scheme = Theme.of(tester.element(button)).colorScheme;
    expect(
      tester.widget<Material>(find.descendant(of: button, matching: find.byType(Material)).first).color,
      scheme.primaryContainer,
    );
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.byType(TodayScreen), findsOneWidget);
  });

  group('a forum link', () {
    testWidgets('to a forum that does not exist says so instead of loading forever', (tester) async {
      final router = await _pump(tester);
      router.go('/community/forum/xyz');
      await tester.pumpAndSettle();
      expect(find.text('Page not found'), findsOneWidget);
      expect(find.text("This forum couldn't be found. It may have moved or closed."), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.tap(find.widgetWithText(FilledButton, 'All forums'));
      await tester.pumpAndSettle();
      expect(find.byType(CommunityScreen), findsOneWidget);
    });

    testWidgets('when the forums cannot load says so at once, and can try again', (tester) async {
      final forums = _Offline();
      final router = await _pump(tester, forums: forums);
      router.go('/community/forum/parsha');
      // Not after every retry: as soon as the first attempt fails.
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text("Couldn't reach the server. Check your connection and try again."), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.widgetWithText(TextButton, 'Try again'), findsOneWidget);
      expect(find.text('All forums'), findsOneWidget);

      forums.online = true;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.byType(ForumScreen), findsOneWidget);
      expect(find.text('Parshat HaShavua'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
    });
  });

  testWidgets('the guide opens over Settings and goes back to it', (tester) async {
    final router = await _pump(tester);
    router.go('/settings');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('How it works'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('How it works'));
    await tester.pumpAndSettle();
    expect(find.byType(GuideScreen), findsOneWidget);

    await goBack(tester);
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(selectedTab(tester), 4);
  });

  group('the policies and sources', () {
    testWidgets('open from About and go back to it', (tester) async {
      final router = await _pump(tester);
      router.go('/settings/about');
      await tester.pumpAndSettle();
      for (final (link, page) in [('Texts & sources', SourcesScreen), ('Privacy', LegalScreen)]) {
        await tester.ensureVisible(find.text(link));
        await tester.pumpAndSettle();
        await tester.tap(find.text(link));
        await tester.pumpAndSettle();
        expect(find.byType(page), findsOneWidget);
        await goBack(tester);
        expect(find.byType(AboutScreen), findsOneWidget);
      }
    });

    testWidgets('open from Community without leaving the Community tab', (tester) async {
      final router = await _pump(tester);
      router.go('/community/account');
      await tester.pumpAndSettle();
      // The link in the sentence under the sign-in button.
      final privacy = find.text('Privacy');
      await tester.ensureVisible(privacy);
      await tester.pumpAndSettle();
      await tester.tap(privacy);
      await tester.pumpAndSettle();
      expect(find.byType(LegalScreen), findsOneWidget);

      await goBack(tester);
      expect(find.byType(AccountScreen), findsOneWidget);
      expect(selectedTab(tester), 3);
    });

    testWidgets('keep their old addresses before onboarding too', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = await pumpApp(tester, settings: const AppSettings(), now: _now);
      await tester.pumpAndSettle();
      final router = c.read(routerProvider);
      router.go('/settings/about/legal/privacy');
      await tester.pumpAndSettle();
      expect(find.byType(LegalScreen), findsOneWidget);
      expect(find.text('Privacy'), findsOneWidget);

      router.go('/settings/about/sources');
      await tester.pumpAndSettle();
      expect(find.byType(SourcesScreen), findsOneWidget);

      router.go('/settings');
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsNothing, reason: 'the rest waits for onboarding');
    });

    testWidgets('keep their old addresses', (tester) async {
      final router = await _pump(tester);
      router.go('/community');
      await tester.pumpAndSettle();
      router.push('/settings/about/legal/guidelines');
      await tester.pumpAndSettle();
      expect(find.byType(LegalScreen), findsOneWidget);
      expect(find.text('Community guidelines'), findsOneWidget);
      await goBack(tester);
      expect(selectedTab(tester), 3);

      router.go('/settings/about/sources');
      await tester.pumpAndSettle();
      expect(find.byType(SourcesScreen), findsOneWidget);
      expect(_home, findsOneWidget);
    });
  });

  group('a week', () {
    String location(GoRouter router) => router.state.uri.toString();

    testWidgets('opened from Today stays in the Today tab, and so does its haftarah', (tester) async {
      final router = await _pump(tester);
      await tester.tap(find.widgetWithText(OutlinedButton, '0 of 7 aliyot'));
      await tester.pumpAndSettle();
      expect(find.byType(WeekOverviewScreen), findsOneWidget);
      expect(location(router), '/today/week/5787:1');
      expect(selectedTab(tester), 0);
      expect(find.byType(BackButton), findsOneWidget);

      final haftarah = find.widgetWithText(ListTile, 'Haftarah');
      await tester.ensureVisible(haftarah);
      await tester.pumpAndSettle();
      await tester.tap(haftarah);
      await _loadTexts(tester);
      expect(find.byType(HaftarahScreen), findsOneWidget);
      expect(location(router), '/today/haftarah/5787:1');
      expect(selectedTab(tester), 0);

      await goBack(tester);
      await goBack(tester);
      expect(find.byType(TodayScreen), findsOneWidget);
    });

    testWidgets('opened from Browse stays in the Parsha tab', (tester) async {
      final router = await _pump(tester);
      router.go('/parsha/browse');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ListTile, 'Noach'));
      await tester.pumpAndSettle();
      expect(find.text('Parshat Noach'), findsOneWidget);
      expect(selectedTab(tester), 1);

      await goBack(tester);
      expect(find.byType(BrowseScreen), findsOneWidget);
    });

    testWidgets('opened from Progress stays in the Progress tab', (tester) async {
      final router = await _pump(tester);
      router.go('/progress');
      await tester.pumpAndSettle();
      final noach = find.byTooltip(RegExp('^Noach'));
      await tester.ensureVisible(noach);
      await tester.pumpAndSettle();
      await tester.tap(noach);
      await tester.pumpAndSettle();
      expect(find.text('Parshat Noach'), findsOneWidget);
      expect(selectedTab(tester), 2);

      await goBack(tester);
      expect(find.byType(ProgressScreen), findsOneWidget);
    });

    testWidgets('opened within a tab goes to its discussion and back', (tester) async {
      final router = await _pump(tester);
      router.go('/parsha/week/5787:2');
      await tester.pumpAndSettle();
      final discuss = find.text("Discuss this week's parsha");
      await tester.ensureVisible(discuss);
      await tester.pumpAndSettle();
      await tester.tap(discuss);
      await tester.pumpAndSettle();
      expect(find.byType(ThreadScreen), findsOneWidget);
      expect(selectedTab(tester), 1);

      await goBack(tester);
      expect(find.text('Parshat Noach'), findsOneWidget);
    });

    Future<void> tapDiscuss(WidgetTester tester) async {
      final discuss = find.text("Discuss this week's parsha");
      await tester.ensureVisible(discuss);
      await tester.pumpAndSettle();
      await tester.tap(discuss);
      await tester.pumpAndSettle();
    }

    testWidgets('opened from a notification goes to its discussion and back, within Today', (tester) async {
      final notifications = NotificationService.disabled();
      await _pump(tester, notifications: notifications);
      notifications.handleTap('/today/week/5787:1');
      await tester.pumpAndSettle();
      await tapDiscuss(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(ThreadScreen), findsOneWidget);
      expect(selectedTab(tester), 0);

      await goBack(tester);
      expect(find.byType(WeekOverviewScreen), findsOneWidget);
    });

    testWidgets('shown over the tabs, from a link, goes to its discussion in the Community tab', (tester) async {
      final router = await _pump(tester);
      router.push(_week);
      await tester.pumpAndSettle();
      await tapDiscuss(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(ThreadScreen), findsOneWidget);
      expect(selectedTab(tester), 3);
    });

    Future<void> tapHaftarah(WidgetTester tester) async {
      final haftarah = find.widgetWithText(ListTile, 'Haftarah');
      await tester.ensureVisible(haftarah);
      await tester.pumpAndSettle();
      await tester.tap(haftarah);
      await _loadTexts(tester);
    }

    testWidgets('opened within Progress opens its haftarah within Progress', (tester) async {
      final router = await _pump(tester);
      router.go('/progress/week/5787:1');
      await tester.pumpAndSettle();
      await tapHaftarah(tester);
      expect(find.byType(HaftarahScreen), findsOneWidget);
      expect(location(router), '/progress/haftarah/5787:1');
      expect(selectedTab(tester), 2);
    });

    testWidgets('opened over the tabs, from a link, opens its haftarah over them too', (tester) async {
      final router = await _pump(tester);
      router.push(_week);
      await tester.pumpAndSettle();
      await tapHaftarah(tester);
      expect(find.byType(HaftarahScreen), findsOneWidget);
      expect(location(router), '/haftarah/5787:1');
      expect(find.byType(NavigationBar), findsNothing);
    });

    testWidgets("shown within a tab has a haftarah whose display sheet covers the tab's navigation bar too", (tester) async {
      final router = await _pump(tester);
      router.go('/today/haftarah/5787:1');
      await _loadTexts(tester);
      expect(find.byType(NavigationBar).hitTestable(), findsOneWidget);
      await tester.tap(find.byTooltip('Display settings'));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsOneWidget);
      expect(find.byType(NavigationBar).hitTestable(), findsNothing, reason: "under the sheet's scrim");

      final display = find.widgetWithText(ListTile, 'Display');
      await tester.scrollUntilVisible(display, 200,
          scrollable: find.descendant(of: find.byType(BottomSheet), matching: find.byType(Scrollable)));
      await tester.tap(display);
      await tester.pumpAndSettle();
      expect(find.byType(DisplaySettingsScreen), findsOneWidget);
      await goBack(tester);
      expect(find.byType(HaftarahScreen), findsOneWidget);
      expect(location(router), '/today/haftarah/5787:1');
    });

    testWidgets('and its haftarah have their own page in just the tabs that open weeks', (tester) async {
      final router = await _pump(tester);
      for (final (i, tab) in ['/today', '/parsha', '/progress', '/community', '/settings'].indexed) {
        for (final (page, screen) in [('week', WeekOverviewScreen), ('haftarah', HaftarahScreen)]) {
          router.go('$tab/$page/5787:1');
          await _loadTexts(tester);
          final inTab = weekTabs.contains(tab);
          expect(find.byType(screen), inTab ? findsOneWidget : findsNothing, reason: '$tab/$page');
          if (inTab) expect(selectedTab(tester), i);
        }
      }
    });
  });

  group('the reader', () {
    Future<void> backToTheWeek(WidgetTester tester) async {
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Back to the week'));
      await tester.pumpAndSettle();
    }

    testWidgets('goes back to the week it was opened from, rather than opening it again', (tester) async {
      await _pump(tester);
      await tester.tap(find.widgetWithText(OutlinedButton, '0 of 7 aliyot'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rishon · aliyah 1'));
      await _loadTexts(tester);
      expect(find.byType(ReaderScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing);

      await backToTheWeek(tester);
      expect(find.byType(WeekOverviewScreen), findsOneWidget);
      expect(selectedTab(tester), 0);
      await goBack(tester);
      expect(find.byType(TodayScreen), findsOneWidget);
    });

    testWidgets('opened from Today shows the week in its place, within Today', (tester) async {
      await _pump(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Start reading'));
      await _loadTexts(tester);
      expect(find.byType(ReaderScreen), findsOneWidget);

      await backToTheWeek(tester);
      expect(find.byType(WeekOverviewScreen), findsOneWidget);
      expect(selectedTab(tester), 0);
      await goBack(tester);
      expect(find.byType(TodayScreen), findsOneWidget);
    });

    testWidgets('opens the display settings over itself, which go back to it', (tester) async {
      final router = await _pump(tester);
      router.push('/read/5787:1/0');
      await _loadTexts(tester);
      await tester.tap(find.byTooltip('Display settings'));
      await tester.pumpAndSettle();
      final display = find.widgetWithText(ListTile, 'Display');
      await tester.scrollUntilVisible(display, 200,
          scrollable: find.descendant(of: find.byType(BottomSheet), matching: find.byType(Scrollable)));
      await tester.tap(display);
      await _loadTexts(tester);
      expect(tester.takeException(), isNull);
      expect(find.byType(DisplaySettingsScreen), findsOneWidget);

      await goBack(tester);
      expect(find.byType(ReaderScreen), findsOneWidget);
    });

    testWidgets('finishing the parsha opens the haftarah in its place, within Today', (tester) async {
      var week = WeekProgress(weekId: '5787:1');
      for (var a = 0; a < 6; a++) {
        for (final p in ReadingPass.values) {
          week = week.withUnit(a, p, LocalDate(2026, 10, 5));
        }
      }
      await _pump(tester, progress: ProgressState(weeks: {'5787:1': week}));
      await tester.tap(find.widgetWithText(FilledButton, 'Continue reading'));
      await _loadTexts(tester);
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark this aliyah as read'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Read the haftarah'));
      await _loadTexts(tester);
      expect(find.byType(HaftarahScreen), findsOneWidget);
      expect(selectedTab(tester), 0);
      await goBack(tester);
      expect(find.byType(TodayScreen), findsOneWidget);
    });

    testWidgets('opened from Progress shows the week in its place, within Progress', (tester) async {
      final router = await _pump(tester);
      router.go('/progress');
      await tester.pumpAndSettle();
      router.push('/read/5787:1/0');
      await _loadTexts(tester);
      expect(find.byType(ReaderScreen), findsOneWidget);

      await backToTheWeek(tester);
      expect(find.byType(WeekOverviewScreen), findsOneWidget);
      expect(router.state.uri.toString(), '/progress/week/5787:1');
      expect(selectedTab(tester), 2);
      await goBack(tester);
      expect(find.byType(ProgressScreen), findsOneWidget);
    });

    testWidgets('finishing the parsha from Progress opens the haftarah within Progress', (tester) async {
      var week = WeekProgress(weekId: '5787:1');
      for (var a = 0; a < 6; a++) {
        week = week.withAliyah(a, LocalDate(2026, 10, 5));
      }
      final router = await _pump(tester, progress: ProgressState(weeks: {'5787:1': week}));
      router.go('/progress');
      await tester.pumpAndSettle();
      router.push('/read/5787:1/6');
      await _loadTexts(tester);
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark this aliyah as read'));
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FilledButton, 'Read the haftarah'));
      await _loadTexts(tester);
      expect(find.byType(HaftarahScreen), findsOneWidget);
      expect(router.state.uri.toString(), '/progress/haftarah/5787:1');
      expect(selectedTab(tester), 2);
    });

    testWidgets('opened from a link shows the week within Today, with a way back to it', (tester) async {
      final router = await _pump(tester);
      router.go('/read/5787:1/0?from=week');
      await _loadTexts(tester);

      await backToTheWeek(tester);
      expect(find.byType(WeekOverviewScreen), findsOneWidget);
      expect(selectedTab(tester), 0);
      await goBack(tester);
      expect(find.byType(TodayScreen), findsOneWidget);
    });
  });

  testWidgets('a thread goes back to its forum', (tester) async {
    final router = await _pump(tester);
    router.go('/community');
    await tester.pumpAndSettle();
    await tester.tap(find.text('Questions & answers'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Why read the Targum rather than a translation?'));
    await tester.pumpAndSettle();
    expect(find.byType(ThreadScreen), findsOneWidget);

    await goBack(tester);
    expect(find.byType(ForumScreen), findsOneWidget);
    await goBack(tester);
    expect(find.byType(CommunityScreen), findsOneWidget);
    expect(selectedTab(tester), 3);
  });

  testWidgets('the guidelines open in front of the dialog that asks to accept them', (tester) async {
    final forums = DemoForumRepository();
    await forums.verifyCode('reader@example.org', '123456');
    await forums.updateDisplayName('Reader');
    final router = await _pump(tester, forums: forums);
    router.go('/community/thread/1');
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Write a reply'), 'Thank you.');
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Reply'));
    await tester.pumpAndSettle();
    final accept = find.byType(CheckboxListTile).hitTestable();
    expect(accept, findsOneWidget);

    await tester.tap(find.text('Read the guidelines'));
    await tester.pumpAndSettle();
    expect(find.byType(LegalScreen).hitTestable(), findsOneWidget);
    expect(accept, findsNothing);

    await goBack(tester);
    expect(find.byType(LegalScreen), findsNothing);
    expect(accept, findsOneWidget);
  });

  group('in Settings', () {
    testWidgets('the account opens within the Settings tab', (tester) async {
      final router = await _pump(tester);
      router.go('/settings');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Account & community'));
      await tester.pumpAndSettle();
      expect(find.byType(AccountScreen), findsOneWidget);
      expect(selectedTab(tester), 4);

      await goBack(tester);
      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets('the reports to review open from the account and go back to it', (tester) async {
      final forums = DemoForumRepository();
      await forums.verifyCode('reader@example.org', '123456');
      final router = await _pump(tester, forums: forums);
      router.go('/settings/account');
      await tester.pumpAndSettle();
      final reports = find.text('Reports to review');
      await tester.ensureVisible(reports);
      await tester.pumpAndSettle();
      await tester.tap(reports);
      await tester.pumpAndSettle();
      expect(find.byType(ModerationScreen), findsOneWidget);
      expect(selectedTab(tester), 4);

      await goBack(tester);
      expect(find.byType(AccountScreen), findsOneWidget);
    });

    Future<void> tapInAccessibility(WidgetTester tester, String row) async {
      final link = find.text(row);
      await tester.ensureVisible(link);
      await tester.pumpAndSettle();
      await tester.tap(link);
      await tester.pumpAndSettle();
    }

    testWidgets('feedback, with no address to email, goes to the feedback forum on a server, and back', (tester) async {
      final router = await _pump(tester, forums: _Server());
      router.go('/settings/accessibility');
      await tester.pumpAndSettle();
      await tapInAccessibility(tester, 'Send feedback');
      expect(find.byType(ForumScreen), findsOneWidget);
      expect(find.text('App feedback'), findsOneWidget);
      expect(selectedTab(tester), 4);

      await goBack(tester);
      expect(find.byType(AccessibilitySettingsScreen), findsOneWidget);
    });

    testWidgets('feedback, with no server for the forum to reach, goes to the issue tracker, as from About', (tester) async {
      final launched = <String>[];
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'launch') launched.add((call.arguments as Map)['url'] as String);
        return true;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
      final router = await _pump(tester);
      router.go('/settings/accessibility');
      await tester.pumpAndSettle();
      await tapInAccessibility(tester, 'Send feedback');
      expect(launched, [issueTrackerUri.toString()]);
      expect(find.byType(ForumScreen), findsNothing, reason: 'the demo forum reaches no one');
      expect(find.byType(AccessibilitySettingsScreen), findsOneWidget);
    });

    for (final (row, page) in [('Display', DisplaySettingsScreen), ('Accessibility statement', LegalScreen)]) {
      testWidgets('Accessibility opens $row over itself, which goes back to it', (tester) async {
        final router = await _pump(tester);
        router.go('/settings/accessibility');
        await tester.pumpAndSettle();
        await tapInAccessibility(tester, row);
        expect(find.byType(page), findsOneWidget);

        await goBack(tester);
        expect(find.byType(AccessibilitySettingsScreen), findsOneWidget);
      });
    }
  });

  testWidgets('a new discussion opens the guidelines over itself, and keeps what was written', (tester) async {
    final router = await _pump(tester);
    router.go('/community');
    await tester.pumpAndSettle();
    router.push('/community/new?forum=questions');
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextField, 'Title'), 'A question on Rashi');
    await tester.pumpAndSettle();
    final guidelines = find.text('Read the guidelines');
    await tester.ensureVisible(guidelines);
    await tester.pumpAndSettle();
    await tester.tap(guidelines);
    await tester.pumpAndSettle();
    expect(find.byType(LegalScreen), findsOneWidget);
    expect(find.text('Community guidelines'), findsOneWidget);

    await goBack(tester);
    expect(find.text('A question on Rashi'), findsOneWidget);
    expect(selectedTab(tester), 3);
  });
}
