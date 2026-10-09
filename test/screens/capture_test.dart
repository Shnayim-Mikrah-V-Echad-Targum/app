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

import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikra/features/reader/scripture_text.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';

import '../helpers.dart';

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
  'welcome': '/welcome',
  'today': '/today',
  'parsha': '/parsha',
  'browse': '/parsha/browse',
  'week': '/week/5787:1',
  'reader': '/read/5787:1/2',
  'reader_full': '/read/5787:1/2?mode=full',
  'reader_focus': '/read/5787:1/2?mode=full',
  'haftarah': '/haftarah/5787:1',
  'progress': '/progress',
  'community': '/community',
  'forum': '/community/forum/parsha',
  'thread': '/community/thread/1',
  'compose': '/community/new',
  'account': '/community/account',
  'settings': '/settings',
  's_reading': '/settings/reading',
  's_display': '/settings/display',
  's_fonts': '/settings/display',
  's_a11y': '/settings/accessibility',
  's_reminders': '/settings/reminders',
  's_data': '/settings/data',
  'about': '/settings/about',
  'guide': '/guide',
};

/// Screens that need more than a route: extra settings, and a first tap once
/// the screen has loaded.
final _screenSettings = <String, AppSettings Function(AppSettings)>{
  'reader_focus': (s) => s.copyWith(focusMode: true, showTranslation: true),
};
final _screenSetup = <String, Future<void> Function(WidgetTester)>{
  // Focus the second verse (each verse is followed by its Targum), so there
  // are dimmed verses above and below it.
  'reader_focus': (tester) => tester.tap(find.byType(ScriptureVerse).at(2)),
  // The interface font choices, at the end of the Display page.
  's_fonts': (tester) => tester.ensureVisible(find.byType(RadioListTile<UiFont>).last),
};

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
  _Mode('sepia', const Size(412, 915), (s) => s.copyWith(theme: AppThemeMode.sepia)),
  _Mode('hcl', const Size(412, 915), (s) => s.copyWith(theme: AppThemeMode.highContrastLight)),
  _Mode('lexend', const Size(412, 915), (s) => s.copyWith(uiFont: UiFont.lexend)),
];

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
      if (mode.tag == 'desktop' && !const {'today', 'week', 'reader', 'reader_full', 'progress', 'thread', 'settings', 'welcome'}.contains(entry.key)) {
        continue;
      }
      final only = _only;
      if (only != null && !only.contains(entry.key)) continue;
      testWidgets('${mode.tag} ${entry.key}', (tester) async {
        tester.view.physicalSize = mode.size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final base = (_screenSettings[entry.key] ?? (s) => s)(
          AppSettings(onboardingComplete: entry.key != 'welcome', joinDate: _join),
        );
        final c = await pumpApp(tester, settings: mode.settings(base), now: _now, progress: _progress());
        if (entry.key != 'welcome') c.read(routerProvider).go(entry.value);
        await _settle(tester);
        final setup = _screenSetup[entry.key];
        if (setup != null) {
          await setup(tester);
          await _settle(tester);
        }
        await _write(tester, '${mode.tag}_${entry.key}');
      }, skip: !_capture);
    }
  }
}
