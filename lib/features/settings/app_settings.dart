import 'dart:math' as math;

import '../../core/calendar/city.dart';
import '../../core/calendar/local_date.dart';
import '../../core/calendar/zmanim.dart';
import '../../core/text/hebrew_text.dart';
import '../../data/models/parsha.dart';
import '../../services/hebrew_voice/voice_settings.dart';
import '../../services/tts.dart' show kDefaultSpeechRate;
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

  /// The whole parsha once, then again, then its Targum (or whatever the
  /// second reading is), aliyah after aliyah each time (ParshaOrder).
  wholeParsha,
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

/// The font of the Torah and the Targum. Persisted by name.
enum ScriptureFont {
  /// Bundled, and the only one with a bold weight, but it sets a meteg under
  /// the vowel beside it, not to its left, and a final kaf's qamats over its
  /// dagesh (אַרְאֶֽךָּ).
  notoSerif('NotoSerifHebrew'),

  /// The default, as on Sefaria: it sets every mark where a printed Chumash
  /// does. Loaded on demand (OptionalFonts), in its Medium weight alone.
  taameyFrank('TaameyFrank'),
  ezra('EzraSIL'),
  notoSans('NotoSansHebrew');

  const ScriptureFont(this.family);
  final String family;
}

/// The interface font. Persisted by name, so new values go at the end.
enum UiFont {
  /// The bundled Noto Sans (English UI) or Noto Sans Hebrew (Hebrew UI) on
  /// every platform, so the app looks the same everywhere.
  standard(null),
  atkinson('AtkinsonHyperlegibleNext'),
  lexend('Lexend'),
  openDyslexic('OpenDyslexic'),

  /// The platform's own interface font, such as Roboto or Segoe UI. The web
  /// can't reach it, so it gets the bundled font there.
  system(null);

  const UiFont(this.family);

  /// The accessibility font's family, or null for [standard] and [system],
  /// whose family depends on the UI language and the platform.
  final String? family;
}

/// The reading column's measure (ScriptureStyles.maxLineWidth).
enum LineWidth { narrow, medium, wide }

/// Whether scripture is justified, flush at both sides as a printed Chumash
/// sets it (ScriptureStyles.justifies). Persisted by name.
enum JustifyMode {
  /// The Hebrew and Aramaic, where the column is wide enough for its spaces
  /// to stretch evenly; English never.
  auto,

  /// Every paragraph, the English too, whatever the column.
  always,

  /// None: every line ends where its words do (WCAG 1.4.8).
  never,
}

/// The line spacing of scripture, as a multiple of its size: never below 1.6,
/// so that lower vowels and cantillation marks are never clipped
/// (DESIGN.md §8).
const kMinLineHeight = 1.6;
const kMaxLineHeight = 3.0;

/// The Rashi script (DESIGN_SYSTEM.md §4.7), loaded only once it is chosen
/// (OptionalFonts).
const kRashiScriptFamily = 'NotoRashiHebrew';

/// Whose public Torah reading the weeks follow. For a few weeks after Pesach
/// or Shavuot, Israel can be a parsha ahead: when the last day of the
/// festival outside Israel falls on Shabbat, Israel already reads the next
/// portion.
enum ReadingSchedule { israel, diaspora }

/// The daily routine the reader ties the day's reading to ("After I finish
/// Shacharit"), which the daily reminder names. Persisted by name.
enum HabitAnchor {
  shacharit,
  breakfast,
  commute,
  dinner,
  bed;

  /// The anchor saved as [raw]: its name or, from versions that saved the
  /// chip's label instead, that label in English or Hebrew. Anything else
  /// is no anchor.
  static HabitAnchor? parse(Object? raw) => values.where((a) => a.name == raw).firstOrNull ?? _legacyLabels[raw];

  /// When the routine usually comes, in minutes after midnight: the time a
  /// daily reminder tied to it suggests, so that a reminder naming a morning
  /// routine doesn't come in the evening.
  int get usualMinutes => switch (this) {
        shacharit || breakfast => 7 * 60 + 30,
        commute => 8 * 60,
        dinner => 20 * 60,
        bed => 21 * 60 + 30,
      };

  /// Whether a reminder at [minutes] after midnight may name the routine:
  /// within four hours of its [usualMinutes], either side of midnight, so
  /// that an 8 PM reminder never says "After Shacharit".
  bool isNear(int minutes) {
    final apart = (usualMinutes - minutes).abs();
    return math.min(apart, 24 * 60 - apart) <= 4 * 60;
  }

