import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/app/shell.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/ui/theme/app_theme.dart';
import 'package:shnayim_mikra/ui/widgets/app_mark.dart';

import '../helpers.dart';

/// docs/DESIGN_SYSTEM.md §6.9 and §6.10: a navigation bar on phones, and from
/// 600 dp a rail headed by the app's mark, joined by its name from 1200 dp.
void main() {
  setUpAll(loadBundledFonts);

  const phone = Size(412, 915);
  const tablet = Size(800, 1180);
  const desktop = Size(1366, 860);
  const hebrew = AppSettings(onboardingComplete: true, language: AppLanguage.hebrew);

  Future<void> open(
    WidgetTester tester,
    Size size, {
    AppSettings settings = const AppSettings(onboardingComplete: true),
    double textScale = 1,
  }) =>
      openRoute(tester, '/today', settings: settings, size: size, textScale: textScale, now: DateTime(2026, 10, 9, 11));

  final rail = find.byType(NavigationRail);
  Finder inRail(Finder finder) => find.descendant(of: rail, matching: finder);
  Finder inBar(Finder finder) => find.descendant(of: find.byType(NavigationBar), matching: finder);
  final mark = inRail(find.byType(AppMark));
  Finder destinationOf(String label) =>
      find.ancestor(of: inRail(find.text(label)), matching: find.byWidgetPredicate((w) => w is InkResponse)).first;

  BorderSide hairline(WidgetTester tester) {
    final sefer = SeferColors.of(tester.element(find.byType(Scaffold).first));
    return BorderSide(color: sefer.hairline, width: sefer.hairlineWidth);
  }

  /// The box that draws the hairline beside [finder]'s bar or rail.
  DecoratedBox edgeOf(WidgetTester tester, Finder finder) =>
      tester.widget<DecoratedBox>(find.ancestor(of: finder, matching: find.byType(DecoratedBox)).first);

  group('phone', () {
    testWidgets('a bar of five destinations; Progress echoes the rings', (tester) async {
      await open(tester, phone);
      expect(rail, findsNothing);
      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect([
        for (final d in bar.destinations.cast<NavigationDestination>())
          ((d.icon as Icon).icon, (d.selectedIcon! as Icon).icon, d.label),
      ], [
        (Icons.today_outlined, Icons.today, 'Today'),
        (Icons.menu_book_outlined, Icons.menu_book, 'Parsha'),
        (Icons.donut_large_outlined, Icons.donut_large, 'Progress'),
        (Icons.forum_outlined, Icons.forum, 'Community'),
        (Icons.settings_outlined, Icons.settings, 'Settings'),
      ]);
      // The selected tab is filled, the others outlined; no sparkle.
      expect(inBar(find.byIcon(Icons.today)), findsOneWidget);
      expect(inBar(find.byIcon(Icons.donut_large_outlined)), findsOneWidget);
      expect(find.byIcon(Icons.insights_outlined), findsNothing);
    });

    for (final mode in [AppThemeMode.light, AppThemeMode.highContrastDark]) {
      testWidgets('${mode.name}: 72 high, under a hairline of its own', (tester) async {
        await open(tester, phone, settings: AppSettings(onboardingComplete: true, theme: mode));
        final edge = hairline(tester);
        expect(edge.width, mode == AppThemeMode.highContrastDark ? 2 : 1);
        final box = edgeOf(tester, find.byType(NavigationBar));
        expect((box.decoration as BoxDecoration).border, Border(top: edge));
        // The hairline lies above the bar rather than over its top edge.
        expect(tester.getSize(find.byType(NavigationBar)).height, 72);
        expect(tester.getTopLeft(find.byType(NavigationBar)).dy - tester.getTopLeft(find.byWidget(box)).dy, edge.width);
      });
    }

    // Large text grows the labels only while the longest still fits its slot
    // on one line, and the bar grows with them: nothing spills over its top
    // hairline or below it, and no word breaks.
    for (final (window, scales) in [
      (phone, [1.0, 1.15, 1.3, 2.0]),
      (const Size(360, 800), [1.0, 1.3, 2.0]),
    ]) {
      for (final scale in scales) {
        for (final (name, settings) in [
          ('English', const AppSettings(onboardingComplete: true)),
          ('Hebrew', hebrew),
          ('OpenDyslexic', const AppSettings(onboardingComplete: true, uiFont: UiFont.openDyslexic)),
        ]) {
          testWidgets('${window.width.round()} dp, $name, text ×$scale: every label and indicator inside the bar',
              (tester) async {
            await open(tester, window, settings: settings, textScale: scale);
            final bar = tester.getRect(find.byType(NavigationBar));
            expect(bar.height, greaterThanOrEqualTo(72));
            expect(bar.bottom, window.height);
            final labels = tester.widgetList<Text>(inBar(find.byType(Text))).toList();
            expect(labels, hasLength(5));
            for (final label in labels) {
              final text = find.byWidget(label);
              final rect = tester.getRect(text);
              expect(bar.contains(rect.topLeft) && bar.contains(rect.bottomRight - const Offset(0.01, 0.01)), isTrue,
                  reason: '${label.data}: $rect in $bar');
              // One line: no word broken across two.
              final paragraph = tester.renderObject<RenderParagraph>(text);
              final lineHeight = paragraph.text.style!.fontSize! * paragraph.text.style!.height!;
              expect(rect.height, lessThan(paragraph.textScaler.scale(lineHeight) * 1.5),
                  reason: '${label.data} wraps');
            }
            for (final indicator in tester.widgetList(inBar(find.byType(NavigationIndicator)))) {
              final rect = tester.getRect(find.byWidget(indicator));
              expect(rect.top, greaterThanOrEqualTo(bar.top), reason: '$rect in $bar');
              expect(rect.bottom, lessThanOrEqualTo(bar.bottom));
            }
            expect(tester.takeException(), isNull);
          });
        }
      }
    }

    testWidgets('at 1× on a 360 dp phone, the bar is 72 high and its labels 12 sp', (tester) async {
      await open(tester, const Size(360, 800));
      expect(tester.getSize(find.byType(NavigationBar)).height, 72);
      final community = tester.renderObject<RenderParagraph>(inBar(find.text('Community')));
      expect(community.textScaler.scale(12), 12);
    });

    testWidgets('with motion reduced, the indicator moves at once', (tester) async {
      await open(tester, phone, settings: const AppSettings(onboardingComplete: true, reduceMotion: true));
      await tester.tap(inBar(find.text('Parsha')));
      await tester.pump();
      await tester.pump();
      final destination =
          find.ancestor(of: inBar(find.text('Parsha')), matching: find.byWidgetPredicate((w) => w is InkResponse));
      final indicator = tester.widget<NavigationIndicator>(
        find.descendant(of: destination.first, matching: find.byType(NavigationIndicator)),
      );
      expect(indicator.animation.value, 1);
    });

    testWidgets('the selected label is bold', (tester) async {
      await open(tester, phone);
      FontWeight? weight(String label) => tester.widget<Text>(inBar(find.text(label))).style?.fontWeight;
      expect(weight('Today'), FontWeight.w700);
      expect(weight('Parsha'), FontWeight.w500);

      await tester.tap(inBar(find.text('Parsha')));
      await tester.pumpAndSettle();
      expect(weight('Parsha'), FontWeight.w700);
      expect(weight('Today'), FontWeight.w500);
    });
  });

  group('compact rail', () {
    testWidgets('from 600 dp: the mark, announced as the app, on surface beside a hairline', (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester, tablet);
      expect(find.byType(NavigationBar), findsNothing);
      final navigation = tester.widget<NavigationRail>(rail);
      expect(navigation.extended, isFalse);
      expect(navigation.labelType, NavigationRailLabelType.all);

      expect(tester.getSize(mark), const Size(40, 40));
      expect(tester.getCenter(mark).dx, AppShell.railWidth / 2);
      expect(
        tester.getSemantics(find.descendant(of: mark, matching: find.byType(RawImage))),
        isSemantics(label: 'Shnayim Mikra', isImage: true, isHeader: false),
      );
      // Neither the old initials nor the wordmark.
      expect(find.text('SM'), findsNothing);
      expect(inRail(find.text('Shnayim Mikra')), findsNothing);

      // The hairline replaces the old divider.
      expect(find.byType(VerticalDivider), findsNothing);
      final edge = hairline(tester);
      expect((edgeOf(tester, rail).decoration as BoxDecoration).border, BorderDirectional(end: edge));
      expect(tester.getTopLeft(find.byWidget(edgeOf(tester, rail))).dx, 0);
      expect(tester.getTopRight(rail).dx + edge.width, tester.getTopRight(find.byWidget(edgeOf(tester, rail))).dx);
      handle.dispose();
    });

    testWidgets('is 80 wide in the bundled font', (tester) async {
      await open(tester, tablet);
      expect(tester.getSize(rail).width, AppShell.railWidth);
    });

    testWidgets("destinations keep Material's 64, which the framework's spacing fixes", (tester) async {
      await open(tester, tablet);
      for (final label in ['Today', 'Parsha', 'Progress', 'Community', 'Settings']) {
        expect(tester.getSize(destinationOf(label)).height, 64, reason: label);
      }
    });

    for (final mode in [AppThemeMode.light, AppThemeMode.highContrastDark]) {
      testWidgets('${mode.name}: keyboard focus on a destination is the bar\'s strong wash', (tester) async {
        FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
        addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
        await open(tester, tablet, settings: AppSettings(onboardingComplete: true, theme: mode));
        final parsha = destinationOf('Parsha');
        final scheme = Theme.of(tester.element(parsha)).colorScheme;
        final wash = scheme.onSurface.withValues(alpha: 0.32);
        expect(Theme.of(tester.element(parsha)).focusColor, wash);
        Focus.of(tester.element(find.descendant(of: parsha, matching: find.byType(Icon)).first)).requestFocus();
        await tester.pumpAndSettle();
        // The ink highlight stores its colour in bytes, so allow for rounding.
        bool isWash(Color c) => [
              (c.r, wash.r),
              (c.g, wash.g),
              (c.b, wash.b),
              (c.a, wash.a),
            ].every((pair) => (pair.$1 - pair.$2).abs() < 0.01);
        expect(rail, paints..something((_, arguments) => arguments.whereType<Paint>().any((p) => isWash(p.color))));
      });
    }

    // OpenDyslexic's "Community" is wider than the rail, so the rail grows to
    // fit it, but by the same amount whether or not it is bold.
    for (final uiFont in [UiFont.standard, UiFont.openDyslexic]) {
      testWidgets('${uiFont.name}: selecting a tab never changes its width, though the label turns bold',
          (tester) async {
        await open(tester, tablet, settings: AppSettings(onboardingComplete: true, uiFont: uiFont));
        final width = tester.getSize(rail).width;
        for (final label in ['Community', 'Progress', 'Settings', 'Parsha', 'Today']) {
          await tester.tap(inRail(find.text(label)).last);
          await tester.pumpAndSettle();
          expect(tester.getSize(rail).width, width, reason: label);
          expect(DefaultTextStyle.of(tester.element(inRail(find.text(label)).last)).style.fontWeight, FontWeight.w700);
        }
      });
    }

    testWidgets('each label is announced once', (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester, tablet);
      for (final label in ['Today', 'Parsha', 'Progress', 'Community', 'Settings']) {
        final node = tester.getSemantics(inRail(find.text(label)).last);
        expect(RegExp(label).allMatches(node.getSemanticsData().label).length, 1, reason: node.label);
      }
      handle.dispose();
    });

    testWidgets('a phone held sideways at 200% text scrolls the rail rather than overflow', (tester) async {
      const window = Size(915, 412);
      await open(tester, window, textScale: 2);
      expect(tester.takeException(), isNull);
      final settings = inRail(find.text('Settings')).last;
      await tester.scrollUntilVisible(settings, 40, scrollable: inRail(find.byType(Scrollable)));
      expect(tester.getRect(settings).bottom, lessThanOrEqualTo(window.height));
    });
  });

  group('extended rail', () {
    testWidgets('from 1200 dp: the mark, then the app name as a heading where the labels start', (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester, desktop);
      final navigation = tester.widget<NavigationRail>(rail);
      expect(navigation.extended, isTrue);
      expect(tester.getSize(rail).width, AppShell.extendedRailWidth);

      final wordmark = inRail(find.text('Shnayim Mikra'));
      expect(wordmark, findsOneWidget);
      expect(tester.widget<Text>(wordmark).style, SeferType.of(tester.element(wordmark)).wordmark);
      expect(tester.getSemantics(wordmark), isSemantics(label: 'Shnayim Mikra', isHeader: true));
      // The name is announced, so the mark beside it is not.
      final markImage = tester.widget<Image>(find.descendant(of: mark, matching: find.byType(Image)));
      expect(markImage.excludeFromSemantics, isTrue);

      // The mark starts at the icons' edge; the name, 12 after it, at the labels'.
      expect(tester.getSize(mark), const Size(40, 40));
      expect(tester.getTopLeft(mark).dx, tester.getTopLeft(inRail(find.byIcon(Icons.menu_book_outlined))).dx);
      expect(tester.getTopLeft(wordmark).dx, tester.getTopRight(mark).dx + 12);
      expect(tester.getTopLeft(wordmark).dx, tester.getTopLeft(inRail(find.text('Parsha'))).dx);
      // Centred on the app bar.
      expect(tester.getCenter(mark).dy, 32);
      expect(tester.getCenter(wordmark).dy, 32);
      handle.dispose();
    });

    testWidgets('destinations are 56 high, labels in labelLarge', (tester) async {
      await open(tester, desktop);
      final labelLarge = Theme.of(tester.element(rail)).textTheme.labelLarge!;
      for (final label in ['Today', 'Parsha', 'Progress', 'Community', 'Settings']) {
        expect(tester.getSize(destinationOf(label)).height, 56, reason: label);
        final text = inRail(find.text(label));
        final style = DefaultTextStyle.of(tester.element(text)).style.merge(tester.widget<Text>(text).style);
        expect((style.fontSize, style.height), (labelLarge.fontSize, labelLarge.height), reason: label);
      }
    });

    testWidgets('Hebrew: the rail at the right, the name in Frank Ruhl Libre to the left of the mark', (tester) async {
      await open(tester, desktop, settings: hebrew);
      final wordmark = inRail(find.text('שניים מקרא'));
      expect(tester.widget<Text>(wordmark).style!.fontFamily, 'FrankRuhlLibre');
      expect(tester.getTopRight(find.byWidget(edgeOf(tester, rail))).dx, desktop.width);
      expect(tester.getTopRight(wordmark).dx, tester.getTopLeft(mark).dx - 12);
      expect(tester.getTopRight(mark).dx, tester.getTopRight(inRail(find.byIcon(Icons.menu_book_outlined))).dx);
    });

    testWidgets('widening the window unfolds the name with the labels; narrowing folds both at once',
        (tester) async {
      await open(tester, tablet);
      tester.view.physicalSize = desktop;
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      // Half way, the header is no wider than the destinations, so the rail
      // widens smoothly with them.
      final width = tester.getSize(rail).width;
      expect(width, inExclusiveRange(AppShell.railWidth, AppShell.extendedRailWidth));
      expect(tester.getSize(destinationOf('Parsha')).width, width);
      expect(inRail(find.text('Shnayim Mikra')), findsOneWidget);
      await tester.pumpAndSettle();
      expect(tester.getSize(rail).width, AppShell.extendedRailWidth);

      tester.view.physicalSize = tablet;
      await tester.pump();
      expect(tester.getSize(rail).width, AppShell.railWidth);
      expect(inRail(find.text('Shnayim Mikra')), findsNothing);
      expect(tester.getCenter(mark).dx, AppShell.railWidth / 2);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  for (final (name, size) in [('tablet', tablet), ('desktop', desktop)]) {
    // The guidelines pass over targets at the window's edge, as the rail's
    // are, so their height is checked on its own above.
    testWidgets('$name: the shell meets the tap-target and label guidelines', (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester, size);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  }

  testWidgets('on Progress, its tab is selected and its rings filled', (tester) async {
    final container = await openRoute(tester, '/today', size: desktop);
    container.read(routerProvider).go('/progress');
    await tester.pumpAndSettle();
    expect(tester.widget<NavigationRail>(rail).selectedIndex, 2);
    expect(inRail(find.byIcon(Icons.donut_large)), findsOneWidget);
  });
}
