import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../core/calendar/hebrew_date.dart';
import '../core/calendar/local_date.dart';
import '../core/calendar/parsha_schedule.dart';
import '../core/text/hebrew_text.dart';
import '../data/models/parsha.dart';
import '../features/progress/domain/progress_models.dart';
import '../features/settings/app_settings.dart';
import '../l10n/app_localizations.dart';

/// [s] as a left-to-right isolate, between U+2066 and U+2069
/// (docs/DESIGN_SYSTEM.md §4.6). Inside Hebrew text a Latin run, such as a
/// reference ("3:22–4:18"), a range of years, an email, a URL or
/// "@hebcal/leyning", then keeps its own order, and the punctuation either
/// side of it stays with the Hebrew sentence.
String ltr(String s) => '\u2066$s\u2069';

/// [items] as a list in a sentence in [l]'s language: "Monday", "Monday
/// and Tuesday", "Monday, Tuesday and Wednesday".
String joinWithAnd(AppLocalizations l, List<String> items) {
  if (items.isEmpty) return '';
  if (items.length == 1) return items.single;
  return l.andJoiner(items.sublist(0, items.length - 1).join(', '), items.last);
}

/// A no-break space: no line breaks between the words either side of it.
const _nbsp = '\u00A0';

extension L10nContext on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  bool get isHebrewUi => Localizations.localeOf(this).languageCode == 'he';

  String get localeName => Localizations.localeOf(this).toLanguageTag();

  /// [s], a Latin run put into a sentence in the UI's language: isolated by
  /// [ltr] in the Hebrew UI, and as it is in the English UI, where it already
  /// runs that way.
  String ltrRun(String s) => isHebrewUi ? ltr(s) : s;
}

/// The aliyot by name, and lists in a sentence, in [l]'s words. [Names] gives
/// them so on a page, and the home-screen widget's timeline, which has no
/// page to take its words from, gives them the same way.
class AliyahNames {
  const AliyahNames(this.l);

  final AppLocalizations l;

  String aliyah(int index) => switch (index) {
        0 => l.aliyah1,
        1 => l.aliyah2,
        2 => l.aliyah3,
        3 => l.aliyah4,
        4 => l.aliyah5,
        5 => l.aliyah6,
        _ => l.aliyah7,
      };

  /// A run of aliyot, from [first] to [last]: "Shlishi – Shevi'i". A
  /// no-break space holds the dash to the name before it, so that a line
  /// may break only after the dash, and none starts with it.
  String aliyahRange(int first, int last) => '${aliyah(first)}$_nbsp– ${aliyah(last)}';

  /// The aliyot to read, by name: one alone, a run of three or more from its
  /// first to its last ([aliyahRange]), or else each of them ([aliyot]).
  String aliyotSpan(List<int> indices) {
    if (indices.length > 2 && indices.length < kAliyot && indices.last - indices.first == indices.length - 1) {
      return aliyahRange(indices.first, indices.last);
    }
    return aliyot(indices);
  }

  /// "Revi'i", "Chamishi and Shishi", or all seven: "The whole parsha".
  String aliyot(List<int> indices) {
    if (indices.length == kAliyot) return l.aliyotWholeParsha;
    return andList(indices.map(aliyah).toList());
  }

  /// [items] as a list in a sentence ([joinWithAnd]).
  String andList(List<String> items) => joinWithAnd(l, items);
}

/// Localized names and dates.
class Names {
  Names(this.context);

  final BuildContext context;

  AppLocalizations get _l => context.l10n;
  bool get _he => context.isHebrewUi;
  AliyahNames get _aliyot => AliyahNames(_l);

  String aliyah(int index) => _aliyot.aliyah(index);

  /// The aliyah's own Hebrew name, the same in either UI, as the Hebrew UI
  /// names it: "רביעי".
  static String aliyahHebrew(int index) => AliyahNames(lookupAppLocalizations(const Locale('he'))).aliyah(index);

  /// See [AliyahNames.aliyahRange].
  String aliyahRange(int first, int last) => _aliyot.aliyahRange(first, last);

  /// See [AliyahNames.aliyotSpan].
  String aliyotSpan(List<int> indices) => _aliyot.aliyotSpan(indices);

  /// See [AliyahNames.aliyot].
  String aliyot(List<int> indices) => _aliyot.aliyot(indices);

  /// See [AliyahNames.andList].
  String andList(List<String> items) => _aliyot.andList(items);

  /// What the reader reads after the Torah's two readings, as [reading]
  /// says: "Targum", "Rashi" or "Onkelos and Rashi".
  String secondReading(SecondReading reading) => switch (reading) {
        SecondReading.onkelos => _l.passTargum,
        SecondReading.rashi || SecondReading.rashiEnglish => _l.passRashi,
        SecondReading.onkelosAndRashi => _l.secondBoth,
      };