  /// The daily reminder's time, now [minutes], once the routine [next] is
  /// chosen in place of [previous]: [next]'s usual time while [minutes] is
  /// only a suggestion (the default, or [previous]'s usual time), and
  /// otherwise, or when the routine is cleared, the time as it is.
  static int reminderMinutes(int minutes, {required HabitAnchor? previous, required HabitAnchor? next}) {
    final suggested = minutes == const AppSettings().dailyReminderMinutes || minutes == previous?.usualMinutes;
    return next != null && suggested ? next.usualMinutes : minutes;
  }

  static const _legacyLabels = {
    'finish Shacharit': shacharit,
    'eat breakfast': breakfast,
    'start my commute': commute,
    'finish dinner': dinner,
    'get ready for bed': bed,
    'אסיים שחרית': shacharit,
    'אאכל ארוחת בוקר': breakfast,
    'אצא לדרך': commute,
    'אסיים ארוחת ערב': dinner,
    'אתכונן לשינה': bed,
  };
}

/// Every user preference, persisted as JSON.
class AppSettings {
  const AppSettings({
    this.readingSchedule = ReadingSchedule.diaspora,
    this.oneDayYomTov = false,
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
    this.repeatLastVerseTouched = false,
    this.thirdReadingPrompts = true,
    this.skipLastVerseWithRashi = false,
    this.showTranslation = false,
    this.showRashi = false,
    this.rashiScript = false,
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
    this.copyDivineNameAsHashem = true,
    this.justifyMode = JustifyMode.auto,
    this.lineWidth = LineWidth.medium,
    this.scriptureFont = ScriptureFont.taameyFrank,
    this.uiFont = UiFont.standard,
    this.boldText = false,
    this.focusMode = false,
    this.listenAlong = false,
    this.parallelColumns = true,
    this.fullTextWholeParsha = false,
    this.keepScreenOn = true,
    this.reduceMotion = false,
    this.haptics = true,
    this.singleKeyShortcuts = true,
    this.screenReaderText = ScreenReaderText.simplified,
    this.divineName = DivineNameSpeech.adonai,
    this.speechRate = kDefaultSpeechRate,
    this.voice = const VoiceSettings(),
    this.showStreaks = true,
    this.cloudSync = false,
    this.autoUpdateCheck = true,
    this.dailyReminder = false,
    this.dailyReminderMinutes = 20 * 60,
    this.fridayReminder = false,
    this.fridayReminderMinutes = 10 * 60,
    this.checkInReminder = false,
    this.habitAnchor,
    this.city,
    this.candleMinutesOverride,
    this.havdalah = HavdalahRule.degrees85,
    this.cityOfferAnswered = false,
    this.language = AppLanguage.system,
    this.onboardingComplete = false,
    this.notificationPromptShown = false,
    this.joinDate,
    this.planHistory = const [],
    this.checkInAnsweredFor,
    this.pauseEndSeen,
    this.lastStripAck,
    this.stripNoteShownOn,
    this.divergenceDismissedFor,
  });

  // Calendar and customs

  /// The reading heard in synagogue, which decides each week's portion.
  final ReadingSchedule readingSchedule;

  /// Whether Yom Tov is kept for one day, as in Israel, rather than two.
  /// This decides which days are free of reading and reminders, apart from
  /// [readingSchedule]: a visitor usually keeps their home custom wherever
  /// they hear the reading.
  final bool oneDayYomTov;
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

  /// Repeat the final verse in Hebrew after its Targum, to end with Mikrah.
  /// Until the reader sets it ([repeatLastVerseTouched]), it follows the
  /// custom (see [withNusach]).
  final bool repeatLastVerse;

  /// Whether the reader has set [repeatLastVerse] themselves.
  final bool repeatLastVerseTouched;

  /// Suggest a third Hebrew reading where Onkelos is mostly names (Numbers
  /// 32:3) or, when Rashi replaces the Targum, where Rashi is silent (MB
  /// 285:5).
  final bool thirdReadingPrompts;

  /// With Rashi as the second reading and Rashi shown alongside, leave out the
  /// final verse repeated at the end ([repeatLastVerse]): the reader's last page.
  final bool skipLastVerseWithRashi;

  /// Show the JPS 1917 English translation as a study aid.
  final bool showTranslation;

  /// Show Rashi alongside, as commentary (independent of [secondReading]).
  final bool showRashi;

  /// Set Rashi's commentary in Rashi script, as printed Chumashim do, rather
  /// than in square letters.
  final bool rashiScript;
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

