import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/ui/theme/app_theme.dart';
import 'package:shnayim_mikra/ui/widgets/common.dart';
import 'package:shnayim_mikra/ui/widgets/ornaments.dart';

import '../../helpers.dart';

void main() {
  Future<void> openGuide(WidgetTester tester, AppLanguage language) async {
    tester.view.physicalSize = const Size(412, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await pumpApp(tester, settings: AppSettings(onboardingComplete: true, language: language));
    c.read(routerProvider).go('/guide');
    await tester.pumpAndSettle();
  }

  testWidgets('How it works gives every time to finish, and the special cases', (tester) async {
    await openGuide(tester, AppLanguage.english);
    expect(find.widgetWithText(AppBar, 'How it works'), findsOneWidget);
    // Before the meal, then until Mincha, then through Tuesday night, then
    // until Simchat Torah.
    final when = find.textContaining('Ideally finish before the Shabbat-day meal; if not, after the meal until Mincha.');
    expect(when, findsOneWidget);
    expect(find.textContaining('until Simchat Torah (SA 285:4; MB 285:12).'), findsOneWidget);
    expect(find.textContaining('may read Rashi in a language they understand (MB 285:5; Rav Moshe Feinstein)'), findsOneWidget);
    expect(find.textContaining('along with the ba’al koreh, word for word, counts as one of the readings (MB 285:14)'),
        findsOneWidget);
    expect(find.textContaining('do so as a voluntary mitzvah.'), findsOneWidget);
  });

  testWidgets('in Hebrew, איך זה עובד gives the same times and sources', (tester) async {
    await openGuide(tester, AppLanguage.hebrew);
    expect(find.widgetWithText(AppBar, 'איך זה עובד'), findsOneWidget);
    expect(find.textContaining('אחרי הסעודה עד מנחה'), findsOneWidget);
    expect(find.textContaining('(מ״ב רפה, ה; הרב משה פיינשטיין)'), findsOneWidget);
    expect(find.textContaining('(מ״ב רפה, יד)'), findsOneWidget);
  });

  testWidgets('opens with the Talmud\'s words, where they are written, and in English what they say', (tester) async {
    final handle = tester.ensureSemantics();
    await openGuide(tester, AppLanguage.english);
    final words = find.textContaining('שְׁנַיִם מִקְרָא וְאֶחָד תַּרְגּוּם');
    expect(words, findsOneWidget);
    // Read as one sentence, in a Hebrew voice.
    expect(
      tester.getSemantics(words),
      isSemantics(label: 'לְעוֹלָם יַשְׁלִים אָדָם פָּרָשִׁיּוֹתָיו עִם הַצִּבּוּר, שְׁנַיִם מִקְרָא וְאֶחָד תַּרְגּוּם'),
    );
    expect(find.text('Berakhot 8a'), findsOneWidget);
    expect(
      find.text('A person should always complete their portions with the community: the text twice and the Targum once.'),
      findsOneWidget,
    );
    handle.dispose();
  });

  testWidgets('in Hebrew, the Talmud\'s words need no translation', (tester) async {
    await openGuide(tester, AppLanguage.hebrew);
    expect(find.text('ברכות ח, א'), findsOneWidget);
    expect(find.textContaining('A person should always'), findsNothing);
    // What follows builds on them, rather than saying them again.
    expect(find.textContaining('לעולם ישלים אדם'), findsNothing);
    expect(find.textContaining('השולחן ערוך פוסק את דברי הגמרא האלה להלכה'), findsOneWidget);
  });

  testWidgets("what follows the Talmud's words builds on them rather than restating them", (tester) async {
    await openGuide(tester, AppLanguage.english);
    expect(find.textContaining('The Shulchan Aruch sets these words of the Talmud down as law'), findsOneWidget);
    expect(find.textContaining('the Torah text twice and the Targum once'), findsNothing);
  });

  for (final (width, padding) in [(412.0, 20.0), (320.0, 16.0)]) {
    testWidgets("the words' card keeps the card rhythm, $padding in at ${width.round()} dp", (tester) async {
      tester.view.physicalSize = Size(width, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = await pumpApp(tester, settings: const AppSettings(onboardingComplete: true));
      c.read(routerProvider).go('/guide');
      await tester.pumpAndSettle();
      final card = tester.getRect(find.ancestor(of: find.text('Berakhot 8a'), matching: find.byType(Card)).first);
      final source = tester.getRect(find.ancestor(of: find.text('Berakhot 8a'), matching: find.byType(Column)).first);
      expect(source.left - card.left, padding);
      expect(card.right - source.right, padding);
    });
  }

  testWidgets('sets its headings in ink, shows the three readings, and lists its sources a line each', (tester) async {
    await openGuide(tester, AppLanguage.english);
    final heading = tester.widget<Text>(find.text('Targum or Rashi'));
    final context = tester.element(find.text('Targum or Rashi'));
    expect(heading.style?.color, Theme.of(context).colorScheme.onSurface, reason: 'not blue');
    expect(heading.style, SeferType.of(context).longformHeading);

    // The three readings, as on every aliyah, under How.
    expect(find.byType(PassPips), findsOneWidget);
    expect(find.text('1\u00a0·\u00a0Mikra  2\u00a0·\u00a0Mikra  3\u00a0·\u00a0Targum'), findsOneWidget);
    expect(tester.getTopLeft(find.byType(PassPips)).dy, greaterThan(tester.getTopLeft(find.text('How')).dy));
    expect(tester.getTopLeft(find.byType(PassPips)).dy, lessThan(tester.getTopLeft(find.textContaining('Read verse by verse')).dy));

    for (final source in [
      'Berakhot 8a–b',
      'Shulchan Aruch, Orach Chaim 285',
      'Mishnah Berurah 285',
      'Kitzur Shulchan Aruch 72',
      'Shulchan Aruch HaRav 285',
    ]) {
      expect(find.text(source), findsOneWidget);
    }
    expect(find.byWidgetPredicate((w) => w is Lozenge && w.size == 6), findsNWidgets(5));
    expect(find.textContaining(' · Shulchan'), findsNothing);
    // Customs vary, and the closing word says so.
    expect(find.widgetWithText(NoticeBanner, 'Customs vary. For practical questions, ask your rav.'), findsOneWidget);
  });

  testWidgets('keeps its lines to a readable length on a wide screen', (tester) async {
    tester.view.physicalSize = const Size(1366, 4000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = await pumpApp(tester, settings: const AppSettings(onboardingComplete: true));
    c.read(routerProvider).go('/guide');
    await tester.pumpAndSettle();
    expect(tester.getSize(find.textContaining('Read verse by verse')).width, lessThanOrEqualTo(ContentWidth.longform));
  });
}
