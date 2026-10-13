import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/features/community/data/demo_forum_repository.dart';
import 'package:shnayim_mikra/features/community/ui/thread_screen.dart' show PostCard;
import 'package:shnayim_mikra/features/reader/reader_bottom_bar.dart';
import 'package:shnayim_mikra/features/reader/scripture_text.dart' show ScriptureVerse;
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/services/notifications.dart';
import 'package:shnayim_mikra/ui/theme/focus.dart';
import 'package:shnayim_mikra/ui/theme/sefer_colors.dart';
import 'package:shnayim_mikra/ui/widgets/common.dart' show NoticeBanner;
import 'package:shnayim_mikra/ui/widgets/lines.dart' show WholeWords;
import 'package:shnayim_mikra/ui/widgets/paper_group.dart';
import 'package:shnayim_mikra/ui/widgets/progress_widgets.dart';

import '../helpers.dart';
import 'routes.dart';
import 'semantics_invariants.dart';

/// Automated accessibility checks for every main screen: tap targets
/// (48dp Android / 44pt iOS), labeled controls and the [SemanticsInvariants],
/// in English and Hebrew, at phone and desktop sizes and at 200% and 300%
/// text size. Text is laid out in the bundled fonts, so sizes and overflow
/// are the real ones. Text contrast, and these guidelines in every theme,
/// are checked in semantics_invariants_test.dart and
/// semantics_invariants_pages_test.dart.
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
      await expectLater(tester, meetsGuideline(semanticsInvariants));
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
        await expectLater(tester, meetsGuideline(semanticsInvariants));
        handle.dispose();
      });
    }

    testWidgets('no overflow or broken word at 200% text size: $route', (tester) async {
      await open(tester, route, settings: const AppSettings(), textScale: 2);
      expect(tester.takeException(), isNull);
      expectWholeWords(tester);
    });
  }

  // Material leaves no space above and below a button's label at this size.
  // On a 360 dp phone, where both labels wrap.
  testWidgets("at 200% text size the welcome's wrapped button labels keep clear of the buttons' edges", (tester) async {
    await open(tester, '/welcome', settings: const AppSettings(), size: const Size(360, 800), textScale: 2);
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
    expect(find.text('Move'), findsOneWidget);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(semanticsInvariants));
    handle.dispose();
  });

  for (final route in ['/today', '/parsha', '/progress', '/settings/display', '/nope']) {
    testWidgets('no overflow or broken word at 200% text size: $route', (tester) async {
      await open(tester, route, textScale: 2);
      expect(tester.takeException(), isNull);
      expectWholeWords(tester);
    });
  }

  // Hebrew sets the parsha's and the aliyot's names in larger letters.
  for (final route in ['/today', '/progress', '/week/5787:2']) {
    testWidgets('no overflow or broken word at 200% text size, Hebrew: $route', (tester) async {
      await open(
        tester,
        route,
        settings: const AppSettings(onboardingComplete: true, language: AppLanguage.hebrew),
        textScale: 2,
      );
      expect(tester.takeException(), isNull);
      expectWholeWords(tester);
    });
  }

  // The largest text a phone offers (iOS's largest accessibility size), on
  // the smallest phone the app is laid out for: nothing overflows, and no
  // word breaks across lines.
  for (final hebrew in [false, true]) {
    testWidgets('no overflow or broken word at 300% on a 320 dp phone: /today${hebrew ? ', Hebrew' : ''}',
        (tester) async {
      await open(
        tester,
        '/today',
        settings: AppSettings(onboardingComplete: true, language: hebrew ? AppLanguage.hebrew : AppLanguage.system),
        size: const Size(320, 640),
        textScale: 3,
      );
      expect(tester.takeException(), isNull);
      expectWholeWords(tester);
    });
  }

  // The day of rest's title page, set in the space under the header (§9
  // Today, 8), is taller than the screen at this size: it scrolls, and the
  // way to the parsha is reached. It meets the guidelines at a phone's size.
  for (final hebrew in [false, true]) {
    final language = hebrew ? ', Hebrew' : '';
    final settings = AppSettings(onboardingComplete: true, language: hebrew ? AppLanguage.hebrew : AppLanguage.system);
    final shabbat = DateTime(2026, 10, 10, 11);

    testWidgets('no overflow or broken word at 300% on a 320 dp phone: /today on Shabbat$language', (tester) async {
      final c = await openRoute(
        tester,
        '/today',
        settings: settings,
        now: shabbat,
        size: const Size(320, 640),
        textScale: 3,
      );
      expect(tester.takeException(), isNull);
      expectWholeWords(tester);
      final open = find.text(hebrew ? 'לפרשה' : 'Open the parsha');
      expect(tester.getRect(open).top, greaterThan(640), reason: 'below the screen at first');
      await tester.scrollUntilVisible(open, 200, scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(open);
      await tester.pumpAndSettle();
      expect(c.read(routerProvider).state.uri.path, '/today/week/5787:1');
    });

    testWidgets('a11y guidelines: /today on Shabbat$language', (tester) async {
      final handle = tester.ensureSemantics();
      await openRoute(tester, '/today', settings: settings, now: shabbat);
      expect(tester.takeException(), isNull);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(semanticsInvariants));
      handle.dispose();
    });
  }

  // A name of two parshiyot, of more than one word, stays whole: "Acharei"
  // over "Mot-Kedoshim", never "Acharei Mot-" over "Kedoshim". The Hebrew
  // UI names it in English under the Hebrew.
  for (final hebrew in [false, true]) {
    testWidgets(
        'no overflow or broken word at 300% on a 320 dp phone: /today in a week of two parshiyot${hebrew ? ', Hebrew' : ''}',
        (tester) async {
      await openRoute(
        tester,
        '/today',
        settings: AppSettings(onboardingComplete: true, language: hebrew ? AppLanguage.hebrew : AppLanguage.system),
        now: DateTime(2028, 5, 1, 10),
        size: const Size(320, 640),
        textScale: 3,
      );
      expect(tester.takeException(), isNull);
      expect(find.text(WholeWords.unbroken('Acharei Mot-Kedoshim')), findsOneWidget);
      expectWholeWords(tester);
    });
  }

  // The same on the pages most read, as the capture harness's Friday of
  // Bereshit shows them (test/helpers.dart): a grace day told under the
  // week, a special haftarah, aliyot left from days gone by on the week's
  // page, a year's Torah map, the forums' activity and a discussion. Each
  // page is opened in English and then shown in Hebrew. A forum's list of
  // discussions holds the longest lines of facts ("… · thanked 13 times").
  for (final route in [
    '/today',
    '/parsha',
    '/progress',
    '/community',
    '/settings',
    '/community/forum/questions',
    '/community/thread/1',
  ]) {
    testWidgets('no overflow or broken word at 300% on a 320 dp phone, in either language, on Friday: $route',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 3;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final c = await pumpApp(
        tester,
        settings: AppSettings(onboardingComplete: true, joinDate: captureJoinDate),
        now: captureNow,
        progress: captureProgress(),
        forums: DemoForumRepository(clock: () => captureNow),
      );
      c.read(routerProvider).go(route);
      await tester.pumpAndSettle();
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 300)));
      await tester.pumpAndSettle();
      if (route == '/today') {
        expect(find.textContaining('covered by a grace day'), findsOneWidget);
        expect(find.textContaining('Shabbat Machar Chodesh'), findsOneWidget);
      }
      if (route == '/parsha') expect(find.byIcon(stillToReadIcon), findsWidgets);
      if (route == '/community/forum/questions') expect(find.textContaining('thanked'), findsWidgets);
      for (final language in [AppLanguage.system, AppLanguage.hebrew]) {
        c.read(settingsProvider.notifier).update((s) => s.copyWith(language: language));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: language.name);
        expectWholeWords(tester);
      }
    });
  }

  // §6.3 and §9 Parsha, 3: at the largest text on the smallest phone, the
  // whole page, a row stacks rather than squeeze its text between its icon
  // and its chevron. No row's title is drawn smaller than its subtitle, as
  // a title once was beside them to keep a long word whole, and the week's
  // aliyot give each fact a line of its own, whole, rather than a word.
  for (final route in ['/settings', '/parsha']) {
    testWidgets('at 300% on a 320 dp phone, in either language, no row title is smaller than its subtitle: $route',
        (tester) async {
      tester.view.physicalSize = const Size(320, 3600);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 3;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final c = await pumpApp(
        tester,
        settings: AppSettings(onboardingComplete: true, joinDate: captureJoinDate),
        now: captureNow,
        progress: captureProgress(),
      );
      c.read(routerProvider).go(route);
      await tester.pumpAndSettle();
      for (final hebrew in [false, true]) {
        final language = hebrew ? AppLanguage.hebrew : AppLanguage.system;
        c.read(settingsProvider.notifier).update((s) => s.copyWith(language: language));
        await tester.pumpAndSettle();
        final page = find.byType(Scrollable).first;
        tester.state<ScrollableState>(page).position.jumpTo(0);
        await tester.pumpAndSettle();
        final checked = <String>{};
        // Down the page, a viewport at a time, so that every row is built.
        while (true) {
          expect(tester.takeException(), isNull, reason: hebrew ? 'he' : 'en');
          expectWholeWords(tester);
          checked.addAll(_expectTitlesNoSmallerThanSubtitles(tester));
          if (route == '/parsha') _expectFactsWhole(tester, hebrew: hebrew);
          final position = tester.state<ScrollableState>(page).position;
          if (position.pixels >= position.maxScrollExtent) break;
          position.jumpTo(position.pixels + 2000);
          await tester.pumpAndSettle();
        }
        // As far as the page's foot.
        final last = route == '/parsha' ? (hebrew ? 'הפטרה' : 'Haftarah') : (hebrew ? 'אודות האפליקציה' : 'About this app');
        expect(checked, contains(last));
      }
    });
  }

  // The reply box's label is never cut short: at the largest text, on the
  // smallest phone, the Reply button goes under the field, at its end, and
  // the label stands on the outline. At 100% the button stays beside it.
  group('the reply box', () {
    Future<void> openThread(WidgetTester tester, {required bool hebrew, required double textScale}) => open(
          tester,
          '/community/thread/1',
          settings: AppSettings(onboardingComplete: true, language: hebrew ? AppLanguage.hebrew : AppLanguage.system),
          size: const Size(320, 640),
          textScale: textScale,
        );

    /// The field's label, as the field lays it out.
    RenderParagraph label(WidgetTester tester, {required bool hebrew}) => tester.renderObject(find.descendant(
          of: find.byType(InputDecorator),
          matching: find.text(hebrew ? 'כתיבת תגובה' : 'Write a reply'),
        ));

    for (final hebrew in [false, true]) {
      testWidgets('at 300% on a 320 dp phone, keeps its label whole, the button under the field${hebrew ? ', Hebrew' : ''}',
          (tester) async {
        await openThread(tester, hebrew: hebrew, textScale: 3);
        expect(tester.takeException(), isNull);
        expect(label(tester, hebrew: hebrew).didExceedMaxLines, isFalse);
        final field = tester.getRect(find.byType(TextField));
        final button = tester.getRect(find.byType(FilledButton));
        expect(button.top, greaterThan(field.bottom));
        // At the field's end.
        if (hebrew) {
          expect(button.left, moreOrLessEquals(field.left));
        } else {
          expect(button.right, moreOrLessEquals(field.right));
        }
      });

      testWidgets('at 100% on a 320 dp phone, sets the button beside the field${hebrew ? ', Hebrew' : ''}',
          (tester) async {
        await openThread(tester, hebrew: hebrew, textScale: 1);
        expect(tester.takeException(), isNull);
        expect(label(tester, hebrew: hebrew).didExceedMaxLines, isFalse);
        final field = tester.getRect(find.byType(TextField));
        final button = tester.getRect(find.byType(FilledButton));
        expect(button.bottom, lessThan(field.bottom), reason: 'level with a one-line field');
        if (hebrew) {
          expect(button.right, lessThan(field.left));
        } else {
          expect(button.left, greaterThan(field.right));
        }
      });
    }

    // The device's Bold text widens the label: at 300% on a 360 dp phone the
    // whole width holds it in regular weight, but not in bold, so there it
    // stands on the outline.
    testWidgets('with Bold text at 300% on a 360 dp phone, keeps its label whole', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(boldText: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await open(tester, '/community/thread/1', size: const Size(360, 640), textScale: 3);
      expect(tester.takeException(), isNull);
      final paragraph = label(tester, hebrew: false);
      expect(paragraph.text.style?.fontWeight, FontWeight.bold);
      expect(paragraph.didExceedMaxLines, isFalse);
    });

    // A label on the outline stands half above the field: at large text, the
    // field leaves room above it, so that the label stays clear of the
    // composer's hairline, or of the post being answered.
    for (final hebrew in [false, true]) {
      for (final textScale in [2.0, 3.0]) {
        testWidgets(
            'at ${(textScale * 100).round()}% on a 320 dp phone, sets its label on the outline clear of what is '
            'above${hebrew ? ', Hebrew' : ''}', (tester) async {
          await openThread(tester, hebrew: hebrew, textScale: textScale);
          final composer = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_Composer');
          final hairline = tester.getRect(find.descendant(of: composer, matching: find.byType(Divider)));
          double labelTop() => label(tester, hebrew: hebrew).localToGlobal(Offset.zero).dy;

          // With the focus and nothing yet written, the label floats.
          await tester.tap(find.byType(TextField));
          await tester.pumpAndSettle();
          expect(labelTop(), greaterThanOrEqualTo(hairline.bottom));

          // The posts are built as they scroll into view, above the composer.
          final reply = find.descendant(of: find.byType(PostCard), matching: find.byIcon(Icons.reply));
          final list = find.descendant(of: find.byType(RefreshIndicator), matching: find.byType(Scrollable)).first;
          for (var i = 0; i < 30 && reply.evaluate().isEmpty; i++) {
            await tester.drag(list, const Offset(0, -200));
            await tester.pumpAndSettle();
          }
          await tester.ensureVisible(reply.first);
          await tester.pumpAndSettle();
          await tester.tap(reply.first);
          await tester.pumpAndSettle();
          final strip = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_ReplyingTo');
          expect(strip, findsOneWidget);
          expect(tester.takeException(), isNull);
          expect(labelTop(), greaterThanOrEqualTo(tester.getRect(strip).bottom));
        });
      }
    }

    // Five lines of 300% text, under the post being answered and over the
    // button, made the reply box taller than a 640-high phone has room for:
    // in Hebrew it covered half the app bar, and none of the thread showed.
    for (final hebrew in [false, true]) {
      testWidgets(
          'at 300% on a 320×640 phone, answering a post at length, stays under the app bar'
          '${hebrew ? ', Hebrew' : ''}', (tester) async {
        await openThread(tester, hebrew: hebrew, textScale: 3);
        final reply = find.descendant(of: find.byType(PostCard), matching: find.byIcon(Icons.reply));
        final list = find.descendant(of: find.byType(RefreshIndicator), matching: find.byType(Scrollable)).first;
        for (var i = 0; i < 30 && reply.evaluate().isEmpty; i++) {
          await tester.drag(list, const Offset(0, -200));
          await tester.pumpAndSettle();
        }
        await tester.ensureVisible(reply.first);
        await tester.pumpAndSettle();
        await tester.tap(reply.first);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextField), List.filled(6, 'Thank you — that settles it for me.').join(' '));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final composer = find.byWidgetPredicate((w) => w.runtimeType.toString() == '_Composer');
        final appBar = tester.getRect(find.byType(AppBar).last);
        // A line of the thread at least, between the app bar and the box.
        expect(tester.getRect(composer).top, greaterThan(appBar.bottom + 72));
        // What is written scrolls within the field, past its lines.
        expect(tester.widget<TextField>(find.byType(TextField)).maxLines, lessThan(5));
      });
    }

    testWidgets('at 100% on a phone, grows to five lines', (tester) async {
      await openThread(tester, hebrew: false, textScale: 1);
      expect(tester.widget<TextField>(find.byType(TextField)).maxLines, 5);
    });

    // The phone turned, say, or the text made smaller: the field moves, but
    // stays the same field.
    testWidgets('keeps the focus and what is written as the button moves beside the field', (tester) async {
      await openThread(tester, hebrew: false, textScale: 3);
      await tester.enterText(find.byType(TextField), 'Thank you.');
      await tester.pump();
      final field = find.descendant(of: find.byType(TextField), matching: find.byType(EditableText));
      final editable = tester.state<EditableTextState>(field);
      expect(editable.widget.focusNode.hasFocus, isTrue);
      expect(tester.getRect(find.byType(FilledButton)).top, greaterThan(tester.getRect(find.byType(TextField)).bottom));

      tester.platformDispatcher.textScaleFactorTestValue = 1;
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(tester.getRect(find.byType(FilledButton)).left, greaterThan(tester.getRect(find.byType(TextField)).right));
      expect(tester.state<EditableTextState>(field), same(editable));
      expect(editable.widget.focusNode.hasFocus, isTrue);
      expect(editable.textEditingValue.text, 'Thank you.');
    });
  });

  // §6.1: Tab reaches Today's main button, which takes the ring.
  testWidgets("Tab reaches Today's main button, which takes the focus ring", (tester) async {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
    await open(tester, '/today');
    final hero = find.ancestor(
      of: find.byIcon(Icons.menu_book),
      matching: find.byWidgetPredicate((w) => w is FilledButton),
    );
    expect(hero, findsOneWidget);
    bool focused() {
      final focus = FocusManager.instance.primaryFocus?.context;
      return focus != null &&
          find.descendant(of: hero, matching: find.byElementPredicate((e) => e == focus)).evaluate().isNotEmpty;
    }

    for (var i = 0; i < 40 && !focused(); i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    expect(focused(), isTrue, reason: 'Tab never reached the button');
    final sefer = Theme.of(tester.element(hero)).extension<SeferColors>()!;
    final shape = tester.widget<Material>(find.descendant(of: hero, matching: find.byType(Material)).first).shape;
    expect(
      shape,
      isA<FocusRingBorder>().having((b) => b.ring, 'ring', sefer.focus).having((b) => b.gap, 'gap', sefer.focusGap),
    );
    expect(
      hero,
      paints
        ..rrect(color: sefer.focusGap, strokeWidth: 2, style: PaintingStyle.stroke)
        ..rrect(color: sefer.focus, strokeWidth: 3, style: PaintingStyle.stroke),
    );
  });

  // The reader, the most text-dense screen, in the real fonts: guided and
  // full text, in English and Hebrew. Its text contrast and focus-mode ink
  // are checked on the test font in test/app/reader_widget_test.dart.
  group('reader', () {
    /// Opens Noach's Rishon and waits for its texts to load.
    Future<void> openReader(
      WidgetTester tester, {
      String mode = '',
      bool hebrew = false,
      double textScale = 1,
      bool wholeParsha = false,
      double readingScale = 1,
      Size size = const Size(412, 915),
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final c = await pumpApp(
        tester,
        settings: AppSettings(
          onboardingComplete: true,
          language: hebrew ? AppLanguage.hebrew : AppLanguage.system,
          fullTextWholeParsha: wholeParsha,
          readingScale: readingScale,
        ),
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
          // Verses, in the interface's language, which the invariants find.
          expect(find.bySemanticsLabel(SemanticsInvariants.verseLabel), findsWidgets);
          await expectLater(tester, meetsGuideline(semanticsInvariants));
          handle.dispose();
        });
      }
    }

    for (final hebrew in [false, true]) {
      testWidgets('no overflow or broken word at 200% text size${hebrew ? ', Hebrew' : ''}', (tester) async {
        await openReader(tester, hebrew: hebrew, textScale: 2);
        expect(tester.takeException(), isNull);
        expectWholeWords(tester);
      });
    }

    testWidgets('full text: no overflow or broken word at 200% text size, Hebrew', (tester) async {
      await openReader(tester, mode: '?mode=full', hebrew: true, textScale: 2);
      expect(tester.takeException(), isNull);
      expectWholeWords(tester);
    });

    // Scripture too: where a maqaf's words are too wide together for the
    // column, a line ends after the maqaf rather than inside a word.
    for (final hebrew in [false, true]) {
      testWidgets('no overflow or broken word at 300% on a 320 dp phone${hebrew ? ', Hebrew' : ''}', (tester) async {
        await openReader(tester, hebrew: hebrew, textScale: 3, size: const Size(320, 640));
        expect(tester.takeException(), isNull);
        expect(find.byType(ScriptureVerse), findsWidgets);
        expectWholeWords(tester);
      });
    }

    // The chrome grows to 200% at most, so that the reader opens on a verse
    // rather than on its ribbon and bars alone: as the capture harness shows
    // it, on Shlishi's Targum, whose title once took two lines in Hebrew.
    for (final hebrew in [false, true]) {
      testWidgets('at 300% on a 320 dp phone, the guided reader opens with a verse in view${hebrew ? ', Hebrew' : ''}',
          (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 3;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        final c = await pumpApp(
          tester,
          settings: AppSettings(
            onboardingComplete: true,
            joinDate: captureJoinDate,
            language: hebrew ? AppLanguage.hebrew : AppLanguage.system,
          ),
          now: captureNow,
          progress: captureProgress(),
        );
        c.read(routerProvider).go('/read/5787:1/2');
        await tester.pump();
        await tester.pump();
        for (var i = 0; i < 30 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
          await tester.pump();
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(find.text(hebrew ? 'קריאת התרגום' : 'Read the Targum'), findsOneWidget);
        final bar = tester.getSize(find.byType(ReaderBottomBar)).height;
        final verse = find.byType(ScriptureVerse).first;
        expect(tester.getTopLeft(verse).dy, lessThan(640 - bar - 48));
        // Its first line, whole, above the bar: the text is the verse's
        // tallest paragraph, beside its number.
        final text = tester
            .renderObjectList<RenderParagraph>(find.descendant(of: verse, matching: find.byType(RichText)))
            .reduce((a, b) => a.size.height >= b.size.height ? a : b);
        final firstLine = text.localToGlobal(Offset.zero).dy + text.getFullHeightForCaret(const TextPosition(offset: 0));
        expect(firstLine, lessThanOrEqualTo(640 - bar));
        expectWholeWords(tester);
      });
    }

    // A week previewed before it opens says so at the top of the text, which
    // scrolls with it: the notice can't squeeze the text off the screen.
    for (final (mode, name) in [('', 'guided reader'), ('?mode=full', 'full text')]) {
      testWidgets('at 300% on a 320 dp phone, a week not yet open in the $name keeps its verses beneath its notice',
          (tester) async {
        tester.view.physicalSize = const Size(320, 640);
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = 3;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        final c = await pumpApp(
          tester,
          settings: AppSettings(onboardingComplete: true, joinDate: captureJoinDate),
          now: captureNow,
        );
        // Noach, the week after Bereshit's Friday.
        c.read(routerProvider).go('/read/5787:2/0$mode');
        await tester.pump();
        await tester.pump();
        for (var i = 0; i < 30 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
          await tester.pump();
        }
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        final notice = find.byType(NoticeBanner);
        expect(notice, findsOneWidget);
        // Twice its size at most, as the rest of the chrome: bodyMedium's 14
        // at 28.
        final text = find.descendant(of: find.textContaining('Preview'), matching: find.byType(RichText));
        expect(tester.renderObject<RenderParagraph>(text).textScaler.scale(14), 28);
        final verse = find.byType(ScriptureVerse).first;
        expect(tester.getTopLeft(verse).dy, greaterThan(tester.getRect(notice).bottom));
        // Scrolled to, the verse comes into view, and the notice goes up.
        await tester.ensureVisible(verse);
        await tester.pumpAndSettle();
        expect(tester.getTopLeft(verse).dy, lessThan(640 - 48));
        expect(tester.takeException(), isNull);
        if (mode.isEmpty) expectWholeWords(tester);
      });
    }

    // In Hebrew the notice is longer: it breaks where it must, but no line
    // starts with its dash ("— הפרשה"), and a day keeps its month ("ל׳ /
    // בתשרי").
    testWidgets('at 300% on a 320 dp phone, the Hebrew preview notice keeps its dash and its date with their words',
        (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = 3;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final c = await pumpApp(
        tester,
        settings: AppSettings(onboardingComplete: true, joinDate: captureJoinDate, language: AppLanguage.hebrew),
        now: captureNow,
      );
      c.read(routerProvider).go('/read/5787:2/0');
      await tester.pump();
      await tester.pump();
      for (var i = 0; i < 30 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: find.textContaining('תצוגה מקדימה'), matching: find.byType(RichText)),
      );
      final text = paragraph.text.toPlainText();
      double top(int i) => paragraph.getBoxesForSelection(TextSelection(baseOffset: i, extentOffset: i + 1)).first.top;
      final dash = text.indexOf('—');
      expect(top(dash), top(dash - 2), reason: 'the dash on the line of the word before it');
      expect(top(text.indexOf('בתשרי')), top(text.indexOf('ל׳')), reason: 'the day on the line of its month');
      expect(top(text.length - 1), greaterThan(top(0)), reason: 'on more than one line at this size');
      expect(tester.takeException(), isNull);
    });

    // The reading size multiplies the system's, so a maqaf's words outgrow
    // the column at 100% text too. (At the largest, 500%, a long word is
    // wider than a phone's column on its own, and breaks.)
    testWidgets('no overflow or broken word at a reading size of 400%', (tester) async {
      await openReader(tester, readingScale: 4);
      expect(tester.takeException(), isNull);
      expect(find.byType(ScriptureVerse), findsWidgets);
      expectWholeWords(tester);
    });

    // On a desktop, the full text in parallel columns, of one aliyah and of
    // the whole parsha under each aliyah's heading.
    for (final whole in [false, true]) {
      for (final hebrew in [false, true]) {
        testWidgets(
            'a11y guidelines: ${whole ? 'the whole parsha' : 'full text'} in parallel columns${hebrew ? ', Hebrew' : ''}',
            (tester) async {
          final handle = tester.ensureSemantics();
          await openReader(tester, mode: '?mode=full', hebrew: hebrew, wholeParsha: whole, size: const Size(1366, 860));
          expect(tester.takeException(), isNull);
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(semanticsInvariants));
          handle.dispose();
        });
      }
    }

    for (final hebrew in [false, true]) {
      testWidgets('the whole parsha: no overflow or broken word at 200% text size${hebrew ? ', Hebrew' : ''}',
          (tester) async {
        await openReader(tester, mode: '?mode=full', hebrew: hebrew, wholeParsha: true, textScale: 2);
        expect(tester.takeException(), isNull);
        expectWholeWords(tester);
      });
    }
  });

  testWidgets('Hebrew interface is right-to-left and passes the guidelines', (tester) async {
    final handle = tester.ensureSemantics();
    await open(tester, '/today', settings: const AppSettings(onboardingComplete: true, language: AppLanguage.hebrew));
    expect(find.text('היום'), findsWidgets);
    // Today's day of the week strip says so.
    expect(find.bySemanticsLabel(RegExp(r'^יום שני, היום: ')), findsOneWidget);
    final dir = Directionality.of(tester.element(find.byType(Scaffold).first));
    expect(dir, TextDirection.rtl);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(semanticsInvariants));
    handle.dispose();
  });

  group('semantics', () {
    String location(ProviderContainer c) => c.read(routerProvider).state.uri.toString();

    testWidgets('a day of the week strip is a button that can be activated', (tester) async {
      final handle = tester.ensureSemantics();
      final c = await open(tester, '/today');
      // Today's day, "Monday, today: …", not the running head ("Monday,
      // October 12 · …").
      expect(
        tester.getSemantics(find.bySemanticsLabel(RegExp('^Monday, today: '))),
        isSemantics(isButton: true, hasTapAction: true, isFocusable: true),
      );
      // Shabbat has no reading to open.
      expect(
        tester.getSemantics(find.bySemanticsLabel(RegExp('^Saturday: '))),
        isSemantics(isButton: false, hasTapAction: false),
      );
      tester.semantics.tap(find.semantics.byLabel(RegExp('^Monday, today: ')));
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
      // The name is set in Hebrew on the title page, and named as the UI
      // names the parsha.
      final title = tester.getSemantics(find.bySemanticsLabel('Parshat Noach'));
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
      expect(find.byTooltip('More options for Revi’i'), findsOneWidget);

      // Each source is a link of its own, by its name and license, and then
      // what it is.
      await open(tester, '/sources');
      expect(
        tester.getSemantics(find.text('Targum Onkelos')),
        isSemantics(
          label: 'Targum Onkelos, Public domain\nTorat Emet edition, via Sefaria.',
          isLink: true,
          hasTapAction: true,
          isFocusable: true,
        ),
      );
      handle.dispose();
    });
  });

  testWidgets('desktop width uses a navigation rail', (tester) async {
    await open(tester, '/today', size: const Size(1366, 900));
    expect(find.byType(NavigationRail), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
  });
}

