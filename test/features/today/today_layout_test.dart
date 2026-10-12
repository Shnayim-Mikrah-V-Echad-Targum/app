import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/features/today/today_screen.dart';
import 'package:shnayim_mikra/l10n/app_localizations.dart';
import 'package:shnayim_mikra/ui/theme/layout.dart';
import 'package:shnayim_mikra/ui/widgets/common.dart';
import 'package:shnayim_mikra/ui/widgets/ledger.dart';
import 'package:shnayim_mikra/ui/widgets/ornaments.dart' show TitlePageFrame;
import 'package:shnayim_mikra/ui/widgets/paper_group.dart';
import 'package:shnayim_mikra/ui/widgets/progress_widgets.dart' show WeekStrip;

import '../../helpers.dart';

/// Joined before the week of Bereshit, with Rishon and Sheni read.
final _settings = AppSettings(onboardingComplete: true, joinDate: LocalDate(2026, 10, 4));

ProgressState _bereshit() {
  final mon = LocalDate(2026, 10, 5);
  return ProgressState(weeks: {
    '5787:1': WeekProgress(weekId: '5787:1').withAliyah(0, mon).withAliyah(1, mon.addDays(1)),
  });
}

/// Friday 9 October 2026, Erev Shabbat Bereshit, in the morning; and
/// Shabbat Bereshit.
final _friday = DateTime(2026, 10, 9, 11);
final _shabbat = DateTime(2026, 10, 10, 11);

/// The extended rail and its hairline, beside the pane, from 1200.
const _rail = 257.0;

final _en = lookupAppLocalizations(const Locale('en'));
final _he = lookupAppLocalizations(const Locale('he'));

