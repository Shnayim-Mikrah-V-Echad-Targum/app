import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:share_plus_platform_interface/share_plus_platform_interface.dart';
import 'package:shnayim_mikrah/app/providers.dart';
import 'package:shnayim_mikrah/app/router.dart';
import 'package:shnayim_mikrah/core/text/hebrew_text.dart';
import 'package:shnayim_mikrah/data/models/scripture.dart';
import 'package:shnayim_mikrah/data/models/verse_ref.dart';
import 'package:shnayim_mikrah/data/text_repository.dart';
import 'package:shnayim_mikrah/features/community/data/demo_forum_repository.dart';
import 'package:shnayim_mikrah/features/community/data/forum_repository.dart';
import 'package:shnayim_mikrah/features/community/data/models.dart';
import 'package:shnayim_mikrah/features/community/ui/account_screen.dart';
import 'package:shnayim_mikrah/features/community/ui/community_ui.dart';
import 'package:shnayim_mikrah/features/community/ui/compose_screen.dart';
import 'package:shnayim_mikrah/features/community/ui/thread_screen.dart';
import 'package:shnayim_mikrah/features/reader/haftarah_screen.dart';
import 'package:shnayim_mikrah/features/reader/reader_screen.dart';
import 'package:shnayim_mikrah/features/reader/scripture_text.dart';
import 'package:shnayim_mikrah/features/reader/verse_actions_sheet.dart';
import 'package:shnayim_mikrah/features/settings/app_settings.dart';
import 'package:shnayim_mikrah/features/settings/widgets/settings_widgets.dart';
import 'package:shnayim_mikrah/ui/widgets/common.dart';
import 'package:shnayim_mikrah/ui/widgets/sefer_choice_chip.dart';

import '../../helpers.dart';

/// The share sheet, which keeps what it was asked to share, or fails as a
/// platform with none would. As a browser without one ([webWithout]), it
/// opens an email in its place where it is let ([ShareParams.mailToFallbackEnabled]),
/// and says only that the result is unavailable, as share_plus does.
class _ShareSheet extends SharePlatform {
  final shared = <ShareParams>[];
  final emailed = <ShareParams>[];
  bool fails = false;
  bool webWithout = false;

