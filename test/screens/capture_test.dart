// Renders every main screen with the app's real fonts and writes PNGs to
// build/screens/, for visual review without a web build:
//
//   CAPTURE=1 flutter test test/screens/capture_test.dart
//   CAPTURE=1 SCREENS=today,reader flutter test test/screens/capture_test.dart
//   CAPTURE=1 SCREENS=today MODES=sepia,hcl flutter test test/screens/capture_test.dart
//   CAPTURE=1 WORDS=1 MODES=big,bighe,huge,hugehe,hugetall,hugetallhe,hugewide flutter test test/screens/capture_test.dart
//
// WORDS=1 also lists every word broken across lines, in
// build/screens/broken_words.txt (remove it before a new run).
//
// Skipped unless CAPTURE is set, so it never runs (or fails) in CI.
@Tags(['screens'])
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shnayim_mikra/app/city_providers.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/core/calendar/city.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/core/calendar/parsha_schedule.dart';
import 'package:shnayim_mikra/core/calendar/zmanim.dart';
import 'package:shnayim_mikra/data/models/parsha.dart';
import 'package:shnayim_mikra/features/community/data/demo_forum_repository.dart';
import 'package:shnayim_mikra/features/community/data/forum_repository.dart';
import 'package:shnayim_mikra/features/community/data/models.dart';
import 'package:shnayim_mikra/features/community/ui/community_ui.dart';
import 'package:shnayim_mikra/features/community/ui/forum_screen.dart';
import 'package:shnayim_mikra/features/community/ui/thread_screen.dart';
import 'package:shnayim_mikra/features/parsha/week_context.dart';
import 'package:shnayim_mikra/features/parsha/week_overview_screen.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikra/features/progress/domain/reading_plan.dart';
import 'package:shnayim_mikra/features/reader/aliyah_ribbon.dart';
import 'package:shnayim_mikra/features/reader/reader_screen.dart';
import 'package:shnayim_mikra/features/reader/scripture_text.dart' show ChapterHeading, ScriptureVerse;
import 'package:shnayim_mikra/features/reader/whole_parsha.dart';
import 'package:shnayim_mikra/features/search/search_screen.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/features/settings/widgets/settings_widgets.dart';
import 'package:shnayim_mikra/features/settings/widgets/shabbat_times_setting.dart';
import 'package:shnayim_mikra/features/today/today_screen.dart';
import 'package:shnayim_mikra/l10n/app_localizations.dart';
import 'package:shnayim_mikra/ui/l10n.dart';
import 'package:shnayim_mikra/features/settings/backup.dart';
import 'package:shnayim_mikra/services/backup_files.dart';
import 'package:shnayim_mikra/services/tts.dart';
import 'package:shnayim_mikra/ui/theme/focus.dart';
import 'package:shnayim_mikra/ui/widgets/common.dart';
import 'package:shnayim_mikra/ui/widgets/paper_group.dart';
import 'package:shnayim_mikra/ui/widgets/progress_widgets.dart';
import 'package:shnayim_mikra/ui/widgets/sefer_choice_chip.dart';

import 'package:timezone/timezone.dart' as tz;

import '../fake_backup_files.dart';
import '../helpers.dart';
import 'galleries.dart';

final _capture = Platform.environment['CAPTURE'] != null;
final _only = Platform.environment['SCREENS']?.split(',').toSet();
final _onlyModes = Platform.environment['MODES']?.split(',').toSet();

/// Whether to list the words each capture breaks across lines, in
/// build/screens/broken_words.txt (WORDS=1): none should be.
final _words = Platform.environment['WORDS'] != null;

/// Friday 9 Oct 2026, the week of Bereshit, and its reader, with Shlishi
/// under way (test/helpers.dart). The goldens show the same.
final _now = captureNow;
final _join = captureJoinDate;
const _progress = captureProgress;

/// 5787 up to the week of Chukat and Balak: most parshiyot read in their
/// weeks, two begun and left, three not opened, and this week begun.
ProgressState _yearRead() {
  final weeks = cycleWeeks(const ParshaSchedule(israel: false), 5787);
  final read = <String, WeekProgress>{};
  for (var n = 1; n <= 40; n++) {
    final week = weeks[n]!;
    final id = weekIdFor(week.portion, week.occasion);
    if (const {9, 17, 30}.contains(n) || read.containsKey(id)) continue;
    final day = week.occasion.addDays(-1);
    final begun = const {21, 33}.contains(n) || n >= 39;
    read[id] = begun
        ? WeekProgress(weekId: id).withAliyah(0, week.start).withAliyah(1, week.start.addDays(1))
        : WeekProgress(weekId: id).withAll(day);
  }
  return ProgressState(weeks: read);
}

