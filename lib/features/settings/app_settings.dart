import '../../core/calendar/local_date.dart';
import '../../core/text/hebrew_text.dart';
import '../../data/models/parsha.dart';
import '../progress/domain/reading_plan.dart';

enum AppThemeMode { system, light, dark, sepia, highContrastLight, highContrastDark }

/// How the three readings are interleaved (MB 285:2).
enum ReadingMethod {
  /// Each verse twice, then its Targum (Arizal, Magen Avraham).
  verseByVerse,

  /// Each section (between parasha breaks) twice, then its Targum (Shelah, Gra).
  sectionBySection,

  /// Each aliyah twice, then its Targum.
  aliyahByAliyah,
}

/// What is read for the "echad Targum".
enum SecondReading {
  /// Targum Onkelos (SA 285:1).
  onkelos,

  /// Rashi's commentary, which may take the place of Targum (SA 285:2).
  rashi,

  /// Both Onkelos and Rashi (SA 285:2, "a God-fearing person").
  onkelosAndRashi,

  /// Rashi in English translation, for those who cannot understand the
  /// Hebrew (consult your rav).
  rashiEnglish,
}

enum NameStyle { sephardi, ashkenazi }

enum AppLanguage { system, english, hebrew }

/// What screen readers are given for scripture text.
enum ScreenReaderText {
  /// Vowels kept, cantillation removed (screen readers mishandle it).
  simplified,

  /// Letters only.
  consonants,

  /// Every mark, for braille displays.
  allMarks,
}

enum ScriptureFont {
  notoSerif('NotoSerifHebrew'),
  taameyFrank('TaameyFrank'),
  ezra('EzraSIL'),
  notoSans('NotoSansHebrew');

  const ScriptureFont(this.family);
  final String family;
}

enum UiFont {
  /// The platform font (bundled Noto Sans on the web).
  standard(null),
  atkinson('AtkinsonHyperlegibleNext'),
  lexend('Lexend'),
  openDyslexic('OpenDyslexic');

  const UiFont(this.family);
  final String? family;
}

enum LineWidth { narrow, medium, wide }

/// Every user preference, persisted as JSON.
class AppSettings {
  const AppSettings({
    this.israel = false,
    this.nusach = HaftarahNusach.ashkenazi,
    this.plan = ReadingPlanType.aliyahPerDay,
    this.lateWindow = LateWindow.tuesday,
    this.haftarahEnabled = true,
    this.haftarahRequired = false,
    this.tishaBavQuiet = true,
    this.cholHamoedQuiet = false,
    this.starterCatchUp = true,
    this.method = ReadingMethod.verseByVerse,
    this.secondReading = SecondReading.onkelos,
    this.repeatLastVerse = true,
    this.thirdReadingPrompts = true,
    this.showTranslation = false,
    this.showRashi = false,
    this.nameStyle = NameStyle.sephardi,
    this.theme = AppThemeMode.system,
    this.readingScale = 1.0,
    this.lineHeight = 1.9,
    this.wordSpacing = 0,
    this.letterSpacing = 0,
    this.showNikud = true,
    this.showTeamim = true,
    this.showKetiv = true,
    this.showVerseNumbers = true,
    this.justify = false,
    this.lineWidth = LineWidth.medium,
    this.scriptureFont = ScriptureFont.notoSerif,
    this.uiFont = UiFont.standard,
    this.boldText = false,
    this.focusMode = false,
    this.keepScreenOn = true,
    this.reduceMotion = false,
    this.haptics = true,
    this.screenReaderText = ScreenReaderText.simplified,
    this.divineName = DivineNameSpeech.adonai,
    this.speechRate = 0.45,
    this.showStreaks = true,
    this.cloudSync = false,
    this.dailyReminder = false,
    this.dailyReminderMinutes = 20 * 60,
    this.fridayReminder = false,
    this.fridayReminderMinutes = 10 * 60,
    this.checkInReminder = false,
    this.habitAnchor,
    this.language = AppLanguage.system,
    this.onboardingComplete = false,
    this.notificationPromptShown = false,
    this.joinDate,
    this.planHistory = const [],
  });

