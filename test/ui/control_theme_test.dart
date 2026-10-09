import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/ui/theme/app_theme.dart';
import 'package:shnayim_mikra/ui/widgets/sefer_choice_chip.dart';

import '../helpers.dart';

/// docs/DESIGN_SYSTEM.md §6.5–6.8: buttons, chips, inputs, switches, sliders
/// and segmented buttons.
const _modes = [
  AppThemeMode.light,
  AppThemeMode.dark,
  AppThemeMode.sepia,
  AppThemeMode.highContrastLight,
  AppThemeMode.highContrastDark,
];

const _focused = {WidgetState.focused};
const _r10 = BorderRadius.all(Radius.circular(10));

ThemeData _theme(AppThemeMode mode, {bool hebrewUi = false}) =>
    AppTheme.build(mode: mode, uiFont: UiFont.standard, hebrewUi: hebrewUi, reduceMotion: false);

/// Pumps [child] centred under [theme].
Future<void> _pump(WidgetTester tester, ThemeData theme, Widget child) =>
    tester.pumpWidget(MaterialApp(theme: theme, home: Scaffold(body: Center(child: child))));

void main() {
  setUpAll(loadBundledFonts);

  // Focus is only ringed for keyboard users; most tests resolve styles as one.
  setUp(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional);
  tearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);

  for (final mode in _modes) {
    group(mode.name, () {
      final theme = _theme(mode);
      final scheme = theme.colorScheme;
      final sefer = theme.extension<SeferColors>()!;
      final hc = sefer.isHighContrast;

      test('buttons are radius 10 and switch to the focus ring at once', () {
        for (final (name, style) in [
          ('filled', theme.filledButtonTheme.style!),
          ('outlined', theme.outlinedButtonTheme.style!),
          ('text', theme.textButtonTheme.style!),
          ('segmented', theme.segmentedButtonTheme.style!),
        ]) {
          expect(style.shape!.resolve({}), const RoundedRectangleBorder(borderRadius: _r10), reason: name);
          expect(style.shape!.resolve({}), isNot(isA<FocusRingBorder>()), reason: name);
          expect(
            style.shape!.resolve(_focused),
            FocusRingBorder(borderRadius: _r10, ring: sefer.focus, gap: sefer.focusGap),
            reason: name,
          );
          expect(style.animationDuration, Duration.zero, reason: name);
        }
        // Icon buttons keep Material's circle; their ring is round.
        final icon = theme.iconButtonTheme.style!;
        expect(icon.shape!.resolve({}), isNull);
        expect(
          icon.shape!.resolve(_focused),
          isA<FocusRingBorder>().having((b) => b.borderRadius, 'radius', const BorderRadius.all(Radius.circular(24))),
        );
        expect(icon.minimumSize!.resolve({}), const Size(48, 48));
      });

      test('buttons: sizes, colours, outlines and washes', () {
        final filled = theme.filledButtonTheme.style!;
        expect(filled.minimumSize!.resolve({}), const Size(64, 48));
        expect(filled.iconSize!.resolve({}), 20);
        expect(filled.overlayColor!.resolve({WidgetState.pressed}), scheme.onPrimary.withValues(alpha: 0.10));
        expect(filled.overlayColor!.resolve({WidgetState.hovered}), scheme.onPrimary.withValues(alpha: 0.06));

        final outlined = theme.outlinedButtonTheme.style!;
        expect(outlined.foregroundColor!.resolve({}), scheme.primary);
        expect(outlined.side!.resolve({}), BorderSide(color: scheme.outline, width: hc ? 2 : 1));
        // Disabled buttons keep Material's defaults.
        expect(outlined.side!.resolve({WidgetState.disabled}), isNull);
        expect(outlined.foregroundColor!.resolve({WidgetState.disabled}), isNull);

        final textButton = theme.textButtonTheme.style!;
        expect(textButton.foregroundColor!.resolve({}), scheme.primary);
        expect(textButton.minimumSize!.resolve({}), const Size(48, 48));
        expect(
          textButton.textStyle?.resolve({})?.decoration,
          hc ? TextDecoration.underline : null,
          reason: 'text buttons are underlined in high contrast only',
        );
      });

      test('the focus tint for list tiles and rail items is onSurface at 24%', () {
        expect(theme.focusColor, scheme.onSurface.withValues(alpha: 0.24));
      });

      test('chips: no checkmark; selection is a fill and a heavier border; focus is a ring', () {
        final chips = theme.chipTheme;
        expect(chips.showCheckmark, isFalse);
        const r8 = BorderRadius.all(Radius.circular(8));
        final shape = chips.shape! as WidgetStateOutlinedBorder;
        expect(shape.resolve({}), const RoundedRectangleBorder(borderRadius: r8));
        expect(shape.resolve({WidgetState.selected}), const RoundedRectangleBorder(borderRadius: r8));
        // Focus is the buttons' ring, outside the border, which stays.
        for (final states in [_focused, {WidgetState.focused, WidgetState.selected}]) {
          expect(shape.resolve(states), FocusRingBorder(borderRadius: r8, ring: sefer.focus, gap: sefer.focusGap));
        }
        expect(chips.backgroundColor, Colors.transparent);
        expect(chips.selectedColor, scheme.primaryContainer);

        // All outside the chip, so no state changes its size.
        const outside = BorderSide.strokeAlignOutside;
        final side = chips.side! as WidgetStateBorderSide;
        expect(side.resolve({}), BorderSide(color: scheme.outline, width: hc ? 2 : 1, strokeAlign: outside));
        expect(
          side.resolve({WidgetState.selected}),
          BorderSide(color: scheme.primary, width: hc ? 2.5 : 1.5, strokeAlign: outside),
        );
        expect(side.resolve({WidgetState.disabled})?.strokeAlign, outside);
        expect(side.resolve({WidgetState.focused, WidgetState.selected}), side.resolve({WidgetState.selected}));

        final label = chips.labelStyle!.color! as WidgetStateColor;
        expect(label.resolve({WidgetState.selected}), scheme.onPrimaryContainer);
        expect(label.resolve({}), scheme.onSurfaceVariant);
        expect(chips.labelStyle!.fontSize, theme.textTheme.labelMedium!.fontSize);
      });

      test('inputs: outlined, radius 10, a 2 px focused border', () {
        final inputs = theme.inputDecorationTheme;
        OutlineInputBorder border(InputBorder? b) => b! as OutlineInputBorder;
        for (final b in [inputs.border, inputs.enabledBorder, inputs.focusedBorder, inputs.errorBorder]) {
          expect(border(b).borderRadius, _r10);
        }
        expect(border(inputs.enabledBorder).borderSide, BorderSide(color: scheme.outline, width: hc ? 2 : 1));
        expect(border(inputs.focusedBorder).borderSide, BorderSide(color: scheme.primary, width: 2));
        expect(border(inputs.errorBorder).borderSide, BorderSide(color: scheme.error, width: 2));
        expect(border(inputs.focusedErrorBorder).borderSide, BorderSide(color: scheme.error, width: 2));
        for (final style in [inputs.helperStyle!, inputs.counterStyle!]) {
          expect(style.fontSize, theme.textTheme.bodySmall!.fontSize);
          expect(style.fontFeatures, contains(const FontFeature.tabularFigures()));
        }
      });

      test('switch: a checked thumb when on, a small plain one when off', () {
        final s = theme.switchTheme;
        expect(s.trackColor!.resolve({WidgetState.selected}), scheme.primary);
        expect(s.thumbColor!.resolve({WidgetState.selected}), scheme.onPrimary);
        expect(s.trackColor!.resolve({}), scheme.surfaceContainerHighest);
        expect(s.trackOutlineColor!.resolve({}), scheme.outline);
        expect(s.trackOutlineWidth!.resolve({}), 2);
        expect(s.thumbColor!.resolve({}), scheme.outline);

        final on = s.thumbIcon!.resolve({WidgetState.selected})!;
        expect((on.icon, on.size), (Icons.check, 16));
        final off = s.thumbIcon!.resolve({});
        // An X on every off switch was noise (D17); high contrast keeps it.
        expect(off?.icon, hc ? Icons.close : null);
      });

      test('slider: a 4 px track, a round 20 px thumb and no tick marks', () {
        final s = theme.sliderTheme;
        expect(s.trackHeight, 4);
        expect(s.activeTrackColor, scheme.primary);
        expect(s.inactiveTrackColor, scheme.surfaceContainerHighest);
        expect(s.thumbColor, scheme.primary);
        expect(s.tickMarkShape, SliderTickMarkShape.noTickMark);
        expect(s.thumbShape, isA<RoundSliderThumbShape>().having((t) => t.enabledThumbRadius, 'radius', 10));
        expect(s.overlayShape, isA<FocusRingSliderOverlay>().having((o) => o.ring, 'ring', sefer.focus));
      });

      test('segmented: primaryContainer and bold when selected, outlined otherwise', () {
        final s = theme.segmentedButtonTheme.style!;
        expect(s.backgroundColor!.resolve({WidgetState.selected}), scheme.primaryContainer);
        expect(s.foregroundColor!.resolve({WidgetState.selected}), scheme.onPrimaryContainer);
        expect(s.backgroundColor!.resolve({}), Colors.transparent);
        expect(s.textStyle!.resolve({WidgetState.selected})!.fontWeight, FontWeight.w700);
        expect(s.side!.resolve({}), BorderSide(color: scheme.outline, width: hc ? 2 : 1));
      });
    });
  }

  for (final mode in [AppThemeMode.light, AppThemeMode.highContrastLight]) {
    testWidgets('${mode.name}: tonal buttons are techelet, not gold; destructive ones are error', (tester) async {
      final theme = _theme(mode);
      final scheme = theme.colorScheme;
      late ButtonStyle tonal, destructive;
      await _pump(
        tester,
        theme,
        Builder(builder: (context) {
          tonal = AppButtons.tonal(context);
          destructive = AppButtons.destructive(context);
          return FilledButton.tonal(style: tonal, onPressed: () {}, child: const Text('Read'));
        }),
      );
      expect(tonal.backgroundColor!.resolve({}), scheme.primaryContainer);
      expect(tonal.foregroundColor!.resolve({}), scheme.onPrimaryContainer);
      expect(tonal.backgroundColor!.resolve({WidgetState.disabled}), isNull);
      final hc = mode == AppThemeMode.highContrastLight;
      expect(tonal.side?.resolve({}), hc ? BorderSide(color: scheme.outline, width: 2) : null);
      expect(destructive.backgroundColor!.resolve({}), scheme.error);
      expect(destructive.foregroundColor!.resolve({}), scheme.onError);

      final material =
          tester.widget<Material>(find.descendant(of: find.byType(FilledButton), matching: find.byType(Material)));
      expect(material.color, scheme.primaryContainer);
      expect(material.shape, const RoundedRectangleBorder(borderRadius: _r10).copyWith(side: tonal.side?.resolve({})));
    });
  }

  for (final hebrewUi in [false, true]) {
    final ui = hebrewUi ? 'Hebrew' : 'English';

    testWidgets('$ui UI: a chip is 36 high, padded to a 48 tap target', (tester) async {
      await _pump(
        tester,
        _theme(AppThemeMode.light, hebrewUi: hebrewUi),
        SeferChoiceChip(label: const Text('Shlishi'), selected: true, onSelected: (_) {}),
      );
      final chip = find.descendant(of: find.byType(ChoiceChip), matching: find.byType(Material)).first;
      expect(tester.getSize(chip).height, 36);
      expect(tester.getSize(find.byType(ChoiceChip)).height, 48);

      // Focus doesn't resize it.
      final width = tester.getSize(chip).width;
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(tester.getSize(chip), Size(width, 36));
      // No checkmark on the selected chip.
      expect(find.byIcon(Icons.check), findsNothing);
    });

    testWidgets('$ui UI: a selected chip is bold, and focus adds no fill', (tester) async {
      final theme = _theme(AppThemeMode.light, hebrewUi: hebrewUi);
      await _pump(
        tester,
        theme,
        Row(mainAxisSize: MainAxisSize.min, children: [
          SeferChoiceChip(label: const Text('Rishon'), selected: true, onSelected: (_) {}),
          SeferChoiceChip(label: const Text('Sheni'), selected: false, onSelected: (_) {}),
        ]),
      );
      FontWeight? weight(String label) =>
          tester.renderObject<RenderParagraph>(find.text(label)).text.style?.fontWeight;
      expect(weight('Rishon'), FontWeight.w700);
      expect(weight('Sheni'), theme.textTheme.labelMedium!.fontWeight);
      // The ring alone marks focus: a grey fill would read as a selection.
      final inkWell = find.descendant(of: find.byType(ChoiceChip).last, matching: find.byType(InkWell));
      expect(Theme.of(tester.element(inkWell)).focusColor, Colors.transparent);
    });

    testWidgets('$ui UI: a segmented button is 48 high, with a check on the selected segment', (tester) async {
      await _pump(
        tester,
        _theme(AppThemeMode.light, hebrewUi: hebrewUi),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('English')),
            ButtonSegment(value: 1, label: Text('עברית')),
          ],
          selected: const {0},
          onSelectionChanged: (_) {},
        ),
      );
      expect(tester.getSize(find.byType(SegmentedButton<int>)).height, 48);
      for (final segment in tester.widgetList<TextButton>(find.byType(TextButton))) {
        expect(tester.getSize(find.byWidget(segment)).height, 48);
      }
      expect(find.byIcon(Icons.check), findsOneWidget);
    });
  }

}
