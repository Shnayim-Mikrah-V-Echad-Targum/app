import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikrah/app/router.dart';
import 'package:shnayim_mikrah/features/settings/app_settings.dart';
import 'package:shnayim_mikrah/l10n/app_localizations.dart';
import 'package:shnayim_mikrah/ui/theme/layout.dart';
import 'package:shnayim_mikrah/ui/widgets/common.dart';
import 'package:shnayim_mikrah/ui/widgets/ledger.dart';
import 'package:shnayim_mikrah/ui/widgets/progress_widgets.dart' show WeekStrip;

import '../../helpers.dart';

/// Progress on a desktop (docs/DESIGN_SYSTEM.md §9 Progress, 10): the
/// streaks, the year and the week beside the Torah map and the weeks gone
/// by, rather than all of it in one narrow column with the map below the
/// fold.
final _settings = AppSettings(onboardingComplete: true, joinDate: historyJoinDate);

/// The extended rail and its hairline, beside the pane, from 1200.
const _rail = 257.0;

final _en = lookupAppLocalizations(const Locale('en'));
final _he = lookupAppLocalizations(const Locale('he'));

void main() {
  setUpAll(loadBundledFonts);

  Future<void> openProgress(WidgetTester tester, Size size, {AppSettings? settings, double textScale = 1}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final c = await pumpApp(tester, settings: settings ?? _settings, now: historyNow, progress: historyProgress());
    c.read(routerProvider).go('/progress');
    await tester.pumpAndSettle();
  }

  Rect ledger(WidgetTester tester) => tester.getRect(find.byType(LedgerCard));
  Rect strip(WidgetTester tester) =>
      tester.getRect(find.ancestor(of: find.byType(WeekStrip), matching: find.byType(InfoCard)));
  Rect year(WidgetTester tester) =>
      tester.getRect(find.ancestor(of: find.text(_en.thisYear), matching: find.byType(InfoCard)).first);
  Rect mapHeader(WidgetTester tester, [AppLocalizations? l]) =>
      tester.getRect(find.ancestor(of: find.text((l ?? _en).torahMap), matching: find.byType(SectionHeader)));
  Rect recent(WidgetTester tester) => tester.getRect(find.text(_en.recentWeeks));
  Rect tile(WidgetTester tester, String name) => tester.getRect(find.bySemanticsLabel(RegExp('^$name: ')));
  Finder mapHelp(AppLocalizations l) => find.byTooltip(l.torahMapHelp);

  group('on a desktop', () {
    // 1366 wide: a pane of 1109 beside the rail, and in it a container of
    // 1040 whose content, 32 in, is 976 wide: 5/12 and 7/12 of what the gap
    // of 24 leaves.
    const size = Size(1366, 860);
    const start = _rail + (1109 - ContentWidth.todayWide) / 2 + 32;
    const width = ContentWidth.todayWide - 2 * 32;
    const first = (width - 24) * 5 / 12;
    const second = (width - 24) * 7 / 12;

    testWidgets('sets the streaks, the year and the week beside the Torah map, in columns of 5 and 7', (tester) async {
      await openProgress(tester, size);
      final title = find.descendant(of: find.byType(AppBar), matching: find.text(_en.progressTitle));
      expect(tester.getTopLeft(title).dx, start, reason: "the title on the columns' edge");

      expect(ledger(tester).left, start);
      expect(ledger(tester).width, moreOrLessEquals(first));
      expect(year(tester).left, start);
      expect(year(tester).top, greaterThan(ledger(tester).bottom));
      expect(strip(tester).left, start);
      expect(strip(tester).top, greaterThan(year(tester).bottom));

      expect(mapHeader(tester).left, moreOrLessEquals(start + first + 24));
      expect(mapHeader(tester).width, moreOrLessEquals(second));
      expect(mapHeader(tester).top, ledger(tester).top, reason: 'the columns start level');
      expect(tile(tester, 'Bereshit').left, moreOrLessEquals(mapHeader(tester).left));
      expect(tile(tester, 'Vayechi').right, moreOrLessEquals(start + width));
      expect(tile(tester, 'Vayechi').bottom, lessThan(size.height), reason: 'the open book in view without scrolling');
      expect(recent(tester).top, greaterThan(tile(tester, 'Vayechi').bottom));
      expect(recent(tester).left, greaterThan(strip(tester).right));
    });

    testWidgets('mirrors the columns in Hebrew, the streaks at the right', (tester) async {
      await openProgress(tester, size, settings: _settings.copyWith(language: AppLanguage.hebrew));
      // The rail is at the right, the pane at the left.
      const end = 1109 - (1109 - ContentWidth.todayWide) / 2 - 32;
      expect(ledger(tester).right, end);
      expect(mapHeader(tester, _he).right, moreOrLessEquals(end - first - 24));
      expect(mapHeader(tester, _he).top, ledger(tester).top);
    });

    testWidgets('with streak numbers hidden, starts the first column with its notice', (tester) async {
      await openProgress(tester, size, settings: _settings.copyWith(showStreaks: false));
      final banner = tester.getRect(find.byType(NoticeBanner));
      expect(banner.left, start);
      expect(banner.top, mapHeader(tester).top);
    });

    testWidgets('Tab goes down the streaks, the year and the week before the map', (tester) async {
      await openProgress(tester, size);
      Focus.of(tester.element(find.text(_en.aboutStreaks))).requestFocus();
      await tester.pump();
      // The week's controls, below, rather than the map's, level with it.
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(strip(tester).contains(FocusManager.instance.primaryFocus!.rect.center), isTrue);
      // Through the week, and on to the map's first control.
      for (var i = 0; i < 20 && strip(tester).contains(FocusManager.instance.primaryFocus!.rect.center); i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
      }
      expect(
        tester.getRect(mapHelp(_en)).contains(FocusManager.instance.primaryFocus!.rect.center),
        isTrue,
        reason: 'the map after the week',
      );
    });

    for (final hebrew in [false, true]) {
      final language = hebrew ? ', in Hebrew' : '';
      testWidgets('a screen reader reads the first column before the map$language', (tester) async {
        final handle = tester.ensureSemantics();
        final l = hebrew ? _he : _en;
        await openProgress(tester, size, settings: hebrew ? _settings.copyWith(language: AppLanguage.hebrew) : null);
        final order = [for (final node in tester.semantics.simulatedAccessibilityTraversal()) node.label];
        int at(String label) => order.indexWhere((text) => text.contains(label));
        for (final label in [l.aboutStreaks, l.weekStripLabel, l.torahMap, l.recentWeeks]) {
          expect(at(label), isNonNegative, reason: label);
        }
        expect(at(l.aboutStreaks), lessThan(at(l.weekStripLabel)));
        expect(at(l.weekStripLabel), lessThan(at(l.torahMap)), reason: 'down the first column, then the second');
        expect(at(l.torahMap), lessThan(at(l.recentWeeks)));
        handle.dispose();
      });
    }

    testWidgets('keeps a book of the map open as the window narrows to one column and widens again', (tester) async {
      await openProgress(tester, size);
      final exodus = find.bySemanticsLabel(RegExp('^Exodus: '));
      await tester.tap(exodus);
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel(RegExp('^Shemot: ')), findsOneWidget);
      for (final width in [1000.0, 1366.0]) {
        tester.view.physicalSize = Size(width, size.height);
        await tester.pumpAndSettle();
        expect(find.bySemanticsLabel(RegExp('^Shemot: ')), findsOneWidget, reason: 'at ${width.round()} dp');
      }
    });

    testWidgets('keeps every control a labelled 48 dp target', (tester) async {
      final handle = tester.ensureSemantics();
      await openProgress(tester, size);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });

  // The narrowest desktop, a pane of 943 beside the rail; and every text
  // twice its size.
  for (final (width, scale) in [(1200.0, 1.0), (1200.0, 2.0), (1366.0, 2.0)]) {
    testWidgets('at ${width.round()} dp with text at ${(scale * 100).round()}%, sets both columns whole',
        (tester) async {
      await openProgress(tester, Size(width, 3000), textScale: scale);
      expect(tester.takeException(), isNull, reason: 'nothing overflows');
      expect(mapHeader(tester).left, greaterThan(ledger(tester).right));
      expect(mapHeader(tester).top, ledger(tester).top);
      if (scale == 1) {
        final days = find.descendant(of: find.byType(WeekStrip), matching: find.byType(InkWell));
        expect(tester.getRect(days.first).top, tester.getRect(days.last).top, reason: 'one row of days');
      }
    });
  }

  // Below 1200, one column of 720 at most, in the order it always had.
  for (final size in [const Size(412, 2600), const Size(800, 2000), const Size(1199, 2000)]) {
    testWidgets('at ${size.width.round()} dp, sets one column, the map under the week', (tester) async {
      await openProgress(tester, size);
      final pane = size.width < Breakpoints.medium ? size.width : size.width - 81;
      final gutter = Gutter.forWidth(size.width);
      final column = (pane < 720 ? pane : 720.0) - 2 * gutter;
      expect(ledger(tester).width, column);
      expect(strip(tester).width, column);
      expect(mapHeader(tester).left, ledger(tester).left);
      expect(mapHeader(tester).width, column);
      // A section's gap below the week, as before the columns.
      expect(mapHeader(tester).top - strip(tester).bottom, Rhythm.sectionGap);
    });
  }
}
