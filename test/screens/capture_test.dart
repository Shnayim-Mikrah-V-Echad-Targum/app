// Renders every main screen with the app's real fonts and writes PNGs to
// build/screens/, for visual review without a web build:
//
//   CAPTURE=1 flutter test test/screens/capture_test.dart
//   CAPTURE=1 SCREENS=today,reader flutter test test/screens/capture_test.dart
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
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/features/community/data/demo_forum_repository.dart';
import 'package:shnayim_mikra/features/community/data/forum_repository.dart';
import 'package:shnayim_mikra/features/community/data/models.dart';
import 'package:shnayim_mikra/features/community/ui/thread_screen.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikra/features/progress/domain/reading_plan.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';

import '../helpers.dart';

final _capture = Platform.environment['CAPTURE'] != null;
final _only = Platform.environment['SCREENS']?.split(',').toSet();

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
  'welcome': '/welcome',
  'welcome_location': '/welcome',
  'today': '/today',
  'today_divergence': '/today',
  'today_divergence_abroad': '/today',
  'today_haftarah_left': '/today',
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
  // Yitro, the sixth aliyah: the Decalogue, with section gaps inside verses.
  'reader_gaps': '/read/5787:17/5?mode=full',
  'reader_gaps_spaced': '/read/5787:17/5?mode=full',
  // Shlishi of Vayishlach with cantillation hidden: the dots written over
  // וישקהו (Genesis 33:4) stay.
  'reader_dots': '/read/5787:8/2?mode=full',
  'haftarah': '/haftarah/5787:1',
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
  'compose': '/community/new',
  'account': '/community/account',
  'account_settings': '/settings/account',
  'account_sync': '/community/account',
  'settings': '/settings',
  's_reading': '/settings/reading',
  's_reading_changed': '/settings/reading',
  's_display': '/settings/display',
  's_a11y': '/settings/accessibility',
  's_reminders': '/settings/reminders',
  's_data': '/settings/data',
  's_data_reset': '/settings/data',
  'about': '/settings/about',
  'guide': '/guide',
  'legal': '/legal/privacy',
  // Links that lead nowhere: a mistyped address, and a forum that is gone.
  'not_found': '/nope',
  'forum_missing': '/community/forum/xyz',
};

/// Screens shown on another day and with other settings: (now, settings).
final _scenes = <String, (DateTime, AppSettings Function(AppSettings))>{
  // A visitor to Israel who keeps two days of Yom Tov, after Pesach 5789:
  // Israel is a parsha ahead, and both pairs of portions are read together.
  'today_divergence': (
    DateTime(2029, 4, 24, 11),
    (s) => s.copyWith(readingSchedule: ReadingSchedule.israel, joinDate: LocalDate(2029, 4, 22)),
  ),
  // An Israeli abroad, the same day: Israel is a parsha ahead.
  'today_divergence_abroad': (
    DateTime(2029, 4, 24, 11),
    (s) => s.copyWith(readingSchedule: ReadingSchedule.diaspora, oneDayYomTov: true, joinDate: LocalDate(2029, 4, 22)),
  ),
  // The widest word spacing, justified: the spaces around a section mark.
  'reader_gaps_spaced': (_now, (s) => s.copyWith(wordSpacing: 16, justify: true)),
  'reader_dots': (_now, (s) => s.copyWith(showTeamim: false)),
  // Tuesday of Noach: Bereshit is read, all but the haftarah, which counts.
  'today_haftarah_left': (DateTime(2026, 10, 13, 11), (s) => s.copyWith(haftarahRequired: true)),
  // Tuesday of Matot-Masei 5787, reading by section.
  'reader_third': (DateTime(2027, 7, 27, 11), (s) => s.copyWith(method: ReadingMethod.sectionBySection)),
  // Reading by aliyah, so that one step finishes Shevi'i.
  'reader_finished': (_now, (s) => s.copyWith(method: ReadingMethod.aliyahByAliyah, repeatLastVerse: false)),
};

