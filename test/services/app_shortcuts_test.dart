import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:quick_actions/quick_actions.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/features/onboarding/onboarding_screen.dart';
import 'package:shnayim_mikra/features/parsha/parsha_tab.dart';
import 'package:shnayim_mikra/features/parsha/week_overview_screen.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikra/features/reader/reader_screen.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/features/today/today_screen.dart';
import 'package:shnayim_mikra/services/app_shortcuts.dart';

import '../helpers.dart';

/// The platform side of quick_actions: records the shortcuts set, and
/// reports the ones chosen through [handler].
class FakeQuickActions implements QuickActions {
  /// Reported while initializing, as Android reports the shortcut that
  /// launched the app.
  List<String> launchedWith = const [];

  QuickActionHandler? handler;
  List<ShortcutItem>? items;
  int updates = 0;

  @override
  Future<void> initialize(QuickActionHandler handler) async {
    this.handler = handler;
    launchedWith.forEach(handler);
  }

  @override
  Future<void> setShortcutItems(List<ShortcutItem> items) async {
    this.items = items;
    updates++;
  }

  @override
  Future<void> clearShortcutItems() async {
    items = const [];
    updates++;
  }
}

void main() {
  // flutter_test reports Android as the platform unless told otherwise.
  group('the service', () {
    test('runs on Android and iOS only', () async {
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      for (final platform in TargetPlatform.values) {
        debugDefaultTargetPlatformOverride = platform;
        final plugin = FakeQuickActions();
        final service = await AppShortcutsService.create(plugin: plugin);
        final expected = platform == TargetPlatform.android || platform == TargetPlatform.iOS;
        expect(service.supported, expected, reason: platform.name);
        expect(plugin.handler != null, expected, reason: platform.name);
      }
    });

    test('shows the launcher icon on Android and the mark on iOS', () {
      addTearDown(() => debugDefaultTargetPlatformOverride = null);
      expect(AppShortcutsService.icon, 'ic_launcher');
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(AppShortcutsService.icon, 'ShortcutMark');
    });

    test('holds the shortcut that launched the app until it is listened to', () async {
      final plugin = FakeQuickActions()..launchedWith = ['log_from_book'];
      final service = await AppShortcutsService.create(plugin: plugin);
      final opened = <AppShortcut>[];
      service.listen(opened.add);
      expect(opened, [AppShortcut.logFromBook]);
      plugin.handler!('this_week');
      expect(opened, [AppShortcut.logFromBook, AppShortcut.thisWeek]);
    });

    test('opens a shortcut reported twice at once only once', () async {
      var now = DateTime(2026, 10, 12, 10);
      final plugin = FakeQuickActions()..launchedWith = ['continue_reading', 'continue_reading'];
      final service = await AppShortcutsService.create(plugin: plugin, now: () => now);
      final opened = <AppShortcut>[];
      service.listen(opened.add);
      expect(opened, [AppShortcut.continueReading]);

      // Chosen again later, it opens again.
      now = now.add(const Duration(minutes: 1));
      plugin.handler!('continue_reading');
      plugin.handler!('continue_reading');
      expect(opened, [AppShortcut.continueReading, AppShortcut.continueReading]);
    });

    test('ignores a shortcut it does not know', () async {
      final plugin = FakeQuickActions();
      final service = await AppShortcutsService.create(plugin: plugin);
      final opened = <AppShortcut>[];
      service.listen(opened.add);
      plugin.handler!('/read/5787:1/0');
      expect(opened, isEmpty);
    });

    test('keeps every type it has given out', () {
      // Android keeps a pinned shortcut's type, so these must never change.
      expect({for (final s in AppShortcut.values) s: s.type}, {
        AppShortcut.continueReading: 'continue_reading',
        AppShortcut.logFromBook: 'log_from_book',
        AppShortcut.thisWeek: 'this_week',
      });
      for (final s in AppShortcut.values) {
        expect(AppShortcut.fromType(s.type), s);
      }
    });
  });

  group('the shortcuts on the icon', () {
    Future<(ProviderContainer, FakeQuickActions)> start(AppSettings settings) async {
      SharedPreferences.setMockInitialValues({'flutter.settings.v1': jsonEncode(settings.toJson())});
      final prefs = await SharedPreferences.getInstance();
      final plugin = FakeQuickActions();
      final service = await AppShortcutsService.create(plugin: plugin);
      final container = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        appShortcutsServiceProvider.overrideWithValue(service),
      ]);
      addTearDown(container.dispose);
      container.listen(appShortcutsProvider, (_, _) {});
      return (container, plugin);
    }

    List<(String, String, String?)> shown(FakeQuickActions plugin) =>
        [for (final i in plugin.items!) (i.type, i.localizedTitle, i.icon)];

    /// Within the 25 characters Android's launchers show in full.
    void expectShortEnough(FakeQuickActions plugin) {
      for (final i in plugin.items!) {
        expect(i.localizedTitle.length, lessThanOrEqualTo(25), reason: i.localizedTitle);
      }
    }

    test('are the three, in the app language, with the launcher icon', () async {
      final (container, plugin) = await start(const AppSettings(onboardingComplete: true));
      expect(shown(plugin), [
        ('continue_reading', 'Continue reading', 'ic_launcher'),
        ('log_from_book', 'Log reading from a book', 'ic_launcher'),
        ('this_week', "This week's parsha", 'ic_launcher'),
      ]);
      expectShortEnough(plugin);

      container.read(settingsProvider.notifier).update((s) => s.copyWith(language: AppLanguage.hebrew));
      container.read(appShortcutsProvider);
      expect(shown(plugin), [
        ('continue_reading', 'המשך קריאה', 'ic_launcher'),
        ('log_from_book', 'רישום קריאה מתוך ספר', 'ic_launcher'),
        ('this_week', 'פרשת השבוע', 'ic_launcher'),
      ]);
      expectShortEnough(plugin);
    });

    test('are set again only when they change', () async {
      final (container, plugin) = await start(const AppSettings(onboardingComplete: true));
      expect(plugin.updates, 1);
      container.read(settingsProvider.notifier).update((s) => s.copyWith(boldText: true));
      container.read(appShortcutsProvider);
      container.invalidate(appShortcutsProvider);
      container.read(appShortcutsProvider);
      expect(plugin.updates, 1);
    });

    test('wait for onboarding, and go if it starts again', () async {
      final (container, plugin) = await start(const AppSettings());
      expect(plugin.items, isEmpty);

      container.read(settingsProvider.notifier).update((s) => s.copyWith(onboardingComplete: true));
      container.read(appShortcutsProvider);
      expect(plugin.items, hasLength(3));

      container.read(settingsProvider.notifier).update((s) => s.copyWith(onboardingComplete: false));
      container.read(appShortcutsProvider);
      expect(plugin.items, isEmpty);
    });
  });

  group('a chosen shortcut', () {
    // Monday 12 October 2026, in the week of Noach.
    final monday = DateTime(2026, 10, 12, 10);
    const noach = '5787:2';

    final mondayDate = LocalDate.fromDateTime(monday);

    /// Rishon and Sheni of Noach read.
    ProgressState twoRead() => ProgressState(weeks: {
          noach: WeekProgress(weekId: noach).withAliyah(0, mondayDate).withAliyah(1, mondayDate),
        });

    Future<(GoRouter, FakeQuickActions)> pump(
      WidgetTester tester, {
      AppSettings settings = const AppSettings(onboardingComplete: true, notificationPromptShown: true),
      ProgressState? progress,
      List<String> launchedWith = const [],
    }) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final plugin = FakeQuickActions()..launchedWith = launchedWith;
      final service = await AppShortcutsService.create(plugin: plugin);
      final container = await pumpApp(
        tester,
        settings: settings,
        now: monday,
        progress: progress,
        overrides: [appShortcutsServiceProvider.overrideWithValue(service)],
      );
      return (container.read(routerProvider), plugin);
    }

    /// Lets the reader load its text, whose spinner never settles.
    Future<void> settle(WidgetTester tester) async {
      await tester.pump();
      await tester.pump();
      for (var i = 0; i < 20 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump();
      }
      await tester.pumpAndSettle();
    }

    /// The page on top.
    String location(GoRouter router) => router.state.uri.toString();

    /// Goes back from the page on top, as its back button does, to Today
    /// with the navigation bar.
    Future<void> expectBackToToday(WidgetTester tester, GoRouter router) async {
      expect(find.byType(NavigationBar), findsNothing);
      await tester.tap(find.byType(BackButton));
      await settle(tester);
      expect(location(router), '/today');
      expect(find.byType(TodayScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
    }

    testWidgets('Continue reading opens the next aliyah over Today', (tester) async {
      final (router, plugin) = await pump(tester, progress: twoRead());
      plugin.handler!('continue_reading');
      await settle(tester);
      expect(location(router), '/read/$noach/2');
      expect(find.byType(ReaderScreen), findsOneWidget);
      await expectBackToToday(tester, router);
    });

    testWidgets('Continue reading opens Rishon once the week is finished', (tester) async {
      final finished = WeekProgress(weekId: noach).withAll(mondayDate);
      final (router, plugin) = await pump(tester, progress: ProgressState(weeks: {noach: finished}));
      plugin.handler!('continue_reading');
      await settle(tester);
      expect(location(router), '/read/$noach/0');
    });

    testWidgets('Log reading from a book opens the week over Today', (tester) async {
      final (router, plugin) = await pump(tester);
      plugin.handler!('log_from_book');
      await settle(tester);
      expect(location(router), '/week/$noach');
      expect(find.byType(WeekOverviewScreen), findsOneWidget);
      await expectBackToToday(tester, router);
    });

    testWidgets("This week's parsha opens the Parsha tab, from wherever the app was", (tester) async {
      final (router, plugin) = await pump(tester);
      router.go('/settings/display');
      await settle(tester);
      plugin.handler!('this_week');
      await settle(tester);
      expect(location(router), '/parsha');
      expect(find.byType(ParshaTab), findsOneWidget);
      expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 1);
    });

    testWidgets('one that launched the app opens over Today, once', (tester) async {
      // Android may report it twice as the app starts.
      final (router, _) = await pump(tester, launchedWith: ['log_from_book', 'log_from_book']);
      await settle(tester);
      expect(location(router), '/week/$noach');
      await expectBackToToday(tester, router);
    });

    testWidgets('waits for onboarding', (tester) async {
      final (router, plugin) = await pump(tester, settings: const AppSettings());
      await settle(tester);
      plugin.handler!('continue_reading');
      await settle(tester);
      expect(location(router), '/welcome');
      expect(find.byType(OnboardingScreen), findsOneWidget);
    });
  });
}
