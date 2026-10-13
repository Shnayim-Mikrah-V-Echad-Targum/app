import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikrah/features/settings/app_settings.dart';
import 'package:shnayim_mikrah/ui/theme/palette.dart';
import 'package:shnayim_mikrah/ui/theme/typography.dart';
import 'package:shnayim_mikrah/ui/widgets/common.dart';
import 'package:shnayim_mikrah/ui/widgets/ornaments.dart';

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

    testWidgets('can carry a title over its text, both in its ink, beside the icon', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpThemed(
        tester,
        const NoticeBanner(icon: Icons.schedule, title: 'Bereshit is still open', text: 'Finish by Tuesday.'),
      );
      final context = tester.element(find.byType(NoticeBanner));
      final title = tester.widget<Text>(find.text('Bereshit is still open')).style;
      expect(title?.fontSize, Theme.of(context).textTheme.titleSmall?.fontSize);
      expect(title?.color, Palettes.light.onSecondaryContainer);
      expect(tester.getTopLeft(find.text('Finish by Tuesday.')).dy,
          tester.getBottomLeft(find.text('Bereshit is still open')).dy);
      // The icon beside the title's line, not the middle of both.
      expect(tester.getCenter(find.byIcon(Icons.schedule)).dy,
          closeTo(tester.getCenter(find.text('Bereshit is still open')).dy, 1));
      // The notice's heading, which a screen reader can move to.
      expect(tester.getSemantics(find.text('Bereshit is still open')), isSemantics(isHeader: true));
      expect(tester.getSemantics(find.text('Finish by Tuesday.')), isNot(isSemantics(isHeader: true)));
      handle.dispose();
    });

    testWidgets('starts no line with a dash: each spaced dash is held to the word before it', (tester) async {
      // The Hebrew preview notice at 300% broke after "מקדימה", leaving the
      // dash to start the next line.
      await pumpThemed(
        tester,
        const SizedBox(
          width: 200,
          child: NoticeBanner(icon: Icons.visibility_outlined, text: 'תצוגה מקדימה — הפרשה נפתחת לרישום'),
        ),
        hebrew: true,
        textScale: 2,
      );
      final text = tester.widget<Text>(find.descendant(of: find.byType(NoticeBanner), matching: find.byType(Text)));
      expect(text.data, 'תצוגה מקדימה\u00A0— הפרשה נפתחת לרישום');
    });

    testWidgets('can be put away with a close button at its top end', (tester) async {
      var dismissed = 0;
      await pumpThemed(
        tester,
        NoticeBanner(
          icon: Icons.play_circle_outline,
          title: 'Welcome back',
          text: 'Your pause has ended.',
          onDismiss: () => dismissed++,
          dismissLabel: 'Dismiss',
        ),
      );
      final close = find.byTooltip('Dismiss');
      expect(close, findsOneWidget);
      expect(tester.getSize(find.byType(IconButton)), const Size(48, 48), reason: 'a 48 dp target');
      // On the title's line, at the end.
      expect(tester.getCenter(find.byIcon(Icons.close)).dy, closeTo(tester.getCenter(find.text('Welcome back')).dy, 3));
      expect(tester.getRect(find.byType(NoticeBanner)).right - tester.getRect(find.byType(IconButton)).right, 4);
      await tester.tap(close);
      expect(dismissed, 1);
    });

    testWidgets('puts its close button at the top end in Hebrew too, on the left', (tester) async {
      await pumpThemed(
        tester,
        NoticeBanner(
          icon: Icons.play_circle_outline,
          title: 'ברוכים השבים',
          text: 'ההשהיה הסתיימה.',
          onDismiss: () {},
          dismissLabel: 'סגירה',
        ),
        hebrew: true,
      );
      final banner = tester.getRect(find.byType(NoticeBanner));
      final button = tester.getRect(find.byType(IconButton));
      expect(button.left - banner.left, 4, reason: 'at the end, which is the left');
      expect(tester.getCenter(find.byIcon(Icons.close)).dy, closeTo(tester.getCenter(find.text('ברוכים השבים')).dy, 3));
      // The icon at the start, on the right, and the title beside it.
      final icon = tester.getRect(find.byIcon(Icons.play_circle_outline));
      expect(banner.right - icon.right, 16);
      expect(tester.getRect(find.text('ברוכים השבים')).right, lessThan(icon.left));
      expect(tester.getRect(find.text('ברוכים השבים')).left, greaterThan(button.right - 1));
    });

    testWidgets('can set its text as marginalia in its ink, the icon on the first line', (tester) async {
      await pumpThemed(
        tester,
        const SizedBox(
          width: 300,
          child: NoticeBanner(
            icon: Icons.handshake_outlined,
            marginalia: true,
            text: 'Shnayim Mikrah runs on the honor system. Log what you read, wherever you read it.',
          ),
        ),
      );
      final context = tester.element(find.byType(NoticeBanner));
      final text = find.textContaining('honor system');
      final style = tester.widget<Text>(text).style!;
      final marginalia = SeferType.of(context).marginalia;
      expect(
        (style.fontFamily, style.fontSize, style.fontStyle),
        (marginalia.fontFamily, marginalia.fontSize, marginalia.fontStyle),
      );
      expect(style.color, Palettes.light.onSecondaryContainer);
      // Several lines, with the icon beside the first of them.
      final line = marginalia.fontSize! * marginalia.height!;
      final box = tester.getRect(text);
      expect(box.height, greaterThan(line * 1.5));
      expect(tester.getCenter(find.byIcon(Icons.handshake_outlined)).dy, closeTo(box.top + line / 2, 1));
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

    // A dialog sets its content at its intrinsic width; the balanced title
    // answers it, as the plain text did before.
    testWidgets('with a title, and a sheet title, may stand in a dialog', (tester) async {
      await pumpThemed(
        tester,
        const AlertDialog(
          title: SheetTitle('Shavua tov! Did you read Bereshit on Shabbat?'),
          content: NoticeBanner(
            icon: Icons.schedule,
            title: 'Shavua tov! Did you read Bereshit on Shabbat?',
            text: 'Finish by Tuesday.',
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      expect(find.text('Finish by Tuesday.'), findsOneWidget);
    });
  });
}
