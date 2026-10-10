import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/features/reader/reader_screen.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';

import '../helpers.dart';

/// The plan step of onboarding, and the reading it ends on, for a reader who
/// joins in the week of Noach 5787: Sunday 11 to Friday 16 October 2026,
/// read on Shabbat the 17th.
void main() {
  final sunday = DateTime(2026, 10, 11, 10);
  final wednesday = DateTime(2026, 10, 14, 10);
  final friday = DateTime(2026, 10, 16, 10);

  /// Pumps a first launch on [now] and goes through to the plan step.
  Future<ProviderContainer> openPlanStep(WidgetTester tester, DateTime now) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await pumpApp(tester, settings: const AppSettings(), now: now);
    await tester.pumpAndSettle();
    await tester.tap(find.text("Start this week's parsha"));
    await tester.pumpAndSettle();
    for (var step = 0; step < 2; step++) {
      await tester.tap(find.text('Continue'));
      await tester.pumpAndSettle();
    }
    expect(find.text('Your plan this week'), findsOneWidget);
    return c;
  }

  Future<void> tapScrolled(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  /// Taps "Start reading" and waits for the reader's texts.
  Future<ReaderScreen> startReading(WidgetTester tester) async {
    final start = find.text('Start reading');
    await tester.ensureVisible(start);
    await tester.pumpAndSettle();
    await tester.tap(start);
    // The reader shows a spinner until its texts load, on real I/O.
    await tester.pump();
    await tester.pump();
    for (var i = 0; i < 20 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    return tester.widget<ReaderScreen>(find.byType(ReaderScreen));
  }

  bool selected(WidgetTester tester) => tester.widget<RadioGroup<bool>>(find.byType(RadioGroup<bool>)).groupValue!;

  testWidgets('joining on a Friday, the whole parsha is read that day, from Rishon', (tester) async {
    final c = await openPlanStep(tester, friday);
    expect(find.text('This week'), findsOneWidget);
    expect(find.text('Read the whole parsha by Shabbat'), findsOneWidget);
    expect(find.text('Start with today\'s reading'), findsOneWidget);
    expect(find.text('Full plan from next week'), findsOneWidget);
    // Noach has 153 verses.
    expect(find.textContaining(RegExp(r'^153 verses · about \d+ min today$')), findsOneWidget);
    expect(selected(tester), isTrue, reason: 'reading the whole parsha is the default');

    final reader = await startReading(tester);
    expect(reader.weekId, '5787:2');
    expect(reader.aliyah, 0);
    final s = c.read(settingsProvider);
    expect(s.joinDate, LocalDate(2026, 10, 16));
    expect(s.starterCatchUp, isTrue);
    final plan = c.read(currentPlanProvider);
    expect(plan.days, hasLength(1));
    expect(plan.days.single.date, LocalDate(2026, 10, 16));
    expect(plan.days.single.aliyot, [0, 1, 2, 3, 4, 5, 6]);
  });

  testWidgets("joining on a Friday and starting with today's reading opens Shishi", (tester) async {
    final c = await openPlanStep(tester, friday);
    await tapScrolled(tester, find.text("Start with today's reading"));
    expect(selected(tester), isFalse);

    final reader = await startReading(tester);
    expect(c.read(settingsProvider).starterCatchUp, isFalse);
    // The usual plan: an aliyah a day from Sunday, and Shishi and Shevi'i on
    // Friday.
    final plan = c.read(currentPlanProvider);
    expect(plan.days, hasLength(6));
    expect(plan.dayFor(LocalDate(2026, 10, 16))!.aliyot, [5, 6]);
    expect(reader.aliyah, 5);
  });

  testWidgets('midweek, the whole parsha is spread over the days left, by the plan chosen', (tester) async {
    await openPlanStep(tester, wednesday);
    // Wednesday, Thursday and Friday.
    expect(find.textContaining(RegExp(r'^153 verses · about \d+ min over 3 days$')), findsOneWidget);

    // Shevi'i on Shabbat morning makes it four.
    await tapScrolled(tester, find.text("Shevi'i on Shabbat morning"));
    expect(find.textContaining(RegExp(r'min over 4 days$')), findsOneWidget);

    // All on Friday is the same plan whenever the reader starts.
    await tapScrolled(tester, find.text('All on Friday'));
    expect(find.text('This week'), findsNothing);
    expect(find.byType(RadioGroup<bool>), findsNothing);
  });

  testWidgets("joining on the week's first day asks nothing about it", (tester) async {
    final c = await openPlanStep(tester, sunday);
    expect(find.text('This week'), findsNothing);
    expect(find.text('Read the whole parsha by Shabbat'), findsNothing);

    final reader = await startReading(tester);
    expect(reader.aliyah, 0);
    expect(c.read(currentPlanProvider).days, hasLength(6));
  });
}
