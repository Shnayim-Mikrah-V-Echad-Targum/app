import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikrah/app/providers.dart';
import 'package:shnayim_mikrah/app/router.dart';
import 'package:shnayim_mikrah/core/calendar/local_date.dart';
import 'package:shnayim_mikrah/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikrah/features/settings/app_settings.dart';
import 'package:shnayim_mikrah/l10n/app_localizations.dart';
import 'package:shnayim_mikrah/ui/theme/layout.dart';
import 'package:shnayim_mikrah/ui/widgets/common.dart';
import 'package:shnayim_mikrah/ui/widgets/paper_group.dart';
import 'package:shnayim_mikrah/ui/widgets/progress_widgets.dart';

import '../../helpers.dart';

/// A week's page on a desktop (docs/DESIGN_SYSTEM.md §9 Parsha tab, 6): the
/// parsha's head beside its aliyot, rather than over them in one narrow
/// column.
final _settings = AppSettings(onboardingComplete: true, joinDate: LocalDate(2026, 10, 4));

/// Friday 9 October 2026, Erev Shabbat Bereshit.
final _friday = DateTime(2026, 10, 9, 11);

ProgressState _bereshit() {
  final mon = LocalDate(2026, 10, 5);
  return ProgressState(weeks: {
    '5787:1': WeekProgress(weekId: '5787:1').withAliyah(0, mon).withAliyah(1, mon.addDays(1)),
  });
}

/// The extended rail and its hairline, beside the pane, from 1200.
const _rail = 257.0;

final _en = lookupAppLocalizations(const Locale('en'));
final _he = lookupAppLocalizations(const Locale('he'));