  // Calendar and customs
  final bool israel;
  final HaftarahNusach nusach;
  final ReadingPlanType plan;
  final LateWindow lateWindow;
  final bool haftarahEnabled;
  final bool haftarahRequired;
  final bool tishaBavQuiet;
  final bool cholHamoedQuiet;

  /// In the week the reader joins, spread the whole portion over the days
  /// left rather than keeping the usual days (see [ReadingPlanner.planFor]).
  final bool starterCatchUp;

  // Reading
  final ReadingMethod method;
  final SecondReading secondReading;

  /// Repeat the final verse in Hebrew after its Targum, to end with Mikra.
  final bool repeatLastVerse;

  /// Prompt a third Hebrew reading where there is no Targum/Rashi
  /// (e.g. Numbers 32:3; verses Rashi does not comment on, MB 285:5).
  final bool thirdReadingPrompts;

  /// Show the JPS 1917 English translation as a study aid.
  final bool showTranslation;

  /// Show Rashi alongside, as commentary (independent of [secondReading]).
  final bool showRashi;
  final NameStyle nameStyle;

  // Display
  final AppThemeMode theme;

  /// Multiplies the scripture font size on top of the system text scale.
  final double readingScale;
  final double lineHeight;
  final double wordSpacing;
  final double letterSpacing;
  final bool showNikud;
  final bool showTeamim;
  final bool showKetiv;
  final bool showVerseNumbers;
  final bool justify;
  final LineWidth lineWidth;
  final ScriptureFont scriptureFont;
  final UiFont uiFont;
  final bool boldText;

  /// Highlight the current verse and dim the rest.
  final bool focusMode;
  final bool keepScreenOn;

  // Accessibility
  final bool reduceMotion;
  final bool haptics;
  final ScreenReaderText screenReaderText;
  final DivineNameSpeech divineName;
  final double speechRate;

  // Streaks
  final bool showStreaks;

  /// Back up progress to the user's community account.
  final bool cloudSync;

  // Reminders
  final bool dailyReminder;
  final int dailyReminderMinutes;
  final bool fridayReminder;
  final int fridayReminderMinutes;

  /// After Shabbat, a reminder to log reading done from a printed Chumash.
  final bool checkInReminder;

  /// The routine the daily reading is anchored to ("after Shacharit").
  final String? habitAnchor;

  // App
  final AppLanguage language;
  final bool onboardingComplete;
  final bool notificationPromptShown;

  /// The day the user started; earlier days are never shown as missed.
  final LocalDate? joinDate;

  /// The plan settings ([planSettings]) over time, oldest first, so that
  /// each day is planned and judged by the settings in force then (see
  /// [settingsAt]): a change applies from the day it was made on, never to
  /// the days before (see [recordingPlanChange]). With no entries, the
  /// settings as they are now have always applied.
  final List<PlanSettingsEntry> planHistory;

  bool get ashkenaziNames => nameStyle == NameStyle.ashkenazi;

  bool get usesRashi =>
      secondReading == SecondReading.rashi ||
      secondReading == SecondReading.rashiEnglish ||
      secondReading == SecondReading.onkelosAndRashi;

  bool get usesOnkelos =>
      secondReading == SecondReading.onkelos || secondReading == SecondReading.onkelosAndRashi;

  /// The settings that decide how weeks are planned and judged, as they are
  /// now. The haftarah counts only while it is shown.
  PlanSettingsEntry get planSettings => PlanSettingsEntry(
        plan: plan,
        tishaBavQuiet: tishaBavQuiet,
        cholHamoedQuiet: cholHamoedQuiet,
        lateWindow: lateWindow,
        haftarahRequired: haftarahEnabled && haftarahRequired,
      );

  /// The plan settings in force on [day]: the latest entry of [planHistory]
  /// from then or before. The earliest entry also covers the days before it.
  PlanSettingsEntry settingsAt(LocalDate day) {
    if (planHistory.isEmpty) return planSettings;
    var found = planHistory.first;
    for (final e in planHistory) {
      if (e.from > day) break;
      found = e;
    }
    return found;
  }

