import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../core/calendar/hebrew_date.dart';
import '../core/calendar/local_date.dart';
import '../core/text/hebrew_text.dart';
import '../data/models/parsha.dart';
import '../features/settings/app_settings.dart';
import '../l10n/app_localizations.dart';

/// [s] as a left-to-right isolate, between U+2066 and U+2069
/// (docs/DESIGN_SYSTEM.md §4.6). Inside Hebrew text a Latin run, such as a
/// reference ("3:22–4:18"), a range of years, an email, a URL or
/// "@hebcal/leyning", then keeps its own order, and the punctuation either
/// side of it stays with the Hebrew sentence.
String ltr(String s) => '\u2066$s\u2069';

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  bool get isHebrewUi => Localizations.localeOf(this).languageCode == 'he';

  String get localeName => Localizations.localeOf(this).toLanguageTag();

  /// [s], a Latin run put into a sentence in the UI's language: isolated by
  /// [ltr] in the Hebrew UI, and as it is in the English UI, where it already
  /// runs that way.
  String ltrRun(String s) => isHebrewUi ? ltr(s) : s;
}

/// Localized names and dates.
class Names {
  Names(this.context);

  final BuildContext context;

  AppLocalizations get _l => context.l10n;
  bool get _he => context.isHebrewUi;

  String aliyah(int index) => switch (index) {
        0 => _l.aliyah1,
        1 => _l.aliyah2,
        2 => _l.aliyah3,
        3 => _l.aliyah4,
        4 => _l.aliyah5,
        5 => _l.aliyah6,
        _ => _l.aliyah7,
      };

  /// "Revi'i" or "Chamishi and Shishi".
  String aliyot(List<int> indices) {
    if (indices.isEmpty) return '';
    if (indices.length == 7) return _he ? 'כל הפרשה' : 'The whole parsha';
    final names = indices.map(aliyah).toList();
    if (names.length == 1) return names.single;
    return _l.andJoiner(names.sublist(0, names.length - 1).join(', '), names.last);
  }

  /// What the reader reads after the Torah's two readings, as [reading]
  /// says: "Targum", "Rashi" or "Onkelos and Rashi".
  String secondReading(SecondReading reading) => switch (reading) {
        SecondReading.onkelos => _l.passTargum,
        SecondReading.rashi || SecondReading.rashiEnglish => _l.passRashi,
        SecondReading.onkelosAndRashi => _l.secondBoth,
      };

  /// The parsha name in the UI language. In Hebrew, the Hebrew name without
  /// vowels; in English, the transliteration in the chosen style.
  String portion(PortionInfo p, {required bool ashkenazi}) =>
      _he ? HebrewText.stripNikud(p.nameHe) : p.displayName(ashkenazi: ashkenazi);

  /// Secondary name: the other language.
  String portionAlt(PortionInfo p, {required bool ashkenazi}) =>
      _he ? p.displayName(ashkenazi: ashkenazi) : HebrewText.stripNikud(p.nameHe);

  String book(String english) {
    final i = kTorahBooks.indexOf(english);
    if (i >= 0) return _he ? kTorahBooksHe[i] : english;
    return _he ? (_prophetsHe[english] ?? english) : english;
  }

  /// "Genesis 7:17–8:14" / "בראשית ז, יז – ח, יד".
  String range(String bookName, int c1, int v1, int c2, int v2) {
    if (_he) {
      final g = HebrewText.gematria;
      final start = '${g(c1, punctuate: false)}, ${g(v1, punctuate: false)}';
      final end = c1 == c2 ? g(v2, punctuate: false) : '${g(c2, punctuate: false)}, ${g(v2, punctuate: false)}';
      return '${book(bookName)} $start–$end';
    }
    final end = c1 == c2 ? '$v2' : '$c2:$v2';
    return '${book(bookName)} $c1:$v1–$end';
  }

  String verseNumber(int n) => _he ? HebrewText.gematria(n, punctuate: false) : '$n';