  /// Write the Divine Names as ה׳ and אלקים in a verse copied, shared or
  /// quoted in a post, which may be erased or thrown away (DESIGN.md §3).
  /// Named, and stored, for the first of them, which was once the only one.
  final bool copyDivineNameAsHashem;
  final JustifyMode justifyMode;
  final LineWidth lineWidth;
  final ScriptureFont scriptureFont;
  final UiFont uiFont;
  final bool boldText;

  /// Highlight the current verse and dim the rest.
  final bool focusMode;

  /// In the guided reader, Listen goes on from each reading to the next by
  /// itself, to the end of the aliyah: Mikrah, Mikrah, Targum, hands-free.
  final bool listenAlong;

  /// On a wide screen, the full text sets the Targum (or, without it, the
  /// translation) in a column beside each verse rather than beneath it
  /// (ScriptureStyles.parallelColumns).
  final bool parallelColumns;

  /// The full text shows the whole parsha, aliyah after aliyah, rather than
  /// the one aliyah opened.
  final bool fullTextWholeParsha;
  final bool keepScreenOn;

  // Accessibility
  final bool reduceMotion;
  final bool haptics;

  /// On the web, where the browser keeps the reader's Ctrl chords for
  /// itself, the reader takes single keys instead (T, N, L, + and −). They
  /// can be turned off for speech input and screen-reader quick keys
  /// (WCAG 2.1.4).
  final bool singleKeyShortcuts;
  final ScreenReaderText screenReaderText;
  final DivineNameSpeech divineName;
  final double speechRate;

  /// The app's own Hebrew voices: which reads what, how they say it, and
  /// how they sound.
  final VoiceSettings voice;

  // Streaks
  final bool showStreaks;

  /// Back up progress to the user's community account.
  final bool cloudSync;

  /// Whether the Windows app looks for a new version by itself, twice a day
  /// at most (lib/services/updates/), in a build that looks for any.
  final bool autoUpdateCheck;

  // Reminders
  final bool dailyReminder;
  final int dailyReminderMinutes;
  final bool fridayReminder;
  final int fridayReminderMinutes;

  /// After Shabbat, a reminder to log reading done from a printed Chumash.
  final bool checkInReminder;

  /// The routine the daily reading is tied to, which the daily reminder
  /// names; null if none is chosen.
  final HabitAnchor? habitAnchor;

  // Shabbat times

  /// The place whose candle-lighting and Havdalah times are shown, chosen
  /// from a list rather than found by location; null until one is chosen.
  /// It stays on the device.
  final City? city;

  /// How many minutes before sunset candles are lit, as the reader's luach
  /// has it, in place of the city's own ([City.candleMinutes]); null for the
  /// city's. Choosing another city goes back to its own.
  final int? candleMinutesOverride;

  /// When Shabbat ends, as the reader's luach has it.
  final HavdalahRule havdalah;

  /// Whether the offer of a city, in Settings → Reminders, has been answered:
  /// put aside, or a city chosen. Until then it is made while reminders are
  /// on without a city, however they were turned on.
  final bool cityOfferAnswered;

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

  // What Today has asked and said on this device, which restoring a
  // backup's settings keeps (see [keepingTodaysNotesOf])

  /// The week whose after-Shabbat check-in was last answered: logged,
  /// finished, or put aside for this time. Until then it is asked on Today
  /// for as long as the week can still count as late.
  final String? checkInAnsweredFor;

  /// The last day of the pause whose end Today last welcomed the reader
  /// back from, once they put the welcome away.
  final LocalDate? pauseEndSeen;

  /// The day the reader last put away the note under Today's week strip:
  /// what was decided by then (a grace day spent, for one) is not said
  /// again.
  final LocalDate? lastStripAck;

  /// The day a note under the week strip was last on show. A note is said
  /// for the day it is first shown, and from the next day it counts as
  /// acknowledged, as though put away.
  final LocalDate? stripNoteShownOn;

  /// The week whose notice that Israel and the Diaspora read different
  /// portions the reader last put away: it is not shown again that week,
  /// but comes back the next if the two still differ.
  final String? divergenceDismissedFor;

  bool get ashkenaziNames => nameStyle == NameStyle.ashkenazi;

  /// The city for Shabbat times with the reader's customs for them, which
  /// everything that gives the times follows; null without a city.
  ShabbatCity? get shabbatCity => switch (city) {
        null => null,
        final city => ShabbatCity(city, candleMinutes: candleMinutesOverride, havdalah: havdalah),
      };

  /// These settings with [nusach] as the reader's custom. Until the reader
  /// sets [repeatLastVerse] themselves, it follows the custom: Chabad's is
  /// not to repeat the last verse.
  AppSettings withNusach(HaftarahNusach nusach) => copyWith(
        nusach: nusach,
        repeatLastVerse: repeatLastVerseTouched ? null : nusach != HaftarahNusach.chabad,
      );

