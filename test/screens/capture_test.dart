// Renders every main screen with the app's real fonts and writes PNGs to
// build/screens/, for visual review without a web build:
//
//   CAPTURE=1 flutter test test/screens/capture_test.dart
//   CAPTURE=1 SCREENS=today,reader flutter test test/screens/capture_test.dart
//   CAPTURE=1 SCREENS=today MODES=sepia,hcl flutter test test/screens/capture_test.dart
//
// Skipped unless CAPTURE is set, so it never runs (or fails) in CI.
@Tags(['screens'])
library;

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/data/models/parsha.dart';
import 'package:shnayim_mikra/features/community/data/demo_forum_repository.dart';
import 'package:shnayim_mikra/features/community/data/forum_repository.dart';
import 'package:shnayim_mikra/features/community/data/models.dart';
import 'package:shnayim_mikra/features/community/ui/thread_screen.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikra/features/progress/domain/reading_plan.dart';
import 'package:shnayim_mikra/features/reader/reader_screen.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/features/settings/backup.dart';
import 'package:shnayim_mikra/services/backup_files.dart';
import 'package:shnayim_mikra/ui/theme/focus.dart';
import 'package:shnayim_mikra/ui/widgets/common.dart';
import 'package:shnayim_mikra/ui/widgets/paper_group.dart';
import 'package:shnayim_mikra/ui/widgets/progress_widgets.dart';

import '../fake_backup_files.dart';
import '../helpers.dart';
import 'galleries.dart';

final _capture = Platform.environment['CAPTURE'] != null;
final _only = Platform.environment['SCREENS']?.split(',').toSet();
final _onlyModes = Platform.environment['MODES']?.split(',').toSet();

/// Friday 9 Oct 2026 (28 Tishrei 5787), the week of Bereshit. Sunday was
/// Simchat Torah in the Diaspora, so the reading week began on Monday.
final _now = DateTime(2026, 10, 9, 11);
final _join = LocalDate(2026, 10, 4);

ProgressState _progress() {
  final mon = LocalDate(2026, 10, 5);
  var w = WeekProgress(weekId: '5787:1');
  for (final p in ReadingPass.values) {
    w = w.withUnit(0, p, mon).withUnit(1, p, mon.addDays(1));
  }
  w = w.withUnit(2, ReadingPass.mikra1, mon.addDays(2)).withUnit(2, ReadingPass.mikra2, mon.addDays(2));
  return ProgressState(weeks: {'5787:1': w});
}

