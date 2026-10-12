import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/core/calendar/hebrew_date.dart';
import 'package:shnayim_mikra/core/calendar/jewish_holidays.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/core/calendar/parsha_schedule.dart';
import 'package:shnayim_mikra/data/models/parsha.dart';
import 'package:shnayim_mikra/features/parsha/week_context.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikra/features/progress/domain/reading_plan.dart';
import 'package:shnayim_mikra/features/progress/domain/streak_engine.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/features/today/check_in.dart';
import 'package:shnayim_mikra/l10n/app_localizations.dart';
import 'package:shnayim_mikra/ui/widgets/common.dart' show NoticeBanner;
import 'package:shnayim_mikra/ui/widgets/lines.dart' show DotLine;

import '../../helpers.dart';

/// Joined on Sunday 4 October 2026, before the week of Bereshit, read on
/// Shabbat 10 October.
final _settings = AppSettings(onboardingComplete: true, joinDate: LocalDate(2026, 10, 4));

const _checkIn = 'Shavua tov! Did you read Bereshit on Shabbat?';

const _finished = 'I finished Bereshit on Shabbat';

/// Of Bereshit, Rishon to Revi'i read on their days.
ProgressState _bereshit() {
  final monday = LocalDate(2026, 10, 5);
  var w = WeekProgress(weekId: '5787:1');
  for (var a = 0; a < 4; a++) {
    w = w.withAliyah(a, monday.addDays(a));
  }
  return ProgressState(weeks: {'5787:1': w});
}

/// The Monday after Shabbat Bereshit, the first time the app is opened since.
final _monday = DateTime(2026, 10, 12, 9);

