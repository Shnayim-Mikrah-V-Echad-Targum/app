import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';
import 'every_theme.dart';
import 'semantics_invariants.dart';

/// The [SemanticsInvariants], text contrast (WCAG 1.4.3), tap targets and
/// labels on every route, in each of the five themes: here the invariants'
/// own tests and the first half of the routes, and in
/// semantics_invariants_pages_test.dart the rest, so that the two files run
/// in parallel.
///
/// Each route is opened once and then shown in each theme in turn, as a
/// reader who changes the theme sees it, so a colour a page keeps from the
/// theme it was built in fails too. It keeps the test font, as
/// text_contrast_test.dart explains: textContrastGuideline reads colours from
/// the pixels, which the bundled fonts' thin strokes blur. Tap targets in the
/// bundled fonts' real metrics are checked in screens_a11y_test.dart.
void main() {
  group('the invariants', () {
    Future<Evaluation> evaluate(WidgetTester tester, Widget child) async {
      await pumpThemed(tester, child);
      return semanticsInvariants.evaluate(tester);
    }

    testWidgets('hold for a button with a tap, and a disabled one without', (tester) async {
      final handle = tester.ensureSemantics();
      final result = await evaluate(
        tester,
        Column(children: [
          FilledButton(onPressed: () {}, child: const Text('Continue')),
          const FilledButton(onPressed: null, child: Text('Done')),
          Semantics(link: true, onTap: () {}, child: const Text('Sources')),
        ]),
      );
      expect(result.passed, isTrue, reason: result.reason);
      handle.dispose();
    });

    // A tile whose gesture was dropped still says it is a button.
    testWidgets('fail for an enabled button or link that cannot be activated', (tester) async {
      final handle = tester.ensureSemantics();
      for (final node in [
        Semantics(button: true, enabled: true, child: const Text('Noach: On time')),
        Semantics(button: true, child: const Text('Noach: On time')),
        Semantics(link: true, child: const Text('Sources')),
      ]) {
        final result = await evaluate(tester, node);
        expect(result.passed, isFalse);
        expect(result.reason, contains('has no tap action'));
      }
      handle.dispose();
    });

    testWidgets('fail for a slider named by its value or not at all', (tester) async {
      final handle = tester.ensureSemantics();
      Widget slider({String? label}) => Semantics(
            label: label,
            value: '100%',
            increasedValue: '110%',
            decreasedValue: '90%',
            slider: true,
            onIncrease: () {},
            onDecrease: () {},
            child: _box,
          );
      expect((await evaluate(tester, slider(label: 'Reading size'))).passed, isTrue);
      for (final label in [null, '100%']) {
        final result = await evaluate(tester, slider(label: label));
        expect(result.passed, isFalse, reason: 'labelled "$label"');
        expect(result.reason, contains('not by its setting'));
      }
      handle.dispose();
    });

    testWidgets('fail for a text field with only a hint', (tester) async {
      final handle = tester.ensureSemantics();
      expect(
        (await evaluate(tester, const TextField(decoration: InputDecoration(labelText: 'Your name')))).passed,
        isTrue,
      );
      // Read-only, and read by its text.
      expect((await evaluate(tester, const SelectableText('Each week, a person completes…'))).passed, isTrue);
      final result = await evaluate(
        tester,
        Semantics(textField: true, hint: 'Your name', child: _box),
      );
      expect(result.passed, isFalse);
      expect(result.reason, contains('a text field has no label'));
      handle.dispose();
    });

    testWidgets("fail for a verse that isn't tagged Hebrew, in either language", (tester) async {
      final handle = tester.ensureSemantics();
      const hebrew = 'אֵלֶּה תּוֹלְדֹת נֹחַ';
      for (final prefix in ['Verse 9. ', 'Targum, verse 9. ', 'פסוק 9. ', 'תרגום, פסוק 9. ']) {
        final label = '$prefix$hebrew';
        final untagged = await evaluate(tester, Semantics(container: true, label: label, child: _box));
        expect(untagged.passed, isFalse, reason: label);
        expect(untagged.reason, contains('not tagged Hebrew'));

        final bySpan = await evaluate(
          tester,
          Semantics(
            container: true,
            attributedLabel: AttributedString(label, attributes: [
              LocaleStringAttribute(
                range: TextRange(start: prefix.length, end: label.length),
                locale: const Locale('he'),
              ),
            ]),
            child: _box,
          ),
        );
        expect(bySpan.passed, isTrue, reason: '$label, its Hebrew tagged');
        final byNode = await evaluate(
          tester,
          Semantics(container: true, localeForSubtree: const Locale('he'), label: label, child: _box),
        );
        expect(byNode.passed, isTrue, reason: '$label, in a Hebrew node');
      }
      // The interface's own words, not a verse.
      for (final label in ['Verse 1 of 14', 'Verse by verse', 'Targum Onkelos', 'תרגום לאנגלית']) {
        final result = await evaluate(tester, Semantics(container: true, label: label, child: _box));
        expect(result.passed, isTrue, reason: label);
      }
      handle.dispose();
    });
  });

  for (final route in a11yRoutesFirstHalf) {
    testWidgets('every theme: $route', (tester) async {
      final handle = tester.ensureSemantics();
      final c = await open(tester, route);
      await expectInEveryTheme(tester, c);
      handle.dispose();
    });
  }
}

/// Room for a node: one with no size is left out of the tree.
const _box = SizedBox(width: 200, height: 48);
