import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/data/models/parsha.dart';
import 'package:shnayim_mikra/data/models/verse_ref.dart';
import 'package:shnayim_mikra/features/reader/haftarah_screen.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';

import '../../helpers.dart';

/// Friday of Bereshit 5787, which is read on Shabbat Machar Chodesh
/// (10 October 2026): its own haftarah, Isaiah 42:5, gives way.
final _friday = DateTime(2026, 10, 9, 11);
final _settings = AppSettings(onboardingComplete: true, joinDate: LocalDate(2026, 10, 4));

const _regularTitle = 'Also: the regular haftarah of Bereshit';
const _fallbackNote = 'Chabad haftarot are being verified; showing the Ashkenazi reading.';

void main() {
  /// Waits for texts to load from the bundle (spinners never settle).
  Future<void> loadTexts(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    for (var i = 0; i < 40 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<ProviderContainer> open(WidgetTester tester, String route, {required AppSettings settings, DateTime? now}) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await pumpApp(tester, settings: settings, now: now ?? _friday);
    c.read(routerProvider).go(route);
    await loadTexts(tester);
    expect(find.byType(HaftarahScreen), findsOneWidget);
    return c;
  }

  Future<ProviderContainer> openHaftarah(WidgetTester tester, AppSettings settings) =>
      open(tester, '/haftarah/5787:1', settings: settings);

  testWidgets("opens Bereshit's own haftarah, folded, after Machar Chodesh's", (tester) async {
    final c = await openHaftarah(tester, _settings);
    expect(find.text('Special haftarah: Shabbat Machar Chodesh'), findsOneWidget);
    expect(find.text('I Samuel'), findsOneWidget);
    expect(find.text(_regularTitle), findsOneWidget);
    expect(find.text('Isaiah 42:5–43:10'), findsOneWidget);
    expect(find.text('Isaiah'), findsNothing, reason: 'folded');
    expect(find.text(_fallbackNote), findsNothing);

    await tester.ensureVisible(find.text(_regularTitle));
    await tester.pumpAndSettle();
    await tester.tap(find.text(_regularTitle));
    await loadTexts(tester);
    expect(find.text('Isaiah'), findsOneWidget);
    final verses = c.read(regularHaftarahTextProvider('5787:1')).requireValue;
    expect((verses.first.book, verses.first.hebrew.ref), ('Isaiah', const VerseRef(42, 5)));
    expect(verses.last.hebrew.ref, const VerseRef(43, 10));
  });

  // ExpansionTile tells screen readers its state in its hint, and announces
  // each change, in each platform's own way.
  testWidgets('its regular haftarah is a heading that says whether it is open, and every target is big enough',
      (tester) async {
    final handle = tester.ensureSemantics();
    await openHaftarah(tester, _settings);
    await tester.ensureVisible(find.text(_regularTitle));
    await tester.pumpAndSettle();
    expect(
      tester.getSemantics(find.text(_regularTitle)),
      isSemantics(label: '$_regularTitle\nIsaiah 42:5–43:10', isHeader: true, hint: 'Collapsed'),
    );
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await tester.tap(find.text(_regularTitle));
    await loadTexts(tester);
    expect(tester.getSemantics(find.text(_regularTitle)), isSemantics(hint: 'Expanded'));
    handle.dispose();
  });

  testWidgets("opens it unfolded for Chabad, whose haftarot are the Ashkenazi ones for now, as it says", (tester) async {
    await openHaftarah(tester, _settings.withNusach(HaftarahNusach.chabad));
    expect(find.text(_fallbackNote), findsOneWidget);
    expect(find.text(_regularTitle), findsOneWidget);
    expect(find.text('Isaiah'), findsOneWidget, reason: 'unfolded');
  });

  testWidgets('shows no regular haftarah, or note, in a week without a special one', (tester) async {
    await open(tester, '/haftarah/5787:2', settings: _settings, now: DateTime(2026, 10, 13, 11));
    expect(find.text('Isaiah'), findsOneWidget, reason: "Noach's haftarah");
    expect(find.byType(ExpansionTile), findsNothing);
    expect(find.text(_fallbackNote), findsNothing);
  });

  group('Today', () {
    Future<void> openToday(WidgetTester tester, DateTime now) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await pumpApp(tester, settings: _settings, now: now);
      await tester.pumpAndSettle();
    }

    testWidgets("says the haftarah page has the regular haftarah too, in a week it gives way", (tester) async {
      await openToday(tester, _friday);
      expect(find.text('Special haftarah: Shabbat Machar Chodesh'), findsOneWidget);
      expect(find.text('Also the regular haftarah'), findsOneWidget);
    });

    testWidgets('says nothing of it in other weeks', (tester) async {
      await openToday(tester, DateTime(2026, 10, 13, 11));
      expect(find.text('Haftarah'), findsOneWidget);
      expect(find.text('Also the regular haftarah'), findsNothing);
    });
  });
}
