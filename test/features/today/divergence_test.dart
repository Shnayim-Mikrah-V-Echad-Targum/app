import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shnayim_mikrah/app/providers.dart';
import 'package:shnayim_mikrah/app/router.dart';
import 'package:shnayim_mikrah/core/calendar/local_date.dart';
import 'package:shnayim_mikrah/core/calendar/parsha_schedule.dart';
import 'package:shnayim_mikrah/features/parsha/week_context.dart';
import 'package:shnayim_mikrah/features/parsha/week_overview_screen.dart';
import 'package:shnayim_mikrah/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikrah/features/settings/app_settings.dart';
import 'package:shnayim_mikrah/ui/widgets/common.dart' show NoticeBanner;

import '../../helpers.dart';

/// Tuesday 22 June 2027. The second day of Shavuot fell on Shabbat outside
/// Israel, so Israel is a parsha ahead: Shelach there, Beha'alotcha elsewhere.
final _tuesday = DateTime(2027, 6, 22, 10);

/// A visitor to Israel: Israel's reading, two days of Yom Tov.
final _visitor = AppSettings(
  onboardingComplete: true,
  joinDate: LocalDate(2027, 6, 20),
  readingSchedule: ReadingSchedule.israel,
);

/// An Israeli abroad: the reading outside Israel, one day of Yom Tov.
final _abroad = _visitor.copyWith(readingSchedule: ReadingSchedule.diaspora, oneDayYomTov: true);

const _notice = 'In Israel this week: Shelach. Outside Israel: Beha’alotcha. Visitors from abroad usually read both. '
    'If you daven with a minyan reading Beha’alotcha, read only that one, and set the reading you’ll hear to '
    'Outside Israel in Settings.';

const _aheadNotice = 'In Israel this week: Shelach. Outside Israel: Beha’alotcha. Israel is a parsha ahead, so you’ll '
    'read Shelach next week.';

