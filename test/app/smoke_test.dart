import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikrah/app/providers.dart';
import 'package:shnayim_mikrah/app/router.dart';
import 'package:shnayim_mikrah/features/about/guide_screen.dart';
import 'package:shnayim_mikrah/features/about/legal_screen.dart';
import 'package:shnayim_mikrah/features/about/sources_screen.dart';
import 'package:shnayim_mikrah/features/notes/notes_screen.dart';
import 'package:shnayim_mikrah/features/parsha/parsha_tab.dart';
import 'package:shnayim_mikrah/features/parsha/week_overview_screen.dart';
import 'package:shnayim_mikrah/features/progress/progress_screen.dart';
import 'package:shnayim_mikrah/features/settings/app_settings.dart';
import 'package:shnayim_mikrah/features/today/today_screen.dart';

import '../helpers.dart';

/// Records each time the app leaves, as the system's Back does when the app
/// has nowhere to go back to.
List<MethodCall> _recordExits(WidgetTester tester) => _recordBack(tester).exits;

/// Records what the app tells the system about Back: each time it leaves,
/// and each time it says whether it handles Back itself. Android 13 and
/// later send Back to the app only while it does (a back swipe otherwise
/// previews the home screen, and leaves). The app says so only once it is
/// running, as it is here.
({List<MethodCall> exits, List<bool> handlesBack}) _recordBack(WidgetTester tester) {
  final exits = <MethodCall>[];
  final handlesBack = <bool>[];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'SystemNavigator.pop') exits.add(call);
    if (call.method == 'SystemNavigator.setFrameworkHandlesBack') handlesBack.add(call.arguments as bool);
    return null;
  });
  addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
  tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
  return (exits: exits, handlesBack: handlesBack);
}

/// Android's predictive back gesture: a swipe from the screen's edge,
/// released.
Future<void> _backSwipe(WidgetTester tester) async {
  Future<void> send(String method, [Map<String, Object>? arguments]) =>
      tester.binding.defaultBinaryMessenger.handlePlatformMessage(
        'flutter/backgesture',
        const StandardMethodCodec().encodeMethodCall(MethodCall(method, arguments)),
        (_) {},
      );
  await send('startBackGesture', {
    'touchOffset': [5.0, 300.0],
    'progress': 0.0,
    'swipeEdge': 0,
  });
  await tester.pump();
  await send('updateBackGestureProgress', {'x': 200.0, 'y': 300.0, 'progress': 0.5, 'swipeEdge': 0});
  await tester.pump();
  await send('commitBackGesture');
  await tester.pumpAndSettle();
}

/// A destination of the navigation rail (the default test window is
/// tablet-sized): its label, not the bold copy laid out unseen beneath it.
Finder _tab(String label) => find.descendant(of: find.byType(NavigationRail), matching: find.text(label)).hitTestable();

int? _selectedTab(WidgetTester tester) => tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex;

