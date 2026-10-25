// ignore_for_file: text_direction_code_point_in_literal

// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hebrew (`he`).
class AppLocalizationsHe extends AppLocalizations {
  AppLocalizationsHe([String locale = 'he']) : super(locale);

  @override
  String get appTitle => 'שניים מקרא';

  @override
  String get appTitleFull => 'שניים מקרא ואחד תרגום';

  @override
  String get navToday => 'היום';

  @override
  String get navParsha => 'פרשה';

  @override
  String get navProgress => 'התקדמות';

  @override
  String get navCommunity => 'קהילה';

  @override
  String get navSettings => 'הגדרות';

  @override
  String get actionContinue => 'המשך';

  @override
  String get actionNext => 'הבא';

  @override
  String get actionBack => 'הקודם';

  @override
  String get actionDone => 'סיום';

  @override
  String get actionCancel => 'ביטול';

  @override
  String get actionSave => 'שמירה';

  @override
  String get actionClose => 'סגירה';

  @override
  String get actionUndo => 'ביטול פעולה';

  @override
  String get actionRetry => 'ניסיון חוזר';

  @override
  String get actionOk => 'אישור';

  @override
  String get actionShare => 'שיתוף';

  @override
  String get actionMarkRead => 'סימון כנקרא';

  @override
  String get actionMarkUnread => 'סימון כלא נקרא';

  @override
  String get actionStart => 'התחלה';

  @override
  String get actionSkip => 'דילוג';

  @override
  String get actionNotNow => 'לא עכשיו';

  @override
  String get actionEdit => 'עריכה';

  @override
  String get actionDelete => 'מחיקה';

  @override
  String get actionClear => 'ניקוי';

  @override
  String get actionReport => 'דיווח';

  @override
  String get actionSend => 'שליחה';

  @override
  String get actionSignIn => 'כניסה';

  @override
  String get actionSignOut => 'יציאה';

  @override
  String get actionMore => 'אפשרויות נוספות';

  @override
  String moreOptionsFor(String name) {
    return 'אפשרויות נוספות עבור $name';
  }

  @override
  String get actionRefresh => 'רענון';

  @override
  String get refreshed => 'עודכן';

  @override
  String get loading => 'טוען…';

  @override
  String get errorGeneric => 'משהו השתבש. נא לנסות שוב.';

  @override
  String get notFoundTitle => 'הדף לא נמצא';

  @override
  String get notFoundBody => 'הקישור הזה לא מוביל לשום דף באפליקציה.';

  @override
  String get goToToday => 'מעבר למסך היום';

  @override
  String get aliyah1 => 'ראשון';

  @override
  String get aliyah2 => 'שני';

  @override
  String get aliyah3 => 'שלישי';

  @override
  String get aliyah4 => 'רביעי';

  @override
  String get aliyah5 => 'חמישי';

  @override
  String get aliyah6 => 'שישי';

  @override
  String get aliyah7 => 'שביעי';

  @override
  String aliyahNumbered(int number) {
    return 'עלייה $number';
  }

  @override
  String aliyahWithName(String name, int number) {
    return '$name';
  }

  @override
  String andJoiner(String first, String second) {
    return '$first ו$second';
  }

  @override
  String get passMikrah1 => 'קריאה ראשונה';

  @override
  String get passMikrah2 => 'קריאה שנייה';

  @override
  String get passTargum => 'תרגום';

  @override
  String get passRashi => 'רש״י';

  @override
  String get aliyotWord => 'עליות';

  @override
  String countOfTotal(int count, int total) {
    return '$count מתוך $total';
  }

  @override
  String passSemantics(String pass, String state) {
    return '$pass: $state';
  }

  @override
  String get stateDone => 'הושלם';

  @override
  String get stateNotDone => 'טרם הושלם';

