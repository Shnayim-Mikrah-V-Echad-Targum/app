import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/data/models/scripture.dart';
import 'package:shnayim_mikra/data/models/verse_ref.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikra/features/reader/reader_flow.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/features/today/today_clock.dart';
import 'package:shnayim_mikra/ui/widgets/ledger.dart';
import 'package:shnayim_mikra/ui/widgets/ornaments.dart' show TitlePageFrame;
import 'package:shnayim_mikra/ui/widgets/paper_group.dart';

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

    testWidgets('gives way, once the parsha is read, to saying so', (tester) async {
      await openToday(
        tester,
        progress: ProgressState(weeks: {'5787:1': WeekProgress(weekId: '5787:1').withAll(LocalDate(2026, 10, 8))}),
      );
      expect(find.text("This week's parsha is complete. Yasher koach!"), findsOneWidget);
      expect(find.bySubtype<FilledButton>(), findsNothing);
      expect(find.byIcon(Icons.celebration_outlined), findsNothing);
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
      expect(find.textContaining('Genesis 1:1–6:8'), findsOneWidget);
      expect(find.textContaining('Read on Shabbat, October 10'), findsOneWidget);
      expect(find.text('Shabbat begins this evening'), findsOneWidget);
      final heading = tester.getSemantics(find.bySemanticsLabel('Parshat Bereshit'));
      expect(heading, isSemantics(label: 'Parshat Bereshit', isHeader: true));
      expect(heading.getSemanticsData().headingLevel, 1);
      // The app's name heads nothing.
      expect(tester.getSemantics(find.text('Shnayim Mikra')), isSemantics(isHeader: false));
      expect(find.byType(TitlePageFrame), findsOneWidget);
      expect(find.byType(AppBar), findsNothing);
      handle.dispose();
    });

    testWidgets('in Hebrew, with the Hebrew date first and the name in English beneath, tagged so', (tester) async {
      final handle = tester.ensureSemantics();
      await openToday(tester, settings: _settings.copyWith(language: AppLanguage.hebrew), progress: _bereshit());
      expect(find.text('פרשת השבוע'), findsOneWidget);
      expect(find.textContaining('יום שישי, כ״ח בתשרי תשפ״ז'), findsOneWidget);
      expect(find.textContaining('9 באוקטובר'), findsOneWidget);
      expect(find.textContaining('נקראת בשבת, כ״ט בתשרי'), findsOneWidget);
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

    testWidgets("leads to all of the week's aliyot, within Today", (tester) async {
      final c = await openToday(tester, progress: _bereshit());
      await tester.tap(find.text('All aliyot'));
      await tester.pumpAndSettle();
      expect(location(c), '/today/week/5787:1');
    });

    testWidgets('opens the guide from the running head', (tester) async {
      final c = await openToday(tester);
      await tester.tap(find.byTooltip('How it works'));
      await tester.pumpAndSettle();
      expect(location(c), '/guide');
    });
  });

  group('below the reading', () {
    testWidgets('the week strip is headed, with its legend a tap away', (tester) async {
      await openToday(tester, progress: _bereshit());
      final header = find.text("This week's plan");
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
      expect(find.text('Begins with Bereshit'), findsOneWidget);
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
      final group = find.ancestor(of: find.text("Discuss this week's parsha"), matching: find.byType(PaperGroup));
      await tester.ensureVisible(group);
      await tester.pumpAndSettle();
      expect(find.text('This week'), findsOneWidget);
      expect(find.descendant(of: group, matching: find.byType(PaperRow)), findsNWidgets(2));
      final haftarah = find.widgetWithText(PaperRow, 'Haftarah');
      expect(
        tester.widget<PaperRow>(haftarah).subtitle,
        'I Samuel 20:18–42\nSpecial haftarah: Shabbat Machar Chodesh\nAlso the regular haftarah',
      );
      await tester.tap(haftarah);
      await loadTexts(tester);
      expect(location(c), '/today/haftarah/5787:1');

      await openToday(tester, settings: _settings.copyWith(haftarahEnabled: false), progress: _bereshit());
      expect(find.widgetWithText(PaperRow, 'Haftarah'), findsNothing);
      expect(find.widgetWithText(PaperRow, "Discuss this week's parsha"), findsOneWidget);
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