const _screens = {
  // A new reader's onboarding, with no join date or progress yet, on the
  // Friday of Bereshit; its plan step on the Wednesday too.
  'welcome': '/welcome',
  'welcome_location': '/welcome/location',
  // "Why we ask" open under the question.
  'welcome_why': '/welcome/location',
  'welcome_method': '/welcome/method',
  'welcome_plan': '/welcome/plan',
  'welcome_plan_midweek': '/welcome/plan',
  // "I already use Shnayim Mikra": the ways to restore, with an account's
  // backup to sign in to.
  'welcome_restore': '/welcome',
  // Signed in, while the account's backup comes in.
  'welcome_restoring': '/welcome',
  // A backup file chosen: what it holds, with nothing here to merge with.
  'welcome_import': '/welcome',
  'today': '/today',
  'today_divergence': '/today',
  'today_divergence_abroad': '/today',
  'today_haftarah_left': '/today',
  'today_yomtov_oneday': '/today',
  'today_yomtov_twoday': '/today',
  'today_joined_midweek': '/today',
  // Hoshana Rabbah in Israel, counting down to Simchat Torah.
  'today_simchat_torah': '/today',
  // The week of Pinchas after 17 Tammuz, with its special haftarah.
  'today_three_weeks': '/today',
  // Paused over the end of Bereshit, with its button to end the pause.
  'today_paused': '/today',
  'parsha': '/parsha',
  'browse': '/parsha/browse',
  'week': '/week/5787:1',
  // A week and its haftarah opened within a tab, under its navigation bar.
  'week_tab': '/today/week/5787:1',
  'haftarah_tab': '/parsha/haftarah/5787:1',
  'reader': '/read/5787:1/2',
  // Revi'i open after Rishon and Sheni, with Shlishi under way.
  'reader_chips': '/read/5787:1/3',
  // Shlishi of Matot-Masei (Numbers 32:1–19) read by section: the Targum
  // step of 32:1–4, with the third reading of 32:3.
  'reader_third': '/read/5787:42-43/2',
  // Shevi'i just finished, with Shlishi still under way.
  'reader_finished': '/read/5787:1/6',
  'reader_full': '/read/5787:1/2?mode=full',
  // The keyboard shortcuts, in the app and on the web.
  'reader_keys': '/read/5787:1/2',
  'reader_keys_web': '/read/5787:1/2',
  // The display sheet, scrolled to its line spacing.
  'reader_display': '/read/5787:1/2',
  // Yitro, the sixth aliyah: the Decalogue, with section gaps inside verses.
  'reader_gaps': '/read/5787:17/5?mode=full',
  'reader_gaps_spaced': '/read/5787:17/5?mode=full',
  // Focus mode, opened on the reader's place in Shlishi.
  'reader_focus': '/read/5787:1/2?mode=full',
  // Shlishi of Vayishlach with cantillation hidden: the dots written over
  // וישקהו (Genesis 33:4) stay.
  'reader_dots': '/read/5787:8/2?mode=full',
  // Rishon of Pinchas, as the scrolls write it: the small yod of פינחס
  // (Numbers 25:11), and the note on the broken vav of shalom.
  'reader_pinchas': '/read/5787:41/0?mode=full',
  'haftarah': '/haftarah/5787:1',
  // Bereshit's own haftarah after Machar Chodesh's: folded, and for Chabad
  // open, under the note that Chabad's haftarot are being verified.
  'haftarah_regular': '/haftarah/5787:1',
  'haftarah_chabad': '/haftarah/5787:1',
  'haftarah_chabad_regular': '/haftarah/5787:1',
  'progress': '/progress',
  'community': '/community',
  'forum': '/community/forum/parsha',
  'thread': '/community/thread/1',
  // An empty weekly thread, and the forum that lists it.
  'thread_weekly': '/community/thread/1000',
  'forum_weekly': '/community/forum/parsha',
  // Reporting a post, before a reason is chosen.
  'thread_report': '/community/thread/1',
  // A thread of 250 posts, open on its latest hundred, and at its end.
  'thread_long': '/community/thread/5000',
  'thread_long_end': '/community/thread/5000',
  // The week's Discuss button while its discussion opens.
  'week_discuss': '/week/5787:1',
  // Asked to confirm clearing the week's progress.
  'week_clear': '/week/5787:1',
  // Just refreshed from the app bar.
  'thread_refreshed': '/community/thread/1',
  'compose': '/community/new',
  // Its empty title field focused: the caret at the start of the UI's direction.
  'compose_focused': '/community/new',
  'account': '/community/account',
  // Just after "Email me a code".
  'account_code': '/community/account',
  'account_settings': '/settings/account',
  'account_sync': '/community/account',
  'settings': '/settings',
  's_reading': '/settings/reading',
  's_reading_changed': '/settings/reading',
  // Its customs: the second reading, the haftarah and the late window.
  's_reading_customs': '/settings/reading',
  // For Chabad: the last verse isn't repeated, as the switch says.
  's_reading_chabad': '/settings/reading',
  's_display': '/settings/display',
  's_fonts': '/settings/display',
  's_a11y': '/settings/accessibility',
  's_a11y_web': '/settings/accessibility',
  's_reminders': '/settings/reminders',
  // As on a phone, where reminders can be scheduled, with all three on.
  's_reminders_on': '/settings/reminders',
  's_data': '/settings/data',
  's_data_reset': '/settings/data',
  // A backup file chosen: what it holds, and whether to merge it.
  's_data_import': '/settings/data',
  // Pasting a backup, which can't be read.
  's_data_paste': '/settings/data',
  // The paste dialog as it opens: the field's label and instruction.
  's_data_paste_open': '/settings/data',
  // Choosing to replace the progress here with a backup: the confirm
  // dialog, with backup on.
  's_data_replace': '/settings/data',
  'about': '/settings/about',
  'guide': '/guide',
  // The special cases, Shabbat and the sources, at its end.
  'guide_end': '/guide',
  'sources': '/sources',
  'legal': '/legal/privacy',
  'legal_a11y': '/legal/accessibility',
  // Links that lead nowhere: a mistyped address, and a forum that is gone.
  'not_found': '/nope',
  'forum_missing': '/community/forum/xyz',
  // Keyboard focus on a control, to check the focus ring (§6.1).
  'focus_button': '/today',
  'focus_day': '/today',
  'focus_card': '/today',
  'focus_tile': '/progress',
  'focus_slider': '/settings/display',
  'focus_switch': '/settings/display',
  'focus_field': '/community/account',
  'focus_chip': '/read/5787:1/2',
  'focus_menu': '/week/5787:1',
  'focus_nav': '/today',
  'focus_segment': '/welcome',
  'focus_fab': '/community/forum/parsha',
  // Overlays (§6.19) and the app bar with content scrolled under it (§6.2).
  'menu': '/week/5787:1',
  'dialog': '/week/5787:1',
  'snackbar': '/week/5787:1',
  'sheet_date': '/week/5787:1',
  'dialog_date': '/week/5787:1',
  'sheet_display': '/read/5787:1/2',
  'scrolled': '/progress',
  // Shared widgets on pages of their own (galleries.dart), opened over Today.
  'kit_ornaments': '/today',
  'kit_rows': '/today',
  'kit_focus': '/today',
  'kit_progress': '/today',
  'kit_week': '/today',
  // The legends behind the info buttons, and the Torah map in every tile
  // state (see [_screenProgress]).
  'legend_week': '/progress',
  'legend_map': '/progress',
  'progress_map': '/progress',
};