  @override
  String versesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count פסוקים',
      one: 'פסוק אחד',
    );
    return '$_temp0';
  }

  @override
  String minutesEstimate(int minutes) {
    return 'כ־$minutes דק׳';
  }

  @override
  String aliyotProgress(int done, int total) {
    return '$done מתוך $total עליות';
  }

  @override
  String readOnShabbat(String date) {
    return 'נקראת בשבת, $date';
  }

  @override
  String readOnSimchatTorah(String date) {
    return 'נקראת בשמחת תורה, $date';
  }

  @override
  String occasionShabbat(String date) {
    return 'שבת, $date';
  }

  @override
  String occasionSimchatTorah(String date) {
    return 'שמחת תורה, $date';
  }

  @override
  String shabbatInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'שבת בעוד $count ימים',
      two: 'שבת בעוד יומיים',
      one: 'שבת מחר',
      zero: 'שבת היום',
    );
    return '$_temp0';
  }

  @override
  String get noWeeklyParshaThisShabbat => 'אין פרשת שבוע בשבת זו';

  @override
  String todayCandleLighting(String time) {
    return 'הדלקת נרות $time';
  }

  @override
  String parshaLabel(String name) {
    return 'פרשת $name';
  }

  @override
  String get parshatHashavua => 'פרשת השבוע';

  @override
  String get nextParsha => 'הפרשה הבאה';

  @override
  String get erevShabbat => 'ערב שבת';

  @override
  String erevYomTov(String holiday) {
    String _temp0 = intl.Intl.selectLogic(holiday, {
      'roshHashanah': 'ערב ראש השנה',
      'yomKippur': 'ערב יום כיפור',
      'other': 'ערב חג',
    });
    return '$_temp0';
  }

  @override
  String erevShabbatYomTov(String holiday) {
    String _temp0 = intl.Intl.selectLogic(holiday, {
      'roshHashanah': 'ערב שבת וראש השנה',
      'yomKippur': 'ערב יום כיפור',
      'other': 'ערב שבת וחג',
    });
    return '$_temp0';
  }

  @override
  String get shabbatShalom => 'שבת שלום';

  @override
  String get chagSameach => 'חג שמח';

  @override
  String get shanaTova => 'שנה טובה';

  @override
  String get gmarChatimaTova => 'גמר חתימה טובה';

  @override
  String get restDayNoWeeklyParsha =>
      'בשבת זו קוראים בתורה קריאה מיוחדת במקום פרשת השבוע.';

  @override
  String get restDayBody => 'קוראים היום מתוך חומש? אפשר לרשום זאת אחרי השבת.';

  @override
  String get restDayBodyChag =>
      'קוראים היום מתוך חומש? אפשר לרשום זאת אחרי החג.';

  @override
  String get restDayBodyYomKippur =>
      'קוראים היום מתוך חומש? אפשר לרשום זאת אחרי יום כיפור.';

  @override
  String get openTheParsha => 'לפרשה';

  @override
  String get simchatTorahEyebrow => 'שמחת תורה';

  @override
  String get shabbatBeginsTonight => 'שבת נכנסת הערב';

  @override
  String yomTovBeginsTonight(String holiday) {
    String _temp0 = intl.Intl.selectLogic(holiday, {
      'roshHashanah': 'ראש השנה נכנס הערב',
      'yomKippur': 'יום כיפור נכנס הערב',
      'other': 'החג נכנס הערב',
    });
    return '$_temp0';
  }

  @override
  String shabbatYomTovBeginTonight(String holiday) {
    String _temp0 = intl.Intl.selectLogic(holiday, {
      'roshHashanah': 'שבת וראש השנה נכנסים הערב',
      'yomKippur': 'שבת ויום כיפור נכנסים הערב',
      'other': 'שבת וחג נכנסים הערב',
    });
    return '$_temp0';
  }

  @override
  String get allAliyot => 'כל העליות';

  @override
  String startAt(String aliyah) {
    return 'התחלה · $aliyah';
  }

  @override
  String continueAt(String aliyah) {
    return 'המשך · $aliyah';
  }

  @override
  String continueAtPass(String aliyah, String pass) {
    return 'המשך · $aliyah, $pass';
  }

  @override
  String readAliyah(String aliyah) {
    return 'לקריאת $aliyah';
  }

  @override
  String get todayReadingTitle => 'הקריאה של היום';

  @override
  String get todayDone => 'הקריאה של היום הושלמה';

  @override
  String get todayAhead => 'מקדימים את התוכנית. כל הכבוד!';

  @override
  String graceUsedNote(int count, String weekdays, String parsha) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$weekdays כוסו בימי חסד — הקצב נמשך. עם סיום פרשת $parsha עד שבת, יום חסד אחד יחזור.',
      one:
          '$weekdays כוסה ביום חסד — הקצב נמשך. עם סיום פרשת $parsha עד שבת, יום החסד יחזור.',
    );
    return '$_temp0';
  }

  @override
  String graceUsedNoteShort(int count, String weekdays) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$weekdays כוסו בימי חסד — הקצב נמשך.',
      one: '$weekdays כוסה ביום חסד — הקצב נמשך.',
    );
    return '$_temp0';
  }

  @override
  String get caughtUpNote => 'חזרה לתוכנית — הקריאה של היום השלימה את אתמול.';

  @override
  String get todayNothingPlanned =>
      'לא מתוכננת קריאה להיום. זמן טוב להשלים או להקדים.';

  @override
  String get todayCatchUpTitle => 'משלימים';

  @override
  String aliyotCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count עליות',
      one: 'עלייה אחת',
    );
    return '$_temp0';
  }

  @override
  String get aliyotWholeParsha => 'כל הפרשה';

  @override
  String todayBehind(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'עוד $count עליות להשלים — רגיל לגמרי באמצע השבוע.',
      one: 'עוד עלייה אחת להשלים — רגיל לגמרי באמצע השבוע.',
    );
    return '$_temp0';
  }

  @override
  String todayBehindThursday(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'עוד $count עליות להשלים — ויש עוד יומיים עד שבת.',
      one: 'עוד עלייה אחת להשלים — ויש עוד יומיים עד שבת.',
    );
    return '$_temp0';
  }

  @override
  String todayLastDayShabbat(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'עוד $count עליות לקרוא לפני שבת — או לסיים בשבת בבוקר מתוך חומש ולרשום אחרי השבת.',
      one: 'עוד עלייה אחת לקרוא לפני שבת — או לסיים בשבת בבוקר מתוך חומש ולרשום אחרי השבת.',
    );
    return '$_temp0';
  }

  @override
  String todayLastDayYomTov(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'עוד $count עליות לקרוא לפני החג — או לסיים בחג מתוך חומש ולרשום אחרי החג.',
      one: 'עוד עלייה אחת לקרוא לפני החג — או לסיים בחג מתוך חומש ולרשום אחרי החג.',
    );
    return '$_temp0';
  }

  @override
  String todayLastDayShabbatThenYomTov(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'עוד $count עליות לקרוא לפני שבת — או לסיים בשבת בבוקר מתוך חומש ולרשום אחרי החג.',
      one: 'עוד עלייה אחת לקרוא לפני שבת — או לסיים בשבת בבוקר מתוך חומש ולרשום אחרי החג.',
    );
    return '$_temp0';
  }

  @override
  String todayLastDayYomTovThenShabbat(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'עוד $count עליות לקרוא לפני החג — או לסיים בחג או בשבת מתוך חומש ולרשום אחרי השבת.',
      one: 'עוד עלייה אחת לקרוא לפני החג — או לסיים בחג או בשבת מתוך חומש ולרשום אחרי השבת.',
    );
    return '$_temp0';
  }

  @override
  String todayBehindBeforeYomTovMore(int count, String day) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'עוד $count עליות להשלים לפני החג — או אחריו, ב$day.',
      one: 'עוד עלייה אחת להשלים לפני החג — או אחריו, ב$day.',
    );
    return '$_temp0';
  }

  @override
  String todayBehindBeforeShabbatMore(int count, String day) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'עוד $count עליות להשלים לפני שבת — או אחריה, ב$day.',
      one: 'עוד עלייה אחת להשלים לפני שבת — או אחריה, ב$day.',
    );
    return '$_temp0';
  }

  @override
  String todayLastDayYomKippur(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'עוד $count עליות להשלים לפני יום כיפור — ויש זמן גם אחריו.',
      one: 'עוד עלייה אחת להשלים לפני יום כיפור — ויש זמן גם אחריו.',
    );
    return '$_temp0';
  }

  @override
  String get pausedTodayNote =>
      'בהשהיה — אפשר לקרוא מתי שנוח; שום דבר לא נחשב לחובתך.';

  @override
  String get erevTishaBavNote =>
      'ערב תשעה באב: רבים מסיימים את הלימוד לפני חצות היום.';

  @override
  String get startReading => 'התחלת קריאה';

  @override
  String get readFromBook => 'קראתי בחומש';

  @override
  String get readFromBookTitle => 'אילו עליות נקראו?';

  @override
  String get weekComplete => 'הפרשה של השבוע הושלמה. יישר כוח!';

  @override
  String get weekCompleteNote => 'הכול מוכן לקריאת התורה בשבת.';

  @override
  String get weekCompleteNoteSimchatTorah =>
      'הכול מוכן לקריאת התורה בשמחת תורה.';

  @override
  String get discussTheParsha => 'לדיון בפרשה';

  @override
  String get haftarahLabel => 'הפטרה';

  @override
  String get haftarahRead => 'ההפטרה נקראה';

  @override
  String openWeekTitle(String name) {
    return 'פרשת $name עדיין פתוחה';
  }

  @override
  String openWeekLate(String when, String date) {
    String _temp0 = intl.Intl.selectLogic(when, {
      'today': 'סיום עד הלילה עדיין נחשב.',
      'tomorrow': 'סיום עד מחר בלילה עדיין נחשב.',
      'other': 'סיום עד סוף $date, עדיין נחשב.',
    });
    return '$_temp0';
  }

  @override
  String openWeekLateEve(String holiday, String when, String date) {
    String _temp0 = intl.Intl.selectLogic(holiday, {
      'shabbat': 'השבת',
      'roshHashanah': 'ראש השנה',
      'yomKippur': 'יום כיפור',
      'other': 'החג',
    });
    String _temp1 = intl.Intl.selectLogic(when, {
      'today': 'הערב עדיין נחשב.',
      'tomorrow': 'מחר בערב עדיין נחשב.',
      'other': 'ב$date, עדיין נחשב.',
    });
    return 'סיום לפני כניסת $_temp0 $_temp1';
  }

  @override
  String openWeekRestore(String name, String next, String deadline, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'אם מסיימים את $name ואת $next עד $deadline, הרצף של $count שבועות נמשך — אפשר לעשות זאת פעם אחת בכל חומש.',
      one:
          'אם מסיימים את $name ואת $next עד $deadline, הרצף של שבוע אחד נמשך — אפשר לעשות זאת פעם אחת בכל חומש.',
    );
    return '$_temp0';
  }

  @override
  String openWeekRestoreZero(String name, String next, String deadline) {
    return 'אם מסיימים את $name ואת $next עד $deadline, שתיהן נחשבות — אפשר לעשות זאת פעם אחת בכל חומש.';
  }

  @override
  String get openWeekHaftarahLeft => 'נשארה רק ההפטרה.';

  @override
  String openWeekOpen(String name) {
    return 'לפרשת $name';
  }

  @override
  String get readTheHaftarah => 'לקריאת ההפטרה';

  @override
  String checkInTitle(String name) {
    return 'שבוע טוב! קראת את פרשת $name בשבת?';
  }

  @override
  String checkInTitleShabbatYomTov(String name) {
    return 'שבוע טוב! קראת את פרשת $name בשבת וביום טוב?';
  }

  @override
  String checkInTitleVezot(String name) {
    return 'סיימת את פרשת $name ביום טוב?';
  }

  @override
  String checkInTitleSimchatTorah(String name) {
    return 'סיימת את פרשת $name בשמחת תורה?';
  }

  @override
  String get checkInBody =>
      'אפשר לרשום מה שקראת מתוך חומש מודפס — זה נחשב בדיוק אותו הדבר.';

  @override
  String checkInFinished(String name) {
    return 'סיימתי את פרשת $name בשבת';
  }

  @override
  String checkInFinishedYomTov(String name) {
    return 'סיימתי את פרשת $name ביום טוב';
  }

  @override
  String checkInFinishedSimchatTorah(String name) {
    return 'סיימתי את פרשת $name בשמחת תורה';
  }

  @override
  String get checkInPick => 'בחירת עליות';

  @override
  String get checkInNotThisTime => 'לא הפעם';

  @override
  String checkInReadOnShabbat(String date) {
    return 'תאריך הקריאה: שבת, $date';
  }

  @override
  String checkInReadOnYomTov(String date) {
    return 'תאריך הקריאה: יום טוב, $date';
  }

  @override
  String checkInReadOn(String date) {
    return 'תאריך הקריאה: $date';
  }

  @override
  String get changeDate => 'שינוי התאריך';

  @override
  String get logReading => 'רישום הקריאה';

  @override
  String pausedBanner(String date) {
    return 'בהשהיה עד $date. דבר אינו מתאפס בזמן ההשהיה.';
  }

  @override
  String get resume => 'סיום ההשהיה';

  @override
  String pauseEndedOn(String date) {
    return 'ההשהיה הסתיימה ב$date, ושום דבר בזמנה לא נחשב לחובתך.';
  }

  @override
  String get pauseEndedStart => 'התחלת פרשת השבוע';

  @override
  String get pauseEndedContinue => 'המשך פרשת השבוע';

  @override
  String catchUpOn(String name) {
    return 'השלמת פרשת $name';
  }

  @override
  String get actionDismiss => 'הסתרה';

  @override
  String readingDivergence(String israel, String diaspora) {
    return 'בארץ ישראל קוראים השבוע את פרשת $israel, ובחוץ לארץ את פרשת $diaspora. מבקרים מחוץ לארץ נוהגים בדרך כלל לקרוא את שתי הפרשות. כשמתפללים במניין שקורא את פרשת $diaspora, קוראים רק אותה, ובהגדרות בוחרים בקריאת התורה של חוץ לארץ.';
  }

  @override
  String readingDivergenceAhead(String israel, String diaspora) {
    return 'בארץ ישראל קוראים השבוע את פרשת $israel, ובחוץ לארץ את פרשת $diaspora. ארץ ישראל מקדימה בפרשה אחת, ואת פרשת $israel קוראים כאן בשבוע הבא.';
  }

  @override
  String readingDivergenceOpen(String name) {
    return 'לפרשת $name';
  }

  @override
  String get readingDivergenceChange => 'שינוי קריאת התורה';

  @override
  String get discussThisWeek => 'דיון על פרשת השבוע';

  @override
  String get thisWeek => 'ועוד השבוע';

  @override
  String get streakParsha => 'רצף פרשות';

  @override
  String get streakDays => 'ימים לפי התוכנית';

  @override
  String weeksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count שבועות',
      two: 'שבועיים',
      one: 'שבוע אחד',
    );
    return '$_temp0';
  }

  @override
  String daysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ימים',
      two: 'יומיים',
      one: 'יום אחד',
    );
    return '$_temp0';
  }

  @override
  String streakBeginsWith(String name) {
    return 'יתחיל עם סיום פרשת $name';
  }

  @override
  String get daysBeginToday => 'יתחיל בקריאה של היום';

  @override
  String get dayKept => 'נקרא';

  @override
  String get dayAhead => 'נקרא מראש';

  @override
  String get dayCaughtUp => 'הושלם למחרת';

  @override
  String get dayGrace => 'מכוסה ביום חסד';

  @override
  String get dayPaused => 'בהשהיה';

  @override
  String get dayOpen => 'עדיין לקריאה';

  @override
  String get dayMissed => 'לא נקרא';

  @override
  String get dayRest => 'שבת או יום טוב';

  @override
  String get dayUpcoming => 'בהמשך';

  @override
  String get dayNoReading => 'אין קריאה מתוכננת';

  @override
  String get dayToday => 'היום';

  @override
  String get yomTovShort => 'יו״ט';

  @override
  String dayChipLabel(String day, String status) {
    return '$day: $status';
  }

  @override
  String get weekStripLabel => 'התוכנית לשבוע זה';

  @override
  String get weekOnTime => 'בזמן';

  @override
  String get weekLate => 'אחרי שבת — עדיין נחשב';

  @override
  String get weekRestored => 'הושלם עם הפרשה הבאה';

  @override
  String get weekMadeUp => 'הושלם מאוחר יותר';

  @override
  String get weekMissed => 'לא הושלם';

  @override
  String get weekTransparent => 'לא נספר';

  @override
  String get weekOverdue => 'עוד אפשר להשלים עם הפרשה הבאה';

  @override
  String get weekInProgress => 'בתהליך';

  @override
  String plannedFor(String day) {
    return 'מתוכנן ל$day';
  }

  @override
  String plannedForOverdue(String day) {
    return 'מתוכנן ל$day, עדיין לקריאה';
  }

  @override
  String get plannedForShabbatOverdue => 'מתוכנן לשבת בבוקר, עדיין לקריאה';

  @override
  String get plannedForToday => 'מתוכנן להיום';

  @override
  String get plannedForShabbat => 'שבת בבוקר — לרשום אחרי שבת';

  @override
  String get markWholeWeek => 'סימון כל הפרשה כנקראה';

  @override
  String get clearWeek => 'ניקוי ההתקדמות של השבוע';

  @override
  String clearWeekConfirm(String name) {
    return 'לנקות את כל ההתקדמות בפרשת $name?';
  }

  @override
  String weekCleared(String name) {
    return 'ההתקדמות בפרשת $name נמחקה';
  }

  @override
  String get whenDidYouRead => 'מתי קראת?';

  @override
  String get whenToday => 'היום';

  @override
  String get whenYesterday => 'אתמול';

  @override
  String get whenOnShabbat => 'בשבת';

  @override
  String get whenOnYomTov => 'ביום טוב';

  @override
  String get whenPickDate => 'בחירת תאריך';

  @override
  String get markedRead => 'סומן כנקרא';

  @override
  String get markedUnread => 'סומן כלא נקרא';

  @override
  String aliyahOtherDivision(String range) {
    return 'לפי חלק מהמקורות: $range';
  }

  @override
  String secondParshaBegins(String name, String ref) {
    return 'פרשת $name מתחילה ב־$ref';
  }

  @override
  String get browseAll => 'כל הפרשות';

  @override
  String get browseTitle => 'התורה';

  @override
  String browseBookParshiyot(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count פרשות',
      one: 'פרשה אחת',
    );
    return '$_temp0';
  }

  @override
  String get browseThisWeek => 'פרשת השבוע';

  @override
  String browseReadWith(String name) {
    return 'נקראת עם $name';
  }

  @override
  String previewNotOpen(String date) {
    return 'תצוגה מקדימה — הפרשה נפתחת לרישום ב$date.';
  }

  @override
  String get stepMikrah1 => 'קריאת המקרא';

  @override
  String get stepMikrah2 => 'קריאת המקרא שוב';

  @override
  String get stepTargum => 'קריאת התרגום';

  @override
  String get stepRashi => 'קריאת רש״י';

  @override
  String get stepThirdHebrew => 'קריאת המקרא בפעם השלישית';

  @override
  String get stepRepeatLast => 'לסיים במקרא: קריאת הפסוק האחרון שוב';

  @override
  String stepOf(int step, int total) {
    return 'קריאה $step מתוך $total';
  }

  @override
  String verseOf(int current, int total) {
    return 'פסוק $current מתוך $total';
  }

  @override
  String sectionOf(int current, int total) {
    return 'קטע $current מתוך $total';
  }

  @override
  String aliyahOf(int current, int total) {
    return 'עלייה $current מתוך $total';
  }

  @override
  String verseLabel(String number) {
    return 'פסוק $number';
  }

  @override
  String targumVerseLabel(String number) {
    return 'תרגום, פסוק $number';
  }

  @override
  String chapterLabel(String number) {
    return 'פרק $number';
  }

  @override
  String get noTargumNote =>
      'אונקלוס כאן מביא בעיקר את שמות המקומות בארמית. בעקבות רש״י (ברכות ח, ב) רבים קוראים פסוק זה גם פעם שלישית בעברית (ראו שו״ע או״ח רפה, א).';

  @override
  String get noRashiNote =>
      'רש״י אינו מפרש פסוק זה. יש הקוראים אותו פעם שלישית בעברית (משנה ברורה רפה, ה).';

  @override
  String get noRashiComment => 'רש״י אינו מפרש פסוק זה.';

  @override
  String ketivQereLabel(String ketiv, String qere) {
    return 'כתיב $ketiv, קרי $qere';
  }

  @override
  String ketivOnlyLabel(String ketiv) {
    return 'כתיב $ketiv, ולא קרי';
  }

  @override
  String qereOnlyLabel(String qere) {
    return 'קרי $qere, ולא כתיב';
  }

  @override
  String noteLabel(String text) {
    return 'הערה: $text';
  }

  @override
  String aliyahComplete(String aliyah) {
    return 'יישר כוח! עליית $aliyah הושלמה.';
  }

  @override
  String parshaComplete(String name) {
    return 'חזק! פרשת $name הושלמה.';
  }

  @override
  String firstAliyahDone(String verses, String second) {
    return 'יישר כוח! העלייה הראשונה שלך הושלמה — $verses, שניים מקרא ו$second.';
  }

  @override
  String get backToWeek => 'חזרה לפרשה';

  @override
  String get displaySettings => 'הגדרות תצוגה';

  @override
  String get textSize => 'גודל טקסט';

  @override
  String get textSmaller => 'הקטנת טקסט';

  @override
  String get textLarger => 'הגדלת טקסט';

  @override
  String get listen => 'השמעה';

  @override
  String get stopListening => 'עצירה';

  @override
  String get listenPause => 'השהיה';

  @override
  String get listenResume => 'המשך השמעה';

  @override
  String get listenPreviousVerse => 'הפסוק הקודם';

  @override
  String get listenNextVerse => 'הפסוק הבא';

  @override
  String speechRateValue(String rate) {
    return 'קצב הקראה: $rate';
  }

  @override
  String get listenAlong => 'השמעה רציפה';

  @override
  String get listenAlongDesc =>
      'ההשמעה עוברת מעצמה מכל קריאה לקריאה שאחריה, עד סוף העלייה. עזר למעקב אחר הטקסט, לא תחליף לקריאה בו.';

  @override
  String get ttsUnavailable => 'הקראה קולית אינה זמינה במכשיר זה.';

  @override
  String get ttsNoHebrewVoice =>
      'לא מותקן קול בעברית. אפשר להוסיף קול בהגדרות הדיבור של המכשיר.';

  @override
  String get guidedMode => 'קריאה מודרכת';

  @override
  String get fullTextMode => 'טקסט מלא';

  @override
  String get wholeParsha => 'הפרשה כולה';

  @override
  String get oneAliyahAtATime => 'עלייה אחת בכל פעם';

  @override
  String get markAliyahRead => 'סימון העלייה כנקראה';

  @override
  String get keyboardShortcuts => 'קיצורי מקלדת';

  @override
  String get translationDisclaimer =>
      'עוזר להבין את הפשט, אך אינו בא במקום תרגום אונקלוס.';

  @override
  String get mikrahLabel => 'מקרא';

  @override
  String get targumLabel => 'תרגום אונקלוס';

  @override
  String get rashiLabel => 'רש״י';

  @override
  String get translationLabel => 'תרגום לאנגלית (JPS 1917)';

  @override
  String get translationHead => 'תרגום לאנגלית';

  @override
  String get haftarahTitle => 'הפטרה';

  @override
  String get markHaftarahRead => 'סימון ההפטרה כנקראה';

  @override
  String get readerFinished => 'סיימת את העלייה הזו.';

  @override
  String get shortcutNext => 'השלב הבא';

  @override
  String get shortcutBack => 'השלב הקודם';

  @override
  String get shortcutGoBack => 'סגירת מסך הקריאה, כמו בכפתור החזרה של העכבר';

  @override
  String get shortcutLarger => 'הגדלת טקסט';

  @override
  String get shortcutSmaller => 'הקטנת טקסט';

  @override
  String get shortcutTeamim => 'הצגת או הסתרת טעמים';

  @override
  String get shortcutNikud => 'הצגת או הסתרת ניקוד';

  @override
  String get shortcutListen => 'השמעה / השהיה';

  @override
  String get shortcutListenVerse => 'בזמן השמעה: הפסוק הקודם או הבא';

  @override
  String get shortcutHelp => 'הצגת קיצורים';

  @override
  String get shortcutScroll => 'גלילת הטקסט';

  @override
  String get shortcutPageDown => 'עמוד למטה, ואז השלב הבא';

  @override
  String get shortcutPageUp => 'עמוד למעלה, ואז השלב הקודם';

  @override
  String get shortcutFocusVerse => 'טקסט מלא במצב מיקוד: הפסוק הקודם או הבא';

  @override
  String get keyUp => 'חץ למעלה';

  @override
  String get keyDown => 'חץ למטה';

  @override
  String get keyLeft => 'חץ שמאלה';

  @override
  String get keyRight => 'חץ ימינה';

  @override
  String get keySpace => 'רווח';

  @override
  String get verseOptions => 'אפשרויות לפסוק';

  @override
  String get shortcutVerseOptions =>
      'אפשרויות לפסוק: סימנייה, הערה, העתקה, שיתוף או שאלה';

  @override
  String get copyVerse => 'העתקה';

  @override
  String get askAboutVerse => 'שאלה על הפסוק';

  @override
  String get askAboutVerseDesc => 'בפורום שאלות ותשובות';

  @override
  String get verseCopied => 'הפסוק הועתק';

  @override
  String get shareCopiedInstead => 'אין כאן אפשרות לשתף, ולכן הפסוק הועתק.';

  @override
  String get bookmarkVerse => 'סימנייה';

  @override
  String get addNote => 'הוספת הערה';

  @override
  String get yourNote => 'ההערה שלך';

  @override
  String noteTitle(String reference) {
    return 'הערה על $reference';
  }

  @override
  String get noteHint => 'שאלה לשולחן השבת, או מחשבה';

  @override
  String get noteSaved => 'ההערה נשמרה';

  @override
  String get noteDeleted => 'ההערה נמחקה';

  @override
  String get verseBookmarked => 'מסומן בסימנייה';

  @override
  String get verseWithNote => 'יש עליו הערה שלך';

  @override
  String yourNoteLabel(String text) {
    return 'ההערה שלך: $text';
  }

  @override
  String get notesTitle => 'סימניות והערות';

  @override
  String get notesEmpty =>
      'כדי לסמן פסוק או לשמור שאלה לשולחן השבת, יש ללחוץ לחיצה ארוכה על הפסוק בזמן הקריאה.';

  @override
  String get notesEmptyParsha => 'עדיין אין סימניות או הערות בפרשה הזו.';

  @override
  String get notesShowAll => 'כל הסימניות וההערות';

  @override
  String get parshaNotes => 'ההערות שלך על הפרשה';

  @override
  String notesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count הערות',
      two: 'שתי הערות',
      one: 'הערה אחת',
    );
    return '$_temp0';
  }

  @override
  String bookmarksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count סימניות',
      two: 'שתי סימניות',
      one: 'סימנייה אחת',
    );
    return '$_temp0';
  }

  @override
  String get copyDivineName => 'כתיבת שמות הקודש כ־ה׳ וכ־אלקים';

  @override
  String get copyDivineNameDesc => 'בפסוק שמעתיקים, משתפים או מצטטים בשאלה';

  @override
  String get progressTitle => 'התקדמות';

  @override
  String longest(String value) {
    return 'הארוך ביותר: $value';
  }

  @override
  String versesRead(String count, String second) {
    return '$count פסוקים בשניים מקרא ו$second';
  }

  @override
  String yearBarSemantics(int done, int total) {
    return 'השנה: הושלמו $done מתוך $total פרשות';
  }

  @override
  String yearBarSemanticsCurrent(int done, int total, String name) {
    return 'השנה: הושלמו $done מתוך $total פרשות; פרשת $name בתהליך';
  }

  @override
  String get bookAbbrGenesis => 'בר׳';

  @override
  String get bookAbbrExodus => 'שמ׳';

  @override
  String get bookAbbrLeviticus => 'וי׳';

  @override
  String get bookAbbrNumbers => 'במ׳';

  @override
  String get bookAbbrDeuteronomy => 'דב׳';

  @override
  String get torahMap => 'מפת התורה';

  @override
  String get torahMapHelp => 'כל משבצת היא פרשה אחת במחזור של השנה.';

  @override
  String torahMapBook(String book, int done, int total) {
    return '$book: $done מתוך $total פרשות';
  }

  @override
  String get recentWeeks => 'שבועות אחרונים';

  @override
  String get makeUpTitle => 'השלמה עד שמחת תורה';

  @override
  String get makeUpBody => 'לא חובה. השלמות נחשבות לסיום התורה של השנה.';

  @override
  String get pauseTitle => 'הפסקה זמנית';

  @override
  String get pauseBody =>
      'אפשר להשהות עד 30 יום — דבר אינו מתאפס בזמן ההשהיה. מחלה, נסיעה, אבלות, תינוק חדש: החיים קודמים.';

  @override
  String get pauseAction => 'השהיית רצפים';

  @override
  String get pauseFor => 'השהיה למשך';

  @override
  String get pauseStarting => 'החל מ־';

  @override
  String pauseManageTitle(String date) {
    return 'בהשהיה עד $date';
  }

  @override
  String get pauseManageBody => 'אפשר להאריך את ההשהיה או לסיים אותה עכשיו.';

  @override
  String get pauseAtMost =>
      'השהיה נמשכת 30 יום לכל היותר. אפשר לסיים אותה עכשיו.';

  @override
  String pauseStarted(String date) {
    return 'בהשהיה עד $date.';
  }

  @override
  String get pauseEnded => 'ברוכים השבים! המקום שלך שמור.';

  @override
  String get streaksHidden => 'מספרי הרצף מוסתרים. ההתקדמות שלך עדיין נשמרת.';

  @override
  String get graceExplainer =>
      'ימי חסד מכסים אוטומטית יום מתוכנן שהוחמץ. מתחילים עם 2, מקבלים 1 בכל פעם שמסיימים פרשה לפני שבת (עד 3), ומשתמשים לכל היותר ב־2 בשבוע. אי אפשר לקנות אותם.';

  @override
  String streakExplainer(String deadline) {
    String _temp0 = intl.Intl.selectLogic(deadline, {
      'tuesday': ' — או עד ליל רביעי, שגם זה נחשב',
      'wednesday': ' — או עד סוף יום רביעי, שגם זה נחשב',
      'other': '',
    });
    return 'רצף הפרשות סופר פרשות שהושלמו לפני שבת$_temp0. שבת ויום טוב לעולם אינם שוברים רצף.';
  }

  @override
  String get statusLegend => 'מקרא';

  @override
  String get noHistory => 'השבועות יופיעו כאן עם תחילת הקריאה.';

  @override
  String get milestoneFirstAliyah => 'עלייה ראשונה';

  @override
  String get milestoneFirstParsha => 'פרשה ראשונה';

  @override
  String get milestonePerfectWeek => 'שבוע מושלם';

  @override
  String milestoneParshaStreak(int count) {
    return 'רצף של $count פרשות';
  }

  @override
  String milestoneDaysOnTrack(int count) {
    return '$count ימים לפי התוכנית';
  }

  @override
  String get milestoneSiyum => 'סיום התורה';

  @override
  String get milestoneComeback => 'ברוכים השבים';

  @override
  String get settingsTitle => 'הגדרות';

  @override
  String get settingsReading => 'קריאה ומנהגים';

  @override
  String get settingsDisplay => 'תצוגה';

  @override
  String get settingsAccessibility => 'נגישות';

  @override
  String get settingsReminders => 'תזכורות';

  @override
  String get settingsStreaks => 'רצפים';

  @override
  String get settingsAccount => 'חשבון וקהילה';

  @override
  String get settingsData => 'הנתונים שלך';

  @override
  String get settingsLanguage => 'שפה';

  @override
  String get settingsAbout => 'אודות האפליקציה';

  @override
  String get settingsReadingDesc =>
      'ארץ ישראל או חו״ל, זמני שבת, תוכנית, תרגום או רש״י, הפטרה';

  @override
  String get settingsDisplayDesc =>
      'ערכת צבעים, גופנים, גודל טקסט, ניקוד וטעמים';

  @override
  String get settingsAccessibilityDesc =>
      'תנועה, קוראי מסך, הקראה, הגדרות מהירות';

  @override
  String get settingsRemindersDesc => 'תזכורות עדינות, לעולם לא בשבת וביום טוב';

  @override
  String get settingsDataDesc => 'גיבוי, שחזור או איפוס ההתקדמות';

  @override
  String get settingsGroupPractice => 'שגרת הקריאה';

  @override
  String get settingsGroupReading => 'קריאה במסך';

  @override
  String get settingsGroupYou => 'אישי';

  @override
  String get settingsAboutDesc => 'גרסה, מקורות, פרטיות';

  @override
  String get settingsPauseDesc =>
      'מחלה, נסיעה, אבלות, תינוק חדש: דבר אינו מתאפס בזמן ההשהיה';

  @override
  String get locationIsrael => 'בארץ ישראל';

  @override
  String get locationDiaspora => 'בחוץ לארץ';

  @override
  String get locationHelp =>
      'בארץ ובחוץ לארץ קוראים לעתים פרשות שונות, ומספר ימי יום טוב שונה. בביקור? בהגדרות אפשר לקבוע בנפרד כמה ימי יום טוב שומרים.';

  @override
  String get readingScheduleLabel =>
      'איזו קריאת תורה תישמע בבית הכנסת שלך בשבת הקרובה?';

  @override
  String get readingScheduleHelp =>
      'לפעמים, במשך כמה שבועות אחרי פסח או חג השבועות, בארץ ישראל מקדימים בפרשה אחת.';

  @override
  String get yomTovDaysLabel => 'כמה ימי יום טוב שומרים אצלך?';

  @override
  String get yomTovDaysOne => 'יום אחד, כמו בארץ ישראל';

  @override
  String get yomTovDaysTwo => 'יומיים, כמו בחוץ לארץ';

  @override
  String get yomTovDaysHelp =>
      'מבקרים נוהגים בדרך כלל כמנהג מקומם הקבוע. יש לשאול רב.';

  @override
  String get planLabel => 'תוכנית שבועית';

  @override
  String get planAliyahPerDay => 'עלייה ליום';

  @override
  String get planAliyahPerDayDesc =>
      'עלייה אחת ביום; שתיים ביום האחרון שלפני שבת';

  @override
  String get planShevii => 'שביעי בשבת בבוקר';

  @override
  String get planSheviiDesc =>
      'עליות ⁦1–6⁩ בימים א׳–ו׳; השביעית לפני סעודת שבת (הגר״א, מ״ב רפה, ח)';

  @override
  String get planErevShabbat => 'הכול ביום שישי';

  @override
  String get planErevShabbatDesc =>
      'כל הפרשה בערב שבת — אחרי שחרית (האריז״ל) או אחרי חצות היום (השל״ה; שולחן ערוך הרב)';

  @override
  String get methodLabel => 'שיטת קריאה';

  @override
  String get methodVerse => 'פסוק פסוק';

  @override
  String methodVerseDesc(String second) {
    return 'כל פסוק פעמיים, ואז $second';
  }

  @override
  String get methodSection => 'פרשה פרשה';

  @override
  String methodSectionDesc(String second) {
    return 'כל פרשה (פתוחה או סתומה) פעמיים, ואז $second';
  }

  @override
  String get methodAliyah => 'עלייה עלייה';

  @override
  String methodAliyahDesc(String second) {
    return 'כל העלייה פעמיים, ואז $second';
  }

  @override
  String get methodWhole => 'כל הפרשה';

  @override
  String methodWholeDesc(String second) {
    return 'כל הפרשה פעם אחת, ושוב, ואז $second';
  }

  @override
  String get secondLabel => 'תרגום או רש״י';

  @override
  String get secondOnkelos => 'תרגום אונקלוס';

  @override
  String get secondRashi => 'רש״י';

  @override
  String get secondBoth => 'אונקלוס ורש״י';

  @override
  String get secondRashiEnglish => 'רש״י באנגלית';

  @override
  String get secondSource =>
      'השולחן ערוך (או״ח רפה, ב) מתיר לקרוא את פירוש רש״י במקום התרגום, וירא שמים יקרא את שניהם.';

  @override
  String get secondAdvice =>
      'תרגום פשוט הוא עזר ללימוד ואינו תחליף. על רש״י מתורגם יש לשאול רב.';

  @override
  String get repeatLastVerse => 'לסיים במקרא';

  @override
  String get repeatLastVerseDesc =>
      'לחזור על הפסוק האחרון של הפרשה בעברית אחרי התרגום';

  @override
  String get thirdReading => 'הצעה לקריאה שלישית';

  @override
  String get thirdReadingDesc =>
      'להציע קריאה שלישית בעברית כשאונקלוס מביא בעיקר שמות (במדבר לב, ג) או כשרש״י אינו מפרש';

  @override
  String get haftarahEnabledDesc => 'קריאת הפטרת השבוע פעם אחת';

  @override
  String get nusachLabel => 'מנהג ההפטרה';

  @override
  String get nusachAshkenazi => 'אשכנז';

  @override
  String get nusachSephardi => 'ספרד';

  @override
  String get nusachChabad => 'חב״ד';

  @override
  String get haftarahRequired => 'ההפטרה נדרשת להשלמת השבוע';

  @override
  String get lateWindowLabel => 'חלון אחרי שבת';

  @override
  String get lateTuesday => 'עד ליל רביעי';

  @override
  String get lateWednesday => 'עד סוף יום רביעי';

  @override
  String get lateNone => 'ללא חלון';

  @override
  String get lateWindowDesc =>
      'קריאה שהושלמה אחרי שבת, עד מועד זה, עדיין נחשבת (שולחן ערוך או״ח רפה, ד).';

  @override
  String get tishaBavQuiet => 'ללא קריאה מתוכננת בתשעה באב';

  @override
  String get cholHamoedQuiet => 'ללא קריאה מתוכננת בחול המועד';

  @override
  String get appliesFromThisWeek => 'חל מהשבוע הזה והלאה';

  @override
  String get nameStyleLabel => 'שמות הפרשות באנגלית';

  @override
  String get nameSephardi => 'ספרדי (Bereshit)';

  @override
  String get nameAshkenazi => 'אשכנזי (Bereishis)';

  @override
  String get readingGroupWhere => 'מקום וזמן';

  @override
  String get readingGroupHow => 'אופן הקריאה';

  @override
  String get readingGroupSpecialDays => 'ימים מיוחדים';

  @override
  String get themeLabel => 'ערכת צבעים';

  @override
  String get themeSystem => 'לפי המכשיר';

  @override
  String get themeSystemDesc => 'בהירה או כהה, כמו המכשיר';

  @override
  String get themeUsedWhenLight => 'בשימוש כשהמכשיר במצב בהיר';

  @override
  String get themeUsedWhenDark => 'בשימוש כשהמכשיר במצב כהה';

  @override
  String get themeLight => 'בהירה';

  @override
  String get themeDark => 'כהה';

  @override
  String get themeSepia => 'ספיה';

  @override
  String get themeHc => 'ניגודיות גבוהה';

  @override
  String get themeHcLight => 'ניגודיות גבוהה — בהירה';

  @override
  String get themeHcDark => 'ניגודיות גבוהה — כהה';

  @override
  String get scriptureFontLabel => 'גופן המקרא';

  @override
  String get fontNotoSerif => 'נוטו סריף עברי';

  @override
  String get fontTaamey => 'טעמי פרנק (חומש קלאסי)';

  @override
  String get fontEzra => 'עזרא SIL';

  @override
  String get fontNotoSans => 'נוטו סנס עברי (ללא תגים)';

  @override
  String get readingSize => 'גודל הקריאה';

  @override
  String readingSizeValue(int percent) {
    return '$percent%';
  }

  @override
  String get lineSpacing => 'ריווח שורות';

  @override
  String get wordSpacing => 'ריווח מילים';

  @override
  String get letterSpacing => 'ריווח אותיות';

  @override
  String get displayGroupSize => 'גודל וריווח';

  @override
  String get displayGroupText => 'טקסט';

  @override
  String get displayGroupStudy => 'עזרי לימוד';

  @override
  String get displayGroupReading => 'קריאה';

  @override
  String decreaseSetting(String name) {
    return 'הקטנת $name';
  }

  @override
  String increaseSetting(String name) {
    return 'הגדלת $name';
  }

  @override
  String get showNikud => 'ניקוד';

  @override
  String get showTeamim => 'טעמי המקרא';

  @override
  String get showKetiv => 'הצגת הכתיב';

  @override
  String get showVerseNumbers => 'מספרי פסוקים';

  @override
  String get justifyText => 'יישור לשני הצדדים';

  @override
  String get justifyHelp =>
      'במצב אוטומטי, עברית וארמית מיושרות לשני הצדדים בטור רחב, כמו בחומש מודפס.';

  @override
  String get justifyAuto => 'אוטומטי';

  @override
  String get justifyAlways => 'תמיד';

  @override
  String get justifyNever => 'אף פעם';

  @override
  String get lineWidthLabel => 'רוחב שורה';

  @override
  String get lineNarrow => 'צר';

  @override
  String get lineMedium => 'בינוני';

  @override
  String get lineWide => 'רחב';

  @override
  String get showTranslation => 'תרגום לאנגלית (עזר ללימוד)';

  @override
  String get showRashi => 'הצגת רש״י לצד הטקסט';

  @override
  String get rashiScript => 'כתב רש״י';

  @override
  String get rashiScriptDesc => 'פירוש רש״י בכתב שבו הוא מודפס בחומש';

  @override
  String get uiFontLabel => 'גופן הממשק';

  @override
  String get uiFontStandard => 'רגיל';

  @override
  String get uiFontAtkinson => 'Atkinson Hyperlegible';

  @override
  String get uiFontLexend => 'Lexend';

  @override
  String get uiFontOpenDyslexic => 'OpenDyslexic';

  @override
  String get uiFontSystem => 'גופן המכשיר';

  @override
  String get boldText => 'טקסט מודגש';

  @override
  String get focusMode => 'מצב מיקוד';

  @override
  String get focusModeDesc => 'הדגשת הפסוק הנוכחי ועמעום השאר';

  @override
  String get sideBySide => 'זה לצד זה';

  @override
  String get sideBySideDesc =>
      'במסך רחב, הטקסט המלא מציג את תרגום אונקלוס, או את התרגום לאנגלית, בטור לצד כל פסוק';

  @override
  String get keepScreenOn => 'השארת המסך דלוק בזמן קריאה';

  @override
  String get previewLabel => 'תצוגה מקדימה';

  @override
  String get reduceMotion => 'הפחתת תנועה';

  @override
  String get reduceMotionDesc => 'כיבוי אנימציות וחגיגות נעות';

  @override
  String get settingOnInDevice => 'מופעל בהגדרות המכשיר';

  @override
  String get haptics => 'משוב רטט';

  @override
  String get singleKeyShortcuts => 'קיצורי מקש יחיד';

  @override
  String get singleKeyShortcutsDesc =>
      'בזמן הקריאה, המקשים T,‏ N,‏ L,‏ + ומינוס פועלים בלחיצה אחת, בלי Ctrl. כדאי לכבות את האפשרות אם משתמשים בקלט קולי או במקשים המהירים של קורא מסך.';

  @override
  String get screenReaderText => 'טקסט לקורא מסך';

  @override
  String get srSimplified => 'עם ניקוד, בלי טעמים (מומלץ)';

  @override
  String get srConsonants => 'אותיות בלבד';

  @override
  String get srAllMarks => 'כל הסימנים (לצג ברייל)';

  @override
  String get divineNameLabel => 'הגיית השם';

  @override
  String get divineAdonai => 'א-דני';

  @override
  String get divineHashem => 'השם';

  @override
  String get speechRate => 'קצב הקראה';

  @override
  String get presetsTitle => 'הגדרות מהירות';

  @override
  String get presetLargePrint => 'אותיות גדולות';

  @override
  String get presetDyslexia => 'ידידותי לדיסלקציה';

  @override
  String get presetHighContrast => 'ניגודיות גבוהה';

  @override
  String get presetLowVision => 'ראייה ירודה';

  @override
  String get presetReset => 'איפוס התצוגה';

  @override
  String get presetLargePrintDesc => 'טקסט גדול ומרווח';

  @override
  String get presetDyslexiaDesc => 'גופן ברור, בלי טעמים';

  @override
  String get presetHighContrastDesc => 'ניגודיות חזקה והדגשה';

  @override
  String get presetLowVisionDesc => 'טקסט גדול מאוד וניגודיות גבוהה';

  @override
  String presetApplied(String name) {
    return 'הוחל: $name';
  }

  @override
  String get displayResetDone => 'הגדרות התצוגה אופסו';

  @override
  String get a11yGroupMotion => 'תנועה ומגע';

  @override
  String get a11yGroupMore => 'הצהרה ומשוב';

  @override
  String get accessibilityStatement => 'הצהרת נגישות';

  @override
  String get sendFeedback => 'שליחת משוב';

  @override
  String get dailyReminder => 'תזכורת יומית';

  @override
  String get dailyReminderDesc => 'תזכורת עדינה בשעה שבחרת';

  @override
  String get dailyReminderDescCity =>
      'תזכורת עדינה בשעה שבחרת, או לפני הדלקת הנרות בערב שבת או יום טוב';

  @override
  String get dailyReminderTime => 'שעת התזכורת היומית';

  @override
  String get fridayReminder => 'תזכורת לערב שבת';

  @override
  String get fridayReminderDesc => 'ביום שישי בבוקר, רק אם הפרשה לא הושלמה';

  @override
  String get fridayReminderDescCity =>
      'ביום שישי, שלוש שעות לפחות לפני הדלקת הנרות, רק אם הפרשה לא הושלמה';

  @override
  String get fridayReminderTime => 'שעת התזכורת לערב שבת';

  @override
  String get checkInReminder => 'תזכורת אחרי שבת או יום טוב';

  @override
  String get checkInReminderDesc =>
      'בבוקר שאחרי שבת או שמחת תורה, לרשום מה שקראת בהם';

  @override
  String get checkInReminderDescCity =>
      'שעה אחרי צאת השבת או שמחת תורה, או למחרת בבוקר כשהם יוצאים מאוחר, לרשום מה שקראת בהם';

  @override
  String get remindersShabbatNote =>
      'לעולם לא בשבת וביום טוב, ולכל היותר פעם ביום.';

  @override
  String remindersShabbatNoteCity(String city) {
    return 'לעולם לא בשבת וביום טוב, ולכל היותר פעם ביום. התזכורות מותאמות לזמני השבת של $city.';
  }

  @override
  String get reminderCityOffer =>
      'בחירת עיר תתאים את התזכורות לזמני השבת שלה: לפני הדלקת הנרות ביום שישי, ואחרי צאת השבת.';

  @override
  String get reminderCityChoose => 'בחירת עיר';

  @override
  String get remindersOnCityOffer =>
      'התזכורות פועלות. בחירת עיר תתאים אותן לזמני השבת שלה.';

  @override
  String get habitAnchorLabel => 'אחרי ש…';

  @override
  String get habitAnchorPrompt =>
      'כדאי לקשור את הקריאה למשהו שכבר עושים כל יום.';

  @override
  String get anchorShacharit => 'אסיים שחרית';

  @override
  String get anchorBreakfast => 'אאכל ארוחת בוקר';

  @override
  String get anchorCommute => 'אצא לדרך';

  @override
  String get anchorDinner => 'אסיים ארוחת ערב';

  @override
  String get anchorBed => 'אתכונן לשינה';

  @override
  String get anchorCueShacharit => 'אחרי שחרית';

  @override
  String get anchorCueBreakfast => 'אחרי ארוחת הבוקר';

  @override
  String get anchorCueCommute => 'בדרך';

  @override
  String get anchorCueDinner => 'אחרי ארוחת הערב';

  @override
  String get anchorCueBed => 'לפני השינה';

  @override
  String get notificationsUnsupported =>
      'תזכורות דורשות את האפליקציה המותקנת, בטלפון או במחשב. כאן אפשר לראות אילו תזכורות היא שולחת.';

  @override
  String get getTheApp => 'להורדת האפליקציה';

  @override
  String get notificationsDenied =>
      'ההתראות לאפליקציה זו כבויות בהגדרות המכשיר.';

  @override
  String get notificationsDeniedTitle => 'ההתראות כבויות';

  @override
  String get openSystemSettings => 'פתיחת ההגדרות';

  @override
  String reminderMoveHint(String time, String usual) {
    return 'התזכורת מגיעה ב־$time. להעביר ל־$usual?';
  }

  @override
  String get reminderMove => 'העברה';

  @override
  String get primingTitle => 'רוצה תזכורת יומית עדינה?';

  @override
  String get primingBody =>
      'לעולם לא בשבת וביום טוב, ולכל היותר אחת ביום. אפשר לשנות בכל עת.';

  @override
  String reminderAtTime(String time) {
    return 'בשעה $time';
  }

  @override
  String get primingYes => 'כן, להזכיר לי';

  @override
  String get notifChannelDaily => 'קריאה יומית';

  @override
  String get notifChannelFriday => 'ערב שבת';

  @override
  String get notifChannelCheckIn => 'אחרי שבת ויום טוב';

  @override
  String get notifChannelDailyDesc =>
      'הקריאה של היום בשעה שבחרת, אף פעם לא בשבת או ביום טוב';

  @override
  String get notifChannelErevShabbatDesc =>
      'לפני שבת או יום טוב, רק אם הפרשה לא הושלמה';

  @override
  String get notifChannelCheckInDesc =>
      'אחרי שבת או שמחת תורה: תזכורת לרשום מה שנקרא, וגם הודעה כשהתזכורות נעצרות';

  @override
  String notifDailyTitle(String aliyah) {
    return 'היום: $aliyah';
  }

  @override
  String notifDailyBody(String parsha, String verses, int minutes) {
    return 'פרשת $parsha · $verses · כ־$minutes דק׳';
  }

  @override
  String notifDailyAnchor(String cue) {
    return '$cue — זה הזמן שלך.';
  }

  @override
  String notifFridayTitle(String parsha) {
    return 'ערב שבת · פרשת $parsha';
  }

  @override
  String get notifFridayBody =>
      'יש עוד זמן — אפשר גם לסיים בשבת בבוקר מתוך חומש ולרשום אחרי שבת.';

  @override
  String get notifFridayBodyThenYomTov =>
      'יש עוד זמן — אפשר גם לסיים בשבת בבוקר מתוך חומש ולרשום אחרי החג.';

  @override
  String notifErevTitle(String eve, String parsha) {
    return '$eve · פרשת $parsha';
  }

  @override
  String get notifErevYomTovBody =>
      'יש עוד זמן — אפשר גם לסיים בחג או בשבת מתוך חומש ולרשום אחרי שבת.';

  @override
  String get notifCheckInTitle => 'שבוע טוב!';

  @override
  String get notifCheckInBody => 'קראת בשבת? אפשר לרשום זאת באפליקציה.';

  @override
  String get notifCheckInBodyShabbatYomTov =>
      'קראת בשבת וביום טוב? אפשר לרשום זאת באפליקציה.';

  @override
  String get notifCheckInBodyVezot =>
      'קראת אותה ביום טוב? אפשר לרשום זאת באפליקציה.';

  @override
  String get notifCheckInBodySimchatTorah =>
      'קראת אותה בשמחת תורה? אפשר לרשום זאת באפליקציה.';

  @override
  String get notifPausedTitle => 'התזכורות הושהו';

  @override
  String notifPausedBody(String parsha) {
    return 'נשהה את התזכורות לעת עתה. המקום שלך בפרשת $parsha שמור — אפשר לחזור בכל עת.';
  }

  @override
  String get showStreaks => 'הצגת מספרי הרצף';

  @override
  String get showStreaksDesc => 'אפשר להסתיר אותם כדי להתמקד בלימוד עצמו';

  @override
  String get exportData => 'ייצוא ההתקדמות שלי';

  @override
  String get exportDataDesc =>
      'שמירת גיבוי של ההתקדמות, הסימניות וההערות, לשחזור מאוחר יותר';

  @override
  String get importData => 'ייבוא התקדמות';

  @override
  String get importDataDesc => 'שחזור מקובץ גיבוי';

  @override
  String get importPrompt => 'יש להדביק את תוכן קובץ הגיבוי.';

  @override
  String get importSuccess => 'ההתקדמות יובאה.';

  @override
  String get importFailed => 'לא ניתן היה לקרוא את הגיבוי.';

  @override
  String get exportCopied => 'הגיבוי הועתק ללוח.';

  @override
  String get resetProgress => 'איפוס כל ההתקדמות';

  @override
  String get resetProgressConfirm =>
      'פעולה זו מוחקת את היסטוריית הקריאה והרצפים במכשיר זה. אי אפשר לבטל אותה.';

  @override
  String get resetProgressConfirmSynced =>
      'פעולה זו מוחקת את היסטוריית הקריאה והרצפים במכשיר זה, בגיבוי ובמכשירים האחרים שלך כשיסונכרנו בפעם הבאה. אי אפשר לבטל אותה.';

  @override
  String get resetDone => 'ההתקדמות אופסה.';

  @override
  String get languageSystem => 'שפת המכשיר';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageHebrew => 'עברית';

  @override
  String get languageDevice => 'לפי המכשיר';

  @override
  String get dataGroupBackup => 'גיבוי ושחזור';

  @override
  String get aboutTitle => 'אודות';

  @override
  String versionLabel(String version) {
    return 'גרסה $version';
  }

  @override
  String get sourcesTitle => 'טקסטים ומקורות';

  @override
  String get licensesTitle => 'רישיונות קוד פתוח';

  @override
  String get privacyTitle => 'פרטיות';

  @override
  String get termsTitle => 'תנאי שימוש';

  @override
  String get guidelinesTitle => 'כללי הקהילה';

  @override
  String get contactTitle => 'כתיבה אלינו בדוא״ל';

  @override
  String get aboutGroupLearn => 'לעיון';

  @override
  String get aboutGroupPolicies => 'מדיניות';

  @override
  String get aboutGroupContact => 'יצירת קשר';

  @override
  String get copySupportDetails => 'העתקת פרטים לתמיכה';

  @override
  String get copySupportDetailsDesc =>
      'מה שהשתבש מאז שהאפליקציה נפתחה, להדבקה בהודעה אלינו';

  @override
  String get supportDetailsCopied => 'הפרטים הועתקו';

  @override
  String get webUpdateReady => 'גרסה חדשה מוכנה.';

  @override
  String get webUpdateRestart => 'הפעלה מחדש';

  @override
  String get errorPanelMessage => 'חלק מהדף לא נטען.';

  @override
  String get startFailedTitle => 'לא ניתן היה לפתוח את שניים מקרא.';

  @override
  String get startFailedReopen => 'סגירת האפליקציה ופתיחתה מחדש עשויה לעזור.';

  @override
  String get startFailedReload => 'כדאי לבדוק את החיבור לאינטרנט ולנסות שוב.';

  @override
  String startFailedWriteTo(String address) {
    return 'אם זה לא עוזר, אפשר להעתיק את הפרטים ולשלוח אותם אל $address.';
  }

  @override
  String get startFailedWriteToUs =>
      'אם זה לא עוזר, אפשר להעתיק את הפרטים ולשלוח אותם אלינו.';

  @override
  String get linkOpenFailed => 'לא ניתן היה לפתוח את הקישור כאן.';

  @override
  String emailOpenFailed(String address) {
    return 'לא נפתחה תוכנת דואר. אפשר לכתוב אל $address.';
  }

  @override
  String get actionCopy => 'העתקה';

  @override
  String get feedbackLinkLabel => 'דף התקלות ב־GitHub';

  @override
  String legalLastUpdated(String date) {
    return 'עודכן לאחרונה: $date';
  }

  @override
  String get guideTitle => 'איך זה עובד';

  @override
  String get disclaimer => 'המנהגים שונים. בשאלות מעשיות יש לשאול רב.';

  @override
  String get onbWelcomeBody =>
      'קוראים את הפרשה פעמיים ואת התרגום פעם אחת — עלייה ליום, ומסיימים לפני שבת.';

  @override
  String get onbStart => 'להתחיל את פרשת השבוע';

  @override
  String get onbLocationTitle => 'היכן תהיו בשבת הקרובה?';

  @override
  String get onbMethodTitle => 'איך לקרוא?';

  @override
  String get onbPlanTitle => 'התוכנית השבועית שלך';

  @override
  String get onbHonor =>
      'שניים מקרא פועל על בסיס אמון. רושמים מה שקוראים, היכן שקוראים — חומש בבית הכנסת נחשב בדיוק כמו האפליקציה.';

  @override
  String get onbChangeAnytime => 'אפשר לשנות זאת בכל עת בהגדרות.';

  @override
  String onbStep(int current, int total) {
    return 'שלב $current מתוך $total';
  }

  @override
  String get onbWhyAsk => 'למה אנחנו שואלים';

  @override
  String get guideWhatTitle => 'מהו שניים מקרא?';

  @override
  String get guideQuoteSource => 'ברכות ח, א';

  @override
  String get guideQuoteTranslation =>
      'לעולם ישלים אדם את פרשיותיו עם הציבור: המקרא פעמיים והתרגום פעם אחת.';

  @override
  String get guideWhatBody =>
      'השולחן ערוך פוסק את דברי הגמרא להלכה (אורח חיים סימן רפה): בכל שבוע משלימים בעצמם, בקצב הציבור, את הפרשה שנקראת בשבת בבית הכנסת.';

  @override
  String get guideWhenTitle => 'מתי';

  @override
  String get guideWhenBody =>
      'אפשר להתחיל ביום ראשון (ויש אומרים כבר משבת אחר הצהריים). לכתחילה מסיימים לפני סעודת שחרית של שבת, ואם לא, אחרי הסעודה עד מנחה. אחר כך אפשר עדיין להשלים עד ליל רביעי (״עד יום רביעי״), ופרשות שהוחמצו אפשר להשלים עד שמחת תורה (שו״ע רפה, ד; מ״ב רפה, יב).';

  @override
  String get guideHowTitle => 'כיצד';

  @override
  String get guideHowBody =>
      'קוראים פסוק פסוק — כל פסוק פעמיים ואחריו התרגום — או פרשה פרשה, כל פרשה פעמיים ואחריה התרגום. רבים חוזרים על הפסוק האחרון בעברית כדי לסיים במקרא. מומלץ לקרוא בקול ובטעמים, אם אפשר.';

  @override
  String get guidePassesCaption => '1 · מקרא  2 · מקרא  3 · תרגום';

  @override
  String get guideTargumTitle => 'תרגום או רש״י';

  @override
  String get guideTargumBody =>
      'פירוש רש״י יכול לבוא במקום התרגום, מפני שהוא מפרש את המקרא; וירא שמים יקרא את שניהם (שו״ע רפה, ב). תרגום פשוט הוא עזר מועיל ללימוד, אך אינו תחליף לתרגום. אם לשונו של רש״י אינה מובנת, אפשר לקרוא את רש״י בשפה מובנת (מ״ב רפה, ה; הרב משה פיינשטיין). יש לשאול רב.';

  @override
  String get guideSpecialTitle => 'מקרים מיוחדים';

  @override
  String get guideSpecialBody =>
      'עטרות ודיבון (במדבר לב, ג): אונקלוס מביא בעיקר את שמות המקומות בארמית, ולכן רבים קוראים את הפסוק גם פעם שלישית בעברית, בעקבות רש״י (ברכות ח, ב).\nוזאת הברכה: קוראים אותה עד קריאתה בבית הכנסת בשמחת תורה, ובמיוחד בהושענא רבה; גם בשמיני עצרת יוצאים.\nההפטרה: רבים קוראים גם את הפטרת השבוע פעם אחת.\nבבית הכנסת: קריאה בלחש עם בעל הקורא, מילה במילה, נחשבת לאחת מקריאות המקרא (מ״ב רפה, יד).\nשתי פרשות: בשבוע שבו שתי פרשות מחוברות קוראים את שתיהן. כשבארץ ישראל ובחוץ לארץ קוראים פרשות שונות, הנוסעים נוהגים בדרך כלל לקרוא את שתיהן.\nבלי ברכה: אין מברכים על הקריאה.\nנשים וילדים: נשים פטורות, ומי שמקבלת על עצמה את המנהג עושה זאת כמצווה שאינה חובה; את הבנים מחנכים לכך מגיל חינוך.';

  @override
  String get guideShabbatTitle => 'שבת ויום טוב';

  @override
  String get guideShabbatBody =>
      'האפליקציה לעולם אינה מבקשת לפתוח אותה בשבת וביום טוב. הרצפים מושהים בימים אלה, אין תזכורות, ואת מה שנקרא מתוך חומש מודפס אפשר לרשום אחר כך.';

  @override
  String get guideSourcesTitle => 'מקורות';

  @override
  String get guideSourcesBody =>
      'ברכות ח, א–ב\nשולחן ערוך, אורח חיים רפה\nמשנה ברורה רפה\nקיצור שולחן ערוך עב\nשולחן ערוך הרב רפה';

  @override
  String hebrewDateLabel(String date) {
    return 'תאריך עברי: $date';
  }

  @override
  String get communityTitle => 'קהילה';

  @override
  String get demoModeBanner =>
      'מצב הדגמה: ההודעות נשמרות במכשיר זה בלבד ומתאפסות בהפעלה מחדש.';

  @override
  String get forumsHeading => 'פורומים';

  @override
  String get forumNotFound => 'הפורום לא נמצא. ייתכן שהועבר או נסגר.';

  @override
  String get allForums => 'כל הפורומים';

  @override
  String get threadNotFound => 'הדיון לא נמצא. ייתכן שנמחק.';

  @override
  String thisWeeksThread(String name) {
    return 'השבוע: פרשת $name';
  }

  @override
  String weeklyThreadTitle(String name, String year) {
    return 'פרשת $name $year';
  }

  @override
  String get openDiscussion => 'לדיון';

  @override
  String get signInPrompt => 'יש להתחבר כדי לכתוב, להודות או לדווח.';

  @override
  String get settingsAccountDesc => 'התחברות כדי לכתוב, להודות או לדווח';

  @override
  String signedInAs(String name) {
    return 'התחברת בשם $name';
  }

  @override
  String get signInTitle => 'כניסה';

  @override
  String get signInBody => 'נשלח אליך בדוא״ל קוד בן 6 ספרות — ללא סיסמה.';

  @override
  String get emailLabel => 'כתובת דוא״ל';

  @override
  String get sendCodeAction => 'שליחת קוד';

  @override
  String codeSentTo(String email) {
    return 'שלחנו קוד בן 6 ספרות אל $email.';
  }

  @override
  String get codeLabel => 'קוד בן 6 ספרות';

  @override
  String get verifyAction => 'כניסה';

  @override
  String get useDifferentEmail => 'שימוש בכתובת אחרת';

  @override
  String get demoCodeHint => 'מצב הדגמה: כל 6 ספרות יעבדו.';

  @override
  String get displayNameLabel => 'שם תצוגה';

  @override
  String get displayNameHelp => 'מוצג עם ההודעות שלך. ⁦2–40⁩ תווים.';

  @override
  String get saveName => 'שמירת השם';

  @override
  String get nameSaved => 'השם נשמר.';

  @override
  String get syncProgress => 'גיבוי ההתקדמות שלי';

  @override
  String get syncProgressDesc =>
      'שמירת התקדמות הקריאה, הסימניות וההערות בחשבון, ושחזורן במכשירים אחרים.';

  @override
  String get syncNow => 'סנכרון עכשיו';

  @override
  String get syncDone => 'ההתקדמות סונכרנה.';

  @override
  String get syncFailed => 'לא ניתן לסנכרן כעת. ננסה שוב מאוחר יותר.';

  @override
  String get syncNeedsUpdate =>
      'הגיבוי נשמר בגרסה חדשה יותר של האפליקציה. יש לעדכן את האפליקציה כדי להמשיך לסנכרן.';

  @override
  String get syncTooLarge =>
      'ההערות שלך ארוכות מכדי לגבות אותן בחשבון, ולכן שום דבר חדש אינו מגובה. כדאי לקצר או למחוק חלק מהן; קובץ גיבוי, מ״הנתונים שלך״, שומר את כולן.';

  @override
  String lastSynced(String time) {
    return 'סונכרן לאחרונה: $time';
  }

  @override
  String get deleteAccount => 'מחיקת החשבון';

  @override
  String get deleteAccountConfirm =>
      'פעולה זו מוחקת לצמיתות את החשבון, הפרופיל, ההודעות שלך ואת הגיבוי בענן של ההתקדמות, הסימניות וההערות. דיון שפתחת ואחרים הגיבו בו נשאר, בלי שמך. מה שבמכשיר זה נשמר, וגם מה שבמכשירים אחרים. אי אפשר לבטל זאת.';

  @override
  String get accountDeleted => 'החשבון נמחק.';

  @override
  String get newThread => 'דיון חדש';

  @override
  String get threadTitleLabel => 'כותרת';

  @override
  String get threadBodyLabel => 'ההודעה שלך';

  @override
  String get forumLabel => 'פורום';

  @override
  String get postAction => 'פרסום';

  @override
  String get replyLabel => 'כתיבת תגובה';

  @override
  String get replyAction => 'תגובה';

  @override
  String replyingTo(String name) {
    return 'בתגובה ל$name';
  }

  @override
  String todahCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count תודות',
      one: 'תודה אחת',
    );
    return '$_temp0';
  }

  @override
  String todahSemantics(String name) {
    return 'תודה ל$name';
  }

  @override
  String todahRemove(String name) {
    return 'ביטול התודה ל$name';
  }

  @override
  String get reportTitle => 'דיווח על ההודעה';

  @override
  String get reportReasonLabel => 'מה הבעיה?';

  @override
  String get reasonSpam => 'ספאם או פרסום';

  @override
  String get reasonLashonHara => 'לשון הרע או רכילות';

  @override
  String get reasonDisrespect => 'חוסר כבוד או פגיעה';

  @override
  String get reasonMisinformation => 'מטעה בהלכה או במקורות';

  @override
  String get reasonOffTopic => 'לא קשור לנושא';

  @override
  String get reasonOther => 'משהו אחר';

  @override
  String get reportDetails => 'פרטים (לא חובה)';

  @override
  String get reportSent => 'תודה. צוות הניהול יבדוק את הדיווח.';

  @override
  String blockUser(String name) {
    return 'חסימת $name';
  }

  @override
  String blockConfirm(String name) {
    return 'ההודעות של $name לא יוצגו, ולא תישלח על כך התראה ל־$name.';
  }

  @override
  String get blockedDone => 'נחסם.';

  @override
  String get unblock => 'ביטול חסימה';

  @override
  String get blockedUsersTitle => 'משתמשים חסומים';

  @override
  String get edited => 'נערך';

  @override
  String get editPostTitle => 'עריכת הודעה';

  @override
  String get deletePostConfirm => 'למחוק את ההודעה?';

  @override
  String get cantBeUndone => 'אי אפשר לבטל פעולה זו.';

  @override
  String get postDeleted => 'ההודעה נמחקה.';

  @override
  String get posted => 'פורסם.';

  @override
  String get viewPostedThread => 'לדיון';

  @override
  String get pendingReview => 'מוסתרת — ממתינה לבדיקת צוות הניהול';

  @override
  String get lockedThread => 'הדיון נעול.';

  @override
  String get pinnedLabel => 'נעוץ';

  @override
  String get lockedLabel => 'נעול';

  @override
  String get lockThread => 'נעילת הדיון';

  @override
  String get unlockThread => 'פתיחת הדיון';

  @override
  String get pinThread => 'נעיצה למעלה';

  @override
  String get unpinThread => 'ביטול נעיצה';

  @override
  String get copyLink => 'העתקת קישור';

  @override
  String get linkCopied => 'הקישור הועתק';

  @override
  String get hidePost => 'הסתרת הודעה';

  @override
  String get moderationQueue => 'דיווחים לבדיקה';

  @override
  String get noReports => 'אין דיווחים פתוחים.';

  @override
  String get removePost => 'הסרת ההודעה';

  @override
  String get dismissReport => 'דחייה';

  @override
  String get guidelinesAccept => 'אקפיד על כללי הקהילה';

  @override
  String get guidelinesPrompt =>
      'לפני ההודעה הראשונה, נא לקרוא את כללי הקהילה.';

  @override
  String get readGuidelines => 'לכללי הקהילה';

  @override
  String noPostsYet(String name) {
    return 'אין עדיין הודעות — אפשר לשתף מחשבה על פרשת $name.';
  }

  @override
  String get noReplies => 'אין עדיין תגובות.';

  @override
  String get loadMore => 'טעינת עוד';

  @override
  String loadedMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'נטענו עוד $count דיונים',
      one: 'נטען עוד דיון אחד',
    );
    return '$_temp0';
  }

  @override
  String get showEarlierPosts => 'הצגת הודעות קודמות';

  @override
  String postsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count הודעות',
      one: 'הודעה אחת',
      zero: 'אין עדיין הודעות',
    );
    return '$_temp0';
  }

  @override
  String threadThanksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count תודות',
      one: 'תודה אחת',
    );
    return '$_temp0';
  }

  @override
  String forumDiscussionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count דיונים',
      one: 'דיון אחד',
      zero: 'אין עדיין דיונים',
    );
    return '$_temp0';
  }

  @override
  String forumActive(String time) {
    return 'פעילות אחרונה: $time';
  }

  @override
  String get timeJustNow => 'הרגע';

  @override
  String timeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'לפני $count דקות',
      one: 'לפני דקה',
    );
    return '$_temp0';
  }

  @override
  String timeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'לפני $count שעות',
      two: 'לפני שעתיים',
      one: 'לפני שעה',
    );
    return '$_temp0';
  }

  @override
  String postedBy(String name, String time) {
    return '$name, $time';
  }

  @override
  String postNofM(int n, int total) {
    return 'הודעה $n מתוך $total';
  }

  @override
  String get anonymousMember => 'חשבון שנמחק';

  @override
  String get errRateLimited => 'הודעות נשלחות מהר מדי — נא להמתין כמה שניות.';

  @override
  String get errThreadLocked => 'הדיון נעול.';

  @override
  String get errTerms => 'יש לאשר קודם את כללי הקהילה.';

  @override
  String get errBanned => 'החשבון שלך אינו יכול לפרסם.';

  @override
  String get errSilenced => 'הפרסום מושהה לחשבונך לעת עתה.';

  @override
  String get errContent => 'לא ניתן לפרסם הודעה זו. נא לעיין בכללי הקהילה.';

  @override
  String get errDuplicate => 'כבר פרסמת זאת.';

  @override
  String get errLinks => 'חברים חדשים יכולים לכלול עד 2 קישורים.';

  @override
  String get errDailyLimit => 'לחברים חדשים יש מגבלה יומית. נא לנסות שוב מחר.';

  @override
  String get errNameTaken => 'השם תפוס.';

  @override
  String get errAlreadyReported => 'כבר דיווחת על ההודעה הזאת.';

  @override
  String get errInvalidName => 'השם צריך להכיל ⁦2–40⁩ תווים.';

  @override
  String get errInvalidCode => 'הקוד לא התקבל. נא לבדוק ולנסות שוב.';

  @override
  String get errInvalidEmail => 'נא להזין כתובת דוא״ל תקינה.';

  @override
  String get errNotSignedIn => 'יש להתחבר תחילה.';

  @override
  String get errForbidden => 'אין לך הרשאה לפעולה זו.';

  @override
  String get errShabbat => 'הפרסום סגור בשבת.';

  @override
  String get errTooShort => 'נא לכתוב מעט יותר.';

  @override
  String get errTitleTooShort => 'הכותרת צריכה להכיל לפחות 5 תווים.';

  @override
  String get errNetwork =>
      'לא ניתן להתחבר לשרת. נא לבדוק את החיבור ולנסות שוב.';

  @override
  String get moderatorBadge => 'צוות ניהול';

  @override
  String get draftRestored => 'הטיוטה שלך שוחזרה.';

  @override
  String get discardDraft => 'מחיקת הטיוטה';

  @override
  String questionOnVerse(String reference) {
    return 'שאלה על $reference';
  }

  @override
  String askDraftKept(String reference) {
    return 'הטיוטה שלא נשלחה נשמרה. אפשר למחוק אותה כדי לשאול על $reference במקומה.';
  }

  @override
  String get removeVerseQuote => 'הסרת הפסוק';

  @override
  String get verseQuoteRemoved => 'הפסוק הוסר';

  @override
  String charactersLeft(int count) {
    return 'נותרו $count תווים';
  }

  @override
  String get shabbatTimesLabel => 'זמני שבת';

  @override
  String get shabbatTimesHelp =>
      'בחירת עיר מציגה מתי מדליקים נרות ומתי יוצאת השבת. הזמנים מחושבים במכשיר, והעיר נשמרת בו בלבד.';

  @override
  String get cityLabel => 'עיר';

  @override
  String get cityNotSet => 'לא נבחרה';

  @override
  String shabbatTimesSummary(String candles, String ends) {
    return 'הדלקת נרות $candles\nצאת השבת $ends';
  }

  @override
  String shabbatCandlesOnly(String candles) {
    return 'הדלקת נרות $candles';
  }

  @override
  String get shabbatNoSunset =>
      'אין שם שקיעה בשבת הקרובה. על הזמנים יש לשאול רב.';

  @override
  String get shabbatTimesUnavailable =>
      'המכשיר אינו יודע מה השעה בעיר הזו, ולכן אי אפשר להציג את הזמנים בה.';

  @override
  String get cityPickerTitle => 'בחירת עיר';

  @override
  String get citySearchLabel => 'חיפוש עיר';

  @override
  String get citySearchClear => 'ניקוי החיפוש';

  @override
  String get cityYours => 'העיר שלך';

  @override
  String get cityNone => 'ללא עיר';

  @override
  String get cityNoneDesc => 'זמני השבת לא יוצגו';

  @override
  String get cityNearYou => 'באזור הזמן שלך';

  @override
  String cityNoResults(String query) {
    return 'לא נמצאה עיר בשם ״$query״.';
  }

  @override
  String cityResultsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'נמצאו $count ערים',
      one: 'נמצאה עיר אחת',
      zero: 'לא נמצאו ערים',
    );
    return '$_temp0';
  }

  @override
  String cityResultsMore(int shown, int count) {
    return 'מוצגות $shown התוצאות הראשונות מתוך $count. אפשר להקליד עוד מהשם כדי למצוא את האחרות.';
  }

  @override
  String get cityListNote =>
      'ברשימה כל מקום שגרים בו 100,000 איש ומעלה, כל הערים בישראל והיישובים הישראליים הגדולים שמעבר לקו הירוק. אם המקום שלך אינו ברשימה, אפשר לבחור את הקרוב אליו; מעבר לקו הירוק, את היישוב הישראלי הקרוב.';

  @override
  String get searchTitle => 'חיפוש בתורה';

  @override
  String get searchFieldLabel => 'מילה או ביטוי';

  @override
  String get searchClear => 'ניקוי החיפוש';

  @override
  String get searchIntro =>
      'אפשר למצוא מילה או ביטוי בתורה, בתרגום אונקלוס או בתרגום לאנגלית.';

  @override
  String get searchPreparing => 'מכינים את הטקסט לחיפוש…';

  @override
  String searchResultsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count פסוקים',
      one: 'פסוק אחד',
    );
    return '$_temp0';
  }

  @override
  String searchResultsFirst(int shown, int count) {
    return '$shown הפסוקים הראשונים מתוך $count';
  }

  @override
  String get searchNarrow => 'אפשר להוסיף מילה כדי לצמצם את החיפוש.';

  @override
  String searchNoResults(String query) {
    return 'לא נמצא פסוק עם ״$query״.';
  }

  @override
  String get searchNoResultsHint =>
      'כדאי לנסות פחות מילים, מילה אחרת או כתיב אחר.';

  @override
  String get searchNoResultsHintEnglish =>
      'כדאי לנסות פחות מילים, או את האנגלית הישנה של התרגום משנת 1917, למשל ״hath״ במקום ״has״.';

  @override
  String searchResultsAnnounced(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'נמצאו $count פסוקים',
      one: 'נמצא פסוק אחד',
      zero: 'לא נמצאו פסוקים',
    );
    return '$_temp0';
  }

  @override
  String get goToVerseLabel => 'פסוק, מילה או ביטוי';

  @override
  String goToVerseHint(String book) {
    return '$book כח, יב';
  }

  @override
  String goToVerseHelp(String example) {
    return 'אפשר לכתוב ספר או פרשה ואחריהם פרק ופסוק, למשל $example, או מילים לחיפוש.';
  }

  @override
  String goToVerseSearch(String query) {
    return 'חיפוש ״$query״';
  }

  @override
  String goToVerseChapters(String book, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count פרקים',
      one: 'פרק אחד',
    );
    return 'בספר $book $_temp0.';
  }

  @override
  String goToVerseVerses(String book, String chapter, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count פסוקים',
      one: 'פסוק אחד',
    );
    return 'בפרק $chapter בספר $book $_temp0.';
  }

  @override
  String get shortcutContinueReading => 'המשך קריאה';

  @override
  String get shortcutLogFromBook => 'רישום קריאה מתוך חומש';

  @override
  String get shortcutThisWeek => 'פרשת השבוע';

  @override
  String widgetToday(String aliyot) {
    return 'היום: $aliyot';
  }

  @override
  String widgetCatchUp(String aliyot) {
    return 'משלימים: $aliyot';
  }

  @override
  String get widgetNothingToday => 'אין קריאה מתוכננת להיום';

  @override
  String get widgetPaused => 'בהשהיה · אפשר לקרוא מתי שנוח';

  @override
  String get widgetWeekComplete => 'הפרשה הושלמה · יישר כוח!';

  @override
  String get widgetStale => 'יש לפתוח את האפליקציה כדי לעדכן';

  @override
  String simchatTorahInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'שמחת תורה בעוד $count ימים',
      two: 'שמחת תורה בעוד יומיים',
      one: 'שמחת תורה מחר',
      zero: 'שמחת תורה היום',
    );
    return '$_temp0';
  }

  @override
  String regularHaftarahOf(String portion) {
    return 'וגם: ההפטרה הרגילה של פרשת $portion';
  }

  @override
  String regularHaftarahSomeRead(String portion) {
    return 'ההפטרה הרגילה של פרשת $portion (יש הקוראים גם אותה)';
  }

  @override
  String haftarahSpecialChabadRegular(String reason) {
    return '$reason · מנהג חב״ד: גם ההפטרה הרגילה';
  }

  @override
  String get chabadFallbackNote =>
      'הפטרות חב״ד עדיין בבדיקה, ולכן מוצגת ההפטרה לפי מנהג אשכנז.';

  @override
  String get repeatLastVerseDescChabad =>
      'לחזור על הפסוק האחרון של הפרשה בעברית אחרי התרגום (במנהג חב״ד לא חוזרים עליו)';

  @override
  String get repeatLastVerseFollowsChabad =>
      'האפשרות ״לסיים במקרא״ כבויה עכשיו, כמנהג חב״ד.';

  @override
  String get repeatLastVerseBackOn => 'האפשרות ״לסיים במקרא״ פועלת שוב.';

  @override
  String get divineAdonaiSpoken => 'שם אדנות';

  @override
  String get importBackupText => 'טקסט הגיבוי';

  @override
  String get importPasteFailed =>
      'לא ניתן היה להדביק מהלוח. אפשר להדביק ישירות בשדה.';

  @override
  String get exportSaved => 'הגיבוי נשמר.';

  @override
  String get importPaste => 'הדבקת טקסט של גיבוי';

  @override
  String get importPasteDesc => 'לגיבוי שהועתק כטקסט';

  @override
  String get pasteFromClipboard => 'הדבקה מהלוח';

  @override
  String importSummary(String date, int weeks, int pauses) {
    String _temp0 = intl.Intl.pluralLogic(
      weeks,
      locale: localeName,
      other: 'קריאה מתועדת ב־$weeks שבועות',
      two: 'קריאה מתועדת בשבועיים',
      one: 'קריאה מתועדת בשבוע אחד',
      zero: 'אין קריאה מתועדת',
    );
    String _temp1 = intl.Intl.pluralLogic(
      pauses,
      locale: localeName,
      other: '$pauses השהיות',
      two: 'שתי השהיות',
      one: 'השהיה אחת',
      zero: 'ללא השהיות',
    );
    return 'גיבוי מ־$date: $_temp0, $_temp1.';
  }

  @override
  String importCounts(int weeks, int pauses) {
    String _temp0 = intl.Intl.pluralLogic(
      weeks,
      locale: localeName,
      other: 'קריאה מתועדת ב־$weeks שבועות',
      two: 'קריאה מתועדת בשבועיים',
      one: 'קריאה מתועדת בשבוע אחד',
      zero: 'אין קריאה מתועדת',
    );
    String _temp1 = intl.Intl.pluralLogic(
      pauses,
      locale: localeName,
      other: '$pauses השהיות',
      two: 'שתי השהיות',
      one: 'השהיה אחת',
      zero: 'ללא השהיות',
    );
    return '$_temp0, $_temp1.';
  }

  @override
  String importMarks(int bookmarks, int notes) {
    String _temp0 = intl.Intl.pluralLogic(
      bookmarks,
      locale: localeName,
      other: '$bookmarks סימניות',
      two: 'שתי סימניות',
      one: 'סימנייה אחת',
      zero: 'ללא סימניות',
    );
    String _temp1 = intl.Intl.pluralLogic(
      notes,
      locale: localeName,
      other: '$notes הערות',
      two: 'שתי הערות',
      one: 'הערה אחת',
      zero: 'ללא הערות',
    );
    return '$_temp0, $_temp1.';
  }

  @override
  String get importMergeBody =>
      'למזג את הגיבוי עם ההתקדמות שבמכשיר הזה? המיזוג שומר את כל מה שיש בשניהם.';

  @override
  String get importAlsoSettings => 'לשחזר גם את ההגדרות';

  @override
  String get importMerge => 'מיזוג';

  @override
  String get importReplace => 'החלפה במקום מיזוג';

  @override
  String get importReplaceTitle => 'להחליף את ההתקדמות שבמכשיר?';

  @override
  String get importReplaceConfirm =>
      'פעולה זו מוחקת את היסטוריית הקריאה והרצפים במכשיר זה, ומשאירה רק את מה שבגיבוי. אי אפשר לבטל אותה.';

  @override
  String get importReplaceConfirmSynced =>
      'פעולה זו מוחקת את היסטוריית הקריאה והרצפים במכשיר זה, בגיבוי בענן ובמכשירים האחרים שלך כשיסונכרנו בפעם הבאה, ומשאירה רק את מה שבגיבוי הזה. אי אפשר לבטל אותה.';

  @override
  String get importReplaceAction => 'החלפה';

  @override
  String get importSuccessRemindersOff =>
      'ההתקדמות יובאה. התזכורות כבויות, כי לאפליקציה אין הרשאה לשלוח התראות.';

  @override
  String get cloudBackup => 'גיבוי בענן';

  @override
  String get sourcesMamDescription =>
      'נוסח התורה וההפטרות, על פי כתר ארם צובה וכתבי יד קרובים, בעריכת אבי קדיש וחבריו בוויקיטקסט העברי, דרך ספריא. בתורה, במקומות שבהם ספרי התורה של אשכנז וספרד שונים מכתר ארם צובה, הנוסח הוא כספרי התורה, ונוסח הכתר מובא בהערה. מלבד זאת הותאם לתצוגה מובנית ללא שינוי בנוסח.';

  @override
  String get onbStarterTitle => 'השבוע';

  @override
  String get onbStarterCatchUp => 'לקרוא את כל הפרשה עד שבת';

  @override
  String onbStarterCatchUpDesc(int verses, int minutes, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'על פני $days ימים',
      two: 'על פני יומיים',
      one: 'היום',
    );
    return '$verses פסוקים · כ־$minutes דק׳ $_temp0';
  }

  @override
  String onbStarterCatchUpOn(int verses, int minutes, String day) {
    return '$verses פסוקים · כ־$minutes דק׳ ב$day';
  }

  @override
  String get onbStarterToday => 'להתחיל מהקריאה של היום';

  @override
  String get onbStarterTodayDesc => 'התוכנית המלאה מהשבוע הבא';

  @override
  String get onbRestore => 'שחזור התקדמות קיימת';

  @override
  String get onbRestoreTitle => 'שחזור ההתקדמות';

  @override
  String get onbRestoreSignIn => 'כניסה לחשבון ושחזור';

  @override
  String get onbRestoreSignInDesc => 'מהגיבוי שנשמר בחשבון';

  @override
  String get onbRestoreFile => 'שחזור מקובץ גיבוי';

  @override
  String get onbRestoreFileDesc => 'קובץ גיבוי שנשמר מההגדרות';

  @override
  String get onbRestoring => 'משחזרים את ההתקדמות…';

  @override
  String get onbRestoreDone => 'ההתקדמות שוחזרה.';

  @override
  String get onbRestoreDoneRemindersOff =>
      'ההתקדמות שוחזרה. התזכורות כבויות, כי לאפליקציה אין הרשאה לשלוח התראות.';

  @override
  String get onbRestoreNone =>
      'לחשבון הזה אין עדיין גיבוי. נמשיך בהגדרת הקריאה.';

  @override
  String signedInNow(String name) {
    return 'התחברת בשם $name';
  }

  @override
  String passTrackLabel(int n, String name) {
    return '$n · $name';
  }

  @override
  String get passTrackMikrah => 'מקרא';

  @override
  String get finishStep => 'סיום';

  @override
  String aliyahDoneTitle(String aliyah) {
    return 'עליית $aliyah הושלמה';
  }

  @override
  String parshaDoneTitle(String name) {
    return 'פרשת $name הושלמה';
  }

  @override
  String get parshaDoneTitleShort => 'הפרשה הושלמה';

  @override
  String restGreeting(String greeting) {
    String _temp0 = intl.Intl.selectLogic(greeting, {
      'chag': 'חג שמח!',
      'roshHashanah': 'שנה טובה!',
      'yomKippur': 'גמר חתימה טובה!',
      'other': 'שבת שלום!',
    });
    return '$_temp0';
  }

  @override
  String nextAliyahLength(String aliyah, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'בעליית $aliyah $count פסוקים.',
      one: 'בעליית $aliyah פסוק אחד.',
    );
    return '$_temp0';
  }

  @override
  String nextAliyahAction(String aliyah) {
    return 'העלייה הבאה · $aliyah';
  }

  @override
  String keepGoingAliyah(String aliyah) {
    return 'להמשיך ל$aliyah';
  }

  @override
  String get todayReadingDone => 'זו הקריאה של היום. נתראה מחר.';

  @override
  String todayReadingDoneOn(String day) {
    return 'זו הקריאה של היום. נתראה ב$day.';
  }

  @override
  String erevShabbatDone(String greeting) {
    String _temp0 = intl.Intl.selectLogic(greeting, {
      'chag': 'חג שמח!',
      'roshHashanah': 'שנה טובה!',
      'yomKippur': 'גמר חתימה טובה!',
      'other': 'שבת שלום!',
    });
    return 'זו הקריאה של השבוע. $_temp0';
  }

  @override
  String erevShabbatDoneMorning(String greeting) {
    String _temp0 = intl.Intl.selectLogic(greeting, {
      'chag': 'חג שמח!',
      'roshHashanah': 'שנה טובה!',
      'yomKippur': 'גמר חתימה טובה!',
      'other': 'שבת שלום!',
    });
    return 'את השאר קוראים בשבת בבוקר. $_temp0';
  }

  @override
  String parshaStreakLength(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count פרשות ברצף',
      one: 'פרשה אחת ברצף',
    );
    return '$_temp0';
  }

  @override
  String get graceDayEarned => 'יום חסד נוסף';

  @override
  String get parshaDoneLate => 'אחרי שבת — וזה עדיין נחשב.';

  @override
  String get parshaDoneLateStreak => 'אחרי שבת — וזה עדיין נחשב. הרצף נמשך.';

  @override
  String get parshaDoneRestored => 'הושלמה יחד עם הפרשה הבאה.';

  @override
  String get parshaDoneRestoredStreak =>
      'הושלמה יחד עם הפרשה הבאה — הרצף נמשך.';

  @override
  String get readHaftarah => 'לקריאת ההפטרה';

  @override
  String seferDoneTitle(String book) {
    return 'ספר $book הושלם';
  }

  @override
  String seferDoneFacts(int count, String second) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString פסוקים, שניים מקרא ו$second.';
  }

  @override
  String seferDoneOn(String weekday, String date) {
    return 'נשלם ב$weekday, $date';
  }

  @override
  String siyumBody(int count, String second, String year) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'כל התורה כולה — $countString פסוקים, שניים מקרא ו$second, במחזור $year.';
  }

  @override
  String siyumFromBody(int count, String second, String year) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString פסוקים, שניים מקרא ו$second, במחזור $year.';
  }

  @override
  String aliyahTabLabel(String name, int n) {
    return '$name, עלייה $n מתוך 7';
  }

  @override
  String get tabRead => 'נקראה';

  @override
  String tabPartial(int done) {
    return 'הושלמו $done מתוך 3 קריאות';
  }

  @override
  String get tabNotStarted => 'טרם התחילה';

  @override
  String haftarahReadOn(String date) {
    return 'נקראה ב$date';
  }

  @override
  String torahMapOfYear(String year) {
    return 'מפת התורה · $year';
  }

  @override
  String get aboutStreaks => 'על הרצפים';

  @override
  String graceAvailable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'נותרו $count ימי חסד',
      one: 'נותר יום חסד אחד',
      zero: 'לא נותרו ימי חסד',
    );
    return '$_temp0';
  }

  @override
  String get thisYear => 'השנה';

  @override
  String get earlierYear => 'שנה קודמת';

  @override
  String parshiyotOfYear(int done, int total) {
    return '$done מתוך $total פרשות';
  }

  @override
  String yearBeginsWith(String name) {
    return 'מתחילה בפרשת $name';
  }

  @override
  String yearBarSemanticsYear(String year, int done, int total) {
    return '$year: הושלמו $done מתוך $total פרשות';
  }

  @override
  String showAllWeeks(int count) {
    return 'הצגת הכול ($count)';
  }

  @override
  String get pauseRowBody =>
      'אפשר להשהות עד 30 יום. דבר אינו מתאפס בזמן ההשהיה.';

  @override
  String get endPause => 'סיום ההשהיה';

  @override
  String get extendPause => 'הארכה';

  @override
  String get extendPauseTitle => 'הארכת ההשהיה';

  @override
  String get extendPauseBy => 'להאריך בעוד';

  @override
  String extendPauseUntil(String date) {
    return 'ההשהיה תסתיים ב$date.';
  }

  @override
  String get recordTitle => 'הושלם עד כה';

  @override
  String milestoneSiyumFrom(String name) {
    return 'סיום התורה מפרשת $name';
  }

  @override
  String get demoTag => 'הדגמה';

  @override
  String get demoAboutTitle => 'על ההדגמה';

  @override
  String get demoAboutBody =>
      'לא מחובר שרת קהילה, ולכן הקהילה פועלת כהדגמה במכשיר הזה בלבד. הדיונים בה הם דוגמאות.';

  @override
  String get demoAboutPosts =>
      'כל מה שמפרסמים נשאר במכשיר הזה, והכול מתאפס כשהאפליקציה מופעלת מחדש.';

  @override
  String get demoAboutSignIn =>
      'כדי לנסות, אפשר להתחבר עם כל כתובת דוא״ל וכל קוד בן 6 ספרות.';

  @override
  String get dismissNotice => 'סגירת ההודעה';

  @override
  String get resendCode => 'שליחת הקוד שוב';

  @override
  String resendCodeIn(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: 'שליחה חוזרת בעוד $seconds שניות',
      one: 'שליחה חוזרת בעוד שנייה',
    );
    return '$_temp0';
  }

  @override
  String get signInPrivacy => 'נשתמש בכתובת הדוא״ל רק לצורך הכניסה לחשבון.';

  @override
  String get editDisplayName => 'עריכת שם התצוגה';

  @override
  String get cloudBackupTitle => 'גיבוי בענן';

  @override
  String get privacySafetyTitle => 'פרטיות ובטיחות';

  @override
  String get accountGroupTitle => 'חשבון';

  @override
  String postingAs(String name) {
    return 'פרסום בשם $name';
  }

  @override
  String get titleMinHelp => 'לפחות 5 תווים';

  @override
  String get bodyMinHelp => 'לפחות 2 תווים';

  @override
  String replyToName(String name) {
    return 'תגובה ל$name';
  }

  @override
  String get sending => 'בשליחה…';

  @override
  String get askedTag => 'שאלה';

  @override
  String get authorTag => 'פתיחת הדיון';

  @override
  String get todahAction => 'תודה';

  @override
  String blockedMembersCount(int count) {
    return 'משתמשים חסומים ($count)';
  }

  @override
  String get noBlockedMembers => 'לא חסמת אף אחד.';

  @override
  String get pinnedHeading => 'נעוצים';

  @override
  String get recentHeading => 'פעילים לאחרונה';

  @override
  String get emptyForum => 'עדיין אין דיונים — אפשר לפתוח את הראשון.';

  @override
  String get emptyLockedForum => 'עדיין אין כאן דיונים.';

  @override
  String repliesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count תגובות',
      one: 'תגובה אחת',
      zero: 'אין עדיין תגובות',
    );
    return '$_temp0';
  }

  @override
  String get errBodyTooShort => 'ההודעה צריכה להכיל לפחות 2 תווים.';

  @override
  String get tishaBavTitle => 'תשעה באב';

  @override
  String get todayTishaBav =>
      'היום אין לומדים תורה, מלבד הדברים הרעים (איוב, איכה ומקצת ירמיהו).';

  @override
  String todayTishaBavTomorrow(String portion) {
    return 'פרשת $portion נמשכת מחר.';
  }

  @override
  String todayTishaBavOn(String portion, String weekday) {
    return 'פרשת $portion נמשכת ב$weekday.';
  }

  @override
  String get tishaBavShort => 'ט׳ באב';

  @override
  String dayChipLabelToday(String day, String status) {
    return '$day, היום: $status';
  }

  @override
  String get speechRateNormal => 'רגיל';

  @override
  String speechRateTimes(String rate) {
    return '$rate×';
  }

  @override
  String get tishaBavQuietDesc =>
      'ביום זה אין לומדים תורה, מלבד הדברים הרעים (שולחן ערוך או״ח תקנד, א)';

  @override
  String get a11yGroupSpeech => 'הקראה';

  @override
  String get widgetTishaBav => 'היום אין לומדים תורה';

  @override
  String get guideAppTitle => 'השימוש באפליקציה';

  @override
  String get guideAppBody =>
      'מסך היום מציג את פרשת השבוע ואת הקריאה של היום. הטבעות מתמלאות עם הקריאה: מקרא, מקרא שוב ותרגום.\nקוראים מתוך חומש מודפס? ״קראתי בחומש״ רושם את הקריאה, ואחרי שבת אפשר לרשום את מה שנקרא בשבת.\nיום שהוחמץ? קריאתו יחד עם הקריאה של למחרת משלימה אותו; אם לא, יום חסד מכסה אותו.\nלחיצה ארוכה על פסוק: סימנייה, הערה, העתקה, שיתוף או שאלה.\nהשמעה מקריאה את הטקסט כדי לעקוב אחריו — עזר, לא תחליף לקריאה.';

  @override
  String get saveBackupFirst => 'שמירת קובץ גיבוי לפני המחיקה';

  @override
  String todahButtonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count תודות',
      one: 'תודה 1',
    );
    return '$_temp0';
  }

  @override
  String codeIncomplete(int count) {
    return 'יש להזין את כל $count הספרות של הקוד.';
  }

  @override
  String shabbatTimesSummaryYomTov(String candles, String after) {
    return 'הדלקת נרות $candles\nהדלקת נרות יום טוב אחרי $after';
  }

  @override
  String get candleLightingSetting => 'הדלקת נרות';

  @override
  String candleMinutesCityDefault(int minutes) {
    return 'ברירת המחדל של העיר ($minutes דק׳)';
  }

  @override
  String candleMinutesBeforeSunset(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes דקות לפני השקיעה',
      one: 'דקה אחת לפני השקיעה',
    );
    return '$_temp0';
  }

  @override
  String get shabbatEndsSetting => 'צאת השבת';

  @override
  String get havdalahNightfall => 'צאת הכוכבים (⁦8.5°⁩)';

  @override
  String havdalahMinutesAfterSunset(int minutes) {
    return '$minutes דקות אחרי השקיעה';
  }

  @override
  String get havdalahRabbeinuTam => '72 דקות (רבנו תם)';

  @override
  String searchSpellingFallback(String query, String variant) {
    return 'אין פסוק עם ״$query״. מוצגות התוצאות עבור ״$variant״, כפי שנכתב בתורה.';
  }

  @override
  String get sourcesSunDescription =>
      'מחושבות במכשיר לפי הנוסחאות של מחשבון השמש של NOAA (על פי Meeus, Astronomical Algorithms), ונבדקו מול Hebcal, שזמניו הם ברירת המחדל: הדלקת נרות 18 דקות לפני השקיעה, 20 בישראל, 40 בירושלים ו־30 בחיפה ובזכרון יעקב, וצאת השבת כשהשמש ⁦8.5°⁩ מתחת לאופק. בהגדרות, תחת קריאה ומנהגים, אפשר לבחור דקות אחרות להדלקת הנרות, ולבחור שהשבת תצא 42, 50 או 72 דקות אחרי השקיעה, כמו בלוח המקומי.';

  @override
  String get communityComingSoon =>
      'הקהילה תגיע בקרוב. עד אז הקריאה שלך נשמרת במכשיר הזה, ואפשר להעביר אותה בעזרת קובץ גיבוי, בהגדרות תחת ״הנתונים שלך״.';

  @override
  String get guideAppBodyNoCommunity =>
      'מסך היום מציג את פרשת השבוע ואת הקריאה של היום. הטבעות מתמלאות עם הקריאה: מקרא, מקרא שוב ותרגום.\nקוראים מתוך חומש מודפס? ״קראתי בחומש״ רושם את הקריאה, ואחרי שבת אפשר לרשום את מה שנקרא בשבת.\nיום שהוחמץ? קריאתו יחד עם הקריאה של למחרת משלימה אותו; אם לא, יום חסד מכסה אותו.\nלחיצה ארוכה על פסוק: סימנייה, הערה, העתקה או שיתוף.\nהשמעה מקריאה את הטקסט כדי לעקוב אחריו — עזר, לא תחליף לקריאה.';

  @override
  String get updatesHeading => 'עדכונים';

  @override
  String get updatesThisVersion => 'הגרסה הזו';

  @override
  String get updatesCheckNow => 'בדיקה עכשיו';

  @override
  String get updatesChecking => 'בבדיקה…';

  @override
  String updatesLastChecked(String time) {
    return 'נבדק לאחרונה $time';
  }

  @override
  String get updatesNotChecked => 'עדיין לא נבדק';

  @override
  String get updatesQuiet => 'העדכונים ממתינים עד אחרי שבת ויום טוב.';

  @override
  String get updatesLatest => 'זו הגרסה העדכנית ביותר.';

  @override
  String get updatesWhatsNew => 'מה חדש';

  @override
  String get updatesWhatsNewDesc => 'הערות הגרסה, ב־GitHub';

  @override
  String get updatesAuto => 'בדיקה אוטומטית';

  @override
  String get updatesAutoDesc => 'עד פעמיים ביום, ולעולם לא בשבת וביום טוב';

  @override
  String updateReady(String version) {
    return 'גרסה $version מוכנה להתקנה';
  }

  @override
  String get updateInstall => 'התקנה';

  @override
  String updateInstallTitle(String version) {
    return 'להתקין את גרסה $version?';
  }

  @override
  String get updateInstallBody =>
      'האפליקציה תיסגר, הגרסה החדשה תותקן, והאפליקציה תיפתח שוב. הקריאה וההגדרות שלך יישארו כפי שהן.';

  @override
  String get updatePreparing => 'העדכון בהכנה…';

  @override
  String get updateCheckFailed =>
      'לא ניתן היה לבדוק אם יש עדכונים. נא לנסות שוב מאוחר יותר.';

  @override
  String get updateInstallFailed =>
      'לא ניתן היה להכין את העדכון, ושום דבר לא השתנה.';

  @override
  String updatesPreviewVersion(String version) {
    return '$version (גרסה מקדימה)';
  }

  @override
  String get installTitle => 'התקנת האפליקציה';

  @override
  String get installDesc => 'לפתוח את שניים מקרא כמו כל אפליקציה אחרת';

  @override
  String get installHomeScreen => 'הוספה למסך הבית';

  @override
  String get installHomeScreenDesc => 'נפתחת ממסך הבית, כמו כל אפליקציה';

  @override
  String get installDesktop => 'התקנה במחשב הזה';

  @override
  String get installDesktopDesc => 'נפתחת בחלון משלה, כמו כל אפליקציה';

  @override
  String get installIosTitle => 'הוספה למסך הבית';

  @override
  String get installIosDesc => 'מתפריט השיתוף של Safari';

  @override
  String get installIosStep1 =>
      'להקיש על ״שיתוף״ בסרגל הכלים של Safari, או בתפריט ״עוד״ שלו אם הוא לא שם.';

  @override
  String get installIosStep2 =>
      'לבחור ״הוספה למסך הבית״, ואם צריך, לגלול אליו למטה.';

  @override
  String get installIosStep3 =>
      'להקיש על ״הוספה״. שניים מקרא נמצאת עכשיו במסך הבית.';

  @override
  String get installIosBackup =>
      'האפליקציה שבמסך הבית שומרת את הקריאה בנפרד. כדי להעביר אליה את מה שקראת כאן, אפשר לייצא אותו קודם בהגדרות, תחת ״הנתונים שלך״, ולייבא אותו שם.';

  @override
  String get installApkTitle => 'אפליקציית Android (קובץ APK)';

  @override
  String get installApkDesc => 'פותחת את האתר הזה כאפליקציה';

  @override
  String get installApkBody =>
      'אפליקציה ל־Android שפותחת את האתר הזה כאפליקציה, עם סמל משלה. יש להוריד את קובץ ה־APK של הגרסה האחרונה ולפתוח אותו כדי להתקין; ייתכן שהטלפון יבקש לאשר התקנות מהדפדפן.';

  @override
  String get installReleases => 'לדף הגרסאות';

  @override
  String get installWindowsTitle => 'אפליקציה ל־Windows';

  @override
  String get installWindowsDesc => 'מותקנת בשורה אחת ב־PowerShell';

  @override
  String get installWindowsBody =>
      'יש לפתוח את PowerShell, להדביק בו את השורה הזו ולהקיש Enter. השורה מורידה מ־GitHub את הגרסה האחרונה, בודקת אותה ומתקינה אותה לחשבון שלך בלבד, בלי הרשאות מנהל.';

  @override
  String get installWindowsMsi => 'או להוריד את קובץ ההתקנה (MSI) מדף הגרסאות.';

  @override
  String get installCopied => 'הועתק';

  @override
  String get installCardText =>
      'אפשר להוסיף את שניים מקרא למסך הבית ולפתוח אותה כמו כל אפליקציה.';

  @override
  String get installAction => 'התקנה';

  @override
  String get aiNoticeTitle => 'נכתב בעזרת בינה מלאכותית';

  @override
  String get aiNoticeBody =>
      'אפליקציה זו, האתר שלה והקוד שלה נכתבו כולם בעזרת בינה מלאכותית, בשיטת וייב קודינג. הנוסח נבנה בתוכנות מהמקורות הציבוריים שמופיעים במקורות הנוסח. לפני שאתם נשענים על פסוק, בדקו אותו במקורו, והודיעו לנו אם משהו שונה.';

  @override
  String get sourcesTopTitle => 'מאיפה בא כל נוסח';

  @override
  String get sourcesTopBody =>
      'כל נוסח נבנה ממהדורה ציבורית אחת מסוימת, שאפשר לפתוח ולהשוות לאפליקציה. אפשר גם לשחזר את הבנייה: טביעה דיגיטלית (SHA-256) של כל קובץ מקור ושל כל קובץ שהאפליקציה מכילה רשומה ב-SOURCES.json, כדי שכל אחד יוכל לבדוק.';

  @override
  String get sourcesTorahDifferences =>
      'בתורה, הנוסח הולך אחרי ספרי התורה של אשכנז וספרד במקומות שבהם הם שונים מכתר ארם צובה, שמופיע במהדורת ויקיטקסט. כל מקום כזה מסומן בנוסח, והנוסח שבכתר מובא בהערה. לכן השוואה לכתר תראה את ההבדלים האלה בכוונה.';

  @override
  String get sourcesManifestAction => 'טביעות דיגיטליות של כל הקבצים';

  @override
  String get sourcesManifestDescription =>
      'SOURCES.json מפרט כל קובץ מקור עם כתובתו בספריא וטביעתו הדיגיטלית, וכל קובץ שהאפליקציה מכילה עם טביעתו. הורידו מקור, חשבו את טביעתו והשוו.';

  @override
  String get verseCheckOnSefaria => 'בדיקת הפסוק בספריא';

  @override
  String get aiNoticeStrip => 'נכתב בעזרת בינה מלאכותית · מקורות הנוסח';

  @override
  String get skipLastVerseWithRashi =>
      'להשמיט את עמוד הפסוק האחרון כשרש״י מוצג לצדו';

  @override
  String get skipLastVerseWithRashiDesc =>
      'כשרש״י הוא הקריאה השנייה ומוצג לצדו, הפסוק האחרון שחוזר בסוף אינו מוצג בעמוד משלו. כבוי: הוא מוצג.';
}
