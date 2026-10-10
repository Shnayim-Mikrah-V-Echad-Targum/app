import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/core/calendar/parsha_schedule.dart';
import 'package:shnayim_mikra/features/progress/domain/reading_plan.dart';
import 'package:shnayim_mikra/features/progress/domain/streak_engine.dart';
import 'package:shnayim_mikra/ui/theme/palette.dart';
import 'package:shnayim_mikra/ui/widgets/common.dart';
import 'package:shnayim_mikra/ui/widgets/progress_widgets.dart';

import '../helpers.dart';

/// docs/DESIGN_SYSTEM.md §6.13: the week strip and its legend.
void main() {
  // The week of Bereshit 5787 in the Diaspora: Sunday 4 October is Simchat
  // Torah, Monday to Thursday have an aliyah each (Thursday two), Friday the
  // last two, and Shabbat is the 10th.
  const planner = ReadingPlanner(schedule: ParshaSchedule(israel: false));
  final plan = planner.planFor(planner.schedule.weekFor(LocalDate(2026, 10, 7)));
  final sunday = LocalDate(2026, 10, 4);
  LocalDate day(int i) => sunday.addDays(i);
  const scheme = Palettes.light;
  final status = Palettes.statusLight;
  final sefer = Palettes.seferLight;

  Widget strip({
    WeekPlan? week,
    LocalDate? today,
    Map<LocalDate, DayStatus> statuses = const {},
    LocalDate? joinDate,
    double width = 364,
    void Function(PlanDay day)? onDayTap,
  }) =>
      Center(
        child: SizedBox(
          width: width,
          child: WeekStrip(
            plan: week ?? plan,
            today: today ?? day(5),
            statuses: statuses,
            israel: false,
            joinDate: joinDate,
            onDayTap: onDayTap ?? (_) {},
          ),
        ),
      );

  /// The day whose screen-reader label starts with [weekday].
  Finder dayOf(String weekday) => find.bySemanticsLabel(RegExp('^$weekday'));

  Color? fillOf(WidgetTester tester, String weekday) {
    final ink = find.descendant(of: dayOf(weekday), matching: find.byType(Ink));
    if (ink.evaluate().isEmpty) return null;
    return (tester.widget<Ink>(ink).decoration! as BoxDecoration).color;
  }

  test('aliyot are Hebrew ordinals: one, two with a dot, a run with a dash', () {
    expect(aliyahOrdinals([0]), 'א');
    expect(aliyahOrdinals([3, 4]), 'ד·ה');
    expect(aliyahOrdinals([4, 3]), 'ד·ה');
    expect(aliyahOrdinals([0, 1, 2, 3, 4, 5, 6]), 'א–ז');
    expect(aliyahOrdinals([0, 2]), 'א·ג');
  });

  testWidgets('each day shows its weekday, its glyph and its aliyot', (tester) async {
    await pumpThemed(
      tester,
      strip(statuses: {
        day(1): DayStatus.kept,
        day(2): DayStatus.ahead,
        day(3): DayStatus.caughtUp,
        day(4): DayStatus.grace,
      }),
    );
    for (final ordinal in ['א', 'ב', 'ג', 'ד·ה', 'ו·ז']) {
      expect(find.text(ordinal), findsOneWidget);
    }
    // Kept, ahead and caught up: a 20 px disc in done, its glyph 14 in onDone.
    for (final (weekday, glyph) in [
      ('Monday', Icons.check),
      ('Tuesday', Icons.fast_forward_rounded),
      ('Wednesday', Icons.published_with_changes),
    ]) {
      final icon = find.descendant(of: dayOf(weekday), matching: find.byIcon(glyph));
      expect(tester.widget<Icon>(icon).size, 14);
      expect(tester.widget<Icon>(icon).color, status.onDone);
      final disc = find.ancestor(of: icon, matching: find.byType(Container)).first;
      expect(tester.getSize(disc), const Size(20, 20));
      expect((tester.widget<Container>(disc).decoration! as BoxDecoration).color, status.done);
    }
    expect(find.descendant(of: dayOf('Thursday'), matching: find.byIcon(Icons.shield_outlined)), findsOneWidget);
  });

  testWidgets('today is filled and edged in primary, with a ring and dot', (tester) async {
    await pumpThemed(tester, strip());
    expect(fillOf(tester, 'Friday'), scheme.primaryContainer);
    final cell = tester.widget<Container>(
      find.descendant(
        of: dayOf('Friday'),
        matching: find.byWidgetPredicate((w) => w is Container && w.foregroundDecoration != null),
      ),
    );
    final border = (cell.foregroundDecoration! as BoxDecoration).border! as Border;
    expect(border.top, BorderSide(color: scheme.primary, width: 1.5));
    expect(find.descendant(of: dayOf('Friday'), matching: find.byType(TodayMark)), findsOneWidget);
    final label = tester.widget<Text>(find.descendant(of: dayOf('Friday'), matching: find.text('Fri')));
    expect(label.style?.fontWeight, FontWeight.w700);
    expect(label.style?.color, scheme.onSurface);
    final other = tester.widget<Text>(find.descendant(of: dayOf('Thursday'), matching: find.text('Thu')));
    expect(other.style?.color, scheme.onSurfaceVariant);
    // Every other day, past or to come, is on the card itself.
    expect(fillOf(tester, 'Thursday'), isNull);
    expect(tester.widget<Icon>(find.descendant(of: dayOf('Thursday'), matching: find.byType(Icon))).icon,
        Icons.radio_button_unchecked);
  });

  testWidgets('Shabbat and Yom Tov are washed and lit; only Yom Tov says so', (tester) async {
    await pumpThemed(tester, strip());
    for (final weekday in ['Sunday', 'Saturday']) {
      expect(fillOf(tester, weekday), sefer.restWash);
      expect(find.descendant(of: dayOf(weekday), matching: find.byType(ShabbatCandlesIcon)), findsOneWidget);
    }
    // Simchat Torah is a Sunday here, not to be taken for Shabbat.
    expect(find.descendant(of: dayOf('Sunday'), matching: find.text('Yom Tov')), findsOneWidget);
    expect(find.text('Yom Tov'), findsOneWidget);
  });

  testWidgets('a Yom Tov week is no taller than any other: its note keeps to one line', (tester) async {
    // The week of Noach has no Yom Tov.
    final noach = planner.planFor(planner.schedule.weekFor(LocalDate(2026, 10, 14)));
    for (final hebrew in [false, true]) {
      await pumpThemed(tester, strip(week: noach, today: LocalDate(2026, 10, 14)), hebrew: hebrew);
      final plain = tester.getSize(find.byType(WeekStrip)).height;
      await pumpThemed(tester, strip(), hebrew: hebrew);
      expect(tester.getSize(find.byType(WeekStrip)).height, plain, reason: hebrew ? 'he' : 'en');
      final note = find.text(hebrew ? 'יו״ט' : 'Yom Tov');
      // Within the day's wash (the slot less its 2 px margins), and clear of
      // its edges by 2 px.
      final sunday = tester.getRect(dayOf(hebrew ? 'יום ראשון' : 'Sunday'));
      final text = tester.getRect(note);
      expect(text.left, greaterThanOrEqualTo(sunday.left + 4 - 0.01), reason: hebrew ? 'he' : 'en');
      expect(text.right, lessThanOrEqualTo(sunday.right - 4 + 0.01), reason: hebrew ? 'he' : 'en');
      expect(tester.widget<Text>(note).maxLines, 1);
    }
  });

  testWidgets('Hebrew: Yom Tov reads יו״ט, and the week runs from the right', (tester) async {
    await pumpThemed(tester, strip(), hebrew: true);
    expect(find.text('יו״ט'), findsOneWidget);
    expect(tester.getCenter(dayOf('יום ראשון')).dx, greaterThan(tester.getCenter(dayOf('יום שבת')).dx));
  });

  testWidgets('a day before joining has no reading, and no aliyot under it', (tester) async {
    await pumpThemed(tester, strip(joinDate: day(2)));
    expect(find.bySemanticsLabel('Monday: No reading planned'), findsOneWidget);
    expect(find.descendant(of: dayOf('Monday'), matching: find.byIcon(Icons.horizontal_rule)), findsOneWidget);
    expect(find.text('א'), findsNothing);
    expect(find.text('ב'), findsOneWidget);
  });

  group('rows', () {
    Future<List<Rect>> days(WidgetTester tester) async => [
          for (final weekday in ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'])
            tester.getRect(dayOf(weekday)),
        ];

    // A phone's strip is its width less the page's padding (2 × 16) and the
    // strip card's (2 × 8).
    testWidgets('seven in a row where each day has 48 dp', (tester) async {
      // A 412 dp phone.
      await pumpThemed(tester, strip(width: 364));
      final rects = await days(tester);
      for (final r in rects) {
        expect(r.top, rects.first.top);
        expect(r.width, moreOrLessEquals(52));
        expect(r.height, greaterThanOrEqualTo(68));
      }
    });

    testWidgets('two rows on a 320 dp phone: Sunday to Wednesday, then Thursday on', (tester) async {
      await pumpThemed(tester, strip(width: 272));
      final rects = await days(tester);
      for (var i = 1; i < 4; i++) {
        expect(rects[i].top, rects[0].top);
      }
      expect(rects[4].top, greaterThan(rects[0].bottom));
      expect(rects[4].left, rects[0].left);
      expect(rects[6].left, rects[2].left);
      for (final r in rects) {
        expect(r.width, moreOrLessEquals(68));
      }
    });

    testWidgets('two rows when large text would not fit the weekdays', (tester) async {
      await pumpThemed(tester, strip(width: 364), textScale: 2);
      final rects = await days(tester);
      expect(rects[4].top, greaterThan(rects[0].bottom));
      expect(tester.takeException(), isNull);
    });

    testWidgets('right to left, Thursday sits under Sunday at the right', (tester) async {
      await pumpThemed(tester, strip(width: 272), hebrew: true);
      final sun = tester.getRect(dayOf('יום ראשון'));
      final thu = tester.getRect(dayOf('יום חמישי'));
      expect(thu.right, sun.right);
      expect(thu.top, greaterThan(sun.bottom));
    });
  });

  testWidgets('each planned day is one button, tapped for its aliyot', (tester) async {
    final handle = tester.ensureSemantics();
    PlanDay? tapped;
    await pumpThemed(tester, strip(onDayTap: (d) => tapped = d));
    expect(
      tester.getSemantics(dayOf('Tuesday')),
      isSemantics(label: 'Tuesday: Not yet. Sheni', isButton: true, hasTapAction: true, isFocusable: true),
    );
    // Simchat Torah has nothing to open.
    expect(tester.getSemantics(dayOf('Sunday')), isSemantics(isButton: false, hasTapAction: false));
    await tester.tap(dayOf('Tuesday'));
    expect(tapped?.aliyot, [1]);
    expect(find.byTooltip('Tuesday: Not yet. Sheni'), findsOneWidget);
    handle.dispose();
  });

  // The 48 dp target is the whole slot, its 2 px margins included.
  for (final width in [364.0, 336.0]) {
    testWidgets('at ${(width / 7).round()} dp a day, a tap on its margin opens it', (tester) async {
      final tapped = <List<int>>[];
      await pumpThemed(tester, strip(width: width, onDayTap: (d) => tapped.add(d.aliyot)));
      final tuesday = tester.getRect(dayOf('Tuesday'));
      expect(tuesday.width, moreOrLessEquals(width / 7));
      await tester.tapAt(Offset(tuesday.left + 1, tuesday.center.dy));
      await tester.tapAt(Offset(tuesday.right - 1, tuesday.center.dy));
      expect(tapped, [
        [1],
        [1],
      ]);
    });
  }

  testWidgets('a day that changes cross-fades to its new glyph over 250 ms', (tester) async {
    await pumpThemed(tester, strip());
    await pumpThemed(tester, strip(statuses: {day(5): DayStatus.kept}));
    await tester.pump(const Duration(milliseconds: 125));
    final friday = dayOf('Friday');
    expect(find.descendant(of: friday, matching: find.byType(TodayMark)), findsOneWidget);
    expect(find.descendant(of: friday, matching: find.byIcon(Icons.check)), findsOneWidget);
    final fades = tester.widgetList<FadeTransition>(find.descendant(of: friday, matching: find.byType(FadeTransition)));
    expect(fades.map((f) => f.opacity.value), everyElement(inExclusiveRange(0, 1)));
    expect(find.descendant(of: friday, matching: find.byType(ScaleTransition)), findsNothing);
    await tester.pump(const Duration(milliseconds: 130));
    expect(find.descendant(of: friday, matching: find.byType(TodayMark)), findsNothing);
  });

  testWidgets('with motion reduced, the new glyph is simply there', (tester) async {
    Widget still(Widget child) => Builder(
          builder: (context) =>
              MediaQuery(data: MediaQuery.of(context).copyWith(disableAnimations: true), child: child),
        );
    await pumpThemed(tester, still(strip()));
    await pumpThemed(tester, still(strip(statuses: {day(5): DayStatus.kept})));
    await tester.pump();
    expect(find.descendant(of: dayOf('Friday'), matching: find.byType(TodayMark)), findsNothing);
  });

  testWidgets('the legend button opens, by keyboard, a sheet naming every glyph', (tester) async {
    await pumpThemed(tester, const Center(child: WeekStripLegendButton()));
    expect(find.byTooltip('Legend'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(SheetTitle, 'Legend'), findsOneWidget);
    for (final label in [
      'Today',
      'Read',
      'Ahead of plan',
      'Caught up',
      'Covered by a grace day',
      'Not yet',
      'Not read',
      'Paused',
      'Upcoming',
      'No reading planned',
      'Shabbat or Yom Tov',
    ]) {
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.byType(TodayMark), findsOneWidget);
    expect(find.byType(ShabbatCandlesIcon), findsOneWidget);
  });
}
