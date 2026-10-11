import 'dart:convert';

import '../../../data/models/parsha.dart';
import '../../../data/models/verse_ref.dart';
import '../../progress/domain/progress_models.dart' show ProgressClock;

/// The longest note a verse takes, in characters.
const kNoteMaxLength = 2000;

/// What the reader has marked on one verse: a bookmark, a note, or both
/// (DESIGN.md §3). Stored and synced as `{"b": bool, "n": String?, "u": ms}`.
///
/// One that holds neither is a tombstone: what is left of an annotation the
/// reader removed, kept with the time of the removal so that merging with a
/// copy that still has it removes it there too, rather than bringing it back.
class Annotation {
  const Annotation({this.bookmarked = false, this.note, required this.updatedAt, this.extra = const {}})
      : assert(note == null || note != '');

  /// A tombstone, for an annotation removed at [updatedAt].
  const Annotation.removed(this.updatedAt)
      : bookmarked = false,
        note = null,
        extra = const {};

  final bool bookmarked;

  /// The reader's note, never empty; null for none.
  final String? note;

  /// When this annotation last changed, from [ProgressClock].
  final int updatedAt;

  /// Fields a newer version of the app stored with it, kept as they were so
  /// that saving here never drops them.
  final Map<String, Object?> extra;

  bool get hasNote => note != null;

  /// Whether this is only the record of a removal.
  bool get isRemoved => !bookmarked && note == null;

  static const _known = {'b', 'n', 'u'};

  /// Reads one stored annotation, or returns null if [json] isn't one.
  static Annotation? tryFromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final b = json['b'] ?? false;
    final n = json['n'];
    final u = json['u'];
    if (b is! bool || (n != null && n is! String) || u is! int || u < 0) return null;
    return Annotation(
      bookmarked: b,
      note: n == null || (n as String).trim().isEmpty ? null : n,
      updatedAt: u,
      extra: {
        for (final MapEntry(:key, :value) in json.entries)
          if (!_known.contains(key)) key: value,
      },
    );
  }

  Map<String, Object?> toJson() => {...extra, 'b': bookmarked, 'n': note, 'u': updatedAt};

  /// Whether this outranks [other], another copy of the same verse's
  /// annotation: the later change wins; on a tie, a removal; and otherwise,
  /// so that the choice never depends on which copy is which, the one whose
  /// JSON sorts first.
  bool outranks(Annotation other) {
    if (updatedAt != other.updatedAt) return updatedAt > other.updatedAt;
    if (isRemoved != other.isRemoved) return isRemoved;
    return _canonical(toJson()).compareTo(_canonical(other.toJson())) < 0;
  }
}

/// Every verse the reader has bookmarked or written a note on, keyed by the
/// verse as a link names it ("Genesis 3:22", see [BookVerse]). Treat as
/// immutable: equality is by value.
///
/// A removal leaves a tombstone ([Annotation.isRemoved]) rather than
/// dropping the key, so that it reaches the reader's other devices. Unlike
/// a cancelled pause, a tombstone is never forgotten: there is at most one
/// for each verse of the Torah, and forgetting it could bring a deleted note
/// back from a device that hasn't synced since.
class Annotations {
  const Annotations([this.entries = const {}, this.unknown = const {}]);

  static const empty = Annotations();

  /// Every annotation, tombstones included, by verse.
  final Map<String, Annotation> entries;

  /// Stored entries this version couldn't read, kept exactly as they were
  /// and written back out unchanged. A readable entry for the same verse
  /// takes precedence.
  final Map<String, Object?> unknown;

  /// What the reader has marked on [verse], or null for nothing (a
  /// tombstone included).
  Annotation? operator [](BookVerse verse) => switch (entries['$verse']) {
        final a? when !a.isRemoved => a,
        _ => null,
      };

  /// Whether nothing is marked anywhere.
  bool get isEmpty => !entries.values.any((a) => !a.isRemoved);

