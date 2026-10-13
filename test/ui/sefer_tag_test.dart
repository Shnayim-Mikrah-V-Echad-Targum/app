import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikrah/features/settings/app_settings.dart';
import 'package:shnayim_mikrah/ui/widgets/sefer_tag.dart';

import '../helpers.dart';

/// docs/DESIGN_SYSTEM.md §6.20: a tag is a label, never a control.
void main() {
  setUpAll(loadBundledFonts);

  BoxDecoration decoration(WidgetTester tester) =>
      tester.widget<Container>(find.descendant(of: find.byType(SeferTag), matching: find.byType(Container))).decoration!
          as BoxDecoration;

  testWidgets('is labelSmall in onSecondaryContainer on secondaryContainer, radius 6, padding 6/1', (tester) async {
    await pumpThemed(tester, const Center(child: SeferTag('Author')));
    final scheme = Theme.of(tester.element(find.byType(SeferTag))).colorScheme;
    final text = Theme.of(tester.element(find.byType(SeferTag))).textTheme;
    final box = decoration(tester);
    expect(box.color, scheme.secondaryContainer);
    expect(box.borderRadius, const BorderRadius.all(Radius.circular(6)));
    expect(box.border, isNull, reason: 'no outline but high contrast’s');
    final label = tester.widget<Text>(find.text('Author'));
    expect(label.style?.color, scheme.onSecondaryContainer);
    expect(label.style?.fontSize, text.labelSmall!.fontSize);
    final tag = tester.getRect(find.byType(SeferTag));
    final word = tester.getRect(find.text('Author'));
    expect(word.left - tag.left, 6);
    expect(tag.right - word.right, 6);
    expect(word.top - tag.top, 1);
    expect(tag.bottom - word.bottom, 1);
  });

  testWidgets('in high contrast, is outlined 2 px outside its padding', (tester) async {
    await pumpThemed(tester, const Center(child: SeferTag('Author')), theme: AppThemeMode.highContrastDark);
    final scheme = Theme.of(tester.element(find.byType(SeferTag))).colorScheme;
    expect(decoration(tester).border, Border.all(color: scheme.outline, width: 2));
    final tag = tester.getRect(find.byType(SeferTag));
    final word = tester.getRect(find.text('Author'));
    expect(word.left - tag.left, 8);
    expect(word.top - tag.top, 3);
  });

  testWidgets('leads with its icon at 14, 4 before the word, at either edge', (tester) async {
    for (final hebrew in [false, true]) {
      await pumpThemed(tester, const Center(child: SeferTag('Moderator', icon: Icons.shield_outlined)), hebrew: hebrew);
      final scheme = Theme.of(tester.element(find.byType(SeferTag))).colorScheme;
      final icon = find.byIcon(Icons.shield_outlined);
      expect(tester.widget<Icon>(icon).size, 14);
      expect(tester.widget<Icon>(icon).color, scheme.onSecondaryContainer);
      final glyph = tester.getRect(icon);
      final word = tester.getRect(find.text('Moderator'));
      final tag = tester.getRect(find.byType(SeferTag));
      if (hebrew) {
        expect(glyph.left - word.right, 4);
        expect(tag.right - glyph.right, 6);
      } else {
        expect(word.left - glyph.right, 4);
        expect(glyph.left - tag.left, 6);
      }
    }
  });

  testWidgets('is read as its word, and is no button or tab stop', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpThemed(tester, const Center(child: SeferTag('Moderator', icon: Icons.shield_outlined)));
    expect(find.descendant(of: find.byType(SeferTag), matching: find.byType(InkWell)), findsNothing);
    expect(find.descendant(of: find.byType(SeferTag), matching: find.byType(Focus)), findsNothing);
    expect(
      tester.getSemantics(find.text('Moderator')),
      isSemantics(label: 'Moderator', isButton: false, isFocusable: false, hasTapAction: false),
    );
    semantics.dispose();
  });
}