  /// The name of reading [pass] of an aliyah, as the rings' legend gives it:
  /// "First reading", "Second reading", and then "Targum", or "Rashi" for a
  /// reader whose second reading is Rashi alone ([rashi]).
  String readingPass(ReadingPass pass, {bool rashi = false}) => switch (pass) {
        ReadingPass.mikrah1 => _l.passMikrah1,
        ReadingPass.mikrah2 => _l.passMikrah2,
        ReadingPass.targum => rashi ? _l.passRashi : _l.passTargum,
      };

  /// The routine [anchor] as it completes "After I…": "finish Shacharit".
  String habitAnchor(HabitAnchor anchor) => switch (anchor) {
        HabitAnchor.shacharit => _l.anchorShacharit,
        HabitAnchor.breakfast => _l.anchorBreakfast,
        HabitAnchor.commute => _l.anchorCommute,
        HabitAnchor.dinner => _l.anchorDinner,
        HabitAnchor.bed => _l.anchorBed,
      };

  /// The parsha name in the UI language. In Hebrew, the Hebrew name without
  /// vowels; in English, the transliteration in the chosen style.
  String portion(PortionInfo p, {required bool ashkenazi}) =>
      _he ? HebrewText.stripNikud(p.nameHe) : p.displayName(ashkenazi: ashkenazi);

  /// The parsha's Hebrew name with its vowels, without cantillation:
  /// "בְּרֵאשִׁית", as a title sets it.
  String portionPointed(PortionInfo p) => HebrewText.forDisplay(p.nameHe, nikud: true, teamim: false);

  /// Secondary name: the other language.
  String portionAlt(PortionInfo p, {required bool ashkenazi}) =>
      _he ? p.displayName(ashkenazi: ashkenazi) : HebrewText.stripNikud(p.nameHe);

  String book(String english) {
    final i = kTorahBooks.indexOf(english);
    if (i >= 0) return _he ? kTorahBooksHe[i] : english;
    return _he ? (_prophetsHe[english] ?? english) : english;
  }

  /// "Genesis 7:17–8:14" / "בראשית ז, יז – ח, יד".
  String range(String bookName, int c1, int v1, int c2, int v2) => '${book(bookName)} ${verseRange(c1, v1, c2, v2)}';

  /// One passage of a haftarah: "I Samuel 20:18–42" / "שמואל א כ, יח–מב", a
  /// book's name of two words held on one line, and a closed range held
  /// together by a word joiner after its dash, so that a line breaks after
  /// the book ("Ezekiel / 45:16–46:18", never "Ezekiel 45:16– / 46:18"), or
  /// after the spaced dash of a Hebrew range across chapters.
  String passage(HaftarahPart p) {
    final name = book(p.book).replaceAll(' ', _nbsp);
    final verses = verseRange(p.start.chapter, p.start.verse, p.end.chapter, p.end.verse);
    return '$name ${verses.replaceAll(_closedDash, '–\u2060')}';
  }

  /// The dash of a closed range ("45:16–46:18", "יח–מב"), between two
  /// characters that are not spaces.
  static final _closedDash = RegExp(r'(?<=\S)–(?=[^\s\u2060])');

  /// A haftarah's passages: "Isaiah 66:1–24 · I Samuel 20:18 · I Samuel
  /// 20:42". A line may end after a dot, but never start with one.
  String haftarah(Haftarah parts) => parts.map(passage).join('$_nbsp· ');

  /// [range] without the book, for a range in a book named nearby:
  /// "7:17–8:14" / "ז, יז – ח, יד".
  ///
  /// In Hebrew a range across chapters spaces its dash, held to the verse
  /// before it as [AliyahNames.aliyahRange] holds it: closed up, "א, א–ו, ח"
  /// would read as chapter 1, verses 1–6 and 8. A range within a chapter
  /// stays closed: "ב, כ–כא". A chapter and its verse are held together, as
  /// "1:1" is, so that a line breaks only after the book or the dash. A
  /// range of one verse, as a haftarah adds, is the verse alone: "20:18", as
  /// [reference] names it.
  String verseRange(int c1, int v1, int c2, int v2) {
    final one = c1 == c2 && v1 == v2;
    if (_he) {
      String g(int n) => HebrewText.gematria(n, punctuate: false);
      final start = '${g(c1)},$_nbsp${g(v1)}';
      if (one) return start;
      if (c1 == c2) return '$start–${g(v2)}';
      return '$start$_nbsp– ${g(c2)},$_nbsp${g(v2)}';
    }
    if (one) return '$c1:$v1';
    final end = c1 == c2 ? '$v2' : '$c2:$v2';
    return '$c1:$v1–$end';
  }

