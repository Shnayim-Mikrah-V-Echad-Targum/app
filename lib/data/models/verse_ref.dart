/// A chapter:verse position within one book.
class VerseRef implements Comparable<VerseRef> {
  const VerseRef(this.chapter, this.verse);

  /// Parses `"12:3"`.
  factory VerseRef.parse(String s) {
    final i = s.indexOf(':');
    return VerseRef(int.parse(s.substring(0, i)), int.parse(s.substring(i + 1)));
  }

  /// Parses `"12:3"` from outside the app's data, such as a link: null for
  /// anything else.
  static VerseRef? tryParse(String? s) {
    final m = _form.firstMatch(s ?? '');
    if (m == null) return null;
    final chapter = int.parse(m[1]!);
    final verse = int.parse(m[2]!);
    return chapter > 0 && verse > 0 ? VerseRef(chapter, verse) : null;
  }

  static final _form = RegExp(r'^(\d{1,3}):(\d{1,3})$');

  final int chapter;
  final int verse;

  @override
  int compareTo(VerseRef other) =>
      chapter != other.chapter ? chapter - other.chapter : verse - other.verse;

  bool operator <(VerseRef o) => compareTo(o) < 0;
  bool operator <=(VerseRef o) => compareTo(o) <= 0;
  bool operator >(VerseRef o) => compareTo(o) > 0;
  bool operator >=(VerseRef o) => compareTo(o) >= 0;

  @override
  bool operator ==(Object other) =>
      other is VerseRef && other.chapter == chapter && other.verse == verse;

  @override
  int get hashCode => Object.hash(chapter, verse);

  @override
  String toString() => '$chapter:$verse';
}

/// An inclusive range of verses within one book.
class VerseRange {
  const VerseRange(this.book, this.start, this.end);

  final String book;
  final VerseRef start;
  final VerseRef end;

  bool contains(VerseRef ref) => ref >= start && ref <= end;

  /// Every verse in the range, given the number of verses in each chapter.
  List<VerseRef> verses(List<int> chapterLengths) {
    final out = <VerseRef>[];
    var c = start.chapter;
    var v = start.verse;
    while (true) {
      out.add(VerseRef(c, v));
      if (c == end.chapter && v == end.verse) return out;
      if (v < chapterLengths[c - 1]) {
        v++;
      } else {
        c++;
        v = 1;
      }
      if (c > end.chapter || c > chapterLengths.length) {
        throw StateError('Range $this runs past the end of $book');
      }
    }
  }

  @override
  String toString() => '$book $start–$end';
}

/// One verse of a book of the Tanakh, as a link names it: the book as the
/// app's data names it, in English, then the chapter and verse ("Genesis
/// 3:22", "I Samuel 20:18").
class BookVerse {
  const BookVerse(this.book, this.ref);

  /// Parses `"Genesis 3:22"` from outside the app's data, such as a link:
  /// null for anything else. Whether the book is one the app has is for
  /// whoever looks the verse up to say.
  static BookVerse? tryParse(String? s) {
    final m = _form.firstMatch(s?.trim() ?? '');
    final ref = VerseRef.tryParse(m?[2]);
    return m == null || ref == null ? null : BookVerse(m[1]!, ref);
  }

  static final _form = RegExp(r'^([A-Za-z][A-Za-z ]*[A-Za-z]) +(\d+:\d+)$');

  final String book;
  final VerseRef ref;

  @override
  bool operator ==(Object other) => other is BookVerse && other.book == book && other.ref == ref;

  @override
  int get hashCode => Object.hash(book, ref);

  @override
  String toString() => '$book $ref';
}
