import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/ui/widgets/lines.dart';

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
