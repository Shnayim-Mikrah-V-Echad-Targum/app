import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/features/progress/domain/reading_plan.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';

import '../../helpers.dart';

/// Tuesday of Noach 5787. Bereshit, the week before, was read on 10 October.
final _now = DateTime(2026, 10, 13, 10);
final _today = LocalDate(2026, 10, 13);
final _joined = LocalDate(2026, 9, 1);
const _applies = 'Applies from this week on';

void main() {
  late ProviderContainer c;

  Future<void> openReadingSettings(WidgetTester tester, {bool haftarahRequired = false}) async {
    c = await pumpApp(
      tester,
      settings: AppSettings(onboardingComplete: true, joinDate: _joined, haftarahRequired: haftarahRequired),
      now: _now,
    );
    c.read(routerProvider).go('/settings/reading');
    await tester.pumpAndSettle();
  }

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text));
    await tester.pumpAndSettle();
    await tester.tap(find.text(text));
    await tester.pumpAndSettle();
  }

  testWidgets('changing the plan says it applies from this week on, and records it from today', (tester) async {
    await openReadingSettings(tester);
    expect(find.text(_applies), findsNothing);

    await tapText(tester, 'All on Friday');

    expect(find.text(_applies), findsOneWidget);
    final s = c.read(settingsProvider);
    expect(s.settingsAt(_today).plan, ReadingPlanType.erevShabbat);
    expect(s.settingsAt(_today.addDays(-1)).plan, ReadingPlanType.aliyahPerDay);
  });

  testWidgets('the reading heard and the days of Yom Tov kept are set apart, and saved', (tester) async {
    await openReadingSettings(tester);
    expect(find.text('Which Torah reading will you hear this Shabbat?'), findsOneWidget);
    expect(find.text('How many days of Yom Tov do you keep?'), findsOneWidget);
    expect(find.text('Visitors usually keep their home custom. Ask your rav.'), findsOneWidget);

    // A visitor from abroad: Israel's reading, two days of Yom Tov.
    await tapText(tester, 'In Israel');
    var s = c.read(settingsProvider);
    expect((s.readingSchedule, s.oneDayYomTov), (ReadingSchedule.israel, false));

    await tapText(tester, 'One, as in Israel');
    s = c.read(settingsProvider);
    expect((s.readingSchedule, s.oneDayYomTov), (ReadingSchedule.israel, true));

    await tapText(tester, 'Outside Israel');
    final prefs = await SharedPreferences.getInstance();
    final saved = AppSettings.fromJson(
      jsonDecode(prefs.getString(SettingsController.storageKey)!) as Map<String, dynamic>,
    );
    expect((saved.readingSchedule, saved.oneDayYomTov), (ReadingSchedule.diaspora, true));
    expect(find.text(_applies), findsNothing);
  });

  testWidgets('changes that don\'t affect how weeks are planned or judged say nothing', (tester) async {
    await openReadingSettings(tester);
    await tapText(tester, 'Section by section');
    await tapText(tester, 'Haftarah');
    expect(c.read(settingsProvider).method, ReadingMethod.sectionBySection);
    expect(c.read(settingsProvider).haftarahEnabled, isFalse);
    expect(find.text(_applies), findsNothing, reason: 'the haftarah did not count toward completion');
    expect(c.read(settingsProvider).planHistory, isEmpty);
  });

  testWidgets('a past week that counted the haftarah still shows it after the haftarah is turned off', (tester) async {
    await openReadingSettings(tester, haftarahRequired: true);
    await tapText(tester, 'Haftarah');
    expect(find.text(_applies), findsOneWidget);

    c.read(routerProvider).go('/week/5787:1');
    await tester.pumpAndSettle();
    expect(find.text('Haftarah'), findsOneWidget, reason: 'Bereshit still needs its haftarah');

    c.read(routerProvider).go('/week/5787:2');
    await tester.pumpAndSettle();
    expect(find.text('Haftarah'), findsNothing, reason: 'Noach does not');
  });
}
