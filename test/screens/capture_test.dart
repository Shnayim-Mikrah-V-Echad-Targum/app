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
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikra/features/reader/scripture_text.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/ui/theme/focus.dart';
import 'package:shnayim_mikra/ui/widgets/common.dart';
import 'package:shnayim_mikra/ui/widgets/paper_group.dart';
import 'package:shnayim_mikra/ui/widgets/progress_widgets.dart';

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
  // The legend behind the week strip's info button.
  'legend_week': '/progress',
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
  // The middle row of a paper group: its ring must clear the hairlines.
  'kit_focus': (tester) async {
    await _showGallery(tester, const RowsGallery());
    await _settle(tester);
    await _keyboardFocus(
      tester,
      find.descendant(of: find.byType(PaperGroup).first, matching: find.byType(SeferInkWell)).at(1),
    );
  },
};

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
  'week',
  'reader',
  'reader_full',
  'progress',
  'thread',
  'settings',
  'welcome',
  'dialog',
  'sheet_display',
  'focus_nav',
  'kit_ornaments',
  'kit_rows',
  'kit_progress',
  'kit_week',
};
// The wide modes render only the screens above.
const _wideModes = {'desktop', 'tablet', 'deskhe', 'deskhc'};
const _tallScreens = {'today', 'parsha', 'week', 'progress', 's_display'};
const _bigTextModes = {'big', 'bighe'};
const _narrowScreens = {'today', 'progress', 'kit_week'};
const _bigTextScreens = {'today', 'progress', 'reader', 'kit_ornaments', 'kit_rows', 'kit_progress', 'kit_week'};

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
        // Soft shadows, as a device draws them; tests otherwise draw them as
        // solid lines. Restored before the test ends, as the binding checks.
        debugDisableShadows = false;
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
        debugDisableShadows = true;
      }, skip: !_capture);
    }
  }
}
