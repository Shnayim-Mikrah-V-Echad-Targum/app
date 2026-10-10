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
  String get actionLearnMore => 'מידע נוסף';

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
    return '$name · עלייה $number';
  }

  @override
  String andJoiner(String first, String second) {
    return '$first ו$second';
  }

  @override
  String get passMikra1 => 'קריאה ראשונה';

  @override
  String get passMikra2 => 'קריאה שנייה';

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
  String get passShortMikra => 'מקרא';

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
  String parshaLabel(String name) {
    return 'פרשת $name';
  }

  @override
  String get todayReadingTitle => 'הקריאה של היום';

  @override
  String get todayDone => 'הקריאה של היום הושלמה';

  @override
  String get todayAhead => 'את/ה מקדים/ה את התוכנית. כל הכבוד!';

  @override
  String get todayNothingPlanned =>
      'לא מתוכננת קריאה להיום. זמן טוב להשלים או להקדים.';

  @override
  String todayBehind(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count עליות בפיגור — רגיל לגמרי באמצע השבוע.',
      one: 'עלייה אחת בפיגור — רגיל לגמרי באמצע השבוע.',
    );
    return '$_temp0';
  }

  @override
  String get readTodaysAliyah => 'לקריאה של היום';

  @override
  String get continueReading => 'המשך קריאה';

  @override
  String get startReading => 'התחלת קריאה';

  @override
  String get readFromBook => 'קראתי מתוך ספר';

  @override
  String get weekComplete => 'הפרשה של השבוע הושלמה. יישר כוח!';

  @override
  String get haftarahLabel => 'הפטרה';

  @override
  String get haftarahRead => 'ההפטרה נקראה';

  @override
  String openWeekTitle(String name) {
    return 'פרשת $name עדיין פתוחה';
  }

  @override
  String openWeekLate(String date) {
    return 'אם תסיים/י עד $date, היא עדיין נחשבת.';
  }

  @override
  String openWeekRestore(String name, String next) {
    return 'סיום $name ו$next עד שבת ישמור על הרצף — השלמה כפולה אחת לכל חומש.';
  }

  @override
  String get openWeekHaftarahLeft => 'נשארה רק ההפטרה.';

  @override
  String get checkInTitle => 'שבוע טוב! קראת בשבת?';

  @override
  String get checkInBody =>
      'אפשר לרשום מה שקראת מתוך חומש מודפס — זה נחשב בדיוק אותו הדבר.';

  @override
  String get checkInFinished => 'סיימתי את הפרשה בשבת';

  @override
  String get checkInPick => 'בחירת עליות';

  @override
  String pausedBanner(String date) {
    return 'בהשהיה עד $date. דבר אינו מתאפס בזמן השהיה.';
  }

  @override
  String get resume => 'חידוש';

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
  String get discussThisWeek => 'דיון על פרשת השבוע';

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
    return 'יתחיל בפרשת $name';
  }

  @override
  String get daysBeginToday => 'יתחיל בקריאה של היום';

  @override
  String get dayKept => 'נקרא';

  @override
  String get dayAhead => 'לפני התוכנית';

  @override
  String get dayCaughtUp => 'הושלם למחרת';

  @override
  String get dayGrace => 'מכוסה ביום חסד';

  @override
  String get dayPaused => 'בהשהיה';

  @override
  String get dayOpen => 'עדיין לא';

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
  String get weekRestored => 'הושלם בכפל';

  @override
  String get weekMadeUp => 'הושלם מאוחר';

  @override
  String get weekMissed => 'לא הושלם';

  @override
  String get weekTransparent => 'לא נספר';

  @override
  String get weekOverdue => 'עוד אפשר להשלים';

  @override
  String get weekInProgress => 'בתהליך';

  @override
  String plannedFor(String day) {
    return 'מתוכנן ליום $day';
  }

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
  String get whenDidYouRead => 'מתי קראת?';

  @override
  String get whenToday => 'היום';

  @override
  String get whenYesterday => 'אתמול';

  @override
  String get whenOnShabbat => 'בשבת';

  @override
  String get whenPickDate => 'בחירת תאריך';

  @override
  String get markedRead => 'סומן כנקרא';

  @override
  String get markedUnread => 'סומן כלא נקרא';

  @override
  String aliyahNote(String note) {
    return 'הערה: $note';
  }

  @override
  String get browseAll => 'כל הפרשות';

  @override
  String get browseTitle => 'התורה';

  @override
  String previewNotOpen(String date) {
    return 'תצוגה מקדימה — הפרשה נפתחת לרישום ב־$date.';
  }

  @override
  String get stepMikra1 => 'קריאת המקרא';

  @override
  String get stepMikra2 => 'קריאת המקרא שוב';

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
  String passTrackLabel(int n, String name) {
    return '$n · $name';
  }

  @override
  String get passTrackMikra => 'מקרא';

  @override
  String get finishStep => 'סיום';

  @override
  String verseOf(int current, int total) {
    return 'פסוק $current מתוך $total';
  }

  @override
  String sectionOf(int current, int total) {
    return 'קטע $current מתוך $total';
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
  String firstAliyahDone(String verses) {
    return 'יישר כוח! העלייה הראשונה שלך הושלמה — $verses, שניים מקרא ואחד תרגום.';
  }

  @override
  String aliyahDoneTitle(String aliyah) {
    return 'עליית $aliyah הושלמה';
  }

  @override
  String parshaDoneTitle(String name) {
    return 'פרשת $name הושלמה';
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
      'other': 'שבת שלום!',
    });
    return 'זו הקריאה של השבוע. $_temp0';
  }

  @override
  String erevShabbatDoneMorning(String greeting) {
    String _temp0 = intl.Intl.selectLogic(greeting, {
      'chag': 'חג שמח!',
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
  String seferDoneBody(String book, int count, String second) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'ספר $book הושלם — $countString פסוקים, שניים מקרא ו$second.';
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
  String get ttsUnavailable => 'הקראה קולית אינה זמינה במכשיר זה.';

  @override
  String get ttsNoHebrewVoice =>
      'לא מותקן קול בעברית. אפשר להוסיף קול בהגדרות הדיבור של המכשיר.';

  @override
  String get guidedMode => 'קריאה מודרכת';

  @override
  String get fullTextMode => 'טקסט מלא';

  @override
  String get markAliyahRead => 'סימון העלייה כנקראה';

  @override
  String get keyboardShortcuts => 'קיצורי מקלדת';

  @override
  String get translationDisclaimer =>
      'התרגום הוא עזר ללימוד, ואינו בא במקום התרגום (אונקלוס).';

  @override
  String get mikraLabel => 'מקרא';

  @override
  String get targumLabel => 'תרגום אונקלוס';

  @override
  String get rashiLabel => 'רש״י';

  @override
  String get translationLabel => 'תרגום לאנגלית (JPS 1917)';

  @override
  String get haftarahTitle => 'הפטרה';

  @override
  String get markHaftarahRead => 'סימון ההפטרה כנקראה';

  @override
  String haftarahReadOn(String date) {
    return 'נקראה ב$date';
  }

  @override
  String specialHaftarah(String reason) {
    return 'הפטרה מיוחדת: $reason';
  }

  @override
  String get readerFinished => 'סיימת את העלייה הזו.';

  @override
  String get shortcutNext => 'השלב הבא';

  @override
  String get shortcutBack => 'השלב הקודם';

  @override
  String get shortcutLarger => 'הגדלת טקסט';

  @override
  String get shortcutSmaller => 'הקטנת טקסט';

  @override
  String get shortcutTeamim => 'הצגת או הסתרת טעמים';

  @override
  String get shortcutNikud => 'הצגת או הסתרת ניקוד';

  @override
  String get shortcutListen => 'השמעה / עצירה';

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
  String get keySpace => 'רווח';

  @override
  String get progressTitle => 'התקדמות';

  @override
  String longest(String value) {
    return 'הארוך ביותר: $value';
  }

  @override
  String versesRead(String count) {
    return '$count פסוקים בשניים מקרא ואחד תרגום';
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
  String torahMapOfYear(String year) {
    return 'מפת התורה · $year';
  }

  @override
  String get torahMapHelp => 'כל משבצת היא פרשה אחת במחזור של השנה.';

  @override
  String torahMapBook(String book, int done, int total) {
    return '$book: $done מתוך $total פרשות';
  }

  @override
  String get aboutStreaks => 'על הרצפים';

  @override
  String graceAvailable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ימי חסד זמינים',
      one: 'יום חסד אחד זמין',
      zero: 'אין ימי חסד זמינים',
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
  String yearBarSemanticsYear(String year, int done, int total) {
    return '$year: הושלמו $done מתוך $total פרשות';
  }

  @override
  String showAllWeeks(int count) {
    return 'הצגת הכול ($count)';
  }

  @override
  String get pauseRowBody =>
      'אפשר להשהות עד 30 יום. דבר אינו מתאפס בזמן השהיה.';

  @override
  String get endPause => 'סיום ההשהיה';

  @override
  String get extendPause => 'הארכה';

  @override
  String get extendPauseTitle => 'הארכת ההשהיה';

  @override
  String get extendPauseBy => 'הארכה בעוד';

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
  String get recentWeeks => 'שבועות אחרונים';

  @override
  String get makeUpTitle => 'השלמה עד שמחת תורה';

  @override
  String get makeUpBody => 'לא חובה. השלמות נחשבות לסיום התורה של השנה.';

  @override
  String get pauseTitle => 'החיים קורים';

  @override
  String get pauseBody =>
      'אפשר להשהות עד 30 יום — דבר אינו מתאפס בזמן השהיה. מחלה, נסיעה, אבלות, תינוק חדש: החיים קודמים.';

  @override
  String get pauseAction => 'השהיית רצפים';

  @override
  String get pauseFor => 'השהיה למשך';

  @override
  String get pauseStarting => 'החל מ־';

  @override
  String pauseStarted(String date) {
    return 'בהשהיה עד $date.';
  }

  @override
  String get pauseEnded => 'ברוך שובך! המקום שלך שמור.';

  @override
  String get streaksHidden => 'מספרי הרצף מוסתרים. ההתקדמות שלך עדיין נשמרת.';

  @override
  String get graceExplainer =>
      'ימי חסד מכסים אוטומטית יום מתוכנן שהוחמץ. מתחילים עם 2, מקבלים 1 בכל פעם שמסיימים פרשה לפני שבת (עד 3), ומשתמשים לכל היותר ב־2 בשבוע. אי אפשר לקנות אותם.';

  @override
  String get streakExplainer =>
      'רצף הפרשות סופר פרשות שהושלמו לפני שבת — או עד ליל רביעי, שגם זה נחשב. שבת ויום טוב לעולם אינם שוברים רצף.';

  @override
  String get streakExplainerWednesday =>
      'רצף הפרשות סופר פרשות שהושלמו לפני שבת — או עד ליל חמישי, שגם זה נחשב. שבת ויום טוב לעולם אינם שוברים רצף.';

  @override
  String get streakExplainerNoWindow =>
      'רצף הפרשות סופר פרשות שהושלמו לפני שבת. שבת ויום טוב לעולם אינם שוברים רצף.';

  @override
  String get statusLegend => 'מקרא';

  @override
  String get noHistory => 'השבועות שלך יופיעו כאן כשתקרא/י.';

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
  String get milestoneComeback => 'ברוך שובך';

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
  String get settingsAbout => 'אודות';

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
      'עלייה אחת בימים א׳–ה׳; שישי ושביעי ביום ו׳';

  @override
  String get planShevii => 'שביעי בשבת בבוקר';

  @override
  String get planSheviiDesc => 'עליות 1–6 בימים א׳–ו׳; השביעית לפני סעודת שבת';

  @override
  String get planErevShabbat => 'הכול ביום שישי';

  @override
  String get planErevShabbatDesc =>
      'כל הפרשה בערב שבת (האריז״ל; שולחן ערוך הרב)';

  @override
  String get methodLabel => 'שיטת קריאה';

  @override
  String get methodVerse => 'פסוק פסוק';

  @override
  String get methodVerseDesc => 'כל פסוק פעמיים ואחריו התרגום';

  @override
  String get methodSection => 'פרשה פרשה';

  @override
  String get methodSectionDesc =>
      'כל פרשה (פתוחה או סתומה) פעמיים ואחריה התרגום';

  @override
  String get methodAliyah => 'עלייה עלייה';

  @override
  String get methodAliyahDesc => 'כל העלייה פעמיים ואחריה התרגום';

  @override
  String get secondLabel => 'תרגום';

  @override
  String get secondOnkelos => 'תרגום אונקלוס';

  @override
  String get secondRashi => 'רש״י';

  @override
  String get secondBoth => 'אונקלוס ורש״י';

  @override
  String get secondRashiEnglish => 'רש״י באנגלית';

  @override
  String get secondHelp =>
      'השולחן ערוך (או״ח רפה, ב) מתיר לקרוא את פירוש רש״י במקום התרגום, וירא שמים יקרא את שניהם. תרגום פשוט הוא עזר ללימוד ואינו תחליף. על רש״י מתורגם יש לשאול רב.';

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
  String get haftarahEnabled => 'הפטרה';

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
  String get themeLabel => 'ערכת צבעים';

  @override
  String get themeSystem => 'לפי המכשיר';

  @override
  String get themeLight => 'בהירה';

  @override
  String get themeDark => 'כהה';

  @override
  String get themeSepia => 'ספיה';

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
  String get keepScreenOn => 'המסך יישאר דלוק בזמן קריאה';

  @override
  String get previewLabel => 'תצוגה מקדימה';

  @override
  String get reduceMotion => 'הפחתת תנועה';

  @override
  String get reduceMotionDesc => 'כיבוי אנימציות וחגיגות נעות';

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
  String get divineAdonai => 'אדני';

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
  String presetApplied(String name) {
    return 'הוחל: $name';
  }

  @override
  String get accessibilityStatement => 'הצהרת נגישות';

  @override
  String get sendFeedback => 'שליחת משוב';

  @override
  String get dailyReminder => 'תזכורת יומית';

  @override
  String get dailyReminderDesc => 'תזכורת עדינה בשעה שבחרת';

  @override
  String get dailyReminderTime => 'שעת התזכורת היומית';

  @override
  String get fridayReminder => 'תזכורת לערב שבת';

  @override
  String get fridayReminderDesc => 'ביום שישי בבוקר, רק אם הפרשה לא הושלמה';

  @override
  String get fridayReminderTime => 'שעת התזכורת לערב שבת';

  @override
  String get checkInReminder => 'תזכורת אחרי שבת';

  @override
  String get checkInReminderDesc => 'ביום ראשון בבוקר, לרשום מה שקראת בשבת';

  @override
  String get remindersShabbatNote =>
      'תזכורות לעולם אינן נשלחות בשבת וביום טוב, ולעולם לא יותר מאחת ביום.';

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
  String get notificationsUnsupported =>
      'תזכורות אינן זמינות בגרסת הדפדפן. אפשר להתקין את האפליקציה בטלפון או במחשב כדי לקבל אותן.';

  @override
  String get notificationsDenied =>
      'ההתראות לאפליקציה זו כבויות בהגדרות המכשיר.';

  @override
  String get notificationsDeniedTitle => 'ההתראות כבויות';

  @override
  String get primingTitle => 'רוצה תזכורת יומית עדינה?';

  @override
  String primingBody(String time) {
    return 'בשעה $time. לעולם לא בשבת וביום טוב, ולכל היותר אחת ביום. אפשר לשנות בכל עת.';
  }

  @override
  String get primingYes => 'כן, להזכיר לי';

  @override
  String get notifChannelDaily => 'קריאה יומית';

  @override
  String get notifChannelFriday => 'ערב שבת';

  @override
  String get notifChannelCheckIn => 'אחרי שבת';

  @override
  String get notifChannelDailyDesc =>
      'הקריאה של היום בשעה שבחרת, אף פעם לא בשבת או ביום טוב';

  @override
  String get notifChannelErevShabbatDesc =>
      'בבוקר שלפני שבת או יום טוב, רק אם הפרשה לא הושלמה';

  @override
  String get notifChannelCheckInDesc =>
      'אחרי שבת: תזכורת לרשום מה שנקרא, וגם הודעה כשהתזכורות נעצרות';

  @override
  String notifDailyTitle(String aliyah) {
    return 'היום: $aliyah';
  }

  @override
  String notifDailyBody(String parsha, String verses) {
    return 'פרשת $parsha · $verses';
  }

  @override
  String notifFridayTitle(String parsha) {
    return 'ערב שבת · פרשת $parsha';
  }

  @override
  String get notifFridayBody =>
      'אם עוד לא סיימת, יש עוד זמן — או לסיים בשבת בבוקר מתוך חומש ולרשום אחרי שבת.';

  @override
  String get notifCheckInTitle => 'שבוע טוב!';

  @override
  String get notifCheckInBody => 'קראת בשבת? אפשר לרשום זאת כאן.';

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
  String get exportDataDesc => 'שמירת גיבוי שאפשר לשחזר מאוחר יותר';

  @override
  String get importData => 'ייבוא התקדמות';

  @override
  String get importDataDesc => 'שחזור מגיבוי';

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
  String get contactTitle => 'יצירת קשר';

  @override
  String get guideTitle => 'על שניים מקרא';

  @override
  String get disclaimer => 'המנהגים שונים. בשאלות מעשיות יש לשאול רב.';

  @override
  String get onbWelcomeBody =>
      'קוראים את הפרשה פעמיים ואת התרגום פעם אחת — עלייה ליום, ומסיימים לפני שבת.';

  @override
  String get onbStart => 'להתחיל את פרשת השבוע';

  @override
  String get onbLocationTitle => 'איפה תהיה/י בשבת הקרובה?';

  @override
  String get onbMethodTitle => 'איך את/ה קורא/ת?';

  @override
  String get onbPlanTitle => 'התוכנית שלך לשבוע';

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
  String get guideWhatBody =>
      'הגמרא (ברכות ח, א) מלמדת: לעולם ישלים אדם פרשיותיו עם הציבור, שניים מקרא ואחד תרגום. השולחן ערוך פוסק זאת באורח חיים סימן רפה. זוהי השלמה אישית של הפרשה שהציבור קורא בשבת.';

  @override
  String get guideWhenTitle => 'מתי';

  @override
  String get guideWhenBody =>
      'אפשר להתחיל ביום ראשון (ויש אומרים כבר משבת אחר הצהריים, משקראו הציבור במנחה את הפרשה הבאה). לכתחילה יש לסיים לפני סעודת שבת. אם לא סיים, יכול להשלים עד ליל רביעי (״עד יום רביעי״, שו״ע רפה, ד), ופרשות שהוחמצו אפשר להשלים עד שמחת תורה.';

  @override
  String get guideHowTitle => 'כיצד';

  @override
  String get guideHowBody =>
      'קוראים פסוק פסוק — כל פסוק פעמיים ואחריו התרגום — או פרשה פרשה, כל פרשה פעמיים ואחריה התרגום. רבים חוזרים על הפסוק האחרון בעברית כדי לסיים במקרא. מומלץ לקרוא בקול ובטעמים, אם אפשר.';

  @override
  String get guideTargumTitle => 'תרגום או רש״י';

  @override
  String get guideTargumBody =>
      'פירוש רש״י יכול לבוא במקום התרגום, מפני שהוא מפרש את המקרא; וירא שמים יקרא את שניהם (שו״ע רפה, ב). תרגום פשוט הוא עזר מועיל ללימוד, אך אינו תחליף לתרגום.';

  @override
  String get guideSpecialTitle => 'מקרים מיוחדים';

  @override
  String get guideSpecialBody =>
      'בפסוק ״עטרות ודיבון״ (במדבר לב, ג) אונקלוס מביא בעיקר את שמות המקומות בארמית, ובעקבות רש״י (ברכות ח, ב) רבים קוראים אותו גם פעם שלישית בעברית. את פרשת וזאת הברכה קוראים לפני שמחת תורה, ובמיוחד בהושענא רבה. רבים קוראים גם את הפטרת השבוע פעם אחת.';

  @override
  String get guideShabbatTitle => 'שבת ויום טוב';

  @override
  String get guideShabbatBody =>
      'האפליקציה לעולם אינה מבקשת שתפתח/י אותה בשבת וביום טוב. הרצפים מושהים בימים אלה, אין תזכורות, ואת מה שקראת מתוך חומש מודפס אפשר לרשום אחר כך.';

  @override
  String get guideSourcesTitle => 'מקורות';

  @override
  String get guideSourcesBody =>
      'ברכות ח, א–ב · שולחן ערוך, אורח חיים רפה · משנה ברורה רפה · קיצור שולחן ערוך עב · שולחן ערוך הרב רפה';

  @override
  String hebrewDateLabel(String date) {
    return 'תאריך עברי: $date';
  }

  @override
  String bookOfTorah(String book) {
    return 'ספר $book';
  }

  @override
  String get communityTitle => 'קהילה';

  @override
  String get demoModeBanner =>
      'מצב הדגמה: ההודעות נשמרות במכשיר זה בלבד ומתאפסות בהפעלה מחדש.';

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
  String get forumsHeading => 'פורומים';

  @override
  String get forumNotFound => 'הפורום לא נמצא. ייתכן שהועבר או נסגר.';

  @override
  String get allForums => 'כל הפורומים';

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
  String get demoCodeHint => 'מצב הדגמה: כל 6 ספרות יעבדו.';

  @override
  String signedInAs(String name) {
    return 'מחובר/ת בשם $name';
  }

  @override
  String get displayNameLabel => 'שם תצוגה';

  @override
  String get displayNameHelp => 'מוצג עם ההודעות שלך. 2–40 תווים.';

  @override
  String get saveName => 'שמירת השם';

  @override
  String get editDisplayName => 'עריכת שם התצוגה';

  @override
  String get cloudBackupTitle => 'גיבוי בענן';

  @override
  String get privacySafetyTitle => 'פרטיות ובטיחות';

  @override
  String get accountGroupTitle => 'חשבון';

  @override
  String get nameSaved => 'השם נשמר.';

  @override
  String get syncProgress => 'גיבוי ההתקדמות שלי';

  @override
  String get syncProgressDesc =>
      'שמירת התקדמות הקריאה בחשבון ושחזורה במכשירים אחרים.';

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
  String lastSynced(String time) {
    return 'סונכרן לאחרונה $time';
  }

  @override
  String get deleteAccount => 'מחיקת החשבון';

  @override
  String get deleteAccountConfirm =>
      'פעולה זו מוחקת לצמיתות את החשבון, הפרופיל וכל מה שפרסמת. התקדמות הקריאה במכשיר זה נשמרת. אי אפשר לבטל זאת.';

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
  String postingAs(String name) {
    return 'פרסום בשם $name';
  }

  @override
  String get titleMinHelp => 'לפחות 5 תווים';

  @override
  String get bodyMinHelp => 'לפחות 2 תווים';

  @override
  String get replyLabel => 'כתיבת תגובה';

  @override
  String get replyAction => 'תגובה';

  @override
  String replyToName(String name) {
    return 'תגובה ל$name';
  }

  @override
  String replyingTo(String name) {
    return 'בתגובה ל$name';
  }

  @override
  String get sending => 'בשליחה…';

  @override
  String get askedTag => 'שואל/ת';

  @override
  String get authorTag => 'פותח/ת הדיון';

  @override
  String get todahAction => 'תודה';

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
  String get reportSent => 'תודה. מנהל/ת יבדקו זאת.';

  @override
  String blockUser(String name) {
    return 'חסימת $name';
  }

  @override
  String blockConfirm(String name) {
    return 'לא תראה/י הודעות של $name. הם לא יקבלו הודעה על כך.';
  }

  @override
  String get blockedDone => 'נחסם.';

  @override
  String get unblock => 'ביטול חסימה';

  @override
  String get blockedUsersTitle => 'משתמשים חסומים';

  @override
  String blockedMembersCount(int count) {
    return 'משתמשים חסומים ($count)';
  }

  @override
  String get noBlockedMembers => 'לא חסמת אף אחד.';

  @override
  String get edited => 'נערך';

  @override
  String get editPostTitle => 'עריכת הודעה';

  @override
  String get deletePostConfirm => 'למחוק את ההודעה?';

  @override
  String get postDeleted => 'ההודעה נמחקה.';

  @override
  String get posted => 'פורסם.';

  @override
  String get pendingReview => 'מוסתר — ממתין לבדיקת מנהל';

  @override
  String get lockedThread => 'הדיון נעול.';

  @override
  String get pinnedHeading => 'נעוצים';

  @override
  String get recentHeading => 'פעילים לאחרונה';

  @override
  String get lockedLabel => 'נעול';

  @override
  String get pinnedLabel => 'נעוץ';

  @override
  String get lockThread => 'נעילת הדיון';

  @override
  String get unlockThread => 'פתיחת הדיון';

  @override
  String get pinThread => 'נעיצה למעלה';

  @override
  String get unpinThread => 'ביטול נעיצה';

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
  String get emptyForum => 'עדיין אין דיונים — אפשר לפתוח את הראשון.';

  @override
  String get emptyLockedForum => 'עדיין אין כאן דיונים.';

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
  String get anonymousMember => 'חבר/ה לשעבר';

  @override
  String get errRateLimited => 'את/ה כותב/ת מהר — נא להמתין כמה שניות.';

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
  String get errInvalidName => 'השם צריך להכיל 2–40 תווים.';

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
  String get errBodyTooShort => 'ההודעה צריכה להכיל לפחות 2 תווים.';

  @override
  String get errNetwork =>
      'לא ניתן להתחבר לשרת. נא לבדוק את החיבור ולנסות שוב.';

  @override
  String get moderatorBadge => 'מנהל/ת';

  @override
  String get draftRestored => 'הטיוטה שלך שוחזרה.';

  @override
  String get discardDraft => 'מחיקת הטיוטה';

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
      'כדאי לנסות פחות מילים, או את הכתיב שבתורה, שלעיתים קרובות אין בו ו׳ וי׳.';

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
  String get shortcutLogFromBook => 'רישום קריאה מתוך ספר';

  @override
  String get shortcutThisWeek => 'פרשת השבוע';
}
