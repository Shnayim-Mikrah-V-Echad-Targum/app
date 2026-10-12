import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/features/community/data/models.dart';
import 'package:shnayim_mikra/features/community/ui/thread_screen.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/l10n/app_localizations.dart';
import 'package:shnayim_mikra/ui/theme/app_theme.dart';
import 'package:shnayim_mikra/ui/theme/palette.dart';
import 'package:shnayim_mikra/ui/widgets/common.dart';
import 'package:shnayim_mikra/ui/widgets/paper_group.dart';
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

  // §6.20: the banner's action is primary where that meets AA on the banner,
  // with the usual ring; otherwise it is in the banner's own ink, and so is
  // its ring. One ring either way.
  for (final legible in [true, false]) {
    testWidgets('a NoticeBanner action ${legible ? 'in primary' : 'in the banner ink'} takes one focus ring',
        (tester) async {
      _keyboardMode();
      final light = _theme(AppThemeMode.light);
      // A banner the colour of primary leaves primary unreadable on it.
      final theme = legible
          ? light
          : light.copyWith(colorScheme: light.colorScheme.copyWith(secondaryContainer: light.colorScheme.primary));
      final scheme = theme.colorScheme;
      final sefer = theme.extension<SeferColors>()!;
      final ink = legible ? scheme.primary : scheme.onSecondaryContainer;
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        home: Scaffold(
          body: NoticeBanner(
            icon: Icons.info_outline,
            text: 'Notice',
            action: TextButton(onPressed: () {}, child: const Text('Open')),
          ),
        ),
      ));
      Material material() =>
          tester.widget<Material>(find.descendant(of: find.byType(TextButton), matching: find.byType(Material)));
      expect(material().textStyle?.color, ink);
      expect(material().shape, isNot(isA<FocusRingBorder>()));

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(
        material().shape,
        isA<FocusRingBorder>()
            .having((b) => b.ring, 'ring', legible ? sefer.focus : ink)
            .having((b) => b.gap, 'gap', sefer.focusGap)
            .having((b) => b.side, 'side', BorderSide.none)
            .having((b) => b.borderRadius, 'radius', _r10),
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

  group('a switch between keyboard and touch', () {
    /// The app's shell around [home]: FocusHighlightScope sits in its builder.
    Widget app(Widget home) => MaterialApp(
          theme: _theme(AppThemeMode.light),
          builder: (context, child) => FocusHighlightScope(child: child!),
          home: Scaffold(body: Center(child: home)),
        );

    OutlinedBorder? shapeOf(WidgetTester tester, Finder control) =>
        tester.widget<Material>(find.descendant(of: control, matching: find.byType(Material)).first).shape
            as OutlinedBorder?;

    testWidgets('a button that keeps its focus drops its ring on a touch, and gets it back on a key',
        (tester) async {
      final focus = FocusNode();
      addTearDown(focus.dispose);
      await tester.pumpWidget(app(FilledButton(focusNode: focus, onPressed: () {}, child: const Text('Read'))));
      final button = find.byType(FilledButton);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(focus.hasFocus, isTrue);
      expect(shapeOf(tester, button), isA<FocusRingBorder>());

      // Touching the page elsewhere switches to touch mode; focus stays.
      await tester.tapAt(const Offset(5, 5));
      await tester.pump();
      expect(focus.hasFocus, isTrue);
      expect(shapeOf(tester, button), isNot(isA<FocusRingBorder>()));
      expect(find.byType(FilledButton), isNot(paints..rrect(strokeWidth: 3, style: PaintingStyle.stroke)));

      await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(shapeOf(tester, button), isA<FocusRingBorder>());
    });

    testWidgets('a button focused by touch gets its ring at the first key press', (tester) async {
      await tester.pumpWidget(app(FilledButton(autofocus: true, onPressed: () {}, child: const Text('Read'))));
      await tester.tapAt(const Offset(5, 5));
      await tester.pump();
      final button = find.byType(FilledButton);
      expect(shapeOf(tester, button), isNot(isA<FocusRingBorder>()));

      await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();
      expect(shapeOf(tester, button), isA<FocusRingBorder>());
    });

    test('records the mode in the theme', () {
      const keyboard = FocusHighlight(keyboard: true);
      const touch = FocusHighlight(keyboard: false);
      expect(keyboard, isNot(touch));
      expect(keyboard.copyWith(keyboard: false), touch);
      expect(keyboard.lerp(touch, 0.4), keyboard);
      expect(keyboard.lerp(touch, 0.6), touch);
    });
  });

  testWidgets('the FAB takes the focus ring, radius 12, while keyboard focus is shown', (tester) async {
    _keyboardMode();
    final theme = _theme(AppThemeMode.light);
    final sefer = theme.extension<SeferColors>()!;
    await tester.pumpWidget(MaterialApp(
      theme: theme,
      home: Scaffold(
        body: const SizedBox.expand(),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {},
          icon: const Icon(Icons.add),
          label: const Text('New discussion'),
        ),
      ),
    ));
    ShapeBorder? shape() => tester
        .widget<Material>(find.descendant(of: find.byType(FloatingActionButton), matching: find.byType(Material)))
        .shape;
    const r12 = BorderRadius.all(Radius.circular(12));
    expect(shape(), const RoundedRectangleBorder(borderRadius: r12));

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(shape(), FocusRingBorder(borderRadius: r12, ring: sefer.focus, gap: sefer.focusGap));
    expect(
      find.byType(FloatingActionButton),
      paints
        ..rrect(color: sefer.focusGap, strokeWidth: 2, style: PaintingStyle.stroke)
        ..rrect(color: sefer.focus, strokeWidth: 3, style: PaintingStyle.stroke),
    );
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

  testWidgets('SeferInkWell leaves the ring to a focused control inside it', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: _theme(AppThemeMode.light),
      home: Scaffold(
        body: PaperGroup(children: [
          PaperRow(
            icon: Icons.menu_book_outlined,
            title: 'Rishon',
            onTap: () {},
            trailing: IconButton(onPressed: () {}, tooltip: 'More', icon: const Icon(Icons.more_vert)),
          ),
        ]),
      ),
    ));
    final row = find.byType(SeferInkWell);

    // Tab reaches the row first: it is ringed.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_inkWellRing(tester, row), isNotNull);

    // Then its menu button, which rings itself; the row, which still holds
    // focus through it, drops its ring rather than show a second one.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final button = find.byType(IconButton);
    expect(Focus.of(tester.element(find.byIcon(Icons.more_vert))).hasPrimaryFocus, isTrue);
    expect(_inkWellRing(tester, row), isNull);
    expect(
      find.descendant(of: button, matching: find.byWidgetPredicate((w) => w is Material && w.shape is FocusRingBorder)),
      findsOneWidget,
    );

    // And back to the row.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pump();
    expect(_inkWellRing(tester, row), isNotNull);
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

  group('the navigation bar and rail ring the focused indicator', () {
    /// The ring that [icon]'s IndicatorFocusRing paints, or null.
    CustomPainter? ringOf(WidgetTester tester, Finder icon) =>
        tester.widget<CustomPaint>(find.ancestor(of: icon, matching: find.byType(CustomPaint)).first).foregroundPainter;

    // Parsha's icon, which is not the selected tab's.
    final parsha = find.descendant(
      of: find.byWidgetPredicate((w) => w is NavigationBar || w is NavigationRail),
      matching: find.byIcon(Icons.menu_book_outlined),
    );

    for (final (name, size, indicator, radius) in [
      ('a bar destination', const Size(412, 915), const Size(64, 32), 16.0),
      ('a rail destination', const Size(1366, 860), const Size(56, 32), 12.0),
    ]) {
      for (final mode in [AppThemeMode.light, AppThemeMode.highContrastDark]) {
        testWidgets('${mode.name}: $name, from the keyboard', (tester) async {
          _keyboardMode();
          await openRoute(
            tester,
            '/today',
            size: size,
            now: DateTime(2026, 10, 9, 11),
            settings: AppSettings(onboardingComplete: true, theme: mode),
          );
          final sefer = SeferColors.of(tester.element(find.byType(Scaffold).first));
          expect(ringOf(tester, parsha), isNull);

          Focus.of(tester.element(parsha)).requestFocus();
          // Focus moves in a microtask, which may come after the next frame.
          await tester.pumpAndSettle();
          // FocusRingBorder's gap and ring, around the indicator centred on
          // the icon.
          final shape = RRect.fromRectAndRadius(
            Rect.fromCenter(
              center: tester.getSize(parsha).center(Offset.zero),
              width: indicator.width,
              height: indicator.height,
            ),
            Radius.circular(radius),
          );
          expect(
            find.ancestor(of: parsha, matching: find.byType(CustomPaint)).first,
            paints
              ..rrect(rrect: shape.inflate(1), color: sefer.focusGap, strokeWidth: 2, style: PaintingStyle.stroke)
              ..rrect(rrect: shape.inflate(3.5), color: sefer.focus, strokeWidth: 3, style: PaintingStyle.stroke),
          );
          // With no wash under it: the colour the ink well would wash in.
          final inkWell = tester.widget<InkResponse>(
            find.ancestor(of: parsha, matching: find.byWidgetPredicate((w) => w is InkResponse)).first,
          );
          final wash = inkWell.overlayColor?.resolve({WidgetState.focused}) ??
              inkWell.focusColor ??
              Theme.of(tester.element(parsha)).focusColor;
          expect(wash, Colors.transparent);

          // A switch to touch drops the ring, though the focus stays.
          FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTouch;
          await tester.pump();
          expect(Focus.of(tester.element(parsha)).hasPrimaryFocus, isTrue);
          expect(ringOf(tester, parsha), isNull);
        });
      }

      testWidgets('$name, the selected one, from the keyboard', (tester) async {
        _keyboardMode();
        await openRoute(tester, '/today', size: size, now: DateTime(2026, 10, 9, 11));
        final sefer = SeferColors.of(tester.element(find.byType(Scaffold).first));
        // Today's selected icon: an IndicatorFocusRing of its own.
        final today = find.descendant(
          of: find.byWidgetPredicate((w) => w is NavigationBar || w is NavigationRail),
          matching: find.byIcon(Icons.today),
        );
        expect(ringOf(tester, today), isNull);
        Focus.of(tester.element(today)).requestFocus();
        await tester.pumpAndSettle();
        final shape = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: tester.getSize(today).center(Offset.zero),
            width: indicator.width,
            height: indicator.height,
          ),
          Radius.circular(radius),
        );
        // The gap and ring stand clear of the selected indicator's fill.
        expect(
          find.ancestor(of: today, matching: find.byType(CustomPaint)).first,
          paints
            ..rrect(rrect: shape.inflate(1), color: sefer.focusGap, strokeWidth: 2, style: PaintingStyle.stroke)
            ..rrect(rrect: shape.inflate(3.5), color: sefer.focus, strokeWidth: 3, style: PaintingStyle.stroke),
        );
      });

      testWidgets('$name focused under touch shows no ring', (tester) async {
        FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTouch;
        addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
        await openRoute(tester, '/today', size: size, now: DateTime(2026, 10, 9, 11));
        Focus.of(tester.element(parsha)).requestFocus();
        // Focus moves in a microtask, which may come after the next frame.
        await tester.pumpAndSettle();
        expect(Focus.of(tester.element(parsha)).hasPrimaryFocus, isTrue);
        expect(ringOf(tester, parsha), isNull);
      });
    }
  });

  testWidgets('the rail, scrolling in a short window, cuts off no ring as Tab moves through it', (tester) async {
    _keyboardMode();
    // A phone held sideways.
    await openRoute(tester, '/today', size: const Size(800, 360), now: DateTime(2026, 10, 9, 11));
    final rail = find.byType(NavigationRail);
    final viewport = tester.getRect(find.descendant(of: rail, matching: find.byType(SingleChildScrollView)));
    final icons = {
      for (final (label, icon) in [
        ('Today', Icons.today),
        ('Parsha', Icons.menu_book_outlined),
        ('Progress', Icons.donut_large_outlined),
        ('Community', Icons.forum_outlined),
        ('Settings', Icons.settings_outlined),
      ])
        label: find.descendant(of: rail, matching: find.byIcon(icon)),
    };
    // The destinations are taller together than the window: the rail scrolls,
    // and clips what lies past its edges.
    expect(tester.getRect(icons['Settings']!).bottom + 40, greaterThan(viewport.bottom));

    // Today, at the top of the rail's scrolling content, then on with Tab,
    // which scrolls each destination into view.
    Focus.of(tester.element(icons['Today']!)).requestFocus();
    await tester.pumpAndSettle();
    final ringed = <String>{};
    for (var i = 0; i < 12 && ringed.length < icons.length; i++) {
      if (i > 0) {
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
      }
      for (final MapEntry(key: label, value: icon) in icons.entries) {
        if (!Focus.of(tester.element(icon)).hasPrimaryFocus) continue;
        ringed.add(label);
        // The ring's outer edge: 5 out from the 56×32 indicator, centred on
        // the icon.
        final ring = Rect.fromCenter(center: tester.getCenter(icon), width: 56 + 10, height: 32 + 10);
        expect(viewport.contains(ring.topLeft) && viewport.contains(ring.bottomRight), isTrue,
            reason: '$label: $ring within $viewport');
      }
    }
    expect(ringed, icons.keys.toSet(), reason: 'Tab reached every destination');
  });

  testWidgets('the reasons to report a post are ringed from the keyboard, within the dialog', (tester) async {
    _keyboardMode();
    await tester.pumpWidget(MaterialApp(
      theme: _theme(AppThemeMode.light),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(child: TextButton(onPressed: () => showReportDialog(context), child: const Text('Report'))),
        ),
      ),
    ));
    await tester.tap(find.text('Report'));
    await tester.pumpAndSettle();
    final rings = find.byType(TileFocusRing);
    expect(rings, findsNWidgets(6));
    final viewport = tester.getRect(
      find.descendant(of: find.byType(AlertDialog), matching: find.byType(SingleChildScrollView)).first,
    );

    // Tab to the first reason.
    final first = rings.first;
    for (var i = 0; i < 10; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final focused = FocusManager.instance.primaryFocus?.context;
      if (focused != null && find.descendant(of: first, matching: find.byWidget(focused.widget)).evaluate().isNotEmpty) {
        break;
      }
    }
    final ringPaint = find.descendant(of: first, matching: find.byType(CustomPaint)).first;
    expect(tester.widget<CustomPaint>(ringPaint).foregroundPainter, isNotNull);
    // 4 out from the tile's sides, as high as it is, and within the
    // dialog's scrolling content, which clips.
    final tile = tester.getRect(find.descendant(of: first, matching: find.byType(RadioListTile<ReportReason>)));
    final outer = RRect.fromRectAndRadius(Rect.fromLTRB(-7, 0, tile.width + 7, tile.height), const Radius.circular(8));
    expect(ringPaint, paints..drrect(outer: outer, inner: outer.deflate(3), color: Palettes.seferLight.focus));
    expect(viewport.left, lessThanOrEqualTo(tile.left - 7));
    expect(viewport.right, greaterThanOrEqualTo(tile.right + 7));
    // With no wash under it.
    final inkWell = find.descendant(of: first, matching: find.byType(InkWell));
    expect(Theme.of(tester.element(inkWell)).focusColor, Colors.transparent);
  });

  group('a popup menu item', () {
    Future<void> openMenu(WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: _theme(AppThemeMode.light),
        home: Scaffold(
          appBar: AppBar(
            actions: [
              PopupMenuButton<int>(
                itemBuilder: (context) => const [
                  SeferMenuItem(value: 1, child: Text('One')),
                  SeferMenuItem(value: 2, child: Text('Two')),
                ],
              ),
            ],
          ),
        ),
      ));
      await tester.tap(find.byType(PopupMenuButton<int>));
      await tester.pumpAndSettle();
    }

    Finder item(String label) => find.ancestor(of: find.text(label), matching: find.byType(SeferMenuItem<int>));
    Finder ringPaint(String label) =>
        find.descendant(of: item(label), matching: find.byType(CustomPaint)).first;
    CustomPainter? ringOf(WidgetTester tester, String label) =>
        tester.widget<CustomPaint>(ringPaint(label)).foregroundPainter;

    testWidgets('is ringed inside, with no wash, from the keyboard', (tester) async {
      _keyboardMode();
      final focus = _theme(AppThemeMode.light).extension<SeferColors>()!.focus;
      await openMenu(tester);
      expect(ringOf(tester, 'Two'), isNull);

      Focus.of(tester.element(find.text('Two'))).requestFocus();
      // Focus moves in a microtask, which may come after the next frame.
      await tester.pumpAndSettle();
      final size = tester.getSize(item('Two'));
      expect(size.height, kMinInteractiveDimension);
      expect(tester.getSize(ringPaint('Two')), size);
      // 3 px, 4 px in from the item's edges, radius 8.
      final outer = RRect.fromRectAndRadius((Offset.zero & size).deflate(4), const Radius.circular(8));
      expect(ringPaint('Two'), paints..drrect(outer: outer, inner: outer.deflate(3), color: focus));
      expect(ringOf(tester, 'One'), isNull);
      // The item's ink well draws no wash under the ring.
      final inkWell = find.descendant(of: item('Two'), matching: find.byType(InkWell));
      expect(Theme.of(tester.element(inkWell)).focusColor, Colors.transparent);
      // Its label starts where Material's would, 12 in.
      expect(tester.getTopLeft(find.text('Two')).dx - tester.getTopLeft(item('Two')).dx, 12);

      // A switch to touch drops the ring.
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTouch;
      await tester.pump();
      expect(ringOf(tester, 'Two'), isNull);
    });

    testWidgets('focused under touch shows no ring', (tester) async {
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTouch;
      addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
      await openMenu(tester);
      Focus.of(tester.element(find.text('Two'))).requestFocus();
      // Focus moves in a microtask, which may come after the next frame.
      await tester.pumpAndSettle();
      expect(Focus.of(tester.element(find.text('Two'))).hasPrimaryFocus, isTrue);
      expect(ringOf(tester, 'Two'), isNull);
    });
  });

  group('a list tile', () {
    final ringPaint = find.descendant(of: find.byType(TileFocusRing), matching: find.byType(CustomPaint)).first;

    /// The ring that TileFocusRing paints on its tile, or null.
    CustomPainter? ringOf(WidgetTester tester) => tester.widget<CustomPaint>(ringPaint).foregroundPainter;

    Future<void> pumpTile(WidgetTester tester, {bool outside = false}) => tester.pumpWidget(MaterialApp(
          theme: _theme(AppThemeMode.light),
          home: Scaffold(
            body: Center(
              child: TileFocusRing(
                outside: outside,
                child: ListTile(onTap: () {}, title: const Text('Rishon')),
              ),
            ),
          ),
        ));

    for (final outside in [false, true]) {
      testWidgets('is ringed ${outside ? 'outside' : 'inside'}, with no wash, from the keyboard', (tester) async {
        await pumpTile(tester, outside: outside);
        expect(ringOf(tester), isNull);

        // Tab switches to keyboard mode and moves focus to the tile.
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        // 3 px, radius 8: 4 px in from the tile's edges, or 4 px out from its
        // sides and as high as it is.
        final size = tester.getSize(find.byType(ListTile));
        expect(tester.getSize(ringPaint), size);
        final area = outside
            ? Rect.fromLTRB(-7, 0, size.width + 7, size.height)
            : (Offset.zero & size).deflate(4);
        final outer = RRect.fromRectAndRadius(area, const Radius.circular(8));
        expect(ringPaint, paints..drrect(outer: outer, inner: outer.deflate(3), color: Palettes.seferLight.focus));
        final inkWell = find.descendant(of: find.byType(ListTile), matching: find.byType(InkWell));
        expect(Theme.of(tester.element(inkWell)).focusColor, Colors.transparent);

        // A touch elsewhere hides it, though focus stays; a key brings it back.
        await tester.tapAt(const Offset(5, 5));
        await tester.pump();
        expect(Focus.of(tester.element(find.text('Rishon'))).hasPrimaryFocus, isTrue);
        expect(ringOf(tester), isNull);
        await tester.sendKeyEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pump();
        expect(ringOf(tester), isNotNull);
      });
    }

    testWidgets('focused under touch shows no ring', (tester) async {
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTouch;
      addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
      await pumpTile(tester);
      Focus.of(tester.element(find.text('Rishon'))).requestFocus();
      // Focus moves in a microtask, which may come after the next frame.
      await tester.pumpAndSettle();
      expect(Focus.of(tester.element(find.text('Rishon'))).hasPrimaryFocus, isTrue);
      expect(ringOf(tester), isNull);
    });
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
