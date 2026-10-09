import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/core/calendar/parsha_schedule.dart';
import 'package:shnayim_mikra/data/models/parsha.dart';
import 'package:shnayim_mikra/data/models/scripture.dart';
import 'package:shnayim_mikra/data/parsha_repository.dart';
import 'package:shnayim_mikra/data/text_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late ParshaRepository repo;
  final texts = TextRepository();

  setUpAll(() async => repo = await ParshaRepository.load());

  test('54 parshiyot with 7 contiguous aliyot covering the whole Torah', () {
    expect(repo.all, hasLength(54));
    var total = 0;
    for (final p in repo.all) {
      expect(p.aliyot, hasLength(7), reason: p.key);
      total += repo.verseCount(p);
    }
    expect(total, 5846, reason: 'verses in the Torah');
  });

  test('all seven combined portions exist and match their parts', () {
    for (final n in [22, 27, 29, 32, 39, 42, 51]) {
      final c = repo.portion(PortionId(n, combined: true));
      expect(c.range.start, repo.byNumber(n).range.start);
      expect(c.range.end, repo.byNumber(n + 1).range.end);
    }
  });

  test('every layer of every book has the same verse structure', () async {
    for (final book in kTorahBooks) {
      final mikra = await texts.book(TextLayer.mikra, book);
      final onkelos = await texts.book(TextLayer.onkelos, book);
      final english = await texts.book(TextLayer.english, book);
      final rashi = await texts.commentary(CommentaryLayer.rashi, book);
      expect(mikra.chapterLengths, repo.chapterLengths(book), reason: book);
      expect(onkelos.chapterLengths, mikra.chapterLengths, reason: book);
      expect(english.chapterLengths, mikra.chapterLengths, reason: book);
      expect(rashi.chapters.map((c) => c.length).toList(), mikra.chapterLengths, reason: book);
      for (final ch in mikra.chapters) {
        for (final v in ch) {
          expect(v.readText, isNotEmpty, reason: '$book ${v.ref}');
          expect(v.readText, isNot(contains('<')), reason: '$book ${v.ref}');
        }
      }
    }
  });

  test('ketiv/qere is read as the qere', () async {
    final genesis = await texts.book(TextLayer.mikra, 'Genesis');
    final v = genesis.chapters[13][1]; // Genesis 14:2
    expect(v.segments.whereType<KetivQere>().single.ketiv, 'צביים');
    expect(v.readText, contains('צְבוֹיִ֔ם'));
    expect(v.readText, isNot(contains('צביים')));
  });

  test('every regular and special haftarah resolves to text, for every custom', () async {
    var checked = 0;
    final ids = [
      for (final p in repo.all) p.id,
      for (final n in [22, 27, 29, 32, 39, 42, 51]) PortionId(n, combined: true),
    ];
    for (final id in ids) {
      for (final n in HaftarahNusach.values) {
        final verses = await texts.haftarah(repo.portion(id).haftarah.forNusach(n));
        expect(verses, isNotEmpty, reason: '${id.key} $n');
        checked++;
      }
    }
    // Special haftarot over a full cycle of weeks.
    const schedule = ParshaSchedule(israel: false);
    var week = schedule.weekFor(LocalDate(2026, 10, 5));
    for (var i = 0; i < 60; i++) {
      for (final n in HaftarahNusach.values) {
        final h = repo.haftarahFor(week.portion, week.occasion, n);
        expect(await texts.haftarah(h.parts), isNotEmpty, reason: '${week.portion.key} ${h.specialKey}');
      }
      week = schedule.nextWeek(week);
    }
    expect(checked, greaterThan(180));
  });
}
