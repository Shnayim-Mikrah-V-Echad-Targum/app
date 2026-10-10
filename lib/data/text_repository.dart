import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'models/parsha.dart';
import 'models/scripture.dart';
import 'models/verse_ref.dart';

/// The text layers bundled with the app.
enum TextLayer {
  /// Hebrew Torah text (Miqra according to the Masorah).
  mikra('mikra'),

  /// Targum Onkelos (Aramaic).
  onkelos('onkelos'),

  /// JPS 1917 English translation — a study aid only.
  english('english');

  const TextLayer(this.folder);
  final String folder;
}

enum CommentaryLayer {
  rashi('rashi'),
  rashiEnglish('rashi_en');

  const CommentaryLayer(this.folder);
  final String folder;
}

/// Loads and caches bundled scripture text. All text ships with the app, so
/// it works fully offline.
class TextRepository {
  TextRepository([AssetBundle? bundle]) : _bundle = bundle ?? rootBundle;

  final AssetBundle _bundle;
  final _books = <String, Future<BookText>>{};
  final _commentaries = <String, Future<CommentaryText>>{};
  Future<_Haftarot>? _haftarot;

  Future<Map<String, dynamic>> _json(String path) async {
    final raw = await _bundle.loadString(path, cache: false);
    // Decoding a ~400 KB file takes a few milliseconds; do it off the UI
    // thread where isolates are available.
    return kIsWeb ? jsonDecode(raw) as Map<String, dynamic> : compute(_decode, raw);
  }

  static Map<String, dynamic> _decode(String raw) => jsonDecode(raw) as Map<String, dynamic>;

  Future<BookText> book(TextLayer layer, String book) {
    final key = '${layer.folder}/$book';
    return _books.putIfAbsent(key, () async {
      try {
        return BookText.fromJson(await _json('assets/text/${layer.folder}/${book.toLowerCase()}.json'));
      } catch (e) {
        _books.remove(key);
        rethrow;
      }
    });
  }

  /// Reads one layer of [book] through [read], all of it off the UI thread
  /// where isolates are available, and keeps nothing: for a pass over every
  /// verse whose result is smaller than the book, such as the search index.
  /// [read] must be a top-level or static function, so it can cross to the
  /// isolate.
  Future<T> readBook<T>(TextLayer layer, String book, T Function(BookText text) read) async {
    final raw = await _bundle.loadString('assets/text/${layer.folder}/${book.toLowerCase()}.json', cache: false);
    final job = (raw: raw, read: read);
    return kIsWeb ? _readRaw(job) : compute(_readRaw<T>, job);
  }

  static T _readRaw<T>(({String raw, T Function(BookText) read}) job) =>
      job.read(BookText.fromJson(_decode(job.raw)));

  Future<CommentaryText> commentary(CommentaryLayer layer, String book) {
    final key = '${layer.folder}/$book';
    return _commentaries.putIfAbsent(key, () async {
      try {
        return CommentaryText.fromJson(await _json('assets/text/${layer.folder}/${book.toLowerCase()}.json'));
      } catch (e) {
        _commentaries.remove(key);
        rethrow;
      }
    });
  }

  /// The verses of a haftarah, in Hebrew and English.
  Future<List<HaftarahVerse>> haftarah(Haftarah parts) async {
    final h = await (_haftarot ??= _loadHaftarot());
    final out = <HaftarahVerse>[];
    for (final part in parts) {
      final he = h.he[part.book]!;
      final en = h.en[part.book]!;
      var c = part.start.chapter;
      var v = part.start.verse;
      while (true) {
        final ref = VerseRef(c, v);
        final heVerse = he['$c:$v'];
        if (heVerse == null) {
          // Next chapter.
          c++;
          v = 1;
          if (VerseRef(c, v) > part.end) break;
          continue;
        }
        out.add(HaftarahVerse(
          book: part.book,
          bookHe: h.bookNames[part.book] ?? part.book,
          hebrew: Verse.fromJson(ref, heVerse),
          english: en['$c:$v'] as String? ?? '',
        ));
        if (ref == part.end) break;
        v++;
      }
    }
    return out;
  }

  Future<_Haftarot> _loadHaftarot() async {
    final j = await _json('assets/text/haftarot.json');
    return _Haftarot(
      bookNames: (j['books'] as Map<String, dynamic>).cast<String, String>(),
      he: {for (final e in (j['he'] as Map<String, dynamic>).entries) e.key: (e.value as Map<String, dynamic>)},
      en: {for (final e in (j['en'] as Map<String, dynamic>).entries) e.key: (e.value as Map<String, dynamic>)},
    );
  }
}

class HaftarahVerse {
  const HaftarahVerse({required this.book, required this.bookHe, required this.hebrew, required this.english});
  final String book;
  final String bookHe;
  final Verse hebrew;
  final String english;
}

class _Haftarot {
  const _Haftarot({required this.bookNames, required this.he, required this.en});
  final Map<String, String> bookNames;
  final Map<String, Map<String, dynamic>> he;
  final Map<String, Map<String, dynamic>> en;
}
