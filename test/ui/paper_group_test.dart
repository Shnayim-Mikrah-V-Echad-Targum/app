import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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

  testWidgets('rows of another kind inset their hairlines where the group is told', (tester) async {
    await pumpThemed(
      tester,
      const SizedBox(
        width: 400,
        child: PaperGroup(ruleInset: 72, children: [SizedBox(height: 84), SizedBox(height: 84)]),
      ),
      hebrew: true,
    );
    // Mirrored in Hebrew, where the text starts at the right.
    expect(
      tester.renderObject(find.byWidgetPredicate((w) => w is CustomPaint && w.child is SizedBox)),
      paints..rect(rect: const Rect.fromLTRB(0, 83, 400 - 72, 84)),
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
    tester.semantics.tap(find.semantics.byPredicate((node) => node.id == row.id));
    tester.semantics.tap(find.semantics.byPredicate((node) => node.id == menu.id));
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
    expect(
      row,
      isSemantics(label: 'Show streak numbers', hasToggledState: true, isToggled: true, hasTapAction: true),
    );
    // A switch, in the switch's role rather than a button's.
    expect(row, isSemantics(isButton: false));
    expect(tester.getSemantics(find.byType(Switch)).id, row.id);
    handle.dispose();
  });

  testWidgets('the row that erases is set in error ink, and a live row is read out as it changes', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpThemed(
      tester,
      SizedBox(
        width: 400,
        child: PaperGroup(children: [
          PaperRow(title: 'Reset all progress', destructive: true, chevron: false, onTap: () {}),
          PaperRow(title: 'Daily reminder time', value: '7:30 AM', liveRegion: true, onTap: () {}),
        ]),
      ),
    );
    final scheme = Theme.of(tester.element(find.byType(PaperGroup))).colorScheme;
    expect(tester.widget<Text>(find.text('Reset all progress')).style?.color, scheme.error);
    expect(find.descendant(of: find.byType(PaperRow).first, matching: find.byType(Icon)), findsNothing);
    expect(tester.getSemantics(find.text('Daily reminder time')), isSemantics(isLiveRegion: true, isButton: true));
    expect(tester.getSemantics(find.text('Reset all progress')), isSemantics(isLiveRegion: false));
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

  testWidgets('with a detail line and no subtitle, the value and chevron still share the title\'s line, 72 high',
      (tester) async {
    await pumpThemed(
      tester,
      Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: 400,
          child: PaperRow(
            icon: Icons.forum_outlined,
            title: 'Forums',
            detail: '12 discussions',
            value: 'New',
            onTap: () {},
          ),
        ),
      ),
    );
    final title = tester.getCenter(find.text('Forums')).dy;
    expect(tester.getCenter(find.text('New')).dy, moreOrLessEquals(title, epsilon: 0.5));
    expect(tester.getCenter(find.byIcon(Icons.chevron_right)).dy, moreOrLessEquals(title, epsilon: 0.5));
    expect(tester.getCenter(find.byIcon(Icons.forum_outlined)).dy, moreOrLessEquals(title, epsilon: 0.5));
    expect(tester.getSize(find.byType(PaperRow)).height, greaterThanOrEqualTo(72));
  });

  for (final hebrew in [false, true]) {
    testWidgets('${hebrew ? 'he' : 'en'}: with a detail line, the icon and chevron share the title\'s line, '
        'rather than the middle of the row', (tester) async {
      Future<void> pumpRow({String? detail}) => pumpThemed(
            tester,
            Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: 400,
                child: PaperRow(
                  icon: Icons.auto_stories_outlined,
                  title: 'Haftarah',
                  subtitle: 'I Samuel 20:18–42',
                  detail: detail,
                  onTap: () {},
                ),
              ),
            ),
            hebrew: hebrew,
          );

      await pumpRow(detail: 'Shabbat Machar Chodesh');
      final title = tester.getRect(find.text('Haftarah'));
      final icon = tester.getRect(find.byIcon(Icons.auto_stories_outlined));
      final chevron = tester.getRect(find.byIcon(Icons.chevron_right));
      expect(icon.center.dy, moreOrLessEquals(title.center.dy, epsilon: 0.5));
      expect(chevron.center.dy, moreOrLessEquals(title.center.dy, epsilon: 0.5));
      // Still at the row's start and end.
      final row = tester.getRect(find.byType(PaperRow));
      expect(hebrew ? row.right - icon.right : icon.left - row.left, 16);
      expect(hebrew ? chevron.left - row.left : row.right - chevron.right, 12);
      expect(icon.center.dy, lessThan(row.center.dy - 10), reason: 'not centred on the three lines');

      // With a title and a subtitle alone, both are centred on the row, as
      // its two lines are.
      await pumpRow();
      final middle = tester.getRect(find.byType(PaperRow)).center.dy;
      expect(tester.getCenter(find.byIcon(Icons.auto_stories_outlined)).dy, moreOrLessEquals(middle, epsilon: 0.5));
      expect(tester.getCenter(find.byIcon(Icons.chevron_right)).dy, moreOrLessEquals(middle, epsilon: 0.5));
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

  // The Haftarah row for Chabad on Shabbat Machar Chodesh: at 300% on a
  // small phone, "Samuel", "Chodesh" and "haftarah" are wider than a row's
  // text beside its icon and chevron.
  testWidgets('enlarged, a subtitle and a detail line keep each word whole', (tester) async {
    const subtitle = 'I Samuel 20:18–42';
    const detail = 'Shabbat Machar Chodesh · Chabad custom: the regular haftarah too';
    await pumpThemed(
      tester,
      const Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: 280,
          child: PaperRow(icon: Icons.auto_stories_outlined, title: 'Haftarah', subtitle: subtitle, detail: detail),
        ),
      ),
      textScale: 3,
    );
    expect(tester.takeException(), isNull);
    expectWordsWhole(tester, subtitle);
    expectWordsWhole(tester, detail);
  });

  testWidgets('a row may set its title and subtitle in other styles, as the forums do', (tester) async {
    late TextTheme text;
    await pumpThemed(
      tester,
      Builder(builder: (context) {
        text = Theme.of(context).textTheme;
        return Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 400,
            child: PaperRow(
              icon: Icons.help_outline,
              title: 'Questions & answers',
              titleStyle: text.titleMedium,
              subtitle: 'Ask about a verse, a Targum or a Rashi.',
              subtitleStyle: text.bodySmall,
              onTap: () {},
            ),
          ),
        );
      }),
    );
    expect(tester.widget<Text>(find.text('Questions & answers')).style, text.titleMedium);
    expect(tester.widget<Text>(find.text('Ask about a verse, a Targum or a Rashi.')).style, text.bodySmall);
  });

  testWidgets('rows built on their own, for a list built as it scrolls, lay out as a group does', (tester) async {
    List<Widget> rows() => [
          for (final title in ['Rishon', 'Sheni', 'Shlishi']) PaperRow(icon: Icons.menu_book_outlined, title: title, onTap: () {}),
        ];
    await pumpThemed(tester, Align(alignment: Alignment.topCenter, child: SizedBox(width: 400, child: PaperGroup(children: rows()))));
    final grouped = [for (final t in ['Rishon', 'Sheni', 'Shlishi']) tester.getRect(find.text(t))];
    final height = tester.getSize(find.byType(PaperGroup)).height;

    final corners = <BorderRadius>[];
    await pumpThemed(
      tester,
      Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          width: 400,
          child: Column(
            key: const Key('rows'),
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (i, row) in rows().indexed)
                PaperGroupRow(
                  first: i == 0,
                  last: i == 2,
                  child: Builder(builder: (context) {
                    corners.add(PaperGroup.rowCorners(context));
                    return row;
                  }),
                ),
            ],
          ),
        ),
      ),
    );
    expect([for (final t in ['Rishon', 'Sheni', 'Shlishi']) tester.getRect(find.text(t))], grouped);
    expect(tester.getSize(find.byKey(const Key('rows'))).height, height);
    // Each rounds its ink and ring to the corners of the card it shares.
    expect(corners, [
      const BorderRadius.vertical(top: Radius.circular(12)),
      BorderRadius.zero,
      const BorderRadius.vertical(bottom: Radius.circular(12)),
    ]);
  });

  testWidgets('a row built on its own keeps its focus ring whole over the row below it', (tester) async {
    FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional;
    addTearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);
    const titles = ['Rishon', 'Sheni', 'Shlishi'];
    await pumpThemed(
      tester,
      Align(
        alignment: Alignment.topCenter,
        child: RepaintBoundary(
          key: const Key('rows'),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (i, title) in titles.indexed)
                    PaperGroupRow(first: i == 0, last: i == 2, child: PaperRow(title: title, onTap: () {})),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    // The keyboard's focus on the middle row.
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    final boundary = tester.renderObject<RenderRepaintBoundary>(find.byKey(const Key('rows')));
    final image = (await tester.runAsync(() => boundary.toImage()))!;
    final data = (await tester.runAsync(() => image.toByteData(format: ui.ImageByteFormat.rawRgba)))!;
    Color pixel(Offset global) {
      final p = boundary.globalToLocal(global);
      final i = (p.dy.floor() * image.width + p.dx.floor()) * 4;
      return Color.fromARGB(data.getUint8(i + 3), data.getUint8(i), data.getUint8(i + 1), data.getUint8(i + 2));
    }

    final row = tester.getRect(find.byType(PaperGroupRow).at(1));
    // The ring, 3 px wide outside the row: over the row above it, which is
    // painted before it, and over the row below it, which is painted after.
    expect(pixel(Offset(row.center.dx, row.top - 1.5)), light.focus);
    expect(pixel(Offset(row.center.dx, row.bottom + 1.5)), light.focus);
    // Below the ring, the next row's paper as ever.
    expect(pixel(Offset(row.center.dx, row.bottom + 8)), light.paper);
    image.dispose();
  });

  testWidgets('a style given in part keeps the rest of the row\'s own', (tester) async {
    await pumpThemed(
      tester,
      const SizedBox(
        width: 400,
        child: PaperRow(
          title: 'Reading',
          titleStyle: TextStyle(fontWeight: FontWeight.w700),
          subtitle: 'Location and plan',
          subtitleStyle: TextStyle(fontStyle: FontStyle.italic),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    final context = tester.element(find.byType(PaperRow));
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final title = tester.widget<Text>(find.text('Reading')).style!;
    expect((title.fontSize, title.fontWeight, title.color), (text.bodyLarge!.fontSize, FontWeight.w700, scheme.onSurface));
    final subtitle = tester.widget<Text>(find.text('Location and plan')).style!;
    expect((subtitle.fontSize, subtitle.fontStyle, subtitle.color), (text.bodyMedium!.fontSize, FontStyle.italic, scheme.onSurfaceVariant));
  });

  for (final hebrew in [false, true]) {
    testWidgets('${hebrew ? 'he' : 'en'}: a labelled button ends the title\'s line, or goes under it at 200%', (tester) async {
      // In the test font, whose every letter is as wide as it is high.
      Future<void> pump(double textScale) => pumpThemed(
            tester,
            Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                width: textScale == 1 ? 700 : 400,
                child: PaperGroup(children: [
                  PaperRow(
                    icon: Icons.shield_outlined,
                    title: '1 grace day available',
                    trailing: TextButton(onPressed: () {}, child: const Text('About streaks')),
                  ),
                ]),
              ),
            ),
            hebrew: hebrew,
            textScale: textScale,
          );
      await pump(1);
      final title = tester.getRect(find.text('1 grace day available'));
      final button = tester.getRect(find.byType(TextButton));
      expect(button.center.dy, moreOrLessEquals(title.center.dy, epsilon: 0.5));
      // At the row's end, 12 in, as a trailing control ends.
      final row = tester.getRect(find.byType(PaperRow));
      expect(hebrew ? button.left - row.left : row.right - button.right, 12);

      await pump(2);
      expect(tester.takeException(), isNull);
      final paragraph = tester.renderObject<RenderParagraph>(find.text('1 grace day available'));
      expect(paragraph.size.width, greaterThanOrEqualTo(paragraph.getMinIntrinsicWidth(double.infinity) - 0.5),
          reason: 'no word broken');
      expect(tester.getRect(find.byType(TextButton)).top, greaterThanOrEqualTo(tester.getRect(find.text('1 grace day available')).bottom - 1));
    });
  }

  testWidgets('the help icon keeps its question mark the right way round in Hebrew', (tester) async {
    await pumpThemed(tester, const PaperRow(icon: Icons.help_outline, title: 'שאלות ותשובות'), hebrew: true);
    final icon = find.byIcon(Icons.help_outline);
    expect(tester.widget<Icon>(icon).textDirection, TextDirection.ltr);
    expect(find.descendant(of: icon, matching: find.byType(Transform)), findsNothing);
  });

  // The haftarah of Re'eh for Sephardim on Rosh Chodesh Elul: its own, with
  // the first and last verses of two more.
  testWidgets('a subtitle that is never cut short, as a long reference, can be let run', (tester) async {
    const reference = 'Isaiah 54:11–\u206055:5\u00A0· Isaiah 66:1\u00A0· Isaiah 66:23\u00A0· '
        'I\u00A0Samuel 20:18\u00A0· I\u00A0Samuel 20:42';
    await pumpThemed(
      tester,
      const Align(
        alignment: Alignment.topCenter,
        child: SizedBox(width: 300, child: PaperRow(title: 'Haftarah', subtitle: reference, subtitleMaxLines: null)),
      ),
    );
    final text = tester.widget<Text>(find.text(reference));
    expect((text.maxLines, text.overflow), (null, null));
    final paragraph = tester.renderObject<RenderParagraph>(
      find.descendant(of: find.text(reference), matching: find.byType(RichText)),
    );
    final boxes = paragraph.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: reference.length));
    final lines = {for (final box in boxes) box.top.round()};
    expect(lines.length, greaterThan(2), reason: 'more than the two lines a subtitle keeps to by default');
    expect(paragraph.didExceedMaxLines, isFalse, reason: 'every line shows');
  });

  group('at large text sizes', () {
    /// The size [text] is drawn at in the row around it: its style, scaled
    /// as the text is, and as much again as it is set smaller to keep a
    /// long word whole.
    double drawnSize(WidgetTester tester, String text) {
      final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
      final row = tester.renderObject(find.ancestor(of: find.text(text), matching: find.byType(PaperRow)).first);
      final transform = paragraph.getTransformTo(row);
      return paragraph.textScaler.scale(paragraph.text.style!.fontSize!) *
          Offset(transform.entry(0, 0), transform.entry(1, 0)).distance;
    }

    /// A group [width] wide (the card of a 320 dp phone is 280) of [rows].
    Future<void> pumpRows(WidgetTester tester, List<Widget> rows,
            {double width = 280, double textScale = 3, bool hebrew = false, double? ruleInset}) =>
        pumpThemed(
          tester,
          Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: width,
              child: SingleChildScrollView(child: PaperGroup(ruleInset: ruleInset, children: rows)),
            ),
          ),
          textScale: textScale,
          hebrew: hebrew,
        );

    for (final hebrew in [false, true]) {
      testWidgets('${hebrew ? 'he' : 'en'}: on a small phone at 300%, a row stacks, its icon and chevron over the '
          'title and the text its full width', (tester) async {
        await pumpRows(tester, hebrew: hebrew, [
          PaperRow(icon: Icons.menu_book_outlined, title: 'Read', subtitle: 'Plan', onTap: () {}),
          const PaperRow(title: 'Last'),
        ]);
        expect(tester.takeException(), isNull);
        final row = tester.getRect(find.byType(PaperRow).first);
        double fromStart(Rect r) => hebrew ? row.right - r.right : r.left - row.left;
        double fromEnd(Rect r) => hebrew ? r.left - row.left : row.right - r.right;
        final icon = tester.getRect(find.byIcon(Icons.menu_book_outlined));
        final chevron = tester.getRect(find.byIcon(Icons.chevron_right));
        final title = tester.getRect(find.text('Read'));
        final subtitle = tester.getRect(find.text('Plan'));
        // The icon grows with the text, to 1.5× at most.
        expect(tester.widget<Icon>(find.byIcon(Icons.menu_book_outlined)).size, 33);
        expect(fromStart(icon), 16);
        expect(chevron.center.dy, moreOrLessEquals(icon.center.dy, epsilon: 0.5));
        expect(fromEnd(chevron), 12);
        expect(title.top, greaterThanOrEqualTo(icon.bottom));
        expect(fromStart(title), 16);
        expect(fromStart(subtitle), 16);
        expect(subtitle.top, greaterThanOrEqualTo(title.bottom));
        // The hairline starts where all the row's text now does.
        expect(
          tester.renderObject(find.byWidgetPredicate((w) => w is CustomPaint && w.child is PaperRow)),
          paints
            ..rect(
              rect: hebrew
                  ? Rect.fromLTRB(0, row.height - 1, 280 - 16, row.height)
                  : Rect.fromLTRB(16, row.height - 1, 280, row.height),
            ),
        );
      });

      testWidgets('${hebrew ? 'he' : 'en'}: on a larger phone at 300%, the icon and chevron keep to the title\'s line',
          (tester) async {
        // The card of a 412 dp phone.
        await pumpRows(tester, width: 372, hebrew: hebrew, [
          PaperRow(icon: Icons.menu_book_outlined, title: 'Read', subtitle: 'Plan', onTap: () {}),
          const PaperRow(title: 'Last'),
        ]);
        expect(tester.takeException(), isNull);
        final row = tester.getRect(find.byType(PaperRow).first);
        double fromStart(Rect r) => hebrew ? row.right - r.right : r.left - row.left;
        final icon = tester.getRect(find.byIcon(Icons.menu_book_outlined));
        final chevron = tester.getRect(find.byIcon(Icons.chevron_right));
        final title = tester.getRect(find.text('Read'));
        expect(fromStart(icon), 16);
        expect(fromStart(title), 16 + 33 + 8);
        expect(icon.center.dy, moreOrLessEquals(title.center.dy, epsilon: 0.5));
        expect(chevron.center.dy, moreOrLessEquals(title.center.dy, epsilon: 0.5));
        // The subtitle under them, the row's full width.
        expect(fromStart(tester.getRect(find.text('Plan'))), 16);
        // The hairline where the title starts, past the grown icon.
        expect(
          tester.renderObject(find.byWidgetPredicate((w) => w is CustomPaint && w.child is PaperRow)),
          paints
            ..rect(
              rect: hebrew
                  ? Rect.fromLTRB(0, row.height - 1, 372 - 57, row.height)
                  : Rect.fromLTRB(57, row.height - 1, 372, row.height),
            ),
        );
      });
    }

    testWidgets('at 200% on a 412 dp phone, a row keeps its columns side by side', (tester) async {
      await pumpRows(tester, width: 372, textScale: 2, [
        PaperRow(icon: Icons.menu_book_outlined, title: 'Read', subtitle: 'Plan', onTap: () {}),
        PaperRow(
          icon: Icons.visibility_outlined,
          title: 'Show',
          onTap: () {},
          chevron: false,
          mergeTrailing: true,
          trailing: Switch(value: true, onChanged: (_) {}, materialTapTargetSize: MaterialTapTargetSize.shrinkWrap),
        ),
      ]);
      final row = tester.getRect(find.byType(PaperRow).first);
      final icon = tester.getRect(find.byIcon(Icons.menu_book_outlined));
      final title = tester.getRect(find.text('Read'));
      expect(tester.widget<Icon>(find.byIcon(Icons.menu_book_outlined)).size, 22);
      expect(title.left - row.left, 54);
      expect(icon.center.dy, moreOrLessEquals(row.center.dy, epsilon: 0.5));
      expect(tester.getCenter(find.byIcon(Icons.chevron_right)).dy, moreOrLessEquals(row.center.dy, epsilon: 0.5));
      // A switch at the end too.
      final switchRow = tester.getRect(find.byType(PaperRow).last);
      expect(switchRow.right - tester.getRect(find.byType(Switch)).right, 12);
    });

    /// The size of the icon of the row titled [title], and where its title
    /// starts in the row.
    (double, double) layoutOf(WidgetTester tester, String title, IconData icon) {
      final row = tester.getRect(find.ancestor(of: find.text(title), matching: find.byType(PaperRow)));
      return (tester.widget<Icon>(find.byIcon(icon)).size!, tester.getRect(find.text(title)).left - row.left);
    }

    // As a setting turns on a button beside its switch, say: a row stacks
    // or not by its width alone, at 200% on a 412 dp phone's card (side by
    // side) and on a 393 dp phone's (stacked).
    testWidgets('a row stacks or not alike as a control at its end comes and goes', (tester) async {
      const spinner = SizedBox.square(key: Key('spinner'), dimension: 16);
      for (final width in [372.0, 353.0]) {
        Future<void> pump(Widget? trailing) => pumpRows(tester, width: width, textScale: 2, [
              PaperRow(icon: Icons.forum_outlined, title: 'Talk', trailing: trailing, onTap: () {}),
            ]);
        await pump(null);
        final before = layoutOf(tester, 'Talk', Icons.forum_outlined);
        final height = tester.getSize(find.byType(PaperRow)).height;
        await pump(spinner);
        expect(layoutOf(tester, 'Talk', Icons.forum_outlined), before, reason: '$width');
        if (width == 372) expect(tester.getSize(find.byType(PaperRow)).height, height);
      }
    });

    // As a discussion opens.
    testWidgets("a row's spinner in the chevron's place leaves it as it was", (tester) async {
      const spinner = SizedBox.square(key: Key('spinner'), dimension: 16);
      for (final width in [372.0, 353.0, 280.0]) {
        for (final scale in [2.0, 3.0]) {
          Future<void> pump(Widget? progress) => pumpRows(tester, width: width, textScale: scale, [
                PaperRow(icon: Icons.forum_outlined, title: 'Talk', progress: progress, onTap: () {}),
              ]);
          await pump(null);
          final before = layoutOf(tester, 'Talk', Icons.forum_outlined);
          final size = tester.getSize(find.byType(PaperRow));
          await pump(spinner);
          expect(layoutOf(tester, 'Talk', Icons.forum_outlined), before, reason: '$width at $scale');
          expect(tester.getSize(find.byType(PaperRow)), size, reason: '$width at $scale');
        }
      }
    });

    testWidgets("a row's spinner takes the chevron's place", (tester) async {
      const spinner = SizedBox.square(key: Key('spinner'), dimension: 16);
      await pumpRows(tester, width: 372, textScale: 1, [
        PaperRow(icon: Icons.forum_outlined, title: 'Talk', progress: spinner, onTap: () {}),
      ]);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
      final row = tester.getRect(find.byType(PaperRow));
      expect(tester.getCenter(find.byKey(const Key('spinner'))).dx, row.right - 12 - 10);
      // Stacked, it stays on the title's line, where the chevron is.
      await pumpRows(tester, width: 372, [
        PaperRow(icon: Icons.forum_outlined, title: 'Talk', progress: spinner, onTap: () {}),
      ]);
      expect(
        tester.getCenter(find.byKey(const Key('spinner'))).dy,
        moreOrLessEquals(tester.getCenter(find.text('Talk')).dy, epsilon: 0.5),
      );
    });

    // At 200% on a 393 dp phone, whose card is 353.
    testWidgets('the rows of a group decide alike, a switch row and a chevron row', (tester) async {
      await pumpRows(tester, width: 353, textScale: 2, [
        PaperRow(icon: Icons.menu_book_outlined, title: 'Read', onTap: () {}),
        PaperRow(
          icon: Icons.visibility_outlined,
          title: 'Show',
          onTap: () {},
          chevron: false,
          mergeTrailing: true,
          trailing: Switch(value: true, onChanged: (_) {}),
        ),
      ]);
      expect(layoutOf(tester, 'Read', Icons.menu_book_outlined), layoutOf(tester, 'Show', Icons.visibility_outlined));
    });

    testWidgets('a stacked row sets a trailing control under its text, and keeps it an item of its own',
        (tester) async {
      final handle = tester.ensureSemantics();
      await pumpRows(tester, [
        PaperRow(
          title: 'Rishon',
          subtitle: 'Gen 1',
          onTap: () {},
          trailing: IconButton(tooltip: 'More options', icon: const Icon(Icons.more_vert), onPressed: () {}),
        ),
      ]);
      expect(tester.takeException(), isNull);
      final row = tester.getRect(find.byType(PaperRow));
      final menu = tester.getRect(find.byType(IconButton));
      final title = tester.getRect(find.text('Rishon'));
      expect(menu.left - row.left, 16);
      expect(menu.top, greaterThanOrEqualTo(tester.getRect(find.text('Gen 1')).bottom + 8));
      // Without an icon, the chevron ends the title's line.
      expect(tester.getCenter(find.byIcon(Icons.chevron_right)).dy, moreOrLessEquals(title.center.dy, epsilon: 0.5));
      expect(row.right - tester.getRect(find.byIcon(Icons.chevron_right)).right, 12);
      final rowNode = tester.getSemantics(find.byType(PaperRow));
      expect(rowNode, isSemantics(label: 'Rishon\nGen 1', isButton: true, hasTapAction: true));
      expect(tester.getSemantics(find.byType(IconButton)).id, isNot(rowNode.id));
      handle.dispose();
    });

    testWidgets('a stacked row with a switch it toggles still reads as one switch', (tester) async {
      final handle = tester.ensureSemantics();
      await pumpRows(tester, [
        PaperRow(
          icon: Icons.visibility_outlined,
          title: 'Show',
          subtitle: 'Hide',
          onTap: () {},
          chevron: false,
          mergeTrailing: true,
          trailing: Switch(value: true, onChanged: (_) {}),
        ),
      ]);
      final row = tester.getRect(find.byType(PaperRow));
      final control = tester.getRect(find.byType(Switch));
      expect(control.left - row.left, 16);
      expect(control.top, greaterThanOrEqualTo(tester.getRect(find.text('Hide')).bottom + 8));
      final node = tester.getSemantics(find.byType(PaperRow));
      expect(node, isSemantics(label: 'Show\nHide', hasToggledState: true, isToggled: true, isButton: false));
      expect(tester.getSemantics(find.byType(Switch)).id, node.id);
      handle.dispose();
    });

    testWidgets('a title set smaller to keep a long word whole sets its subtitle no larger', (tester) async {
      // In the test font, "Accessibility" at 300% is far wider than the row.
      await pumpRows(tester, [
        PaperRow(icon: Icons.accessibility_new_outlined, title: 'Accessibility', subtitle: 'Calm', onTap: () {}),
      ]);
      expect(tester.takeException(), isNull);
      final title = drawnSize(tester, 'Accessibility');
      expect(title, lessThan(48), reason: 'set smaller to keep the word whole');
      expect(drawnSize(tester, 'Calm'), lessThanOrEqualTo(title + 0.01));
      expectWordsWhole(tester, 'Accessibility');

      // A title that fits leaves its subtitle as it is.
      await pumpRows(tester, [
        PaperRow(icon: Icons.accessibility_new_outlined, title: 'Ease', subtitle: 'Calm', onTap: () {}),
      ]);
      expect(drawnSize(tester, 'Ease'), 48);
      expect(drawnSize(tester, 'Calm'), 45);
    });

    testWidgets('the hairline follows a stacked row wherever it is in its group\'s row, and comes back',
        (tester) async {
      List<Widget> rows() => [
            Builder(
              builder: (context) =>
                  PaperRow(icon: Icons.menu_book_outlined, title: 'Read', subtitle: 'Plan', onTap: () {}),
            ),
            const PaperRow(title: 'Last'),
          ];
      final rule = find.byWidgetPredicate((w) => w is CustomPaint && w.child is Builder);
      await pumpRows(tester, rows(), ruleInset: PaperGroup.iconInset);
      var height = tester.getSize(rule).height;
      expect(tester.renderObject(rule), paints..rect(rect: Rect.fromLTRB(16, height - 1, 280, height)));

      await pumpRows(tester, rows(), ruleInset: PaperGroup.iconInset, textScale: 1);
      height = tester.getSize(rule).height;
      expect(tester.renderObject(rule), paints..rect(rect: Rect.fromLTRB(54, height - 1, 280, height)));
    });

    testWidgets('so does the hairline under a row built on its own', (tester) async {
      await pumpThemed(
        tester,
        Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 280,
            child: SingleChildScrollView(
              child: Column(children: [
                PaperGroupRow(
                  first: true,
                  last: false,
                  child: PaperRow(icon: Icons.menu_book_outlined, title: 'Read', subtitle: 'Plan', onTap: () {}),
                ),
                const PaperGroupRow(first: false, last: true, child: PaperRow(title: 'Last')),
              ]),
            ),
          ),
        ),
        textScale: 3,
      );
      final share = find.descendant(of: find.byType(PaperGroupRow).first, matching: find.byType(CustomPaint)).first;
      final height = tester.getSize(share).height;
      expect(tester.renderObject(share), paints..rrect()..rect(rect: Rect.fromLTRB(16, height - 1, 280, height)));
    });
  });

  group('a leading widget', () {
    const disc = SizedBox.square(key: Key('disc'), dimension: 32);

    testWidgets('takes the icon\'s place, and its hairline', (tester) async {
      await pumpThemed(
        tester,
        Align(
          alignment: Alignment.topCenter,
          child: SizedBox(
            width: 400,
            child: PaperGroup(children: [
              PaperRow(leading: disc, title: 'Rivka', onTap: () {}),
              const PaperRow(title: 'Last'),
            ]),
          ),
        ),
      );
      final row = tester.getRect(find.byType(PaperRow).first);
      final lead = tester.getRect(find.byKey(const Key('disc')));
      expect(lead.left - row.left, 16);
      expect(lead.center.dy, moreOrLessEquals(row.center.dy, epsilon: 0.5));
      expect(tester.getRect(find.text('Rivka')).left - row.left, 54);
      expect(
        tester.renderObject(find.byWidgetPredicate((w) => w is CustomPaint && w.child is PaperRow)),
        paints..rect(rect: Rect.fromLTRB(54, row.height - 1, 400, row.height)),
      );
    });

    testWidgets('stays in its slot beside the title of a stacked row', (tester) async {
      await pumpThemed(
        tester,
        Align(
          alignment: Alignment.topCenter,
          child: SizedBox(width: 372, child: PaperRow(leading: disc, title: 'Rivka', subtitle: 'Gen', onTap: () {})),
        ),
        textScale: 3,
      );
      final row = tester.getRect(find.byType(PaperRow));
      final title = tester.getRect(find.text('Rivka'));
      expect(tester.getRect(find.byKey(const Key('disc'))).left - row.left, 16);
      expect(title.left - row.left, 54);
      expect(tester.getRect(find.byKey(const Key('disc'))).center.dy, moreOrLessEquals(title.center.dy, epsilon: 0.5));
      expect(tester.getRect(find.text('Gen')).left - row.left, 16);
    });

    for (final hebrew in [false, true]) {
      testWidgets('${hebrew ? 'he' : 'en'}: on a small phone at 300%, goes on a line of its own, with the chevron',
          (tester) async {
        await pumpThemed(
          tester,
          Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: 280,
              child: PaperGroup(children: [
                PaperRow(leading: disc, title: 'Rivka', subtitle: 'Gen', onTap: () {}),
                const PaperRow(title: 'Last'),
              ]),
            ),
          ),
          textScale: 3,
          hebrew: hebrew,
        );
        expect(tester.takeException(), isNull);
        final row = tester.getRect(find.byType(PaperRow).first);
        double fromStart(Rect r) => hebrew ? row.right - r.right : r.left - row.left;
        double fromEnd(Rect r) => hebrew ? r.left - row.left : row.right - r.right;
        final lead = tester.getRect(find.byKey(const Key('disc')));
        final chevron = tester.getRect(find.byIcon(Icons.chevron_right));
        final title = tester.getRect(find.text('Rivka'));
        expect(fromStart(lead), 16);
        expect(fromEnd(chevron), 12);
        expect(chevron.center.dy, moreOrLessEquals(lead.center.dy, epsilon: 0.5));
        expect(title.top, greaterThanOrEqualTo(lead.bottom));
        expect(fromStart(title), 16);
        expect(
          tester.renderObject(find.byWidgetPredicate((w) => w is CustomPaint && w.child is PaperRow)),
          paints
            ..rect(
              rect: hebrew
                  ? Rect.fromLTRB(0, row.height - 1, 280 - 16, row.height)
                  : Rect.fromLTRB(16, row.height - 1, 280, row.height),
            ),
        );
      });
    }

    test('is one or the other with an icon', () {
      expect(() => PaperRow(icon: Icons.person_outline, leading: disc, title: 'Rivka'), throwsAssertionError);
    });
  });

  // A dialog sets its content at its intrinsic width, which a row, deciding
  // its layout at layout, can't give: given a width, it stands in one.
  testWidgets('a row given a width may stand in a dialog', (tester) async {
    await pumpThemed(
      tester,
      AlertDialog(
        content: SizedBox(
          width: 280,
          child: PaperGroup(children: [PaperRow(icon: Icons.menu_book_outlined, title: 'Read', onTap: () {})]),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(tester.getSize(find.byType(PaperRow)).width, 280);
  });

  group('at large text, as Android scales it', () {
    /// The size [text] is drawn at in the row around it, scaled and as much
    /// again as it is set smaller to keep a long word whole.
    double drawnSize(WidgetTester tester, String text) {
      final paragraph = tester.renderObject<RenderParagraph>(find.text(text));
      final row = tester.renderObject(find.ancestor(of: find.text(text), matching: find.byType(PaperRow)).first);
      final transform = paragraph.getTransformTo(row);
      return paragraph.textScaler.scale(paragraph.text.style!.fontSize!) *
          Offset(transform.entry(0, 0), transform.entry(1, 0)).distance;
    }

    Future<void> pump(WidgetTester tester, double width, List<Widget> rows) => tester.pumpWidget(MaterialApp(
          theme: AppTheme.build(mode: AppThemeMode.light, uiFont: UiFont.standard, hebrewUi: false, reduceMotion: false),
          builder: (context, page) => MediaQuery(
            data: MediaQuery.of(context).copyWith(textScaler: const _AndroidLargest()),
            child: page!,
          ),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(width: width, child: SingleChildScrollView(child: PaperGroup(children: rows))),
            ),
          ),
        ));

    testWidgets('a row on a narrow card stacks, as the title is enlarged', (tester) async {
      for (final width in [280.0, 320.0]) {
        await pump(tester, width, [
          PaperRow(icon: Icons.menu_book_outlined, title: 'Read', subtitle: 'Plan', onTap: () {}),
        ]);
        final row = tester.getRect(find.byType(PaperRow));
        expect(tester.getRect(find.text('Plan')).left - row.left, 16, reason: 'the subtitle the full width, at $width');
      }
    });

    testWidgets('a title set smaller to keep a long word whole is drawn no smaller than its subtitle', (tester) async {
      for (final width in [280.0, 320.0, 412.0]) {
        await pump(tester, width, [
          PaperRow(icon: Icons.accessibility_new_outlined, title: 'Accessibility', subtitle: 'Calm', onTap: () {}),
        ]);
        expect(tester.takeException(), isNull);
        final title = drawnSize(tester, 'Accessibility');
        expect(drawnSize(tester, 'Calm'), lessThanOrEqualTo(title + 0.01), reason: '$width');
        expectWordsWhole(tester, 'Accessibility');
      }
    });

    testWidgets('a value, or a labelled button, wraps under the title, drawn no larger than it', (tester) async {
      await pump(tester, 280, [
        PaperRow(icon: Icons.language, title: 'Accessibility', value: 'English', onTap: () {}),
        PaperRow(
          icon: Icons.notifications_outlined,
          title: 'Notifications',
          trailing: TextButton(onPressed: () {}, child: const Text('Test')),
        ),
      ]);
      expect(tester.takeException(), isNull);
      for (final (title, other) in [('Accessibility', 'English'), ('Notifications', 'Test')]) {
        expect(tester.getRect(find.text(other)).top, greaterThanOrEqualTo(tester.getRect(find.text(title)).bottom));
        if (other == 'English') expect(drawnSize(tester, other), lessThanOrEqualTo(drawnSize(tester, title) + 0.01));
      }
    });
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

/// Android 14's text scale at its largest, 200%, which grows large text less
/// than small: 14 to 26, 16 to 28, and from 100 on not at all (its
/// converter's table for the font scale 2.0, interpolated).
class _AndroidLargest extends TextScaler {
  const _AndroidLargest();

  static const _table = [
    (8.0, 16.0),
    (10.0, 20.0),
    (12.0, 24.0),
    (14.0, 26.0),
    (18.0, 30.0),
    (20.0, 34.0),
    (24.0, 36.0),
    (30.0, 38.0),
    (100.0, 100.0),
  ];

  @override
  double scale(double fontSize) {
    if (fontSize <= _table.first.$1) return fontSize * 2;
    for (var i = 1; i < _table.length; i++) {
      final (x0, y0) = _table[i - 1];
      final (x1, y1) = _table[i];
      if (fontSize <= x1) return y0 + (fontSize - x0) / (x1 - x0) * (y1 - y0);
    }
    return fontSize;
  }

  @override
  double get textScaleFactor => 2;

  @override
  bool operator ==(Object other) => other is _AndroidLargest;

  @override
  int get hashCode => 0;
}