  /// These settings, changed from [before] on [today] in a way that changes
  /// [planSettings]: [planHistory] records the change as applying from
  /// [today] on, so that the days before stay planned and judged as they
  /// were.
  AppSettings recordingPlanChange(AppSettings before, LocalDate today) {
    // Before the reader starts, nothing has been planned or judged.
    final joined = before.joinDate;
    if (joined == null) return this;
    final history = [
      // Until now, the settings before the change had always applied.
      if (planHistory.isEmpty) before.planSettings.startingOn(joined) else ...planHistory,
    ]..removeWhere((e) => e.from >= today); // superseded by this change
    final now = planSettings;
    // A change back to the settings in force before today needs no entry.
    if (history.isEmpty || !history.last.sameSettingsAs(now)) history.add(now.startingOn(today));
    return copyWith(planHistory: history);
  }

  AppSettings copyWith({
    bool? israel,
    HaftarahNusach? nusach,
    ReadingPlanType? plan,
    LateWindow? lateWindow,
    bool? haftarahEnabled,
    bool? haftarahRequired,
    bool? tishaBavQuiet,
    bool? cholHamoedQuiet,
    bool? starterCatchUp,
    ReadingMethod? method,
    SecondReading? secondReading,
    bool? repeatLastVerse,
    bool? thirdReadingPrompts,
    bool? showTranslation,
    bool? showRashi,
    NameStyle? nameStyle,
    AppThemeMode? theme,
    double? readingScale,
    double? lineHeight,
    double? wordSpacing,
    double? letterSpacing,
    bool? showNikud,
    bool? showTeamim,
    bool? showKetiv,
    bool? showVerseNumbers,
    bool? justify,
    LineWidth? lineWidth,
    ScriptureFont? scriptureFont,
    UiFont? uiFont,
    bool? boldText,
    bool? focusMode,
    bool? keepScreenOn,
    bool? reduceMotion,
    bool? haptics,
    ScreenReaderText? screenReaderText,
    DivineNameSpeech? divineName,
    double? speechRate,
    bool? showStreaks,
    bool? cloudSync,
    bool? dailyReminder,
    int? dailyReminderMinutes,
    bool? fridayReminder,
    int? fridayReminderMinutes,
    bool? checkInReminder,
    Object? habitAnchor = _keep,
    AppLanguage? language,
    bool? onboardingComplete,
    bool? notificationPromptShown,
    Object? joinDate = _keep,
    List<PlanSettingsEntry>? planHistory,
  }) =>
      AppSettings(
        israel: israel ?? this.israel,
        nusach: nusach ?? this.nusach,
        plan: plan ?? this.plan,
        lateWindow: lateWindow ?? this.lateWindow,
        haftarahEnabled: haftarahEnabled ?? this.haftarahEnabled,
        haftarahRequired: haftarahRequired ?? this.haftarahRequired,
        tishaBavQuiet: tishaBavQuiet ?? this.tishaBavQuiet,
        cholHamoedQuiet: cholHamoedQuiet ?? this.cholHamoedQuiet,
        starterCatchUp: starterCatchUp ?? this.starterCatchUp,
        method: method ?? this.method,
        secondReading: secondReading ?? this.secondReading,
        repeatLastVerse: repeatLastVerse ?? this.repeatLastVerse,
        thirdReadingPrompts: thirdReadingPrompts ?? this.thirdReadingPrompts,
        showTranslation: showTranslation ?? this.showTranslation,
        showRashi: showRashi ?? this.showRashi,
        nameStyle: nameStyle ?? this.nameStyle,
        theme: theme ?? this.theme,
        readingScale: readingScale ?? this.readingScale,
        lineHeight: lineHeight ?? this.lineHeight,
        wordSpacing: wordSpacing ?? this.wordSpacing,
        letterSpacing: letterSpacing ?? this.letterSpacing,
        showNikud: showNikud ?? this.showNikud,
        showTeamim: showTeamim ?? this.showTeamim,
        showKetiv: showKetiv ?? this.showKetiv,
        showVerseNumbers: showVerseNumbers ?? this.showVerseNumbers,
        justify: justify ?? this.justify,
        lineWidth: lineWidth ?? this.lineWidth,
        scriptureFont: scriptureFont ?? this.scriptureFont,
        uiFont: uiFont ?? this.uiFont,
        boldText: boldText ?? this.boldText,
        focusMode: focusMode ?? this.focusMode,
        keepScreenOn: keepScreenOn ?? this.keepScreenOn,
        reduceMotion: reduceMotion ?? this.reduceMotion,
        haptics: haptics ?? this.haptics,
        screenReaderText: screenReaderText ?? this.screenReaderText,
        divineName: divineName ?? this.divineName,
        speechRate: speechRate ?? this.speechRate,
        showStreaks: showStreaks ?? this.showStreaks,
        cloudSync: cloudSync ?? this.cloudSync,
        dailyReminder: dailyReminder ?? this.dailyReminder,
        dailyReminderMinutes: dailyReminderMinutes ?? this.dailyReminderMinutes,
        fridayReminder: fridayReminder ?? this.fridayReminder,
        fridayReminderMinutes: fridayReminderMinutes ?? this.fridayReminderMinutes,
        checkInReminder: checkInReminder ?? this.checkInReminder,
        habitAnchor: identical(habitAnchor, _keep) ? this.habitAnchor : habitAnchor as String?,
        language: language ?? this.language,
        onboardingComplete: onboardingComplete ?? this.onboardingComplete,
        notificationPromptShown: notificationPromptShown ?? this.notificationPromptShown,
        joinDate: identical(joinDate, _keep) ? this.joinDate : joinDate as LocalDate?,
        planHistory: planHistory ?? this.planHistory,
      );

