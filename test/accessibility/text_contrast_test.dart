import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/services/notifications.dart';
import 'package:shnayim_mikra/ui/widgets/progress_widgets.dart';

import '../helpers.dart';
import 'routes.dart';

/// Text contrast (WCAG 1.4.3) on every main screen and in every theme.
///
/// textContrastGuideline reads the colours from the rendered pixels around
/// each text and takes the most common dark and light ones. That only works
/// with the test font, whose glyphs are solid blocks of the text colour: the
/// thin strokes of the bundled fonts are mostly anti-aliased edge pixels, which
/// can outnumber the true text colour (a 16px "Wide" in 16:1 ink measured
/// 3.9:1). So, unlike screens_a11y_test.dart, this file never loads them. The
/// colour pairs themselves are checked in test/ui/palette_contrast_test.dart.
void main() {
  Future<void> expectReadableText(
    WidgetTester tester,
    String route, {
    AppSettings settings = a11ySettings,
    NotificationService? notifications,
  }) async {
    final handle = tester.ensureSemantics();
    await openRoute(tester, route, settings: settings, now: a11yMonday, notifications: notifications);
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  }

  for (final route in a11yRoutes) {
    testWidgets('text contrast: $route', (tester) => expectReadableText(tester, route));
  }

  for (final route in a11yOnboardingRoutes) {
    testWidgets('text contrast: $route', (tester) => expectReadableText(tester, route, settings: const AppSettings()));
  }

  testWidgets('text contrast: reminders, where they can be scheduled, with all of them on', (tester) async {
    await expectReadableText(tester, '/settings/reminders', settings: a11yRemindersOn, notifications: PhoneNotifications());
    expect(find.text('Daily reminder time'), findsOneWidget);
  });

  for (final theme in [AppThemeMode.dark, AppThemeMode.sepia, AppThemeMode.highContrastLight, AppThemeMode.highContrastDark]) {
    testWidgets('text contrast in the ${theme.name} theme', (tester) async {
      await expectReadableText(tester, '/today', settings: AppSettings(onboardingComplete: true, theme: theme));
    });
  }

  // The Torah map with a tile in every past state, and the week strip above
  // it. textContrastGuideline finds text by its node's label, and a tile's
  // label also names its state ("Noach: Made up"), as a day's names its
  // status and a book header's its count, so the guideline skips them; their
  // colours are checked here instead: a tile's name against its fill and its
  // icon against the fill as a graphic, a filled day's weekday and aliyot
  // against its fill, and each book header's count against the page.
  for (final theme in [AppThemeMode.light, AppThemeMode.sepia, AppThemeMode.highContrastDark]) {
    testWidgets('Torah map tiles, filled days and book counts are readable in the ${theme.name} theme',
        (tester) async {
      final handle = tester.ensureSemantics();
      tester.view.physicalSize = const Size(412, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = await pumpApp(
        tester,
        settings: AppSettings(onboardingComplete: true, theme: theme, joinDate: historyJoinDate),
        now: historyNow,
        progress: historyProgress(),
      );
      c.read(routerProvider).go('/progress');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.bySemanticsLabel(RegExp('^Genesis: ')));
      await tester.pumpAndSettle();

      double contrast(Color a, Color b) {
        final (la, lb) = (a.computeLuminance(), b.computeLuminance());
        return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
      }

      for (final label in [
        'Bereshit: On time',
        'Noach: After Shabbat — still counts',
        'Lech Lecha: Not completed',
        'Vayera: Made up',
        'Toldot: In progress',
        'Vayetzei: Upcoming',
      ]) {
        final tile = find.bySemanticsLabel(label);
        final ink = tester.widget<Ink>(find.descendant(of: tile, matching: find.byType(Ink)));
        final fill = (ink.decoration! as BoxDecoration).color!;
        final name = label.substring(0, label.indexOf(':'));
        final text = tester.widget<Text>(find.descendant(of: tile, matching: find.text(name)));
        expect(fill.a, 1, reason: '$label: text on a translucent fill');
        expect(contrast(text.style!.color!, fill), greaterThanOrEqualTo(4.5), reason: label);
        for (final icon in tester.widgetList<Icon>(find.descendant(of: tile, matching: find.byType(Icon)))) {
          expect(contrast(icon.color!, fill), greaterThanOrEqualTo(3), reason: '$label icon');
        }
      }

      // Today (Wednesday) on primaryContainer, Shabbat on the rest wash.
      final strip = find.byType(WeekStrip);
      final filled = tester.widgetList<Ink>(find.descendant(of: strip, matching: find.byType(Ink))).toList();
      expect(filled, hasLength(2));
      for (final ink in filled) {
        final fill = (ink.decoration! as BoxDecoration).color!;
        final texts = tester.widgetList<Text>(find.descendant(of: find.byWidget(ink), matching: find.byType(Text)));
        expect(texts, isNotEmpty);
        for (final text in texts) {
          expect(contrast(text.style!.color!, fill), greaterThanOrEqualTo(4.5), reason: '"${text.data}" on $fill');
        }
      }

      final page = Theme.of(tester.element(strip)).colorScheme.surface;
      for (final book in ['Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy']) {
        final count = tester.widget<Text>(
          find.descendant(of: find.bySemanticsLabel(RegExp('^$book: ')), matching: find.textContaining(' of ')),
        );
        expect(contrast(count.style!.color!, page), greaterThanOrEqualTo(4.5), reason: '$book count');
      }
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });
  }
}
