import 'dart:convert';

import 'package:flutter/services.dart';

import '../core/calendar/local_date.dart';
import '../core/calendar/parsha_schedule.dart';
import '../core/calendar/special_haftarah.dart';
import 'models/parsha.dart';
import 'models/verse_ref.dart';

/// The haftarah to read for a given week, with the reason when it is a
/// special one (e.g. "Shabbat Shekalim").
class WeekHaftarah {
  const WeekHaftarah(this.parts, {this.specialKey});
  final Haftarah parts;
  final String? specialKey;
}

/// Parsha metadata: names, aliyot and haftarot (assets/data/parshiyot.json).
class ParshaRepository {
  ParshaRepository._(this._singles, this._combined, this._special, this._chapterLengths);

  static Future<ParshaRepository> load([AssetBundle? bundle]) async {
    final raw = await (bundle ?? rootBundle).loadString('assets/data/parshiyot.json');
    return ParshaRepository.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  factory ParshaRepository.fromJson(Map<String, dynamic> j) {
    final singles = <PortionInfo>[
      for (final p in (j['parshiyot'] as List).cast<Map<String, dynamic>>())
        PortionInfo.fromJson(p, PortionId(p['num'] as int)),
    ];
    final combined = <int, PortionInfo>{
      for (final p in (j['combined'] as List).cast<Map<String, dynamic>>())
        ((p['parts'] as List).first as int): PortionInfo.fromJson(
          p,
          PortionId((p['parts'] as List).first as int, combined: true),
        ),
    };
    final special = <String, HaftarahOptions>{
      for (final e in (j['specialHaftarot'] as Map<String, dynamic>).entries)
        e.key: HaftarahOptions.fromJson(e.value as Map<String, dynamic>),
    };
    final lengths = <String, List<int>>{
      for (final e in (j['chapterLengths'] as Map<String, dynamic>).entries)
        e.key: (e.value as List).cast<int>(),
    };
    return ParshaRepository._(singles, combined, special, lengths);
  }

  final List<PortionInfo> _singles;
  final Map<int, PortionInfo> _combined;
  final Map<String, HaftarahOptions> _special;
  final Map<String, List<int>> _chapterLengths;

  /// Verses per chapter of a book of the Torah.
  List<int> chapterLengths(String book) => _chapterLengths[book]!;

  /// The verses of one aliyah (0-based) of [portion].
  List<VerseRef> aliyahVerses(PortionInfo portion, int aliyah) =>
      portion.aliyot[aliyah].verses(chapterLengths(portion.book));

  int aliyahVerseCount(PortionInfo portion, int aliyah) => aliyahVerses(portion, aliyah).length;

  int verseCount(PortionInfo portion) => portion.range.verses(chapterLengths(portion.book)).length;

  /// All 54 parshiyot in order.
  List<PortionInfo> get all => List.unmodifiable(_singles);

  /// The weeks that read two parshiyot together, by their first.
  List<PortionInfo> get combined => List.unmodifiable(_combined.values);

  PortionInfo portion(PortionId id) {
    if (id.combined) {
      final c = _combined[id.number];
      if (c == null) throw ArgumentError('${id.key} is not a combined portion');
      return c;
    }
    return _singles[id.number - 1];
  }

  PortionInfo byNumber(int number) => _singles[number - 1];

  /// The haftarah read on [occasion] for [portion], accounting for special
  /// Shabbatot. Vezot HaBerakhah's haftarah is that of Simchat Torah.
  WeekHaftarah haftarahFor(PortionId portion, LocalDate occasion, HaftarahNusach nusach) {
    if (occasion.isShabbat) {
      final key = specialHaftarahKey(occasion, portion);
      final special = key == null ? null : _special[key];
      if (special != null) return WeekHaftarah(special.forNusach(nusach), specialKey: key);
    }
    return WeekHaftarah(this.portion(portion).haftarah.forNusach(nusach));
  }
}
