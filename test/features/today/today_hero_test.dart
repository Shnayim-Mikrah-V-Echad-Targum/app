import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shnayim_mikrah/app/providers.dart';
import 'package:shnayim_mikrah/app/router.dart';
import 'package:shnayim_mikrah/core/calendar/local_date.dart';
import 'package:shnayim_mikrah/data/models/scripture.dart';
import 'package:shnayim_mikrah/data/models/verse_ref.dart';
import 'package:shnayim_mikrah/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikrah/features/reader/reader_flow.dart';
import 'package:shnayim_mikrah/features/settings/app_settings.dart';
import 'package:shnayim_mikrah/features/today/today_clock.dart';
import 'package:shnayim_mikrah/features/today/today_screen.dart';
import 'package:shnayim_mikrah/ui/widgets/ledger.dart';
import 'package:shnayim_mikrah/ui/widgets/ornaments.dart' show SeferDivider, TitlePageFrame;
import 'package:shnayim_mikrah/ui/widgets/paper_group.dart';
import 'package:shnayim_mikrah/ui/widgets/progress_widgets.dart' show ParshaRings, RingsWithLegend;

import '../../helpers.dart';

/// Joined on Sunday 4 October 2026 (Simchat Torah outside Israel), before
/// the week of Bereshit began on Monday the 5th.
final _settings = AppSettings(onboardingComplete: true, joinDate: LocalDate(2026, 10, 4));

/// Rishon and Sheni read, and Shlishi read twice in Hebrew, marked from the
/// week's page, so no place in it is saved: the Targum is left.
ProgressState _bereshit() {
  final mon = LocalDate(2026, 10, 5);
  var w = WeekProgress(weekId: '5787:1').withAliyah(0, mon).withAliyah(1, mon.addDays(1));
  w = w.withUnit(2, ReadingPass.mikra1, mon.addDays(2)).withUnit(2, ReadingPass.mikra2, mon.addDays(2));
  return ProgressState(weeks: {'5787:1': w});
}

/// Friday 9 October 2026, Erev Shabbat Bereshit, in the morning.
final _friday = DateTime(2026, 10, 9, 11);

