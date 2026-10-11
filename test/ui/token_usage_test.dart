import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikra/features/progress/domain/streak_engine.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/ui/theme/palette.dart';
import 'package:shnayim_mikra/ui/widgets/common.dart';
import 'package:shnayim_mikra/ui/widgets/progress_widgets.dart';

import '../helpers.dart';

/// Widgets that used to pick ad hoc or seeded colours now read the tokens.
void main() {
  for (final (mode, scheme, status) in [
    (AppThemeMode.light, Palettes.light, Palettes.statusLight),
    (AppThemeMode.highContrastDark, Palettes.hcDark, Palettes.statusHcDark),
  ]) {
    testWidgets('${mode.name}: week strip and status badge colours', (tester) async {
      await pumpApp(tester, settings: AppSettings(onboardingComplete: true, theme: mode));
      final context = tester.element(find.byType(Scaffold).first);

      Color? iconColor(DayDisplay d) => (d.icon(context) as Icon).color;
      // outlineVariant was about 1.5:1, too faint to read as a day at all.
      expect(iconColor(DayDisplay.upcoming), scheme.outline);
      expect(iconColor(DayDisplay.noReading), scheme.outline);
      expect(iconColor(DayDisplay.missed), status.neutral);
      expect(iconColor(DayDisplay.grace), status.grace);

      // A week still open after its Shabbat is gold ink; finishing late is
      // a quieter blue, so the two no longer share a colour.
      expect(WeekStatusBadge.color(context, WeekStatus.overdue), status.overdue);
      expect(WeekStatusBadge.color(context, WeekStatus.late), status.late);
      expect(status.overdue, isNot(status.late));
      // Restored is finished late too (§3.4); only on time is done's colour.
      expect(WeekStatusBadge.color(context, WeekStatus.restored), status.late);
      expect(WeekStatusBadge.color(context, WeekStatus.madeUp), status.late);
      expect(WeekStatusBadge.color(context, WeekStatus.onTime), status.done);
    });
  }

  for (final (mode, sefer) in [
    (AppThemeMode.light, Palettes.seferLight),
    (AppThemeMode.dark, Palettes.seferDark),
    (AppThemeMode.highContrastDark, Palettes.seferHcDark),
  ]) {
    testWidgets('${mode.name}: the rings are the two Mikra blues and the Targum gold on their track', (tester) async {
      // Rishon read all three ways: one arc in each ring.
      final rishon = WeekProgress(weekId: '5787:1')
          .withUnit(0, ReadingPass.mikra1, LocalDate(2026, 10, 5))
          .withUnit(0, ReadingPass.mikra2, LocalDate(2026, 10, 5))
          .withUnit(0, ReadingPass.targum, LocalDate(2026, 10, 5));
      await pumpThemed(
        tester,
        Center(child: ParshaRings(progress: rishon, aliyahWeights: const [31, 17, 26, 24, 4, 34, 10])),
        theme: mode,
      );
      final rings = find.descendant(of: find.byType(ParshaRings), matching: find.byType(CustomPaint)).first;
      expect(
        rings,
        paints
          // Three full tracks, then each ring's done arc in its own colour.
          ..circle(color: sefer.ringTrack)
          ..circle(color: sefer.ringTrack)
          ..circle(color: sefer.ringTrack)
          ..arc(color: sefer.ringMikra1)
          ..arc(color: sefer.ringMikra2)
          ..arc(color: sefer.ringTargum),
      );
      // Mikra 2 used to be Mikra 1 at 80% alpha, and the Targum tertiary.
      expect(sefer.ringMikra2, isNot(sefer.ringMikra1));
      expect(sefer.ringMikra2.a, 1);
    });
  }

  for (final (mode, scheme) in [
    (AppThemeMode.light, Palettes.light),
    (AppThemeMode.highContrastDark, Palettes.hcDark),
  ]) {
    testWidgets('${mode.name}: the reader\'s note on a verse without Rashi is gold-ink paper, not tertiary',
        (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = await pumpApp(
        tester,
        settings: AppSettings(onboardingComplete: true, theme: mode, secondReading: SecondReading.rashi),
        now: DateTime(2026, 10, 12, 10),
      );
      // Noach's Revi'i opens on 8:15, on which Rashi has no comment.
      c.read(routerProvider).go('/read/5787:2/3');
      await tester.pump();
      await tester.pump();
      for (var i = 0; i < 50 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      for (var step = 0; step < 2; step++) {
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }
      final note = find.textContaining('Rashi does not comment on this verse');
      expect(note, findsOneWidget);
      // A notice, as every page's are (§6.20).
      final notice = find.ancestor(of: note, matching: find.byType(NoticeBanner));
      final card = tester.widget<Card>(find.descendant(of: notice, matching: find.byType(Card)));
      expect(card.color, scheme.secondaryContainer);
      expect(tester.widget<Text>(note).style?.color, scheme.onSecondaryContainer);
      final icon = tester.widget<Icon>(find.descendant(of: notice, matching: find.byIcon(Icons.info_outline)));
      expect(icon.color, scheme.onSecondaryContainer);
    });
  }

  testWidgets('the demo notice is a gold-ink notice within the page, not a tertiary strip', (tester) async {
    final c = await pumpApp(tester);
    c.read(routerProvider).go('/community');
    await tester.pumpAndSettle();
    final notice = find.ancestor(of: find.textContaining('Demo mode'), matching: find.byType(NoticeBanner));
    final card = tester.widget<Card>(find.descendant(of: notice, matching: find.byType(Card)));
    expect(card.color, Palettes.light.secondaryContainer);
    final text = tester.widget<Text>(find.textContaining('Demo mode'));
    expect(text.style?.color, Palettes.light.onSecondaryContainer);
    expect(find.descendant(of: notice, matching: find.byIcon(Icons.info_outline)), findsOneWidget);
    // Within the gutters, as wide as the cards below it: never full-bleed.
    final cards = tester.getRect(find.byType(InfoCard).first);
    expect(tester.getRect(notice).left, cards.left);
    expect(tester.getRect(notice).right, cards.right);
  });
}