void main() {
  setUpAll(loadBundledFonts);
  setUp(TodayScreen.forgetCompletions);

  Future<void> openToday(
    WidgetTester tester,
    Size size, {
    AppSettings? settings,
    DateTime? now,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await pumpApp(tester, settings: settings ?? _settings, now: now ?? _friday, progress: _bereshit());
    await tester.pumpAndSettle();
  }

  Rect hero(WidgetTester tester) => tester.getRect(find.byType(TitlePageFrame));
  Rect strip(WidgetTester tester) =>
      tester.getRect(find.ancestor(of: find.byType(WeekStrip), matching: find.byType(InfoCard)));
  Rect today(WidgetTester tester) =>
      tester.getRect(find.ancestor(of: find.text('Catching up'), matching: find.byType(InfoCard)));
  // The masthead, which on a desktop is the tab's name, the rail beside it
  // carrying the app's.
  Finder masthead(String text) => find.descendant(of: find.byType(TodayScreen), matching: find.text(text));
  Rect header(WidgetTester tester) => tester.getRect(masthead(_en.navToday));

  group('on a desktop', () {
    // 1366 wide: a pane of 1109 beside the rail, and in it a container of
    // 1040 whose content, 32 in, is 976 wide: 7/12 and 5/12 of what the gap
    // of 24 leaves.
    const size = Size(1366, 860);
    const start = _rail + (1109 - ContentWidth.todayWide) / 2 + 32;
    const width = ContentWidth.todayWide - 2 * 32;
    const main = (width - 24) * 7 / 12;
    const side = (width - 24) * 5 / 12;

    testWidgets('sets the title page and today beside the week, in columns of 7 and 5 under the header',
        (tester) async {
      await openToday(tester, size);
      expect(header(tester).left, start);
      final help = tester.getRect(find.byTooltip('How it works'));
      expect(help.right, start + width, reason: "the header's button ends where the columns do");

      expect(hero(tester).left, start);
      expect(hero(tester).width, moreOrLessEquals(main));
      expect(today(tester).left, start);
      expect(today(tester).top, greaterThan(hero(tester).bottom));

      expect(strip(tester).left, moreOrLessEquals(start + main + 24));
      expect(strip(tester).width, moreOrLessEquals(side));
      expect(strip(tester).top, hero(tester).top, reason: 'the columns start level');
      final ledger = tester.getRect(find.byType(LedgerCard));
      final group = tester.getRect(find.byType(PaperGroup));
      expect(ledger.left, strip(tester).left);
      expect(ledger.top, greaterThan(strip(tester).bottom));
      expect(group.right, moreOrLessEquals(start + width));
      expect(group.top, greaterThan(ledger.bottom));
      expect(group.bottom, lessThan(size.height), reason: 'the week in view without scrolling');
    });

    testWidgets('mirrors the columns in Hebrew, the title page at the right', (tester) async {
      await openToday(tester, size, settings: _settings.copyWith(language: AppLanguage.hebrew));
      // The rail is at the right, the pane at the left.
      const end = 1109 - (1109 - ContentWidth.todayWide) / 2 - 32;
      expect(hero(tester).right, end);
      expect(strip(tester).right, moreOrLessEquals(end - main - 24));
      expect(strip(tester).top, hero(tester).top);
    });

    for (final hebrew in [false, true]) {
      final language = hebrew ? ', in Hebrew' : '';
      testWidgets("Tab goes down the title page and today's reading before the week$language", (tester) async {
        final l = hebrew ? _he : _en;
        await openToday(tester, size, settings: hebrew ? _settings.copyWith(language: AppLanguage.hebrew) : null);
        // Focuses the control around [inside], then moves on as Tab does, and
        // gives where focus lands.
        Future<Rect> tabFrom(Finder inside) async {
          Focus.of(tester.element(inside)).requestFocus();
          await tester.pump();
          FocusManager.instance.primaryFocus!.nextFocus();
          await tester.pump();
          return FocusManager.instance.primaryFocus!.rect;
        }

        // From the header's button, the title page's first control rather
        // than the week's, which is higher on the page: in Hebrew, the
        // column at the right.
        final afterHelp = await tabFrom(find.descendant(of: find.byTooltip(l.guideTitle), matching: find.byType(Icon)));
        expect(hero(tester).contains(afterHelp.center), isTrue);
        // From the first column's last control, the week's first.
        final afterChumash = await tabFrom(find.text(l.readFromBook));
        expect(strip(tester).contains(afterChumash.center), isTrue);
      });
    }

    testWidgets('keeps the focus where it is as the window narrows to one column and widens again', (tester) async {
      await openToday(tester, size);
      final button = find.descendant(of: find.byType(TitlePageFrame), matching: find.byType(FilledButton));
      Focus.of(tester.element(find.descendant(of: button, matching: find.byType(Text)).first)).requestFocus();
      await tester.pump();
      final focused = FocusManager.instance.primaryFocus;
      expect(focused, isNotNull);
      expect(tester.getRect(button).contains(focused!.rect.center), isTrue);

      for (final width in [1000.0, 1920.0, 1366.0]) {
        tester.view.physicalSize = Size(width, size.height);
        await tester.pumpAndSettle();
        expect(FocusManager.instance.primaryFocus, same(focused), reason: 'at ${width.round()} dp');
        expect(focused.context!.mounted, isTrue);
        expect(tester.getRect(button).contains(focused.rect.center), isTrue);
      }
      // Each column a group of its own again.
      expect(strip(tester).top, hero(tester).top);
    });

    for (final hebrew in [false, true]) {
      final language = hebrew ? ', in Hebrew' : '';
      testWidgets("a screen reader reads the title page and today's reading before the week$language", (tester) async {
        final handle = tester.ensureSemantics();
        await openToday(tester, size, settings: hebrew ? _settings.copyWith(language: AppLanguage.hebrew) : null);
        final order = [for (final node in tester.semantics.simulatedAccessibilityTraversal()) node.label];
        int at(String label) => order.indexWhere((l) => l.contains(label));
        final (button, chumash, week, discuss) = hebrew
            ? ('המשך', 'קראתי בחומש', 'התוכנית לשבוע זה', 'דיון על פרשת השבוע')
            : ('Continue', 'I read it in a Chumash', 'This week’s plan', 'Discuss this week’s parsha');
        for (final label in [button, chumash, week, discuss]) {
          expect(at(label), isNonNegative, reason: label);
        }
        expect(at(button), lessThan(at(chumash)));
        expect(at(chumash), lessThan(at(week)), reason: 'down the first column, then the second');
        expect(at(week), lessThan(at(discuss)));
        handle.dispose();
      });
    }

    testWidgets('keeps every control a labelled 48 dp target', (tester) async {
      final handle = tester.ensureSemantics();
      await openToday(tester, size);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });

    testWidgets('keeps the day of rest to a single column', (tester) async {
      await openToday(tester, size, now: _shabbat);
      expect(find.byType(WeekStrip), findsNothing);
      expect(hero(tester).width, ContentWidth.list - 2 * 32);
      expect(hero(tester).center.dx, _rail + 1109 / 2);
    });

    for (final (hebrew, rest) in [(false, false), (true, false), (false, true), (true, true)]) {
      final when = '${rest ? ' on the day of rest' : ''}${hebrew ? ', in Hebrew' : ''}';
      testWidgets("titles the page with the tab's name, not the app's, which the rail beside it carries$when",
          (tester) async {
        final handle = tester.ensureSemantics();
        final l = hebrew ? _he : _en;
        await openToday(
          tester,
          size,
          settings: hebrew ? _settings.copyWith(language: AppLanguage.hebrew) : null,
          now: rest ? _shabbat : null,
        );
        expect(masthead(l.navToday), findsOneWidget);
        expect(masthead(l.appTitle), findsNothing);
        expect(find.text(l.appTitle), findsOneWidget, reason: "the rail's wordmark");
        expect(tester.getSemantics(masthead(l.navToday)), isSemantics(isHeader: false));
        handle.dispose();
      });
    }
  });

  // A phone's or a tablet's rail is the mark alone, and so is a window's
  // under 1200: the masthead names the app.
  for (final (width, hebrew) in [(412.0, false), (412.0, true), (800.0, false), (1199.0, false)]) {
    testWidgets("at ${width.round()} dp${hebrew ? ', in Hebrew' : ''}, the masthead names the app", (tester) async {
      final l = hebrew ? _he : _en;
      await openToday(
        tester,
        Size(width, 1200),
        settings: hebrew ? _settings.copyWith(language: AppLanguage.hebrew) : null,
      );
      expect(masthead(l.appTitle), findsOneWidget);
      expect(masthead(l.navToday), findsNothing);
    });
  }

  // The narrowest desktop: a pane of 943 beside the rail, and the week's
  // seven days still in one row; and every text twice its size.
  for (final (width, scale) in [(1200.0, 1.0), (1200.0, 2.0), (1366.0, 2.0)]) {
    testWidgets('at ${width.round()} dp with text at ${(scale * 100).round()}%, sets both columns whole',
        (tester) async {
      await openToday(tester, Size(width, 3000), textScale: scale);
      expect(tester.takeException(), isNull, reason: 'nothing overflows');
      expect(strip(tester).left, greaterThan(hero(tester).right));
      if (scale == 1) {
        final days = find.descendant(of: find.byType(WeekStrip), matching: find.byType(InkWell));
        expect(tester.getRect(days.first).top, tester.getRect(days.last).top, reason: 'one row of days');
      }
    });
  }

  for (final width in [800.0, 1199.0]) {
    testWidgets('at ${width.round()} dp, sets one column of 720 at most', (tester) async {
      await openToday(tester, Size(width, 2000));
      final pane = width - 81;
      final column = (pane < 720 ? pane : 720.0) - 2 * 24;
      expect(hero(tester).width, column);
      expect(strip(tester).left, hero(tester).left);
      expect(strip(tester).width, column);
      expect(strip(tester).top, greaterThan(today(tester).bottom));
    });
  }
}
