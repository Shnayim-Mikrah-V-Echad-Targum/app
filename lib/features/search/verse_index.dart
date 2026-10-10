import 'dart:async';

import '../../core/text/hebrew_text.dart';
import '../../data/models/parsha.dart';
import '../../data/models/scripture.dart';
import '../../data/models/verse_ref.dart';
import '../../data/text_repository.dart';

/// Text as search compares it.
abstract final class SearchText {
  /// [text] folded for comparison:
  /// * Hebrew without its marks, as [HebrewText.consonantsOnly] leaves it,
  ///   and with final letters in their ordinary forms ([HebrewText.foldFinals]);
  /// * Latin letters in lower case;
  /// * apostrophes, quotation marks, geresh and gershayim left out, so
  ///   "Jacob’s" is "jacobs";
  /// * every other run of spaces and punctuation, the maqaf, paseq and sof
  ///   pasuq among them, as one space, with none at either end.
  static String fold(String text) => _fold(text, null);

  /// [fold], with the index in [text] that each character of the result
  /// comes from.
  static ({String folded, List<int> sources}) foldWithSources(String text) {
    final sources = <int>[];
    return (folded: _fold(text, sources), sources: sources);
  }

  static const _space = 0x20;

  /// Marks of quotation and elision, and invisible characters: left out
  /// without parting the letters around them.
  static const _dropped = {
    0x22, 0x27, 0xAD, 0x02BC, 0x05F3, 0x05F4, 0x200B, 0x200C, 0x200D, 0x200E, 0x200F, //
    0x2018, 0x2019, 0x201C, 0x201D, 0x2060, 0xFEFF,
  };

  static String _fold(String text, List<int>? sources) {
    final out = <int>[];
    // Where the separator not yet written began, if one is pending.
    var gap = -1;
    void write(int unit, int source) {
      if (gap >= 0 && out.isNotEmpty) {
        out.add(_space);
        sources?.add(gap);
      }
      gap = -1;
      out.add(unit);
      sources?.add(source);
    }

    for (var i = 0; i < text.length; i++) {
      final c = text.codeUnitAt(i);
      if (c >= 0x05D0 && c <= 0x05EA) {
        write(HebrewText.foldFinal(c), i);
      } else if (c >= 0x61 && c <= 0x7A || c >= 0x30 && c <= 0x39) {
        write(c, i);
      } else if (c >= 0x41 && c <= 0x5A) {
        write(c + 0x20, i);
      } else if (HebrewText.isMark(c) || _dropped.contains(c)) {
        continue;
      } else if (c >= 0xC0 && c < 0x0590 && _isLetter(text[i])) {
        for (final unit in text[i].toLowerCase().codeUnits) {
          write(unit, i);
        }
      } else if (gap < 0) {
        gap = i;
      }
    }
    return String.fromCharCodes(out);
  }

  static bool _isLetter(String char) => char.toLowerCase() != char.toUpperCase();

  /// Whether [folded] text has Hebrew letters in it.
  static bool hasHebrew(String folded) => folded.codeUnits.any((c) => c >= 0x05D0 && c <= 0x05EA);
}

/// The layers search reads, in the order a result shows them.
const searchLayers = [TextLayer.mikra, TextLayer.onkelos, TextLayer.english];

/// A search shorter than this, in letters, would match nearly every verse.
const kMinSearchLength = 2;

/// Whether [query] is long enough to search for ([kMinSearchLength]).
bool isSearchable(String query) => SearchText.fold(query).replaceAll(' ', '').length >= kMinSearchLength;

/// The most verses one search lists.
const kSearchLimit = 200;

/// Where [query] stands in [folded] text, from [from]: anywhere in a Hebrew
/// or Aramaic word, whose prefixes (ו, ה, ב, ל…) are part of it, but only at
/// the start of an English one, so "ram" doesn't find Abram. -1 if nowhere.
int _find(String folded, String query, {required bool wordStart, int from = 0}) {
  var at = folded.indexOf(query, from);
  if (!wordStart) return at;
  while (at > 0 && folded.codeUnitAt(at - 1) != SearchText._space) {
    at = folded.indexOf(query, at + 1);
  }
  return at;
}

/// A verse's text cut to a few lines around what was found, and where in it
/// the matches are.
class Snippet {
  const Snippet(this.text, this.matches, {this.clippedStart = false, this.clippedEnd = false});