/// Screens that need more than a route: extra settings, and a first tap once
/// the screen has loaded.
final _screenSettings = <String, AppSettings Function(AppSettings)>{
  'reader_focus': (s) => s.copyWith(focusMode: true, showTranslation: true),
  'reader_dots': (s) => s.copyWith(showTeamim: false),
  's_reminders_on': (s) => s.copyWith(dailyReminder: true, fridayReminder: true, checkInReminder: true),
  // Reading by section, so that 32:3 is read with the verses around it.
  'reader_third': (s) => s.copyWith(method: ReadingMethod.sectionBySection),
  // Reading by aliyah, so that one step finishes Shevi'i.
  'reader_finished': (s) => s.copyWith(method: ReadingMethod.aliyahByAliyah, repeatLastVerse: false),
  'focus_segment': (s) => s.copyWith(onboardingComplete: false),
  // A visitor to Israel who keeps two days of Yom Tov, after Pesach 5789:
  // Israel is a parsha ahead, and both pairs of portions are read together.
  'today_divergence': (s) => s.copyWith(readingSchedule: ReadingSchedule.israel, joinDate: LocalDate(2029, 4, 22)),
  // An Israeli abroad, the same day: Israel is a parsha ahead.
  'today_divergence_abroad': (s) =>
      s.copyWith(readingSchedule: ReadingSchedule.diaspora, oneDayYomTov: true, joinDate: LocalDate(2029, 4, 22)),
  // The widest word spacing, justified: the spaces around a section mark.
  'reader_gaps_spaced': (s) => s.copyWith(wordSpacing: 16, justify: true),
  // Tuesday of Noach: Bereshit is read, all but the haftarah, which counts.
  'today_haftarah_left': (s) => s.copyWith(haftarahRequired: true),
  // The Tuesday after Shavuot 5789 (Sunday and Monday, 20 and 21 May) on
  // Israel's reading: one day of Yom Tov kept, then two (a visitor).
  'today_yomtov_oneday': (s) =>
      s.copyWith(readingSchedule: ReadingSchedule.israel, oneDayYomTov: true, joinDate: LocalDate(2029, 5, 1)),
  'today_yomtov_twoday': (s) =>
      s.copyWith(readingSchedule: ReadingSchedule.israel, oneDayYomTov: false, joinDate: LocalDate(2029, 5, 1)),
  // Joined on the Wednesday of Bereshit: the days before have no reading.
  'today_joined_midweek': (s) => s.copyWith(joinDate: LocalDate(2026, 10, 7)),
  'today_simchat_torah': (s) =>
      s.copyWith(readingSchedule: ReadingSchedule.israel, oneDayYomTov: true, joinDate: LocalDate(2026, 9, 20)),
  'today_three_weeks': (s) => s.copyWith(joinDate: LocalDate(2027, 7, 18)),
  'haftarah_chabad': (s) => s.withNusach(HaftarahNusach.chabad),
  's_reading_chabad': (s) => s.withNusach(HaftarahNusach.chabad),
  'haftarah_chabad_regular': (s) => s.withNusach(HaftarahNusach.chabad),
};

/// Screens shown on another day, with another history: the Torah map in
/// every tile state, and the days and histories of [_screenSettings].
final _screenNow = <String, DateTime>{
  'progress_map': historyNow,
  'today_divergence': DateTime(2029, 4, 24, 11),
  'today_divergence_abroad': DateTime(2029, 4, 24, 11),
  'today_haftarah_left': DateTime(2026, 10, 13, 11),
  'today_yomtov_oneday': DateTime(2029, 5, 22, 11),
  'today_yomtov_twoday': DateTime(2029, 5, 22, 11),
  // Hoshana Rabbah 5787; Simchat Torah is on Shabbat in Israel.
  'today_simchat_torah': DateTime(2026, 10, 2, 11),
  // Tuesday of Pinchas 5787, read on 24 July 2027.
  'today_three_weeks': DateTime(2027, 7, 20, 11),
  // Tuesday of Matot-Masei 5787.
  'reader_third': DateTime(2027, 7, 27, 11),
  // The Wednesday of Bereshit, which began on Monday.
  'welcome_plan_midweek': DateTime(2026, 10, 7, 11),
};
final _screenProgress = <String, ProgressState Function()>{
  'progress_map': historyProgress,
  'today_haftarah_left': () => ProgressState(weeks: {
        '5787:1': WeekProgress(weekId: '5787:1').withAll(LocalDate(2026, 10, 9)),
      }),
  'today_joined_midweek': () => ProgressState(weeks: {}),
  'today_simchat_torah': () => ProgressState(weeks: {}),
  'today_three_weeks': () => ProgressState(weeks: {}),
  'today_paused': () => ProgressState(
        weeks: _progress().weeks,
        pauses: [Pause(LocalDate(2026, 10, 8), LocalDate(2026, 10, 18), id: 'travel')],
      ),
  // All three readings of Shlishi (from Genesis 2:20) have reached 3:1,
  // its seventh verse, where the guided reader resumes and focus mode opens.
  'reader_focus': () => ProgressState(weeks: {
        '5787:1': WeekProgress(weekId: '5787:1').withPosition(2, const [6, 6, 6]),
      }),
  // Both Hebrew readings of 32:1–4 done: the Targum is next.
  'reader_third': () => ProgressState(weeks: {
        '5787:42-43': WeekProgress(weekId: '5787:42-43').withPosition(2, const [4, 4, 0]),
      }),
  // All but Shlishi (two readings) and Shevi'i (all but the Targum) read.
  'reader_finished': () {
    final day = LocalDate(2026, 10, 8);
    var w = WeekProgress(weekId: '5787:1');
    for (final a in [0, 1, 3, 4, 5]) {
      w = w.withAliyah(a, day);
    }
    for (final a in [2, 6]) {
      w = w.withUnit(a, ReadingPass.mikra1, day).withUnit(a, ReadingPass.mikra2, day);
    }
    return ProgressState(weeks: {'5787:1': w.withPosition(6, const [16, 16, 0])});
  },
};