  String weekday(LocalDate d) => DateFormat.EEEE(context.localeName).format(d.toDateTime());

  String weekdayShort(LocalDate d) {
    if (_he) return const ['א׳', 'ב׳', 'ג׳', 'ד׳', 'ה׳', 'ו׳', 'ש׳'][d.weekday];
    return DateFormat.E(context.localeName).format(d.toDateTime());
  }

  /// "Sunday, 11 October".
  String dateLong(LocalDate d) => DateFormat.MMMMEEEEd(context.localeName).format(d.toDateTime());

  /// "11 October" (no weekday).
  String dateMonthDay(LocalDate d) => DateFormat.MMMMd(context.localeName).format(d.toDateTime());

  /// "11 Oct".
  String dateShort(LocalDate d) => DateFormat.MMMd(context.localeName).format(d.toDateTime());

  /// "11 October 2026".
  String dateWithYear(LocalDate d) => DateFormat.yMMMMd(context.localeName).format(d.toDateTime());

  String time(int minutesSinceMidnight) => DateFormat.jm(context.localeName)
      .format(DateTime(2000, 1, 1, minutesSinceMidnight ~/ 60, minutesSinceMidnight % 60));

  /// "28 Tishrei 5787" / "כ״ח תשרי תשפ״ז".
  String hebrewDate(LocalDate d) {
    final h = HebrewDate.fromLocalDate(d);
    final month = hebrewMonth(h.year, h.month);
    if (_he) {
      return '${HebrewText.gematria(h.day)} $month ${HebrewText.gematria(h.year % 1000)}';
    }
    return '${h.day} $month ${h.year}';
  }

  String hebrewMonth(int year, int month) {
    final leap = HebrewDate.isLeapYear(year);
    if (_he) {
      if (month == HebrewMonth.adar) return leap ? 'אדר א׳' : 'אדר';
      if (month == HebrewMonth.adar2) return 'אדר ב׳';
      return const ['', 'ניסן', 'אייר', 'סיון', 'תמוז', 'אב', 'אלול', 'תשרי', 'חשון', 'כסלו', 'טבת', 'שבט'][month];
    }
    if (month == HebrewMonth.adar) return leap ? 'Adar I' : 'Adar';
    if (month == HebrewMonth.adar2) return 'Adar II';
    return const ['', 'Nisan', 'Iyar', 'Sivan', 'Tammuz', 'Av', 'Elul', 'Tishrei', 'Cheshvan', 'Kislev', 'Tevet', 'Shevat'][month];
  }

  /// Human name for a special haftarah key from the data file.
  String specialHaftarah(String key) => (_he ? specialHaftarotHe[key] : specialHaftarotEn[key]) ?? key;

  static const _prophetsHe = {
    'Joshua': 'יהושע', 'Judges': 'שופטים', 'I Samuel': 'שמואל א', 'II Samuel': 'שמואל ב',
    'I Kings': 'מלכים א', 'II Kings': 'מלכים ב', 'Isaiah': 'ישעיהו', 'Jeremiah': 'ירמיהו',
    'Ezekiel': 'יחזקאל', 'Hosea': 'הושע', 'Joel': 'יואל', 'Amos': 'עמוס', 'Obadiah': 'עובדיה',
    'Jonah': 'יונה', 'Micah': 'מיכה', 'Nahum': 'נחום', 'Habakkuk': 'חבקוק', 'Zephaniah': 'צפניה',
    'Haggai': 'חגי', 'Zechariah': 'זכריה', 'Malachi': 'מלאכי',
  };

