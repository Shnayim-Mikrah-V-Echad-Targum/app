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
    });

    test('has the Sephardi regular haftarah for Sephardim', () {
      final h = repo.haftarahFor(bereshit, shabbat, HaftarahNusach.sephardi);
      expect(refs(h.regular), 'Isaiah 42:5-42:21');
      expect(h.fallback, isFalse, reason: 'a Sephardi reading not listed is the same as the Ashkenazi');
    });

    test('has the Ashkenazi readings for Chabad, and says so', () {
      final h = repo.haftarahFor(bereshit, shabbat, HaftarahNusach.chabad);
      expect(refs(h.parts), 'I Samuel 20:18-20:42');
      expect(refs(h.regular), 'Isaiah 42:5-43:10');
      expect(h.fallback, isTrue);
    });
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

    test("has the Rosh Chodesh haftarah for Ashkenazim, Re'eh's apart, and then both with Ki Teitzei", () {
      final h = repo.haftarahFor(const PortionId(47), reeh, HaftarahNusach.ashkenazi);
      expect(h.specialKey, 'Shabbat Rosh Chodesh');
      expect(refs(h.parts), 'Isaiah 66:1-66:24');
      expect(refs(h.regular), 'Isaiah 54:11-55:5');
      final next = repo.haftarahFor(const PortionId(49), kiTeitzei, HaftarahNusach.ashkenazi);
      expect(refs(next.parts), 'Isaiah 54:1-54:10, Isaiah 54:11-55:5');
      expect(next.regular, isNull, reason: "Ki Teitzei's own haftarah is its first part");
    });

    for (final n in [HaftarahNusach.sephardi, HaftarahNusach.chabad]) {
      test("has Re'eh's own for the ${n.name} custom, with the first and last verses of Rosh Chodesh's", () {
        final h = repo.haftarahFor(const PortionId(47), reeh, n);
        expect(h.specialKey, "Re'eh on Shabbat Rosh Chodesh");
        expect(refs(h.parts), 'Isaiah 54:11-55:5, Isaiah 66:1-66:1, Isaiah 66:23-66:23');
        expect(h.regular, isNull);
        expect(h.fallback, isFalse, reason: "it is the custom's own reading");
        final next = repo.haftarahFor(const PortionId(49), kiTeitzei, n);
        expect(next.specialKey, isNull);
        expect(refs(next.parts), 'Isaiah 54:1-54:10');
      });
    }
  });

  test('HaftarahOptions says when Chabad falls back to the Ashkenazi reading', () {
    final bereshit = repo.portion(const PortionId(1)).haftarah;
    expect(bereshit.fallsBack(HaftarahNusach.chabad), isTrue);
    expect(bereshit.fallsBack(HaftarahNusach.sephardi), isFalse);
    expect(bereshit.fallsBack(HaftarahNusach.ashkenazi), isFalse);
    expect(repo.portion(const PortionId(25)).haftarah.fallsBack(HaftarahNusach.chabad), isFalse, reason: 'Tzav');
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