  /// Cuts [display] to about [span] words, starting [lead] words before the
  /// first match of [query] (already folded) where there is room, and marks
  /// every match within that. With no [query], the first [span] words. A
  /// verse of up to a third more than [span] words is left whole.
  factory Snippet.find(String display, String? query, {required bool wordStart, int lead = 4, int span = 16}) {
    final matches = <({int start, int end})>[];
    if (query != null && query.isNotEmpty) {
      final (:folded, :sources) = SearchText.foldWithSources(display);
      for (var at = _find(folded, query, wordStart: wordStart);
          at >= 0;
          at = _find(folded, query, wordStart: wordStart, from: at + query.length)) {
        var end = sources[at + query.length - 1] + 1;
        // The marks on the last letter belong to it.
        while (end < display.length && HebrewText.isMark(display.codeUnitAt(end))) {
          end++;
        }
        matches.add((start: sources[at], end: end));
      }
    }

    final words = <({int start, int end})>[];
    for (var i = 0, start = -1; i <= display.length; i++) {
      final space = i == display.length || _isSpace(display.codeUnitAt(i));
      if (space && start >= 0) {
        words.add((start: start, end: i));
        start = -1;
      } else if (!space && start < 0) {
        start = i;
      }
    }
    if (words.isEmpty) return Snippet(display, const []);

    int wordAt(int index) {
      final w = words.indexWhere((w) => w.end > index);
      return w < 0 ? words.length - 1 : w;
    }

    // A verse a little longer than the span shows whole, rather than lose
    // its last few words; so does the end of a longer one, or its start.
    final slack = span ~/ 3;
    var from = 0;
    var to = words.length - 1;
    if (words.length > span + slack) {
      if (matches.isEmpty) {
        to = span - 1;
      } else {
        final first = matches.first;
        final last = wordAt(first.end - 1);
        from = (wordAt(first.start) - lead).clamp(0, words.length - 1);
        to = (from + span - 1).clamp(last, words.length - 1);
        // Near the end, the words before fill the room instead.
        from = (to - span + 1).clamp(0, from);
      }
      if (from <= slack ~/ 2) from = 0;
      if (words.length - 1 - to <= slack ~/ 2) to = words.length - 1;
    }
    final start = words[from].start;
    final end = words[to].end;
    return Snippet(
      display.substring(start, end),
      [
        for (final m in matches)
          if (m.end > start && m.start < end) (start: m.start.clamp(start, end) - start, end: m.end.clamp(start, end) - start),
      ],
      clippedStart: from > 0,
      clippedEnd: to < words.length - 1,
    );
  }

  static bool _isSpace(int c) => c == 0x20 || c == 0xA0 || c == 0x2003 || c == 0x09 || c == 0x0A;

  /// The verse's words shown, without the ellipses that [clippedStart] and
  /// [clippedEnd] call for.
  final String text;

  /// Each match, as a range of [text].
  final List<({int start, int end})> matches;

  /// Whether words before [text] were left out.
  final bool clippedStart;

  /// Whether words after [text] were left out.
  final bool clippedEnd;
}

/// One layer of a verse in a search result.
class LayerSnippet {
  const LayerSnippet(this.layer, this.snippet);

  final TextLayer layer;
  final Snippet snippet;

  /// Whether the search found something in this layer. A Targum match also
  /// shows the start of the verse, unmatched, as the reader shows the Targum
  /// under its verse.
  bool get matched => snippet.matches.isNotEmpty;
}

/// A verse that holds what was searched for.
class VerseHit {
  const VerseHit(this.bookIndex, this.ref, this.snippets);

  /// Its book's place in [kTorahBooks].
  final int bookIndex;
  final VerseRef ref;

  /// Its layers to show, in the order of [searchLayers].
  final List<LayerSnippet> snippets;

  String get book => kTorahBooks[bookIndex];
}

/// What one search found.
class SearchResults {
  const SearchResults({required this.query, required this.hits, required this.total});

  /// The search as it was typed.
  final String query;

  /// The first verses found, at most [kSearchLimit], in the Torah's order.
  final List<VerseHit> hits;

  /// How many verses hold it in all.
  final int total;

  bool get truncated => total > hits.length;
}

/// The verses of one book in one layer, as read aloud and folded for search.
typedef _BookLayer = ({List<int> chapterLengths, List<String> texts, List<String> keys});

/// Every verse of the Torah in Mikra, Targum Onkelos and the translation,
/// folded for search ([SearchText.fold]).
class VerseIndex {
  VerseIndex._(this._books, this._refs, this._texts, this._keys);

