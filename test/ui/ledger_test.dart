import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikrah/features/settings/app_settings.dart';
import 'package:shnayim_mikrah/ui/theme/app_theme.dart';
import 'package:shnayim_mikrah/ui/theme/palette.dart';
import 'package:shnayim_mikrah/ui/widgets/ledger.dart';

import '../helpers.dart';

/// docs/DESIGN_SYSTEM.md §6.12: the two streaks on one card, and never a
/// stark 0.
void main() {
  Future<void> pumpLedger(
    WidgetTester tester,
    LedgerCard card, {
    bool hebrew = false,
    AppThemeMode theme = AppThemeMode.light,
    double width = 400,
  }) =>
      pumpThemed(
        tester,
        Align(alignment: Alignment.topCenter, child: SizedBox(width: width, child: card)),
        hebrew: hebrew,
        theme: theme,
      );

  testWidgets('a streak of 0 says what starts it instead', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpLedger(tester, LedgerCard(parshaStreak: 0, daysOnTrack: 2, beginsWith: 'Bereshit', onTap: () {}));
    expect(find.text('Starts when Bereshit is complete'), findsOneWidget);
    expect(find.text('0'), findsNothing);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Parsha streak'), findsOneWidget);
    expect(find.text('Days on track'), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(LedgerCard)),
      isSemantics(label: 'Parsha streak: starts when Bereshit is complete. Days on track: 2', isButton: true),
    );

    await pumpLedger(tester, const LedgerCard(parshaStreak: 3, daysOnTrack: 0, beginsWith: 'Noach'));
    expect(find.text('Starts with today’s reading'), findsOneWidget);
    expect(find.text('Starts when Noach is complete'), findsNothing);
    expect(find.text('0'), findsNothing);
    expect(
      tester.getSemantics(find.byType(LedgerCard)),
      isSemantics(label: 'Parsha streak: 3. Days on track: starts with today’s reading', isButton: false),
    );
    handle.dispose();
  });

  testWidgets('in Hebrew', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpLedger(tester, const LedgerCard(parshaStreak: 0, daysOnTrack: 0, beginsWith: 'בראשית'), hebrew: true);
    expect(find.text('יתחיל עם סיום פרשת בראשית'), findsOneWidget);
    expect(find.text('יתחיל בקריאה של היום'), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(LedgerCard)),
      isSemantics(label: 'רצף פרשות: יתחיל עם סיום פרשת בראשית. ימים לפי התוכנית: יתחיל בקריאה של היום'),
    );
    // The parsha streak comes first, on the right.
    expect(tester.getCenter(find.text('רצף פרשות')).dx, greaterThan(tester.getCenter(find.text('ימים לפי התוכנית')).dx));
    handle.dispose();
  });

  testWidgets('counts are set as ledger numerals, sentences as titles', (tester) async {
    await pumpLedger(tester, const LedgerCard(parshaStreak: 0, daysOnTrack: 12, beginsWith: 'Bereshit'));
    final context = tester.element(find.byType(LedgerCard));
    expect(tester.widget<Text>(find.text('12')).style, SeferType.of(context).ledgerNumeral);
    expect(tester.widget<Text>(find.text('Starts when Bereshit is complete')).style, Theme.of(context).textTheme.titleMedium);
  });

  testWidgets('a longest run shows only when it is longer than the current one', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpLedger(
      tester,
      const LedgerCard(parshaStreak: 3, daysOnTrack: 9, beginsWith: 'Noach', longestParshaStreak: 5, longestDaysOnTrack: 9),
    );
    expect(find.text('Longest: 5 weeks'), findsOneWidget);
    expect(find.textContaining('Longest: 9'), findsNothing);
    expect(
      tester.getSemantics(find.byType(LedgerCard)),
      isSemantics(label: 'Parsha streak: 3. Longest: 5 weeks. Days on track: 9'),
    );

    await pumpLedger(tester, const LedgerCard(parshaStreak: 0, daysOnTrack: 0, beginsWith: 'Noach', longestDaysOnTrack: 1));
    expect(find.text('Longest: 1 day'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('the labels line up even when a sentence wraps', (tester) async {
    await pumpLedger(
      tester,
      const LedgerCard(parshaStreak: 0, daysOnTrack: 2, beginsWith: 'Vayakhel-Pekudei'),
      width: 320,
    );
    expect(tester.getSize(find.text('Starts when Vayakhel-Pekudei is complete')).height, greaterThan(24), reason: 'it wraps');
    expect(tester.getTopLeft(find.text('Parsha streak')).dy, tester.getTopLeft(find.text('Days on track')).dy);
    // Each column is padded 16.
    final card = tester.getRect(find.byType(LedgerCard));
    expect(tester.getTopLeft(find.text('Starts when Vayakhel-Pekudei is complete')), card.topLeft + const Offset(16, 16));
    expect(card.bottom - tester.getRect(find.text('Parsha streak')).bottom, 16);
  });

  testWidgets('at the largest text on a small phone, every word stays whole', (tester) async {
    await pumpThemed(
      tester,
      const Align(
        alignment: Alignment.topCenter,
        child: SizedBox(width: 288, child: LedgerCard(parshaStreak: 0, daysOnTrack: 0, beginsWith: 'Noach')),
      ),
      textScale: 3,
    );
    for (final text in ['Starts when Noach is complete', 'Starts with today’s reading', 'Parsha streak', 'Days on track']) {
      expectWordsWhole(tester, text);
    }
    expect(tester.takeException(), isNull);

    // A count is one word too: "365" in ledger numerals is far wider than
    // its column here.
    await pumpThemed(
      tester,
      const Align(
        alignment: Alignment.topCenter,
        child: SizedBox(width: 288, child: LedgerCard(parshaStreak: 54, daysOnTrack: 365, beginsWith: 'Noach')),
      ),
      textScale: 3,
    );
    for (final text in ['54', '365', 'Parsha streak', 'Days on track']) {
      expectWordsWhole(tester, text);
    }
    final column = tester.getSize(find.byType(LedgerCard)).width / 2 - 32;
    expect(tester.getRect(find.text('365')).width, lessThanOrEqualTo(column));
    expect(tester.takeException(), isNull);
  });

  testWidgets('one tap target with a hairline between the columns', (tester) async {
    var taps = 0;
    await pumpLedger(tester, LedgerCard(parshaStreak: 1, daysOnTrack: 2, beginsWith: 'Noach', onTap: () => taps++));
    await tester.tap(find.text('Days on track'));
    expect(taps, 1);
    expect(find.byType(SeferInkWell), findsOneWidget);
    expect(
      tester.widget<Table>(find.byType(Table)).border!.verticalInside,
      BorderSide(color: Palettes.seferLight.hairline),
    );

    await pumpLedger(
      tester,
      const LedgerCard(parshaStreak: 1, daysOnTrack: 2, beginsWith: 'Noach'),
      theme: AppThemeMode.highContrastDark,
    );
    expect(
      tester.widget<Table>(find.byType(Table)).border!.verticalInside,
      BorderSide(color: Palettes.hcDark.outline, width: 2),
    );
  });

  group('with the app’s fonts', () {
    // Last, as the fonts stay loaded for whatever follows.
    setUpAll(loadBundledFonts);

    testWidgets('a sentence in place of a count leaves no word alone on its last line', (tester) async {
      // A 412 dp phone's card, as on Today and Progress.
      await pumpLedger(
        tester,
        const LedgerCard(parshaStreak: 0, daysOnTrack: 2, beginsWith: 'בראשית'),
        hebrew: true,
        width: 372,
      );
      const sentence = 'יתחיל עם סיום פרשת בראשית';
      final paragraph = tester.renderObject<RenderParagraph>(find.text(sentence));
      double lineOf(String word) =>
          paragraph.getOffsetForCaret(TextPosition(offset: sentence.indexOf(word)), Rect.zero).dy;
      expect(lineOf('יתחיל'), lessThan(lineOf('בראשית')), reason: 'it takes two lines');
      expect(lineOf('פרשת'), lineOf('בראשית'), reason: 'the name is not alone');
    });

    // The English is longer than the column's two lines can hold: "Bereshit
    // is complete" alone is wider than a 412 dp phone's column (154), so
    // it takes three. A change of copy that adds a line should be a choice.
    testWidgets('the English sentence takes three lines in a phone’s column', (tester) async {
      await pumpLedger(tester, const LedgerCard(parshaStreak: 0, daysOnTrack: 2, beginsWith: 'Bereshit'), width: 372);
      const sentence = 'Starts when Bereshit is complete';
      final paragraph = tester.renderObject<RenderParagraph>(find.text(sentence));
      final words = sentence.split(' ');
      final lines = <double, List<String>>{};
      var offset = 0;
      for (final word in words) {
        final y = paragraph.getOffsetForCaret(TextPosition(offset: offset), Rect.zero).dy;
        (lines[y] ??= []).add(word);
        offset += word.length + 1;
      }
      expect([for (final line in lines.values) line.join(' ')], ['Starts when', 'Bereshit is', 'complete']);
    });
  });
}
