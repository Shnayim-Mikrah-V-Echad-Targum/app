import 'dart:async';
import 'dart:ui' show Locale, SemanticsAction, Tristate;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

/// What every node of the semantics tree must be, whatever the screen, for a
/// screen reader to operate and name it (run it with `meetsGuideline`):
///
/// 1. An enabled button or link can be activated: it has a tap action. A
///    control that says it is a button but can't be pressed is a dead end,
///    as a tile whose gesture was moved or dropped would be.
/// 2. A slider is named by its setting, not left unnamed or named by its
///    value.
/// 3. A text field has a label: its hint alone is gone once text is typed.
///    Scoped to fields that take input: Flutter's SelectableText (a post,
///    the guide) is a read-only text field whose text is its value, and
///    which no one types in.
/// 4. A verse, as the reader labels it ("Verse 9." or "Targum, verse 9."
///    and the Hebrew, or the same in Hebrew), is tagged Hebrew, by its node's
///    locale or a span of its label, so it is read in a Hebrew voice.
///
/// Nodes merged into a parent are skipped: the parent speaks for them.
/// Hidden ones are not. Flutter marks a node hidden when it is scrolled out
/// of view but still built (within the scrollable's cache extent), so that
/// TalkBack and VoiceOver can reach it by swiping and scroll to it; a control
/// just below the fold is a control all the same. No rule depends on where a
/// node is.
class SemanticsInvariants extends AccessibilityGuideline {
  const SemanticsInvariants();

  /// The reader's label of a verse or its Targum, in either language of the
  /// app (`verseLabel` and `targumVerseLabel`, then ". "). Only this form:
  /// labels such as "Verse 1 of 14", "Verse by verse", "Targum Onkelos" or
  /// "תרגום לאנגלית" name parts of the interface, in its own language.
  static final verseLabel = RegExp(r'^(Verse|Targum, verse|פסוק|תרגום, פסוק) \d+\. ');

  static const _hebrew = 'he';

  @override
  String get description => 'Buttons, links, sliders, text fields and verses should be operable, named and tagged';

  @override
  FutureOr<Evaluation> evaluate(WidgetTester tester) {
    var result = const Evaluation.pass();
    for (final view in tester.binding.renderViews) {
      result += _traverse(view.owner!.semanticsOwner!.rootSemanticsNode!);
    }
    return result;
  }

  Evaluation _traverse(SemanticsNode node) {
    var result = const Evaluation.pass();
    node.visitChildren((child) {
      result += _traverse(child);
      return true;
    });
    if (node.isMergedIntoParent) return result;

    final data = node.getSemanticsData();
    final flags = data.flagsCollection;
    Evaluation fail(String why) => Evaluation.fail('$node: $why');

    if ((flags.isButton || flags.isLink) &&
        flags.isEnabled != Tristate.isFalse &&
        !data.hasAction(SemanticsAction.tap)) {
      result += fail('an enabled ${flags.isLink ? 'link' : 'button'} has no tap action');
    }
    if (flags.isSlider && (data.label.trim().isEmpty || data.label == data.value)) {
      result += fail('a slider is named "${data.label}", not by its setting (value "${data.value}")');
    }
    if (flags.isTextField && !flags.isReadOnly && data.label.trim().isEmpty) {
      result += fail('a text field has no label');
    }
    if (verseLabel.hasMatch(data.label) && !_taggedHebrew(data)) {
      result += fail('a verse\'s label is not tagged Hebrew, by its locale or a span of it');
    }
    return result;
  }

  static bool _taggedHebrew(SemanticsData data) =>
      _isHebrew(data.locale) ||
      data.attributedLabel.attributes.any((a) => a is LocaleStringAttribute && _isHebrew(a.locale));

  static bool _isHebrew(Locale? locale) => locale?.languageCode == _hebrew;
}

/// The [SemanticsInvariants], for `meetsGuideline`.
const semanticsInvariants = SemanticsInvariants();
