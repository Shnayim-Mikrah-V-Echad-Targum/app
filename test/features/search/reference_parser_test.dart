import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/core/text/hebrew_text.dart';
import 'package:shnayim_mikra/data/models/parsha.dart';
import 'package:shnayim_mikra/data/models/verse_ref.dart';
import 'package:shnayim_mikra/data/parsha_repository.dart';
import 'package:shnayim_mikra/features/search/reference_parser.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ParshaRepository repo;
  late ReferenceParser parser;
  setUpAll(() async {
    repo = await ParshaRepository.load();
    parser = ReferenceParser.of(repo);
  });

  TypedReference? parse(String s, {String? currentBook}) => parser.parse(s, currentBook: currentBook);
  VerseReference verse(String book, int chapter, int verse) => VerseReference(book, VerseRef(chapter, verse));

  group('books and verses', () {
    test('the examples', () {
      expect(parse('Gen 28:12'), verse('Genesis', 28, 12));
      expect(parse('בראשית כ״ח:י״ב'), verse('Genesis', 28, 12));
      expect(parse('Vayetzei 28 12'), verse('Genesis', 28, 12));
      expect(parse('3:22', currentBook: 'Exodus'), verse('Exodus', 3, 22));
      expect(parse('בראשית כח יב'), verse('Genesis', 28, 12));
    });

    test('books in English, in transliteration and in Hebrew', () {
      for (final name in ['Genesis', 'genesis', 'Gen', 'Gen.', 'Gn', 'Bereshit', 'Bereishit', 'Bereishis', 'Bereshis', 'בראשית']) {
        expect(parse('$name 1:1'), verse('Genesis', 1, 1), reason: name);
      }
      expect(parse('Exodus 20:2'), verse('Exodus', 20, 2));
      expect(parse('Ex 20:2'), verse('Exodus', 20, 2));
      expect(parse('Shemos 20:2'), verse('Exodus', 20, 2));
      expect(parse('שמות כ, ב'), verse('Exodus', 20, 2));
      expect(parse('Lev 19:18'), verse('Leviticus', 19, 18));
      expect(parse('ויקרא יט, יח'), verse('Leviticus', 19, 18));
      expect(parse('Num 6:24'), verse('Numbers', 6, 24));
      expect(parse('Bemidbar 6:24'), verse('Numbers', 6, 24));
      expect(parse('במדבר ו כד'), verse('Numbers', 6, 24));
      expect(parse('Deut 6:4'), verse('Deuteronomy', 6, 4));
      expect(parse('Dt 6:4'), verse('Deuteronomy', 6, 4));
      expect(parse('דברים ו, ד'), verse('Deuteronomy', 6, 4));
    });

    test('Hebrew abbreviations of the books', () {
      expect(parse('בר׳ כח, יב'), verse('Genesis', 28, 12));
      expect(parse("שמ' כ ב"), verse('Exodus', 20, 2));
      expect(parse('דב׳ ו, ד'), verse('Deuteronomy', 6, 4));
    });

    test('any separator: a colon, comma, full stop or space', () {
      for (final s in ['Gen 28:12', 'Gen 28,12', 'Gen 28.12', 'Gen 28 12', 'Gen. 28. 12', 'Gen 28, 12', 'Gen28:12', '  Gen  28 :  12  ']) {
        expect(parse(s), verse('Genesis', 28, 12), reason: s);
      }
    });

    test('Hebrew numerals with or without their marks, or digits', () {
      for (final s in ['בראשית כ״ח, י״ב', 'בראשית כח, יב', 'בראשית כ"ח י"ב', 'בראשית כח:יב', 'בראשית 28:12', 'בראשית כח 12']) {
        expect(parse(s), verse('Genesis', 28, 12), reason: s);
      }
      expect(parse('שמות ט״ו, ט״ז'), verse('Exodus', 15, 16));
      expect(parse('שמות טו טז'), verse('Exodus', 15, 16));
    });

    test('a book’s own way of saying it: chapter and verse spelled out', () {
      expect(parse('בראשית פרק כח פסוק יב'), verse('Genesis', 28, 12));
      expect(parse('ספר בראשית כח, יב'), verse('Genesis', 28, 12));
      expect(parse('Genesis chapter 28 verse 12'), verse('Genesis', 28, 12));
      expect(parse('the book of Genesis 28:12'), verse('Genesis', 28, 12));
    });

    test('a range opens at its first verse', () {
      expect(parse('Gen 28:12-15'), verse('Genesis', 28, 12));
      expect(parse('Gen 28:12–29:3'), verse('Genesis', 28, 12));
      expect(parse('בראשית ז, יז–ח, יד'), verse('Genesis', 7, 17));
      expect(parse('לך-לך יב, א-ה'), verse('Genesis', 12, 1));
    });

    test('reads every reference the app writes, in either language', () {
      for (final (b, book) in kTorahBooks.indexed) {
        final lengths = repo.chapterLengths(book);
        for (var c = 1; c <= lengths.length; c++) {
          for (var v = 1; v <= lengths[c - 1]; v++) {
            // As Names.reference writes them.
            final english = '$book $c:$v';
            final hebrew = '${kTorahBooksHe[b]} ${HebrewText.gematria(c, punctuate: false)}, '
                '${HebrewText.gematria(v, punctuate: false)}';
            expect(parse(english), verse(book, c, v), reason: english);
            expect(parse(hebrew), verse(book, c, v), reason: hebrew);
          }
        }
      }
    });
  });

  group('parshiyot', () {
    test('stand for their book, in either transliteration or in Hebrew', () {
      expect(parse('Vayeitzei 28:12'), verse('Genesis', 28, 12));
      expect(parse('ויצא כח, יב'), verse('Genesis', 28, 12));
      expect(parse('Lech Lecha 12:1'), verse('Genesis', 12, 1));
      expect(parse('Lech-Lecha 12:1'), verse('Genesis', 12, 1));
      expect(parse('לך לך יב א'), verse('Genesis', 12, 1));
      expect(parse('Ki Sisa 30:12'), verse('Exodus', 30, 12));
      expect(parse('Ki Tissa 30:12'), verse('Exodus', 30, 12));
      expect(parse('כי תשא ל, יב'), verse('Exodus', 30, 12));
      expect(parse("Re'eh 11:26"), verse('Deuteronomy', 11, 26));
      expect(parse('Reeh 11:26'), verse('Deuteronomy', 11, 26));
      expect(parse('נח ו ט'), verse('Genesis', 6, 9));
      expect(parse('צו ו א'), verse('Leviticus', 6, 1));
    });

    test('in the spellings people use', () {
      for (final (spelling, key) in [
        ('Chayei Sarah', 'Chayei Sara'),
        ('Chaye Sara', 'Chayei Sara'),
        ('Mikets', 'Miketz'),
        ('Vayakhel', 'Vayakhel'),
        ("Vayak'hel", 'Vayakhel'),
        ('Naso', 'Nasso'),
        ('Behaalotecha', "Beha'alotcha"),
        ('Shelach Lecha', "Sh'lach"),
        ('Acharei Mot', 'Achrei Mot'),
        ('Pinehas', 'Pinchas'),
        ('Vezot Haberacha', 'Vezot Haberakhah'),
        ('Vezos Habrachah', 'Vezot Haberakhah'),
        ('פנחס', 'Pinchas'),
        ('פינחס', 'Pinchas'),
        ('בהעלותך', "Beha'alotcha"),
        ('קדושים', 'Kedoshim'),
        ('בחוקותי', 'Bechukotai'),
        ('מצורע', 'Metzora'),
        ('שלח', "Sh'lach"),
        ('שלח לך', "Sh'lach"),
        ('וישלח', 'Vayishlach'),
        ('וזאת הברכה', 'Vezot Haberakhah'),
      ]) {
        final p = repo.all.firstWhere((p) => p.key == key);
        expect(parse(spelling), VerseReference(p.book, p.range.start), reason: spelling);
      }
    });

    test('alone, open at their first verse', () {
      expect(parse('Vayetzei'), verse('Genesis', 28, 10));
      expect(parse('ויצא'), verse('Genesis', 28, 10));
      expect(parse('Pekudei'), verse('Exodus', 38, 21));
      expect(parse('בא'), verse('Exodus', 10, 1));
      expect(parse('נח'), verse('Genesis', 6, 9));
      expect(parse('לך לך'), verse('Genesis', 12, 1));
      expect(parse('כי תצא'), verse('Deuteronomy', 21, 10));
    });

    test('say when only a name was given, which may be a word to search for', () {
      expect((parse('ויצא')! as VerseReference).byName, isTrue);
      expect((parse('Genesis')! as VerseReference).byName, isTrue);
      expect((parse('ויצא כח יב')! as VerseReference).byName, isFalse);
      expect((parse('Gen 28')! as VerseReference).byName, isFalse);
    });

    test('every parsha, by each of its names', () {
      for (final p in repo.all) {
        for (final name in [p.key, p.nameAshkenazi, p.nameHe, HebrewText.consonantsOnly(p.nameHe)]) {
          expect(parse(name), VerseReference(p.book, p.range.start), reason: name);
        }
      }
    });
  });

  group('without a verse', () {
    test('a chapter opens at its first verse', () {
      expect(parse('Gen 28'), verse('Genesis', 28, 1));
      expect(parse('בראשית כח'), verse('Genesis', 28, 1));
      expect(parse('Ki Tisa 30'), verse('Exodus', 30, 1));
    });

    test('a book named in full opens at its start, an abbreviation does not', () {
      expect(parse('Genesis'), verse('Genesis', 1, 1));
      expect(parse('דברים'), verse('Deuteronomy', 1, 1));
      expect(parse('Gen'), isNull);
      expect(parse('בר׳'), isNull);
    });
  });

  group('in the current week’s book', () {
    test('a bare chapter and verse', () {
      expect(parse('3:22', currentBook: 'Genesis'), verse('Genesis', 3, 22));
      expect(parse('3 22', currentBook: 'Genesis'), verse('Genesis', 3, 22));
      expect(parse('ג, כב', currentBook: 'Genesis'), verse('Genesis', 3, 22));
      expect(parse('ג׳:כ״ב', currentBook: 'Genesis'), verse('Genesis', 3, 22));
      expect(parse('ג׳ כ״ב', currentBook: 'Genesis'), verse('Genesis', 3, 22));
    });

    test('but two Hebrew words could be a phrase to search for', () {
      expect(parse('כח יב', currentBook: 'Genesis'), isNull);
    });

    test('and nothing without a current book', () {
      expect(parse('3:22'), isNull);
    });

    test('a single number is not a reference', () {
      expect(parse('28', currentBook: 'Genesis'), isNull);
      expect(parse('כח', currentBook: 'Genesis'), isNull);
    });
  });

  group('numbers past the end', () {
    test('a chapter the book doesn’t have', () {
      expect(parse('Gen 51:1'), const MissingVerse('Genesis', 51, chapters: 50));
      expect(parse('Gen 51'), const MissingVerse('Genesis', 51, chapters: 50));
      expect(parse('Gen 0:1'), const MissingVerse('Genesis', 0, chapters: 50));
      expect(parse('דברים לה, א'), const MissingVerse('Deuteronomy', 35, chapters: 34));
    });

    test('a verse the chapter doesn’t have', () {
      expect(parse('Gen 28:23'), const MissingVerse('Genesis', 28, chapters: 50, verses: 22));
      expect(parse('9:99', currentBook: 'Exodus'), const MissingVerse('Exodus', 9, chapters: 40, verses: 35));
    });
  });

  group('not references', () {
    test('words to search for', () {
      for (final s in ['', '   ', 'ladder', 'Abraham', 'אברהם', 'ויצא יעקב', 'בראשית ברא', 'in the beginning', 'Joshua 1:1', 'Gen 28:12:5', '::']) {
        expect(parse(s, currentBook: 'Genesis'), isNull, reason: s);
      }
    });
  });

  test('no spelling names two places', () {
    // The table asserts it as it is built, as the parser above was.
    expect(() => ReferenceParser.of(repo), returnsNormally);
  });

  test('ordinary Hebrew words are not taken for parshiyot', () {
    // Written without ו or י, they would match Shmini, Emor, Pekudei and
    // Masei spelled that way.
    for (final word in ['שמן', 'אמר', 'פקד', 'מסע']) {
      expect(parse(word), isNull, reason: word);
    }
  });
}
