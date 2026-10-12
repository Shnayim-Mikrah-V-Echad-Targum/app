import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/ui/theme/app_theme.dart';
import 'package:shnayim_mikra/ui/theme/palette.dart';
import 'package:shnayim_mikra/ui/widgets/common.dart';

/// docs/DESIGN_SYSTEM.md §5, §6.2, §6.3 and §6.19: the app bar, cards, menus,
/// sheets, dialogs, snack bars and tooltips. Paper on surface, full-strength
/// hairlines, no Material tint, and no elevation but the FAB's and menus'.
const _modes = [
  AppThemeMode.light,
  AppThemeMode.dark,
  AppThemeMode.sepia,
  AppThemeMode.highContrastLight,
  AppThemeMode.highContrastDark,
];

ThemeData _theme(AppThemeMode mode, {bool reduceMotion = false}) =>
    AppTheme.build(mode: mode, uiFont: UiFont.standard, hebrewUi: false, reduceMotion: reduceMotion);

BorderRadius _radius(ShapeBorder? shape) =>
    (shape! as RoundedRectangleBorder).borderRadius.resolve(TextDirection.ltr);

BorderSide _side(ShapeBorder? shape) => (shape! as RoundedRectangleBorder).side;

void main() {
  for (final mode in _modes) {
    group(mode.name, () {
      final theme = _theme(mode);
      final scheme = theme.colorScheme;
      final sefer = theme.extension<SeferColors>()!;
      final text = theme.textTheme;
      final hc = sefer.isHighContrast;
      // Floating paper is outlined in high contrast, where paper is surface.
      final floatingEdge = hc ? BorderSide(color: scheme.outline, width: 2) : BorderSide.none;

      test('app bar: 64 high on surface, and never a shadow', () {
        final bar = theme.appBarTheme;
        expect(bar.toolbarHeight, 64);
        expect(bar.backgroundColor, scheme.surface);
        expect(bar.elevation, 0);
        // Scrolled under, a hairline instead (ScrolledUnderRule, below).
        expect(bar.scrolledUnderElevation, 0);
        expect(bar.shadowColor, Colors.transparent);
        expect(bar.shape, hc ? Border(bottom: BorderSide(color: scheme.outline, width: 2)) : isNull);
        expect(bar.centerTitle, isFalse);
        expect(bar.titleTextStyle!.fontFamily, text.titleLarge!.fontFamily);
        expect(bar.titleTextStyle!.fontSize, text.titleLarge!.fontSize);
        expect(bar.titleTextStyle!.color, scheme.onSurface);
        for (final icons in [bar.iconTheme!, bar.actionsIconTheme!]) {
          expect((icons.size, icons.color), (24, scheme.onSurfaceVariant));
        }
      });

      test('cards: paper, radius 12, a full-strength hairline, and they clip', () {
        final card = theme.cardTheme;
        expect(card.color, sefer.paper);
        expect(card.elevation, 0);
        expect(card.clipBehavior, Clip.antiAlias);
        expect(_radius(card.shape), const BorderRadius.all(Radius.circular(12)));
        expect(_side(card.shape), BorderSide(color: sefer.hairline, width: hc ? 2 : 1));
        // The hairline used to be drawn at half strength.
        expect(_side(card.shape).color.a, 1);
        if (hc) expect(_side(card.shape).color, scheme.outline);
      });

      test('no Material tint on any surface', () {
        final popupMenu = theme.popupMenuTheme;
        final menuStyle = theme.menuTheme.style!;
        for (final (name, tint) in [
          ('app bar', theme.appBarTheme.surfaceTintColor),
          ('card', theme.cardTheme.surfaceTintColor),
          ('chip', theme.chipTheme.surfaceTintColor),
          ('popup menu', popupMenu.surfaceTintColor),
          ('menu', menuStyle.surfaceTintColor!.resolve({})),
          ('bottom sheet', theme.bottomSheetTheme.surfaceTintColor),
          ('dialog', theme.dialogTheme.surfaceTintColor),
          ('date picker', theme.datePickerTheme.surfaceTintColor),
          ('navigation bar', theme.navigationBarTheme.surfaceTintColor),
        ]) {
          expect(tint, Colors.transparent, reason: name);
        }
        expect(scheme.surfaceTint, Colors.transparent);
      });

      test('only the FAB and menus float, at 2 on the shadow token', () {
        final fab = theme.floatingActionButtonTheme;
        for (final e in [fab.elevation, fab.focusElevation, fab.hoverElevation, fab.highlightElevation]) {
          expect(e, 2);
        }
        // The one FAB, the forum's extended "New discussion", is radius 12
        // (§9 Community); focus swaps in the ring (focus_test.dart).
        final fabShape = WidgetStateProperty.resolveAs<ShapeBorder?>(fab.shape, {});
        expect(_side(fabShape), floatingEdge);
        expect(_radius(fabShape), const BorderRadius.all(Radius.circular(12)));
        expect(theme.popupMenuTheme.elevation, 2);
        expect(theme.popupMenuTheme.shadowColor, scheme.shadow);
        expect(theme.popupMenuTheme.color, sefer.paper);
        expect(theme.menuTheme.style!.elevation!.resolve({}), 2);
        expect(theme.menuTheme.style!.backgroundColor!.resolve({}), sefer.paper);
        expect(theme.shadowColor, scheme.shadow);
        for (final (name, elevation) in [
          ('app bar', theme.appBarTheme.elevation),
          ('card', theme.cardTheme.elevation),
          ('bottom sheet', theme.bottomSheetTheme.elevation),
          ('modal bottom sheet', theme.bottomSheetTheme.modalElevation),
          ('dialog', theme.dialogTheme.elevation),
          ('date picker', theme.datePickerTheme.elevation),
          ('time picker', theme.timePickerTheme.elevation),
          ('snack bar', theme.snackBarTheme.elevation),
          ('navigation bar', theme.navigationBarTheme.elevation),
        ]) {
          expect(elevation, 0, reason: name);
        }
      });

      test('progress is primary on the ring track', () {
        expect(theme.progressIndicatorTheme.color, scheme.primary);
        expect(theme.progressIndicatorTheme.linearTrackColor, sefer.ringTrack);
      });

      test('sheets: paper, 20 px top corners, a drag handle, 640 wide at most', () {
        final sheet = theme.bottomSheetTheme;
        expect(sheet.backgroundColor, sefer.paper);
        expect(sheet.modalBackgroundColor, sefer.paper);
        expect(_radius(sheet.shape), const BorderRadius.vertical(top: Radius.circular(20)));
        expect(_side(sheet.shape), floatingEdge);
        expect(sheet.showDragHandle, isTrue);
        expect(sheet.dragHandleSize, const Size(36, 4));
        // In full: the handle is also a dismiss button.
        expect(sheet.dragHandleColor, scheme.outline);
        expect(sheet.constraints, const BoxConstraints(maxWidth: 640));
      });

      test('dialogs: paper, radius 16, a serif title over quieter body text', () {
        final dialog = theme.dialogTheme;
        expect(dialog.backgroundColor, sefer.paper);
        expect(_radius(dialog.shape), const BorderRadius.all(Radius.circular(16)));
        expect(_side(dialog.shape), floatingEdge);
        expect(dialog.titleTextStyle!.fontFamily, text.titleLarge!.fontFamily);
        expect(dialog.titleTextStyle!.color, scheme.onSurface);
        expect(dialog.contentTextStyle!.fontSize, text.bodyMedium!.fontSize);
        expect(dialog.contentTextStyle!.color, scheme.onSurfaceVariant);
        for (final picker in [theme.datePickerTheme.backgroundColor, theme.timePickerTheme.backgroundColor]) {
          expect(picker, sefer.paper);
        }
        expect(_radius(theme.datePickerTheme.shape), const BorderRadius.all(Radius.circular(16)));
        expect(_radius(theme.timePickerTheme.shape), const BorderRadius.all(Radius.circular(16)));
      });

      test('snack bars float in the inverse colours, radius 10, 16 from the edges', () {
        final bar = theme.snackBarTheme;
        expect(bar.behavior, SnackBarBehavior.floating);
        expect(bar.backgroundColor, scheme.inverseSurface);
        expect(bar.contentTextStyle!.color, scheme.onInverseSurface);
        expect(bar.actionTextColor, scheme.inversePrimary);
        expect(_radius(bar.shape), const BorderRadius.all(Radius.circular(10)));
        expect(bar.insetPadding, const EdgeInsets.all(16));
      });

      test('tooltips: inverse colours, radius 6, small text, after 400 ms', () {
        final tooltip = theme.tooltipTheme;
        final decoration = tooltip.decoration! as BoxDecoration;
        expect(decoration.color, scheme.inverseSurface);
        expect(decoration.borderRadius, const BorderRadius.all(Radius.circular(6)));
        expect(tooltip.textStyle!.fontSize, text.bodySmall!.fontSize);
        expect(tooltip.textStyle!.color, scheme.onInverseSurface);
        expect(tooltip.waitDuration, const Duration(milliseconds: 400));
      });
    });
  }

  group('in a screen', () {
    Future<void> pump(WidgetTester tester, ThemeData theme, Widget body, {Size size = const Size(412, 800)}) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MaterialApp(theme: theme, home: body));
    }

    testWidgets('a card clips the ink of the list tile inside it', (tester) async {
      await pump(
        tester,
        _theme(AppThemeMode.light),
        Scaffold(body: Card(child: ListTile(title: const Text('Bereshit'), onTap: () {}))),
      );
      final material = tester.widget<Material>(find.descendant(of: find.byType(Card), matching: find.byType(Material)));
      expect(material.clipBehavior, Clip.antiAlias);
      expect(material.color, Palettes.seferLight.paper);
    });

    for (final (width, padding) in [(412.0, 20.0), (340.0, 16.0)]) {
      testWidgets('an InfoCard pads $padding at $width dp', (tester) async {
        await pump(
          tester,
          _theme(AppThemeMode.light),
          const Scaffold(body: InfoCard(child: Text('Streak'))),
          size: Size(width, 800),
        );
        final inner = tester.widget<Padding>(
          find.ancestor(of: find.text('Streak'), matching: find.byType(Padding)).first,
        );
        expect(inner.padding, EdgeInsets.all(padding));
        // It clips like any card; only a tappable one leaves room for its ring.
        expect(tester.widget<Card>(find.byType(Card)).clipBehavior, isNull);
      });
    }

    /// The rule [ScrolledUnderRule] paints over its app bar: where, and in
    /// what colour; null for none.
    (Rect, Color)? rule(WidgetTester tester) {
      final paint = tester.renderObject<RenderCustomPaint>(
        find.descendant(of: find.byType(ScrolledUnderRule), matching: find.byType(CustomPaint)).first,
      );
      final canvas = TestRecordingCanvas();
      paint.foregroundPainter!.paint(canvas, paint.size);
      final rects = [
        for (final call in canvas.invocations)
          if (call.invocation.memberName == #drawRect)
            (call.invocation.positionalArguments[0] as Rect, (call.invocation.positionalArguments[1] as Paint).color),
      ];
      expect(canvas.invocations.length, rects.length, reason: 'it paints nothing but the rule');
      expect(rects.length, lessThanOrEqualTo(1));
      return rects.firstOrNull;
    }

    Widget scrolling({AppBar? appBar}) => Scaffold(
          appBar: ScrolledUnderRule(appBar: appBar ?? AppBar(title: const Text('Progress'))),
          body: ListView(children: [for (var i = 0; i < 40; i++) ListTile(title: Text('Row $i'))]),
        );

    for (final mode in [AppThemeMode.light, AppThemeMode.highContrastDark]) {
      testWidgets('${mode.name}: content scrolled under the app bar brings a hairline, never a shadow or tint',
          (tester) async {
        final theme = _theme(mode);
        final scheme = theme.colorScheme;
        final sefer = theme.extension<SeferColors>()!;
        final hc = sefer.isHighContrast;
        await pump(tester, theme, scrolling());
        Material bar() =>
            tester.widget<Material>(find.descendant(of: find.byType(AppBar), matching: find.byType(Material)).first);
        expect(tester.getSize(find.byType(ScrolledUnderRule)).height, 64);
        expect(bar().elevation, 0);
        expect(rule(tester), isNull);

        await tester.drag(find.byType(ListView), const Offset(0, -300));
        await tester.pump();
        await tester.pump(Motion.short ~/ 2);
        // Fading in, in high contrast not at all: the bar's 2 px rule is
        // there all the time.
        final fading = rule(tester);
        if (hc) {
          expect(fading, isNull);
        } else {
          expect(fading!.$2.a, inExclusiveRange(0, 1));
        }

        await tester.pumpAndSettle();
        expect(bar().elevation, 0);
        expect(bar().color, scheme.surface);
        expect(bar().surfaceTintColor, Colors.transparent);
        // A full-width rule in the bar's last pixel row.
        final shown = rule(tester);
        if (hc) {
          expect(shown, isNull);
        } else {
          expect(shown!.$1, const Rect.fromLTWH(0, 63, 412, 1));
          expect(shown.$2, isSameColorAs(sefer.hairline));
        }
        if (hc) expect(bar().shape, Border(bottom: BorderSide(color: scheme.outline, width: 2)));

        // Back at the top, it fades out.
        await tester.drag(find.byType(ListView), const Offset(0, 600));
        await tester.pumpAndSettle();
        expect(rule(tester), isNull);
      });
    }

    testWidgets('with motion reduced, the rule is there at once', (tester) async {
      await pump(tester, _theme(AppThemeMode.light, reduceMotion: true), scrolling());
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pump();
      expect(rule(tester)?.$2, isSameColorAs(Palettes.seferLight.hairline));
    });

    testWidgets('it follows the app bar\'s predicate, and a new one clears it', (tester) async {
      final theme = _theme(AppThemeMode.light);
      bool never(ScrollNotification _) => false;
      await pump(tester, theme, scrolling(appBar: AppBar(notificationPredicate: never)));
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(rule(tester), isNull);

      await tester.pumpWidget(MaterialApp(theme: theme, home: scrolling()));
      await tester.drag(find.byType(ListView), const Offset(0, -100));
      await tester.pumpAndSettle();
      expect(rule(tester)?.$2, isSameColorAs(Palettes.seferLight.hairline));

      // The text now scrolls under something else, with its own rule.
      await tester.pumpWidget(MaterialApp(theme: theme, home: scrolling(appBar: AppBar(notificationPredicate: never))));
      await tester.pumpAndSettle();
      expect(rule(tester), isNull);
    });

    testWidgets('every page\'s app bar has the rule', (tester) async {
      await pump(
        tester,
        _theme(AppThemeMode.light),
        PageScaffold(
          titleText: 'Progress',
          body: PageBody(children: [for (var i = 0; i < 40; i++) ListTile(title: Text('Row $i'))]),
        ),
      );
      expect(find.descendant(of: find.byType(ScrolledUnderRule), matching: find.byType(AppBar)), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -300));
      await tester.pumpAndSettle();
      expect(rule(tester)?.$2, isSameColorAs(Palettes.seferLight.hairline));
    });
  });
}