  /// One verse: "Genesis 28:10" / "בראשית כח, י", its chapter held to its
  /// verse by a no-break space, as in [verseRange] and as "28:10" holds
  /// together, so that a line never ends between them.
  String reference(String bookName, int chapter, int verse) {
    if (_he) {
      final g = HebrewText.gematria;
      return '${book(bookName)} ${g(chapter, punctuate: false)},$_nbsp${g(verse, punctuate: false)}';
    }
    return '${book(bookName)} $chapter:$verse';
  }

  String verseNumber(int n) => _he ? HebrewText.gematria(n, punctuate: false) : '$n';

  /// A Hebrew year: "5787", or in the Hebrew UI "תשפ״ז".
  String hebrewYear(int year) => _he ? HebrewText.gematria(year % 1000) : '$year';

  String weekday(LocalDate d) => DateFormat.EEEE(context.localeName).format(d.toDateTime());

  String weekdayShort(LocalDate d) {
    if (_he) return const ['א׳', 'ב׳', 'ג׳', 'ד׳', 'ה׳', 'ו׳', 'ש׳'][d.weekday];
    return DateFormat.E(context.localeName).format(d.toDateTime());
  }

  /// "Sunday, 11 October".
  String dateLong(LocalDate d) => DateFormat.MMMMEEEEd(context.localeName).format(d.toDateTime());

  /// [dateLong] for a sentence: it wraps after its weekday's comma or not at
  /// all, never between a day and its month ("October / 11", "11 /
  /// באוקטובר").
  String dateInText(LocalDate d) => _heldTogether(dateLong(d));

  /// [date]'s words held together by no-break spaces, but after a comma.
  static String _heldTogether(String date) =>
      [for (final part in date.split(', ')) part.replaceAll(' ', _nbsp)].join(', ');

  /// "11 October" (no weekday).
  String dateMonthDay(LocalDate d) => DateFormat.MMMMd(context.localeName).format(d.toDateTime());

  /// "11 Oct".
  String dateShort(LocalDate d) => DateFormat.MMMd(context.localeName).format(d.toDateTime());

  /// "11 October 2026".
  String dateWithYear(LocalDate d) => DateFormat.yMMMMd(context.localeName).format(d.toDateTime());

  /// "Oct 11, 2026".
  String dateShortWithYear(LocalDate d) => DateFormat.yMMMd(context.localeName).format(d.toDateTime());

  String time(int minutesSinceMidnight) => DateFormat.jm(context.localeName)
      .format(DateTime(2000, 1, 1, minutesSinceMidnight ~/ 60, minutesSinceMidnight % 60));

  /// "28 Tishrei 5787" / "כ״ח בתשרי תשפ״ז".
  String hebrewDate(LocalDate d) {
    final h = HebrewDate.fromLocalDate(d);
    return '${_hebrewDayMonth(h)} ${_he ? HebrewText.gematria(h.year % 1000) : h.year}';
  }

  /// "28 Tishrei" / "כ״ח בתשרי": [hebrewDate] without the year.
  String hebrewDayMonth(LocalDate d) => _hebrewDayMonth(HebrewDate.fromLocalDate(d));

  /// In Hebrew the month takes ב, as a date is written and said: כ״ח בתשרי.
  String _hebrewDayMonth(HebrewDate h) {
    final month = hebrewMonth(h.year, h.month);
    return _he ? '${HebrewText.gematria(h.day)} ב$month' : '${h.day} $month';
  }

  /// A day of the practice (a Shabbat, a pause's last day, the day a parsha
  /// opens or its late window closes, the day something was read) in a
  /// sentence: [dateInText] in English, "Sunday, October 11", and in the
  /// Hebrew UI the Hebrew date with its weekday, without the year, "יום
  /// ראשון, ל׳ בתשרי", held together as [dateInText] is
  /// (docs/DESIGN_SYSTEM.md §4.6).
  String practiceDate(LocalDate d) => _heldTogether(_practiceDateLong(d));

  /// [practiceDate] without its weekday, after a word that names the day:
  /// "Read on Shabbat, October 10", "שבת, כ״ט בתשרי".
  String practiceDayMonth(LocalDate d) => _he ? hebrewDayMonth(d) : dateMonthDay(d);

  /// A day of the practice in a list or on a chip, briefly: "Oct 10", or in
  /// the Hebrew UI "כ״ט בתשרי". With its year where [today] is given and is
  /// in another year, a Hebrew one in the Hebrew UI: "Oct 10, 2025", "כ״ט
  /// בתשרי תשפ״ו".
  String practiceDateShort(LocalDate d, {LocalDate? today}) {
    if (_he) {
      final otherYear = today != null && HebrewDate.fromLocalDate(d).year != HebrewDate.fromLocalDate(today).year;
      return otherYear ? hebrewDate(d) : hebrewDayMonth(d);
    }
    return today != null && d.year != today.year ? dateShortWithYear(d) : dateShort(d);
  }

