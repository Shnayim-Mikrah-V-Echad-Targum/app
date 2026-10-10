import '../../core/text/hebrew_text.dart';
import '../../data/models/parsha.dart';
import '../../data/models/verse_ref.dart';
import '../../data/parsha_repository.dart';

/// A reference to the Torah read from what someone typed: a verse, or
/// numbers past the end of a book or chapter.
sealed class TypedReference {
  const TypedReference(this.book);

  /// The book, as [kTorahBooks] names it.
  final String book;
}

/// A verse of the Torah.
final class VerseReference extends TypedReference {
  const VerseReference(super.book, this.verse, {this.byName = false});

  final VerseRef verse;

  /// Whether only a name was given, a book's or a parsha's, which opens at
  /// its first verse: as a word, it may also be meant as a search.
  final bool byName;

  @override
  bool operator ==(Object other) => other is VerseReference && other.book == book && other.verse == verse;

  @override
  int get hashCode => Object.hash(book, verse);

  @override
  String toString() => '$book $verse';
}

/// A chapter the book doesn't have ([verses] is null), or a verse the
/// chapter doesn't have.
final class MissingVerse extends TypedReference {
  const MissingVerse(super.book, this.chapter, {required this.chapters, this.verses});

  final int chapter;

  /// How many chapters the book has.
  final int chapters;

  /// How many verses [chapter] has, when the book has that chapter.
  final int? verses;

  @override
  bool operator ==(Object other) =>
      other is MissingVerse &&
      other.book == book &&
      other.chapter == chapter &&
      other.chapters == chapters &&
      other.verses == verses;

  @override
  int get hashCode => Object.hash(book, chapter, chapters, verses);

  @override
  String toString() => 'MissingVerse($book $chapter, of $chapters chapters, ${verses ?? '-'} verses)';
}

/// Reads a reference to a verse of the Torah, as people write one:
///
/// - a book in English, in transliteration or in Hebrew, or an abbreviation
///   ("Genesis", "Gen", "Bereshit", "Bereishis", "בראשית", "בר׳");
/// - or a parsha, in either transliteration or in Hebrew ("Vayetzei",
///   "Vayeitzei", "ויצא"), which stands for its book;
/// - then the chapter and the verse, in digits or Hebrew numerals ("28:12",
///   "כ״ח, י״ב", "כח יב"), separated by a colon, comma, full stop or space.
///
/// Without a verse, a chapter opens at its first verse, and a book or parsha
/// named in full at its own first verse. Without a book, a chapter and verse
/// ("3:22") are in [parse]'s `currentBook`.
class ReferenceParser {
  /// Knows the names of [parshiyot] and the books they are in, whose lengths
  /// [_chapterLengths] gives.
  ReferenceParser(List<PortionInfo> parshiyot, this._chapterLengths) : _names = _nameTable(parshiyot);

  ReferenceParser.of(ParshaRepository repo) : this(repo.all, repo.chapterLengths);

  final List<int> Function(String book) _chapterLengths;
  final Map<String, _Name> _names;

  /// The reference [input] makes, or null if it makes none. A bare chapter
  /// and verse are taken in [currentBook].
  TypedReference? parse(String input, {String? currentBook}) {
    final text = _prepare(input);
    final tokens = [
      for (final m in _token.allMatches(text))
        if (!_fillers.contains(m[0]!.toLowerCase().replaceAll(_numeralMarks, ''))) m,
    ];
    // The most numbers that leave a name before them, or nothing at all.
    for (var count = 2; count >= 0; count--) {
      if (tokens.length < count) continue;
      final numbers = [for (final m in tokens.sublist(tokens.length - count)) _number(m[0]!)];
      if (numbers.contains(null)) continue;
      final nameTokens = tokens.sublist(0, tokens.length - count);
      final _Name name;
      if (nameTokens.isEmpty) {
        // Two numbers on their own, plainly a reference rather than words.
        if (count < 2 || currentBook == null || !_plainlyNumbers(text, tokens)) continue;
        name = _Name(currentBook, full: false);
      } else {
        final nameText = text.substring(nameTokens.first.start, nameTokens.last.end);
        // A number left over is not part of a name ("Gen 28:12:5").
        if (nameText.contains(_digit)) continue;
        final named = _names[_key(nameText)];
        if (named == null || (count == 0 && !named.full)) continue;
        name = named;
      }
      return switch (numbers) {
        [final chapter!, final verse!] => _check(name.book, chapter, verse),
        [final chapter!] => _check(name.book, chapter, 1),
        _ => VerseReference(name.book, name.opening, byName: true),
      };
    }
    return null;
  }

