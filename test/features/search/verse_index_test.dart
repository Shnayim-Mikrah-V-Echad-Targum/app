import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/core/text/hebrew_text.dart';
import 'package:shnayim_mikra/data/models/verse_ref.dart';
import 'package:shnayim_mikra/data/parsha_repository.dart';
import 'package:shnayim_mikra/data/text_repository.dart';
import 'package:shnayim_mikra/features/search/verse_index.dart';

/// The text of each of [snippet]'s matches.
List<String> matched(Snippet snippet) => [for (final m in snippet.matches) snippet.text.substring(m.start, m.end)];

void main() {
  group('SearchText.fold', () {
    test('drops the marks consonantsOnly drops, and folds final letters', () {
      const genesis11 = 'בְּרֵאשִׁ֖ית בָּרָ֣א אֱלֹהִ֑ים אֵ֥ת הַשָּׁמַ֖יִם וְאֵ֥ת הָאָֽרֶץ׃';
      expect(SearchText.fold(genesis11), 'בראשית ברא אלהימ את השמימ ואת הארצ');
      expect(
        SearchText.fold(genesis11),
        HebrewText.foldFinals(HebrewText.consonantsOnly(genesis11)).replaceAll('׃', '').trim(),
      );
    });

    test('turns the maqaf, paseq and sof pasuq into word spaces', () {
      expect(SearchText.fold('עַל־פְּנֵ֣י תְה֑וֹם׃'), 'על פני תהומ');
      expect(SearchText.fold('אֱלֹהִ֤ים ׀ לָאוֹר֙'), 'אלהימ לאור');
      expect(SearchText.fold('לֹ֥א תִּרְצָ֖ח׃ לֹ֣א תִּנְאָ֑ף׃'), 'לא תרצח לא תנאפ');
    });

    test('lowers English, leaves out apostrophes and parts words at punctuation', () {
      expect(SearchText.fold('And Jacob went out from Beer-sheba, and went toward Haran.'),
          'and jacob went out from beer sheba and went toward haran');
      expect(SearchText.fold('Jacob’s ladder'), 'jacobs ladder');
      expect(SearchText.fold('  “Let there be light”  '), 'let there be light');
    });

    test('folds what is typed the way it folds the text', () {
      expect(SearchText.fold('וַיֵּצֵא  יַעֲקֹב'), SearchText.fold('ויצא יעקב'));
      expect(SearchText.fold('חרנ'), SearchText.fold('חָרָן'));
      expect(SearchText.fold('כ״ח'), 'כח');
      expect(SearchText.fold('ÉDEN'), 'éden');
    });

    test('maps each folded character back to its source', () {
      const text = 'וַיֵּצֵ֥א יַעֲקֹ֖ב';
      final (:folded, :sources) = SearchText.foldWithSources(text);
      expect(folded, 'ויצא יעקב');
      expect(sources, hasLength(folded.length));
      for (final (i, source) in sources.indexed) {
        if (folded[i] != ' ') expect(text[source], folded[i]);
      }
    });
  });

  group('Snippet', () {
    test('marks every match, with the marks on its last letter', () {
      final s = Snippet.find('וַיֵּצֵא יַעֲקֹב מִבְּאֵר שָׁבַע וַיֵּלֶךְ חָרָנָה׃', SearchText.fold('ויצא יעקב'), wordStart: false);
      expect(matched(s), ['וַיֵּצֵא יַעֲקֹב']);
      expect(s.clippedStart, isFalse);
      expect(s.clippedEnd, isFalse);
    });

    test('finds Hebrew inside a word, but English only at the start of one', () {
      expect(matched(Snippet.find('וַיֹּאמֶר אַבְרָם', 'אמר', wordStart: false)), ['אמֶר']);
      expect(matched(Snippet.find('בָּרָא אֱלֹהִים', 'אלה', wordStart: false)), ['אֱלֹהִ']);
      expect(Snippet.find('And Abram said', 'ram', wordStart: true).matches, isEmpty);
      expect(matched(Snippet.find('a ram caught in the thicket; the rams', 'ram', wordStart: true)), ['ram', 'ram']);
    });

    test('cuts a long verse to the words around the first match', () {
      final words = [for (var i = 1; i <= 40; i++) 'w$i'];
      final s = Snippet.find(words.join(' '), 'w20', wordStart: true, lead: 4, span: 10);
      expect(s.text, words.sublist(15, 25).join(' '));
      expect(matched(s), ['w20']);
      expect(s.clippedStart, isTrue);
      expect(s.clippedEnd, isTrue);

      // Near the end, the earlier words fill the room.
      final end = Snippet.find(words.join(' '), 'w39', wordStart: true, lead: 4, span: 10);
      expect(end.text, words.sublist(30).join(' '));
      expect(end.clippedEnd, isFalse);

      // With nothing to find, the start of the verse.
      final start = Snippet.find(words.join(' '), null, wordStart: true, span: 10);
      expect(start.text, words.sublist(0, 10).join(' '));
      expect(start.matches, isEmpty);
    });

    test('keeps a verse a little longer than the span whole, and the last word or two of a longer one', () {
      final words = [for (var i = 1; i <= 13; i++) 'w$i'];
      final whole = Snippet.find(words.join(' '), 'w12', wordStart: true, lead: 4, span: 10);
      expect(whole.text, words.join(' '));
      expect((whole.clippedStart, whole.clippedEnd), (false, false));

      final longer = [for (var i = 1; i <= 30; i++) 'w$i'];
      // Seven words left over at the end: cut.
      final cut = Snippet.find(longer.join(' '), 'w18', wordStart: true, lead: 4, span: 10);
      expect(cut.text, longer.sublist(13, 23).join(' '));
      // Starting one word in, the first word joins it.
      final start = Snippet.find(longer.join(' '), 'w6', wordStart: true, lead: 4, span: 10);
      expect(start.text, longer.sublist(0, 11).join(' '));
      expect(start.clippedStart, isFalse);
      // Ending one word short, the last word joins it.
      final end = Snippet.find(longer.join(' '), 'w24', wordStart: true, lead: 4, span: 10);
      expect(end.text, longer.sublist(19).join(' '));
      expect(end.clippedEnd, isFalse);
    });
  });

  group('VerseIndex', () {
    TestWidgetsFlutterBinding.ensureInitialized();
    late VerseIndex index;
    late ParshaRepository repo;
    final shares = <double>[];

    setUpAll(() async {
      repo = await ParshaRepository.load();
      index = await VerseIndex.build(TextRepository(), onProgress: shares.add);
    });

    test('holds every verse of the Torah and reports its progress', () {
      expect(index.length, 5846);
      expect(shares, hasLength(15));
      expect(shares, orderedEquals([...shares]..sort()));
      expect(shares.last, 1.0);
    });

    test('בראשית finds Genesis 1:1 first', () {
      final results = index.search('בראשית');
      expect(results.hits.first.book, 'Genesis');
      expect(results.hits.first.ref, const VerseRef(1, 1));
      expect(results.hits.first.snippets.first.layer, TextLayer.mikra);
      // The large bet is part of the word, which keeps its vowels.
      final word = matched(results.hits.first.snippets.first.snippet).single;
      expect(HebrewText.consonantsOnly(word), 'בראשית');
      expect(word, isNot('בראשית'));
    });

    test('ויצא יעקב finds Genesis 28:10 well within a second', () {
      final watch = Stopwatch()..start();
      final results = index.search('ויצא יעקב');
      watch.stop();
      expect(watch.elapsedMilliseconds, lessThan(1000));
      final hit = results.hits.singleWhere((h) => h.book == 'Genesis' && h.ref == const VerseRef(28, 10));
      final words = matched(hit.snippets.single.snippet).single;
      expect(HebrewText.consonantsOnly(words), 'ויצא יעקב');
      expect(hit.snippets.single.snippet.text, startsWith(words));
    });

    test('the vowels of a result follow the reader, and its cantillation never shows', () {
      final pointed = index.search('ויצא יעקב').hits.first.snippets.first.snippet.text;
      final plain = index.search('ויצא יעקב', nikud: false).hits.first.snippets.first.snippet.text;
      expect(pointed, HebrewText.stripTeamim(pointed));
      expect(pointed, isNot(plain));
      expect(plain, HebrewText.consonantsOnly(pointed));
    });

    test('reads past the extraordinary points and the inverted nun', () {
      // Dots over every letter of וישקהו, as the scroll writes it.
      final kiss = index.search('וישקהו').hits.single;
      expect((kiss.book, kiss.ref), ('Genesis', const VerseRef(33, 4)));
      expect(HebrewText.consonantsOnly(matched(kiss.snippets.single.snippet).single), 'וישקהו');
      // Numbers 10:35 opens with an inverted nun.
      final ark = index.search('ויהי בנסע הארן').hits.single;
      expect((ark.book, ark.ref), ('Numbers', const VerseRef(10, 35)));
    });

    test('finds the Targum, under its verse', () {
      final hit = index.search('בקדמין').hits.first;
      expect((hit.book, hit.ref), ('Genesis', const VerseRef(1, 1)));
      expect([for (final s in hit.snippets) (s.layer, s.matched)], [(TextLayer.mikra, false), (TextLayer.onkelos, true)]);
    });

    test('finds the translation, by whole words from their start', () {
      final results = index.search('Jacob went out');
      final hit = results.hits.singleWhere((h) => h.ref == const VerseRef(28, 10));
      expect(hit.snippets.single.layer, TextLayer.english);
      expect(matched(hit.snippets.single.snippet), ['Jacob went out']);
      // "ram" is never the end of Abram.
      for (final h in index.search('ram').hits) {
        expect(h.snippets.single.snippet.text.toLowerCase(), matches(RegExp(r'\bram')));
      }
    });

    test('lists at most 200 verses but counts them all', () {
      final results = index.search('יהוה');
      expect(results.hits, hasLength(kSearchLimit));
      expect(results.total, greaterThan(1500));
      expect(results.truncated, isTrue);
    });

    test('a single letter is too short to search for', () {
      expect(index.search('א').total, 0);
      expect(index.search(' ').total, 0);
      expect(index.search('אב').total, greaterThan(0));
    });

    test('groups results by parsha, in order', () {
      final groups = groupByParsha(index.search('יעקב').hits, repo.all);
      expect(groups.first.parsha.key, 'Toldot');
      expect([for (final g in groups) g.parsha.id.number], orderedEquals([for (final g in groups) g.parsha.id.number]..sort()));
      for (final g in groups) {
        for (final hit in g.hits) {
          expect(g.parsha.range.contains(hit.ref), isTrue, reason: '${hit.book} ${hit.ref}');
        }
      }
    });
  });
}
