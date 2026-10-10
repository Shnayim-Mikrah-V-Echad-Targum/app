import '../../core/calendar/parsha_schedule.dart';
import '../../core/calendar/special_haftarah.dart' show HaftarahNusach;
import 'verse_ref.dart';

export '../../core/calendar/special_haftarah.dart' show HaftarahNusach;

/// A passage from the Prophets, possibly one of several read together.
class HaftarahPart {
  const HaftarahPart(this.book, this.start, this.end);

  factory HaftarahPart.fromJson(Map<String, dynamic> j) => HaftarahPart(
        j['k'] as String,
        VerseRef.parse(j['b'] as String),
        VerseRef.parse(j['e'] as String),
      );

  final String book;
  final VerseRef start;
  final VerseRef end;

  /// Whether [other] lies within this passage.
  bool covers(HaftarahPart other) => other.book == book && other.start >= start && other.end <= end;

  @override
  String toString() => '$book $start-$end';
}

typedef Haftarah = List<HaftarahPart>;

/// Whether every verse of [inner] is read in [outer].
bool haftarahCovers(Haftarah outer, Haftarah inner) => inner.every((p) => outer.any((o) => o.covers(p)));

/// Haftarah references by tradition. Sephardi and Chabad fall back to the
/// Ashkenazi reading where they have none of their own.
///
/// Sephardi readings are listed wherever they differ, so a Sephardi
/// fallback is the same reading. Chabad's are listed only where they have
/// been sourced so far, so a Chabad fallback may not be the Chabad reading
/// (see [fallsBack]).
class HaftarahOptions {
  const HaftarahOptions({required this.ashkenazi, this.sephardi, this.chabad});

  factory HaftarahOptions.fromJson(Map<String, dynamic> j) {
    Haftarah? parse(Object? o) => o == null
        ? null
        : [for (final p in (o as List)) HaftarahPart.fromJson(p as Map<String, dynamic>)];
    return HaftarahOptions(
      ashkenazi: parse(j['ashkenazi'])!,
      sephardi: parse(j['sephardi']),
      chabad: parse(j['chabad']),
    );
  }

  final Haftarah ashkenazi;
  final Haftarah? sephardi;
  final Haftarah? chabad;

  Haftarah forNusach(HaftarahNusach nusach) => switch (nusach) {
        HaftarahNusach.ashkenazi => ashkenazi,
        HaftarahNusach.sephardi => sephardi ?? ashkenazi,
        HaftarahNusach.chabad => chabad ?? ashkenazi,
      };

  /// Whether [forNusach] gives [nusach] the Ashkenazi reading for want of
  /// its own, rather than because the two are the same: so far, a Chabad
  /// reading that isn't listed.
  bool fallsBack(HaftarahNusach nusach) => nusach == HaftarahNusach.chabad && chabad == null;
}

/// Metadata for one weekly reading (a single parsha or a combined pair).
class PortionInfo {
  const PortionInfo({
    required this.id,
    required this.key,
    required this.nameHe,
    required this.nameEn,
    required this.nameAshkenazi,
    required this.book,
    required this.aliyot,
    required this.haftarah,
    this.aliyahNotes = const {},
  });

  factory PortionInfo.fromJson(Map<String, dynamic> j, PortionId id) {
    final book = j['book'] as String;
    final aliyot = <VerseRange>[];
    final notes = <int, String>{};
    final list = j['aliyot'] as List;
    for (var i = 0; i < list.length; i++) {
      final a = list[i] as Map<String, dynamic>;
      aliyot.add(VerseRange(book, VerseRef.parse(a['b'] as String), VerseRef.parse(a['e'] as String)));
      if (a['note'] != null) notes[i] = a['note'] as String;
    }
    return PortionInfo(
      id: id,
      key: j['key'] as String,
      nameHe: j['he'] as String,
      nameEn: j['en'] as String,
      nameAshkenazi: j['ashkenazi'] as String,
      book: book,
      aliyot: aliyot,
      haftarah: HaftarahOptions.fromJson(j['haftarah'] as Map<String, dynamic>),
      aliyahNotes: notes,
    );
  }

  final PortionId id;

  /// The stable data key, @hebcal's name (e.g. "Lech-Lecha"). Progress and
  /// other data are keyed by it, so it never changes; it is never shown.
  final String key;
  final String nameHe;

  /// The English name in Sephardi (Israeli) pronunciation, e.g. "Lech Lecha".
  final String nameEn;

  /// The English name in Ashkenazi pronunciation, e.g. "Bereishis".
  final String nameAshkenazi;

  /// English book name, e.g. "Genesis".
  final String book;

  /// The seven aliyot.
  final List<VerseRange> aliyot;

  final HaftarahOptions haftarah;

  /// Notes on alternative aliyah boundaries, keyed by aliyah index.
  final Map<int, String> aliyahNotes;

  VerseRange get range => VerseRange(book, aliyot.first.start, aliyot.last.end);

  /// Index of the book in the Torah, 0 (Genesis) – 4 (Deuteronomy).
  int get bookIndex => kTorahBooks.indexOf(book);

  String displayName({required bool ashkenazi}) => ashkenazi ? nameAshkenazi : nameEn;
}

const kTorahBooks = ['Genesis', 'Exodus', 'Leviticus', 'Numbers', 'Deuteronomy'];

const kTorahBooksHe = ['בראשית', 'שמות', 'ויקרא', 'במדבר', 'דברים'];
