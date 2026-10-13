import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/core/calendar/parsha_schedule.dart';
import 'package:shnayim_mikra/data/models/parsha.dart';
import 'package:shnayim_mikra/data/parsha_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ParshaRepository repo;

  setUpAll(() async => repo = await ParshaRepository.load());

  String? refs(Haftarah? h) => h?.join(', ');

  group('Bereshit 5787, read on Shabbat Machar Chodesh,', () {
    final shabbat = LocalDate(2026, 10, 10);
    const bereshit = PortionId(1);

    test("has Machar Chodesh's haftarah, and Bereshit's own as the regular one", () {
      final h = repo.haftarahFor(bereshit, shabbat, HaftarahNusach.ashkenazi);
      expect(h.specialKey, 'Shabbat Machar Chodesh');
      expect(refs(h.parts), 'I Samuel 20:18-20:42');
      expect(refs(h.regular), 'Isaiah 42:5-43:10');
      expect(h.fallback, isFalse);
      expect(h.regularFallback, isFalse);
    });

    test('has the Sephardi regular haftarah for Sephardim', () {
      final h = repo.haftarahFor(bereshit, shabbat, HaftarahNusach.sephardi);
      expect(refs(h.regular), 'Isaiah 42:5-42:21');
      expect(h.fallback, isFalse, reason: 'a Sephardi reading not listed is the same as the Ashkenazi');
      expect(h.regularFallback, isFalse);
    });

    test('has the Ashkenazi readings for Chabad, and says so only of the regular one', () {
      final h = repo.haftarahFor(bereshit, shabbat, HaftarahNusach.chabad);
      expect(refs(h.parts), 'I Samuel 20:18-20:42');
      expect(refs(h.regular), 'Isaiah 42:5-43:10');
      expect(h.fallback, isFalse, reason: "every custom reads Machar Chodesh's the same");
      expect(h.regularFallback, isTrue, reason: "the Ashkenazi and Sephardi readings of Bereshit's differ");
    });
  });

  test("a week whose haftarah every custom reads the same doesn't say Chabad's is the Ashkenazi one", () {
    // Lech Lecha 5787: Isaiah 40:27–41:16.
    final h = repo.haftarahFor(const PortionId(3), LocalDate(2026, 10, 24), HaftarahNusach.chabad);
    expect(h.specialKey, isNull);
    expect(refs(h.parts), 'Isaiah 40:27-41:16');
    expect(h.fallback, isFalse);
    expect(h.regularFallback, isFalse);
  });

  test("keeps hebcal's Chabad readings of special haftarot", () {
    // Shabbat HaChodesh and Zachor 5786, from the weeks of the year.
    const schedule = ParshaSchedule(israel: false);
    final found = <String, WeekHaftarah>{};
    var week = schedule.weekFor(LocalDate(2026, 1, 1));
    for (var i = 0; i < 20 && found.length < 2; i++, week = schedule.nextWeek(week)) {
      final h = repo.haftarahFor(week.portion, week.occasion, HaftarahNusach.chabad);
      if (h.specialKey case final key? when key == 'Shabbat HaChodesh' || key == 'Shabbat Zachor') found[key] = h;
    }
    expect(refs(found['Shabbat HaChodesh']!.parts), 'Ezekiel 45:18-46:16');
    expect(refs(found['Shabbat Zachor']!.parts), 'I Samuel 15:2-15:34');
    for (final h in found.values) {
      expect(h.fallback, isFalse, reason: "it is Chabad's own");
    }
  });

  test('Shabbat Rosh Chodesh on the 30th adds the first and last verses of Machar Chodesh, for every custom', () {
    // Korach 5788, on 30 Sivan, the first day of Rosh Chodesh Tammuz.
    for (final n in HaftarahNusach.values) {
      final h = repo.haftarahFor(const PortionId(38), LocalDate(2028, 6, 24), n);
      expect(h.specialKey, 'Shabbat Rosh Chodesh (and Sunday)', reason: n.name);
      expect(refs(h.parts), 'Isaiah 66:1-66:24, I Samuel 20:18-20:18, I Samuel 20:42-20:42', reason: n.name);
      expect(h.fallback, isFalse, reason: n.name);
    }
  });

  test('a week without a special haftarah has no regular one apart', () {
    final noach = repo.haftarahFor(const PortionId(2), LocalDate(2026, 10, 17), HaftarahNusach.ashkenazi);
    expect(noach.specialKey, isNull);
    expect(noach.regular, isNull);
    expect(refs(noach.parts), 'Isaiah 54:1-55:5');
  });

  test("a special haftarah that includes the portion's own has no regular one apart", () {
    // Matot-Masei 5781 on Rosh Chodesh Av: Masei's haftarah, with a verse for
    // Rosh Chodesh (and for Sephardim, two more).
    for (final n in HaftarahNusach.values) {
      final masei = repo.haftarahFor(const PortionId(42, combined: true), LocalDate(2021, 7, 10), n);
      expect(masei.specialKey, 'Matot-Masei on Shabbat Rosh Chodesh', reason: n.name);
      expect(masei.regular, isNull, reason: n.name);
    }
  });

  group("Re'eh 5782, on Rosh Chodesh Elul,", () {
    final reeh = LocalDate(2022, 8, 27);
    final kiTeitzei = LocalDate(2022, 9, 10);

    test("has the Rosh Chodesh haftarah for Ashkenazim, and Re'eh's with Ki Tetze's, not apart this week", () {
      final h = repo.haftarahFor(const PortionId(47), reeh, HaftarahNusach.ashkenazi);
      // 30 Av, with Sunday Rosh Chodesh too: Machar Chodesh's first and last
      // verses are added.
      expect(h.specialKey, 'Shabbat Rosh Chodesh (and Sunday)');
      expect(refs(h.parts), 'Isaiah 66:1-66:24, I Samuel 20:18-20:18, I Samuel 20:42-20:42');
      // Read two weeks later, so not offered as one some read too now.
      expect(h.regular, isNull);
      expect(h.regularFallback, isFalse);
      final next = repo.haftarahFor(const PortionId(49), kiTeitzei, HaftarahNusach.ashkenazi);
      expect(refs(next.parts), 'Isaiah 54:1-54:10, Isaiah 54:11-55:5');
      expect(next.regular, isNull, reason: "Ki Tetze's own haftarah is its first part");
    });

    test("has Re'eh's own for Sephardim, with the first and last verses of Rosh Chodesh's and Machar Chodesh's", () {
      final h = repo.haftarahFor(const PortionId(47), reeh, HaftarahNusach.sephardi);
      expect(h.specialKey, "Re'eh on Shabbat Rosh Chodesh (and Sunday)");
      expect(
        refs(h.parts),
        'Isaiah 54:11-55:5, Isaiah 66:1-66:1, Isaiah 66:23-66:23, I Samuel 20:18-20:18, I Samuel 20:42-20:42',
      );
      expect(h.regular, isNull);
      expect(h.fallback, isFalse, reason: "it is the custom's own reading");
      final next = repo.haftarahFor(const PortionId(49), kiTeitzei, HaftarahNusach.sephardi);
      expect(next.specialKey, isNull);
      expect(refs(next.parts), 'Isaiah 54:1-54:10');
    });

    test("has the Rosh Chodesh haftarah for Chabad, as Ashkenazim, and Re'eh's with Ki Tetze's", () {
      // Re'eh 5789, on 30 Av too.
      for (final shabbat in [reeh, LocalDate(2029, 8, 11)]) {
        final h = repo.haftarahFor(const PortionId(47), shabbat, HaftarahNusach.chabad);
        expect(h.specialKey, 'Shabbat Rosh Chodesh (and Sunday)', reason: '$shabbat');
        expect(refs(h.parts), 'Isaiah 66:1-66:24, I Samuel 20:18-20:18, I Samuel 20:42-20:42', reason: '$shabbat');
        expect(h.regular, isNull, reason: "$shabbat: Chabad reads Re'eh's with Ki Tetze's, not twice");
      }
      final next = repo.haftarahFor(const PortionId(49), kiTeitzei, HaftarahNusach.chabad);
      expect(next.specialKey, 'Ki Teitzei with 3rd Haftarah of Consolation');
      expect(refs(next.parts), 'Isaiah 54:1-54:10, Isaiah 54:11-55:5');
    });
  });

  group('Acharei Mot 5782, on Shabbat Machar Chodesh,', () {
    final acharei = LocalDate(2022, 4, 30);

    test("has no regular haftarah apart for Ashkenazim or Chabad, who read Acharei Mot's for Kedoshim", () {
      for (final n in [HaftarahNusach.ashkenazi, HaftarahNusach.chabad]) {
        final h = repo.haftarahFor(const PortionId(29), acharei, n);
        expect(h.specialKey, 'Shabbat Machar Chodesh', reason: n.name);
        expect(h.regular, isNull, reason: n.name);
        expect(h.regularFallback, isFalse, reason: n.name);
      }
    });

    test('offers Sephardim its own as one some read too, as Kedoshim reads its own', () {
      final h = repo.haftarahFor(const PortionId(29), acharei, HaftarahNusach.sephardi);
      expect(h.specialKey, 'Shabbat Machar Chodesh');
      expect(refs(h.regular), 'Ezekiel 22:1-22:16');
    });
  });

  group('Kedoshim 5782, after Acharei Mot gave way to Shabbat Machar Chodesh,', () {
    final kedoshim = LocalDate(2022, 5, 7);

    test("has Acharei Mot's haftarah for Ashkenazim, and for Chabad, saying it is the Ashkenazi reading", () {
      for (final n in [HaftarahNusach.ashkenazi, HaftarahNusach.chabad]) {
        final h = repo.haftarahFor(const PortionId(30), kedoshim, n);
        expect(h.specialKey, 'Kedoshim following Special Shabbat', reason: n.name);
        expect(refs(h.parts), 'Amos 9:7-9:15', reason: n.name);
        expect(refs(h.regular), 'Ezekiel 22:1-22:19', reason: n.name);
        expect(h.fallback, n == HaftarahNusach.chabad, reason: n.name);
        expect(h.regularFallback, n == HaftarahNusach.chabad, reason: n.name);
      }
    });

    test("has Kedoshim's own for Sephardim", () {
      final h = repo.haftarahFor(const PortionId(30), kedoshim, HaftarahNusach.sephardi);
      expect(h.specialKey, isNull);
      expect(refs(h.parts), 'Ezekiel 20:2-20:20');
      expect(h.regular, isNull);
    });
  });

  test('HaftarahOptions says when Chabad falls back to the Ashkenazi reading', () {
    final bereshit = repo.portion(const PortionId(1)).haftarah;
    expect(bereshit.fallsBack(HaftarahNusach.chabad), isTrue);
    expect(bereshit.fallsBack(HaftarahNusach.sephardi), isFalse);
    expect(bereshit.fallsBack(HaftarahNusach.ashkenazi), isFalse);
    expect(repo.portion(const PortionId(25)).haftarah.fallsBack(HaftarahNusach.chabad), isFalse, reason: 'Tzav');
    // Where the Ashkenazi and Sephardi readings agree, Chabad's is taken to
    // agree too.
    final lechLecha = repo.portion(const PortionId(3)).haftarah;
    expect(lechLecha.sephardi, isNull);
    expect(lechLecha.chabad, isNull);
    expect(lechLecha.fallsBack(HaftarahNusach.chabad), isFalse);
  });

  group('the second parsha of two read together', () {
    test('is the one after the first, and begins within an aliyah, where the first ends', () {
      expect(repo.combined, hasLength(7));
      for (final pair in repo.combined) {
        final second = repo.secondParsha(pair)!;
        final first = repo.byNumber(pair.id.number);
        expect(second.id, PortionId(pair.id.number + 1), reason: pair.key);
        final start = second.aliyot.first.start;
        expect(pair.range.contains(start), isTrue, reason: pair.key);
        expect(first.range.end < start && second.range.end == pair.range.end, isTrue, reason: pair.key);
        // No aliyah of the week begins where the second does: the seam
        // falls within one, which is why the week's page says where.
        expect(pair.aliyot.where((a) => a.contains(start)), hasLength(1), reason: pair.key);
        expect(pair.aliyot.any((a) => a.start == start), isFalse, reason: pair.key);
      }
    });

    test('of Vayakhel-Pekudei is Pekudei, from 38:21, within Revi’i', () {
      final pair = repo.portion(const PortionId(22, combined: true));
      final pekudei = repo.secondParsha(pair)!;
      expect(pekudei.key, 'Pekudei');
      expect(pekudei.aliyot.first.start.toString(), '38:21');
      expect(pair.aliyot.indexWhere((a) => a.contains(pekudei.aliyot.first.start)), 3);
    });

    test('is none for a portion of one parsha', () {
      expect(repo.secondParsha(repo.byNumber(22)), isNull);
    });
  });

  group('parsha names', () {
    const combined = [22, 27, 29, 32, 39, 42, 51];

    test('are spelt in one style, in either pronunciation', () {
      for (final p in repo.all) {
        for (final name in [p.displayName(ashkenazi: false), p.displayName(ashkenazi: true)]) {
          expect(name, isNot(contains('-')), reason: '$name: words apart, not hyphenated');
          // The k and h of Vayakhel are two letters, ק and ה.
          expect(name.replaceFirst('Vayakhel', ''), isNot(contains('kh')), reason: '$name: "ch" for both ח and כ');
          expect(name, isNot(contains(RegExp(r"[^aeiou]'|'[^aeiou]"))), reason: '$name: an apostrophe only between vowels');
          expect(name, isNot(contains(RegExp(r'([a-z])\1'))), reason: '$name: no doubled letters');
        }
      }
      expect([for (final n in [3, 5, 26, 29, 35, 37, 54]) repo.byNumber(n).displayName(ashkenazi: false)],
          ['Lech Lecha', 'Chayei Sarah', 'Shemini', 'Acharei Mot', 'Naso', 'Shelach', 'Vezot HaBerachah']);
      expect(repo.byNumber(54).displayName(ashkenazi: true), 'Vezos HaBerachah');
    });

    test('write tsere as each pronunciation says it', () {
      // Sephardi: "e", and "ei" only where a yod is written after it, at the
      // end of a word (Chayei, Pekudei, Acharei, Masei).
      for (final p in repo.all) {
        final name = p.displayName(ashkenazi: false);
        expect(name, isNot(contains(RegExp(r'ei\B'))), reason: '$name: tsere is "e"');
      }
      const tsere = [1, 4, 7, 9, 10, 14, 46, 49, 52];
      expect([for (final n in tsere) repo.byNumber(n).displayName(ashkenazi: false)],
          ['Bereshit', 'Vayera', 'Vayetze', 'Vayeshev', 'Miketz', 'Va’era', 'Ekev', 'Ki Tetze', 'Vayelech']);
      // Ashkenazi: "ei".
      expect([for (final n in tsere) repo.byNumber(n).displayName(ashkenazi: true)],
          ['Bereishis', 'Vayeira', 'Vayeitzei', 'Vayeishev', 'Mikeitz', 'Va’eira', 'Eikev', 'Ki Seitzei', 'Vayeilech']);
      expect([for (final n in [5, 23, 29, 43]) repo.byNumber(n).displayName(ashkenazi: false)],
          ['Chayei Sarah', 'Pekudei', 'Acharei Mot', 'Masei']);
    });

    test('of a combined portion join its parts with a hyphen', () {
      for (final n in combined) {
        final pair = repo.portion(PortionId(n, combined: true));
        for (final ashkenazi in [false, true]) {
          final parts = [for (final part in [n, n + 1]) repo.byNumber(part).displayName(ashkenazi: ashkenazi)];
          expect(pair.displayName(ashkenazi: ashkenazi), parts.join('-'));
        }
      }
      expect(repo.portion(const PortionId(29, combined: true)).displayName(ashkenazi: false), 'Acharei Mot-Kedoshim');
    });

    test('leave the data keys as they were', () {
      // Progress, backups and the forum are keyed by these.
      expect([for (final n in [3, 37, 54]) repo.byNumber(n).key], ['Lech-Lecha', "Sh'lach", 'Vezot Haberakhah']);
      expect(repo.portion(const PortionId(29, combined: true)).key, 'Achrei Mot-Kedoshim');
    });
  });
}