  /// These settings with [repeatLastVerse] set by the reader, so that it no
  /// longer follows the custom.
  AppSettings withRepeatLastVerse(bool repeat) => copyWith(repeatLastVerse: repeat, repeatLastVerseTouched: true);

  /// The opt-in font families these settings show text in, which are loaded
  /// on demand (OptionalFonts); null for a bundled font. The Rashi script
  /// only while Rashi is shown in it.
  List<String?> get optionalFonts =>
      [uiFont.family, scriptureFont.family, if (rashiScript && showsRashi) kRashiScriptFamily];

  /// Whether the reader shows Rashi: beside the Torah, or as the second
  /// reading.
  bool get showsRashi => showRashi || usesRashi;

  /// Whether the reader leaves out the final verse repeated at the end: the
  /// setting is on, and Rashi is both the second reading and shown alongside.
  bool get skipsRepeatedVerse => skipLastVerseWithRashi && usesRashi && showRashi;

  /// Whether the reading heard and the days of Yom Tov kept are those of
  /// different places, as for a visitor to or from Israel.
  bool get readingAndYomTovDiffer => (readingSchedule == ReadingSchedule.israel) != oneDayYomTov;

  /// These settings for someone spending Shabbat in [place], who hears its
  /// reading and keeps its days of Yom Tov.
  AppSettings locatedIn(ReadingSchedule place) =>
      copyWith(readingSchedule: place, oneDayYomTov: place == ReadingSchedule.israel);

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
    ReadingSchedule? readingSchedule,
    bool? oneDayYomTov,
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
    bool? repeatLastVerseTouched,
    bool? thirdReadingPrompts,
    bool? skipLastVerseWithRashi,
    bool? showTranslation,
    bool? showRashi,
    bool? rashiScript,
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
    bool? copyDivineNameAsHashem,
    JustifyMode? justifyMode,
    LineWidth? lineWidth,
    ScriptureFont? scriptureFont,
    UiFont? uiFont,
    bool? boldText,
    bool? focusMode,
    bool? listenAlong,
    bool? parallelColumns,
    bool? fullTextWholeParsha,
    bool? keepScreenOn,
    bool? reduceMotion,
    bool? haptics,
    bool? singleKeyShortcuts,
    ScreenReaderText? screenReaderText,
    DivineNameSpeech? divineName,
    double? speechRate,
    VoiceSettings? voice,
    bool? showStreaks,
    bool? cloudSync,
    bool? autoUpdateCheck,
    bool? dailyReminder,
    int? dailyReminderMinutes,
    bool? fridayReminder,
    int? fridayReminderMinutes,
    bool? checkInReminder,
    Object? habitAnchor = _keep,
    Object? city = _keep,
    Object? candleMinutesOverride = _keep,
    HavdalahRule? havdalah,
    bool? cityOfferAnswered,
    AppLanguage? language,
    bool? onboardingComplete,
    bool? notificationPromptShown,
    Object? joinDate = _keep,
    List<PlanSettingsEntry>? planHistory,
    Object? checkInAnsweredFor = _keep,
    Object? pauseEndSeen = _keep,
    Object? lastStripAck = _keep,
    Object? stripNoteShownOn = _keep,
    Object? divergenceDismissedFor = _keep,
  }) =>
      AppSettings(
        readingSchedule: readingSchedule ?? this.readingSchedule,
        oneDayYomTov: oneDayYomTov ?? this.oneDayYomTov,
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
        repeatLastVerseTouched: repeatLastVerseTouched ?? this.repeatLastVerseTouched,
        thirdReadingPrompts: thirdReadingPrompts ?? this.thirdReadingPrompts,
        skipLastVerseWithRashi: skipLastVerseWithRashi ?? this.skipLastVerseWithRashi,
        showTranslation: showTranslation ?? this.showTranslation,
        showRashi: showRashi ?? this.showRashi,
        rashiScript: rashiScript ?? this.rashiScript,
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
        copyDivineNameAsHashem: copyDivineNameAsHashem ?? this.copyDivineNameAsHashem,
        justifyMode: justifyMode ?? this.justifyMode,
        lineWidth: lineWidth ?? this.lineWidth,
        scriptureFont: scriptureFont ?? this.scriptureFont,
        uiFont: uiFont ?? this.uiFont,
        boldText: boldText ?? this.boldText,
        focusMode: focusMode ?? this.focusMode,
        listenAlong: listenAlong ?? this.listenAlong,
        parallelColumns: parallelColumns ?? this.parallelColumns,
        fullTextWholeParsha: fullTextWholeParsha ?? this.fullTextWholeParsha,
        keepScreenOn: keepScreenOn ?? this.keepScreenOn,
        reduceMotion: reduceMotion ?? this.reduceMotion,
        haptics: haptics ?? this.haptics,
        singleKeyShortcuts: singleKeyShortcuts ?? this.singleKeyShortcuts,
        screenReaderText: screenReaderText ?? this.screenReaderText,
        divineName: divineName ?? this.divineName,
        speechRate: speechRate ?? this.speechRate,
        voice: voice ?? this.voice,
        showStreaks: showStreaks ?? this.showStreaks,
        cloudSync: cloudSync ?? this.cloudSync,
        autoUpdateCheck: autoUpdateCheck ?? this.autoUpdateCheck,
        dailyReminder: dailyReminder ?? this.dailyReminder,
        dailyReminderMinutes: dailyReminderMinutes ?? this.dailyReminderMinutes,
        fridayReminder: fridayReminder ?? this.fridayReminder,
        fridayReminderMinutes: fridayReminderMinutes ?? this.fridayReminderMinutes,
        checkInReminder: checkInReminder ?? this.checkInReminder,
        habitAnchor: identical(habitAnchor, _keep) ? this.habitAnchor : habitAnchor as HabitAnchor?,
        city: identical(city, _keep) ? this.city : city as City?,
        candleMinutesOverride:
            identical(candleMinutesOverride, _keep) ? this.candleMinutesOverride : candleMinutesOverride as int?,
        havdalah: havdalah ?? this.havdalah,
        cityOfferAnswered: cityOfferAnswered ?? this.cityOfferAnswered,
        language: language ?? this.language,
        onboardingComplete: onboardingComplete ?? this.onboardingComplete,
        notificationPromptShown: notificationPromptShown ?? this.notificationPromptShown,
        joinDate: identical(joinDate, _keep) ? this.joinDate : joinDate as LocalDate?,
        planHistory: planHistory ?? this.planHistory,
        checkInAnsweredFor:
            identical(checkInAnsweredFor, _keep) ? this.checkInAnsweredFor : checkInAnsweredFor as String?,
        pauseEndSeen: identical(pauseEndSeen, _keep) ? this.pauseEndSeen : pauseEndSeen as LocalDate?,
        lastStripAck: identical(lastStripAck, _keep) ? this.lastStripAck : lastStripAck as LocalDate?,
        stripNoteShownOn:
            identical(stripNoteShownOn, _keep) ? this.stripNoteShownOn : stripNoteShownOn as LocalDate?,
        divergenceDismissedFor: identical(divergenceDismissedFor, _keep)
            ? this.divergenceDismissedFor
            : divergenceDismissedFor as String?,
      );

  /// These settings with what Today has said on this device taken from
  /// [device]: restoring a backup's settings doesn't ask again what this
  /// device has asked, or say again what it has said.
  AppSettings keepingTodaysNotesOf(AppSettings device) => copyWith(
        checkInAnsweredFor: device.checkInAnsweredFor,
        pauseEndSeen: device.pauseEndSeen,
        lastStripAck: device.lastStripAck,
        stripNoteShownOn: device.stripNoteShownOn,
        divergenceDismissedFor: device.divergenceDismissedFor,
      );

  static const _keep = Object();

  Map<String, dynamic> toJson() => {
        'readingSchedule': readingSchedule.name,
        'oneDayYomTov': oneDayYomTov,
        // For versions from before the two were separate, which read this
        // one setting for both.
        'israel': readingSchedule == ReadingSchedule.israel,
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
        'repeatLastVerseTouched': repeatLastVerseTouched,
        'thirdReadingPrompts': thirdReadingPrompts,
        'skipLastVerseWithRashi': skipLastVerseWithRashi,
        'showTranslation': showTranslation,
        'showRashi': showRashi,
        'rashiScript': rashiScript,
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
        'copyDivineNameAsHashem': copyDivineNameAsHashem,
        'justifyMode': justifyMode.name,
        // For versions from before Auto, which read a switch.
        'justify': justifyMode == JustifyMode.always,
        'lineWidth': lineWidth.name,
        'scriptureTypeface': scriptureFont.name,
        // For versions from before Taamey Frank was the default, which read
        // this one.
        'scriptureFont': scriptureFont.name,
        'uiFont': uiFont.name,
        'boldText': boldText,
        'focusMode': focusMode,
        'listenAlong': listenAlong,
        'parallelColumns': parallelColumns,
        'fullTextWholeParsha': fullTextWholeParsha,
        'keepScreenOn': keepScreenOn,
        'reduceMotion': reduceMotion,
        'haptics': haptics,
        'singleKeyShortcuts': singleKeyShortcuts,
        'screenReaderText': screenReaderText.name,
        'divineName': divineName.name,
        'speechRate': speechRate,
        'voice': voice.toJson(),
        'showStreaks': showStreaks,
        'cloudSync': cloudSync,
        'autoUpdateCheck': autoUpdateCheck,
        'dailyReminder': dailyReminder,
        'dailyReminderMinutes': dailyReminderMinutes,
        'fridayReminder': fridayReminder,
        'fridayReminderMinutes': fridayReminderMinutes,
        'checkInReminder': checkInReminder,
        'habitAnchor': habitAnchor?.name,
        'city': city?.toJson(),
        'candleMinutesOverride': candleMinutesOverride,
        'havdalah': havdalah.name,
        'cityOfferAnswered': cityOfferAnswered,
        'language': language.name,
        'onboardingComplete': onboardingComplete,
        'notificationPromptShown': notificationPromptShown,
        'joinDate': joinDate?.rd,
        'planHistory': [for (final e in planHistory) e.toJson()],
        'checkInAnsweredFor': checkInAnsweredFor,
        'pauseEndSeen': pauseEndSeen?.rd,
        'lastStripAck': lastStripAck?.rd,
        'stripNoteShownOn': stripNoteShownOn?.rd,
        'divergenceDismissedFor': divergenceDismissedFor,
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
    LocalDate? date(String k) => j[k] is int ? LocalDate.fromRd(j[k] as int) : null;
    final nusach = e(HaftarahNusach.values, j['nusach'], d.nusach);
    // Settings saved before this was kept may have turned the repeat off:
    // that was the reader's choice, since it was on by default.
    final repeatTouched = b('repeatLastVerseTouched', j['repeatLastVerse'] == false);
    // Settings saved before the reading and the days of Yom Tov were
    // separate have one 'israel' setting, which decided both.
    final located = switch (j['israel']) {
      true => d.locatedIn(ReadingSchedule.israel),
      false => d.locatedIn(ReadingSchedule.diaspora),
      _ => d,
    };
    final read = AppSettings(
      readingSchedule: e(ReadingSchedule.values, j['readingSchedule'], located.readingSchedule),
      oneDayYomTov: b('oneDayYomTov', located.oneDayYomTov),
      nusach: nusach,
      plan: e(ReadingPlanType.values, j['plan'], d.plan),
      lateWindow: e(LateWindow.values, j['lateWindow'], d.lateWindow),
      haftarahEnabled: b('haftarahEnabled', d.haftarahEnabled),
      haftarahRequired: b('haftarahRequired', d.haftarahRequired),
      tishaBavQuiet: b('tishaBavQuiet', d.tishaBavQuiet),
      cholHamoedQuiet: b('cholHamoedQuiet', d.cholHamoedQuiet),
      starterCatchUp: b('starterCatchUp', d.starterCatchUp),
      method: e(ReadingMethod.values, j['method'], d.method),
      secondReading: e(SecondReading.values, j['secondReading'], d.secondReading),
      // Until the reader sets it, it follows the custom (see withNusach).
      // Chabad settings saved before then have it on only because that was
      // the default.
      repeatLastVerse: repeatTouched ? b('repeatLastVerse', d.repeatLastVerse) : nusach != HaftarahNusach.chabad,
      repeatLastVerseTouched: repeatTouched,
      thirdReadingPrompts: b('thirdReadingPrompts', d.thirdReadingPrompts),
      skipLastVerseWithRashi: b('skipLastVerseWithRashi', d.skipLastVerseWithRashi),
      showTranslation: b('showTranslation', d.showTranslation),
      showRashi: b('showRashi', d.showRashi),
      rashiScript: b('rashiScript', d.rashiScript),
      nameStyle: e(NameStyle.values, j['nameStyle'], d.nameStyle),
      theme: e(AppThemeMode.values, j['theme'], d.theme),
      readingScale: n('readingScale', d.readingScale, kMinReadingScale, kMaxReadingScale),
      // Spacing saved below the minimum (1.5 was once allowed) is raised to it.
      lineHeight: n('lineHeight', d.lineHeight, kMinLineHeight, kMaxLineHeight),
      wordSpacing: n('wordSpacing', d.wordSpacing, 0, 16),
      letterSpacing: n('letterSpacing', d.letterSpacing, 0, 4),
      showNikud: b('showNikud', d.showNikud),
      showTeamim: b('showTeamim', d.showTeamim),
      showKetiv: b('showKetiv', d.showKetiv),
      showVerseNumbers: b('showVerseNumbers', d.showVerseNumbers),
      copyDivineNameAsHashem: b('copyDivineNameAsHashem', d.copyDivineNameAsHashem),
      // Settings saved before Auto have a switch, off by default: on was the
      // reader's choice, and off only the default, which Auto now is.
      justifyMode: e(JustifyMode.values, j['justifyMode'], j['justify'] == true ? JustifyMode.always : d.justifyMode),
      lineWidth: e(LineWidth.values, j['lineWidth'], d.lineWidth),
      // Settings saved before 'scriptureTypeface' have Noto Serif Hebrew only
      // because it was the default then: they move to Taamey Frank, which
      // sets the meteg and a final kaf's marks correctly.
      scriptureFont: j.containsKey('scriptureTypeface')
          ? e(ScriptureFont.values, j['scriptureTypeface'], d.scriptureFont)
          : j['scriptureFont'] == ScriptureFont.notoSerif.name
              ? d.scriptureFont
              : e(ScriptureFont.values, j['scriptureFont'], d.scriptureFont),
      uiFont: e(UiFont.values, j['uiFont'], d.uiFont),
      boldText: b('boldText', d.boldText),
      focusMode: b('focusMode', d.focusMode),
      listenAlong: b('listenAlong', d.listenAlong),
      parallelColumns: b('parallelColumns', d.parallelColumns),
      fullTextWholeParsha: b('fullTextWholeParsha', d.fullTextWholeParsha),
      keepScreenOn: b('keepScreenOn', d.keepScreenOn),
      reduceMotion: b('reduceMotion', d.reduceMotion),
      haptics: b('haptics', d.haptics),
      singleKeyShortcuts: b('singleKeyShortcuts', d.singleKeyShortcuts),
      screenReaderText: e(ScreenReaderText.values, j['screenReaderText'], d.screenReaderText),
      divineName: e(DivineNameSpeech.values, j['divineName'], d.divineName),
      speechRate: n('speechRate', d.speechRate, 0.1, 1.0),
      voice: VoiceSettings.fromJson(j['voice']),
      showStreaks: b('showStreaks', d.showStreaks),
      cloudSync: b('cloudSync', d.cloudSync),
      autoUpdateCheck: b('autoUpdateCheck', d.autoUpdateCheck),
      dailyReminder: b('dailyReminder', d.dailyReminder),
      dailyReminderMinutes: i('dailyReminderMinutes', d.dailyReminderMinutes),
      fridayReminder: b('fridayReminder', d.fridayReminder),
      fridayReminderMinutes: i('fridayReminderMinutes', d.fridayReminderMinutes),
      checkInReminder: b('checkInReminder', d.checkInReminder),
      habitAnchor: HabitAnchor.parse(j['habitAnchor']),
      city: _readCity(j['city']),
      candleMinutesOverride: _readCandleMinutes(j['candleMinutesOverride']),
      havdalah: e(HavdalahRule.values, j['havdalah'], d.havdalah),
      cityOfferAnswered: b('cityOfferAnswered', d.cityOfferAnswered),
      language: e(AppLanguage.values, j['language'], d.language),
      onboardingComplete: b('onboardingComplete', d.onboardingComplete),
      notificationPromptShown: b('notificationPromptShown', d.notificationPromptShown),
      joinDate: date('joinDate'),
      planHistory: _readPlanHistory(j['planHistory']),
      checkInAnsweredFor: j['checkInAnsweredFor'] is String ? j['checkInAnsweredFor'] as String : null,
      pauseEndSeen: date('pauseEndSeen'),
      lastStripAck: date('lastStripAck'),
      stripNoteShownOn: date('stripNoteShownOn'),
      divergenceDismissedFor: j['divergenceDismissedFor'] is String ? j['divergenceDismissedFor'] as String : null,
    );
    // The dyslexia setup of a version with the switch turned it off, for a
    // ragged edge: read as Auto, its narrow column would be justified on a
    // tablet, and the setup no longer shown as chosen. Display settings
    // still as that setup left them keep it, as Never.
    if (!j.containsKey('justifyMode') && j['justify'] == false) {
      final never = read.copyWith(justifyMode: JustifyMode.never);
      if (presetActive(never, DisplayPreset.dyslexia)) return never;
    }
    return read;
  }

  /// Reads [city], forgetting one that can't be read: choosing it again is
  /// better than wrong times.
  static City? _readCity(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    try {
      return City.fromJson(raw);
    } on FormatException {
      return null;
    }
  }

  /// Reads [candleMinutesOverride]: minutes before sunset, within what a
  /// city's own may be ([City.fromJson]); anything else is the city's.
  static int? _readCandleMinutes(Object? raw) => raw is int && raw >= 0 && raw <= 90 ? raw : null;

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

