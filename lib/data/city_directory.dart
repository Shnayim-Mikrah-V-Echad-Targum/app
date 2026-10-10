import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:timezone/timezone.dart' as tz;

import '../core/calendar/city.dart';
import '../core/calendar/zmanim.dart';

/// The places a reader can choose for Shabbat times (assets/data/cities.json,
/// from GeoNames, CC BY 4.0): every place of 100,000 people or more and every
/// Israeli city, largest first, with their countries' and states' names.
class CityDirectory {
  CityDirectory._(this.cities, this._countries, this._regions, List<List<String>> aliases)
      : _keys = [for (final (i, c) in cities.indexed) _SearchKeys(c, aliases[i])];

  /// Reads the list. The text isn't kept in the bundle's cache: the parsed
  /// list is what's kept, by whoever holds it.
  ///
  /// Parsing and indexing some 6,000 places takes a few hundred milliseconds
  /// on a phone, so it runs on another isolate, off the UI's (on the web,
  /// which has no other, in place).
  static Future<CityDirectory> load([AssetBundle? bundle]) async {
    final json = await (bundle ?? rootBundle).loadString('assets/data/cities.json', cache: false);
    return compute(CityDirectory.parse, json, debugLabel: 'CityDirectory.parse');
  }

  factory CityDirectory.parse(String json) {
    final j = jsonDecode(json) as Map<String, dynamic>;
    Map<String, (String, String)> names(Object? raw) => {
          for (final MapEntry(:key, :value) in (raw as Map<String, dynamic>).entries)
            key: ((value as Map<String, dynamic>)['en'] as String, value['he'] as String),
        };
    final raw = (j['cities'] as List).cast<Map<String, dynamic>>();
    return CityDirectory._(
      [for (final c in raw) City.fromJson(c)],
      names(j['countries']),
      names(j['regions']),
      [for (final c in raw) (c['alt'] as List?)?.cast<String>() ?? const []],
    );
  }

  /// Largest first.
  final List<City> cities;
  final Map<String, (String, String)> _countries;
  final Map<String, (String, String)> _regions;
  final List<_SearchKeys> _keys;

  /// Where [city] is, to tell it from others of its name: "Ohio, United
  /// States", "France".
  String placeOf(City city, {required bool hebrew}) {
    String? pick((String, String)? names) => names == null ? null : (hebrew ? names.$2 : names.$1);
    return [pick(_regions[city.region]), pick(_countries[city.countryCode])].nonNulls.join(', ');
  }

  /// The places whose name, in either language, or another spelling of it,
  /// matches [query], best first: a whole name, then a name that begins with
  /// it, a word that does, and one that holds it, each by a place's own name
  /// before another spelling; the largest first within each. Accents,
  /// punctuation and spaces don't matter, nor do letters that are often
  /// spelled differently ("Petach Tikva", "קרית").
  List<City> search(String query, {int limit = 50}) {
    final q = foldForSearch(query);
    if (q.isEmpty) return const [];
    final found = <(int, int)>[];
    for (final (i, keys) in _keys.indexed) {
      final rank = keys.rank(q);
      if (rank != null) found.add((rank, i));
    }
    found.sort((a, b) => a.$1 != b.$1 ? a.$1 - b.$1 : a.$2 - b.$2);
    return [for (final (_, i) in found.take(limit)) cities[i]];
  }

  /// How many places [search] finds for [query], without its limit.
  int count(String query) {
    final q = foldForSearch(query);
    if (q.isEmpty) return 0;
    return _keys.where((keys) => keys.rank(q) != null).length;
  }

  /// Whether [query] is something to search for: one that folds to nothing,
  /// such as a lone ו or י, or punctuation, is treated as no query at all.
  static bool isQuery(String query) => foldForSearch(query).isNotEmpty;

  /// The largest places on the clock of [timeZone], the device's: the places
  /// in that zone, or for a zone the list doesn't use (an old name such as
  /// "US/Eastern"), those keeping the same time all year.
  List<City> inTimeZone(String timeZone, {int limit = 8}) {
    final same = cities.where((c) => c.timeZone == timeZone).take(limit).toList();
    if (same.isNotEmpty || _universal.hasMatch(timeZone)) return same;
    final clock = _yearOfOffsets(timeZone);
    if (clock == null) return same;
    final zones = <String, bool>{};
    return cities.where((c) => zones[c.timeZone] ??= _sameOffsets(_yearOfOffsets(c.timeZone), clock)).take(limit).toList();
  }

  /// UTC itself, which many devices report when no zone is set, keeps the
  /// time of West Africa and Iceland, places the reader is unlikely to be.
  static final _universal = RegExp(r'^(Etc/.*|UTC|GMT|Universal|Zulu|UCT)$');

  /// The UTC offsets of [timeZone] in January and July of this year.
  static (Duration, Duration)? _yearOfOffsets(String timeZone) {
    final location = Zmanim.timeZone(timeZone);
    if (location == null) return null;
    final year = DateTime.now().year;
    return (tz.TZDateTime(location, year, 1, 15).timeZoneOffset, tz.TZDateTime(location, year, 7, 15).timeZoneOffset);
  }

