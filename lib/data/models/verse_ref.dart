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
