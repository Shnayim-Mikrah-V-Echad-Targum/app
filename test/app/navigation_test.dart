import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shnayim_mikra/app/router.dart';
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
import 'package:shnayim_mikra/features/community/ui/thread_screen.dart';
import 'package:shnayim_mikra/features/parsha/week_overview_screen.dart';
import 'package:shnayim_mikra/features/settings/screens/accessibility_settings_screen.dart';
import 'package:shnayim_mikra/features/settings/screens/settings_screen.dart';
import 'package:shnayim_mikra/features/today/today_screen.dart';
import 'package:shnayim_mikra/services/notifications.dart';

import '../helpers.dart';

/// Friday of Bereshit 5787.
final _now = DateTime(2026, 10, 9, 11);
const _week = '/week/5787:1';

/// A backend whose forums never load.
class _Offline extends DemoForumRepository {
  @override
  Future<List<Forum>> forums() async => throw Exception('offline');
}

final _home = find.widgetWithIcon(IconButton, Icons.home_outlined);

/// The app on a phone, for its navigation bar, on [_now].
Future<GoRouter> _pump(WidgetTester tester, {NotificationService? notifications, ForumRepository? forums}) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final c = await pumpApp(tester, now: _now, notifications: notifications, forums: forums);
  await tester.pumpAndSettle();
  return c.read(routerProvider);
}

void main() {
  int? selectedTab(WidgetTester tester) => tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex;

  Future<void> goBack(WidgetTester tester) async {
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
  }

  group('a notification', () {
    testWidgets('for a week opens it over Today, with a way back to the navigation bar', (tester) async {
      final notifications = NotificationService.disabled();
      final router = await _pump(tester, notifications: notifications);
      router.go('/settings');
      await tester.pumpAndSettle();

      notifications.handleTap(_week);
      await tester.pumpAndSettle();
      expect(find.byType(WeekOverviewScreen), findsOneWidget);
      expect(find.byType(BackButton), findsOneWidget);
      expect(_home, findsNothing);
      expect(find.byType(NavigationBar), findsNothing);

      await goBack(tester);
      expect(find.byType(TodayScreen), findsOneWidget);
      expect(selectedTab(tester), 0);
    });

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

    testWidgets('that launched the app opens over Today, once', (tester) async {
      final notifications = NotificationService.disabled()..launchRoute = _week;
      await _pump(tester, notifications: notifications);
      expect(find.byType(WeekOverviewScreen), findsOneWidget);
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

    testWidgets('such as a week that does not exist, still has a way home', (tester) async {
      final router = await _pump(tester);
      router.go('/week/nonsense');
      await tester.pumpAndSettle();
      expect(find.text('Something went wrong. Please try again.'), findsOneWidget);
      expect(_home, findsOneWidget);
    });

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
    expect(find.text("This link doesn't lead anywhere in the app."), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Go to Today'));
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

      await tester.tap(find.widgetWithText(TextButton, 'All forums'));
      await tester.pumpAndSettle();
      expect(find.byType(CommunityScreen), findsOneWidget);
    });

    testWidgets('when the forums cannot load says so, and can try again', (tester) async {
      final router = await _pump(tester, forums: _Offline());
      router.go('/community/forum/parsha');
      await tester.pumpAndSettle();
      expect(find.text("Couldn't reach the server. Check your connection and try again."), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Try again'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'All forums'), findsOneWidget);
    });
  });

  testWidgets('the guide opens over Settings and goes back to it', (tester) async {
    final router = await _pump(tester);
    router.go('/settings');
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('About Shnayim Mikra'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('About Shnayim Mikra'));
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
      final privacy = find.widgetWithText(TextButton, 'Privacy');
      await tester.ensureVisible(privacy);
      await tester.pumpAndSettle();
      await tester.tap(privacy);
      await tester.pumpAndSettle();
      expect(find.byType(LegalScreen), findsOneWidget);

      await goBack(tester);
      expect(find.byType(AccountScreen), findsOneWidget);
      expect(selectedTab(tester), 3);
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
    testWidgets('feedback, with no address to email, goes to the feedback forum and back', (tester) async {
      final router = await _pump(tester);
      router.go('/settings/accessibility');
      await tester.pumpAndSettle();
      final feedback = find.text('Send feedback');
      await tester.ensureVisible(feedback);
      await tester.pumpAndSettle();
      await tester.tap(feedback);
      await tester.pumpAndSettle();
      expect(find.byType(ForumScreen), findsOneWidget);
      expect(find.text('App feedback'), findsOneWidget);
      expect(selectedTab(tester), 4);

      await goBack(tester);
      expect(find.byType(AccessibilitySettingsScreen), findsOneWidget);
    });
  });
}
