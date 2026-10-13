import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikrah/features/settings/app_settings.dart';
import 'package:shnayim_mikrah/features/settings/widgets/settings_widgets.dart';
import 'package:shnayim_mikrah/ui/theme/app_theme.dart';
import 'package:shnayim_mikrah/ui/widgets/paper_group.dart';

import '../../helpers.dart';

/// The rows of the redesigned settings pages (docs/DESIGN_SYSTEM.md §9
/// Settings): choices as paper radio rows or segments, their headings and
/// source notes, and switch rows.
void main() {
  /// A choice of three, [width] wide, whose choices are recorded.
  Future<List<String>> pumpChoice(
    WidgetTester tester, {
    bool segmented = false,
    bool prominent = false,
    String? help,
    bool helpIsSource = false,
    String? source,
    int headingLevel = 2,
    double width = 372,
    double textScale = 1,
    List<String> labels = const ['Ashkenazi', 'Sephardi', 'Chabad'],
    AppThemeMode theme = AppThemeMode.light,
  }) async {
    final chosen = <String>[];
    var value = labels.first;
    await pumpThemed(
      tester,
      Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: width,
          child: StatefulBuilder(
            builder: (context, setState) => ChoiceGroup<String>(
              title: 'Haftarah custom',
              help: help,
              helpIsSource: helpIsSource,
              source: source,
              headingLevel: headingLevel,
              segmented: segmented,
              prominent: prominent,
              value: value,
              choices: [for (final label in labels) Choice(label, label)],
              onChanged: (v) => setState(() {
                chosen.add(v);
                value = v;
              }),
            ),
          ),
        ),
      ),
      textScale: textScale,
      theme: theme,
    );
    return chosen;
  }

  group('ChoiceGroup', () {
    testWidgets('an option shown as a sample of itself is read by its name alone', (tester) async {
      final handle = tester.ensureSemantics();
      const sample = TextStyle(fontFamily: 'NotoSansHebrew', fontSize: 22);
      await pumpThemed(
        tester,
        ChoiceGroup<int>(
          title: 'Scripture font',
          value: 1,
          choices: const [
            Choice(1, 'בְּרֵאשִׁית בָּרָא', subtitle: 'Noto Sans Hebrew', sampleStyle: sample),
            Choice(2, 'בְּרֵאשִׁית בָּרָא', subtitle: 'Noto Serif Hebrew', sampleStyle: sample),
          ],
          onChanged: (_) {},
        ),
      );
      final first = find.byType(RadioListTile<int>).first;
      final title = tester.widget<Text>(find.descendant(of: first, matching: find.text('בְּרֵאשִׁית בָּרָא')));
      expect(title.style, sample);
      final label = tester.getSemantics(first).label;
      expect(label, contains('Noto Sans Hebrew'));
      expect(label, isNot(contains('בְּרֵאשִׁית')));
      handle.dispose();
    });

    testWidgets('sets its options as radio rows on one sheet of paper, 56 high, chosen by a tap', (tester) async {
      final chosen = await pumpChoice(tester);
      expect(find.byType(PaperGroup), findsOneWidget);
      final rows = find.byWidgetPredicate((w) => w is RadioListTile<String>);
      expect(rows, findsNWidgets(3));
      for (var i = 0; i < 3; i++) {
        expect(tester.getSize(rows.at(i)).height, 56);
      }
      // The text starts where a paper row's does, after its icon.
      final card = tester.getRect(find.byType(PaperGroup));
      expect(tester.getTopLeft(find.text('Sephardi')).dx - card.left, PaperGroup.iconInset);

      await tester.tap(find.text('Chabad'));
      await tester.pump();
      expect(chosen, ['Chabad']);
    });

    testWidgets('reads as one radio group: checked, one of several, and moved through with the arrow keys',
        (tester) async {
      final handle = tester.ensureSemantics();
      final chosen = await pumpChoice(tester);
      expect(
        tester.getSemantics(find.text('Ashkenazi')),
        isSemantics(label: 'Ashkenazi', hasCheckedState: true, isChecked: true, isInMutuallyExclusiveGroup: true),
      );
      expect(tester.getSemantics(find.text('Sephardi')), isSemantics(hasCheckedState: true, isChecked: false));

      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      expect(chosen, ['Sephardi']);
      handle.dispose();
    });

    testWidgets('a focused row is ringed as a paper row is, not washed', (tester) async {
      await pumpChoice(tester);
      FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
      addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final focus = SeferColors.of(tester.element(find.byType(PaperGroup))).focus;
      final ringed = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((box) => box.decoration)
          .whereType<ShapeDecoration>()
          .where((d) => (d.shape as RoundedRectangleBorder).side.color == focus);
      expect(ringed, hasLength(1));
      final tile = find.byWidgetPredicate((w) => w is RadioListTile<String>).first;
      expect(Theme.of(tester.element(find.descendant(of: tile, matching: find.byType(InkWell)))).focusColor,
          Colors.transparent);
    });

    testWidgets('a level-3 heading is a subheading, and its source note is marginalia on a quiet wash',
        (tester) async {
      final handle = tester.ensureSemantics();
      const source = 'Reading finished after Shabbat still counts (Shulchan Aruch OC 285:4).';
      await pumpChoice(tester, help: source, helpIsSource: true, headingLevel: 3);
      final context = tester.element(find.byType(ChoiceGroup<String>));
      final theme = Theme.of(context);
      final heading = tester.widget<Text>(find.text('Haftarah custom'));
      expect(heading.style?.fontSize, theme.textTheme.titleMedium?.fontSize);
      expect(tester.getSemantics(find.text('Haftarah custom')).getSemanticsData().headingLevel, 3);

      expect(find.byType(SourceNote), findsOneWidget);
      expect(tester.widget<Text>(find.text(source)).style, SeferType.of(context).marginalia);
      final wash = tester.widget<DecoratedBox>(
        find.descendant(of: find.byType(SourceNote), matching: find.byType(DecoratedBox)).first,
      );
      expect((wash.decoration as BoxDecoration).color, theme.colorScheme.surfaceContainerLow);
      handle.dispose();
    });

    testWidgets('a source is a note in the margin, and the advice after it plain help', (tester) async {
      const source = 'The Shulchan Aruch (OC 285:2) permits Rashi in place of Targum.';
      const advice = 'Ask your rav about translated Rashi.';
      await pumpChoice(tester, source: source, help: advice, headingLevel: 3);
      final context = tester.element(find.byType(ChoiceGroup<String>));
      expect(find.descendant(of: find.byType(SourceNote), matching: find.text(source)), findsOneWidget);
      expect(find.descendant(of: find.byType(SourceNote), matching: find.text(advice)), findsNothing);
      expect(tester.widget<Text>(find.text(advice)).style?.fontSize, Theme.of(context).textTheme.bodyMedium?.fontSize);
      expect(tester.getTopLeft(find.text(advice)).dy, greaterThan(tester.getBottomLeft(find.byType(SourceNote)).dy));
    });

    test('a prominent question takes plain help, never a source', () {
      expect(
        () => ChoiceGroup<int>(title: 'Q', value: 0, choices: const [], onChanged: (_) {}, prominent: true, help: 'x', helpIsSource: true),
        throwsAssertionError,
      );
      expect(
        () => ChoiceGroup<int>(title: 'Q', value: 0, choices: const [], onChanged: (_) {}, prominent: true, source: 'x'),
        throwsAssertionError,
      );
    });

    testWidgets('plain help is bodyMedium in onSurfaceVariant', (tester) async {
      await pumpChoice(tester, help: 'Visitors usually keep their home custom.');
      final theme = Theme.of(tester.element(find.byType(ChoiceGroup<String>)));
      final style = tester.widget<Text>(find.text('Visitors usually keep their home custom.')).style!;
      expect(style.fontSize, theme.textTheme.bodyMedium!.fontSize);
      expect(style.color, theme.colorScheme.onSurfaceVariant);
      expect(find.byType(SourceNote), findsNothing);
    });

    group('segmented', () {
      SegmentedButton<String> segments(WidgetTester tester) =>
          tester.widget<SegmentedButton<String>>(find.byType(SegmentedButton<String>));

      testWidgets('lies across the column with a check where the labels fit beside it', (tester) async {
        final chosen = await pumpChoice(tester, segmented: true, width: 600);
        expect(segments(tester).direction, Axis.horizontal);
        expect(segments(tester).showSelectedIcon, isTrue);
        expect(tester.getSize(find.byType(SegmentedButton<String>)).width, 600);
        await tester.tap(find.text('Sephardi'));
        await tester.pump();
        expect(chosen, ['Sephardi']);
      });

      testWidgets('stands one segment under another, checked, where a word would not fit beside the check',
          (tester) async {
        // In the test font every letter is as wide as the text is high, 15:
        // "Ashkenazi" fits a third of 520 alone, but not beside a check. The
        // check is the selected segment's non-colour cue, kept in every
        // theme (§6.8).
        for (final theme in [AppThemeMode.light, AppThemeMode.highContrastDark]) {
          await pumpChoice(tester, segmented: true, width: 520, theme: theme);
          expect(tester.takeException(), isNull);
          expect(segments(tester).direction, Axis.vertical, reason: theme.name);
          expect(segments(tester).showSelectedIcon, isTrue, reason: theme.name);
        }
      });

      testWidgets('stands one segment under another at 200% text', (tester) async {
        await pumpChoice(tester, segmented: true, textScale: 2);
        expect(segments(tester).direction, Axis.vertical);
        expect(segments(tester).showSelectedIcon, isTrue);
        expect(tester.takeException(), isNull);
      });

      testWidgets('keeps the check, and every label its room, so that no label moves as the choice changes',
          (tester) async {
        // "Out side" (120 in the test font) takes one line of its segment's
        // 130 alone, but two beside the check: set beside the check's room
        // whether or not it bears the check, it keeps its two lines.
        await pumpChoice(tester, segmented: true, width: 320, labels: const ['In', 'Out side']);
        expect(segments(tester).showSelectedIcon, isTrue);
        expect(segments(tester).direction, Axis.horizontal);
        final unselected = tester.getRect(find.text('Out side'));
        await tester.tap(find.text('Out side'));
        await tester.pumpAndSettle();
        final selected = tester.getRect(find.text('Out side'));
        expect(selected.height, unselected.height);
        expect(unselected.height, greaterThan(30), reason: 'two lines');
        expect(selected.width, unselected.width);
      });
    });

    group('prominent', () {
      Finder rows() => find.byWidgetPredicate((w) => w is RadioListTile<String>);

      /// The sheet that card [i] is drawn on, and its border.
      Material card(WidgetTester tester, int i) =>
          tester.widget<Material>(find.ancestor(of: rows().at(i), matching: find.byType(Material)).first);
      BorderSide side(WidgetTester tester, int i) => (card(tester, i).shape! as RoundedRectangleBorder).side;

      testWidgets('asks its question as a level-2 heading in headlineSmall', (tester) async {
        final handle = tester.ensureSemantics();
        await pumpChoice(tester, prominent: true, help: 'Visitors usually keep their home custom.');
        final theme = Theme.of(tester.element(find.byType(ChoiceGroup<String>)));
        final heading = tester.widget<Text>(find.text('Haftarah custom'));
        expect(heading.style?.fontSize, theme.textTheme.headlineSmall?.fontSize);
        expect(heading.style?.fontFamily, theme.textTheme.headlineSmall?.fontFamily);
        final data = tester.getSemantics(find.text('Haftarah custom')).getSemanticsData();
        expect(data.flagsCollection.isHeader, isTrue);
        expect(data.headingLevel, 2);
        expect(find.byType(GroupHeader), findsNothing, reason: 'no eyebrow');
        final help = tester.widget<Text>(find.text('Visitors usually keep their home custom.')).style!;
        expect(help.color, theme.colorScheme.onSurfaceVariant);
        handle.dispose();
      });

      testWidgets('sets each option on a card of its own, at least 72 high and 8 apart', (tester) async {
        final chosen = await pumpChoice(tester, prominent: true);
        expect(find.byType(PaperGroup), findsNothing);
        expect(rows(), findsNWidgets(3));
        for (var i = 0; i < 3; i++) {
          expect(tester.getSize(rows().at(i)).height, greaterThanOrEqualTo(72));
          final shape = card(tester, i).shape! as RoundedRectangleBorder;
          expect(shape.borderRadius, const BorderRadius.all(Radius.circular(12)));
        }
        for (var i = 1; i < 3; i++) {
          expect(tester.getTopLeft(rows().at(i)).dy - tester.getBottomLeft(rows().at(i - 1)).dy, ChoiceGroup.cardGap);
        }
        expect(ChoiceGroup.cardGap, 8);
        // The text starts where a paper row's does.
        final left = tester.getRect(rows().at(1)).left;
        expect(tester.getTopLeft(find.text('Sephardi')).dx - left, PaperGroup.iconInset);

        await tester.tap(find.text('Chabad'));
        await tester.pump();
        expect(chosen, ['Chabad']);
      });

      testWidgets('washes the chosen card in primaryContainer within a 2 px primary border', (tester) async {
        await pumpChoice(tester, prominent: true);
        final context = tester.element(find.byType(ChoiceGroup<String>));
        final scheme = Theme.of(context).colorScheme;
        expect(card(tester, 0).color, scheme.primaryContainer);
        expect((side(tester, 0).color, side(tester, 0).width), (scheme.primary, 2));
        for (final i in [1, 2]) {
          expect(card(tester, i).color, SeferColors.of(context).paper);
          expect((side(tester, i).color, side(tester, i).width), (scheme.outline, 1));
        }

        // The wash and border follow the choice.
        await tester.tap(find.text('Sephardi'));
        await tester.pumpAndSettle();
        expect(card(tester, 1).color, scheme.primaryContainer);
        expect(card(tester, 0).color, SeferColors.of(context).paper);
      });

      testWidgets('borders every card more heavily in high contrast, the chosen one most', (tester) async {
        await pumpChoice(tester, prominent: true, theme: AppThemeMode.highContrastDark);
        final scheme = Theme.of(tester.element(find.byType(ChoiceGroup<String>))).colorScheme;
        expect((side(tester, 0).color, side(tester, 0).width), (scheme.primary, 3));
        expect((side(tester, 1).color, side(tester, 1).width), (scheme.outline, 2));
      });

      testWidgets('still reads as one radio group, moved through with the arrow keys', (tester) async {
        final handle = tester.ensureSemantics();
        final chosen = await pumpChoice(tester, prominent: true);
        expect(
          tester.getSemantics(find.text('Ashkenazi')),
          isSemantics(label: 'Ashkenazi', hasCheckedState: true, isChecked: true, isInMutuallyExclusiveGroup: true),
        );
        expect(tester.getSemantics(find.text('Sephardi')), isSemantics(hasCheckedState: true, isChecked: false));

        FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
        addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        expect(chosen, ['Sephardi']);
        handle.dispose();
      });

      testWidgets('a focused card is ringed clear of its border, with the gap of every focus ring', (tester) async {
        await pumpChoice(tester, prominent: true);
        FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
        addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        final sefer = SeferColors.of(tester.element(find.byType(ChoiceGroup<String>)));
        final rings = tester
            .widgetList<DecoratedBox>(find.byType(DecoratedBox))
            .map((box) => box.decoration)
            .whereType<ShapeDecoration>()
            .map((d) => d.shape)
            .whereType<FocusRingBorder>()
            .toList();
        expect(rings, hasLength(1));
        expect((rings.single.ring, rings.single.gap), (sefer.focus, sefer.focusGap));
      });
    });
  });

  group('SwitchRow', () {
    testWidgets('the whole row toggles it, and it reads as one switch, never cut short', (tester) async {
      final handle = tester.ensureSemantics();
      var on = false;
      const description = 'Suggest a third Hebrew reading where Onkelos is mostly names (Numbers 32:3) '
          'or Rashi is silent, so that the reading never rests on names alone';
      await pumpThemed(
        tester,
        Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 360,
            child: StatefulBuilder(
              builder: (context, setState) => PaperGroup(children: [
                SwitchRow(
                  title: 'Third-reading prompts',
                  subtitle: description,
                  value: on,
                  onChanged: (v) => setState(() => on = v),
                ),
              ]),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Third-reading prompts'));
      await tester.pump();
      expect(on, isTrue);
      final row = tester.getSemantics(find.byType(SwitchRow));
      expect(row, isSemantics(hasToggledState: true, isToggled: true, hasTapAction: true, hasEnabledState: true));
      expect(row, isSemantics(isButton: false));
      expect(tester.widget<Text>(find.text(description)).maxLines, isNull);
      // One stop for the keyboard: the row, not the switch inside it as well.
      expect(find.descendant(of: find.byType(SwitchRow), matching: find.byType(ExcludeFocus)), findsOneWidget);
      handle.dispose();
    });

    testWidgets('without onChanged, shows its state disabled', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpThemed(
        tester,
        SizedBox(
          width: 360,
          child: PaperGroup(children: [SwitchRow(title: 'Daily reminder', value: false, onChanged: null)]),
        ),
      );
      final row = tester.getSemantics(find.byType(SwitchRow));
      expect(row, isSemantics(hasEnabledState: true, isEnabled: false, hasToggledState: true, isToggled: false));
      expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
      handle.dispose();
    });
  });
}