/// Checks that each paper row with a subtitle draws its title at least as
/// large as the subtitle, and gives their titles. Sizes are as drawn: the
/// style's, scaled as the text is, and set smaller where a long word needs.
Iterable<String> _expectTitlesNoSmallerThanSubtitles(WidgetTester tester) sync* {
  for (final element in find.byWidgetPredicate((w) => w is PaperRow && w.subtitle != null).evaluate()) {
    final row = element.widget as PaperRow;
    final box = element.renderObject!;
    final paragraphs = tester.renderObjectList<RenderParagraph>(
      find.descendant(of: find.byElementPredicate((e) => e == element), matching: find.byType(RichText)),
    );
    double drawn(String text) {
      final paragraph = paragraphs.firstWhere((p) => p.text.toPlainText() == text);
      final transform = paragraph.getTransformTo(box);
      return paragraph.textScaler.scale(paragraph.text.style!.fontSize!) *
          Offset(transform.entry(0, 0), transform.entry(1, 0)).distance;
    }

    // A hair's leeway for the arithmetic of the sizes, no more.
    expect(drawn(row.title), greaterThanOrEqualTo(drawn(row.subtitle!) - 0.01), reason: row.title);
    yield row.title;
  }
}

/// Checks that each fact of an aliyah's row on the week's page, its verses
/// and the time they take, stays on one line.
void _expectFactsWhole(WidgetTester tester, {required bool hebrew}) {
  final facts = find.byWidgetPredicate((w) {
    if (w is! RichText) return false;
    final text = w.text.toPlainText();
    return hebrew
        ? text.contains('פסוקים') || text.contains('דק׳')
        : text.contains('verses') || text.contains('min');
  });
  for (final paragraph in tester.renderObjectList<RenderParagraph>(facts)) {
    final text = paragraph.text.toPlainText();
    final lines = {
      for (final box in paragraph.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: text.length)))
        box.top,
    };
    expect(lines, hasLength(1), reason: text);
  }
}
