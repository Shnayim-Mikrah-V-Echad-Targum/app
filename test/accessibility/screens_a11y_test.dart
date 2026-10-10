import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/services/notifications.dart';

import '../helpers.dart';

/// Automated accessibility checks for every main screen: tap targets
/// (48dp Android / 44pt iOS), labeled controls, and text contrast — in
/// English and Hebrew, phone and tablet sizes, and at 200% text size.
void main() {
  final monday = DateTime(2026, 10, 12, 10);
  const routes = [
    '/today',
    '/parsha',
    '/parsha/browse',
    '/progress',
    '/community',
    '/settings',
    '/settings/reading',
    '/settings/display',
    '/settings/accessibility',
    '/settings/reminders',
    '/settings/about',
    '/settings/account',
    '/guide',
    '/sources',
    '/legal/privacy',
    // A week within a tab, under its navigation bar.
    '/parsha/week/5787:2',
    // Opened directly, as on a web reload: with a home button.
    '/week/5787:1',
    // Links that lead nowhere.
    '/nope',
    '/community/forum/xyz',
  ];

  Future<ProviderContainer> open(
    WidgetTester tester,
    String route, {
    AppSettings? settings,
    Size size = const Size(412, 915),
    double textScale = 1,
    NotificationService? notifications,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final container = await pumpApp(
      tester,
      settings: settings ?? AppSettings(onboardingComplete: true, joinDate: null),
      now: monday,
      notifications: notifications,
    );
    container.read(routerProvider).go(route);
    await tester.pumpAndSettle();
    // Let asset-backed previews (e.g. display settings) load.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
    await tester.pumpAndSettle();
    return container;
  }

  for (final route in routes) {
    testWidgets('a11y guidelines: $route', (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester, route);
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  }

  testWidgets('a11y guidelines: reminders, where they can be scheduled, with all of them on', (tester) async {
    final handle = tester.ensureSemantics();
    await open(
      tester,
      '/settings/reminders',
      settings: const AppSettings(onboardingComplete: true, dailyReminder: true, fridayReminder: true, checkInReminder: true),
      notifications: PhoneNotifications(),
    );
    expect(find.text('Daily reminder time'), findsOneWidget);
    expect(find.text('Erev Shabbat reminder time'), findsOneWidget);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });

  for (final theme in [AppThemeMode.dark, AppThemeMode.sepia, AppThemeMode.highContrastLight, AppThemeMode.highContrastDark]) {
    testWidgets('text contrast in the ${theme.name} theme', (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester, '/today', settings: AppSettings(onboardingComplete: true, theme: theme));
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  }

  for (final route in ['/today', '/parsha', '/progress', '/settings/display', '/nope']) {
    testWidgets('no overflow at 200% text size: $route', (tester) async {
      await open(tester, route, textScale: 2);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('Hebrew interface is right-to-left and passes the guidelines', (tester) async {
    final handle = tester.ensureSemantics();
    await open(tester, '/today', settings: const AppSettings(onboardingComplete: true, language: AppLanguage.hebrew));
    expect(find.text('היום'), findsWidgets);
    final dir = Directionality.of(tester.element(find.byType(Scaffold).first));
    expect(dir, TextDirection.rtl);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  group('semantics', () {
    String location(ProviderContainer c) => c.read(routerProvider).state.uri.toString();

    testWidgets('a day of the week strip is a button that can be activated', (tester) async {
      final handle = tester.ensureSemantics();
      final c = await open(tester, '/today');
      expect(
        tester.getSemantics(find.bySemanticsLabel(RegExp('^Monday'))),
        isSemantics(isButton: true, hasTapAction: true, isFocusable: true),
      );
      // Shabbat has no reading to open.
      expect(
        tester.getSemantics(find.bySemanticsLabel(RegExp('^Saturday'))),
        isSemantics(isButton: false, hasTapAction: false),
      );
      tester.semantics.tap(find.semantics.byLabel(RegExp('^Monday')));
      await tester.pump();
      await tester.pump();
      expect(location(c), '/read/5787:2/1', reason: "Monday's reading is Sheni");
      handle.dispose();
    });

    testWidgets('a parsha of the Torah map is a button that can be activated', (tester) async {
      final handle = tester.ensureSemantics();
      final c = await open(tester, '/progress');
      expect(
        tester.getSemantics(find.bySemanticsLabel(RegExp('^Noach: '))),
        isSemantics(isButton: true, hasTapAction: true, isFocusable: true),
      );
      tester.semantics.tap(find.semantics.byLabel(RegExp('^Noach: ')));
      await tester.pumpAndSettle();
      expect(location(c), '/progress/week/5787:2');
      handle.dispose();
    });

    testWidgets('a slider is named by its setting, and its buttons by what they do', (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester, '/settings/display');
      expect(
        tester.getSemantics(find.byType(Slider).first),
        isSemantics(label: 'Reading size', value: '100%', isSlider: true),
      );
      expect(find.byTooltip('Decrease Reading size'), findsOneWidget);
      expect(find.byTooltip('Increase Reading size'), findsOneWidget);
      handle.dispose();
    });

    testWidgets("the parsha's title is a heading of its own, apart from its rings", (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester, '/today');
      final title = tester.getSemantics(find.text('Parshat Noach'));
      expect(title, isSemantics(label: 'Parshat Noach', isHeader: true, isImage: false));
      expect(title.getSemanticsData().headingLevel, 1);
      expect(
        tester.getSemantics(find.bySemanticsLabel(RegExp(r'^0 of 7 aliyot\. '))),
        isSemantics(
          label: '0 of 7 aliyot. First reading: 0 of 7. Second reading: 0 of 7. Targum: 0 of 7',
          isImage: true,
          isHeader: false,
        ),
      );
      handle.dispose();
    });

    testWidgets('a page keeps its headings, texts and controls apart', (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester, '/week/5787:2');
      // Not one node with the texts above it and the haftarah's button below.
      expect(
        tester.getSemantics(find.text('0 of 7 aliyot')),
        isSemantics(label: '0 of 7 aliyot', isHeader: true, isButton: false, hasTapAction: false),
      );
      expect(find.byTooltip("More options for Revi'i"), findsOneWidget);

      await open(tester, '/sources');
      expect(tester.getSemantics(find.text('Targum Onkelos')), isSemantics(label: 'Targum Onkelos', isHeader: true));
      handle.dispose();
    });
  });

  testWidgets('desktop width uses a navigation rail', (tester) async {
    await open(tester, '/today', size: const Size(1366, 900));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
}
