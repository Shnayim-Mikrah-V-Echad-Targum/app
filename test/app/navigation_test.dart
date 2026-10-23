import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shnayim_mikrah/app/config.dart';
import 'package:shnayim_mikrah/app/providers.dart';
import 'package:shnayim_mikrah/app/router.dart';
import 'package:shnayim_mikrah/app/routes.dart';
import 'package:shnayim_mikrah/core/calendar/local_date.dart';
import 'package:shnayim_mikrah/features/about/about_screen.dart';
import 'package:shnayim_mikrah/features/about/guide_screen.dart';
import 'package:shnayim_mikrah/features/about/legal_screen.dart';
import 'package:shnayim_mikrah/features/about/sources_screen.dart';
import 'package:shnayim_mikrah/features/community/data/demo_forum_repository.dart';
import 'package:shnayim_mikrah/features/community/data/forum_repository.dart';
import 'package:shnayim_mikrah/features/community/data/models.dart';
import 'package:shnayim_mikrah/features/community/ui/account_screen.dart';
import 'package:shnayim_mikrah/features/community/ui/community_screen.dart';
import 'package:shnayim_mikrah/features/community/ui/compose_screen.dart';
import 'package:shnayim_mikrah/features/community/ui/forum_screen.dart';
import 'package:shnayim_mikrah/features/community/ui/moderation_screen.dart';
import 'package:shnayim_mikrah/features/community/ui/thread_screen.dart';
import 'package:shnayim_mikrah/features/parsha/browse_screen.dart';
import 'package:shnayim_mikrah/features/parsha/week_overview_screen.dart';
import 'package:shnayim_mikrah/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikrah/features/progress/progress_screen.dart';
import 'package:shnayim_mikrah/features/reader/haftarah_screen.dart';
import 'package:shnayim_mikrah/features/reader/reader_screen.dart';
import 'package:shnayim_mikrah/features/reader/scripture_text.dart' show ScriptureVerse;
import 'package:shnayim_mikrah/features/settings/app_settings.dart';
import 'package:shnayim_mikrah/features/settings/screens/accessibility_settings_screen.dart';
import 'package:shnayim_mikrah/features/settings/screens/display_settings_screen.dart';
import 'package:shnayim_mikrah/features/settings/screens/settings_screen.dart';
import 'package:shnayim_mikrah/features/today/today_screen.dart';
import 'package:shnayim_mikrah/l10n/app_localizations.dart';
import 'package:shnayim_mikrah/services/notifications.dart';
import 'package:shnayim_mikrah/ui/widgets/common.dart';
import 'package:shnayim_mikrah/ui/widgets/paper_group.dart';

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

/// A page's own heading, in its body: a policy sets its title there, which
/// the app bar repeats, for the eye alone, once it has scrolled away.
Finder _pageHeading(String text) => find.widgetWithText(PageBody, text);

