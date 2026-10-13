import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikrah/app/providers.dart';
import 'package:shnayim_mikrah/app/router.dart';
import 'package:shnayim_mikrah/core/calendar/local_date.dart';
import 'package:shnayim_mikrah/data/models/verse_ref.dart';
import 'package:shnayim_mikrah/features/notes/notes_screen.dart';
import 'package:shnayim_mikrah/features/parsha/browse_screen.dart';
import 'package:shnayim_mikrah/features/parsha/week_overview_screen.dart';
import 'package:shnayim_mikrah/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikrah/features/progress/domain/reading_plan.dart';
import 'package:shnayim_mikrah/features/settings/app_settings.dart';
import 'package:shnayim_mikrah/ui/theme/app_theme.dart';
import 'package:shnayim_mikrah/ui/widgets/ornaments.dart';
import 'package:shnayim_mikrah/ui/widgets/paper_group.dart';
import 'package:shnayim_mikrah/ui/widgets/progress_widgets.dart';

import '../../helpers.dart';

/// Joined on Sunday 4 October 2026 (Simchat Torah outside Israel), before
/// the week of Bereshit began on Monday the 5th. Its plan: Rishon on Monday,
/// Sheni on Tuesday, Shlishi on Wednesday, Revi'i and Chamishi on Thursday,
/// and Shishi and Shevi'i on Friday.
final _settings = AppSettings(onboardingComplete: true, joinDate: LocalDate(2026, 10, 4));

/// Friday 9 October 2026, Erev Shabbat Bereshit.
final _friday = DateTime(2026, 10, 9, 11);

/// Rishon and Sheni read, and Shlishi read twice in Hebrew.
ProgressState _bereshit() {
  final mon = LocalDate(2026, 10, 5);
  var w = WeekProgress(weekId: '5787:1').withAliyah(0, mon).withAliyah(1, mon.addDays(1));
  w = w.withUnit(2, ReadingPass.mikra1, mon.addDays(2)).withUnit(2, ReadingPass.mikra2, mon.addDays(2));
  return ProgressState(weeks: {'5787:1': w});
}

