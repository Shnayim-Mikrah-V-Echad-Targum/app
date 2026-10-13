import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikrah/core/calendar/local_date.dart';
import 'package:shnayim_mikrah/features/settings/app_settings.dart';
import 'package:shnayim_mikrah/ui/widgets/lines.dart';

import '../../helpers.dart';

/// Browse at the largest text a phone offers, on the smallest phone the app
/// is laid out for, in the app's own fonts: every name stays whole, and a
/// book's count makes way for its names.
void main() {
  setUpAll(loadBundledFonts);

  /// Joined on Simchat Torah 5787 outside Israel, on Friday of Bereshit.
  AppSettings settings({required bool hebrew}) => AppSettings(
        onboardingComplete: true,
        joinDate: LocalDate(2026, 10, 4),
        language: hebrew ? AppLanguage.hebrew : AppLanguage.english,
      );
  final friday = DateTime(2026, 10, 9, 11);

  /// The book of Genesis's names, as its header sets them.
  Finder genesis({required bool hebrew}) => find.byWidgetPredicate(
        (w) => w is Text && w.textSpan != null && w.semanticsLabel == (hebrew ? 'בראשית' : 'Genesis'),
      );

  // The gap between the Hebrew and English names grows with the text, as a
  // widget in the text does: measured at 8 whatever the size, the names were
  // judged to fit beside the count when they didn't, and the English one
  // wrapped under the Hebrew with the count still beside them.
  // The widths where some book's names, measured so, were taken to fit:
  // Exodus on a 398 dp phone at 200%, Leviticus at 422, Genesis and Numbers
  // at 442, Deuteronomy at 494, and Exodus and Leviticus on tablets at 300%.
  for (final (width, scale) in [
    (398.0, 2.0),
    (412.0, 2.0),
    (422.0, 2.0),
    (442.0, 2.0),
    (494.0, 2.0),
    (320.0, 3.0),
    (562.0, 3.0),
    (594.0, 3.0),
  ]) {
    testWidgets('at ${scale}x on a ${width.round()} dp phone, a count beside the names leaves them one line',
        (tester) async {
      await openRoute(
        tester,
        '/parsha/browse',
        settings: settings(hebrew: false),
        now: friday,
        size: Size(width, 20000),
        textScale: scale,
      );
      expect(tester.takeException(), isNull);
      for (final book in ['Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy']) {
        final names = find.byWidgetPredicate((w) => w is Text && w.textSpan != null && w.semanticsLabel == book);
        await tester.scrollUntilVisible(names, 400);
        await tester.pumpAndSettle();
        final header = find.ancestor(of: names, matching: find.byType(LayoutBuilder)).first;
        final count = find.descendant(of: header, matching: find.textContaining('parshiyot'));
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(of: names, matching: find.byType(RichText)).first,
        );
        // One line is as tall as the Hebrew name's, 28 at its size (the
        // two names' runs stand at different heights within it).
        final oneLine = paragraph.size.height < 1.5 * 28 * scale;
        final beside = tester.getRect(count).top < tester.getRect(names).bottom;
        if (beside) expect(oneLine, isTrue, reason: '$book: the count beside names ${paragraph.size.height} high');
      }
    });
  }

  for (final hebrew in [false, true]) {
    final language = hebrew ? ', in Hebrew' : '';

    // The names of a parsha keep each word whole, and a maqaf's words
    // together: never "לך־" over "לך".
    testWidgets('a parsha\'s names stay whole at 300% on a 320 dp phone$language', (tester) async {
      await openRoute(
        tester,
        '/parsha/browse',
        settings: settings(hebrew: hebrew),
        now: friday,
        size: const Size(320, 3600),
        textScale: 3,
      );
      expect(tester.takeException(), isNull);
      final lech = WholeWords.unbroken('לך־לך');
      expect(lech, 'לך־⁠לך');
      expectWordsWhole(tester, lech);
      expectWholeWords(tester);
    });

    // Beside the names, the count once squeezed them to a letter a line.
    testWidgets('a book\'s count ends its names\' line, or goes under them at 300%$language', (tester) async {
      final count = find.text(hebrew ? '12 פרשות' : '12 parshiyot');
      await openRoute(tester, '/parsha/browse', settings: settings(hebrew: hebrew), now: friday);
      expect(tester.getRect(count).top, lessThan(tester.getRect(genesis(hebrew: hebrew)).bottom));

      await openRoute(
        tester,
        '/parsha/browse',
        settings: settings(hebrew: hebrew),
        now: friday,
        size: const Size(320, 3600),
        textScale: 3,
      );
      expect(tester.takeException(), isNull);
      final names = tester.getRect(genesis(hebrew: hebrew));
      final under = tester.getRect(count);
      expect(under.top, greaterThanOrEqualTo(names.bottom));
      // At the start, as the names are.
      if (hebrew) {
        expect(under.right, moreOrLessEquals(names.right));
      } else {
        expect(under.left, moreOrLessEquals(names.left));
      }
      expectWholeWords(tester);
    });
  }
}