/// Week [id], whose first reading day is [first], read an aliyah a day,
/// with the last two on the fifth day, up to aliyah [upTo] (exclusive).
WeekProgress _readOnTheirDays(String id, LocalDate first, {int upTo = 7}) {
  var w = WeekProgress(weekId: id);
  for (var a = 0; a < upTo; a++) {
    w = w.withAliyah(a, first.addDays(a < 6 ? a : 4));
  }
  return w;
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
  // Joining on Tisha B'Av 5787, a quiet day: only Friday is left.
  'welcome_plan_tisha_bav': '/welcome/plan',
  // "I already use Shnayim Mikra": the ways to restore, with an account's
  // backup to sign in to.
  'welcome_restore': '/welcome',
  // Signed in, while the account's backup comes in.
  'welcome_restoring': '/welcome',
  // A backup file chosen: what it holds, with nothing here to merge with.
  'welcome_import': '/welcome',
  'today': '/today',
  // With a city for Shabbat times: on Erev Shabbat, candle-lighting there,
  // by the reader's luach (30 minutes before sunset, not Jerusalem's 40).
  'today_candles': '/today',
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
  // Friday afternoon: Erev Shabbat heads the title page.
  'today_afternoon': '/today',
  // Behind on the Thursday of Noach, and on Erev Rosh Hashanah 5789, whose
  // two days run into Shabbat: the catch-up line says so, rather than
  // "midweek". Then Erev Shabbat Bamidbar 5789, with Shavuot after it.
  'today_thursday': '/today',
  'today_erev_yomtov': '/today',
  'today_erev_shabbat_yomtov': '/today',
  // Logging from a Chumash: the aliyot due, each checked.
  'today_book': '/today',
  // Shabbat Bereshit, and the first day of Shavuot 5789 (a Sunday, before a
  // second day of Yom Tov): Today at rest.
  'today_shabbat': '/today',
  'today_yomtov': '/today',
  // Yom Kippur 5787, a Monday: its own greeting, not "Chag Sameach".
  'today_yom_kippur': '/today',
  // Friday evening after candle-lighting in Jerusalem: Shabbat has begun.
  'today_friday_night': '/today',
  // Bereshit complete on Friday, with its haftarah still to read; and as
  // its last aliyah is logged, the frame drawing itself.
  'today_complete': '/today',
  'today_completing': '/today',
  // The Monday after Shabbat Bereshit, half read: the check-in, and its
  // sheet.
  'today_checkin': '/today',
  'today_checkin_sheet': '/today',
  // Motzaei Shabbat Bereshit, after nightfall in Jerusalem: the check-in,
  // under a running head with Sunday's date, the reading day's.
  'today_motzaei_shabbat': '/today',
  // Wednesday of Noach: Bereshit can still be restored by doubling up.
  'today_restore': '/today',
  // The Monday after a pause that ended on Sunday: welcomed back.
  'today_pause_ended': '/today',
  // Friday of Noach, Wednesday missed: a grace day covered it.
  'today_grace': '/today',
  // Erev Tisha B'Av 5787, the day the reader joined.
  'today_erev_tisha_bav': '/today',
  // Tisha B'Av 5787, behind on Va'etchanan and with Devarim still open:
  // the fast heads the page, which invites no reading; and its week strip.
  'today_tisha_bav': '/today',
  'today_tisha_bav_week': '/today',
  'parsha': '/parsha',
  // Scrolled past its head: the app bar names the parsha.
  'parsha_scrolled': '/parsha',
  'browse': '/parsha/browse',
  // The Wednesday of Chukat and Balak, read together, most of the year read:
  // opened with this week in view.
  'browse_summer': '/parsha/browse',
  'week': '/week/5787:1',
  // Next week's, not yet open: a preview.
  'week_next': '/week/5787:2',
  // Two parshiyot read together, under one long name: Vayakhel-Pekudei in
  // 5786, a common year (5787 is a leap year, which reads them apart).
  'week_combined': '/week/5786:22-23',
  // A week and its haftarah opened within a tab, under its navigation bar.
  'week_tab': '/today/week/5787:1',
  'haftarah_tab': '/parsha/haftarah/5787:1',
  'reader': '/read/5787:1/2',
  // Next week's, not yet open: the notice at the top of the text.
  'reader_preview': '/read/5787:2/0',
  // Revi'i open after Rishon and Sheni, with Shlishi under way.
  'reader_ribbon': '/read/5787:1/3',
  // Chamishi of Acharei Mot-Kedoshim (5786), the longest title the reader's
  // app bar sets.
  'reader_long': '/read/5786:29-30/4',
  // Shlishi of Matot-Masei (Numbers 32:1–19) read by section: the Targum
  // step of 32:1–4, with the third reading of 32:3.
  'reader_third': '/read/5787:42-43/2',
  // Shevi'i just finished, with Shlishi still under way.
  'reader_finished': '/read/5787:1/6',
  // The reader's first aliyah ever, Rishon, just finished: the offer of
  // reminders, with a routine chosen.
  'reader_offer': '/read/5787:1/0',
  // Its first routine chosen, and Yes: the list of cities offered.
  'reader_offer_city': '/read/5787:1/0',
  // Shlishi just finished on Friday, with Friday's own aliyot still to read:
  // on to Revi'i.
  'reader_finished_next': '/read/5787:1/2',
  // Shlishi just finished on Wednesday, the day's reading: Done, or keep
  // going.
  'reader_finished_day': '/read/5787:1/2',
  // Shishi just finished on Friday, with Shevi'i left for Shabbat morning.
  'reader_finished_erev': '/read/5787:1/5',
  // Shevi'i just finished on Friday, the rest read: the parsha, on time.
  'reader_finished_week': '/read/5787:1/6',
  'reader_full': '/read/5787:1/2?mode=full',
  // Its end, with the button that marks the aliyah read.
  'reader_full_end': '/read/5787:1/2?mode=full',
  // With the translation: beneath the verse, or in parallel columns after it
  // in its column, the Targum beside it.
  'reader_full_english': '/read/5787:1/2?mode=full',
  // Rashi read in the Targum's place, with the translation: the translation
  // beside the verse in parallel columns.
  'reader_full_rashi_english': '/read/5787:1/2?mode=full',
  // The whole parsha, opened at Shlishi: its heading at the top.
  'reader_parsha': '/read/5787:1/2?mode=full',
  // Read on into Shlishi, its heading kept at the top.
  'reader_parsha_pinned': '/read/5787:1/2?mode=full',
  // The end of Shlishi and the start of Revi'i: the button that marks
  // Shlishi read, then Revi'i's heading.
  'reader_parsha_join': '/read/5787:1/2?mode=full',
  // The parsha's end, Shevi'i read.
  'reader_parsha_end': '/read/5787:1/2?mode=full',
  // In focus mode, read on from Shlishi into Revi'i.
  'reader_parsha_focus': '/read/5787:1/2?mode=full',
  // The reader's menu in the full text: the whole parsha.
  'reader_parsha_menu': '/read/5787:1/2?mode=full',
  // The display sheet with the switch for parallel columns, on a wide screen.
  'reader_display_side': '/read/5787:1/2?mode=full',
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
  // The guided reader at a chapter's start (Genesis 3:1), and reading by
  // section: the verses up to a petuchah, and its mark.
  'reader_chapter': '/read/5787:1/2',
  'reader_section': '/read/5787:1/2',
  // Rashi beside the full text, in square letters and in Rashi script, and
  // read in the Targum's place in the guided reader.
  'reader_rashi': '/read/5787:1/2?mode=full',
  'reader_rashi_script': '/read/5787:1/2?mode=full',
  'reader_rashi_step': '/read/5787:1/2',
  // Shlishi of Vayishlach with cantillation hidden: the dots written over
  // וישקהו (Genesis 33:4) stay.
  'reader_dots': '/read/5787:8/2?mode=full',
  // The opt-in scripture fonts, which load on demand.
  'reader_taamey': '/read/5787:1/2?mode=full',
  'reader_ezra': '/read/5787:1/2?mode=full',
  // Rishon of Pinchas, as the scrolls write it: the small yod of פינחס
  // (Numbers 25:11), and the note on the broken vav of shalom.
  'reader_pinchas': '/read/5787:41/0?mode=full',
  // Listen, two verses on: in the guided reader, by section, and in the full
  // text, where each verse is read with its Targum; then paused there, in
  // focus mode, and the menu of speech rates.
  'reader_listen': '/read/5787:1/2',
  'reader_listen_full': '/read/5787:1/2?mode=full',
  'reader_listen_paused': '/read/5787:1/2?mode=full',
  'reader_listen_focus': '/read/5787:1/2?mode=full',
  'reader_listen_rate': '/read/5787:1/2?mode=full',
  // The haftarah read aloud, on its own and within its tab.
  'haftarah_listen': '/haftarah/5787:1',
  'haftarah_tab_listen': '/parsha/haftarah/5787:1',
  'haftarah': '/haftarah/5787:1',
  // Bereshit's own haftarah after Machar Chodesh's: folded, and for Chabad
  // open, under the note that Chabad's haftarot are being verified.
  'haftarah_regular': '/haftarah/5787:1',
  'haftarah_chabad': '/haftarah/5787:1',
  'haftarah_chabad_regular': '/haftarah/5787:1',
  // Nitzavim-Vayeilech 5786's (Isaiah 61:10–63:9): the head of its last
  // chapter, and its end, with the divider and the button. Then Bereshit's
  // once it is read.
  'haftarah_chapter': '/haftarah/5786:51-52',
  'haftarah_end': '/haftarah/5786:51-52',
  'haftarah_read': '/haftarah/5787:1',
  // Shabbat Shuva with Ha'azinu 5787: Hosea, then Joel.
  'haftarah_books': '/haftarah/5786:53',
  // A book of the Torah just finished: Genesis, in the cycle of 5787.
  'celebrate': '/celebrate/sefer:5787:0',
  'progress': '/progress',
  'community': '/community',
  'forum': '/community/forum/parsha',
  'thread': '/community/thread/1',
  // An empty weekly thread, and the forum that lists it.
  'thread_weekly': '/community/thread/1000',
  'forum_weekly': '/community/forum/parsha',
  // Signed in as a moderator: the initial on the account button, and the
  // reports to review.
  'community_member': '/community',
  // This week's discussion, opened from its card, with the posts the demo
  // starts it with.
  'thread_this_week': '/community',
  // Forums in both languages, one with a locked discussion, and one with
  // none at all.
  'forum_questions': '/community/forum/questions',
  'forum_feedback': '/community/forum/feedback',
  'forum_empty': '/community/forum/divrei-torah',
  // Offline: a forum's threads, a discussion's posts and the reports that
  // can't load, each said in the page's column.
  'forum_error': '/community/forum/questions',
  'thread_error': '/community/thread/1',
  'moderation_error': '/community/moderation',
  // Offline before the forums came: the Community page, a forum opened from
  // a link, and the blocked members of an account.
  'community_error': '/community',
  'forum_unreachable': '/community/forum/questions',
  'account_blocked_error': '/community/account',
  // What the Demo tag explains.
  'demo_about': '/community/forum/questions',
  // Reporting a post, before a reason is chosen.
  'thread_report': '/community/thread/1',
  // Letters that quote the posts they answer, and the member who began the
  // discussion answering under an Author tag.
  'thread_letters': '/community/thread/11',
  // A discussion in Hebrew.
  'thread_hebrew': '/community/thread/12',
  // Answering a post: the strip above the reply box, and the reply typed.
  'thread_replying': '/community/thread/1',
  // Signed in, under your own post: its thanks counted, with no button.
  'thread_mine': '/community/thread/1',
  // Editing that post: its field, with no counter until near the limit.
  'thread_edit': '/community/thread/1',
  // Locked: no reply box, and no Reply under the posts.
  'thread_locked': '/community/thread/51',
  // A thread of 250 posts, open on its latest hundred, and at its end.
  'thread_long': '/community/thread/5000',
  'thread_long_end': '/community/thread/5000',
  // The week's Discuss button while its discussion opens.
  'week_discuss': '/week/5787:1',
  // Asked to confirm clearing the week's progress.
  'week_clear': '/week/5787:1',
  // Just refreshed from the app bar: the message above the reply box, and
  // above the button that begins a discussion.
  'thread_refreshed': '/community/thread/1',
  'forum_refreshed': '/community/forum/questions',
  'compose': '/community/new',
  // Its empty title field focused: the caret at the start of the UI's direction.
  'compose_focused': '/community/new',
  // Post pressed with nothing written: what each field needs.
  'compose_errors': '/community/new',
  // A member with a name, who has accepted the guidelines, near the
  // title's limit: signed with their name, and its counter shown.
  'compose_member': '/community/new',
  'account': '/community/account',
  // Just after "Email me a code".
  'account_code': '/community/account',
  // Three digits, then Sign in: the code's error under its boxes.
  'account_code_error': '/community/account',
  // Signed in to post, with a machine's name: the name step.
  'account_name': '/community/account?then=back',
  // A moderator with a name, who has blocked a member; the name's dialog,
  // and the blocked members.
  'account_member': '/community/account',
  'account_edit': '/community/account',
  'account_blocked': '/community/account',
  // Delete my account: what goes with it, and a backup file first.
  'account_delete': '/community/account',
  // Keyboard focus on the privacy link in its sentence.
  'focus_link': '/community/account',
  'account_settings': '/settings/account',
  'account_sync': '/community/account',
  // Backup on, with notes too long for the server: why nothing is sent.
  'account_sync_large': '/community/account',
  'settings': '/settings',
  // The language, chosen in a sheet.
  'settings_language': '/settings',
  's_reading': '/settings/reading',
  's_reading_changed': '/settings/reading',
  // Its end: the haftarah, special days and parsha names.
  's_reading_end': '/settings/reading',
  // The city for Shabbat times, and its list: as it opens, searched, and
  // searched for a place that isn't there. The page itself has Jerusalem,
  // at its own minutes; here the reader's luach sets its times.
  's_reading_city': '/settings/reading',
  // The luach's candle-lighting minutes and end of Shabbat, chosen in
  // sheets; and in a week whose Shabbat runs into Yom Tov (Shavuot 5789).
  's_reading_candles': '/settings/reading',
  's_reading_havdalah': '/settings/reading',
  's_reading_yomtov': '/settings/reading',
  'city': '/settings/reading/city',
  'city_search': '/settings/reading/city',
  'city_many': '/settings/reading/city',
  'city_none': '/settings/reading/city',
  // The list of cities, which failed to load.
  'city_error': '/settings/reading/city',
  // Its customs: the second reading, the haftarah and the late window.
  's_reading_customs': '/settings/reading',
  // For Chabad: the last verse isn't repeated, as the switch says.
  's_reading_chabad': '/settings/reading',
  's_display': '/settings/display',
  // Scrolled to the sliders: the preview held at the top, shrunk.
  's_display_scrolled': '/settings/display',
  // The preview at a small size, whole, in focus mode with a theme chosen.
  's_display_small': '/settings/display',
  's_fonts': '/settings/display',
  // With Rashi shown: the switch for Rashi script, in view.
  's_display_rashi': '/settings/display',
  's_a11y': '/settings/accessibility',
  // Large print in force, then Low vision just applied, with its Undo.
  's_a11y_active': '/settings/accessibility',
  's_a11y_undo': '/settings/accessibility',
  // Low vision applied from the keyboard: its Undo stays, with Close.
  's_a11y_undo_keys': '/settings/accessibility',
  's_a11y_web': '/settings/accessibility',
  // The device's Reduce motion and Bold text on: the switches show them.
  's_a11y_device': '/settings/accessibility',
  's_display_device': '/settings/display',
  // Scrolled to Speech, the rate set faster than normal.
  's_a11y_speech': '/settings/accessibility',
  's_reminders': '/settings/reminders',
  // As on a phone, where reminders can be scheduled, with all three on.
  's_reminders_on': '/settings/reminders',
  // Turning the daily reminder on where the OS has refused notifications.
  's_reminders_denied': '/settings/reminders',
  // Turning the first reminder on without a city: the list of cities offered.
  's_reminders_offer': '/settings/reminders',
  // All three on, following the Shabbat times of the city chosen.
  's_reminders_city': '/settings/reminders',
  // A daily reminder at 8 PM after Shacharit: the offer to move it to 7:30.
  's_reminders_far': '/settings/reminders',
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
  'sources': '/sources',
  'guide': '/guide',
  // The special cases, Shabbat and the sources, at its end; and with Bold
  // text, where each case's lead-in stands on a line of its own.
  'guide_end': '/guide',
  'guide_end_bold': '/guide',
  // The privacy policy, open to every visitor; and at its end, the way to
  // reach us.
  'legal': '/legal/privacy',
  'legal_end': '/legal/privacy',
  'legal_a11y': '/legal/accessibility',
  // Links that lead nowhere: a mistyped address, and a forum that is gone.
  'not_found': '/nope',
  'forum_missing': '/community/forum/xyz',
  // Search: the index being built the first time, then the page as it
  // opens, a phrase, a word in many verses, a word found only in the
  // Targum, English, a word the Torah has in no spelling, and one it spells
  // with fewer ו and י, whose verses are shown.
  'search_preparing': '/search',
  'search': '/search',
  'search_results': '/search',
  'search_many': '/search',
  'search_targum': '/search',
  'search_english': '/search',
  'search_none': '/search',
  'search_spelling': '/search',
  // Go to verse, from the Parsha tab's search button: as it opens, a verse
  // found, one past the end of its chapter, and words to search for. Then
  // the verse in the reader, and in focus mode.
  'goto': '/parsha',
  'goto_verse': '/parsha',
  'goto_missing': '/parsha',
  'goto_words': '/parsha',
  'goto_phrase': '/parsha',
  'goto_help': '/parsha',
  'reader_verse': '/read/5787:1/2?verse=3:8',
  'reader_verse_focus': '/read/5787:1/2?verse=3:8',
  // A long press on Genesis 3:22, Revi'i's first verse, and on the
  // haftarah's first: what can be done with it.
  'reader_verse_actions': '/read/5787:1/3',
  'haftarah_verse_actions': '/haftarah/5787:1',
  // Bookmarks and notes (see [_annotations]): marked after the verse number
  // in the guided reader and in the full text; Genesis 3:22's options, with
  // its bookmark and note, and its note open; the list of every verse
  // marked, of Bereshit's, and of none; and the row on the week's page.
  'reader_marks': '/read/5787:1/3',
  'reader_full_marks': '/read/5787:1/3?mode=full',
  'reader_verse_actions_marked': '/read/5787:1/3',
  'note_dialog': '/read/5787:1/3',
  'notes': '/notes',
  'notes_parsha': '/notes?week=5787:1',
  'notes_empty': '/notes',
  'week_notes': '/week/5787:1',
  // "Ask about this verse": the question begun over the reader, and a draft
  // kept instead; then posted, back in the reader.
  'compose_verse': '/read/5787:1/3',
  'compose_verse_draft': '/read/5787:1/3',
  'compose_verse_posted': '/read/5787:1/3',
  // Keyboard focus on a control, to check the focus ring (§6.1).
  'focus_button': '/today',
  'focus_day': '/today',
  'focus_card': '/today',
  // A source's card, and the link to reach us in the privacy policy.
  'focus_source': '/sources',
  'focus_contact': '/legal/privacy',
  'focus_tile': '/progress',
  'focus_slider': '/settings/display',
  'focus_switch': '/settings/display',
  'focus_field': '/community/account',
  'focus_tab': '/read/5787:1/2',
  'focus_menu': '/week/5787:1',
  // The week's menu, opened from the keyboard, its second item focused.
  'focus_menu_item': '/week/5787:1',
  // A tile in the check-in's sheet (ringed inside), and in the import
  // dialog (ringed outside, its text being at its edge).
  'focus_sheet_tile': '/today',
  'focus_dialog_tile': '/settings/data',
  'focus_nav': '/today',
  // Today's tab, the selected one: at the very top of the rail, which
  // scrolls in a short window.
  'focus_nav_today': '/today',
  'focus_segment': '/welcome',
  'focus_fab': '/community/forum/parsha',
  'focus_thread': '/community/forum/questions',
  'focus_demo_tag': '/community/forum/questions',
  // Overlays (§6.19) and the app bar with content scrolled under it (§6.2).
  'menu': '/week/5787:1',
  'dialog': '/week/5787:1',
  'snackbar': '/week/5787:1',
  'sheet_date': '/week/5787:1',
  'dialog_date': '/week/5787:1',
  'sheet_display': '/read/5787:1/2',
  // Drawn up to its full height.
  'sheet_display_full': '/read/5787:1/2',
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
  // Progress paused, and asked how long to extend the pause.
  'progress_paused': '/progress',
  'progress_extend': '/progress',
  // The sheet behind the grace row's "About streaks".
  'progress_about': '/progress',
  // A reader in their second year (see [_secondYear]): the year chips, last
  // year chosen, and what they have finished so far at the page's end.
  'progress_years': '/progress',
  'progress_past': '/progress',
  'progress_record': '/progress',
};

