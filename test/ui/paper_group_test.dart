import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/ui/theme/app_theme.dart';
import 'package:shnayim_mikra/ui/theme/palette.dart';
import 'package:shnayim_mikra/ui/widgets/common.dart';
import 'package:shnayim_mikra/ui/widgets/ornaments.dart';
import 'package:shnayim_mikra/ui/widgets/paper_group.dart';

import '../helpers.dart';

/// docs/DESIGN_SYSTEM.md §6.3 and §6.22: paper groups and their rows, group
/// headers and empty states, in both text directions.
void main() {
  const light = Palettes.seferLight;

  /// A group of a two-line row, a row with a value, and a plain row, 400 wide.
  Future<List<String>> pumpGroup(WidgetTester tester, {bool hebrew = false, double textScale = 1}) async {
    final taps = <String>[];
    await pumpThemed(
      tester,
      Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: 400,
          child: PaperGroup(
            children: [
              PaperRow(
                icon: Icons.menu_book_outlined,
                title: 'Reading',
                subtitle: 'Location and plan',
                onTap: () => taps.add('reading'),
              ),
              PaperRow(
                icon: Icons.translate_outlined,
                title: 'Language',
                value: 'Device',
                onTap: () => taps.add('language'),
              ),
              const PaperRow(title: 'Version'),
            ],
          ),
        ),
      ),
      hebrew: hebrew,
      textScale: textScale,
    );
    return taps;
  }

  Finder row(int i) => find.byType(PaperRow).at(i);

  for (final hebrew in [false, true]) {
    final ltr = !hebrew;
    group(hebrew ? 'right to left' : 'left to right', () {
      testWidgets('rows are 56 high, or 72 and up with a subtitle', (tester) async {
        await pumpGroup(tester, hebrew: hebrew);
        // The Hebrew text theme's lines are taller: 26 + 24 + 24.
        expect(tester.getSize(row(0)).height, hebrew ? 74 : 72);
        expect(tester.getSize(row(1)).height, 56);
        expect(tester.getSize(row(2)).height, 56);
      });

      testWidgets('the icon leads and the chevron ends, mirrored', (tester) async {
        await pumpGroup(tester, hebrew: hebrew);
        final group = tester.getRect(find.byType(PaperGroup));
        double fromStart(Finder f) {
          final r = tester.getRect(f);
          return ltr ? r.left - group.left : group.right - r.right;
        }

        final icon = find.byIcon(Icons.menu_book_outlined);
        expect(tester.widget<Icon>(icon).size, 22);
        expect(tester.widget<Icon>(icon).color, Palettes.light.onSurfaceVariant);
        expect(fromStart(icon), 16);
        // The text starts after the 38 slot.
        expect(fromStart(find.text('Reading')), 16 + 38);
        expect(fromStart(find.text('Version')), 16);

        final chevrons = find.byIcon(Icons.chevron_right);
        expect(chevrons, findsNWidgets(2), reason: 'only the rows that can be tapped');
        expect(tester.widget<Icon>(chevrons.first).size, 20);
        expect(tester.widget<Icon>(chevrons.first).color, Palettes.light.outline);
        // Drawn mirrored in Hebrew, so it points along the reading direction.
        expect(Icons.chevron_right.matchTextDirection, isTrue);
        final end = ltr ? group.right - tester.getRect(chevrons.first).right : tester.getRect(chevrons.first).left - group.left;
        expect(end, 12);

        // The value sits just before the chevron.
        final value = tester.getRect(find.text('Device'));
        final chevron = tester.getRect(chevrons.last);
        expect(ltr ? chevron.left - value.right : value.left - chevron.right, 4);
      });

      testWidgets('hairlines run from the text to the end edge', (tester) async {
        await pumpGroup(tester, hebrew: hebrew);
        final rules = find.byWidgetPredicate((w) => w is CustomPaint && w.child is PaperRow);
        expect(rules, findsNWidgets(2), reason: 'none under the last row');
        final height = tester.getSize(row(0)).height;
        // Inset 54 under a row with an icon; 16 under one without.
        expect(
          tester.renderObject(rules.first),
          paints
            ..rect(
              rect: ltr ? Rect.fromLTRB(54, height - 1, 400, height) : Rect.fromLTRB(0, height - 1, 400 - 54, height),
              color: light.hairline,
            ),
        );
      });

      testWidgets('each row rounds its ink to the card corners it touches', (tester) async {
        await pumpGroup(tester, hebrew: hebrew);
        const r = Radius.circular(12);
        final wells = tester.widgetList<SeferInkWell>(find.byType(SeferInkWell)).toList();
        expect(wells.map((w) => w.borderRadius), [
          const BorderRadius.vertical(top: r),
          BorderRadius.zero,
        ]);
        // The card doesn't clip, so a focus ring shows whole.
        expect(tester.widget<Card>(find.byType(Card)).clipBehavior, Clip.none);
      });
    });
  }

  testWidgets('a group of rows without icons insets its hairlines 16', (tester) async {
    await pumpThemed(
      tester,
      const SizedBox(
        width: 400,
        child: PaperGroup(children: [PaperRow(title: 'One'), PaperRow(title: 'Two')]),
      ),
    );
    expect(
      tester.renderObject(find.byWidgetPredicate((w) => w is CustomPaint && w.child is PaperRow)),
      paints..rect(rect: const Rect.fromLTRB(16, 55, 400, 56)),
    );
  });

  testWidgets('high contrast: 2 px hairlines in the outline colour', (tester) async {
    await pumpThemed(
      tester,
      const SizedBox(
        width: 400,
        child: PaperGroup(children: [PaperRow(title: 'One'), PaperRow(title: 'Two')]),
      ),
      theme: AppThemeMode.highContrastDark,
    );
    expect(
      tester.renderObject(find.byWidgetPredicate((w) => w is CustomPaint && w.child is PaperRow)),
      paints..rect(rect: const Rect.fromLTRB(16, 54, 400, 56), color: Palettes.hcDark.outline),
    );
  });

  testWidgets('rows are tapped, and read as one button each', (tester) async {
    final handle = tester.ensureSemantics();
    final taps = await pumpGroup(tester);
    await tester.tap(find.text('Language'));
    expect(taps, ['language']);
    expect(
      tester.getSemantics(row(0)),
      isSemantics(label: 'Reading\nLocation and plan', isButton: true, hasTapAction: true),
    );
    expect(tester.getSemantics(row(1)), isSemantics(label: 'Language\nDevice', isButton: true));
    expect(tester.getSemantics(row(2)), isSemantics(label: 'Version', isButton: false, hasTapAction: false));
    handle.dispose();
  });

  testWidgets('a trailing control keeps its own item, so the row and the control can both be reached',
      (tester) async {
    final handle = tester.ensureSemantics();
    final taps = <String>[];
    await pumpThemed(
      tester,
      SizedBox(
        width: 400,
        child: PaperGroup(children: [
          PaperRow(
            title: 'Rishon',
            subtitle: 'Genesis 1:1–2:3',
            onTap: () => taps.add('row'),
            trailing: IconButton(
              tooltip: 'More options',
              icon: const Icon(Icons.more_vert),
              onPressed: () => taps.add('menu'),
            ),
          ),
        ]),
      ),
    );
    final row = tester.getSemantics(find.byType(PaperRow));
    final menu = tester.getSemantics(find.byType(IconButton));
    expect(row, isSemantics(label: 'Rishon\nGenesis 1:1–2:3', isButton: true, hasTapAction: true));
    expect(menu, isSemantics(tooltip: 'More options', isButton: true, hasTapAction: true));
    expect(menu.id, isNot(row.id));

    // A screen reader's double tap on each item does what it says.
    final owner = tester.binding.pipelineOwner.semanticsOwner!;
    owner.performAction(row.id, SemanticsAction.tap);
    owner.performAction(menu.id, SemanticsAction.tap);
    await tester.pump();
    expect(taps, ['row', 'menu']);
    handle.dispose();
  });

  testWidgets('a switch the row toggles reads as part of it', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpThemed(
      tester,
      SizedBox(
        width: 400,
        child: PaperGroup(children: [
          PaperRow(
            title: 'Show streak numbers',
            onTap: () {},
            chevron: false,
            mergeTrailing: true,
            trailing: Switch(value: true, onChanged: (_) {}),
          ),
        ]),
      ),
    );
    final row = tester.getSemantics(find.byType(PaperRow));
    expect(row, isSemantics(label: 'Show streak numbers', hasToggledState: true, isToggled: true, hasTapAction: true));
    expect(tester.getSemantics(find.byType(Switch)).id, row.id);
    handle.dispose();
  });

  for (final hebrew in [false, true]) {
    testWidgets('${hebrew ? 'he' : 'en'}: with a subtitle, the icon, value and chevron share the title\'s line',
        (tester) async {
      await pumpThemed(
        tester,
        Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 400,
            child: PaperRow(
              icon: Icons.translate_outlined,
              title: 'Language',
              subtitle: 'For menus and buttons',
              value: 'English',
              onTap: () {},
            ),
          ),
        ),
        hebrew: hebrew,
      );
      final title = tester.getCenter(find.text('Language')).dy;
      expect(tester.getCenter(find.text('English')).dy, moreOrLessEquals(title, epsilon: 0.5));
      expect(tester.getCenter(find.byIcon(Icons.chevron_right)).dy, moreOrLessEquals(title, epsilon: 0.5));
      expect(tester.getCenter(find.byIcon(Icons.translate_outlined)).dy, moreOrLessEquals(title, epsilon: 0.5));
      // And still 4 apart.
      final value = tester.getRect(find.text('English'));
      final chevron = tester.getRect(find.byIcon(Icons.chevron_right));
      expect(hebrew ? value.left - chevron.right : chevron.left - value.right, 4);
      final subtitle = tester.getRect(find.text('For menus and buttons'));
      expect(subtitle.top, greaterThanOrEqualTo(tester.getRect(find.text('Language')).bottom));
    });
  }

  testWidgets('a value moves under the title rather than squeeze it, at 200%', (tester) async {
    await pumpGroup(tester);
    // On the title's line while they fit.
    expect(tester.getCenter(find.text('Device')).dy, tester.getCenter(find.text('Language')).dy);

    await pumpThemed(
      tester,
      SizedBox(
        width: 320,
        child: PaperGroup(
          children: [
            PaperRow(icon: Icons.translate_outlined, title: 'Language', value: 'Device language', onTap: () {}),
          ],
        ),
      ),
      textScale: 2,
    );
    expect(tester.takeException(), isNull);
    final title = tester.getRect(find.text('Language'));
    final value = tester.getRect(find.text('Device language'));
    expect(value.top, greaterThanOrEqualTo(title.bottom));
    expect(value.left, title.left);
  });

  testWidgets('a subtitle stops at two lines, unless the text is enlarged', (tester) async {
    final long = List.filled(4, 'Location and plan').join(', ');
    Future<int?> maxLines(double scale) async {
      await pumpThemed(
        tester,
        Align(
          alignment: Alignment.topCenter,
          child: SizedBox(width: 400, child: PaperRow(title: 'Reading', subtitle: long)),
        ),
        textScale: scale,
      );
      expect(tester.takeException(), isNull);
      return tester.widget<Text>(find.text(long)).maxLines;
    }

    expect(await maxLines(1), 2);
    expect(await maxLines(2), isNull);
  });

  group('GroupHeader', () {
    for (final hebrew in [false, true]) {
      testWidgets('an eyebrow heading, 28 above, 8 below, inset 4 (${hebrew ? 'he' : 'en'})', (tester) async {
        final handle = tester.ensureSemantics();
        await pumpThemed(
          tester,
          const Align(alignment: Alignment.topCenter, child: GroupHeader('Practice')),
          hebrew: hebrew,
        );
        final header = tester.getRect(find.byType(GroupHeader));
        final text = tester.getRect(find.byType(Eyebrow));
        expect(text.top - header.top, 28);
        expect(header.bottom - text.bottom, 8);
        expect(hebrew ? header.right - text.right : text.left - header.left, 4);

        final node = tester.getSemantics(find.byType(Eyebrow));
        expect(node.flagsCollection.isHeader, isTrue);
        expect(node.headingLevel, 2);
        handle.dispose();
      });
    }
  });

  group('EmptyState', () {
    testWidgets('a divider, one sentence and a tonal action, centred and at most 320 wide', (tester) async {
      var tapped = false;
      await pumpThemed(
        tester,
        Align(
          alignment: Alignment.topCenter,
          child: EmptyState(
            message: 'No discussions yet — begin the first.',
            actionLabel: 'New discussion',
            onAction: () => tapped = true,
          ),
        ),
      );
      final page = tester.getRect(find.byType(Scaffold));
      final divider = tester.getRect(find.byType(SeferDivider));
      final message = tester.getRect(find.text('No discussions yet — begin the first.'));
      final button = find.widgetWithText(FilledButton, 'New discussion');

      expect(divider.top - page.top, 40);
      expect(divider.width, 320, reason: 'the divider takes 45% of this column');
      expect(tester.getSize(find.descendant(of: find.byType(SeferDivider), matching: find.byType(CustomPaint))).width,
          0.45 * 320);
      expect(message.top - divider.bottom, 12);
      expect(tester.getRect(button).top - message.bottom, 16);
      expect(divider.center.dx, page.center.dx);
      expect(message.center.dx, closeTo(page.center.dx, 0.01));

      final context = tester.element(find.byType(EmptyState));
      expect(tester.widget<Text>(find.text('No discussions yet — begin the first.')).style, SeferType.of(context).marginalia);
      // Tonal: the primary container, never Material's secondary (gold).
      final material = tester.widget<Material>(find.descendant(of: button, matching: find.byType(Material)));
      expect(material.color, Palettes.light.primaryContainer);

      await tester.tap(button);
      expect(tapped, isTrue);
    });

    testWidgets('has no button without an action', (tester) async {
      await pumpThemed(tester, const EmptyState(message: 'Nothing here yet.'));
      expect(find.byType(FilledButton), findsNothing);
      expect(find.text('Nothing here yet.'), findsOneWidget);
    });
  });
}