void main() {
  Future<ProviderContainer> openToday(
    WidgetTester tester, {
    AppSettings? settings,
    DateTime? now,
    ProgressState? progress,
  }) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await pumpApp(
      tester,
      settings: settings ?? _settings,
      now: now ?? _monday,
      progress: progress ?? _bereshit(),
    );
    await tester.pumpAndSettle();
    return c;
  }

  WeekProgress bereshit(ProviderContainer c) => c.read(progressProvider).week('5787:1');

  group('the check-in after Shabbat', () {
    testWidgets('is still asked when the app is first opened on Monday', (tester) async {
      await openToday(tester);
      expect(find.text(_checkIn), findsOneWidget);
      expect(find.text('Bereshit is still open'), findsNothing);
    });

    testWidgets('is asked while the week can count as late, and not after', (tester) async {
      await openToday(tester, now: DateTime(2026, 10, 13, 9));
      expect(find.text(_checkIn), findsOneWidget, reason: 'Tuesday is the last day it counts as late');

      await openToday(tester, now: DateTime(2026, 10, 14, 9));
      expect(find.text(_checkIn), findsNothing);
      expect(find.text('Bereshit is still open'), findsOneWidget);
    });

    testWidgets('without a late window, is asked on the first day after Shabbat alone', (tester) async {
      final settings = _settings.copyWith(lateWindow: LateWindow.none);
      await openToday(tester, settings: settings, now: DateTime(2026, 10, 11, 9));
      expect(find.text(_checkIn), findsOneWidget);
      await openToday(tester, settings: settings);
      expect(find.text(_checkIn), findsNothing);
    });

    testWidgets('can be put aside for this time', (tester) async {
      final c = await openToday(tester);
      await tester.tap(find.text('Not this time'));
      await tester.pumpAndSettle();
      expect(c.read(settingsProvider).checkInAnsweredFor, '5787:1');
      expect(find.text(_checkIn), findsNothing);
      expect(find.text('Bereshit is still open'), findsOneWidget);
      expect(bereshit(c).completedAliyot, 4, reason: 'nothing logged');

      // Answered, it isn't asked again.
      await openToday(tester, settings: c.read(settingsProvider), now: DateTime(2026, 10, 13, 9));
      expect(find.text(_checkIn), findsNothing);
    });

    testWidgets('logs three aliyot and the haftarah in one sheet, which Undo takes back', (tester) async {
      final c = await openToday(tester);
      final before = bereshit(c);
      await tester.tap(find.text('Choose aliyot'));
      await tester.pumpAndSettle();

      expect(find.text(_checkIn), findsNWidgets(2), reason: 'the sheet is titled with the question');
      final boxes = find.byType(CheckboxListTile);
      expect(boxes, findsNWidgets(4), reason: 'Chamishi, Shishi, Shevi\'i and the haftarah');
      expect([for (final b in tester.widgetList<CheckboxListTile>(boxes)) b.value], everyElement(isTrue));
      expect(findDotLine('Genesis 4:19–22 · 4 verses'), findsOneWidget, reason: "Chamishi's reference");
      expect(find.text('I\u00A0Samuel 20:18–\u206042'), findsOneWidget, reason: 'the haftarah of Machar Chodesh');
      expect(findDotLine('Read on Shabbat, October 10'), findsOneWidget);

      await tester.tap(find.text('Log reading'));
      await tester.pumpAndSettle();
      final shabbat = LocalDate(2026, 10, 10);
      final week = bereshit(c);
      expect(week.isComplete, isTrue);
      expect(week.units[4], everyElement(shabbat));
      expect(week.haftarah, shabbat);
      expect(week.units[0], before.units[0], reason: 'what was read keeps its day');
      expect(c.read(settingsProvider).checkInAnsweredFor, '5787:1');
      expect(find.text('Chazak! Parshat Bereshit is complete.'), findsOneWidget);
      expect(find.text(_checkIn), findsNothing);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(bereshit(c).units, before.units);
      expect(bereshit(c).haftarah, isNull);
      expect(c.read(settingsProvider).checkInAnsweredFor, isNull);
      expect(find.text(_checkIn), findsOneWidget, reason: 'asked again, as before');
    });

    testWidgets('logs only what is still checked, on the day chosen', (tester) async {
      final c = await openToday(tester);
      await tester.tap(find.text('Choose aliyot'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Shevi’i'));
      await tester.tap(find.widgetWithText(CheckboxListTile, 'Haftarah'));
      await tester.pump();

      await tester.tap(find.text('Change date'));
      await tester.pumpAndSettle();
      expect(find.text('When did you read it?'), findsOneWidget);
      await tester.tap(find.widgetWithText(ListTile, 'Yesterday'));
      await tester.pumpAndSettle();
      expect(findWords('Read on Sunday, October 11'), findsOneWidget);

      await tester.tap(find.text('Log reading'));
      await tester.pumpAndSettle();
      final week = bereshit(c);
      expect([for (var a = 0; a < 7; a++) week.isAliyahDone(a)], [true, true, true, true, true, true, false]);
      expect(week.units[5], everyElement(LocalDate(2026, 10, 11)));
      expect(week.haftarah, isNull);
      expect(find.text('Marked as read'), findsOneWidget);
      expect(find.text('Bereshit is still open'), findsOneWidget);
    });

    testWidgets('with nothing checked, logs nothing', (tester) async {
      await openToday(tester);
      await tester.tap(find.text('Choose aliyot'));
      await tester.pumpAndSettle();
      for (final name in ['Chamishi', 'Shishi', 'Shevi’i', 'Haftarah']) {
        await tester.tap(find.widgetWithText(CheckboxListTile, name));
        await tester.pump();
      }
      expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Log reading')).onPressed, isNull);
    });

    testWidgets('offers no haftarah where it is not shown', (tester) async {
      await openToday(tester, settings: _settings.copyWith(haftarahEnabled: false));
      await tester.tap(find.text('Choose aliyot'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(CheckboxListTile, 'Haftarah'), findsNothing);
    });

    testWidgets('finishes the parsha at once, which Undo takes back', (tester) async {
      final c = await openToday(tester);
      final before = bereshit(c);
      await tester.tap(find.text(_finished));
      await tester.pumpAndSettle();
      expect(bereshit(c).isComplete, isTrue);
      expect(find.text('Chazak! Parshat Bereshit is complete.'), findsOneWidget);
      expect(find.text(_checkIn), findsNothing);

      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(bereshit(c).units, before.units);
      expect(find.text(_checkIn), findsOneWidget);
    });

    testWidgets("sets its tonal button 12 from the notice's end and foot, clear of the corner", (tester) async {
      Rect banner() =>
          tester.getRect(find.descendant(of: find.byType(NoticeBanner), matching: find.byType(Material)).first);
      Rect button(String label) =>
          tester.getRect(find.ancestor(of: find.text(label), matching: find.byType(FilledButton)));

      await openToday(tester);
      expect(banner().right - button(_finished).right, 12);
      expect(banner().bottom - button(_finished).bottom, 12);

      // At the left in Hebrew.
      await openToday(tester, settings: _settings.copyWith(language: AppLanguage.hebrew));
      expect(button('סיימתי את פרשת בראשית בשבת').left - banner().left, 12);
      expect(banner().bottom - button('סיימתי את פרשת בראשית בשבת').bottom, 12);
    });

    testWidgets('names the parsha it asks about, above the next one', (tester) async {
      await openToday(tester);
      expect(find.text(_checkIn), findsOneWidget);
      expect(find.text(_finished), findsOneWidget);
      expect(find.bySemanticsLabel('Parshat Noach'), findsOneWidget, reason: "this week's, beneath it");
      await tester.tap(find.text('Choose aliyot'));
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: find.byType(BottomSheet), matching: find.text(_checkIn)),
        findsOneWidget,
        reason: 'the sheet is titled with the same question',
      );
    });

    testWidgets('balances its question where it wraps, leaving no word alone', (tester) async {
      await openToday(tester);
      // In the test font, set in full "Shavua tov! Did you / read Bereshit on
      // / Shabbat?", and balanced "Shavua tov! Did / you read Bereshit / on
      // Shabbat?".
      final title = tester.renderObject<RenderParagraph>(
        find.descendant(of: find.byType(NoticeBanner), matching: find.text(_checkIn)),
      );
      double lineOf(int offset) => title.getOffsetForCaret(TextPosition(offset: offset), Rect.zero).dy;
      final lastLine = lineOf(_checkIn.length - 1);
      expect(lineOf(0), lessThan(lastLine), reason: 'the question wraps');
      expect(lineOf(_checkIn.lastIndexOf(' on ') + 1), lastLine, reason: 'the last line holds more than one word');
    });

    testWidgets('names both parshiyot of a week that reads them together', (tester) async {
      // Vayakhel-Pekudei 5786, read together on Shabbat 14 March 2026.
      final week = findWeekById(const ParshaSchedule(israel: false), '5786:22-23')!;
      final sunday = week.occasion.addDays(1);
      final settings = AppSettings(onboardingComplete: true, joinDate: LocalDate(2026, 3, 1));
      final progress = ProgressState(weeks: {
        '5786:22-23': WeekProgress(weekId: '5786:22-23').withAliyah(0, week.occasion.addDays(-6)),
      });
      final now = DateTime(sunday.year, sunday.month, sunday.day, 9);
      await openToday(tester, settings: settings, now: now, progress: progress);
      expect(find.text('Shavua tov! Did you read Vayakhel-Pekudei on Shabbat?'), findsOneWidget);
      expect(find.text('I finished Vayakhel-Pekudei on Shabbat'), findsOneWidget);

      await openToday(tester, settings: settings.copyWith(language: AppLanguage.hebrew), now: now, progress: progress);
      expect(find.text('שבוע טוב! קראת את פרשת ויקהל־פקודי בשבת?'), findsOneWidget);
      expect(find.text('סיימתי את פרשת ויקהל־פקודי בשבת'), findsOneWidget);
    });

    testWidgets('in Hebrew', (tester) async {
      await openToday(tester, settings: _settings.copyWith(language: AppLanguage.hebrew));
      const question = 'שבוע טוב! קראת את פרשת בראשית בשבת?';
      expect(find.text(question), findsOneWidget);
      expect(find.text('סיימתי את פרשת בראשית בשבת'), findsOneWidget);
      expect(find.text('לא הפעם'), findsOneWidget);
      await tester.tap(find.text('בחירת עליות'));
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byType(BottomSheet), matching: find.text(question)), findsOneWidget);
      // Dated in the Hebrew calendar, as the hero dates the same Shabbat.
      expect(findDotLine('תאריך הקריאה: שבת, כ״ט בתשרי'), findsOneWidget);
      expect(find.text('שינוי התאריך'), findsOneWidget);
      expect(find.text('רישום הקריאה'), findsOneWidget);
    });

    testWidgets("waits for the day after Tisha B'Av, when no greeting is given", (tester) async {
      // Sunday 3 August 2025, 9 Av 5785, the day after Shabbat Devarim, of
      // which Rishon to Revi'i were read on their days.
      final settings = _settings.copyWith(joinDate: LocalDate(2025, 7, 20));
      var devarim = WeekProgress(weekId: '5785:44');
      for (var a = 0; a < 4; a++) {
        devarim = devarim.withAliyah(a, LocalDate(2025, 7, 27).addDays(a));
      }
      final progress = ProgressState(weeks: {'5785:44': devarim});
      final en = lookupAppLocalizations(const Locale('en'));
      // Whatever is planned on the fast.
      for (final quiet in [true, false]) {
        await openToday(
          tester,
          settings: settings.copyWith(tishaBavQuiet: quiet),
          now: DateTime(2025, 8, 3, 11),
          progress: progress,
        );
        expect(find.text(en.checkInTitle('Devarim')), findsNothing, reason: 'quiet: $quiet');
        // Nor, while it waits, the rest of last week's notice.
        expect(find.text(en.openWeekTitle('Devarim')), findsNothing, reason: 'quiet: $quiet');
        expect(find.byType(NoticeBanner), findsNothing, reason: 'quiet: $quiet');
      }
      await openToday(tester, settings: settings, now: DateTime(2025, 8, 4, 9), progress: progress);
      expect(find.text(en.checkInTitle('Devarim')), findsOneWidget);
    });
  });

  group('after Simchat Torah', () {
    // 5787 outside Israel: Shemini Atzeret on Shabbat 3 October 2026, and
    // Simchat Torah, when Vezot HaBerachah is read, on Sunday 4 October.
    final joined = AppSettings(onboardingComplete: true, joinDate: LocalDate(2026, 9, 1));
    const question = 'Did you finish Vezot HaBerachah over Yom Tov?';
    // "Yom Tov" held together, so that Tov never stands alone.
    const finished = 'I finished Vezot HaBerachah on Yom\u00A0Tov';
    WeekProgress vezot(ProviderContainer c) => c.read(progressProvider).week('5786:54');

    testWidgets('asks about Vezot HaBerachah on Monday, and logs it as read on Yom Tov, on time', (tester) async {
      final c = await openToday(tester, settings: joined, now: DateTime(2026, 10, 5, 9), progress: const ProgressState());
      expect(find.text(question), findsOneWidget);
      expect(find.text(finished), findsOneWidget);
      expect(find.textContaining('Shavua tov'), findsNothing, reason: 'it follows Yom Tov, not Shabbat');
      expect(find.text('Vezot HaBerachah is still open'), findsNothing);

      await tester.tap(find.text(finished));
      await tester.pumpAndSettle();
      expect(vezot(c).isComplete, isTrue);
      expect(vezot(c).units, everyElement(everyElement(LocalDate(2026, 10, 4))), reason: 'Simchat Torah');
      expect(c.read(settingsProvider).checkInAnsweredFor, '5786:54');
      final week = c.read(streakSummaryProvider).weeks.singleWhere((w) => w.plan.weekId == '5786:54');
      expect(week.status, WeekStatus.onTime);
      expect(find.text(question), findsNothing);
    });

    testWidgets('is asked through the week, until Bereshit is read', (tester) async {
      await openToday(tester, settings: joined, now: DateTime(2026, 10, 9, 9), progress: const ProgressState());
      expect(find.text(question), findsOneWidget, reason: 'Friday');

      // No late window keeps it open; Bereshit's own check-in takes its place.
      await openToday(tester, settings: joined, now: DateTime(2026, 10, 11, 9), progress: const ProgressState());
      expect(find.text(question), findsNothing);
      expect(find.text('Vezot HaBerachah is still open'), findsNothing);
      expect(find.byType(NoticeBanner), findsOneWidget);
      expect(find.text(_checkIn), findsOneWidget);
    });

    testWidgets('logs in one sheet, on any day of Yom Tov in its week', (tester) async {
      final c = await openToday(tester, settings: joined, now: DateTime(2026, 10, 5, 9), progress: const ProgressState());
      await tester.tap(find.text('Choose aliyot'));
      await tester.pumpAndSettle();
      expect(find.descendant(of: find.byType(BottomSheet), matching: find.text(question)), findsOneWidget);
      expect(findDotLine('Read on Yom Tov, October 4'), findsOneWidget);

      // Below all seven aliyot and the haftarah.
      await tester.ensureVisible(find.text('Change date'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Change date'));
      await tester.pumpAndSettle();
      // Simchat Torah, Shemini Atzeret and the first two days of Sukkot,
      // latest first; yesterday is named as the Yom Tov it was. Each date is
      // held together but after its comma.
      final days = [
        for (final tile in tester.widgetList<ListTile>(find.widgetWithText(ListTile, 'On Yom Tov')))
          (tile.subtitle! as DotLine).parts.single.replaceAll('\u00A0', ' '),
      ];
      expect(days, ['Sunday, October 4', 'Saturday, October 3', 'Sunday, September 27', 'Saturday, September 26']);
      expect(find.widgetWithText(ListTile, 'Yesterday'), findsNothing);
      expect(find.widgetWithText(ListTile, 'On Shabbat'), findsNothing);

      await tester.tap(find.ancestor(of: findDotLine('Saturday, October\u00A03'), matching: find.byType(ListTile)));
      await tester.pumpAndSettle();
      expect(findDotLine('Read on Yom Tov, October 3'), findsOneWidget);
      await tester.ensureVisible(find.text('Log reading'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Log reading'));
      await tester.pumpAndSettle();
      expect(vezot(c).units, everyElement(everyElement(LocalDate(2026, 10, 3))), reason: 'Shemini Atzeret');
      expect(find.text('Chazak! Parshat Vezot HaBerachah is complete.'), findsOneWidget);
    });

    testWidgets('in Hebrew', (tester) async {
      await openToday(
        tester,
        settings: joined.copyWith(language: AppLanguage.hebrew),
        now: DateTime(2026, 10, 5, 9),
        progress: const ProgressState(),
      );
      expect(find.text('סיימת את פרשת וזאת הברכה ביום טוב?'), findsOneWidget);
      expect(find.text('סיימתי את פרשת וזאת הברכה ביום\u00A0טוב'), findsOneWidget);
    });

    testWidgets('balances its button’s label where large text wraps it, leaving no word alone', (tester) async {
      final handle = tester.ensureSemantics();
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      for (final (settings, label) in [
        (joined, finished),
        (joined.copyWith(language: AppLanguage.hebrew), 'סיימתי את פרשת וזאת הברכה ביום\u00A0טוב'),
      ]) {
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await pumpApp(tester, settings: settings, now: DateTime(2026, 10, 5, 9), progress: const ProgressState());
        await tester.pumpAndSettle();
        final text = find.descendant(of: find.byType(FilledButton), matching: find.text(label));
        expect(text, findsOneWidget, reason: 'the whole label, as one text');
        final paragraph = tester.renderObject<RenderParagraph>(text);
        double lineOf(int offset) => paragraph.getOffsetForCaret(TextPosition(offset: offset), Rect.zero).dy;
        final lastLine = lineOf(label.length - 1);
        expect(lineOf(0), lessThan(lastLine), reason: 'it wraps');
        // The word before the last, "Yom", is on the last line too.
        expect(lineOf(label.lastIndexOf(RegExp('[ \u00A0]')) - 1), lastLine, reason: '$label: no word alone');
        final button = find.ancestor(of: text, matching: find.byType(FilledButton));
        expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
        expect(tester.getSize(button).width, greaterThanOrEqualTo(48));
        expect(tester.getSemantics(button), matchesSemantics(label: label, isButton: true, hasTapAction: true,
            hasEnabledState: true, isEnabled: true, isFocusable: true, hasFocusAction: true));
      }
      handle.dispose();
    });

    testWidgets('is not asked of a reader who joined on Simchat Torah', (tester) async {
      await openToday(tester, now: DateTime(2026, 10, 5, 9), progress: const ProgressState());
      expect(find.text(question), findsNothing);
      expect(find.byType(NoticeBanner), findsNothing);
    });

    testWidgets('asks about Simchat Torah by name where it was no Yom Tov for the reader, and dates it plainly',
        (tester) async {
      // One day of Yom Tov, and the reading outside Israel: Yom Tov ended on
      // Shemini Atzeret, the day before.
      final c = await openToday(
        tester,
        settings: joined.copyWith(oneDayYomTov: true),
        now: DateTime(2026, 10, 5, 9),
        progress: const ProgressState(),
      );
      expect(find.text('Did you finish Vezot HaBerachah on Simchat Torah?'), findsOneWidget);
      expect(find.text(question), findsNothing);
      expect(find.text('I finished Vezot HaBerachah on Simchat Torah'), findsOneWidget);
      expect(find.text(finished), findsNothing);
      await tester.tap(find.text('Choose aliyot'));
      await tester.pumpAndSettle();
      expect(findDotLine('Read on Sunday, October\u00A04'), findsOneWidget);
      Navigator.of(tester.element(find.byType(BottomSheet))).pop();
      await tester.pumpAndSettle();

      await tester.tap(find.text('I finished Vezot HaBerachah on Simchat Torah'));
      await tester.pumpAndSettle();
      expect(vezot(c).units, everyElement(everyElement(LocalDate(2026, 10, 4))), reason: 'Simchat Torah');

      await openToday(
        tester,
        settings: joined.copyWith(oneDayYomTov: true, language: AppLanguage.hebrew),
        now: DateTime(2026, 10, 5, 9),
        progress: const ProgressState(),
      );
      expect(find.text('סיימת את פרשת וזאת הברכה בשמחת תורה?'), findsOneWidget);
      expect(find.text('סיימתי את פרשת וזאת הברכה בשמחת תורה'), findsOneWidget);
    });
  });

  group('when Simchat Torah is a Friday and Bereshit is read the next day', () {
    // 5789 outside Israel: Simchat Torah on Friday 13 October 2028, and
    // Bereshit on Shabbat 14 October. Sunday 15 October is the first reading
    // day after both.
    final joined = AppSettings(onboardingComplete: true, joinDate: LocalDate(2028, 9, 1));
    const vezotQuestion = 'Did you finish Vezot HaBerachah over Yom Tov?';
    const bereshitQuestion = 'Shavua tov! Did you read Bereshit on Shabbat?';
    final sunday = DateTime(2028, 10, 15, 9);
    String idOf(LocalDate d) {
      final week = const ParshaSchedule(israel: false).weekFor(d);
      return weekIdFor(week.portion, week.occasion);
    }

    testWidgets('asks about Vezot HaBerachah first, and then about Bereshit', (tester) async {
      final c = await openToday(tester, settings: joined, now: sunday, progress: const ProgressState());
      expect(find.text(vezotQuestion), findsOneWidget);
      expect(find.text(bereshitQuestion), findsNothing, reason: 'one question at a time');
      expect(find.byType(NoticeBanner), findsOneWidget);

      await tester.tap(find.text('I finished Vezot HaBerachah on Yom\u00A0Tov'));
      await tester.pumpAndSettle();
      final vezot = c.read(progressProvider).week(idOf(LocalDate(2028, 10, 13)));
      expect(vezot.units, everyElement(everyElement(LocalDate(2028, 10, 13))), reason: 'Simchat Torah');
      final status = c.read(streakSummaryProvider).weeks.singleWhere((w) => w.plan.weekId == vezot.weekId).status;
      expect(status, WeekStatus.onTime);
      expect(find.text(vezotQuestion), findsNothing);
      expect(find.text(bereshitQuestion), findsOneWidget);
    });

    testWidgets('asks about Vezot HaBerachah through the week, until Noach is read, once put aside asks Bereshit',
        (tester) async {
      await openToday(tester, settings: joined, now: DateTime(2028, 10, 20, 9), progress: const ProgressState());
      expect(find.text(vezotQuestion), findsOneWidget, reason: 'Friday');

      final c = await openToday(tester, settings: joined, now: sunday, progress: const ProgressState());
      await tester.tap(find.text('Not this time'));
      await tester.pumpAndSettle();
      expect(c.read(settingsProvider).checkInAnsweredFor, idOf(LocalDate(2028, 10, 13)));
      expect(find.text(bereshitQuestion), findsOneWidget);

      await openToday(tester, settings: joined, now: DateTime(2028, 10, 22, 9), progress: const ProgressState());
      expect(find.text(vezotQuestion), findsNothing, reason: 'after Noach');
    });
  });

  testWidgets('after Shabbat and the Yom Tov straight after it, asks about both', (tester) async {
    // Shabbat Bamidbar 5789, then Shavuot on Sunday and Monday: asked on
    // Tuesday 22 May 2029.
    final week = const ParshaSchedule(israel: false).weekFor(LocalDate(2029, 5, 19));
    final id = weekIdFor(week.portion, week.occasion);
    final settings = AppSettings(onboardingComplete: true, joinDate: LocalDate(2029, 5, 1));
    final progress = ProgressState(weeks: {id: WeekProgress(weekId: id).withAliyah(0, LocalDate(2029, 5, 13))});
    await openToday(tester, settings: settings, now: DateTime(2029, 5, 22, 9), progress: progress);
    const question = 'Shavua tov! Did you read Bamidbar over Shabbat and Yom Tov?';
    expect(find.text(question), findsOneWidget);
    expect(find.text('I finished Bamidbar on Shabbat'), findsOneWidget, reason: 'it was read in synagogue then');
    await tester.tap(find.text('Choose aliyot'));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(BottomSheet), matching: find.text(question)), findsOneWidget);
    expect(findDotLine('Read on Shabbat, May 19'), findsOneWidget);
    // The days it asks about: Shabbat, and both days of Shavuot after it,
    // latest first; yesterday is named as the Yom Tov it was.
    await tester.ensureVisible(find.text('Change date'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Change date'));
    await tester.pumpAndSettle();
    final days = [
      for (final tile in tester.widgetList<ListTile>(find.widgetWithText(ListTile, 'On Yom Tov')))
        (tile.subtitle! as DotLine).parts.single.replaceAll('\u00A0', ' '),
    ];
    expect(days, ['Monday, May 21', 'Sunday, May 20']);
    expect(find.widgetWithText(ListTile, 'Yesterday'), findsNothing);
    expect(find.widgetWithText(ListTile, 'On Shabbat'), findsOneWidget);
    await tester.tap(find.ancestor(of: findDotLine('Sunday, May\u00A020'), matching: find.byType(ListTile)));
    await tester.pumpAndSettle();
    expect(findDotLine('Read on Yom Tov, May 20'), findsOneWidget);

    await openToday(
      tester,
      settings: settings.copyWith(language: AppLanguage.hebrew),
      now: DateTime(2029, 5, 22, 9),
      progress: progress,
    );
    expect(find.text('שבוע טוב! קראת את פרשת במדבר בשבת וביום טוב?'), findsOneWidget);
  });

  group('a week still open within its late window', () {
    test('closes today, tomorrow, or on a day it names', () {
      final tuesday = LocalDate(2026, 10, 13);
      expect(lateDeadlineDay(tuesday, today: tuesday), 'today');
      expect(lateDeadlineDay(tuesday, today: LocalDate(2026, 10, 12)), 'tomorrow');
      expect(lateDeadlineDay(tuesday, today: LocalDate(2026, 10, 11)), 'other');
    });

    // Bereshit's window closes at the end of Tuesday 13 October, 2 Cheshvan.
    final answered = _settings.copyWith(checkInAnsweredFor: '5787:1');

    testWidgets('says so by tonight on its last day, by tomorrow night the day before, and else by its date',
        (tester) async {
      for (final (day, words) in [
        (11, 'Finish by the end of Tuesday, October 13, and it still counts.'),
        (12, 'Finish by tomorrow night and it still counts.'),
        (13, 'Finish by tonight and it still counts.'),
      ]) {
        await openToday(tester, settings: answered, now: DateTime(2026, 10, day, 9));
        expect(find.text('Bereshit is still open'), findsOneWidget);
        expect(findWords(words), findsOneWidget, reason: 'on October $day');
      }
    });

    testWidgets('in Hebrew, by the Hebrew date', (tester) async {
      final hebrew = answered.copyWith(language: AppLanguage.hebrew);
      for (final (day, words) in [
        (11, 'סיום עד סוף יום שלישי, ב׳ בחשון, עדיין נחשב.'),
        (12, 'סיום עד מחר בלילה עדיין נחשב.'),
        (13, 'סיום עד הלילה עדיין נחשב.'),
      ]) {
        await openToday(tester, settings: hebrew, now: DateTime(2026, 10, day, 9));
        expect(findWords(words), findsOneWidget, reason: 'on October $day');
      }
    });

    testWidgets('closes when the reader’s window does: at the end of Wednesday', (tester) async {
      final wednesday = answered.copyWith(lateWindow: LateWindow.wednesday);
      await openToday(tester, settings: wednesday, now: DateTime(2026, 10, 12, 9));
      expect(findWords('Finish by the end of Wednesday, October 14, and it still counts.'), findsOneWidget);
      await openToday(tester, settings: wednesday, now: DateTime(2026, 10, 14, 9));
      expect(findWords('Finish by tonight and it still counts.'), findsOneWidget);
    });

    test('closes on its last reading day, before a day of rest, as that day of rest begins', () {
      // Pesach 5788 on Tuesday 11 April 2028, the Tuesday window's last day:
      // the reading day before it, Erev Pesach, in Israel and outside it.
      for (final oneDayYomTov in [false, true]) {
        expect(lastLateReadingDay(LocalDate(2028, 4, 11), oneDayYomTov: oneDayYomTov), LocalDate(2028, 4, 10));
      }
      // Shavuot 5788 in Israel, Wednesday 31 May 2028.
      expect(lastLateReadingDay(LocalDate(2028, 5, 31), oneDayYomTov: true), LocalDate(2028, 5, 30));
      expect(lastLateReadingDay(LocalDate(2026, 10, 13), oneDayYomTov: false), LocalDate(2026, 10, 13));
      // What begins that evening.
      expect(restBeginsAfter(LocalDate(2028, 4, 10), oneDayYomTov: false), 'other');
      expect(restBeginsAfter(LocalDate(2028, 5, 30), oneDayYomTov: true), 'other');
      expect(restBeginsAfter(LocalDate(2028, 9, 20), oneDayYomTov: false), 'roshHashanah');
      // Tuesday 18 September 2029, Erev Yom Kippur 5790, the Wednesday
      // window's last reading day after Shabbat Shuva.
      expect(restBeginsAfter(LocalDate(2029, 9, 18), oneDayYomTov: false), 'yomKippur');
      expect(restBeginsAfter(LocalDate(2026, 10, 16), oneDayYomTov: false), 'shabbat');
      expect(restBeginsAfter(LocalDate(2026, 10, 13), oneDayYomTov: false), isNull);
    });

    group('where the window ends on Yom Tov', () {
      String idOf(LocalDate shabbat, {bool israel = false}) {
        final week = ParshaSchedule(israel: israel).weekFor(shabbat);
        return weekIdFor(week.portion, week.occasion);
      }

      testWidgets('says to finish before Yom Tov begins, on Erev Pesach and the day before', (tester) async {
        // Shabbat 8 April 2028, then Pesach on Tuesday, the window's last day.
        final id = idOf(LocalDate(2028, 4, 8));
        final settings =
            AppSettings(onboardingComplete: true, joinDate: LocalDate(2028, 3, 26), checkInAnsweredFor: id);
        for (final (day, words) in [
          (9, 'Finish before Yom Tov begins tomorrow evening and it still counts.'),
          (10, 'Finish before Yom Tov begins this evening and it still counts.'),
        ]) {
          await openToday(tester, settings: settings, now: DateTime(2028, 4, day, 9), progress: const ProgressState());
          expect(findWords(words), findsOneWidget, reason: 'on April $day');
          expect(find.textContaining('night'), findsNothing, reason: 'on April $day');
        }
        await openToday(
          tester,
          settings: settings.copyWith(language: AppLanguage.hebrew),
          now: DateTime(2028, 4, 10, 9),
          progress: const ProgressState(),
        );
        expect(findWords('סיום לפני כניסת החג הערב עדיין נחשב.'), findsOneWidget);
      });

      testWidgets('in Israel, before Shavuot on the Wednesday window’s last day', (tester) async {
        // Shabbat 27 May 2028, then Shavuot on Wednesday the 31st.
        final id = idOf(LocalDate(2028, 5, 27), israel: true);
        final settings = AppSettings(
          onboardingComplete: true,
          joinDate: LocalDate(2028, 5, 14),
          checkInAnsweredFor: id,
          lateWindow: LateWindow.wednesday,
        ).locatedIn(ReadingSchedule.israel);
        for (final (day, words) in [
          (28, 'Finish before Yom Tov begins on Tuesday, May 30, and it still counts.'),
          (29, 'Finish before Yom Tov begins tomorrow evening and it still counts.'),
          (30, 'Finish before Yom Tov begins this evening and it still counts.'),
        ]) {
          await openToday(tester, settings: settings, now: DateTime(2028, 5, day, 9), progress: const ProgressState());
          expect(findWords(words), findsOneWidget, reason: 'on May $day');
        }
        // With the Tuesday window, its last day is Erev Shavuot itself.
        await openToday(
          tester,
          settings: settings.copyWith(lateWindow: LateWindow.tuesday),
          now: DateTime(2028, 5, 30, 9),
          progress: const ProgressState(),
        );
        expect(findWords('Finish before Yom Tov begins this evening and it still counts.'), findsOneWidget);
        await openToday(
          tester,
          settings: settings.copyWith(language: AppLanguage.hebrew),
          now: DateTime(2028, 5, 28, 9),
          progress: const ProgressState(),
        );
        expect(findWords('סיום לפני כניסת החג ביום שלישי, ה׳ בסיון, עדיין נחשב.'), findsOneWidget);
      });
    });
  });

  group('a week still open after its late window', () {
    testWidgets('can still be finished with the next parsha, which keeps a streak going', (tester) async {
      // Wednesday of Noach, with a two-week streak before Bereshit.
      final monday = LocalDate(2026, 9, 21);
      var weeks = <String, WeekProgress>{};
      for (final (id, first) in [('5786:53', monday), ('5786:54', monday)]) {
        weeks[id] = WeekProgress(weekId: id).withAll(first);
      }
      await openToday(
        tester,
        settings: _settings.copyWith(joinDate: LocalDate(2026, 9, 1)),
        now: DateTime(2026, 10, 14, 9),
        progress: ProgressState(weeks: {...weeks, ..._bereshit().weeks}),
      );
      expect(
        findWords(
          'Finish Bereshit and Noach by Shabbat and your 2-week streak continues — '
          'you can do this once in each book of the Torah.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('says both count, with no streak to keep', (tester) async {
      await openToday(tester, now: DateTime(2026, 10, 14, 9));
      expect(
        findWords('Finish Bereshit and Noach by Shabbat and both count — you can do this once in each book of the Torah.'),
        findsOneWidget,
      );
      expect(find.textContaining('streak continues'), findsNothing);

      await openToday(tester, settings: _settings.copyWith(language: AppLanguage.hebrew), now: DateTime(2026, 10, 14, 9));
      expect(findWords('אם מסיימים את בראשית ואת נח עד שבת, שתיהן נחשבות — אפשר לעשות זאת פעם אחת בכל חומש.'), findsOneWidget);
    });
  });

  test("asks only after a Shabbat's reading, or Simchat Torah's, and only until answered", () async {
    final repo = await loadRepo();
    WeekContext previous({
      required LocalDate occasion,
      String id = '5787:1',
      WeekStatus status = WeekStatus.inProgress,
      bool israel = false,
    }) {
      final schedule = ParshaSchedule(israel: israel);
      final week = findWeekById(schedule, id)!;
      expect(week.occasion, occasion);
      return WeekContext(
        week: week,
        plan: ReadingPlanner(schedule: schedule).planFor(week),
        portion: repo.portion(week.portion),
        progress: WeekProgress(weekId: id),
        today: occasion.addDays(2),
        status: status,
        haftarah: repo.haftarahFor(week.portion, week.occasion, HaftarahNusach.ashkenazi),
        aliyahVerses: const [0, 0, 0, 0, 0, 0, 0],
      );
    }

    final bereshit = previous(occasion: LocalDate(2026, 10, 10));
    final monday = LocalDate(2026, 10, 12);
    expect(asksCheckIn(bereshit, today: monday, settings: _settings), isTrue);
    expect(asksCheckIn(bereshit, today: monday, settings: _settings.copyWith(checkInAnsweredFor: '5787:1')), isFalse);
    expect(asksCheckIn(bereshit, today: monday, settings: _settings.copyWith(checkInAnsweredFor: '5786:54')), isTrue,
        reason: 'answered for an earlier week');
    // Vezot HaBerachah is read on Simchat Torah, a Yom Tov, when nobody
    // reads from a device either: on Sunday 4 October 2026 outside Israel.
    // With no late window, the week is missed from Monday, and asked about
    // until Bereshit is read on Shabbat.
    final vezot = previous(occasion: LocalDate(2026, 10, 4), id: '5786:54', status: WeekStatus.missed);
    expect(checkInDay(vezot, settings: _settings), LocalDate(2026, 10, 5));
    for (var day = LocalDate(2026, 10, 5); day < LocalDate(2026, 10, 10); day = day.addDays(1)) {
      expect(asksCheckIn(vezot, today: day, settings: _settings), isTrue, reason: '$day');
    }
    expect(asksCheckIn(vezot, today: LocalDate(2026, 10, 11), settings: _settings), isFalse);
    expect(asksCheckIn(vezot, today: LocalDate(2026, 10, 5), settings: _settings.copyWith(checkInAnsweredFor: '5786:54')),
        isFalse);
    // In Israel, on Shabbat 3 October: from Sunday.
    final vezotIsrael = previous(occasion: LocalDate(2026, 10, 3), id: '5786:54', status: WeekStatus.missed, israel: true);
    final israeli = _settings.copyWith(readingSchedule: ReadingSchedule.israel, oneDayYomTov: true);
    expect(asksCheckIn(vezotIsrael, today: LocalDate(2026, 10, 4), settings: israeli), isTrue);
    expect(asksCheckIn(vezotIsrael, today: LocalDate(2026, 10, 9), settings: israeli), isTrue);
    expect(asksCheckIn(vezotIsrael, today: LocalDate(2026, 10, 11), settings: israeli), isFalse);
    // A week that counts neither way, begun before the reader joined or
    // paused, is not asked about.
    final transparent = previous(occasion: LocalDate(2026, 10, 4), id: '5786:54', status: WeekStatus.transparent);
    expect(asksCheckIn(transparent, today: LocalDate(2026, 10, 5), settings: _settings), isFalse);
    expect(asksCheckIn(previous(occasion: LocalDate(2026, 10, 10), status: WeekStatus.transparent), today: monday,
        settings: _settings), isFalse);
    // Nor one the streak engine doesn't judge, as before the reader joined.
    final unjudged = WeekContext(
      week: bereshit.week,
      plan: bereshit.plan,
      portion: bereshit.portion,
      progress: bereshit.progress,
      today: monday,
      status: null,
      haftarah: bereshit.haftarah,
      aliyahVerses: bereshit.aliyahVerses,
    );
    expect(asksCheckIn(unjudged, today: LocalDate(2026, 10, 11), settings: _settings), isFalse);

    // Tisha B'Av on the Sunday after Shabbat Devarim (5785), or postponed to
    // it from Shabbat (5789): the check-in, which greets the reader, waits
    // for Monday, and Today with it.
    for (final (year, shabbat) in [
      (5785, LocalDate(2025, 8, 2)),
      (5789, HebrewDate(5789, HebrewMonth.av, 9).toLocalDate()),
    ]) {
      final devarim = previous(occasion: shabbat, id: '$year:44');
      expect(devarim.week.occasion, shabbat, reason: '$year');
      final sunday = shabbat.addDays(1);
      expect(JewishHolidays.isTishaBav(sunday), isTrue, reason: '$year');
      expect(checkInDay(devarim, settings: _settings), sunday.addDays(1), reason: '$year');
      expect(asksCheckIn(devarim, today: sunday, settings: _settings), isFalse, reason: '$year');
      expect(awaitsCheckIn(devarim, today: sunday, settings: _settings), isTrue, reason: '$year');
      expect(asksCheckIn(devarim, today: sunday.addDays(1), settings: _settings), isTrue, reason: '$year');
      expect(awaitsCheckIn(devarim, today: sunday.addDays(1), settings: _settings), isFalse, reason: '$year');
      final answered = _settings.copyWith(checkInAnsweredFor: '$year:44');
      expect(awaitsCheckIn(devarim, today: sunday, settings: answered), isFalse, reason: '$year');
    }
    // On a Tuesday or a Thursday, the fast comes after it: Sunday asks.
    final devarim = previous(occasion: LocalDate(2027, 8, 7), id: '5787:44');
    expect(checkInDay(devarim, settings: _settings), LocalDate(2027, 8, 8));

    // The question names the days it asks about: Shabbat, Shabbat and the
    // Yom Tov after it, by the days the reader keeps (Shavuot 5789 on Sunday,
    // and Monday outside Israel), or Simchat Torah.
    final en = lookupAppLocalizations(const Locale('en'));
    String question(WeekContext week, {bool oneDayYomTov = false}) =>
        checkInQuestion(en, week, 'X', oneDayYomTov: oneDayYomTov);
    expect(question(bereshit), en.checkInTitle('X'));
    final bamidbar = previous(occasion: LocalDate(2029, 5, 19), id: '5789:34');
    expect(question(bamidbar), en.checkInTitleShabbatYomTov('X'));
    expect(question(bamidbar, oneDayYomTov: true), en.checkInTitleShabbatYomTov('X'));
    expect(question(vezot), en.checkInTitleVezot('X'));
    expect(question(vezotIsrael, oneDayYomTov: true), en.checkInTitleVezot('X'), reason: 'on Shabbat, but Yom Tov too');
    // Simchat Torah outside Israel is no Yom Tov for one who keeps one day.
    expect(question(vezot, oneDayYomTov: true), en.checkInTitleSimchatTorah('X'));

    // Simchat Torah on Friday 13 October 2028 outside Israel, and Bereshit
    // on the Shabbat straight after: asked from Sunday until Noach is read.
    final vezot5789 = previous(occasion: LocalDate(2028, 10, 13), id: '5788:54', status: WeekStatus.missed);
    expect(checkInDay(vezot5789, settings: _settings), LocalDate(2028, 10, 15));
    for (var day = LocalDate(2028, 10, 15); day < LocalDate(2028, 10, 21); day = day.addDays(1)) {
      expect(asksCheckIn(vezot5789, today: day, settings: _settings), isTrue, reason: '$day');
    }
    expect(asksCheckIn(vezot5789, today: LocalDate(2028, 10, 22), settings: _settings), isFalse);
    // And in Israel, on Thursday 12 October, asked on Friday alone, before
    // Bereshit; for a visitor keeping two days, from Sunday.
    final vezot5789Israel =
        previous(occasion: LocalDate(2028, 10, 12), id: '5788:54', status: WeekStatus.missed, israel: true);
    final israeli5789 = _settings.copyWith(readingSchedule: ReadingSchedule.israel, oneDayYomTov: true);
    expect(asksCheckIn(vezot5789Israel, today: LocalDate(2028, 10, 13), settings: israeli5789), isTrue);
    expect(asksCheckIn(vezot5789Israel, today: LocalDate(2028, 10, 15), settings: israeli5789), isFalse);
    final visitor = _settings.copyWith(readingSchedule: ReadingSchedule.israel, oneDayYomTov: false);
    expect(asksCheckIn(vezot5789Israel, today: LocalDate(2028, 10, 15), settings: visitor), isTrue);
    expect(asksCheckIn(vezot5789Israel, today: LocalDate(2028, 10, 20), settings: visitor), isTrue);
  });
}