/// Screens that need more than a route: extra settings, and a first tap once
/// the screen has loaded.
final _screenSettings = <String, AppSettings Function(AppSettings)>{
  'reader_focus': (s) => s.copyWith(focusMode: true, showTranslation: true),
  'reader_full_english': (s) => s.copyWith(showTranslation: true),
  'reader_full_rashi_english': (s) => s.copyWith(showTranslation: true, secondReading: SecondReading.rashi),
  for (final screen in ['reader_parsha', 'reader_parsha_pinned', 'reader_parsha_join', 'reader_parsha_end'])
    screen: (s) => s.copyWith(fullTextWholeParsha: true),
  'reader_parsha_focus': (s) => s.copyWith(fullTextWholeParsha: true, focusMode: true),
  'reader_section': (s) => s.copyWith(method: ReadingMethod.sectionBySection),
  'reader_rashi': (s) => s.copyWith(showRashi: true),
  'reader_rashi_script': (s) => s.copyWith(showRashi: true, rashiScript: true),
  'reader_rashi_step': (s) => s.copyWith(secondReading: SecondReading.rashi),
  's_display_small': (s) => s.copyWith(readingScale: 0.6, focusMode: true, theme: AppThemeMode.sepia),
  's_display_rashi': (s) => s.copyWith(showRashi: true),
  's_a11y_active': (s) => applyPreset(s, DisplayPreset.largePrint, darkPreferred: false),
  's_a11y_speech': (s) => s.copyWith(speechRate: 0.65),
  'reader_dots': (s) => s.copyWith(showTeamim: false),
  'guide_end_bold': (s) => s.copyWith(boldText: true),
  's_reminders_on': (s) => s.copyWith(
        dailyReminder: true,
        dailyReminderMinutes: 7 * 60 + 30,
        fridayReminder: true,
        checkInReminder: true,
        habitAnchor: HabitAnchor.shacharit,
      ),
  's_reminders_far': (s) =>
      s.copyWith(dailyReminder: true, dailyReminderMinutes: 20 * 60, habitAnchor: HabitAnchor.shacharit),
  'reader_offer': (s) => s.copyWith(method: ReadingMethod.aliyahByAliyah),
  'reader_offer_city': (s) => s.copyWith(method: ReadingMethod.aliyahByAliyah),
  // Reading by section, so that 32:3 is read with the verses around it.
  'reader_third': (s) => s.copyWith(method: ReadingMethod.sectionBySection),
  // Reading by aliyah, so that one step finishes the aliyah. Set as the
  // reader sets it: untouched, the repeat follows the haftarah custom.
  'reader_finished': (s) => s.copyWith(method: ReadingMethod.aliyahByAliyah).withRepeatLastVerse(false),
  'reader_finished_next': (s) => s.copyWith(method: ReadingMethod.aliyahByAliyah),
  'reader_finished_day': (s) => s.copyWith(method: ReadingMethod.aliyahByAliyah),
  'reader_finished_erev': (s) => s.copyWith(method: ReadingMethod.aliyahByAliyah, plan: ReadingPlanType.sheviiOnShabbat),
  'reader_finished_week': (s) => s.copyWith(method: ReadingMethod.aliyahByAliyah).withRepeatLastVerse(false),
  'reader_verse_focus': (s) => s.copyWith(focusMode: true, showTranslation: true),
  'reader_listen': (s) => s.copyWith(method: ReadingMethod.sectionBySection),
  'reader_listen_focus': (s) => s.copyWith(focusMode: true),
  'focus_segment': (s) => s.copyWith(onboardingComplete: false),
  // A visitor to Israel who keeps two days of Yom Tov, after Pesach 5789:
  // Israel is a parsha ahead, and both pairs of portions are read together.
  'today_divergence': (s) => s.copyWith(readingSchedule: ReadingSchedule.israel, joinDate: LocalDate(2029, 4, 22)),
  // An Israeli abroad, the same day: Israel is a parsha ahead.
  'today_divergence_abroad': (s) =>
      s.copyWith(readingSchedule: ReadingSchedule.diaspora, oneDayYomTov: true, joinDate: LocalDate(2029, 4, 22)),
  // The widest word spacing, justified: the spaces around a section mark.
  'reader_gaps_spaced': (s) => s.copyWith(wordSpacing: 16, justify: true),
  'reader_taamey': (s) => s.copyWith(scriptureFont: ScriptureFont.taameyFrank),
  'reader_ezra': (s) => s.copyWith(scriptureFont: ScriptureFont.ezra),
  // Tuesday of Noach: Bereshit is read, all but the haftarah, which counts.
  // The check-in, answered on Sunday, gives way to the open week's notice.
  'today_haftarah_left': (s) => s.copyWith(haftarahRequired: true, checkInAnsweredFor: '5787:1'),
  // The Tuesday after Shavuot 5789 (Sunday and Monday, 20 and 21 May) on
  // Israel's reading: one day of Yom Tov kept, then two (a visitor).
  'today_yomtov_oneday': (s) =>
      s.copyWith(readingSchedule: ReadingSchedule.israel, oneDayYomTov: true, joinDate: LocalDate(2029, 5, 1)),
  'today_yomtov_twoday': (s) =>
      s.copyWith(readingSchedule: ReadingSchedule.israel, oneDayYomTov: false, joinDate: LocalDate(2029, 5, 1)),
  // Joined on the Wednesday of Bereshit: the days before have no reading.
  'today_joined_midweek': (s) => s.copyWith(joinDate: LocalDate(2026, 10, 7)),
  for (final screen in ['progress_years', 'progress_past', 'progress_record'])
    screen: (s) => s.copyWith(joinDate: secondYearJoinDate),
  's_reading': (s) => s.copyWith(city: _jerusalem),
  's_reading_city': (s) => s.copyWith(city: _jerusalem, candleMinutesOverride: 30, havdalah: HavdalahRule.min72),
  's_reading_candles': (s) => s.copyWith(city: _jerusalem, candleMinutesOverride: 30),
  's_reading_havdalah': (s) => s.copyWith(city: _jerusalem, havdalah: HavdalahRule.min72),
  's_reading_yomtov': (s) => s.copyWith(city: _jerusalem, joinDate: LocalDate(2029, 5, 1)),
  'today_candles': (s) => s.copyWith(city: _jerusalem, candleMinutesOverride: 30),
  's_reminders_city': (s) => s.copyWith(
        dailyReminder: true,
        dailyReminderMinutes: 7 * 60 + 30,
        fridayReminder: true,
        checkInReminder: true,
        habitAnchor: HabitAnchor.shacharit,
        city: _jerusalem,
      ),
  'city': (s) => s.copyWith(city: _jerusalem),
  'city_search': (s) => s.copyWith(city: _jerusalem),
  'city_many': (s) => s.copyWith(city: _jerusalem),
  'today_simchat_torah': (s) =>
      s.copyWith(readingSchedule: ReadingSchedule.israel, oneDayYomTov: true, joinDate: LocalDate(2026, 9, 20)),
  'today_three_weeks': (s) => s.copyWith(joinDate: LocalDate(2027, 7, 18)),
  'today_erev_yomtov': (s) => s.copyWith(joinDate: LocalDate(2028, 9, 1)),
  'today_erev_shabbat_yomtov': (s) => s.copyWith(joinDate: LocalDate(2029, 5, 1)),
  'today_yomtov': (s) => s.copyWith(joinDate: LocalDate(2029, 5, 1)),
  'today_yom_kippur': (s) => s.copyWith(joinDate: LocalDate(2026, 9, 1)),
  'today_friday_night': (s) => s.copyWith(city: _jerusalem),
  'today_motzaei_shabbat': (s) => s.copyWith(city: _jerusalem),
  'today_erev_tisha_bav': (s) => s.copyWith(joinDate: LocalDate(2027, 8, 11)),
  for (final screen in ['today_tisha_bav', 'today_tisha_bav_week'])
    screen: (s) => s.copyWith(joinDate: LocalDate(2027, 8, 1)),
  'haftarah_chabad': (s) => s.withNusach(HaftarahNusach.chabad),
  's_reading_chabad': (s) => s.withNusach(HaftarahNusach.chabad),
  'haftarah_chabad_regular': (s) => s.withNusach(HaftarahNusach.chabad),
};

