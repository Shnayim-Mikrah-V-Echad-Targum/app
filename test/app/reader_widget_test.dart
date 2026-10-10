import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/core/text/hebrew_text.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikra/features/reader/reader_screen.dart';
import 'package:shnayim_mikra/features/reader/scripture_text.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/services/tts.dart';

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

  for (final hebrew in [false, true]) {
    testWidgets('the open aliyah chip is scrolled into view on a phone${hebrew ? ', right to left' : ''}', (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = await pumpApp(
        tester,
        settings: AppSettings(onboardingComplete: true, language: hebrew ? AppLanguage.hebrew : AppLanguage.english),
        now: monday,
      );
      // Shevi'i, the last, begins beyond the edge of a phone before it is
      // scrolled to: the right edge, or the left in Hebrew.
      c.read(routerProvider).go('/read/5787:2/6');
      await loadTexts(tester);
      final chip = find.ancestor(of: find.text(hebrew ? 'שביעי' : "Shevi'i"), matching: find.byType(ChoiceChip));
      expect(tester.widget<ChoiceChip>(chip).selected, isTrue);
      final open = tester.getRect(chip);
      expect(open.left, greaterThanOrEqualTo(0));
      expect(open.right, lessThanOrEqualTo(412));
    });
  }

  testWidgets('a chip whose saved place is stale is not under way, as the reader starts it over', (tester) async {
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
    final sheni = find.ancestor(of: find.text('Sheni'), matching: find.byType(ChoiceChip));
    expect(find.descendant(of: sheni, matching: find.byIcon(Icons.timelapse)), findsNothing);
    expect(find.bySemanticsLabel(RegExp(r'^Sheni, not started')), findsOneWidget);

    await tester.tap(sheni);
    await tester.pumpAndSettle();
    expect(find.text('Read the Hebrew'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^Verse 1 of ')), findsOneWidget);
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
    // Laid out in reading order: the step's label, the Onkelos of 32:1–3,
    // the Hebrew of 32:3 in a block of its own, then the label again
    // before the Onkelos of 32:4–19.
    final scroll = find.byType(SingleChildScrollView).last;
    final targumLabels = find.descendant(of: scroll, matching: find.text('Targum Onkelos'));
    expect(targumLabels, findsNWidgets(2));
    final torah = find.descendant(of: scroll, matching: find.text('Torah'));
    expect(torah, findsOneWidget);
    final note = find.textContaining('Onkelos here gives mostly the Aramaic forms of the place names');
    expect(tester.getTopLeft(targumLabels.first).dy, lessThan(tester.getTopLeft(torah).dy));
    expect(tester.getTopLeft(torah).dy, lessThan(tester.getTopLeft(note).dy));
    expect(tester.getTopLeft(note).dy, lessThan(tester.getTopLeft(targumLabels.last).dy));
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
      'on Windows, as on the web, a verse is labelled in Hebrew and its node is tagged he',
      (tester) async {
        final handle = tester.ensureSemantics();
        await openNoach(tester);
        expect(find.bySemanticsLabel(RegExp(r'^Verse 9\. ')), findsNothing);
        final verse = labelled(tester, RegExp(r'^פסוק 9\. '));
        expect(HebrewText.consonantsOnly(verse.label), startsWith('פסוק 9. אלה תולדת נח'));
        expect(verse.locale, const Locale('he'));
        handle.dispose();
      },
      variant: TargetPlatformVariant.only(TargetPlatform.windows),
    );

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
          if (announces) isAccessibilityAnnouncement('Read the Hebrew again. Reading 2 of 3. Verse 1 of 14'),
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
    expect(find.text('Chapter 6'), findsOneWidget);
    // Built with the text, so that Tab reaches it, but at its end.
    expect(tester.getTopLeft(find.text('Mark this aliyah as read')).dy, greaterThan(900), reason: 'the button is at the end of the text');
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
      expect(tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Back')).onPressed, isNull);
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
        for (var i = 0; i < 3; i++) {
          await tester.tap(find.text('Next'));
          await tester.pumpAndSettle();
        }
        const heading = 'Yasher koach! Rishon is complete.';
        expect(find.text(heading), findsOneWidget);
        expect(focused(tester, 'Continue with Sheni'), isTrue);
        expect(tester.getSemantics(find.text(heading)), isSemantics(label: heading, isHeader: true, isLiveRegion: !announces));
        expect(tester.takeAnnouncements().map((a) => a.message), announces ? contains(heading) : isEmpty);

        // Continued from the keyboard, the next aliyah opens with the focus
        // on Next.
        await press(tester, LogicalKeyboardKey.enter);
        expect(find.text('Noach · Sheni'), findsOneWidget);
        expect(focused(tester, 'Next'), isTrue);
        handle.dispose();
      });
    }

    testWidgets('in focus mode, ↓ and ↑ move the verse read and keep it in view', (tester) async {
      // The first reading has reached Genesis 6:15, the seventh verse.
      final progress = ProgressState(weeks: {'5787:2': WeekProgress(weekId: '5787:2').withPosition(0, const [6, 6, 6])});
      await open(
        tester,
        '/read/5787:2/0?mode=full',
        settings: const AppSettings(onboardingComplete: true, focusMode: true),
        progress: progress,
      );
      Finder current() => find.byWidgetPredicate((w) => w is ScriptureVerse && w.highlighted);
      int verse() => tester.widget<ScriptureVerse>(current()).verse.ref.verse;
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
      handle.dispose();
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      c.read(routerProvider).go('/settings/accessibility');
      await tester.pumpAndSettle();
      expect(find.text('Single-key shortcuts'), findsNothing, reason: 'there are none to turn off');
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