void main() {
  setUp(ParshaRings.forgetShown);

  Future<ProviderContainer> open(
    WidgetTester tester, {
    String route = '/parsha',
    AppSettings? settings,
    ProgressState? progress,
    DateTime? now,
    Size size = const Size(412, 915),
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = textScale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    final c = await pumpApp(
      tester,
      settings: settings ?? _settings,
      now: now ?? _friday,
      progress: progress ?? _bereshit(),
    );
    c.read(routerProvider).go(route);
    await tester.pumpAndSettle();
    return c;
  }

  /// The row of the aliyah named [name].
  Finder row(String name) => find.ancestor(of: find.text(name), matching: find.byType(SeferInkWell)).first;

  /// The Text in [row] that holds [text], a Text.rich among them.
  Text textIn(WidgetTester tester, Finder row, String text) =>
      tester.widget<Text>(find.descendant(of: row, matching: find.textContaining(text)).first);

  group('the head of the page', () {
    testWidgets("names the parsha in pointed Hebrew as the page's heading, and in English under it",
        (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester);
      expect(find.text('בְּרֵאשִׁית'), findsOneWidget);
      expect(find.text('Bereshit'), findsOneWidget);
      final heading = tester.getSemantics(find.bySemanticsLabel('Parshat Bereshit'));
      expect(heading, isSemantics(label: 'Parshat Bereshit', isHeader: true, namesRoute: true));
      expect(heading.getSemanticsData().headingLevel, 1);
      // Its verses, and when it is read in both calendars.
      expect(find.textContaining(RegExp(r'^Genesis 1:1–6:8( · 146 verses)?$')), findsOneWidget);
      expect(findWords('Read on Shabbat, October 10'), findsOneWidget);
      expect(find.textContaining(RegExp(r'(^| · )29 Tishrei 5787$')), findsOneWidget);
      expect(find.textContaining('In progress'), findsOneWidget);
      expect(find.byType(RingsWithLegend), findsOneWidget);
      expect(tester.widget<RingsWithLegend>(find.byType(RingsWithLegend)).size, ParshaRings.header);
      handle.dispose();
    });

    testWidgets('names the parsha in the app bar too once it has scrolled out of sight', (tester) async {
      await open(tester);
      double opacity() => tester
          .widget<AnimatedOpacity>(find.descendant(of: find.byType(AppBar), matching: find.byType(AnimatedOpacity)))
          .opacity;
      expect(opacity(), 0);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(opacity(), 1);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 300));
      await tester.pumpAndSettle();
      expect(opacity(), 0);
    });

    testWidgets('takes the name back from the app bar when the page comes to fit without a scroll', (tester) async {
      await open(tester);
      double opacity() => tester
          .widget<AnimatedOpacity>(find.descendant(of: find.byType(AppBar), matching: find.byType(AnimatedOpacity)))
          .opacity;
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(opacity(), 1);
      // A window made tall enough for the whole page: its offset goes back
      // to the top without a scroll of the reader's.
      tester.view.physicalSize = const Size(412, 4000);
      await tester.pumpAndSettle();
      expect(opacity(), 0);
    });

    testWidgets('in Hebrew, gives the English name under the Hebrew, in English', (tester) async {
      await open(tester, settings: _settings.copyWith(language: AppLanguage.hebrew));
      expect(find.text('בְּרֵאשִׁית'), findsOneWidget);
      final english = tester.widget<Text>(find.text('Bereshit'));
      expect(english.textDirection, TextDirection.ltr);
    });
  });

  group('the aliyot', () {
    testWidgets('are seven rows of one sheet, each its name, verses and time, and its day', (tester) async {
      await open(tester);
      final group = find.ancestor(of: find.text('Rishon'), matching: find.byType(PaperGroup));
      expect(tester.widget<PaperGroup>(group).ruleInset, 72);
      for (final name in ['Rishon', 'Sheni', 'Shlishi', 'Revi’i', 'Chamishi', 'Shishi', 'Shevi’i']) {
        expect(find.descendant(of: group, matching: find.text(name)), findsOneWidget, reason: name);
      }
      // The aliyah's number is said, not shown: a Hebrew ordinal in its disc.
      expect(find.textContaining('· aliyah'), findsNothing);
      expect(find.descendant(of: row('Revi’i'), matching: find.text('ד')), findsOneWidget);
      // The book is named at the head of the page.
      // On one line where it fits, or a line a part.
      final parts = [
        for (final t in tester.widgetList<Text>(find.descendant(of: row('Rishon'), matching: find.byType(Text))))
          ...?t.data?.split(' · '),
      ];
      expect(parts, containsAllInOrder(['1:1\u2060–\u20602:3', '34 verses', 'about 15 min', 'Planned for Monday']));
    });

    testWidgets("today's say so in bold, and those of a day gone by still to read say it in gold", (tester) async {
      await open(tester);
      final context = tester.element(find.byType(WeekOverview));
      final scheme = Theme.of(context).colorScheme;
      final overdue = StatusColors.of(context).overdue;

      for (final name in ['Shishi', 'Shevi’i']) {
        final today = textIn(tester, row(name), 'Planned for today');
        expect(today.style?.fontWeight, FontWeight.w700, reason: name);
        expect(today.style?.color, scheme.onSurface, reason: name);
      }
      for (final (name, day) in [('Shlishi', 'Wednesday'), ('Revi’i', 'Thursday'), ('Chamishi', 'Thursday')]) {
        expect(textIn(tester, row(name), 'Planned for $day').style?.color, overdue, reason: name);
        expect(find.descendant(of: row(name), matching: find.byIcon(stillToReadIcon)), findsOneWidget, reason: name);
      }
      // Read on their days: plain.
      expect(textIn(tester, row('Rishon'), 'Planned for Monday').style?.color, scheme.onSurfaceVariant);
      expect(find.descendant(of: row('Rishon'), matching: find.byIcon(stillToReadIcon)), findsNothing);
    });

    testWidgets('planned for a day before the reader joined are never overdue', (tester) async {
      // Joined on Wednesday, starting with that day's reading.
      await open(
        tester,
        settings: _settings.copyWith(joinDate: LocalDate(2026, 10, 7), starterCatchUp: false),
        progress: const ProgressState(),
      );
      expect(find.descendant(of: row('Rishon'), matching: find.byIcon(stillToReadIcon)), findsNothing);
      expect(find.descendant(of: row('Sheni'), matching: find.byIcon(stillToReadIcon)), findsNothing);
      expect(find.descendant(of: row('Shlishi'), matching: find.byIcon(stillToReadIcon)), findsOneWidget);
    });

    group('are never overdue on a day that does not count', () {
      void expectNoneOverdue(WidgetTester tester) {
        final overdue = StatusColors.of(tester.element(find.byType(WeekOverview))).overdue;
        expect(find.byIcon(stillToReadIcon), findsNothing);
        for (final (name, day) in [('Shlishi', 'Wednesday'), ('Revi’i', 'Thursday'), ('Chamishi', 'Thursday')]) {
          expect(textIn(tester, row(name), 'Planned for $day').style?.color, isNot(overdue), reason: name);
        }
      }

      testWidgets('while paused', (tester) async {
        await open(
          tester,
          progress: ProgressState(weeks: _bereshit().weeks, pauses: [Pause(LocalDate(2026, 10, 8), LocalDate(2026, 10, 18))]),
        );
        expectNoneOverdue(tester);
      });

      testWidgets('on the days a pause covered', (tester) async {
        // Paused Wednesday and Thursday; Friday is a day back.
        await open(
          tester,
          progress: ProgressState(weeks: _bereshit().weeks, pauses: [Pause(LocalDate(2026, 10, 7), LocalDate(2026, 10, 8))]),
        );
        expectNoneOverdue(tester);
        expect(find.text('Planned for today'), findsNWidgets(2));
      });

      testWidgets('in a past week a pause kept from counting', (tester) async {
        // Bereshit, paused throughout, seen once its late window is over.
        await open(
          tester,
          route: '/week/5787:1',
          now: DateTime(2026, 10, 22, 10),
          progress: ProgressState(weeks: _bereshit().weeks, pauses: [Pause(LocalDate(2026, 10, 5), LocalDate(2026, 10, 10))]),
        );
        expect(find.textContaining('Not counted'), findsOneWidget);
        expectNoneOverdue(tester);
        expect(find.descendant(of: row('Shishi'), matching: find.byIcon(stillToReadIcon)), findsNothing);
      });
    });

    group("planned for Shabbat morning (the plan with Shevi'i on Shabbat)", () {
      final shabbatPlan = _settings.copyWith(plan: ReadingPlanType.sheviiOnShabbat);

      testWidgets('say so, and are not behind before Shabbat', (tester) async {
        await open(tester, settings: shabbatPlan);
        final line = textIn(tester, row('Shevi’i'), 'Shabbat morning');
        expect(line.data, 'Shabbat morning — log it after Shabbat');
        expect(find.descendant(of: row('Shevi’i'), matching: find.byIcon(stillToReadIcon)), findsNothing);
      });

      testWidgets('are still to read once Shabbat has passed', (tester) async {
        final handle = tester.ensureSemantics();
        // Sunday after Shabbat Bereshit, everything but Shevi'i read.
        var w = WeekProgress(weekId: '5787:1');
        for (var a = 0; a < 6; a++) {
          w = w.withAliyah(a, LocalDate(2026, 10, 5 + (a < 5 ? a : 4)));
        }
        await open(
          tester,
          route: '/week/5787:1',
          settings: shabbatPlan,
          now: DateTime(2026, 10, 11, 10),
          progress: ProgressState(weeks: {'5787:1': w}),
        );
        final overdue = StatusColors.of(tester.element(find.byType(WeekOverview))).overdue;
        expect(textIn(tester, row('Shevi’i'), 'Shabbat morning').style?.color, overdue);
        expect(find.descendant(of: row('Shevi’i'), matching: find.byIcon(stillToReadIcon)), findsOneWidget);
        expect(
          tester.getSemantics(find.text('Shevi’i')).getSemanticsData().label,
          contains('Planned for Shabbat morning, still to read'),
        );
        handle.dispose();
      });
    });

    testWidgets('of a past week finished on its days are plain, with no reading under way', (tester) async {
      var w = WeekProgress(weekId: '5787:1');
      for (var a = 0; a < 7; a++) {
        w = w.withAliyah(a, LocalDate(2026, 10, 5 + (a < 5 ? a : 4)));
      }
      await open(tester, route: '/week/5787:1', now: DateTime(2026, 10, 22, 10), progress: ProgressState(weeks: {'5787:1': w}));
      expect(find.text('Planned for today'), findsNothing);
      expect(find.byIcon(stillToReadIcon), findsNothing);
      expect([for (final p in tester.widgetList<PassPips>(find.byType(PassPips))) p.current], everyElement(isNull));
      expect(find.descendant(of: row('Shlishi'), matching: find.byIcon(Icons.check)), findsOneWidget);
    });

    testWidgets("of next week's preview have no reading under way, no today and nothing behind", (tester) async {
      await open(tester, route: '/week/5787:2');
      expect(findWords('Preview — you can log this parsha from'), findsOneWidget);
      expect(find.text('Planned for today'), findsNothing);
      expect(find.byIcon(stillToReadIcon), findsNothing);
      expect([for (final p in tester.widgetList<PassPips>(find.byType(PassPips))) p.current], everyElement(isNull));
    });

    testWidgets("show their three readings, the current one ringed, and a check once they're done", (tester) async {
      await open(tester);
      const done = PipState.done, pending = PipState.pending;
      final pips = tester.widgetList<PassPips>(find.byType(PassPips)).toList();
      expect(pips, hasLength(7));
      expect(pips[0].states, [done, done, done]);
      expect(pips[2].states, [done, done, pending]);
      expect(pips[3].states, [pending, pending, pending]);
      expect(pips.map((p) => p.size), everyElement(PassPips.full));
      // The Targum of Shlishi is where the reading continues.
      expect([for (final p in pips) p.current], [null, null, 2, null, null, null, null]);
      expect(find.descendant(of: row('Rishon'), matching: find.byIcon(Icons.check)), findsOneWidget);
      expect(find.descendant(of: row('Shlishi'), matching: find.byIcon(Icons.check)), findsNothing);
    });

    testWidgets('read to a screen reader with their number and the state of each reading', (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester);
      final data = tester.getSemantics(find.text('Shlishi')).getSemanticsData();
      expect(data.label, startsWith('Shlishi · aliyah 3\n'));
      // The overdue colour and mark, in words.
      expect(data.label, contains('Planned for Wednesday, still to read'));
      expect(data.value, 'First reading: done, Second reading: done, Targum: not done');
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      // The menu is reached on its own.
      expect(find.byTooltip('More options for Shlishi'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('open the reader at the aliyah tapped', (tester) async {
      final c = await open(tester);
      await tester.ensureVisible(find.text('Revi’i'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Revi’i'));
      await tester.pump();
      expect(c.read(routerProvider).state.uri.toString(), '/read/5787:1/3?from=week');
    });

    // §9 Parsha, 3: rather than leave the lines a word or two each between
    // the disc and the pips. In the test font, whose letters are as wide as
    // they are high, a small phone at 200% squeezes them already.
    for (final hebrew in [false, true]) {
      testWidgets('stack with large text, the lines their full width and the pips over the menu under them'
          '${hebrew ? ', in Hebrew' : ''}', (tester) async {
        final handle = tester.ensureSemantics();
        await open(
          tester,
          settings: _settings.copyWith(language: hebrew ? AppLanguage.hebrew : AppLanguage.system),
          size: const Size(320, 3600),
          textScale: 2,
        );
        expect(tester.takeException(), isNull);
        final name = hebrew ? 'ראשון' : 'Rishon';
        final rishon = row(name);
        final box = tester.getRect(rishon);
        double fromStart(Rect r) => hebrew ? box.right - r.right : r.left - box.left;
        double fromEnd(Rect r) => hebrew ? r.left - box.left : box.right - r.right;
        final disc = tester.getRect(find.descendant(of: rishon, matching: find.byIcon(Icons.check)));
        final title = tester.getRect(find.text(name));
        expect(title.center.dy, moreOrLessEquals(disc.center.dy, epsilon: 1), reason: 'the name beside its disc');
        // The verses, under the name, from the row's start.
        final verses = find.descendant(of: rishon, matching: find.text(hebrew ? '34 פסוקים' : '34 verses'));
        final facts = tester.getRect(verses);
        expect(fromStart(facts), 16);
        expect(facts.top, greaterThanOrEqualTo(title.bottom - 1));
        // Lines of 18 or 20, at 200%.
        expect(tester.renderObject<RenderParagraph>(verses).size.height, lessThan(2 * 2 * 18), reason: 'one line');
        // The pips at the start and the menu at the end, under the lines.
        final pips = tester.getRect(find.descendant(of: rishon, matching: find.byType(PassPips)));
        final menuButton = find.byTooltip(hebrew ? 'אפשרויות נוספות עבור $name' : 'More options for $name');
        final menu = tester.getRect(menuButton);
        expect(pips.top, greaterThanOrEqualTo(facts.bottom));
        expect(fromStart(pips), 16);
        expect(fromEnd(menu), 10);
        expect(pips.center.dy, moreOrLessEquals(menu.center.dy, epsilon: 0.5));
        // Still one button, beside the menu's own item.
        final node = tester.getSemantics(find.text(name));
        expect(node, isSemantics(isButton: true, hasTapAction: true));
        expect(tester.getSemantics(menuButton).id, isNot(node.id));
        handle.dispose();
      });
    }

    testWidgets('keep their columns at 200% on a 412 dp phone', (tester) async {
      await open(tester, textScale: 2);
      final rishon = row('Rishon');
      final title = tester.getRect(find.text('Rishon'));
      final pips = tester.getRect(find.descendant(of: rishon, matching: find.byType(PassPips)));
      expect(title.left - tester.getRect(rishon).left, 72);
      expect(pips.center.dy, moreOrLessEquals(title.center.dy, epsilon: 1), reason: "on the name's line");
    });

    testWidgets('note where some sources divide an aliyah otherwise, quietly, as a line of meta', (tester) async {
      await open(tester);
      final chamishi = row('Chamishi');
      final note = textIn(tester, chamishi, 'Some sources use');
      final words = note.textSpan!.toPlainText(includePlaceholders: false);
      expect(words, 'Some sources use 4:19\u2060–\u206026');
      expect(note.semanticsLabel, words, reason: 'its words, without the mark');
      // Set as the row's other meta are, not louder than its name.
      final theme = Theme.of(tester.element(find.byType(WeekOverview)));
      final meta = theme.textTheme.bodySmall!;
      final style = note.style!;
      expect((style.fontFamily, style.fontSize, style.fontStyle), (meta.fontFamily, meta.fontSize, meta.fontStyle));
      expect(style.color, theme.colorScheme.onSurfaceVariant);
      // After a small mark in its colour at the start of its first line, as
      // the overdue mark leads the plan's line.
      final mark = find.descendant(of: chamishi, matching: find.byIcon(Icons.info_outline));
      expect(tester.widget<Icon>(mark).size, 14);
      expect(tester.widget<Icon>(mark).color, theme.colorScheme.onSurfaceVariant);
      final text = tester.getRect(find.descendant(of: chamishi, matching: find.textContaining('Some sources use')));
      final plan = tester.getRect(find.descendant(of: chamishi, matching: find.byIcon(stillToReadIcon)));
      expect(tester.getRect(mark).left, moreOrLessEquals(text.left, epsilon: 0.5));
      expect(tester.getRect(mark).left, moreOrLessEquals(plan.left, epsilon: 0.5));
      final firstLine = style.fontSize! * style.height!;
      expect(tester.getCenter(mark).dy, moreOrLessEquals(text.top + firstLine / 2, epsilon: 1.5));
      // Only where some sources do.
      expect(find.descendant(of: row('Rishon'), matching: find.byIcon(Icons.info_outline)), findsNothing);
    });

    testWidgets('note it in Hebrew too, in Hebrew numerals', (tester) async {
      await open(tester, settings: _settings.copyWith(language: AppLanguage.hebrew));
      final note = find.textContaining('לפי חלק מהמקורות: ד,\u00A0יט\u2060–\u2060כו');
      expect(note, findsOneWidget);
      // Its mark at the start, on the right.
      final mark = find.descendant(of: row('חמישי'), matching: find.byIcon(Icons.info_outline));
      expect(tester.getRect(mark).right, moreOrLessEquals(tester.getRect(note).right, epsilon: 0.5));
      expect(find.text('מתוכנן ליום שני'), findsOneWidget, reason: 'the weekday names its day once');
    });
  });

  testWidgets('the haftarah and the discussion share a sheet of their own', (tester) async {
    await open(tester);
    final group = find.ancestor(of: find.text('Haftarah'), matching: find.byType(PaperGroup));
    expect(find.descendant(of: group, matching: find.text('Discuss this week’s parsha')), findsOneWidget);
    expect(tester.widget<PaperGroup>(group).ruleInset, PaperGroup.iconInset);
  });

  testWidgets('the whole parsha can be marked as read at the end of the page, until it is', (tester) async {
    final c = await open(tester);
    final mark = find.widgetWithText(TextButton, 'Mark the whole parsha as read');
    await tester.ensureVisible(mark);
    await tester.pumpAndSettle();
    await tester.tap(mark);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(PaperRow, 'Today'));
    await tester.pumpAndSettle();
    expect(c.read(progressProvider).week('5787:1').isComplete, isTrue);
    expect(mark, findsNothing);
  });

  testWidgets('the Parsha tab names its way to every parsha', (tester) async {
    final c = await open(tester);
    final browse = find.descendant(of: find.byType(AppBar), matching: find.widgetWithText(TextButton, 'All parshiyot'));
    expect(browse, findsOneWidget);
    await tester.tap(browse);
    await tester.pumpAndSettle();
    expect(find.byType(BrowseScreen), findsOneWidget);
    expect(c.read(routerProvider).state.uri.toString(), '/parsha/browse');
  });

  testWidgets('the Parsha tab opens every bookmark and note', (tester) async {
    // A tablet's app bar, which has room for the button.
    final c = await open(tester, size: const Size(800, 1000));
    final notes = find.descendant(of: find.byType(AppBar), matching: find.byTooltip('Bookmarks & notes'));
    expect(notes, findsOneWidget);
    // Between the way to every parsha and search.
    final browse = tester.getRect(find.widgetWithText(TextButton, 'All parshiyot'));
    final search = tester.getRect(find.byIcon(Icons.search));
    expect(tester.getCenter(notes).dx, inExclusiveRange(browse.right, search.left));
    await tester.tap(notes);
    await tester.pumpAndSettle();
    expect(tester.widget<NotesScreen>(find.byType(NotesScreen)).weekId, isNull, reason: "every parsha's");
    expect(c.read(routerProvider).state.uri.toString(), '/notes');
  });

  // The title revealed on scrolling needs the room on a phone; the menu
  // holds the way to every bookmark and note as its second item.
  testWidgets('on a phone, the Parsha tab leaves bookmarks and notes to its menu', (tester) async {
    final c = await open(tester);
    expect(find.descendant(of: find.byType(AppBar), matching: find.byTooltip('Bookmarks & notes')), findsNothing);
    expect(find.descendant(of: find.byType(AppBar), matching: find.byIcon(Icons.search)), findsOneWidget);
    await tester.tap(find.descendant(of: find.byType(AppBar), matching: find.byType(PopupMenuButton<String>)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bookmarks & notes'));
    await tester.pumpAndSettle();
    expect(tester.widget<NotesScreen>(find.byType(NotesScreen)).weekId, isNull, reason: "every parsha's");
    expect(c.read(routerProvider).state.uri.toString(), '/notes');
  });

  group("the week's menu", () {
    /// Opens the menu, and gives its items' labels, its hairline as "—".
    Future<List<String>> openMenu(WidgetTester tester) async {
      await tester.tap(find.descendant(of: find.byType(AppBar), matching: find.byType(PopupMenuButton<String>)));
      await tester.pumpAndSettle();
      return [
        for (final entry in tester.widgetList(find.byWidgetPredicate((w) => w is PopupMenuEntry)))
          entry is PopupMenuItem ? (entry.child! as Text).data! : '—',
      ];
    }

    testWidgets('offers ways to read first, then under a hairline the progress, the clearing last', (tester) async {
      await open(tester);
      expect(await openMenu(tester), [
        'Full text',
        'Bookmarks & notes',
        '—',
        'Mark the whole parsha as read',
        'Clear this week’s progress',
      ]);
      final hairline = tester.widget<PopupMenuDivider>(find.byType(PopupMenuDivider));
      final sefer = SeferColors.of(tester.element(find.byType(WeekOverview)));
      expect((hairline.color, hairline.thickness), (sefer.hairline, sefer.hairlineWidth));
    });

    testWidgets('draws no hairline over nothing in a week with nothing to mark or clear', (tester) async {
      // Next week's, not yet open, and not begun.
      await open(tester, route: '/week/5787:2');
      expect(await openMenu(tester), ['Full text', 'Bookmarks & notes']);
    });

    testWidgets('opens every bookmark and note from a week', (tester) async {
      await open(tester, route: '/week/5787:1');
      await openMenu(tester);
      await tester.tap(find.text('Bookmarks & notes'));
      await tester.pumpAndSettle();
      expect(tester.widget<NotesScreen>(find.byType(NotesScreen)).weekId, isNull);
    });

    testWidgets('names the parsha a clearing cleared, and Undo brings it back', (tester) async {
      final c = await open(tester, route: '/week/5787:1');
      await openMenu(tester);
      await tester.tap(find.text('Clear this week’s progress'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Clear'));
      await tester.pumpAndSettle();
      expect(c.read(progressProvider).week('5787:1').completedUnits, 0);
      expect(find.text('Progress for Bereshit cleared'), findsOneWidget);
      await tester.tap(find.widgetWithText(SnackBarAction, 'Undo'));
      await tester.pumpAndSettle();
      expect(c.read(progressProvider).week('5787:1').isAliyahDone(1), isTrue);
    });

    testWidgets('names it in Hebrew too', (tester) async {
      await open(tester, route: '/week/5787:1', settings: _settings.copyWith(language: AppLanguage.hebrew));
      await openMenu(tester);
      await tester.tap(find.text('ניקוי ההתקדמות של השבוע'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'ניקוי'));
      await tester.pumpAndSettle();
      expect(find.text('ההתקדמות בפרשת בראשית נמחקה'), findsOneWidget);
    });
  });

  testWidgets("the Parsha tab's way to every parsha keeps to its share of the app bar with very large text",
      (tester) async {
    await openRoute(tester, '/parsha', settings: _settings, now: _friday, textScale: 2);
    final bar = tester.getRect(find.byType(AppBar));
    final browse = tester.getRect(find.widgetWithText(TextButton, 'All parshiyot'));
    expect(browse.width, lessThanOrEqualTo(412 * 0.4 + 24), reason: "40% of the width, and the button's padding");
    expect(tester.takeException(), isNull);
    for (final icon in [Icons.search, Icons.more_vert]) {
      final rect = tester.getRect(find.byIcon(icon).first);
      expect(rect.left, greaterThanOrEqualTo(browse.right - 1));
      expect(rect.right, lessThanOrEqualTo(bar.right));
    }
  });

  testWidgets('another aliyah division is read from its note', (tester) async {
    final repo = await tester.runAsync(loadRepo);
    final bereshit = repo!.all.first;
    final other = bereshit.alternativeAliyah(4)!;
    expect((other.start, other.end), (const VerseRef(4, 19), const VerseRef(4, 26)));
    expect(bereshit.alternativeAliyah(0), isNull);
    final across = [
      for (final p in repo.all)
        for (var a = 0; a < 7; a++) ?p.alternativeAliyah(a),
    ].where((r) => r.start.chapter != r.end.chapter);
    expect(across, isNotEmpty, reason: 'a note across chapters, such as 25:31-26:14');
  });
}