  static bool _sameOffsets((Duration, Duration)? a, (Duration, Duration) b) => a != null && a.$1 == b.$1 && a.$2 == b.$2;
}

/// A place's names folded for search ([foldForSearch]), whole and word by
/// word.
class _SearchKeys {
  _SearchKeys(City city, List<String> aliases)
      : names = [city.nameEn, ?city.nameHe].map(_Folded.new).toList(),
        aliases = aliases.map(_Folded.new).toList();

  final List<_Folded> names;
  final List<_Folded> aliases;

  /// How well [query] matches, best first, or null: as a whole name, then
  /// as another whole spelling, a name's beginning, another spelling's, and
  /// so on ([_Folded.rank]).
  int? rank(String query) {
    final ranks = [
      for (final k in names)
        if (k.rank(query) case final r?) 2 * r,
      for (final k in aliases)
        if (k.rank(query) case final r?) 2 * r + 1,
    ];
    return ranks.isEmpty ? null : ranks.reduce(math.min);
  }
}

class _Folded {
  _Folded(String name)
      : whole = foldForSearch(name),
        words = name.split(_wordBreak).map(foldForSearch).where((w) => w.isNotEmpty).toList();

  static final _wordBreak = RegExp(r'[\s\-־/()]+');

  final String whole;
  final List<String> words;

  /// 0 if [query] is the whole name, 1 if the name begins with it, 2 if a
  /// word does, 3 if the name holds it; null otherwise.
  int? rank(String query) {
    if (whole == query) return 0;
    if (whole.startsWith(query)) return 1;
    if (words.any((w) => w.startsWith(query))) return 2;
    if (whole.contains(query)) return 3;
    return null;
  }
}

/// [text] as search compares it: lower case, without accents, nikud,
/// punctuation or spaces, and with the letters that transliterations and
/// Hebrew spellings vary on made alike: "ch" and "kh" as "h", "q" and "c" as
/// "k", "y" and "j" as "i", "w" as "v", "tz" and "ts" as "z", doubled letters
/// once; in Hebrew, without ו and י, or an א after the first letter (פאריז and
/// פריז, שאנגחאי and שנגחאי), and with final letters as other letters.
String foldForSearch(String text) {
  final out = StringBuffer();
  for (final rune in text.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    if (rune >= 0x05D0 && rune <= 0x05EA) {
      if (char != 'ו' && char != 'י' && (char != 'א' || out.isEmpty)) out.write(_hebrewFinals[char] ?? char);
    } else if (_plain.hasMatch(char)) {
      out.write(char);
    } else if (_accents[char] case final plain?) {
      out.write(plain);
    }
  }
  return out
      .toString()
      .replaceAll(_h, 'h')
      .replaceAll(_k, 'k')
      .replaceAll(_i, 'i')
      .replaceAll('w', 'v')
      .replaceAll(_z, 'z')
      .replaceAllMapped(_doubled, (m) => m[1]!);
}

final _plain = RegExp('[a-z0-9]');
final _h = RegExp('ch|kh');
final _k = RegExp('[qc]');
final _i = RegExp('[jy]');
final _z = RegExp('tz|ts');
final _doubled = RegExp(r'(.)\1+');

const _hebrewFinals = {'ך': 'כ', 'ם': 'מ', 'ן': 'נ', 'ף': 'פ', 'ץ': 'צ'};

/// Latin letters with accents, and ligatures, as plain letters.
final Map<String, String> _accents = () {
  const groups = {
    'a': 'àáâãäåāăąǎȁȃạảấầẩẫậắằẳẵặ',
    'ae': 'æǣ',
    'c': 'çćĉċč',
    'd': 'ďđḍḏḑ',
    'e': 'èéêëēĕėęěȅȇẹẻẽếềểễệə',
    'g': 'ĝğġģǧ',
    'h': 'ĥħḥḩḫẖ',
    'i': 'ìíîïĩīĭįıǐȉȋịỉ',
    'j': 'ĵ',
    'k': 'ķǩḳ',
    'l': 'ĺļľŀłḷ',
    'n': 'ñńņňŉṅṇ',
    'o': 'òóôõöøōŏőơǒȍȏọỏốồổỗộớờởỡợ',
    'oe': 'œ',
    'r': 'ŕŗřṛ',
    's': 'śŝşšșṣ',
    'ss': 'ß',
    't': 'ţťŧțṭ',
    'u': 'ùúûüũūŭůűųưǔȕȗụủứừửữự',
    'w': 'ŵ',
    'y': 'ýÿŷỳỵỷỹ',
    'z': 'źżžẓẕ',
  };
  return {
    for (final MapEntry(key: plain, value: accented) in groups.entries)
      for (final char in accented.split('')) char: plain,
  };
}();