  /// Every verse of the Torah marked, in the Torah's order, with what is
  /// marked on it. Entries for other books (which a later version may keep)
  /// are left out.
  List<(BookVerse, Annotation)> get inTorah {
    final marked = [
      for (final MapEntry(:key, :value) in entries.entries)
        if (!value.isRemoved)
          if (BookVerse.tryParse(key) case final v? when kTorahBooks.contains(v.book)) (v, value),
    ];
    marked.sort((x, y) {
      final books = kTorahBooks.indexOf(x.$1.book) - kTorahBooks.indexOf(y.$1.book);
      return books != 0 ? books : x.$1.ref.compareTo(y.$1.ref);
    });
    return marked;
  }

  /// The verses of [range] marked, in order.
  List<(BookVerse, Annotation)> within(VerseRange range) =>
      [for (final e in inTorah) if (e.$1.book == range.book && range.contains(e.$1.ref)) e];

  /// These annotations with [verse] marked as [bookmarked] and [note] say,
  /// a change made now: stamped later than what it replaces, even on a clock
  /// running behind the device that stamped that. Fields a newer version
  /// stored with the verse stay. Unchanged if that is what is marked.
  Annotations _marked(BookVerse verse, {required bool bookmarked, required String? note}) {
    final current = this[verse];
    if ((current?.bookmarked ?? false) == bookmarked && current?.note == note) return this;
    final key = '$verse';
    final stored = entries[key];
    final stamp = ProgressClock.after(stored?.updatedAt ?? 0);
    final next = !bookmarked && note == null
        ? Annotation.removed(stamp)
        : Annotation(bookmarked: bookmarked, note: note, updatedAt: stamp, extra: stored?.extra ?? const {});
    return Annotations({...entries, key: next}, {...unknown}..remove(key));
  }

  /// [verse] bookmarked, or not.
  Annotations withBookmark(BookVerse verse, bool bookmarked) =>
      _marked(verse, bookmarked: bookmarked, note: this[verse]?.note);

  /// [verse] with [note] as its note: trimmed, and none if blank.
  Annotations withNote(BookVerse verse, String? note) {
    final text = note?.trim();
    return _marked(verse, bookmarked: this[verse]?.bookmarked ?? false, note: text == null || text.isEmpty ? null : text);
  }

  /// Merges two copies of the reader's annotations (this device's and the
  /// cloud's, or a backup's), verse by verse: the later change wins, a
  /// removal included (see [Annotation.outranks]). Commutative, associative
  /// and idempotent, as a sync needs.
  static Annotations merge(Annotations a, Annotations b) {
    final entries = <String, Annotation>{...a.entries};
    for (final MapEntry(:key, :value) in b.entries.entries) {
      final mine = entries[key];
      if (mine == null || value.outranks(mine)) entries[key] = value;
    }
    // What neither could read goes along untouched, unless either could:
    // and of two for the same verse, the one whose JSON sorts first.
    final unknown = <String, Object?>{};
    for (final side in [a, b]) {
      for (final MapEntry(:key, :value) in side.unknown.entries) {
        if (entries.containsKey(key)) continue;
        if (!unknown.containsKey(key) || _canonical(value).compareTo(_canonical(unknown[key])) < 0) unknown[key] = value;
      }
    }
    return Annotations(entries, unknown);
  }

  /// Reads stored or synced annotations leniently: an entry that can't be
  /// read is kept aside in [unknown] rather than losing the rest. Anything
  /// but a JSON object reads as none.
  factory Annotations.fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return empty;
    final entries = <String, Annotation>{};
    final unknown = <String, Object?>{};
    for (final MapEntry(:key, :value) in json.entries) {
      if (Annotation.tryFromJson(value) case final a?) {
        entries[key] = a;
      } else {
        unknown[key] = value;
      }
    }
    return Annotations(entries, unknown);
  }

  Map<String, Object?> toJson() => {...unknown, for (final e in entries.entries) e.key: e.value.toJson()};

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is Annotations && _canonical(other.toJson()) == _canonical(toJson());

  @override
  int get hashCode => _canonical(toJson()).hashCode;
}

/// [json] with every object's keys sorted, encoded, so that equal JSON
/// compares equal whatever order its keys arrive in (the server's jsonb
/// storage reorders them).
String _canonical(Object? json) {
  Object? sorted(Object? v) => switch (v) {
        Map() => {for (final k in v.keys.map((k) => '$k').toList()..sort()) k: sorted(v[k])},
        List() => [for (final e in v) sorted(e)],
        _ => v,
      };
  return jsonEncode(sorted(json));
}
