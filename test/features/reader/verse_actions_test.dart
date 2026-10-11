import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/core/text/hebrew_text.dart';
import 'package:shnayim_mikra/data/models/scripture.dart';
import 'package:shnayim_mikra/data/models/verse_ref.dart';
import 'package:shnayim_mikra/data/text_repository.dart';
import 'package:shnayim_mikra/features/community/ui/compose_screen.dart';
import 'package:shnayim_mikra/features/reader/reader_screen.dart';
import 'package:shnayim_mikra/features/reader/scripture_text.dart';
import 'package:shnayim_mikra/features/reader/verse_actions_sheet.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/ui/widgets/common.dart';
import 'package:shnayim_mikra/ui/widgets/sefer_choice_chip.dart';

import '../../helpers.dart';

/// The share sheet, which keeps what it was asked to share, or fails as a
/// platform with none would.
class _ShareSheet extends SharePlatform {
  final shared = <ShareParams>[];
  bool fails = false;

  @override
  Future<ShareResult> share(ShareParams params) async {
    if (fails) throw UnimplementedError('no share sheet');
    shared.add(params);
    return const ShareResult('', ShareResultStatus.dismissed);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // Friday of Bereshit 5787, whose Revi'i begins at Genesis 3:22, and whose
  // haftarah is Machar Chodesh's, from I Samuel 20:18.
  final friday = DateTime(2026, 10, 9, 11);
  const genesis3_22 = BookVerse('Genesis', VerseRef(3, 22));
  // SharePlus keeps the platform it first finds, so one sheet serves every
  // test.
  final sheet = _ShareSheet();
  SharePlatform.instance = sheet;

  late BookText mikra;
  late BookText onkelos;
  late BookText english;
  late Verse samuel20_18;
  // Genesis 3:22 as the data writes it: the Divine Name, and the verse with
  // the Name written ה׳ in its place.
  late String name;
  late String hebrew3_22;
  setUpAll(() async {
    final repo = TextRepository();
    mikra = await repo.book(TextLayer.mikra, 'Genesis');
    onkelos = await repo.book(TextLayer.onkelos, 'Genesis');
    english = await repo.book(TextLayer.english, 'Genesis');
    samuel20_18 = (await repo.hebrewVerse(const BookVerse('I Samuel', VerseRef(20, 18))))!;
    final raw = mikra.verse(genesis3_22.ref).readText;
    name = raw.split(' ').singleWhere((w) => HebrewText.consonantsOnly(w) == 'יהוה');
    hebrew3_22 = raw.replaceFirst(name, 'ה׳');
  });

  group('the text that leaves the app', () {
    test('is the verse as shown, with the Divine Name written ה׳', () {
      final text = verseText(mikra.verse(genesis3_22.ref), const AppSettings());
      expect(text, hebrew3_22);
      expect(HebrewText.consonantsOnly(text), startsWith('ויאמר ה׳ אלהים הן האדם'));
      expect(HebrewText.consonantsOnly(text), isNot(contains('יהוה')));
      // Nothing the screen adds to keep words together travels with it.
      expect(text, isNot(contains('\u2060')));
      expect(text, isNot(contains('\u00a0')));
    });

    test('follows what the reader shows, and the Name as the reader chooses', () {
      final verse = mikra.verse(genesis3_22.ref);
      // The paseq goes with the cantillation.
      expect(verseText(verse, const AppSettings(showTeamim: false)), HebrewText.stripTeamim(hebrew3_22));
      expect(
        verseText(verse, const AppSettings(showNikud: false, showTeamim: false)),
        HebrewText.forDisplay(hebrew3_22, nikud: false, teamim: false),
      );
      expect(verseText(verse, const AppSettings(copyDivineNameAsHashem: false)), verse.readText);
    });

    test('reads the qere, gives the ketiv where it is shown, and leaves notes out', () {
      const verse = Verse(VerseRef(1, 1), [
        PlainText('ויאמר '),
        KetivQere('ויצו', 'ויצוה'),
        PlainText(' את־'),
        SizedLetters('ב', LetterSize.large),
        PlainText('ית'),
        TextNote('A note on the scroll.'),
        PisqaGap(SectionBreak.open),
        PlainText('ליהוה׃'),
      ]);
      expect(verseText(verse, const AppSettings()), 'ויאמר ויצוה (ויצו) את־בית לה׳׃');
      expect(verseText(verse, const AppSettings(showKetiv: false)), 'ויאמר ויצוה את־בית לה׳׃');
      // Written but not read.
      expect(verseText(const Verse(VerseRef(1, 1), [PlainText('א '), KetivQere('ב', ''), PlainText(' ג')]), const AppSettings()), 'א [ב] ג');
      // A gloss in the Targum, as it is shown.
      expect(verseText(const Verse(VerseRef(1, 1), [PlainText('א'), AlternateReading('ב'), PlainText('ג')]), const AppSettings()), 'א (ב) ג');
    });

    test('copied or shared, has the Targum and the translation where shown, then the reference', () {
      final r = genesis3_22.ref;
      final chosen = ChosenVerse(
        at: genesis3_22,
        hebrew: mikra.verse(r),
        targum: onkelos.verse(r),
        english: english.verse(r).readText,
      );
      final lines = verseCopy(chosen, const AppSettings(), reference: 'Genesis 3:22').split('\n');
      expect(lines, hasLength(4));
      expect(lines[0], verseText(mikra.verse(r), const AppSettings()));
      expect(lines[1], onkelos.verse(r).readText);
      expect(lines[2], startsWith('And the LORD God said'));
      expect(lines[3], '— Genesis 3:22');
      expect(
        verseCopy(ChosenVerse(at: genesis3_22, hebrew: mikra.verse(r)), const AppSettings(), reference: 'בראשית ג, כב'),
        '${lines[0]}\n— בראשית ג, כב',
      );
    });

    test('quoted in a question, runs from the left in the English UI, where the question will', () {
      final verse = mikra.verse(genesis3_22.ref);
      final hebrew = verseText(verse, const AppSettings());
      expect(verseQuote(verse, const AppSettings(), leftToRight: true), '\u200E> $hebrew\n\n');
      expect(verseQuote(verse, const AppSettings(), leftToRight: false), '> $hebrew\n\n');
    });

    test('asks in Questions & answers, naming the verse as a link does', () {
      final uri = Uri.parse(askAboutVersePath(genesis3_22));
      expect(uri.path, '/community/new');
      expect(uri.queryParameters, {'forum': 'questions', 'verse': 'Genesis 3:22'});
      expect(BookVerse.tryParse(uri.queryParameters['verse']), genesis3_22);
    });
  });

  group('BookVerse', () {
    test('reads a verse as a link names it', () {
      expect(BookVerse.tryParse('Genesis 3:22'), genesis3_22);
      expect(BookVerse.tryParse('I Samuel 20:18'), const BookVerse('I Samuel', VerseRef(20, 18)));
      expect(BookVerse.tryParse(' Isaiah  42:5 '), const BookVerse('Isaiah', VerseRef(42, 5)));
      expect('${const BookVerse('I Samuel', VerseRef(20, 18))}', 'I Samuel 20:18');
    });

    test('takes nothing else', () {
      for (final s in [null, '', 'Genesis', 'Genesis 3', '3:22', 'Genesis 0:1', 'Genesis 3:22:1', 'בראשית 3:22']) {
        expect(BookVerse.tryParse(s), isNull, reason: s);
      }
    });
  });

  group('in the app', () {
    String? copied;
    setUp(() {
      copied = null;
      sheet
        ..shared.clear()
        ..fails = false;
    });

    Future<ProviderContainer> open(
      WidgetTester tester,
      String route, {
      AppSettings settings = const AppSettings(onboardingComplete: true),
      Map<String, Object> stored = const {},
    }) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      final c = await pumpApp(tester, settings: settings, now: friday, stored: stored);
      c.read(routerProvider).go(route);
      await tester.pump();
      await tester.pump();
      // The texts load on real I/O.
      for (var i = 0; i < 30 && find.byType(CircularProgressIndicator).evaluate().isNotEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      return c;
    }

    Finder inSheet(Finder finder) => find.descendant(of: find.byType(BottomSheet), matching: finder);

    /// Waits for a new discussion's message to quote its verse, whose text
    /// loads on real I/O, or for long enough to be sure it won't.
    Future<void> untilQuoted(WidgetTester tester) async {
      bool quoted() => find.byType(TextField).evaluate().length > 1 &&
          tester.widgetList<TextField>(find.byType(TextField)).elementAt(1).controller!.text.isNotEmpty;
      for (var i = 0; i < 20 && !quoted(); i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
      }
      await tester.pumpAndSettle();
    }

    testWidgets('a long press on Genesis 3:22 copies the pointed verse with ה׳ and its reference', (tester) async {
      await open(tester, '/read/5787:1/3');
      await tester.longPress(find.byType(ScriptureVerse).first);
      await tester.pumpAndSettle();
      expect(inSheet(find.text('Genesis 3:22')), findsOneWidget);

      await tester.tap(inSheet(find.text('Copy')));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Verse copied'), findsOneWidget);
      final lines = copied!.split('\n');
      expect(lines.first, hebrew3_22);
      expect(lines[1], onkelos.verse(genesis3_22.ref).readText, reason: 'the Targum, which the reader reads');
      expect(lines.last, '— Genesis 3:22');
    });

    testWidgets('screen readers find "Verse options" among a verse\'s actions', (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester, '/read/5787:1/3');
      const options = CustomSemanticsAction(label: 'Verse options');
      final verse = tester.getSemantics(find.byType(ScriptureVerse).first);
      expect(verse.label, startsWith('Verse 22. '));
      expect(verse, isSemantics(hasLongPressAction: true, customActions: [options]));
      tester.semantics.customAction(find.semantics.byLabel(RegExp(r'^Verse 22\. ')), options);
      await tester.pumpAndSettle();
      expect(inSheet(find.text('Genesis 3:22')), findsOneWidget);
      handle.dispose();
    });

    testWidgets('in the Hebrew UI, the reference is in Hebrew', (tester) async {
      await open(tester, '/read/5787:1/3', settings: const AppSettings(onboardingComplete: true, language: AppLanguage.hebrew));
      await tester.longPress(find.byType(ScriptureVerse).first);
      await tester.pumpAndSettle();
      expect(inSheet(find.text('בראשית ג, כב')), findsOneWidget);
      await tester.tap(inSheet(find.text('העתקה')));
      await tester.pumpAndSettle();
      expect(copied!.split('\n').last, '— בראשית ג, כב');
    });

    testWidgets('the Name is written out where the reader asks for that', (tester) async {
      await open(
        tester,
        '/read/5787:1/3',
        settings: const AppSettings(onboardingComplete: true, copyDivineNameAsHashem: false),
      );
      await tester.longPress(find.byType(ScriptureVerse).first);
      await tester.pumpAndSettle();
      await tester.tap(inSheet(find.text('Copy')));
      await tester.pumpAndSettle();
      expect(copied, contains(name));
      expect(copied, isNot(contains('ה׳')));
    });

    testWidgets('a secondary click opens the options too, and Shift+F10 those of the verse in view', (tester) async {
      await open(tester, '/read/5787:1/3');
      await tester.tap(find.byType(ScriptureVerse).first, buttons: kSecondaryButton, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      expect(inSheet(find.text('Genesis 3:22')), findsOneWidget);
      Navigator.pop(tester.element(find.byType(BottomSheet)));
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyEvent(LogicalKeyboardKey.f10);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
      await tester.pumpAndSettle();
      expect(inSheet(find.text('Genesis 3:22')), findsOneWidget);
    });

    testWidgets('the shortcuts list the key for a verse\'s options', (tester) async {
      await open(tester, '/read/5787:1/3');
      await tester.sendKeyEvent(LogicalKeyboardKey.f1);
      await tester.pumpAndSettle();
      expect(find.text('Verse options: copy, share or ask'), findsOneWidget);
    });

    testWidgets('in the full text, a long press anywhere in a verse\'s block opens its options', (tester) async {
      final handle = tester.ensureSemantics();
      await open(tester, '/read/5787:1/3?mode=full', settings: const AppSettings(onboardingComplete: true, showTranslation: true));
      // On the Targum, beneath the verse.
      await tester.longPress(find.byType(ScriptureVerse).at(1));
      await tester.pumpAndSettle();
      expect(inSheet(find.text('Genesis 3:22')), findsOneWidget);
      await tester.tap(inSheet(find.text('Copy')));
      await tester.pumpAndSettle();
      expect(copied!.split('\n'), hasLength(4), reason: 'the verse, its Targum, its translation and its reference');

      // Screen readers hear the options on the verse and its Targum, which
      // stay nodes of their own.
      const options = CustomSemanticsAction(label: 'Verse options');
      final verse = tester.getSemantics(find.byType(ScriptureVerse).at(0));
      final targum = tester.getSemantics(find.byType(ScriptureVerse).at(1));
      expect(verse.label, startsWith('Verse 22. '));
      expect(targum.label, startsWith('Targum, verse 22. '));
      for (final node in [verse, targum]) {
        expect(node, isSemantics(hasLongPressAction: true, customActions: [options]));
      }
      handle.dispose();
    });

    testWidgets('sharing shares the verse from its row, and closes the sheet once done', (tester) async {
      await open(tester, '/read/5787:1/3');
      await tester.longPress(find.byType(ScriptureVerse).first);
      await tester.pumpAndSettle();
      final row = tester.getRect(find.ancestor(of: inSheet(find.text('Share')), matching: find.byType(InkWell)).first);
      await tester.tap(inSheet(find.text('Share')));
      await tester.pumpAndSettle();
      final params = sheet.shared.single;
      expect(params.text, startsWith(hebrew3_22));
      expect(params.text, endsWith('— Genesis 3:22'));
      expect(params.subject, 'Genesis 3:22');
      expect(params.sharePositionOrigin, row);
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.byType(SnackBar), findsNothing, reason: 'the share sheet says for itself what became of it');
    });

    testWidgets('where nothing can share, the verse is copied instead, and the page says so', (tester) async {
      sheet.fails = true;
      await open(tester, '/read/5787:1/3');
      await tester.longPress(find.byType(ScriptureVerse).first);
      await tester.pumpAndSettle();
      await tester.tap(inSheet(find.text('Share')));
      await tester.pumpAndSettle();
      expect(copied, endsWith('— Genesis 3:22'));
      expect(find.text("Sharing isn't available here, so the verse was copied."), findsOneWidget);
    });

    testWidgets('asking about the verse begins a question on it in Questions & answers', (tester) async {
      final c = await open(tester, '/read/5787:1/3');
      await tester.longPress(find.byType(ScriptureVerse).first);
      await tester.pumpAndSettle();
      await tester.tap(inSheet(find.text('Ask about this verse')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(ReaderScreen), findsNothing);
      expect(find.byType(ComposeScreen), findsOneWidget);
      expect(c.read(routerProvider).routerDelegate.currentConfiguration.uri.queryParameters['verse'], 'Genesis 3:22');
      final chosen = tester.widgetList<SeferChoiceChip>(find.byType(SeferChoiceChip)).where((chip) => chip.selected);
      expect(find.descendant(of: find.byWidget(chosen.single), matching: find.text('Questions & answers')), findsOneWidget);

      final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
      expect(fields[0].controller!.text, 'Question on Genesis 3:22');
      final body = fields[1].controller!;
      expect(body.text, '\u200E> $hebrew3_22\n\n');
      expect(body.selection, TextSelection.collapsed(offset: body.text.length), reason: 'the question goes after it');
      await tester.pump(const Duration(seconds: 1));
      expect(c.read(sharedPreferencesProvider).getString('draft.newThread'), contains('Question on Genesis 3:22'));
    });

    testWidgets('a draft not yet sent is kept, and discarding it begins the question', (tester) async {
      final draft = jsonEncode({'title': 'On the names of places', 'body': 'Why does Onkelos keep some names'});
      await open(tester, '/community/new?forum=questions&verse=Genesis%203:22', stored: {'draft.newThread': draft});
      TextEditingController field(int i) => tester.widgetList<TextField>(find.byType(TextField)).elementAt(i).controller!;
      expect(field(0).text, 'On the names of places');
      expect(field(1).text, 'Why does Onkelos keep some names');
      final banner = find.byType(NoticeBanner);
      expect(
        find.descendant(of: banner, matching: find.text('Your unsent draft is kept. Discard it to ask about Genesis 3:22 instead.')),
        findsOneWidget,
      );

      await tester.tap(find.descendant(of: banner, matching: find.text('Discard draft')));
      await untilQuoted(tester);
      expect(banner, findsNothing);
      expect(field(0).text, 'Question on Genesis 3:22');
      expect(field(1).text, '\u200E> $hebrew3_22\n\n');
      final message = find.descendant(of: find.byType(TextField).at(1), matching: find.byType(EditableText));
      expect(tester.widget<EditableText>(message).focusNode.hasFocus, isTrue, reason: 'where the question goes');

      // Once begun, discarding the question clears it, as any draft.
      await tester.tap(find.text('Discard draft'));
      await tester.pumpAndSettle();
      expect(field(0).text, isEmpty);
      expect(field(1).text, isEmpty);
    });

    testWidgets('in the Hebrew UI, the question is in Hebrew and runs from the right', (tester) async {
      await open(
        tester,
        '/community/new?forum=questions&verse=Genesis%203:22',
        settings: const AppSettings(onboardingComplete: true, language: AppLanguage.hebrew),
      );
      await untilQuoted(tester);
      final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
      expect(fields[0].controller!.text, 'שאלה על בראשית ג, כב');
      expect(fields[1].controller!.text, '> $hebrew3_22\n\n');
    });

    testWidgets('a verse that can\'t be read begins nothing', (tester) async {
      await open(tester, '/community/new?forum=questions&verse=Genesis%2099:1');
      await untilQuoted(tester);
      final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
      expect(fields[0].controller!.text, 'Question on Genesis 99:1', reason: 'named, as asked');
      expect(fields[1].controller!.text, isEmpty, reason: 'there is no such verse to quote');
    });

    testWidgets('in the haftarah, a verse of the Prophets has its options, and its question its text', (tester) async {
      await open(tester, '/haftarah/5787:1');
      await tester.longPress(find.byType(ScriptureVerse).first);
      await tester.pumpAndSettle();
      expect(inSheet(find.text('I Samuel 20:18')), findsOneWidget);
      await tester.tap(inSheet(find.text('Copy')));
      await tester.pumpAndSettle();
      expect(copied, endsWith('\n— I Samuel 20:18'));
      expect(copied!.split('\n'), hasLength(2), reason: 'no Targum or translation shown');

      // From the keyboard, the first verse in view.
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyEvent(LogicalKeyboardKey.f10);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
      await tester.pumpAndSettle();
      expect(inSheet(find.text('I Samuel 20:18')), findsOneWidget);

      await tester.tap(inSheet(find.text('Ask about this verse')));
      await untilQuoted(tester);
      final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
      expect(fields[0].controller!.text, 'Question on I Samuel 20:18');
      expect(fields[1].controller!.text, '\u200E> ${samuel20_18.readText}\n\n');
    });

    testWidgets('Display has the switch for the Divine Name, on by default', (tester) async {
      final c = await open(tester, '/settings/display');
      final row = find.widgetWithText(SwitchListTile, 'Write the Divine Name as ה׳');
      await tester.scrollUntilVisible(row, 200, scrollable: find.byType(Scrollable).first);
      await Scrollable.ensureVisible(tester.element(row), alignment: 0.5);
      await tester.pumpAndSettle();
      expect(find.text('In a verse copied, shared or quoted in a question'), findsOneWidget);
      expect(tester.widget<SwitchListTile>(row).value, isTrue);
      await tester.tap(find.descendant(of: row, matching: find.byType(Switch)));
      await tester.pumpAndSettle();
      expect(c.read(settingsProvider).copyDivineNameAsHashem, isFalse);
    });
  });
}