/// Ready-made combinations of display settings, offered in Settings →
/// Accessibility.
enum DisplayPreset { largePrint, dyslexia, highContrast, lowVision, reset }

/// [s] with the display settings [p] sets. High contrast is dark or light as
/// the reader prefers ([darkPreferred]): as the theme in use is.
AppSettings applyPreset(AppSettings s, DisplayPreset p, {required bool darkPreferred}) {
  const d = AppSettings();
  final highContrast = darkPreferred ? AppThemeMode.highContrastDark : AppThemeMode.highContrastLight;
  switch (p) {
    case DisplayPreset.largePrint:
      return s.copyWith(readingScale: 1.8, lineHeight: 2.1, lineWidth: LineWidth.medium);
    case DisplayPreset.dyslexia:
      return s.copyWith(
        uiFont: UiFont.lexend,
        wordSpacing: 4,
        lineHeight: 2.2,
        showTeamim: false,
        focusMode: true,
        justifyMode: JustifyMode.never,
        lineWidth: LineWidth.narrow,
      );
    case DisplayPreset.highContrast:
      return s.copyWith(theme: highContrast, boldText: true);
    case DisplayPreset.lowVision:
      return s.copyWith(
        readingScale: 2.6,
        lineHeight: 2.0,
        theme: highContrast,
        boldText: true,
        focusMode: true,
        lineWidth: LineWidth.wide,
      );
    case DisplayPreset.reset:
      return s.copyWith(
        theme: d.theme,
        readingScale: d.readingScale,
        lineHeight: d.lineHeight,
        wordSpacing: d.wordSpacing,
        letterSpacing: d.letterSpacing,
        showNikud: d.showNikud,
        showTeamim: d.showTeamim,
        justifyMode: d.justifyMode,
        lineWidth: d.lineWidth,
        scriptureFont: d.scriptureFont,
        uiFont: d.uiFont,
        boldText: d.boldText,
        focusMode: d.focusMode,
      );
  }
}