void main() {
  setUpAll(loadBundledFonts);
  setUp(ParshaRings.forgetShown);

  Future<void> open(
    WidgetTester tester,
    Size size, {
    String route = '/week/5787:1',
    AppSettings? settings,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final c = await pumpApp(tester, settings: settings ?? _settings, now: _friday, progress: _bereshit());
    c.read(routerProvider).go(route);
    await tester.pumpAndSettle();
  }

  /// The parsha's pointed name, the page's heading.
  Rect name(WidgetTester tester) => tester.getRect(find.text('בְּרֵאשִׁית'));
  Rect rings(WidgetTester tester) => tester.getRect(find.byType(RingsWithLegend));
  Rect count(WidgetTester tester) => tester.getRect(find.byType(SectionHeader));
  Rect aliyot(WidgetTester tester) => tester.getRect(find.byType(PaperGroup).first);
  Rect haftarah(WidgetTester tester) => tester.getRect(find.byType(PaperGroup).last);

  group('on a desktop', () {
    // A week opened from Today or Progress covers the window: 1366 wide, a
    // container of 1040 whose content, 32 in, is 976 wide: 5/12 and 7/12 of
    // what the gap of 24 leaves.
    const size = Size(1366, 860);
    const start = (1366 - ContentWidth.todayWide) / 2 + 32;
    const width = ContentWidth.todayWide - 2 * 32;
    const first = (width - 24) * 5 / 12;
    const second = (width - 24) * 7 / 12;

    testWidgets('sets the head of the page beside the aliyot, in columns of 5 and 7', (tester) async {
      await open(tester, size);
      expect(name(tester).left, start);
      expect(rings(tester).left, start);
      expect(rings(tester).right, lessThanOrEqualTo(start + first));

      expect(count(tester).left, moreOrLessEquals(start + first + 24));
      expect(count(tester).top, name(tester).top, reason: 'the columns start level');
      expect(aliyot(tester).left, moreOrLessEquals(start + first + 24));
      expect(aliyot(tester).width, moreOrLessEquals(second));
      expect(aliyot(tester).right, moreOrLessEquals(start + width));
      expect(haftarah(tester).left, aliyot(tester).left);
      expect(haftarah(tester).top, greaterThan(aliyot(tester).bottom));
      // The app bar's menu ends where the columns do.
      expect(tester.getRect(find.byTooltip(_en.actionMore).first).right, (1366 + ContentWidth.todayWide) / 2);
    });

    testWidgets('mirrors the columns in Hebrew, the head at the right', (tester) async {
      await open(tester, size, settings: _settings.copyWith(language: AppLanguage.hebrew));
      expect(name(tester).right, 1366 - start);
      expect(aliyot(tester).right, moreOrLessEquals(1366 - start - first - 24));
      expect(count(tester).top, name(tester).top);
    });

    testWidgets('says a week not yet open in the head, beside its aliyot', (tester) async {
      await open(tester, size, route: '/week/5787:2');
      final notice = tester.getRect(find.byType(NoticeBanner));
      expect(notice.left, start);
      expect(notice.top, greaterThan(rings(tester).bottom));
      expect(aliyot(tester).left, greaterThan(notice.right));
      expect(count(tester).top, tester.getRect(find.text('נֹחַ')).top);
    });

    testWidgets("in the Parsha tab, keeps the columns' edge for the title revealed as the name scrolls away",
        (tester) async {
      await open(tester, size, route: '/parsha');
      const tabStart = _rail + (1109 - ContentWidth.todayWide) / 2 + 32;
      expect(name(tester).left, tabStart);
      expect(aliyot(tester).right, moreOrLessEquals(tabStart + width));
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
      await tester.pumpAndSettle();
      // The parsha's name alone, as the tab says it is a parsha.
      final title = find.descendant(of: find.byType(AppBar), matching: find.text('Bereshit'));
      expect(tester.getTopLeft(title).dx, tabStart);
    });

    for (final hebrew in [false, true]) {
      final language = hebrew ? ', in Hebrew' : '';
      testWidgets('a screen reader reads the head before the aliyot$language', (tester) async {
        final handle = tester.ensureSemantics();
        final l = hebrew ? _he : _en;
        await open(tester, size, settings: hebrew ? _settings.copyWith(language: AppLanguage.hebrew) : null);
        final order = [for (final node in tester.semantics.simulatedAccessibilityTraversal()) node.label];
        int at(String label) => order.indexWhere((text) => text.contains(label));
        final (heading, legend, rishon) = hebrew
            ? (l.parshaLabel('בראשית'), l.passMikrah1, 'ראשון')
            : (l.parshaLabel('Bereshit'), l.passMikrah1, 'Rishon');
        for (final label in [heading, legend, rishon]) {
          expect(at(label), isNonNegative, reason: label);
        }
        expect(at(heading), lessThan(at(legend)));
        expect(at(legend), lessThan(at(rishon)), reason: 'down the head, then the aliyot');
        handle.dispose();
      });
    }

    testWidgets('keeps every control a labelled 48 dp target', (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester, size);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });

  // The narrowest desktop, and every text twice its size. A week opened
  // over the tabs fills the 1040 container at 1200 as at 1366; within the
  // Parsha tab, beside the extended rail, its pane is 943, which leaves 879
  // of content and the narrowest columns, about 356 and 499.
  for (final (width, scale, route) in [
    (1200.0, 1.0, '/week/5787:1'),
    (1200.0, 2.0, '/week/5787:1'),
    (1366.0, 2.0, '/week/5787:1'),
    (1200.0, 1.0, '/parsha'),
    (1200.0, 2.0, '/parsha'),
  ]) {
    final inTab = route == '/parsha';
    testWidgets(
        'at ${width.round()} dp with text at ${(scale * 100).round()}%${inTab ? ', within the Parsha tab,' : ''} '
        'sets both columns whole', (tester) async {
      await open(tester, Size(width, 3000), textScale: scale, route: route);
      expect(tester.takeException(), isNull, reason: 'nothing overflows');
      expect(aliyot(tester).left, greaterThan(rings(tester).right));
      expect(count(tester).top, name(tester).top);
      if (inTab) {
        const content = 1200 - _rail - 2 * 32;
        const first = (content - 24) * 5 / 12;
        const start = _rail + 32;
        // Within half a pixel: very large text widens the rail's labels a
        // fraction.
        expect(name(tester).left, closeTo(start, 0.5));
        expect(aliyot(tester).left, closeTo(start + first + 24, 0.5));
        expect(aliyot(tester).width, closeTo((content - 24) * 7 / 12, 0.5));
        expect(rings(tester).right, lessThanOrEqualTo(start + first + 0.5));
      }
    });
  }

  // Below 1200, one column of 720 at most, as it always was.
  for (final size in [const Size(412, 2000), const Size(800, 2000), const Size(1199, 2000)]) {
    testWidgets('at ${size.width.round()} dp, sets one column, the aliyot under the head', (tester) async {
      await open(tester, size);
      final gutter = Gutter.forWidth(size.width);
      final column = (size.width < 720 ? size.width : 720.0) - 2 * gutter;
      expect(aliyot(tester).left, name(tester).left);
      expect(aliyot(tester).width, column);
      // A section's gap under the rings, as before the columns.
      expect(count(tester).top - rings(tester).bottom, Rhythm.sectionGap);
    });
  }
}
