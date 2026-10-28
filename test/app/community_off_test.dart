import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shnayim_mikrah/app/config.dart';
import 'package:shnayim_mikrah/app/router.dart';
import 'package:shnayim_mikrah/features/about/about_screen.dart';
import 'package:shnayim_mikrah/features/about/guide_screen.dart';
import 'package:shnayim_mikrah/features/community/data/backend.dart';
import 'package:shnayim_mikrah/features/community/data/demo_forum_repository.dart';
import 'package:shnayim_mikrah/features/community/ui/community_screen.dart';
import 'package:shnayim_mikrah/features/onboarding/onboarding_screen.dart';
import 'package:shnayim_mikrah/features/reader/scripture_text.dart';
import 'package:shnayim_mikrah/features/settings/app_settings.dart';
import 'package:shnayim_mikrah/features/settings/screens/data_settings_screen.dart';
import 'package:shnayim_mikrah/features/settings/screens/settings_screen.dart';
import 'package:shnayim_mikrah/features/today/today_screen.dart';
import 'package:shnayim_mikrah/ui/widgets/common.dart';

import '../helpers.dart';

/// A demo that says it is a community server, as one configured would: the
/// restore sheet offers to sign in to it, where there is a community.
class _Server extends DemoForumRepository {
  @override
  bool get isDemo => false;
}

