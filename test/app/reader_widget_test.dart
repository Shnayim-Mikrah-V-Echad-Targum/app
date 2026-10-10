import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/core/text/hebrew_text.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikra/features/reader/aliyah_ribbon.dart';
import 'package:shnayim_mikra/features/reader/reader_bottom_bar.dart';
import 'package:shnayim_mikra/features/reader/reader_screen.dart';
import 'package:shnayim_mikra/features/reader/scripture_text.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/services/tts.dart';
import 'package:shnayim_mikra/ui/theme/focus.dart';
import 'package:shnayim_mikra/ui/theme/motion.dart';
import 'package:shnayim_mikra/ui/widgets/lang.dart';
import 'package:shnayim_mikra/ui/widgets/ornaments.dart';

import '../helpers.dart';

void main() {
  final monday = DateTime(2026, 10, 12, 10); // week of Noach, 5787

  Future<void> loadTexts(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
    for (var i = 0; i < 20 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  // The bottom bar's forward button: Next, or Finish on the aliyah's last
  // step.
  final forward = find.byWidgetPredicate((w) => w is Text && (w.data == 'Next' || w.data == 'Finish'));

  // An aliyah's tab in the ribbon, by its name.
  Finder tab(String name) =>
      find.ancestor(of: find.descendant(of: find.byType(AliyahRibbon), matching: find.text(name)), matching: find.byType(SeferInkWell));

  testWidgets('guided verse-by-verse reading records progress', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await pumpApp(tester, settings: const AppSettings(onboardingComplete: true), now: monday);
    c.read(routerProvider).go('/read/5787:2/0');
    await loadTexts(tester);

    expect(find.text('Read the Hebrew'), findsOneWidget);
    expect(find.text('Verse 1 of 14'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Read the Hebrew again'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Read the Targum'), findsOneWidget);
    expect(find.text('3 · Targum'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.text('Verse 2 of 14'), findsOneWidget);

    final week = c.read(progressProvider).week('5787:2');
    expect(week.positions[0], [1, 1, 1]);
    expect(week.isAliyahDone(0), isFalse);

    // Mark the rest as read from the menu.
    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark this aliyah as read'));
    await tester.pumpAndSettle();
    expect(c.read(progressProvider).week('5787:2').isAliyahDone(0), isTrue);
    expect(c.read(progressProvider).week('5787:2').positions[0], [14, 14, 14], reason: 'the real verse count');
    expect(find.textContaining('Rishon is complete'), findsWidgets);
  });

  for (final method in [ReadingMethod.verseByVerse, ReadingMethod.aliyahByAliyah]) {
    testWidgets('after Mark as not read, the aliyah starts over (${method.name})', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = await pumpApp(
        tester,
        settings: AppSettings(onboardingComplete: true, notificationPromptShown: true, method: method),
        now: monday,
      );
      WeekProgress week() => c.read(progressProvider).week('5787:2');

      c.read(routerProvider).go('/read/5787:2/0');
      await loadTexts(tester);
      for (var i = 0; i < 60 && !week().isAliyahDone(0); i++) {
        await tester.tap(forward);
        await tester.pumpAndSettle();
      }
      expect(week().isAliyahDone(0), isTrue);
      expect(week().positions[0], [14, 14, 14]);

      c.read(routerProvider).go('/week/5787:2');
      await tester.pumpAndSettle();
      final rishon = find.ancestor(of: find.text('Rishon · aliyah 1'), matching: find.byType(ListTile));
      await tester.tap(find.descendant(of: rishon, matching: find.byTooltip('More options for Rishon')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark as not read'));
      await tester.pumpAndSettle();
      expect(week().units[0], [null, null, null]);
      expect(week().positions[0], [0, 0, 0]);
      // Let the confirmation snack bar clear the reader's bottom bar.
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();

      // Reopened, it resumes at the first reading, and one step credits only
      // what that step actually read.
      c.read(routerProvider).go('/read/5787:2/0');
      await loadTexts(tester);
      expect(find.text('Read the Hebrew'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      final firstChunkIsWholeAliyah = method == ReadingMethod.aliyahByAliyah;
      expect(week().isUnitDone(0, ReadingPass.mikra1), firstChunkIsWholeAliyah);
      expect(week().isUnitDone(0, ReadingPass.mikra2), isFalse);
      expect(week().isUnitDone(0, ReadingPass.targum), isFalse);
      expect(week().positions[0], [firstChunkIsWholeAliyah ? 14 : 1, 0, 0]);
    });
  }

  testWidgets('a stale saved position credits no reading that is not done', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Counts at the end of the aliyah with nothing marked done, as a sync
    // that predates Mark as not read clearing them could leave it.
    final stale = ProgressState(weeks: {'5787:2': WeekProgress(weekId: '5787:2').withPosition(0, const [14, 14, 14])});
    final c = await pumpApp(tester, settings: const AppSettings(onboardingComplete: true), now: monday, progress: stale);
    c.read(routerProvider).go('/read/5787:2/0');
    await loadTexts(tester);
    expect(find.text('Read the Hebrew'), findsOneWidget);
    expect(find.text('Verse 1 of 14'), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    final week = c.read(progressProvider).week('5787:2');
    expect(week.completedUnits, 0);
    expect(week.positions[0], [1, 0, 0]);
  });

  testWidgets('aliyah tabs show the readings done, not which is open', (tester) async {
    final handle = tester.ensureSemantics();
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final day = LocalDate(2026, 10, 12);
    final week = WeekProgress(weekId: '5787:2')
        .withAliyah(0, day)
        .withUnit(2, ReadingPass.mikra1, day)
        .withUnit(2, ReadingPass.mikra2, day);
    final c = await pumpApp(
      tester,
      settings: const AppSettings(onboardingComplete: true),
      now: monday,
      progress: ProgressState(weeks: {'5787:2': week}),
    );
    c.read(routerProvider).go('/read/5787:2/3');
    await loadTexts(tester);

    List<PipState> pips(String name) =>
        tester.widget<PassPips>(find.descendant(of: tab(name), matching: find.byType(PassPips))).states;
    const done = PipState.done, pending = PipState.pending;
    expect(pips('Rishon'), [done, done, done]);
    expect(pips('Sheni'), [pending, pending, pending]);
    expect(pips('Shlishi'), [done, done, pending], reason: 'two of its three readings are done');
    expect(pips("Revi'i"), [pending, pending, pending], reason: 'being open is not being read');
    // A check means "read" alone, and the ribbon has none.
    for (final icon in [Icons.check, Icons.check_circle, Icons.timelapse]) {
      expect(find.descendant(of: find.byType(AliyahRibbon), matching: find.byIcon(icon)), findsNothing);
    }

    expect(tester.getSemantics(find.bySemanticsLabel('Rishon, aliyah 1 of 7, read')), isSemantics(isSelected: false));
    expect(find.bySemanticsLabel('Sheni, aliyah 2 of 7, not started'), findsOneWidget);
    expect(find.bySemanticsLabel('Shlishi, aliyah 3 of 7, 2 of 3 readings done'), findsOneWidget);
    expect(
      tester.getSemantics(find.bySemanticsLabel("Revi'i, aliyah 4 of 7, not started")),
      isSemantics(isButton: true, isSelected: true, hasSelectedState: true, hasTapAction: true, isFocusable: true),
    );
    handle.dispose();
  });

  for (final hebrew in [false, true]) {
    testWidgets('the open aliyah is scrolled into view on a narrow phone${hebrew ? ', right to left' : ''}', (tester) async {
      tester.view.physicalSize = const Size(340, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = await pumpApp(
        tester,
        settings: AppSettings(onboardingComplete: true, language: hebrew ? AppLanguage.hebrew : AppLanguage.english),
        now: monday,
      );
      // Shevi'i, the last, begins beyond the edge of a narrow phone before it
      // is scrolled to: the right edge, or the left in Hebrew.
      c.read(routerProvider).go('/read/5787:2/6');
      await loadTexts(tester);
      expect(find.descendant(of: find.byType(AliyahRibbon), matching: find.byType(Scrollable)), findsOneWidget);
      final open = tester.getRect(tab(hebrew ? 'שביעי' : "Shevi'i"));
      expect(open.left, greaterThanOrEqualTo(0));
      expect(open.right, lessThanOrEqualTo(340));
    });
  }

  testWidgets('at 200% text the ribbon scrolls rather than clip its names', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final c = await pumpApp(tester, settings: const AppSettings(onboardingComplete: true), now: monday);
    c.read(routerProvider).go('/read/5787:2/4');
    await loadTexts(tester);
    expect(find.descendant(of: find.byType(AliyahRibbon), matching: find.byType(Scrollable)), findsOneWidget);
    // Each name is as wide as it needs, within its tab.
    final name = find.descendant(of: find.byType(AliyahRibbon), matching: find.text('Chamishi'));
    final paragraph = tester.renderObject<RenderParagraph>(name);
    expect(paragraph.size.width, greaterThanOrEqualTo(paragraph.getMaxIntrinsicWidth(double.infinity)));
    expect(tester.getRect(tab('Chamishi')).width, greaterThanOrEqualTo(paragraph.size.width));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a tab whose saved place is stale is not under way, as the reader starts it over', (tester) async {
    final handle = tester.ensureSemantics();
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    // Counts at or past the end of Sheni with none of its readings marked
    // done, as a sync that predates Mark as not read could leave them.
    final week = WeekProgress(weekId: '5787:2').withPosition(1, const [99, 99, 99]);
    final c = await pumpApp(
      tester,
      settings: const AppSettings(onboardingComplete: true),
      now: monday,
      progress: ProgressState(weeks: {'5787:2': week}),
    );
    c.read(routerProvider).go('/read/5787:2/0');
    await loadTexts(tester);
    expect(find.bySemanticsLabel('Sheni, aliyah 2 of 7, not started'), findsOneWidget);

    await tester.tap(tab('Sheni'));
    await tester.pumpAndSettle();
    expect(find.text('Read the Hebrew'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^Verse 1 of ')), findsOneWidget);
    handle.dispose();
  });

  testWidgets('a reading under way, with none done, is said as none done', (tester) async {
    final handle = tester.ensureSemantics();
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final week = WeekProgress(weekId: '5787:2').withPosition(1, const [3, 3, 3]);
    final c = await pumpApp(
      tester,
      settings: const AppSettings(onboardingComplete: true),
      now: monday,
      progress: ProgressState(weeks: {'5787:2': week}),
    );
    c.read(routerProvider).go('/read/5787:2/0');
    await loadTexts(tester);
    expect(find.bySemanticsLabel('Sheni, aliyah 2 of 7, 0 of 3 readings done'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('focus mode reads the full text without the ribbon', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await pumpApp(tester, settings: const AppSettings(onboardingComplete: true, focusMode: true), now: monday);
    c.read(routerProvider).go('/read/5787:2/0');
    await loadTexts(tester);
    expect(find.byType(AliyahRibbon), findsOneWidget, reason: 'guided reading keeps it');

    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Full text'));
    await tester.pumpAndSettle();
    expect(find.byType(AliyahRibbon), findsNothing);
    // The menu still switches back, and marks the aliyah read.
    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    expect(find.text('Guided reading'), findsOneWidget);
    expect(find.widgetWithText(PopupMenuItem<String>, 'Mark this aliyah as read'), findsOneWidget);
    await tester.tap(find.text('Guided reading'));
    await tester.pumpAndSettle();
    expect(find.byType(AliyahRibbon), findsOneWidget);
  });

  testWidgets('finishing an aliyah offers the next one not yet read', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final day = LocalDate(2026, 10, 12);
    var week = WeekProgress(weekId: '5787:2');
    for (final a in [0, 1, 3, 4, 5]) {
      week = week.withAliyah(a, day);
    }
    week = week.withUnit(2, ReadingPass.mikra1, day);
    final c = await pumpApp(
      tester,
      settings: const AppSettings(onboardingComplete: true, notificationPromptShown: true),
      now: monday,
      progress: ProgressState(weeks: {'5787:2': week}),
    );
    c.read(routerProvider).go('/read/5787:2/6');
    await loadTexts(tester);
    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark this aliyah as read'));
    await tester.pumpAndSettle();

    // Shevi'i is the last aliyah, but Shlishi is still under way. Monday's
    // reading (and Sunday's) is done, so Done leads and going on is quieter.
    expect(find.text("Shevi'i is complete"), findsOneWidget);
    expect(find.textContaining("That's today's reading."), findsOneWidget);
    expect(find.text('Shlishi is 22 verses.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Done'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Keep going: Shlishi'));
    await tester.pumpAndSettle();
    expect(find.text('Shlishi · שלישי'), findsOneWidget);
    expect(find.text('Read the Hebrew'), findsOneWidget);

    // Once every aliyah is read, there is nothing to continue with.
    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark this aliyah as read'));
    await tester.pumpAndSettle();
    expect(find.text('Parshat Noach is complete'), findsOneWidget);
    expect(find.textContaining('Next aliyah'), findsNothing);
    expect(find.textContaining('Keep going'), findsNothing);
  });

  testWidgets('read by section, the Targum of Numbers 32:3 is followed by its Hebrew', (tester) async {
    final handle = tester.ensureSemantics();
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await pumpApp(
      tester,
      settings: const AppSettings(onboardingComplete: true, method: ReadingMethod.sectionBySection),
      now: DateTime(2027, 7, 26, 10), // Matot-Masei 5787; Shlishi begins at 32:1
    );
    c.read(routerProvider).go('/read/5787:42-43/2');
    await loadTexts(tester);
    expect(find.text('Section 1 of 3'), findsOneWidget);
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Read the Targum'), findsOneWidget);
    expect(find.bySemanticsLabel('Read the Targum\nReading 3 of 3'), findsOneWidget,
        reason: 'no separate step for the third reading');
    expect(find.textContaining('Onkelos here gives mostly the Aramaic forms of the place names'), findsOneWidget);
    expect(find.text('Torah'), findsOneWidget, reason: 'the Hebrew is labelled among the Targum');
    handle.dispose();
  });

  testWidgets('read by aliyah, the Targum after the Hebrew of Numbers 32:3 is labelled Targum again', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await pumpApp(
      tester,
      settings: const AppSettings(onboardingComplete: true, method: ReadingMethod.aliyahByAliyah, showTranslation: true),
      now: DateTime(2027, 7, 26, 10), // Matot-Masei 5787; Shlishi is 32:1–19
    );
    c.read(routerProvider).go('/read/5787:42-43/2');
    await loadTexts(tester);
    for (var i = 0; i < 2; i++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Read the Targum'), findsOneWidget);
    // Laid out in reading order: the step's reading on the pass track, the
    // Onkelos of 32:1–3, the Hebrew of 32:3 in a block of its own, then the
    // Targum named again before the Onkelos of 32:4–19.
    final scroll = find.byType(SingleChildScrollView).last;
    final track = find.descendant(of: scroll, matching: find.text('3 · Targum'));
    expect(track, findsOneWidget);
    final targumLabel = find.descendant(of: scroll, matching: find.text('Targum Onkelos'));
    expect(targumLabel, findsOneWidget);
    final torah = find.descendant(of: scroll, matching: find.text('Torah'));
    expect(torah, findsOneWidget);
    final note = find.textContaining('Onkelos here gives mostly the Aramaic forms of the place names');
    expect(tester.getTopLeft(track).dy, lessThan(tester.getTopLeft(torah).dy));
    expect(tester.getTopLeft(torah).dy, lessThan(tester.getTopLeft(note).dy));
    expect(tester.getTopLeft(note).dy, lessThan(tester.getTopLeft(targumLabel).dy));
    // With the translation shown, as the third reading's own step shows it.
    expect(find.descendant(of: scroll, matching: find.byType(TranslationVerse)), findsOneWidget);
  });

  for (final prompts in [true, false]) {
    testWidgets('a verse Rashi is silent on ${prompts ? 'suggests' : 'does not suggest'} a third reading', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = await pumpApp(
        tester,
        settings: AppSettings(
          onboardingComplete: true,
          method: ReadingMethod.sectionBySection,
          secondReading: SecondReading.rashi,
          thirdReadingPrompts: prompts,
        ),
        now: monday,
      );
      // Rashi does not comment on Genesis 6:10, in Noach's first section.
      c.read(routerProvider).go('/read/5787:2/0');
      await loadTexts(tester);
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Read Rashi'), findsOneWidget);
      expect(find.textContaining('Some read it a third time in Hebrew'), prompts ? findsOneWidget : findsNothing);
      expect(find.text('Rashi does not comment on this verse.'), prompts ? findsNothing : findsOneWidget);
    });
  }

  testWidgets('a verse Rashi is silent on suggests no third reading when the Targum is read too', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await pumpApp(
      tester,
      settings: const AppSettings(
        onboardingComplete: true,
        method: ReadingMethod.sectionBySection,
        secondReading: SecondReading.onkelosAndRashi,
        thirdReadingPrompts: true,
      ),
      now: monday,
    );
    c.read(routerProvider).go('/read/5787:2/0');
    await loadTexts(tester);
    for (var i = 0; i < 4 && find.text('Read Rashi').evaluate().isEmpty; i++) {
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Read Rashi'), findsOneWidget);
    expect(find.text('Rashi does not comment on this verse.'), findsOneWidget);
    expect(find.textContaining('Some read it a third time in Hebrew'), findsNothing);
  });

  group('Listen reads', () {
    Future<RecordingTts> open(WidgetTester tester, String path, AppSettings settings, {DateTime? now, int steps = 0}) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final tts = RecordingTts();
      final c = await pumpApp(tester, settings: settings, now: now ?? monday, overrides: [ttsProvider.overrideWithValue(tts)]);
      c.read(routerProvider).go(path);
      await loadTexts(tester);
      for (var i = 0; i < steps; i++) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.byTooltip('Listen'));
      await tester.pumpAndSettle();
      return tts;
    }

    testWidgets('the Hebrew of Numbers 32:3 after its Onkelos, read by section', (tester) async {
      final tts = await open(
        tester,
        '/read/5787:42-43/2',
        const AppSettings(onboardingComplete: true, method: ReadingMethod.sectionBySection),
        now: DateTime(2027, 7, 26, 10),
        steps: 2,
      );
      expect(find.text('Read the Targum'), findsOneWidget);
      final (text, language) = tts.spoken.single;
      expect(language, 'he-IL');
      final plain = HebrewText.consonantsOnly(text);
      // Onkelos of 32:3, then its Hebrew, then the Onkelos of 32:4.
      final targum = plain.indexOf('מכללתא ומלבשתא');
      final hebrew = plain.indexOf('עטרות ודיבן ויעזר ונמרה');
      final next = plain.indexOf('ארעא די מחא');
      expect(targum, greaterThanOrEqualTo(0));
      expect(hebrew, greaterThan(targum));
      expect(next, greaterThan(hebrew));
    });

    testWidgets('a verse Rashi is silent on in Hebrew', (tester) async {
      // Genesis 6:10 read verse by verse, with Rashi in place of the Targum.
      final tts = await open(
        tester,
        '/read/5787:2/0',
        const AppSettings(onboardingComplete: true, secondReading: SecondReading.rashi, thirdReadingPrompts: false),
        steps: 5,
      );
      expect(find.text('Read Rashi'), findsOneWidget);
      expect(find.text('Rashi does not comment on this verse.'), findsOneWidget);
      final (text, language) = tts.spoken.single;
      expect(language, 'he-IL');
      expect(HebrewText.consonantsOnly(text), startsWith('ויולד נח שלשה בנים'));
    });

    testWidgets('the Name in the Targum as chosen', (tester) async {
      final tts = await open(
        tester,
        '/read/5787:2/0',
        const AppSettings(onboardingComplete: true, divineName: DivineNameSpeech.hashem),
        steps: 2,
      );
      expect(find.text('Read the Targum'), findsOneWidget);
      final plain = HebrewText.consonantsOnly(tts.spoken.single.$1);
      expect(plain, contains('דהשם'));
      expect(plain, isNot(contains('יי')));
    });

    testWidgets("the Name in Rashi as chosen, written ה'", (tester) async {
      // Rashi on Genesis 7:16, in Sheni, writes the Name ה'.
      final tts = await open(
        tester,
        '/read/5787:2/1',
        const AppSettings(
          onboardingComplete: true,
          method: ReadingMethod.aliyahByAliyah,
          secondReading: SecondReading.rashi,
          divineName: DivineNameSpeech.hashem,
        ),
        steps: 2,
      );
      expect(find.text('Read Rashi'), findsOneWidget);
      final plain = HebrewText.consonantsOnly(tts.spoken.single.$1);
      expect(plain, contains('ויסגור השם בעדו'));
      expect(plain, isNot(contains("ויסגור ה'")));
    });
  });

  // Text contrast stays on the test font, whose solid glyphs show the
  // guideline the exact text colour. Tap targets and labels are checked in
  // the real fonts, whose metrics they depend on, in
  // test/accessibility/screens_a11y_test.dart.
  testWidgets('reader text is readable, and each verse is spoken', (tester) async {
    final handle = tester.ensureSemantics();
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await pumpApp(tester, settings: const AppSettings(onboardingComplete: true), now: monday);
    c.read(routerProvider).go('/read/5787:2/0');
    await loadTexts(tester);
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    // Each verse has a spoken label: "Verse 9." (Noach begins at 6:9) followed by the Hebrew.
    expect(find.bySemanticsLabel(RegExp(r'^Verse 9\. ')), findsWidgets);
    handle.dispose();
  });

  group('screen-reader labels', () {
    Future<void> openNoach(WidgetTester tester, {AppSettings settings = const AppSettings(onboardingComplete: true)}) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = await pumpApp(tester, settings: settings, now: monday);
      c.read(routerProvider).go('/read/5787:2/0');
      await loadTexts(tester);
    }

    Future<void> next(WidgetTester tester, int steps) async {
      for (var i = 0; i < steps; i++) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }
    }

    SemanticsData labelled(WidgetTester tester, Pattern label) =>
        tester.getSemantics(find.bySemanticsLabel(label).first).getSemanticsData();

    testWidgets('on Android, the Hebrew of a verse is tagged within its English label', (tester) async {
      final handle = tester.ensureSemantics();
      await openNoach(tester);
      final verse = labelled(tester, RegExp(r'^Verse 9\. '));
      expect(verse.locale, isNull, reason: 'the node is not Hebrew: "Verse 9." is English');
      final span = verse.attributedLabel.attributes.whereType<LocaleStringAttribute>().single;
      expect(span.locale, const Locale('he'));
      expect(span.range.start, 'Verse 9. '.length);
      final hebrew = verse.label.substring(span.range.start, span.range.end);
      expect(HebrewText.consonantsOnly(hebrew), 'אלה תולדת נח נח איש צדיק תמים היה בדרתיו את האלהים התהלך נח.');
      handle.dispose();
    });

    testWidgets(
      'on Windows, whose screen readers take no language from the app, a verse keeps "Verse 9." in the interface language',
      (tester) async {
        final handle = tester.ensureSemantics();
        await openNoach(tester);
        final verse = labelled(tester, RegExp(r'^Verse 9\. '));
        expect(verse.locale, isNull);
        final span = verse.attributedLabel.attributes.whereType<LocaleStringAttribute>().single;
        expect((span.locale, span.range.start), (const Locale('he'), 'Verse 9. '.length));
        handle.dispose();
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );

    testWidgets('on the web, which tags whole nodes, a verse is labelled in Hebrew and its node is tagged he', (tester) async {
      debugNodeLanguageOnly = true;
      addTearDown(() => debugNodeLanguageOnly = null);
      final handle = tester.ensureSemantics();
      await openNoach(tester);
      expect(find.bySemanticsLabel(RegExp(r'^Verse 9\. ')), findsNothing);
      final verse = labelled(tester, RegExp(r'^פסוק 9\. '));
      expect(HebrewText.consonantsOnly(verse.label), startsWith('פסוק 9. אלה תולדת נח'));
      expect(verse.locale, const Locale('he'));
      handle.dispose();
    });

    testWidgets("a verse's note is read like the verse: no cantillation, and the Name as chosen", (tester) async {
      final handle = tester.ensureSemantics();
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = await pumpApp(
        tester,
        settings: const AppSettings(onboardingComplete: true, divineName: DivineNameSpeech.hashem),
        now: monday,
      );
      // Deuteronomy 32:6, in Haazinu's first aliyah, has a note: "בספרי
      // תימן הַֽלְיהֹוָה֙ בתיבה אחת".
      c.read(routerProvider).go('/read/5787:53/0?mode=full');
      await loadTexts(tester);
      final verse = labelled(tester, RegExp(r'^Verse 6\. '));
      final note = verse.label.substring(verse.label.indexOf('Note: ') + 'Note: '.length);
      expect(HebrewText.consonantsOnly(note), 'בספרי תימן הלשם בתיבה אחת');
      expect(note, isNot(contains(RegExp('[\u0591-\u05af]'))), reason: 'no cantillation');
      final span = verse.attributedLabel.attributes.whereType<LocaleStringAttribute>().last;
      expect(verse.label.substring(span.range.start, span.range.end), note);
      handle.dispose();
    });

    testWidgets('a verse of Targum is labelled as Targum and reads the Name as chosen', (tester) async {
      final handle = tester.ensureSemantics();
      await openNoach(tester, settings: const AppSettings(onboardingComplete: true, divineName: DivineNameSpeech.hashem));
      await next(tester, 2);
      expect(find.text('Read the Targum'), findsOneWidget);
      // Onkelos writes the Name יְיָ, here with a prefix: דַּיְיָ.
      final targum = labelled(tester, RegExp(r'^Targum, verse 9\. '));
      expect(HebrewText.consonantsOnly(targum.label), contains(' בדחלתא דהשם הליך '));
      handle.dispose();
    });

    testWidgets('each comment of Rashi is one node, tagged he', (tester) async {
      final handle = tester.ensureSemantics();
      await openNoach(tester, settings: const AppSettings(onboardingComplete: true, secondReading: SecondReading.rashi));
      await next(tester, 2);
      expect(find.text('Read Rashi'), findsOneWidget);
      final comment = labelled(tester, RegExp(r'^אלה תולדת נח נח איש צדיק\. הוֹאִיל '));
      expect(comment.locale, const Locale('he'));
      final span = comment.attributedLabel.attributes.whereType<LocaleStringAttribute>().single;
      expect((span.range.start, span.range.end), (0, comment.label.length));
      handle.dispose();
    });

    for (final english in [false, true]) {
      testWidgets("Rashi${english ? ' in English' : ''} reads the Name he writes ה' as chosen", (tester) async {
        final handle = tester.ensureSemantics();
        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final c = await pumpApp(
          tester,
          settings: AppSettings(
            onboardingComplete: true,
            method: ReadingMethod.aliyahByAliyah,
            secondReading: english ? SecondReading.rashiEnglish : SecondReading.rashi,
            divineName: DivineNameSpeech.hashem,
          ),
          now: monday,
        );
        // Rashi on Genesis 7:16, in Sheni: "ויסגור ה' בעדו".
        c.read(routerProvider).go('/read/5787:2/1');
        await loadTexts(tester);
        await next(tester, 2);
        expect(find.text('Read Rashi'), findsOneWidget);
        final comment = labelled(tester, RegExp('^ויסגור '));
        expect(HebrewText.consonantsOnly(comment.label), startsWith('ויסגור השם בעדו'));
        if (english) {
          final span = comment.attributedLabel.attributes.whereType<LocaleStringAttribute>().first;
          expect(HebrewText.consonantsOnly(comment.label.substring(span.range.start, span.range.end)), 'ויסגור השם בעדו');
        }
        handle.dispose();
      });
    }

    testWidgets('Rashi in English is tagged en, and the Hebrew it quotes he', (tester) async {
      final handle = tester.ensureSemantics();
      await openNoach(tester, settings: const AppSettings(onboardingComplete: true, secondReading: SecondReading.rashiEnglish));
      await next(tester, 2);
      final comment = labelled(tester, RegExp(r'^אלה תולדת נח נח איש צדיק THESE ARE THE PROGENY OF NOAH'));
      expect(comment.locale, const Locale('en'));
      final span = comment.attributedLabel.attributes.whereType<LocaleStringAttribute>().first;
      expect(span.locale, const Locale('he'));
      expect(comment.label.substring(span.range.start, span.range.end), 'אלה תולדת נח נח איש צדיק');
      handle.dispose();
    });

    testWidgets('the English translation is tagged en in the Hebrew interface', (tester) async {
      final handle = tester.ensureSemantics();
      await openNoach(
        tester,
        settings: const AppSettings(onboardingComplete: true, language: AppLanguage.hebrew, showTranslation: true),
      );
      expect(labelled(tester, RegExp(r'^9 These are the generations of Noah')).locale, const Locale('en'));
      handle.dispose();
    });
  });

  group('a step is spoken once', () {
    for (final announces in [true, false]) {
      testWidgets(announces ? 'in an announcement, where the platform takes them' : 'by its live region, elsewhere', (tester) async {
        final handle = tester.ensureSemantics();
        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        tester.platformDispatcher.accessibilityFeaturesTestValue = FakeAccessibilityFeatures(supportsAnnounce: announces);
        addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
        final c = await pumpApp(tester, settings: const AppSettings(onboardingComplete: true), now: monday);
        c.read(routerProvider).go('/read/5787:2/0');
        await loadTexts(tester);
        tester.takeAnnouncements();

        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
        expect(find.text('Read the Hebrew again'), findsOneWidget);
        expect(
          tester.getSemantics(find.text('Read the Hebrew again')),
          isSemantics(label: 'Read the Hebrew again\nReading 2 of 3', isLiveRegion: !announces),
        );
        expect(tester.takeAnnouncements(), [
          if (announces) isAccessibilityAnnouncement('Read the Hebrew again. Reading 2 of 3. Verse 1 of 14. Genesis 6:9'),
        ]);

        // So is the step another aliyah opens on, chosen from its tab.
        await tester.tap(tab('Sheni'));
        await tester.pumpAndSettle();
        expect(find.text('Sheni · שני'), findsOneWidget);
        expect([for (final a in tester.takeAnnouncements()) a.message], [
          if (announces) matches(RegExp(r'^Read the Hebrew\. Reading 1 of 3\. Verse 1 of \d+\. Genesis \d+:\d+$')),
        ]);
        handle.dispose();
      });
    }
  });

  testWidgets('the display sheet names its slider by its setting', (tester) async {
    final handle = tester.ensureSemantics();
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await pumpApp(tester, settings: const AppSettings(onboardingComplete: true), now: monday);
    c.read(routerProvider).go('/read/5787:2/0');
    await loadTexts(tester);
    await tester.tap(find.byTooltip('Display settings'));
    await tester.pumpAndSettle();
    final slider = find.descendant(of: find.byType(BottomSheet), matching: find.byType(Slider));
    await tester.scrollUntilVisible(slider, 200, scrollable: find.descendant(of: find.byType(BottomSheet), matching: find.byType(Scrollable)));
    expect(tester.getSemantics(slider), isSemantics(label: 'Line spacing', value: '1.9', isSlider: true));
    // Wholly in view, its buttons too.
    await tester.ensureVisible(find.byTooltip('Increase Line spacing'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Increase Line spacing'));
    await tester.pumpAndSettle();
    expect(c.read(settingsProvider).lineHeight, closeTo(2.0, 1e-9));
    handle.dispose();
  });

  testWidgets('full-text mode shows Torah and Targum together', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await pumpApp(tester, settings: const AppSettings(onboardingComplete: true), now: monday);
    c.read(routerProvider).go('/read/5787:2/0?mode=full');
    await loadTexts(tester);
    // The aliyah opens mid-chapter, headed by its chapter.
    expect(find.text('פרק ו'), findsOneWidget);
    expect(find.text('Chapter 6'), findsOneWidget);
    // Each verse's Targum is ruled off beneath it, without its number.
    final targum = tester.widgetList<ScriptureVerse>(find.byType(ScriptureVerse)).where((v) => v.kind == ScriptureKind.targum);
    expect(targum, isNotEmpty);
    expect(targum.every((v) => v.ruled && !v.showNumber), isTrue);
    // Built with the text, so that Tab reaches it, but at its end.
    final button = find.text('Mark this aliyah as read');
    expect(tester.getTopLeft(button).dy, greaterThan(900), reason: 'the button is at the end of the text');
    // After a divider, a tonal button (§6.5), centred.
    final scheme = Theme.of(tester.element(button)).colorScheme;
    final tonal = find.ancestor(of: button, matching: find.byWidgetPredicate((w) => w is ButtonStyleButton));
    expect(tester.widget<ButtonStyleButton>(tonal).style?.backgroundColor?.resolve({}), scheme.primaryContainer);
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    expect(tester.getBottomLeft(find.byType(SeferDivider)).dy, lessThan(tester.getTopLeft(button).dy));
    expect(tester.getCenter(tonal).dx, closeTo(tester.getCenter(find.byType(SeferDivider)).dx, 1));
  });

  testWidgets('in focus mode, tapping verses moves no line of the text', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await pumpApp(
      tester,
      // Small enough that the first verses are on the screen together.
      settings: const AppSettings(onboardingComplete: true, focusMode: true, showTranslation: true, readingScale: 0.6),
      now: monday,
    );
    c.read(routerProvider).go('/read/5787:2/0?mode=full');
    await loadTexts(tester);
    // Every paragraph of the text, where it is and how it breaks.
    List<(Rect, double)> layout() => [
          for (final p in tester.renderObjectList<RenderParagraph>(
            find.descendant(of: find.byType(VerseGroup), matching: find.byType(RichText)),
          ))
            (p.localToGlobal(Offset.zero) & p.size, p.getMaxIntrinsicWidth(double.infinity)),
        ];
    final before = layout();
    final verses = find.byType(VerseGroup);
    bool highlighted(int i) => tester.widget<VerseGroup>(verses.at(i)).highlighted;
    // Focus mode opens on the first verse; a tap moves it, and a tap on the
    // verse it is on lets it go.
    int? focused = 0;
    expect(highlighted(0), isTrue);
    for (final i in [1, 0, 0]) {
      expect(tester.getRect(verses.at(i)).top + 24, lessThan(915), reason: 'on the screen');
      await tester.tapAt(tester.getRect(verses.at(i)).topCenter + const Offset(0, 24));
      focused = focused == i ? null : i;
      await tester.pump();
      expect([highlighted(0), highlighted(1)], [focused == 0, focused == 1]);
      await tester.pump(Motion.short ~/ 2);
      expect(layout(), before, reason: 'as the highlight fades');
      await tester.pumpAndSettle();
      expect(layout(), before);
    }
  });

  testWidgets('line spacing goes no lower than 1.6', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await pumpApp(tester, settings: const AppSettings(onboardingComplete: true, lineHeight: 1.6), now: monday);
    c.read(routerProvider).go('/read/5787:2/0');
    await loadTexts(tester);
    await tester.tap(find.byTooltip('Display settings'));
    await tester.pumpAndSettle();
    final slider = find.descendant(of: find.byType(BottomSheet), matching: find.byType(Slider));
    await tester.scrollUntilVisible(slider, 200, scrollable: find.descendant(of: find.byType(BottomSheet), matching: find.byType(Scrollable)));
    final decrease = find.byTooltip('Decrease Line spacing');
    await tester.ensureVisible(decrease);
    await tester.pumpAndSettle();
    final spacing = tester.widget<Slider>(slider);
    expect((spacing.min, spacing.max, spacing.divisions), (1.6, 3.0, 14));
    expect(tester.widget<IconButton>(find.ancestor(of: decrease, matching: find.byType(IconButton))).onPressed, isNull);
    expect(c.read(settingsProvider).lineHeight, 1.6);
  });

  testWidgets('the display sheet turns the Rashi script on', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await pumpApp(tester, settings: const AppSettings(onboardingComplete: true), now: monday);
    c.read(routerProvider).go('/read/5787:2/0');
    await loadTexts(tester);
    await tester.tap(find.byTooltip('Display settings'));
    await tester.pumpAndSettle();
    final toggle = find.widgetWithText(SwitchListTile, 'Rashi script');
    await tester.scrollUntilVisible(toggle, 200, scrollable: find.descendant(of: find.byType(BottomSheet), matching: find.byType(Scrollable)));
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(c.read(settingsProvider).rashiScript, isTrue);
  });

  testWidgets('the guided reader heads a chapter where one starts', (tester) async {
    final handle = tester.ensureSemantics();
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await pumpApp(tester, settings: const AppSettings(onboardingComplete: true), now: monday);
    // Noach's Sheni opens on Genesis 7:1.
    c.read(routerProvider).go('/read/5787:2/1');
    await loadTexts(tester);
    expect(find.text('פרק ז'), findsOneWidget);
    expect(tester.getSemantics(find.byType(ChapterHeading)), isSemantics(label: 'Chapter 7', isHeader: true));
    // Under the instruction, over the verse, whose number hangs at its start.
    final heading = tester.getRect(find.byType(ChapterHeading));
    expect(heading.top, greaterThan(tester.getRect(find.text('Read the Hebrew')).bottom));
    final verse = tester.getRect(find.byType(ScriptureVerse));
    expect(heading.bottom, lessThanOrEqualTo(verse.top));
    expect(find.descendant(of: find.byType(ScriptureVerse), matching: find.text('א')), findsOneWidget);
    handle.dispose();
  });

  group('the keyboard', () {
    Future<ProviderContainer> open(WidgetTester tester, String path, {AppSettings? settings, ProgressState? progress}) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = await pumpApp(
        tester,
        settings: settings ?? const AppSettings(onboardingComplete: true, notificationPromptShown: true),
        now: monday,
        progress: progress,
      );
      c.read(routerProvider).go(path);
      await loadTexts(tester);
      return c;
    }

    // The text's own scrollable: the aliyah chips scroll across.
    ScrollPosition text(WidgetTester tester) => tester
        .stateList<ScrollableState>(find.byType(Scrollable))
        .firstWhere((s) => s.position.axis == Axis.vertical)
        .position;

    Future<void> press(WidgetTester tester, LogicalKeyboardKey key, {List<LogicalKeyboardKey> holding = const []}) async {
      for (final k in holding) {
        await tester.sendKeyDownEvent(k);
      }
      await tester.sendKeyEvent(key);
      for (final k in holding.reversed) {
        await tester.sendKeyUpEvent(k);
      }
      await tester.pumpAndSettle();
    }

    bool focused(WidgetTester tester, String label) => Focus.of(tester.element(find.text(label))).hasPrimaryFocus;

    testWidgets('scrolls the full text by the page, and Tab reaches Mark as read', (tester) async {
      await open(tester, '/read/5787:2/0?mode=full');
      expect(text(tester).pixels, 0);
      await press(tester, LogicalKeyboardKey.pageDown);
      expect(text(tester).pixels, closeTo(0.8 * text(tester).viewportDimension, 1));
      await press(tester, LogicalKeyboardKey.pageUp);
      expect(text(tester).pixels, 0);

      for (var i = 0; i < 30 && !focused(tester, 'Mark this aliyah as read'); i++) {
        await press(tester, LogicalKeyboardKey.tab);
      }
      expect(focused(tester, 'Mark this aliyah as read'), isTrue);
    });

    testWidgets('pages through a long step, and at its end goes on to the next', (tester) async {
      await open(
        tester,
        '/read/5787:2/0',
        settings: const AppSettings(onboardingComplete: true, method: ReadingMethod.sectionBySection, readingScale: 3),
      );
      expect(find.text('Read the Hebrew'), findsOneWidget);
      await press(tester, LogicalKeyboardKey.pageDown);
      expect(text(tester).pixels, greaterThan(0));
      expect(find.text('Read the Hebrew'), findsOneWidget, reason: 'the first press scrolls');
      for (var i = 0; i < 40 && text(tester).extentAfter > 1; i++) {
        await press(tester, LogicalKeyboardKey.pageDown);
      }
      expect(text(tester).extentAfter, lessThanOrEqualTo(1));
      expect(find.text('Read the Hebrew'), findsOneWidget, reason: 'the step is scrolled to its end before it is left');

      await press(tester, LogicalKeyboardKey.pageDown);
      expect(find.text('Read the Hebrew again'), findsOneWidget);
      expect(text(tester).pixels, 0, reason: 'the next step opens at its top');
      await press(tester, LogicalKeyboardKey.pageUp);
      expect(find.text('Read the Hebrew'), findsOneWidget, reason: 'at the top, Page Up goes back');
      // Alt+↓ steps on wherever the text is scrolled.
      await press(tester, LogicalKeyboardKey.arrowDown, holding: [LogicalKeyboardKey.altLeft]);
      expect(find.text('Read the Hebrew again'), findsOneWidget);
    });

    testWidgets('Space presses a focused Next, and Back gives the focus to Next when it is disabled', (tester) async {
      await open(tester, '/read/5787:2/0');
      Focus.of(tester.element(find.text('Next'))).requestFocus();
      await tester.pump();
      await press(tester, LogicalKeyboardKey.space);
      expect(find.text('Read the Hebrew again'), findsOneWidget);

      Focus.of(tester.element(find.text('Back'))).requestFocus();
      await tester.pump();
      await press(tester, LogicalKeyboardKey.space);
      expect(find.text('Read the Hebrew'), findsOneWidget);
      expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'Back')).onPressed, isNull);
      expect(focused(tester, 'Next'), isTrue);
    });

    for (final announces in [true, false]) {
      testWidgets('the finished panel takes the focus, and says so ${announces ? 'in an announcement' : 'by its live region'}',
          (tester) async {
        final handle = tester.ensureSemantics();
        tester.platformDispatcher.accessibilityFeaturesTestValue = FakeAccessibilityFeatures(supportsAnnounce: announces);
        addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
        await open(
          tester,
          '/read/5787:2/0',
          settings: const AppSettings(
            onboardingComplete: true,
            notificationPromptShown: true,
            method: ReadingMethod.aliyahByAliyah,
          ),
        );
        tester.takeAnnouncements();
        for (final label in ['Next', 'Next', 'Finish']) {
          await tester.tap(find.text(label));
          await tester.pumpAndSettle();
        }
        // The title is quiet; what is said is warmer, by the announcement or
        // by the title's live region.
        const heading = 'Rishon is complete';
        const spoken = 'Yasher koach! Rishon is complete.';
        expect(find.text(heading), findsOneWidget);
        expect(focused(tester, 'Next aliyah · Sheni'), isTrue);
        expect(
          tester.getSemantics(find.text(heading)),
          isSemantics(label: announces ? heading : spoken, isHeader: true, isLiveRegion: !announces),
        );
        expect(tester.takeAnnouncements().map((a) => a.message), announces ? contains(spoken) : isEmpty);

        // Continued from the keyboard, the next aliyah opens with the focus
        // on Next.
        await press(tester, LogicalKeyboardKey.enter);
        expect(find.text('Sheni · שני'), findsOneWidget);
        expect(focused(tester, 'Next'), isTrue);
        handle.dispose();
      });
    }

    testWidgets('the first aliyah ever finished offers reminders, which keep the focus until they are answered', (tester) async {
      await open(
        tester,
        '/read/5787:2/0',
        settings: const AppSettings(onboardingComplete: true, method: ReadingMethod.aliyahByAliyah),
      );
      Focus.of(tester.element(find.text('Next'))).requestFocus();
      await tester.pump();
      for (var i = 0; i < 3; i++) {
        await press(tester, LogicalKeyboardKey.enter);
      }
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(Focus.of(tester.element(find.text('Next aliyah · Sheni'))).hasFocus, isFalse,
          reason: 'nothing behind the dialog has the focus');
      // Enter answers the dialog, rather than continuing behind it.
      final answer = find.descendant(of: find.byType(AlertDialog), matching: find.bySubtype<ButtonStyleButton>()).first;
      Focus.of(tester.element(find.descendant(of: answer, matching: find.byType(Text)))).requestFocus();
      await tester.pump();
      await press(tester, LogicalKeyboardKey.enter);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.text('Rishon · ראשון'), findsOneWidget);
      expect(focused(tester, 'Next aliyah · Sheni'), isTrue, reason: "the panel's first button takes the focus back");
    });

    testWidgets("marking the aliyah read from the menu gives the panel's first button the focus", (tester) async {
      await open(tester, '/read/5787:2/0');
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Mark this aliyah as read'));
      await tester.pumpAndSettle();
      expect(focused(tester, 'Next aliyah · Sheni'), isTrue);
    });

    for (final (name, key, holding) in [
      ('Page Up', LogicalKeyboardKey.pageUp, <LogicalKeyboardKey>[]),
      ('Alt+↑', LogicalKeyboardKey.arrowUp, [LogicalKeyboardKey.altLeft]),
    ]) {
      testWidgets('leaving the finished panel with $name gives Next the focus', (tester) async {
        await open(
          tester,
          '/read/5787:2/0',
          settings: const AppSettings(onboardingComplete: true, notificationPromptShown: true, method: ReadingMethod.aliyahByAliyah),
        );
        for (var i = 0; i < 3; i++) {
          await tester.tap(forward);
          await tester.pumpAndSettle();
        }
        expect(focused(tester, 'Next aliyah · Sheni'), isTrue);
        await press(tester, key, holding: holding);
        expect(find.text('Read the Targum'), findsOneWidget);
        // The aliyah's last step, whose Next says Finish.
        expect(focused(tester, 'Finish'), isTrue);
      });
    }

    testWidgets('marking the aliyah read at the end of the full text keeps the focus in the reader', (tester) async {
      await open(tester, '/read/5787:2/0?mode=full');
      for (var i = 0; i < 30 && !focused(tester, 'Mark this aliyah as read'); i++) {
        await press(tester, LogicalKeyboardKey.tab);
      }
      await press(tester, LogicalKeyboardKey.enter);
      expect(find.text('Mark this aliyah as read'), findsNothing);
      final reader = Focus.of(tester.element(find.byType(Scaffold).last));
      expect(reader.hasPrimaryFocus, isTrue, reason: "the reader's own focus, not a control out of view");
      // Its keys still work.
      await press(tester, LogicalKeyboardKey.pageDown);
      expect(text(tester).pixels, greaterThan(0));
    });

    testWidgets("in focus mode, the full text opens on the verse the guided reader resumes at, read by aliyah", (tester) async {
      // The first reading of Rishon is done: the guided reader resumes at
      // its second reading, from Genesis 6:9.
      final day = LocalDate(2026, 10, 12);
      final progress = ProgressState(weeks: {
        '5787:2': WeekProgress(weekId: '5787:2').withUnit(0, ReadingPass.mikra1, day).withPosition(0, const [14, 0, 0]),
      });
      await open(
        tester,
        '/read/5787:2/0?mode=full',
        settings: const AppSettings(onboardingComplete: true, focusMode: true, method: ReadingMethod.aliyahByAliyah),
        progress: progress,
      );
      final current = find.byWidgetPredicate((w) => w is VerseGroup && w.highlighted);
      expect(tester.widget<VerseGroup>(current).verse.verse, 9);
    });

    testWidgets('in focus mode, ↓ and ↑ move the verse read and keep it in view', (tester) async {
      // The first reading has reached Genesis 6:15, the seventh verse.
      final progress = ProgressState(weeks: {'5787:2': WeekProgress(weekId: '5787:2').withPosition(0, const [6, 6, 6])});
      await open(
        tester,
        '/read/5787:2/0?mode=full',
        settings: const AppSettings(onboardingComplete: true, focusMode: true),
        progress: progress,
      );
      Finder current() => find.byWidgetPredicate((w) => w is VerseGroup && w.highlighted);
      int verse() => tester.widget<VerseGroup>(current()).verse.verse;
      void expectInView() {
        final rect = tester.getRect(current());
        expect(rect.top, greaterThanOrEqualTo(tester.getRect(find.byType(SingleChildScrollView).last).top));
        expect(rect.bottom, lessThanOrEqualTo(915));
      }

      expect(verse(), 15, reason: "focus mode opens on the reader's place");
      expect(text(tester).pixels, greaterThan(0));
      expectInView();
      for (var i = 0; i < 5; i++) {
        await press(tester, LogicalKeyboardKey.arrowDown);
      }
      expect(verse(), 20);
      expectInView();
      await press(tester, LogicalKeyboardKey.arrowUp);
      expect(verse(), 19);
      expectInView();
    });

    testWidgets('on the web, single keys change the display, unless turned off', (tester) async {
      ReaderScreen.singleKeyPlatform = true;
      addTearDown(() => ReaderScreen.singleKeyPlatform = false);
      final c = await open(tester, '/read/5787:2/0');
      AppSettings s() => c.read(settingsProvider);

      await press(tester, LogicalKeyboardKey.keyT);
      expect(s().showTeamim, isFalse);
      await press(tester, LogicalKeyboardKey.keyN);
      expect(s().showNikud, isFalse);
      await press(tester, LogicalKeyboardKey.equal);
      expect(s().readingScale, closeTo(1.1, 1e-9));
      await press(tester, LogicalKeyboardKey.minus);
      expect(s().readingScale, closeTo(1.0, 1e-9));
      // The numpad's + comes with the character "+", and counts once.
      await tester.sendKeyEvent(LogicalKeyboardKey.numpadAdd, character: '+');
      await tester.pumpAndSettle();
      expect(s().readingScale, closeTo(1.1, 1e-9));
      // So does "+" typed with Shift, as the browser reports it.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.add, physicalKey: PhysicalKeyboardKey.equal, character: '+');
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(s().readingScale, closeTo(1.2, 1e-9));
      await press(tester, LogicalKeyboardKey.numpadSubtract);
      await press(tester, LogicalKeyboardKey.minus);
      expect(s().readingScale, closeTo(1.0, 1e-9));
      // Ctrl+Shift+T stays the browser's.
      await press(tester, LogicalKeyboardKey.keyT, holding: [LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.shiftLeft]);
      expect(s().showTeamim, isFalse);

      // ? lists the keys as the web binds them.
      final handle = tester.ensureSemantics();
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.slash, character: '?');
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pumpAndSettle();
      expect(find.text('Keyboard shortcuts'), findsOneWidget);
      expect(find.bySemanticsLabel('Scroll the text\nUp arrow, Down arrow, Space'), findsOneWidget);
      expect(find.bySemanticsLabel('Show or hide cantillation\nT'), findsOneWidget);
      expect(find.bySemanticsLabel('Show shortcuts\n?, F1, Ctrl + /'), findsOneWidget);
      handle.dispose();
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      // Settings → Accessibility turns them off.
      c.read(routerProvider).go('/settings/accessibility');
      await tester.pumpAndSettle();
      final toggle = find.widgetWithText(SwitchListTile, 'Single-key shortcuts');
      await tester.scrollUntilVisible(toggle, 200);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(s().singleKeyShortcuts, isFalse);
      c.read(routerProvider).go('/read/5787:2/0');
      await loadTexts(tester);
      await press(tester, LogicalKeyboardKey.keyT);
      expect(s().showTeamim, isFalse);
    });

    testWidgets('elsewhere, display shortcuts take Ctrl, and single keys are left alone', (tester) async {
      final c = await open(tester, '/read/5787:2/0');
      AppSettings s() => c.read(settingsProvider);
      await press(tester, LogicalKeyboardKey.keyT);
      expect(s().showTeamim, isTrue);
      await press(tester, LogicalKeyboardKey.keyT, holding: [LogicalKeyboardKey.controlLeft, LogicalKeyboardKey.shiftLeft]);
      expect(s().showTeamim, isFalse);
      await press(tester, LogicalKeyboardKey.equal, holding: [LogicalKeyboardKey.controlLeft]);
      expect(s().readingScale, closeTo(1.1, 1e-9));

      final handle = tester.ensureSemantics();
      await press(tester, LogicalKeyboardKey.f1);
      expect(find.text('Keyboard shortcuts'), findsOneWidget);
      expect(find.bySemanticsLabel('Scroll the text\nCtrl + Up arrow, Ctrl + Down arrow'), findsOneWidget);
      expect(find.bySemanticsLabel('Down a page, then the next step\nPage Down'), findsOneWidget);
      expect(find.bySemanticsLabel('Show or hide cantillation\nCtrl + Shift + T'), findsOneWidget);
      expect(find.bySemanticsLabel('Show shortcuts\nF1, Ctrl + /'), findsOneWidget);
      expect(find.textContaining('focus mode'), findsNothing, reason: '↑ and ↓ move between verses only in focus mode');
      handle.dispose();
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      c.read(settingsProvider.notifier).update((s) => s.copyWith(focusMode: true));
      await tester.pumpAndSettle();
      await press(tester, LogicalKeyboardKey.f1);
      expect(find.text('Full text in focus mode: previous or next verse'), findsOneWidget);
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      c.read(routerProvider).go('/settings/accessibility');
      await tester.pumpAndSettle();
      expect(find.text('Single-key shortcuts'), findsNothing, reason: 'there are none to turn off');
    });
  });

  group('the chrome around the text', () {
    Future<ProviderContainer> open(
      WidgetTester tester,
      String path, {
      Size size = const Size(412, 915),
      AppSettings settings = const AppSettings(onboardingComplete: true, notificationPromptShown: true),
      List<Override> overrides = const [],
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = await pumpApp(tester, settings: settings, now: monday, overrides: overrides);
      c.read(routerProvider).go(path);
      await loadTexts(tester);
      return c;
    }

    /// The icons in the row of the pass track's [label].
    Finder trackIcon(String label, IconData icon) => find.descendant(
          of: find.ancestor(of: find.text(label), matching: find.byType(Row)).first,
          matching: find.byIcon(icon),
        );

    FontWeight? weight(WidgetTester tester, String label) => tester.widget<Text>(find.text(label)).style?.fontWeight;

    testWidgets('the pass track checks the readings done and sets the one under way in bold', (tester) async {
      await open(tester, '/read/5787:2/0');
      expect(find.text('1 · Mikra'), findsOneWidget);
      expect(find.text('2 · Mikra'), findsOneWidget);
      expect(find.text('3 · Targum'), findsOneWidget);
      expect(weight(tester, '1 · Mikra'), FontWeight.w700);
      expect(trackIcon('1 · Mikra', Icons.check), findsNothing);

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(trackIcon('1 · Mikra', Icons.check), findsOneWidget);
      expect(weight(tester, '1 · Mikra'), isNot(FontWeight.w700));
      expect(weight(tester, '2 · Mikra'), FontWeight.w700);
      expect(trackIcon('3 · Targum', Icons.check), findsNothing);
      // Nothing but the instruction comes between the track and the verse.
      expect(find.text('Chapter 6'), findsNothing);
    });

    testWidgets('the pass track names the third reading as it is read: Rashi, or the Hebrew again', (tester) async {
      // Genesis 6:9, with Rashi read in place of the Targum.
      await open(
        tester,
        '/read/5787:2/0',
        settings: const AppSettings(onboardingComplete: true, secondReading: SecondReading.rashi),
      );
      expect(find.text('3 · Rashi'), findsOneWidget);
      // Noach's Revi'i opens on 8:15, on which Rashi is silent: it is read a
      // third time in Hebrew instead.
      await tester.tap(tab("Revi'i"));
      await tester.pumpAndSettle();
      expect(find.text('3 · Mikra'), findsOneWidget);
      expect(find.text('3 · Rashi'), findsNothing);
    });

    testWidgets('Next points on, and says Finish with a check on the last step of the aliyah', (tester) async {
      await open(
        tester,
        '/read/5787:2/0',
        settings: const AppSettings(
          onboardingComplete: true,
          notificationPromptShown: true,
          method: ReadingMethod.aliyahByAliyah,
        ),
      );
      final button = find.byType(FilledButton);
      expect(find.descendant(of: button, matching: find.byIcon(Icons.chevron_right)), findsOneWidget);
      expect(find.descendant(of: button, matching: find.byIcon(Icons.check)), findsNothing);
      expect(tester.getSize(button).height, greaterThanOrEqualTo(52));
      expect(tester.getSize(button).width, greaterThanOrEqualTo(128));
      for (var i = 0; i < 2; i++) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Next'), findsNothing);
      expect(find.descendant(of: button, matching: find.text('Finish')), findsOneWidget);
      expect(find.descendant(of: button, matching: find.byIcon(Icons.check)), findsOneWidget);
      expect(find.descendant(of: button, matching: find.byIcon(Icons.chevron_right)), findsNothing);
    });

    for (final reduced in [false, true]) {
      testWidgets(reduced ? 'with Reduce Motion, the next step is simply there' : 'a step fades into the next, in place',
          (tester) async {
        await open(
          tester,
          '/read/5787:2/0',
          settings: AppSettings(onboardingComplete: true, notificationPromptShown: true, reduceMotion: reduced),
        );
        await tester.tap(find.text('Next'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 90));
        if (reduced) {
          expect(find.text('Read the Hebrew'), findsNothing);
        } else {
          // Halfway, both are on the page, the one fading out and the other
          // in, one over the other: opacity alone, nothing slides.
          double opacity(String step) =>
              tester.widget<FadeTransition>(find.ancestor(of: find.text(step), matching: find.byType(FadeTransition)).first).opacity.value;
          expect(opacity('Read the Hebrew'), inExclusiveRange(0, 1));
          expect(opacity('Read the Hebrew again'), inExclusiveRange(0, 1));
          expect(tester.getTopLeft(find.text('Read the Hebrew')), tester.getTopLeft(find.text('Read the Hebrew again')));
          final switcher = find.ancestor(of: find.text('Read the Hebrew again'), matching: find.byType(AnimatedSwitcher));
          expect(find.descendant(of: switcher.first, matching: find.byType(SlideTransition)), findsNothing);
          await tester.pumpAndSettle();
          expect(find.text('Read the Hebrew'), findsNothing);
        }
        expect(find.text('Read the Hebrew again'), findsOneWidget);
      });
    }

    for (final hebrew in [false, true]) {
      testWidgets('the app bar sets the parsha over the aliyah${hebrew ? ', in Hebrew alone' : ''}', (tester) async {
        final handle = tester.ensureSemantics();
        await open(
          tester,
          '/read/5787:2/3',
          settings: AppSettings(onboardingComplete: true, language: hebrew ? AppLanguage.hebrew : AppLanguage.english),
        );
        final bar = find.byType(AppBar);
        final parsha = find.descendant(of: bar, matching: find.text(hebrew ? 'נח' : 'Noach'));
        final aliyah = find.descendant(of: bar, matching: find.text(hebrew ? 'רביעי' : "Revi'i · רביעי"));
        expect(find.descendant(of: bar, matching: find.byType(Eyebrow)), findsOneWidget);
        expect(tester.getBottomLeft(parsha).dy, lessThanOrEqualTo(tester.getTopLeft(aliyah).dy));
        expect(tester.getSize(bar).height, 64);
        // Heard as the page names itself.
        expect(
          tester.getSemantics(aliyah),
          isSemantics(label: hebrew ? 'נח · רביעי' : "Noach · Revi'i", isHeader: true),
        );
        handle.dispose();
      });
    }

    testWidgets('the first verse begins in the top quarter of a phone', (tester) async {
      await open(tester, '/read/5787:2/0');
      // Three layers of chrome once filled 29% of the screen above it.
      expect(tester.getTopLeft(find.byType(ScriptureVerse).first).dy, lessThan(0.25 * 915));
    });

    testWidgets('on a wide screen, the title, the ribbon, Back and Next keep to the reading column', (tester) async {
      await open(tester, '/read/5787:2/0', size: const Size(1366, 860));
      final column = tester.getRect(find.byType(ScriptureVerse).first);
      expect(column.width, lessThan(1000));
      expect(tester.getTopLeft(find.text('Rishon · ראשון')).dx, moreOrLessEquals(column.left, epsilon: 1));
      expect(tester.getRect(tab('Rishon')).left, moreOrLessEquals(column.left, epsilon: 1));
      expect(tester.getRect(tab("Shevi'i")).right, moreOrLessEquals(column.right, epsilon: 1));
      final back = tester.getRect(find.widgetWithText(TextButton, 'Back'));
      final next = tester.getRect(find.widgetWithText(FilledButton, 'Next'));
      expect(back.left, moreOrLessEquals(column.left, epsilon: 1));
      expect(next.right, moreOrLessEquals(column.right, epsilon: 1));
    });

    testWidgets('on a narrow phone, where the reader is goes above Back and Next, which share the width', (tester) async {
      await open(tester, '/read/5787:2/0', size: const Size(360, 780));
      final where = tester.getRect(find.text('Verse 1 of 14'));
      final back = tester.getRect(find.widgetWithText(TextButton, 'Back'));
      final next = tester.getRect(find.widgetWithText(FilledButton, 'Next'));
      expect(where.bottom, lessThanOrEqualTo(back.top));
      expect(back.top, moreOrLessEquals(next.top, epsilon: 4));
      expect(back.width, moreOrLessEquals(next.width, epsilon: 1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('the bottom bar runs under the gesture bar, with its buttons above it', (tester) async {
      tester.view.padding = const FakeViewPadding(bottom: 34);
      addTearDown(tester.view.resetPadding);
      await open(tester, '/read/5787:2/0');
      // Painted to the screen's edge: no strip of another colour beneath.
      expect(tester.getRect(find.byType(ReaderBottomBar)).bottom, 915);
      expect(tester.getRect(find.widgetWithText(FilledButton, 'Next')).bottom, lessThanOrEqualTo(915 - 34));
    });

    testWidgets('the full text ends clear of the gesture bar', (tester) async {
      tester.view.padding = const FakeViewPadding(bottom: 34);
      addTearDown(tester.view.resetPadding);
      await open(tester, '/read/5787:2/0?mode=full');
      final scrollable = tester.stateList<ScrollableState>(find.byType(Scrollable)).last;
      scrollable.position.jumpTo(scrollable.position.maxScrollExtent);
      await tester.pumpAndSettle();
      expect(tester.getRect(find.text('Mark this aliyah as read')).bottom, lessThanOrEqualTo(915 - 34));
    });

    testWidgets('status messages rise above the bottom bar', (tester) async {
      await open(tester, '/read/5787:2/0', overrides: [ttsProvider.overrideWithValue(_NoHebrewVoice())]);
      await tester.tap(find.byTooltip('Listen'));
      await tester.pumpAndSettle();
      final message = find.byType(SnackBar);
      expect(message, findsOneWidget);
      expect(tester.getRect(message).bottom, lessThanOrEqualTo(tester.getRect(find.byType(ReaderBottomBar)).top));
    });
  });

  testWidgets('a section mark between verses is a rubric, like one inside a verse', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await pumpApp(tester, settings: const AppSettings(onboardingComplete: true), now: monday);
    c.read(routerProvider).go('/read/5787:2/0?mode=full');
    await loadTexts(tester);
    // A setumah follows Genesis 6:12.
    final mark = tester.widget<Text>(find.text('ס'));
    final scheme = Theme.of(tester.element(find.text('ס'))).colorScheme;
    expect(mark.style?.color, scheme.secondary);
  });

  // Focus mode dims every verse but the one tapped. The dimmed ink must still
  // be readable (4.5:1), not a 55% alpha fade of the normal ink.
  for (final theme in AppThemeMode.values.where((m) => m != AppThemeMode.system)) {
    testWidgets('focus mode dims verses with readable ink: ${theme.name}', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = await pumpApp(
        tester,
        settings: AppSettings(onboardingComplete: true, theme: theme, focusMode: true, showTranslation: true),
        now: monday,
      );
      c.read(routerProvider).go('/read/5787:2/0?mode=full');
      await loadTexts(tester);
      // Focus mode opens on the reader's place, the first verse: every other
      // verse is dimmed.
      expect(tester.widget<VerseGroup>(find.byType(VerseGroup).first).highlighted, isTrue);

      final dimmed = find.byWidgetPredicate(
        (w) => (w is ScriptureVerse && w.dimmed) || (w is TranslationVerse && w.dimmed),
      );
      expect(dimmed, findsWidgets);
      await expectLater(
        tester,
        meetsGuideline(CustomMinimumContrastGuideline(finder: dimmed, minimumRatio: 4.5)),
      );
    });
  }

  testWidgets('onboarding sets the join date and opens the reader', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await pumpApp(tester, settings: const AppSettings(), now: monday);
    await tester.pumpAndSettle();
    await tester.tap(find.text("Start this week's parsha"));
    await tester.pumpAndSettle();
    expect(find.text('Where will you be this Shabbat?'), findsOneWidget);
    expect(find.textContaining('Visiting? You can set the days of Yom Tov you keep separately in Settings.'), findsOneWidget);
    await tester.tap(find.text('In Israel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Your plan this week'), findsOneWidget);
    await tester.tap(find.text('Start reading'));
    await loadTexts(tester);
    final s = c.read(settingsProvider);
    expect(s.onboardingComplete, isTrue);
    expect(s.readingSchedule, ReadingSchedule.israel);
    expect(s.oneDayYomTov, isTrue, reason: 'the location sets the days of Yom Tov too');
    expect(s.joinDate, isNotNull);
    expect(find.text('Read the Hebrew'), findsOneWidget);
    expect(kAliyot, 7);
  });
}

/// Speech without a Hebrew voice, which says so in a status message.
class _NoHebrewVoice extends RecordingTts {
  @override
  Future<bool?> hasHebrewVoice() async => false;
}