  /// The names of the special haftarot (the keys of `specialHaftarot` in
  /// assets/data/parshiyot.json) in Hebrew, and in [specialHaftarotEn] in
  /// English.
  @visibleForTesting
  static const specialHaftarotHe = {
    'Shabbat Rosh Chodesh': 'שבת ראש חודש',
    'Shabbat Machar Chodesh': 'שבת מחר חודש',
    'Shabbat Shekalim': 'שבת שקלים',
    'Shabbat Shekalim (on Rosh Chodesh)': 'שבת שקלים (בראש חודש)',
    'Shabbat Zachor': 'שבת זכור',
    'Shabbat Parah': 'שבת פרה',
    'Shabbat HaChodesh': 'שבת החודש',
    'Shabbat HaChodesh (on Rosh Chodesh)': 'שבת החודש (בראש חודש)',
    'Shabbat HaGadol': 'שבת הגדול',
    "Shabbat Shuva (with Ha'azinu)": 'שבת שובה',
    'Shabbat Shuva (with Vayeilech)': 'שבת שובה',
    'Pinchas occurring after 17 Tammuz': 'פנחס אחרי י״ז בתמוז',
    'Shabbat Rosh Chodesh Chanukah': 'שבת ראש חודש וחנוכה',
    'Chanukah Day 1 (on Shabbat)': 'שבת חנוכה',
    'Chanukah Day 2 (on Shabbat)': 'שבת חנוכה',
    'Chanukah Day 3 (on Shabbat)': 'שבת חנוכה',
    'Chanukah Day 4 (on Shabbat)': 'שבת חנוכה',
    'Chanukah Day 7 (on Shabbat)': 'שבת חנוכה',
    'Chanukah Day 8 (on Shabbat)': 'שבת חנוכה השנייה',
    'Kedoshim following Special Shabbat': 'קדושים (הפטרת אחרי מות)',
    'Masei on Shabbat Rosh Chodesh': 'מסעי בשבת ראש חודש',
    'Matot-Masei on Shabbat Rosh Chodesh': 'מטות־מסעי בשבת ראש חודש',
    'Ki Teitzei with 3rd Haftarah of Consolation': 'כי תצא עם ״עניה סוערה״',
  };

  @visibleForTesting
  static const specialHaftarotEn = {
    'Shabbat Rosh Chodesh': 'Shabbat Rosh Chodesh',
    'Shabbat Machar Chodesh': 'Shabbat Machar Chodesh',
    'Shabbat Shekalim': 'Shabbat Shekalim',
    'Shabbat Shekalim (on Rosh Chodesh)': 'Shabbat Shekalim and Rosh Chodesh',
    'Shabbat Zachor': 'Shabbat Zachor',
    'Shabbat Parah': 'Shabbat Parah',
    'Shabbat HaChodesh': 'Shabbat HaChodesh',
    'Shabbat HaChodesh (on Rosh Chodesh)': 'Shabbat HaChodesh and Rosh Chodesh',
    'Shabbat HaGadol': 'Shabbat HaGadol',
    "Shabbat Shuva (with Ha'azinu)": 'Shabbat Shuvah',
    'Shabbat Shuva (with Vayeilech)': 'Shabbat Shuvah',
    'Pinchas occurring after 17 Tammuz': 'First haftarah of the Three Weeks',
    'Shabbat Rosh Chodesh Chanukah': 'Shabbat Chanukah and Rosh Chodesh',
    'Chanukah Day 1 (on Shabbat)': 'Shabbat Chanukah',
    'Chanukah Day 2 (on Shabbat)': 'Shabbat Chanukah',
    'Chanukah Day 3 (on Shabbat)': 'Shabbat Chanukah',
    'Chanukah Day 4 (on Shabbat)': 'Shabbat Chanukah',
    'Chanukah Day 7 (on Shabbat)': 'Shabbat Chanukah',
    'Chanukah Day 8 (on Shabbat)': 'Second Shabbat of Chanukah',
    'Kedoshim following Special Shabbat': 'Kedoshim (haftarah of Acharei Mot)',
    'Masei on Shabbat Rosh Chodesh': 'Masei on Rosh Chodesh Av',
    'Matot-Masei on Shabbat Rosh Chodesh': 'Matot-Masei on Rosh Chodesh Av',
    'Ki Teitzei with 3rd Haftarah of Consolation': "Ki Teitzei, with Aniyah So'arah",
  };
}