/// The app built with `COMMUNITY=off` (AppConfig.communityEnabled), as the
/// pre-releases are until the accounts' database is ready: no Community
/// tab, no way to ask about a verse, no account or cloud backup, no week's
/// discussion, and links to any of them open Today. About and the guide
/// say that the community is coming, and Your data keeps its backup file.
void main() {
  // Friday of Bereshit 5787.
  final friday = DateTime(2026, 10, 9, 11);

  setUp(() => AppConfig.debugCommunity = false);
  tearDown(() => AppConfig.debugCommunity = null);

  Future<ProviderContainer> pump(
    WidgetTester tester, {
    Size size = const Size(412, 915),
    AppSettings settings = const AppSettings(onboardingComplete: true),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await pumpApp(tester, settings: settings, now: friday, forums: _Server());
    await tester.pumpAndSettle();
    return c;
  }

  Future<void> go(WidgetTester tester, ProviderContainer c, String location) async {
    c.read(routerProvider).go(location);
    await tester.pump();
    await tester.pump();
    for (var i = 0; i < 30 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  String location(ProviderContainer c) => c.read(routerProvider).state.uri.toString();

  test('is on unless the build turns it off', () {
    AppConfig.debugCommunity = null;
    // The tests are built without COMMUNITY, as CI's builds are.
    expect(AppConfig.communityEnabled, isTrue);
    AppConfig.debugCommunity = false;
    expect(AppConfig.communityEnabled, isFalse);
  });

  testWidgets("a phone's navigation bar has no Community", (tester) async {
    final c = await pump(tester);
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect([for (final d in bar.destinations) (d as NavigationDestination).label], [
      'Today',
      'Parsha',
      'Progress',
      'Settings',
    ]);
    // Settings, the fourth, is Settings' tab.
    await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text('Settings')));
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(location(c), '/settings');
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 3);
  });

  testWidgets("a desktop's rail has no Community", (tester) async {
    await pump(tester, size: const Size(1366, 860));
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    expect(rail.destinations, hasLength(4));
    expect(find.descendant(of: find.byType(NavigationRail), matching: find.text('Community')), findsNothing);
  });

  for (final link in [
    '/community',
    '/community/thread/1',
    '/community/forum/questions',
    '/community/new?forum=questions&verse=Genesis%203:22',
    '/community/sign-in',
    '/community/legal/guidelines',
    '/ask?verse=Genesis%203:22',
    '/account',
    '/account/legal/privacy',
    '/sign-in',
    '/settings/account',
    '/settings/account/legal/privacy',
  ]) {
    testWidgets('a link to $link opens Today', (tester) async {
      final c = await pump(tester);
      await go(tester, c, link);
      expect(find.byType(TodayScreen), findsOneWidget);
      expect(find.byType(CommunityScreen), findsNothing);
      expect(location(c), '/today');
    });
  }

  testWidgets('a link to a discussion before onboarding opens the welcome, and nothing after it', (tester) async {
    final c = await pump(tester, settings: const AppSettings());
    await go(tester, c, '/community/thread/1');
    expect(find.byType(OnboardingScreen), findsOneWidget);
    expect(c.read(heldLocationProvider).take(), isNull);
    await go(tester, c, '/welcome/account');
    expect(find.byType(OnboardingScreen), findsOneWidget);
  });

  testWidgets("the restore sheet doesn't offer to sign in", (tester) async {
    await pump(tester, settings: const AppSettings());
    await tester.tap(find.text('I already use Shnayim Mikrah'));
    await tester.pumpAndSettle();
    expect(find.text('Sign in to restore'), findsNothing);
    expect(find.text('Restore from a backup file'), findsOneWidget);
  });

  testWidgets("Today has no week's discussion", (tester) async {
    await pump(tester);
    await tester.scrollUntilVisible(find.text('Haftarah'), 200, scrollable: find.byType(Scrollable).first);
    expect(find.text('Discuss this week’s parsha'), findsNothing);
  });

  testWidgets("a week's page has no discussion either", (tester) async {
    final c = await pump(tester);
    await go(tester, c, '/parsha');
    expect(find.text('Discuss this week’s parsha'), findsNothing);
  });

  testWidgets("with the haftarah off too, Today's This week heading goes with its rows", (tester) async {
    // Tall enough for the whole page to be built.
    const tall = Size(412, 3000);
    const settings = AppSettings(onboardingComplete: true, haftarahEnabled: false);
    await pump(tester, size: tall, settings: settings);
    expect(find.text('Also this week'), findsNothing);
    // With the community, the discussion keeps them.
    AppConfig.debugCommunity = null;
    await pump(tester, size: tall, settings: settings);
    expect(find.text('Also this week'), findsOneWidget);
    expect(find.text('Discuss this week’s parsha'), findsOneWidget);
  });

  testWidgets("a verse's options have no question to ask", (tester) async {
    final c = await pump(tester);
    await go(tester, c, '/read/5787:1/3');
    await tester.longPress(find.byType(ScriptureVerse).first);
    await tester.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    expect(find.descendant(of: sheet, matching: find.text('Copy')), findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text('Ask about this verse')), findsNothing);
  });

  testWidgets('Settings has no account, and Your data no cloud backup, but its backup file', (tester) async {
    final c = await pump(tester);
    await go(tester, c, '/settings');
    expect(find.text('Account & community'), findsNothing);
    expect(find.text('Your data'), findsOneWidget);
    await go(tester, c, '/settings/data');
    expect(find.byType(DataSettingsScreen), findsOneWidget);
    expect(find.text('Cloud backup'), findsNothing);
    expect(find.text('Export my progress'), findsOneWidget);
    expect(find.text('Import progress'), findsOneWidget);
  });

  testWidgets('About says the community is coming, and how to move the reading meanwhile', (tester) async {
    final c = await pump(tester);
    await go(tester, c, '/settings/about');
    expect(find.byType(AboutScreen), findsOneWidget);
    expect(
      find.widgetWithText(
        NoticeBanner,
        'The community is coming soon. Until then, your reading stays on this device; to move it, use a backup, in Settings under Your data.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('the guide says so too, and asks nothing about a verse', (tester) async {
    final c = await pump(tester);
    await go(tester, c, '/settings/guide');
    expect(find.byType(GuideScreen), findsOneWidget);
    // Its points and paragraphs select, a SelectableText each.
    final text = [
      for (final t in tester.widgetList<SelectableText>(
        find.descendant(of: find.byType(GuideScreen), matching: find.byType(SelectableText)),
      ))
        t.data ?? t.textSpan?.toPlainText() ?? '',
    ].join('\n');
    expect(text, contains('The community is coming soon.'));
    expect(text, contains('copy or share it'));
    expect(text, isNot(contains('ask about it')));
  });

  testWidgets('the backend is the demo, whatever the build configures', (tester) async {
    AppConfig.debugWebUrl = 'https://shnayimmikrah.org/';
    addTearDown(() => AppConfig.debugWebUrl = null);
    SharedPreferences.setMockInitialValues({});
    final backend = await Backend.initialize(preferences: SharedPreferences.getInstance());
    expect(backend.forums, isA<DemoForumRepository>());
  });
}