  TypedReference _check(String book, int chapter, int verse) {
    final lengths = _chapterLengths(book);
    if (chapter < 1 || chapter > lengths.length) return MissingVerse(book, chapter, chapters: lengths.length);
    if (verse < 1 || verse > lengths[chapter - 1]) {
      return MissingVerse(book, chapter, chapters: lengths.length, verses: lengths[chapter - 1]);
    }
    return VerseReference(book, VerseRef(chapter, verse));
  }

  // --- Reading the text ---------------------------------------------------

  // Words, numbers and names: what lies between the separators.
  static final _token = RegExp(r'[^\s:,.;]+');

  // The geresh and gershayim, and the quotation marks typed for them.
  static final _numeralMarks = RegExp('[׳״\'"`’‘”“]');

  // Words that may stand around the name and numbers: "the book of",
  // "parshat", "chapter 28 verse 12".
  static const _fillers = {
    'the', 'book', 'of', 'parshat', 'parashat', 'chapter', 'chap', 'ch', 'verse', 'vs', 'v', 'perek', 'pasuk', //
    'ספר', 'פרשת', 'פרק', 'פסוק', 'פס',
  };

  // Directional marks and isolates, as text copied from a page can carry.
  static final _bidiControls = RegExp('[\u200e\u200f\u202a-\u202e\u2066-\u2069]');

  // A Latin name run into its chapter: "Gen28:12".
  static final _nameThenDigit = RegExp(r'([A-Za-z])(\d)');

  static final _dash = RegExp('[–—]');
  static final _hyphen = RegExp('-');
  static final _lastToken = RegExp(r'[^\s:,.;-]+$');

  static String _prepare(String input) {
    var text = input.replaceAll(_bidiControls, '').trim();
    // Of a range, only its first verse is wanted. Names have no dashes, and
    // hyphens only between words, never straight after a number.
    final dash = text.indexOf(_dash);
    if (dash >= 0) text = text.substring(0, dash);
    for (final hyphen in _hyphen.allMatches(text)) {
      final before = _lastToken.firstMatch(text.substring(0, hyphen.start))?[0];
      if (before != null && _number(before) != null) {
        text = text.substring(0, hyphen.start);
        break;
      }
    }
    return text.replaceAllMapped(_nameThenDigit, (m) => '${m[1]} ${m[2]}');
  }

  static final _digits = RegExp(r'^\d{1,3}$');
  static final _digit = RegExp(r'\d');

  /// A chapter or verse number: digits, or Hebrew numerals in their usual
  /// form (so that a word such as לך is not one).
  static int? _number(String token) {
    if (_digits.hasMatch(token)) return int.parse(token);
    if (!HebrewText.containsHebrew(token)) return null;
    return HebrewText.parseGematria(HebrewText.consonantsOnly(token));
  }

  /// Whether the last two tokens, with no name before them, are plainly a
  /// chapter and verse: in digits, joined by a colon, comma or full stop, or
  /// marked as numerals. Two Hebrew words such as כח יב could be a phrase to
  /// search for.
  static bool _plainlyNumbers(String text, List<RegExpMatch> tokens) {
    final [chapter, verse] = tokens.sublist(tokens.length - 2);
    return (_digits.hasMatch(chapter[0]!) && _digits.hasMatch(verse[0]!)) ||
        text.substring(chapter.end, verse.start).contains(RegExp('[:,.]')) ||
        _numeralMarks.hasMatch(chapter[0]!) ||
        _numeralMarks.hasMatch(verse[0]!);
  }

  // --- Names ----------------------------------------------------------------

  static final _notLatin = RegExp('[^a-z]');
  static final _notHebrewLetter = RegExp('[^א-ת]');
  static final _doubled = RegExp(r'(.)\1+');
  static final _finalH = RegExp(r'([aeiou])h$');

  /// A name as it is compared, so that its spellings meet: in Latin letters,
  /// in lower case without spaces, hyphens or apostrophes, and with the
  /// common variants of transliteration made one (kh and ch, q and k, ts and
  /// tz, w and v, ei and e, doubled letters, a final h after a vowel); in
  /// Hebrew, without points, spaces, maqaf, geresh or final forms.
  ///
  /// Hebrew spelled with or without the ו and י that mark vowels is listed
  /// name by name ([_parshaNames]) rather than folded: folded, words such as
  /// שמן and אמר would read as the parshiyot Shmini and Emor.
  static String _key(String name) {
    if (HebrewText.containsHebrew(name)) {
      return HebrewText.foldFinals(HebrewText.consonantsOnly(name).replaceAll(_notHebrewLetter, ''));
    }
    return name
        .toLowerCase()
        .replaceAll(_notLatin, '')
        .replaceAll('kh', 'ch')
        .replaceAll('q', 'k')
        .replaceAll('ts', 'tz')
        .replaceAll('w', 'v')
        .replaceAll('ei', 'e')
        .replaceAllMapped(_doubled, (m) => m[1]!)
        .replaceFirstMapped(_finalH, (m) => m[1]!);
  }

