import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/core/calendar/parsha_schedule.dart';
import 'package:shnayim_mikra/features/parsha/browse_screen.dart';
import 'package:shnayim_mikra/features/parsha/week_context.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/ui/theme/app_theme.dart';
import 'package:shnayim_mikra/ui/widgets/lang.dart';
import 'package:shnayim_mikra/ui/widgets/lines.dart';
import 'package:shnayim_mikra/ui/widgets/ornaments.dart';
import 'package:shnayim_mikra/ui/widgets/paper_group.dart';

import '../../helpers.dart';

/// Joined on Simchat Torah 5787 outside Israel, before the week of Bereshit.
final _settings = AppSettings(onboardingComplete: true, joinDate: LocalDate(2026, 10, 4));

/// Friday 9 October 2026, the week of Bereshit.
final _bereshitWeek = DateTime(2026, 10, 9, 11);

/// Wednesday 14 July 2027, the week of Chukat and Balak, read together
/// outside Israel.
final _chukatBalakWeek = DateTime(2027, 7, 14, 11);

/// Bereshit read, and Noach begun.
ProgressState _progress() => ProgressState(weeks: {
      '5787:1': WeekProgress(weekId: '5787:1').withAll(LocalDate(2026, 10, 9)),
      '5787:2': WeekProgress(weekId: '5787:2').withUnit(0, ReadingPass.mikra1, LocalDate(2026, 10, 11)),
    });

