import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/ui/theme/app_theme.dart';
import 'package:shnayim_mikra/ui/theme/palette.dart';
import 'package:shnayim_mikra/ui/widgets/common.dart';
import 'package:shnayim_mikra/ui/widgets/progress_widgets.dart';

import '../helpers.dart';

const _ring = Color(0xFF112233);
const _gap = Color(0xFFFAF7F0);
const _r10 = BorderRadius.all(Radius.circular(10));

ThemeData _theme(AppThemeMode mode) =>
    AppTheme.build(mode: mode, uiFont: UiFont.standard, hebrewUi: false, reduceMotion: false);

/// Shows focus the way a keyboard user sees it, whatever the test platform.
void _keyboardMode() {
  FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
  addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
}

/// The ring a [SeferInkWell] paints around itself, or null.
BorderSide? _inkWellRing(WidgetTester tester, Finder inkWell) {
  final box = tester.widget<DecoratedBox>(find.descendant(of: inkWell, matching: find.byType(DecoratedBox)).first);
  final decoration = box.decoration;
  return decoration is ShapeDecoration ? (decoration.shape as RoundedRectangleBorder).side : null;
}

void main() {
  group('FocusRingBorder', () {
    const border = FocusRingBorder(borderRadius: _r10, ring: _ring, gap: _gap);

    test('keeps its ring through copyWith, scale and lerp', () {
      final withSide = border.copyWith(side: const BorderSide(width: 2));
      expect(withSide, isA<FocusRingBorder>());
      expect((withSide.ring, withSide.gap, withSide.side.width), (_ring, _gap, 2));
      expect(border.copyWith(borderRadius: BorderRadius.zero).ring, _ring);
      expect(border.scale(2).borderRadius, const BorderRadius.all(Radius.circular(20)));
      expect(border.scale(2).ring, _ring);

      // Gaining focus tweens towards the ring, which must survive the tween.
      // (Losing it tweens to the plain shape, whose lerpFrom wins.)
      const plain = RoundedRectangleBorder(borderRadius: BorderRadius.zero);
      for (final lerped in [
        ShapeBorder.lerp(plain, border, 0.5),
        ShapeBorder.lerp(null, border, 0.5),
        border.lerpTo(plain, 0.5),
      ]) {
        expect(lerped, isA<FocusRingBorder>().having((b) => b.ring, 'ring', _ring).having((b) => b.gap, 'gap', _gap));
      }
      final other = border.copyWith().lerpTo(const FocusRingBorder(ring: Colors.white, gap: Colors.black), 1)!;
      expect((other as FocusRingBorder).ring, Colors.white);
    });

    test('compares its colours', () {
      expect(border, const FocusRingBorder(borderRadius: _r10, ring: _ring, gap: _gap));
      expect(border.hashCode, const FocusRingBorder(borderRadius: _r10, ring: _ring, gap: _gap).hashCode);
      expect(border, isNot(const FocusRingBorder(borderRadius: _r10, ring: Colors.red, gap: _gap)));
      expect(border, isNot(const RoundedRectangleBorder(borderRadius: _r10)));
    });

    testWidgets('paints a gap and then a 3 px ring outside the shape', (tester) async {
      await tester.pumpWidget(const Center(
        child: SizedBox(
          width: 100,
          height: 48,
          child: DecoratedBox(decoration: ShapeDecoration(shape: border)),
        ),
      ));
      final rrect = RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 100, 48), const Radius.circular(10));
      expect(
        tester.renderObject(find.byType(DecoratedBox)),
        paints
          ..rrect(rrect: rrect.inflate(1), color: _gap, strokeWidth: 2, style: PaintingStyle.stroke)
          ..rrect(rrect: rrect.inflate(3.5), color: _ring, strokeWidth: 3, style: PaintingStyle.stroke),
      );
    });

    testWidgets('starts the gap past a border drawn outside the shape', (tester) async {
      await tester.pumpWidget(Center(
        child: SizedBox(
          width: 100,
          height: 36,
          child: DecoratedBox(
            decoration: ShapeDecoration(
              shape: border.copyWith(
                side: const BorderSide(width: 1.5, strokeAlign: BorderSide.strokeAlignOutside),
              ),
            ),
          ),
        ),
      ));
      final rrect = RRect.fromRectAndRadius(const Rect.fromLTWH(0, 0, 100, 36), const Radius.circular(10));
      expect(
        tester.renderObject(find.byType(DecoratedBox)),
        paints
          ..drrect(outer: rrect.inflate(1.5), inner: rrect)
          ..rrect(rrect: rrect.inflate(2.5), color: _gap, strokeWidth: 2)
          ..rrect(rrect: rrect.inflate(5), color: _ring, strokeWidth: 3),
      );
    });
  });

  for (final mode in [AppThemeMode.light, AppThemeMode.highContrastDark]) {
    testWidgets('${mode.name}: a focused FilledButton draws the ring outside its fill', (tester) async {
      _keyboardMode();
      final theme = _theme(mode);
      final sefer = theme.extension<SeferColors>()!;
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: Scaffold(body: Center(child: FilledButton(onPressed: () {}, child: const Text('Continue')))),
      ));
      OutlinedBorder? shape() =>
          tester.widget<Material>(find.descendant(of: find.byType(FilledButton), matching: find.byType(Material))).shape
              as OutlinedBorder?;
      expect(shape(), isNot(isA<FocusRingBorder>()));

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        shape(),
        isA<FocusRingBorder>()
            .having((b) => b.ring, 'ring', sefer.focus)
            .having((b) => b.gap, 'gap', sefer.focusGap)
            .having((b) => b.borderRadius, 'radius', _r10),
      );
      // Drawn at once: no shape tween that could blend the ring away.
      expect(
        find.byType(FilledButton),
        paints
          ..rrect(color: sefer.focusGap, strokeWidth: 2, style: PaintingStyle.stroke)
          ..rrect(color: sefer.focus, strokeWidth: 3, style: PaintingStyle.stroke),
      );
    });
  }

  testWidgets('a focused button in touch mode shows no ring', (tester) async {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTouch;
    addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
    await tester.pumpWidget(MaterialApp(
      theme: _theme(AppThemeMode.light),
      home: Scaffold(body: Center(child: FilledButton(autofocus: true, onPressed: () {}, child: const Text('OK')))),
    ));
    await tester.pump();
    final material =
        tester.widget<Material>(find.descendant(of: find.byType(FilledButton), matching: find.byType(Material)));
    expect(material.shape, isNot(isA<FocusRingBorder>()));
  });

  testWidgets('SeferInkWell rings itself only while keyboard focus is shown', (tester) async {
    final focus = FocusNode();
    addTearDown(focus.dispose);
    final theme = _theme(AppThemeMode.light);
    await tester.pumpWidget(MaterialApp(
      theme: theme,
      home: Scaffold(
        body: Center(
          child: SeferInkWell(
            focusNode: focus,
            borderRadius: _r10,
            onTap: () {},
            child: const SizedBox(width: 60, height: 60),
          ),
        ),
      ),
    ));
    final inkWell = find.byType(SeferInkWell);
    expect(_inkWellRing(tester, inkWell), isNull);

    // Tab switches to keyboard mode and moves focus.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(focus.hasFocus, isTrue);
    expect(
      _inkWellRing(tester, inkWell),
      BorderSide(color: Palettes.seferLight.focus, width: 3, strokeAlign: BorderSide.strokeAlignOutside),
    );
    // The ring replaces Material's focus tint.
    expect(tester.widget<InkWell>(find.byType(InkWell)).focusColor, Colors.transparent);

    // A touch elsewhere hides it, though focus stays.
    await tester.tapAt(const Offset(5, 5));
    await tester.pump();
    expect(focus.hasFocus, isTrue);
    expect(_inkWellRing(tester, inkWell), isNull);

    await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(_inkWellRing(tester, inkWell), isNotNull);
  });

  testWidgets('a tappable InfoCard leaves room for the ring around it', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: _theme(AppThemeMode.light),
      home: Scaffold(body: InfoCard(onTap: () {}, child: const Text('Streak'))),
    ));
    final card = tester.widget<Card>(find.byType(Card));
    expect(card.clipBehavior, Clip.none);
    final shape = _theme(AppThemeMode.light).cardTheme.shape! as RoundedRectangleBorder;
    expect(tester.widget<SeferInkWell>(find.byType(SeferInkWell)).borderRadius, shape.borderRadius);
  });

  group('the slider overlay', () {
    for (final mode in [AppThemeMode.light, AppThemeMode.highContrastLight]) {
      testWidgets('${mode.name}: rings the thumb while focused', (tester) async {
        _keyboardMode();
        final theme = _theme(mode);
        final sefer = theme.extension<SeferColors>()!;
        await tester.pumpWidget(MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Center(
              child: SizedBox(width: 300, child: Slider(value: 0.5, divisions: 4, onChanged: (_) {})),
            ),
          ),
        ));
        expect(theme.sliderTheme.overlayColor, isA<WidgetStateColor>());
        final overlay = theme.sliderTheme.overlayColor! as WidgetStateColor;
        expect(overlay.resolve({WidgetState.focused}), sefer.focus);
        expect(overlay.resolve({WidgetState.hovered}).a, lessThan(0.1));

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(
          find.byType(Slider),
          paints
            ..circle(radius: 11, color: sefer.focusGap, strokeWidth: 2, style: PaintingStyle.stroke)
            ..circle(radius: 13.5, color: sefer.focus, strokeWidth: 3, style: PaintingStyle.stroke),
        );
      });
    }
  });

  group('tabbing in the app', () {
    // A Friday in the week of Bereshit, so the strip has days to open.
    final now = DateTime(2026, 10, 9, 11);

    /// Presses Tab until focus lands inside [target]; returns the focused
    /// SeferInkWell.
    Future<Finder> tabInto(WidgetTester tester, Finder target) async {
      for (var i = 0; i < 120; i++) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final focused = FocusManager.instance.primaryFocus?.context;
        if (focused == null) continue;
        final inside = find.descendant(of: target, matching: find.byWidgetPredicate((w) => w is SeferInkWell));
        for (final element in inside.evaluate()) {
          var found = false;
          focused.visitAncestorElements((a) => !(found = a == element));
          if (found) return find.byWidget(element.widget);
        }
      }
      fail('Tab never reached $target');
    }

    testWidgets('a week-strip day shows a ring outside the day', (tester) async {
      _keyboardMode();
      final c = await pumpApp(tester, now: now);
      c.read(routerProvider).go('/today');
      await tester.pumpAndSettle();
      final day = await tabInto(tester, find.byType(WeekStrip));
      expect(tester.widget<SeferInkWell>(day).borderRadius, const BorderRadius.all(Radius.circular(10)));
      expect(_inkWellRing(tester, day)?.width, 3);
      expect(_inkWellRing(tester, day)?.strokeAlign, BorderSide.strokeAlignOutside);
    });

    testWidgets('a Torah-map tile shows a ring outside the tile', (tester) async {
      _keyboardMode();
      final c = await pumpApp(tester, now: now);
      c.read(routerProvider).go('/progress');
      await tester.pumpAndSettle();
      // The map's first row: Bereshit, Noach and Lech-Lecha.
      final tiles = find.ancestor(of: find.text('Noach'), matching: find.byType(IntrinsicHeight));
      final tile = await tabInto(tester, tiles);
      expect(tester.widget<SeferInkWell>(tile).borderRadius, const BorderRadius.all(Radius.circular(6)));
      expect(_inkWellRing(tester, tile)?.color, Palettes.seferLight.focus);
    });
  });
}