const _jerusalem = City(
  id: 281184,
  nameEn: 'Jerusalem',
  nameHe: 'ירושלים',
  countryCode: 'IL',
  latitude: 31.769,
  longitude: 35.2163,
  timeZone: 'Asia/Jerusalem',
  candleMinutes: 40,
);

/// Providers replaced for a screen: the device's time zone, which suggests
/// cities, and the time zones loaded, as the app loads them once its first
/// frame is up (which tests never report).
final _screenOverrides = <String, List<Override>>{
  for (final screen in ['city', 'city_search', 'city_many', 'city_none'])
    screen: [deviceTimeZoneProvider.overrideWith((ref) async => 'Asia/Jerusalem')],
  for (final screen in ['today_candles', 'today_friday_night', 'today_motzaei_shabbat'])
    screen: [
      timeZoneDatabaseProvider.overrideWith((ref) async {}),
      // A device in Jerusalem, on its clock: tests run on UTC.
      deviceClockProvider.overrideWithValue(_clockOf(_jerusalem)),
    ],
  'search_preparing': [verseIndexProvider.overrideWith(_PreparingIndex.new)],
  for (final screen in _listening) screen: [ttsProvider.overrideWithValue(_HeldTts())],
  'city_error': [cityDirectoryProvider.overrideWith((ref) async => throw Exception('offline'))],
};

/// Screens shown while Listen reads.
const _listening = {
  'reader_listen',
  'reader_listen_full',
  'reader_listen_paused',
  'reader_listen_focus',
  'reader_listen_rate',
  'haftarah_listen',
  'haftarah_tab_listen',
};

/// Speech that says nothing, and never finishes what it is asked to say, so
/// that Listen stays at the verse it has reached.
class _HeldTts extends RecordingTts {
  @override
  Future<bool> speak(String text, {required String language, double rate = kDefaultSpeechRate}) {
    spoken.add((text, language));
    return Completer<bool>().future;
  }
}

/// Listen, then on two verses.
final _listenOnTwo = _tapInTurn([
  () => find.byIcon(Icons.volume_up_outlined),
  () => find.byIcon(Icons.skip_next_rounded),
  () => find.byIcon(Icons.skip_next_rounded),
]);

/// The clock of [city], for a device there.
Duration Function(LocalDate) _clockOf(City city) {
  final location = Zmanim.timeZone(city.timeZone)!;
  return (d) => tz.TZDateTime(location, d.year, d.month, d.day, 12).timeZoneOffset;
}

