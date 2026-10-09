import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/core/calendar/parsha_schedule.dart';
import 'package:shnayim_mikra/features/parsha/week_context.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';

import '../../helpers.dart';

/// Tuesday 22 June 2027. The second day of Shavuot fell on Shabbat outside
/// Israel, so Israel is a parsha ahead: Sh'lach there, Beha'alotcha elsewhere.
final _tuesday = DateTime(2027, 6, 22, 10);

/// A visitor to Israel: Israel's reading, two days of Yom Tov.
final _visitor = AppSettings(
  onboardingComplete: true,
  joinDate: LocalDate(2027, 6, 20),
  readingSchedule: ReadingSchedule.israel,
);

const _notice = "In Israel this week: Sh'lach. Outside Israel: Beha'alotcha. Visitors from abroad usually read both; "
    "if you daven with a minyan reading Beha'alotcha, read only that one.";

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
      expect(find.text("Parshat Sh'lach"), findsOneWidget, reason: 'the week follows the reading heard');

      await tester.tap(find.widgetWithText(TextButton, "Open Beha'alotcha"));
      await tester.pumpAndSettle();
      expect(find.text("Parshat Beha'alotcha"), findsOneWidget);
      expect(find.text('Mark the whole parsha as read'), findsOneWidget, reason: "last week's portion in Israel is open");
    });

    testWidgets('an Israeli abroad sees them too', (tester) async {
      await openToday(tester, _visitor.copyWith(readingSchedule: ReadingSchedule.diaspora, oneDayYomTov: true));
      expect(find.text(_notice), findsOneWidget);
      expect(find.text("Parshat Beha'alotcha"), findsOneWidget);
      expect(find.widgetWithText(TextButton, "Open Sh'lach"), findsOneWidget);
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
      expect(find.textContaining('בארץ ישראל השבוע'), findsOneWidget);
      expect(tester.takeException(), isNull);
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

    test("names each place's portion, and the week of the other in the reader's schedule", () async {
      final visitor = await divergenceOn(_tuesday, _visitor);
      expect((visitor!.israel, visitor.diaspora), (const PortionId(37), const PortionId(36)));
      expect(visitor.other!.portion, const PortionId(36));
      expect(visitor.other!.occasion, LocalDate(2027, 6, 19), reason: "last week's reading in Israel");

      final abroad = await divergenceOn(_tuesday, _visitor.copyWith(readingSchedule: ReadingSchedule.diaspora, oneDayYomTov: true));
      expect(abroad!.other!.portion, const PortionId(37));
      expect(abroad.other!.occasion, LocalDate(2027, 7, 3), reason: "next week's reading outside Israel");
    });

    test('offers no other week when the reader\'s own week holds it', () async {
      // Outside Israel, Chukat and Balak are read together on 17 July 2027,
      // when Israel reads Balak: the two schedules meet again.
      final abroad = _visitor.copyWith(readingSchedule: ReadingSchedule.diaspora, oneDayYomTov: true);
      final d = await divergenceOn(DateTime(2027, 7, 13, 10), abroad);
      expect((d!.israel, d.diaspora), (const PortionId(40), const PortionId(39, combined: true)));
      expect(d.other, isNull);
    });
  });
}
