import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikra/features/progress/domain/reading_plan.dart';
import 'package:shnayim_mikra/features/progress/domain/streak_engine.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/ui/theme/motion.dart';
import 'package:shnayim_mikra/ui/widgets/lines.dart' show BalancedText;
import 'package:shnayim_mikra/ui/widgets/ornaments.dart';
import 'package:shnayim_mikra/ui/widgets/progress_widgets.dart';

import '../../helpers.dart';

// The finished panel (DESIGN_SYSTEM.md §6.23), in the week of Bereshit 5787:
// Monday 5 October to Friday 9 October 2026, an aliyah a day and two on
// Thursday and Friday (Rishon, Sheni, Shlishi, Revi'i and Chamishi, Shishi
// and Shevi'i).

final _monday = LocalDate(2026, 10, 5);

/// Bereshit with every aliyah up to [last] read on its planned day, and the
/// Hebrew of aliyah [partly] read twice, so that one step (the Targum, read
/// aliyah by aliyah) finishes it.
ProgressState _readThrough(int last, {required int partly, required LocalDate on}) {
  var w = WeekProgress(weekId: '5787:1');
  for (var a = 0; a <= last; a++) {
    w = w.withAliyah(a, _monday.addDays(a < 3 ? a : (a < 5 ? 3 : 4)));
  }
  w = w
      .withUnit(partly, ReadingPass.mikra1, on)
      .withUnit(partly, ReadingPass.mikra2, on)
      .withPosition(partly, const [99, 99, 0]);
  return ProgressState(weeks: {'5787:1': w});
}

/// Bereshit with each aliyah in [read] read on its day, and the Hebrew of
/// aliyah [partly] read twice on [on], so that one step finishes it.
ProgressState _bereshit(Map<int, LocalDate> read, {required int partly, required LocalDate on}) {
  var w = WeekProgress(weekId: '5787:1');
  for (final MapEntry(key: a, value: day) in read.entries) {
    w = w.withAliyah(a, day);
  }
  w = w
      .withUnit(partly, ReadingPass.mikra1, on)
      .withUnit(partly, ReadingPass.mikra2, on)
      .withPosition(partly, const [99, 99, 0]);
  return ProgressState(weeks: {'5787:1': w});
}

/// Week [id] with every aliyah read on [on] but Shevi'i, whose Hebrew is
/// read twice, so that its Targum finishes the parsha.
ProgressState _allButShevii(String id, LocalDate on) {
  var w = WeekProgress(weekId: id);
  for (var a = 0; a < 6; a++) {
    w = w.withAliyah(a, on);
  }
  w = w.withUnit(6, ReadingPass.mikra1, on).withUnit(6, ReadingPass.mikra2, on).withPosition(6, const [99, 99, 0]);
  return ProgressState(weeks: {id: w});
}

Future<void> _loadTexts(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  for (var i = 0; i < 20 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump();
  }
  await tester.pumpAndSettle();
}

/// Opens aliyah [aliyah] of Bereshit (or of [week]) on [day] and reads on
/// to its end.
Future<void> _finish(
  WidgetTester tester, {
  required int aliyah,
  required DateTime day,
  required ProgressState progress,
  AppSettings settings = const AppSettings(),
  String week = '5787:1',
  bool settle = true,
  bool repeat = false,
  double textScale = 1,
  String next = 'Next',
  String finish = 'Finish',
  Size size = const Size(412, 915),
  bool linked = false,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearAllTestValues);
  final c = await pumpApp(
    tester,
    // The repeat set as the reader sets it, off unless [repeat]: untouched,
    // it follows the haftarah custom, and is read back on.
    settings: settings
        .copyWith(
          onboardingComplete: true,
          notificationPromptShown: true,
          joinDate: LocalDate(2026, 10, 4),
          method: ReadingMethod.aliyahByAliyah,
        )
        .withRepeatLastVerse(repeat),
    now: day,
    progress: progress,
  );
  // Opened from a link, as after a cold start: no rings of the week seen in
  // this run, as Today's are as the app opens.
  if (linked) ParshaRings.forgetShown();
  c.read(routerProvider).go('/read/$week/$aliyah');
  await _loadTexts(tester);
  // Read whole already, an aliyah starts again from its first step.
  for (var i = 0; i < 3 && find.text(finish).evaluate().isEmpty; i++) {
    await tester.tap(find.text(next));
    await tester.pumpAndSettle();
  }
  await tester.tap(find.text(finish));
  if (settle) await tester.pumpAndSettle();
}

