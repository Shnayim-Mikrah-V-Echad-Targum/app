import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/data/models/verse_ref.dart';
import 'package:shnayim_mikra/features/parsha/browse_screen.dart';
import 'package:shnayim_mikra/features/parsha/week_overview_screen.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/ui/theme/app_theme.dart';
import 'package:shnayim_mikra/ui/widgets/ornaments.dart';
import 'package:shnayim_mikra/ui/widgets/paper_group.dart';
import 'package:shnayim_mikra/ui/widgets/progress_widgets.dart';

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
  }) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await pumpApp(tester, settings: settings ?? _settings, now: _friday, progress: progress ?? _bereshit());
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
      for (final name in ['Rishon', 'Sheni', 'Shlishi', "Revi'i", 'Chamishi', 'Shishi', "Shevi'i"]) {
        expect(find.descendant(of: group, matching: find.text(name)), findsOneWidget, reason: name);
      }
      // The aliyah's number is said, not shown: a Hebrew ordinal in its disc.
      expect(find.textContaining('· aliyah'), findsNothing);
      expect(find.descendant(of: row('Revi\'i'), matching: find.text('ד')), findsOneWidget);
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

      for (final name in ['Shishi', "Shevi'i"]) {
        final today = textIn(tester, row(name), 'Planned for today');
        expect(today.style?.fontWeight, FontWeight.w700, reason: name);
        expect(today.style?.color, scheme.onSurface, reason: name);
      }
      for (final (name, day) in [('Shlishi', 'Wednesday'), ("Revi'i", 'Thursday'), ('Chamishi', 'Thursday')]) {
        expect(textIn(tester, row(name), 'Planned for $day').style?.color, overdue, reason: name);
        expect(find.descendant(of: row(name), matching: find.byIcon(Icons.history)), findsOneWidget, reason: name);
      }
      // Read on their days: plain.
      expect(textIn(tester, row('Rishon'), 'Planned for Monday').style?.color, scheme.onSurfaceVariant);
      expect(find.descendant(of: row('Rishon'), matching: find.byIcon(Icons.history)), findsNothing);
    });

    testWidgets('planned for a day before the reader joined are never overdue', (tester) async {
      // Joined on Wednesday, starting with that day's reading.
      await open(
        tester,
        settings: _settings.copyWith(joinDate: LocalDate(2026, 10, 7), starterCatchUp: false),
        progress: const ProgressState(),
      );
      expect(find.descendant(of: row('Rishon'), matching: find.byIcon(Icons.history)), findsNothing);
      expect(find.descendant(of: row('Sheni'), matching: find.byIcon(Icons.history)), findsNothing);
      expect(find.descendant(of: row('Shlishi'), matching: find.byIcon(Icons.history)), findsOneWidget);
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
      expect(data.label, contains('Planned for Wednesday'));
      expect(data.value, 'First reading: done, Second reading: done, Targum: not done');
      expect(data.flagsCollection.isButton, isTrue);
      expect(data.hasAction(SemanticsAction.tap), isTrue);
      // The menu is reached on its own.
      expect(find.byTooltip('More options for Shlishi'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('open the reader at the aliyah tapped', (tester) async {
      final c = await open(tester);
      await tester.ensureVisible(find.text("Revi'i"));
      await tester.pumpAndSettle();
      await tester.tap(find.text("Revi'i"));
      await tester.pump();
      expect(c.read(routerProvider).state.uri.toString(), '/read/5787:1/3?from=week');
    });

    testWidgets('note where some sources divide an aliyah otherwise', (tester) async {
      await open(tester);
      final note = textIn(tester, row('Chamishi'), 'Some sources use');
      expect(note.data, 'Some sources use 4:19\u2060–\u206026');
      expect(note.style, SeferType.of(tester.element(find.byType(WeekOverview))).marginalia);
    });

    testWidgets('note it in Hebrew too, in Hebrew numerals', (tester) async {
      await open(tester, settings: _settings.copyWith(language: AppLanguage.hebrew));
      expect(find.text('לפי חלק מהמקורות: ד,\u00A0יט\u2060–\u2060כו'), findsOneWidget);
      expect(find.text('מתוכנן ליום שני'), findsOneWidget, reason: 'the weekday names its day once');
    });
  });

  testWidgets('the haftarah and the discussion share a sheet of their own', (tester) async {
    await open(tester);
    final group = find.ancestor(of: find.text('Haftarah'), matching: find.byType(PaperGroup));
    expect(find.descendant(of: group, matching: find.text("Discuss this week's parsha")), findsOneWidget);
    expect(tester.widget<PaperGroup>(group).ruleInset, PaperGroup.iconInset);
  });

  testWidgets('the whole parsha can be marked as read at the end of the page, until it is', (tester) async {
    final c = await open(tester);
    final mark = find.widgetWithText(TextButton, 'Mark the whole parsha as read');
    await tester.ensureVisible(mark);
    await tester.pumpAndSettle();
    await tester.tap(mark);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(ListTile, 'Today'));
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