/// The app on a phone, for its navigation bar, on [_now].
Future<GoRouter> _pump(
  WidgetTester tester, {
  NotificationService? notifications,
  ForumRepository? forums,
  ProgressState? progress,
  List<Override> overrides = const [],
}) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final c = await pumpApp(tester, now: _now, notifications: notifications, forums: forums, progress: progress, overrides: overrides);
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

    // As a click on a Windows toast that launched the app arrives: through
    // the plugin's callback, while main() is still starting the app.
    testWidgets('tapped before the app is up opens once Today is up, within it', (tester) async {
      final notifications = NotificationService.disabled()..handleTap('/today/week/5787:1');
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
      // The tab's own app bar, with its way to every parsha.
      expect(find.descendant(of: find.byType(AppBar), matching: find.text('All parshiyot')), findsOneWidget);
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
      expect(find.text('This forum couldn’t be found. It may have moved or closed.'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      await tester.tap(find.widgetWithText(FilledButton, 'All forums'));
      await tester.pumpAndSettle();
      expect(find.byType(CommunityScreen), findsOneWidget);
    });

    testWidgets('when the forums cannot load says so at once, and can try again', (tester) async {
      final forums = _Offline();
      final router = await _pump(tester, forums: forums);
      router.go('/community/forum/parsha');
      // As soon as the attempt fails: the forums are tried again only when
      // the reader asks.
      for (var i = 0; i < 3; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      expect(find.text('Couldn’t reach the server. Check your connection and try again.'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      // Under Community, as a thread names its forum when the forums fail.
      expect(find.descendant(of: find.byType(AppBar), matching: find.text('Community')), findsOneWidget);
      // Try again first, as the page's one Tonal button, and the way back
      // to the forums beside it.
      expect(find.widgetWithText(FilledButton, 'Try again'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'All forums'), findsOneWidget);

      forums.online = true;
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();
      expect(find.byType(ForumScreen), findsOneWidget);
      expect(find.text('Parshat HaShavua'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);
    });
  });

  testWidgets('the guide opens within Settings and goes back to it', (tester) async {
    final router = await _pump(tester);
    router.go('/settings');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('How it works'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('How it works'));
    await tester.pumpAndSettle();
    expect(find.byType(GuideScreen), findsOneWidget);
    expect(router.state.matchedLocation, '/settings/guide');
    expect(selectedTab(tester), 4);

    await goBack(tester);
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(selectedTab(tester), 4);
  });

  testWidgets("Today's help opens the guide within Today and goes back to it", (tester) async {
    final router = await _pump(tester);
    await tester.tap(find.byTooltip('How it works'));
    await tester.pumpAndSettle();
    expect(find.byType(GuideScreen), findsOneWidget);
    expect(router.state.matchedLocation, '/today/guide');
    expect(selectedTab(tester), 0);

    await goBack(tester);
    expect(find.byType(TodayScreen), findsOneWidget);
  });

  group('the policies and sources', () {
    testWidgets('open from About within Settings and go back to it', (tester) async {
      final router = await _pump(tester);
      router.go('/settings/about');
      await tester.pumpAndSettle();
      for (final (link, page, location) in [
        ('Texts & sources', SourcesScreen, '/settings/about/sources'),
        ('Privacy', LegalScreen, '/settings/about/legal/privacy'),
        ('Terms of use', LegalScreen, '/settings/about/legal/terms'),
        ('Community guidelines', LegalScreen, '/settings/about/legal/guidelines'),
        ('Accessibility statement', LegalScreen, '/settings/about/legal/accessibility'),
      ]) {
        await tester.ensureVisible(find.text(link));
        await tester.pumpAndSettle();
        await tester.tap(find.text(link));
        await _loadTexts(tester);
        expect(find.byType(page), findsOneWidget);
        expect(router.state.matchedLocation, location);
        expect(selectedTab(tester), 4);
        await goBack(tester);
        expect(find.byType(AboutScreen), findsOneWidget);
      }
    });

    testWidgets('each page has the address the browser shows: the page on top, with its query', (tester) async {
      final shown = <Uri>[];
      final router = await _pump(tester, overrides: [browserAddressProvider.overrideWithValue((uri) => shown.add(uri))]);
      // The strip at the top of Today.
      await tester.tap(find.textContaining('Texts & sources'));
      await _loadTexts(tester);
      expect(find.byType(SourcesScreen), findsOneWidget);
      expect(shown.last.path, '/settings/about/sources');
      // Back to Today, whose address it then shows.
      await goBack(tester);
      expect(shown.last.path, '/today');
      // A page pushed with a query keeps it in its address.
      router.push('/search?q=shalom');
      await tester.pumpAndSettle();
      expect(shown.last.path, '/search');
      expect(shown.last.queryParameters['q'], 'shalom');
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
      // Under the account, as the page beneath it is.
      expect(router.state.matchedLocation, '/community/account/legal/privacy');
      expect(selectedTab(tester), 3);

      await goBack(tester);
      expect(find.byType(AccountScreen), findsOneWidget);
      expect(selectedTab(tester), 3);
    });

    testWidgets('open from the account in Settings without leaving the Settings tab', (tester) async {
      final router = await _pump(tester);
      router.go('/settings/account');
      await tester.pumpAndSettle();
      final privacy = find.text('Privacy');
      await tester.ensureVisible(privacy);
      await tester.pumpAndSettle();
      await tester.tap(privacy);
      await tester.pumpAndSettle();
      expect(find.byType(LegalScreen), findsOneWidget);
      // Under the account, not About: a reload puts back the account beneath.
      expect(router.state.matchedLocation, '/settings/account/legal/privacy');
      expect(selectedTab(tester), 4);

      await goBack(tester);
      expect(find.byType(AccountScreen), findsOneWidget);
      expect(selectedTab(tester), 4);
    });

    testWidgets('open on their own from the account shown over the tabs', (tester) async {
      final router = await _pump(tester);
      router.push('/account?then=back');
      await tester.pumpAndSettle();
      final privacy = find.text('Privacy');
      await tester.ensureVisible(privacy);
      await tester.pumpAndSettle();
      await tester.tap(privacy);
      await tester.pumpAndSettle();
      expect(find.byType(LegalScreen), findsOneWidget);
      expect(router.state.matchedLocation, '/legal/privacy');
      expect(tester.takeException(), isNull);

      await goBack(tester);
      expect(find.byType(AccountScreen), findsOneWidget);
    });

    testWidgets('open on their own from signing in on the welcome, before onboarding', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = await pumpApp(tester, settings: const AppSettings(), now: _now);
      await tester.pumpAndSettle();
      final router = c.read(routerProvider);
      router.push('/welcome/account');
      await tester.pumpAndSettle();
      final privacy = find.text('Privacy');
      await tester.ensureVisible(privacy);
      await tester.pumpAndSettle();
      await tester.tap(privacy);
      await _loadTexts(tester);
      expect(find.byType(LegalScreen), findsOneWidget);
      expect(_pageHeading('Privacy'), findsOneWidget);
      expect(router.state.matchedLocation, '/legal/privacy');

      await goBack(tester);
      expect(find.byType(AccountScreen), findsOneWidget);
    });

    testWidgets('keep their addresses in About before onboarding too, on their own', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = await pumpApp(tester, settings: const AppSettings(), now: _now);
      await tester.pumpAndSettle();
      final router = c.read(routerProvider);
      router.go('/settings/about/legal/privacy');
      await tester.pumpAndSettle();
      expect(find.byType(LegalScreen), findsOneWidget);
      expect(_pageHeading('Privacy'), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing, reason: 'the tabs wait for onboarding');

      router.go('/settings/about/sources');
      await tester.pumpAndSettle();
      expect(find.byType(SourcesScreen), findsOneWidget);

      router.go('/settings');
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsNothing, reason: 'the rest waits for onboarding');
    });

    testWidgets('keep their addresses in About, now within Settings', (tester) async {
      final router = await _pump(tester);
      router.go('/community');
      await tester.pumpAndSettle();
      // Pushed, as a page of the tab on show.
      router.push('/settings/about/legal/guidelines');
      await tester.pumpAndSettle();
      expect(find.byType(LegalScreen), findsOneWidget);
      expect(_pageHeading('Community guidelines'), findsOneWidget);
      await goBack(tester);
      expect(selectedTab(tester), 3);

      // Gone to, as a link or a reload does, under About.
      router.go('/settings/about/sources');
      await tester.pumpAndSettle();
      expect(find.byType(SourcesScreen), findsOneWidget);
      expect(selectedTab(tester), 4);
      expect(_home, findsNothing);
      await goBack(tester);
      expect(find.byType(AboutScreen), findsOneWidget);
    });
  });

  group('a week', () {
    String location(GoRouter router) => router.state.uri.toString();

    testWidgets('opened from Today stays in the Today tab, and so does its haftarah', (tester) async {
      final router = await _pump(tester);
      await tester.tap(find.widgetWithText(TextButton, 'All aliyot'));
      await tester.pumpAndSettle();
      expect(find.byType(WeekOverviewScreen), findsOneWidget);
      expect(location(router), '/today/week/5787:1');
      expect(selectedTab(tester), 0);
      expect(find.byType(BackButton), findsOneWidget);

      final haftarah = find.widgetWithText(PaperRow, 'Haftarah');
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
      await tester.tap(find.text('Noach'));
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
      final discuss = find.text('Discuss this week’s parsha');
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
      final discuss = find.text('Discuss this week’s parsha');
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
      final haftarah = find.widgetWithText(PaperRow, 'Haftarah');
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

      final display = find.widgetWithText(PaperRow, 'Display');
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
      await tester.tap(find.widgetWithText(TextButton, 'All aliyot'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Rishon'));
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
      // On a phone, below the strip that says the app was made with AI.
      await Scrollable.ensureVisible(tester.element(find.widgetWithText(FilledButton, 'Start · Rishon')), alignment: 0.1);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Start · Rishon'));
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
      final display = find.widgetWithText(PaperRow, 'Display');
      await tester.scrollUntilVisible(display, 200,
          scrollable: find.descendant(of: find.byType(BottomSheet), matching: find.byType(Scrollable)));
      // Wholly in view, so that the tap lands on it rather than below the
      // sheet: the reader's sheet is longer, with Listen along.
      await tester.ensureVisible(display);
      await tester.pumpAndSettle();
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
      // On a phone, below the strip that says the app was made with AI.
      await Scrollable.ensureVisible(tester.element(find.widgetWithText(FilledButton, 'Continue · Shevi’i')), alignment: 0.1);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Continue · Shevi’i'));
      await _loadTexts(tester);
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark this aliyah as read'));
      await tester.pumpAndSettle();

      // On a phone, below the strip that says the app was made with AI.
      await Scrollable.ensureVisible(tester.element(find.widgetWithText(FilledButton, 'Read the haftarah')), alignment: 0.1);
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

      // On a phone, below the strip that says the app was made with AI.
      await Scrollable.ensureVisible(tester.element(find.widgetWithText(FilledButton, 'Read the haftarah')), alignment: 0.1);
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
      await tester.ensureVisible(find.text('Account & community'));
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

    Future<void> tapRow(WidgetTester tester, String row) async {
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
      await tapRow(tester, 'Send feedback');
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
      await tapRow(tester, 'Send feedback');
      expect(launched, [issueTrackerUri.toString()]);
      expect(find.byType(ForumScreen), findsNothing, reason: 'the demo forum reaches no one');
      expect(find.byType(AccessibilitySettingsScreen), findsOneWidget);
    });

    /// Records the links opened, each opening as [opens] says.
    List<String> recordLaunches(WidgetTester tester, {bool opens = true}) {
      final launched = <String>[];
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'launch') launched.add((call.arguments as Map)['url'] as String);
        return opens;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
      return launched;
    }

    void withSupportEmail() {
      AppConfig.debugSupportEmail = 'help@example.org';
      addTearDown(() => AppConfig.debugSupportEmail = null);
    }

    testWidgets('feedback, with an address to email, is emailed from Accessibility', (tester) async {
      withSupportEmail();
      final launched = recordLaunches(tester);
      final router = await _pump(tester, forums: _Server());
      router.go('/settings/accessibility');
      await tester.pumpAndSettle();
      await tapRow(tester, 'Send feedback');
      expect(launched, [supportEmailUri(lookupAppLocalizations(const Locale('en')))!.toString()]);
      expect(find.byType(ForumScreen), findsNothing);
    });

    testWidgets('feedback, with an address but no mail app to send it, goes to the feedback forum', (tester) async {
      withSupportEmail();
      final launched = recordLaunches(tester, opens: false);
      final router = await _pump(tester, forums: _Server());
      router.go('/settings/accessibility');
      await tester.pumpAndSettle();
      await tapRow(tester, 'Send feedback');
      expect(launched, hasLength(1));
      expect(launched.single, startsWith('mailto:'));
      expect(find.byType(ForumScreen), findsOneWidget);
    });

    // About's Contact row emails already, so its Send feedback goes as
    // Accessibility's does without an address.
    testWidgets('feedback from About goes to the feedback forum on a server, not the issue tracker, and back',
        (tester) async {
      withSupportEmail();
      final launched = recordLaunches(tester);
      final router = await _pump(tester, forums: _Server());
      router.go('/settings/about');
      await tester.pumpAndSettle();
      await tapRow(tester, 'Send feedback');
      expect(launched, isEmpty, reason: 'neither email, which Contact us sends, nor the issue tracker');
      expect(find.byType(ForumScreen), findsOneWidget);
      expect(find.text('App feedback'), findsOneWidget);
      expect(selectedTab(tester), 4);

      await goBack(tester);
      expect(find.byType(AboutScreen), findsOneWidget);
    });

    testWidgets('feedback from About, with no server for the forum to reach, goes to the issue tracker', (tester) async {
      withSupportEmail();
      final launched = recordLaunches(tester);
      final router = await _pump(tester);
      router.go('/settings/about');
      await tester.pumpAndSettle();
      await tapRow(tester, 'Send feedback');
      expect(launched, [issueTrackerUri.toString()]);
      expect(find.byType(ForumScreen), findsNothing);
      expect(find.byType(AboutScreen), findsOneWidget);
    });

    for (final (row, page, location) in [
      ('Display', DisplaySettingsScreen, '/settings/display'),
      ('Accessibility statement', LegalScreen, '/settings/accessibility/legal/accessibility'),
    ]) {
      testWidgets('Accessibility opens $row over itself, within Settings, which goes back to it', (tester) async {
        final router = await _pump(tester);
        router.go('/settings/accessibility');
        await tester.pumpAndSettle();
        await tapRow(tester, row);
        expect(find.byType(page), findsOneWidget);
        expect(router.state.matchedLocation, location);
        expect(selectedTab(tester), 4);

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
    expect(_pageHeading('Community guidelines'), findsOneWidget);
    expect(router.state.matchedLocation, '/community/legal/guidelines');
    expect(selectedTab(tester), 3);

    await goBack(tester);
    expect(find.text('A question on Rashi'), findsOneWidget);
    expect(selectedTab(tester), 3);
  });

  testWidgets("a question asked from Today's haftarah opens the guidelines within Today, back to the question",
      (tester) async {
    final router = await _pump(tester);
    router.go('/today/haftarah/5787:1');
    await _loadTexts(tester);
    await tester.longPress(find.byType(ScriptureVerse).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ask about this verse'));
    await tester.pumpAndSettle();
    expect(find.byType(ComposeScreen), findsOneWidget);
    expect(selectedTab(tester), 0, reason: 'within Today, as the haftarah was');

    final guidelines = find.text('Read the guidelines');
    await tester.ensureVisible(guidelines);
    await tester.pumpAndSettle();
    await tester.tap(guidelines);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.byType(LegalScreen), findsOneWidget);
    expect(_pageHeading('Community guidelines'), findsOneWidget);
    expect(selectedTab(tester), 0, reason: 'still within Today');

    await goBack(tester);
    expect(find.byType(ComposeScreen), findsOneWidget);
    expect(selectedTab(tester), 0);
  });

  testWidgets('a question asked over the reader opens the guidelines over itself too', (tester) async {
    final router = await _pump(tester);
    router.push('/ask?verse=Genesis%203:22');
    await tester.pumpAndSettle();
    final guidelines = find.text('Read the guidelines');
    await tester.ensureVisible(guidelines);
    await tester.pumpAndSettle();
    await tester.tap(guidelines);
    await tester.pumpAndSettle();
    expect(find.byType(LegalScreen), findsOneWidget);
    expect(router.state.matchedLocation, '/legal/guidelines');
    expect(tester.takeException(), isNull);

    await goBack(tester);
    expect(find.text('Read the guidelines'), findsOneWidget);
  });
}
