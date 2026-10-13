import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';

import '../../helpers.dart';

/// Hoshana Rabbah 5787, Friday 2 October 2026, in the week of Vezot
/// HaBerachah. Simchat Torah is on Shabbat in Israel, and on Sunday outside it.
final _hoshanaRabbah = DateTime(2026, 10, 2, 10);

final _israel = AppSettings(
  onboardingComplete: true,
  joinDate: LocalDate(2026, 9, 20),
  readingSchedule: ReadingSchedule.israel,
  oneDayYomTov: true,
);

final _diaspora = _israel.copyWith(readingSchedule: ReadingSchedule.diaspora, oneDayYomTov: false);

void main() {
  Future<ProviderContainer> openToday(WidgetTester tester, AppSettings settings, DateTime now) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await pumpApp(tester, settings: settings, now: now);
    await tester.pumpAndSettle();
    return c;
  }

  group('the countdown', () {
    testWidgets('on Hoshana Rabbah in Israel is to Simchat Torah, not Shabbat', (tester) async {
      await openToday(tester, _israel, _hoshanaRabbah);
      expect(find.textContaining('Vezot'), findsWidgets);
      expect(find.text('Simchat Torah is tomorrow'), findsOneWidget);
      expect(find.textContaining('Shabbat is'), findsNothing, reason: 'the portion is read on Simchat Torah');
    });

    testWidgets('outside Israel gives way on that Friday to Shabbat, which begins this evening', (tester) async {
      // Simchat Torah is on Sunday, two days off; reading stops tonight.
      await openToday(tester, _diaspora, _hoshanaRabbah);
      expect(find.text('Shabbat begins this evening'), findsOneWidget);
      expect(find.text('Simchat Torah in 2 days'), findsNothing);
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
    // The Haftarah row's detail line, under its reference.
    expect(find.text('First haftarah of the Three Weeks'), findsOneWidget);
  });

  group('dates', () {
    // Wednesday 7 October 2026, 26 Tishrei 5787, in the week of Bereshit,
    // read on Shabbat the 10th, 29 Tishrei.
    final wednesday = DateTime(2026, 10, 7, 10);

    // The running head and the hero's line each set their parts on one line
    // between middle dots where they fit, and on lines of their own where
    // they don't, a part too long for a line keeping its clauses whole with
    // no-break spaces: so each part is found as part of a text, its spaces
    // either kind.
    testWidgets('in English, are Gregorian, with the Hebrew date beside them', (tester) async {
      final c = await openToday(tester, _diaspora, wednesday);
      expect(find.textContaining(wordsRegExp(r'^Wednesday, October 7( · 26 Tishrei 5787)?$')), findsOneWidget);
      expect(find.textContaining(wordsRegExp(r'^(Wednesday, October 7 · )?26 Tishrei 5787$')), findsOneWidget);
      expect(findWords('Read on Shabbat, October 10'), findsOneWidget);

      // The week page: when it is read, then the Hebrew date.
      c.read(routerProvider).go('/week/5787:1');
      await tester.pumpAndSettle();
      expect(find.textContaining(wordsRegExp(r'^Read on Shabbat, October 10( · 29 Tishrei 5787)?$')), findsOneWidget);
      expect(find.textContaining(wordsRegExp(r'^(Read on Shabbat, October 10 · )?29 Tishrei 5787$')), findsOneWidget);
      expect(find.textContaining(wordsRegExp(r'^(Genesis 1:1–6:8 · )?146 verses$')), findsOneWidget);
    });

    testWidgets('in Hebrew, take ב before the month, and the week page gives the Gregorian date', (tester) async {
      final c = await openToday(tester, _diaspora.copyWith(language: AppLanguage.hebrew), wednesday);
      // The Hebrew date first, in the Hebrew UI.
      expect(find.textContaining(wordsRegExp(r'^יום רביעי, כ״ו בתשרי תשפ״ז( · 7 באוקטובר)?$')), findsOneWidget);
      expect(find.textContaining(wordsRegExp(r'^(יום רביעי, כ״ו בתשרי תשפ״ז · )?7 באוקטובר$')), findsOneWidget);
      expect(findWords('נקראת בשבת, כ״ט בתשרי'), findsOneWidget);

      c.read(routerProvider).go('/week/5787:1');
      await tester.pumpAndSettle();
      expect(find.textContaining(wordsRegExp(r'^נקראת בשבת, כ״ט בתשרי( · 10 באוקטובר 2026)?$')), findsOneWidget);
      expect(find.textContaining(wordsRegExp(r'^(נקראת בשבת, כ״ט בתשרי · )?10 באוקטובר 2026$')), findsOneWidget);
      expect(find.textContaining(wordsRegExp(r'^(בראשית א, א – ו, ח · )?146 פסוקים$')), findsOneWidget);
    });
  });

  testWidgets('reading from a printed Chumash can be logged', (tester) async {
    await openToday(tester, _diaspora, DateTime(2026, 10, 13, 10));
    expect(find.widgetWithText(TextButton, 'I read it in a Chumash'), findsOneWidget);
  });
}
