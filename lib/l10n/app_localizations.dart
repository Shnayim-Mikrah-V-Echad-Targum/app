// ignore_for_file: text_direction_code_point_in_literal
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
  /// **'Shnayim Mikrah'**
  String get appTitle;

  /// No description provided for @appTitleFull.
  ///
  /// In en, this message translates to:
  /// **'Shnayim Mikrah v’Echad Targum'**
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

  /// No description provided for @actionClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get actionClear;

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

  /// No description provided for @moreOptionsFor.
  ///
  /// In en, this message translates to:
  /// **'More options for {name}'**
  String moreOptionsFor(String name);

  /// No description provided for @actionRefresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get actionRefresh;

  /// No description provided for @refreshed.
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get refreshed;

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

  /// No description provided for @notFoundTitle.
  ///
  /// In en, this message translates to:
  /// **'Page not found'**
  String get notFoundTitle;

  /// No description provided for @notFoundBody.
  ///
  /// In en, this message translates to:
  /// **'This link leads nowhere in the app.'**
  String get notFoundBody;

  /// No description provided for @goToToday.
  ///
  /// In en, this message translates to:
  /// **'Go to Today'**
  String get goToToday;

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
  /// **'Revi’i'**
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
  /// **'Shevi’i'**
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

  /// No description provided for @passMikrah1.
  ///
  /// In en, this message translates to:
  /// **'First reading'**
  String get passMikrah1;

  /// No description provided for @passMikrah2.
  ///
  /// In en, this message translates to:
  /// **'Second reading'**
  String get passMikrah2;

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

  /// No description provided for @countOfTotal.
  ///
  /// In en, this message translates to:
  /// **'{count} of {total}'**
  String countOfTotal(int count, int total);

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

  /// On Today, in place of shabbatInDays on the eve of Shabbat or Yom Tov, when a city is chosen for Shabbat times: when candles are lit there today. time is a time of day, such as 4:12 PM.
  ///
  /// In en, this message translates to:
  /// **'Candle-lighting {time}'**
  String todayCandleLighting(String time);

  /// No description provided for @parshaLabel.
  ///
  /// In en, this message translates to:
  /// **'Parshat {name}'**
  String parshaLabel(String name);

  /// The eyebrow over the parsha's name in the Today hero, on most days.
  ///
  /// In en, this message translates to:
  /// **'Parshat HaShavua'**
  String get parshatHashavua;

  /// The eyebrow over the parsha's name in the Today hero on Friday afternoon.
  ///
  /// In en, this message translates to:
  /// **'Erev Shabbat'**
  String get erevShabbat;

  /// The eyebrow over the parsha's name in the Today hero on the afternoon before a Yom Tov that is not Shabbat, as erevShabbat on Friday. holiday is roshHashanah, yomKippur or other.
  ///
  /// In en, this message translates to:
  /// **'{holiday, select, roshHashanah{Erev Rosh Hashanah} yomKippur{Erev Yom Kippur} other{Erev Yom Tov}}'**
  String erevYomTov(String holiday);

  /// The greeting on Today's title page on Shabbat.
  ///
  /// In en, this message translates to:
  /// **'Shabbat Shalom'**
  String get shabbatShalom;

  /// The greeting on Today's title page on the festivals' days of Yom Tov (Pesach, Shavuot, Sukkot, Shemini Atzeret).
  ///
  /// In en, this message translates to:
  /// **'Chag Sameach'**
  String get chagSameach;

  /// The greeting on Today's title page on Rosh Hashanah, for a good year.
  ///
  /// In en, this message translates to:
  /// **'Shanah Tovah'**
  String get shanaTova;

  /// The greeting on Today's title page on Yom Kippur, a solemn fast day: 'a good final sealing'.
  ///
  /// In en, this message translates to:
  /// **'G’mar Chatimah Tovah'**
  String get gmarChatimaTova;

  /// On Today's title page on Shabbat, under the parsha's name.
  ///
  /// In en, this message translates to:
  /// **'Reading from a printed Chumash today? You can log it after Shabbat.'**
  String get restDayBody;

  /// As restDayBody, on Shabbat or Yom Tov when the days of rest end with Yom Tov.
  ///
  /// In en, this message translates to:
  /// **'Reading from a printed Chumash today? You can log it after Yom Tov.'**
  String get restDayBodyChag;

  /// As restDayBody, on Yom Kippur, which is not called Yom Tov.
  ///
  /// In en, this message translates to:
  /// **'Reading from a printed Chumash today? You can log it after Yom Kippur.'**
  String get restDayBodyYomKippur;

  /// The one button on Today on Shabbat or Yom Tov, which opens the parsha's week.
  ///
  /// In en, this message translates to:
  /// **'Open the parsha'**
  String get openTheParsha;

  /// The eyebrow over the parsha's name in the Today hero in the week of Vezot HaBerachah, which is read on Simchat Torah.
  ///
  /// In en, this message translates to:
  /// **'Simchat Torah'**
  String get simchatTorahEyebrow;

  /// In the Today hero on Friday, in place of the countdown to Shabbat (shabbatInDays).
  ///
  /// In en, this message translates to:
  /// **'Shabbat begins this evening'**
  String get shabbatBeginsTonight;

  /// In the Today hero on the day before a Yom Tov that is not Shabbat, in place of the countdown to Shabbat (shabbatInDays), as shabbatBeginsTonight on Friday. holiday is roshHashanah, yomKippur or other.
  ///
  /// In en, this message translates to:
  /// **'{holiday, select, roshHashanah{Rosh Hashanah begins this evening} yomKippur{Yom Kippur begins this evening} other{Yom Tov begins this evening}}'**
  String yomTovBeginsTonight(String holiday);

  /// A link under the rings in the Today hero to the week's page, which lists its seven aliyot.
  ///
  /// In en, this message translates to:
  /// **'All aliyot'**
  String get allAliyot;

  /// The Today hero's button when nothing of the week is read yet. aliyah is the aliyah it opens, such as Rishon.
  ///
  /// In en, this message translates to:
  /// **'Start · {aliyah}'**
  String startAt(String aliyah);

  /// The Today hero's button: aliyah is the first aliyah not yet read, such as Shlishi.
  ///
  /// In en, this message translates to:
  /// **'Continue · {aliyah}'**
  String continueAt(String aliyah);

  /// The Today hero's button when some readings of the next aliyah are done: pass is the reading it resumes at, such as Targum.
  ///
  /// In en, this message translates to:
  /// **'Continue · {aliyah}, {pass}'**
  String continueAtPass(String aliyah, String pass);

  /// A button on Today's reading card that opens the aliyah named, such as Shishi.
  ///
  /// In en, this message translates to:
  /// **'Read {aliyah}'**
  String readAliyah(String aliyah);

  /// No description provided for @todayReadingTitle.
  ///
  /// In en, this message translates to:
  /// **'Today’s reading'**
  String get todayReadingTitle;

  /// No description provided for @todayDone.
  ///
  /// In en, this message translates to:
  /// **'Today’s reading is done'**
  String get todayDone;

  /// No description provided for @todayAhead.
  ///
  /// In en, this message translates to:
  /// **'You’re ahead of plan. Well done!'**
  String get todayAhead;

  /// Under Today's week strip, once, after grace days covered planned days without reading. count is how many grace days, weekdays those days as a list ('Monday and Tuesday'); parsha this week's.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{weekdays} was covered by a grace day — your rhythm continues. You’ll earn one back when you finish {parsha} by Shabbat.} other{{weekdays} were covered by grace days — your rhythm continues. You’ll earn one back when you finish {parsha} by Shabbat.}}'**
  String graceUsedNote(int count, String weekdays, String parsha);

  /// As graceUsedNote, when finishing this week's parsha would not earn a grace day back (it is finished, or none is missing).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{weekdays} was covered by a grace day — your rhythm continues.} other{{weekdays} were covered by grace days — your rhythm continues.}}'**
  String graceUsedNoteShort(int count, String weekdays);

  /// Under Today's week strip when reading two days' aliyot today has made up for yesterday. It says what happened in plain words, as the rescue of a missed parsha is named, with no word for doubling up.
  ///
  /// In en, this message translates to:
  /// **'Caught up — today’s reading made up for yesterday.'**
  String get caughtUpNote;

  /// No description provided for @todayNothingPlanned.
  ///
  /// In en, this message translates to:
  /// **'No reading is planned for today. A good day to catch up or read ahead.'**
  String get todayNothingPlanned;

  /// The eyebrow of Today's reading card while aliyot planned for earlier days are still to read.
  ///
  /// In en, this message translates to:
  /// **'Catching up'**
  String get todayCatchUpTitle;

  /// No description provided for @aliyotCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 aliyah} other{{count} aliyot}}'**
  String aliyotCount(int count);

  /// All seven aliyot, where the aliyot of a day are named: on Today's reading card when a day's reading is the whole parsha, or all of it is still to catch up, and on the home-screen widget ("Today: The whole parsha").
  ///
  /// In en, this message translates to:
  /// **'The whole parsha'**
  String get aliyotWholeParsha;

  /// On Today's reading card, under the aliyot to catch up, from Sunday to Wednesday. count is every aliyah the card names: those planned up to today and not yet read, today's included.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{One aliyah to catch up — very normal midweek.} other{{count} aliyot to catch up — very normal midweek.}}'**
  String todayBehind(int count);

  /// As todayBehind, on Thursday, when Thursday and Friday are left for reading before Shabbat. count is every aliyah planned up to today and not yet read.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{One aliyah to catch up — and there are still two days before Shabbat.} other{{count} aliyot to catch up — and there are still two days before Shabbat.}}'**
  String todayBehindThursday(int count);

  /// As todayBehind, on Erev Shabbat. count is every aliyah planned up to today and not yet read.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{One aliyah left to read before Shabbat — or finish Shabbat morning from a Chumash and log it after Shabbat.} other{{count} aliyot left to read before Shabbat — or finish Shabbat morning from a Chumash and log it after Shabbat.}}'**
  String todayLastDayShabbat(int count);

  /// As todayBehind, on Erev Yom Tov. count is every aliyah planned up to today and not yet read.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{One aliyah left to read before Yom Tov — or finish on Yom Tov from a Chumash and log it after Yom Tov.} other{{count} aliyot left to read before Yom Tov — or finish on Yom Tov from a Chumash and log it after Yom Tov.}}'**
  String todayLastDayYomTov(int count);

  /// As todayLastDayShabbat, on an Erev Shabbat whose Shabbat runs straight into Yom Tov, so that reading done then is logged once Yom Tov is over. count is every aliyah planned up to today and not yet read.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{One aliyah left to read before Shabbat — or finish Shabbat morning from a Chumash and log it after Yom Tov.} other{{count} aliyot left to read before Shabbat — or finish Shabbat morning from a Chumash and log it after Yom Tov.}}'**
  String todayLastDayShabbatThenYomTov(int count);

  /// As todayLastDayYomTov, on an Erev Yom Tov whose Yom Tov runs straight into Shabbat (Rosh Hashanah on Thursday and Friday, say), so that reading done then is logged once Shabbat is over. count is every aliyah planned up to today and not yet read.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{One aliyah left to read before Yom Tov — or finish on Yom Tov or Shabbat from a Chumash and log it after Shabbat.} other{{count} aliyot left to read before Yom Tov — or finish on Yom Tov or Shabbat from a Chumash and log it after Shabbat.}}'**
  String todayLastDayYomTovThenShabbat(int count);

  /// As todayBehind, on the day before Yom Kippur, which is never the last reading day of a week. count is every aliyah planned up to today and not yet read.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{One aliyah to catch up before Yom Kippur — and there is still time after it, too.} other{{count} aliyot to catch up before Yom Kippur — and there is still time after it, too.}}'**
  String todayLastDayYomKippur(int count);

  /// On Today's reading card while streaks are paused, in place of a line about aliyot to catch up.
  ///
  /// In en, this message translates to:
  /// **'Paused — read whenever you like; nothing counts against you.'**
  String get pausedTodayNote;

  /// On Today's reading card on the day before Tisha B'Av, when many have the custom not to learn Torah from midday.
  ///
  /// In en, this message translates to:
  /// **'Erev Tisha B’Av: many finish their learning before midday.'**
  String get erevTishaBavNote;

  /// No description provided for @startReading.
  ///
  /// In en, this message translates to:
  /// **'Start reading'**
  String get startReading;

  /// No description provided for @readFromBook.
  ///
  /// In en, this message translates to:
  /// **'I read it in a Chumash'**
  String get readFromBook;

  /// The title of the sheet that logs reading done from a printed Chumash, over the aliyot to log, each checked.
  ///
  /// In en, this message translates to:
  /// **'Which aliyot did you read?'**
  String get readFromBookTitle;

  /// No description provided for @weekComplete.
  ///
  /// In en, this message translates to:
  /// **'This week’s parsha is complete. Yasher koach!'**
  String get weekComplete;

  /// A gentle line under weekComplete on Today's title page, once every aliyah of the week is read.
  ///
  /// In en, this message translates to:
  /// **'Ready to hear it read on Shabbat.'**
  String get weekCompleteNote;

  /// As weekCompleteNote, for Vezot HaBerachah, which is read on Simchat Torah.
  ///
  /// In en, this message translates to:
  /// **'Ready to hear it read on Simchat Torah.'**
  String get weekCompleteNoteSimchatTorah;

  /// A text button on Today's title page, once the week is complete, that opens the week's discussion.
  ///
  /// In en, this message translates to:
  /// **'Discuss the parsha'**
  String get discussTheParsha;

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

  /// On Today's notice that last week's parsha is still open, within its late window: when its last day is. when is today, tomorrow or other; date is that day, with its weekday (a Hebrew date in the Hebrew UI), used only for other.
  ///
  /// In en, this message translates to:
  /// **'{when, select, today{Finish by tonight and it still counts.} tomorrow{Finish by tomorrow night and it still counts.} other{Finish by the end of {date}, and it still counts.}}'**
  String openWeekLate(String when, String date);

  /// In place of openWeekLate when the late window's last reading day is the eve of Shabbat or Yom Tov (as when Yom Tov falls on the window's last day), so that it closes as that day of rest begins, not at night. holiday is shabbat, roshHashanah, yomKippur or other (a Yom Tov); when is today, tomorrow or other; date is that day, with its weekday (a Hebrew date in the Hebrew UI), used only for other.
  ///
  /// In en, this message translates to:
  /// **'Finish before {holiday, select, shabbat{Shabbat} roshHashanah{Rosh Hashanah} yomKippur{Yom Kippur} other{Yom Tov}} begins {when, select, today{this evening and it still counts.} tomorrow{tomorrow evening and it still counts.} other{on {date}, and it still counts.}}'**
  String openWeekLateEve(String holiday, String when, String date);

  /// On Today's notice that last week's parsha is still open, after its late window. name is last week's parsha, next this week's, and count the reader's parsha streak, at least 1. A no-break space keeps the last two words together, so neither is left alone on a line.
  ///
  /// In en, this message translates to:
  /// **'Finish {name} and {next} by Shabbat and your {count}-week streak continues — you can do this once in each book of the Torah.'**
  String openWeekRestore(String name, String next, int count);

  /// As openWeekRestore, when the reader has no parsha streak to continue.
  ///
  /// In en, this message translates to:
  /// **'Finish {name} and {next} by Shabbat and both count — you can do this once in each book of the Torah.'**
  String openWeekRestoreZero(String name, String next);

  /// No description provided for @openWeekHaftarahLeft.
  ///
  /// In en, this message translates to:
  /// **'Only the haftarah is left.'**
  String get openWeekHaftarahLeft;

  /// The button of the notice on Today that last week's parsha is still open: name is the parsha.
  ///
  /// In en, this message translates to:
  /// **'Open {name}'**
  String openWeekOpen(String name);

  /// A button that opens the week's haftarah.
  ///
  /// In en, this message translates to:
  /// **'Read the haftarah'**
  String get readTheHaftarah;

  /// The after-Shabbat check-in on Today, and the title of its sheet: asks whether the parsha of the Shabbat just past was read on it, from a printed Chumash. name is that parsha, or the two read together.
  ///
  /// In en, this message translates to:
  /// **'Shavua tov! Did you read {name} on Shabbat?'**
  String checkInTitle(String name);

  /// As checkInTitle, when the days of rest after that Shabbat ran on into Yom Tov (Shavuot on Sunday, say), on any of which the parsha may have been read.
  ///
  /// In en, this message translates to:
  /// **'Shavua tov! Did you read {name} over Shabbat and Yom Tov?'**
  String checkInTitleShabbatYomTov(String name);

  /// As checkInTitle, after Simchat Torah, the Yom Tov Vezot HaBerachah is read on: asks whether it was finished then, from a printed Chumash. name is Vezot HaBerachah, in the reader's style.
  ///
  /// In en, this message translates to:
  /// **'Did you finish {name} over Yom Tov?'**
  String checkInTitleVezot(String name);

  /// As checkInTitleVezot, for a reader to whom Simchat Torah, when Vezot HaBerachah was read, was not Yom Tov (one who keeps a single day of Yom Tov but hears the reading outside Israel, a day later). name is Vezot HaBerachah, in the reader's style.
  ///
  /// In en, this message translates to:
  /// **'Did you finish {name} on Simchat Torah?'**
  String checkInTitleSimchatTorah(String name);

  /// No description provided for @checkInBody.
  ///
  /// In en, this message translates to:
  /// **'Log what you read from a printed Chumash — it counts just the same.'**
  String get checkInBody;

  /// The after-Shabbat check-in's button that logs the whole of the Shabbat's parsha as read on it. name is that parsha, as in checkInTitle.
  ///
  /// In en, this message translates to:
  /// **'I finished {name} on Shabbat'**
  String checkInFinished(String name);

  /// As checkInFinished, after Simchat Torah: logs the whole of Vezot HaBerachah as read on that Yom Tov. name is Vezot HaBerachah, as in checkInTitleVezot. Yom Tov is held together by a no-break space, so that where large text wraps the label, Tov never stands alone on its last line.
  ///
  /// In en, this message translates to:
  /// **'I finished {name} on Yom Tov'**
  String checkInFinishedYomTov(String name);

  /// As checkInFinishedYomTov, under checkInTitleSimchatTorah: logs the whole of Vezot HaBerachah as read on Simchat Torah, which was not Yom Tov for the reader. name is Vezot HaBerachah.
  ///
  /// In en, this message translates to:
  /// **'I finished {name} on Simchat Torah'**
  String checkInFinishedSimchatTorah(String name);

  /// No description provided for @checkInPick.
  ///
  /// In en, this message translates to:
  /// **'Choose aliyot'**
  String get checkInPick;

  /// A button of the after-Shabbat check-in on Today that puts it away without logging anything.
  ///
  /// In en, this message translates to:
  /// **'Not this time'**
  String get checkInNotThisTime;

  /// In the after-Shabbat check-in sheet, the day the checked readings are logged for: the Shabbat just past. date is its day and month.
  ///
  /// In en, this message translates to:
  /// **'Read on Shabbat, {date}'**
  String checkInReadOnShabbat(String date);

  /// As checkInReadOnShabbat, for a Yom Tov: Simchat Torah, for Vezot HaBerachah, or a day of Yom Tov chosen instead. date is its day and month.
  ///
  /// In en, this message translates to:
  /// **'Read on Yom Tov, {date}'**
  String checkInReadOnYomTov(String date);

  /// As checkInReadOnShabbat, once another day is chosen. date is its weekday, day and month.
  ///
  /// In en, this message translates to:
  /// **'Read on {date}'**
  String checkInReadOn(String date);

  /// A button beside the day reading is logged for, which asks for another.
  ///
  /// In en, this message translates to:
  /// **'Change date'**
  String get changeDate;

  /// The button of the after-Shabbat check-in sheet that logs every checked reading at once.
  ///
  /// In en, this message translates to:
  /// **'Log reading'**
  String get logReading;

  /// No description provided for @pausedBanner.
  ///
  /// In en, this message translates to:
  /// **'Paused until {date}. Nothing resets while paused.'**
  String pausedBanner(String date);

  /// Under Today's paused banner, and in the dialog Settings' pause row opens while a pause lasts: ends the pause now.
  ///
  /// In en, this message translates to:
  /// **'End pause'**
  String get resume;

  /// On Today, under pauseEnded, the first time it is opened after a pause has ended. date is the pause's last day.
  ///
  /// In en, this message translates to:
  /// **'Your pause ended on {date}, and nothing during it counts against you.'**
  String pauseEndedOn(String date);

  /// A button on Today's welcome back after a pause, when nothing of this week's parsha is read yet.
  ///
  /// In en, this message translates to:
  /// **'Start this week’s parsha'**
  String get pauseEndedStart;

  /// As pauseEndedStart, when some of this week's parsha is read.
  ///
  /// In en, this message translates to:
  /// **'Continue this week’s parsha'**
  String get pauseEndedContinue;

  /// A button on Today's welcome back after a pause, that opens last week's parsha, which can still count.
  ///
  /// In en, this message translates to:
  /// **'Catch up on {name}'**
  String catchUpOn(String name);

  /// The tooltip and label of a close button that puts a note away.
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get actionDismiss;

  /// Shown on Today when the reader hears Israel's reading but keeps two days of Yom Tov (a visitor to Israel), in a week when Israel and the Diaspora read different portions.
  ///
  /// In en, this message translates to:
  /// **'In Israel this week: {israel}. Outside Israel: {diaspora}. Visitors from abroad usually read both. If you daven with a minyan reading {diaspora}, read only that one, and set the reading you’ll hear to Outside Israel in Settings.'**
  String readingDivergence(String israel, String diaspora);

  /// Shown on Today when the reader hears the reading outside Israel but keeps one day of Yom Tov (an Israeli abroad), in a week when Israel reads the next portion.
  ///
  /// In en, this message translates to:
  /// **'In Israel this week: {israel}. Outside Israel: {diaspora}. Israel is a parsha ahead, so you’ll read {israel} next week.'**
  String readingDivergenceAhead(String israel, String diaspora);

  /// Button on the divergence notice that opens the week page of the Diaspora's portion, read in Israel the week before.
  ///
  /// In en, this message translates to:
  /// **'Open {name}'**
  String readingDivergenceOpen(String name);

  /// Button on the divergence notice for a visitor to Israel that opens Settings → Reading & customs, where the Torah reading they hear is chosen.
  ///
  /// In en, this message translates to:
  /// **'Change the reading'**
  String get readingDivergenceChange;

  /// No description provided for @discussThisWeek.
  ///
  /// In en, this message translates to:
  /// **'Discuss this week’s parsha'**
  String get discussThisWeek;

  /// The heading over the haftarah and the discussion on Today, under the week strip, whose card is headed This week’s plan (weekStripLabel): the rest of what the week holds besides its reading plan.
  ///
  /// In en, this message translates to:
  /// **'Also this week'**
  String get thisWeek;

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

  /// On the streak card, in place of a parsha streak of 0, over the label 'Parsha streak': the streak starts once this week's parsha is finished. Screen readers hear it after the label ('Parsha streak: starts when Bereshit is complete').
  ///
  /// In en, this message translates to:
  /// **'Starts when {name} is complete'**
  String streakBeginsWith(String name);

  /// On the streak card, in place of 0 days on track, over the label 'Days on track': the run starts with today's planned reading. Screen readers hear it after the label ('Days on track: starts with today’s reading').
  ///
  /// In en, this message translates to:
  /// **'Starts with today’s reading'**
  String get daysBeginToday;

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

  /// In the week strip, a planned day gone by whose reading is still to do, in full or in part (a day counts once three readings are done, so a day with one or two read is still to read), and can still be caught up (drawn in the overdue colour), and today until its reading is done. Say nothing of whether any of it was read. Pairs with dayMissed ('Not read'), a day gone by that can no longer be caught up, and with plannedForOverdue's 'still to read' on the week's page.
  ///
  /// In en, this message translates to:
  /// **'Still to read'**
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

  /// Under a Yom Tov day in the week strip (any Yom Tov, Yom Kippur and Rosh Hashana included), so it is not taken for Shabbat. Keep it short: the day is about 48 dp wide; where the words don't fit on one line at their size, they wrap, never shrink.
  ///
  /// In en, this message translates to:
  /// **'Yom Tov'**
  String get yomTovShort;

  /// Read by screen readers, and shown as the tooltip, for a day of the week strip: the weekday's name (Names.weekday) and how the day stands (dayKept, dayOpen and so on).
  ///
  /// In en, this message translates to:
  /// **'{day}: {status}'**
  String dayChipLabel(String day, String status);

  /// No description provided for @weekStripLabel.
  ///
  /// In en, this message translates to:
  /// **'This week’s plan'**
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

  /// A parsha's status: missed by its late window, then finished together with the next parsha by the next Shabbat (once in each book of the Torah), so the streak continues. weekOverdue is the same rescue still open; keep the two in the same words. No no-break spaces: in the Progress page's recent weeks, the line balances its words itself, and a pair held together would be set smaller there as one word.
  ///
  /// In en, this message translates to:
  /// **'Finished with the next parsha'**
  String get weekRestored;

  /// A parsha's status: finished after its late window, but not together with the next parsha by the next Shabbat. It counts for the year, but the streak begins again.
  ///
  /// In en, this message translates to:
  /// **'Made up later'**
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

  /// A parsha's status: missed by its late window, and it can still count if it is finished together with the next parsha by the next Shabbat (see weekRestored).
  ///
  /// In en, this message translates to:
  /// **'Can still be finished with the next parsha'**
  String get weekOverdue;

  /// No description provided for @weekInProgress.
  ///
  /// In en, this message translates to:
  /// **'In progress'**
  String get weekInProgress;

  /// The day is the weekday's name (Names.weekday): 'Monday', in Hebrew 'יום שני', which takes ל directly.
  ///
  /// In en, this message translates to:
  /// **'Planned for {day}'**
  String plannedFor(String day);

  /// Read by screen readers for an aliyah on the week's page planned for a day gone by and still to read, which the page shows in the overdue colour after a mark.
  ///
  /// In en, this message translates to:
  /// **'Planned for {day}, still to read'**
  String plannedForOverdue(String day);

  /// As plannedForOverdue, for an aliyah planned for Shabbat morning once Shabbat has passed.
  ///
  /// In en, this message translates to:
  /// **'Planned for Shabbat morning, still to read'**
  String get plannedForShabbatOverdue;

  /// No description provided for @plannedForToday.
  ///
  /// In en, this message translates to:
  /// **'Planned for today'**
  String get plannedForToday;

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
  /// **'Clear this week’s progress'**
  String get clearWeek;

  /// No description provided for @clearWeekConfirm.
  ///
  /// In en, this message translates to:
  /// **'Clear all progress for {name}?'**
  String clearWeekConfirm(String name);

  /// A status message, with Undo, once a week's progress has been cleared from its menu. The parsha's name, as in clearWeekConfirm.
  ///
  /// In en, this message translates to:
  /// **'Progress for {name} cleared'**
  String weekCleared(String name);

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

  /// In the sheet that asks when reading was done, a day of Yom Tov in that week, read from a printed Chumash; its date is beneath.
  ///
  /// In en, this message translates to:
  /// **'On Yom Tov'**
  String get whenOnYomTov;

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

  /// Under an aliyah whose verses some sources divide differently: the verses they give it instead, without the book ('4:19–26'; in Hebrew 'ד, יט–כו').
  ///
  /// In en, this message translates to:
  /// **'Some sources use {range}'**
  String aliyahOtherDivision(String range);

  /// In a week of two parshiyot read together, under the aliyah in which the second begins: its name and its first verse, without the book ('Pekudei begins at 38:21'; in Hebrew the verse is 'לח, כא').
  ///
  /// In en, this message translates to:
  /// **'{name} begins at {ref}'**
  String secondParshaBegins(String name, String ref);

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

  /// Beside a book's name on the page of every parsha (The Torah): how many parshiyot the book has.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 parsha} other{{count} parshiyot}}'**
  String browseBookParshiyot(int count);

  /// Eyebrow over the name of this week's parsha in the list of every parsha (The Torah).
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get browseThisWeek;

  /// Under a parsha in the list of every parsha, when this year it is read together with the parsha before or after it on one Shabbat. The name is that other parsha's, in the UI's language: 'Read with Pekudei'.
  ///
  /// In en, this message translates to:
  /// **'Read with {name}'**
  String browseReadWith(String name);

  /// The date is the day the week opens, with its weekday first (Names.dateLong): 'Sunday, July 18', in Hebrew 'יום ראשון, 18 ביולי', which takes ב directly.
  ///
  /// In en, this message translates to:
  /// **'Preview — you can log this parsha from {date}.'**
  String previewNotOpen(String date);

  /// No description provided for @stepMikrah1.
  ///
  /// In en, this message translates to:
  /// **'Read the Hebrew'**
  String get stepMikrah1;

  /// No description provided for @stepMikrah2.
  ///
  /// In en, this message translates to:
  /// **'Read the Hebrew again'**
  String get stepMikrah2;

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
  /// **'End with Mikrah: read the last verse once more'**
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

  /// Spoken by screen readers before the Aramaic of a verse of Targum Onkelos.
  ///
  /// In en, this message translates to:
  /// **'Targum, verse {number}'**
  String targumVerseLabel(String number);

  /// No description provided for @chapterLabel.
  ///
  /// In en, this message translates to:
  /// **'Chapter {number}'**
  String chapterLabel(String number);

  /// No description provided for @noTargumNote.
  ///
  /// In en, this message translates to:
  /// **'Onkelos here gives mostly the Aramaic forms of the place names. Following Rashi (Berachot 8b), many also read this verse a third time in Hebrew (see Shulchan Aruch OC 285:1).'**
  String get noTargumNote;

  /// No description provided for @noRashiNote.
  ///
  /// In en, this message translates to:
  /// **'Rashi does not comment on this verse. Some read it a third time in Hebrew (Mishnah Berurah 285:5).'**
  String get noRashiNote;

  /// No description provided for @noRashiComment.
  ///
  /// In en, this message translates to:
  /// **'Rashi does not comment on this verse.'**
  String get noRashiComment;

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
  /// **'Yasher koach! Your first aliyah is done — {verses}, twice, with {second}.'**
  String firstAliyahDone(String verses, String second);

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

  /// No description provided for @listenPause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get listenPause;

  /// No description provided for @listenResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get listenResume;

  /// No description provided for @listenPreviousVerse.
  ///
  /// In en, this message translates to:
  /// **'Previous verse'**
  String get listenPreviousVerse;

  /// No description provided for @listenNextVerse.
  ///
  /// In en, this message translates to:
  /// **'Next verse'**
  String get listenNextVerse;

  /// The speech rate's button in the player that shows while Listen reads, as screen readers hear it. The rate is as the player and Settings show it, relative to the default: speechRateNormal ("Normal") or speechRateTimes ("1.2×").
  ///
  /// In en, this message translates to:
  /// **'Speech rate: {rate}'**
  String speechRateValue(String rate);

  /// No description provided for @listenAlong.
  ///
  /// In en, this message translates to:
  /// **'Listen along'**
  String get listenAlong;

  /// No description provided for @listenAlongDesc.
  ///
  /// In en, this message translates to:
  /// **'Keeps playing from one reading to the next, to the end of the aliyah. An aid for following the text, not a substitute for reading it.'**
  String get listenAlongDesc;

  /// No description provided for @ttsUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Text-to-speech isn’t available on this device.'**
  String get ttsUnavailable;

  /// No description provided for @ttsNoHebrewVoice.
  ///
  /// In en, this message translates to:
  /// **'No Hebrew voice is installed. You can add one in your device’s speech settings.'**
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

  /// No description provided for @wholeParsha.
  ///
  /// In en, this message translates to:
  /// **'Whole parsha'**
  String get wholeParsha;

  /// No description provided for @oneAliyahAtATime.
  ///
  /// In en, this message translates to:
  /// **'One aliyah at a time'**
  String get oneAliyahAtATime;

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
  /// **'Helps with the meaning; it doesn’t take the place of the Targum.'**
  String get translationDisclaimer;

  /// No description provided for @mikrahLabel.
  ///
  /// In en, this message translates to:
  /// **'Mikrah'**
  String get mikrahLabel;

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

  /// The head of the English translation's column beside the Torah in the full text's side-by-side columns (where the Targum isn't shown), set as an eyebrow in small capitals beside "Mikrah". No digits: in small capitals "1" reads as "I", so the JPS 1917 isn't named here.
  ///
  /// In en, this message translates to:
  /// **'English translation'**
  String get translationHead;

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

  /// No description provided for @readerFinished.
  ///
  /// In en, this message translates to:
  /// **'You’ve finished this aliyah.'**
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

  /// In the Windows app’s list of the reader’s keyboard shortcuts, beside Alt+←: close the reading screen and return to the page it was opened from, as the system’s Back would. Not a page of text, nor the reader’s previous step, which are rows of their own.
  ///
  /// In en, this message translates to:
  /// **'Close the reader, as the mouse’s back button does'**
  String get shortcutGoBack;

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
  /// **'Listen / pause'**
  String get shortcutListen;

  /// No description provided for @shortcutListenVerse.
  ///
  /// In en, this message translates to:
  /// **'While listening: previous or next verse'**
  String get shortcutListenVerse;

  /// No description provided for @shortcutHelp.
  ///
  /// In en, this message translates to:
  /// **'Show shortcuts'**
  String get shortcutHelp;

  /// No description provided for @shortcutScroll.
  ///
  /// In en, this message translates to:
  /// **'Scroll the text'**
  String get shortcutScroll;

  /// No description provided for @shortcutPageDown.
  ///
  /// In en, this message translates to:
  /// **'Down a page, then the next step'**
  String get shortcutPageDown;

  /// No description provided for @shortcutPageUp.
  ///
  /// In en, this message translates to:
  /// **'Up a page, then the previous step'**
  String get shortcutPageUp;

  /// No description provided for @shortcutFocusVerse.
  ///
  /// In en, this message translates to:
  /// **'Full text in focus mode: previous or next verse'**
  String get shortcutFocusVerse;

  /// No description provided for @keyUp.
  ///
  /// In en, this message translates to:
  /// **'Up arrow'**
  String get keyUp;

  /// No description provided for @keyDown.
  ///
  /// In en, this message translates to:
  /// **'Down arrow'**
  String get keyDown;

  /// No description provided for @keyLeft.
  ///
  /// In en, this message translates to:
  /// **'Left arrow'**
  String get keyLeft;

  /// No description provided for @keyRight.
  ///
  /// In en, this message translates to:
  /// **'Right arrow'**
  String get keyRight;

  /// No description provided for @keySpace.
  ///
  /// In en, this message translates to:
  /// **'Space'**
  String get keySpace;

  /// A screen reader's action on a verse, which opens what can be done with it: bookmark it, write a note on it, copy, share or ask about it.
  ///
  /// In en, this message translates to:
  /// **'Verse options'**
  String get verseOptions;

  /// No description provided for @shortcutVerseOptions.
  ///
  /// In en, this message translates to:
  /// **'Verse options: bookmark, note, copy, share or ask'**
  String get shortcutVerseOptions;

  /// No description provided for @copyVerse.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get copyVerse;

  /// No description provided for @askAboutVerse.
  ///
  /// In en, this message translates to:
  /// **'Ask about this verse'**
  String get askAboutVerse;

  /// No description provided for @askAboutVerseDesc.
  ///
  /// In en, this message translates to:
  /// **'In Questions & answers'**
  String get askAboutVerseDesc;

  /// No description provided for @verseCopied.
  ///
  /// In en, this message translates to:
  /// **'Verse copied'**
  String get verseCopied;

  /// No description provided for @shareCopiedInstead.
  ///
  /// In en, this message translates to:
  /// **'Sharing isn’t available here, so the verse was copied.'**
  String get shareCopiedInstead;

  /// A switch in a verse's options that bookmarks the verse.
  ///
  /// In en, this message translates to:
  /// **'Bookmark'**
  String get bookmarkVerse;

  /// No description provided for @addNote.
  ///
  /// In en, this message translates to:
  /// **'Add a note'**
  String get addNote;

  /// A verse's options: the row that opens the reader's note on the verse, with the note beneath it. Also the label of the note's field.
  ///
  /// In en, this message translates to:
  /// **'Your note'**
  String get yourNote;

  /// The title of the dialog that edits the reader's note on a verse, such as "Note on Genesis 3:22".
  ///
  /// In en, this message translates to:
  /// **'Note on {reference}'**
  String noteTitle(String reference);

  /// No description provided for @noteHint.
  ///
  /// In en, this message translates to:
  /// **'A question for the Shabbat table, or a thought'**
  String get noteHint;

  /// No description provided for @noteSaved.
  ///
  /// In en, this message translates to:
  /// **'Note saved'**
  String get noteSaved;

  /// No description provided for @noteDeleted.
  ///
  /// In en, this message translates to:
  /// **'Note deleted'**
  String get noteDeleted;

  /// Said by screen readers after a verse the reader has bookmarked.
  ///
  /// In en, this message translates to:
  /// **'Bookmarked'**
  String get verseBookmarked;

  /// Said by screen readers after a verse the reader has written a note on.
  ///
  /// In en, this message translates to:
  /// **'With your note'**
  String get verseWithNote;

  /// Read by screen readers on the list of bookmarks and notes: the reader's own note on a verse.
  ///
  /// In en, this message translates to:
  /// **'Your note: {text}'**
  String yourNoteLabel(String text);

  /// No description provided for @notesTitle.
  ///
  /// In en, this message translates to:
  /// **'Bookmarks & notes'**
  String get notesTitle;

  /// No description provided for @notesEmpty.
  ///
  /// In en, this message translates to:
  /// **'To bookmark a verse or keep a question for the Shabbat table, press and hold the verse as you read.'**
  String get notesEmpty;

  /// No description provided for @notesEmptyParsha.
  ///
  /// In en, this message translates to:
  /// **'No bookmarks or notes on this parsha yet.'**
  String get notesEmptyParsha;

  /// No description provided for @notesShowAll.
  ///
  /// In en, this message translates to:
  /// **'All bookmarks & notes'**
  String get notesShowAll;

  /// A row on a week's page that opens the reader's bookmarks and notes on its parsha.
  ///
  /// In en, this message translates to:
  /// **'Your notes on this parsha'**
  String get parshaNotes;

  /// No description provided for @notesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 note} other{{count} notes}}'**
  String notesCount(int count);

  /// No description provided for @bookmarksCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 bookmark} other{{count} bookmarks}}'**
  String bookmarksCount(int count);

  /// No description provided for @copyDivineName.
  ///
  /// In en, this message translates to:
  /// **'Write Divine Names as ה׳ and אלקים'**
  String get copyDivineName;

  /// No description provided for @copyDivineNameDesc.
  ///
  /// In en, this message translates to:
  /// **'In a verse copied, shared or quoted in a question'**
  String get copyDivineNameDesc;

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

  /// No description provided for @versesRead.
  ///
  /// In en, this message translates to:
  /// **'{count} verses read twice with {second}'**
  String versesRead(String count, String second);

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
  /// **'Each tile is one parsha of this year’s cycle.'**
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
  /// **'Optional. Make-ups count toward this year’s siyum.'**
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

  /// The title of the dialog that Settings' pause row opens while a pause lasts.
  ///
  /// In en, this message translates to:
  /// **'Paused until {date}'**
  String pauseManageTitle(String date);

  /// No description provided for @pauseManageBody.
  ///
  /// In en, this message translates to:
  /// **'You can extend the pause, or end it now.'**
  String get pauseManageBody;

  /// In place of pauseManageBody when the pause under way already runs its 30 days.
  ///
  /// In en, this message translates to:
  /// **'A pause lasts 30 days at most. You can end it now.'**
  String get pauseAtMost;

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

  /// No description provided for @graceExplainer.
  ///
  /// In en, this message translates to:
  /// **'Grace days cover a missed planned day automatically. You start with 2, earn 1 each time you finish a parsha before Shabbat (up to 3), and use at most 2 a week. They can never be bought.'**
  String get graceExplainer;

  /// In Progress's About streaks sheet. The deadline is the reader's after-Shabbat window (lateWindowLabel): tuesday, wednesday or none.
  ///
  /// In en, this message translates to:
  /// **'Your parsha streak counts portions finished before Shabbat{deadline, select, tuesday{ — or by Tuesday night, which still counts} wednesday{ — or by the end of Wednesday, which still counts} other{}}. Shabbat and Yom Tov never break a streak.'**
  String streakExplainer(String deadline);

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
  /// **'About this app'**
  String get settingsAbout;

  /// No description provided for @settingsReadingDesc.
  ///
  /// In en, this message translates to:
  /// **'Israel or abroad, Shabbat times, plan, Targum or Rashi, haftarah'**
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

  /// Heading of the settings group with Reading & customs, Reminders and the streaks.
  ///
  /// In en, this message translates to:
  /// **'Practice'**
  String get settingsGroupPractice;

  /// Heading of the settings group with Display and Accessibility: how the text reads on the screen.
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get settingsGroupReading;

  /// Heading of the settings group with the account, the reader's data and the language.
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get settingsGroupYou;

  /// No description provided for @settingsAboutDesc.
  ///
  /// In en, this message translates to:
  /// **'Version, sources, privacy'**
  String get settingsAboutDesc;

  /// Under pauseAction in Settings, which opens the pause dialog.
  ///
  /// In en, this message translates to:
  /// **'Illness, travel, mourning, a new baby: nothing resets while paused'**
  String get settingsPauseDesc;

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
  /// **'Israel and the Diaspora sometimes read different parshiyot and keep a different number of Yom Tov days. Visiting? You can set the days of Yom Tov you keep separately in Settings.'**
  String get locationHelp;

  /// No description provided for @readingScheduleLabel.
  ///
  /// In en, this message translates to:
  /// **'Which Torah reading will you hear this Shabbat?'**
  String get readingScheduleLabel;

  /// No description provided for @readingScheduleHelp.
  ///
  /// In en, this message translates to:
  /// **'For a few weeks after Pesach or Shavuot, Israel can be a parsha ahead.'**
  String get readingScheduleHelp;

  /// No description provided for @yomTovDaysLabel.
  ///
  /// In en, this message translates to:
  /// **'How many days of Yom Tov do you keep?'**
  String get yomTovDaysLabel;

  /// No description provided for @yomTovDaysOne.
  ///
  /// In en, this message translates to:
  /// **'One, as in Israel'**
  String get yomTovDaysOne;

  /// No description provided for @yomTovDaysTwo.
  ///
  /// In en, this message translates to:
  /// **'Two, as outside Israel'**
  String get yomTovDaysTwo;

  /// No description provided for @yomTovDaysHelp.
  ///
  /// In en, this message translates to:
  /// **'Visitors usually keep their home custom. Ask your rav.'**
  String get yomTovDaysHelp;

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
  /// **'One aliyah a day; two on the last day before Shabbat'**
  String get planAliyahPerDayDesc;

  /// No description provided for @planShevii.
  ///
  /// In en, this message translates to:
  /// **'Shevi’i on Shabbat morning'**
  String get planShevii;

  /// No description provided for @planSheviiDesc.
  ///
  /// In en, this message translates to:
  /// **'Aliyot 1–6 Sunday–Friday; the 7th before the Shabbat meal (Vilna Gaon, MB 285:8)'**
  String get planSheviiDesc;

  /// No description provided for @planErevShabbat.
  ///
  /// In en, this message translates to:
  /// **'All on Friday'**
  String get planErevShabbat;

  /// No description provided for @planErevShabbatDesc.
  ///
  /// In en, this message translates to:
  /// **'The whole parsha on Erev Shabbat — after Shacharit (Arizal) or after midday (Shelah; Shulchan Aruch HaRav)'**
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

  /// {second} is the reading after the Torah's two, as the reader set it: Targum, Rashi, or Onkelos and Rashi.
  ///
  /// In en, this message translates to:
  /// **'Each verse twice, then its {second}'**
  String methodVerseDesc(String second);

  /// No description provided for @methodSection.
  ///
  /// In en, this message translates to:
  /// **'Section by section'**
  String get methodSection;

  /// As methodVerseDesc.
  ///
  /// In en, this message translates to:
  /// **'Each paragraph twice, then its {second}'**
  String methodSectionDesc(String second);

  /// No description provided for @methodAliyah.
  ///
  /// In en, this message translates to:
  /// **'Aliyah by aliyah'**
  String get methodAliyah;

  /// As methodVerseDesc.
  ///
  /// In en, this message translates to:
  /// **'The whole aliyah twice, then its {second}'**
  String methodAliyahDesc(String second);

  /// No description provided for @secondLabel.
  ///
  /// In en, this message translates to:
  /// **'Targum or Rashi'**
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

  /// The source of the choice of second reading, set as a margin note under its heading.
  ///
  /// In en, this message translates to:
  /// **'The Shulchan Aruch (OC 285:2) permits Rashi in place of Targum, and praises reading both.'**
  String get secondSource;

  /// Advice on the choice of second reading, in plain help after secondSource.
  ///
  /// In en, this message translates to:
  /// **'A plain translation is a study aid, not a substitute. Ask your rav about translated Rashi.'**
  String get secondAdvice;

  /// No description provided for @repeatLastVerse.
  ///
  /// In en, this message translates to:
  /// **'End with Mikrah'**
  String get repeatLastVerse;

  /// No description provided for @repeatLastVerseDesc.
  ///
  /// In en, this message translates to:
  /// **'Repeat the parsha’s last verse in Hebrew after its Targum'**
  String get repeatLastVerseDesc;

  /// No description provided for @thirdReading.
  ///
  /// In en, this message translates to:
  /// **'Third-reading prompts'**
  String get thirdReading;

  /// No description provided for @thirdReadingDesc.
  ///
  /// In en, this message translates to:
  /// **'Suggest a third Hebrew reading where Onkelos is mostly names (Numbers 32:3) or Rashi is silent'**
  String get thirdReadingDesc;

  /// No description provided for @haftarahEnabledDesc.
  ///
  /// In en, this message translates to:
  /// **'Read the week’s haftarah once'**
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
  /// **'Until the end of Wednesday'**
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
  /// **'No reading planned on Tisha B’Av'**
  String get tishaBavQuiet;

  /// No description provided for @cholHamoedQuiet.
  ///
  /// In en, this message translates to:
  /// **'No reading planned on Chol HaMoed'**
  String get cholHamoedQuiet;

  /// Status shown after changing the reading plan or a custom that decides how weeks are planned and judged; earlier weeks keep the settings they had.
  ///
  /// In en, this message translates to:
  /// **'Applies from this week on'**
  String get appliesFromThisWeek;

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

  /// Heading in Reading & customs over the reading heard, the days of Yom Tov, Shabbat times, the plan and the after-Shabbat window.
  ///
  /// In en, this message translates to:
  /// **'Where & when'**
  String get readingGroupWhere;

  /// Heading in Reading & customs over the reading method, the second reading and the prompts to read again.
  ///
  /// In en, this message translates to:
  /// **'How I read'**
  String get readingGroupHow;

  /// Heading in Reading & customs over the switches for Tisha B'Av and Chol HaMoed.
  ///
  /// In en, this message translates to:
  /// **'Special days'**
  String get readingGroupSpecialDays;

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

  /// Under the Match device switch over the theme swatches, in Display settings and the reader's display sheet.
  ///
  /// In en, this message translates to:
  /// **'Light or dark, like the device'**
  String get themeSystemDesc;

  /// A screen reader's hint on a theme swatch while the app matches the device: the theme it uses when the device is in light mode.
  ///
  /// In en, this message translates to:
  /// **'Used while the device is light'**
  String get themeUsedWhenLight;

  /// As themeUsedWhenLight, for dark mode.
  ///
  /// In en, this message translates to:
  /// **'Used while the device is dark'**
  String get themeUsedWhenDark;

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

  /// The first line of a high-contrast theme's swatch label, over themeLight or themeDark.
  ///
  /// In en, this message translates to:
  /// **'High contrast'**
  String get themeHc;

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

  /// Heading in Display settings over the sliders for reading size and line, word and letter spacing.
  ///
  /// In en, this message translates to:
  /// **'Size and spacing'**
  String get displayGroupSize;

  /// Heading in Display settings over the switches for vowels, cantillation, the ketiv, verse numbers and justified text.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get displayGroupText;

  /// Heading in Display settings over the switches for the English translation, Rashi and the Rashi script.
  ///
  /// In en, this message translates to:
  /// **'Study aids'**
  String get displayGroupStudy;

  /// Heading in Display settings over the switches for focus mode, bold text and keeping the screen on.
  ///
  /// In en, this message translates to:
  /// **'Reading'**
  String get displayGroupReading;

  /// Tooltip and spoken name of the minus button beside a settings slider. name is the slider's name, such as 'Reading size'.
  ///
  /// In en, this message translates to:
  /// **'Decrease {name}'**
  String decreaseSetting(String name);

  /// Tooltip and spoken name of the plus button beside a settings slider. name is the slider's name, such as 'Reading size'.
  ///
  /// In en, this message translates to:
  /// **'Increase {name}'**
  String increaseSetting(String name);

  /// No description provided for @showNikud.
  ///
  /// In en, this message translates to:
  /// **'Vowels (nikud)'**
  String get showNikud;

  /// No description provided for @showTeamim.
  ///
  /// In en, this message translates to:
  /// **'Cantillation (ta’amim)'**
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

  /// The title of the Display setting that sets scripture flush at both sides of its column, over its three choices.
  ///
  /// In en, this message translates to:
  /// **'Justify text'**
  String get justifyText;

  /// Under the Justify text setting: what its Auto choice does. English is never justified automatically.
  ///
  /// In en, this message translates to:
  /// **'Auto justifies Hebrew and Aramaic in a wide column, as in a printed Chumash.'**
  String get justifyHelp;

  /// A choice of the Justify text setting, short for automatic, as one of three segments sharing a phone's width: justify the Hebrew and Aramaic only where the column is wide enough.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get justifyAuto;

  /// A choice of the Justify text setting: justify every paragraph, English too, in every column.
  ///
  /// In en, this message translates to:
  /// **'Always'**
  String get justifyAlways;

  /// A choice of the Justify text setting: never justify; every line ends where its words do.
  ///
  /// In en, this message translates to:
  /// **'Never'**
  String get justifyNever;

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

  /// Display switch: set Rashi's commentary in the traditional Rashi script rather than square letters.
  ///
  /// In en, this message translates to:
  /// **'Rashi script'**
  String get rashiScript;

  /// No description provided for @rashiScriptDesc.
  ///
  /// In en, this message translates to:
  /// **'Set Rashi’s commentary in the script of a printed Chumash'**
  String get rashiScriptDesc;

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

  /// No description provided for @sideBySide.
  ///
  /// In en, this message translates to:
  /// **'Side by side'**
  String get sideBySide;

  /// No description provided for @sideBySideDesc.
  ///
  /// In en, this message translates to:
  /// **'On a wide screen, the full text shows the Targum, or the translation, in a column beside each verse'**
  String get sideBySideDesc;

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

  /// Under the Reduce motion or Bold text switch while the device has that setting on, in place of the switch's description: the switch shows it on, and can't be turned off in the app.
  ///
  /// In en, this message translates to:
  /// **'On in your device’s settings'**
  String get settingOnInDevice;

  /// No description provided for @haptics.
  ///
  /// In en, this message translates to:
  /// **'Haptic feedback'**
  String get haptics;

  /// No description provided for @singleKeyShortcuts.
  ///
  /// In en, this message translates to:
  /// **'Single-key shortcuts'**
  String get singleKeyShortcuts;

  /// No description provided for @singleKeyShortcutsDesc.
  ///
  /// In en, this message translates to:
  /// **'While reading, T, N, L, + and − work on their own, without Ctrl. Turn this off if you use speech input or screen-reader quick keys.'**
  String get singleKeyShortcutsDesc;

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
  /// **'Ado-nai'**
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

  /// One short line under Large print in Accessibility's quick setups.
  ///
  /// In en, this message translates to:
  /// **'Bigger, roomier text'**
  String get presetLargePrintDesc;

  /// No description provided for @presetDyslexiaDesc.
  ///
  /// In en, this message translates to:
  /// **'Clear font, no cantillation'**
  String get presetDyslexiaDesc;

  /// No description provided for @presetHighContrastDesc.
  ///
  /// In en, this message translates to:
  /// **'Strong contrast, bold'**
  String get presetHighContrastDesc;

  /// No description provided for @presetLowVisionDesc.
  ///
  /// In en, this message translates to:
  /// **'Largest text, high contrast'**
  String get presetLowVisionDesc;

  /// No description provided for @presetApplied.
  ///
  /// In en, this message translates to:
  /// **'{name} applied'**
  String presetApplied(String name);

  /// Status message after Reset display in Accessibility, with an Undo action.
  ///
  /// In en, this message translates to:
  /// **'Display settings reset'**
  String get displayResetDone;

  /// Heading in Accessibility over the switches for reduced motion, haptic feedback and single-key shortcuts.
  ///
  /// In en, this message translates to:
  /// **'Motion and touch'**
  String get a11yGroupMotion;

  /// Heading in Accessibility over the accessibility statement and Send feedback.
  ///
  /// In en, this message translates to:
  /// **'Statement and feedback'**
  String get a11yGroupMore;

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

  /// In place of dailyReminderDesc when a city is chosen for Shabbat times: a daily reminder set for later than two and a half hours before candle-lighting comes then instead.
  ///
  /// In en, this message translates to:
  /// **'A gentle nudge at your chosen time, or before candle-lighting on the eve of Shabbat or Yom Tov'**
  String get dailyReminderDescCity;

  /// No description provided for @dailyReminderTime.
  ///
  /// In en, this message translates to:
  /// **'Daily reminder time'**
  String get dailyReminderTime;

  /// No description provided for @fridayReminder.
  ///
  /// In en, this message translates to:
  /// **'Erev Shabbat reminder'**
  String get fridayReminder;

  /// No description provided for @fridayReminderDesc.
  ///
  /// In en, this message translates to:
  /// **'Friday morning, only if the parsha isn’t finished'**
  String get fridayReminderDesc;

  /// In place of fridayReminderDesc when a city is chosen for Shabbat times: the reminder comes at the time chosen, or three hours before candle-lighting if that is earlier.
  ///
  /// In en, this message translates to:
  /// **'Friday, at least three hours before candle-lighting, only if the parsha isn’t finished'**
  String get fridayReminderDescCity;

  /// No description provided for @fridayReminderTime.
  ///
  /// In en, this message translates to:
  /// **'Erev Shabbat reminder time'**
  String get fridayReminderTime;

  /// The reminder setting that, after a Shabbat whose parsha isn't finished (and the Yom Tov straight after it, if any), and after Simchat Torah while Vezot HaBerachah isn't, reminds the reader to log what they read then.
  ///
  /// In en, this message translates to:
  /// **'Check-in after Shabbat or Yom Tov'**
  String get checkInReminder;

  /// Under checkInReminder when no city is chosen for Shabbat times: the morning after the days of rest end.
  ///
  /// In en, this message translates to:
  /// **'The morning after Shabbat or Simchat Torah, to log what you read then'**
  String get checkInReminderDesc;

  /// In place of checkInReminderDesc when a city is chosen for Shabbat times: an hour after nightfall as the days of rest end, unless that is after 10:30 PM.
  ///
  /// In en, this message translates to:
  /// **'An hour after Shabbat or Simchat Torah ends, or the next morning when it ends late, to log what you read then'**
  String get checkInReminderDescCity;

  /// The note at the top of Settings → Reminders, in a notice whose lines are balanced. Yom Tov is held together by a no-break space, so that a line never ends with Yom and starts the next with Tov.
  ///
  /// In en, this message translates to:
  /// **'Never on Shabbat or Yom Tov, and at most once a day.'**
  String get remindersShabbatNote;

  /// In place of remindersShabbatNote when a city is chosen for Shabbat times, Yom Tov held together as there. city is its name.
  ///
  /// In en, this message translates to:
  /// **'Never on Shabbat or Yom Tov, and at most once a day. They follow the Shabbat times in {city}.'**
  String remindersShabbatNoteCity(String city);

  /// Offered under the reminders while any of them is on and no city is chosen for Shabbat times, with reminderCityChoose and actionNotNow.
  ///
  /// In en, this message translates to:
  /// **'Choose your city, and reminders will follow its Shabbat times: before candle-lighting on Friday, and after Shabbat ends.'**
  String get reminderCityOffer;

  /// Button: opens the list of cities for Shabbat times (see reminderCityOffer and remindersOnCityOffer).
  ///
  /// In en, this message translates to:
  /// **'Choose a city'**
  String get reminderCityChoose;

  /// Status message, with the action reminderCityChoose, once the reader has turned reminders on in the offer after their first aliyah and no city is chosen for Shabbat times.
  ///
  /// In en, this message translates to:
  /// **'Reminders are on. Choose your city, and they’ll follow its Shabbat times.'**
  String get remindersOnCityOffer;

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

  /// The reader's chosen routine, named in the daily reminder: 'After Shacharit — your time for the parsha.'
  ///
  /// In en, this message translates to:
  /// **'After Shacharit'**
  String get anchorCueShacharit;

  /// The reader's chosen routine, named in the daily reminder: 'After breakfast — your time for the parsha.'
  ///
  /// In en, this message translates to:
  /// **'After breakfast'**
  String get anchorCueBreakfast;

  /// The reader's chosen routine, named in the daily reminder: 'On your commute — your time for the parsha.'
  ///
  /// In en, this message translates to:
  /// **'On your commute'**
  String get anchorCueCommute;

  /// The reader's chosen routine, named in the daily reminder: 'After dinner — your time for the parsha.'
  ///
  /// In en, this message translates to:
  /// **'After dinner'**
  String get anchorCueDinner;

  /// The reader's chosen routine, named in the daily reminder: 'Before bed — your time for the parsha.'
  ///
  /// In en, this message translates to:
  /// **'Before bed'**
  String get anchorCueBed;

  /// No description provided for @notificationsUnsupported.
  ///
  /// In en, this message translates to:
  /// **'Reminders need the installed app, on your phone or computer. Below are the reminders it can send.'**
  String get notificationsUnsupported;

  /// Under notificationsUnsupported on the web, where the app can be installed from (INSTALL_URL).
  ///
  /// In en, this message translates to:
  /// **'Get the app'**
  String get getTheApp;

  /// No description provided for @notificationsDenied.
  ///
  /// In en, this message translates to:
  /// **'Notifications are turned off for this app in your device settings.'**
  String get notificationsDenied;

  /// No description provided for @notificationsDeniedTitle.
  ///
  /// In en, this message translates to:
  /// **'Notifications are off'**
  String get notificationsDeniedTitle;

  /// Opens the device's notification settings for this app, from the dialog saying notifications are off.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get openSystemSettings;

  /// Under the routines in the daily reminder's settings, when the reminder's time is far from the chosen routine's usual time (an 8 PM reminder after Shacharit), so that the reminder doesn't name the routine. With the button reminderMove.
  ///
  /// In en, this message translates to:
  /// **'Your reminder comes at {time}. Move it to {usual}?'**
  String reminderMoveHint(String time, String usual);

  /// Button, after reminderMoveHint: moves the daily reminder to the routine's usual time.
  ///
  /// In en, this message translates to:
  /// **'Move'**
  String get reminderMove;

  /// No description provided for @primingTitle.
  ///
  /// In en, this message translates to:
  /// **'Want a gentle daily nudge?'**
  String get primingTitle;

  /// No description provided for @primingBody.
  ///
  /// In en, this message translates to:
  /// **'Never on Shabbat or Yom Tov, and at most one a day. Change it anytime.'**
  String get primingBody;

  /// The daily reminder's time in the offer of reminders; tapping it changes the time.
  ///
  /// In en, this message translates to:
  /// **'At {time}'**
  String reminderAtTime(String time);

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

  /// Android notification channel name, shown in the system's notification settings: the check-in after Shabbat and after Simchat Torah.
  ///
  /// In en, this message translates to:
  /// **'After Shabbat and Yom Tov'**
  String get notifChannelCheckIn;

  /// Android notification channel description, shown in the system's notification settings.
  ///
  /// In en, this message translates to:
  /// **'Your day’s reading at the time you choose, never on Shabbat or Yom Tov'**
  String get notifChannelDailyDesc;

  /// Android notification channel description, shown in the system's notification settings.
  ///
  /// In en, this message translates to:
  /// **'Before Shabbat or Yom Tov, only if the parsha isn’t finished'**
  String get notifChannelErevShabbatDesc;

  /// Android notification channel description, shown in the system's notification settings.
  ///
  /// In en, this message translates to:
  /// **'After Shabbat or Simchat Torah, a reminder to log what you read; also the note when reminders stop'**
  String get notifChannelCheckInDesc;

  /// No description provided for @notifDailyTitle.
  ///
  /// In en, this message translates to:
  /// **'Today: {aliyah}'**
  String notifDailyTitle(String aliyah);

  /// No description provided for @notifDailyBody.
  ///
  /// In en, this message translates to:
  /// **'Parshat {parsha} · {verses} · about {minutes} min'**
  String notifDailyBody(String parsha, String verses, int minutes);

  /// Ends the daily reminder when the reader has tied the reading to a routine, after ' · '.
  ///
  /// In en, this message translates to:
  /// **'{cue} — your time for the parsha.'**
  String notifDailyAnchor(String cue);

  /// No description provided for @notifFridayTitle.
  ///
  /// In en, this message translates to:
  /// **'Erev Shabbat · Parshat {parsha}'**
  String notifFridayTitle(String parsha);

  /// The Erev Shabbat reminder, sent only while the week's parsha isn't finished.
  ///
  /// In en, this message translates to:
  /// **'There’s still time — or finish Shabbat morning from your Chumash and log it after Shabbat.'**
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

  /// As notifCheckInBody, when the days of rest after Shabbat ran on into Yom Tov; it comes once that Yom Tov is over.
  ///
  /// In en, this message translates to:
  /// **'Did you read on Shabbat and Yom Tov? Tap to log it.'**
  String get notifCheckInBodyShabbatYomTov;

  /// The check-in reminder after Simchat Torah, under the title Vezot HaBerachah (the parsha's name): whether it was read on that Yom Tov, from a printed Chumash.
  ///
  /// In en, this message translates to:
  /// **'Did you read it on Yom Tov? Tap to log it.'**
  String get notifCheckInBodyVezot;

  /// As notifCheckInBodyVezot, for a reader to whom Simchat Torah was not Yom Tov (one who keeps a single day of Yom Tov but hears the reading outside Israel, a day later).
  ///
  /// In en, this message translates to:
  /// **'Did you read it on Simchat Torah? Tap to log it.'**
  String get notifCheckInBodySimchatTorah;

  /// The last notification, sent when the app has not been opened for two weeks; none follow until it is opened again.
  ///
  /// In en, this message translates to:
  /// **'Reminders paused'**
  String get notifPausedTitle;

  /// No description provided for @notifPausedBody.
  ///
  /// In en, this message translates to:
  /// **'We’ll pause reminders for now. Your place in Parshat {parsha} is saved — come back anytime.'**
  String notifPausedBody(String parsha);

  /// No description provided for @showStreaks.
  ///
  /// In en, this message translates to:
  /// **'Show streak numbers'**
  String get showStreaks;

  /// No description provided for @showStreaksDesc.
  ///
  /// In en, this message translates to:
  /// **'Hide them if you’d rather focus on the learning itself'**
  String get showStreaksDesc;

  /// No description provided for @exportData.
  ///
  /// In en, this message translates to:
  /// **'Export my progress'**
  String get exportData;

  /// No description provided for @exportDataDesc.
  ///
  /// In en, this message translates to:
  /// **'Save a backup of your progress, bookmarks and notes to restore later'**
  String get exportDataDesc;

  /// No description provided for @importData.
  ///
  /// In en, this message translates to:
  /// **'Import progress'**
  String get importData;

  /// No description provided for @importDataDesc.
  ///
  /// In en, this message translates to:
  /// **'Restore from a backup file'**
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
  /// **'That backup couldn’t be read.'**
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
  /// **'This erases your reading history and streaks on this device. It can’t be undone.'**
  String get resetProgressConfirm;

  /// No description provided for @resetProgressConfirmSynced.
  ///
  /// In en, this message translates to:
  /// **'This erases your reading history and streaks on this device, in your backup, and on your other devices when they next sync. It can’t be undone.'**
  String get resetProgressConfirmSynced;

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

  /// The Language row's value in Settings when the app follows the device's language.
  ///
  /// In en, this message translates to:
  /// **'Device'**
  String get languageDevice;

  /// No description provided for @dataGroupBackup.
  ///
  /// In en, this message translates to:
  /// **'Backup & restore'**
  String get dataGroupBackup;

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

  /// Heading over About's link to the texts and their sources.
  ///
  /// In en, this message translates to:
  /// **'Learn'**
  String get aboutGroupLearn;

  /// Heading over About's links to the privacy policy, terms, community guidelines, accessibility statement and open-source licenses.
  ///
  /// In en, this message translates to:
  /// **'Policies'**
  String get aboutGroupPolicies;

  /// Heading over About's links to email us and to send feedback, and, after something has gone wrong, the row that copies details for support.
  ///
  /// In en, this message translates to:
  /// **'Contact'**
  String get aboutGroupContact;

  /// A row in About, shown only after something has gone wrong since the app started: it copies the app's version and what went wrong, to paste into a message to the maintainers.
  ///
  /// In en, this message translates to:
  /// **'Copy details for support'**
  String get copySupportDetails;

  /// Under copySupportDetails.
  ///
  /// In en, this message translates to:
  /// **'What went wrong since the app opened, to paste into a message to us'**
  String get copySupportDetailsDesc;

  /// A status message once copySupportDetails has copied the details to the clipboard.
  ///
  /// In en, this message translates to:
  /// **'Details copied'**
  String get supportDetailsCopied;

  /// In the web app, at the top of Today and in About, once a new version of the app has downloaded and is waiting to replace the one open.
  ///
  /// In en, this message translates to:
  /// **'A new version is ready.'**
  String get webUpdateReady;

  /// The button beside webUpdateReady, which reloads the app in the new version, keeping the reader's progress and settings.
  ///
  /// In en, this message translates to:
  /// **'Restart'**
  String get webUpdateRestart;

  /// Shown, in a release build, in place of a part of a page that failed to appear, such as a card that couldn't be built.
  ///
  /// In en, this message translates to:
  /// **'Something on this page didn’t load.'**
  String get errorPanelMessage;

  /// A status message when tapping a link opened nothing, as on a device with no browser to hand it to.
  ///
  /// In en, this message translates to:
  /// **'The link couldn’t be opened here.'**
  String get linkOpenFailed;

  /// A status message when tapping the support address opened no mail app, with an action to copy the address.
  ///
  /// In en, this message translates to:
  /// **'No mail app opened. You can write to {address}.'**
  String emailOpenFailed(String address);

  /// No description provided for @actionCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get actionCopy;

  /// The link text, inside a policy's sentence ('Questions or requests: GitHub issues'), for the public issue tracker on GitHub, where there is no support email address.
  ///
  /// In en, this message translates to:
  /// **'GitHub issues'**
  String get feedbackLinkLabel;

  /// Under a policy's title. date is a month and year, such as 'October 2026'.
  ///
  /// In en, this message translates to:
  /// **'Last updated: {date}'**
  String legalLastUpdated(String date);

  /// No description provided for @guideTitle.
  ///
  /// In en, this message translates to:
  /// **'How it works'**
  String get guideTitle;

  /// No description provided for @disclaimer.
  ///
  /// In en, this message translates to:
  /// **'Customs vary. For practical questions, ask your rav.'**
  String get disclaimer;

  /// No description provided for @onbWelcomeBody.
  ///
  /// In en, this message translates to:
  /// **'Read the parsha twice and the Targum once — one aliyah a day, done before Shabbat.'**
  String get onbWelcomeBody;

  /// No description provided for @onbStart.
  ///
  /// In en, this message translates to:
  /// **'Start this week’s parsha'**
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
  /// **'Your weekly plan'**
  String get onbPlanTitle;

  /// No description provided for @onbHonor.
  ///
  /// In en, this message translates to:
  /// **'Shnayim Mikrah runs on the honor system. Log what you read, wherever you read it — a Chumash in shul counts just as much as this app.'**
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
  /// **'What is Shnayim Mikrah?'**
  String get guideWhatTitle;

  /// Under the Talmud's words that open the guide, in Hebrew: where they are written.
  ///
  /// In en, this message translates to:
  /// **'Berachot 8a'**
  String get guideQuoteSource;

  /// The Talmud's words that open the guide, in English. Shown in the English interface only, under the Hebrew.
  ///
  /// In en, this message translates to:
  /// **'A person should always complete their portions with the community: the text twice and the Targum once.'**
  String get guideQuoteTranslation;

  /// No description provided for @guideWhatBody.
  ///
  /// In en, this message translates to:
  /// **'The Shulchan Aruch sets the Talmud’s words down as law (Orach Chaim 285): each week, a person completes on their own the portion the community reads aloud on Shabbat, keeping pace with it.'**
  String get guideWhatBody;

  /// No description provided for @guideWhenTitle.
  ///
  /// In en, this message translates to:
  /// **'When'**
  String get guideWhenTitle;

  /// No description provided for @guideWhenBody.
  ///
  /// In en, this message translates to:
  /// **'You may begin on Sunday (some say from Shabbat afternoon). Ideally finish before the Shabbat-day meal; if not, after the meal until Mincha. After that it may still be completed until Tuesday night (“until Wednesday”), and missed portions may be made up until Simchat Torah (SA 285:4; MB 285:12).'**
  String get guideWhenBody;

  /// No description provided for @guideHowTitle.
  ///
  /// In en, this message translates to:
  /// **'How'**
  String get guideHowTitle;

  /// No description provided for @guideHowBody.
  ///
  /// In en, this message translates to:
  /// **'Read verse by verse — each verse twice and then its Targum — or section by section, reading each paragraph twice and then its Targum. Many repeat the final verse in Hebrew so as to end with the Torah text. If you can, read aloud and with the cantillation.'**
  String get guideHowBody;

  /// Beside three marks for the three readings, at the top of the guide's How section: the text twice, then the Targum. No-break spaces keep each reading's number with its name.
  ///
  /// In en, this message translates to:
  /// **'1 · Mikrah  2 · Mikrah  3 · Targum'**
  String get guidePassesCaption;

  /// No description provided for @guideTargumTitle.
  ///
  /// In en, this message translates to:
  /// **'Targum or Rashi'**
  String get guideTargumTitle;

  /// No description provided for @guideTargumBody.
  ///
  /// In en, this message translates to:
  /// **'Rashi’s commentary may take the place of the Targum, since it explains the text; a God-fearing person reads both (SA 285:2). A plain translation is a helpful study aid but is not a substitute for the Targum. Someone who doesn’t understand Rashi’s Hebrew may read Rashi in a language they understand (MB 285:5; Rav Moshe Feinstein). Ask your rav.'**
  String get guideTargumBody;

  /// No description provided for @guideSpecialTitle.
  ///
  /// In en, this message translates to:
  /// **'Special cases'**
  String get guideSpecialTitle;

  /// Under the guide's Special cases heading: one case to a line, each shown after a bullet. Each line's words before its first colon and space are its lead-in, shown in bold; keep that colon and space.
  ///
  /// In en, this message translates to:
  /// **'Atarot v’Divon (Numbers 32:3): Onkelos gives mostly the Aramaic forms of the place names, so many also read the verse a third time in Hebrew, following Rashi (Berachot 8b).\nVezot HaBerachah: read by the time it is read in shul on Simchat Torah, ideally on Hoshana Rabbah; Shemini Atzeret also counts.\nThe haftarah: many also read the week’s haftarah once.\nIn shul: reading quietly along with the ba’al koreh, word for word, counts as one of the readings (MB 285:14).\nTwo portions: in a double-portion week, read both. When Israel and the Diaspora read different portions, travelers usually read both.\nNo blessing: none is said.\nWomen and children: women are exempt, and those who take it on do so as a voluntary mitzvah; boys are trained in it from the age of chinuch.'**
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

  /// The guide's sources, one to a line.
  ///
  /// In en, this message translates to:
  /// **'Berachot 8a–b\nShulchan Aruch, Orach Chaim 285\nMishnah Berurah 285\nKitzur Shulchan Aruch 72\nShulchan Aruch HaRav 285'**
  String get guideSourcesBody;

  /// No description provided for @hebrewDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Hebrew date: {date}'**
  String hebrewDateLabel(String date);

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

  /// No description provided for @forumNotFound.
  ///
  /// In en, this message translates to:
  /// **'This forum couldn’t be found. It may have moved or closed.'**
  String get forumNotFound;

  /// No description provided for @allForums.
  ///
  /// In en, this message translates to:
  /// **'All forums'**
  String get allForums;

  /// A link to a discussion that isn't there, or that the reader may not see, under the title notFoundTitle, above All forums.
  ///
  /// In en, this message translates to:
  /// **'This discussion couldn’t be found. It may have been deleted.'**
  String get threadNotFound;

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
  /// **'Sign in to post, say todah or report.'**
  String get signInPrompt;

  /// Settings, under the Account row's title while no one is signed in on this device. Todah is the forum's button that thanks a post's author.
  ///
  /// In en, this message translates to:
  /// **'Sign in to post, say todah or report'**
  String get settingsAccountDesc;

  /// Settings, under the Account row's title: the member signed in on this device.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {name}'**
  String signedInAs(String name);

  /// No description provided for @signInTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signInTitle;

  /// No description provided for @signInBody.
  ///
  /// In en, this message translates to:
  /// **'We’ll email you a 6-digit code — no password needed.'**
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
  /// **'Keep your reading progress, bookmarks and notes with your account, and restore them on other devices.'**
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
  /// **'Couldn’t sync right now. We’ll try again later.'**
  String get syncFailed;

  /// No description provided for @syncNeedsUpdate.
  ///
  /// In en, this message translates to:
  /// **'Your backup was saved by a newer version of the app. Update the app to keep syncing.'**
  String get syncNeedsUpdate;

  /// On the account page, and as Sync now's reply, when what the backup would hold is more than the server takes: many long notes on verses.
  ///
  /// In en, this message translates to:
  /// **'Your notes are too long to back up to your account, so nothing new is backed up. Shorten or delete some of them; a backup file, from Your data, keeps them all.'**
  String get syncTooLarge;

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

  /// The account's deletion dialog, shown whether or not backup is on now: a backup made earlier stays in the account until it is deleted. As the privacy policy says, a discussion the member started stays, without their name, where others posted in it (delete_my_account); called a discussion, as the forums call it.
  ///
  /// In en, this message translates to:
  /// **'This permanently deletes your account, your profile, your posts and the cloud backup of your progress, bookmarks and notes. Where others have replied to a discussion you started, it stays, without your name. What’s on this device is kept, and other devices keep what’s on them. This can’t be undone.'**
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

  /// How many have thanked one's own post, under it, for screen readers. The Todah button on others' posts says it with todahButtonCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Thanked once} other{Thanked {count} times}}'**
  String todahCount(int count);

  /// The Todah button's name for screen readers, which holds the word the button shows (Todah), so that voice control finds it by what it says.
  ///
  /// In en, this message translates to:
  /// **'Say todah to {name}'**
  String todahSemantics(String name);

  /// The Todah button's name for screen readers once thanks are given; it holds the word the button shows.
  ///
  /// In en, this message translates to:
  /// **'Remove your todah to {name}'**
  String todahRemove(String name);

  /// No description provided for @reportTitle.
  ///
  /// In en, this message translates to:
  /// **'Report this post'**
  String get reportTitle;

  /// No description provided for @reportReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'What’s wrong?'**
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
  /// **'You won’t see posts from {name}. They won’t be notified.'**
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

  /// Said of what can't be undone: the message of a dialog that confirms it, such as deleting a post, under its question, and the line under Reset all progress in Your data.
  ///
  /// In en, this message translates to:
  /// **'This can’t be undone.'**
  String get cantBeUndone;

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

  /// The action of the "Posted." message after a question asked from the reader is posted, which goes back to the reader: opens the new discussion in Community.
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get viewPostedThread;

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

  /// Tag above the title of a pinned discussion in a forum's list.
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

  /// In a discussion's menu (More options, in its app bar): copies the discussion's address on the web app, for the member to share.
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get copyLink;

  /// A status message once copyLink has copied the discussion's address to the clipboard.
  ///
  /// In en, this message translates to:
  /// **'Link copied'**
  String get linkCopied;

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
  /// **'I’ll follow the community guidelines'**
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

  /// An empty weekly thread. {name} is the parsha; a no-break space keeps it with "Parshat".
  ///
  /// In en, this message translates to:
  /// **'No posts yet — share a thought on Parshat {name}.'**
  String noPostsYet(String name);

  /// No description provided for @noReplies.
  ///
  /// In en, this message translates to:
  /// **'No replies yet.'**
  String get noReplies;

  /// No description provided for @loadMore.
  ///
  /// In en, this message translates to:
  /// **'Load more'**
  String get loadMore;

  /// No description provided for @loadedMore.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Loaded 1 more discussion} other{Loaded {count} more discussions}}'**
  String loadedMore(int count);

  /// Above the first post shown in a long thread, which opens on its latest posts: loads the posts before it.
  ///
  /// In en, this message translates to:
  /// **'Show earlier posts'**
  String get showEarlierPosts;

  /// No description provided for @postsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No posts yet} =1{1 post} other{{count} posts}}'**
  String postsCount(int count);

  /// In a forum's list, after a discussion's replies: how often its posts have been thanked (todah), once they have been. It runs on in a lowercase list ("Rivka · 3 hours ago · 4 replies · thanked 12 times"). A no-break space holds the count to its word, and nothing more, so that at large text on a phone the line can break after "thanked" rather than inside a word.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{thanked once} other{thanked {count} times}}'**
  String threadThanksCount(int count);

  /// Under a forum's description on the Community page: how many discussions it has. A no-break space keeps the count with its word.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No discussions yet} =1{1 discussion} other{{count} discussions}}'**
  String forumDiscussionsCount(int count);

  /// After a forum's count of discussions on the Community page: when one was last posted in. {time} is "3 hours ago", "just now" or, after a day, a date ("Thu, Oct 8"): the phrase must read well with either.
  ///
  /// In en, this message translates to:
  /// **'active {time}'**
  String forumActive(String time);

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

  /// No description provided for @postNofM.
  ///
  /// In en, this message translates to:
  /// **'Post {n} of {total}'**
  String postNofM(int n, int total);

  /// No description provided for @anonymousMember.
  ///
  /// In en, this message translates to:
  /// **'Former member'**
  String get anonymousMember;

  /// No description provided for @errRateLimited.
  ///
  /// In en, this message translates to:
  /// **'You’re posting quickly — please wait a few seconds.'**
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
  /// **'Your account can’t post.'**
  String get errBanned;

  /// No description provided for @errSilenced.
  ///
  /// In en, this message translates to:
  /// **'Posting is paused for your account for now.'**
  String get errSilenced;

  /// No description provided for @errContent.
  ///
  /// In en, this message translates to:
  /// **'That message can’t be posted. Please review the community guidelines.'**
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

  /// No description provided for @errAlreadyReported.
  ///
  /// In en, this message translates to:
  /// **'You’ve already reported this post.'**
  String get errAlreadyReported;

  /// No description provided for @errInvalidName.
  ///
  /// In en, this message translates to:
  /// **'Names must be 2–40 characters.'**
  String get errInvalidName;

  /// No description provided for @errInvalidCode.
  ///
  /// In en, this message translates to:
  /// **'That code didn’t work. Check it and try again.'**
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
  /// **'You don’t have permission to do that.'**
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
  /// **'Couldn’t reach the server. Check your connection and try again.'**
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

  /// The title a question about a verse starts with, such as "Question on Genesis 3:22".
  ///
  /// In en, this message translates to:
  /// **'Question on {reference}'**
  String questionOnVerse(String reference);

  /// No description provided for @askDraftKept.
  ///
  /// In en, this message translates to:
  /// **'Your unsent draft is kept. Discard it to ask about {reference} instead.'**
  String askDraftKept(String reference);

  /// Tooltip of the button beside the verse quoted above a question's message, in a new discussion or while a posted question is edited, which takes the verse out of the question.
  ///
  /// In en, this message translates to:
  /// **'Remove the verse'**
  String get removeVerseQuote;

  /// Status message once the verse quoted above a new question's message is taken out of it, with Undo, which puts it back.
  ///
  /// In en, this message translates to:
  /// **'Verse removed'**
  String get verseQuoteRemoved;

  /// No description provided for @charactersLeft.
  ///
  /// In en, this message translates to:
  /// **'{count} characters left'**
  String charactersLeft(int count);

  /// No description provided for @shabbatTimesLabel.
  ///
  /// In en, this message translates to:
  /// **'Shabbat times'**
  String get shabbatTimesLabel;

  /// No description provided for @shabbatTimesHelp.
  ///
  /// In en, this message translates to:
  /// **'Choose your city to see when to light candles and when Shabbat ends. The times are worked out on this device, and your city stays on it.'**
  String get shabbatTimesHelp;

  /// No description provided for @cityLabel.
  ///
  /// In en, this message translates to:
  /// **'City'**
  String get cityLabel;

  /// No description provided for @cityNotSet.
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get cityNotSet;

  /// This week's Shabbat times in the reader's city, on two lines under the city in Settings. candles and ends are times of day, such as 6:07 PM.
  ///
  /// In en, this message translates to:
  /// **'Candle-lighting {candles}\nShabbat ends {ends}'**
  String shabbatTimesSummary(String candles, String ends);

  /// This week's candle-lighting time, where the sky never gets dark enough to say when Shabbat ends (far north in summer).
  ///
  /// In en, this message translates to:
  /// **'Candle-lighting {candles}'**
  String shabbatCandlesOnly(String candles);

  /// Under the city in Settings, near the poles, where the sun neither sets nor rises on some days (the midnight sun, or the polar night).
  ///
  /// In en, this message translates to:
  /// **'There is no sunset there this Shabbat. Ask your rav about the times.'**
  String get shabbatNoSunset;

  /// Under the city in Settings, in the rare case that the device doesn't know the city's time zone.
  ///
  /// In en, this message translates to:
  /// **'This device can’t tell the time in that city, so its times can’t be shown.'**
  String get shabbatTimesUnavailable;

  /// No description provided for @cityPickerTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose a city'**
  String get cityPickerTitle;

  /// No description provided for @citySearchLabel.
  ///
  /// In en, this message translates to:
  /// **'Search for a city'**
  String get citySearchLabel;

  /// No description provided for @citySearchClear.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get citySearchClear;

  /// No description provided for @cityYours.
  ///
  /// In en, this message translates to:
  /// **'Your city'**
  String get cityYours;

  /// No description provided for @cityNone.
  ///
  /// In en, this message translates to:
  /// **'No city'**
  String get cityNone;

  /// No description provided for @cityNoneDesc.
  ///
  /// In en, this message translates to:
  /// **'Shabbat times aren’t shown'**
  String get cityNoneDesc;

  /// No description provided for @cityNearYou.
  ///
  /// In en, this message translates to:
  /// **'In your time zone'**
  String get cityNearYou;

  /// Shown when a search of the city list finds nothing. query is what the reader typed.
  ///
  /// In en, this message translates to:
  /// **'No city matches “{query}”.'**
  String cityNoResults(String query);

  /// Read out by screen readers after typing in the city search.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No cities found} =1{1 city found} other{{count} cities found}}'**
  String cityResultsCount(int count);

  /// Under a long list of city search results, which stops at the first matches.
  ///
  /// In en, this message translates to:
  /// **'The first {shown} of {count} matches are listed. Type more of the name to find the others.'**
  String cityResultsMore(int shown, int count);

  /// No description provided for @cityListNote.
  ///
  /// In en, this message translates to:
  /// **'The list has every place of 100,000 people or more, every city in Israel, and the larger Israeli localities beyond the Green Line. If yours isn’t there, choose the nearest one; beyond the Green Line, the nearest Israeli locality.'**
  String get cityListNote;

  /// No description provided for @searchTitle.
  ///
  /// In en, this message translates to:
  /// **'Search the Torah'**
  String get searchTitle;

  /// No description provided for @searchFieldLabel.
  ///
  /// In en, this message translates to:
  /// **'A word or phrase'**
  String get searchFieldLabel;

  /// No description provided for @searchClear.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get searchClear;

  /// No description provided for @searchIntro.
  ///
  /// In en, this message translates to:
  /// **'Find a word or phrase in the Torah, in Targum Onkelos, or in the English translation.'**
  String get searchIntro;

  /// Shown with a progress bar the first time search opens, while every verse is read and indexed.
  ///
  /// In en, this message translates to:
  /// **'Preparing the text for search…'**
  String get searchPreparing;

  /// Above the results of a search: how many verses hold what was searched for.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 verse} other{{count} verses}}'**
  String searchResultsCount(int count);

  /// Above the results of a search that found more verses than are listed. shown is how many are listed, count how many there are.
  ///
  /// In en, this message translates to:
  /// **'The first {shown} of {count} verses'**
  String searchResultsFirst(int shown, int count);

  /// No description provided for @searchNarrow.
  ///
  /// In en, this message translates to:
  /// **'Add a word to narrow the search.'**
  String get searchNarrow;

  /// Shown when a search of the Torah finds nothing. query is what the reader typed.
  ///
  /// In en, this message translates to:
  /// **'No verse matches “{query}”.'**
  String searchNoResults(String query);

  /// Under searchNoResults, after a search in Hebrew. By then the app has tried the Torah's spellings itself, with fewer ו and י, and found nothing either (see searchSpellingFallback), so this suggests only what it can't try.
  ///
  /// In en, this message translates to:
  /// **'Try fewer words, or another word or spelling.'**
  String get searchNoResultsHint;

  /// Under searchNoResults, after a search in English. The translation is the JPS 1917.
  ///
  /// In en, this message translates to:
  /// **'Try fewer words, or the older English of the 1917 translation, such as “hath” for “has”.'**
  String get searchNoResultsHintEnglish;

  /// Read out by screen readers once typing in the Torah search pauses.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No verses found} =1{1 verse found} other{{count} verses found}}'**
  String searchResultsAnnounced(int count);

  /// The label of the field in the sheet that opens from the search button: a reference to go to, or words to search the Torah for.
  ///
  /// In en, this message translates to:
  /// **'A verse, word or phrase'**
  String get goToVerseLabel;

  /// An example reference shown in the empty field. book is the name of the first parsha (Bereshit, or Bereishis for readers who chose Ashkenazi names), which is also the book's name. In Hebrew the chapter and verse are Hebrew numerals: כח, יב.
  ///
  /// In en, this message translates to:
  /// **'{book} 28:12'**
  String goToVerseHint(String book);

  /// Shown in the go-to-verse sheet when what was typed is neither a reference nor words to search for, such as a number alone. example is a sample reference, such as Bereshit 28:12 (in Hebrew, בראשית כח, יב).
  ///
  /// In en, this message translates to:
  /// **'Type a book or parsha, then a chapter and verse, as in {example}; or words to search for.'**
  String goToVerseHelp(String example);

  /// A row in the go-to-verse sheet that opens the Torah search for what was typed.
  ///
  /// In en, this message translates to:
  /// **'Search for “{query}”'**
  String goToVerseSearch(String query);

  /// Shown in the go-to-verse sheet for a chapter past the end of the book, e.g. Genesis 51.
  ///
  /// In en, this message translates to:
  /// **'{book} has {count, plural, =1{1 chapter} other{{count} chapters}}.'**
  String goToVerseChapters(String book, int count);

  /// Shown in the go-to-verse sheet for a verse past the end of its chapter, e.g. Genesis 28:30. chapter is the chapter's number, in Hebrew numerals in Hebrew.
  ///
  /// In en, this message translates to:
  /// **'{book} {chapter} has {count, plural, =1{1 verse} other{{count} verses}}.'**
  String goToVerseVerses(String book, String chapter, int count);

  /// Shortcut shown when the app's icon is long-pressed on Android and iOS; opens the reader at the first aliyah not yet read. Keep it under 25 characters.
  ///
  /// In en, this message translates to:
  /// **'Continue reading'**
  String get shortcutContinueReading;

  /// Shortcut shown when the app's icon is long-pressed; opens this week's page to mark what was read from a printed Chumash. Keep it under 25 characters.
  ///
  /// In en, this message translates to:
  /// **'Log a Chumash reading'**
  String get shortcutLogFromBook;

  /// Shortcut shown when the app's icon is long-pressed; opens the Parsha tab. Keep it under 25 characters.
  ///
  /// In en, this message translates to:
  /// **'This week’s parsha'**
  String get shortcutThisWeek;

  /// On the home-screen widget, the day's reading: the aliyot planned for it, by name ("Today: Shlishi"). Keep it short: the widget gives it one line.
  ///
  /// In en, this message translates to:
  /// **'Today: {aliyot}'**
  String widgetToday(String aliyot);

  /// On the home-screen widget, in place of widgetToday while aliyot planned for earlier days are unread: every aliyah due, as Today's card names them ("Catching up: Shlishi – Revi'i"). Keep it short.
  ///
  /// In en, this message translates to:
  /// **'Catching up: {aliyot}'**
  String widgetCatchUp(String aliyot);

  /// On the home-screen widget, a reading day with nothing planned (the plan reads everything on Friday, say). Keep it short.
  ///
  /// In en, this message translates to:
  /// **'No reading planned today'**
  String get widgetNothingToday;

  /// On the home-screen widget, on a day within a pause ("Life happens"): nothing counts against the reader. Keep it short.
  ///
  /// In en, this message translates to:
  /// **'Paused · read whenever you like'**
  String get widgetPaused;

  /// On the home-screen widget, once every aliyah of the week is read. Keep it short.
  ///
  /// In en, this message translates to:
  /// **'Parsha complete · Yasher koach!'**
  String get widgetWeekComplete;

  /// On the home-screen widget, on a weekday once the days it was given have passed without the app being opened: it then shows the last parsha it was given, and this line. (On Shabbat and Yom Tov it shows only the candles and the day's greeting, and asks nothing.)
  ///
  /// In en, this message translates to:
  /// **'Open the app to bring this up to date'**
  String get widgetStale;

  /// On Today, in place of shabbatInDays in the week of Vezot HaBerachah, which is read on Simchat Torah: the days left until then.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Simchat Torah is today} =1{Simchat Torah is tomorrow} other{Simchat Torah in {count} days}}'**
  String simchatTorahInDays(int count);

  /// Heads the portion's own haftarah, open under the special haftarah that displaces it this week, for Chabad, whose custom is to read both.
  ///
  /// In en, this message translates to:
  /// **'Also: the regular haftarah of {portion}'**
  String regularHaftarahOf(String portion);

  /// Heads the portion's own haftarah, folded under the special haftarah that displaces it this week, for the customs other than Chabad's: only some read it as well. (Chabad, whose custom is to read both, has regularHaftarahOf.)
  ///
  /// In en, this message translates to:
  /// **'The regular haftarah of {portion} (some read it too)'**
  String regularHaftarahSomeRead(String portion);

  /// The detail line of the week's Haftarah row (on Today and a week's page) for Chabad, in a week a special haftarah displaces the portion's own: its name (e.g. "Shabbat Machar Chodesh"), and that Chabad's custom is to read the regular haftarah as well, which the haftarah page offers after it. Other customs see the special haftarah's name alone. A no-break space holds the dot to the name, so that no line starts with it.
  ///
  /// In en, this message translates to:
  /// **'{reason} · Chabad custom: the regular haftarah too'**
  String haftarahSpecialChabadRegular(String reason);

  /// No description provided for @chabadFallbackNote.
  ///
  /// In en, this message translates to:
  /// **'Chabad haftarot are being verified; showing the Ashkenazi reading.'**
  String get chabadFallbackNote;

  /// No description provided for @repeatLastVerseDescChabad.
  ///
  /// In en, this message translates to:
  /// **'Repeat the parsha’s last verse in Hebrew after its Targum (Chabad custom: not repeated)'**
  String get repeatLastVerseDescChabad;

  /// Said when choosing the Chabad haftarah custom turns repeatLastVerse off, since the reader hasn't set it themselves.
  ///
  /// In en, this message translates to:
  /// **'“End with Mikrah” is now off, following the Chabad custom.'**
  String get repeatLastVerseFollowsChabad;

  /// Said when choosing another haftarah custom than Chabad turns repeatLastVerse back on.
  ///
  /// In en, this message translates to:
  /// **'“End with Mikrah” is on again.'**
  String get repeatLastVerseBackOn;

  /// What screen readers say for divineAdonai, which is written with a hyphen out of respect, and would be spelled out letter by letter as written.
  ///
  /// In en, this message translates to:
  /// **'Adonai'**
  String get divineAdonaiSpoken;

  /// The label of the field a backup is pasted into; importPrompt is its helper text.
  ///
  /// In en, this message translates to:
  /// **'Backup text'**
  String get importBackupText;

  /// Under the backup text field, when 'Paste from clipboard' finds no text, or the browser won't let the app read the clipboard.
  ///
  /// In en, this message translates to:
  /// **'Couldn’t paste from the clipboard. Paste into the field instead.'**
  String get importPasteFailed;

  /// No description provided for @exportSaved.
  ///
  /// In en, this message translates to:
  /// **'Backup saved.'**
  String get exportSaved;

  /// No description provided for @importPaste.
  ///
  /// In en, this message translates to:
  /// **'Paste backup text'**
  String get importPaste;

  /// No description provided for @importPasteDesc.
  ///
  /// In en, this message translates to:
  /// **'For a backup copied as text'**
  String get importPasteDesc;

  /// No description provided for @pasteFromClipboard.
  ///
  /// In en, this message translates to:
  /// **'Paste from clipboard'**
  String get pasteFromClipboard;

  /// What a backup holds, as importCounts says it, and the day it was made.
  ///
  /// In en, this message translates to:
  /// **'Backup from {date}: {weeks, plural, =0{nothing logged} =1{1 week logged} other{{weeks} weeks logged}}, {pauses, plural, =0{no pauses} =1{1 pause} other{{pauses} pauses}}.'**
  String importSummary(String date, int weeks, int pauses);

  /// What a backup holds: the weeks with reading logged, and the pauses ("Life happens"). Each number is joined to its noun by a no-break space.
  ///
  /// In en, this message translates to:
  /// **'{weeks, plural, =0{Nothing logged} =1{1 week logged} other{{weeks} weeks logged}}, {pauses, plural, =0{no pauses} =1{1 pause} other{{pauses} pauses}}.'**
  String importCounts(int weeks, int pauses);

  /// What a backup holds besides the progress, under importSummary, when it holds any: the verses bookmarked, and the notes on verses. Each number is joined to its noun by a no-break space.
  ///
  /// In en, this message translates to:
  /// **'{bookmarks, plural, =0{No bookmarks} =1{1 bookmark} other{{bookmarks} bookmarks}}, {notes, plural, =0{no notes} =1{1 note} other{{notes} notes}}.'**
  String importMarks(int bookmarks, int notes);

  /// No description provided for @importMergeBody.
  ///
  /// In en, this message translates to:
  /// **'Merge this backup with the progress on this device? Merging keeps everything from both.'**
  String get importMergeBody;

  /// No description provided for @importAlsoSettings.
  ///
  /// In en, this message translates to:
  /// **'Also restore settings'**
  String get importAlsoSettings;

  /// No description provided for @importMerge.
  ///
  /// In en, this message translates to:
  /// **'Merge'**
  String get importMerge;

  /// No description provided for @importReplace.
  ///
  /// In en, this message translates to:
  /// **'Replace instead'**
  String get importReplace;

  /// No description provided for @importReplaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Replace the progress here?'**
  String get importReplaceTitle;

  /// No description provided for @importReplaceConfirm.
  ///
  /// In en, this message translates to:
  /// **'This erases the reading history and streaks on this device, and keeps only what the backup holds. It can’t be undone.'**
  String get importReplaceConfirm;

  /// No description provided for @importReplaceConfirmSynced.
  ///
  /// In en, this message translates to:
  /// **'This erases the reading history and streaks on this device, in your cloud backup, and on your other devices when they next sync, and keeps only what this backup holds. It can’t be undone.'**
  String get importReplaceConfirmSynced;

  /// No description provided for @importReplaceAction.
  ///
  /// In en, this message translates to:
  /// **'Replace'**
  String get importReplaceAction;

  /// After importing a backup whose settings had reminders on, when the device refused the app's notifications. Shown with a 'Reminders' action that opens their settings.
  ///
  /// In en, this message translates to:
  /// **'Progress imported. Reminders are off, since notifications aren’t allowed for this app.'**
  String get importSuccessRemindersOff;

  /// No description provided for @cloudBackup.
  ///
  /// In en, this message translates to:
  /// **'Cloud backup'**
  String get cloudBackup;

  /// About the Miqra according to the Masorah edition, on the Texts & sources page. Its license (CC BY-SA) requires saying how the text was changed.
  ///
  /// In en, this message translates to:
  /// **'Hebrew text of the Torah and haftarot, based on the Aleppo Codex and related manuscripts, edited by Avi Kadish and collaborators on Hebrew Wikisource, via Sefaria. In the Torah, where Ashkenazi and Sephardi scrolls differ from the Aleppo Codex, the text follows the scrolls, with the Codex’s reading in a note. Otherwise it is converted to a structured format without changing the text.'**
  String get sourcesMamDescription;

  /// No description provided for @onbStarterTitle.
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get onbStarterTitle;

  /// No description provided for @onbStarterCatchUp.
  ///
  /// In en, this message translates to:
  /// **'Read the whole parsha by Shabbat'**
  String get onbStarterCatchUp;

  /// The whole parsha spread over the days left in the week the reader joins: its length, its reading time, and the number of days with reading. One day is always today; a single day that isn't takes onbStarterCatchUpOn.
  ///
  /// In en, this message translates to:
  /// **'{verses} verses · about {minutes} min {days, plural, =1{today} other{over {days} days}}'**
  String onbStarterCatchUpDesc(int verses, int minutes, int days);

  /// As onbStarterCatchUpDesc, when the one day left with reading is not today (the reader joins on a day without reading, such as Tisha B'Av): its weekday, such as 'Friday'.
  ///
  /// In en, this message translates to:
  /// **'{verses} verses · about {minutes} min on {day}'**
  String onbStarterCatchUpOn(int verses, int minutes, String day);

  /// No description provided for @onbStarterToday.
  ///
  /// In en, this message translates to:
  /// **'Start with today’s reading'**
  String get onbStarterToday;

  /// No description provided for @onbStarterTodayDesc.
  ///
  /// In en, this message translates to:
  /// **'Full plan from next week'**
  String get onbStarterTodayDesc;

  /// No description provided for @onbRestore.
  ///
  /// In en, this message translates to:
  /// **'I already use Shnayim Mikrah'**
  String get onbRestore;

  /// No description provided for @onbRestoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore your progress'**
  String get onbRestoreTitle;

  /// No description provided for @onbRestoreSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in to restore'**
  String get onbRestoreSignIn;

  /// No description provided for @onbRestoreSignInDesc.
  ///
  /// In en, this message translates to:
  /// **'From the backup kept with your account'**
  String get onbRestoreSignInDesc;

  /// No description provided for @onbRestoreFile.
  ///
  /// In en, this message translates to:
  /// **'Restore from a backup file'**
  String get onbRestoreFile;

  /// No description provided for @onbRestoreFileDesc.
  ///
  /// In en, this message translates to:
  /// **'A backup exported from Settings'**
  String get onbRestoreFileDesc;

  /// No description provided for @onbRestoring.
  ///
  /// In en, this message translates to:
  /// **'Restoring your progress…'**
  String get onbRestoring;

  /// No description provided for @onbRestoreDone.
  ///
  /// In en, this message translates to:
  /// **'Your progress is restored.'**
  String get onbRestoreDone;

  /// As importSuccessRemindersOff, after restoring a backup during onboarding.
  ///
  /// In en, this message translates to:
  /// **'Your progress is restored. Reminders are off, since notifications aren’t allowed for this app.'**
  String get onbRestoreDoneRemindersOff;

  /// No description provided for @onbRestoreNone.
  ///
  /// In en, this message translates to:
  /// **'This account has no backup yet. Let’s set up your reading.'**
  String get onbRestoreNone;

  /// The message once the email code is accepted, confirming the sign-in worked; also announced to screen readers on the page signed in for.
  ///
  /// In en, this message translates to:
  /// **'Signed in as {name}'**
  String signedInNow(String name);

  /// A segment of the reader's pass track: the reading's number and what is read, e.g. "1 · Mikrah", "3 · Targum".
  ///
  /// In en, this message translates to:
  /// **'{n} · {name}'**
  String passTrackLabel(int n, String name);

  /// The Hebrew text of the Torah, as a reading on the reader's pass track ("1 · Mikrah").
  ///
  /// In en, this message translates to:
  /// **'Mikrah'**
  String get passTrackMikrah;

  /// The reader's Next button on the last step of an aliyah.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get finishStep;

  /// The title of the reader's finished panel once an aliyah is read, e.g. "Revi'i is complete". Calm and short: aliyahComplete is what is spoken.
  ///
  /// In en, this message translates to:
  /// **'{aliyah} is complete'**
  String aliyahDoneTitle(String aliyah);

  /// The title of the reader's finished panel once the whole parsha is read. parshaComplete is what is spoken.
  ///
  /// In en, this message translates to:
  /// **'Parshat {name} is complete'**
  String parshaDoneTitle(String name);

  /// Used only by the Hebrew UI: the title of the reader's finished panel once the whole parsha is read, under the parsha's pointed Hebrew name, which it would otherwise repeat. The English UI uses parshaDoneTitle.
  ///
  /// In en, this message translates to:
  /// **'The parsha is complete'**
  String get parshaDoneTitleShort;

  /// A greeting on the reader's finished panel when the parsha is finished on the eve of Shabbat or Yom Tov. {greeting} is chosen as for erevShabbatDone.
  ///
  /// In en, this message translates to:
  /// **'{greeting, select, chag{Chag sameach!} roshHashanah{Shanah tovah!} yomKippur{G’mar chatimah tovah!} other{Shabbat shalom!}}'**
  String restGreeting(String greeting);

  /// A gentle line on the finished panel about the aliyah to read next, e.g. "Chamishi is 31 verses."
  ///
  /// In en, this message translates to:
  /// **'{aliyah} is {count, plural, =1{one verse} other{{count} verses}}.'**
  String nextAliyahLength(String aliyah, int count);

  /// The finished panel's main button, naming the aliyah it opens.
  ///
  /// In en, this message translates to:
  /// **'Next aliyah · {aliyah}'**
  String nextAliyahAction(String aliyah);

  /// A quieter button on the finished panel once the day's reading is done, for reading on anyway.
  ///
  /// In en, this message translates to:
  /// **'Keep going: {aliyah}'**
  String keepGoingAliyah(String aliyah);

  /// On the finished panel when every aliyah planned for today (and before) is read, and tomorrow has reading planned.
  ///
  /// In en, this message translates to:
  /// **'That’s today’s reading. See you tomorrow.'**
  String get todayReadingDone;

  /// As todayReadingDone, when the next day with reading planned is later than tomorrow. {day} is a weekday, e.g. "Sunday".
  ///
  /// In en, this message translates to:
  /// **'That’s today’s reading. See you on {day}.'**
  String todayReadingDoneOn(String day);

  /// On the finished panel when the last day of the week's plan is done. {greeting} is the next day's: roshHashanah or yomKippur when it is Rosh Hashanah or Yom Kippur (on Shabbat too), chag when it is another Yom Tov that is not Shabbat, and otherwise Shabbat (other).
  ///
  /// In en, this message translates to:
  /// **'That’s this week’s reading. {greeting, select, chag{Chag sameach!} roshHashanah{Shanah tovah!} yomKippur{G’mar chatimah tovah!} other{Shabbat shalom!}}'**
  String erevShabbatDone(String greeting);

  /// As erevShabbatDone, when the plan leaves aliyot for Shabbat morning (read from a printed chumash).
  ///
  /// In en, this message translates to:
  /// **'The rest is for Shabbat morning. {greeting, select, chag{Chag sameach!} roshHashanah{Shanah tovah!} yomKippur{G’mar chatimah tovah!} other{Shabbat shalom!}}'**
  String erevShabbatDoneMorning(String greeting);

  /// After "On time · " on the finished panel, once a parsha is finished before its Shabbat.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1-week parsha streak} other{{count}-week parsha streak}}'**
  String parshaStreakLength(int count);

  /// After the parsha streak on the finished panel, when finishing on time earned a grace day.
  ///
  /// In en, this message translates to:
  /// **'+1 grace day'**
  String get graceDayEarned;

  /// No description provided for @parshaDoneLate.
  ///
  /// In en, this message translates to:
  /// **'After Shabbat — and it still counts.'**
  String get parshaDoneLate;

  /// No description provided for @parshaDoneLateStreak.
  ///
  /// In en, this message translates to:
  /// **'After Shabbat — and it still counts. Your streak continues.'**
  String get parshaDoneLateStreak;

  /// No description provided for @parshaDoneRestored.
  ///
  /// In en, this message translates to:
  /// **'Finished together with the next parsha.'**
  String get parshaDoneRestored;

  /// No description provided for @parshaDoneRestoredStreak.
  ///
  /// In en, this message translates to:
  /// **'Finished together with the next parsha — your streak continues.'**
  String get parshaDoneRestoredStreak;

  /// No description provided for @readHaftarah.
  ///
  /// In en, this message translates to:
  /// **'Read the haftarah'**
  String get readHaftarah;

  /// Names the page shown once a whole book of the Torah is read, e.g. in the browser's tab.
  ///
  /// In en, this message translates to:
  /// **'{book} is complete'**
  String seferDoneTitle(String book);

  /// On the page shown once a whole book of the Torah is read, under "Genesis is complete": what was read, e.g. "1,533 verses, twice, with Targum." {second} is what was read after the Torah's two readings. A book has hundreds of verses.
  ///
  /// In en, this message translates to:
  /// **'{count} verses, twice, with {second}.'**
  String seferDoneFacts(int count, String second);

  /// The last line of the page shown once a whole book of the Torah is read, as a printed book's colophon dates it: e.g. "Finished on Friday, 28 Tishrei 5787".
  ///
  /// In en, this message translates to:
  /// **'Finished on {weekday}, {date}'**
  String seferDoneOn(String weekday, String date);

  /// On the page shown once the whole Torah is read in a year's cycle (under "Siyum HaTorah"): e.g. "The whole Torah — 5,846 verses, twice, with Targum, in the cycle of 5786." Named as a cycle, as the date beneath it falls in the next year: Vezot HaBerakhah is read in Tishrei.
  ///
  /// In en, this message translates to:
  /// **'The whole Torah — {count} verses, twice, with {second}, in the cycle of {year}.'**
  String siyumBody(int count, String second, String year);

  /// On the page for the siyum of a reader who joined partway through a year's cycle, under "Siyum from Parshat Vayera": what they read, from that parsha to the end of the Torah, e.g. "5,327 verses, twice, with Targum, in the cycle of 5786."
  ///
  /// In en, this message translates to:
  /// **'{count} verses, twice, with {second}, in the cycle of {year}.'**
  String siyumFromBody(int count, String second, String year);

  /// Spoken for an aliyah's tab in the reader's ribbon, before its state, e.g. "Revi'i, aliyah 4 of 7, not started".
  ///
  /// In en, this message translates to:
  /// **'{name}, aliyah {n} of 7'**
  String aliyahTabLabel(String name, int n);

  /// Spoken after an aliyah tab's label in the reader: all three of its readings are done.
  ///
  /// In en, this message translates to:
  /// **'read'**
  String get tabRead;

  /// Spoken after an aliyah tab's label in the reader: how many of its three readings (Mikrah, Mikrah again, Targum) are done.
  ///
  /// In en, this message translates to:
  /// **'{done} of 3 readings done'**
  String tabPartial(int done);

  /// Spoken after an aliyah tab's label in the reader: none of its readings is done or under way.
  ///
  /// In en, this message translates to:
  /// **'not started'**
  String get tabNotStarted;

  /// At the end of the haftarah once it is marked read. {date} is dateLong, e.g. "Friday, 9 October".
  ///
  /// In en, this message translates to:
  /// **'Read on {date}'**
  String haftarahReadOn(String date);

  /// The Torah map's heading while it shows an earlier year, chosen by the year chips on Progress.
  ///
  /// In en, this message translates to:
  /// **'Torah map · {year}'**
  String torahMapOfYear(String year);

  /// On Progress, beside the grace days: opens a sheet explaining grace days and the parsha streak.
  ///
  /// In en, this message translates to:
  /// **'About streaks'**
  String get aboutStreaks;

  /// No description provided for @graceAvailable.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No grace days available} =1{1 grace day available} other{{count} grace days available}}'**
  String graceAvailable(int count);

  /// Heading on Progress over this year's count of parshiyot and the year bar.
  ///
  /// In en, this message translates to:
  /// **'This year'**
  String get thisYear;

  /// The same heading while the reader looks at the parshiyot of a cycle before this one.
  ///
  /// In en, this message translates to:
  /// **'An earlier year'**
  String get earlierYear;

  /// The parshiyot finished in a year's cycle, out of all of them.
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} parshiyot'**
  String parshiyotOfYear(int done, int total);

  /// On Progress, under the heading 'This year', in place of '0 of 54 parshiyot' while none of this year's parshiyot is finished yet: the reader's year begins with this week's parsha. Its subject is the year (in Hebrew, feminine, agreeing with השנה).
  ///
  /// In en, this message translates to:
  /// **'Begins with {name}'**
  String yearBeginsWith(String name);

  /// Screen-reader label of the year bar for a cycle before this one; year is its Hebrew year (5786).
  ///
  /// In en, this message translates to:
  /// **'{year}: {done} of {total} parshiyot complete'**
  String yearBarSemanticsYear(String year, int done, int total);

  /// Under the recent weeks on Progress: shows the rest of them in place.
  ///
  /// In en, this message translates to:
  /// **'Show all ({count})'**
  String showAllWeeks(int count);

  /// No description provided for @pauseRowBody.
  ///
  /// In en, this message translates to:
  /// **'Pause for up to 30 days. Nothing resets while paused.'**
  String get pauseRowBody;

  /// No description provided for @endPause.
  ///
  /// In en, this message translates to:
  /// **'End pause'**
  String get endPause;

  /// On Progress while streaks are paused, and in the dialog that extends a pause: makes the pause longer.
  ///
  /// In en, this message translates to:
  /// **'Extend'**
  String get extendPause;

  /// The title of the dialog Progress's Extend opens. Settings' opens the same dialog titled pauseManageTitle.
  ///
  /// In en, this message translates to:
  /// **'Extend the pause'**
  String get extendPauseTitle;

  /// Over choices of 1, 3, 7 or 14 days.
  ///
  /// In en, this message translates to:
  /// **'Extend by'**
  String get extendPauseBy;

  /// In the dialog that extends a pause, before it is confirmed: when the pause would then end.
  ///
  /// In en, this message translates to:
  /// **'The pause will end on {date}.'**
  String extendPauseUntil(String date);

  /// Heading on Progress over what the reader has done: first aliyah, books finished, the siyum.
  ///
  /// In en, this message translates to:
  /// **'Finished so far'**
  String get recordTitle;

  /// In the Record: a reader who joined partway through the year finished every parsha from the one they began with to the end of the Torah.
  ///
  /// In en, this message translates to:
  /// **'Siyum from Parshat {name}'**
  String milestoneSiyumFrom(String name);

  /// A small tag in the app bar of community pages when no community server is connected. Tapping it explains the demo.
  ///
  /// In en, this message translates to:
  /// **'Demo'**
  String get demoTag;

  /// No description provided for @demoAboutTitle.
  ///
  /// In en, this message translates to:
  /// **'About the demo'**
  String get demoAboutTitle;

  /// No description provided for @demoAboutBody.
  ///
  /// In en, this message translates to:
  /// **'No community server is connected, so the community runs as a demo on this device alone. The discussions in it are examples.'**
  String get demoAboutBody;

  /// No description provided for @demoAboutPosts.
  ///
  /// In en, this message translates to:
  /// **'Anything you post stays on this device, and everything resets when the app restarts.'**
  String get demoAboutPosts;

  /// After demoAboutPosts in the demo's explanation, to a reader not signed in.
  ///
  /// In en, this message translates to:
  /// **'To try it, sign in with any email address and any 6 digits as the code.'**
  String get demoAboutSignIn;

  /// No description provided for @dismissNotice.
  ///
  /// In en, this message translates to:
  /// **'Dismiss notice'**
  String get dismissNotice;

  /// No description provided for @resendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend code'**
  String get resendCode;

  /// No description provided for @resendCodeIn.
  ///
  /// In en, this message translates to:
  /// **'Resend in {seconds}s'**
  String resendCodeIn(int seconds);

  /// No description provided for @signInPrivacy.
  ///
  /// In en, this message translates to:
  /// **'We use your email only to sign you in.'**
  String get signInPrivacy;

  /// No description provided for @editDisplayName.
  ///
  /// In en, this message translates to:
  /// **'Edit display name'**
  String get editDisplayName;

  /// No description provided for @cloudBackupTitle.
  ///
  /// In en, this message translates to:
  /// **'Cloud backup'**
  String get cloudBackupTitle;

  /// No description provided for @privacySafetyTitle.
  ///
  /// In en, this message translates to:
  /// **'Privacy & safety'**
  String get privacySafetyTitle;

  /// No description provided for @accountGroupTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountGroupTitle;

  /// No description provided for @postingAs.
  ///
  /// In en, this message translates to:
  /// **'Posting as {name}'**
  String postingAs(String name);

  /// No description provided for @titleMinHelp.
  ///
  /// In en, this message translates to:
  /// **'At least 5 characters'**
  String get titleMinHelp;

  /// No description provided for @bodyMinHelp.
  ///
  /// In en, this message translates to:
  /// **'At least 2 characters'**
  String get bodyMinHelp;

  /// Read by screen readers for a post's Reply button.
  ///
  /// In en, this message translates to:
  /// **'Reply to {name}'**
  String replyToName(String name);

  /// No description provided for @sending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get sending;

  /// A small tag beside a member's name on the post that asked a question (a discussion in Questions & answers): it names the post. Their later posts there are tagged authorTag.
  ///
  /// In en, this message translates to:
  /// **'Question'**
  String get askedTag;

  /// A small tag beside a member's name on their posts in a discussion they started (in a question, on all but the post that asked it, which is tagged askedTag): it names the person.
  ///
  /// In en, this message translates to:
  /// **'Author'**
  String get authorTag;

  /// The label of a post's thanks button: the Hebrew word for thanks.
  ///
  /// In en, this message translates to:
  /// **'Todah'**
  String get todahAction;

  /// No description provided for @blockedMembersCount.
  ///
  /// In en, this message translates to:
  /// **'Blocked members ({count})'**
  String blockedMembersCount(int count);

  /// No description provided for @noBlockedMembers.
  ///
  /// In en, this message translates to:
  /// **'You haven’t blocked anyone.'**
  String get noBlockedMembers;

  /// Heading over a forum's pinned discussions.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get pinnedHeading;

  /// Heading over a forum's other discussions, the most recently active first.
  ///
  /// In en, this message translates to:
  /// **'Recent'**
  String get recentHeading;

  /// No description provided for @emptyForum.
  ///
  /// In en, this message translates to:
  /// **'No discussions yet — begin the first.'**
  String get emptyForum;

  /// An empty forum, to a member who may not begin a discussion in it (it is locked).
  ///
  /// In en, this message translates to:
  /// **'No discussions here yet.'**
  String get emptyLockedForum;

  /// In a forum's list, how many replies a discussion has had. A no-break space keeps the count with its word.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No replies yet} =1{1 reply} other{{count} replies}}'**
  String repliesCount(int count);

  /// No description provided for @errBodyTooShort.
  ///
  /// In en, this message translates to:
  /// **'The message needs at least 2 characters.'**
  String get errBodyTooShort;

  /// On Today on Tisha B'Av, while no reading is planned on it: the eyebrow of the title page, in place of Parshat HaShavua, and of the home-screen widget.
  ///
  /// In en, this message translates to:
  /// **'Tisha B’Av'**
  String get tishaBavTitle;

  /// Today's card on Tisha B'Av, while no reading is planned on it, in place of today's reading: on the fast, Torah is not studied, but for the sad passages (Shulchan Aruch OC 554:1–2). Followed by todayTishaBavTomorrow while the week's parsha is unfinished.
  ///
  /// In en, this message translates to:
  /// **'Torah study is set aside today, apart from the passages of mourning (Iyov, Eicha, parts of Yirmiyahu).'**
  String get todayTishaBav;

  /// After todayTishaBav, while the week's parsha is unfinished and the reader's plan has reading for the next day (the day after Tisha B'Av is always a reading day, but a plan may leave it empty, or a pause may run past it; see todayTishaBavOn). portion is the week's parsha.
  ///
  /// In en, this message translates to:
  /// **'{portion} continues tomorrow.'**
  String todayTishaBavTomorrow(String portion);

  /// After todayTishaBav, in place of todayTishaBavTomorrow, when the reader's plan has nothing to read the next day (the whole parsha on Erev Shabbat, say) or a pause runs past it: the next day of the week with reading. portion is the week's parsha; weekday is that day's name, as 'Friday'.
  ///
  /// In en, this message translates to:
  /// **'{portion} continues on {weekday}.'**
  String todayTishaBavOn(String portion, String weekday);

  /// Under Tisha B'Av in the week strip, while no reading is planned on it (on the 10th of Av too, when the fast is postponed from Shabbat): the fast, by its date. Keep it short: the day is about 48 dp wide.
  ///
  /// In en, this message translates to:
  /// **'9 Av'**
  String get tishaBavShort;

  /// As dayChipLabel, for today's day in the week strip, so a screen reader can find it: the weekday's name (Names.weekday) and how the day stands (dayKept, dayOpen and so on).
  ///
  /// In en, this message translates to:
  /// **'{day}, today: {status}'**
  String dayChipLabelToday(String day, String status);

  /// The default speech rate, as the player that shows while Listen reads, and Settings → Accessibility → Speech rate, show it. Agrees with "Speech rate" (speechRate).
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get speechRateNormal;

  /// Any other speech rate, as a multiple of the default (Normal): "0.6×", "1.2×", "2.2×". Shown in the Listen player's rate menu and on the Speech rate slider in Settings → Accessibility.
  ///
  /// In en, this message translates to:
  /// **'{rate}×'**
  String speechRateTimes(String rate);

  /// Under the switch tishaBavQuiet in Reading & customs: why no reading is planned on Tisha B'Av.
  ///
  /// In en, this message translates to:
  /// **'Torah study is set aside on the fast, apart from the passages of mourning (Shulchan Aruch OC 554:1)'**
  String get tishaBavQuietDesc;

  /// Heading in Accessibility over the speech rate slider, which sets how fast Listen reads aloud.
  ///
  /// In en, this message translates to:
  /// **'Speech'**
  String get a11yGroupSpeech;

  /// On the home-screen widget on Tisha B'Av, while no reading is planned on it, in place of the day's reading (as Today's card says, todayTishaBav). Keep it short.
  ///
  /// In en, this message translates to:
  /// **'Torah study is set aside today'**
  String get widgetTishaBav;

  /// The guide's first heading, under the Talmud's words that open it: how the app helps with the practice.
  ///
  /// In en, this message translates to:
  /// **'Using the app'**
  String get guideAppTitle;

  /// Under the guide's Using the app heading: one point to a line, each shown after a bullet. It quotes readFromBook, and names Today, Listen and grace days as the app does.
  ///
  /// In en, this message translates to:
  /// **'Today shows this week’s parsha and today’s reading. The rings fill as you read: Mikrah, Mikrah again, then Targum.\nRead from a printed Chumash? Tap “I read it in a Chumash”. After Shabbat, log what you read on Shabbat.\nMissed a day? Read it with the next day’s reading and it’s made up; if not, a grace day covers it.\nPress and hold a verse to bookmark it, add a note, copy, share or ask about it.\nListen reads the text aloud for you to follow — an aid, not a substitute for reading.'**
  String get guideAppBody;

  /// In the account's deletion dialog: closes it and opens Your data, where a backup file can be exported.
  ///
  /// In en, this message translates to:
  /// **'Save a backup file first'**
  String get saveBackupFirst;

  /// On a post's Todah button, after what a tap does, for screen readers: how many have thanked it, always in digits, as the button shows the count, so that voice control finds the button by the number it shows too (WCAG 2.5.3).
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Thanked 1 time} other{Thanked {count} times}}'**
  String todahButtonCount(int count);

  /// Under the sign-in code's boxes, when Sign in is pressed before every digit is typed.
  ///
  /// In en, this message translates to:
  /// **'Enter all {count} digits of the code.'**
  String codeIncomplete(int count);

  /// This week's Shabbat times in the reader's city, under the city in Settings, when Yom Tov begins as Shabbat ends: its candles are lit only after Shabbat. candles and after are times of day, such as 6:07 PM.
  ///
  /// In en, this message translates to:
  /// **'Candle-lighting {candles}\nYom Tov candles after {after}'**
  String shabbatTimesSummaryYomTov(String candles, String after);

  /// In Settings, under the city for Shabbat times: the row, and the title of its sheet, that sets how many minutes before sunset candles are lit, as the reader's local calendar (luach) has it.
  ///
  /// In en, this message translates to:
  /// **'Candle-lighting'**
  String get candleLightingSetting;

  /// The candle-lighting option that follows the city's own custom, which the app knows: minutes is how many minutes before sunset candles are lit there, such as 18 or 40.
  ///
  /// In en, this message translates to:
  /// **'City default ({minutes} min)'**
  String candleMinutesCityDefault(int minutes);

  /// A candle-lighting option, chosen to match the reader's luach: candles are lit this many minutes before sunset (15, 18, 20, 22, 30 or 40).
  ///
  /// In en, this message translates to:
  /// **'{minutes, plural, =1{1 minute before sunset} other{{minutes} minutes before sunset}}'**
  String candleMinutesBeforeSunset(int minutes);

  /// In Settings, under the city for Shabbat times: the row, and the title of its sheet, that sets when Shabbat ends, as the reader's luach has it.
  ///
  /// In en, this message translates to:
  /// **'Shabbat ends'**
  String get shabbatEndsSetting;

  /// The default end of Shabbat: nightfall, when three small stars are out, reckoned as the sun 8.5 degrees below the horizon.
  ///
  /// In en, this message translates to:
  /// **'Nightfall (sun 8.5° below)'**
  String get havdalahNightfall;

  /// An end of Shabbat a fixed time after sunset, as many luachs give it: 42 or 50 minutes.
  ///
  /// In en, this message translates to:
  /// **'{minutes} minutes after sunset'**
  String havdalahMinutesAfterSunset(int minutes);

  /// An end of Shabbat 72 minutes after sunset, following Rabbeinu Tam.
  ///
  /// In en, this message translates to:
  /// **'72 minutes (Rabbeinu Tam)'**
  String get havdalahRabbeinuTam;

  /// Above the results of a search in Hebrew that no verse holds as typed, when the same words with fewer ו and י, as the Torah often spells them (אהרן for אהרון, כהן for כוהן), were found instead. query is what the reader typed; variant is the Torah's spelling whose verses are shown.
  ///
  /// In en, this message translates to:
  /// **'No verse has “{query}”. Showing “{variant}”, as the Torah spells it.'**
  String searchSpellingFallback(String query, String variant);

  /// On the Texts & sources page, under Sunrise and sunset: how Shabbat times are worked out, their defaults, and the choices Settings offers.
  ///
  /// In en, this message translates to:
  /// **'Worked out on the device with the formulas of the NOAA Solar Calculator (after Meeus, Astronomical Algorithms), and checked against Hebcal, whose times are the default: candles lit 18 minutes before sunset, 20 in Israel, 40 in Jerusalem and 30 in Haifa and Zikhron Ya’akov, and Shabbat ending when the sun is 8.5° below the horizon. In Settings, under Reading & customs, candles can be lit at other minutes, and Shabbat can end 42, 50 or 72 minutes after sunset, as a local luach has them.'**
  String get sourcesSunDescription;
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
