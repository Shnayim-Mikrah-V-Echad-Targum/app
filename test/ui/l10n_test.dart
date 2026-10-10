import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/core/calendar/hebrew_date.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/core/calendar/parsha_schedule.dart';
import 'package:shnayim_mikra/data/models/parsha.dart';
import 'package:shnayim_mikra/features/progress/domain/reading_plan.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/ui/l10n.dart';

import '../core/calendar/fixtures.dart';
import '../helpers.dart';

const _key = Key('page');

/// Pumps a page in English or Hebrew, and returns its context.
Future<BuildContext> _page(WidgetTester tester, {required bool hebrew}) async {
  await pumpThemed(tester, const SizedBox(key: _key), hebrew: hebrew);
  return tester.element(find.byKey(_key));
}

void main() {
  group('special haftarot', () {
    // Every key in the data file, and every key the calendar gives a Shabbat
    // in 2000–2100 (by every custom in 5780–5800), in Israel and outside it.
    final data = jsonDecode(File('assets/data/parshiyot.json').readAsStringSync()) as Map<String, dynamic>;
    final fixture = loadFixture('special_haftarot.json') as Map<String, dynamic>;
    final byCustom = loadFixture('special_haftarot_by_custom.json') as Map<String, dynamic>;
    final keys = {
      ...(data['specialHaftarot'] as Map<String, dynamic>).keys,
      for (final place in ['il', 'diaspora']) ...[
        ...((fixture[place] as Map<String, dynamic>)['special'] as Map<String, dynamic>).values.cast<String>(),
        for (final nusach in HaftarahNusach.values)
          ...((byCustom[place] as Map<String, dynamic>)[nusach.name] as Map<String, dynamic>).values.cast<String>(),
      ],
    };

    test('each has a name in Hebrew and in English', () {
      expect(keys, hasLength(greaterThan(20)));
      expect(Names.specialHaftarotEn.keys.toSet(), Names.specialHaftarotHe.keys.toSet());
      for (final key in keys) {
        expect(Names.specialHaftarotHe, contains(key));
        expect(Names.specialHaftarotEn, contains(key));
      }
    });

    test("the English names don't read like the data's keys", () {
      for (final name in Names.specialHaftarotEn.values) {
        expect(name, isNot(matches(RegExp(r'\(on |Day \d|occurring|following|3rd|Shuva\b'))), reason: name);
      }
    });

    testWidgets('are named in the UI language', (tester) async {
      var names = Names(await _page(tester, hebrew: false));
      expect(names.specialHaftarah('Pinchas occurring after 17 Tammuz'), 'First haftarah of the Three Weeks');
      expect(names.specialHaftarah('Chanukah Day 8 (on Shabbat)'), 'Second Shabbat of Chanukah');
      expect(names.specialHaftarah('Shabbat Zachor'), 'Shabbat Zachor');
      expect(names.specialHaftarah('Not a key'), 'Not a key', reason: 'an unknown key is shown as it is');

      names = Names(await _page(tester, hebrew: true));
      expect(names.specialHaftarah('Pinchas occurring after 17 Tammuz'), 'ראשונה דפורענותא (״דברי ירמיהו״)');
      expect(names.specialHaftarah('Masei on Shabbat Rosh Chodesh'), 'מסעי בראש חודש אב');
      expect(names.specialHaftarah('Matot-Masei on Shabbat Rosh Chodesh'), 'מטות־מסעי בראש חודש אב');
      expect(names.specialHaftarah('Chanukah Day 8 (on Shabbat)'), 'שבת חנוכה השנייה');
    });
  });

  group('Hebrew dates', () {
    LocalDate on(int year, int month, int day) => HebrewDate(year, month, day).toLocalDate();

    testWidgets('are transliterated in English, with the year', (tester) async {
      final names = Names(await _page(tester, hebrew: false));
      expect(names.hebrewDate(LocalDate(2026, 10, 9)), '28 Tishrei 5787');
      expect(names.hebrewDayMonth(LocalDate(2026, 10, 9)), '28 Tishrei');
      expect(names.hebrewDate(on(5787, HebrewMonth.adar2, 14)), '14 Adar II 5787');
    });

    testWidgets('take ב before the month in Hebrew, as a date is written', (tester) async {
      final names = Names(await _page(tester, hebrew: true));
      expect(names.hebrewDate(LocalDate(2026, 10, 9)), 'כ״ח בתשרי תשפ״ז');
      expect(names.hebrewDayMonth(LocalDate(2026, 10, 9)), 'כ״ח בתשרי');
      expect(names.hebrewDayMonth(on(5787, HebrewMonth.nisan, 1)), 'א׳ בניסן');
      expect(names.hebrewDayMonth(on(5787, HebrewMonth.shevat, 15)), 'ט״ו בשבט');
      // 5787 is a leap year, and 5786 is not.
      expect(names.hebrewDate(on(5787, HebrewMonth.adar, 14)), 'י״ד באדר א׳ תשפ״ז');
      expect(names.hebrewDate(on(5787, HebrewMonth.adar2, 14)), 'י״ד באדר ב׳ תשפ״ז');
      expect(names.hebrewDate(on(5786, HebrewMonth.adar, 14)), 'י״ד באדר תשפ״ו');
    });
  });

  group('the day a portion is read', () {
    const diaspora = ParshaSchedule(israel: false);
    const israel = ParshaSchedule(israel: true);
    // Bereshit, read on Shabbat 10 October 2026, 29 Tishrei 5787.
    final bereshit = diaspora.weekFor(LocalDate(2026, 10, 9));
    // Vezot HaBerachah, read on Simchat Torah: Sunday 4 October 2026
    // (23 Tishrei) in the Diaspora, and Shabbat 3 October (22 Tishrei) in
    // Israel, where it is still Simchat Torah rather than Shabbat.
    final vezot = diaspora.weekFor(LocalDate(2026, 10, 1));
    final vezotIsrael = israel.weekFor(LocalDate(2026, 10, 1));

    test('is the Shabbat of Bereshit, and Simchat Torah for Vezot HaBerachah', () {
      expect(bereshit.portion, const PortionId(1));
      expect(bereshit.occasion, LocalDate(2026, 10, 10));
      expect(vezot.portion.isVezotHaberakhah, isTrue);
      expect(vezot.occasion, LocalDate(2026, 10, 4));
      expect(vezotIsrael.portion.isVezotHaberakhah, isTrue);
      expect(vezotIsrael.occasion, LocalDate(2026, 10, 3));
    });

    testWidgets('is a Gregorian date in English', (tester) async {
      final names = Names(await _page(tester, hebrew: false));
      expect(names.readOnLabel(bereshit), 'Read on Shabbat, October 10');
      expect(names.readOnLabel(vezot), 'Read on Simchat Torah, Sunday, October 4');
    });

    testWidgets('is a Hebrew date in Hebrew, without the year', (tester) async {
      final names = Names(await _page(tester, hebrew: true));
      expect(names.readOnLabel(bereshit), 'נקראת בשבת, כ״ט בתשרי');
      expect(names.readOnLabel(vezot), 'נקראת בשמחת תורה, יום ראשון, כ״ג בתשרי');
      expect(names.readOnLabel(vezotIsrael), 'נקראת בשמחת תורה, יום שבת, כ״ב בתשרי');
    });
  });

  testWidgets('a book of the Torah is headed by its name: Genesis, and ספר בראשית', (tester) async {
    var context = await _page(tester, hebrew: false);
    expect(context.l10n.bookOfTorah(Names(context).book(kTorahBooks.first)), 'Genesis');

    context = await _page(tester, hebrew: true);
    expect(context.l10n.bookOfTorah(Names(context).book(kTorahBooks.first)), 'ספר בראשית');
  });

  testWidgets('the second reading is named as the setting says', (tester) async {
    var context = await _page(tester, hebrew: false);
    var names = Names(context);
    expect(
      [for (final s in SecondReading.values) names.secondReading(s)],
      ['Targum', 'Rashi', 'Onkelos and Rashi', 'Rashi'],
    );
    expect(
      context.l10n.versesRead('1,234', names.secondReading(SecondReading.rashi)),
      '1,234 verses read twice with Rashi',
    );

    expect(
      context.l10n.methodVerseDesc(names.secondReading(SecondReading.onkelosAndRashi)),
      'Each verse twice, then its Onkelos and Rashi',
    );

    context = await _page(tester, hebrew: true);
    names = Names(context);
    final l = context.l10n;
    expect(
      [for (final s in SecondReading.values) names.secondReading(s)],
      ['תרגום', 'רש״י', 'אונקלוס ורש״י', 'רש״י'],
    );
    // The ו joins the name directly, as Hebrew writes it.
    expect(l.versesRead('1,234', names.secondReading(SecondReading.rashi)), '1,234 פסוקים בשניים מקרא ורש״י');
    expect(l.versesRead('5', names.secondReading(SecondReading.onkelos)), '5 פסוקים בשניים מקרא ותרגום');
    expect(
      l.firstAliyahDone('בראשית א, א–ב, ג', names.secondReading(SecondReading.onkelos)),
      'יישר כוח! העלייה הראשונה שלך הושלמה — בראשית א, א–ב, ג, שניים מקרא ותרגום.',
    );
    expect(
      l.firstAliyahDone('בראשית א, א–ב, ג', names.secondReading(SecondReading.onkelosAndRashi)),
      'יישר כוח! העלייה הראשונה שלך הושלמה — בראשית א, א–ב, ג, שניים מקרא ואונקלוס ורש״י.',
    );
    expect(l.methodVerseDesc(names.secondReading(SecondReading.rashi)), 'כל פסוק פעמיים, ואז רש״י');
    expect(l.methodAliyahDesc(names.secondReading(SecondReading.onkelos)), 'כל העלייה פעמיים, ואז תרגום');
  });

  testWidgets('the streak explainer gives the late window the reader chose', (tester) async {
    final l = (await _page(tester, hebrew: false)).l10n;
    expect(
      l.streakExplainer(LateWindow.tuesday.name),
      'Your parsha streak counts portions finished before Shabbat — or by Tuesday night, which still counts. '
      'Shabbat and Yom Tov never break a streak.',
    );
    expect(l.streakExplainer(LateWindow.wednesday.name), contains('— or by the end of Wednesday, which still counts.'));
    expect(
      l.streakExplainer(LateWindow.none.name),
      'Your parsha streak counts portions finished before Shabbat. Shabbat and Yom Tov never break a streak.',
    );

    final he = (await _page(tester, hebrew: true)).l10n;
    expect(he.streakExplainer(LateWindow.wednesday.name), contains('או עד סוף יום רביעי'));
    expect(he.streakExplainer(LateWindow.none.name), isNot(contains('רביעי')));
  });
}
