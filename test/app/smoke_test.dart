import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/features/about/guide_screen.dart';
import 'package:shnayim_mikra/features/about/legal_screen.dart';
import 'package:shnayim_mikra/features/about/sources_screen.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';

import '../helpers.dart';

void main() {
  testWidgets('first launch shows onboarding', (tester) async {
    await pumpApp(tester, settings: const AppSettings());
    await tester.pumpAndSettle();
    expect(find.text("Start this week's parsha"), findsOneWidget);
  });

  testWidgets('Back returns a step of onboarding, and leaves the app only from the welcome', (tester) async {
    final exits = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemNavigator.pop') exits.add(call);
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    final c = await pumpApp(tester, settings: const AppSettings());
    final router = c.read(routerProvider);
    await tester.pumpAndSettle();

    await tester.tap(find.text("Start this week's parsha"));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/welcome/location');
    await tester.tap(find.text('In Israel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/welcome/method');
    expect(find.text('Step 2 of 3'), findsOneWidget);

    // The system's Back, as on Android.
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text('Step 1 of 3'), findsOneWidget);
    expect(find.text('Where will you be this Shabbat?'), findsOneWidget);
    // The choice made there is kept.
    expect(c.read(settingsProvider).readingSchedule, ReadingSchedule.israel);
    expect(exits, isEmpty);

    // The app bar's Back, the same way.
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Step 1 of 3'), findsOneWidget);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(find.text("Start this week's parsha"), findsOneWidget);
    expect(exits, isEmpty);

    // From the welcome, Back leaves the app.
    expect(await tester.binding.handlePopRoute(), isFalse);
    expect(exits, hasLength(1));
  });

  testWidgets('a step of onboarding opens at its own address, over the welcome', (tester) async {
    final c = await pumpApp(tester, settings: const AppSettings());
    final router = c.read(routerProvider);
    await tester.pumpAndSettle();
    router.go('/welcome/plan');
    await tester.pumpAndSettle();
    expect(find.text('Step 3 of 3'), findsOneWidget);
    expect(find.text('Start reading'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text("Start this week's parsha"), findsOneWidget);

    // Once onboarding is done, the steps lead to Today.
    c.read(settingsProvider.notifier).update((s) => s.copyWith(onboardingComplete: true));
    await tester.pumpAndSettle();
    router.go('/welcome/method');
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/today');
  });

  testWidgets('the policies, sources and guide open before onboarding', (tester) async {
    final c = await pumpApp(tester, settings: const AppSettings());
    final router = c.read(routerProvider);
    await tester.pumpAndSettle();

    router.go('/legal/privacy');
    await tester.pumpAndSettle();
    expect(find.byType(LegalScreen), findsOneWidget);
    // Home is the welcome, until onboarding is done.
    await tester.tap(find.widgetWithIcon(IconButton, Icons.home_outlined));
    await tester.pumpAndSettle();
    expect(find.text("Start this week's parsha"), findsOneWidget);

    router.go('/sources');
    await tester.pumpAndSettle();
    expect(find.byType(SourcesScreen), findsOneWidget);
    router.go('/guide');
    await tester.pumpAndSettle();
    expect(find.byType(GuideScreen), findsOneWidget);

    router.go('/progress');
    await tester.pumpAndSettle();
    expect(find.text("Start this week's parsha"), findsOneWidget);
  });

  testWidgets('today screen renders', (tester) async {
    await pumpApp(tester);
    await tester.pumpAndSettle();
    // The default test window is tablet-sized, so navigation is a rail.
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.text('Parshat Bereshit').evaluate().isNotEmpty || find.textContaining('Parshat').evaluate().isNotEmpty, isTrue);
  });
}
