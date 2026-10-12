import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/data/models/verse_ref.dart';
import 'package:shnayim_mikra/features/parsha/week_overview_screen.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikra/features/reader/scripture_text.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/ui/theme/app_theme.dart';
import 'package:shnayim_mikra/ui/widgets/progress_widgets.dart';

import '../../helpers.dart';

/// Vayakhel-Pekudei, read together in 5786, a common year, on Shabbat 14
/// March 2026. Pekudei begins at Exodus 38:21, within Revi'i (38:1–39:1),
/// the 21st of its 32 verses.
const _week = '5786:22-23';
const _pekudei = VerseRef(38, 21);

/// Wednesday 11 March 2026, in its week.
final _wednesday = DateTime(2026, 3, 11, 11);

final _settings = AppSettings(
  onboardingComplete: true,
  notificationPromptShown: true,
  joinDate: LocalDate(2026, 3, 1),
);

void main() {
  setUp(ParshaRings.forgetShown);

  Future<ProviderContainer> open(WidgetTester tester, String route, {AppSettings? settings, ProgressState? progress}) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await pumpApp(tester, settings: settings ?? _settings, now: _wednesday, progress: progress);
    c.read(routerProvider).go(route);
    await tester.pump();
    await tester.pump();
    // The reader's texts load from assets.
    for (var i = 0; i < 20 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump();
    }
    await tester.pumpAndSettle();
    return c;
  }

  /// The row of the aliyah named [name] on the week's page.
  Finder row(String name) => find.ancestor(of: find.text(name), matching: find.byType(SeferInkWell)).first;

  group("the week's page", () {
    testWidgets('says under Revi’i that Pekudei begins at 38:21, in marginalia', (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester, '/week/$_week');
      final line = find.descendant(of: row('Revi’i'), matching: find.text('Pekudei begins at 38:21'));
      expect(line, findsOneWidget);
      expect(find.textContaining('begins at'), findsOneWidget, reason: 'in the one aliyah it begins in');
      expect(tester.widget<Text>(line).style, SeferType.of(tester.element(find.byType(WeekOverview))).marginalia);
      // A screen reader hears it with the row.
      expect(find.bySemanticsLabel(RegExp(r'^Revi’i · aliyah 4\b.*\bPekudei begins at 38:21', dotAll: true)),
          findsOneWidget);
      handle.dispose();
    });

    testWidgets('says it in Hebrew, the verse in Hebrew numerals', (tester) async {
      await open(tester, '/week/$_week', settings: _settings.copyWith(language: AppLanguage.hebrew));
      // The prefix held to the verse by a word joiner, as a maqaf's words
      // are kept whole.
      expect(
        find.descendant(of: row('רביעי'), matching: find.text('פרשת פקודי מתחילה ב־\u2060לח,\u00A0כא')),
        findsOneWidget,
      );
    });

    testWidgets('says nothing of the kind in a week of one parsha', (tester) async {
      // Vayakhel alone, in 5787, a leap year.
      await open(tester, '/week/5787:22');
      expect(find.text('Rishon'), findsOneWidget);
      expect(find.textContaining('begins at'), findsNothing);
    });
  });

  group('the reader', () {
    /// The heading that names Pekudei, the only one that names no chapter.
    final heading = find.byWidgetPredicate((w) => w is ChapterHeading && w.chapter == null, skipOffstage: false);

    Finder verseGroup(VerseRef r) =>
        find.byWidgetPredicate((w) => w is VerseGroup && w.verse == r, skipOffstage: false);

    testWidgets('heads 38:21 in the full text with Pekudei, set as a chapter is', (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester, '/read/$_week/3?mode=full');
      expect(heading, findsOneWidget);
      final widget = tester.widget<ChapterHeading>(heading);
      expect(widget.hebrewName, 'פְקוּדֵי');
      expect(widget.name, 'Pekudei');
      expect(widget.headingLevel, 2, reason: 'as the chapters are');
      // Between 38:20 and 38:21.
      final rect = tester.getRect(heading);
      expect(rect.top, greaterThanOrEqualTo(tester.getRect(verseGroup(const VerseRef(38, 20))).bottom));
      expect(rect.bottom, lessThanOrEqualTo(tester.getRect(verseGroup(_pekudei)).top));
      // Gold Hebrew, the English beneath, and one heading to a screen reader.
      await tester.ensureVisible(heading);
      await tester.pumpAndSettle();
      expect(find.descendant(of: heading, matching: find.text('פְקוּדֵי')), findsOneWidget);
      expect(find.descendant(of: heading, matching: find.text('Pekudei')), findsOneWidget);
      expect(tester.getSemantics(heading), isSemantics(label: 'Pekudei', isHeader: true));
      handle.dispose();
    });

    testWidgets('names it in Hebrew to a screen reader in the Hebrew UI, with no English beneath', (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester, '/read/$_week/3?mode=full', settings: _settings.copyWith(language: AppLanguage.hebrew));
      await tester.ensureVisible(heading);
      await tester.pumpAndSettle();
      expect(find.descendant(of: heading, matching: find.text('Pekudei')), findsNothing);
      expect(tester.getSemantics(heading), isSemantics(label: 'פקודי', isHeader: true));
      handle.dispose();
    });

    testWidgets('heads it beneath its aliyah’s heading in the whole parsha', (tester) async {
      await open(tester, '/read/$_week/3?mode=full', settings: _settings.copyWith(fullTextWholeParsha: true));
      await tester.scrollUntilVisible(
        find.byWidgetPredicate((w) => w is ChapterHeading && w.chapter == null),
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      expect(heading, findsOneWidget);
      expect(tester.widget<ChapterHeading>(heading).headingLevel, 3);
    });

    testWidgets('heads it in each reading of its step in the guided reader, and no other', (tester) async {
      // Revi'i read up to 38:20 in all three readings: it goes on at 38:21.
      final progress = ProgressState(weeks: {
        _week: WeekProgress(weekId: _week, positions: {
          3: const [20, 20, 20],
        }),
      });
      await open(tester, '/read/$_week/3', progress: progress);
      for (final step in ['Read the Hebrew', 'Read the Hebrew again', 'Read the Targum']) {
        expect(find.text(step), findsOneWidget);
        expect(find.text('Verse 21 of 32'), findsOneWidget);
        expect(heading, findsOneWidget, reason: step);
        expect(tester.getRect(heading).bottom, lessThanOrEqualTo(tester.getRect(find.byType(ScriptureVerse)).top));
        await tester.tap(find.text('Next'));
        await tester.pumpAndSettle();
      }
      expect(find.text('Verse 22 of 32'), findsOneWidget);
      expect(heading, findsNothing);
    });
  });
}
