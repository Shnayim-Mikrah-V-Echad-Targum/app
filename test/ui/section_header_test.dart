import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/ui/theme/palette.dart';
import 'package:shnayim_mikra/ui/theme/typography.dart';
import 'package:shnayim_mikra/ui/widgets/common.dart';
import 'package:shnayim_mikra/ui/widgets/ornaments.dart';

import '../helpers.dart';

/// docs/DESIGN_SYSTEM.md §6.4 and §6.20: section headers and notices.
void main() {
  group('SectionHeader', () {
    testWidgets('is an eyebrow in gold ink, and a heading of its level', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpThemed(tester, const Column(children: [SectionHeader('Torah map'), SectionHeader('Rashi', level: 3)]));
      final context = tester.element(find.byType(SectionHeader).first);
      expect(find.byType(Eyebrow), findsNWidgets(2));
      final style = tester.widget<Text>(find.text('Torah map')).style;
      expect(style, SeferType.of(context).eyebrow);
      expect(style?.color, Palettes.light.secondary);
      for (final (text, level) in [('Torah map', 2), ('Rashi', 3)]) {
        final node = tester.getSemantics(find.text(text));
        expect(node, isSemantics(label: text, isHeader: true));
        expect(node.getSemanticsData().headingLevel, level);
      }
      handle.dispose();
    });

    testWidgets('keeps a control at its end', (tester) async {
      await pumpThemed(
        tester,
        SectionHeader('This week', trailing: IconButton(onPressed: () {}, icon: const Icon(Icons.info_outline))),
      );
      expect(
        tester.getRect(find.byType(IconButton)).right,
        tester.getRect(find.byType(SectionHeader)).right,
      );
    });

    testWidgets('in plain type for digits, which an eyebrow never holds', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpThemed(tester, const SectionHeader.plain('2 of 7 aliyot'));
      expect(find.byType(Eyebrow), findsNothing);
      final context = tester.element(find.byType(SectionHeader));
      final style = tester.widget<Text>(find.text('2 of 7 aliyot')).style;
      expect(style?.fontSize, Theme.of(context).textTheme.titleSmall?.fontSize);
      expect(style?.color, Palettes.light.onSurfaceVariant);
      expect(tester.getSemantics(find.text('2 of 7 aliyot')).getSemanticsData().headingLevel, 2);
      handle.dispose();
    });
  });

  group('NoticeBanner', () {
    ShapeBorder? shapeOf(WidgetTester tester) =>
        tester.widget<Card>(find.descendant(of: find.byType(NoticeBanner), matching: find.byType(Card))).shape;

    testWidgets('is a gold wash with rounded corners and no border', (tester) async {
      await pumpThemed(tester, const NoticeBanner(icon: Icons.info_outline, text: 'Notice'));
      final card = tester.widget<Card>(find.descendant(of: find.byType(NoticeBanner), matching: find.byType(Card)));
      expect(card.color, Palettes.light.secondaryContainer);
      expect(
        shapeOf(tester),
        const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(12)), side: BorderSide.none),
      );
      final context = tester.element(find.byType(NoticeBanner));
      final text = tester.widget<Text>(find.text('Notice')).style;
      expect(text?.fontSize, Theme.of(context).textTheme.bodyMedium?.fontSize);
      expect(text?.color, Palettes.light.onSecondaryContainer);
      final icon = tester.widget<Icon>(find.byIcon(Icons.info_outline));
      expect((icon.size, icon.color), (20, Palettes.light.onSecondaryContainer));
      // 16 in from the start.
      final banner = tester.getRect(find.byType(NoticeBanner));
      final glyph = tester.getRect(find.byIcon(Icons.info_outline));
      expect(glyph.left - banner.left, 16);
    });

    testWidgets('is outlined 2 px in high contrast', (tester) async {
      await pumpThemed(
        tester,
        const NoticeBanner(icon: Icons.info_outline, text: 'Notice'),
        theme: AppThemeMode.highContrastDark,
      );
      expect(
        shapeOf(tester),
        RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(12)),
          side: BorderSide(color: Palettes.hcDark.outline, width: 2),
        ),
      );
    });
  });
}