void main() {
  Future<ProviderContainer> open(
    WidgetTester tester, {
    DateTime? now,
    AppSettings? settings,
    ProgressState? progress,
    Size size = const Size(412, 915),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await pumpApp(
      tester,
      settings: settings ?? _settings,
      now: now ?? _bereshitWeek,
      progress: progress ?? _progress(),
    );
    c.read(routerProvider).go('/parsha/browse');
    await tester.pumpAndSettle();
    return c;
  }

  /// The row of the parsha named [name].
  Finder row(String name) => find.ancestor(of: find.text(name), matching: find.byType(SeferInkWell)).first;

  /// Every line of text in [row], parts of a line split at its dots.
  List<String> partsOf(WidgetTester tester, Finder row) => [
        for (final t in tester.widgetList<Text>(find.descendant(of: row, matching: find.byType(Text))))
          ...?t.data?.replaceAll(' ', ' ').split(' · '),
      ];

  group('cycleWeeks', () {
    test("gives each parsha its week in the year's cycle, two read together under one", () {
      final weeks = cycleWeeks(const ParshaSchedule(israel: false), 5787);
      expect(weeks.keys, unorderedEquals([for (var n = 1; n <= kParshaCount; n++) n]));
      expect(weeks[1]!.occasion, LocalDate(2026, 10, 10));
      expect(weeks[39], same(weeks[40]));
      expect(weeks[39]!.portion, const PortionId(39, combined: true));
      expect(weeks[39]!.occasion, LocalDate(2027, 7, 17));
      // Vezot HaBerachah ends it, on Simchat Torah of the next year.
      expect(weeks[54]!.occasion, LocalDate(2027, 10, 24));
      for (var n = 2; n <= kParshaCount; n++) {
        expect(weeks[n]!.occasion >= weeks[n - 1]!.occasion, isTrue, reason: '$n');
      }
    });

    test("follows Israel's reading in Israel", () {
      final weeks = cycleWeeks(const ParshaSchedule(israel: true), 5787);
      expect(weeks[39]!.occasion, LocalDate(2027, 7, 10));
      expect(weeks[40]!.occasion, LocalDate(2027, 7, 17));
      expect(weeks[54]!.occasion, LocalDate(2027, 10, 23));
    });
  });

  group('the books', () {
    testWidgets('each have a sheet, headed by their Hebrew and English names and their count', (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester);
      expect(find.byType(PaperGroup), findsNWidgets(5));
      for (final (hebrew, english, count) in [
        ('בראשית', 'Genesis', 12),
        ('שמות', 'Exodus', 11),
        ('ויקרא', 'Leviticus', 10),
        ('במדבר', 'Numbers', 10),
        ('דברים', 'Deuteronomy', 11),
      ]) {
        final heading = find.bySemanticsLabel(RegExp('^$english\n'));
        // The sheets below may not be laid out on screen yet.
        await tester.scrollUntilVisible(find.textContaining(english, findRichText: true).first, 300);
        expect(find.textContaining(hebrew, findRichText: true), findsWidgets, reason: english);
        final data = tester.getSemantics(heading).getSemanticsData();
        expect(data.label, '$english\n$count parshiyot');
        expect(data.flagsCollection.isHeader, isTrue);
        expect(data.headingLevel, 2);
      }
      handle.dispose();
    });

    testWidgets('are named in Hebrew alone in the Hebrew UI', (tester) async {
      await open(tester, settings: _settings.copyWith(language: AppLanguage.hebrew));
      expect(find.textContaining('Genesis', findRichText: true), findsNothing);
      expect(find.text('12 פרשות'), findsOneWidget);
    });
  });

  group('the parshiyot', () {
    testWidgets('give their number, names, verses and the day they are read this year', (tester) async {
      await open(tester);
      final lech = row('Lech Lecha');
      expect(find.descendant(of: lech, matching: find.text('3')), findsOneWidget);
      expect(find.descendant(of: lech, matching: find.text(WholeWords.unbroken('לך־לך'))), findsOneWidget);
      expect(partsOf(tester, lech), containsAllInOrder(['Genesis 12:1–17:27', 'October 24']));
      // No icon of a book on every row, and no chevron on a phone.
      expect(find.byIcon(Icons.menu_book_outlined), findsNothing);
      expect(find.descendant(of: find.byType(BrowseScreen), matching: find.byIcon(Icons.chevron_right)), findsNothing);
    });

    testWidgets('read together this year say with which', (tester) async {
      await open(tester, now: _chukatBalakWeek, progress: const ProgressState());
      expect(partsOf(tester, row('Chukat')), containsAllInOrder(['Numbers 19:1–22:1', 'Read with Balak', 'July 17']));
      expect(partsOf(tester, row('Balak')), containsAllInOrder(['Numbers 22:2–25:9', 'Read with Chukat', 'July 17']));
      await tester.scrollUntilVisible(find.text('Masei'), 300);
      expect(partsOf(tester, row('Masei')), containsAllInOrder(['Read with Matot', 'July 31']));
      expect(partsOf(tester, row('Pinchas')), isNot(contains(startsWith('Read with'))));
    });

    testWidgets('read together, break between the parts of the line with very large text, never at a dot',
        (tester) async {
      await open(tester, now: _chukatBalakWeek, progress: const ProgressState());
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await tester.pumpAndSettle();
      for (final name in ['Chukat', 'Balak']) {
        expect(partsOf(tester, row(name)), containsAllInOrder(['Read with ${name == 'Chukat' ? 'Balak' : 'Chukat'}', 'July 17']));
        // Each line of the subtitle is a text of its own; one that holds a
        // dot between two parts keeps to one line, so no line starts or ends
        // with it.
        for (final text in find.descendant(of: row(name), matching: find.byType(RichText)).evaluate()) {
          final paragraph = text.renderObject! as RenderParagraph;
          final plain = paragraph.text.toPlainText();
          if (!plain.contains('·')) continue;
          final line = paragraph.getFullHeightForCaret(const TextPosition(offset: 0));
          expect(paragraph.size.height, lessThan(line * 1.5), reason: '$name: "$plain" wraps');
        }
      }
    });

    testWidgets('grow the mark with the text to 1.5× at most, inside its column and clear of the title',
        (tester) async {
      await open(tester);
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await tester.pumpAndSettle();
      final bereshit = row('Bereshit');
      final mark = tester.getRect(find.descendant(of: bereshit, matching: find.byIcon(Icons.check_circle)));
      final column = tester.getRect(
        find.ancestor(
          of: find.descendant(of: bereshit, matching: find.byIcon(Icons.check_circle)),
          matching: find.byWidgetPredicate((w) => w is SizedBox && w.width == 28),
        ),
      );
      expect(mark.width, lessThanOrEqualTo(27.01));
      expect(mark.left, greaterThanOrEqualTo(column.left - 0.01));
      expect(mark.right, lessThanOrEqualTo(column.right + 0.01));
      expect(mark.right, lessThan(tester.getRect(find.text('Bereshit')).left));
    });

    testWidgets('show a check once read this year, and a clock while under way', (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester);
      final bereshit = row('Bereshit');
      final noach = row('Noach');
      expect(find.descendant(of: bereshit, matching: find.byIcon(Icons.check_circle)), findsOneWidget);
      expect(find.descendant(of: bereshit, matching: find.text('1')), findsNothing);
      expect(find.descendant(of: noach, matching: find.byIcon(Icons.timelapse)), findsOneWidget);
      expect(find.descendant(of: noach, matching: find.text('2')), findsNothing);
      final check = tester.widget<Icon>(find.descendant(of: bereshit, matching: find.byIcon(Icons.check_circle)));
      expect(check.color, Theme.of(tester.element(bereshit)).colorScheme.primary);

      expect(tester.getSemantics(bereshit).getSemanticsData().value, 'done');
      expect(tester.getSemantics(noach).getSemanticsData().value, 'In progress');
      final lech = tester.getSemantics(row('Lech Lecha')).getSemanticsData();
      expect(lech.value, isEmpty);
      // The row is one button, named in English: neither its number nor its
      // Hebrew name is read.
      expect(lech.label, startsWith('Lech Lecha\nGenesis 12:1–17:27'));
      expect(lech.label, isNot(contains('3')));
      expect(lech.label, isNot(contains('לך')));
      expect(lech.flagsCollection.isButton, isTrue);
      handle.dispose();
    });

    testWidgets('read in another year count for nothing here', (tester) async {
      await open(
        tester,
        progress: ProgressState(weeks: {
          '5786:2': WeekProgress(weekId: '5786:2').withAll(LocalDate(2025, 10, 24)),
        }),
      );
      expect(find.descendant(of: row('Noach'), matching: find.text('2')), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsNothing);
    });

    testWidgets("open their week, by the week's own id", (tester) async {
      final c = await open(tester, now: _chukatBalakWeek, progress: const ProgressState());
      await tester.tap(row('Balak'));
      await tester.pumpAndSettle();
      expect(c.read(routerProvider).state.uri.toString(), '/parsha/week/5787:39-40');
    });

    testWidgets('give the Hebrew name beside the title, or under it once the two no longer fit', (tester) async {
      await open(tester);
      var title = tester.getRect(find.text('Toldot'));
      var hebrew = tester.getRect(find.text('תולדות'));
      expect(hebrew.left, greaterThan(title.right));
      // On the title's baseline.
      final line = find
          .ancestor(
            of: find.text('תולדות'),
            matching: find.byWidgetPredicate((w) => w is Row && w.crossAxisAlignment == CrossAxisAlignment.baseline),
          )
          .first;
      expect(find.descendant(of: line, matching: find.text('Toldot')), findsOneWidget);
      expect(find.descendant(of: line, matching: find.text('6')), findsNothing);

      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await tester.pumpAndSettle();
      title = tester.getRect(find.text('Toldot'));
      hebrew = tester.getRect(find.text('תולדות'));
      expect(hebrew.top, greaterThanOrEqualTo(title.bottom));
      expect(hebrew.left, title.left);
    });

    testWidgets('end in a chevron on a larger screen', (tester) async {
      await open(tester, size: const Size(800, 1180));
      expect(find.descendant(of: row('Bereshit'), matching: find.byIcon(Icons.chevron_right)), findsOneWidget);
    });

    testWidgets('in Hebrew, are titled in Hebrew, with the English name at the end in English', (tester) async {
      await open(tester, settings: _settings.copyWith(language: AppLanguage.hebrew));
      final title = tester.widget<Text>(find.text('נח'));
      expect(title.style?.fontSize, 20);
      expect(title.style?.fontFamily, 'FrankRuhlLibre');
      final english = find.text('Noach');
      expect(tester.widget<Text>(english).textDirection, TextDirection.ltr);
      expect(
        find.ancestor(of: english, matching: find.byWidgetPredicate((w) => w is Lang && w.locale.languageCode == 'en')),
        findsOneWidget,
      );
      // At the end of the title's line: to its left.
      expect(tester.getRect(english).right, lessThan(tester.getRect(find.text('נח')).left));
      expect(partsOf(tester, row('נח')), containsAllInOrder(['בראשית ו, ט – יא, לב', 'ו׳ בחשון']));
    });
  });

  group("this week's parsha", () {
    testWidgets('is ruled at its start and named so', (tester) async {
      await open(tester);
      final eyebrow = find.widgetWithText(Eyebrow, 'This week');
      expect(eyebrow, findsOneWidget);
      expect(find.descendant(of: row('Bereshit'), matching: eyebrow), findsOneWidget);
      final rule = find.descendant(
        of: row('Bereshit'),
        matching: find.byWidgetPredicate((w) => w is SizedBox && w.width == 3),
      );
      expect(rule, findsOneWidget);
      final card = tester.getRect(find.ancestor(of: row('Bereshit'), matching: find.byType(Card)));
      expect(tester.getRect(rule).left, closeTo(card.left + 1, 0.01));
      expect(find.descendant(of: row('Noach'), matching: find.byWidgetPredicate((w) => w is SizedBox && w.width == 3)),
          findsNothing);
    });

    testWidgets('is ruled at its start in Hebrew too, on the right', (tester) async {
      await open(tester, settings: _settings.copyWith(language: AppLanguage.hebrew));
      final bereshit = row('בראשית');
      final rule = find.descendant(of: bereshit, matching: find.byWidgetPredicate((w) => w is SizedBox && w.width == 3));
      expect(rule, findsOneWidget);
      final card = tester.getRect(find.ancestor(of: bereshit, matching: find.byType(Card)));
      final hairline = SeferColors.of(tester.element(bereshit)).hairlineWidth;
      expect(tester.getRect(rule).right, closeTo(card.right - hairline, 0.01));
    });

    testWidgets('of two read together, rules both and names the first', (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester, now: _chukatBalakWeek, progress: const ProgressState());
      final eyebrow = find.widgetWithText(Eyebrow, 'This week');
      expect(eyebrow, findsOneWidget);
      expect(find.descendant(of: row('Chukat'), matching: eyebrow), findsOneWidget);
      for (final name in ['Chukat', 'Balak']) {
        expect(
          find.descendant(of: row(name), matching: find.byWidgetPredicate((w) => w is SizedBox && w.width == 3)),
          findsOneWidget,
          reason: name,
        );
        // Both are this week's to a screen reader.
        expect(tester.getSemantics(row(name)).getSemanticsData().label, startsWith('This week\n'), reason: name);
      }
      handle.dispose();
    });

    testWidgets('is in view as the page opens', (tester) async {
      await open(tester, now: _chukatBalakWeek, progress: const ProgressState());
      final view = tester.getRect(find.byType(Scrollable).last);
      final chukat = tester.getRect(row('Chukat'));
      expect(chukat.top, greaterThanOrEqualTo(view.top));
      expect(chukat.bottom, lessThanOrEqualTo(view.bottom));
      // Three tenths of the way down.
      expect(chukat.top - view.top, closeTo(0.3 * (view.height - chukat.height), 1));
    });

    testWidgets('leaves the page where it is when it shows already', (tester) async {
      await open(tester);
      final position = tester.state<ScrollableState>(find.byType(Scrollable).last).position;
      expect(position.pixels, 0);
    });

    for (final reduced in [false, true]) {
      testWidgets(reduced ? 'is brought into view at once while motion is reduced' : 'is scrolled into view',
          (tester) async {
        tester.view.physicalSize = const Size(412, 915);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final c = await pumpApp(
          tester,
          settings: _settings.copyWith(reduceMotion: reduced),
          now: _chukatBalakWeek,
          progress: const ProgressState(),
        );
        c.read(routerProvider).go('/parsha/browse');
        // The page's first frame, and the next, with no time between them.
        await tester.pump();
        await tester.pump();
        final position = tester.state<ScrollableState>(find.byType(Scrollable).last).position;
        final first = position.pixels;
        await tester.pumpAndSettle();
        expect(position.pixels, greaterThan(0));
        if (reduced) {
          expect(first, position.pixels);
        } else {
          expect(first, lessThan(position.pixels));
        }
      });
    }
  });
}
