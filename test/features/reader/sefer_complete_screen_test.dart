import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/providers.dart' show ProgressState;
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/core/calendar/jewish_holidays.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/core/calendar/parsha_schedule.dart';
import 'package:shnayim_mikra/core/text/hebrew_text.dart';
import 'package:shnayim_mikra/features/parsha/week_context.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikra/features/reader/sefer_complete_screen.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/ui/widgets/lines.dart';
import 'package:shnayim_mikra/ui/widgets/ornaments.dart';

import '../../helpers.dart';

// The page shown as a book of the Torah is finished, set as a colophon
// (DESIGN_SYSTEM.md §6.23), and the Siyum HaTorah as Deuteronomy is
// finished with the year's reading; their moment and its one haptic (§8).

/// HapticFeedback.vibrate(), Android's celebrate haptic.
const _celebrate = 'vibrate';

/// Friday 25 December 2026, 15 Tevet 5787: the day before Vayechi, the last
/// parsha of Genesis, is read.
final _friday = LocalDate(2026, 12, 25);

/// Genesis 5787: Bereshit to Vayigash read a month before [_friday], and
/// Vayechi on it, all but its last [lastAliyot] aliyot.
ProgressState _genesis({int lastAliyot = 0}) {
  final before = _friday.addDays(-30);
  return ProgressState(weeks: {
    for (var n = 1; n <= 11; n++) '5787:$n': WeekProgress(weekId: '5787:$n').withAll(before),
    '5787:12': [for (var a = 0; a < 7 - lastAliyot; a++) a]
        .fold(WeekProgress(weekId: '5787:12'), (w, a) => w.withAliyah(a, _friday)),
  });
}

/// Every week of 5786 from parsha [from] on read whole, each on the last
/// weekday before it is read: Vezot HaBerakhah on Hoshana Rabbah, Friday 2
/// October 2026 (21 Tishrei 5787).
ProgressState _year5786({int from = 1}) {
  final weeks = cycleWeeks(const ParshaSchedule(israel: false), 5786);
  final read = <String, WeekProgress>{};
  for (var n = from; n <= 54; n++) {
    final week = weeks[n]!;
    var day = week.occasion.addDays(-1);
    while (JewishHolidays.isRestDay(day, israel: false)) {
      day = day.addDays(-1);
    }
    final id = weekIdFor(week.portion, week.occasion);
    read[id] = WeekProgress(weekId: id).withAll(day);
  }
  return ProgressState(weeks: read);
}

/// The haptics sent to the platform from now on, each by its type as
/// HapticFeedback sends it ('vibrate' for HapticFeedback.vibrate()).
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

/// Opens the page for [key] on a phone, with [progress] logged, on the
/// Friday Genesis was finished, and builds its first frame.
Future<ProviderContainer> _open(
  WidgetTester tester,
  String key, {
  required ProgressState progress,
  AppSettings settings = const AppSettings(),
}) async {
  tester.view.physicalSize = const Size(412, 915);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final c = await pumpApp(
    tester,
    settings: settings.copyWith(onboardingComplete: true, joinDate: LocalDate(2025, 10, 1)),
    now: DateTime(2026, 12, 25, 11),
    progress: progress,
  );
  c.read(routerProvider).go('/celebrate/$key');
  // The route, parsed, then built.
  await tester.pump();
  await tester.pump();
  expect(find.byType(SeferCompleteScreen), findsOneWidget);
  return c;
}

/// The balanced line of [text], however it holds its dash.
Finder _balanced(String text) => find.byWidgetPredicate((w) => w is BalancedText && w.text == text);

/// The line of [text] that dates the page, however it is wrapped: the test
/// font is wider than the app's.
Finder _dated(String text) => find.byWidgetPredicate((w) => w is DotLine && w.parts.single == text);

/// The page's own [finder], not Today's beneath it as it opens.
Finder _onPage(Finder finder) => find.descendant(of: find.byType(SeferCompleteScreen), matching: finder);

/// How much of the frame's rule is drawn.
double? _drawn(WidgetTester tester) =>
    tester.widget<TitlePageFrame>(_onPage(find.byType(TitlePageFrame))).drawProgress;

/// The page's fade.
Animation<double> _fade(WidgetTester tester) =>
    tester.widget<FadeTransition>(_onPage(find.byType(FadeTransition)).first).opacity;