/// Screens shown as on the web, where the reader takes single keys.
const _webKeys = {'reader_keys_web', 's_a11y_web'};

/// Screens captured after typing into their only text field.
const _typed = {'account_code': 'reader@example.org'};

/// Screens shown signed in with backup on, where a newer version of the app
/// has written the backup, so syncing has stopped.
const _syncBlocked = {'account_sync'};

Future<ForumRepository> _accountWithNewerBackup() async {
  final repo = DemoForumRepository();
  await repo.verifyCode('reader@example.org', '123456');
  await repo.saveProgress({..._progress().toJson(), 'version': kProgressFormat + 1});
  return repo;
}

/// Screens shown signed in with backup on.
const _backupOn = {'s_data_reset', 's_data_replace'};

/// Screens where the reader chooses [_backupFile] to restore.
const _choosesBackup = {'s_data_import', 's_data_replace', 'welcome_import'};

/// A backup made on another phone on the Thursday of Bereshit: the last
/// eleven weeks of 5786 read, and a pause over Sukkot.
String _backupFile() {
  final first = LocalDate(2026, 7, 24);
  return encodeBackup(
    ProgressState(
      weeks: {
        for (var i = 0; i < 11; i++)
          '5786:${44 + i}': WeekProgress(weekId: '5786:${44 + i}').withAll(first.addDays(7 * i)),
      },
      pauses: [Pause(LocalDate(2026, 9, 27), LocalDate(2026, 10, 3), id: 'sukkot')],
    ),
    AppSettings(onboardingComplete: true, joinDate: LocalDate(2026, 7, 20)),
    now: DateTime(2026, 10, 8, 21),
  );
}

/// Screens shown where reminders are available.
const _remindersSupported = {'s_reminders_on'};

Future<ForumRepository> _signedIn() async {
  final repo = DemoForumRepository();
  await repo.verifyCode('reader@example.org', '123456');
  return repo;
}

/// Screens shown with another community than the plain demo.
final _communities = <String, Future<ForumRepository> Function()>{
  'thread_weekly': _withWeeklyThread,
  'forum_weekly': _withWeeklyThread,
  'thread_report': _signedIn,
  'thread_long': _withLongThread,
  'thread_long_end': _withLongThread,
  'week_discuss': () async => _OpeningForever(),
  'welcome_restore': () async => _Cloud(),
  'welcome_restoring': () async {
    final repo = _CloudForever();
    await repo.verifyCode('reader@example.org', '123456');
    return repo;
  },
};

/// The demo with a thread of 250 posts in Divrei Torah, thread 5000.
Future<ForumRepository> _withLongThread() async {
  const names = ['Avraham', 'Rivka', 'Yosef', 'Miriam', 'Shmuel'];
  const bodies = [
    'Rashi reads the verse as a promise rather than a command.',
    'Onkelos translates it the same way here as in the previous chapter.',
    'רמב״ן מקשה על כך מן הפסוק הבא.',
    'Thank you — I had never noticed that before.',
    'Which edition of the Targum are you reading from?',
  ];
  // On the clock that posts' relative times are told by.
  final now = DateTime.now();
  final start = now.subtract(const Duration(days: 20));
  return DemoForumRepository()
    ..seed(
      threads: [
        ThreadSummary(
          id: '5000',
          forumId: 3,
          title: 'The order of the blessings in Vayechi',
          kind: ThreadKind.discussion,
          authorName: names.first,
          postCount: 250,
          lastPostAt: now.subtract(const Duration(minutes: 20)),
          createdAt: start,
        ),
      ],
      posts: [
        for (var i = 0; i < 250; i++)
          Post(
            id: '${i + 1}',
            threadId: '5000',
            authorId: 'demo-${i % names.length}',
            authorName: names[i % names.length],
            body: bodies[i % bodies.length],
            createdAt: i == 249 ? now.subtract(const Duration(minutes: 20)) : start.add(Duration(hours: i)),
          ),
      ],
    );
}