void main() {
  testWidgets('first launch shows onboarding', (tester) async {
    await pumpApp(tester, settings: const AppSettings());
    await tester.pumpAndSettle();
    expect(find.text('Start this week’s parsha'), findsOneWidget);
  });

  testWidgets('Back returns a step of onboarding, and leaves the app only from the welcome', (tester) async {
    final exits = _recordExits(tester);
    final c = await pumpApp(tester, settings: const AppSettings());
    final router = c.read(routerProvider);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Start this week’s parsha'));
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
    expect(find.text('Start this week’s parsha'), findsOneWidget);
    expect(exits, isEmpty);

    // From the welcome, Back leaves the app.
    expect(await tester.binding.handlePopRoute(), isFalse);
    expect(exits, hasLength(1));
  });

  testWidgets('Back from another tab returns to Today, and only then leaves', (tester) async {
    final exits = _recordExits(tester);
    final c = await pumpApp(tester);
    final router = c.read(routerProvider);
    await tester.pumpAndSettle();

    for (final (label, path) in [
      ('Parsha', '/parsha'),
      ('Progress', '/progress'),
      ('Community', '/community'),
      ('Settings', '/settings'),
    ]) {
      await tester.tap(_tab(label));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, path);

      // The system's Back, as on Android.
      expect(await tester.binding.handlePopRoute(), isTrue, reason: 'Back from $label');
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/today', reason: 'Back from $label');
      expect(_selectedTab(tester), 0);
      expect(find.byType(TodayScreen), findsOneWidget);
      expect(exits, isEmpty);
    }

    // From Today, Back leaves the app.
    expect(await tester.binding.handlePopRoute(), isFalse);
    expect(exits, hasLength(1));
  });

  testWidgets('Back closes a week open in Parsha before it returns to Today', (tester) async {
    final exits = _recordExits(tester);
    final c = await pumpApp(tester);
    final router = c.read(routerProvider);
    await tester.pumpAndSettle();
    router.go('/parsha/week/5787:2');
    await tester.pumpAndSettle();
    expect(find.byType(WeekOverviewScreen), findsOneWidget);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/parsha');
    expect(_selectedTab(tester), 1);
    expect(find.byType(ParshaTab), findsOneWidget);
    expect(find.byType(WeekOverviewScreen), findsNothing);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/today');
    expect(exits, isEmpty);

    expect(await tester.binding.handlePopRoute(), isFalse);
    expect(exits, hasLength(1));
  });

  testWidgets('Back closes a page over another tab, then returns to Today', (tester) async {
    final exits = _recordExits(tester);
    final c = await pumpApp(tester);
    final router = c.read(routerProvider);
    await tester.pumpAndSettle();
    await tester.tap(_tab('Progress'));
    await tester.pumpAndSettle();
    router.push('/notes');
    await tester.pumpAndSettle();
    expect(find.byType(NotesScreen), findsOneWidget);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/progress');
    expect(find.byType(NotesScreen), findsNothing);
    expect(find.byType(ProgressScreen), findsOneWidget);

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/today');
    expect(exits, isEmpty);
  });

  testWidgets('the app handles Back wherever there is somewhere to go back to', (tester) async {
    final back = _recordBack(tester);
    final c = await pumpApp(tester);
    final router = c.read(routerProvider);
    await tester.pumpAndSettle();
    expect(back.handlesBack.last, isFalse, reason: 'Today');

    await tester.tap(_tab('Progress'));
    await tester.pumpAndSettle();
    expect(back.handlesBack.last, isTrue, reason: 'Progress');

    // Today with this week's page open, shown again by Back or by its tab:
    // its tab's navigator says nothing as it is, and Back must still close
    // the page rather than leave the app.
    await tester.tap(_tab('Today'));
    await tester.pumpAndSettle();
    expect(back.handlesBack.last, isFalse, reason: 'Today');
    router.push('/today/week/5787:2');
    await tester.pumpAndSettle();
    expect(back.handlesBack.last, isTrue, reason: 'a week open in Today');
    for (final returnBy in ['Back', 'the tab']) {
      await tester.tap(_tab('Progress'));
      await tester.pumpAndSettle();
      expect(back.handlesBack.last, isTrue, reason: 'Progress');
      if (returnBy == 'Back') {
        expect(await tester.binding.handlePopRoute(), isTrue);
      } else {
        await tester.tap(_tab('Today'));
      }
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/today/week/5787:2', reason: 'back to Today by $returnBy');
      expect(find.byType(WeekOverviewScreen), findsOneWidget);
      expect(back.handlesBack.last, isTrue, reason: 'a week open in Today, back to it by $returnBy');
    }

    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/today');
    expect(find.byType(WeekOverviewScreen), findsNothing);
    expect(back.handlesBack.last, isFalse, reason: 'Today');
    expect(back.exits, isEmpty);
  });

  testWidgets('Back leaves the app from Today, even with a page open in another tab', (tester) async {
    final back = _recordBack(tester);
    final c = await pumpApp(tester);
    final router = c.read(routerProvider);
    await tester.pumpAndSettle();
    router.go('/parsha/week/5787:2');
    await tester.pumpAndSettle();
    expect(back.handlesBack.last, isTrue, reason: 'a week open in Parsha');

    await tester.tap(_tab('Today'));
    await tester.pumpAndSettle();
    // So a back swipe previews the home screen.
    expect(back.handlesBack.last, isFalse, reason: 'Today, with a week open in Parsha');
    expect(await tester.binding.handlePopRoute(), isTrue);
    await tester.pumpAndSettle();
    expect(back.exits, hasLength(1));

    // The week is still open in Parsha.
    await tester.tap(_tab('Parsha'));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/parsha/week/5787:2');
    expect(back.handlesBack.last, isTrue, reason: 'a week open in Parsha');
  });

  group('a back swipe', () {
    testWidgets('on another tab returns to Today, leaving the page open there', (tester) async {
      final c = await pumpApp(tester);
      final router = c.read(routerProvider);
      await tester.pumpAndSettle();
      router.push('/today/week/5787:2');
      await tester.pumpAndSettle();
      await tester.tap(_tab('Progress'));
      await tester.pumpAndSettle();

      await _backSwipe(tester);
      expect(_selectedTab(tester), 0);
      expect(router.state.uri.path, '/today/week/5787:2');
      expect(find.byType(WeekOverviewScreen), findsOneWidget);
    });

    testWidgets("closes the page on show alone, not one in another tab", (tester) async {
      final c = await pumpApp(tester);
      final router = c.read(routerProvider);
      await tester.pumpAndSettle();
      router.push('/today/week/5787:2');
      await tester.pumpAndSettle();
      await tester.tap(_tab('Parsha'));
      await tester.pumpAndSettle();
      router.push('/parsha/week/5787:3');
      await tester.pumpAndSettle();

      await _backSwipe(tester);
      expect(router.state.uri.path, '/parsha');
      expect(find.byType(ParshaTab), findsOneWidget);
      expect(find.byType(WeekOverviewScreen), findsNothing);

      await tester.tap(_tab('Today'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/today/week/5787:2');
      expect(find.byType(WeekOverviewScreen), findsOneWidget);
    });

    testWidgets('closes a page over the tabs, or a dialog, and not the page beneath it', (tester) async {
      final c = await pumpApp(tester);
      final router = c.read(routerProvider);
      await tester.pumpAndSettle();
      router.go('/parsha/week/5787:2');
      await tester.pumpAndSettle();

      router.push('/notes');
      await tester.pumpAndSettle();
      await _backSwipe(tester);
      expect(find.byType(NotesScreen), findsNothing);
      expect(router.state.uri.path, '/parsha/week/5787:2');
      expect(find.byType(WeekOverviewScreen), findsOneWidget);

      unawaited(showDialog<void>(
        context: tester.element(find.byType(WeekOverviewScreen)),
        builder: (_) => const AlertDialog(content: Text('A dialog')),
      ));
      await tester.pumpAndSettle();
      await _backSwipe(tester);
      expect(find.text('A dialog'), findsNothing);
      expect(router.state.uri.path, '/parsha/week/5787:2');
      expect(find.byType(WeekOverviewScreen), findsOneWidget);
    });
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
    expect(find.text('Start this week’s parsha'), findsOneWidget);

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
    expect(find.text('Start this week’s parsha'), findsOneWidget);

    router.go('/sources');
    await tester.pumpAndSettle();
    expect(find.byType(SourcesScreen), findsOneWidget);
    router.go('/guide');
    await tester.pumpAndSettle();
    expect(find.byType(GuideScreen), findsOneWidget);

    router.go('/progress');
    await tester.pumpAndSettle();
    expect(find.text('Start this week’s parsha'), findsOneWidget);
  });

  testWidgets('today screen renders', (tester) async {
    final handle = tester.ensureSemantics();
    // A Monday: on a Friday the title page names the eve of Shabbat instead.
    await pumpApp(tester, now: DateTime(2026, 10, 19, 10));
    await tester.pumpAndSettle();
    // The default test window is tablet-sized, so navigation is a rail.
    expect(find.byType(NavigationRail), findsOneWidget);
    // The title page: its eyebrow, the parsha named as a heading, and the
    // button that names where the reading starts.
    expect(find.text('Parshat HaShavua'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Parshat (?!HaShavua)')), findsOneWidget);
    expect(
      find.ancestor(of: find.textContaining(RegExp(r'^(Start|Continue) · ')), matching: find.byType(FilledButton)),
      findsOneWidget,
    );
    handle.dispose();
  });
}