  @override
  Future<ShareResult> share(ShareParams params) async {
    if (fails) throw UnimplementedError('no share sheet');
    if (webWithout) {
      if (!params.mailToFallbackEnabled) throw Exception('Navigator.canShare() is unavailable');
      emailed.add(params);
      return ShareResult.unavailable;
    }
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
  // Genesis 3:22 as the data writes it: the Divine Name, and Elohim; and the
  // verse with the Name written ה׳ in its place, and Elohim אלקים.
  late String name;
  late String elohim;
  late String hebrew3_22;
  setUpAll(() async {
    final repo = TextRepository();
    mikra = await repo.book(TextLayer.mikra, 'Genesis');
    onkelos = await repo.book(TextLayer.onkelos, 'Genesis');
    english = await repo.book(TextLayer.english, 'Genesis');
    samuel20_18 = (await repo.hebrewVerse(const BookVerse('I Samuel', VerseRef(20, 18))))!;
    final raw = mikra.verse(genesis3_22.ref).readText;
    name = raw.split(' ').singleWhere((w) => HebrewText.consonantsOnly(w) == 'יהוה');
    elohim = raw.split(' ').singleWhere((w) => HebrewText.consonantsOnly(w) == 'אלהים');
    hebrew3_22 = raw.replaceFirst(name, 'ה׳').replaceFirst(elohim, elohim.replaceFirst('ה', 'ק'));
  });

  group('the text that leaves the app', () {
    test('is the verse as shown, with the Divine Names written ה׳ and אלקים', () {
      final text = verseText(mikra.verse(genesis3_22.ref), const AppSettings());
      expect(text, hebrew3_22);
      expect(text, contains(' ׀ ה׳ אֱלֹקִ֗ים '), reason: 'every vowel and cantillation mark kept');
      expect(HebrewText.consonantsOnly(text), startsWith('ויאמר ה׳ אלקים הן האדם'));
      expect(HebrewText.consonantsOnly(text), isNot(contains('יהוה')));
      expect(HebrewText.consonantsOnly(text), isNot(contains('אלהים')));
      // Nothing the screen adds to keep words together travels with it.
      expect(text, isNot(contains('\u2060')));
      expect(text, isNot(contains('\u00a0')));
    });

    test('is shown in the sheet with no line broken after a maqaf, or begun with a paseq', () {
      expect(keepLinesSound('פֶּן־יִשְׁלַח'), 'פֶּן־\u2060יִשְׁלַח');
      expect(keepLinesSound('וְעַתָּה ׀ פֶּן'), 'וְעַתָּה\u00a0׀ פֶּן');
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
      // The Targum's Hebrew Elohim as the Torah's.
      expect(lines[1], verseText(onkelos.verse(r), const AppSettings(), targum: true));
      expect(lines[1], startsWith('וַאֲמַר יְיָ אֱלֹקִים '));
      expect(lines[2], startsWith('And the LORD God said'));
      expect(lines[3], '— Genesis 3:22');
      expect(
        verseCopy(ChosenVerse(at: genesis3_22, hebrew: mikra.verse(r)), const AppSettings(), reference: 'בראשית ג, כב'),
        '${lines[0]}\n— בראשית ג, כב',
      );
    });

    // Onkelos's Aramaic forms of Elohim are the rabbinic advisor's to decide
    // (docs/DESIGN.md §11): every one stays as written, even where its
    // letters are a Hebrew form's, as "my God" in Exodus 15:2 (אלהי); only
    // Elohim as Hebrew spells it is written אלקים, as in the Torah.
    test('copied with the Targum, writes its Aramaic forms of Elohim as they are', () async {
      final repo = TextRepository();
      final exodus = await repo.book(TextLayer.mikra, 'Exodus');
      final exodusTargum = await repo.book(TextLayer.onkelos, 'Exodus');
      final deuteronomy = await repo.book(TextLayer.mikra, 'Deuteronomy');
      final deuteronomyTargum = await repo.book(TextLayer.onkelos, 'Deuteronomy');
      List<String> copied(BookText torah, BookText targum, VerseRef r) => [
            for (final line in verseCopy(
              ChosenVerse(at: BookVerse('', r), hebrew: torah.verse(r), targum: targum.verse(r)),
              const AppSettings(),
              reference: '',
            ).split('\n'))
              HebrewText.consonantsOnly(line),
          ];

      // "This is my God… the God of my father": the Torah's אלהי is the Name;
      // the Targum's אלהי ("my God") and אלהא stay.
      final song = copied(exodus, exodusTargum, const VerseRef(15, 2));
      expect(song[0], contains('אלקי אבי'));
      expect(song[1], contains('דין אלהי '));
      expect(song[1], contains('אלהא דאבהתי'));
      expect(song[1], isNot(contains('אלק')));

      // "The LORD your God, He is God, the faithful God": the Targum keeps the
      // Hebrew אלהים there, between its own אלהך and אלהא.
      final faithful = copied(deuteronomy, deuteronomyTargum, const VerseRef(7, 9));
      expect(faithful[0], contains('ה׳ אלקיך הוא האלקים'));
      expect(faithful[1], contains('יי אלהך הוא אלקים אלהא מהימנא'));
    });

    test('quoted in a question, runs from the left where the question does', () {
      final hebrew = verseText(mikra.verse(genesis3_22.ref), const AppSettings());
      expect(withVerseQuote(hebrew, 'Why?', leftToRight: true), '\u200E> $hebrew\n\nWhy?');
      expect(withVerseQuote(hebrew, 'למה?', leftToRight: false), '> $hebrew\n\nלמה?');
    });

    test('quoted in a question, is found there however the Names were written', () {
      final verse = mikra.verse(genesis3_22.ref);
      const s = AppSettings();
      const off = AppSettings(copyDivineNameAsHashem: false);
      String quote(Verse verse, AppSettings s, {String question = '', bool leftToRight = true}) =>
          withVerseQuote(verseText(verse, s), question, leftToRight: leftToRight);
      expect(quotesVerse(quote(verse, s, question: 'Why "like one of us"?'), verse, s), isTrue);
      expect(quotesVerse(quote(verse, s, question: 'למה "כאחד ממנו"?', leftToRight: false), verse, s), isTrue);
      // Begun while the reader had the Names written out, and asked again
      // since they chose otherwise, or the other way round.
      expect(quotesVerse('> ${verse.readText}\n\nWhy?', verse, s), isTrue);
      expect(quotesVerse(quote(verse, s), verse, off), isTrue);
      // Kept from before Elohim was written אלקים.
      expect(quotesVerse('> ${verse.readText.replaceFirst(name, 'ה׳')}\n\nWhy?', verse, s), isTrue);
      // Another verse's question, or none.
      expect(quotesVerse(quote(mikra.verse(const VerseRef(3, 23)), s), verse, s), isFalse);
      expect(quotesVerse('Why does Onkelos keep some names?', verse, s), isFalse);
      expect(quotesVerse('', verse, s), isFalse);
    });

    test('asks in Questions & answers, naming the verse as a link does', () {
      final uri = Uri.parse(askAboutVersePath(genesis3_22));
      expect(uri.path, '/community/new');
      expect(uri.queryParameters, {'forum': 'questions', 'verse': 'Genesis 3:22'});
      expect(BookVerse.tryParse(uri.queryParameters['verse']), genesis3_22);
      // Over the tabs, where Questions & answers is the page's own forum.
      final over = Uri.parse(askAboutVersePath(genesis3_22, overTabs: true));
      expect(over.path, '/ask');
      expect(over.queryParameters, {'verse': 'Genesis 3:22'});
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
        ..emailed.clear()
        ..fails = false
        ..webWithout = false;
    });

    Future<ProviderContainer> open(
      WidgetTester tester,
      String route, {
      AppSettings settings = const AppSettings(onboardingComplete: true),
      Map<String, Object> stored = const {},
      ForumRepository? forums,
    }) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
      final c = await pumpApp(tester, settings: settings, now: friday, stored: stored, forums: forums);
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

    /// Waits for [done], which waits on real I/O (a verse's text, which a
    /// new discussion looks up), or for long enough to be sure it won't come.
    Future<void> until(WidgetTester tester, bool Function() done) async {
      for (var i = 0; i < 20 && !done(); i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
      }
      await tester.pumpAndSettle();
    }

    TextEditingController field(WidgetTester tester, int i) =>
        tester.widgetList<TextField>(find.byType(TextField)).elementAt(i).controller!;

    /// The verse a new discussion quotes above its message, as quoted; null
    /// for none.
    String? quoted(WidgetTester tester) {
      final quote = find.descendant(of: find.byType(ComposeScreen), matching: find.byType(VerseQuote));
      return quote.evaluate().isEmpty ? null : tester.widget<VerseQuote>(quote).hebrew;
    }

    /// Waits for a new discussion to quote its verse, or for long enough to
    /// be sure it won't.
    Future<void> untilQuoted(WidgetTester tester) => until(tester, () => quoted(tester) != null);

    /// Waits for the page to say that a draft was kept.
    Future<void> untilKept(WidgetTester tester) => until(tester, () => find.byType(NoticeBanner).evaluate().isNotEmpty);

    String location(ProviderContainer c) => c.read(routerProvider).state.uri.toString();

    /// The verse [r] of Genesis in the reader, not its Targum.
    Finder verseOf(VerseRef r) =>
        find.byWidgetPredicate((w) => w is ScriptureVerse && w.verse.ref == r && !w.secondary).first;

    /// Brings [verse] well into view, clear of the ribbon over the text.
    Future<void> reveal(WidgetTester tester, Finder verse) async {
      await Scrollable.ensureVisible(tester.element(verse), alignment: 0.3);
      await tester.pumpAndSettle();
    }

    /// Opens the options of [verse] with a long press, and asks about it.
    Future<void> ask(WidgetTester tester, Finder verse) async {
      await reveal(tester, verse);
      await tester.longPress(verse);
      await tester.pumpAndSettle();
      await tester.tap(inSheet(find.text('Ask about this verse')));
      await untilQuoted(tester);
    }

    testWidgets('a long press on Genesis 3:22 copies the pointed verse with ה׳ and its reference', (tester) async {
      await open(tester, '/read/5787:1/3');
      await tester.longPress(find.byType(ScriptureVerse).first);
      await tester.pumpAndSettle();
      expect(inSheet(find.text('Genesis 3:22')), findsOneWidget);
      // The verse over the options keeps פֶּן־יִשְׁלַח on one line, as the
      // reader does; what is copied has none of that.
      expect(inSheet(find.text(keepLinesSound(hebrew3_22))), findsOneWidget);

      await tester.tap(inSheet(find.text('Copy')));
      await tester.pumpAndSettle();
      expect(find.byType(BottomSheet), findsNothing);
      expect(find.text('Verse copied'), findsOneWidget);
      final lines = copied!.split('\n');
      expect(lines.first, hebrew3_22);
      // Onkelos too writes אֱלֹהִים here, after the Name as he writes it.
      final targum = onkelos.verse(genesis3_22.ref).readText;
      expect(targum, contains('יְיָ אֱלֹהִים'));
      expect(lines[1], targum.replaceFirst('יְיָ אֱלֹהִים', 'יְיָ אֱלֹקִים'), reason: 'the Targum, which the reader reads');
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
      expect(inSheet(find.text('בראשית ג,\u00A0כב')), findsOneWidget);
      await tester.tap(inSheet(find.text('העתקה')));
      await tester.pumpAndSettle();
      expect(copied!.split('\n').last, '— בראשית ג,\u00A0כב');
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
      expect(copied, contains(elohim));
      expect(copied, isNot(contains('ה׳')));
      expect(copied, isNot(contains('אֱלֹקִ')));
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
      expect(find.text('Verse options: bookmark, note, copy, share or ask'), findsOneWidget);
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
      expect(find.text('Sharing isn’t available here, so the verse was copied.'), findsOneWidget);
    });

    testWidgets('a browser without a share sheet copies the verse rather than open an email', (tester) async {
      sheet.webWithout = true;
      await open(tester, '/read/5787:1/3');
      await tester.longPress(find.byType(ScriptureVerse).first);
      await tester.pumpAndSettle();
      await tester.tap(inSheet(find.text('Share')));
      await tester.pumpAndSettle();
      expect(sheet.emailed, isEmpty);
      expect(copied, endsWith('— Genesis 3:22'));
      expect(find.text('Sharing isn’t available here, so the verse was copied.'), findsOneWidget);
      expect(find.byType(BottomSheet), findsNothing);
    });

    testWidgets('asking about the verse begins a question on it over the reader, which closing it goes back to',
        (tester) async {
      final c = await open(tester, '/read/5787:1/3?mode=full');
      await ask(tester, verseOf(genesis3_22.ref));
      expect(tester.takeException(), isNull);
      expect(find.byType(ReaderScreen), findsNothing, reason: 'beneath the question');
      expect(find.byType(ComposeScreen), findsOneWidget);
      expect(find.byType(NavigationBar), findsNothing, reason: 'over the tabs, as the reader is');
      expect(Uri.parse(location(c)).path, '/ask');
      expect(Uri.parse(location(c)).queryParameters['verse'], 'Genesis 3:22');
      final chosen = tester.widgetList<SeferChoiceChip>(find.byType(SeferChoiceChip)).where((chip) => chip.selected);
      expect(find.descendant(of: find.byWidget(chosen.single), matching: find.text('Questions & answers')), findsOneWidget);

      expect(field(tester, 0).text, 'Question on Genesis 3:22');
      // The verse above the message, which is left for the question.
      expect(quoted(tester), hebrew3_22);
      expect(field(tester, 1).text, isEmpty);
      await tester.pump(const Duration(seconds: 1));
      expect(c.read(sharedPreferencesProvider).getString('draft.newThread'), isNull, reason: 'nothing of the member\'s yet');

      // Closed, the reader is as it was: in the full text, at the verse.
      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();
      expect(find.byType(ComposeScreen), findsNothing);
      expect(find.byType(ReaderScreen), findsOneWidget);
      expect(location(c), '/read/5787:1/3?mode=full');
      expect(verseOf(genesis3_22.ref).hitTestable(), findsOneWidget);
      expect(find.text('Mark this aliyah as read').hitTestable(), findsNothing, reason: 'still at the top of the full text');
    });

    testWidgets('a question left untouched is no draft: the next verse asked about begins its own', (tester) async {
      final c = await open(tester, '/read/5787:1/3?mode=full');
      await ask(tester, verseOf(genesis3_22.ref));
      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();

      await ask(tester, verseOf(const VerseRef(3, 23)));
      expect(find.byType(NoticeBanner), findsNothing);
      expect(field(tester, 0).text, 'Question on Genesis 3:23');
      expect(quoted(tester), verseText(mikra.verse(const VerseRef(3, 23)), const AppSettings()));
      expect(field(tester, 1).text, isEmpty);
      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();

      // Nor does it come back as a new discussion's draft.
      c.read(routerProvider).go('/community');
      await tester.pumpAndSettle();
      c.read(routerProvider).push('/community/new?forum=questions');
      await tester.pumpAndSettle();
      expect(field(tester, 0).text, isEmpty);
      expect(field(tester, 1).text, isEmpty);
      expect(quoted(tester), isNull);
    });

    testWidgets('a question written on is kept, and asked about again comes back as it was', (tester) async {
      final c = await open(tester, '/read/5787:1/3?mode=full');
      await ask(tester, verseOf(genesis3_22.ref));
      const question = 'Why "like one of us"?';
      await tester.enterText(find.byType(TextField).at(1), question);
      // Closed at once: what was just typed is kept all the same, with the
      // verse apart from it.
      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();
      final draft = jsonDecode(c.read(sharedPreferencesProvider).getString('draft.newThread')!) as Map<String, dynamic>;
      expect(draft, {'title': 'Question on Genesis 3:22', 'quote': hebrew3_22, 'body': question});

      await ask(tester, verseOf(genesis3_22.ref));
      expect(find.byType(NoticeBanner), findsNothing, reason: 'the draft is a question on this verse');
      expect(field(tester, 0).text, 'Question on Genesis 3:22');
      expect(quoted(tester), hebrew3_22);
      expect(field(tester, 1).text, question);
      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();

      // Another verse's question waits on it.
      await ask(tester, verseOf(const VerseRef(3, 23)));
      expect(
        find.text('Your unsent draft is kept. Discard it to ask about Genesis 3:23 instead.'),
        findsOneWidget,
      );
      expect(field(tester, 1).text, question);
    });

    testWidgets('what is typed just before the page closes is kept', (tester) async {
      final c = await open(tester, '/community/new', settings: const AppSettings(onboardingComplete: true, reduceMotion: true));
      await tester.enterText(find.byType(TextField).at(0), 'On the names of places');
      await tester.tap(find.byType(CloseButton));
      await tester.pump();
      await tester.pump();
      expect(find.byType(ComposeScreen), findsNothing);
      expect(c.read(sharedPreferencesProvider).getString('draft.newThread'), contains('On the names of places'));
    });

    testWidgets('the page shown already follows a link to another verse', (tester) async {
      final c = await open(tester, '/community/new?forum=questions&verse=Genesis%203:22');
      await untilQuoted(tester);
      expect(field(tester, 0).text, 'Question on Genesis 3:22');

      // The same page, as a link to it from over the tabs opens it.
      c.read(routerProvider).go('/community/new?forum=questions&verse=Genesis%203:23');
      await until(tester, () => field(tester, 0).text.endsWith('3:23'));
      expect(find.byType(NoticeBanner), findsNothing);
      expect(field(tester, 0).text, 'Question on Genesis 3:23');
      expect(quoted(tester), verseText(mikra.verse(const VerseRef(3, 23)), const AppSettings()));
      expect(field(tester, 1).text, isEmpty);

      // With something of the member's in it, it says the draft was kept.
      await tester.enterText(find.byType(TextField).at(1), 'My own words');
      c.read(routerProvider).go('/community/new?forum=questions&verse=Genesis%203:24');
      await untilKept(tester);
      expect(
        find.text('Your unsent draft is kept. Discard it to ask about Genesis 3:24 instead.'),
        findsOneWidget,
      );
      expect(field(tester, 1).text, 'My own words');

      // A link with no verse leaves the draft, with nothing to say of it.
      c.read(routerProvider).go('/community/new?forum=questions');
      await tester.pumpAndSettle();
      expect(find.byType(NoticeBanner), findsNothing);
      expect(field(tester, 1).text, 'My own words');
    });

    testWidgets('posted over the reader, the question goes back to the verse, whose message leads to it',
        (tester) async {
      final forums = DemoForumRepository();
      await forums.verifyCode('reader@example.org', '123456');
      await forums.updateDisplayName('Reader');
      await forums.acceptGuidelines();
      final c = await open(tester, '/read/5787:1/3?mode=full', forums: forums);
      await ask(tester, verseOf(genesis3_22.ref));
      await tester.enterText(find.byType(TextField).at(1), 'Why "like one of us"?');
      await tester.tap(find.descendant(of: find.byType(AppBar), matching: find.widgetWithText(FilledButton, 'Post')));
      await tester.pumpAndSettle();
      expect(find.byType(ComposeScreen), findsNothing);
      expect(find.byType(ReaderScreen), findsOneWidget);
      expect(location(c), '/read/5787:1/3?mode=full');
      expect(find.text('Posted.'), findsOneWidget);
      expect(c.read(sharedPreferencesProvider).getString('draft.newThread'), isNull);

      await tester.tap(find.text('View'));
      await tester.pumpAndSettle();
      expect(find.byType(ThreadScreen), findsOneWidget);
      expect(location(c), startsWith('/community/thread/'));
      expect(find.text('Question on Genesis 3:22'), findsOneWidget);
      // Posted as questions on a verse always were: the verse quoted first,
      // after a left-to-right mark for a question in English.
      final posts = await forums.posts(Uri.parse(location(c)).pathSegments.last);
      expect(posts.single.body, '\u200E> $hebrew3_22\n\nWhy "like one of us"?');
      // And shown as a quotation, over the question.
      expect(tester.widget<VerseQuote>(find.byType(VerseQuote)).hebrew, hebrew3_22);
      expect(find.text('Why "like one of us"?'), findsOneWidget);
    });

    testWidgets('signing in to post over the reader opens the account over the tabs too', (tester) async {
      final c = await open(tester, '/read/5787:1/3?mode=full');
      await ask(tester, verseOf(genesis3_22.ref));
      await tester.enterText(find.byType(TextField).at(1), 'Why "like one of us"?');
      await tester.tap(find.descendant(of: find.byType(AppBar), matching: find.widgetWithText(FilledButton, 'Post')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(AccountScreen), findsOneWidget);
      expect(location(c), '/account?then=back');
      expect(find.byType(NavigationBar), findsNothing);

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(ComposeScreen), findsOneWidget);
      expect(field(tester, 0).text, 'Question on Genesis 3:22');
      expect(quoted(tester), hebrew3_22);
      expect(field(tester, 1).text, 'Why "like one of us"?');
    });

    testWidgets('from the haftarah within a tab, the question opens within that tab, and back returns to it',
        (tester) async {
      final c = await open(tester, '/today/haftarah/5787:1');
      expect(OwnContextMenu.browserMenuAway, isTrue);
      await ask(tester, find.byType(ScriptureVerse).first);
      expect(find.byType(ComposeScreen), findsOneWidget);
      expect(Uri.parse(location(c)).path, '/community/new');
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0,
        reason: 'within Today, as a page opened from a tab\'s page is',
      );
      expect(field(tester, 0).text, 'Question on I Samuel 20:18');
      // The haftarah is kept beneath it, out of sight: the question's fields
      // have the browser's menu again.
      expect(OwnContextMenu.browserMenuAway, isFalse);

      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();
      expect(find.byType(HaftarahScreen), findsOneWidget);
      expect(location(c), '/today/haftarah/5787:1');
      expect(OwnContextMenu.browserMenuAway, isTrue);
    });

    testWidgets('the browser\'s menu stays away while the reader is shown, sheets and all, and only then',
        (tester) async {
      final c = await open(tester, '/read/5787:1/3?mode=full');
      expect(OwnContextMenu.browserMenuAway, isTrue);
      await tester.longPress(verseOf(genesis3_22.ref));
      await tester.pumpAndSettle();
      expect(OwnContextMenu.browserMenuAway, isTrue, reason: 'the verse\'s options are the reader\'s own');
      await tester.tap(inSheet(find.text('Ask about this verse')));
      await untilQuoted(tester);
      expect(OwnContextMenu.browserMenuAway, isFalse, reason: 'the question\'s fields have the browser\'s menu');
      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();
      expect(OwnContextMenu.browserMenuAway, isTrue);
      c.read(routerProvider).go('/today');
      await tester.pumpAndSettle();
      expect(OwnContextMenu.browserMenuAway, isFalse);
    });

    testWidgets('in full-text focus mode, Shift+F10 opens the focused verse\'s options, wherever it is',
        (tester) async {
      await open(tester, '/read/5787:1/3?mode=full', settings: const AppSettings(onboardingComplete: true, focusMode: true));
      VerseGroup group(VerseRef r) => tester.widget<VerseGroup>(find.byWidgetPredicate((w) => w is VerseGroup && w.verse == r));
      // Tap 3:23 into focus, then scroll it out of view.
      await reveal(tester, verseOf(const VerseRef(3, 23)));
      await tester.tap(verseOf(const VerseRef(3, 23)));
      await tester.pump();
      expect(group(const VerseRef(3, 23)).highlighted, isTrue);
      final text = find.descendant(
        of: find.byType(ReaderScreen),
        matching: find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down),
      );
      await tester.drag(text, const Offset(0, -1500));
      await tester.pumpAndSettle();
      expect(verseOf(const VerseRef(3, 23)).hitTestable(), findsNothing);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
      await tester.sendKeyEvent(LogicalKeyboardKey.f10);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
      await tester.pumpAndSettle();
      expect(inSheet(find.text('Genesis 3:23')), findsOneWidget);
    });

    testWidgets('a draft not yet sent is kept, and discarding it begins the question', (tester) async {
      final draft = jsonEncode({'title': 'On the names of places', 'body': 'Why does Onkelos keep some names'});
      await open(tester, '/community/new?forum=questions&verse=Genesis%203:22', stored: {'draft.newThread': draft});
      await untilKept(tester);
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
      expect(quoted(tester), hebrew3_22);
      expect(field(1).text, isEmpty);
      final message = find.descendant(of: find.byType(TextField).at(1), matching: find.byType(EditableText));
      expect(tester.widget<EditableText>(message).focusNode.hasFocus, isTrue, reason: 'where the question goes');

      // Once begun, discarding the question clears it, as any draft.
      await tester.tap(find.text('Discard draft'));
      await tester.pumpAndSettle();
      expect(field(0).text, isEmpty);
      expect(field(1).text, isEmpty);
      expect(quoted(tester), isNull);
    });

    testWidgets('closed with its verse taken out and nothing written, keeps no draft, and asked again begins anew',
        (tester) async {
      final c = await open(tester, '/read/5787:1/3?mode=full');
      await ask(tester, verseOf(genesis3_22.ref));
      await tester.tap(find.byTooltip('Remove the verse'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();
      expect(c.read(sharedPreferencesProvider).getString('draft.newThread'), isNull);

      await ask(tester, verseOf(genesis3_22.ref));
      expect(find.byType(NoticeBanner), findsNothing, reason: 'no draft in its way');
      expect(quoted(tester), hebrew3_22);
    });

    testWidgets("a draft whose message begins with the member's own quote keeps it in the message", (tester) async {
      const message = '> אני חושב שהמפרש צודק\n\nמסכים';
      final draft = jsonEncode({'title': 'On Rashi', 'quote': null, 'body': message});
      await open(tester, '/community/new?forum=questions', stored: {'draft.newThread': draft});
      await untilKept(tester);
      expect(quoted(tester), isNull);
      expect(field(tester, 1).text, message);
    });

    testWidgets('a draft quoting the verse with Elohim written out, as questions once did, is its question already',
        (tester) async {
      final verse = mikra.verse(genesis3_22.ref).readText.replaceFirst(name, 'ה׳');
      final body = '\u200E> $verse\n\nWhy "like one of us"?';
      final draft = jsonEncode({'title': 'Question on Genesis 3:22', 'body': body});
      final c = await open(tester, '/community/new?forum=questions&verse=Genesis%203:22', stored: {'draft.newThread': draft});
      await untilKept(tester);
      expect(find.byType(NoticeBanner), findsNothing, reason: 'the draft is a question on this verse');
      // The verse quoted as the draft kept it, apart from the question.
      expect(quoted(tester), verse);
      expect(field(tester, 1).text, 'Why "like one of us"?');

      // Another verse's question waits on it.
      c.read(routerProvider).go('/community/new?forum=questions&verse=Genesis%203:23');
      await untilKept(tester);
      expect(find.text('Your unsent draft is kept. Discard it to ask about Genesis 3:23 instead.'), findsOneWidget);
      expect(quoted(tester), verse);
      expect(field(tester, 1).text, 'Why "like one of us"?');
    });

    testWidgets('in the Hebrew UI, the question is in Hebrew and runs from the right', (tester) async {
      await open(
        tester,
        '/community/new?forum=questions&verse=Genesis%203:22',
        settings: const AppSettings(onboardingComplete: true, language: AppLanguage.hebrew),
      );
      await untilQuoted(tester);
      final fields = tester.widgetList<TextField>(find.byType(TextField)).toList();
      expect(fields[0].controller!.text, 'שאלה על בראשית ג,\u00A0כב');
      expect(quoted(tester), hebrew3_22);
      expect(fields[1].controller!.text, isEmpty);
    });

    /// A member with a name, who has accepted the guidelines: Post sends at
    /// once.
    Future<DemoForumRepository> member() async {
      final forums = DemoForumRepository();
      await forums.verifyCode('reader@example.org', '123456');
      await forums.updateDisplayName('Reader');
      await forums.acceptGuidelines();
      return forums;
    }

    /// Posts the discussion on the page, and returns its first post's text.
    Future<String> post(WidgetTester tester, ProviderContainer c, DemoForumRepository forums) async {
      await tester.tap(find.byType(FilledButton).first);
      await tester.pumpAndSettle();
      expect(find.byType(ThreadScreen), findsOneWidget);
      final posts = await forums.posts(Uri.parse(location(c)).pathSegments.last);
      return posts.single.body;
    }

    testWidgets('the verse is taken out of the question by its button, and the message takes the focus', (tester) async {
      final forums = await member();
      final c = await open(tester, '/community/new?forum=questions&verse=Genesis%203:22', forums: forums);
      await untilQuoted(tester);
      final remove = find.byTooltip('Remove the verse');
      expect(remove, findsOneWidget);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      expect(quoted(tester), isNull);
      expect(remove, findsNothing);
      final message = find.descendant(of: find.byType(TextField).at(1), matching: find.byType(EditableText));
      expect(tester.widget<EditableText>(message).focusNode.hasFocus, isTrue, reason: 'the button that had it is gone');

      // Nothing of the member's yet: no draft, and the verse can be put
      // back from the status message.
      await tester.pump(const Duration(seconds: 1));
      expect(c.read(sharedPreferencesProvider).getString('draft.newThread'), isNull);
      expect(find.text('Verse removed'), findsOneWidget);
      await tester.tap(find.widgetWithText(SnackBarAction, 'Undo'));
      await tester.pumpAndSettle();
      expect(quoted(tester), hebrew3_22);
      await tester.tap(remove);
      await tester.pumpAndSettle();
      expect(quoted(tester), isNull);

      await tester.enterText(find.byType(TextField).at(1), 'Why "like one of us"?');
      // Something of the member's: kept as a draft with no verse.
      await tester.pump(const Duration(seconds: 1));
      final draft = jsonDecode(c.read(sharedPreferencesProvider).getString('draft.newThread')!) as Map<String, dynamic>;
      expect(draft, {'title': 'Question on Genesis 3:22', 'quote': null, 'body': 'Why "like one of us"?'});
      expect(await post(tester, c, forums), 'Why "like one of us"?', reason: 'quoting nothing');
      expect(find.byType(VerseQuote), findsNothing);
    });

    testWidgets('the verse is no question: posted with nothing else, the message says what it needs', (tester) async {
      final forums = await member();
      await open(tester, '/community/new?forum=questions&verse=Genesis%203:22', forums: forums);
      await untilQuoted(tester);
      await tester.tap(find.byType(FilledButton).first);
      await tester.pumpAndSettle();
      expect(find.byType(ComposeScreen), findsOneWidget, reason: 'nothing sent');
      expect(find.text('The message needs at least 2 characters.'), findsOneWidget);
      final message = find.descendant(of: find.byType(TextField).at(1), matching: find.byType(EditableText));
      expect(tester.widget<EditableText>(message).focusNode.hasFocus, isTrue);
    });

    testWidgets('a question runs from the side its own words begin, whatever the interface\'s language', (tester) async {
      const hebrewUi = AppSettings(onboardingComplete: true, language: AppLanguage.hebrew);
      for (final (settings, question, mark) in [
        (hebrewUi, 'למה "כאחד ממנו"?', ''),
        (hebrewUi, 'Why "like one of us"?', '\u200E'),
        (const AppSettings(onboardingComplete: true), 'למה "כאחד ממנו"?', ''),
      ]) {
        final forums = await member();
        final c = await open(tester, '/community/new?forum=questions&verse=Genesis%203:22', settings: settings, forums: forums);
        await untilQuoted(tester);
        await tester.enterText(find.byType(TextField).at(1), question);
        expect(await post(tester, c, forums), '$mark> $hebrew3_22\n\n$question');
      }
    });

    testWidgets('a verse that isn\'t there begins nothing, nor keeps a draft from it', (tester) async {
      for (final verse in ['Genesis%2099:1', 'Spam%201:1']) {
        await open(tester, '/community/new?forum=questions&verse=$verse');
        await untilQuoted(tester);
        expect(field(tester, 0).text, isEmpty, reason: '$verse: no such verse to name');
        expect(quoted(tester), isNull, reason: '$verse: nor to quote');
        expect(field(tester, 1).text, isEmpty);
      }
      final draft = jsonEncode({'title': 'On the names of places', 'body': 'Why does Onkelos keep some names'});
      await open(tester, '/community/new?forum=questions&verse=Genesis%2099:1', stored: {'draft.newThread': draft});
      await untilKept(tester);
      expect(find.byType(NoticeBanner), findsNothing);
      expect(field(tester, 0).text, 'On the names of places');
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
      expect(quoted(tester), samuel20_18.readText);
      expect(fields[1].controller!.text, isEmpty);
    });

    testWidgets('Display has the switch for the Divine Names, on by default', (tester) async {
      final c = await open(tester, '/settings/display');
      final row = find.widgetWithText(SwitchRow, 'Write Divine Names as ה׳ and אלקים');
      await tester.scrollUntilVisible(row, 200, scrollable: find.byType(Scrollable).first);
      await Scrollable.ensureVisible(tester.element(row), alignment: 0.5);
      await tester.pumpAndSettle();
      expect(find.text('In a verse copied, shared or quoted in a question'), findsOneWidget);
      final toggle = find.descendant(of: row, matching: find.byType(Switch));
      expect(tester.widget<Switch>(toggle).value, isTrue);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(c.read(settingsProvider).copyDivineNameAsHashem, isFalse);
    });
  });
}
