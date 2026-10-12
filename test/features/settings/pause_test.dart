import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/features/settings/widgets/pause_setting.dart';
import 'package:shnayim_mikra/l10n/app_localizations_en.dart';
import 'package:shnayim_mikra/ui/widgets/sefer_choice_chip.dart';

import '../../helpers.dart';

/// Extending a pause (docs/DESIGN_SYSTEM.md §9 Progress, 8, and Settings):
/// one dialog with one rule, wherever it is opened from.
void main() {
  final en = AppLocalizationsEn();

  group('pauseExtensions', () {
    ({LocalDate start, LocalDate end}) lasting(int days) {
      final start = LocalDate(2026, 11, 1);
      return (start: start, end: start.addDays(days - 1));
    }

    test('offers 1, 3, 7 or 14 days, as long as the pause then lasts 30 days in all', () {
      expect(pauseExtensions(lasting(1)), [1, 3, 7, 14]);
      expect(pauseExtensions(lasting(16)), [1, 3, 7, 14]);
      expect(pauseExtensions(lasting(17)), [1, 3, 7]);
      expect(pauseExtensions(lasting(23)), [1, 3, 7]);
      expect(pauseExtensions(lasting(24)), [1, 3]);
      expect(pauseExtensions(lasting(27)), [1, 3]);
      expect(pauseExtensions(lasting(28)), [1]);
      expect(pauseExtensions(lasting(29)), [1]);
      expect(pauseExtensions(lasting(30)), isEmpty);
    });

    test('counts from the first day of the pause, not from today', () {
      // Begun three days ago, to end in a fortnight: 18 days, and 12 more at
      // most, though a pause made today could reach further.
      final pause = (start: LocalDate(2026, 11, 8), end: LocalDate(2026, 11, 25));
      expect(pauseExtensions(pause), [1, 3, 7]);
    });
  });

  group('Extend', () {
    /// Wednesday 11 November 2026: paused from the 1st to the 9th, and again
    /// from the 9th, backdated, to Wednesday the 18th: one rest of 18 days.
    final twoPauses = [
      Pause(LocalDate(2026, 11, 1), LocalDate(2026, 11, 9), id: 'trip'),
      Pause(LocalDate(2026, 11, 9), LocalDate(2026, 11, 18), id: 'ill'),
    ];

    Future<ProviderContainer> open(WidgetTester tester, String route, {List<Pause>? pauses}) async {
      tester.view.physicalSize = const Size(412, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = await pumpApp(
        tester,
        settings: AppSettings(onboardingComplete: true, joinDate: historyJoinDate),
        now: historyNow,
        progress: historyProgress().copyWith(pauses: pauses ?? twoPauses),
      );
      c.read(routerProvider).go(route);
      await tester.pumpAndSettle();
      return c;
    }

    /// Opens the dialog that extends the pause, from Progress's Extend or
    /// from Settings' pause row.
    Future<void> openDialog(WidgetTester tester, {required bool fromSettings}) async {
      final button = fromSettings ? find.text(en.pauseAction) : find.widgetWithText(TextButton, en.extendPause);
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      await tester.tap(button);
      await tester.pumpAndSettle();
    }

    final dialog = find.byType(AlertDialog);

    /// The dialog's choices, the one chosen marked with a star.
    List<String> choices(WidgetTester tester) => [
          for (final chip in tester.widgetList<SeferChoiceChip>(
            find.descendant(of: dialog, matching: find.byType(SeferChoiceChip)),
          ))
            '${(chip.label as Text).data}${chip.selected ? '*' : ''}',
        ];

    /// The labels of the dialog's actions, in order.
    List<String> actions(WidgetTester tester) => [
          for (final button in tester.widgetList<ButtonStyleButton>(
            find.descendant(of: dialog, matching: find.bySubtype<ButtonStyleButton>()),
          ))
            (button.child as Text).data!,
        ];

    List<(LocalDate, LocalDate, String)> pauses(ProviderContainer c) => [
          for (final p in c.read(progressProvider).pauses)
            if (!p.deleted) (p.start, p.end, p.id),
        ];

    testWidgets('from Progress and from Settings offers the same choices and writes the same record', (tester) async {
      final results = <bool, List<String>>{};
      for (final fromSettings in [false, true]) {
        final c = await open(tester, fromSettings ? '/settings' : '/progress');
        await openDialog(tester, fromSettings: fromSettings);
        // Counted from the 1st, through the pause today's runs on from: 12
        // days more at most, and a week chosen.
        final offered = choices(tester);
        expect(offered, ['1 day', '3 days', '7 days*'], reason: fromSettings ? 'Settings' : 'Progress');
        final until = en.extendPauseUntil('Wednesday, November\u00A025');
        expect(find.descendant(of: dialog, matching: find.text(until)), findsOneWidget);
        expect(find.descendant(of: dialog, matching: find.text(en.extendPauseBy)), findsOneWidget);
        await tester.tap(find.descendant(of: dialog, matching: find.widgetWithText(FilledButton, en.extendPause)));
        await tester.pumpAndSettle();
        expect(find.text('Paused until Wednesday, November\u00A025.'), findsOneWidget, reason: 'the status message');
        // The pause covering today runs on to the new end: no third pause.
        results[fromSettings] = [...offered, for (final p in pauses(c)) '$p'];
        expect(pauses(c), [
          (LocalDate(2026, 11, 1), LocalDate(2026, 11, 9), 'trip'),
          (LocalDate(2026, 11, 9), LocalDate(2026, 11, 25), 'ill'),
        ]);
        expect(c.read(isPausedProvider), isTrue);
      }
      expect(results[true], results[false]);
    });

    testWidgets('chooses the most there is room for when a week is too much, and then says there is none', (tester) async {
      for (final fromSettings in [false, true]) {
        // 27 days, from the 1st to Friday the 27th: three more at most.
        final c = await open(
          tester,
          fromSettings ? '/settings' : '/progress',
          pauses: [Pause(LocalDate(2026, 11, 1), LocalDate(2026, 11, 27), id: 'long')],
        );
        await openDialog(tester, fromSettings: fromSettings);
        expect(choices(tester), ['1 day', '3 days*']);
        await tester.tap(find.descendant(of: dialog, matching: find.widgetWithText(FilledButton, en.extendPause)));
        await tester.pumpAndSettle();
        expect(pauses(c), [(LocalDate(2026, 11, 1), LocalDate(2026, 11, 30), 'long')]);
        // 30 days, the most a pause lasts.
        if (fromSettings) {
          await openDialog(tester, fromSettings: true);
          expect(find.descendant(of: dialog, matching: find.text(en.pauseAtMost)), findsOneWidget);
          expect(find.descendant(of: dialog, matching: find.text(en.extendPauseBy)), findsNothing);
          expect(choices(tester), isEmpty);
          expect(actions(tester), [en.resume, en.actionCancel]);
        } else {
          expect(find.widgetWithText(TextButton, en.extendPause), findsNothing);
          expect(find.widgetWithText(FilledButton, en.endPause), findsOneWidget);
        }
      }
    });

    testWidgets('Settings titles it until when, and offers End pause beside Cancel and Extend', (tester) async {
      await open(tester, '/settings');
      await openDialog(tester, fromSettings: true);
      expect(find.descendant(of: dialog, matching: findWords('Paused until Wednesday, November 18')), findsOneWidget);
      expect(find.descendant(of: dialog, matching: find.text(en.pauseManageBody)), findsOneWidget);
      expect(actions(tester), [en.resume, en.actionCancel, en.extendPause]);
      await tester.tap(find.widgetWithText(TextButton, en.actionCancel));
      await tester.pumpAndSettle();
      expect(dialog, findsNothing);

      // Progress has End pause beside its Extend, so its dialog only extends.
      await open(tester, '/progress');
      await openDialog(tester, fromSettings: false);
      expect(find.descendant(of: dialog, matching: find.text(en.extendPauseTitle)), findsOneWidget);
      expect(actions(tester), [en.actionCancel, en.extendPause]);
    });

    testWidgets('End pause ends it as of yesterday, from Progress and from Settings alike', (tester) async {
      for (final fromSettings in [false, true]) {
        final c = await open(tester, fromSettings ? '/settings' : '/progress');
        if (fromSettings) {
          await openDialog(tester, fromSettings: true);
          await tester.tap(find.descendant(of: dialog, matching: find.widgetWithText(TextButton, en.resume)));
        } else {
          final end = find.widgetWithText(FilledButton, en.endPause);
          await tester.ensureVisible(end);
          await tester.pumpAndSettle();
          await tester.tap(end);
        }
        await tester.pumpAndSettle();
        expect(c.read(isPausedProvider), isFalse);
        expect(pauses(c), [
          (LocalDate(2026, 11, 1), LocalDate(2026, 11, 9), 'trip'),
          (LocalDate(2026, 11, 9), LocalDate(2026, 11, 10), 'ill'),
        ]);
        expect(c.read(settingsProvider).pauseEndSeen, LocalDate(2026, 11, 10));
        expect(find.text(en.pauseEnded), findsOneWidget);
      }
    });
  });
}