  String _practiceDateLong(LocalDate d) => _he ? '${weekday(d)}, ${hebrewDayMonth(d)}' : dateLong(d);

  /// When [week]'s portion is read in synagogue: "Read on Shabbat,
  /// 10 October", or for Vezot HaBerachah "Read on Simchat Torah, Sunday,
  /// 4 October". The Hebrew UI dates it in the Hebrew calendar, without the
  /// year: "נקראת בשבת, כ״ט בתשרי".
  String readOnLabel(ReadingWeek week) {
    final d = week.occasion;
    // Simchat Torah is seldom a Shabbat, so it gives the weekday too.
    if (week.portion.isVezotHaberakhah) return _l.readOnSimchatTorah(_practiceDateLong(d));
    return _l.readOnShabbat(practiceDayMonth(d));
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

  /// Human name for a special haftarah key from the data file. A key with no
  /// name is shown as it is, its apostrophes typeset in English.
  String specialHaftarah(String key) =>
      _he ? specialHaftarotHe[key] ?? key : specialHaftarotEn[key] ?? key.replaceAll("'", '’');

  static const _prophetsHe = {
    'Joshua': 'יהושע', 'Judges': 'שופטים', 'I Samuel': 'שמואל א', 'II Samuel': 'שמואל ב',
    'I Kings': 'מלכים א', 'II Kings': 'מלכים ב', 'Isaiah': 'ישעיהו', 'Jeremiah': 'ירמיהו',
    'Ezekiel': 'יחזקאל', 'Hosea': 'הושע', 'Joel': 'יואל', 'Amos': 'עמוס', 'Obadiah': 'עובדיה',
    'Jonah': 'יונה', 'Micah': 'מיכה', 'Nahum': 'נחום', 'Habakkuk': 'חבקוק', 'Zephaniah': 'צפניה',
    'Haggai': 'חגי', 'Zechariah': 'זכריה', 'Malachi': 'מלאכי',
  };

  /// The names of the special haftarot (the keys of `specialHaftarot` in
  /// assets/data/parshiyot.json, as the calendar gives them, with straight
  /// apostrophes) in Hebrew, and in [specialHaftarotEn] in English.
  @visibleForTesting
  static const specialHaftarotHe = {
    'Shabbat Rosh Chodesh': 'שבת ראש חודש',
    'Shabbat Rosh Chodesh (and Sunday)': 'שבת ראש חודש, ומוסיפים פסוקים מ״מחר חודש״',
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
    'Pinchas occurring after 17 Tammuz': 'ראשונה דפורענותא (״דברי ירמיהו״)',
    'Shabbat Rosh Chodesh Chanukah': 'שבת ראש חודש וחנוכה',
    'Chanukah Day 1 (on Shabbat)': 'שבת חנוכה',
    'Chanukah Day 2 (on Shabbat)': 'שבת חנוכה',
    'Chanukah Day 3 (on Shabbat)': 'שבת חנוכה',
    'Chanukah Day 4 (on Shabbat)': 'שבת חנוכה',
    'Chanukah Day 7 (on Shabbat)': 'שבת חנוכה',
    'Chanukah Day 8 (on Shabbat)': 'שבת חנוכה השנייה',
    'Kedoshim following Special Shabbat': 'קדושים (הפטרת אחרי מות)',
    'Masei on Shabbat Rosh Chodesh': 'מסעי בראש חודש אב',
    'Matot-Masei on Shabbat Rosh Chodesh': 'מטות־מסעי בראש חודש אב',
    'Ki Teitzei with 3rd Haftarah of Consolation': 'כי תצא עם ״עניה סוערה״',
    "Re'eh on Shabbat Rosh Chodesh (and Sunday)": 'ראה בשבת ראש חודש אלול, ומוסיפים פסוקים מ״מחר חודש״',
  };

  @visibleForTesting
  static const specialHaftarotEn = {
    'Shabbat Rosh Chodesh': 'Shabbat Rosh Chodesh',
    'Shabbat Rosh Chodesh (and Sunday)': 'Shabbat Rosh Chodesh, with verses for Sunday’s Rosh Chodesh',
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
    'Ki Teitzei with 3rd Haftarah of Consolation': 'Ki Tetze, with Aniyah So’arah',
    "Re'eh on Shabbat Rosh Chodesh (and Sunday)": 'Re’eh on Rosh Chodesh Elul, with verses for Sunday’s Rosh Chodesh',
  };
}
