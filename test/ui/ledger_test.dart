import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/ui/theme/app_theme.dart';
import 'package:shnayim_mikra/ui/theme/palette.dart';
import 'package:shnayim_mikra/ui/widgets/ledger.dart';

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

  testWidgets('a streak of 0 says where it begins instead', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpLedger(tester, LedgerCard(parshaStreak: 0, daysOnTrack: 2, beginsWith: 'Bereshit', onTap: () {}));
    expect(find.text('Begins with Bereshit'), findsOneWidget);
    expect(find.text('0'), findsNothing);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('Parsha streak'), findsOneWidget);
    expect(find.text('Days on track'), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(LedgerCard)),
      isSemantics(label: 'Parsha streak: begins with Bereshit. Days on track: 2', isButton: true),
    );

    await pumpLedger(tester, const LedgerCard(parshaStreak: 3, daysOnTrack: 0, beginsWith: 'Noach'));
    expect(find.text("Begins with today's reading"), findsOneWidget);
    expect(find.text('Begins with Noach'), findsNothing);
    expect(find.text('0'), findsNothing);
    expect(
      tester.getSemantics(find.byType(LedgerCard)),
      isSemantics(label: "Parsha streak: 3. Days on track: begins with today's reading", isButton: false),
    );
    handle.dispose();
  });

  testWidgets('in Hebrew', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpLedger(tester, const LedgerCard(parshaStreak: 0, daysOnTrack: 0, beginsWith: 'בראשית'), hebrew: true);
    expect(find.text('יתחיל בפרשת בראשית'), findsOneWidget);
    expect(find.text('יתחיל בקריאה של היום'), findsOneWidget);
    expect(
      tester.getSemantics(find.byType(LedgerCard)),
      isSemantics(label: 'רצף פרשות: יתחיל בפרשת בראשית. ימים לפי התוכנית: יתחיל בקריאה של היום'),
    );
    // The parsha streak comes first, on the right.
    expect(tester.getCenter(find.text('רצף פרשות')).dx, greaterThan(tester.getCenter(find.text('ימים לפי התוכנית')).dx));
    handle.dispose();
  });

  testWidgets('counts are set as ledger numerals, sentences as titles', (tester) async {
    await pumpLedger(tester, const LedgerCard(parshaStreak: 0, daysOnTrack: 12, beginsWith: 'Bereshit'));
    final context = tester.element(find.byType(LedgerCard));
    expect(tester.widget<Text>(find.text('12')).style, SeferType.of(context).ledgerNumeral);
    expect(tester.widget<Text>(find.text('Begins with Bereshit')).style, Theme.of(context).textTheme.titleMedium);
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
    expect(tester.getSize(find.text('Begins with Vayakhel-Pekudei')).height, greaterThan(24), reason: 'it wraps');
    expect(tester.getTopLeft(find.text('Parsha streak')).dy, tester.getTopLeft(find.text('Days on track')).dy);
    // Each column is padded 16.
    final card = tester.getRect(find.byType(LedgerCard));
    expect(tester.getTopLeft(find.text('Begins with Vayakhel-Pekudei')), card.topLeft + const Offset(16, 16));
    expect(card.bottom - tester.getRect(find.text('Parsha streak')).bottom, 16);
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
}