/// The demo with the weekly thread of Bereshit 5787, thread 1000.
Future<ForumRepository> _withWeeklyThread() async {
  final repo = DemoForumRepository();
  await repo.weeklyThread(parshaNumber: 1, hebrewYear: 5787, title: 'Bereshit · בראשית · 5787');
  return repo;
}

/// The demo, standing in for a real community, which keeps backups.
class _Cloud extends DemoForumRepository {
  @override
  bool get isDemo => false;
}

/// A community whose backups never finish coming in.
class _CloudForever extends _Cloud {
  @override
  Future<Map<String, dynamic>?> loadProgress() => Completer<Map<String, dynamic>?>().future;
}

/// A community whose weekly threads never finish opening.
class _OpeningForever extends DemoForumRepository {
  @override
  Future<String> weeklyThread({required int parshaNumber, required int hebrewYear, required String title}) =>
      Completer<String>().future;
}

/// Screens captured just after tapping what the finder finds, to show the
/// response before it settles (a snackbar that has yet to leave).
final _taps = {
  // Choosing "All on Friday" says that it applies from this week on.
  's_reading_changed': () => find.byType(RadioListTile<ReadingPlanType>).last,
  'welcome_why': () => find.byIcon(Icons.expand_more),
  // Next, on the last step of Shevi'i.
  'reader_finished': () => find.byWidgetPredicate((w) => w is FilledButton).last,
  'week_discuss': () => find.widgetWithIcon(OutlinedButton, Icons.forum_outlined),
  'thread_refreshed': () => find.byIcon(Icons.refresh),
  'account_code': () => find.byType(FilledButton).first,
};

/// Taps what each finder finds in turn, settling after each.
Future<void> Function(WidgetTester) _tapInTurn(List<Finder Function()> steps) => (tester) async {
      for (final step in steps) {
        await tester.tap(step());
        await _settle(tester);
      }
    };

final _openShortcuts = _tapInTurn([
  () => find.descendant(of: find.byType(AppBar), matching: find.byType(PopupMenuButton<String>)),
  () => find.byWidgetPredicate((w) => w is PopupMenuItem<String> && w.value == 'keys'),
]);

Future<void> _showWeekStrip(WidgetTester tester) =>
    Scrollable.ensureVisible(tester.element(find.byType(WeekStrip)), alignment: 0.5);