void main() {
  testWidgets('a finished book is a colophon: framed, one divider, what was read and the day it was finished',
      (tester) async {
    final semantics = tester.ensureSemantics();
    await _open(tester, 'sefer:5787:0', progress: _genesis());
    await tester.pumpAndSettle();

    final frame = find.byType(TitlePageFrame);
    expect(frame, findsOneWidget);
    Finder inFrame(Finder f) => find.descendant(of: frame, matching: f);
    expect(inFrame(find.text(SeferCompleteScreen.chazak)), findsOneWidget);
    expect(find.byType(SeferDivider), findsOneWidget, reason: 'the frame and one divider: two ornaments');
    expect(inFrame(find.byType(Lozenge)), findsNothing);
    expect(inFrame(find.text('Genesis is complete')), findsOneWidget);
    expect(inFrame(find.text('1,533 verses, twice, with Targum.')), findsOneWidget);
    expect(inFrame(_dated('Finished on Friday, 15 Tevet 5787')), findsOneWidget);
    // In that order, down the page, and Continue below the frame.
    final tops = [
      for (final line in [
        find.text(SeferCompleteScreen.chazak),
        find.text('Genesis is complete'),
        _dated('Finished on Friday, 15 Tevet 5787'),
      ])
        tester.getTopLeft(line).dy,
    ];
    expect(tops, orderedEquals([...tops]..sort()));
    expect(tester.getTopLeft(find.text('Continue')).dy, greaterThan(tester.getBottomLeft(frame).dy));
    final button = tester.getSize(find.widgetWithText(FilledButton, 'Continue'));
    expect(button.width, greaterThanOrEqualTo(200));
    expect(button.height, greaterThanOrEqualTo(52));

    // The page's heading, read from its letters.
    final heading = tester.getSemantics(find.text(SeferCompleteScreen.chazak));
    expect(heading, isSemantics(label: HebrewText.stripNikud(SeferCompleteScreen.chazak), isHeader: true));
    expect(heading.getSemanticsData().headingLevel, 1);
    semantics.dispose();
  });

  testWidgets('in Hebrew, the colophon is dated as a Hebrew book is', (tester) async {
    const hebrew = AppSettings(language: AppLanguage.hebrew);
    await _open(tester, 'sefer:5787:0', progress: _genesis(), settings: hebrew);
    await tester.pumpAndSettle();
    expect(find.text('ספר בראשית הושלם'), findsOneWidget);
    expect(find.text('1,533 פסוקים, שניים מקרא ותרגום.'), findsOneWidget);
    expect(_dated('נשלם ביום שישי, ט״ו בטבת תשפ״ז'), findsOneWidget);
  });

  testWidgets('the page fades in, its frame’s rule then draws, and the celebrate haptic comes as it closes, once',
      (tester) async {
    final sent = _recordHaptics(tester);
    await _open(tester, 'sefer:5787:0', progress: _genesis());
    final fade = _fade(tester);
    expect(fade.value, 0);
    expect(_drawn(tester), 0);

    await tester.pump(const Duration(milliseconds: 380));
    expect(fade.value, greaterThan(0.9), reason: 'fading in over 400 ms');
    expect(_drawn(tester), 0, reason: 'the rule waits for the fade');
    await tester.pump(const Duration(milliseconds: 470));
    expect(fade.value, 1);
    expect(_drawn(tester), inExclusiveRange(0, 1));
    expect(sent, isEmpty, reason: 'the rule is still drawing');

    await tester.pump(const Duration(milliseconds: 500));
    expect(_drawn(tester), 1);
    expect(sent, [_celebrate]);
    await tester.pump(const Duration(minutes: 1));
    expect(sent, [_celebrate]);
    expect(find.byType(SeferCompleteScreen), findsOneWidget, reason: 'it stays until Continue');
  });

  testWidgets('under Reduce Motion it is whole at once, and its haptic comes at once', (tester) async {
    final sent = _recordHaptics(tester);
    await _open(tester, 'sefer:5787:0', progress: _genesis(), settings: const AppSettings(reduceMotion: true));
    expect(_drawn(tester), 1);
    expect(_fade(tester).value, 1);
    expect(sent, [_celebrate]);
  });

  testWidgets('the Siyum HaTorah: five lozenges, and the whole Torah read in the year', (tester) async {
    await _open(tester, 'sefer:5786:4', progress: _year5786());
    await tester.pumpAndSettle();
    final frame = find.byType(TitlePageFrame);
    final lozenges = find.descendant(of: frame, matching: find.byType(Lozenge));
    expect(lozenges, findsNWidgets(5));
    expect(find.byType(SeferDivider), findsNothing, reason: 'the lozenges in its place');
    expect(find.text('Siyum HaTorah'), findsOneWidget);
    expect(find.text('Deuteronomy is complete'), findsNothing);
    expect(_balanced('The whole Torah — 5,846 verses, twice, with Targum, in 5786.'), findsOneWidget);
    expect(_dated('Finished on Friday, 21 Tishrei 5787'), findsOneWidget);
    // 8 apart, and centred.
    final left = [for (var i = 0; i < 5; i++) tester.getTopLeft(lozenges.at(i)).dx];
    expect([for (var i = 1; i < 5; i++) left[i] - left[i - 1]], everyElement(16));
    expect((tester.getCenter(lozenges.at(2)).dx - tester.getCenter(frame).dx).abs(), lessThan(0.5));
  });

  testWidgets('a reader who joined partway makes a siyum from their first parsha, and is told of the book',
      (tester) async {
    await _open(tester, 'sefer:5786:4', progress: _year5786(from: 4));
    await tester.pumpAndSettle();
    expect(find.text('Siyum from Parshat Vayera'), findsOneWidget);
    expect(find.text('956 verses, twice, with Targum.'), findsOneWidget);
    expect(find.descendant(of: find.byType(TitlePageFrame), matching: find.byType(Lozenge)), findsNWidgets(5));
  });

  testWidgets('Deuteronomy finished without the year’s reading before it is a book like the rest', (tester) async {
    await _open(tester, 'sefer:5786:4', progress: _year5786(from: 44));
    await tester.pumpAndSettle();
    expect(find.text('Deuteronomy is complete'), findsOneWidget);
    expect(find.byType(SeferDivider), findsOneWidget);
    expect(find.text('Siyum HaTorah'), findsNothing);
  });

  group('one finish is felt once', () {
    /// Opens the last aliyah of Vayechi, all of Genesis read but it, and
    /// marks it read from the menu, which finishes the book.
    Future<List<String>> finishGenesis(
      WidgetTester tester, {
      bool full = false,
      bool reduceMotion = false,
      bool settle = true,
    }) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = await pumpApp(
        tester,
        settings: AppSettings(
          onboardingComplete: true,
          joinDate: LocalDate(2026, 10, 4),
          notificationPromptShown: true,
          reduceMotion: reduceMotion,
        ),
        now: DateTime(2026, 12, 25, 10),
        progress: _genesis(lastAliyot: 1),
      );
      c.read(routerProvider).push('/read/5787:12/6${full ? '?mode=full' : ''}');
      for (var i = 0; i < 20 && find.byTooltip('More options').evaluate().isEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      final sent = _recordHaptics(tester);
      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      // The menu's, over the full text's button at the aliyah's end.
      await tester.tap(find.text('Mark this aliyah as read').last);
      await tester.pump();
      if (settle) {
        await tester.pumpAndSettle();
        expect(find.byType(SeferCompleteScreen), findsOneWidget);
      } else {
        // The book's page, pushed on the next frame.
        await tester.pump();
        await tester.pump();
      }
      return sent;
    }

    /// The celebrate haptic of the platform under test.
    String celebrate() =>
        defaultTargetPlatform == TargetPlatform.iOS ? 'HapticFeedbackType.successNotification' : _celebrate;
    const phones = TargetPlatformVariant({TargetPlatform.android, TargetPlatform.iOS});

    testWidgets(
      'in the guided reader, once: not again by the book’s page, nor as the rings close beneath it',
      (tester) async {
        final sent = await finishGenesis(tester);
        expect(sent, [celebrate()]);
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(find.text('Parshat Vayechi is complete'), findsOneWidget);
        expect(sent, [celebrate()]);
      },
      variant: phones,
    );

    testWidgets(
      "in the guided reader, as the rings close beneath the book's page, before it is left",
      (tester) async {
        // Today showed the week's rings as the app opened, so the panel's
        // sweep. The page covers the reader before they have closed, which
        // stops the reader's tickers; the haptic comes as they close all the
        // same, not only once the page is left.
        final sent = await finishGenesis(tester, settle: false);
        expect(find.byType(SeferCompleteScreen), findsOneWidget);
        expect(sent, isEmpty);
        // Frame by frame, as a device draws them, so that the page's
        // transition ends, and the reader is hidden, before the rings close.
        for (var t = 0; t < 700; t += 16) {
          await tester.pump(const Duration(milliseconds: 16));
        }
        expect(sent, [celebrate()], reason: 'as the rings close, 600 ms after the finish');
        await tester.pumpAndSettle();
        expect(sent, [celebrate()], reason: 'the page gives none');
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(sent, [celebrate()]);
      },
      variant: phones,
    );

    testWidgets(
      "Continue pressed before the page's rule closes still leaves the one celebrate",
      (tester) async {
        final sent = await finishGenesis(tester, settle: false);
        await tester.pump(const Duration(milliseconds: 800));
        expect(find.byType(SeferCompleteScreen), findsOneWidget);
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(find.byType(SeferCompleteScreen), findsNothing);
        expect(find.text('Parshat Vayechi is complete'), findsOneWidget);
        expect(sent, [celebrate()]);
      },
      variant: phones,
    );

    testWidgets(
      'under Reduce Motion, by the rings closed at once, and the page that follows gives none',
      (tester) async {
        final sent = await finishGenesis(tester, reduceMotion: true);
        expect(sent, [celebrate()]);
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(sent, [celebrate()]);
      },
      variant: phones,
    );

    testWidgets(
      'in the full text, at the press, and the page that follows gives none',
      (tester) async {
        final sent = await finishGenesis(tester, full: true);
        expect(sent, [celebrate()]);
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(sent, [celebrate()]);
      },
      variant: phones,
    );
  });
}
