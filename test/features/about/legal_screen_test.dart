import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/config.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/features/about/about_screen.dart';
import 'package:shnayim_mikra/features/about/legal_texts.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';

import '../../helpers.dart';

void main() {
  group('the policies file', () {
    final source = File('assets/legal/legal.json').readAsStringSync();
    final texts = LegalTexts.parse(source);

    test('has every policy in both languages, in the same shape', () {
      List<String> shape(List<LegalSection> sections) => [
            for (final s in sections) ...['${s.heading.isEmpty}', for (final b in s.blocks) '${b.runtimeType}'],
          ];
      for (final doc in LegalDoc.values) {
        final en = texts.sections(doc, hebrew: false, hasEmail: false);
        final he = texts.sections(doc, hebrew: true, hasEmail: false);
        expect(en.length, greaterThan(2), reason: doc.name);
        expect(shape(he), shape(en), reason: doc.name);
        expect(texts.updated(doc), isNotNull, reason: doc.name);
      }
      expect(texts.updated(LegalDoc.privacy), DateTime(2026, 10));
    });

    test('says how to reach us in a contact line alone, by {contact}', () {
      for (final doc in LegalDoc.values) {
        for (final hebrew in [false, true]) {
          final blocks = texts.sections(doc, hebrew: hebrew, hasEmail: false).expand((s) => s.blocks);
          for (final block in blocks) {
            final placeholders = RegExp(r'\{[^}]*\}').allMatches(block.text).map((m) => m[0]).toList();
            expect(placeholders, block is ContactLine ? ['{contact}'] : isEmpty, reason: block.text);
          }
        }
      }
      final privacy = texts.sections(LegalDoc.privacy, hebrew: true, hasEmail: false);
      expect((privacy.last.blocks.single as ContactLine).parts, ('שאלות ובקשות: ', ''));
    });

    test('keeps a section or block only where it applies', () {
      final sections = [
        {
          'heading': '',
          'blocks': [
            {'type': 'para', 'text': 'Always.'},
          ],
        },
        {
          'heading': 'By email',
          'when': 'email',
          'blocks': [
            {'type': 'contact', 'text': 'Write to {contact}.', 'subject': 'Hi'},
          ],
        },
        {
          'heading': 'Else',
          'blocks': [
            {'type': 'bullet', 'text': 'Without', 'when': 'no-email'},
            {'type': 'bullet', 'text': 'With', 'when': 'email'},
          ],
        },
      ];
      final texts = LegalTexts.parse(jsonEncode({
        for (final lang in ['en', 'he']) lang: {for (final doc in LegalDoc.values) doc.name: sections},
      }));
      String outline(bool hasEmail) => [
            for (final s in texts.sections(LegalDoc.privacy, hebrew: false, hasEmail: hasEmail))
              '${s.heading}: ${s.blocks.map((b) => b.text).join(', ')}',
          ].join(' | ');
      expect(outline(false), ': Always. | Else: Without');
      expect(outline(true), ': Always. | By email: Write to {contact}. | Else: With');
      final contact = texts.sections(LegalDoc.privacy, hebrew: false, hasEmail: true)[1].blocks.single as ContactLine;
      expect(contact.subject, 'Hi');
      expect(contact.parts, ('Write to ', '.'));
    });

    test('refuses a block it cannot show', () {
      expect(
        () => LegalBlock.fromJson(const {'type': 'table', 'text': 'x'}),
        throwsA(isA<FormatException>()),
      );
      expect(
        () => LegalBlock.fromJson(const {'type': 'para', 'text': 'x', 'when': 'sometimes'}),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('a policy', () {
    late List<String> launched;
    late List<String> copied;

    Future<void> open(
      WidgetTester tester,
      String doc, {
      AppLanguage language = AppLanguage.english,
      bool opens = true,
    }) async {
      launched = [];
      copied = [];
      const channel = MethodChannel('plugins.flutter.io/url_launcher');
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
        if (call.method == 'launch') launched.add((call.arguments as Map)['url'] as String);
        return opens;
      });
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied.add((call.arguments as Map)['text'] as String);
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, null));
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final c = await pumpApp(tester, settings: AppSettings(onboardingComplete: true, language: language));
      c.read(routerProvider).go('/legal/$doc');
      await tester.pumpAndSettle();
    }

    /// The opacity of the app bar's title.
    double titleOpacity(WidgetTester tester) => tester
        .widget<AnimatedOpacity>(find.descendant(of: find.byType(AppBar), matching: find.byType(AnimatedOpacity)))
        .opacity;

    testWidgets('heads its page with its title and the month it was last updated', (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester, 'privacy');
      final heading = find.descendant(of: find.byType(ListView), matching: find.text('Privacy'));
      expect(tester.getSemantics(heading), isSemantics(label: 'Privacy', isHeader: true));
      expect(find.text('Last updated: October 2026'), findsOneWidget);
      expect(find.text('Shnayim Mikra is built to need as little of your data as possible.'), findsOneWidget);
      // The app bar shows the title only once the heading has scrolled away.
      expect(titleOpacity(tester), 0);
      await tester.drag(find.byType(ListView), const Offset(0, -400));
      await tester.pumpAndSettle();
      expect(titleOpacity(tester), 1);
      handle.dispose();
    });

    testWidgets('in Hebrew, says when it was updated in Hebrew', (tester) async {
      await open(tester, 'privacy', language: AppLanguage.hebrew);
      expect(find.text('עודכן לאחרונה: אוקטובר 2026'), findsOneWidget);
      expect(find.textContaining('עודכן לאחרונה: אוקטובר 2026.'), findsNothing, reason: 'not in the text as well');
    });

    testWidgets('hangs a wrapped bullet from its bullet', (tester) async {
      await open(tester, 'accessibility');
      final item = find.ancestor(of: find.textContaining('A choice of how the Divine Name is spoken'), matching: find.byType(Row)).first;
      await tester.ensureVisible(item);
      await tester.pumpAndSettle();
      final bullet = tester.getRect(find.descendant(of: item, matching: find.text('•')));
      final text = tester.getRect(find.descendant(of: item, matching: find.byType(RichText)).last);
      // Every line of the item starts past the bullet: it runs to more than
      // one, all within the text's own column.
      expect(text.left, greaterThan(bullet.right));
      expect(text.height, greaterThan(bullet.height * 1.5));
      expect(find.textContaining('• '), findsNothing, reason: 'the bullet is drawn, not written');
    });

    /// The middle of [part] of the contact line [line].
    Offset centreOf(WidgetTester tester, Finder line, String part) {
      final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: line, matching: find.byType(RichText), matchRoot: true).first,
      );
      final start = paragraph.text.toPlainText(includeSemanticsLabels: false).indexOf(part);
      final box = paragraph.getBoxesForSelection(TextSelection(baseOffset: start, extentOffset: start + part.length)).first;
      return paragraph.localToGlobal(box.toRect().center);
    }

    testWidgets('links its contact, which opens the issue tracker where there is no address to email', (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester, 'privacy');
      final line = find.text('Questions or requests: GitHub issues', findRichText: true);
      await tester.ensureVisible(line);
      await tester.pumpAndSettle();
      expect(
        find.semantics.byLabel('GitHub issues').evaluate().single,
        matchesSemantics(label: 'GitHub issues', isLink: true, hasTapAction: true),
      );

      // Only the link opens it, not the words before it.
      await tester.tapAt(centreOf(tester, line, 'Questions'));
      expect(launched, isEmpty);
      await tester.tapAt(centreOf(tester, line, 'GitHub issues'));
      expect(launched, ['$issueTrackerUri']);
      handle.dispose();
    });

    testWidgets("says so where nothing opens the issue tracker's link", (tester) async {
      await open(tester, 'privacy', opens: false);
      final line = find.text('Questions or requests: GitHub issues', findRichText: true);
      await tester.ensureVisible(line);
      await tester.pumpAndSettle();
      await tester.tapAt(centreOf(tester, line, 'GitHub issues'));
      await tester.pumpAndSettle();
      expect(find.text("The link couldn't be opened here."), findsOneWidget);
    });

    testWidgets('can be selected and copied, its paragraphs one text', (tester) async {
      await open(tester, 'privacy');
      expect(find.byType(SelectionArea), findsOneWidget);
      final line = find.text('Questions or requests: GitHub issues', findRichText: true);
      expect(find.ancestor(of: line, matching: find.byType(SelectionArea)), findsOneWidget);
      expect(find.byType(SelectableText), findsNothing, reason: 'the page selects as a whole');
    });

    group('with an address to email', () {
      const email = 'help@example.org';
      setUp(() => AppConfig.debugSupportEmail = email);
      tearDown(() => AppConfig.debugSupportEmail = null);

      testWidgets('in Hebrew, links the address, isolated, at the end of the sentence, and emails it', (tester) async {
        final handle = tester.ensureSemantics();
        await open(tester, 'privacy', language: AppLanguage.hebrew);
        final line = find.textContaining(email, findRichText: true);
        await tester.ensureVisible(line);
        await tester.pumpAndSettle();
        expect(line, findsOneWidget);
        expect(
          tester.renderObject<RenderParagraph>(find.descendant(of: line, matching: find.byType(RichText), matchRoot: true).first)
              .text
              .toPlainText(includeSemanticsLabels: false),
          'שאלות ובקשות: \u2066$email\u2069',
        );
        // Read as the address alone, without the marks that isolate it.
        expect(
          find.semantics.byLabel(email).evaluate().single,
          matchesSemantics(label: email, isLink: true, hasTapAction: true),
        );
        // At the end of the Hebrew sentence: to the left of its words.
        final paragraph = tester.renderObject<RenderParagraph>(
          find.descendant(of: line, matching: find.byType(RichText), matchRoot: true).first,
        );
        double leftOf(String part) {
          final start = paragraph.text.toPlainText(includeSemanticsLabels: false).indexOf(part);
          return paragraph
              .getBoxesForSelection(TextSelection(baseOffset: start, extentOffset: start + part.length))
              .map((b) => b.left)
              .reduce((a, b) => a < b ? a : b);
        }

        expect(leftOf(email), lessThan(leftOf('שאלות')));
        await tester.tapAt(centreOf(tester, line, email));
        expect(launched.single, startsWith('mailto:$email?subject='));
        handle.dispose();
      });

      testWidgets('copied from a selection, the address comes without the marks that isolate it', (tester) async {
        await open(tester, 'privacy', language: AppLanguage.hebrew);
        final line = find.textContaining(email, findRichText: true);
        await tester.ensureVisible(line);
        await tester.pumpAndSettle();
        // Everything on the page selected, the address and its marks with it.
        tester.state<SelectableRegionState>(find.byType(SelectableRegion)).selectAll(SelectionChangedCause.keyboard);
        await tester.pumpAndSettle();
        Actions.invoke(tester.element(line), CopySelectionTextIntent.copy);
        await tester.pump();
        expect(copied, isNotEmpty);
        expect(copied.last, contains(email));
        expect(copied.last, isNot(contains(RegExp('[\u2066-\u2069]'))));
      });

      testWidgets('where no mail app opens, says so and offers the address to copy, bare', (tester) async {
        await open(tester, 'privacy', language: AppLanguage.hebrew, opens: false);
        final line = find.textContaining(email, findRichText: true);
        await tester.ensureVisible(line);
        await tester.pumpAndSettle();
        await tester.tapAt(centreOf(tester, line, email));
        await tester.pumpAndSettle();
        expect(find.text('לא נפתחה תוכנת דואר. אפשר לכתוב אל \u2066$email\u2069.'), findsOneWidget);
        await tester.tap(find.text('העתקה'));
        await tester.pumpAndSettle();
        expect(copied, [email]);
      });
    });

    testWidgets('opens its contact from the keyboard', (tester) async {
      await open(tester, 'accessibility');
      final line = find.textContaining('GitHub issues', findRichText: true);
      await tester.ensureVisible(line);
      await tester.pumpAndSettle();
      Focus.of(tester.element(line)).requestFocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(launched, ['$issueTrackerUri']);
    });
  });
}
