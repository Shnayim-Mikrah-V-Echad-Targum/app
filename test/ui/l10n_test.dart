import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/core/calendar/hebrew_date.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/core/calendar/parsha_schedule.dart';
import 'package:shnayim_mikra/data/models/parsha.dart';
import 'package:shnayim_mikra/data/models/verse_ref.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
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
      // The calendar's keys have straight apostrophes; the names, curly ones.
      expect(
        names.specialHaftarah("Re'eh on Shabbat Rosh Chodesh (and Sunday)"),
        'Re’eh on Rosh Chodesh Elul, with verses for Sunday’s Rosh Chodesh',
      );
      expect(names.specialHaftarah('Ki Teitzei with 3rd Haftarah of Consolation'), 'Ki Tetze, with Aniyah So’arah');
      expect(names.specialHaftarah("Not a key's"), 'Not a key’s');
      expect(
        names.specialHaftarah('Shabbat Rosh Chodesh (and Sunday)'),
        'Shabbat Rosh Chodesh, with verses for Sunday’s Rosh Chodesh',
      );

      names = Names(await _page(tester, hebrew: true));
      expect(names.specialHaftarah('Pinchas occurring after 17 Tammuz'), 'ראשונה דפורענותא (״דברי ירמיהו״)');
      expect(names.specialHaftarah('Masei on Shabbat Rosh Chodesh'), 'מסעי בראש חודש אב');
      expect(names.specialHaftarah('Matot-Masei on Shabbat Rosh Chodesh'), 'מטות־מסעי בראש חודש אב');
      expect(names.specialHaftarah('Chanukah Day 8 (on Shabbat)'), 'שבת חנוכה השנייה');
      expect(
        names.specialHaftarah("Re'eh on Shabbat Rosh Chodesh (and Sunday)"),
        'ראה בשבת ראש חודש אלול, ומוסיפים פסוקים מ״מחר חודש״',
      );
      expect(names.specialHaftarah('Shabbat Rosh Chodesh (and Sunday)'), 'שבת ראש חודש, ומוסיפים פסוקים מ״מחר חודש״');
    });

    test('have no straight apostrophe in English', () {
      for (final name in Names.specialHaftarotEn.values) {
        expect(name, isNot(contains("'")), reason: name);
      }
    });
  });

  testWidgets("a parsha's English name sets its apostrophe curly, and the data keeps it straight", (tester) async {
    final repo = (await tester.runAsync(loadRepo))!;
    final haazinu = repo.byNumber(53), behaalotcha = repo.byNumber(36);
    var names = Names(await _page(tester, hebrew: false));
    expect(names.portion(haazinu, ashkenazi: false), 'Ha’azinu');
    expect(names.portion(behaalotcha, ashkenazi: false), 'Beha’alotcha');
    expect(names.portion(behaalotcha, ashkenazi: true), 'Beha’aloscha');

    names = Names(await _page(tester, hebrew: true));
    expect(names.portion(haazinu, ashkenazi: false), 'האזינו');
    expect(names.portionAlt(haazinu, ashkenazi: false), 'Ha’azinu');

    // The weekly threads' titles are built from it, as the server's are.
    expect(haazinu.nameEn, "Ha'azinu");
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

  testWidgets('a date in a sentence wraps after its weekday or not at all', (tester) async {
    final day = LocalDate(2026, 10, 11);
    var names = Names(await _page(tester, hebrew: false));
    expect(names.dateInText(day), 'Sunday, October\u00A011');
    expect(names.dateInText(day).replaceAll('\u00A0', ' '), names.dateLong(day));

    names = Names(await _page(tester, hebrew: true));
    expect(names.dateInText(day), 'יום\u00A0ראשון, 11\u00A0באוקטובר');
    expect(names.dateInText(day).replaceAll('\u00A0', ' '), names.dateLong(day));
  });

  group('a day of the practice', () {
    // Shabbat Bereshit, 10 October 2026 (29 Tishrei 5787), and the Sunday
    // after it (30 Tishrei).
    final shabbat = LocalDate(2026, 10, 10);
    final sunday = LocalDate(2026, 10, 11);
    final roshHashanah5788 = HebrewDate(5788, HebrewMonth.tishrei, 1).toLocalDate();

    testWidgets('is the Gregorian date in English, as before', (tester) async {
      final names = Names(await _page(tester, hebrew: false));
      expect(names.practiceDate(sunday), 'Sunday, October\u00A011');
      expect(names.practiceDate(sunday), names.dateInText(sunday));
      expect(names.practiceDayMonth(shabbat), 'October 10');
      expect(names.practiceDateShort(shabbat), 'Oct 10');
      // The year only for a day of another year than today's.
      expect(names.practiceDateShort(shabbat, today: LocalDate(2026, 12, 31)), 'Oct 10');
      expect(names.practiceDateShort(shabbat, today: LocalDate(2027, 1, 1)), 'Oct 10, 2026');
    });

    testWidgets('is the Hebrew date in Hebrew, without the year, held together but after its comma', (tester) async {
      final names = Names(await _page(tester, hebrew: true));
      expect(names.practiceDate(sunday), 'יום\u00A0ראשון, ל׳\u00A0בתשרי');
      expect(names.practiceDate(shabbat).replaceAll('\u00A0', ' '), 'יום שבת, כ״ט בתשרי');
      // Adar I's name is two words, held to its day too.
      expect(
        names.practiceDate(HebrewDate(5787, HebrewMonth.adar, 14).toLocalDate()).split(', ').last,
        'י״ד\u00A0באדר\u00A0א׳',
      );
      expect(names.practiceDayMonth(shabbat), 'כ״ט בתשרי');
      expect(names.practiceDateShort(shabbat), 'כ״ט בתשרי');
      // The year only in another Hebrew year, not another Gregorian one.
      expect(names.practiceDateShort(shabbat, today: LocalDate(2027, 1, 1)), 'כ״ט בתשרי');
      expect(names.practiceDateShort(shabbat, today: roshHashanah5788.addDays(-1)), 'כ״ט בתשרי');
      expect(names.practiceDateShort(shabbat, today: roshHashanah5788), 'כ״ט בתשרי תשפ״ז');
    });
  });

  testWidgets("a book's parshiyot are counted beside its name: 12 parshiyot, and 12 פרשות", (tester) async {
    var context = await _page(tester, hebrew: false);
    expect(context.l10n.browseBookParshiyot(12), '12 parshiyot');
    expect(context.l10n.browseBookParshiyot(1), '1 parsha');

    context = await _page(tester, hebrew: true);
    expect(context.l10n.browseBookParshiyot(12), '12 פרשות');
    expect(context.l10n.browseBookParshiyot(1), 'פרשה אחת');
  });

  testWidgets('aliyot to read are spanned when three or more run on, and named otherwise', (tester) async {
    var names = Names(await _page(tester, hebrew: false));
    // A no-break space holds the dash to the name before it: no line starts
    // with the dash.
    expect(names.aliyotSpan([2, 3, 4, 5, 6]), 'Shlishi\u00A0– Shevi’i');
    expect(names.aliyotSpan([0, 1, 2]), 'Rishon\u00A0– Shlishi');
    expect(names.aliyotSpan([4, 5]), 'Chamishi and Shishi');
    expect(names.aliyotSpan([3]), 'Revi’i');
    // Not a run: Revi'i was read ahead.
    expect(names.aliyotSpan([2, 4, 5]), 'Shlishi, Chamishi and Shishi');
    expect(names.aliyotSpan([0, 1, 2, 3, 4, 5, 6]), 'The whole parsha');

    names = Names(await _page(tester, hebrew: true));
    expect(names.aliyotSpan([2, 3, 4, 5, 6]), 'שלישי\u00A0– שביעי');
    expect(names.aliyotSpan([0, 1, 2, 3, 4, 5, 6]), 'כל הפרשה');
  });

  group('a range of verses', () {
    testWidgets('closes up its dash in English, within a chapter or across chapters', (tester) async {
      final names = Names(await _page(tester, hebrew: false));
      expect(names.range('Genesis', 2, 20, 2, 25), 'Genesis 2:20–25');
      expect(names.range('Genesis', 1, 1, 6, 8), 'Genesis 1:1–6:8');
      expect(names.verseRange(7, 17, 8, 14), '7:17–8:14');
    });

    // "א, א–ו, ח" would read as chapter 1, verses 1–6 and 8. No-break
    // spaces hold each chapter to its verse, and the dash to the verse
    // before it: a line breaks only after the book or the dash.
    testWidgets('spaces its dash in Hebrew across chapters, held to the verse before it', (tester) async {
      final names = Names(await _page(tester, hebrew: true));
      expect(names.range('Genesis', 2, 20, 2, 25), 'בראשית ב,\u00A0כ–כה');
      expect(names.verseRange(2, 20, 2, 21), 'ב,\u00A0כ–כא');
      expect(names.range('Genesis', 1, 1, 6, 8), 'בראשית א,\u00A0א\u00A0– ו,\u00A0ח');
      expect(names.verseRange(7, 17, 8, 14), 'ז,\u00A0יז\u00A0– ח,\u00A0יד');
      expect(names.range('Isaiah', 42, 5, 43, 10), 'ישעיהו מב,\u00A0ה\u00A0– מג,\u00A0י');
    });

    // As a haftarah adds the first and last verses of another.
    testWidgets('of one verse is the verse alone', (tester) async {
      var names = Names(await _page(tester, hebrew: false));
      expect(names.range('I Samuel', 20, 18, 20, 18), 'I Samuel 20:18');
      expect(names.range('I Samuel', 20, 18, 20, 18), names.reference('I Samuel', 20, 18));
      names = Names(await _page(tester, hebrew: true));
      expect(names.range('I Samuel', 20, 18, 20, 18), 'שמואל א כ,\u00A0יח');
      expect(names.range('I Samuel', 20, 18, 20, 18), names.reference('I Samuel', 20, 18));
    });
  });

  // "I" never ends a line with "Samuel" on the next, nor "·" starts one,
  // nor does a line end inside a closed range ("45:16– / 46:18").
  testWidgets(
      "a haftarah's passages hold a book's name of two words, a closed range, and each dot to the passage before it",
      (tester) async {
    const parts = [
      HaftarahPart('Isaiah', VerseRef(66, 1), VerseRef(66, 24)),
      HaftarahPart('I Samuel', VerseRef(20, 18), VerseRef(20, 18)),
      HaftarahPart('I Samuel', VerseRef(20, 42), VerseRef(20, 42)),
    ];
    const ezekiel = HaftarahPart('Ezekiel', VerseRef(45, 16), VerseRef(46, 18));
    var names = Names(await _page(tester, hebrew: false));
    expect(names.passage(parts[1]), 'I\u00A0Samuel 20:18');
    expect(names.passage(ezekiel), 'Ezekiel 45:16–\u206046:18');
    expect(names.haftarah(parts), 'Isaiah 66:1–\u206024\u00A0· I\u00A0Samuel 20:18\u00A0· I\u00A0Samuel 20:42');
    names = Names(await _page(tester, hebrew: true));
    expect(
      names.haftarah(parts),
      'ישעיהו סו,\u00A0א–\u2060כד\u00A0· שמואל\u00A0א כ,\u00A0יח\u00A0· שמואל\u00A0א כ,\u00A0מב',
    );
    // Across chapters, the spaced dash may still end a line (§4.6).
    expect(names.passage(ezekiel), 'יחזקאל מה,\u00A0טז\u00A0– מו,\u00A0יח');
  });

  // As a range holds them, so that a long reference at large text breaks
  // after the book, never between "כח," and "י".
  testWidgets('one verse holds its chapter to its verse, in Hebrew as "28:10" does in English', (tester) async {
    expect(Names(await _page(tester, hebrew: false)).reference('Genesis', 28, 10), 'Genesis 28:10');
    expect(Names(await _page(tester, hebrew: true)).reference('Genesis', 28, 10), 'בראשית כח,\u00A0י');
  });

  testWidgets('a reading of an aliyah is named as the rings\' legend names it', (tester) async {
    var names = Names(await _page(tester, hebrew: false));
    expect(
      [for (final p in ReadingPass.values) names.readingPass(p)],
      ['First reading', 'Second reading', 'Targum'],
    );
    expect(names.readingPass(ReadingPass.targum, rashi: true), 'Rashi');
    names = Names(await _page(tester, hebrew: true));
    expect(names.readingPass(ReadingPass.targum), 'תרגום');
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
      l.firstAliyahDone('בראשית א,\u00A0א\u00A0– ב,\u00A0ג', names.secondReading(SecondReading.onkelos)),
      'יישר כוח! העלייה הראשונה שלך הושלמה — בראשית א,\u00A0א\u00A0– ב,\u00A0ג, שניים מקרא ותרגום.',
    );
    expect(
      l.firstAliyahDone('בראשית א,\u00A0א\u00A0– ב,\u00A0ג', names.secondReading(SecondReading.onkelosAndRashi)),
      'יישר כוח! העלייה הראשונה שלך הושלמה — בראשית א,\u00A0א\u00A0– ב,\u00A0ג, שניים מקרא ואונקלוס ורש״י.',
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