  static const _keep = Object();

  Map<String, dynamic> toJson() => {
        'israel': israel,
        'nusach': nusach.name,
        'plan': plan.name,
        'lateWindow': lateWindow.name,
        'haftarahEnabled': haftarahEnabled,
        'haftarahRequired': haftarahRequired,
        'tishaBavQuiet': tishaBavQuiet,
        'cholHamoedQuiet': cholHamoedQuiet,
        'starterCatchUp': starterCatchUp,
        'method': method.name,
        'secondReading': secondReading.name,
        'repeatLastVerse': repeatLastVerse,
        'thirdReadingPrompts': thirdReadingPrompts,
        'showTranslation': showTranslation,
        'showRashi': showRashi,
        'nameStyle': nameStyle.name,
        'theme': theme.name,
        'readingScale': readingScale,
        'lineHeight': lineHeight,
        'wordSpacing': wordSpacing,
        'letterSpacing': letterSpacing,
        'showNikud': showNikud,
        'showTeamim': showTeamim,
        'showKetiv': showKetiv,
        'showVerseNumbers': showVerseNumbers,
        'justify': justify,
        'lineWidth': lineWidth.name,
        'scriptureFont': scriptureFont.name,
        'uiFont': uiFont.name,
        'boldText': boldText,
        'focusMode': focusMode,
        'keepScreenOn': keepScreenOn,
        'reduceMotion': reduceMotion,
        'haptics': haptics,
        'screenReaderText': screenReaderText.name,
        'divineName': divineName.name,
        'speechRate': speechRate,
        'showStreaks': showStreaks,
        'cloudSync': cloudSync,
        'dailyReminder': dailyReminder,
        'dailyReminderMinutes': dailyReminderMinutes,
        'fridayReminder': fridayReminder,
        'fridayReminderMinutes': fridayReminderMinutes,
        'checkInReminder': checkInReminder,
        'habitAnchor': habitAnchor,
        'language': language.name,
        'onboardingComplete': onboardingComplete,
        'notificationPromptShown': notificationPromptShown,
        'joinDate': joinDate?.rd,
        'planHistory': [for (final e in planHistory) e.toJson()],
      };

