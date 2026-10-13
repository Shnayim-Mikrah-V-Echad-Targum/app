import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/ui/theme/palette.dart';
import 'package:shnayim_mikra/ui/widgets/fallbacks.dart';
import 'package:shnayim_mikra/ui/widgets/ornaments.dart';

import '../helpers.dart';

void main() {
  const message = 'Couldn’t reach the server. Check your connection and try again.';
  final retry = find.widgetWithText(FilledButton, 'Try again');

  group('ErrorMessage', () {
    testWidgets('says why under a divider, and tries again when asked', (tester) async {
      var retries = 0;
      await pumpThemed(tester, ErrorMessage(message: message, onRetry: () => retries++));
      expect(find.byType(SeferDivider), findsOneWidget);
      expect(find.text(message), findsOneWidget);
      expect(find.descendant(of: retry, matching: find.byIcon(Icons.refresh)), findsOneWidget);
      expect(find.byType(Scrollable), findsNothing, reason: 'it sits in the page that shows it');
      await tester.tap(retry);
      expect(retries, 1);
    });

    testWidgets('while it retries, spins in place of its icon, and stays enabled but does nothing', (tester) async {
      var retries = 0;
      await pumpThemed(tester, ErrorMessage(message: message, onRetry: () => retries++, retrying: true));
      expect(find.descendant(of: retry, matching: find.byType(CircularProgressIndicator)), findsOneWidget);
      expect(find.descendant(of: retry, matching: find.byIcon(Icons.refresh)), findsNothing);
      expect(tester.widget<FilledButton>(retry).enabled, isTrue, reason: 'so that it keeps the keyboard focus');
      await tester.tap(retry);
      expect(retries, 0);
    });
  });

  group('tried again and failing again', () {
    for (final announces in [true, false]) {
      testWidgets(
          'says why again, ${announces ? 'announced' : 'a new live region each time, where nothing is announced'}',
          (tester) async {
        tester.platformDispatcher.accessibilityFeaturesTestValue = FakeAccessibilityFeatures(supportsAnnounce: announces);
        addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
        final semantics = tester.ensureSemantics();
        Future<void> pump({required bool retrying}) =>
            pumpThemed(tester, ErrorMessage(message: message, onRetry: () {}, retrying: retrying));
        int? liveRegion() {
          final node = tester.getSemantics(find.text(message));
          return node.flagsCollection.isLiveRegion ? node.id : null;
        }

        await pump(retrying: false);
        await pump(retrying: true);
        expect(tester.takeAnnouncements(), isEmpty, reason: 'nothing said until the outcome');
        expect(liveRegion(), isNull);

        // Failed again: the page looks just as it did, and the button keeps
        // the focus, so the message is said again.
        await pump(retrying: false);
        expect([for (final a in tester.takeAnnouncements()) a.message], announces ? [message] : isEmpty);
        final first = liveRegion();
        expect(first, announces ? isNull : isNotNull);

        await pump(retrying: true);
        await pump(retrying: false);
        expect([for (final a in tester.takeAnnouncements()) a.message], announces ? [message] : isEmpty);
        if (!announces) expect(liveRegion(), allOf(isNotNull, isNot(first)), reason: 'a live region new to the screen reader');
        semantics.dispose();
      });
    }

    testWidgets('as a whole page says why again too', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(supportsAnnounce: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      Future<void> pump({required bool retrying}) =>
          pumpThemed(tester, ErrorState(message: message, onRetry: () {}, retrying: retrying));
      await pump(retrying: true);
      await pump(retrying: false);
      expect([for (final a in tester.takeAnnouncements()) a.message], [message]);
    });
  });

  group('ErrorState', () {
    testWidgets('can be pulled to refresh, and offers Try again before any other action', (tester) async {
      var retries = 0;
      await pumpThemed(
        tester,
        ErrorState(
          message: message,
          onRetry: () => retries++,
          actions: [TextButton(onPressed: () {}, child: const Text('All forums'))],
        ),
      );
      final scrollable = tester.widget<Scrollable>(find.byType(Scrollable));
      expect(scrollable.physics, isA<AlwaysScrollableScrollPhysics>());
      expect(tester.getTopLeft(retry).dx, lessThan(tester.getTopLeft(find.text('All forums')).dx));
      await tester.tap(retry);
      expect(retries, 1);
    });
  });

  group('AppErrorPanel', () {
    const english = 'Something on this page didn’t load.';
    const hebrew = 'חלק מהדף לא נטען.';

    /// [child], within which a widget fails to build, in a release build.
    Future<void> pumpFailing(
      WidgetTester tester,
      Widget Function(Widget broken) child, {
      bool hebrew = false,
      AppThemeMode theme = AppThemeMode.light,
      double textScale = 1,
    }) async {
      final builder = ErrorWidget.builder;
      AppErrorPanel.install(debug: false);
      // Put back before the test ends, as the binding checks.
      try {
        await pumpThemed(tester, child(const _Fails()), hebrew: hebrew, theme: theme, textScale: textScale);
      } finally {
        ErrorWidget.builder = builder;
      }
      expect(tester.takeException(), isA<StateError>());
    }

    Widget Function(Widget) slot(double width, double height) =>
        (broken) => Center(child: SizedBox(width: width, height: height, child: broken));

    Color paper(WidgetTester tester) => tester
        .widget<ColoredBox>(find.descendant(of: find.byType(AppErrorPanel), matching: find.byType(ColoredBox)))
        .color;

    for (final (inHebrew, text) in [(false, english), (true, hebrew)]) {
      testWidgets('stands calmly for a widget that fails, in ${inHebrew ? 'Hebrew' : 'English'}', (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpFailing(tester, slot(300, 120), hebrew: inHebrew);
        expect(find.byType(AppErrorPanel), findsOneWidget);
        expect(find.byType(ErrorWidget), findsNothing, reason: 'no grey box');
        expect(find.text(text), findsOneWidget);
        expect(tester.getCenter(find.text(text)), tester.getCenter(find.byType(AppErrorPanel)));
        expect(tester.widget<Text>(find.text(text)).textDirection, inHebrew ? TextDirection.rtl : TextDirection.ltr);
        // Read once, as the sentence, in its own direction.
        expect(
          tester.getSemantics(find.byType(AppErrorPanel)),
          isSemantics(label: text, textDirection: inHebrew ? TextDirection.rtl : TextDirection.ltr),
        );
        expect(find.bySemanticsLabel(text), findsOneWidget);
        semantics.dispose();
      });
    }

    for (final (width, height) in [(100.0, 120.0), (300.0, 40.0)]) {
      testWidgets('where the line has no room ($width × $height), is only the page’s paper, said all the same',
          (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpFailing(tester, slot(width, height));
        expect(find.text(english), findsNothing);
        expect(tester.getSize(find.byType(AppErrorPanel)), Size(width, height));
        expect(paper(tester), Palettes.light.surface);
        expect(find.bySemanticsLabel(english), findsOneWidget);
        semantics.dispose();
      });
    }

    testWidgets('in a list, is as tall as its line and 12 either side', (tester) async {
      await pumpFailing(tester, (broken) => ListView(children: [broken]));
      expect(tester.getSize(find.byType(AppErrorPanel)), const Size(800, 48));
      expect(find.text(english), findsOneWidget);
    });

    testWidgets('at twice the text size, ends in an ellipsis rather than overflow its slot', (tester) async {
      await pumpFailing(tester, slot(200, 60), textScale: 2);
      final text = tester.widget<Text>(find.text(english));
      expect(text.maxLines, 1, reason: 'one 48-high line fits in 60');
      expect(text.overflow, TextOverflow.ellipsis);
      expect(tester.getSize(find.text(english)).height, lessThanOrEqualTo(60));
    });

    for (final theme in [AppThemeMode.dark, AppThemeMode.sepia, AppThemeMode.highContrastDark]) {
      testWidgets('takes the paper and ink of the app’s theme (${theme.name})', (tester) async {
        await pumpFailing(tester, slot(300, 120), theme: theme);
        final scheme = Theme.of(tester.element(find.byType(AppErrorPanel))).colorScheme;
        expect(paper(tester), scheme.surface);
        expect(tester.widget<Text>(find.text(english)).style?.color, scheme.onSurface);
      });
    }

    testWidgets('is of a piece with the card it lies on', (tester) async {
      await pumpFailing(tester, (broken) => Card(child: SizedBox(width: 300, height: 120, child: broken)));
      expect(paper(tester), SeferColors.of(tester.element(find.byType(AppErrorPanel))).paper);
    });

    testWidgets('on a surface of the other brightness, writes in the theme’s surface', (tester) async {
      await pumpFailing(
        tester,
        (broken) => Material(color: Palettes.light.primary, child: SizedBox(width: 300, height: 120, child: broken)),
      );
      expect(paper(tester), Palettes.light.primary);
      expect(tester.widget<Text>(find.text(english)).style?.color, Palettes.light.surface);
    });

    for (final brightness in Brightness.values) {
      testWidgets('above the app’s theme, takes the device’s light or dark paper (${brightness.name})',
          (tester) async {
        tester.platformDispatcher.platformBrightnessTestValue = brightness;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        final builder = ErrorWidget.builder;
        AppErrorPanel.install(debug: false);
        try {
          // No theme, no localizations, no directionality: only the view.
          await tester.pumpWidget(const _Fails());
        } finally {
          ErrorWidget.builder = builder;
        }
        expect(tester.takeException(), isA<StateError>());
        final scheme = brightness == Brightness.dark ? Palettes.dark : Palettes.light;
        expect(paper(tester), scheme.surface);
        expect(tester.widget<Text>(find.text(english)).style?.color, scheme.onSurface);
      });
    }

    testWidgets('leaves a debug build its red screen', (tester) async {
      final builder = ErrorWidget.builder;
      AppErrorPanel.install(debug: true);
      expect(ErrorWidget.builder, same(builder));
    });
  });
}

/// A widget that fails to build.
class _Fails extends StatelessWidget {
  const _Fails();

  @override
  Widget build(BuildContext context) => throw StateError('broken');
}