void main() {
  group('on Today', () {
    Future<ProviderContainer> openToday(WidgetTester tester, AppSettings settings, {DateTime? now}) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = await pumpApp(tester, settings: settings, now: now ?? _tuesday);
      await tester.pumpAndSettle();
      return c;
    }

    testWidgets('a visitor sees both portions, and can open the other', (tester) async {
      await openToday(tester, _visitor);
      expect(find.text(_notice), findsOneWidget);
      // The title page's name, under its Hebrew.
      expect(find.text('Shelach'), findsOneWidget, reason: 'the week follows the reading heard');

      await tester.tap(find.widgetWithText(TextButton, 'Open Beha’alotcha'));
      await tester.pumpAndSettle();
      // Beha'alotcha's page (its app bar's title, revealed on scrolling, is
      // left out where the test font makes it too wide).
      expect(tester.widget<WeekOverview>(find.byType(WeekOverview)).ctx.portion.id, const PortionId(36));
      expect(find.text('Mark the whole parsha as read'), findsOneWidget, reason: "last week's portion in Israel is open");
    });

    testWidgets('a visitor can change the reading they hear, in Settings', (tester) async {
      final c = await openToday(tester, _visitor);
      final change = find.widgetWithText(TextButton, 'Change the reading');
      expect(change, findsOneWidget);
      await tester.tap(change);
      await tester.pumpAndSettle();
      expect(c.read(routerProvider).state.uri.path, '/settings/reading');
      expect(find.text('Which Torah reading will you hear this Shabbat?'), findsOneWidget);
      await tester.tap(find.byTooltip('Back'));
      await tester.pumpAndSettle();
      expect(c.read(routerProvider).state.uri.path, '/today');
    });

    testWidgets('an Israeli abroad is told that Israel is a parsha ahead, with nothing to open', (tester) async {
      await openToday(tester, _abroad);
      expect(find.text(_aheadNotice), findsOneWidget);
      expect(find.text('Beha’alotcha'), findsOneWidget);
      // Shelach is next week's reading for them, not open yet.
      expect(find.textContaining('Open '), findsNothing);
      expect(find.text('Change the reading'), findsNothing);
    });

    Finder dismiss() => find.descendant(of: find.byType(NoticeBanner), matching: find.byTooltip('Dismiss'));

    testWidgets('can be put away for the week, and is told again the next while the two differ', (tester) async {
      final c = await openToday(tester, _visitor);
      await tester.tap(dismiss());
      await tester.pumpAndSettle();
      expect(find.textContaining('In Israel this week'), findsNothing);
      final settings = c.read(settingsProvider);
      expect(settings.divergenceDismissedFor, '5787:37', reason: "this week's, Shelach's in Israel");
      // The hero follows the reading heard, still.
      expect(find.text('Shelach'), findsOneWidget);

      // Later that week, it stays away.
      await openToday(tester, settings, now: DateTime(2027, 6, 25, 10));
      expect(find.textContaining('In Israel this week'), findsNothing);

      // The next week Israel is still a parsha ahead, and says so.
      await openToday(tester, settings, now: DateTime(2027, 6, 29, 10));
      expect(find.textContaining('In Israel this week: Korach. Outside Israel: Shelach.'), findsOneWidget);
    });

    testWidgets('an Israeli abroad can put it away too', (tester) async {
      final c = await openToday(tester, _abroad);
      await tester.tap(dismiss());
      await tester.pumpAndSettle();
      expect(find.text(_aheadNotice), findsNothing);
      expect(c.read(settingsProvider).divergenceDismissedFor, '5787:36', reason: "Beha’alotcha's, outside Israel");
    });

    for (final theme in [AppThemeMode.light, AppThemeMode.dark, AppThemeMode.highContrastLight, AppThemeMode.highContrastDark]) {
      testWidgets('the notice meets the accessibility guidelines in the ${theme.name} theme', (tester) async {
        final handle = tester.ensureSemantics();
        await openToday(tester, _visitor.copyWith(theme: theme));
        expect(find.text(_notice), findsOneWidget);
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        handle.dispose();
      });
    }

    testWidgets('the notice fits at 200% text, and in Hebrew', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await openToday(tester, _visitor);
      expect(find.text(_notice), findsOneWidget);
      expect(tester.takeException(), isNull);

      await openToday(tester, _visitor.copyWith(language: AppLanguage.hebrew));
      expect(find.textContaining('בארץ ישראל קוראים השבוע את פרשת שלח'), findsOneWidget);
      expect(tester.takeException(), isNull);

      await openToday(tester, _abroad.copyWith(language: AppLanguage.hebrew));
      expect(find.textContaining('ארץ ישראל מקדימה בפרשה אחת'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('keeps a name of two parshiyot whole, in the notice and on its button', (tester) async {
      // Tuesday 24 April 2029: outside Israel Acharei Mot and Kedoshim are
      // read together, a week after Israel read them apart.
      final visitor = _visitor.copyWith(joinDate: LocalDate(2029, 4, 22));
      for (final (hebrew, name) in [(false, 'Mot-\u2060Kedoshim'), (true, 'מות־\u2060קדשים')]) {
        for (final width in [360.0, 412.0, 600.0, 900.0, 1366.0]) {
          tester.view.physicalSize = Size(width, 1400);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await pumpApp(
            tester,
            settings: hebrew ? visitor.copyWith(language: AppLanguage.hebrew) : visitor,
            now: DateTime(2029, 4, 24, 10),
          );
          await tester.pumpAndSettle();
          final texts = [
            for (final e in find.textContaining(name).evaluate())
              if (e.renderObject is RenderParagraph) e.renderObject! as RenderParagraph,
          ];
          expect(texts, hasLength(2), reason: 'the notice and its Open button, at $width');
          for (final paragraph in texts) {
            final text = paragraph.text.toPlainText();
            final at = text.indexOf(name);
            double lineOf(int offset) => paragraph.getOffsetForCaret(TextPosition(offset: offset), Rect.zero).dy;
            expect(lineOf(at + name.length - 1), lineOf(at), reason: '"$text" at $width: the name whole');
          }
        }
      }
    });

    testWidgets('no notice for someone who keeps the customs of one place', (tester) async {
      await openToday(tester, _visitor.locatedIn(ReadingSchedule.israel));
      expect(find.textContaining('In Israel this week'), findsNothing);
      await openToday(tester, _visitor.locatedIn(ReadingSchedule.diaspora));
      expect(find.textContaining('In Israel this week'), findsNothing);
    });

    testWidgets('no notice in a week when both read the same portion', (tester) async {
      await openToday(tester, _visitor, now: DateTime(2027, 8, 3, 10));
      expect(find.textContaining('In Israel this week'), findsNothing);
    });
  });

  group('readingDivergenceProvider', () {
    Future<ReadingDivergence?> divergenceOn(DateTime now, AppSettings settings) async {
      SharedPreferences.setMockInitialValues({SettingsController.storageKey: jsonEncode(settings.toJson())});
      final prefs = await SharedPreferences.getInstance();
      final clock = TodayController.now;
      TodayController.now = () => now;
      TodayController.autoRollover = false;
      final container = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
      addTearDown(() {
        container.dispose();
        TodayController.now = clock;
      });
      return container.read(readingDivergenceProvider);
    }

    test("names each place's portion, and for a visitor, the home portion's week in Israel", () async {
      final visitor = await divergenceOn(_tuesday, _visitor);
      expect((visitor!.israel, visitor.diaspora), (const PortionId(37), const PortionId(36)));
      expect(visitor.hearsIsrael, isTrue);
      expect(visitor.previous!.portion, const PortionId(36));
      expect(visitor.previous!.occasion, LocalDate(2027, 6, 19), reason: "last week's reading in Israel");

      final abroad = await divergenceOn(_tuesday, _abroad);
      expect((abroad!.israel, abroad.diaspora), (const PortionId(37), const PortionId(36)));
      expect(abroad.hearsIsrael, isFalse);
      expect(abroad.previous, isNull, reason: "Israel's portion is next week's, which hasn't opened");
    });

    test('says nothing to an Israeli abroad in a week that holds both portions', () async {
      // Outside Israel, Chukat and Balak are read together on 17 July 2027,
      // when Israel reads Balak: the two schedules meet again.
      expect(await divergenceOn(DateTime(2027, 7, 13, 10), _abroad), isNull);
      final visitor = await divergenceOn(DateTime(2027, 7, 13, 10), _visitor);
      expect((visitor!.israel, visitor.diaspora), (const PortionId(40), const PortionId(39, combined: true)));
      expect(visitor.previous!.portion, const PortionId(39), reason: 'Chukat, read in Israel last week');
    });

    test("says nothing on the Diaspora's Simchat Torah, when Israel has begun Bereshit", () async {
      // Sunday 4 October 2026, 23 Tishrei 5787: an ordinary day for someone
      // who keeps one day of Yom Tov.
      final simchatTorah = DateTime(2026, 10, 4, 10);
      expect(await divergenceOn(simchatTorah, _abroad), isNull);
      expect(await divergenceOn(simchatTorah, _visitor), isNull);
    });
  });

  test('Israel is never more than a parsha ahead, so the notices hold every year', () {
    const israel = ParshaSchedule(israel: true);
    const diaspora = ParshaSchedule(israel: false);
    var divergentWeeks = 0;
    for (var day = LocalDate(2025, 9, 23); day < LocalDate(2040, 9, 1); day = day.addDays(1)) {
      final (i, d) = (israel.weekFor(day), diaspora.weekFor(day));
      if (i.portion == d.portion || i.portion.isVezotHaberakhah || d.portion.isVezotHaberakhah) continue;
      divergentWeeks++;
      // A visitor's home portion is last week's in Israel...
      final home = findWeekById(israel, weekIdFor(d.portion, d.occasion))!;
      expect(home.occasion == i.occasion || home.occasion == israel.previousWeek(i).occasion, isTrue, reason: '$day');
      // ...and Israel's portion is this week's or next week's outside it.
      final ahead = findWeekById(diaspora, weekIdFor(i.portion, i.occasion))!;
      expect(ahead.occasion == d.occasion || ahead.occasion == diaspora.nextWeek(d).occasion, isTrue, reason: '$day');
    }
    expect(divergentWeeks, greaterThan(100));
  });
}