  /// Reads settings, tolerating missing or unknown values so that older and
  /// newer app versions can share stored data.
  factory AppSettings.fromJson(Map<String, dynamic> j) {
    const d = AppSettings();
    T e<T extends Enum>(List<T> values, Object? name, T fallback) =>
        values.where((v) => v.name == name).firstOrNull ?? fallback;
    bool b(String k, bool fallback) => j[k] is bool ? j[k] as bool : fallback;
    double n(String k, double fallback, double min, double max) =>
        j[k] is num ? (j[k] as num).toDouble().clamp(min, max) : fallback;
    int i(String k, int fallback) => j[k] is int ? j[k] as int : fallback;
    return AppSettings(
      israel: b('israel', d.israel),
      nusach: e(HaftarahNusach.values, j['nusach'], d.nusach),
      plan: e(ReadingPlanType.values, j['plan'], d.plan),
      lateWindow: e(LateWindow.values, j['lateWindow'], d.lateWindow),
      haftarahEnabled: b('haftarahEnabled', d.haftarahEnabled),
      haftarahRequired: b('haftarahRequired', d.haftarahRequired),
      tishaBavQuiet: b('tishaBavQuiet', d.tishaBavQuiet),
      cholHamoedQuiet: b('cholHamoedQuiet', d.cholHamoedQuiet),
      starterCatchUp: b('starterCatchUp', d.starterCatchUp),
      method: e(ReadingMethod.values, j['method'], d.method),
      secondReading: e(SecondReading.values, j['secondReading'], d.secondReading),
      repeatLastVerse: b('repeatLastVerse', d.repeatLastVerse),
      thirdReadingPrompts: b('thirdReadingPrompts', d.thirdReadingPrompts),
      showTranslation: b('showTranslation', d.showTranslation),
      showRashi: b('showRashi', d.showRashi),
      nameStyle: e(NameStyle.values, j['nameStyle'], d.nameStyle),
      theme: e(AppThemeMode.values, j['theme'], d.theme),
      readingScale: n('readingScale', d.readingScale, kMinReadingScale, kMaxReadingScale),
      lineHeight: n('lineHeight', d.lineHeight, 1.5, 3.0),
      wordSpacing: n('wordSpacing', d.wordSpacing, 0, 16),
      letterSpacing: n('letterSpacing', d.letterSpacing, 0, 4),
      showNikud: b('showNikud', d.showNikud),
      showTeamim: b('showTeamim', d.showTeamim),
      showKetiv: b('showKetiv', d.showKetiv),
      showVerseNumbers: b('showVerseNumbers', d.showVerseNumbers),
      justify: b('justify', d.justify),
      lineWidth: e(LineWidth.values, j['lineWidth'], d.lineWidth),
      scriptureFont: e(ScriptureFont.values, j['scriptureFont'], d.scriptureFont),
      uiFont: e(UiFont.values, j['uiFont'], d.uiFont),
      boldText: b('boldText', d.boldText),
      focusMode: b('focusMode', d.focusMode),
      keepScreenOn: b('keepScreenOn', d.keepScreenOn),
      reduceMotion: b('reduceMotion', d.reduceMotion),
      haptics: b('haptics', d.haptics),
      screenReaderText: e(ScreenReaderText.values, j['screenReaderText'], d.screenReaderText),
      divineName: e(DivineNameSpeech.values, j['divineName'], d.divineName),
      speechRate: n('speechRate', d.speechRate, 0.1, 1.0),
      showStreaks: b('showStreaks', d.showStreaks),
      cloudSync: b('cloudSync', d.cloudSync),
      dailyReminder: b('dailyReminder', d.dailyReminder),
      dailyReminderMinutes: i('dailyReminderMinutes', d.dailyReminderMinutes),
      fridayReminder: b('fridayReminder', d.fridayReminder),
      fridayReminderMinutes: i('fridayReminderMinutes', d.fridayReminderMinutes),
      checkInReminder: b('checkInReminder', d.checkInReminder),
      habitAnchor: j['habitAnchor'] as String?,
      language: e(AppLanguage.values, j['language'], d.language),
      onboardingComplete: b('onboardingComplete', d.onboardingComplete),
      notificationPromptShown: b('notificationPromptShown', d.notificationPromptShown),
      joinDate: j['joinDate'] is int ? LocalDate.fromRd(j['joinDate'] as int) : null,
      planHistory: _readPlanHistory(j['planHistory']),
    );
  }

  /// Reads [planHistory], oldest first, skipping entries that can't be read.
  /// Settings saved before it existed have none: the settings saved with
  /// them apply throughout, as they did then.
  static List<PlanSettingsEntry> _readPlanHistory(Object? raw) {
    if (raw is! List) return const [];
    final out = <PlanSettingsEntry>[];
    for (final e in raw) {
      try {
        out.add(PlanSettingsEntry.fromJson(e as Map<String, dynamic>));
      } catch (_) {
        // Skipped: an unreadable entry can't say when it applied.
      }
    }
    return out..sort((a, b) => a.from.compareTo(b.from));
  }
}

const kMinReadingScale = 0.5;
const kMaxReadingScale = 5.0;
