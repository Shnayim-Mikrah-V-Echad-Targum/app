import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/services/notifications.dart';

import '../helpers.dart';
import 'routes.dart';

/// Automated accessibility checks for every main screen: tap targets
/// (48dp Android / 44pt iOS) and labeled controls, in English and Hebrew, at
/// phone and tablet sizes and at 200% text size. Text is laid out in the
/// bundled fonts, so sizes and overflow are the real ones. Text contrast is
/// checked in text_contrast_test.dart.
void main() {
  setUpAll(loadBundledFonts);

  Future<ProviderContainer> open(
    WidgetTester tester,
    String route, {
    AppSettings? settings,
    Size size = const Size(412, 915),
    double textScale = 1,
    NotificationService? notifications,
  }) =>
      openRoute(
        tester,
        route,
        settings: settings ?? a11ySettings,
        now: a11yMonday,
        size: size,
        textScale: textScale,
        notifications: notifications,
      );

  for (final route in a11yRoutes) {
    testWidgets('a11y guidelines: $route', (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester, route);
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  }

  for (final route in a11yOnboardingRoutes) {
    for (final hebrew in [false, true]) {
      testWidgets('a11y guidelines: $route${hebrew ? ', Hebrew' : ''}', (tester) async {
        final handle = tester.ensureSemantics();
        await open(tester, route, settings: AppSettings(language: hebrew ? AppLanguage.hebrew : AppLanguage.system));
        expect(tester.takeException(), isNull);
        if (route == '/welcome/location') {
          // With the reason it is asked shown.
          await tester.tap(find.byIcon(Icons.expand_more));
          await tester.pumpAndSettle();
        }
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });
    }

    testWidgets('no overflow at 200% text size: $route', (tester) async {
      await open(tester, route, settings: const AppSettings(), textScale: 2);
      expect(tester.takeException(), isNull);
    });
  }

  // Material leaves no space above and below a button's label at this size.
  testWidgets("at 200% text size the welcome's wrapped button labels keep clear of the buttons' edges", (tester) async {
    await open(tester, '/welcome', settings: const AppSettings(), textScale: 2);
    for (final button in [find.byType(FilledButton), find.widgetWithText(TextButton, 'I already use Shnayim Mikra')]) {
      final box = tester.getRect(button);
      final label = tester.getRect(find.descendant(of: button, matching: find.byType(Text)));
      expect(label.height, greaterThan(60), reason: 'two lines of 30 px text');
      expect(label.top - box.top, greaterThanOrEqualTo(7.5));
      expect(box.bottom - label.bottom, greaterThanOrEqualTo(7.5));
    }
  });

  // Text contrast on this page is checked in text_contrast_test.dart.
  testWidgets('a11y guidelines: reminders, where they can be scheduled, with all of them on', (tester) async {
    final handle = tester.ensureSemantics();
    await open(tester, '/settings/reminders', settings: a11yRemindersOn, notifications: PhoneNotifications());
    expect(find.text('Daily reminder time'), findsOneWidget);
    expect(find.text('Erev Shabbat reminder time'), findsOneWidget);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    handle.dispose();
  });

  for (final route in ['/today', '/parsha', '/progress', '/settings/display', '/nope']) {
    testWidgets('no overflow at 200% text size: $route', (tester) async {
      await open(tester, route, textScale: 2);
      expect(tester.takeException(), isNull);
    });
  }

  // The reader, the most text-dense screen, in the real fonts: guided and
  // full text, in English and Hebrew. Its text contrast and focus-mode ink
  // are checked on the test font in test/app/reader_widget_test.dart.
  group('reader', () {
    /// Opens Noach's Rishon and waits for its texts to load.
    Future<void> openReader(WidgetTester tester, {String mode = '', bool hebrew = false, double textScale = 1}) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final c = await pumpApp(
        tester,
        settings: AppSettings(onboardingComplete: true, language: hebrew ? AppLanguage.hebrew : AppLanguage.system),
        now: a11yMonday,
      );
      // Not openRoute: its settling would wait on the loading spinner.
      c.read(routerProvider).go('/read/5787:2/0$mode');
      await tester.pump();
      await tester.pump();
      for (var i = 0; i < 30 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    }

    for (final (mode, name) in [('', 'guided'), ('?mode=full', 'full text')]) {
      for (final hebrew in [false, true]) {
        testWidgets('a11y guidelines: $name${hebrew ? ', Hebrew' : ''}', (tester) async {
          final handle = tester.ensureSemantics();
          await openReader(tester, mode: mode, hebrew: hebrew);
          expect(tester.takeException(), isNull);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          handle.dispose();
        });
      }
    }

    for (final hebrew in [false, true]) {
      testWidgets('no overflow at 200% text size${hebrew ? ', Hebrew' : ''}', (tester) async {
        await openReader(tester, hebrew: hebrew, textScale: 2);
        expect(tester.takeException(), isNull);
      });
    }
  });

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
