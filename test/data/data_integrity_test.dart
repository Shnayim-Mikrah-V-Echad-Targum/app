import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/core/calendar/parsha_schedule.dart';
import 'package:shnayim_mikra/core/text/hebrew_text.dart';
import 'package:shnayim_mikra/data/models/parsha.dart';
import 'package:shnayim_mikra/data/models/scripture.dart';
import 'package:shnayim_mikra/data/models/verse_ref.dart';
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

  group('the Torah follows Ashkenazi and Sephardi scrolls', () {
    late Map<String, BookText> torah;
    setUpAll(() async => torah = {for (final b in kTorahBooks) b: await texts.book(TextLayer.mikra, b)});

    Verse verse(String book, int c, int v) => torah[book]!.verse(VerseRef(c, v));
    List<String> notes(Verse v) => [for (final n in v.segments.whereType<TextNote>()) n.text];
    String consonants(String s) => HebrewText.consonantsOnly(s);

    test('in the words they spell differently, noting the Aleppo Codex', () {
      // Read aloud: "vayehi", not the Codex's "vayihyu".
      final gen929 = verse('Genesis', 9, 29);
      expect(gen929.readText, startsWith('וַֽיְהִי'));
      expect(consonants(gen929.readText), startsWith('ויהי כל־ימי־נח'));
      expect(notes(gen929).map(consonants), ['בכתר ארם צובה ובספרי תימן: ויהיו']);

      // The last word before the note, after a maqaf: דַּכָּ֛ה, its marks
      // in the text's order.
      final deut232 = verse('Deuteronomy', 23, 2);
      expect(deut232.readText, contains('דַּכָּ֛ה'));
      expect(consonants(deut232.readText), startsWith('לא־יבא פצוע־דכה וכרות'));
      // Only most Ashkenazi scrolls have it; the rest share the Codex's.
      expect(notes(deut232).map(consonants), ['בכתר ארם צובה, בספרי תימן ובמקצת ספרי אשכנז: דכא']);
    });

    test('with the small yod of Pinchas, and a word on the broken vav of shalom', () {
      final pinchas = verse('Numbers', 25, 11);
      final small = pinchas.segments.whereType<SizedLetters>().single;
      expect((small.text, small.size), ('י', LetterSize.small));
      expect(consonants(pinchas.readText), startsWith('פינחס בן־אלעזר'));
      expect(notes(pinchas), isEmpty);
      expect(notes(verse('Numbers', 25, 12)), ['בספר תורה נכתבת וי״ו קטיעא במילה שלום']);
    });

    test('in their section breaks', () {
      expect(torah['Leviticus']!.breaks.keys, isNot(contains(const VerseRef(7, 21))));
      expect(notes(verse('Leviticus', 7, 21)), ['בכתר ארם צובה: פרשה פתוחה']);
      expect(torah['Deuteronomy']!.breaks[const VerseRef(27, 19)], SectionBreak.closed);
    });

    test('everywhere they differ, rather than only noting it', () {
      for (final book in torah.values) {
        for (final ch in book.chapters) {
          for (final v in ch) {
            for (final note in notes(v)) {
              expect(note, isNot(startsWith('בספרי ספרד')), reason: '${book.book} ${v.ref}');
            }
          }
        }
      }
    });
  });

  group('section breaks inside a verse', () {
    // Every verse of Mikra and of the haftarot, keyed "Book c:v".
    Future<Map<String, Verse>> allHebrewVerses() async {
      final out = <String, Verse>{};
      for (final book in kTorahBooks) {
        final mikra = await texts.book(TextLayer.mikra, book);
        for (final ch in mikra.chapters) {
          for (final v in ch) {
            out['$book ${v.ref}'] = v;
          }
        }
      }
      final haftarot = jsonDecode(await rootBundle.loadString('assets/text/haftarot.json')) as Map<String, dynamic>;
      (haftarot['he'] as Map<String, dynamic>).forEach((book, verses) {
        (verses as Map<String, dynamic>).forEach((ref, json) {
          out['$book $ref'] = Verse.fromJson(VerseRef.parse(ref), json as Object);
        });
      });
      return out;
    }

    late Map<String, Verse> verses;
    setUpAll(() async => verses = await allHebrewVerses());

    test('no word runs into the next after a sof pasuq', () {
      final fused = RegExp(r'׃\S');
      for (final MapEntry(:key, value: v) in verses.entries) {
        for (final seg in v.segments.whereType<PlainText>()) {
          expect(fused.hasMatch(seg.text), isFalse, reason: '$key: ${seg.text}');
        }
      }
    });

    test('no word continues after a final letter', () {
      // A final form (ך ם ן ף ץ), then any vowels or cantillation, then
      // another letter: two words fused into one.
      final fused = RegExp('[ךםןףץ][\u0591-\u05BD\u05BF\u05C1\u05C2\u05C4\u05C5\u05C7\u034F]*[א-ת]');
      final separators = RegExp(r'[\s־]+');
      for (final MapEntry(:key, value: v) in verses.entries) {
        for (final seg in v.segments.whereType<PlainText>()) {
          for (final token in seg.text.split(separators)) {
            expect(fused.hasMatch(token), isFalse, reason: '$key: $token');
          }
        }
      }
    });

    test('are kept as gaps, and the words around them stay apart', () {
      const withGaps = [
        // Torah
        'Genesis 35:22', 'Exodus 20:13', 'Exodus 20:14', 'Numbers 26:1', 'Deuteronomy 2:8',
        'Deuteronomy 5:17', 'Deuteronomy 5:18',
        // Haftarot
        'I Samuel 20:27', 'II Samuel 6:20', 'II Samuel 7:4', 'II Samuel 7:5', 'I Kings 1:19', 'Ezekiel 43:27',
      ];
      for (final key in withGaps) {
        expect(verses[key], isNotNull, reason: key);
        expect(verses[key]!.segments.whereType<PisqaGap>(), isNotEmpty, reason: key);
      }
      final decalogue = verses['Exodus 20:13']!;
      expect([for (final g in decalogue.segments.whereType<PisqaGap>()) g.kind], List.filled(3, SectionBreak.closed));
      expect(HebrewText.consonantsOnly(decalogue.readText), 'לא תרצח׃ לא תנאף׃ לא תגנב׃ לא־תענה ברעך עד שקר׃');
    });

    test('do not end the verse as a section break', () async {
      final genesis = await texts.book(TextLayer.mikra, 'Genesis');
      final exodus = await texts.book(TextLayer.mikra, 'Exodus');
      final numbers = await texts.book(TextLayer.mikra, 'Numbers');
      final deuteronomy = await texts.book(TextLayer.mikra, 'Deuteronomy');
      expect(genesis.breaks[const VerseRef(35, 22)], isNull);
      expect(numbers.breaks[const VerseRef(26, 1)], isNull);
      expect(deuteronomy.breaks[const VerseRef(2, 8)], isNull);
      // A verse can hold gaps and still end with a break of its own.
      expect(exodus.breaks[const VerseRef(20, 13)], SectionBreak.closed);
      expect(exodus.breaks[const VerseRef(20, 14)], SectionBreak.open);
      // Only a footnote follows this petuchah; it is still a break.
      expect(exodus.breaks[const VerseRef(33, 23)], SectionBreak.open);
      expect(exodus.verse(const VerseRef(33, 23)).segments.whereType<PisqaGap>(), isEmpty);
    });
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