void main() {
  setUp(TodayScreen.forgetCompletions);

  Future<ProviderContainer> openToday(
    WidgetTester tester, {
    AppSettings? settings,
    DateTime? now,
    ProgressState? progress,
    Size size = const Size(412, 915),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await pumpApp(tester, settings: settings ?? _settings, now: now ?? _friday, progress: progress);
    await tester.pumpAndSettle();
    return c;
  }

  /// Settles a page that loads its texts from assets, which takes real time.
  Future<void> loadTexts(WidgetTester tester) async {
    await tester.pump();
    await tester.pump();
    for (var i = 0; i < 20 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  String location(ProviderContainer c) => c.read(routerProvider).state.uri.toString();

  group('the button', () {
    testWidgets('names exactly where the reading continues, opens it there, and is the only filled one',
        (tester) async {
      final c = await openToday(tester, progress: _bereshit());
      expect(find.bySubtype<FilledButton>(), findsOneWidget);
      final button = find.widgetWithText(FilledButton, 'Continue · Shlishi, Targum');
      expect(button, findsOneWidget);
      expect(tester.getSize(button).height, greaterThanOrEqualTo(52));
      // No outlined count that looks like a button.
      expect(find.bySubtype<OutlinedButton>(), findsNothing);
      expect(find.text('2 of 7 aliyot'), findsNothing);

      await tester.tap(button);
      await loadTexts(tester);
      expect(location(c), '/read/5787:1/2');
      expect(find.text('Read the Targum'), findsOneWidget, reason: 'Shlishi resumes at its Targum');
    });

    testWidgets('starts the week, and continues at an aliyah with none of it read', (tester) async {
      await openToday(tester, progress: ProgressState(weeks: {}));
      expect(find.text('Start · Rishon'), findsOneWidget);

      final mon = LocalDate(2026, 10, 5);
      await openToday(
        tester,
        progress: ProgressState(weeks: {
          '5787:1': WeekProgress(weekId: '5787:1').withAliyah(0, mon).withAliyah(1, mon),
        }),
      );
      expect(find.text('Continue · Shlishi'), findsOneWidget);
    });

    testWidgets("names the reader's own second reading", (tester) async {
      await openToday(tester, settings: _settings.copyWith(secondReading: SecondReading.rashi), progress: _bereshit());
      expect(find.text('Continue · Shlishi, Rashi'), findsOneWidget);
    });

    testWidgets('in Hebrew', (tester) async {
      await openToday(tester, settings: _settings.copyWith(language: AppLanguage.hebrew), progress: _bereshit());
      expect(find.text('המשך · שלישי, תרגום'), findsOneWidget);
    });

    // A phone, a wider compact window (a large phone at a small display
    // size, or a narrowed window), a tablet beside the compact rail, at 100%
    // and 150% text, and a desktop's column, in English and in Hebrew. The
    // rings' group, as wide as the rings, the gap and the legend's natural
    // width with its slack, is wider than 360 in each, and wider than the
    // frame's content in a compact window or at large text: the button then
    // spans the frame.
    for (final (width, hebrew, scale, spans) in [
      (412.0, false, 1.0, true),
      (412.0, true, 1.0, true),
      (500.0, false, 1.0, true),
      (800.0, false, 1.0, false),
      (800.0, false, 1.5, true),
      (1366.0, false, 1.0, false),
      (1366.0, true, 1.0, false),
    ]) {
      final what = spans
          ? "spans a frame narrower than the rings' group"
          : 'stands centred under the rings, as wide as their group';
      final how = [if (hebrew) 'in Hebrew', if (scale != 1) 'at ${(scale * 100).round()}% text'];
      testWidgets('$what at ${width.round()} dp${how.map((h) => ', $h').join()}', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await openToday(
          tester,
          size: Size(width, 1600),
          settings: hebrew ? _settings.copyWith(language: AppLanguage.hebrew) : null,
          progress: _bereshit(),
        );
        final button = tester.getRect(find.bySubtype<FilledButton>());
        // The frame's content, which the button may span, and the rings'
        // group, centred in it.
        Rect column(Finder inside) => tester.getRect(find.ancestor(of: inside, matching: find.byType(Column)).first);
        final content = column(find.byType(SeferDivider));
        final rings = column(find.byType(RingsWithLegend));
        expect(button.center.dx, moreOrLessEquals(content.center.dx));
        expect(rings.center.dx, moreOrLessEquals(content.center.dx));
        // The group is as wide as it may be in the frame; the button as wide
        // as the group, or 360 should that be wider, within the frame.
        expect(button.width, moreOrLessEquals(math.min(content.width, math.max(360, rings.width))));
        if (spans) {
          expect(rings.width, content.width);
          expect(button.width, content.width);
        } else {
          expect(rings.width, greaterThan(360), reason: 'the button follows the group, not 360 alone');
          expect(button.width, lessThan(content.width));
        }
      });
    }

    testWidgets('gives way, once the parsha is read, to saying so', (tester) async {
      final c = await openToday(
        tester,
        progress: ProgressState(weeks: {'5787:1': WeekProgress(weekId: '5787:1').withAll(LocalDate(2026, 10, 8))}),
      );
      expect(find.bySemanticsLabel('This week’s parsha is complete. Yasher koach!'), findsOneWidget);
      expect(find.text('Ready to hear it read on Shabbat.'), findsOneWidget);
      expect(find.byType(ParshaRings), findsNothing);
      expect(find.textContaining(RegExp('^(Start|Continue) ·')), findsNothing);
      expect(find.byIcon(Icons.celebration_outlined), findsNothing);
      // The haftarah, still to read, is the one button that looks like one,
      // and it is tonal.
      final haftarah = find.widgetWithText(FilledButton, 'Read the haftarah');
      expect(find.bySubtype<FilledButton>(), findsOneWidget);
      expect(tester.widget<FilledButton>(haftarah).style?.backgroundColor, isNotNull, reason: 'it is tonal');
      expect(find.widgetWithText(TextButton, 'Discuss the parsha'), findsOneWidget);
      await tester.tap(haftarah);
      await tester.pump();
      expect(c.read(routerProvider).state.uri.path, '/today/haftarah/5787:1');

      // Once read, only the discussion is offered.
      await openToday(
        tester,
        progress: ProgressState(weeks: {
          '5787:1': WeekProgress(weekId: '5787:1').withAll(LocalDate(2026, 10, 8)).withHaftarah(LocalDate(2026, 10, 8)),
        }),
      );
      expect(find.bySubtype<FilledButton>(), findsNothing);
      expect(find.widgetWithText(TextButton, 'Discuss the parsha'), findsOneWidget);
    });

    testWidgets('for Vezot HaBerachah, is ready for Simchat Torah', (tester) async {
      // Hoshana Rabbah 5787 in Israel, where Simchat Torah is on Shabbat.
      await openToday(
        tester,
        settings: _settings.copyWith(
          readingSchedule: ReadingSchedule.israel,
          oneDayYomTov: true,
          joinDate: LocalDate(2026, 9, 20),
        ),
        now: DateTime(2026, 10, 2, 11),
        progress: ProgressState(weeks: {'5786:54': WeekProgress(weekId: '5786:54').withAll(LocalDate(2026, 10, 1))}),
      );
      expect(find.text('Ready to hear it read on Simchat Torah.'), findsOneWidget);
    });

    group('once the parsha is read while the app is open, its frame', () {
      /// Shevi'i's Targum alone left; then logged.
      Future<ProviderContainer> finish(WidgetTester tester, {AppSettings? settings}) async {
        final w = WeekProgress(weekId: '5787:1').withAll(LocalDate(2026, 10, 8)).withUnit(6, ReadingPass.targum, null);
        final c = await openToday(tester, settings: settings, progress: ProgressState(weeks: {'5787:1': w}));
        expect(tester.widget<TitlePageFrame>(find.byType(TitlePageFrame)).drawProgress, isNull);
        c.read(progressProvider.notifier).markUnit('5787:1', 6, ReadingPass.targum, LocalDate(2026, 10, 9));
        await tester.pump();
        return c;
      }

      double? drawn(WidgetTester tester) => tester.widget<TitlePageFrame>(find.byType(TitlePageFrame)).drawProgress;

      testWidgets('draws itself around the page once, and stays', (tester) async {
        final c = await finish(tester);
        expect(drawn(tester), 0);
        await tester.pump(const Duration(milliseconds: 450));
        expect(drawn(tester), allOf(greaterThan(0), lessThan(1)));
        await tester.pumpAndSettle();
        expect(drawn(tester), 1);

        // Undone and finished again, it is drawn already.
        c.read(progressProvider.notifier).markUnit('5787:1', 6, ReadingPass.targum, null);
        await tester.pumpAndSettle();
        c.read(progressProvider.notifier).markUnit('5787:1', 6, ReadingPass.targum, LocalDate(2026, 10, 9));
        await tester.pump();
        expect(drawn(tester), 1);
        await tester.pump(const Duration(milliseconds: 300));
        expect(drawn(tester), 1);
      });

      testWidgets('is drawn at once under Reduce Motion', (tester) async {
        await finish(tester, settings: _settings.copyWith(reduceMotion: true));
        expect(drawn(tester), 1);
      });

      testWidgets('waits until the page can be seen', (tester) async {
        final w = WeekProgress(weekId: '5787:1').withAll(LocalDate(2026, 10, 8)).withUnit(6, ReadingPass.targum, null);
        final c = await openToday(tester, progress: ProgressState(weeks: {'5787:1': w}));
        c.read(routerProvider).push('/settings');
        await tester.pumpAndSettle();
        c.read(progressProvider.notifier).markUnit('5787:1', 6, ReadingPass.targum, LocalDate(2026, 10, 9));
        await tester.pumpAndSettle();
        c.read(routerProvider).pop();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(drawn(tester), lessThan(1));
        await tester.pumpAndSettle();
        expect(drawn(tester), 1);
      });

      testWidgets('is still in a restarted app', (tester) async {
        await openToday(
          tester,
          progress: ProgressState(weeks: {'5787:1': WeekProgress(weekId: '5787:1').withAll(LocalDate(2026, 10, 8))}),
        );
        expect(drawn(tester), 1);
        expect(tester.binding.hasScheduledFrame, isFalse);
      });
    });

    test('resumes a reading marked done with no place saved after it', () {
      final day = LocalDate(2026, 10, 7);
      final week = WeekProgress(weekId: '5787:1')
          .withUnit(2, ReadingPass.mikra1, day)
          .withUnit(2, ReadingPass.mikra2, day);
      expect(week.savedPositions(2, 6), [6, 6, 0]);
      // A place saved partway through a reading since marked done.
      expect(week.withPosition(2, const [3, 0, 0]).savedPositions(2, 6), [6, 6, 0]);
      // A place that claims a reading not marked done is still stale.
      expect(WeekProgress(weekId: '5787:1').withPosition(2, const [6, 6, 0]).savedPositions(2, 6), [0, 0, 0]);

      final flow = ReaderFlow(
        book: 'Genesis',
        verses: [for (var v = 1; v <= 6; v++) VerseRef(2, v)],
        method: ReadingMethod.verseByVerse,
        second: SecondReading.onkelos,
        hasRashi: List.filled(6, true),
        breaks: const <VerseRef, SectionBreak>{},
        thirdReadingPrompts: true,
        repeatLastVerse: false,
      );
      expect(flow.resumeFrom(week.savedPositions(2, 6)), (0, 2), reason: 'the Targum of the first verse');
    });
  });

  group('the title page', () {
    testWidgets("names the parsha as a heading, in Hebrew with its vowels, and when it's read", (tester) async {
      final handle = tester.ensureSemantics();
      await openToday(tester, progress: _bereshit());
      expect(find.text('Parshat HaShavua'), findsOneWidget);
      expect(find.text('בְּרֵאשִׁית'), findsOneWidget);
      expect(find.text('Bereshit'), findsOneWidget);
      expect(findWords('Genesis 1:1–6:8'), findsOneWidget);
      expect(findWords('Read on Shabbat, October 10'), findsOneWidget);
      expect(find.text('Shabbat begins this evening'), findsOneWidget);
      final heading = tester.getSemantics(find.bySemanticsLabel('Parshat Bereshit'));
      expect(heading, isSemantics(label: 'Parshat Bereshit', isHeader: true));
      expect(heading.getSemanticsData().headingLevel, 1);
      // The app's name heads nothing.
      expect(tester.getSemantics(find.text('Shnayim Mikrah')), isSemantics(isHeader: false));
      expect(find.byType(TitlePageFrame), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
      handle.dispose();
    });

    testWidgets('in Hebrew, with the Hebrew date first and the name in English beneath, tagged so', (tester) async {
      final handle = tester.ensureSemantics();
      await openToday(tester, settings: _settings.copyWith(language: AppLanguage.hebrew), progress: _bereshit());
      expect(find.text('פרשת השבוע'), findsOneWidget);
      expect(findWords('יום שישי, כ״ח בתשרי תשפ״ז'), findsOneWidget);
      expect(findWords('9 באוקטובר'), findsOneWidget);
      expect(findWords('נקראת בשבת, כ״ט בתשרי'), findsOneWidget);
      expect(find.text('שבת נכנסת הערב'), findsOneWidget);
      expect(tester.getSemantics(find.bySemanticsLabel('פרשת בראשית')), isSemantics(isHeader: true));
      final latin = tester.getSemantics(find.text('Bereshit')).getSemanticsData();
      expect(latin.label, 'Bereshit');
      handle.dispose();
    });

    testWidgets('becomes Erev Shabbat at midday on Friday', (tester) async {
      await openToday(tester, now: DateTime(2026, 10, 9, 12));
      expect(find.text('Erev Shabbat'), findsOneWidget);
      expect(find.text('Parshat HaShavua'), findsNothing);

      // Thursday afternoon is not.
      await openToday(tester, now: DateTime(2026, 10, 8, 15));
      expect(find.text('Parshat HaShavua'), findsOneWidget);
      expect(find.text('Shabbat is tomorrow'), findsNothing);
      expect(find.text('Shabbat in 2 days'), findsOneWidget);
    });

    testWidgets('on the eve of Yom Tov, says it begins this evening, and from midday is headed by it',
        (tester) async {
      // Wednesday 20 September 2028, Erev Rosh Hashanah 5789, with no city
      // chosen: Haazinu's Shabbat is three days off, but reading stops
      // tonight.
      final erev = DateTime(2028, 9, 20, 11);
      await openToday(tester, now: erev, progress: ProgressState(weeks: {}));
      expect(find.text('Rosh Hashanah begins this evening'), findsOneWidget);
      expect(find.text('Shabbat in 3 days'), findsNothing);
      expect(find.text('Parshat HaShavua'), findsOneWidget);

      await openToday(tester, now: DateTime(2028, 9, 20, 12), progress: ProgressState(weeks: {}));
      expect(find.text('Erev Rosh Hashanah'), findsOneWidget);
      expect(find.text('Parshat HaShavua'), findsNothing);

      await openToday(
        tester,
        settings: _settings.copyWith(language: AppLanguage.hebrew),
        now: DateTime(2028, 9, 20, 12),
        progress: ProgressState(weeks: {}),
      );
      expect(find.text('ערב ראש השנה'), findsOneWidget);
      expect(find.text('ראש השנה נכנס הערב'), findsOneWidget);

      // Wednesday 1 October 2025, Erev Yom Kippur 5786, in the week of
      // Haazinu.
      await openToday(
        tester,
        settings: _settings.copyWith(joinDate: LocalDate(2025, 9, 1)),
        now: DateTime(2025, 10, 1, 15),
        progress: ProgressState(weeks: {}),
      );
      expect(find.text('Erev Yom Kippur'), findsOneWidget);
      expect(find.text('Yom Kippur begins this evening'), findsOneWidget);

      // Sunday 10 October 2027, Erev Yom Kippur 5788, when Haazinu was read
      // before it: the week is Vezot HaBerachah's, but Simchat Torah, two
      // weeks off, waits.
      await openToday(
        tester,
        settings: _settings.copyWith(joinDate: LocalDate(2027, 9, 1)),
        now: DateTime(2027, 10, 10, 15),
        progress: ProgressState(weeks: {}),
      );
      expect(find.text('Simchat Torah'), findsOneWidget);
      expect(find.text('Yom Kippur begins this evening'), findsOneWidget);
      expect(find.textContaining('Simchat Torah in'), findsNothing);

      // Hoshana Rabbah 5789, Wednesday 11 October 2028: outside Israel,
      // Shemini Atzeret begins this evening, and Simchat Torah is the day
      // after; in Israel, Simchat Torah is tomorrow, and says so.
      final hoshanaRabbah = DateTime(2028, 10, 11, 15);
      final joined = _settings.copyWith(joinDate: LocalDate(2028, 9, 1));
      await openToday(tester, settings: joined, now: hoshanaRabbah, progress: ProgressState(weeks: {}));
      expect(find.text('Yom Tov begins this evening'), findsOneWidget);
      await openToday(
        tester,
        settings: joined.locatedIn(ReadingSchedule.israel),
        now: hoshanaRabbah,
        progress: ProgressState(weeks: {}),
      );
      expect(find.text('Simchat Torah is tomorrow'), findsOneWidget);
      expect(find.text('Yom Tov begins this evening'), findsNothing);

      // Thursday 10 June 2027, Erev Shavuot, which outside Israel runs on
      // into Shabbat.
      await openToday(
        tester,
        settings: _settings.copyWith(joinDate: LocalDate(2027, 6, 6)),
        now: DateTime(2027, 6, 10, 15),
        progress: ProgressState(weeks: {}),
      );
      expect(find.text('Erev Yom Tov'), findsOneWidget);
      expect(find.text('Yom Tov begins this evening'), findsOneWidget);
    });

    testWidgets('on a Friday before Yom Tov, is Erev Shabbat', (tester) async {
      // Friday 18 May 2029, with Shavuot on Sunday and Monday.
      await openToday(
        tester,
        settings: _settings.copyWith(joinDate: LocalDate(2029, 5, 1)),
        now: DateTime(2029, 5, 18, 15),
        progress: ProgressState(weeks: {}),
      );
      expect(find.text('Erev Shabbat'), findsOneWidget);
      expect(find.text('Shabbat begins this evening'), findsOneWidget);
      expect(find.text('Erev Yom Tov'), findsNothing);
      expect(find.text('Yom Tov begins this evening'), findsNothing);
    });

    testWidgets('in the week of Vezot HaBerachah, is headed Simchat Torah', (tester) async {
      // Hoshana Rabbah 5787, a Friday, in the afternoon.
      await openToday(
        tester,
        settings: _settings.copyWith(joinDate: LocalDate(2026, 9, 20)),
        now: DateTime(2026, 10, 2, 15),
      );
      expect(find.text('Simchat Torah'), findsOneWidget);
      expect(find.text('Erev Shabbat'), findsNothing);
    });

    testWidgets('in the week of Vezot HaBerachah, says on a Friday that Shabbat begins this evening', (tester) async {
      final joined = _settings.copyWith(joinDate: LocalDate(2026, 9, 1));
      // Friday 25 September 2026, Erev Sukkot 5787, which is on Shabbat,
      // after Haazinu was read: not "Simchat Torah in 9 days", nor 8 in
      // Israel.
      for (final israel in [false, true]) {
        await openToday(
          tester,
          settings: israel ? joined.locatedIn(ReadingSchedule.israel) : joined,
          now: DateTime(2026, 9, 25, 11),
          progress: ProgressState(weeks: {}),
        );
        expect(find.text('Simchat Torah'), findsOneWidget, reason: 'israel: $israel');
        expect(find.text('Shabbat begins this evening'), findsOneWidget, reason: 'israel: $israel');
        expect(find.textContaining('Simchat Torah in'), findsNothing, reason: 'israel: $israel');
      }
      // Hoshana Rabbah 5787, Friday 2 October 2026: outside Israel, Shabbat
      // and Shemini Atzeret begin this evening, and Simchat Torah is two
      // days off; in Israel, Simchat Torah is that Shabbat, tomorrow.
      final hoshanaRabbah = DateTime(2026, 10, 2, 11);
      await openToday(tester, settings: joined, now: hoshanaRabbah, progress: ProgressState(weeks: {}));
      expect(find.text('Shabbat begins this evening'), findsOneWidget);
      expect(find.text('Simchat Torah in 2 days'), findsNothing);
      await openToday(
        tester,
        settings: joined.locatedIn(ReadingSchedule.israel),
        now: hoshanaRabbah,
        progress: ProgressState(weeks: {}),
      );
      expect(find.text('Simchat Torah is tomorrow'), findsOneWidget);
      expect(find.text('Shabbat begins this evening'), findsNothing);
    });

    testWidgets("leads to all of the week's aliyot, within Today", (tester) async {
      final c = await openToday(tester, progress: _bereshit());
      await tester.tap(find.text('All aliyot'));
      await tester.pumpAndSettle();
      expect(location(c), '/today/week/5787:1');
    });

    testWidgets('opens the guide from the running head, within Today', (tester) async {
      final c = await openToday(tester);
      await tester.tap(find.byTooltip('How it works'));
      await tester.pumpAndSettle();
      expect(location(c), '/today/guide');
    });
  });

  group('below the reading', () {
    testWidgets('the week strip is headed, with its legend a tap away', (tester) async {
      await openToday(tester, progress: _bereshit());
      final header = find.text('This week’s plan');
      await tester.ensureVisible(header);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Legend'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(BottomSheet, 'Legend'), findsOneWidget);
    });

    testWidgets('the streaks are one ledger, leading to Progress, and never a stark 0', (tester) async {
      final c = await openToday(tester, progress: _bereshit());
      final ledger = find.byType(LedgerCard);
      await tester.ensureVisible(ledger);
      await tester.pumpAndSettle();
      expect(find.text('Starts when Bereshit is complete'), findsOneWidget);
      expect(find.text('0 weeks'), findsNothing);
      expect(find.byIcon(Icons.event_available_outlined), findsNothing);
      await tester.tap(ledger);
      await tester.pumpAndSettle();
      expect(location(c), '/progress');

      await openToday(tester, settings: _settings.copyWith(showStreaks: false), progress: _bereshit());
      expect(find.byType(LedgerCard), findsNothing);
    });

    testWidgets("this week's haftarah and discussion share one sheet", (tester) async {
      final c = await openToday(tester, progress: _bereshit());
      final group = find.ancestor(of: find.text('Discuss this week’s parsha'), matching: find.byType(PaperGroup));
      await tester.ensureVisible(group);
      await tester.pumpAndSettle();
      // Headed apart from the week strip's "This week’s plan" above it.
      expect(find.widgetWithText(GroupHeader, 'Also this week'), findsOneWidget);
      expect(find.descendant(of: group, matching: find.byType(PaperRow)), findsNWidgets(2));
      final haftarah = find.widgetWithText(PaperRow, 'Haftarah');
      final row = tester.widget<PaperRow>(haftarah);
      // The book's name held on one line, and its range; the special
      // haftarah by name in the line under it.
      expect(row.subtitleParts, ['I\u00A0Samuel 20:18–\u206042']);
      expect(row.detail, 'Shabbat Machar Chodesh');
      await tester.tap(haftarah);
      await loadTexts(tester);
      expect(location(c), '/today/haftarah/5787:1');

      await openToday(tester, settings: _settings.copyWith(haftarahEnabled: false), progress: _bereshit());
      expect(find.widgetWithText(PaperRow, 'Haftarah'), findsNothing);
      expect(find.widgetWithText(PaperRow, 'Discuss this week’s parsha'), findsOneWidget);
    });
  });

  testWidgets('midday comes at noon', (tester) async {
    TodayController.autoRollover = true;
    addTearDown(() => TodayController.autoRollover = false);
    var now = DateTime(2026, 10, 9, 11, 59, 30);
    TodayController.now = () => now;
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
    expect(c.read(pastMiddayProvider), isFalse);
    now = DateTime(2026, 10, 9, 12);
    await tester.pump(const Duration(seconds: 30));
    expect(c.read(pastMiddayProvider), isTrue);
    // Its timers, and the reading day's, end with it.
    c.dispose();
  });
}