  /// Builds the index from the bundled texts, about 3.5 MB of them, calling
  /// [onProgress] with the share done, from 0 to 1, as each book's layer is
  /// read.
  static Future<VerseIndex> build(TextRepository repo, {void Function(double share)? onProgress}) async {
    final books = <int>[];
    final refs = <VerseRef>[];
    final texts = {for (final l in searchLayers) l: <String>[]};
    final keys = {for (final l in searchLayers) l: <String>[]};
    final steps = kTorahBooks.length * searchLayers.length;
    var done = 0;
    for (var b = 0; b < kTorahBooks.length; b++) {
      final layers = await Future.wait([
        for (final layer in searchLayers)
          repo.readBook(layer, kTorahBooks[b], _readLayer).then((part) {
            onProgress?.call(++done / steps);
            return part;
          }),
      ]);
      for (final (c, length) in layers.first.chapterLengths.indexed) {
        for (var v = 1; v <= length; v++) {
          books.add(b);
          refs.add(VerseRef(c + 1, v));
        }
      }
      for (final (i, layer) in searchLayers.indexed) {
        if (layers[i].texts.length != layers.first.texts.length) {
          throw StateError('${layer.folder} ${kTorahBooks[b]} has ${layers[i].texts.length} verses');
        }
        texts[layer]!.addAll(layers[i].texts);
        keys[layer]!.addAll(layers[i].keys);
      }
      // On the web the reading above runs on the UI thread: let a frame
      // through between books.
      await Future<void>.delayed(Duration.zero);
    }
    return VerseIndex._(books, refs, texts, keys);
  }

  static _BookLayer _readLayer(BookText book) {
    final texts = [
      for (final chapter in book.chapters)
        for (final verse in chapter) verse.readText,
    ];
    return (chapterLengths: book.chapterLengths, texts: texts, keys: [for (final t in texts) SearchText.fold(t)]);
  }

  final List<int> _books;
  final List<VerseRef> _refs;
  final Map<TextLayer, List<String>> _texts;
  final Map<TextLayer, List<String>> _keys;

  /// The number of verses indexed: the whole Torah.
  int get length => _refs.length;

  /// The verses that hold [query], in the Torah's order: at most [limit] of
  /// them, and how many there are in all. A Hebrew search reads the Mikra and
  /// the Targum, any other the translation. The Hebrew of a result has its
  /// vowels if [nikud], and never its cantillation.
  SearchResults search(String query, {int limit = kSearchLimit, bool nikud = true}) {
    if (!isSearchable(query)) return SearchResults(query: query, hits: const [], total: 0);
    final q = SearchText.fold(query);
    final hebrew = SearchText.hasHebrew(q);
    final layers = hebrew ? const [TextLayer.mikra, TextLayer.onkelos] : const [TextLayer.english];
    final hits = <VerseHit>[];
    var total = 0;
    for (var i = 0; i < _refs.length; i++) {
      final found = [
        for (final layer in layers)
          if (_find(_keys[layer]![i], q, wordStart: layer == TextLayer.english) >= 0) layer,
      ];
      if (found.isEmpty) continue;
      total++;
      if (hits.length >= limit) continue;
      hits.add(VerseHit(_books[i], _refs[i], [
        // A verse found only in its Targum still shows the verse first.
        if (hebrew && found.first != TextLayer.mikra) _snippet(TextLayer.mikra, i, null, nikud),
        for (final layer in found) _snippet(layer, i, q, nikud),
      ]));
    }
    return SearchResults(query: query, hits: hits, total: total);
  }

  LayerSnippet _snippet(TextLayer layer, int verse, String? query, bool nikud) {
    final text = _texts[layer]![verse];
    final english = layer == TextLayer.english;
    return LayerSnippet(
      layer,
      english
          ? Snippet.find(text, query, wordStart: true, lead: 6, span: 26)
          : Snippet.find(HebrewText.forDisplay(text, nikud: nikud, teamim: false), query, wordStart: false),
    );
  }
}

/// [hits] in runs by the parsha that holds them, in order. [parshiyot] are
/// the 54, as [ParshaRepository.all] lists them.
List<({PortionInfo parsha, List<VerseHit> hits})> groupByParsha(List<VerseHit> hits, List<PortionInfo> parshiyot) {
  final groups = <({PortionInfo parsha, List<VerseHit> hits})>[];
  for (final hit in hits) {
    final current = groups.lastOrNull;
    if (current != null && current.parsha.book == hit.book && current.parsha.range.contains(hit.ref)) {
      current.hits.add(hit);
      continue;
    }
    final parsha = parshiyot.firstWhere((p) => p.book == hit.book && p.range.contains(hit.ref));
    groups.add((parsha: parsha, hits: [hit]));
  }
  return groups;
}
