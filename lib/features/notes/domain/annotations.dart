import 'dart:convert';
import 'dart:math';

import '../../../data/models/parsha.dart';
import '../../../data/models/verse_ref.dart';
import '../../progress/domain/progress_models.dart' show ProgressClock;

/// The longest note a verse takes, in characters.
const kNoteMaxLength = 2000;

/// What the reader has marked on one verse: a bookmark, a note, or both
/// (DESIGN.md §3). Stored and synced as
/// `{"b": bool, "n": String?, "bu": ms, "nu": ms, "u": ms}`: the bookmark,
/// the note, when each last changed, and the later of the two, which older
/// versions, keeping only `u`, compare whole annotations by.
///
/// Each of the two has a time of its own so that copies merge field by field
/// ([Annotations.merge]): a bookmark made on one device doesn't erase a note
/// written on another before they synced, nor the reverse.
///
/// One that holds neither is a tombstone: what is left of an annotation the
/// reader removed, kept with the time of the removal so that merging with a
/// copy that still has it removes it there too, rather than bringing it back.
class Annotation {
  const Annotation({
    this.bookmarked = false,
    this.note,
    required this.bookmarkAt,
    required this.noteAt,
    this.extra = const {},
  }) : assert(note == null || note != '');

  final bool bookmarked;

  /// The reader's note, never empty; null for none.
  final String? note;

  /// When [bookmarked] last changed, from [ProgressClock].
  final int bookmarkAt;

  /// When [note] last changed, from [ProgressClock].
  final int noteAt;

  /// Fields a newer version of the app stored with it, kept as they were so
  /// that saving here never drops them.
  final Map<String, Object?> extra;

  /// When this annotation last changed: the later of [bookmarkAt] and
  /// [noteAt].
  int get updatedAt => max(bookmarkAt, noteAt);

  bool get hasNote => note != null;

  /// Whether this is only the record of a removal.
  bool get isRemoved => !bookmarked && note == null;

  static const _known = {'b', 'n', 'u', 'bu', 'nu'};