/// Whether the display settings of [s] are those [p] sets, in either of its
/// high contrast themes; the settings it leaves alone may be anything. A
/// size or spacing within a hair of the preset's counts, as a slider's steps
/// add up to one.
bool presetActive(AppSettings s, DisplayPreset p) =>
    [false, true].any((dark) => _sameDisplay(applyPreset(s, p, darkPreferred: dark), s));

/// [now] with the display settings a preset may set (those [presetActive]
/// compares) put back from [after] to [before], as undoing a preset that
/// turned [before] into [after]: each that still holds what the preset left
/// in it. Those changed since, and every other setting, stay as they are
/// now, so that an Undo pressed later takes back the preset alone.
AppSettings undoDisplayChange(AppSettings now, {required AppSettings before, required AppSettings after}) {
  T back<T>(T Function(AppSettings s) field) => field(now) == field(after) ? field(before) : field(now);
  return now.copyWith(
    theme: back((s) => s.theme),
    readingScale: back((s) => s.readingScale),
    lineHeight: back((s) => s.lineHeight),
    wordSpacing: back((s) => s.wordSpacing),
    letterSpacing: back((s) => s.letterSpacing),
    showNikud: back((s) => s.showNikud),
    showTeamim: back((s) => s.showTeamim),
    justifyMode: back((s) => s.justifyMode),
    lineWidth: back((s) => s.lineWidth),
    scriptureFont: back((s) => s.scriptureFont),
    uiFont: back((s) => s.uiFont),
    boldText: back((s) => s.boldText),
    focusMode: back((s) => s.focusMode),
  );
}

/// Whether [a] and [b] show the text alike: every display setting a preset
/// may set. Applying a preset changes only its own, so comparing them all
/// compares just those.
bool _sameDisplay(AppSettings a, AppSettings b) {
  bool near(double x, double y) => (x - y).abs() < 1e-6;
  return a.theme == b.theme &&
      near(a.readingScale, b.readingScale) &&
      near(a.lineHeight, b.lineHeight) &&
      near(a.wordSpacing, b.wordSpacing) &&
      near(a.letterSpacing, b.letterSpacing) &&
      a.showNikud == b.showNikud &&
      a.showTeamim == b.showTeamim &&
      a.justifyMode == b.justifyMode &&
      a.lineWidth == b.lineWidth &&
      a.scriptureFont == b.scriptureFont &&
      a.uiFont == b.uiFont &&
      a.boldText == b.boldText &&
      a.focusMode == b.focusMode;
}