Future<void> _scrollToEnd(WidgetTester tester) async {
  // A lazily built list only learns its full extent as it scrolls.
  for (var i = 0; i < 8; i++) {
    for (final s in tester.stateList<ScrollableState>(find.byType(Scrollable))) {
      if (s.position.axis == Axis.vertical) s.position.jumpTo(s.position.maxScrollExtent);
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
}

final _screenSetup = <String, Future<void> Function(WidgetTester)>{
  // The last post's menu, then Report.
  'thread_report': _tapInTurn([
    () => find.descendant(of: find.byType(PostCard).last, matching: find.byType(PopupMenuButton<String>)),
    () => find.byWidgetPredicate((w) => w is PopupMenuItem<String> && w.value == 'report'),
  ]),
  // The reader's menu, then Keyboard shortcuts.
  'reader_keys': _openShortcuts,
  'reader_keys_web': _openShortcuts,
  // The week's menu, then Clear.
  'week_clear': _tapInTurn([
    () => find.descendant(of: find.byType(AppBar), matching: find.byType(PopupMenuButton<String>)),
    () => find.byWidgetPredicate((w) => w is PopupMenuItem<String> && w.value == 'clear'),
  ]),
  // The display sheet, scrolled to its end.
  'reader_display': (tester) async {
    await tester.tap(find.byIcon(Icons.text_format));
    await _settle(tester);
    await _scrollToEnd(tester);
  },
  'reader_dots': _scrollToEnd,
  'reader_third': _scrollToEnd,
  // The haftarah, near the end of Today.
  'today_three_weeks': _scrollToEnd,
  'guide_end': _scrollToEnd,
  // The regular haftarah's heading, with the special one's end above it.
  'haftarah_regular': (tester) => _showRegularHaftarah(tester, alignment: 0.6),
  'haftarah_chabad_regular': (tester) => _showRegularHaftarah(tester, alignment: 0.3),
  's_reading_customs': (tester) =>
      Scrollable.ensureVisible(tester.element(find.byType(RadioListTile<ReadingMethod>).last)),
  's_reading_chabad': (tester) =>
      Scrollable.ensureVisible(tester.element(find.byType(SwitchListTile).first), alignment: 0.3),
  'thread_long_end': _scrollToEnd,
  'week_discuss': _scrollToEnd,
  // The interface font choices, at the end of the Display page.
  's_fonts': (tester) => tester.ensureVisible(find.byType(RadioListTile<UiFont>).last),
  'focus_button': (tester) => _keyboardFocus(tester, find.byType(FilledButton).first),
  'focus_day': (tester) =>
      _keyboardFocus(tester, find.descendant(of: find.byType(WeekStrip), matching: find.byType(SeferInkWell)).at(1)),
  'focus_card': (tester) => _keyboardFocus(tester, find.byWidgetPredicate((w) => w is InfoCard && w.onTap != null).first),
  // Noach: map tiles are the ink wells with 6 px corners.
  'focus_tile': (tester) => _keyboardFocus(
        tester,
        find
            .byWidgetPredicate((w) => w is SeferInkWell && w.borderRadius == const BorderRadius.all(Radius.circular(6)))
            .at(1),
      ),
  'focus_slider': (tester) => _keyboardFocus(tester, find.byType(Slider).first),
  'focus_switch': (tester) => _keyboardFocus(tester, find.byType(SwitchListTile).first),
  'focus_field': (tester) => _keyboardFocus(tester, find.byType(TextField).first),
  'compose_focused': (tester) => _keyboardFocus(tester, find.byWidgetPredicate((w) => w is TextField && w.maxLength == 150)),
  'focus_chip': (tester) => _keyboardFocus(tester, find.byType(ChoiceChip).at(1)),
  // A menu button inside a card, which clips: the ring must still show.
  'focus_menu': (tester) => _keyboardFocus(
        tester,
        find.descendant(of: find.byType(Card), matching: find.byType(PopupMenuButton<String>)).first,
      ),
  // The Parsha tab of the navigation bar or rail.
  'focus_nav': (tester) => _keyboardFocus(
        tester,
        find
            .ancestor(
              of: find.descendant(
                of: find.byWidgetPredicate((w) => w is NavigationBar || w is NavigationRail),
                matching: find.byIcon(Icons.menu_book_outlined),
              ),
              matching: find.byWidgetPredicate((w) => w is InkResponse),
            )
            .first,
      ),
  // The second segment of the language switch: the group is ringed, the
  // segment washed and underlined.
  'focus_segment': (tester) => _keyboardFocus(
        tester,
        find.descendant(of: find.byType(SegmentedButton<AppLanguage>), matching: find.byType(TextButton)).last,
      ),
  'focus_fab': (tester) => _keyboardFocus(tester, find.byType(FloatingActionButton)),
  'menu': (tester) => _openWeekMenu(tester),
  // The week menu: full text, mark the whole parsha, clear the week.
  'dialog': (tester) => _openWeekMenu(tester, item: 2),
  'snackbar': (tester) async {
    await _openWeekMenu(tester, item: 2);
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.byType(FilledButton)));
  },
  'sheet_date': (tester) => _openWeekMenu(tester, item: 1),
  'dialog_date': (tester) async {
    await _openWeekMenu(tester, item: 1);
    await tester.tap(find.byIcon(Icons.edit_calendar));
  },
  'sheet_display': (tester) => tester.tap(find.byIcon(Icons.text_format)),
  'scrolled': (tester) => tester.drag(find.byType(Scrollable).first, const Offset(0, -400)),
  'kit_ornaments': (tester) => _showGallery(tester, const OrnamentsGallery()),
  'kit_rows': (tester) => _showGallery(tester, const RowsGallery()),
  'kit_progress': (tester) => _showGallery(tester, const ProgressGallery()),
  'kit_week': (tester) => _showGallery(tester, const WeekGallery()),
  'legend_week': (tester) async {
    await tester.ensureVisible(find.byType(WeekStripLegendButton));
    await tester.tap(find.byType(WeekStripLegendButton));
  },
  // The map's info button is the page's last.
  'legend_map': (tester) async {
    await tester.ensureVisible(find.byIcon(Icons.info_outline).last);
    await tester.tap(find.byIcon(Icons.info_outline).last);
  },
  // The map's section heading at the top of the page.
  'progress_map': (tester) => Scrollable.ensureVisible(tester.element(find.byIcon(Icons.info_outline).last)),
  // The middle row of a paper group: its ring must clear the hairlines.
  'kit_focus': (tester) async {
    await _showGallery(tester, const RowsGallery());
    await _settle(tester);
    await _keyboardFocus(
      tester,
      find.descendant(of: find.byType(PaperGroup).first, matching: find.byType(SeferInkWell)).at(1),
    );
  },
  // The end of the main list: the spaces around section marks.
  'reader_gaps': _scrollToEnd,
  'reader_gaps_spaced': _scrollToEnd,
  // The restore sheet: the welcome's last text button.
  'welcome_restore': (tester) => tester.tap(find.byType(TextButton).last),
  'welcome_restoring': _tapInTurn([() => find.byType(TextButton).last, () => find.byType(ListTile).first]),
  // The reset dialog.
  's_data_reset': (tester) => tester.tap(find.byIcon(Icons.delete_forever_outlined)),
  's_data_import': (tester) => tester.tap(find.byIcon(Icons.download)),
  's_data_paste': _tapInTurn([
    () => find.byIcon(Icons.content_paste),
    () => find.byType(FilledButton),
  ]),
  's_data_paste_open': (tester) => tester.tap(find.byIcon(Icons.content_paste)),
  's_data_replace': _tapInTurn([
    () => find.byIcon(Icons.download),
    // "Replace instead", the dialog's last text button.
    () => find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextButton)).last,
  ]),
  'welcome_import': _tapInTurn([
    () => find.byType(TextButton).last,
    () => find.byIcon(Icons.restore_page_outlined),
  ]),
  // The week strip, in the middle of the page.
  'today_yomtov_oneday': _showWeekStrip,
  'today_yomtov_twoday': _showWeekStrip,
  'today_joined_midweek': _showWeekStrip,
};

