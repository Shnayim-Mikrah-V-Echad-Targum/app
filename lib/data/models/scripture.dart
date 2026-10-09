import 'verse_ref.dart';

/// A piece of a verse. Most verses are a single [PlainText] segment.
sealed class Segment {
  const Segment();

  static Segment fromJson(Object json) {
    if (json is String) return PlainText(json);
    final m = json as Map<String, dynamic>;
    if (m.containsKey('k')) return KetivQere(m['k'] as String, m['q'] as String);
    if (m.containsKey('n')) return TextNote(m['n'] as String);
    if (m.containsKey('big')) return SizedLetters(m['big'] as String, LetterSize.large);
    if (m.containsKey('small')) return SizedLetters(m['small'] as String, LetterSize.small);
    if (m.containsKey('sup')) return SizedLetters(m['sup'] as String, LetterSize.raised);
    if (m.containsKey('alt')) return AlternateReading(m['alt'] as String);
    if (m.containsKey('gap')) {
      return PisqaGap(switch (m['gap']) {
        'P' => SectionBreak.open,
        'S' => SectionBreak.closed,
        _ => throw FormatException('Unknown section gap $m'),
      });
    }
    throw FormatException('Unknown segment $m');
  }
}

class PlainText extends Segment {
  const PlainText(this.text);
  final String text;
}

/// A word written one way (ketiv) and read another (qere).
/// Either may be empty: "written but not read" / "read but not written".
class KetivQere extends Segment {
  const KetivQere(this.ketiv, this.qere);
  final String ketiv;
  final String qere;
}

/// An editorial note, such as a scribal variant between traditions.
class TextNote extends Segment {
  const TextNote(this.text);
  final String text;
}

enum LetterSize { large, small, raised }

/// Letters the Masorah writes large (e.g. the bet of Bereshit) or small.
class SizedLetters extends Segment {
  const SizedLetters(this.text, this.size);
  final String text;
  final LetterSize size;
}

/// (Targum) A bracketed alternate reading or gloss.
class AlternateReading extends Segment {
  const AlternateReading(this.text);
  final String text;
}

/// A petuchah or setumah that falls inside a verse (pisqa be'emtza pasuq),
/// as between the commandments of the Decalogue. The verse continues after
/// it; as text it is a word space.
class PisqaGap extends Segment {
  const PisqaGap(this.kind);
  final SectionBreak kind;
}

/// One verse as a list of segments.
class Verse {
  const Verse(this.ref, this.segments);

  factory Verse.fromJson(VerseRef ref, Object json) => Verse(
        ref,
        json is List ? [for (final s in json) Segment.fromJson(s as Object)] : [PlainText(json as String)],
      );

  final VerseRef ref;
  final List<Segment> segments;

  /// The verse as it is read aloud: qere for ketiv/qere, without notes or
  /// alternate readings, and a word space for a section gap inside it.
  String get readText {
    final b = StringBuffer();
    for (final s in segments) {
      switch (s) {
        case PlainText(:final text):
          b.write(text);
        case KetivQere(:final qere):
          b.write(qere);
        case SizedLetters(:final text):
          b.write(text);
        case PisqaGap():
          b.write(' ');
        case TextNote():
        case AlternateReading():
          break;
      }
    }
    return b.toString().replaceAll(RegExp(r'\s{2,}'), ' ').trim();
  }

  bool get isEmpty => segments.isEmpty;
}

/// Section breaks in the Torah scroll.
enum SectionBreak {
  /// Parasha petucha (פ): the next section starts on a new line.
  open,

  /// Parasha setuma (ס): a gap within the line.
  closed,
}

/// The full text of one layer (Mikra, Targum, translation) of one book.
class BookText {
  const BookText({required this.book, required this.chapters, this.breaks = const {}});

  factory BookText.fromJson(Map<String, dynamic> j) {
    final rawChapters = j['chapters'] as List;
    final chapters = <List<Verse>>[];
    for (var c = 0; c < rawChapters.length; c++) {
      final verses = rawChapters[c] as List;
      chapters.add([
        for (var v = 0; v < verses.length; v++) Verse.fromJson(VerseRef(c + 1, v + 1), verses[v] as Object),
      ]);
    }
    final breaks = <VerseRef, SectionBreak>{};
    final rawBreaks = j['breaks'] as Map<String, dynamic>?;
    rawBreaks?.forEach((k, v) {
      breaks[VerseRef.parse(k)] = v == 'P' ? SectionBreak.open : SectionBreak.closed;
    });
    return BookText(book: j['book'] as String, chapters: chapters, breaks: breaks);
  }

  final String book;
  final List<List<Verse>> chapters;

  /// Section break that follows the given verse.
  final Map<VerseRef, SectionBreak> breaks;

  List<int> get chapterLengths => [for (final c in chapters) c.length];

  Verse verse(VerseRef ref) => chapters[ref.chapter - 1][ref.verse - 1];

  List<Verse> range(VerseRange r) => [for (final ref in r.verses(chapterLengths)) verse(ref)];
}

/// One Rashi comment: the quoted words (dibbur hamatchil) and the comment.
class Comment {
  const Comment(this.heading, this.text);

  factory Comment.fromJson(Object json) {
    if (json is String) return Comment(null, json);
    final m = json as Map<String, dynamic>;
    return Comment(m['d'] as String?, m['t'] as String);
  }

  final String? heading;
  final String text;
}

/// A verse-by-verse commentary on one book.
class CommentaryText {
  const CommentaryText({required this.book, required this.chapters});

  factory CommentaryText.fromJson(Map<String, dynamic> j) => CommentaryText(
        book: j['book'] as String,
        chapters: [
          for (final ch in (j['chapters'] as List))
            [
              for (final v in (ch as List)) [for (final c in (v as List)) Comment.fromJson(c as Object)],
            ],
        ],
      );

  final String book;
  final List<List<List<Comment>>> chapters;

  List<Comment> on(VerseRef ref) {
    if (ref.chapter > chapters.length) return const [];
    final ch = chapters[ref.chapter - 1];
    return ref.verse > ch.length ? const [] : ch[ref.verse - 1];
  }
}