/// The haptics sent to the platform from now on, each by its type as
/// HapticFeedback sends it ('vibrate' for HapticFeedback.vibrate(),
/// Android's celebrate).
List<String> _recordHaptics(WidgetTester tester) {
  final sent = <String>[];
  final messenger = tester.binding.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == 'HapticFeedback.vibrate') sent.add(call.arguments as String? ?? 'vibrate');
    return null;
  });
  addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));
  return sent;
}

bool _focused(WidgetTester tester, String label) => Focus.of(tester.element(find.text(label))).hasFocus;

/// A marginalia line of the panel that says [text]: one text, or where it
/// is too long for one line, a text for each of its sentences.
Finder _line(String text) => find.byWidgetPredicate((w) => w is BalancedText && w.text == text);

/// The lines of the standing line, beside its [status]'s icon.
List<String> _standingLines(WidgetTester tester, WeekStatus status) {
  final line = find.ancestor(of: find.byIcon(WeekStatusBadge.icon(status)), matching: find.byType(Row)).first;
  final texts = tester.widgetList<Text>(find.descendant(of: line, matching: find.byType(Text)));
  return [for (final text in texts) text.data!];
}

/// The standing line as it reads, its lines rejoined: a line breaks only
/// between two parts, where their dot is.
String _standing(WidgetTester tester, WeekStatus status) => _standingLines(tester, status).join(' · ');

/// Checks that the standing line, what is drawn of its icon and its words
/// together, is centred under the panel's [title], with its icon at the
/// start: the left, or in [hebrew], the right.
void _expectStandingCentred(WidgetTester tester, WeekStatus status, String title, {bool hebrew = false}) {
  final icon = find.byIcon(WeekStatusBadge.icon(status));
  final glyph = tester.getRect(icon);
  // Where its words are drawn, line by line.
  final row = find.ancestor(of: icon, matching: find.byType(Row)).first;
  var words = Rect.zero;
  final text = find.descendant(of: row, matching: find.byType(Flexible));
  for (final element in find.descendant(of: text, matching: find.byType(RichText)).evaluate()) {
    final paragraph = element.renderObject! as RenderParagraph;
    // Word by word: a space that ends a line hangs past it.
    for (final word in RegExp(r'[^\s\u00A0]+').allMatches(paragraph.text.toPlainText())) {
      for (final box in paragraph.getBoxesForSelection(TextSelection(baseOffset: word.start, extentOffset: word.end))) {
        final rect = MatrixUtils.transformRect(paragraph.getTransformTo(null), box.toRect());
        words = words == Rect.zero ? rect : words.expandToInclude(rect);
      }
    }
  }
  final drawn = glyph.expandToInclude(words);
  expect(drawn.center.dx, closeTo(tester.getRect(find.text(title)).center.dx, 1), reason: 'centred under the title');
  if (hebrew) {
    expect(glyph.left, greaterThan(words.right), reason: 'the icon at the start, the right');
  } else {
    expect(glyph.right, lessThan(words.left), reason: 'the icon at the start, the left');
  }
}