  /// Reads one stored annotation, or returns null if [json] isn't one.
  ///
  /// One without times of its own for the bookmark and the note, the later
  /// of which is `u`, takes `u` for each: it was stored by an older version,
  /// which knows only `u`, or changed by one since, which stamped `u` anew
  /// and kept the times it couldn't read as they were.
  static Annotation? tryFromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final b = json['b'] ?? false;
    final n = json['n'];
    final u = json['u'];
    if (b is! bool || (n != null && n is! String) || u is! int || u < 0) return null;
    final (bu, nu) = switch ((json['bu'], json['nu'])) {
      (final int bu, final int nu) when bu >= 0 && nu >= 0 && max(bu, nu) == u => (bu, nu),
      _ => (u, u),
    };
    return Annotation(
      bookmarked: b,
      note: n == null || (n as String).trim().isEmpty ? null : n,
      bookmarkAt: bu,
      noteAt: nu,
      extra: {
        for (final MapEntry(:key, :value) in json.entries)
          if (!_known.contains(key)) key: value,
      },
    );
  }

  Map<String, Object?> toJson() =>
      {...extra, 'b': bookmarked, 'n': note, 'bu': bookmarkAt, 'nu': noteAt, 'u': updatedAt};

  /// This and [other], another copy of the same verse's annotation, merged
  /// field by field: the bookmark of the copy whose bookmark changed later,
  /// and on a tie, none; the note of the copy whose note changed later, and
  /// on a tie, none, or otherwise the note that sorts first; and the fields
  /// a newer version stored from the copy that changed later, and on a tie,
  /// those whose JSON sorts first.
  ///
  /// Each is the greater of the two under an order of its own, so that the
  /// result never depends on which copy is which, nor, merging three, on
  /// which two are merged first.
  Annotation mergedWith(Annotation other) {
    final bookmark = _laterBookmark(this, other) ? this : other;
    final note = _laterNote(this, other) ? this : other;
    final kept = updatedAt != other.updatedAt
        ? (updatedAt > other.updatedAt ? extra : other.extra)
        : (_canonical(extra).compareTo(_canonical(other.extra)) <= 0 ? extra : other.extra);
    return Annotation(
      bookmarked: bookmark.bookmarked,
      note: note.note,
      bookmarkAt: bookmark.bookmarkAt,
      noteAt: note.noteAt,
      extra: kept,
    );
  }

  /// Whether [a]'s bookmark outranks [b]'s: the later change, and on a tie,
  /// none.
  static bool _laterBookmark(Annotation a, Annotation b) =>
      a.bookmarkAt != b.bookmarkAt ? a.bookmarkAt > b.bookmarkAt : !a.bookmarked || b.bookmarked;

  /// Whether [a]'s note outranks [b]'s: the later change; on a tie, none;
  /// and otherwise the note that sorts first.
  static bool _laterNote(Annotation a, Annotation b) {
    if (a.noteAt != b.noteAt) return a.noteAt > b.noteAt;
    final (x, y) = (a.note, b.note);
    if (x == null || y == null) return x == null;
    return x.compareTo(y) <= 0;
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
  /// a change made now: the bookmark or the note that changes is stamped
  /// later than what is stored for the verse, even on a clock running behind
  /// the device that stamped that, and the other keeps its time. Fields a
  /// newer version stored with the verse stay, unless nothing is left on it.
  /// Unchanged if that is what is marked.
  Annotations _marked(BookVerse verse, {required bool bookmarked, required String? note}) {
    final current = this[verse];
    final bookmarkChanged = (current?.bookmarked ?? false) != bookmarked;
    final noteChanged = current?.note != note;
    if (!bookmarkChanged && !noteChanged) return this;
    final key = '$verse';
    final stored = entries[key];
    // Later than both of the verse's times, not only the changing one's, so
    // that `u` rises with every change for the older versions that compare
    // nothing else.
    final stamp = ProgressClock.after(stored?.updatedAt ?? 0);
    final next = Annotation(
      bookmarked: bookmarked,
      note: note,
      bookmarkAt: bookmarkChanged ? stamp : stored?.bookmarkAt ?? 0,
      noteAt: noteChanged ? stamp : stored?.noteAt ?? 0,
      extra: bookmarked || note != null ? stored?.extra ?? const {} : const {},
    );
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
  /// cloud's), verse by verse and field by field: the later change to the
  /// bookmark and the later change to the note each win, a removal included
  /// (see [Annotation.mergedWith]). Commutative, associative and idempotent,
  /// as a sync needs.
  static Annotations merge(Annotations a, Annotations b) {
    final entries = <String, Annotation>{...a.entries};
    for (final MapEntry(:key, :value) in b.entries.entries) {
      entries[key] = entries[key]?.mergedWith(value) ?? value;
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

  /// These annotations with [backup]'s restored, as importing a backup file
  /// restores them: a bookmark or a note it holds that isn't marked here
  /// comes back, even if removed here since, as a change made now, which the
  /// next sync carries to the reader's other devices. Everything else merges
  /// as a sync does ([merge]): a note changed here since keeps its change,
  /// and a removal the backup holds, later than what is here, still removes
  /// it.
  Annotations restoring(Annotations backup) {
    final restored = <String, Annotation>{};
    // The rest of the backup: removals, and what is marked here already.
    final rest = <String, Annotation>{};
    for (final MapEntry(:key, value: theirs) in backup.entries.entries) {
      final mine = entries[key];
      final bookmark = theirs.bookmarked && !(mine?.bookmarked ?? false);
      final note = theirs.hasNote && !(mine?.hasNote ?? false);
      if (!bookmark && !note) {
        rest[key] = theirs;
        continue;
      }
      final both = mine?.mergedWith(theirs) ?? theirs;
      final stamp = ProgressClock.after(both.updatedAt);
      restored[key] = Annotation(
        bookmarked: bookmark || both.bookmarked,
        note: note ? theirs.note : both.note,
        bookmarkAt: bookmark ? stamp : both.bookmarkAt,
        noteAt: note ? stamp : both.noteAt,
        // A verse marked here keeps what a newer version stored with it here;
        // one restored whole takes the backup's.
        extra: mine == null || mine.isRemoved ? theirs.extra : both.extra,
      );
    }
    return merge(Annotations({...entries, ...restored}, unknown), Annotations(rest, backup.unknown));
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
