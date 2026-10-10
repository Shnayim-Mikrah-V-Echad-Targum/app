// ignore_for_file: text_direction_code_point_in_literal

// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Shnayim Mikra';

  @override
  String get appTitleFull => 'Shnayim Mikra v\'Echad Targum';

  @override
  String get navToday => 'Today';

  @override
  String get navParsha => 'Parsha';

  @override
  String get navProgress => 'Progress';

  @override
  String get navCommunity => 'Community';

  @override
  String get navSettings => 'Settings';

  @override
  String get actionContinue => 'Continue';

  @override
  String get actionNext => 'Next';

  @override
  String get actionBack => 'Back';

  @override
  String get actionDone => 'Done';

  @override
  String get actionCancel => 'Cancel';

  @override
  String get actionSave => 'Save';

  @override
  String get actionClose => 'Close';

  @override
  String get actionUndo => 'Undo';

  @override
  String get actionRetry => 'Try again';

  @override
  String get actionOk => 'OK';

  @override
  String get actionShare => 'Share';

  @override
  String get actionLearnMore => 'Learn more';

  @override
  String get actionMarkRead => 'Mark as read';

  @override
  String get actionMarkUnread => 'Mark as not read';

  @override
  String get actionStart => 'Start';

  @override
  String get actionSkip => 'Skip';

  @override
  String get actionNotNow => 'Not now';

  @override
  String get actionEdit => 'Edit';

  @override
  String get actionDelete => 'Delete';

  @override
  String get actionClear => 'Clear';

  @override
  String get actionReport => 'Report';

  @override
  String get actionSend => 'Send';

  @override
  String get actionSignIn => 'Sign in';

  @override
  String get actionSignOut => 'Sign out';

  @override
  String get actionMore => 'More options';

  @override
  String moreOptionsFor(String name) {
    return 'More options for $name';
  }

  @override
  String get actionRefresh => 'Refresh';

  @override
  String get refreshed => 'Updated';

  @override
  String get loading => 'Loading…';

  @override
  String get errorGeneric => 'Something went wrong. Please try again.';

  @override
  String get notFoundTitle => 'Page not found';

  @override
  String get notFoundBody => 'This link leads nowhere in the app.';

  @override
  String get goToToday => 'Go to Today';

  @override
  String get aliyah1 => 'Rishon';

  @override
  String get aliyah2 => 'Sheni';

  @override
  String get aliyah3 => 'Shlishi';

  @override
  String get aliyah4 => 'Revi\'i';

  @override
  String get aliyah5 => 'Chamishi';

  @override
  String get aliyah6 => 'Shishi';

  @override
  String get aliyah7 => 'Shevi\'i';

  @override
  String aliyahNumbered(int number) {
    return 'Aliyah $number';
  }

  @override
  String aliyahWithName(String name, int number) {
    return '$name · aliyah $number';
  }

  @override
  String andJoiner(String first, String second) {
    return '$first and $second';
  }

  @override
  String get passMikra1 => 'First reading';

  @override
  String get passMikra2 => 'Second reading';

  @override
  String get passTargum => 'Targum';

  @override
  String get passRashi => 'Rashi';

  @override
  String get aliyotWord => 'aliyot';

  @override
  String countOfTotal(int count, int total) {
    return '$count of $total';
  }

  @override
  String get passShortMikra => 'Mikra';

  @override
  String passSemantics(String pass, String state) {
    return '$pass: $state';
  }

  @override
  String get stateDone => 'done';

  @override
  String get stateNotDone => 'not done';

  @override
  String versesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count verses',
      one: '1 verse',
    );
    return '$_temp0';
  }

  @override
  String minutesEstimate(int minutes) {
    return 'about $minutes min';
  }

  @override
  String aliyotProgress(int done, int total) {
    return '$done of $total aliyot';
  }

  @override
  String readOnShabbat(String date) {
    return 'Read on Shabbat, $date';
  }

  @override
  String readOnSimchatTorah(String date) {
    return 'Read on Simchat Torah, $date';
  }

  @override
  String shabbatInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Shabbat in $count days',
      one: 'Shabbat is tomorrow',
      zero: 'Shabbat is today',
    );
    return '$_temp0';
  }

  @override
  String todayCandleLighting(String time) {
    return 'Candle-lighting $time';
  }

  @override
  String parshaLabel(String name) {
    return 'Parshat $name';
  }

  @override
  String get todayReadingTitle => 'Today\'s reading';

  @override
  String get todayDone => 'Today\'s reading is done';

  @override
  String get todayAhead => 'You\'re ahead of plan. Well done!';

  @override
  String get todayNothingPlanned =>
      'No reading is planned for today. A good day to catch up or read ahead.';

  @override
  String todayBehind(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count aliyot behind — very normal midweek.',
      one: '1 aliyah behind — very normal midweek.',
    );
    return '$_temp0';
  }

  @override
  String get readTodaysAliyah => 'Read today\'s reading';

  @override
  String get continueReading => 'Continue reading';

  @override
  String get startReading => 'Start reading';

  @override
  String get readFromBook => 'I read it in a Chumash';

  @override
  String get weekComplete => 'This week\'s parsha is complete. Yasher koach!';

  @override
  String get haftarahLabel => 'Haftarah';

  @override
  String get haftarahRead => 'Haftarah read';

  @override
  String openWeekTitle(String name) {
    return '$name is still open';
  }

  @override
  String openWeekLate(String date) {
    return 'Finish by $date and it still counts.';
  }

  @override
  String openWeekRestore(String name, String next) {
    return 'Finish $name and $next by Shabbat to keep your streak — one double-up per book.';
  }

  @override
  String get openWeekHaftarahLeft => 'Only the haftarah is left.';

  @override
  String get checkInTitle => 'Shavua tov! Did you read on Shabbat?';

  @override
  String get checkInBody =>
      'Log what you read from a printed Chumash — it counts just the same.';

  @override
  String get checkInFinished => 'I finished it on Shabbat';

  @override
  String get checkInPick => 'Choose aliyot';

  @override
  String pausedBanner(String date) {
    return 'Paused until $date. Nothing resets while paused.';
  }

  @override
  String get resume => 'Resume';

  @override
  String readingDivergence(String israel, String diaspora) {
    return 'In Israel this week: $israel. Outside Israel: $diaspora. Visitors from abroad usually read both. If you daven with a minyan reading $diaspora, read only that one, and set the reading you\'ll hear to Outside Israel in Settings.';
  }

  @override
  String readingDivergenceAhead(String israel, String diaspora) {
    return 'In Israel this week: $israel. Outside Israel: $diaspora. Israel is a parsha ahead, so you\'ll read $israel next week.';
  }

  @override
  String readingDivergenceOpen(String name) {
    return 'Open $name';
  }

  @override
  String get discussThisWeek => 'Discuss this week\'s parsha';

  @override
  String get streakParsha => 'Parsha streak';

  @override
  String get streakDays => 'Days on track';

  @override
  String weeksCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weeks',
      one: '1 week',
    );
    return '$_temp0';
  }

  @override
  String daysCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String streakBeginsWith(String name) {
    return 'Begins with $name';
  }

  @override
  String get daysBeginToday => 'Begins with today\'s reading';

  @override
  String get graceDays => 'Grace days';

  @override
  String graceDaysAvailable(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count available',
      one: '1 available',
      zero: 'none available',
    );
    return '$_temp0';
  }

  @override
  String get dayKept => 'Read';

  @override
  String get dayAhead => 'Ahead of plan';

  @override
  String get dayCaughtUp => 'Caught up';

  @override
  String get dayGrace => 'Covered by a grace day';

  @override
  String get dayPaused => 'Paused';

  @override
  String get dayOpen => 'Not yet';

  @override
  String get dayMissed => 'Not read';

  @override
  String get dayRest => 'Shabbat or Yom Tov';

  @override
  String get dayUpcoming => 'Upcoming';

  @override
  String get dayNoReading => 'No reading planned';

  @override
  String get dayToday => 'Today';

  @override
  String get yomTovShort => 'Yom Tov';

  @override
  String dayChipLabel(String day, String status) {
    return '$day: $status';
  }

  @override
  String get weekStripLabel => 'This week\'s plan';

  @override
  String get weekOnTime => 'On time';

  @override
  String get weekLate => 'After Shabbat — still counts';

  @override
  String get weekRestored => 'Doubled up';

  @override
  String get weekMadeUp => 'Made up';

  @override
  String get weekMissed => 'Not completed';

  @override
  String get weekTransparent => 'Not counted';

  @override
  String get weekOverdue => 'Can still be restored';

  @override
  String get weekInProgress => 'In progress';

  @override
  String plannedFor(String day) {
    return 'Planned for $day';
  }

  @override
  String get plannedForShabbat => 'Shabbat morning — log it after Shabbat';

  @override
  String get markWholeWeek => 'Mark the whole parsha as read';

  @override
  String get clearWeek => 'Clear this week\'s progress';

  @override
  String clearWeekConfirm(String name) {
    return 'Clear all progress for $name?';
  }

  @override
  String get whenDidYouRead => 'When did you read it?';

  @override
  String get whenToday => 'Today';

  @override
  String get whenYesterday => 'Yesterday';

  @override
  String get whenOnShabbat => 'On Shabbat';

  @override
  String get whenPickDate => 'Choose a date';

  @override
  String get markedRead => 'Marked as read';

  @override
  String get markedUnread => 'Marked as not read';

  @override
  String aliyahNote(String note) {
    return 'Note: $note';
  }

  @override
  String get browseAll => 'All parshiyot';

  @override
  String get browseTitle => 'The Torah';

  @override
  String previewNotOpen(String date) {
    return 'Preview — this parsha opens for credit on $date.';
  }

  @override
  String get stepMikra1 => 'Read the Hebrew';

  @override
  String get stepMikra2 => 'Read the Hebrew again';

  @override
  String get stepTargum => 'Read the Targum';

  @override
  String get stepRashi => 'Read Rashi';

  @override
  String get stepThirdHebrew => 'Read the Hebrew a third time';

  @override
  String get stepRepeatLast => 'End with Mikra: read the last verse once more';

  @override
  String stepOf(int step, int total) {
    return 'Reading $step of $total';
  }

  @override
  String verseOf(int current, int total) {
    return 'Verse $current of $total';
  }

  @override
  String sectionOf(int current, int total) {
    return 'Section $current of $total';
  }

  @override
  String verseLabel(String number) {
    return 'Verse $number';
  }

  @override
  String targumVerseLabel(String number) {
    return 'Targum, verse $number';
  }

  @override
  String chapterLabel(String number) {
    return 'Chapter $number';
  }

  @override
  String get noTargumNote =>
      'Onkelos here gives mostly the Aramaic forms of the place names. Following Rashi (Berakhot 8b), many also read this verse a third time in Hebrew (see Shulchan Aruch OC 285:1).';

  @override
  String get noRashiNote =>
      'Rashi does not comment on this verse. Some read it a third time in Hebrew (Mishnah Berurah 285:5).';

  @override
  String get noRashiComment => 'Rashi does not comment on this verse.';

  @override
  String ketivQereLabel(String ketiv, String qere) {
    return 'Written $ketiv, read $qere';
  }

  @override
  String ketivOnlyLabel(String ketiv) {
    return 'Written $ketiv, not read';
  }

  @override
  String qereOnlyLabel(String qere) {
    return 'Read $qere, not written';
  }

  @override
  String noteLabel(String text) {
    return 'Note: $text';
  }

  @override
  String aliyahComplete(String aliyah) {
    return 'Yasher koach! $aliyah is complete.';
  }

  @override
  String parshaComplete(String name) {
    return 'Chazak! Parshat $name is complete.';
  }

  @override
  String firstAliyahDone(String verses, String second) {
    return 'Yasher koach! Your first aliyah is done — $verses, twice, with $second.';
  }

  @override
  String continueWithAliyah(String aliyah) {
    return 'Continue with $aliyah';
  }

  @override
  String get aliyahStatusRead => 'read';

  @override
  String get aliyahStatusPartial => 'in progress';

  @override
  String get aliyahStatusUnread => 'not started';

  @override
  String get backToWeek => 'Back to the week';

  @override
  String get displaySettings => 'Display settings';

  @override
  String get textSize => 'Text size';

  @override
  String get textSmaller => 'Smaller text';

  @override
  String get textLarger => 'Larger text';

  @override
  String get listen => 'Listen';

  @override
  String get stopListening => 'Stop';

  @override
  String get ttsUnavailable =>
      'Text-to-speech isn\'t available on this device.';

  @override
  String get ttsNoHebrewVoice =>
      'No Hebrew voice is installed. You can add one in your device\'s speech settings.';

  @override
  String get guidedMode => 'Guided reading';

  @override
  String get fullTextMode => 'Full text';

  @override
  String get markAliyahRead => 'Mark this aliyah as read';

  @override
  String get keyboardShortcuts => 'Keyboard shortcuts';

  @override
  String get translationDisclaimer =>
      'A translation is a study aid. It does not take the place of the Targum.';

  @override
  String get mikraLabel => 'Mikra';

  @override
  String get targumLabel => 'Targum Onkelos';

  @override
  String get rashiLabel => 'Rashi';

  @override
  String get translationLabel => 'Translation (JPS 1917)';

  @override
  String get haftarahTitle => 'Haftarah';

  @override
  String get markHaftarahRead => 'Mark the haftarah as read';

  @override
  String specialHaftarah(String reason) {
    return 'Special haftarah: $reason';
  }

  @override
  String get readerFinished => 'You\'ve finished this aliyah.';

  @override
  String get shortcutNext => 'Next step';

  @override
  String get shortcutBack => 'Previous step';

  @override
  String get shortcutLarger => 'Larger text';

  @override
  String get shortcutSmaller => 'Smaller text';

  @override
  String get shortcutTeamim => 'Show or hide cantillation';

  @override
  String get shortcutNikud => 'Show or hide vowels';

  @override
  String get shortcutListen => 'Listen / stop';

  @override
  String get shortcutHelp => 'Show shortcuts';

  @override
  String get shortcutScroll => 'Scroll the text';

  @override
  String get shortcutPageDown => 'Down a page, then the next step';

  @override
  String get shortcutPageUp => 'Up a page, then the previous step';

  @override
  String get shortcutFocusVerse =>
      'Full text in focus mode: previous or next verse';

  @override
  String get keyUp => 'Up arrow';

  @override
  String get keyDown => 'Down arrow';

  @override
  String get keySpace => 'Space';

  @override
  String get progressTitle => 'Progress';

  @override
  String longest(String value) {
    return 'Longest: $value';
  }

  @override
  String thisCycle(int done) {
    return 'This year: $done of 54 parshiyot';
  }

  @override
  String versesRead(String count, String second) {
    return '$count verses read twice with $second';
  }

  @override
  String yearBarSemantics(int done, int total) {
    return 'This year: $done of $total parshiyot complete';
  }

  @override
  String yearBarSemanticsCurrent(int done, int total, String name) {
    return 'This year: $done of $total parshiyot complete; $name in progress';
  }

  @override
  String get bookAbbrGenesis => 'Gen';

  @override
  String get bookAbbrExodus => 'Exo';

  @override
  String get bookAbbrLeviticus => 'Lev';

  @override
  String get bookAbbrNumbers => 'Num';

  @override
  String get bookAbbrDeuteronomy => 'Deu';

  @override
  String get torahMap => 'Torah map';

  @override
  String get torahMapHelp => 'Each tile is one parsha of this year\'s cycle.';

  @override
  String torahMapBook(String book, int done, int total) {
    return '$book: $done of $total parshiyot';
  }

  @override
  String get recentWeeks => 'Recent weeks';

  @override
  String get makeUpTitle => 'Make up before Simchat Torah';

  @override
  String get makeUpBody =>
      'Optional. Make-ups count toward this year\'s siyum.';

  @override
  String get pauseTitle => 'Life happens';

  @override
  String get pauseBody =>
      'Pause for up to 30 days — nothing resets while paused. Illness, travel, mourning, a new baby: life comes first.';

  @override
  String get pauseAction => 'Pause streaks';

  @override
  String get pauseFor => 'Pause for';

  @override
  String get pauseStarting => 'Starting';

  @override
  String pauseStarted(String date) {
    return 'Paused until $date.';
  }

  @override
  String get pauseEnded => 'Welcome back! Your place is saved.';

  @override
  String get streaksHidden =>
      'Streak numbers are hidden. Your progress is still saved.';

  @override
  String get milestonesTitle => 'Milestones';

  @override
  String get graceExplainer =>
      'Grace days cover a missed planned day automatically. You start with 2, earn 1 each time you finish a parsha before Shabbat (up to 3), and use at most 2 a week. They can never be bought.';

  @override
  String streakExplainer(String deadline) {
    String _temp0 = intl.Intl.selectLogic(deadline, {
      'tuesday': ' — or by Tuesday night, which still counts',
      'wednesday': ' — or by the end of Wednesday, which still counts',
      'other': '',
    });
    return 'Your parsha streak counts portions finished before Shabbat$_temp0. Shabbat and Yom Tov never break a streak.';
  }

  @override
  String get statusLegend => 'Legend';

  @override
  String get noHistory => 'Your weeks will appear here as you read.';

  @override
  String get milestoneFirstAliyah => 'First aliyah';

  @override
  String get milestoneFirstParsha => 'First parsha';

  @override
  String get milestonePerfectWeek => 'Perfect week';

  @override
  String milestoneParshaStreak(int count) {
    return '$count-week parsha streak';
  }

  @override
  String milestoneDaysOnTrack(int count) {
    return '$count days on track';
  }

  @override
  String milestoneSefer(String book) {
    return '$book complete — Chazak!';
  }

  @override
  String get milestoneSiyum => 'Siyum HaTorah';

  @override
  String get milestoneComeback => 'Welcome back';

  @override
  String get milestoneLocked => 'Not yet reached';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsReading => 'Reading & customs';

  @override
  String get settingsDisplay => 'Display';

  @override
  String get settingsAccessibility => 'Accessibility';

  @override
  String get settingsReminders => 'Reminders';

  @override
  String get settingsStreaks => 'Streaks';

  @override
  String get settingsAccount => 'Account & community';

  @override
  String get settingsData => 'Your data';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsAbout => 'About this app';

  @override
  String get settingsReadingDesc =>
      'Israel or abroad, Shabbat times, plan, Targum or Rashi, haftarah';

  @override
  String get settingsDisplayDesc =>
      'Theme, fonts, text size, vowels and cantillation';

  @override
  String get settingsAccessibilityDesc =>
      'Motion, screen readers, speech, quick setups';

  @override
  String get settingsRemindersDesc =>
      'Gentle reminders, never on Shabbat or Yom Tov';

  @override
  String get settingsDataDesc => 'Back up, restore or reset your progress';

  @override
  String get locationIsrael => 'In Israel';

  @override
  String get locationDiaspora => 'Outside Israel';

  @override
  String get locationHelp =>
      'Israel and the Diaspora sometimes read different parshiyot and keep a different number of Yom Tov days. Visiting? You can set the days of Yom Tov you keep separately in Settings.';

  @override
  String get readingScheduleLabel =>
      'Which Torah reading will you hear this Shabbat?';

  @override
  String get readingScheduleHelp =>
      'For a few weeks after Pesach or Shavuot, Israel can be a parsha ahead.';

  @override
  String get yomTovDaysLabel => 'How many days of Yom Tov do you keep?';

  @override
  String get yomTovDaysOne => 'One, as in Israel';

  @override
  String get yomTovDaysTwo => 'Two, as outside Israel';

  @override
  String get yomTovDaysHelp =>
      'Visitors usually keep their home custom. Ask your rav.';

  @override
  String get planLabel => 'Weekly plan';

  @override
  String get planAliyahPerDay => 'An aliyah a day';

  @override
  String get planAliyahPerDayDesc =>
      'One aliyah a day; two on the last day before Shabbat';

  @override
  String get planShevii => 'Shevi\'i on Shabbat morning';

  @override
  String get planSheviiDesc =>
      'Aliyot 1–6 Sunday–Friday; the 7th before the Shabbat meal (Vilna Gaon, MB 285:8)';

  @override
  String get planErevShabbat => 'All on Friday';

  @override
  String get planErevShabbatDesc =>
      'The whole parsha on Erev Shabbat — after Shacharit (Arizal) or after midday (Shelah; Shulchan Aruch HaRav)';

  @override
  String get methodLabel => 'Reading method';

  @override
  String get methodVerse => 'Verse by verse';

  @override
  String methodVerseDesc(String second) {
    return 'Each verse twice, then its $second';
  }

  @override
  String get methodSection => 'Section by section';

  @override
  String methodSectionDesc(String second) {
    return 'Each paragraph twice, then its $second';
  }

  @override
  String get methodAliyah => 'Aliyah by aliyah';

  @override
  String methodAliyahDesc(String second) {
    return 'The whole aliyah twice, then its $second';
  }

  @override
  String get secondLabel => 'Targum or Rashi';

  @override
  String get secondOnkelos => 'Targum Onkelos';

  @override
  String get secondRashi => 'Rashi';

  @override
  String get secondBoth => 'Onkelos and Rashi';

  @override
  String get secondRashiEnglish => 'Rashi in English';

  @override
  String get secondHelp =>
      'The Shulchan Aruch (OC 285:2) permits Rashi in place of Targum, and praises reading both. A plain translation is a study aid, not a substitute. Ask your rav about translated Rashi.';

  @override
  String get repeatLastVerse => 'End with Mikra';

  @override
  String get repeatLastVerseDesc =>
      'Repeat the parsha\'s last verse in Hebrew after its Targum';

  @override
  String get thirdReading => 'Third-reading prompts';

  @override
  String get thirdReadingDesc =>
      'Suggest a third Hebrew reading where Onkelos is mostly names (Numbers 32:3) or Rashi is silent';

  @override
  String get haftarahEnabled => 'Haftarah';

  @override
  String get haftarahEnabledDesc => 'Read the week\'s haftarah once';

  @override
  String get nusachLabel => 'Haftarah custom';

  @override
  String get nusachAshkenazi => 'Ashkenazi';

  @override
  String get nusachSephardi => 'Sephardi';

  @override
  String get nusachChabad => 'Chabad';

  @override
  String get haftarahRequired => 'Count the haftarah toward completion';

  @override
  String get lateWindowLabel => 'After-Shabbat window';

  @override
  String get lateTuesday => 'Until Tuesday night';

  @override
  String get lateWednesday => 'Until the end of Wednesday';

  @override
  String get lateNone => 'No window';

  @override
  String get lateWindowDesc =>
      'Reading finished after Shabbat, until this time, still counts (Shulchan Aruch OC 285:4).';

  @override
  String get tishaBavQuiet => 'No reading planned on Tisha B\'Av';

  @override
  String get cholHamoedQuiet => 'No reading planned on Chol HaMoed';

  @override
  String get appliesFromThisWeek => 'Applies from this week on';

  @override
  String get nameStyleLabel => 'Parsha names';

  @override
  String get nameSephardi => 'Sephardi (Bereshit)';

  @override
  String get nameAshkenazi => 'Ashkenazi (Bereishis)';

  @override
  String get themeLabel => 'Theme';

  @override
  String get themeSystem => 'Match device';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeSepia => 'Sepia';

  @override
  String get themeHcLight => 'High contrast — light';

  @override
  String get themeHcDark => 'High contrast — dark';

  @override
  String get scriptureFontLabel => 'Scripture font';

  @override
  String get fontNotoSerif => 'Noto Serif Hebrew';

  @override
  String get fontTaamey => 'Taamey Frank (classic Chumash)';

  @override
  String get fontEzra => 'Ezra SIL';

  @override
  String get fontNotoSans => 'Noto Sans Hebrew (sans-serif)';

  @override
  String get readingSize => 'Reading size';

  @override
  String readingSizeValue(int percent) {
    return '$percent%';
  }

  @override
  String get lineSpacing => 'Line spacing';

  @override
  String get wordSpacing => 'Word spacing';

  @override
  String get letterSpacing => 'Letter spacing';

  @override
  String decreaseSetting(String name) {
    return 'Decrease $name';
  }

  @override
  String increaseSetting(String name) {
    return 'Increase $name';
  }

  @override
  String get showNikud => 'Vowels (nikud)';

  @override
  String get showTeamim => 'Cantillation (ta\'amim)';

  @override
  String get showKetiv => 'Show ketiv (as written)';

  @override
  String get showVerseNumbers => 'Verse numbers';

  @override
  String get justifyText => 'Justify text';

  @override
  String get lineWidthLabel => 'Line width';

  @override
  String get lineNarrow => 'Narrow';

  @override
  String get lineMedium => 'Medium';

  @override
  String get lineWide => 'Wide';

  @override
  String get showTranslation => 'English translation (study aid)';

  @override
  String get showRashi => 'Show Rashi alongside';

  @override
  String get uiFontLabel => 'Interface font';

  @override
  String get uiFontStandard => 'Standard';

  @override
  String get uiFontAtkinson => 'Atkinson Hyperlegible';

  @override
  String get uiFontLexend => 'Lexend';

  @override
  String get uiFontOpenDyslexic => 'OpenDyslexic';

  @override
  String get uiFontSystem => 'Device font';

  @override
  String get boldText => 'Bold text';

  @override
  String get focusMode => 'Focus mode';

  @override
  String get focusModeDesc => 'Highlight the current verse and dim the rest';

  @override
  String get keepScreenOn => 'Keep the screen on while reading';

  @override
  String get previewLabel => 'Preview';

  @override
  String get reduceMotion => 'Reduce motion';

  @override
  String get reduceMotionDesc => 'Turn off animations and moving celebrations';

  @override
  String get haptics => 'Haptic feedback';

  @override
  String get singleKeyShortcuts => 'Single-key shortcuts';

  @override
  String get singleKeyShortcutsDesc =>
      'While reading, T, N, L, + and − work on their own, without Ctrl. Turn this off if you use speech input or screen-reader quick keys.';

  @override
  String get screenReaderText => 'Screen reader text';

  @override
  String get srSimplified => 'Vowels, no cantillation (recommended)';

  @override
  String get srConsonants => 'Letters only';

  @override
  String get srAllMarks => 'All marks (for braille displays)';

  @override
  String get divineNameLabel => 'Speaking the Divine Name';

  @override
  String get divineAdonai => 'Ado-nai';

  @override
  String get divineHashem => 'HaShem';

  @override
  String get speechRate => 'Speech rate';

  @override
  String get presetsTitle => 'Quick setups';

  @override
  String get presetLargePrint => 'Large print';

  @override
  String get presetDyslexia => 'Dyslexia-friendly';

  @override
  String get presetHighContrast => 'High contrast';

  @override
  String get presetLowVision => 'Low vision';

  @override
  String get presetReset => 'Reset display';

  @override
  String presetApplied(String name) {
    return '$name applied';
  }

  @override
  String get accessibilityStatement => 'Accessibility statement';

  @override
  String get sendFeedback => 'Send feedback';

  @override
  String get dailyReminder => 'Daily reminder';

  @override
  String get dailyReminderDesc => 'A gentle nudge at your chosen time';

  @override
  String get dailyReminderDescCity =>
      'A gentle nudge at your chosen time, or before candle-lighting on the eve of Shabbat or Yom Tov';

  @override
  String get dailyReminderTime => 'Daily reminder time';

  @override
  String get fridayReminder => 'Erev Shabbat reminder';

  @override
  String get fridayReminderDesc =>
      'Friday morning, only if the parsha isn\'t finished';

  @override
  String get fridayReminderDescCity =>
      'Friday, at least three hours before candle-lighting, only if the parsha isn\'t finished';

  @override
  String get fridayReminderTime => 'Erev Shabbat reminder time';

  @override
  String get checkInReminder => 'After-Shabbat check-in';

  @override
  String get checkInReminderDesc =>
      'Sunday morning, to log what you read on Shabbat';

  @override
  String get checkInReminderDescCity =>
      'An hour after Shabbat ends, or Sunday morning when it ends late, to log what you read on Shabbat';

  @override
  String get remindersShabbatNote =>
      'Reminders are never sent on Shabbat or Yom Tov, and never more than one a day.';

  @override
  String remindersShabbatNoteCity(String city) {
    return 'Reminders are never sent on Shabbat or Yom Tov, and never more than one a day. They follow the Shabbat times in $city.';
  }

  @override
  String get reminderCityOffer =>
      'Choose your city, and reminders will follow its Shabbat times: before candle-lighting on Friday, and after Shabbat ends.';

  @override
  String get reminderCityChoose => 'Choose a city';

  @override
  String get remindersOnCityOffer =>
      'Reminders are on. Choose your city, and they\'ll follow its Shabbat times.';

  @override
  String get habitAnchorLabel => 'After I…';

  @override
  String get habitAnchorPrompt =>
      'Tie your reading to something you already do every day.';

  @override
  String get anchorShacharit => 'finish Shacharit';

  @override
  String get anchorBreakfast => 'eat breakfast';

  @override
  String get anchorCommute => 'start my commute';

  @override
  String get anchorDinner => 'finish dinner';

  @override
  String get anchorBed => 'get ready for bed';

  @override
  String get anchorCueShacharit => 'After Shacharit';

  @override
  String get anchorCueBreakfast => 'After breakfast';

  @override
  String get anchorCueCommute => 'On your commute';

  @override
  String get anchorCueDinner => 'After dinner';

  @override
  String get anchorCueBed => 'Before bed';

  @override
  String get notificationsUnsupported =>
      'Reminders aren\'t available in the web version. Install the app on your phone or computer to get them.';

  @override
  String get notificationsDenied =>
      'Notifications are turned off for this app in your device settings.';

  @override
  String get notificationsDeniedTitle => 'Notifications are off';

  @override
  String get openSystemSettings => 'Open settings';

  @override
  String get primingTitle => 'Want a gentle daily nudge?';

  @override
  String get primingBody =>
      'Never on Shabbat or Yom Tov, and at most one a day. Change it anytime.';

  @override
  String reminderAtTime(String time) {
    return 'At $time';
  }

  @override
  String get primingYes => 'Yes, remind me';

  @override
  String get notifChannelDaily => 'Daily reading';

  @override
  String get notifChannelFriday => 'Erev Shabbat';

  @override
  String get notifChannelCheckIn => 'After Shabbat';

  @override
  String get notifChannelDailyDesc =>
      'Your day\'s reading at the time you choose, never on Shabbat or Yom Tov';

  @override
  String get notifChannelErevShabbatDesc =>
      'Before Shabbat or Yom Tov, only if the parsha isn\'t finished';

  @override
  String get notifChannelCheckInDesc =>
      'After Shabbat, a reminder to log what you read; also the note when reminders stop';

  @override
  String notifDailyTitle(String aliyah) {
    return 'Today: $aliyah';
  }

  @override
  String notifDailyBody(String parsha, String verses, int minutes) {
    return 'Parshat $parsha · $verses · about $minutes min';
  }

  @override
  String notifDailyAnchor(String cue) {
    return '$cue — it\'s yours.';
  }

  @override
  String notifFridayTitle(String parsha) {
    return 'Erev Shabbat · Parshat $parsha';
  }

  @override
  String get notifFridayBody =>
      'If you haven\'t finished, there\'s still time — or finish Shabbat morning from your Chumash and log it after Shabbat.';

  @override
  String get notifCheckInTitle => 'Shavua tov!';

  @override
  String get notifCheckInBody => 'Did you read on Shabbat? Tap to log it.';

  @override
  String get notifPausedTitle => 'Reminders paused';

  @override
  String notifPausedBody(String parsha) {
    return 'We\'ll pause reminders for now. Your place in Parshat $parsha is saved — come back anytime.';
  }

  @override
  String get showStreaks => 'Show streak numbers';

  @override
  String get showStreaksDesc =>
      'Hide them if you\'d rather focus on the learning itself';

  @override
  String get exportData => 'Export my progress';

  @override
  String get exportDataDesc => 'Save a backup you can restore later';

  @override
  String get importData => 'Import progress';

  @override
  String get importDataDesc => 'Restore from a backup file';

  @override
  String get importPrompt => 'Paste the contents of your backup file.';

  @override
  String get importSuccess => 'Progress imported.';

  @override
  String get importFailed => 'That backup couldn\'t be read.';

  @override
  String get exportCopied => 'Backup copied to the clipboard.';

  @override
  String get resetProgress => 'Reset all progress';

  @override
  String get resetProgressConfirm =>
      'This erases your reading history and streaks on this device. It can\'t be undone.';

  @override
  String get resetProgressConfirmSynced =>
      'This erases your reading history and streaks on this device, in your backup, and on your other devices when they next sync. It can\'t be undone.';

  @override
  String get resetDone => 'Progress reset.';

  @override
  String get languageSystem => 'Device language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageHebrew => 'עברית';

  @override
  String get aboutTitle => 'About';

  @override
  String versionLabel(String version) {
    return 'Version $version';
  }

  @override
  String get sourcesTitle => 'Texts & sources';

  @override
  String get licensesTitle => 'Open-source licenses';

  @override
  String get privacyTitle => 'Privacy';

  @override
  String get termsTitle => 'Terms of use';

  @override
  String get guidelinesTitle => 'Community guidelines';

  @override
  String get contactTitle => 'Contact us';

  @override
  String get guideTitle => 'How it works';

  @override
  String get disclaimer =>
      'Customs vary. For practical questions, ask your rav.';

  @override
  String get onbWelcomeBody =>
      'Read the parsha twice and the Targum once — one aliyah a day, done before Shabbat.';

  @override
  String get onbStart => 'Start this week\'s parsha';

  @override
  String get onbLocationTitle => 'Where will you be this Shabbat?';

  @override
  String get onbMethodTitle => 'How do you read?';

  @override
  String get onbPlanTitle => 'Your weekly plan';

  @override
  String get onbHonor =>
      'Shnayim Mikra runs on the honor system. Log what you read, wherever you read it — a Chumash in shul counts just as much as this app.';

  @override
  String get onbChangeAnytime => 'You can change this anytime in Settings.';

  @override
  String onbStep(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get onbWhyAsk => 'Why we ask';

  @override
  String get guideWhatTitle => 'What is Shnayim Mikra?';

  @override
  String get guideWhatBody =>
      'The Talmud (Berakhot 8a) teaches that a person should complete the weekly Torah portion together with the community: the Torah text twice and the Targum once. The Shulchan Aruch codifies this in Orach Chaim 285. It completes, privately, the portion the community reads publicly on Shabbat.';

  @override
  String get guideWhenTitle => 'When';

  @override
  String get guideWhenBody =>
      'You may begin on Sunday (some say from Shabbat afternoon). Ideally finish before the Shabbat-day meal; if not, after the meal until Mincha. After that it may still be completed through Tuesday night (\"until Wednesday\"), and missed portions may be made up until Simchat Torah (SA 285:4; MB 285:12).';

  @override
  String get guideHowTitle => 'How';

  @override
  String get guideHowBody =>
      'Read verse by verse — each verse twice and then its Targum — or section by section, reading each paragraph twice and then its Targum. Many repeat the final verse in Hebrew so as to end with the Torah text. If you can, read aloud and with the cantillation.';

  @override
  String get guideTargumTitle => 'Targum or Rashi';

  @override
  String get guideTargumBody =>
      'Rashi\'s commentary may take the place of the Targum, since it explains the text; a God-fearing person reads both (SA 285:2). A plain translation is a helpful study aid but is not a substitute for the Targum. Someone who doesn\'t understand Rashi\'s Hebrew may read Rashi in a language they understand (MB 285:5; Rav Moshe Feinstein). Ask your rav.';

  @override
  String get guideSpecialTitle => 'Special cases';

  @override
  String get guideSpecialBody =>
      'In \"Atarot v\'Divon\" (Numbers 32:3), Onkelos gives mostly the Aramaic forms of the place names; following Rashi (Berakhot 8b), many also read it a third time in Hebrew. Vezot HaBerachah is read before Simchat Torah, ideally on Hoshana Rabbah. Many also read the week\'s haftarah once. Reading quietly along with the ba\'al koreh, word for word, counts as one of the readings (MB 285:14). In a double-portion week, read both. When Israel and the Diaspora read different portions, travelers usually read both. There is no blessing. Women and children who take on the practice do so as a voluntary mitzvah.';

  @override
  String get guideShabbatTitle => 'Shabbat and Yom Tov';

  @override
  String get guideShabbatBody =>
      'This app never asks you to open it on Shabbat or Yom Tov. Streaks pause on those days, reminders are never sent, and reading you do from a printed Chumash can be logged afterwards.';

  @override
  String get guideSourcesTitle => 'Sources';

  @override
  String get guideSourcesBody =>
      'Berakhot 8a–b · Shulchan Aruch, Orach Chaim 285 · Mishnah Berurah 285 · Kitzur Shulchan Aruch 72 · Shulchan Aruch HaRav 285';

  @override
  String hebrewDateLabel(String date) {
    return 'Hebrew date: $date';
  }

  @override
  String bookOfTorah(String book) {
    return '$book';
  }

  @override
  String get communityTitle => 'Community';

  @override
  String get demoModeBanner =>
      'Demo mode: posts stay on this device and reset when the app restarts.';

  @override
  String get forumsHeading => 'Forums';

  @override
  String get forumNotFound =>
      'This forum couldn\'t be found. It may have moved or closed.';

  @override
  String get allForums => 'All forums';

  @override
  String thisWeeksThread(String name) {
    return 'This week: Parshat $name';
  }

  @override
  String weeklyThreadTitle(String name, String year) {
    return 'Parshat $name $year';
  }

  @override
  String get openDiscussion => 'Open the discussion';

  @override
  String get signInPrompt => 'Sign in to post, say thanks or report.';

  @override
  String get signInTitle => 'Sign in';

  @override
  String get signInBody =>
      'We\'ll email you a 6-digit code — no password needed.';

  @override
  String get emailLabel => 'Email address';

  @override
  String get sendCodeAction => 'Email me a code';

  @override
  String codeSentTo(String email) {
    return 'We sent a 6-digit code to $email.';
  }

  @override
  String get codeLabel => '6-digit code';

  @override
  String get verifyAction => 'Sign in';

  @override
  String get useDifferentEmail => 'Use a different email';

  @override
  String get demoCodeHint => 'Demo mode: any 6 digits will work.';

  @override
  String signedInAs(String name) {
    return 'Signed in as $name';
  }

  @override
  String get displayNameLabel => 'Display name';

  @override
  String get displayNameHelp => 'Shown with your posts. 2–40 characters.';

  @override
  String get saveName => 'Save name';

  @override
  String get nameSaved => 'Name saved.';

  @override
  String get syncProgress => 'Back up my progress';

  @override
  String get syncProgressDesc =>
      'Keep your reading progress with your account and restore it on other devices.';

  @override
  String get syncNow => 'Sync now';

  @override
  String get syncDone => 'Progress synced.';

  @override
  String get syncFailed => 'Couldn\'t sync right now. We\'ll try again later.';

  @override
  String get syncNeedsUpdate =>
      'Your backup was saved by a newer version of the app. Update the app to keep syncing.';

  @override
  String lastSynced(String time) {
    return 'Last synced $time';
  }

  @override
  String get deleteAccount => 'Delete my account';

  @override
  String get deleteAccountConfirm =>
      'This permanently deletes your account, your profile and everything you\'ve posted. Your reading progress on this device is kept. This can\'t be undone.';

  @override
  String get accountDeleted => 'Your account was deleted.';

  @override
  String get newThread => 'New discussion';

  @override
  String get threadTitleLabel => 'Title';

  @override
  String get threadBodyLabel => 'Your message';

  @override
  String get forumLabel => 'Forum';

  @override
  String get postAction => 'Post';

  @override
  String get replyLabel => 'Write a reply';

  @override
  String get replyAction => 'Reply';

  @override
  String replyingTo(String name) {
    return 'Replying to $name';
  }

  @override
  String todahCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count thanks',
      one: '1 thanks',
      zero: 'Say thanks',
    );
    return '$_temp0';
  }

  @override
  String todahSemantics(String name) {
    return 'Say thanks to $name';
  }

  @override
  String todahRemove(String name) {
    return 'Remove your thanks to $name';
  }

  @override
  String get reportTitle => 'Report this post';

  @override
  String get reportReasonLabel => 'What\'s wrong?';

  @override
  String get reasonSpam => 'Spam or advertising';

  @override
  String get reasonLashonHara => 'Lashon hara or gossip';

  @override
  String get reasonDisrespect => 'Disrespectful or abusive';

  @override
  String get reasonMisinformation => 'Misleading about halacha or sources';

  @override
  String get reasonOffTopic => 'Off topic';

  @override
  String get reasonOther => 'Something else';

  @override
  String get reportDetails => 'Details (optional)';

  @override
  String get reportSent => 'Thank you. A moderator will review it.';

  @override
  String blockUser(String name) {
    return 'Block $name';
  }

  @override
  String blockConfirm(String name) {
    return 'You won\'t see posts from $name. They won\'t be notified.';
  }

  @override
  String get blockedDone => 'Blocked.';

  @override
  String get unblock => 'Unblock';

  @override
  String get blockedUsersTitle => 'Blocked members';

  @override
  String get edited => 'edited';

  @override
  String get editPostTitle => 'Edit post';

  @override
  String get deletePostConfirm => 'Delete this post?';

  @override
  String get postDeleted => 'Post deleted.';

  @override
  String get posted => 'Posted.';

  @override
  String get pendingReview => 'Hidden — waiting for a moderator';

  @override
  String get lockedThread => 'This discussion is locked.';

  @override
  String get pinnedLabel => 'Pinned';

  @override
  String get lockedLabel => 'Locked';

  @override
  String get lockThread => 'Lock discussion';

  @override
  String get unlockThread => 'Unlock discussion';

  @override
  String get pinThread => 'Pin to top';

  @override
  String get unpinThread => 'Unpin';

  @override
  String get hidePost => 'Hide post';

  @override
  String get moderationQueue => 'Reports to review';

  @override
  String get noReports => 'No open reports.';

  @override
  String get removePost => 'Remove post';

  @override
  String get dismissReport => 'Dismiss';

  @override
  String get guidelinesAccept => 'I\'ll follow the community guidelines';

  @override
  String get guidelinesPrompt =>
      'Before your first post, please read the community guidelines.';

  @override
  String get readGuidelines => 'Read the guidelines';

  @override
  String get noThreads => 'No discussions yet. Start the first one!';

  @override
  String noPostsYet(String name) {
    return 'No posts yet — share a thought on Parshat $name.';
  }

  @override
  String get noReplies => 'No replies yet.';

  @override
  String get loadMore => 'Load more';

  @override
  String loadedMore(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Loaded $count more discussions',
      one: 'Loaded 1 more discussion',
    );
    return '$_temp0';
  }

  @override
  String get showEarlierPosts => 'Show earlier posts';

  @override
  String postsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count posts',
      one: '1 post',
      zero: 'No posts yet',
    );
    return '$_temp0';
  }

  @override
  String get timeJustNow => 'just now';

  @override
  String timeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes ago',
      one: '1 minute ago',
    );
    return '$_temp0';
  }

  @override
  String timeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String postedBy(String name, String time) {
    return '$name, $time';
  }

  @override
  String postNofM(int n, int total) {
    return 'Post $n of $total';
  }

  @override
  String get anonymousMember => 'Former member';

  @override
  String get errRateLimited =>
      'You\'re posting quickly — please wait a few seconds.';

  @override
  String get errThreadLocked => 'This discussion is locked.';

  @override
  String get errTerms => 'Please accept the community guidelines first.';

  @override
  String get errBanned => 'Your account can\'t post.';

  @override
  String get errSilenced => 'Posting is paused for your account for now.';

  @override
  String get errContent =>
      'That message can\'t be posted. Please review the community guidelines.';

  @override
  String get errDuplicate => 'You already posted that.';

  @override
  String get errLinks => 'New members can include at most 2 links.';

  @override
  String get errDailyLimit =>
      'New members can post a limited amount each day. Please try again tomorrow.';

  @override
  String get errNameTaken => 'That name is taken.';

  @override
  String get errAlreadyReported => 'You\'ve already reported this post.';

  @override
  String get errInvalidName => 'Names must be 2–40 characters.';

  @override
  String get errInvalidCode =>
      'That code didn\'t work. Check it and try again.';

  @override
  String get errInvalidEmail => 'Please enter a valid email address.';

  @override
  String get errNotSignedIn => 'Please sign in first.';

  @override
  String get errForbidden => 'You don\'t have permission to do that.';

  @override
  String get errShabbat => 'Posting is closed for Shabbat.';

  @override
  String get errTooShort => 'Please write a little more.';

  @override
  String get errTitleTooShort => 'The title needs at least 5 characters.';

  @override
  String get errNetwork =>
      'Couldn\'t reach the server. Check your connection and try again.';

  @override
  String get moderatorBadge => 'Moderator';

  @override
  String get draftRestored => 'Your draft was restored.';

  @override
  String get discardDraft => 'Discard draft';

  @override
  String charactersLeft(int count) {
    return '$count characters left';
  }

  @override
  String get shabbatTimesLabel => 'Shabbat times';

  @override
  String get shabbatTimesHelp =>
      'Choose your city to see when to light candles and when Shabbat ends. The times are worked out on this device, and your city stays on it.';

  @override
  String get cityLabel => 'City';

  @override
  String get cityNotSet => 'Not set';

  @override
  String shabbatTimesSummary(String candles, String ends) {
    return 'Candle-lighting $candles\nShabbat ends $ends';
  }

  @override
  String shabbatCandlesOnly(String candles) {
    return 'Candle-lighting $candles';
  }

  @override
  String get shabbatNoSunset =>
      'There is no sunset there this Shabbat. Ask your rav about the times.';

  @override
  String get shabbatTimesUnavailable =>
      'This device can\'t tell the time in that city, so its times can\'t be shown.';

  @override
  String get cityPickerTitle => 'Choose a city';

  @override
  String get citySearchLabel => 'Search for a city';

  @override
  String get citySearchClear => 'Clear search';

  @override
  String get cityYours => 'Your city';

  @override
  String get cityNone => 'No city';

  @override
  String get cityNoneDesc => 'Shabbat times aren\'t shown';

  @override
  String get cityNearYou => 'In your time zone';

  @override
  String cityNoResults(String query) {
    return 'No city matches “$query”.';
  }

  @override
  String cityResultsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cities found',
      one: '1 city found',
      zero: 'No cities found',
    );
    return '$_temp0';
  }

  @override
  String cityResultsMore(int shown, int count) {
    return 'The first $shown of $count matches are listed. Type more of the name to find the others.';
  }

  @override
  String get cityListNote =>
      'The list has every place of 100,000 people or more, every city in Israel, and the larger Israeli localities beyond the Green Line. If yours isn\'t there, choose the nearest one; beyond the Green Line, the nearest Israeli locality.';

  @override
  String get searchTitle => 'Search the Torah';

  @override
  String get searchFieldLabel => 'A word or phrase';

  @override
  String get searchClear => 'Clear search';

  @override
  String get searchIntro =>
      'Find a word or phrase in the Torah, in Targum Onkelos, or in the English translation.';

  @override
  String get searchPreparing => 'Preparing the text for search…';

  @override
  String searchResultsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count verses',
      one: '1 verse',
    );
    return '$_temp0';
  }

  @override
  String searchResultsFirst(int shown, int count) {
    return 'The first $shown of $count verses';
  }

  @override
  String get searchNarrow => 'Add a word to narrow the search.';

  @override
  String searchNoResults(String query) {
    return 'No verse matches “$query”.';
  }

  @override
  String get searchNoResultsHint =>
      'Try fewer words, or the Torah’s own spelling, which often leaves out ו and י.';

  @override
  String get searchNoResultsHintEnglish =>
      'Try fewer words, or the older English of the 1917 translation, such as “hath” for “has”.';

  @override
  String searchResultsAnnounced(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count verses found',
      one: '1 verse found',
      zero: 'No verses found',
    );
    return '$_temp0';
  }

  @override
  String get goToVerseLabel => 'A verse, word or phrase';

  @override
  String goToVerseHint(String book) {
    return '$book 28:12';
  }

  @override
  String goToVerseHelp(String example) {
    return 'Type a book or parsha, then a chapter and verse, as in $example; or words to search for.';
  }

  @override
  String goToVerseSearch(String query) {
    return 'Search for “$query”';
  }

  @override
  String goToVerseChapters(String book, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chapters',
      one: '1 chapter',
    );
    return '$book has $_temp0.';
  }

  @override
  String goToVerseVerses(String book, String chapter, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count verses',
      one: '1 verse',
    );
    return '$book $chapter has $_temp0.';
  }

  @override
  String get shortcutContinueReading => 'Continue reading';

  @override
  String get shortcutLogFromBook => 'Log reading from a book';

  @override
  String get shortcutThisWeek => 'This week\'s parsha';

  @override
  String simchatTorahInDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Simchat Torah in $count days',
      one: 'Simchat Torah is tomorrow',
      zero: 'Simchat Torah is today',
    );
    return '$_temp0';
  }

  @override
  String regularHaftarahOf(String portion) {
    return 'Also: the regular haftarah of $portion';
  }

  @override
  String get alsoRegularHaftarah => 'Also the regular haftarah';

  @override
  String get chabadFallbackNote =>
      'Chabad haftarot are being verified; showing the Ashkenazi reading.';

  @override
  String get repeatLastVerseDescChabad =>
      'Repeat the parsha\'s last verse in Hebrew after its Targum (Chabad custom: not repeated)';

  @override
  String get repeatLastVerseFollowsChabad =>
      '\"End with Mikra\" is now off, following the Chabad custom.';

  @override
  String get repeatLastVerseBackOn => '\"End with Mikra\" is on again.';

  @override
  String get divineAdonaiSpoken => 'Adonai';

  @override
  String get importBackupText => 'Backup text';

  @override
  String get importPasteFailed =>
      'Couldn\'t paste from the clipboard. Paste into the field instead.';

  @override
  String get exportSaved => 'Backup saved.';

  @override
  String get importPaste => 'Paste backup text';

  @override
  String get importPasteDesc => 'For a backup copied as text';

  @override
  String get pasteFromClipboard => 'Paste from clipboard';

  @override
  String importSummary(String date, int weeks, int pauses) {
    String _temp0 = intl.Intl.pluralLogic(
      weeks,
      locale: localeName,
      other: '$weeks weeks logged',
      one: '1 week logged',
      zero: 'nothing logged',
    );
    String _temp1 = intl.Intl.pluralLogic(
      pauses,
      locale: localeName,
      other: '$pauses pauses',
      one: '1 pause',
      zero: 'no pauses',
    );
    return 'Backup from $date: $_temp0, $_temp1.';
  }

  @override
  String importCounts(int weeks, int pauses) {
    String _temp0 = intl.Intl.pluralLogic(
      weeks,
      locale: localeName,
      other: '$weeks weeks logged',
      one: '1 week logged',
      zero: 'Nothing logged',
    );
    String _temp1 = intl.Intl.pluralLogic(
      pauses,
      locale: localeName,
      other: '$pauses pauses',
      one: '1 pause',
      zero: 'no pauses',
    );
    return '$_temp0, $_temp1.';
  }

  @override
  String get importMergeBody =>
      'Merge this backup with the progress on this device? Merging keeps everything from both.';

  @override
  String get importAlsoSettings => 'Also restore settings';

  @override
  String get importMerge => 'Merge';

  @override
  String get importReplace => 'Replace instead';

  @override
  String get importReplaceTitle => 'Replace the progress here?';

  @override
  String get importReplaceConfirm =>
      'This erases the reading history and streaks on this device, and keeps only what the backup holds. It can\'t be undone.';

  @override
  String get importReplaceConfirmSynced =>
      'This erases the reading history and streaks on this device, in your cloud backup, and on your other devices when they next sync, and keeps only what this backup holds. It can\'t be undone.';

  @override
  String get importReplaceAction => 'Replace';

  @override
  String get importSuccessRemindersOff =>
      'Progress imported. Reminders are off, since notifications aren\'t allowed for this app.';

  @override
  String get cloudBackup => 'Cloud backup';

  @override
  String get sourcesMamDescription =>
      'Hebrew text of the Torah and haftarot, based on the Aleppo Codex and related manuscripts, edited by Avi Kadish and collaborators on Hebrew Wikisource, via Sefaria. In the Torah, where Ashkenazi and Sephardi scrolls differ from the Aleppo Codex, the text follows the scrolls, with the Codex\'s reading in a note. Otherwise it is converted to a structured format without changing the text.';

  @override
  String get onbStarterTitle => 'This week';

  @override
  String get onbStarterCatchUp => 'Read the whole parsha by Shabbat';

  @override
  String onbStarterCatchUpDesc(int verses, int minutes, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'over $days days',
      one: 'today',
    );
    return '$verses verses · about $minutes min $_temp0';
  }

  @override
  String onbStarterCatchUpOn(int verses, int minutes, String day) {
    return '$verses verses · about $minutes min on $day';
  }

  @override
  String get onbStarterToday => 'Start with today\'s reading';

  @override
  String get onbStarterTodayDesc => 'Full plan from next week';

  @override
  String get onbRestore => 'I already use Shnayim Mikra';

  @override
  String get onbRestoreTitle => 'Restore your progress';

  @override
  String get onbRestoreSignIn => 'Sign in to restore';

  @override
  String get onbRestoreSignInDesc => 'From the backup kept with your account';

  @override
  String get onbRestoreFile => 'Restore from a backup file';

  @override
  String get onbRestoreFileDesc => 'A backup exported from Settings';

  @override
  String get onbRestoring => 'Restoring your progress…';

  @override
  String get onbRestoreDone => 'Your progress is restored.';

  @override
  String get onbRestoreDoneRemindersOff =>
      'Your progress is restored. Reminders are off, since notifications aren\'t allowed for this app.';

  @override
  String get onbRestoreNone =>
      'This account has no backup yet. Let\'s set up your reading.';

  @override
  String signedInNow(String name) {
    return 'Signed in as $name';
  }
}