/// Scrolls the haftarah page's regular haftarah heading to [alignment].
Future<void> _showRegularHaftarah(WidgetTester tester, {required double alignment}) => Scrollable.ensureVisible(
      tester.element(find.descendant(of: find.byType(ExpansionTile), matching: find.byType(ListTile))),
      alignment: alignment,
    );

/// Opens [gallery] as a page over the current route.
Future<void> _showGallery(WidgetTester tester, Widget gallery) async {
  unawaited(tester.state<NavigatorState>(find.byType(Navigator).first).push(
    MaterialPageRoute<void>(builder: (_) => gallery),
  ));
}

/// Opens the week overview's menu, and picks its [item] if one is given.
Future<void> _openWeekMenu(WidgetTester tester, {int? item}) async {
  await tester.tap(find.descendant(of: find.byType(AppBar), matching: find.byType(PopupMenuButton<String>)));
  await tester.pumpAndSettle();
  if (item != null) {
    await tester.tap(find.byType(PopupMenuItem<String>).at(item));
    await tester.pumpAndSettle();
  }
}

/// Moves keyboard focus to [target], as Tab would, and shows it the way a
/// keyboard user sees it.
Future<void> _keyboardFocus(WidgetTester tester, Finder target) async {
  FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
  addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
  // Centred, so the ring isn't cut off at the edge of the scroll view.
  await Scrollable.ensureVisible(tester.element(target), alignment: 0.5);
  await tester.pump();
  // The control's own focus node: the first one inside it that Tab can reach.
  final foci = find.descendant(of: target, matching: find.byType(Focus));
  final nodes = [
    for (var i = 0; i < foci.evaluate().length; i++)
      Focus.of(
        tester.element(find.descendant(of: foci.at(i), matching: find.byWidgetPredicate((_) => true)).first),
        createDependency: false,
      ),
  ];
  nodes.firstWhere((n) => n.canRequestFocus && !n.skipTraversal).requestFocus();
}

class _Mode {
  const _Mode(this.tag, this.size, this.settings, {this.textScale = 1});
  final String tag;
  final Size size;
  final AppSettings Function(AppSettings) settings;

  /// The system text size.
  final double textScale;
}

final _modes = [
  _Mode('phone', const Size(412, 915), (s) => s),
  _Mode('dark', const Size(412, 915), (s) => s.copyWith(theme: AppThemeMode.dark)),
  _Mode('he', const Size(412, 915), (s) => s.copyWith(language: AppLanguage.hebrew)),
  _Mode('hc', const Size(412, 915), (s) => s.copyWith(theme: AppThemeMode.highContrastDark)),
  _Mode('desktop', const Size(1366, 860), (s) => s),
  // The compact rail, and the extended rail in Hebrew and in high contrast.
  _Mode('tablet', const Size(800, 1180), (s) => s),
  _Mode('deskhe', const Size(1366, 860), (s) => s.copyWith(language: AppLanguage.hebrew)),
  _Mode('deskhc', const Size(1366, 860), (s) => s.copyWith(theme: AppThemeMode.highContrastDark)),
  _Mode('sepia', const Size(412, 915), (s) => s.copyWith(theme: AppThemeMode.sepia)),
  _Mode('hcl', const Size(412, 915), (s) => s.copyWith(theme: AppThemeMode.highContrastLight)),
  _Mode('lexend', const Size(412, 915), (s) => s.copyWith(uiFont: UiFont.lexend)),
  // Its Hebrew falls back to Noto Sans Hebrew, Medium where the role is.
  _Mode('lexhe', const Size(412, 915), (s) => s.copyWith(uiFont: UiFont.lexend, language: AppLanguage.hebrew)),
  // Long pages in full, for the screens in [_tallScreens].
  _Mode('phonetall', const Size(412, 2600), (s) => s),
  // System text at 200%, tall, for the screens in [_bigTextScreens].
  _Mode('big', const Size(412, 2600), (s) => s, textScale: 2),
  _Mode('bighe', const Size(412, 2600), (s) => s.copyWith(language: AppLanguage.hebrew), textScale: 2),
  // A 360 dp phone, tall, for the screens in [_narrowScreens].
  _Mode('narrow', const Size(360, 2600), (s) => s),
];

