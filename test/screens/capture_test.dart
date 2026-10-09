// Renders every main screen with the app's real fonts and writes PNGs to
// build/screens/, for visual review without a web build:
//
//   CAPTURE=1 flutter test test/screens/capture_test.dart
//   CAPTURE=1 SCREENS=today,reader flutter test test/screens/capture_test.dart
//
// Skipped unless CAPTURE is set, so it never runs (or fails) in CI.
@Tags(['screens'])
library;

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
  'today': '/today',
  'parsha': '/parsha',
  'browse': '/parsha/browse',
  'week': '/week/5787:1',
  'reader': '/read/5787:1/2',
  'reader_full': '/read/5787:1/2?mode=full',
  // Yitro, the sixth aliyah: the Decalogue, with section gaps inside verses.
  'reader_gaps': '/read/5787:17/5?mode=full',
  'haftarah': '/haftarah/5787:1',
  'progress': '/progress',
  'community': '/community',
  'forum': '/community/forum/parsha',
  'thread': '/community/thread/1',
  'compose': '/community/new',
  'account': '/community/account',
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

/// Screens shown with backup on (but not signed in).
const _backupOn = {'s_data_reset'};

/// Screens captured with a dialog open, by tapping the icon given.
const _dialogs = {'s_data_reset': Icons.delete_forever_outlined};

/// Screens captured just after tapping what the finder finds, to show the
/// response.
final _taps = {
  // Choosing "All on Friday" says that it applies from this week on.
  's_reading_changed': () => find.byType(RadioListTile<ReadingPlanType>).last,
};

/// Screens captured scrolled to the end of their main list.
const _scrolledToEnd = {'reader_gaps'};

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
      if (mode.tag == 'desktop' && !const {'today', 'week', 'reader', 'reader_full', 'reader_gaps', 'progress', 'thread', 'settings', 'welcome'}.contains(entry.key)) {
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
          onboardingComplete: entry.key != 'welcome',
          joinDate: _join,
          cloudSync: blocked || _backupOn.contains(entry.key),
        );
        final c = await pumpApp(
          tester,
          settings: mode.settings(base),
          now: _now,
          progress: _progress(),
          forums: blocked ? await _accountWithNewerBackup() : null,
        );
        if (entry.key != 'welcome') c.read(routerProvider).go(entry.value);
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
        await _write(tester, '${mode.tag}_${entry.key}');
      }, skip: !_capture);
    }
  }
}