/// Screens shown with other progress than [_progress].
final _sceneProgress = <String, ProgressState Function()>{
  'today_haftarah_left': () => ProgressState(weeks: {
        '5787:1': WeekProgress(weekId: '5787:1').withAll(LocalDate(2026, 10, 9)),
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
const _backupOn = {'s_data_reset'};

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
  final start = _now.subtract(const Duration(days: 20));
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
          lastPostAt: _now.subtract(const Duration(minutes: 20)),
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
            createdAt: i == 249 ? _now.subtract(const Duration(minutes: 20)) : start.add(Duration(hours: i)),
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

/// A community whose weekly threads never finish opening.
class _OpeningForever extends DemoForumRepository {
  @override
  Future<String> weeklyThread({required int parshaNumber, required int hebrewYear, required String title}) =>
      Completer<String>().future;
}

/// Screens captured with a dialog open, by tapping the icon given.
const _dialogs = {'s_data_reset': Icons.delete_forever_outlined};

/// Screens captured just after tapping what the finder finds, to show the
/// response.
final _taps = {
  // Choosing "All on Friday" says that it applies from this week on.
  's_reading_changed': () => find.byType(RadioListTile<ReadingPlanType>).last,
  // The second page of onboarding: where the reader will be this Shabbat.
  'welcome_location': () => find.byType(FilledButton).first,
  // Next, on the last step of Shevi'i.
  'reader_finished': () => find.byWidgetPredicate((w) => w is FilledButton).last,
  'week_discuss': () => find.widgetWithIcon(OutlinedButton, Icons.forum_outlined),
};

/// Screens captured after tapping what each finder finds in turn, settling
/// after each.
final _tapSteps = {
  // The last post's menu, then Report.
  'thread_report': [
    () => find.descendant(of: find.byType(PostCard).last, matching: find.byType(PopupMenuButton<String>)),
    () => find.byWidgetPredicate((w) => w is PopupMenuItem<String> && w.value == 'report'),
  ],
};

/// Screens captured scrolled to the end of their main list.
const _scrolledToEnd = {'reader_gaps', 'reader_gaps_spaced', 'reader_dots', 'reader_third', 'week_discuss', 'thread_long_end'};

Future<void> _scrollToEnd(WidgetTester tester) async {
  // A lazily built list only learns its full extent as it scrolls.
  for (var i = 0; i < 8; i++) {
    for (final s in tester.stateList<ScrollableState>(find.byType(Scrollable))) {
      if (s.position.axis == Axis.vertical) s.position.jumpTo(s.position.maxScrollExtent);
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
}

class _Mode {
  const _Mode(this.tag, this.size, this.settings);
  final String tag;
  final Size size;
  final AppSettings Function(AppSettings) settings;
}

final _modes = [
  _Mode('phone', const Size(412, 915), (s) => s),
  _Mode('dark', const Size(412, 915), (s) => s.copyWith(theme: AppThemeMode.dark)),
  _Mode('he', const Size(412, 915), (s) => s.copyWith(language: AppLanguage.hebrew)),
  _Mode('hc', const Size(412, 915), (s) => s.copyWith(theme: AppThemeMode.highContrastDark)),
  _Mode('desktop', const Size(1366, 860), (s) => s),
];

Future<void> _loadFonts() async {
  final manifest = jsonDecode(await rootBundle.loadString('FontManifest.json')) as List;
  for (final family in manifest.cast<Map<String, dynamic>>()) {
    final name = family['family'] as String;
    final assets = [for (final f in (family['fonts'] as List).cast<Map<String, dynamic>>()) f['asset'] as String];
    for (final alias in [name, if (name == 'NotoSans') 'Roboto']) {
      final loader = FontLoader(alias);
      for (final a in assets) {
        loader.addFont(rootBundle.load(a));
      }
      await loader.load();
    }
  }
}

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
    if (_capture) await _loadFonts();
  });

  for (final mode in _modes) {
    for (final entry in _screens.entries) {
      if (mode.tag == 'desktop' && !const {'today', 'today_divergence', 'today_haftarah_left', 'week', 'week_tab', 'haftarah_tab', 'reader', 'reader_third', 'reader_finished', 'reader_full', 'reader_gaps', 'progress', 'thread', 'thread_long', 'settings', 'welcome'}.contains(entry.key)) {
        continue;
      }
      final only = _only;
      if (only != null && !only.contains(entry.key)) continue;
      testWidgets('${mode.tag} ${entry.key}', (tester) async {
        tester.view.physicalSize = mode.size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final blocked = _syncBlocked.contains(entry.key);
        final base = AppSettings(
          onboardingComplete: !entry.key.startsWith('welcome'),
          joinDate: _join,
          cloudSync: blocked || _backupOn.contains(entry.key),
        );
        final scene = _scenes[entry.key];
        final c = await pumpApp(
          tester,
          settings: mode.settings(scene?.$2(base) ?? base),
          now: scene?.$1 ?? _now,
          progress: (_sceneProgress[entry.key] ?? _progress)(),
          forums: blocked
              ? await _accountWithNewerBackup()
              : (_backupOn.contains(entry.key) ? await _signedIn() : await _communities[entry.key]?.call()),
        );
        if (!entry.key.startsWith('welcome')) c.read(routerProvider).go(entry.value);
        await _settle(tester);
        if (_scrolledToEnd.contains(entry.key)) await _scrollToEnd(tester);
        if (_dialogs[entry.key] case final icon?) {
          await tester.tap(find.byIcon(icon));
          await _settle(tester);
        }
        if (_taps[entry.key] case final target?) {
          await tester.tap(target());
          // Long enough for a snackbar to appear, not to leave again.
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
        }
        for (final step in _tapSteps[entry.key] ?? const <Finder Function()>[]) {
          await tester.tap(step());
          await _settle(tester);
        }
        await _write(tester, '${mode.tag}_${entry.key}');
      }, skip: !_capture);
    }
  }
}