/// A verse index that stays two fifths built.
class _PreparingIndex extends VerseIndexLoader {
  @override
  VerseIndexState build() => const VerseIndexState(progress: 0.4);
}

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
  'today_afternoon': DateTime(2026, 10, 9, 14),
  'today_thursday': DateTime(2026, 10, 15, 11),
  // Wednesday 20 September 2028, before Rosh Hashanah and Haazinu's Shabbat.
  'today_erev_yomtov': DateTime(2028, 9, 20, 11),
  // Friday 18 May 2029, with Shavuot on Sunday and Monday.
  'today_erev_shabbat_yomtov': DateTime(2029, 5, 18, 11),
  'today_shabbat': DateTime(2026, 10, 10, 11),
  'today_yomtov': DateTime(2029, 5, 20, 11),
  'today_yom_kippur': DateTime(2026, 9, 21, 11),
  'today_friday_night': DateTime(2026, 10, 9, 20),
  // The Tuesday before Shabbat 19 May 2029, with Shavuot on Sunday.
  's_reading_yomtov': DateTime(2029, 5, 15, 11),
  'today_checkin': DateTime(2026, 10, 12, 11),
  'today_checkin_sheet': DateTime(2026, 10, 12, 11),
  'focus_sheet_tile': DateTime(2026, 10, 12, 11),
  'today_motzaei_shabbat': DateTime(2026, 10, 10, 20),
  'today_restore': DateTime(2026, 10, 14, 11),
  'today_pause_ended': DateTime(2026, 10, 12, 11),
  'today_grace': DateTime(2026, 10, 16, 11),
  'today_erev_tisha_bav': DateTime(2027, 8, 11, 11),
  // Thursday 12 August 2027, 9 Av 5787.
  'today_tisha_bav': DateTime(2027, 8, 12, 11),
  'today_tisha_bav_week': DateTime(2027, 8, 12, 11),
  // Tuesday of Matot-Masei 5787.
  'reader_third': DateTime(2027, 7, 27, 11),
  'browse_summer': DateTime(2027, 7, 14, 11),
  // The Wednesday of Bereshit, which began on Monday.
  'welcome_plan_midweek': DateTime(2026, 10, 7, 11),
  // Thursday 12 August 2027, 9 Av 5787.
  'welcome_plan_tisha_bav': DateTime(2027, 8, 12, 11),
  'reader_finished_day': DateTime(2026, 10, 7, 11),
};
final _screenProgress = <String, ProgressState Function()>{
  'progress_map': historyProgress,
  'browse_summer': _yearRead,
  'today_haftarah_left': () => ProgressState(weeks: {
        '5787:1': WeekProgress(weekId: '5787:1').withAll(LocalDate(2026, 10, 9)),
      }),
  'today_joined_midweek': () => ProgressState(weeks: {}),
  'today_simchat_torah': () => ProgressState(weeks: {}),
  'today_three_weeks': () => ProgressState(weeks: {}),
  // Bereshit finished; nothing of Noach read.
  'today_thursday': () => ProgressState(weeks: {
        '5787:1': WeekProgress(weekId: '5787:1').withAll(LocalDate(2026, 10, 9)),
      }),
  'today_erev_yomtov': () => ProgressState(weeks: {}),
  'today_erev_shabbat_yomtov': () => ProgressState(weeks: {}),
  'today_yomtov': () => ProgressState(weeks: {}),
  'today_yom_kippur': () => ProgressState(weeks: {}),
  'today_erev_tisha_bav': () => ProgressState(weeks: {}),
  // Devarim read on its days but for Shevi'i; of Va'etchanan, Rishon to
  // Shlishi on theirs, and Wednesday's aliyot not yet.
  for (final screen in ['today_tisha_bav', 'today_tisha_bav_week'])
    screen: () => ProgressState(weeks: {
          '5787:44': _readOnTheirDays('5787:44', LocalDate(2027, 8, 1), upTo: 6),
          '5787:45': _readOnTheirDays('5787:45', LocalDate(2027, 8, 8), upTo: 3),
        }),
  // Every aliyah read on its day; the haftarah not yet.
  'today_complete': () => ProgressState(weeks: {'5787:1': _readOnTheirDays('5787:1', LocalDate(2026, 10, 5))}),
  // All but the Targum of Shevi'i, which the capture logs.
  'today_completing': () => ProgressState(weeks: {
        '5787:1': _readOnTheirDays('5787:1', LocalDate(2026, 10, 5)).withUnit(6, ReadingPass.targum, null),
      }),
  'today_pause_ended': () => ProgressState(
        weeks: _progress().weeks,
        pauses: [Pause(LocalDate(2026, 10, 8), LocalDate(2026, 10, 11), id: 'travel')],
      ),
  // Bereshit read on its days; of Noach, Rishon to Shlishi on theirs, then
  // nothing on Wednesday and Chamishi alone on Thursday.
  'today_grace': () {
    final sunday = LocalDate(2026, 10, 11);
    var noach = WeekProgress(weekId: '5787:2');
    for (var a = 0; a < 3; a++) {
      noach = noach.withAliyah(a, sunday.addDays(a));
    }
    return ProgressState(weeks: {
      '5787:1': _readOnTheirDays('5787:1', LocalDate(2026, 10, 5)),
      '5787:2': noach.withAliyah(4, sunday.addDays(4)),
    });
  },
  // Nothing read yet: Rishon is the first aliyah ever finished.
  'reader_offer': () => ProgressState(weeks: {}),
  'reader_offer_city': () => ProgressState(weeks: {}),
  'today_paused': () => ProgressState(
        weeks: _progress().weeks,
        pauses: [Pause(LocalDate(2026, 10, 8), LocalDate(2026, 10, 18), id: 'travel')],
      ),
  // Paused from Wednesday to the Friday after next.
  for (final screen in ['progress_paused', 'progress_extend'])
    screen: () => _progress().copyWith(pauses: [Pause(LocalDate(2026, 10, 7), LocalDate(2026, 10, 16))]),
  for (final screen in ['progress_years', 'progress_past', 'progress_record']) screen: _secondYear,
  // All three readings of Shlishi (from Genesis 2:20) have reached 3:1,
  // its seventh verse, where the guided reader resumes and focus mode opens.
  'reader_focus': () => ProgressState(weeks: {
        '5787:1': WeekProgress(weekId: '5787:1').withPosition(2, const [6, 6, 6]),
      }),
  'reader_chapter': () => ProgressState(weeks: {
        '5787:1': WeekProgress(weekId: '5787:1').withPosition(2, const [6, 6, 6]),
      }),
  // Both Hebrew readings of Genesis 2:20 done: Rashi is next.
  'reader_rashi_step': () => ProgressState(weeks: {
        '5787:1': WeekProgress(weekId: '5787:1').withPosition(2, const [1, 1, 0]),
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
  'haftarah_read': () {
    final w = _progress().weeks['5787:1']!.withHaftarah(LocalDate(2026, 10, 8));
    return ProgressState(weeks: {'5787:1': w});
  },
  'reader_finished_next': () => _readThrough(1, partly: 2),
  'reader_finished_day': () => _readThrough(1, partly: 2, on: LocalDate(2026, 10, 7)),
  'reader_finished_erev': () => _readThrough(4, partly: 5),
  'reader_finished_week': () => _readThrough(5, partly: 6),
};

/// A reader in their second year, with Bereshit 5787 as in [_progress].
ProgressState _secondYear() => ProgressState(weeks: {...secondYearProgress(), ..._progress().weeks});

/// Bereshit with every aliyah up to [last] read on its planned day, and the
/// Hebrew of aliyah [partly] read twice on [on], so that the guided reader
/// resumes at its Targum.
ProgressState _readThrough(int last, {required int partly, LocalDate? on}) {
  final mon = LocalDate(2026, 10, 5);
  var w = WeekProgress(weekId: '5787:1');
  for (var a = 0; a <= last; a++) {
    w = w.withAliyah(a, mon.addDays(a < 3 ? a : (a < 5 ? 3 : 4)));
  }
  final day = on ?? mon.addDays(4);
  w = w
      .withUnit(partly, ReadingPass.mikra1, day)
      .withUnit(partly, ReadingPass.mikra2, day)
      .withPosition(partly, const [99, 99, 0]);
  return ProgressState(weeks: {'5787:1': w});
}

/// Screens shown with the device's own accessibility settings on.
const _deviceFeatures = {
  's_a11y_device': FakeAccessibilityFeatures(disableAnimations: true, boldText: true),
  's_display_device': FakeAccessibilityFeatures(boldText: true),
};

/// Screens captured as their setup leaves them, partway through an
/// animation.
const _unsettled = {'today_completing'};

/// Screens shown as on the web, where the reader takes single keys.
const _webKeys = {'reader_keys_web', 's_a11y_web'};

/// Screens captured after typing into their only text field.
const _typed = {
  'account_code': 'reader@example.org',
  'thread_replying': 'Thank you — that settles it for me.',
};

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
const _backupOn = {'s_data_reset', 's_data_replace', 'account_sync_large'};

/// Notes too long, together, for the server to back up: 230 of 2,000
/// Hebrew letters each.
final _longNotes = jsonEncode({
  for (var i = 1; i <= 230; i++) 'Genesis 1:$i': {'b': false, 'n': 'א' * 2000, 'u': i},
});

/// Screens where the reader chooses [_backupFile] to restore.
const _choosesBackup = {'s_data_import', 's_data_replace', 'welcome_import', 'focus_dialog_tile'};

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
const _remindersSupported = {'s_reminders_on', 's_reminders_city', 's_reminders_far', 'reader_offer'};

/// Screens shown where reminders are available and the OS allows them.
const _remindersAllowed = {'s_reminders_offer', 'reader_offer_city'};

/// Screens shown where reminders are available but the OS refuses them.
const _remindersRefused = {'s_reminders_denied'};

class _RefusedNotifications extends PhoneNotifications {
  @override
  Future<bool> requestPermission() async => false;
}

class _AllowedNotifications extends PhoneNotifications {
  @override
  Future<bool> requestPermission() async => true;
}

Future<ForumRepository> _signedIn() async {
  final repo = DemoForumRepository();
  await repo.verifyCode('reader@example.org', '123456');
  return repo;
}

/// Signed in as Rivka, who has accepted the guidelines and blocked a member.
Future<ForumRepository> _member() async {
  final repo = DemoForumRepository();
  await repo.verifyCode('rivka@example.org', '123456');
  await repo.updateDisplayName('Rivka Levi');
  await repo.acceptGuidelines();
  final other = (await repo.posts('1')).map((p) => p.authorId).firstWhere((id) => id != null && id != 'me');
  await repo.block(other!);
  return repo;
}

/// Screens shown with another community than the plain demo.
final _communities = <String, Future<ForumRepository> Function()>{
  'thread_weekly': _withWeeklyThread,
  'forum_weekly': _withWeeklyThread,
  'thread_report': _signedIn,
  'community_member': _signedIn,
  'account_name': _signedIn,
  for (final screen in ['compose_member', 'compose_verse_posted', 'account_member', 'account_edit', 'account_blocked', 'account_delete'])
    screen: _member,
  'forum_empty': () async => DemoForumRepository(samples: false),
  for (final screen in ['forum_error', 'thread_error', 'moderation_error']) screen: () async => _Offline(),
  for (final screen in ['community_error', 'forum_unreachable']) screen: () async => _NoForums(),
  'account_blocked_error': _memberNoBlocked,
  'thread_long': _withLongThread,
  'thread_long_end': _withLongThread,
  'thread_mine': _withOwnPost,
  'thread_edit': _withOwnPost,
  'week_discuss': () async => _OpeningForever(),
  'welcome_restore': () async => _Cloud(),
  'welcome_restoring': () async {
    final repo = _CloudForever();
    await repo.verifyCode('reader@example.org', '123456');
    return repo;
  },
};

/// Signed in, with a post of your own in thread 1 that three have thanked.
Future<ForumRepository> _withOwnPost() async {
  final repo = DemoForumRepository();
  await repo.verifyCode('reader@example.org', '123456');
  return repo
    ..seed(posts: [
      Post(
        id: '9100',
        threadId: '1',
        authorId: 'me',
        authorName: 'Leah',
        body: 'Rashi on the Targum of 1:1 is a good place to see the difference.',
        createdAt: DateTime.now().subtract(const Duration(minutes: 40)),
        todah: 3,
      ),
    ]);
}

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

/// A community whose forums load, but whose threads, posts and reports
/// can't.
class _Offline extends DemoForumRepository {
  @override
  Future<List<ThreadSummary>> threads({
    int? forumId,
    int? parshaNumber,
    (DateTime, String)? after,
    int limit = ForumRepository.threadsPageSize,
  }) async =>
      throw Exception('offline');

  @override
  Future<List<Post>> posts(String threadId, {(DateTime, String)? before, int limit = ForumRepository.postsPageSize}) async =>
      throw Exception('offline');

  @override
  Future<List<Report>> openReports() async => throw Exception('offline');
}

/// A community whose forums can't be fetched.
class _NoForums extends DemoForumRepository {
  @override
  Future<List<Forum>> forums() async => throw Exception('offline');
}

/// A community whose members blocked can't be fetched.
class _NoBlocked extends DemoForumRepository {
  @override
  Future<Set<String>> blockedUsers() async => throw Exception('offline');
}

/// Signed in as Rivka, whose blocked members can't be fetched.
Future<ForumRepository> _memberNoBlocked() async {
  final repo = _NoBlocked();
  await repo.verifyCode('rivka@example.org', '123456');
  await repo.updateDisplayName('Rivka Levi');
  await repo.acceptGuidelines();
  return repo;
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
  // Finish, on the aliyah's last step.
  for (final screen in ['reader_finished', 'reader_finished_next', 'reader_finished_day', 'reader_finished_erev', 'reader_finished_week'])
    screen: () => find.byWidgetPredicate((w) => w is FilledButton).last,
  'week_discuss': () => find.widgetWithIcon(PaperRow, Icons.forum_outlined),
  for (final screen in ['thread_refreshed', 'forum_refreshed']) screen: () => find.byIcon(Icons.refresh),
  'account_code': () => find.byType(FilledButton).first,
  'compose_errors': () => find.byType(FilledButton).last,
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

/// Opens the sheet of the Shabbat times' row marked by [icon], once the row
/// is in view.
Future<void> _openShabbatTimesSheet(WidgetTester tester, IconData icon) async {
  await Scrollable.ensureVisible(tester.element(find.byIcon(icon)), alignment: 0.5);
  await _settle(tester);
  await tester.tap(find.byIcon(icon));
}

/// Waits for the verse index, built from every book of the Torah, and
/// searches for [query].
Future<void> _search(WidgetTester tester, String query) async {
  for (var i = 0; i < 100 && find.byType(LinearProgressIndicator).evaluate().isNotEmpty; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump(const Duration(milliseconds: 100));
  }
  if (query.isNotEmpty) await tester.enterText(find.byType(TextField), query);
}

/// Opens Go to verse from the Parsha tab, and types [query].
Future<void> _goTo(WidgetTester tester, String query) async {
  await tester.tap(find.byIcon(Icons.search));
  await tester.pumpAndSettle();
  if (query.isNotEmpty) await tester.enterText(find.byType(TextField), query);
}

/// Waits for the list of cities, which loads from a large asset.
Future<void> _untilLoaded(WidgetTester tester) async {
  for (var i = 0; i < 100 && find.byType(PaperGroup).evaluate().isEmpty; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
    await tester.pump();
  }
}

Future<void> _showCatchUpLine(WidgetTester tester) =>
    Scrollable.ensureVisible(tester.element(find.byIcon(Icons.import_contacts)), alignment: 0.7);

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

/// Bookmarks and notes on Genesis and Exodus, in both languages, for the
/// screens that show them.
final _annotations = jsonEncode({
  'Genesis 1:1': {'b': false, 'n': 'What does a world made “in the beginning” say about every new start?', 'u': 1},
  'Genesis 1:27': {'b': true, 'n': null, 'u': 2},
  'Genesis 3:9': {'b': true, 'n': 'Ayeka — “where are you?” A question for the table: when do we hide?', 'u': 3},
  'Genesis 3:22': {
    'b': true,
    'n': 'Why “like one of us”? Onkelos and Rashi each read it another way: ask at the table.',
    'u': 4,
  },
  'Genesis 3:24': {'b': true, 'n': null, 'u': 5},
  'Genesis 4:1': {'b': false, 'n': 'קניתי איש את ה׳ — מה חוה מבקשת לומר בשם קין?', 'u': 6},
  'Genesis 2:3': {'b': false, 'n': null, 'u': 7},
  'Exodus 3:14': {'b': true, 'n': null, 'u': 8},
});

/// Screens that show [_annotations].
const _annotated = {
  'reader_marks',
  'reader_full_marks',
  'reader_verse_actions_marked',
  'note_dialog',
  'notes',
  'notes_parsha',
  'week_notes',
};

final _screenSetup = <String, Future<void> Function(WidgetTester)>{
  'reader_verse_actions_marked': (tester) => tester.longPress(find.byType(ScriptureVerse).first),
  'note_dialog': (tester) async {
    await tester.longPress(find.byType(ScriptureVerse).first);
    await _settle(tester);
    await tester.tap(find.byIcon(Icons.sticky_note_2_outlined));
  },
  'week_notes': _scrollToEnd,
  's_a11y_speech': _scrollToEnd,
  for (final screen in [
    'reader_listen',
    'reader_listen_full',
    'reader_listen_focus',
    'haftarah_listen',
    'haftarah_tab_listen',
  ])
    screen: _listenOnTwo,
  'reader_listen_paused': (tester) async {
    await _listenOnTwo(tester);
    await tester.tap(find.byIcon(Icons.pause_rounded));
  },
  'reader_listen_rate': (tester) async {
    await _listenOnTwo(tester);
    await tester.tap(find.byTooltip(tester.element(find.byType(Scaffold).last).l10n.speechRate));
  },
  // Past the times what failed to load is tried again, so that none is
  // still waiting as the test ends.
  for (final screen in ['forum_error', 'thread_error', 'moderation_error', 'city_error'])
    screen: (tester) => tester.pump(const Duration(minutes: 1)),
  // Next through Rishon's three readings, then a routine in the offer.
  'reader_offer': _tapInTurn([
    for (var i = 0; i < 3; i++) () => find.byWidgetPredicate((w) => w is FilledButton).last,
    () => find.descendant(of: find.byType(AlertDialog), matching: find.byType(SeferChoiceChip)).first,
  ]),
  'reader_offer_city': _tapInTurn([
    for (var i = 0; i < 3; i++) () => find.byWidgetPredicate((w) => w is FilledButton).last,
    () => find.descendant(of: find.byType(AlertDialog), matching: find.byType(SeferChoiceChip)).first,
    () => find.descendant(of: find.byType(AlertDialog), matching: find.byType(FilledButton)),
  ]),
  // The daily reminder's switch.
  's_reminders_denied': (tester) => tester.tap(find.byType(SwitchRow).first),
  's_reminders_offer': (tester) => tester.tap(find.byType(SwitchRow).first),
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
  'reader_full_end': _scrollToEnd,
  'reader_parsha_pinned': (tester) => tester.drag(find.byType(CustomScrollView), const Offset(0, -500)),
  // Revi'i's heading three fifths of the way down: brought there again
  // once the verses before it are built, whose height is till then
  // reckoned.
  'reader_parsha_join': (tester) async {
    for (var i = 0; i < 3; i++) {
      await Scrollable.ensureVisible(
        tester.element(find.byWidgetPredicate((w) => w is AliyahHeader && w.aliyah == 3, skipOffstage: false)),
        alignment: 0.6,
      );
      await _settle(tester);
    }
  },
  'reader_parsha_end': _scrollToEnd,
  // Focus mode opens on Shlishi's first verse (Genesis 2:20); ↓ through its
  // 27 verses reaches Revi'i's first, 3:22.
  'reader_parsha_focus': (tester) async {
    for (var i = 0; i < 27; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump(const Duration(milliseconds: 50));
    }
  },
  'reader_parsha_menu': _tapInTurn([
    () => find.descendant(of: find.byType(AppBar), matching: find.byType(PopupMenuButton<String>)),
  ]),
  // The sheet drawn up, with its switches in view: Side by side among them
  // where the columns would show.
  'reader_display_side': (tester) async {
    await tester.tap(find.byIcon(Icons.text_format));
    await _settle(tester);
    await tester.drag(find.byType(SheetTitle), const Offset(0, -600));
    await _settle(tester);
    final l = _l10n(tester);
    final focus = find.widgetWithText(SwitchRow, l.focusMode);
    await tester.scrollUntilVisible(
      focus,
      200,
      scrollable: find.descendant(of: find.byType(BottomSheet), matching: find.byType(Scrollable)).first,
    );
    final side = find.widgetWithText(SwitchRow, l.sideBySide);
    await Scrollable.ensureVisible(tester.element(side.evaluate().isNotEmpty ? side : focus), alignment: 0.5);
  },
  'haftarah_end': _scrollToEnd,
  'haftarah_chapter': (tester) => Scrollable.ensureVisible(tester.element(find.byType(ChapterHeading).last), alignment: 0.3),
  'haftarah_read': _scrollToEnd,
  's_reading_end': _scrollToEnd,
  'reader_third': _scrollToEnd,
  // The haftarah, near the end of Today.
  'today_three_weeks': _scrollToEnd,
  'today_tisha_bav_week': (tester) =>
      Scrollable.ensureVisible(tester.element(find.byType(WeekStrip)), alignment: 0.5),
  // Choose aliyot, the check-in's second text button.
  'today_checkin_sheet': (tester) =>
      tester.tap(find.descendant(of: find.byType(NoticeBanner), matching: find.byType(TextButton)).at(1)),
  // Shevi'i's Targum logged, and the frame a third of the way round.
  'today_completing': (tester) async {
    ProviderScope.containerOf(tester.element(find.byType(TodayScreen)))
        .read(progressProvider.notifier)
        .markUnit('5787:1', 6, ReadingPass.targum, LocalDate(2026, 10, 9));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
  },
  'today_book': (tester) async {
    await tester.ensureVisible(find.byIcon(Icons.import_contacts));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.import_contacts));
  },
  'guide_end': _scrollToEnd,
  'guide_end_bold': _scrollToEnd,
  'legal_end': _scrollToEnd,
  // The regular haftarah's heading, with the special one's end above it.
  'haftarah_regular': (tester) => _showRegularHaftarah(tester, alignment: 0.6),
  'haftarah_chabad_regular': (tester) => _showRegularHaftarah(tester, alignment: 0.3),
  's_reading_customs': (tester) =>
      Scrollable.ensureVisible(tester.element(find.byType(RadioListTile<ReadingMethod>).last)),
  's_reading_chabad': (tester) =>
      Scrollable.ensureVisible(tester.element(find.byType(SegmentedButton<HaftarahNusach>)), alignment: 0.3),
  'thread_long_end': _scrollToEnd,
  // Reply on the last post, which large text leaves out of view.
  'thread_replying': (tester) async {
    await _scrollToEnd(tester);
    final reply = find.descendant(of: find.byType(PostCard).last, matching: find.widgetWithIcon(TextButton, Icons.reply));
    await tester.ensureVisible(reply);
    await tester.tap(reply);
  },
  'thread_mine': _scrollToEnd,
  // Your own post's menu, then Edit.
  'thread_edit': (tester) async {
    await _scrollToEnd(tester);
    await tester.tap(find.descendant(of: find.byType(PostCard).last, matching: find.byType(PopupMenuButton<String>)));
    await _settle(tester);
    await tester.tap(find.byWidgetPredicate((w) => w is PopupMenuItem<String> && w.value == 'edit'));
  },
  'week_discuss': _scrollToEnd,
  // The interface font choices, at the end of the Display page.
  's_fonts': (tester) => tester.ensureVisible(find.byType(RadioListTile<UiFont>).last),
  // Halfway down, clear of the preview pinned over the page.
  's_display_rashi': (tester) => Scrollable.ensureVisible(
        tester.element(find.text(tester.element(find.byType(Scaffold).last).l10n.rashiScriptDesc)),
        alignment: 0.5,
      ),
  's_display_scrolled': (tester) async => tester
      .state<ScrollableState>(find.descendant(of: find.byType(CustomScrollView), matching: find.byType(Scrollable)))
      .position
      .jumpTo(700),
  // Low vision, the second row's second card.
  's_a11y_undo': (tester) => tester.tap(find.text(tester.element(find.byType(Scaffold).last).l10n.presetLowVision)),
  's_a11y_undo_keys': (tester) async {
    await _keyboardFocus(
      tester,
      find.ancestor(
        of: find.text(tester.element(find.byType(Scaffold).last).l10n.presetLowVision),
        matching: find.byType(MergeSemantics),
      ),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  },
  's_a11y_device': (tester) => Scrollable.ensureVisible(
        tester.element(find.text(tester.element(find.byType(Scaffold).last).l10n.reduceMotion)),
        alignment: 0.5,
      ),
  's_display_device': (tester) => Scrollable.ensureVisible(
        tester.element(find.text(tester.element(find.byType(Scaffold).last).l10n.boldText)),
        alignment: 0.5,
      ),
  'focus_button': (tester) => _keyboardFocus(tester, find.byType(FilledButton).first),
  'focus_day': (tester) =>
      _keyboardFocus(tester, find.descendant(of: find.byType(WeekStrip), matching: find.byType(SeferInkWell)).at(1)),
  'focus_card': (tester) => _keyboardFocus(tester, find.byWidgetPredicate((w) => w is InfoCard && w.onTap != null).first),
  'focus_source': (tester) => _keyboardFocus(tester, find.byType(SeferInkWell).first),
  'focus_contact': (tester) => _keyboardFocus(
        tester,
        find.ancestor(of: find.textContaining('GitHub', findRichText: true), matching: find.byType(FocusableActionDetector)).first,
      ),
  // Noach: map tiles are the ink wells with 6 px corners.
  'focus_tile': (tester) => _keyboardFocus(
        tester,
        find
            .byWidgetPredicate((w) => w is SeferInkWell && w.borderRadius == const BorderRadius.all(Radius.circular(6)))
            .at(1),
      ),
  'focus_slider': (tester) => _keyboardFocus(tester, find.byType(Slider).first),
  'focus_switch': (tester) => _keyboardFocus(tester, find.byType(SwitchRow).first),
  'focus_field': (tester) => _keyboardFocus(tester, find.byType(TextField).first),
  'compose_focused': (tester) => _keyboardFocus(tester, find.byWidgetPredicate((w) => w is TextField && w.maxLength == 150)),
  'focus_chip': (tester) => _keyboardFocus(tester, find.byType(ChoiceChip).at(1)),
  'focus_link': (tester) => _keyboardFocus(tester, find.byType(LinkedText)),
  'compose_member': (tester) async {
    await tester.enterText(find.byType(TextField).first, 'On the order of the second reading: verse by verse, section by section, or the whole aliyah at once — and which do you find you keep?');
    await tester.enterText(find.byType(TextField).last, 'I have been reading verse by verse.');
  },
  'account_code_error': (tester) async {
    await tester.enterText(find.byType(TextField), 'reader@example.org');
    await tester.tap(find.byType(FilledButton).first);
    await _settle(tester);
    await tester.enterText(find.byType(TextField), '123');
    await tester.tap(find.byType(FilledButton).first);
  },
  'account_edit': (tester) => tester.tap(find.byIcon(Icons.edit_outlined)),
  'account_blocked': (tester) => tester.tap(find.byIcon(Icons.block)),
  'account_blocked_error': (tester) => tester.tap(find.byIcon(Icons.block)),
  'account_delete': (tester) async {
    await tester.ensureVisible(find.byIcon(Icons.delete_forever_outlined));
    await _settle(tester);
    await tester.tap(find.byIcon(Icons.delete_forever_outlined));
  },
  // Sheni's tab in the reader's aliyah ribbon.
  'focus_tab': (tester) =>
      _keyboardFocus(tester, find.descendant(of: find.byType(AliyahRibbon), matching: find.byType(SeferInkWell)).at(1)),
  // A menu button inside a card, which clips: the ring must still show.
  'focus_menu': (tester) => _keyboardFocus(
        tester,
        find.descendant(of: find.byType(Card), matching: find.byType(PopupMenuButton<String>)).first,
      ),
  'focus_nav_today': (tester) => _keyboardFocus(
        tester,
        find
            .ancestor(
              of: find.descendant(
                of: find.byWidgetPredicate((w) => w is NavigationBar || w is NavigationRail),
                matching: find.byIcon(Icons.today),
              ),
              matching: find.byWidgetPredicate((w) => w is InkResponse),
            )
            .first,
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
  'focus_menu_item': (tester) async {
    await _keyboardFocus(
      tester,
      find.descendant(of: find.byType(AppBar), matching: find.byType(PopupMenuButton<String>)),
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
  },
  'focus_sheet_tile': (tester) async {
    await tester.tap(find.descendant(of: find.byType(NoticeBanner), matching: find.byType(TextButton)).at(1));
    await tester.pumpAndSettle();
    await _keyboardFocus(tester, find.byType(CheckboxListTile).at(1));
  },
  'focus_dialog_tile': (tester) async {
    await tester.tap(find.byIcon(Icons.download_outlined));
    await _settle(tester);
    await _keyboardFocus(tester, find.byType(CheckboxListTile));
  },
  // The second segment of the language switch: the group is ringed, the
  // segment washed and underlined.
  'focus_segment': (tester) => _keyboardFocus(
        tester,
        find.descendant(of: find.byType(SegmentedButton<AppLanguage>), matching: find.byType(TextButton)).last,
      ),
  'focus_fab': (tester) => _keyboardFocus(tester, find.byType(FloatingActionButton)),
  // A discussion in the middle of a forum's list: its ring clears the hairlines.
  'focus_thread': (tester) => _keyboardFocus(tester, find.byType(ThreadTile).at(1)),
  'focus_demo_tag': (tester) => _keyboardFocus(tester, find.byType(DemoTag)),
  'demo_about': (tester) => tester.tap(find.byType(DemoTag)),
  'thread_this_week': (tester) => tester.tap(find.byType(ThisWeekCard)),
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
  'sheet_display_full': (tester) async {
    await tester.tap(find.byIcon(Icons.text_format));
    await _settle(tester);
    await tester.drag(find.byType(SheetTitle), const Offset(0, -600));
  },
  'scrolled': (tester) => tester.drag(find.byType(Scrollable).first, const Offset(0, -400)),
  // The page's own list, not the navigation rail's, which comes first on a
  // wide screen.
  'parsha_scrolled': (tester) => tester.drag(
        find.descendant(of: find.byType(WeekOverview), matching: find.byType(Scrollable)).first,
        const Offset(0, -300),
      ),
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
  'progress_paused': _scrollToEnd,
  'progress_extend': (tester) async {
    await tester.ensureVisible(find.text(_l10n(tester).extendPause));
    await tester.pump();
    await tester.tap(find.text(_l10n(tester).extendPause));
  },
  'progress_about': (tester) => tester.tap(find.text(_l10n(tester).aboutStreaks)),
  'progress_past': (tester) async {
    final chip = find.byType(SeferChoiceChip).first;
    await tester.tap(chip);
    await _settle(tester);
    await Scrollable.ensureVisible(tester.element(chip), alignment: 0.1);
  },
  'progress_record': _scrollToEnd,
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
  's_data_reset': (tester) => tester.tap(find.text(tester.element(find.byType(Scaffold).last).l10n.resetProgress)),
  's_reading_city': (tester) => Scrollable.ensureVisible(tester.element(find.byType(ShabbatTimesSetting))),
  's_reading_yomtov': (tester) => Scrollable.ensureVisible(tester.element(find.byType(ShabbatTimesSetting))),
  's_reading_candles': (tester) => _openShabbatTimesSheet(tester, Icons.wb_twilight_outlined),
  's_reading_havdalah': (tester) => _openShabbatTimesSheet(tester, Icons.bedtime_outlined),
  // The plan's last choice brought into view, so that the tap reaches it
  // rather than the navigation bar over where it would be.
  's_reading_changed': (tester) =>
      Scrollable.ensureVisible(tester.element(find.byType(RadioListTile<ReadingPlanType>).last), alignment: 0.5),
  'city': _untilLoaded,
  'city_search': (tester) async {
    await _untilLoaded(tester);
    await tester.enterText(find.byType(TextField), 'york');
  },
  'city_none': (tester) async {
    await _untilLoaded(tester);
    await tester.enterText(find.byType(TextField), 'Atlantis');
  },
  // More matches than are listed: the note at the end of the list.
  'city_many': (tester) async {
    await _untilLoaded(tester);
    await tester.enterText(find.byType(TextField), tester.element(find.byType(TextField)).isHebrewUi ? 'בר' : 'an');
    await tester.pump();
    await _scrollToEnd(tester);
  },
  'search': (tester) => _search(tester, ''),
  'search_results': (tester) => _search(tester, 'ויצא יעקב'),
  'search_many': (tester) => _search(tester, 'אברהם'),
  'search_targum': (tester) => _search(tester, 'בקדמין'),
  'search_english': (tester) => _search(tester, 'ladder'),
  'search_none': (tester) => _search(tester, 'טלפון'),
  'search_spelling': (tester) => _search(tester, 'אהרון'),
  'goto': (tester) => _goTo(tester, ''),
  'goto_verse': (tester) => _goTo(tester, 'בראשית כח יב'),
  'goto_missing': (tester) => _goTo(tester, 'Gen 28:30'),
  'goto_words': (tester) => _goTo(tester, 'ladder'),
  // A name and a word that is also a numeral: the verse, and the search.
  'goto_phrase': (tester) => _goTo(tester, 'שלח לו'),
  // Nothing to go to or search for: what the sheet takes.
  'goto_help': (tester) => _goTo(tester, '28'),
  'reader_verse_actions': (tester) => tester.longPress(find.byType(ScriptureVerse).first),
  'haftarah_verse_actions': (tester) => tester.longPress(find.byType(ScriptureVerse).first),
  'compose_verse': (tester) async {
    // Not awaited: the push completes only once the page is closed.
    unawaited(ProviderScope.containerOf(tester.element(find.byType(Scaffold).first))
        .read(routerProvider)
        .push('/ask?verse=Genesis%203:22'));
  },
  // Asked, written and posted: back at the verse, with the way to it.
  'compose_verse_posted': (tester) async {
    unawaited(ProviderScope.containerOf(tester.element(find.byType(Scaffold).first))
        .read(routerProvider)
        .push('/ask?verse=Genesis%203:22'));
    await _settle(tester);
    final body = find.byType(TextField).last;
    await tester.enterText(body, '${tester.widget<TextField>(body).controller!.text}Why “like one of us”?');
    await tester.tap(find.byType(FilledButton).first);
  },
  // A draft left from before, then the verse asked about.
  'compose_verse_draft': (tester) async {
    final c = ProviderScope.containerOf(tester.element(find.byType(Scaffold).first));
    await c.read(sharedPreferencesProvider).setString(
          'draft.newThread',
          '{"title":"Onkelos and the names of places","body":"Why does Onkelos keep some names"}',
        );
    unawaited(c.read(routerProvider).push('/ask?verse=Genesis%203:22'));
  },
  's_data_import': (tester) => tester.tap(find.byIcon(Icons.download_outlined)),
  'settings_language': (tester) async {
    await tester.ensureVisible(find.byIcon(Icons.translate_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.translate_outlined));
  },
  's_data_paste': _tapInTurn([
    () => find.byIcon(Icons.content_paste_outlined),
    () => find.byType(FilledButton),
  ]),
  's_data_paste_open': (tester) => tester.tap(find.byIcon(Icons.content_paste_outlined)),
  's_data_replace': _tapInTurn([
    () => find.byIcon(Icons.download_outlined),
    // "Replace instead", the dialog's last text button.
    () => find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextButton)).last,
  ]),
  'welcome_import': _tapInTurn([
    () => find.byType(TextButton).last,
    () => find.byIcon(Icons.restore_page_outlined),
  ]),
  // The catch-up line, on the eve of days of rest.
  'today_erev_yomtov': _showCatchUpLine,
  'today_erev_shabbat_yomtov': _showCatchUpLine,
  // The week strip, in the middle of the page.
  'today_yomtov_oneday': _showWeekStrip,
  'today_yomtov_twoday': _showWeekStrip,
  'today_joined_midweek': _showWeekStrip,
  'today_grace': _showWeekStrip,
};

/// Scrolls the haftarah page's regular haftarah heading to [alignment].
Future<void> _showRegularHaftarah(WidgetTester tester, {required double alignment}) => Scrollable.ensureVisible(
      tester.element(find.descendant(of: find.byType(ExpansionTile), matching: find.byType(ListTile))),
      alignment: alignment,
    );

/// The app's strings, in the language of the mode.
AppLocalizations _l10n(WidgetTester tester) => tester.element(find.byType(Scaffold).first).l10n;

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
    await tester.tap(find.byType(SeferMenuItem<String>).at(item));
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
  // A 1920 dp desktop, where a column's inset is widest.
  _Mode('wide', const Size(1920, 1080), (s) => s),
  // The narrowest desktop, where Today's columns are narrowest, for the
  // screens in [_narrowDesktopScreens].
  _Mode('desk1200', const Size(1200, 800), (s) => s),
  // System text at 200% on a phone's own height, for the screens in
  // [_bigPhoneScreens]: what stays in view without scrolling.
  _Mode('bigphone', const Size(412, 915), (s) => s, textScale: 2),
  // System text at 300% on a 320 dp phone, in English and Hebrew, for the
  // screens in [_hugeScreens], as screens_a11y_test.dart lays them out.
  _Mode('huge', const Size(320, 640), (s) => s, textScale: 3),
  _Mode('hugehe', const Size(320, 640), (s) => s.copyWith(language: AppLanguage.hebrew), textScale: 3),
  // The same, tall, for the screens in [_hugeTallScreens]: the whole page.
  _Mode('hugetall', const Size(320, 3600), (s) => s, textScale: 3),
  _Mode('hugetallhe', const Size(320, 3600), (s) => s.copyWith(language: AppLanguage.hebrew), textScale: 3),
  // A phone held sideways, where the rail scrolls, for the screens in
  // [_sidewaysScreens].
  _Mode('sideways', const Size(800, 360), (s) => s),
  // System text at 300% on a 412 dp phone, tall, for the screens in
  // [_hugeWideScreens]: a stacked row keeps its icon on the title's line.
  _Mode('hugewide', const Size(412, 3600), (s) => s, textScale: 3),
];

const _sidewaysScreens = {'focus_nav', 'focus_nav_today'};

const _bigPhoneScreens = {
  // The button that begins a discussion: its icon alone at 200% (§5).
  'forum_questions',
  'welcome',
  'welcome_location',
  'welcome_plan',
  // What deleting the account takes with it, and the dialog's three
  // actions, stacked.
  'account_delete',
};
const _hugeModes = {'huge', 'hugehe'};
// The reader with Listen's player over its bar too: the chrome is held at
// 200% so that a verse shows beneath it. Browse, whose names stay whole.
const _hugeScreens = {
  'today',
  'reader',
  'reader_listen',
  'reader_preview',
  'browse',
  // The reply box, its button under the field, and while answering a post.
  'thread',
  'thread_replying',
};
const _hugeTallModes = {'hugetall', 'hugetallhe'};
const _hugeTallScreens = {
  'today',
  'parsha',
  'week',
  'progress',
  'settings',
  'community',
  // A forum's discussions, the longest lines of facts among them, and its
  // floating button, its icon alone.
  'forum_questions',
  // What can't load, with Try again: under a thread's title, and beside All
  // forums.
  'thread_error',
  'forum_unreachable',
  'thread',
  'haftarah',
  'browse',
  // The offer to move the daily reminder, its button under its text.
  's_reminders_far',
  // Verses found, where words a maqaf joins part only if they must.
  'search_many',
  'search_spelling',
};
const _hugeWideScreens = {'parsha', 'settings'};

const _narrowDesktopScreens = {
  'today',
  'today_checkin',
  'today_complete',
  'today_grace',
  'today_pause_ended',
  'today_divergence',
  'forum_questions',
  'snackbar',
};

const _desktopScreens = {
  'notes',
  'reader_full_marks',
  'today',
  'today_candles',
  'today_shabbat',
  'today_complete',
  'today_checkin',
  'today_divergence',
  'today_haftarah_left',
  'today_yomtov_oneday',
  // Today's columns with a notice over the title page, with the strip's
  // note, and with a sheet over them.
  'today_paused',
  'today_pause_ended',
  'today_grace',
  'today_book',
  // The fast: the title page without its button.
  'today_tisha_bav',
  'parsha',
  'parsha_scrolled',
  'week',
  'week_combined',
  'week_tab',
  'haftarah_tab',
  'haftarah',
  'haftarah_regular',
  'haftarah_read',
  'reader',
  'reader_third',
  'reader_finished',
  'reader_finished_week',
  'reader_offer',
  'reader_offer_city',
  'celebrate',
  'reader_full',
  'reader_full_end',
  'reader_full_english',
  'reader_full_rashi_english',
  'reader_parsha',
  'reader_parsha_pinned',
  'reader_parsha_join',
  'reader_parsha_end',
  'reader_parsha_focus',
  'reader_parsha_menu',
  'reader_display_side',
  'reader_focus',
  'reader_section',
  'reader_rashi',
  'reader_keys',
  'reader_keys_web',
  'reader_gaps',
  'progress',
  'progress_years',
  'progress_paused',
  'progress_about',
  'thread',
  'thread_letters',
  'thread_replying',
  'thread_long',
  'legal',
  'not_found',
  'settings',
  // The app bar's title on the column's edge (§5), over pages of each kind.
  's_display',
  's_display_scrolled',
  's_a11y',
  's_reading',
  's_reminders',
  's_data',
  'community',
  'forum',
  'forum_questions',
  // The button that begins a discussion, at the column's end.
  'forum_empty',
  // What can't load, said under the title rather than at the pane's edge.
  'forum_error',
  'thread_error',
  'moderation_error',
  'city_error',
  'community_error',
  'forum_unreachable',
  'account',
  'account_code',
  'account_member',
  'account_delete',
  'compose',
  'browse',
  'browse_summer',
  'guide',
  'about',
  'sources',
  'welcome',
  'welcome_plan',
  'welcome_restore',
  'dialog',
  // Status messages, centred on the page that shows them: over the tabs,
  // and within one beside the rail.
  'snackbar',
  's_a11y_undo',
  's_a11y_undo_keys',
  'thread_refreshed',
  'forum_refreshed',
  'sheet_display',
  'focus_nav',
  'focus_nav_today',
  'kit_ornaments',
  'kit_rows',
  'kit_progress',
  'kit_week',
  'progress_map',
  'city_search',
  'search',
  'search_many',
  'goto_verse',
  'reader_verse',
  'reader_verse_actions',
  'compose_verse',
  'reader_listen',
  'reader_listen_full',
  'haftarah_listen',
  'haftarah_tab_listen',
};
// The wide modes render only the screens above.
const _wideModes = {'desktop', 'tablet', 'deskhe', 'deskhc', 'wide'};
const _tallScreens = {
  'today',
  'parsha',
  'week',
  'browse',
  'progress',
  'progress_years',
  'settings',
  's_reading',
  's_reading_end',
  's_reminders',
  's_reminders_on',
  's_data',
  's_display',
  's_a11y',
  'sources',
  'about',
  'guide',
  'legal',
  'legal_a11y',
  'week_notes',
  'notes',
  'notes_parsha',
  // Every forum, with how busy it is.
  'community',
};
const _bigTextModes = {'big', 'bighe'};
const _narrowScreens = {
  'welcome',
  'welcome_plan',
  'settings',
  's_reading',
  's_display',
  's_a11y',
  'sheet_display_full',
  'parsha',
  'browse',
  'today',
  'today_book',
  'today_paused',
  'today_shabbat',
  'today_checkin',
  'today_grace',
  'progress',
  'progress_map',
  'progress_years',
  'kit_week',
  's_data_import',
  'reader',
  'reader_long',
  'reader_listen',
  'reader_listen_full',
  // The guide's card, its rhythm 16 under 360 dp, and its lists.
  'guide',
};
const _bigTextScreens = {
  // A held message with Undo and Close, at twice the text size.
  's_a11y_undo_keys',
  // A focus ring on a menu item and on tiles, at twice the text size.
  'focus_menu_item',
  'focus_sheet_tile',
  'focus_dialog_tile',
  's_display',
  's_a11y',
  'sheet_display_full',
  'parsha',
  'browse',
  'week_combined',
  'notes',
  'reader_marks',
  'reader_verse_actions_marked',
  'note_dialog',
  'today',
  'today_book',
  'today_shabbat',
  'today_complete',
  'today_checkin',
  'today_checkin_sheet',
  'today_pause_ended',
  'today_grace',
  'today_tisha_bav',
  'reader_offer',
  'reader_offer_city',
  's_reminders_on',
  's_reminders_offer',
  's_reminders_city',
  's_reminders_far',
  'today_candles',
  'community',
  'compose',
  'compose_errors',
  'account',
  'account_code',
  'account_name',
  'account_member',
  'account_delete',
  'thread',
  'thread_replying',
  'forum_questions',
  'reader_finished_day',
  'reader_finished_week',
  'celebrate',
  'haftarah',
  'haftarah_read',
  'goto_verse',
  'goto_missing',
  'reader_verse',
  'reader_verse_actions',
  'compose_verse_draft',
  'search_many',
  'search_none',
  'search_spelling',
  's_reading_city',
  's_reading_candles',
  's_reading_havdalah',
  'settings',
  's_reading',
  'city',
  'today_paused',
  'welcome',
  'welcome_restore',
  'welcome_location',
  'welcome_plan',
  's_data',
  's_data_import',
  'progress',
  'progress_years',
  'reader',
  'haftarah_regular',
  'reader_focus',
  'kit_ornaments',
  'kit_rows',
  'kit_progress',
  'kit_week',
  'progress_map',
  // The Torah map's legend, each state's name balanced over its lines.
  'legend_map',
  'about',
  'guide',
  'sources',
  'legal_a11y',
  'reader_listen',
  'reader_listen_full',
  'haftarah_listen',
  'reader_parsha',
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
  if (_words) {
    final broken = brokenWords(tester);
    if (broken.isNotEmpty) {
      File('build/screens/broken_words.txt')
          .writeAsStringSync('$name\n  ${broken.join('\n  ')}\n', mode: FileMode.append);
    }
  }
}

void main() {
  setUpAll(() async {
    if (_capture) await loadBundledFonts();
    // The version About shows, as a release names it.
    PackageInfo.setMockInitialValues(
      appName: 'Shnayim Mikra',
      packageName: 'app.shnayimmikra',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  for (final mode in _modes) {
    if (!(_onlyModes?.contains(mode.tag) ?? true)) continue;
    for (final entry in _screens.entries) {
      if (_wideModes.contains(mode.tag) && !_desktopScreens.contains(entry.key)) continue;
      if (mode.tag == 'phonetall' && !_tallScreens.contains(entry.key)) continue;
      if (_bigTextModes.contains(mode.tag) && !_bigTextScreens.contains(entry.key)) continue;
      if (mode.tag == 'narrow' && !_narrowScreens.contains(entry.key)) continue;
      if (mode.tag == 'bigphone' && !_bigPhoneScreens.contains(entry.key)) continue;
      if (mode.tag == 'desk1200' && !_narrowDesktopScreens.contains(entry.key)) continue;
      if (_hugeModes.contains(mode.tag) && !_hugeScreens.contains(entry.key)) continue;
      if (_hugeTallModes.contains(mode.tag) && !_hugeTallScreens.contains(entry.key)) continue;
      if (mode.tag == 'sideways' && !_sidewaysScreens.contains(entry.key)) continue;
      if (mode.tag == 'hugewide' && !_hugeWideScreens.contains(entry.key)) continue;
      final only = _only;
      if (only != null && !only.contains(entry.key)) continue;
      testWidgets('${mode.tag} ${entry.key}', (tester) async {
        tester.view.physicalSize = mode.size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        tester.platformDispatcher.textScaleFactorTestValue = mode.textScale;
        addTearDown(tester.platformDispatcher.clearAllTestValues);
        if (_deviceFeatures[entry.key] case final features?) {
          tester.platformDispatcher.accessibilityFeaturesTestValue = features;
        }
        // As though the app had just started.
        TodayScreen.forgetCompletions();
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
            stored: {
              if (_annotated.contains(entry.key)) AnnotationsController.storageKey: _annotations,
              if (entry.key == 'account_sync_large') AnnotationsController.storageKey: _longNotes,
            },
            forums: blocked
                ? await _accountWithNewerBackup()
                : (_backupOn.contains(entry.key) ? await _signedIn() : await _communities[entry.key]?.call()),
            notifications: _remindersRefused.contains(entry.key)
                ? _RefusedNotifications()
                : _remindersAllowed.contains(entry.key)
                    ? _AllowedNotifications()
                    : (_remindersSupported.contains(entry.key) ? PhoneNotifications() : null),
            overrides: [
              ...?_screenOverrides[entry.key],
              if (_choosesBackup.contains(entry.key))
                backupFilesProvider.overrideWithValue(FakeBackupFiles(file: _backupFile())),
            ],
          );
          c.read(routerProvider).go(entry.value);
          await _settle(tester);
          final setup = _screenSetup[entry.key];
          if (setup != null) {
            await setup(tester);
            if (!_unsettled.contains(entry.key)) await _settle(tester);
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