const _desktopScreens = {
  'today',
  'today_divergence',
  'today_haftarah_left',
  'today_yomtov_oneday',
  'week',
  'week_tab',
  'haftarah_tab',
  'haftarah_regular',
  'reader',
  'reader_third',
  'reader_finished',
  'reader_full',
  'reader_focus',
  'reader_keys',
  'reader_keys_web',
  'reader_gaps',
  'progress',
  'thread',
  'thread_long',
  'legal',
  'not_found',
  'settings',
  'welcome',
  'welcome_plan',
  'welcome_restore',
  'dialog',
  'sheet_display',
  'focus_nav',
  'kit_ornaments',
  'kit_rows',
  'kit_progress',
  'kit_week',
  'progress_map',
};
// The wide modes render only the screens above.
const _wideModes = {'desktop', 'tablet', 'deskhe', 'deskhc'};
const _tallScreens = {'today', 'parsha', 'week', 'progress', 's_display'};
const _bigTextModes = {'big', 'bighe'};
const _narrowScreens = {'today', 'today_paused', 'progress', 'progress_map', 'kit_week', 's_data_import'};
const _bigTextScreens = {
  'today',
  'today_paused',
  'welcome',
  'welcome_restore',
  's_data',
  's_data_import',
  'progress',
  'reader',
  'haftarah_regular',
  'kit_ornaments',
  'kit_rows',
  'kit_progress',
  'kit_week',
  'progress_map',
};

Future<void> _settle(WidgetTester tester) async {
  // Text assets load on real async I/O; spinners never "settle".
  for (var i = 0; i < 30; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _write(WidgetTester tester, String name) async {
  final view = tester.binding.renderViews.first;
  final layer = view.debugLayer! as OffsetLayer;
  final bytes = await tester.runAsync(() async {
    final image = await layer.toImage(view.paintBounds);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  });
  final file = File('build/screens/$name.png')..createSync(recursive: true);
  file.writeAsBytesSync(bytes!);
}

void main() {
  setUpAll(() async {
    if (_capture) await loadBundledFonts();
  });

  for (final mode in _modes) {
    if (!(_onlyModes?.contains(mode.tag) ?? true)) continue;
    for (final entry in _screens.entries) {
      if (_wideModes.contains(mode.tag) && !_desktopScreens.contains(entry.key)) continue;
      if (mode.tag == 'phonetall' && !_tallScreens.contains(entry.key)) continue;
      if (_bigTextModes.contains(mode.tag) && !_bigTextScreens.contains(entry.key)) continue;
      if (mode.tag == 'narrow' && !_narrowScreens.contains(entry.key)) continue;
      final only = _only;
      if (only != null && !only.contains(entry.key)) continue;
      testWidgets('${mode.tag} ${entry.key}', (tester) async {
        tester.view.physicalSize = mode.size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        tester.platformDispatcher.textScaleFactorTestValue = mode.textScale;
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        if (_webKeys.contains(entry.key)) {
          ReaderScreen.singleKeyPlatform = true;
          addTearDown(() => ReaderScreen.singleKeyPlatform = false);
        }
        // Soft shadows, as a device draws them; tests otherwise draw them as
        // solid lines. Restored before the test ends, as the binding checks.
        debugDisableShadows = false;
        try {
          final blocked = _syncBlocked.contains(entry.key);
          final onboarding = entry.key.startsWith('welcome');
          final base = (_screenSettings[entry.key] ?? (s) => s)(
            AppSettings(
              onboardingComplete: !onboarding,
              joinDate: onboarding ? null : _join,
              cloudSync: blocked || _backupOn.contains(entry.key),
            ),
          );
          final c = await pumpApp(
            tester,
            settings: mode.settings(base),
            now: _screenNow[entry.key] ?? _now,
            progress: onboarding ? const ProgressState() : (_screenProgress[entry.key] ?? _progress)(),
            forums: blocked
                ? await _accountWithNewerBackup()
                : (_backupOn.contains(entry.key) ? await _signedIn() : await _communities[entry.key]?.call()),
            notifications: _remindersSupported.contains(entry.key) ? PhoneNotifications() : null,
            overrides: [
              if (_choosesBackup.contains(entry.key))
                backupFilesProvider.overrideWithValue(FakeBackupFiles(file: _backupFile())),
            ],
          );
          c.read(routerProvider).go(entry.value);
          await _settle(tester);
          final setup = _screenSetup[entry.key];
          if (setup != null) {
            await setup(tester);
            await _settle(tester);
          }
          if (_typed[entry.key] case final text?) {
            await tester.enterText(find.byType(TextField), text);
            await tester.pump();
          }
          if (_taps[entry.key] case final target?) {
            await tester.tap(target());
            // Long enough for a snackbar to appear, not to leave again, and
            // for the focus to move where it is moved after a frame.
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 500));
            await tester.pump(const Duration(milliseconds: 200));
          }
          await _write(tester, '${mode.tag}_${entry.key}');
        } finally {
          debugDisableShadows = true;
        }
      }, skip: !_capture);
    }
  }
}
