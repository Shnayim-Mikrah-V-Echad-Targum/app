import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikrah/app/router.dart';
import 'package:shnayim_mikrah/features/settings/app_settings.dart';
import 'package:shnayim_mikrah/l10n/app_localizations.dart';
import 'package:shnayim_mikrah/ui/theme/app_theme.dart';
import 'package:shnayim_mikrah/ui/widgets/common.dart';
import 'package:shnayim_mikrah/ui/widgets/ornaments.dart';

import '../../helpers.dart';

/// Where [element]'s render box is on the screen.
Rect rectOf(Element element) {
  final box = element.renderObject! as RenderBox;
  return box.localToGlobal(Offset.zero) & box.size;
}

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
    // Before the meal, then until Mincha, then until Tuesday night, as the
    // setting for the late days says, then until Simchat Torah.
    final when = find.textContaining('Ideally finish before the Shabbat-day meal; if not, after the meal until Mincha.');
    expect(when, findsOneWidget);
    expect(find.textContaining('may still be completed until Tuesday night (“until Wednesday”)'), findsOneWidget);
    expect(find.textContaining('through Tuesday'), findsNothing);
    expect(find.textContaining('until Simchat Torah (SA\u00a0285:4; MB\u00a0285:12).'), findsOneWidget);
    expect(find.textContaining('may read Rashi in a language they understand (MB\u00a0285:5; Rav Moshe Feinstein)'),
        findsOneWidget);
    expect(
        find.textContaining('along with the ba’al koreh, word for word, counts as one of the readings (MB\u00a0285:14)'),
        findsOneWidget);
    expect(find.textContaining('women are exempt, and those who take it on do so as a voluntary mitzvah'),
        findsOneWidget);
    expect(find.textContaining('boys are trained in it from the age of chinuch.'), findsOneWidget);
  });

  testWidgets('in Hebrew, איך זה עובד gives the same times and sources', (tester) async {
    await openGuide(tester, AppLanguage.hebrew);
    expect(find.widgetWithText(AppBar, 'איך זה עובד'), findsOneWidget);
    expect(find.textContaining('אחרי הסעודה עד מנחה'), findsOneWidget);
    expect(find.textContaining('(מ״ב\u00a0רפה,\u00a0ה; הרב משה פיינשטיין)'), findsOneWidget);
    expect(find.textContaining('(מ״ב\u00a0רפה,\u00a0יד)'), findsOneWidget);
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
    expect(find.text('Berachot 8a'), findsOneWidget);
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
    expect(find.textContaining('השולחן ערוך פוסק את דברי הגמרא להלכה'), findsOneWidget);
  });

  testWidgets("what follows the Talmud's words builds on them rather than restating them", (tester) async {
    await openGuide(tester, AppLanguage.english);
    expect(find.textContaining('The Shulchan Aruch sets the Talmud’s words down as law'), findsOneWidget);
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
      final card = tester.getRect(find.ancestor(of: find.text('Berachot 8a'), matching: find.byType(Card)).first);
      final source = tester.getRect(find.ancestor(of: find.text('Berachot 8a'), matching: find.byType(Column)).first);
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
      'Berachot 8a–b',
      'Shulchan Aruch, Orach Chaim 285',
      'Mishnah Berurah 285',
      'Kitzur Shulchan Aruch 72',
      'Shulchan Aruch HaRav 285',
    ]) {
      expect(find.text(source), findsOneWidget);
    }
    // A lozenge before each source, as before each point on using the app
    // and each special case.
    expect(find.byWidgetPredicate((w) => w is Lozenge && w.size == 6), findsNWidgets(5 + 5 + 7));
    expect(find.textContaining(' · Shulchan'), findsNothing);
    // Customs vary, and the closing word says so.
    expect(find.widgetWithText(NoticeBanner, 'Customs vary. For practical questions, ask your rav.'), findsOneWidget);
  });

  for (final (language, title, points, next) in [
    (
      AppLanguage.english,
      'Using the app',
      [
        'Today shows this week’s parsha and today’s reading.',
        'Read from a printed Chumash? Tap “I read it in a Chumash”.',
        'Missed a day? Read it with the next day’s reading',
        'Press and hold a verse to bookmark it',
        'Listen reads the text aloud for you to follow — an aid, not a substitute for reading.',
      ],
      'What is Shnayim Mikrah?',
    ),
    (
      AppLanguage.hebrew,
      'השימוש באפליקציה',
      [
        'מסך היום מציג את פרשת השבוע ואת הקריאה של היום.',
        'קוראים מתוך חומש מודפס? ״קראתי בחומש״ רושם את הקריאה',
        'יום שהוחמץ? קריאתו יחד עם הקריאה של למחרת משלימה אותו',
        'לחיצה ארוכה על פסוק: סימנייה, הערה, העתקה, שיתוף או שאלה.',
        'השמעה מקריאה את הטקסט כדי לעקוב אחריו — עזר, לא תחליף לקריאה.',
      ],
      'מהו שניים מקרא?',
    ),
  ]) {
    testWidgets('opens with $title under the Talmud\'s words: five points, one after each lozenge', (tester) async {
      await openGuide(tester, language);
      final heading = tester.getRect(find.text(title));
      final words = find.textContaining('שְׁנַיִם מִקְרָא');
      final card = tester.getRect(find.ancestor(of: words, matching: find.byType(Card)));
      final practice = tester.getRect(find.text(next));
      expect(heading.top, greaterThan(card.bottom));
      expect(heading.bottom, lessThan(practice.top), reason: 'the first section, before the practice');

      // The points in order, between the heading and the practice, each a
      // gap from its lozenge at the start of the line, its wrapped lines
      // hanging beside it.
      final rtl = language == AppLanguage.hebrew;
      final lozenges = find.byWidgetPredicate((w) => w is Lozenge && w.size == 6).evaluate().map(rectOf).toList();
      var above = heading.bottom;
      for (final point in points) {
        final text = tester.getRect(find.textContaining(point));
        expect(text.top, greaterThan(above));
        expect(text.bottom, lessThan(practice.top));
        final lozenge = lozenges.firstWhere((r) => r.top >= text.top && r.bottom <= text.top + 32);
        if (rtl) {
          expect(text.right, lozenge.left - Space.md);
        } else {
          expect(text.left, lozenge.right + Space.md);
        }
        above = text.bottom;
      }
      // Even where a point has a colon, nothing in this list is a lead-in.
      for (final point in points) {
        final item = tester.widget<SelectableText>(
          find.ancestor(of: find.textContaining(point), matching: find.byType(SelectableText)),
        );
        expect(item.textSpan, isNull);
        expect(item.style, SeferType.of(tester.element(find.text(title))).longformBody);
      }
    });
  }

  for (final (language, weight, leadIns) in [
    (
      AppLanguage.english,
      // Semibold over EB Garamond's Medium.
      FontWeight.w600,
      [
        'Atarot v’Divon (Numbers 32:3):',
        'Vezot HaBerachah:',
        'The haftarah:',
        'In shul:',
        'Two portions:',
        'No blessing:',
        'Women and children:',
      ],
    ),
    (
      AppLanguage.hebrew,
      // Bold over Frank Ruhl Libre's Medium, whose Semibold barely shows.
      FontWeight.w700,
      [
        'עטרות ודיבון (במדבר לב, ג):',
        'וזאת הברכה:',
        'ההפטרה:',
        'בבית הכנסת:',
        'שתי פרשות:',
        'בלי ברכה:',
        'נשים וילדים:',
      ],
    ),
  ]) {
    testWidgets('in ${language.name}, sets the special cases as seven items, each led by its case, heavier',
        (tester) async {
      await openGuide(tester, language);
      final finder = find.byWidgetPredicate((w) => w is SelectableText && w.textSpan != null);
      final items = tester.widgetList<SelectableText>(finder).toList();
      expect(items, hasLength(leadIns.length));
      final body = SeferType.of(tester.element(finder.first)).longformBody;
      for (final (i, item) in items.indexed) {
        expect(item.style, body, reason: 'upright, in the long-form body');
        final [lead, rest] = item.textSpan!.children!.cast<TextSpan>();
        expect(lead.text, leadIns[i]);
        expect(lead.style?.fontWeight, weight);
        expect(rest.style, isNull, reason: 'the rest in the body’s own weight');
        expect(rest.text, startsWith(' '));
      }
      // One item after another, 8 apart.
      final rects = finder.evaluate().map(rectOf).toList();
      for (var i = 1; i < rects.length; i++) {
        expect(rects[i].top - rects[i - 1].bottom, closeTo(Space.sm, 0.01));
      }
    });
  }

  // A lead-in is always set apart from the text after it: heavier by a step
  // that shows, or, where the text is Bold already and no heavier weight is
  // left, on a line of its own.
  for (final (name, settings, body, lead) in [
    ('in English', const AppSettings(), FontWeight.w500, FontWeight.w600),
    ('in Hebrew', const AppSettings(language: AppLanguage.hebrew), FontWeight.w500, FontWeight.w700),
    // High contrast sets the serifs heavier: EB Garamond in Semibold, Frank
    // Ruhl Libre in Bold, the heaviest bundled.
    ('in high contrast', const AppSettings(theme: AppThemeMode.highContrastDark), FontWeight.w600, FontWeight.w700),
    (
      'in Hebrew in high contrast',
      const AppSettings(theme: AppThemeMode.highContrastDark, language: AppLanguage.hebrew),
      FontWeight.w700,
      null,
    ),
    // The accessibility fonts bundle Regular and Bold only.
    ('in an accessibility font', const AppSettings(uiFont: UiFont.atkinson), FontWeight.w400, FontWeight.w700),
    ('with Bold text', const AppSettings(boldText: true), FontWeight.w700, null),
    // The low-vision preset turns Bold text on, as the high-contrast one does.
    (
      'with the low-vision preset',
      applyPreset(const AppSettings(), DisplayPreset.lowVision, darkPreferred: false),
      FontWeight.w700,
      null,
    ),
  ]) {
    testWidgets('$name, the text is set in its weight, and a lead-in stands apart from it', (tester) async {
      tester.view.physicalSize = const Size(412, 4000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = await pumpApp(tester, settings: settings.copyWith(onboardingComplete: true));
      c.read(routerProvider).go('/guide');
      await tester.pumpAndSettle();
      final selectable = find.byType(SelectableText);
      expect(selectable, findsWidgets);
      for (final text in tester.widgetList<SelectableText>(selectable)) {
        if (text.style!.fontStyle == FontStyle.italic) continue; // the sources' marginalia
        expect(text.style?.fontWeight, body);
      }
      final finder = find.byWidgetPredicate((w) => w is SelectableText && w.textSpan != null);
      final items = tester.widgetList<SelectableText>(finder).toList();
      expect(items, hasLength(7));
      for (final (i, item) in items.indexed) {
        final [first, rest] = item.textSpan!.children!.cast<TextSpan>();
        if (lead != null) {
          expect(first.style?.fontWeight, lead);
          expect(rest.text, startsWith(' '), reason: 'the text runs on after the lead-in');
        } else {
          // As heavy as the text: on a line of its own, above it.
          expect(first.style?.fontWeight, isNull);
          expect(first.text, endsWith(':\n'));
          expect(rest.text, isNot(startsWith(' ')));
          final paragraph = tester
              .state<EditableTextState>(find.descendant(of: finder.at(i), matching: find.byType(EditableText)))
              .renderEditable;
          final leadEnd = first.text!.length - 1;
          final leadLine = paragraph.getBoxesForSelection(TextSelection(baseOffset: 0, extentOffset: leadEnd)).last;
          final restLine =
              paragraph.getBoxesForSelection(TextSelection(baseOffset: leadEnd + 1, extentOffset: leadEnd + 2)).first;
          expect(restLine.top, greaterThanOrEqualTo(leadLine.bottom - 0.5), reason: 'the text begins under it');
        }
      }
    });
  }

  testWidgets('at twice the text size, its lozenges grow with the text, level with the first line', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearAllTestValues);
    await openGuide(tester, AppLanguage.english);
    final point = find.textContaining('Press and hold a verse');
    final text = tester.getRect(point);
    final line = SeferType.of(tester.element(point)).longformBody;
    final firstLine = line.fontSize! * 2 * line.height!;
    final lozenge = find.byWidgetPredicate((w) => w is Lozenge && w.size == 12).evaluate().map(rectOf).firstWhere(
          (r) => r.top >= text.top && r.bottom <= text.top + firstLine,
        );
    expect(lozenge.center.dy, closeTo(text.top + firstLine / 2, 0.5));
  });

  // Using the app names the buttons and the tab as the app labels them, so a
  // label renamed must be renamed in the guide too.
  test('names Today, its Chumash button and Listen as the app does, in either language', () {
    for (final l in [lookupAppLocalizations(const Locale('en')), lookupAppLocalizations(const Locale('he'))]) {
      expect(l.guideAppBody, contains(l.navToday), reason: l.localeName);
      expect(l.guideAppBody, contains(l.readFromBook), reason: l.localeName);
      expect(l.guideAppBody, contains(l.listen), reason: l.localeName);
    }
  });

  test('keeps each source in a sentence to one line, and never starts a line with a dash', () {
    final source = RegExp(r'\b(SA|MB|Berachot|Numbers|Chaim) \d|(שו״ע|מ״ב|במדבר|ברכות|סימן) |רפה, ');
    for (final l in [lookupAppLocalizations(const Locale('en')), lookupAppLocalizations(const Locale('he'))]) {
      for (final text in [
        l.guideAppBody,
        l.guideWhatBody,
        l.guideWhenBody,
        l.guideHowBody,
        l.guideTargumBody,
        l.guideSpecialBody,
      ]) {
        expect(source.hasMatch(text), isFalse, reason: 'A no-break space keeps a source whole: $text');
        expect(text, isNot(contains(' —')), reason: 'A no-break space keeps a dash with the word before it: $text');
      }
    }
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
