import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';

import '../../helpers.dart';

/// Hoshana Rabbah 5787, Friday 2 October 2026, in the week of Vezot
/// HaBerakhah. Simchat Torah is on Shabbat in Israel, and on Sunday outside it.
final _hoshanaRabbah = DateTime(2026, 10, 2, 10);

final _israel = AppSettings(
  onboardingComplete: true,
  joinDate: LocalDate(2026, 9, 20),
  readingSchedule: ReadingSchedule.israel,
  oneDayYomTov: true,
);

final _diaspora = _israel.copyWith(readingSchedule: ReadingSchedule.diaspora, oneDayYomTov: false);

void main() {
  Future<void> openToday(WidgetTester tester, AppSettings settings, DateTime now) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpApp(tester, settings: settings, now: now);
    await tester.pumpAndSettle();
  }

  group('the countdown', () {
    testWidgets('on Hoshana Rabbah in Israel is to Simchat Torah, not Shabbat', (tester) async {
      await openToday(tester, _israel, _hoshanaRabbah);
      expect(find.textContaining('Vezot'), findsWidgets);
      expect(find.text('Simchat Torah is tomorrow'), findsOneWidget);
      expect(find.textContaining('Shabbat is'), findsNothing, reason: 'the portion is read on Simchat Torah');
    });

    testWidgets('outside Israel is to Sunday, two days after Hoshana Rabbah', (tester) async {
      await openToday(tester, _diaspora, _hoshanaRabbah);
      expect(find.text('Simchat Torah in 2 days'), findsOneWidget);
      expect(find.textContaining('Shabbat in'), findsNothing, reason: 'Shabbat is tomorrow, and the reading is not');
    });

    testWidgets('is to Simchat Torah in Hebrew too', (tester) async {
      await openToday(tester, _israel.copyWith(language: AppLanguage.hebrew), _hoshanaRabbah);
      expect(find.text('שמחת תורה מחר'), findsOneWidget);
    });

    testWidgets('in any other week is to Shabbat', (tester) async {
      // Tuesday of Noach 5787, read on Shabbat 17 October.
      await openToday(tester, _diaspora, DateTime(2026, 10, 13, 10));
      expect(find.text('Shabbat in 4 days'), findsOneWidget);
      expect(find.textContaining('Simchat Torah in'), findsNothing);
    });
  });

  testWidgets('a special haftarah is named in words, not by its key in the data', (tester) async {
    // Tuesday of Pinchas 5787, read on 24 July 2027, after 17 Tammuz.
    await openToday(tester, _diaspora.copyWith(joinDate: LocalDate(2027, 7, 18)), DateTime(2027, 7, 20, 10));
    expect(find.text('Special haftarah: First haftarah of the Three Weeks'), findsOneWidget);
  });

  testWidgets('reading from a printed Chumash can be logged', (tester) async {
    await openToday(tester, _diaspora, DateTime(2026, 10, 13, 10));
    expect(find.widgetWithText(OutlinedButton, 'I read it in a Chumash'), findsOneWidget);
  });
}
