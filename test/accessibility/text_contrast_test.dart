import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/services/notifications.dart';
import 'package:shnayim_mikra/ui/theme/app_theme.dart';
import 'package:shnayim_mikra/ui/widgets/progress_widgets.dart';

import '../helpers.dart';
import 'every_theme.dart' show themes;
import 'routes.dart';

/// Text contrast (WCAG 1.4.3) where a page needs more than opening it: the
/// reminders as a phone schedules them, and the Torah map's tiles. Every
/// route in every theme is checked in semantics_invariants_test.dart and
/// semantics_invariants_pages_test.dart.
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

  testWidgets('text contrast: reminders, where they can be scheduled, with all of them on', (tester) async {
    await expectReadableText(tester, '/settings/reminders', settings: a11yRemindersOn, notifications: PhoneNotifications());
    expect(find.text('Daily reminder time'), findsOneWidget);
    expect(find.text('Move'), findsOneWidget);
  });

  // A switch that the device's own setting holds on is disabled, which the
  // guideline passes over, but the line under it says why: it is read at
  // the full contrast of a description, in every theme.
  for (final (route, title, features) in [
    ('/settings/accessibility', 'Reduce motion', const FakeAccessibilityFeatures(disableAnimations: true)),
    ('/settings/display', 'Bold text', const FakeAccessibilityFeatures(boldText: true)),
  ]) {
    testWidgets("text contrast: why $title's switch is held on by the device, in every theme", (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = features;
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      for (final theme in themes) {
        await openRoute(tester, route, settings: AppSettings(onboardingComplete: true, theme: theme), now: a11yMonday);
        final note = find.text('On in your device’s settings');
        await tester.ensureVisible(note);
        await tester.pumpAndSettle();
        final color = tester.renderObject<RenderParagraph>(note).text.style!.color!;
        final paper = SeferColors.of(tester.element(note)).paper;
        expect(color.a, 1, reason: '${theme.name}: not dimmed');
        expect(_contrast(color, paper), greaterThanOrEqualTo(4.5), reason: theme.name);
        // The title is dimmed with the switch, as an inactive control's.
        final heading = tester.renderObject<RenderParagraph>(find.text(title)).text.style!.color!;
        expect(heading.a, lessThan(0.5), reason: '${theme.name}: the title dimmed');
      }
    });
  }

  // The Torah map with a tile in every past state, and the week strip above
  // it. textContrastGuideline finds text by its node's label, and a tile's
  // label also names its state ("Vayera: Made up later"), as a day's names its
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

      _expectReadableTiles(tester, [
        'Bereshit: On time',
        'Noach: After Shabbat — still counts',
        'Lech Lecha: Not completed',
        'Vayera: Made up later',
        'Toldot: In progress',
        'Vayetze: Upcoming',
      ]);

      // Today (Wednesday) on primaryContainer, Shabbat on the rest wash.
      final strip = find.byType(WeekStrip);
      final filled = tester.widgetList<Ink>(find.descendant(of: strip, matching: find.byType(Ink))).toList();
      expect(filled, hasLength(2));
      for (final ink in filled) {
        final fill = (ink.decoration! as BoxDecoration).color!;
        final texts = tester.widgetList<Text>(find.descendant(of: find.byWidget(ink), matching: find.byType(Text)));
        expect(texts, isNotEmpty);
        for (final text in texts) {
          expect(_contrast(text.style!.color!, fill), greaterThanOrEqualTo(4.5), reason: '"${text.data}" on $fill');
        }
      }

      final page = Theme.of(tester.element(strip)).colorScheme.surface;
      for (final book in ['Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy']) {
        final count = tester.widget<Text>(
          find.descendant(of: find.bySemanticsLabel(RegExp('^$book: ')), matching: find.textContaining(' of ')),
        );
        expect(_contrast(count.style!.color!, page), greaterThanOrEqualTo(4.5), reason: '$book count');
      }
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      handle.dispose();
    });

    // The two states of a parsha missed and then finished with the next: the
    // one the reader has done, and the one still open to them.
    testWidgets('tiles finished with the next parsha, or yet to be, are readable in the ${theme.name} theme',
        (tester) async {
      tester.view.physicalSize = const Size(412, 2600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = await pumpApp(
        tester,
        settings: AppSettings(onboardingComplete: true, theme: theme, joinDate: historyJoinDate),
        now: rescueNow,
        progress: rescueProgress(),
      );
      c.read(routerProvider).go('/progress');
      await tester.pumpAndSettle();
      // Exodus is the book being read; Genesis opens from its header.
      await tester.ensureVisible(find.bySemanticsLabel(RegExp('^Genesis: ')));
      await tester.pumpAndSettle();
      await tester.tap(find.bySemanticsLabel(RegExp('^Genesis: ')));
      await tester.pumpAndSettle();
      _expectReadableTiles(tester, [
        'Noach: Finished with the next parsha',
        'Shemot: Can still be finished with the next parsha',
      ]);
    });
  }
}

/// Each Torah-map tile [labels] names: its name at least 4.5:1 against its
/// fill, which is solid, and its icon at least 3:1, as a graphic.
void _expectReadableTiles(WidgetTester tester, List<String> labels) {
  for (final label in labels) {
    final tile = find.bySemanticsLabel(label);
    expect(tile, findsOneWidget, reason: label);
    final ink = tester.widget<Ink>(find.descendant(of: tile, matching: find.byType(Ink)));
    final fill = (ink.decoration! as BoxDecoration).color!;
    final name = label.substring(0, label.indexOf(':'));
    final text = tester.widget<Text>(find.descendant(of: tile, matching: find.text(name)));
    expect(fill.a, 1, reason: '$label: text on a translucent fill');
    expect(_contrast(text.style!.color!, fill), greaterThanOrEqualTo(4.5), reason: label);
    for (final icon in tester.widgetList<Icon>(find.descendant(of: tile, matching: find.byType(Icon)))) {
      expect(_contrast(icon.color!, fill), greaterThanOrEqualTo(3), reason: '$label icon');
    }
  }
}

double _contrast(Color a, Color b) {
  final (la, lb) = (a.computeLuminance(), b.computeLuminance());
  return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
}