  /// The names of the books of the Torah: in full, which can stand alone,
  /// and abbreviated, which need a chapter after them.
  static const _bookNames = {
    'Genesis': (
      full: ['Genesis', 'Bereshit', 'Bereishis', 'Breishit', 'Beresheet', 'בראשית'],
      short: ['Gen', 'Gn', 'Ge', 'בר'],
    ),
    'Exodus': (
      full: ['Exodus', 'Shemot', 'Shemos', 'Shmot', 'Shmos', 'שמות'],
      short: ['Ex', 'Exo', 'Exod', 'שמ'],
    ),
    'Leviticus': (
      full: ['Leviticus', 'Vayikra', 'Wayyiqra', 'ויקרא'],
      short: ['Lev', 'Lv', 'ויק'],
    ),
    'Numbers': (
      full: ['Numbers', 'Bamidbar', 'Bemidbar', 'במדבר'],
      short: ['Num', 'Nm', 'Nu', 'Numb', 'במ', 'במד'],
    ),
    'Deuteronomy': (
      full: ['Deuteronomy', 'Devarim', 'Dvarim', 'Debarim', 'דברים'],
      short: ['Deut', 'Dt', 'Deu', 'דב', 'דבר'],
    ),
  };

  /// Spellings of parsha names common enough to know, beyond the data's own
  /// two transliterations and its Hebrew, by the data's key. The Hebrew adds
  /// the spellings with and without ו and י.
  static const _parshaNames = {
    'Noach': ['Noah'],
    'Lech-Lecha': ['Lekh Lekha'],
    'Toldot': ['Toledot'],
    'Tetzaveh': ['תצווה'],
    'Metzora': ['מצורע'],
    'Achrei Mot': ['Acharei Mot', 'Aharei Mot'],
    'Kedoshim': ['קדושים'],
    'Bechukotai': ['בחוקותי', 'בחקותי'],
    "Beha'alotcha": ['Behaalotecha', "Beha'alotecha", 'Behaaloscha', 'בהעלותך'],
    "Sh'lach": ['Shelach Lecha', 'Shlach Lecha', 'Shlach', 'שלח'],
    'Korach': ['Korah'],
    'Chukat': ['חוקת'],
    'Pinchas': ['Pinehas', 'פנחס'],
    'Shoftim': ['Shofetim'],
    'Nitzavim': ['ניצבים'],
    'Vezot Haberakhah': ['Vezot Haberacha', "V'Zot HaBerachah", 'Zot Haberacha', 'זאת הברכה'],
  };

  static Map<String, _Name> _nameTable(List<PortionInfo> parshiyot) {
    final names = <String, _Name>{};
    void add(String spelling, _Name name) {
      final key = _key(spelling);
      final before = names[key];
      // A book may take the name of the parsha that opens it, which begins
      // where it does; no other spelling may name two places.
      assert(
        before == null || (before.book == name.book && before.opening == name.opening && name.full),
        '"$spelling" names both ${before.book} ${before.opening} and ${name.book} ${name.opening}',
      );
      names[key] = name;
    }

    for (final p in parshiyot) {
      final name = _Name(p.book, full: true, start: p.range.start);
      for (final spelling in [p.key, p.nameAshkenazi, p.nameHe, ...?_parshaNames[p.key]]) {
        add(spelling, name);
      }
    }
    for (final MapEntry(key: book, value: spellings) in _bookNames.entries) {
      for (final spelling in spellings.full) {
        add(spelling, _Name(book, full: true));
      }
      for (final spelling in spellings.short) {
        add(spelling, _Name(book, full: false));
      }
    }
    return names;
  }
}

/// What a name stands for: a book, or a parsha in it that begins at [start].
class _Name {
  const _Name(this.book, {required this.full, this.start});

  final String book;

  /// Whether it is a name in full, which can stand alone, rather than an
  /// abbreviation, which needs a chapter after it.
  final bool full;
  final VerseRef? start;

  /// Where it begins: the parsha's first verse, or the book's.
  VerseRef get opening => start ?? const VerseRef(1, 1);
}
