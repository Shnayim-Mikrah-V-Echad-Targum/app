import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/core/text/hebrew_text.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';

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
    expect(find.text('Targum Onkelos'), findsOneWidget);
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
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }
      expect(week().isAliyahDone(0), isTrue);
      expect(week().positions[0], [14, 14, 14]);

      c.read(routerProvider).go('/week/5787:2');
      await tester.pumpAndSettle();
      final rishon = find.ancestor(of: find.text('Rishon · aliyah 1'), matching: find.byType(ListTile));
      await tester.tap(find.descendant(of: rishon, matching: find.byTooltip('More options')));
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

  testWidgets('aliyah chips show what is read and under way, not which is open', (tester) async {
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

    Finder chip(String name) => find.ancestor(of: find.text(name), matching: find.byType(ChoiceChip));
    Finder inChip(String name, IconData icon) => find.descendant(of: chip(name), matching: find.byIcon(icon));
    expect(tester.widget<ChoiceChip>(chip("Revi'i")).selected, isTrue);
    final open = tester.getRect(chip("Revi'i"));
    expect(open.left >= 0 && open.right <= 412, isTrue, reason: 'the open aliyah is scrolled into view');
    expect(inChip("Revi'i", Icons.check), findsNothing, reason: 'being open is not being read');
    expect(inChip("Revi'i", Icons.check_circle), findsNothing);
    expect(inChip("Revi'i", Icons.timelapse), findsNothing);
    expect(inChip('Rishon', Icons.check_circle), findsOneWidget);
    expect(inChip('Shlishi', Icons.timelapse), findsOneWidget, reason: 'two of its three readings are done');
    expect(inChip('Sheni', Icons.check_circle), findsNothing);
    expect(inChip('Sheni', Icons.timelapse), findsNothing);

    expect(find.bySemanticsLabel(RegExp(r'^Rishon, read')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r'^Shlishi, in progress')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r"^Revi'i, not started")), findsOneWidget);
    handle.dispose();
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

    // Shevi'i is the last aliyah, but Shlishi is still under way.
    expect(find.textContaining("Shevi'i is complete"), findsWidgets);
    await tester.tap(find.text('Continue with Shlishi'));
    await tester.pumpAndSettle();
    expect(find.text('Noach · Shlishi'), findsOneWidget);
    expect(find.text('Read the Hebrew'), findsOneWidget);

    // Once every aliyah is read, there is nothing to continue with.
    await tester.tap(find.byTooltip('More options'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark this aliyah as read'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Parshat Noach is complete'), findsWidgets);
    expect(find.textContaining('Continue with'), findsNothing);
  });

  testWidgets('read by section, the Targum of Numbers 32:3 is followed by its Hebrew', (tester) async {
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
    expect(find.text('Reading 3 of 3'), findsOneWidget, reason: 'no separate step for the third reading');
    expect(find.textContaining('Onkelos here gives mostly the Aramaic forms of the place names'), findsOneWidget);
    expect(find.text('Torah'), findsOneWidget, reason: 'the Hebrew is labelled among the Targum');
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

  testWidgets('reader meets accessibility guidelines', (tester) async {
    final handle = tester.ensureSemantics();
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await pumpApp(tester, settings: const AppSettings(onboardingComplete: true), now: monday);
    c.read(routerProvider).go('/read/5787:2/0');
    await loadTexts(tester);
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
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
  });

  testWidgets('full-text mode shows Torah and Targum together', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await pumpApp(tester, settings: const AppSettings(onboardingComplete: true), now: monday);
    c.read(routerProvider).go('/read/5787:2/0?mode=full');
    await loadTexts(tester);
    expect(find.text('Chapter 6'), findsOneWidget);
    expect(find.text('Mark this aliyah as read'), findsNothing, reason: 'the button is at the end of the list');
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