void main() {
  testWidgets('finishing Shlishi with the day still ahead names Revi\'i, and how long it is', (tester) async {
    await _finish(tester, aliyah: 2, day: DateTime(2026, 10, 9, 10), progress: _readThrough(1, partly: 2, on: _monday));

    expect(find.text('Shlishi is complete'), findsOneWidget);
    expect(find.text('Revi’i is 21 verses.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Next aliyah · Revi’i'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Done'), findsOneWidget);
    expect(find.textContaining('That’s today’s reading.'), findsNothing, reason: "Friday's own aliyot are still to read");
    expect(find.byIcon(Icons.celebration), findsNothing);
    expect(find.byIcon(Icons.check_circle), findsNothing);
    expect(_focused(tester, 'Next aliyah · Revi’i'), isTrue);
  });

  testWidgets("once the day's reading is done, Done leads and going on is quieter", (tester) async {
    await _finish(
      tester,
      aliyah: 2,
      day: DateTime(2026, 10, 7, 10),
      progress: _readThrough(1, partly: 2, on: LocalDate(2026, 10, 7)),
    );

    expect(find.text('Shlishi is complete'), findsOneWidget);
    expect(_line('That’s today’s reading. See you tomorrow.'), findsOneWidget);
    expect(find.text('Revi’i is 21 verses.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Done'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Keep going: Revi’i'), findsOneWidget);
    expect(find.textContaining('Next aliyah'), findsNothing);
    expect(_focused(tester, 'Done'), isTrue, reason: 'the first button takes the focus');
  });

  testWidgets("on the plan's last day, Shevi'i is left for Shabbat morning", (tester) async {
    await _finish(
      tester,
      aliyah: 5,
      day: DateTime(2026, 10, 9, 10),
      progress: _readThrough(4, partly: 5, on: LocalDate(2026, 10, 9)),
      settings: const AppSettings(plan: ReadingPlanType.sheviiOnShabbat),
    );

    expect(find.text('Shishi is complete'), findsOneWidget);
    expect(_line('The rest is for Shabbat morning. Shabbat shalom!'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Keep going: Shevi’i'), findsOneWidget);
  });

  testWidgets("with the days ahead read ahead, the next reading is the next day that has some", (tester) async {
    // Tuesday: Rishon and Sheni read on their days, then Shlishi and Revi'i
    // read ahead, and Chamishi finished. Wednesday's and Thursday's are read.
    final tuesday = LocalDate(2026, 10, 6);
    await _finish(
      tester,
      aliyah: 4,
      day: DateTime(2026, 10, 6, 10),
      progress: _bereshit({0: _monday, 1: tuesday, 2: tuesday, 3: tuesday}, partly: 4, on: tuesday),
    );

    expect(find.text('Chamishi is complete'), findsOneWidget);
    expect(_line('That’s today’s reading. See\u00A0you\u00A0on\u00A0Friday.'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Keep going: Shishi'), findsOneWidget);
  });

  testWidgets('with an earlier aliyah still due, the panel offers the next as on any day', (tester) async {
    // Wednesday: Rishon read, but not Sheni, which was Tuesday's.
    final wednesday = LocalDate(2026, 10, 7);
    await _finish(
      tester,
      aliyah: 2,
      day: DateTime(2026, 10, 7, 10),
      progress: _bereshit({0: _monday}, partly: 2, on: wednesday),
    );

    expect(find.text('Shlishi is complete'), findsOneWidget);
    expect(find.textContaining('That’s today’s reading.'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Next aliyah · Revi’i'), findsOneWidget);
  });

  testWidgets('on the eve of Rosh Hashanah, the greeting is for the new year', (tester) async {
    // Ha'azinu 5788, read on the Shabbat after Rosh Hashanah 5789 (Thursday
    // and Friday, 21 and 22 September 2028): Shishi finished on Wednesday,
    // and Shevi'i left for Shabbat morning. Rosh Hashanah has its own
    // greeting, as Today's title page gives it then.
    final wednesday = LocalDate(2028, 9, 20);
    var w = WeekProgress(weekId: '5788:53');
    for (var a = 0; a < 5; a++) {
      w = w.withAliyah(a, LocalDate(2028, 9, 17 + a ~/ 2));
    }
    w = w.withUnit(5, ReadingPass.mikra1, wednesday).withUnit(5, ReadingPass.mikra2, wednesday).withPosition(5, const [99, 99, 0]);
    await _finish(
      tester,
      week: '5788:53',
      aliyah: 5,
      day: DateTime(2028, 9, 20, 10),
      progress: ProgressState(weeks: {'5788:53': w}),
      settings: const AppSettings(plan: ReadingPlanType.sheviiOnShabbat),
    );

    expect(find.text('Shishi is complete'), findsOneWidget);
    expect(_line('The rest is for Shabbat morning. Shanah\u00A0tovah!'), findsOneWidget);
  });

  group('the parsha finished', () {
    testWidgets('closes its rings in place of the divider, names it in Hebrew, and greets Shabbat on its eve',
        (tester) async {
      await _finish(tester, aliyah: 6, day: DateTime(2026, 10, 9, 10), progress: _readThrough(5, partly: 6, on: _monday));

      // The rings at the Parsha header's size, closed, with no legend: what
      // they say is spoken (parshaComplete).
      final rings = tester.widget<ParshaRings>(find.byType(ParshaRings));
      expect(rings.size, ParshaRings.header);
      expect(rings.progress.isComplete, isTrue);
      expect(find.byType(RingLegend), findsNothing);
      expect(find.byType(SeferDivider), findsNothing);
      // Then the parsha's pointed name, the title, the standing line and
      // Friday's greeting, in that order.
      final name = find.text('בְּרֵאשִׁית');
      expect(name, findsOneWidget);
      final greeting = find.text('Shabbat\u00A0shalom!');
      expect(greeting, findsOneWidget);
      double top(Finder f) => tester.getTopLeft(f).dy;
      expect(top(find.byType(ParshaRings)), lessThan(top(name)));
      expect(top(name), lessThan(top(find.text('Parshat Bereshit is complete'))));
      expect(top(find.text('Parshat Bereshit is complete')), lessThan(top(find.byIcon(Icons.check_circle))));
      expect(top(find.byIcon(Icons.check_circle)), lessThan(top(greeting)));
      expect(top(greeting), lessThan(top(find.text('Read the haftarah'))));
      // A size below the aliyah's title, under the name.
      final context = tester.element(name);
      expect(
        tester.widget<Text>(find.text('Parshat Bereshit is complete')).style?.fontSize,
        Theme.of(context).textTheme.headlineSmall?.fontSize,
      );
    });

    for (final announces in [true, false]) {
      testWidgets('in Hebrew, says the parsha is complete under its name, and its heading still names it'
          '${announces ? '' : ' (live region)'}', (tester) async {
        final handle = tester.ensureSemantics();
        tester.platformDispatcher.accessibilityFeaturesTestValue = FakeAccessibilityFeatures(supportsAnnounce: announces);
        addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
        await _finish(
          tester,
          aliyah: 6,
          day: DateTime(2026, 10, 9, 10),
          progress: _readThrough(5, partly: 6, on: _monday),
          settings: const AppSettings(language: AppLanguage.hebrew),
          next: 'הבא',
          finish: 'סיום',
        );

        expect(find.text('בְּרֵאשִׁית'), findsOneWidget);
        expect(find.text('הפרשה הושלמה'), findsOneWidget);
        expect(find.textContaining('פרשת בראשית'), findsNothing, reason: 'the name is not repeated beneath itself');
        expect(find.text('שבת\u00A0שלום!'), findsOneWidget);
        expect(
          tester.getSemantics(find.text('הפרשה הושלמה')),
          isSemantics(
            label: announces ? 'פרשת בראשית הושלמה' : 'חזק! פרשת בראשית הושלמה.',
            isHeader: true,
            isLiveRegion: !announces,
          ),
        );
        // The pointed name and the rings are for the eye alone.
        expect(find.bySemanticsLabel(RegExp('בְּרֵאשִׁית')), findsNothing);
        expect(find.bySemanticsLabel(RegExp('^7 מתוך 7 עליות')), findsNothing);
        handle.dispose();
      });
    }

    testWidgets('midweek, has no greeting', (tester) async {
      // Wednesday: every aliyah read ahead of its day.
      final wednesday = LocalDate(2026, 10, 7);
      await _finish(tester, aliyah: 6, day: DateTime(2026, 10, 7, 10), progress: _allButShevii('5787:1', wednesday));

      expect(find.text('Parshat Bereshit is complete'), findsOneWidget);
      expect(find.byType(ParshaRings), findsOneWidget);
      expect(find.textContaining('shalom'), findsNothing);
      expect(find.textContaining('sameach'), findsNothing);
    });

    for (final (what, week, day, greeting) in [
      // Naso 5787, finished on Thursday 10 June 2027, Erev Shavuot (Friday
      // and Shabbat outside Israel).
      ('Erev Shavuot', '5787:35', LocalDate(2027, 6, 10), 'Chag\u00A0sameach!'),
      // Ha'azinu 5788, finished on Wednesday 20 September 2028, Erev Rosh
      // Hashanah.
      ('Erev Rosh Hashanah', '5788:53', LocalDate(2028, 9, 20), 'Shanah\u00A0tovah!'),
      // Vezot HaBerachah 5786, whose long week outside Israel begins on
      // Sunday 20 September 2026, Erev Yom Kippur.
      ('Erev Yom Kippur', '5786:54', LocalDate(2026, 9, 20), 'G’mar\u00A0chatimah\u00A0tovah!'),
    ]) {
      testWidgets('on $what, greets the day that begins', (tester) async {
        await _finish(
          tester,
          week: week,
          aliyah: 6,
          day: DateTime(day.year, day.month, day.day, 10),
          progress: _allButShevii(week, day),
        );

        expect(find.byType(ParshaRings), findsOneWidget);
        expect(find.text(greeting), findsOneWidget);
        expect(find.textContaining('Shabbat\u00A0shalom'), findsNothing);
      });
    }

    testWidgets('on time says so, with the streak and the grace day it earned, and offers the haftarah', (tester) async {
      await _finish(tester, aliyah: 6, day: DateTime(2026, 10, 9, 10), progress: _readThrough(5, partly: 6, on: _monday));

      expect(find.text('Parshat Bereshit is complete'), findsOneWidget);
      // The grace day held together, so that "day" is never left alone on a
      // line.
      expect(_standing(tester, WeekStatus.onTime), 'On time · 1-week parsha streak · +1\u00A0grace\u00A0day');
      expect(find.widgetWithText(FilledButton, 'Read the haftarah'), findsOneWidget);
      expect(find.widgetWithText(TextButton, 'Done'), findsOneWidget);
      expect(find.textContaining('Next aliyah'), findsNothing);
      expect(_focused(tester, 'Read the haftarah'), isTrue);
    });

    testWidgets('on time, with the last verse repeated after its Targum, still tells of the streak', (tester) async {
      // The Targum completes the parsha, and the repeat of its last verse,
      // as the custom has it, finishes the aliyah after it.
      await _finish(
        tester,
        aliyah: 6,
        day: DateTime(2026, 10, 9, 10),
        progress: _readThrough(5, partly: 6, on: _monday),
        repeat: true,
      );

      expect(find.text('Parshat Bereshit is complete'), findsOneWidget);
      expect(_standing(tester, WeekStatus.onTime), 'On time · 1-week parsha streak · +1\u00A0grace\u00A0day');
    });

    testWidgets('on time, with streaks hidden, says only that', (tester) async {
      await _finish(
        tester,
        aliyah: 6,
        day: DateTime(2026, 10, 9, 10),
        progress: _readThrough(5, partly: 6, on: _monday),
        settings: const AppSettings(showStreaks: false, haftarahEnabled: false),
      );

      expect(_standing(tester, WeekStatus.onTime), 'On time');
      // As wide as its words, under the centred title.
      _expectStandingCentred(tester, WeekStatus.onTime, 'Parshat Bereshit is complete');
      expect(find.textContaining('streak', findRichText: true), findsNothing);
      expect(find.text('Read the haftarah'), findsNothing);
      expect(find.widgetWithText(FilledButton, 'Done'), findsOneWidget, reason: 'with nothing else to do, Done leads');
    });

    testWidgets('together with the next, says the streak continues', (tester) async {
      // Thursday of Noach, with Noach read: Bereshit, past its late window,
      // is finished in time to be doubled up.
      final thursday = LocalDate(2026, 10, 15);
      var noach = WeekProgress(weekId: '5787:2');
      for (var a = 0; a < 7; a++) {
        noach = noach.withAliyah(a, LocalDate(2026, 10, 12 + a ~/ 3));
      }
      final bereshit = _readThrough(5, partly: 6, on: thursday);
      await _finish(
        tester,
        aliyah: 6,
        day: DateTime(2026, 10, 15, 10),
        progress: bereshit.copyWith(weeks: {...bereshit.weeks, '5787:2': noach}),
      );

      expect(find.text('Parshat Bereshit is complete'), findsOneWidget);
      // The dash held to the word before it, so that no line starts with it.
      expect(
        _standing(tester, WeekStatus.restored),
        'Finished together with the next parsha\u00A0— your streak continues.',
      );
    });

    testWidgets('read again weeks later, says only how it stands, with no streak or grace day', (tester) async {
      // Wednesday of Noach: Bereshit was finished on time, and its Shevi'i
      // is read through once more.
      var bereshit = WeekProgress(weekId: '5787:1');
      for (var a = 0; a < 7; a++) {
        bereshit = bereshit.withAliyah(a, _monday.addDays(a < 3 ? a : (a < 5 ? 3 : 4)));
      }
      await _finish(
        tester,
        aliyah: 6,
        day: DateTime(2026, 10, 14, 10),
        progress: ProgressState(weeks: {'5787:1': bereshit}),
      );

      expect(find.text('Parshat Bereshit is complete'), findsOneWidget);
      expect(_standing(tester, WeekStatus.onTime), 'On time');
      expect(find.textContaining('streak', findRichText: true), findsNothing);
      expect(find.textContaining('grace', findRichText: true), findsNothing);
      // Finished long ago: its divider, as for an aliyah, over its name.
      expect(find.byType(ParshaRings), findsNothing);
      expect(find.byType(SeferDivider), findsOneWidget);
      expect(find.text('בְּרֵאשִׁית'), findsOneWidget);
      expect(find.textContaining('shalom'), findsNothing, reason: 'Thursday is not the eve of Shabbat');
    });

    testWidgets('after Shabbat says it still counts', (tester) async {
      // Sunday of Noach: Bereshit is in its late window.
      await _finish(tester, aliyah: 6, day: DateTime(2026, 10, 11, 10), progress: _readThrough(5, partly: 6, on: _monday));

      expect(find.text('Parshat Bereshit is complete'), findsOneWidget);
      expect(_standing(tester, WeekStatus.late), 'After Shabbat\u00A0— and it still counts. Your streak continues.');
      expect(find.textContaining('shalom'), findsNothing);
      _expectStandingCentred(tester, WeekStatus.late, 'Parshat Bereshit is complete');
    });

    testWidgets('after Shabbat, in Hebrew, its sentence is centred under the title, its icon at the right', (tester) async {
      await _finish(
        tester,
        aliyah: 6,
        day: DateTime(2026, 10, 11, 10),
        progress: _readThrough(5, partly: 6, on: _monday),
        settings: const AppSettings(language: AppLanguage.hebrew),
        next: 'הבא',
        finish: 'סיום',
      );

      _expectStandingCentred(tester, WeekStatus.late, 'הפרשה הושלמה', hebrew: true);
    });

    testWidgets('at twice the text size, keeps each part of the standing line whole, and gives the buttons room',
        (tester) async {
      await _finish(
        tester,
        aliyah: 6,
        day: DateTime(2026, 10, 9, 10),
        progress: _readThrough(5, partly: 6, on: _monday),
        textScale: 2,
      );

      const parts = ['On time', '1-week parsha streak', '+1\u00A0grace\u00A0day'];
      final lines = _standingLines(tester, WeekStatus.onTime);
      expect(lines, hasLength(greaterThan(1)), reason: 'too long for one line at this size');
      for (final line in lines) {
        expect(parts, containsAll(line.split(' · ')), reason: '"$line" breaks inside a part');
      }
      expect(lines.join(' · '), parts.join(' · '));
      // Read as one line, however many it takes.
      final spoken = tester.getSemantics(find.text(lines.first)).label;
      for (final part in parts) {
        expect(spoken, contains(part));
      }

      // Room above and below each label, as on Today, and the haftarah's
      // icon grown with its label: 1.6 times the theme's 20.
      for (final (button, label) in [
        (find.widgetWithText(FilledButton, 'Read the haftarah'), 'Read the haftarah'),
        (find.widgetWithText(TextButton, 'Done'), 'Done'),
      ]) {
        final outer = tester.getRect(button);
        final text = tester.getRect(find.text(label));
        expect(text.top - outer.top, greaterThanOrEqualTo(8), reason: label);
        expect(outer.bottom - text.bottom, greaterThanOrEqualTo(8), reason: label);
      }
      expect(tester.getSize(find.byIcon(Icons.auto_stories_outlined)), const Size.square(32));
      // Its lines, beside the icon, centred under the title.
      _expectStandingCentred(tester, WeekStatus.onTime, 'Parshat Bereshit is complete');
    });
  });

  group('at twice the text size, the buttons have room', () {
    void expectRoomy(WidgetTester tester, Finder button, String label) {
      final outer = tester.getRect(button);
      final text = tester.getRect(find.text(label));
      expect(text.top - outer.top, greaterThanOrEqualTo(8), reason: label);
      expect(outer.bottom - text.bottom, greaterThanOrEqualTo(8), reason: label);
      expect(outer.height, greaterThanOrEqualTo(52), reason: label);
    }

    testWidgets("Next aliyah, its chevron grown with its label, and a quiet Done", (tester) async {
      await _finish(
        tester,
        aliyah: 2,
        day: DateTime(2026, 10, 9, 10),
        progress: _readThrough(1, partly: 2, on: _monday),
        textScale: 2,
      );

      expectRoomy(tester, find.widgetWithText(FilledButton, 'Next aliyah · Revi’i'), 'Next aliyah · Revi’i');
      expectRoomy(tester, find.widgetWithText(TextButton, 'Done'), 'Done');
      // 1.6 times the theme's 20.
      expect(tester.getSize(find.byIcon(Icons.chevron_right)), const Size.square(32));
    });

    testWidgets('Done leading, and a quiet Keep going', (tester) async {
      await _finish(
        tester,
        aliyah: 2,
        day: DateTime(2026, 10, 7, 10),
        progress: _readThrough(1, partly: 2, on: LocalDate(2026, 10, 7)),
        textScale: 2,
      );

      expectRoomy(tester, find.widgetWithText(FilledButton, 'Done'), 'Done');
      expectRoomy(tester, find.widgetWithText(TextButton, 'Keep going: Revi’i'), 'Keep going: Revi’i');
    });
  });

  testWidgets("the divider's hairlines draw out, then the rest fades in", (tester) async {
    await _finish(
      tester,
      aliyah: 2,
      day: DateTime(2026, 10, 9, 10),
      progress: _readThrough(1, partly: 2, on: _monday),
      settle: false,
    );
    await tester.pump();
    double drawn() => tester.widget<SeferDivider>(find.byType(SeferDivider)).progress;
    double shown() => tester
        .widget<FadeTransition>(find.ancestor(of: find.text('Shlishi is complete'), matching: find.byType(FadeTransition)).first)
        .opacity
        .value;
    expect(drawn(), lessThan(0.1));
    expect(shown(), 0);
    await tester.pump(Motion.long);
    expect(drawn(), 1);
    expect(shown(), 0);
    await tester.pump(Motion.short);
    expect(shown(), 1);
  });

  testWidgets("the parsha's rings close, then its name and the rest fade in as the last arc lands", (tester) async {
    await _finish(
      tester,
      aliyah: 6,
      day: DateTime(2026, 10, 9, 10),
      progress: _readThrough(5, partly: 6, on: _monday),
      settle: false,
    );
    await tester.pump();
    final fade = find.ancestor(of: find.text('בְּרֵאשִׁית'), matching: find.byType(FadeTransition)).first;
    double shown() => tester.widget<FadeTransition>(fade).opacity.value;
    // The name fades in with the title, beneath the rings, which are there
    // from the start.
    expect(find.descendant(of: fade, matching: find.text('Parshat Bereshit is complete')), findsOneWidget);
    expect(find.descendant(of: fade, matching: find.byType(ParshaRings)), findsNothing);
    expect(shown(), 0);
    await tester.pump(Motion.ring);
    expect(shown(), 0);
    await tester.pump(Motion.short);
    expect(shown(), 1);
    await tester.pumpAndSettle();
  });

  testWidgets('under Reduce Motion, the panel is simply there', (tester) async {
    await _finish(
      tester,
      aliyah: 2,
      day: DateTime(2026, 10, 9, 10),
      progress: _readThrough(1, partly: 2, on: _monday),
      settings: const AppSettings(reduceMotion: true),
      settle: false,
    );
    await tester.pump();
    expect(tester.widget<SeferDivider>(find.byType(SeferDivider)).progress, 1);
    final fade = find.ancestor(of: find.text('Shlishi is complete'), matching: find.byType(FadeTransition)).first;
    expect(tester.widget<FadeTransition>(fade).opacity.value, 1);
  });

  testWidgets("under Reduce Motion, the parsha's panel is simply there too", (tester) async {
    await _finish(
      tester,
      aliyah: 6,
      day: DateTime(2026, 10, 9, 10),
      progress: _readThrough(5, partly: 6, on: _monday),
      settings: const AppSettings(reduceMotion: true),
      settle: false,
    );
    await tester.pump();
    final fade = find.ancestor(of: find.text('בְּרֵאשִׁית'), matching: find.byType(FadeTransition)).first;
    expect(tester.widget<FadeTransition>(fade).opacity.value, 1);
    expect(tester.binding.transientCallbackCount, 0, reason: 'nothing moves, the rings included');
  });

  group("the parsha's moment", () {
    const success = 'HapticFeedbackType.lightImpact';
    const celebrate = 'vibrate';
    // Back from the panel, as the keyboard goes back (the panel has no Back).
    Future<void> back(WidgetTester tester) async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
      await tester.pumpAndSettle();
    }

    testWidgets('opened from a link, shows its rings closed from the first frame, and celebrates at once',
        (tester) async {
      await _finish(
        tester,
        aliyah: 6,
        day: DateTime(2026, 10, 9, 10),
        progress: _readThrough(5, partly: 6, on: _monday),
        settle: false,
        linked: true,
      );
      final sent = _recordHaptics(tester);
      await tester.pump();
      // Nothing to sweep from: closed at once, and the haptic with them,
      // not 600 ms later with nothing moving.
      expect(find.text('7/7'), findsOneWidget);
      expect(find.text('6/7'), findsNothing);
      expect(sent, [celebrate]);
      // The rest follows after a short beat.
      final fade = find.ancestor(of: find.text('בְּרֵאשִׁית'), matching: find.byType(FadeTransition)).first;
      await tester.pump(Motion.short + Motion.short);
      expect(tester.widget<FadeTransition>(fade).opacity.value, 1);
      await tester.pumpAndSettle();
      expect(sent, [celebrate]);
    });

    testWidgets('stepped back from before its rings close and finished again, celebrates once, at the second',
        (tester) async {
      await _finish(
        tester,
        aliyah: 6,
        day: DateTime(2026, 10, 9, 10),
        progress: _readThrough(5, partly: 6, on: _monday),
        settle: false,
      );
      // Finish has been pressed already; the haptics from here on.
      final sent = _recordHaptics(tester);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('6/7'), findsOneWidget, reason: 'still closing');
      await back(tester);
      expect(sent, isEmpty, reason: 'the first panel went before its rings closed');
      await tester.tap(find.text('Finish'));
      await tester.pumpAndSettle();
      // The parsha's moment still, its rings closed already, felt once.
      expect(find.byType(ParshaRings), findsOneWidget);
      expect(_standing(tester, WeekStatus.onTime), startsWith('On time · 1-week parsha streak'));
      expect(sent, [celebrate]);
    });

    testWidgets('stepped back from once its rings have closed and finished again, only tells how it stands',
        (tester) async {
      await _finish(tester, aliyah: 6, day: DateTime(2026, 10, 9, 10), progress: _readThrough(5, partly: 6, on: _monday));
      expect(find.byType(ParshaRings), findsOneWidget);
      final sent = _recordHaptics(tester);
      await back(tester);
      await tester.tap(find.text('Finish'));
      await tester.pumpAndSettle();
      // Once a visit: its divider, the plain standing, an aliyah's success.
      expect(find.byType(ParshaRings), findsNothing);
      expect(find.byType(SeferDivider), findsOneWidget);
      expect(_standing(tester, WeekStatus.onTime), 'On time');
      expect(sent, [success]);
    });

    testWidgets("finished from the week's page, its rings close once: back on the page they are closed",
        (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = await pumpApp(
        tester,
        settings: const AppSettings(
          onboardingComplete: true,
          notificationPromptShown: true,
          method: ReadingMethod.aliyahByAliyah,
        ).withRepeatLastVerse(false),
        now: DateTime(2026, 10, 9, 10),
        progress: _readThrough(5, partly: 6, on: _monday),
      );
      c.read(routerProvider).go('/parsha/week/5787:1');
      await _loadTexts(tester);
      expect(find.text('6/7'), findsOneWidget);
      c.read(routerProvider).push('/read/5787:1/6');
      await _loadTexts(tester);
      await tester.tap(find.text('Finish'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 16));
      // The panel's rings sweep from what the week's page showed.
      expect(find.text('6/7'), findsOneWidget);
      await tester.pumpAndSettle();
      expect(find.text('6/7'), findsNothing);

      await tester.tap(find.text('Done'));
      await tester.pump();
      for (var i = 0; i < 4; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        expect(find.text('6/7'), findsNothing, reason: 'not swept closed a second time');
      }
      await tester.pumpAndSettle();
      expect(find.text('7/7'), findsOneWidget);
    });

    for (final (what, size, theme, nameSize, nameWeight, titleSize) in [
      ('from 600 dp, its name and title a size larger', const Size(1000, 900), AppThemeMode.light, 44.0, null, 'medium'),
      ('in high contrast, its name in bold', const Size(412, 915), AppThemeMode.highContrastLight, 36.0, FontWeight.w700, 'small'),
    ]) {
      testWidgets(what, (tester) async {
        await _finish(
          tester,
          aliyah: 6,
          day: DateTime(2026, 10, 9, 10),
          progress: _readThrough(5, partly: 6, on: _monday),
          settings: AppSettings(theme: theme),
          size: size,
        );
        final name = tester.widget<Text>(find.text('בְּרֵאשִׁית')).style!;
        expect(name.fontSize, nameSize);
        if (nameWeight != null) expect(name.fontWeight, nameWeight);
        final textTheme = Theme.of(tester.element(find.text('בְּרֵאשִׁית'))).textTheme;
        expect(
          tester.widget<Text>(find.text('Parshat Bereshit is complete')).style?.fontSize,
          (titleSize == 'medium' ? textTheme.headlineMedium : textTheme.headlineSmall)!.fontSize,
        );
      });
    }
  });
}
