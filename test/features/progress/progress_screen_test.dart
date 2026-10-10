import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/l10n/app_localizations_en.dart';
import 'package:shnayim_mikra/ui/theme/focus.dart';
import 'package:shnayim_mikra/ui/theme/palette.dart';
import 'package:shnayim_mikra/ui/widgets/common.dart';
import 'package:shnayim_mikra/ui/widgets/ledger.dart';
import 'package:shnayim_mikra/ui/widgets/ornaments.dart';
import 'package:shnayim_mikra/ui/widgets/paper_group.dart';
import 'package:shnayim_mikra/ui/widgets/sefer_choice_chip.dart';

import '../../helpers.dart';

/// Progress, top to bottom (docs/DESIGN_SYSTEM.md §9): the ledger, grace, this
/// year, the week, the Torah map, the weeks gone by, a pause and the Record.
void main() {
  final en = AppLocalizationsEn();

  Future<ProviderContainer> openProgress(
    WidgetTester tester, {
    AppSettings? settings,
    ProgressState? progress,
    DateTime? now,
  }) async {
    tester.view.physicalSize = const Size(412, 2600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await pumpApp(
      tester,
      settings: settings ?? AppSettings(onboardingComplete: true, joinDate: historyJoinDate),
      now: now ?? historyNow,
      progress: progress ?? historyProgress(),
    );
    c.read(routerProvider).go('/progress');
    await tester.pumpAndSettle();
    return c;
  }

  /// A reader in their second year, in the week of Bereshit 5787.
  Future<ProviderContainer> openSecondYear(WidgetTester tester, {AppSettings? settings}) => openProgress(
    tester,
    settings: settings ?? AppSettings(onboardingComplete: true, joinDate: secondYearJoinDate),
    progress: ProgressState(weeks: secondYearProgress()),
    now: DateTime(2026, 10, 7, 10),
  );

  /// What [finder] finds, scrolled into view.
  Future<Finder> shown(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    return finder;
  }

  testWidgets('opens on the ledger and grace, with the rules behind "About streaks"', (tester) async {
    final c = await openProgress(tester);
    final summary = c.read(streakSummaryProvider);
    final ledger = tester.widget<LedgerCard>(find.byType(LedgerCard));
    expect((ledger.parshaStreak, ledger.daysOnTrack), (summary.parshaStreak, summary.daysOnTrack));
    expect(find.text(en.graceAvailable(summary.graceBalance)), findsOneWidget);
    expect(
      tester
          .widget<Icon>(find.descendant(of: find.byType(PaperRow), matching: find.byIcon(Icons.shield_outlined)))
          .color,
      Palettes.statusLight.grace,
    );
    // No paragraphs of rules on the page itself.
    expect(find.text(en.graceExplainer), findsNothing);
    expect(find.text(en.streakExplainer), findsNothing);

    await tester.tap(find.widgetWithText(TextButton, en.aboutStreaks));
    await tester.pumpAndSettle();
    final sheet = find.byType(BottomSheet);
    expect(find.descendant(of: sheet, matching: find.widgetWithText(SheetTitle, en.aboutStreaks)), findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text(en.graceExplainer)), findsOneWidget);
    expect(find.descendant(of: sheet, matching: find.text(en.streakExplainer)), findsOneWidget);
  });

  testWidgets('a ledger column says how long its longest run was only when it was longer', (tester) async {
    final c = await openProgress(tester);
    // Bereshit on time, Noach late, Lech-Lecha missed, Vayera made up and
    // Chayei Sara on time: the parsha streak is 1 of a longest 2.
    expect(find.text('Longest: 2 weeks'), findsOneWidget);
    final summary = c.read(streakSummaryProvider);
    expect(
      find.textContaining(RegExp(r'^Longest: \d+ days?$')),
      summary.longestDaysOnTrack > summary.daysOnTrack ? findsOneWidget : findsNothing,
    );
  });

  testWidgets('this year counts its parshiyot, its verses and has its bar', (tester) async {
    await openProgress(tester);
    expect(find.text('This year'), findsOneWidget);
    expect(find.text('4 of 54 parshiyot'), findsOneWidget);
    expect(find.textContaining(RegExp(r'^5787 · [\d,]+ verses read twice with Targum$')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^This year: 4 of 54 parshiyot complete; Toldot in progress')), findsOneWidget);
    // With one year in the log, there is nothing to choose.
    expect(find.byType(SeferChoiceChip), findsNothing);
  });

  testWidgets('recent weeks leave out the week before the reader joined, with nothing read', (tester) async {
    await openProgress(tester);
    final recent = await shown(tester, find.text(en.recentWeeks));
    expect(recent, findsOneWidget);
    // The reader joined on Simchat Torah, the last day of Vezot HaBerakhah's
    // week, and read nothing of it.
    expect(find.textContaining(RegExp('^Vezot')), findsNothing);
    expect(find.text(en.weekTransparent), findsNothing);
    for (final name in ['Toldot', 'Chayei Sara', 'Vayera', 'Lech-Lecha', 'Noach', 'Bereshit']) {
      expect(
        find.descendant(of: find.byType(PaperGroup), matching: find.text(name)),
        findsWidgets,
        reason: name,
      );
    }
  });

  testWidgets('ten weeks are shown, and the rest in place on "Show all"', (tester) async {
    await openSecondYear(tester);
    final weeks = find.ancestor(of: find.text('Vezot Haberakhah'), matching: find.byType(PaperGroup)).first;
    int rows() => tester.widget<PaperGroup>(weeks).children.length;
    expect(rows(), 10);
    final all = await shown(tester, find.textContaining(RegExp(r'^Show all \(\d+\)$')));
    final total = int.parse(RegExp(r'\d+').firstMatch(tester.widget<Text>(all).data!)!.group(0)!);
    expect(total, greaterThan(40));

    // From the keyboard: the focus goes on to the first week it shows.
    Focus.of(tester.element(all)).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(rows(), total);
    expect(find.textContaining(RegExp(r'^Show all')), findsNothing);
    final eleventh = tester.widget<SeferInkWell>(
      find.descendant(of: weeks, matching: find.byType(SeferInkWell)).at(10),
    );
    expect(FocusManager.instance.primaryFocus, eleventh.focusNode);
    expect(eleventh.focusNode, isNotNull);
  });

  testWidgets('"Life happens" pauses, and while paused offers to end or extend the pause', (tester) async {
    final c = await openProgress(tester);
    final row = await shown(tester, find.text(en.pauseTitle));
    expect(find.text(en.pauseRowBody), findsOneWidget);
    await tester.tap(row);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(AlertDialog, en.pauseTitle), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, en.pauseAction));
    await tester.pumpAndSettle();

    // Seven days from Wednesday 11 November: to Tuesday the 17th.
    expect(find.text(en.pausedBanner('Tuesday, November 17')), findsOneWidget);
    expect(find.widgetWithText(FilledButton, en.endPause), findsOneWidget);
    await tester.tap(await shown(tester, find.widgetWithText(TextButton, en.extendPause)));
    await tester.pumpAndSettle();
    final dialog = find.byType(AlertDialog);
    expect(find.descendant(of: dialog, matching: find.text(en.extendPauseTitle)), findsOneWidget);
    await tester.tap(find.descendant(of: dialog, matching: find.text('7 days')));
    await tester.pump();
    expect(find.descendant(of: dialog, matching: find.text(en.pauseStarted('Tuesday, November 24'))), findsOneWidget);
    await tester.tap(find.descendant(of: dialog, matching: find.widgetWithText(FilledButton, en.extendPause)));
    await tester.pumpAndSettle();
    expect(c.read(progressProvider).pauses.single.end, LocalDate(2026, 11, 24));
    expect(find.text(en.pausedBanner('Tuesday, November 24')), findsOneWidget);

    await tester.tap(await shown(tester, find.widgetWithText(FilledButton, en.endPause)));
    await tester.pumpAndSettle();
    expect(c.read(isPausedProvider), isFalse);
    expect(find.text(en.pauseRowBody), findsOneWidget);
  });

  testWidgets('a pause reaches no further than 30 days ahead', (tester) async {
    await openProgress(
      tester,
      progress: historyProgress().copyWith(pauses: [Pause(LocalDate(2026, 11, 11), LocalDate(2026, 12, 8))]),
    );
    await tester.tap(await shown(tester, find.widgetWithText(TextButton, en.extendPause)));
    await tester.pumpAndSettle();
    // To 8 December is 28 days: one more day is the most it can take.
    expect(find.byType(SeferChoiceChip), findsOneWidget);
    expect(find.text('1 day'), findsOneWidget);
  });

  testWidgets('the Record lists only what is done, newest first, with no locks or trophies', (tester) async {
    await openSecondYear(tester);
    final record = await shown(tester, find.text(en.recordTitle));
    expect(record, findsOneWidget);
    expect(find.byIcon(Icons.emoji_events), findsNothing);
    expect(find.byIcon(Icons.lock_outline), findsNothing);
    expect(find.text('Not yet reached'), findsNothing);
    final group = find.byType(PaperGroup).last;
    final titles = [
      for (final t in tester.widgetList<Text>(find.descendant(of: group, matching: find.byType(Text)))) t.data ?? '',
    ];
    // The joiner's siyum, above the book that completed it, both finished on
    // the same day; Genesis, begun at Vayera, was never finished.
    expect(titles.take(4), ['Siyum from Parshat Vayera', 'Oct 2, 2026', 'Deuteronomy is complete', 'Oct 2, 2026']);
    expect(titles, isNot(contains('Siyum HaTorah')));
    expect(titles, isNot(contains('Genesis is complete')));
    expect(titles.last, 'Nov 2, 2025');
    expect(titles[titles.length - 2], 'First aliyah');
    // A finished book is followed by the words said as one is.
    expect(find.descendant(of: group, matching: find.text('חֲזַק חֲזַק וְנִתְחַזֵּק')), findsNWidgets(4));
    // One lozenge to a row.
    expect(
      find.descendant(of: group, matching: find.byType(Lozenge)),
      findsNWidgets(tester.widget<PaperGroup>(group).children.length),
    );
  });

  testWidgets('with streak numbers hidden, the Record leaves out the streaks', (tester) async {
    await openSecondYear(
      tester,
      settings: AppSettings(onboardingComplete: true, joinDate: secondYearJoinDate, showStreaks: false),
    );
    expect(find.byType(LedgerCard), findsNothing);
    expect(find.text(en.streaksHidden), findsOneWidget);
    await shown(tester, find.text(en.recordTitle));
    expect(find.textContaining('parsha streak'), findsNothing);
    expect(find.textContaining('days on track'), findsNothing);
    expect(find.text('Deuteronomy is complete'), findsOneWidget);
  });

  testWidgets('with an earlier year in the log, chips choose the year the bar and map show', (tester) async {
    await openSecondYear(tester);
    final chips = find.byType(SeferChoiceChip);
    expect(chips, findsNWidgets(2));
    expect([for (final c in tester.widgetList<SeferChoiceChip>(chips)) (c.label as Text).data], ['5786', '5787']);
    expect(tester.widget<SeferChoiceChip>(chips.last).selected, isTrue);
    expect(find.text('0 of 54 parshiyot'), findsOneWidget);

    await tester.tap(chips.first);
    await tester.pumpAndSettle();
    expect(find.text(en.earlierYear), findsOneWidget);
    expect(find.text(en.thisYear), findsNothing);
    // Vayera to Vezot HaBerakhah.
    expect(find.text('51 of 54 parshiyot'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^5786: 51 of 54 parshiyot complete')), findsOneWidget);
    // The map shows 5786 as it ended: nothing in it is still to come.
    expect(find.bySemanticsLabel('Bereshit: Not counted'), findsOneWidget);
    expect(find.bySemanticsLabel('Vayera: On time'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(r': (In progress|Upcoming)$')), findsNothing);
  });
}
