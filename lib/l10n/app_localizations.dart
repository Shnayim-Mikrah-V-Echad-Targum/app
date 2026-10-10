import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_he.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('he'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Shnayim Mikra'**
  String get appTitle;

  /// No description provided for @appTitleFull.
  ///
  /// In en, this message translates to:
  /// **'Shnayim Mikra v\'Echad Targum'**
  String get appTitleFull;

  /// No description provided for @navToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get navToday;

  /// No description provided for @navParsha.
  ///
  /// In en, this message translates to:
  /// **'Parsha'**
  String get navParsha;

  /// No description provided for @navProgress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get navProgress;

  /// No description provided for @navCommunity.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get navCommunity;

  /// No description provided for @navSettings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get navSettings;

  /// No description provided for @actionContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get actionContinue;

  /// No description provided for @actionNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get actionNext;

  /// No description provided for @actionBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get actionBack;

  /// No description provided for @actionDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get actionDone;

  /// No description provided for @actionCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get actionCancel;

  /// No description provided for @actionSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get actionSave;

  /// No description provided for @actionClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get actionClose;

  /// No description provided for @actionUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get actionUndo;

  /// No description provided for @actionRetry.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get actionRetry;

  /// No description provided for @actionOk.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get actionOk;

  /// No description provided for @actionShare.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get actionShare;

  /// No description provided for @actionLearnMore.
  ///
  /// In en, this message translates to:
  /// **'Learn more'**
  String get actionLearnMore;

  /// No description provided for @actionMarkRead.
  ///
  /// In en, this message translates to:
  /// **'Mark as read'**
  String get actionMarkRead;

  /// No description provided for @actionMarkUnread.
  ///
  /// In en, this message translates to:
  /// **'Mark as not read'**
  String get actionMarkUnread;

  /// No description provided for @actionStart.
  ///
  /// In en, this message translates to:
  /// **'Start'**
  String get actionStart;

  /// No description provided for @actionSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get actionSkip;

  /// No description provided for @actionNotNow.
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get actionNotNow;

  /// No description provided for @actionEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get actionEdit;

  /// No description provided for @actionDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get actionDelete;

  /// No description provided for @actionReport.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get actionReport;

  /// No description provided for @actionSend.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get actionSend;

  /// No description provided for @actionSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get actionSignIn;

  /// No description provided for @actionSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get actionSignOut;

  /// No description provided for @actionMore.
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get actionMore;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorGeneric;

  /// No description provided for @aliyah1.
  ///
  /// In en, this message translates to:
  /// **'Rishon'**
  String get aliyah1;

  /// No description provided for @aliyah2.
  ///
  /// In en, this message translates to:
  /// **'Sheni'**
  String get aliyah2;

  /// No description provided for @aliyah3.
  ///
  /// In en, this message translates to:
  /// **'Shlishi'**
  String get aliyah3;

  /// No description provided for @aliyah4.
  ///
  /// In en, this message translates to:
  /// **'Revi\'i'**
  String get aliyah4;

  /// No description provided for @aliyah5.
  ///
  /// In en, this message translates to:
  /// **'Chamishi'**
  String get aliyah5;

  /// No description provided for @aliyah6.
  ///
  /// In en, this message translates to:
  /// **'Shishi'**
  String get aliyah6;

  /// No description provided for @aliyah7.
  ///
  /// In en, this message translates to:
  /// **'Shevi\'i'**
  String get aliyah7;

  /// No description provided for @aliyahNumbered.
  ///
  /// In en, this message translates to:
  /// **'Aliyah {number}'**
  String aliyahNumbered(int number);

  /// No description provided for @aliyahWithName.
  ///
  /// In en, this message translates to:
  /// **'{name} · aliyah {number}'**
  String aliyahWithName(String name, int number);

  /// No description provided for @andJoiner.
  ///
  /// In en, this message translates to:
  /// **'{first} and {second}'**
  String andJoiner(String first, String second);

  /// No description provided for @passMikra1.
  ///
  /// In en, this message translates to:
  /// **'First reading'**
  String get passMikra1;

  /// No description provided for @passMikra2.
  ///
  /// In en, this message translates to:
  /// **'Second reading'**
  String get passMikra2;

  /// No description provided for @passTargum.
  ///
  /// In en, this message translates to:
  /// **'Targum'**
  String get passTargum;

  /// No description provided for @passRashi.
  ///
  /// In en, this message translates to:
  /// **'Rashi'**
  String get passRashi;

  /// Under the count of finished aliyot ("2/7") in the centre of the parsha rings.
  ///
  /// In en, this message translates to:
  /// **'aliyot'**
  String get aliyotWord;

  /// A count against its total, e.g. readings done out of the seven aliyot.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total}'**
  String countOfTotal(int done, int total);

  /// No description provided for @passShortMikra.
  ///
  /// In en, this message translates to:
  /// **'Mikra'**
  String get passShortMikra;

  /// No description provided for @passSemantics.
  ///
  /// In en, this message translates to:
  /// **'{pass}: {state}'**
  String passSemantics(String pass, String state);

  /// No description provided for @stateDone.
  ///
  /// In en, this message translates to:
  /// **'done'**
  String get stateDone;

  /// No description provided for @stateNotDone.
  ///
  /// In en, this message translates to:
  /// **'not done'**
  String get stateNotDone;

  /// No description provided for @versesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 verse} other{{count} verses}}'**
  String versesCount(int count);

  /// No description provided for @minutesEstimate.
  ///
  /// In en, this message translates to:
  /// **'about {minutes} min'**
  String minutesEstimate(int minutes);

  /// No description provided for @aliyotProgress.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} aliyot'**
  String aliyotProgress(int done, int total);

  /// No description provided for @readOnShabbat.
  ///
  /// In en, this message translates to:
  /// **'Read on Shabbat, {date}'**
  String readOnShabbat(String date);

  /// No description provided for @readOnSimchatTorah.
  ///
  /// In en, this message translates to:
  /// **'Read on Simchat Torah, {date}'**
  String readOnSimchatTorah(String date);

  /// No description provided for @shabbatInDays.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Shabbat is today} =1{Shabbat is tomorrow} other{Shabbat in {count} days}}'**
  String shabbatInDays(int count);

  /// No description provided for @parshaLabel.
  ///
  /// In en, this message translates to:
  /// **'Parshat {name}'**
  String parshaLabel(String name);

  /// No description provided for @todayReadingTitle.
  ///
  /// In en, this message translates to:
  /// **'Today\'s reading'**
  String get todayReadingTitle;

  /// No description provided for @todayDone.
  ///
  /// In en, this message translates to:
  /// **'Today\'s reading is done'**
  String get todayDone;

  /// No description provided for @todayAhead.
  ///
  /// In en, this message translates to:
  /// **'You\'re ahead of plan. Well done!'**
  String get todayAhead;

  /// No description provided for @todayNothingPlanned.
  ///
  /// In en, this message translates to:
  /// **'No reading is planned for today. A good day to catch up or read ahead.'**
  String get todayNothingPlanned;

  /// No description provided for @todayBehind.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 aliyah behind — very normal midweek.} other{{count} aliyot behind — very normal midweek.}}'**
  String todayBehind(int count);

  /// No description provided for @readTodaysAliyah.
  ///
  /// In en, this message translates to:
  /// **'Read today\'s reading'**
  String get readTodaysAliyah;

  /// No description provided for @continueReading.
  ///
  /// In en, this message translates to:
  /// **'Continue reading'**
  String get continueReading;

  /// No description provided for @startReading.
  ///
  /// In en, this message translates to:
  /// **'Start reading'**
  String get startReading;

  /// No description provided for @readFromBook.
  ///
  /// In en, this message translates to:
  /// **'I read it from a book'**
  String get readFromBook;

  /// No description provided for @weekComplete.
  ///
  /// In en, this message translates to:
  /// **'This week\'s parsha is complete. Yasher koach!'**
  String get weekComplete;

  /// No description provided for @haftarahLabel.
  ///
  /// In en, this message translates to:
  /// **'Haftarah'**
  String get haftarahLabel;

  /// No description provided for @haftarahRead.
  ///
  /// In en, this message translates to:
  /// **'Haftarah read'**
  String get haftarahRead;

  /// No description provided for @openWeekTitle.
  ///
  /// In en, this message translates to:
  /// **'{name} is still open'**
  String openWeekTitle(String name);

  /// No description provided for @openWeekLate.
  ///
  /// In en, this message translates to:
  /// **'Finish by {date} and it still counts.'**
  String openWeekLate(String date);

  /// No description provided for @openWeekRestore.
  ///
  /// In en, this message translates to:
  /// **'Finish {name} and {next} by Shabbat to keep your streak — one double-up per book.'**
  String openWeekRestore(String name, String next);

  /// No description provided for @checkInTitle.
  ///
  /// In en, this message translates to:
  /// **'Shavua tov! Did you read on Shabbat?'**
  String get checkInTitle;

  /// No description provided for @checkInBody.
  ///
  /// In en, this message translates to:
  /// **'Log what you read from a printed Chumash — it counts just the same.'**
  String get checkInBody;

  /// No description provided for @checkInFinished.
  ///
  /// In en, this message translates to:
  /// **'I finished it on Shabbat'**
  String get checkInFinished;

  /// No description provided for @checkInPick.
  ///
  /// In en, this message translates to:
  /// **'Choose aliyot'**
  String get checkInPick;

  /// No description provided for @pausedBanner.
  ///
  /// In en, this message translates to:
  /// **'Paused until {date}. Nothing resets while paused.'**
  String pausedBanner(String date);

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @discussThisWeek.
  ///
  /// In en, this message translates to:
  /// **'Discuss this week\'s parsha'**
  String get discussThisWeek;

  /// No description provided for @streakParsha.
  ///
  /// In en, this message translates to:
  /// **'Parsha streak'**
  String get streakParsha;

  /// No description provided for @streakDays.
  ///
  /// In en, this message translates to:
  /// **'Days on track'**
  String get streakDays;

  /// No description provided for @weeksCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 week} other{{count} weeks}}'**
  String weeksCount(int count);

  /// No description provided for @daysCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 day} other{{count} days}}'**
  String daysCount(int count);

  /// On the streak card, in place of a parsha streak of 0: the streak starts when this parsha is finished.
  ///
  /// In en, this message translates to:
  /// **'Begins with {name}'**
  String streakBeginsWith(String name);

  /// On the streak card, in place of 0 days on track.
  ///
  /// In en, this message translates to:
  /// **'Begins with today\'s reading'**
  String get daysBeginToday;

  /// No description provided for @graceDays.
  ///
  /// In en, this message translates to:
  /// **'Grace days'**
  String get graceDays;

  /// No description provided for @graceDaysAvailable.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{none available} =1{1 available} other{{count} available}}'**
  String graceDaysAvailable(int count);

  /// No description provided for @dayKept.
  ///
  /// In en, this message translates to:
  /// **'Read'**
  String get dayKept;

  /// No description provided for @dayAhead.
  ///
  /// In en, this message translates to:
  /// **'Ahead of plan'**
  String get dayAhead;

  /// No description provided for @dayCaughtUp.
  ///
  /// In en, this message translates to:
  /// **'Caught up'**
  String get dayCaughtUp;

  /// No description provided for @dayGrace.
  ///
  /// In en, this message translates to:
  /// **'Covered by a grace day'**
  String get dayGrace;

  /// No description provided for @dayPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get dayPaused;

  /// No description provided for @dayOpen.
  ///
  /// In en, this message translates to:
  /// **'Not yet'**
  String get dayOpen;

  /// No description provided for @dayMissed.
  ///
  /// In en, this message translates to:
  /// **'Not read'**
  String get dayMissed;

  /// No description provided for @dayRest.
  ///
  /// In en, this message translates to:
  /// **'Shabbat or Yom Tov'**
  String get dayRest;

  /// No description provided for @dayUpcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get dayUpcoming;

  /// No description provided for @dayNoReading.
  ///
  /// In en, this message translates to:
  /// **'No reading planned'**
  String get dayNoReading;

  /// In the week-strip legend, beside the mark for today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get dayToday;

  /// Under a Yom Tov day in the week strip (any Yom Tov, Yom Kippur and Rosh Hashana included), so it is not taken for Shabbat. Keep it short: the day is about 48 dp wide, and a longer word is shrunk to fit one line.
  ///
  /// In en, this message translates to:
  /// **'Yom Tov'**
  String get yomTovShort;

  /// No description provided for @dayChipLabel.
  ///
  /// In en, this message translates to:
  /// **'{day}: {status}'**
  String dayChipLabel(String day, String status);

  /// No description provided for @weekStripLabel.
  ///
  /// In en, this message translates to:
  /// **'This week\'s plan'**
  String get weekStripLabel;

  /// No description provided for @weekOnTime.
  ///
  /// In en, this message translates to:
  /// **'On time'**
  String get weekOnTime;

  /// No description provided for @weekLate.
  ///
  /// In en, this message translates to:
  /// **'After Shabbat — still counts'**
  String get weekLate;

  /// No description provided for @weekRestored.
  ///
  /// In en, this message translates to:
  /// **'Doubled up'**
  String get weekRestored;

  /// No description provided for @weekMadeUp.
  ///
  /// In en, this message translates to:
  /// **'Made up'**
  String get weekMadeUp;

  /// No description provided for @weekMissed.
  ///
  /// In en, this message translates to:
  /// **'Not completed'**
  String get weekMissed;

  /// No description provided for @weekTransparent.
  ///
  /// In en, this message translates to:
  /// **'Not counted'**
  String get weekTransparent;

  /// No description provided for @weekOverdue.
  ///
  /// In en, this message translates to:
  /// **'Can still be restored'**
  String get weekOverdue;

  /// No description provided for @weekInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get weekInProgress;

  /// No description provided for @plannedFor.
  ///
  /// In en, this message translates to:
  /// **'Planned for {day}'**
  String plannedFor(String day);

  /// No description provided for @plannedForShabbat.
  ///
  /// In en, this message translates to:
  /// **'Shabbat morning — log it after Shabbat'**
  String get plannedForShabbat;

  /// No description provided for @markWholeWeek.
  ///
  /// In en, this message translates to:
  /// **'Mark the whole parsha as read'**
  String get markWholeWeek;

  /// No description provided for @clearWeek.
  ///
  /// In en, this message translates to:
  /// **'Clear this week\'s progress'**
  String get clearWeek;

  /// No description provided for @clearWeekConfirm.
  ///
  /// In en, this message translates to:
  /// **'Clear all progress for {name}?'**
  String clearWeekConfirm(String name);

  /// No description provided for @whenDidYouRead.
  ///
  /// In en, this message translates to:
  /// **'When did you read it?'**
  String get whenDidYouRead;

  /// No description provided for @whenToday.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get whenToday;

  /// No description provided for @whenYesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get whenYesterday;

  /// No description provided for @whenOnShabbat.
  ///
  /// In en, this message translates to:
  /// **'On Shabbat'**
  String get whenOnShabbat;

  /// No description provided for @whenPickDate.
  ///
  /// In en, this message translates to:
  /// **'Choose a date'**
  String get whenPickDate;

  /// No description provided for @markedRead.
  ///
  /// In en, this message translates to:
  /// **'Marked as read'**
  String get markedRead;

  /// No description provided for @markedUnread.
  ///
  /// In en, this message translates to:
  /// **'Marked as not read'**
  String get markedUnread;

  /// No description provided for @aliyahNote.
  ///
  /// In en, this message translates to:
  /// **'Note: {note}'**
  String aliyahNote(String note);

  /// No description provided for @browseAll.
  ///
  /// In en, this message translates to:
  /// **'All parshiyot'**
  String get browseAll;

  /// No description provided for @browseTitle.
  ///
  /// In en, this message translates to:
  /// **'The Torah'**
  String get browseTitle;

  /// No description provided for @previewNotOpen.
  ///
  /// In en, this message translates to:
  /// **'Preview — this parsha opens for credit on {date}.'**
  String previewNotOpen(String date);

  /// No description provided for @stepMikra1.
  ///
  /// In en, this message translates to:
  /// **'Read the Hebrew'**
  String get stepMikra1;

  /// No description provided for @stepMikra2.
  ///
  /// In en, this message translates to:
  /// **'Read the Hebrew again'**
  String get stepMikra2;

  /// No description provided for @stepTargum.
  ///
  /// In en, this message translates to:
  /// **'Read the Targum'**
  String get stepTargum;

  /// No description provided for @stepRashi.
  ///
  /// In en, this message translates to:
  /// **'Read Rashi'**
  String get stepRashi;

  /// No description provided for @stepThirdHebrew.
  ///
  /// In en, this message translates to:
  /// **'Read the Hebrew a third time'**
  String get stepThirdHebrew;

  /// No description provided for @stepRepeatLast.
  ///
  /// In en, this message translates to:
  /// **'End with Mikra: read the last verse once more'**
  String get stepRepeatLast;

  /// No description provided for @stepOf.
  ///
  /// In en, this message translates to:
  /// **'Reading {step} of {total}'**
  String stepOf(int step, int total);

  /// No description provided for @verseOf.
  ///
  /// In en, this message translates to:
  /// **'Verse {current} of {total}'**
  String verseOf(int current, int total);

  /// No description provided for @sectionOf.
  ///
  /// In en, this message translates to:
  /// **'Section {current} of {total}'**
  String sectionOf(int current, int total);

  /// No description provided for @verseLabel.
  ///
  /// In en, this message translates to:
  /// **'Verse {number}'**
  String verseLabel(String number);

  /// No description provided for @chapterLabel.
  ///
  /// In en, this message translates to:
  /// **'Chapter {number}'**
  String chapterLabel(String number);

  /// No description provided for @noTargumNote.
  ///
  /// In en, this message translates to:
  /// **'Many read this verse a third time in Hebrew in place of the Targum (Shulchan Aruch OC 285:2).'**
  String get noTargumNote;

  /// No description provided for @noRashiNote.
  ///
  /// In en, this message translates to:
  /// **'Rashi does not comment on this verse. Some read it a third time in Hebrew (Mishnah Berurah 285:5).'**
  String get noRashiNote;

  /// No description provided for @ketivQereLabel.
  ///
  /// In en, this message translates to:
  /// **'Written {ketiv}, read {qere}'**
  String ketivQereLabel(String ketiv, String qere);

  /// No description provided for @ketivOnlyLabel.
  ///
  /// In en, this message translates to:
  /// **'Written {ketiv}, not read'**
  String ketivOnlyLabel(String ketiv);

  /// No description provided for @qereOnlyLabel.
  ///
  /// In en, this message translates to:
  /// **'Read {qere}, not written'**
  String qereOnlyLabel(String qere);

  /// No description provided for @noteLabel.
  ///
  /// In en, this message translates to:
  /// **'Note: {text}'**
  String noteLabel(String text);

  /// No description provided for @aliyahComplete.
  ///
  /// In en, this message translates to:
  /// **'Yasher koach! {aliyah} is complete.'**
  String aliyahComplete(String aliyah);

  /// No description provided for @parshaComplete.
  ///
  /// In en, this message translates to:
  /// **'Chazak! Parshat {name} is complete.'**
  String parshaComplete(String name);

  /// No description provided for @firstAliyahDone.
  ///
  /// In en, this message translates to:
  /// **'Yasher koach! Your first aliyah is done — {verses}, twice, with Targum.'**
  String firstAliyahDone(String verses);

  /// No description provided for @nextAliyah.
  ///
  /// In en, this message translates to:
  /// **'Next aliyah'**
  String get nextAliyah;

  /// No description provided for @backToWeek.
  ///
  /// In en, this message translates to:
  /// **'Back to the week'**
  String get backToWeek;

  /// No description provided for @displaySettings.
  ///
  /// In en, this message translates to:
  /// **'Display settings'**
  String get displaySettings;

  /// No description provided for @textSize.
  ///
  /// In en, this message translates to:
  /// **'Text size'**
  String get textSize;

  /// No description provided for @textSmaller.
  ///
  /// In en, this message translates to:
  /// **'Smaller text'**
  String get textSmaller;

  /// No description provided for @textLarger.
  ///
  /// In en, this message translates to:
  /// **'Larger text'**
  String get textLarger;

  /// No description provided for @listen.
  ///
  /// In en, this message translates to:
  /// **'Listen'**
  String get listen;

  /// No description provided for @stopListening.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stopListening;

  /// No description provided for @ttsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Text-to-speech isn\'t available on this device.'**
  String get ttsUnavailable;

  /// No description provided for @ttsNoHebrewVoice.
  ///
  /// In en, this message translates to:
  /// **'No Hebrew voice is installed. You can add one in your device\'s speech settings.'**
  String get ttsNoHebrewVoice;

  /// No description provided for @guidedMode.
  ///
  /// In en, this message translates to:
  /// **'Guided reading'**
  String get guidedMode;

  /// No description provided for @fullTextMode.
  ///
  /// In en, this message translates to:
  /// **'Full text'**
  String get fullTextMode;

  /// No description provided for @markAliyahRead.
  ///
  /// In en, this message translates to:
  /// **'Mark this aliyah as read'**
  String get markAliyahRead;

  /// No description provided for @keyboardShortcuts.
  ///
  /// In en, this message translates to:
  /// **'Keyboard shortcuts'**
  String get keyboardShortcuts;

  /// No description provided for @translationDisclaimer.
  ///
  /// In en, this message translates to:
  /// **'A translation is a study aid. It does not take the place of the Targum.'**
  String get translationDisclaimer;

  /// No description provided for @mikraLabel.
  ///
  /// In en, this message translates to:
  /// **'Torah'**
  String get mikraLabel;

  /// No description provided for @targumLabel.
  ///
  /// In en, this message translates to:
  /// **'Targum Onkelos'**
  String get targumLabel;

  /// No description provided for @rashiLabel.
  ///
  /// In en, this message translates to:
  /// **'Rashi'**
  String get rashiLabel;

  /// No description provided for @translationLabel.
  ///
  /// In en, this message translates to:
  /// **'Translation (JPS 1917)'**
  String get translationLabel;

  /// No description provided for @haftarahTitle.
  ///
  /// In en, this message translates to:
  /// **'Haftarah'**
  String get haftarahTitle;

  /// No description provided for @markHaftarahRead.
  ///
  /// In en, this message translates to:
  /// **'Mark the haftarah as read'**
  String get markHaftarahRead;

  /// No description provided for @specialHaftarah.
  ///
  /// In en, this message translates to:
  /// **'Special haftarah: {reason}'**
  String specialHaftarah(String reason);

  /// No description provided for @readerFinished.
  ///
  /// In en, this message translates to:
  /// **'You\'ve finished this aliyah.'**
  String get readerFinished;

  /// No description provided for @shortcutNext.
  ///
  /// In en, this message translates to:
  /// **'Next step'**
  String get shortcutNext;

  /// No description provided for @shortcutBack.
  ///
  /// In en, this message translates to:
  /// **'Previous step'**
  String get shortcutBack;

  /// No description provided for @shortcutLarger.
  ///
  /// In en, this message translates to:
  /// **'Larger text'**
  String get shortcutLarger;

  /// No description provided for @shortcutSmaller.
  ///
  /// In en, this message translates to:
  /// **'Smaller text'**
  String get shortcutSmaller;

  /// No description provided for @shortcutTeamim.
  ///
  /// In en, this message translates to:
  /// **'Show or hide cantillation'**
  String get shortcutTeamim;

  /// No description provided for @shortcutNikud.
  ///
  /// In en, this message translates to:
  /// **'Show or hide vowels'**
  String get shortcutNikud;

  /// No description provided for @shortcutListen.
  ///
  /// In en, this message translates to:
  /// **'Listen / stop'**
  String get shortcutListen;

  /// No description provided for @shortcutHelp.
  ///
  /// In en, this message translates to:
  /// **'Show shortcuts'**
  String get shortcutHelp;

  /// No description provided for @progressTitle.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get progressTitle;

  /// No description provided for @longest.
  ///
  /// In en, this message translates to:
  /// **'Longest: {value}'**
  String longest(String value);

  /// No description provided for @thisCycle.
  ///
  /// In en, this message translates to:
  /// **'This year: {done} of 54 parshiyot'**
  String thisCycle(int done);

  /// No description provided for @versesRead.
  ///
  /// In en, this message translates to:
  /// **'{count} verses read twice with Targum'**
  String versesRead(String count);

  /// Screen-reader label of the bar of the year's parshiyot, when none is being read now.
  ///
  /// In en, this message translates to:
  /// **'This year: {done} of {total} parshiyot complete'**
  String yearBarSemantics(int done, int total);

  /// Screen-reader label of the bar of the year's parshiyot; name is this week's parsha.
  ///
  /// In en, this message translates to:
  /// **'This year: {done} of {total} parshiyot complete; {name} in progress'**
  String yearBarSemanticsCurrent(int done, int total, String name);

  /// Short name of the book under its part of the year bar.
  ///
  /// In en, this message translates to:
  /// **'Gen'**
  String get bookAbbrGenesis;

  /// No description provided for @bookAbbrExodus.
  ///
  /// In en, this message translates to:
  /// **'Exo'**
  String get bookAbbrExodus;

  /// No description provided for @bookAbbrLeviticus.
  ///
  /// In en, this message translates to:
  /// **'Lev'**
  String get bookAbbrLeviticus;

  /// No description provided for @bookAbbrNumbers.
  ///
  /// In en, this message translates to:
  /// **'Num'**
  String get bookAbbrNumbers;

  /// No description provided for @bookAbbrDeuteronomy.
  ///
  /// In en, this message translates to:
  /// **'Deu'**
  String get bookAbbrDeuteronomy;

  /// No description provided for @torahMap.
  ///
  /// In en, this message translates to:
  /// **'Torah map'**
  String get torahMap;

  /// No description provided for @torahMapHelp.
  ///
  /// In en, this message translates to:
  /// **'Each tile is one parsha of this year\'s cycle.'**
  String get torahMapHelp;

  /// Screen-reader label of a book's header on the Torah map; the header expands or collapses that book.
  ///
  /// In en, this message translates to:
  /// **'{book}: {done} of {total} parshiyot'**
  String torahMapBook(String book, int done, int total);

  /// No description provided for @recentWeeks.
  ///
  /// In en, this message translates to:
  /// **'Recent weeks'**
  String get recentWeeks;

  /// No description provided for @makeUpTitle.
  ///
  /// In en, this message translates to:
  /// **'Make up before Simchat Torah'**
  String get makeUpTitle;

  /// No description provided for @makeUpBody.
  ///
  /// In en, this message translates to:
  /// **'Optional. Make-ups count toward this year\'s siyum.'**
  String get makeUpBody;

  /// No description provided for @pauseTitle.
  ///
  /// In en, this message translates to:
  /// **'Life happens'**
  String get pauseTitle;

  /// No description provided for @pauseBody.
  ///
  /// In en, this message translates to:
  /// **'Pause for up to 30 days — nothing resets while paused. Illness, travel, mourning, a new baby: life comes first.'**
  String get pauseBody;

  /// No description provided for @pauseAction.
  ///
  /// In en, this message translates to:
  /// **'Pause streaks'**
  String get pauseAction;

  /// No description provided for @pauseFor.
  ///
  /// In en, this message translates to:
  /// **'Pause for'**
  String get pauseFor;

  /// No description provided for @pauseStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting'**
  String get pauseStarting;

  /// No description provided for @pauseStarted.
  ///
  /// In en, this message translates to:
  /// **'Paused until {date}.'**
  String pauseStarted(String date);

  /// No description provided for @pauseEnded.
  ///
  /// In en, this message translates to:
  /// **'Welcome back! Your place is saved.'**
  String get pauseEnded;

  /// No description provided for @streaksHidden.
  ///
  /// In en, this message translates to:
  /// **'Streak numbers are hidden. Your progress is still saved.'**
  String get streaksHidden;

  /// No description provided for @milestonesTitle.
  ///
  /// In en, this message translates to:
  /// **'Milestones'**
  String get milestonesTitle;

  /// No description provided for @graceExplainer.
  ///
  /// In en, this message translates to:
  /// **'Grace days cover a missed planned day automatically. You start with 2, earn 1 each time you finish a parsha before Shabbat (up to 3), and use at most 2 a week. They can never be bought.'**
  String get graceExplainer;

  /// No description provided for @streakExplainer.
  ///
  /// In en, this message translates to:
  /// **'Your parsha streak counts portions finished before Shabbat — or by Tuesday night, which still counts. Shabbat and Yom Tov never break a streak.'**
  String get streakExplainer;

  /// No description provided for @statusLegend.
  ///
  /// In en, this message translates to:
  /// **'Legend'**
  String get statusLegend;

  /// No description provided for @noHistory.
  ///
  /// In en, this message translates to:
  /// **'Your weeks will appear here as you read.'**
  String get noHistory;

  /// No description provided for @milestoneFirstAliyah.
  ///
  /// In en, this message translates to:
  /// **'First aliyah'**
  String get milestoneFirstAliyah;

  /// No description provided for @milestoneFirstParsha.
  ///
  /// In en, this message translates to:
  /// **'First parsha'**
  String get milestoneFirstParsha;

  /// No description provided for @milestonePerfectWeek.
  ///
  /// In en, this message translates to:
  /// **'Perfect week'**
  String get milestonePerfectWeek;

  /// No description provided for @milestoneParshaStreak.
  ///
  /// In en, this message translates to:
  /// **'{count}-week parsha streak'**
  String milestoneParshaStreak(int count);

  /// No description provided for @milestoneDaysOnTrack.
  ///
  /// In en, this message translates to:
  /// **'{count} days on track'**
  String milestoneDaysOnTrack(int count);

  /// No description provided for @milestoneSefer.
  ///
  /// In en, this message translates to:
  /// **'Sefer {book} complete — Chazak!'**
  String milestoneSefer(String book);

  /// No description provided for @milestoneSiyum.
  ///
  /// In en, this message translates to:
  /// **'Siyum HaTorah'**
  String get milestoneSiyum;

  /// No description provided for @milestoneComeback.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get milestoneComeback;

  /// No description provided for @milestoneLocked.
  ///
  /// In en, this message translates to:
  /// **'Not yet reached'**
  String get milestoneLocked;

  /// No description provided for @settingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settingsTitle;

  /// No description provided for @settingsReading.
  ///
  /// In en, this message translates to:
  /// **'Reading & customs'**
  String get settingsReading;

  /// No description provided for @settingsDisplay.
  ///
  /// In en, this message translates to:
  /// **'Display'**
  String get settingsDisplay;

  /// No description provided for @settingsAccessibility.
  ///
  /// In en, this message translates to:
  /// **'Accessibility'**
  String get settingsAccessibility;

  /// No description provided for @settingsReminders.
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get settingsReminders;

  /// No description provided for @settingsStreaks.
  ///
  /// In en, this message translates to:
  /// **'Streaks'**
  String get settingsStreaks;

  /// No description provided for @settingsAccount.
  ///
  /// In en, this message translates to:
  /// **'Account & community'**
  String get settingsAccount;

  /// No description provided for @settingsData.
  ///
  /// In en, this message translates to:
  /// **'Your data'**
  String get settingsData;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsAbout.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get settingsAbout;

  /// No description provided for @settingsReadingDesc.
  ///
  /// In en, this message translates to:
  /// **'Location, plan, Targum or Rashi, haftarah'**
  String get settingsReadingDesc;

  /// No description provided for @settingsDisplayDesc.
  ///
  /// In en, this message translates to:
  /// **'Theme, fonts, text size, vowels and cantillation'**
  String get settingsDisplayDesc;

  /// No description provided for @settingsAccessibilityDesc.
  ///
  /// In en, this message translates to:
  /// **'Motion, screen readers, speech, quick setups'**
  String get settingsAccessibilityDesc;

  /// No description provided for @settingsRemindersDesc.
  ///
  /// In en, this message translates to:
  /// **'Gentle reminders, never on Shabbat or Yom Tov'**
  String get settingsRemindersDesc;

  /// No description provided for @settingsDataDesc.
  ///
  /// In en, this message translates to:
  /// **'Back up, restore or reset your progress'**
  String get settingsDataDesc;

  /// No description provided for @locationLabel.
  ///
  /// In en, this message translates to:
  /// **'This Shabbat I\'ll be'**
  String get locationLabel;

  /// No description provided for @locationIsrael.
  ///
  /// In en, this message translates to:
  /// **'In Israel'**
  String get locationIsrael;

  /// No description provided for @locationDiaspora.
  ///
  /// In en, this message translates to:
  /// **'Outside Israel'**
  String get locationDiaspora;

  /// No description provided for @locationHelp.
  ///
  /// In en, this message translates to:
  /// **'Israel and the Diaspora sometimes read different parshiyot and keep a different number of Yom Tov days.'**
  String get locationHelp;

  /// No description provided for @planLabel.
  ///
  /// In en, this message translates to:
  /// **'Weekly plan'**
  String get planLabel;

  /// No description provided for @planAliyahPerDay.
  ///
  /// In en, this message translates to:
  /// **'An aliyah a day'**
  String get planAliyahPerDay;

  /// No description provided for @planAliyahPerDayDesc.
  ///
  /// In en, this message translates to:
  /// **'One aliyah Sunday–Thursday; the 6th and 7th on Friday'**
  String get planAliyahPerDayDesc;

  /// No description provided for @planShevii.
  ///
  /// In en, this message translates to:
  /// **'Shevi\'i on Shabbat morning'**
  String get planShevii;

  /// No description provided for @planSheviiDesc.
  ///
  /// In en, this message translates to:
  /// **'Aliyot 1–6 Sunday–Friday; the 7th before the Shabbat meal'**
  String get planSheviiDesc;

  /// No description provided for @planErevShabbat.
  ///
  /// In en, this message translates to:
  /// **'All on Friday'**
  String get planErevShabbat;

  /// No description provided for @planErevShabbatDesc.
  ///
  /// In en, this message translates to:
  /// **'The whole parsha on Erev Shabbat (Arizal; Shulchan Aruch HaRav)'**
  String get planErevShabbatDesc;

  /// No description provided for @methodLabel.
  ///
  /// In en, this message translates to:
  /// **'Reading method'**
  String get methodLabel;

  /// No description provided for @methodVerse.
  ///
  /// In en, this message translates to:
  /// **'Verse by verse'**
  String get methodVerse;

  /// No description provided for @methodVerseDesc.
  ///
  /// In en, this message translates to:
  /// **'Each verse twice, then its Targum'**
  String get methodVerseDesc;

  /// No description provided for @methodSection.
  ///
  /// In en, this message translates to:
  /// **'Section by section'**
  String get methodSection;

  /// No description provided for @methodSectionDesc.
  ///
  /// In en, this message translates to:
  /// **'Each paragraph twice, then its Targum'**
  String get methodSectionDesc;

  /// No description provided for @methodAliyah.
  ///
  /// In en, this message translates to:
  /// **'Aliyah by aliyah'**
  String get methodAliyah;

  /// No description provided for @methodAliyahDesc.
  ///
  /// In en, this message translates to:
  /// **'The whole aliyah twice, then its Targum'**
  String get methodAliyahDesc;

  /// No description provided for @secondLabel.
  ///
  /// In en, this message translates to:
  /// **'Targum'**
  String get secondLabel;

  /// No description provided for @secondOnkelos.
  ///
  /// In en, this message translates to:
  /// **'Targum Onkelos'**
  String get secondOnkelos;

  /// No description provided for @secondRashi.
  ///
  /// In en, this message translates to:
  /// **'Rashi'**
  String get secondRashi;

  /// No description provided for @secondBoth.
  ///
  /// In en, this message translates to:
  /// **'Onkelos and Rashi'**
  String get secondBoth;

  /// No description provided for @secondRashiEnglish.
  ///
  /// In en, this message translates to:
  /// **'Rashi in English'**
  String get secondRashiEnglish;

  /// No description provided for @secondHelp.
  ///
  /// In en, this message translates to:
  /// **'The Shulchan Aruch (OC 285:2) permits Rashi in place of Targum, and praises reading both. A plain translation is a study aid, not a substitute. Ask your rav about translated Rashi.'**
  String get secondHelp;

  /// No description provided for @repeatLastVerse.
  ///
  /// In en, this message translates to:
  /// **'End with Mikra'**
  String get repeatLastVerse;

  /// No description provided for @repeatLastVerseDesc.
  ///
  /// In en, this message translates to:
  /// **'Repeat the parsha\'s last verse in Hebrew after its Targum'**
  String get repeatLastVerseDesc;

  /// No description provided for @thirdReading.
  ///
  /// In en, this message translates to:
  /// **'Third-reading prompts'**
  String get thirdReading;

  /// No description provided for @thirdReadingDesc.
  ///
  /// In en, this message translates to:
  /// **'Where there is no Targum or Rashi, suggest reading the Hebrew a third time'**
  String get thirdReadingDesc;

  /// No description provided for @haftarahEnabled.
  ///
  /// In en, this message translates to:
  /// **'Haftarah'**
  String get haftarahEnabled;

  /// No description provided for @haftarahEnabledDesc.
  ///
  /// In en, this message translates to:
  /// **'Read the week\'s haftarah once'**
  String get haftarahEnabledDesc;

  /// No description provided for @nusachLabel.
  ///
  /// In en, this message translates to:
  /// **'Haftarah custom'**
  String get nusachLabel;

  /// No description provided for @nusachAshkenazi.
  ///
  /// In en, this message translates to:
  /// **'Ashkenazi'**
  String get nusachAshkenazi;

  /// No description provided for @nusachSephardi.
  ///
  /// In en, this message translates to:
  /// **'Sephardi'**
  String get nusachSephardi;

  /// No description provided for @nusachChabad.
  ///
  /// In en, this message translates to:
  /// **'Chabad'**
  String get nusachChabad;

  /// No description provided for @haftarahRequired.
  ///
  /// In en, this message translates to:
  /// **'Count the haftarah toward completion'**
  String get haftarahRequired;

  /// No description provided for @lateWindowLabel.
  ///
  /// In en, this message translates to:
  /// **'After-Shabbat window'**
  String get lateWindowLabel;

  /// No description provided for @lateTuesday.
  ///
  /// In en, this message translates to:
  /// **'Until Tuesday night'**
  String get lateTuesday;

  /// No description provided for @lateWednesday.
  ///
  /// In en, this message translates to:
  /// **'Until Wednesday night'**
  String get lateWednesday;

  /// No description provided for @lateNone.
  ///
  /// In en, this message translates to:
  /// **'No window'**
  String get lateNone;

  /// No description provided for @lateWindowDesc.
  ///
  /// In en, this message translates to:
  /// **'Reading finished after Shabbat, until this time, still counts (Shulchan Aruch OC 285:4).'**
  String get lateWindowDesc;

  /// No description provided for @tishaBavQuiet.
  ///
  /// In en, this message translates to:
  /// **'No reading planned on Tisha B\'Av'**
  String get tishaBavQuiet;

  /// No description provided for @cholHamoedQuiet.
  ///
  /// In en, this message translates to:
  /// **'No reading planned on Chol HaMoed'**
  String get cholHamoedQuiet;

  /// No description provided for @nameStyleLabel.
  ///
  /// In en, this message translates to:
  /// **'Parsha names'**
  String get nameStyleLabel;

  /// No description provided for @nameSephardi.
  ///
  /// In en, this message translates to:
  /// **'Sephardi (Bereshit)'**
  String get nameSephardi;

  /// No description provided for @nameAshkenazi.
  ///
  /// In en, this message translates to:
  /// **'Ashkenazi (Bereishis)'**
  String get nameAshkenazi;

  /// No description provided for @themeLabel.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get themeLabel;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'Match device'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @themeSepia.
  ///
  /// In en, this message translates to:
  /// **'Sepia'**
  String get themeSepia;

  /// No description provided for @themeHcLight.
  ///
  /// In en, this message translates to:
  /// **'High contrast — light'**
  String get themeHcLight;

  /// No description provided for @themeHcDark.
  ///
  /// In en, this message translates to:
  /// **'High contrast — dark'**
  String get themeHcDark;

  /// No description provided for @scriptureFontLabel.
  ///
  /// In en, this message translates to:
  /// **'Scripture font'**
  String get scriptureFontLabel;

  /// No description provided for @fontNotoSerif.
  ///
  /// In en, this message translates to:
  /// **'Noto Serif Hebrew'**
  String get fontNotoSerif;

  /// No description provided for @fontTaamey.
  ///
  /// In en, this message translates to:
  /// **'Taamey Frank (classic Chumash)'**
  String get fontTaamey;

  /// No description provided for @fontEzra.
  ///
  /// In en, this message translates to:
  /// **'Ezra SIL'**
  String get fontEzra;

  /// No description provided for @fontNotoSans.
  ///
  /// In en, this message translates to:
  /// **'Noto Sans Hebrew (sans-serif)'**
  String get fontNotoSans;

  /// No description provided for @readingSize.
  ///
  /// In en, this message translates to:
  /// **'Reading size'**
  String get readingSize;

  /// No description provided for @readingSizeValue.
  ///
  /// In en, this message translates to:
  /// **'{percent}%'**
  String readingSizeValue(int percent);

  /// Tooltip and spoken name of the minus button beside a settings slider. title is the slider's name, such as 'Reading size'.
  ///
  /// In en, this message translates to:
  /// **'{title}: decrease'**
  String sliderDecrease(String title);

  /// Tooltip and spoken name of the plus button beside a settings slider. title is the slider's name, such as 'Reading size'.
  ///
  /// In en, this message translates to:
  /// **'{title}: increase'**
  String sliderIncrease(String title);

  /// No description provided for @lineSpacing.
  ///
  /// In en, this message translates to:
  /// **'Line spacing'**
  String get lineSpacing;

  /// No description provided for @wordSpacing.
  ///
  /// In en, this message translates to:
  /// **'Word spacing'**
  String get wordSpacing;

  /// No description provided for @letterSpacing.
  ///
  /// In en, this message translates to:
  /// **'Letter spacing'**
  String get letterSpacing;

  /// No description provided for @showNikud.
  ///
  /// In en, this message translates to:
  /// **'Vowels (nikud)'**
  String get showNikud;

  /// No description provided for @showTeamim.
  ///
  /// In en, this message translates to:
  /// **'Cantillation (ta\'amim)'**
  String get showTeamim;

  /// No description provided for @showKetiv.
  ///
  /// In en, this message translates to:
  /// **'Show ketiv (as written)'**
  String get showKetiv;

  /// No description provided for @showVerseNumbers.
  ///
  /// In en, this message translates to:
  /// **'Verse numbers'**
  String get showVerseNumbers;

  /// No description provided for @justifyText.
  ///
  /// In en, this message translates to:
  /// **'Justify text'**
  String get justifyText;

  /// No description provided for @lineWidthLabel.
  ///
  /// In en, this message translates to:
  /// **'Line width'**
  String get lineWidthLabel;

  /// No description provided for @lineNarrow.
  ///
  /// In en, this message translates to:
  /// **'Narrow'**
  String get lineNarrow;

  /// No description provided for @lineMedium.
  ///
  /// In en, this message translates to:
  /// **'Medium'**
  String get lineMedium;

  /// No description provided for @lineWide.
  ///
  /// In en, this message translates to:
  /// **'Wide'**
  String get lineWide;

  /// No description provided for @showTranslation.
  ///
  /// In en, this message translates to:
  /// **'English translation (study aid)'**
  String get showTranslation;

  /// No description provided for @showRashi.
  ///
  /// In en, this message translates to:
  /// **'Show Rashi alongside'**
  String get showRashi;

  /// No description provided for @uiFontLabel.
  ///
  /// In en, this message translates to:
  /// **'Interface font'**
  String get uiFontLabel;

  /// No description provided for @uiFontStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get uiFontStandard;

  /// No description provided for @uiFontAtkinson.
  ///
  /// In en, this message translates to:
  /// **'Atkinson Hyperlegible'**
  String get uiFontAtkinson;

  /// No description provided for @uiFontLexend.
  ///
  /// In en, this message translates to:
  /// **'Lexend'**
  String get uiFontLexend;

  /// No description provided for @uiFontOpenDyslexic.
  ///
  /// In en, this message translates to:
  /// **'OpenDyslexic'**
  String get uiFontOpenDyslexic;

  /// No description provided for @uiFontSystem.
  ///
  /// In en, this message translates to:
  /// **'Device font'**
  String get uiFontSystem;

  /// No description provided for @boldText.
  ///
  /// In en, this message translates to:
  /// **'Bold text'**
  String get boldText;

  /// No description provided for @focusMode.
  ///
  /// In en, this message translates to:
  /// **'Focus mode'**
  String get focusMode;

  /// No description provided for @focusModeDesc.
  ///
  /// In en, this message translates to:
  /// **'Highlight the current verse and dim the rest'**
  String get focusModeDesc;

  /// No description provided for @keepScreenOn.
  ///
  /// In en, this message translates to:
  /// **'Keep the screen on while reading'**
  String get keepScreenOn;

  /// No description provided for @previewLabel.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get previewLabel;

  /// No description provided for @reduceMotion.
  ///
  /// In en, this message translates to:
  /// **'Reduce motion'**
  String get reduceMotion;

  /// No description provided for @reduceMotionDesc.
  ///
  /// In en, this message translates to:
  /// **'Turn off animations and moving celebrations'**
  String get reduceMotionDesc;

  /// No description provided for @haptics.
  ///
  /// In en, this message translates to:
  /// **'Haptic feedback'**
  String get haptics;

  /// No description provided for @screenReaderText.
  ///
  /// In en, this message translates to:
  /// **'Screen reader text'**
  String get screenReaderText;

  /// No description provided for @srSimplified.
  ///
  /// In en, this message translates to:
  /// **'Vowels, no cantillation (recommended)'**
  String get srSimplified;

  /// No description provided for @srConsonants.
  ///
  /// In en, this message translates to:
  /// **'Letters only'**
  String get srConsonants;

  /// No description provided for @srAllMarks.
  ///
  /// In en, this message translates to:
  /// **'All marks (for braille displays)'**
  String get srAllMarks;

  /// No description provided for @divineNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Speaking the Divine Name'**
  String get divineNameLabel;

  /// No description provided for @divineAdonai.
  ///
  /// In en, this message translates to:
  /// **'Adonai'**
  String get divineAdonai;

  /// No description provided for @divineHashem.
  ///
  /// In en, this message translates to:
  /// **'HaShem'**
  String get divineHashem;

  /// No description provided for @speechRate.
  ///
  /// In en, this message translates to:
  /// **'Speech rate'**
  String get speechRate;

  /// No description provided for @presetsTitle.
  ///
  /// In en, this message translates to:
  /// **'Quick setups'**
  String get presetsTitle;

  /// No description provided for @presetLargePrint.
  ///
  /// In en, this message translates to:
  /// **'Large print'**
  String get presetLargePrint;

  /// No description provided for @presetDyslexia.
  ///
  /// In en, this message translates to:
  /// **'Dyslexia-friendly'**
  String get presetDyslexia;

  /// No description provided for @presetHighContrast.
  ///
  /// In en, this message translates to:
  /// **'High contrast'**
  String get presetHighContrast;

  /// No description provided for @presetLowVision.
  ///
  /// In en, this message translates to:
  /// **'Low vision'**
  String get presetLowVision;

  /// No description provided for @presetReset.
  ///
  /// In en, this message translates to:
  /// **'Reset display'**
  String get presetReset;

  /// No description provided for @presetApplied.
  ///
  /// In en, this message translates to:
  /// **'{name} applied'**
  String presetApplied(String name);

  /// No description provided for @accessibilityStatement.
  ///
  /// In en, this message translates to:
  /// **'Accessibility statement'**
  String get accessibilityStatement;

  /// No description provided for @sendFeedback.
  ///
  /// In en, this message translates to:
  /// **'Send feedback'**
  String get sendFeedback;

  /// No description provided for @dailyReminder.
  ///
  /// In en, this message translates to:
  /// **'Daily reminder'**
  String get dailyReminder;

  /// No description provided for @dailyReminderDesc.
  ///
  /// In en, this message translates to:
  /// **'A gentle nudge at your chosen time'**
  String get dailyReminderDesc;

  /// No description provided for @reminderTime.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get reminderTime;

  /// No description provided for @fridayReminder.
  ///
  /// In en, this message translates to:
  /// **'Erev Shabbat reminder'**
  String get fridayReminder;

  /// No description provided for @fridayReminderDesc.
  ///
  /// In en, this message translates to:
  /// **'Friday morning, only if the parsha isn\'t finished'**
  String get fridayReminderDesc;

  /// No description provided for @checkInReminder.
  ///
  /// In en, this message translates to:
  /// **'After-Shabbat check-in'**
  String get checkInReminder;

  /// No description provided for @checkInReminderDesc.
  ///
  /// In en, this message translates to:
  /// **'Sunday morning, to log what you read on Shabbat'**
  String get checkInReminderDesc;

  /// No description provided for @remindersShabbatNote.
  ///
  /// In en, this message translates to:
  /// **'Reminders are never sent on Shabbat or Yom Tov, and never more than one a day.'**
  String get remindersShabbatNote;

  /// No description provided for @habitAnchorLabel.
  ///
  /// In en, this message translates to:
  /// **'After I…'**
  String get habitAnchorLabel;

  /// No description provided for @habitAnchorPrompt.
  ///
  /// In en, this message translates to:
  /// **'Tie your reading to something you already do every day.'**
  String get habitAnchorPrompt;

  /// No description provided for @anchorShacharit.
  ///
  /// In en, this message translates to:
  /// **'finish Shacharit'**
  String get anchorShacharit;

  /// No description provided for @anchorBreakfast.
  ///
  /// In en, this message translates to:
  /// **'eat breakfast'**
  String get anchorBreakfast;

  /// No description provided for @anchorCommute.
  ///
  /// In en, this message translates to:
  /// **'start my commute'**
  String get anchorCommute;

  /// No description provided for @anchorDinner.
  ///
  /// In en, this message translates to:
  /// **'finish dinner'**
  String get anchorDinner;

  /// No description provided for @anchorBed.
  ///
  /// In en, this message translates to:
  /// **'get ready for bed'**
  String get anchorBed;

  /// No description provided for @notificationsUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Reminders aren\'t available in the web version. Install the app on your phone or computer to get them.'**
  String get notificationsUnsupported;

  /// No description provided for @notificationsDenied.
  ///
  /// In en, this message translates to:
  /// **'Notifications are turned off for this app in your device settings.'**
  String get notificationsDenied;

  /// No description provided for @primingTitle.
  ///
  /// In en, this message translates to:
  /// **'Want a gentle daily nudge?'**
  String get primingTitle;

  /// No description provided for @primingBody.
  ///
  /// In en, this message translates to:
  /// **'At {time}. Never on Shabbat or Yom Tov, and at most one a day. Change it anytime.'**
  String primingBody(String time);

  /// No description provided for @primingYes.
  ///
  /// In en, this message translates to:
  /// **'Yes, remind me'**
  String get primingYes;

  /// No description provided for @notifChannelDaily.
  ///
  /// In en, this message translates to:
  /// **'Daily reading'**
  String get notifChannelDaily;

  /// No description provided for @notifChannelFriday.
  ///
  /// In en, this message translates to:
  /// **'Erev Shabbat'**
  String get notifChannelFriday;

  /// No description provided for @notifChannelCheckIn.
  ///
  /// In en, this message translates to:
  /// **'After Shabbat'**
  String get notifChannelCheckIn;

  /// No description provided for @notifDailyTitle.
  ///
  /// In en, this message translates to:
  /// **'Today: {aliyah}'**
  String notifDailyTitle(String aliyah);

  /// No description provided for @notifDailyBody.
  ///
  /// In en, this message translates to:
  /// **'Parshat {parsha} · {verses}'**
  String notifDailyBody(String parsha, String verses);

  /// No description provided for @notifFridayTitle.
  ///
  /// In en, this message translates to:
  /// **'Erev Shabbat · Parshat {parsha}'**
  String notifFridayTitle(String parsha);

  /// No description provided for @notifFridayBody.
  ///
  /// In en, this message translates to:
  /// **'If you haven\'t finished, there\'s still time — or finish Shabbat morning from your Chumash and log it after Shabbat.'**
  String get notifFridayBody;

  /// No description provided for @notifCheckInTitle.
  ///
  /// In en, this message translates to:
  /// **'Shavua tov!'**
  String get notifCheckInTitle;

  /// No description provided for @notifCheckInBody.
  ///
  /// In en, this message translates to:
  /// **'Did you read on Shabbat? Tap to log it.'**
  String get notifCheckInBody;

  /// No description provided for @showStreaks.
  ///
  /// In en, this message translates to:
  /// **'Show streak numbers'**
  String get showStreaks;

  /// No description provided for @showStreaksDesc.
  ///
  /// In en, this message translates to:
  /// **'Hide them if you\'d rather focus on the learning itself'**
  String get showStreaksDesc;

  /// No description provided for @exportData.
  ///
  /// In en, this message translates to:
  /// **'Export my progress'**
  String get exportData;

  /// No description provided for @exportDataDesc.
  ///
  /// In en, this message translates to:
  /// **'Save a backup you can restore later'**
  String get exportDataDesc;

  /// No description provided for @importData.
  ///
  /// In en, this message translates to:
  /// **'Import progress'**
  String get importData;

  /// No description provided for @importDataDesc.
  ///
  /// In en, this message translates to:
  /// **'Restore from a backup'**
  String get importDataDesc;

  /// No description provided for @importPrompt.
  ///
  /// In en, this message translates to:
  /// **'Paste the contents of your backup file.'**
  String get importPrompt;

  /// No description provided for @importSuccess.
  ///
  /// In en, this message translates to:
  /// **'Progress imported.'**
  String get importSuccess;

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'That backup couldn\'t be read.'**
  String get importFailed;

  /// No description provided for @exportCopied.
  ///
  /// In en, this message translates to:
  /// **'Backup copied to the clipboard.'**
  String get exportCopied;

  /// No description provided for @resetProgress.
  ///
  /// In en, this message translates to:
  /// **'Reset all progress'**
  String get resetProgress;

  /// No description provided for @resetProgressConfirm.
  ///
  /// In en, this message translates to:
  /// **'This erases your reading history and streaks on this device. It can\'t be undone.'**
  String get resetProgressConfirm;

  /// No description provided for @resetDone.
  ///
  /// In en, this message translates to:
  /// **'Progress reset.'**
  String get resetDone;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'Device language'**
  String get languageSystem;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageHebrew.
  ///
  /// In en, this message translates to:
  /// **'עברית'**
  String get languageHebrew;

  /// No description provided for @aboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get aboutTitle;

  /// No description provided for @versionLabel.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String versionLabel(String version);

  /// No description provided for @sourcesTitle.
  ///
  /// In en, this message translates to:
  /// **'Texts & sources'**
  String get sourcesTitle;

  /// No description provided for @licensesTitle.
  ///
  /// In en, this message translates to:
  /// **'Open-source licenses'**
  String get licensesTitle;

  /// No description provided for @privacyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy'**
  String get privacyTitle;

  /// No description provided for @termsTitle.
  ///
  /// In en, this message translates to:
  /// **'Terms of use'**
  String get termsTitle;

  /// No description provided for @guidelinesTitle.
  ///
  /// In en, this message translates to:
  /// **'Community guidelines'**
  String get guidelinesTitle;

  /// No description provided for @contactTitle.
  ///
  /// In en, this message translates to:
  /// **'Contact us'**
  String get contactTitle;

  /// No description provided for @guideTitle.
  ///
  /// In en, this message translates to:
  /// **'About Shnayim Mikra'**
  String get guideTitle;

  /// No description provided for @disclaimer.
  ///
  /// In en, this message translates to:
  /// **'Customs vary. For practical questions, ask your rav.'**
  String get disclaimer;

  /// No description provided for @onbWelcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Read the parsha twice and the Targum once — one aliyah a day, done before Shabbat.'**
  String get onbWelcomeBody;

  /// No description provided for @onbStart.
  ///
  /// In en, this message translates to:
  /// **'Start this week\'s parsha'**
  String get onbStart;

  /// No description provided for @onbLocationTitle.
  ///
  /// In en, this message translates to:
  /// **'Where will you be this Shabbat?'**
  String get onbLocationTitle;

  /// No description provided for @onbMethodTitle.
  ///
  /// In en, this message translates to:
  /// **'How do you read?'**
  String get onbMethodTitle;

  /// No description provided for @onbPlanTitle.
  ///
  /// In en, this message translates to:
  /// **'Your plan this week'**
  String get onbPlanTitle;

  /// No description provided for @onbHonor.
  ///
  /// In en, this message translates to:
  /// **'Shnayim Mikra runs on the honor system. Log what you read, wherever you read it — a Chumash in shul counts just as much as this app.'**
  String get onbHonor;

  /// No description provided for @onbChangeAnytime.
  ///
  /// In en, this message translates to:
  /// **'You can change this anytime in Settings.'**
  String get onbChangeAnytime;

  /// No description provided for @onbStep.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}'**
  String onbStep(int current, int total);

  /// No description provided for @onbWhyAsk.
  ///
  /// In en, this message translates to:
  /// **'Why we ask'**
  String get onbWhyAsk;

  /// No description provided for @guideWhatTitle.
  ///
  /// In en, this message translates to:
  /// **'What is Shnayim Mikra?'**
  String get guideWhatTitle;

  /// No description provided for @guideWhatBody.
  ///
  /// In en, this message translates to:
  /// **'The Talmud (Berakhot 8a) teaches that a person should complete the weekly Torah portion together with the community: the Torah text twice and the Targum once. The Shulchan Aruch codifies this in Orach Chaim 285. It completes, privately, the portion the community reads publicly on Shabbat.'**
  String get guideWhatBody;

  /// No description provided for @guideWhenTitle.
  ///
  /// In en, this message translates to:
  /// **'When'**
  String get guideWhenTitle;

  /// No description provided for @guideWhenBody.
  ///
  /// In en, this message translates to:
  /// **'You may begin on Sunday (some say from Shabbat afternoon, after the community reads the next portion at Mincha). Ideally finish before the Shabbat meal. If not, it may still be completed until Tuesday night (\"until Wednesday\", SA 285:4), and missed portions may be made up until Simchat Torah.'**
  String get guideWhenBody;

  /// No description provided for @guideHowTitle.
  ///
  /// In en, this message translates to:
  /// **'How'**
  String get guideHowTitle;

  /// No description provided for @guideHowBody.
  ///
  /// In en, this message translates to:
  /// **'Read verse by verse — each verse twice and then its Targum — or section by section, reading each paragraph twice and then its Targum. Many repeat the final verse in Hebrew so as to end with the Torah text. If you can, read aloud and with the cantillation.'**
  String get guideHowBody;

  /// No description provided for @guideTargumTitle.
  ///
  /// In en, this message translates to:
  /// **'Targum or Rashi'**
  String get guideTargumTitle;

  /// No description provided for @guideTargumBody.
  ///
  /// In en, this message translates to:
  /// **'Rashi\'s commentary may take the place of the Targum, since it explains the text; a God-fearing person reads both (SA 285:2). A plain translation is a helpful study aid but is not a substitute for the Targum.'**
  String get guideTargumBody;

  /// No description provided for @guideSpecialTitle.
  ///
  /// In en, this message translates to:
  /// **'Special cases'**
  String get guideSpecialTitle;

  /// No description provided for @guideSpecialBody.
  ///
  /// In en, this message translates to:
  /// **'Some verses have no separate Targum, such as \"Atarot v\'Divon\" (Numbers 32:3); many read them a third time in Hebrew. Vezot HaBerakhah is read before Simchat Torah, ideally on Hoshana Rabbah. Many also read the week\'s haftarah once.'**
  String get guideSpecialBody;

  /// No description provided for @guideShabbatTitle.
  ///
  /// In en, this message translates to:
  /// **'Shabbat and Yom Tov'**
  String get guideShabbatTitle;

  /// No description provided for @guideShabbatBody.
  ///
  /// In en, this message translates to:
  /// **'This app never asks you to open it on Shabbat or Yom Tov. Streaks pause on those days, reminders are never sent, and reading you do from a printed Chumash can be logged afterwards.'**
  String get guideShabbatBody;

  /// No description provided for @guideSourcesTitle.
  ///
  /// In en, this message translates to:
  /// **'Sources'**
  String get guideSourcesTitle;

  /// No description provided for @guideSourcesBody.
  ///
  /// In en, this message translates to:
  /// **'Berakhot 8a–b · Shulchan Aruch, Orach Chaim 285 · Mishnah Berurah 285 · Kitzur Shulchan Aruch 72 · Shulchan Aruch HaRav 285'**
  String get guideSourcesBody;

  /// No description provided for @hebrewDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Hebrew date: {date}'**
  String hebrewDateLabel(String date);

  /// No description provided for @bookOfTorah.
  ///
  /// In en, this message translates to:
  /// **'Sefer {book}'**
  String bookOfTorah(String book);

  /// No description provided for @communityTitle.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get communityTitle;

  /// No description provided for @demoModeBanner.
  ///
  /// In en, this message translates to:
  /// **'Demo mode: posts stay on this device and reset when the app restarts.'**
  String get demoModeBanner;

  /// No description provided for @forumsHeading.
  ///
  /// In en, this message translates to:
  /// **'Forums'**
  String get forumsHeading;

  /// No description provided for @thisWeeksThread.
  ///
  /// In en, this message translates to:
  /// **'This week: Parshat {name}'**
  String thisWeeksThread(String name);

  /// No description provided for @weeklyThreadTitle.
  ///
  /// In en, this message translates to:
  /// **'Parshat {name} {year}'**
  String weeklyThreadTitle(String name, String year);

  /// No description provided for @openDiscussion.
  ///
  /// In en, this message translates to:
  /// **'Open the discussion'**
  String get openDiscussion;

  /// No description provided for @signInPrompt.
  ///
  /// In en, this message translates to:
  /// **'Sign in to post, say thanks or report.'**
  String get signInPrompt;

  /// No description provided for @signInTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInTitle;

  /// No description provided for @signInBody.
  ///
  /// In en, this message translates to:
  /// **'We\'ll email you a 6-digit code — no password needed.'**
  String get signInBody;

  /// No description provided for @emailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get emailLabel;

  /// No description provided for @sendCodeAction.
  ///
  /// In en, this message translates to:
  /// **'Email me a code'**
  String get sendCodeAction;

  /// No description provided for @codeSentTo.
  ///
  /// In en, this message translates to:
  /// **'We sent a 6-digit code to {email}.'**
  String codeSentTo(String email);

  /// No description provided for @codeLabel.
  ///
  /// In en, this message translates to:
  /// **'6-digit code'**
  String get codeLabel;

  /// No description provided for @verifyAction.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get verifyAction;

  /// No description provided for @useDifferentEmail.
  ///
  /// In en, this message translates to:
  /// **'Use a different email'**
  String get useDifferentEmail;

  /// No description provided for @demoCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Demo mode: any 6 digits will work.'**
  String get demoCodeHint;

  /// No description provided for @signedInAs.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {name}'**
  String signedInAs(String name);

  /// No description provided for @displayNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Display name'**
  String get displayNameLabel;

  /// No description provided for @displayNameHelp.
  ///
  /// In en, this message translates to:
  /// **'Shown with your posts. 2–40 characters.'**
  String get displayNameHelp;

  /// No description provided for @saveName.
  ///
  /// In en, this message translates to:
  /// **'Save name'**
  String get saveName;

  /// No description provided for @nameSaved.
  ///
  /// In en, this message translates to:
  /// **'Name saved.'**
  String get nameSaved;

  /// No description provided for @syncProgress.
  ///
  /// In en, this message translates to:
  /// **'Back up my progress'**
  String get syncProgress;

  /// No description provided for @syncProgressDesc.
  ///
  /// In en, this message translates to:
  /// **'Keep your reading progress with your account and restore it on other devices.'**
  String get syncProgressDesc;

  /// No description provided for @syncNow.
  ///
  /// In en, this message translates to:
  /// **'Sync now'**
  String get syncNow;

  /// No description provided for @syncDone.
  ///
  /// In en, this message translates to:
  /// **'Progress synced.'**
  String get syncDone;

  /// No description provided for @syncFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t sync right now. We\'ll try again later.'**
  String get syncFailed;

  /// No description provided for @lastSynced.
  ///
  /// In en, this message translates to:
  /// **'Last synced {time}'**
  String lastSynced(String time);

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete my account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountConfirm.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes your account, your profile and everything you\'ve posted. Your reading progress on this device is kept. This can\'t be undone.'**
  String get deleteAccountConfirm;

  /// No description provided for @accountDeleted.
  ///
  /// In en, this message translates to:
  /// **'Your account was deleted.'**
  String get accountDeleted;

  /// No description provided for @newThread.
  ///
  /// In en, this message translates to:
  /// **'New discussion'**
  String get newThread;

  /// No description provided for @threadTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get threadTitleLabel;

  /// No description provided for @threadBodyLabel.
  ///
  /// In en, this message translates to:
  /// **'Your message'**
  String get threadBodyLabel;

  /// No description provided for @forumLabel.
  ///
  /// In en, this message translates to:
  /// **'Forum'**
  String get forumLabel;

  /// No description provided for @postAction.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get postAction;

  /// No description provided for @replyLabel.
  ///
  /// In en, this message translates to:
  /// **'Write a reply'**
  String get replyLabel;

  /// No description provided for @replyAction.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get replyAction;

  /// No description provided for @replyingTo.
  ///
  /// In en, this message translates to:
  /// **'Replying to {name}'**
  String replyingTo(String name);

  /// No description provided for @todahCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Say thanks} =1{1 thanks} other{{count} thanks}}'**
  String todahCount(int count);

  /// No description provided for @todahSemantics.
  ///
  /// In en, this message translates to:
  /// **'Say thanks to {name}'**
  String todahSemantics(String name);

  /// No description provided for @reportTitle.
  ///
  /// In en, this message translates to:
  /// **'Report this post'**
  String get reportTitle;

  /// No description provided for @reportReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'What\'s wrong?'**
  String get reportReasonLabel;

  /// No description provided for @reasonSpam.
  ///
  /// In en, this message translates to:
  /// **'Spam or advertising'**
  String get reasonSpam;

  /// No description provided for @reasonLashonHara.
  ///
  /// In en, this message translates to:
  /// **'Lashon hara or gossip'**
  String get reasonLashonHara;

  /// No description provided for @reasonDisrespect.
  ///
  /// In en, this message translates to:
  /// **'Disrespectful or abusive'**
  String get reasonDisrespect;

  /// No description provided for @reasonMisinformation.
  ///
  /// In en, this message translates to:
  /// **'Misleading about halacha or sources'**
  String get reasonMisinformation;

  /// No description provided for @reasonOffTopic.
  ///
  /// In en, this message translates to:
  /// **'Off topic'**
  String get reasonOffTopic;

  /// No description provided for @reasonOther.
  ///
  /// In en, this message translates to:
  /// **'Something else'**
  String get reasonOther;

  /// No description provided for @reportDetails.
  ///
  /// In en, this message translates to:
  /// **'Details (optional)'**
  String get reportDetails;

  /// No description provided for @reportSent.
  ///
  /// In en, this message translates to:
  /// **'Thank you. A moderator will review it.'**
  String get reportSent;

  /// No description provided for @blockUser.
  ///
  /// In en, this message translates to:
  /// **'Block {name}'**
  String blockUser(String name);

  /// No description provided for @blockConfirm.
  ///
  /// In en, this message translates to:
  /// **'You won\'t see posts from {name}. They won\'t be notified.'**
  String blockConfirm(String name);

  /// No description provided for @blockedDone.
  ///
  /// In en, this message translates to:
  /// **'Blocked.'**
  String get blockedDone;

  /// No description provided for @unblock.
  ///
  /// In en, this message translates to:
  /// **'Unblock'**
  String get unblock;

  /// No description provided for @blockedUsersTitle.
  ///
  /// In en, this message translates to:
  /// **'Blocked members'**
  String get blockedUsersTitle;

  /// No description provided for @edited.
  ///
  /// In en, this message translates to:
  /// **'edited'**
  String get edited;

  /// No description provided for @editPostTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit post'**
  String get editPostTitle;

  /// No description provided for @deletePostConfirm.
  ///
  /// In en, this message translates to:
  /// **'Delete this post?'**
  String get deletePostConfirm;

  /// No description provided for @postDeleted.
  ///
  /// In en, this message translates to:
  /// **'Post deleted.'**
  String get postDeleted;

  /// No description provided for @posted.
  ///
  /// In en, this message translates to:
  /// **'Posted.'**
  String get posted;

  /// No description provided for @pendingReview.
  ///
  /// In en, this message translates to:
  /// **'Hidden — waiting for a moderator'**
  String get pendingReview;

  /// No description provided for @lockedThread.
  ///
  /// In en, this message translates to:
  /// **'This discussion is locked.'**
  String get lockedThread;

  /// No description provided for @pinnedLabel.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get pinnedLabel;

  /// No description provided for @lockedLabel.
  ///
  /// In en, this message translates to:
  /// **'Locked'**
  String get lockedLabel;

  /// No description provided for @lockThread.
  ///
  /// In en, this message translates to:
  /// **'Lock discussion'**
  String get lockThread;

  /// No description provided for @unlockThread.
  ///
  /// In en, this message translates to:
  /// **'Unlock discussion'**
  String get unlockThread;

  /// No description provided for @pinThread.
  ///
  /// In en, this message translates to:
  /// **'Pin to top'**
  String get pinThread;

  /// No description provided for @unpinThread.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get unpinThread;

  /// No description provided for @hidePost.
  ///
  /// In en, this message translates to:
  /// **'Hide post'**
  String get hidePost;

  /// No description provided for @moderationQueue.
  ///
  /// In en, this message translates to:
  /// **'Reports to review'**
  String get moderationQueue;

  /// No description provided for @noReports.
  ///
  /// In en, this message translates to:
  /// **'No open reports.'**
  String get noReports;

  /// No description provided for @removePost.
  ///
  /// In en, this message translates to:
  /// **'Remove post'**
  String get removePost;

  /// No description provided for @dismissReport.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get dismissReport;

  /// No description provided for @guidelinesAccept.
  ///
  /// In en, this message translates to:
  /// **'I\'ll follow the community guidelines'**
  String get guidelinesAccept;

  /// No description provided for @guidelinesPrompt.
  ///
  /// In en, this message translates to:
  /// **'Before your first post, please read the community guidelines.'**
  String get guidelinesPrompt;

  /// No description provided for @readGuidelines.
  ///
  /// In en, this message translates to:
  /// **'Read the guidelines'**
  String get readGuidelines;

  /// No description provided for @noThreads.
  ///
  /// In en, this message translates to:
  /// **'No discussions yet. Start the first one!'**
  String get noThreads;

  /// No description provided for @loadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get loadMore;

  /// No description provided for @postsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No posts yet} =1{1 post} other{{count} posts}}'**
  String postsCount(int count);

  /// No description provided for @timeJustNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get timeJustNow;

  /// No description provided for @timeMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 minute ago} other{{count} minutes ago}}'**
  String timeMinutesAgo(int count);

  /// No description provided for @timeHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 hour ago} other{{count} hours ago}}'**
  String timeHoursAgo(int count);

  /// No description provided for @postedBy.
  ///
  /// In en, this message translates to:
  /// **'{name}, {time}'**
  String postedBy(String name, String time);

  /// No description provided for @anonymousMember.
  ///
  /// In en, this message translates to:
  /// **'Former member'**
  String get anonymousMember;

  /// No description provided for @errRateLimited.
  ///
  /// In en, this message translates to:
  /// **'You\'re posting quickly — please wait a few seconds.'**
  String get errRateLimited;

  /// No description provided for @errThreadLocked.
  ///
  /// In en, this message translates to:
  /// **'This discussion is locked.'**
  String get errThreadLocked;

  /// No description provided for @errTerms.
  ///
  /// In en, this message translates to:
  /// **'Please accept the community guidelines first.'**
  String get errTerms;

  /// No description provided for @errBanned.
  ///
  /// In en, this message translates to:
  /// **'Your account can\'t post.'**
  String get errBanned;

  /// No description provided for @errSilenced.
  ///
  /// In en, this message translates to:
  /// **'Posting is paused for your account for now.'**
  String get errSilenced;

  /// No description provided for @errContent.
  ///
  /// In en, this message translates to:
  /// **'That message can\'t be posted. Please review the community guidelines.'**
  String get errContent;

  /// No description provided for @errDuplicate.
  ///
  /// In en, this message translates to:
  /// **'You already posted that.'**
  String get errDuplicate;

  /// No description provided for @errLinks.
  ///
  /// In en, this message translates to:
  /// **'New members can include at most 2 links.'**
  String get errLinks;

  /// No description provided for @errDailyLimit.
  ///
  /// In en, this message translates to:
  /// **'New members can post a limited amount each day. Please try again tomorrow.'**
  String get errDailyLimit;

  /// No description provided for @errNameTaken.
  ///
  /// In en, this message translates to:
  /// **'That name is taken.'**
  String get errNameTaken;

  /// No description provided for @errInvalidName.
  ///
  /// In en, this message translates to:
  /// **'Names must be 2–40 characters.'**
  String get errInvalidName;

  /// No description provided for @errInvalidCode.
  ///
  /// In en, this message translates to:
  /// **'That code didn\'t work. Check it and try again.'**
  String get errInvalidCode;

  /// No description provided for @errInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid email address.'**
  String get errInvalidEmail;

  /// No description provided for @errNotSignedIn.
  ///
  /// In en, this message translates to:
  /// **'Please sign in first.'**
  String get errNotSignedIn;

  /// No description provided for @errForbidden.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have permission to do that.'**
  String get errForbidden;

  /// No description provided for @errShabbat.
  ///
  /// In en, this message translates to:
  /// **'Posting is closed for Shabbat.'**
  String get errShabbat;

  /// No description provided for @errTooShort.
  ///
  /// In en, this message translates to:
  /// **'Please write a little more.'**
  String get errTooShort;

  /// No description provided for @errTitleTooShort.
  ///
  /// In en, this message translates to:
  /// **'The title needs at least 5 characters.'**
  String get errTitleTooShort;

  /// No description provided for @errNetwork.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach the server. Check your connection and try again.'**
  String get errNetwork;

  /// No description provided for @moderatorBadge.
  ///
  /// In en, this message translates to:
  /// **'Moderator'**
  String get moderatorBadge;

  /// No description provided for @draftRestored.
  ///
  /// In en, this message translates to:
  /// **'Your draft was restored.'**
  String get draftRestored;

  /// No description provided for @discardDraft.
  ///
  /// In en, this message translates to:
  /// **'Discard draft'**
  String get discardDraft;

  /// No description provided for @charactersLeft.
  ///
  /// In en, this message translates to:
  /// **'{count} characters left'**
  String charactersLeft(int count);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'he'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'he':
      return AppLocalizationsHe();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
