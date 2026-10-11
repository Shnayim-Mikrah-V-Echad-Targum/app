import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikra/features/reader/aliyah_ribbon.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/ui/theme/focus.dart';

import '../../helpers.dart';

// The ribbon in the bundled fonts, whose metrics decide whether the seven
// tabs share the width.
void main() {
  setUpAll(loadBundledFonts);

  const names = ['Rishon', 'Sheni', 'Shlishi', "Revi'i", 'Chamishi', 'Shishi', "Shevi'i"];
  const namesHe = ['ראשון', 'שני', 'שלישי', 'רביעי', 'חמישי', 'שישי', 'שביעי'];

  Future<List<int>> pump(
    WidgetTester tester, {
    double width = 412,
    bool hebrew = false,
    UiFont uiFont = UiFont.standard,
    double textScale = 1,
    double maxWidth = 760,
  }) async {
    tester.view.physicalSize = Size(width, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final selected = <int>[];
    final day = LocalDate(2026, 10, 12);
    await pumpThemed(
      tester,
      Column(
        children: [
          AliyahRibbon(
            week: WeekProgress(weekId: '5787:2').withAliyah(0, day).withUnit(2, ReadingPass.mikra1, day),
            aliyahVerses: const [14, 23, 22, 21, 14, 18, 20],
            selected: 3,
            onSelected: selected.add,
            maxWidth: maxWidth,
          ),
        ],
      ),
      hebrew: hebrew,
      uiFont: uiFont,
      textScale: textScale,
    );
    await tester.pumpAndSettle();
    return selected;
  }

  Finder tab(String name) => find.ancestor(of: find.text(name), matching: find.byType(SeferInkWell));
  final scrolls = find.descendant(of: find.byType(AliyahRibbon), matching: find.byType(Scrollable));

  /// Every name on one line, as wide as it is set, within its tab.
  void expectNamesWhole(WidgetTester tester, List<String> names) {
    for (final name in names) {
      final paragraph = tester.renderObject<RenderParagraph>(find.text(name));
      final width = paragraph.getMaxIntrinsicWidth(double.infinity);
      expect(paragraph.didExceedMaxLines, isFalse);
      // A fraction of a pixel of overhang hides in the letters' side bearings.
      expect(tester.getRect(tab(name)).width, greaterThanOrEqualTo(width.floorToDouble()), reason: name);
    }
  }

  for (final (label, hebrew, font) in [
    ('English', false, UiFont.standard),
    ('Hebrew', true, UiFont.standard),
    ('Lexend', false, UiFont.lexend),
  ]) {
    testWidgets('the seven tabs share a 412 dp phone, in $label', (tester) async {
      await pump(tester, hebrew: hebrew, uiFont: font);
      expect(scrolls, findsNothing);
      final shown = hebrew ? namesHe : names;
      expect(tester.getRect(tab(shown.first)).width, greaterThanOrEqualTo(AliyahRibbon.minTabWidth));
      expectNamesWhole(tester, shown);
      expect(tester.getSize(find.byType(AliyahRibbon)).height, greaterThanOrEqualTo(AliyahRibbon.minHeight));
    });
  }

  testWidgets('on a narrower phone the tabs scroll, each at least 64 wide', (tester) async {
    await pump(tester, width: 360);
    expect(scrolls, findsOneWidget);
    for (final name in names) {
      expect(tester.getRect(tab(name)).width, greaterThanOrEqualTo(AliyahRibbon.scrollingTabWidth));
    }
  });

  for (final hebrew in [false, true]) {
    testWidgets('at 200% text nothing is clipped, and the ribbon grows${hebrew ? ', in Hebrew' : ''}', (tester) async {
      await pump(tester, hebrew: hebrew, textScale: 2);
      expect(tester.takeException(), isNull);
      expect(scrolls, findsOneWidget);
      // Scrolled along, each tab shows its whole name.
      final shown = hebrew ? namesHe : names;
      for (final name in shown) {
        await tester.ensureVisible(tab(name));
        await tester.pumpAndSettle();
      }
      expectNamesWhole(tester, shown);
      expect(tester.getSize(find.byType(AliyahRibbon)).height, greaterThan(AliyahRibbon.minHeight));
    });
  }

  testWidgets('on a wide screen the tabs keep to the reading column, centred', (tester) async {
    await pump(tester, width: 1366, maxWidth: 680);
    final first = tester.getRect(tab(names.first));
    final last = tester.getRect(tab(names.last));
    expect(first.left, moreOrLessEquals((1366 - 680) / 2));
    expect(last.right, moreOrLessEquals((1366 + 680) / 2));
  });

  testWidgets('a tab opens its aliyah, and the open one is marked by a bar alone', (tester) async {
    final selected = await pump(tester);
    await tester.tap(tab('Sheni'));
    expect(selected, [1]);
    // The open tab's bar is drawn; the others' are not.
    double bar(String name) => tester
        .widget<AnimatedOpacity>(
          find.descendant(of: find.ancestor(of: tab(name), matching: find.byType(Stack)).first, matching: find.byType(AnimatedOpacity)),
        )
        .opacity;
    expect(bar("Revi'i"), 1);
    expect(bar('Sheni'), 0);
  });
}
