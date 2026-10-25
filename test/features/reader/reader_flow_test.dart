import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikrah/data/models/scripture.dart';
import 'package:shnayim_mikrah/data/models/verse_ref.dart';
import 'package:shnayim_mikrah/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikrah/features/reader/reader_flow.dart';
import 'package:shnayim_mikrah/features/settings/app_settings.dart';

void main() {
  final verses = [for (var v = 1; v <= 6; v++) VerseRef(1, v)];
  ReaderFlow flow({
    ReadingMethod method = ReadingMethod.verseByVerse,
    SecondReading second = SecondReading.onkelos,
    List<bool>? rashi,
    bool repeatLast = false,
    bool thirdReadingPrompts = true,
    String book = 'Genesis',
    List<VerseRef>? refs,
    Map<VerseRef, SectionBreak>? breaks,
  }) =>
      ReaderFlow(
        book: book,
        verses: refs ?? verses,
        method: method,
        second: second,
        hasRashi: rashi ?? List.filled((refs ?? verses).length, true),
        breaks: breaks ?? {const VerseRef(1, 2): SectionBreak.closed, const VerseRef(1, 5): SectionBreak.open},
        thirdReadingPrompts: thirdReadingPrompts,
        repeatLastVerse: repeatLast,
      );

  test('chunks follow the reading method', () {
    expect(flow().chunks, hasLength(6));
    expect(flow(method: ReadingMethod.aliyahByAliyah).chunks.single.length, 6);
    final sections = flow(method: ReadingMethod.sectionBySection).chunks;
    expect(sections.map((c) => (c.start, c.end)), [(0, 2), (2, 5), (5, 6)]);
  });

  test('steps: twice Mikrah then the chosen second reading', () {
    expect(flow().stepsFor(0), [StepKind.mikrah1, StepKind.mikrah2, StepKind.targum]);
    expect(flow(second: SecondReading.rashi).stepsFor(0), [StepKind.mikrah1, StepKind.mikrah2, StepKind.rashi]);
    expect(flow(second: SecondReading.onkelosAndRashi).stepsFor(0),
        [StepKind.mikrah1, StepKind.mikrah2, StepKind.targum, StepKind.rashi]);
  });

  test('a verse without Rashi gets a third Hebrew reading in Rashi mode', () {
    final f = flow(second: SecondReading.rashi, rashi: [true, false, true, true, true, true]);
    expect(f.stepsFor(1), [StepKind.mikrah1, StepKind.mikrah2, StepKind.thirdHebrew]);
    expect(f.stepVerses(1, StepKind.thirdHebrew), [const VerseRef(1, 2)]);
  });

  test('with third-reading prompts off, a verse without Rashi is read in the Rashi step', () {
    final f = flow(
      second: SecondReading.rashi,
      rashi: [true, false, true, true, true, true],
      thirdReadingPrompts: false,
    );
    expect(f.stepsFor(1), [StepKind.mikrah1, StepKind.mikrah2, StepKind.rashi]);
  });

  group('Atarot v\'Divon (Numbers 32:3)', () {
    const refs = [VerseRef(32, 1), VerseRef(32, 2), VerseRef(32, 3), VerseRef(32, 4), VerseRef(32, 5)];
    final breaks = {const VerseRef(32, 4): SectionBreak.closed};
    ReaderFlow numbers({
      ReadingMethod method = ReadingMethod.verseByVerse,
      SecondReading second = SecondReading.onkelos,
      bool thirdReadingPrompts = true,
    }) =>
        flow(
          book: 'Numbers',
          refs: refs,
          breaks: breaks,
          method: method,
          second: second,
          thirdReadingPrompts: thirdReadingPrompts,
        );

    test('read verse by verse, it has a third Hebrew reading of its own', () {
      final f = numbers();
      expect(f.stepsFor(1), [StepKind.mikrah1, StepKind.mikrah2, StepKind.targum]);
      expect(f.stepsFor(2), [StepKind.mikrah1, StepKind.mikrah2, StepKind.targum, StepKind.thirdHebrew]);
      expect(f.stepVerses(2, StepKind.thirdHebrew), [const VerseRef(32, 3)]);
      expect(f.thirdHebrewInTargum(2, const VerseRef(32, 3)), isFalse, reason: 'it has its own step');
    });

    test('with Rashi too, the third reading comes last', () {
      expect(numbers(second: SecondReading.onkelosAndRashi).stepsFor(2),
          [StepKind.mikrah1, StepKind.mikrah2, StepKind.targum, StepKind.rashi, StepKind.thirdHebrew]);
    });

    test('read by section, the Targum step shows it again after its Onkelos', () {
      final f = numbers(method: ReadingMethod.sectionBySection);
      expect(f.chunks.map((c) => (c.start, c.end)), [(0, 4), (4, 5)]);
      expect(f.stepsFor(0), [StepKind.mikrah1, StepKind.mikrah2, StepKind.targum]);
      expect(f.needsThirdHebrewAfterTargum(const VerseRef(32, 3)), isTrue);
      expect(f.needsThirdHebrewAfterTargum(const VerseRef(32, 2)), isFalse);
      expect(f.thirdReadingRefs(f.chunks[0]), [const VerseRef(32, 3)]);
      expect(f.thirdHebrewInTargum(0, const VerseRef(32, 3)), isTrue);
      expect(f.thirdHebrewInTargum(0, const VerseRef(32, 2)), isFalse);
      expect(f.thirdReadingRefs(f.chunks[1]), isEmpty);
    });

    test('read by aliyah, the Targum step shows it again after its Onkelos', () {
      final f = numbers(method: ReadingMethod.aliyahByAliyah);
      expect(f.stepsFor(0), [StepKind.mikrah1, StepKind.mikrah2, StepKind.targum]);
      expect(f.thirdHebrewInTargum(0, const VerseRef(32, 3)), isTrue);
    });

    test('with third-reading prompts off, it is read like any other verse', () {
      final verse = numbers(thirdReadingPrompts: false);
      expect(verse.stepsFor(2), [StepKind.mikrah1, StepKind.mikrah2, StepKind.targum]);
      final section = numbers(method: ReadingMethod.sectionBySection, thirdReadingPrompts: false);
      expect(section.needsThirdHebrewAfterTargum(const VerseRef(32, 3)), isFalse);
      expect(section.thirdHebrewInTargum(0, const VerseRef(32, 3)), isFalse);
    });

    test('with Rashi in place of the Targum, there is no third reading', () {
      expect(numbers(second: SecondReading.rashi).stepsFor(2), [StepKind.mikrah1, StepKind.mikrah2, StepKind.rashi]);
      final section = numbers(method: ReadingMethod.sectionBySection, second: SecondReading.rashi);
      expect(section.needsThirdHebrewAfterTargum(const VerseRef(32, 3)), isFalse);
    });
  });

  test('the final repeat shows only the last verse', () {
    final f = flow(method: ReadingMethod.sectionBySection, repeatLast: true);
    expect(f.stepVerses(2, StepKind.repeatLast), [const VerseRef(1, 6)]);
    expect(f.stepVerses(1, StepKind.mikrah1), [const VerseRef(1, 3), const VerseRef(1, 4), const VerseRef(1, 5)]);
  });

  test('end with Mikrah adds a final repeat step', () {
    final f = flow(repeatLast: true);
    expect(f.stepsFor(5).last, StepKind.repeatLast);
    expect(f.stepsFor(4).last, StepKind.targum);
    expect(f.passCompletedBy(5, f.stepsFor(5).length - 1), isNull);
    expect(f.passCompletedBy(5, f.stepsFor(5).length - 2), ReadingPass.targum);
  });

  test('positions advance per pass and never regress', () {
    final f = flow();
    var p = [0, 0, 0];
    p = f.positionsAfter(0, 0, p);
    expect(p, [1, 0, 0]);
    p = f.positionsAfter(0, 1, p);
    p = f.positionsAfter(0, 2, p);
    expect(p, [1, 1, 1]);
    expect(f.positionsAfter(0, 0, [5, 5, 5]), [5, 5, 5]);
  });

  test('section mode completes each pass over the whole section', () {
    final f = flow(method: ReadingMethod.sectionBySection);
    expect(f.positionsAfter(1, 0, [2, 2, 2]), [5, 2, 2]);
    expect(f.positionsAfter(1, 2, [5, 5, 2]), [5, 5, 5]);
  });

  test('resume picks up at the right verse and step', () {
    final f = flow();
    expect(f.resumeFrom(null), (0, 0));
    expect(f.resumeFrom([3, 3, 3]), (3, 0));
    expect(f.resumeFrom([4, 3, 3]), (3, 1));
    expect(f.resumeFrom([4, 4, 3]), (3, 2));
    expect(f.resumeFrom([6, 6, 6]), (0, 0), reason: 'finished aliyah restarts for review');
  });

  test('resume never skips a reading that was un-marked on its own', () {
    final f = flow(method: ReadingMethod.aliyahByAliyah);
    expect(f.resumeFrom([0, 6, 0]), (0, 0), reason: 'the first reading is not done');
    expect(f.resumeFrom([6, 0, 0]), (0, 1));
    expect(f.resumeFrom([6, 6, 0]), (0, 2));
  });

  group('a chunk starts past the readings of the Hebrew done before the aliyah was opened', () {
    test('read twice from a Chumash, each verse starts at its Targum', () {
      final f = flow();
      for (var c = 0; c < 6; c++) {
        expect(f.entryStep(c, [6, 6, 0]), 2, reason: 'verse ${c + 1}');
      }
      expect(f.resumeFrom([6, 6, 1]), (1, 2), reason: 'as the reader resumes there');
      expect(f.entryStep(0, [6, 0, 0]), 1, reason: 'read once: the second reading');
    });

    test('nothing done, or the aliyah read, starts every chunk at its beginning', () {
      final f = flow();
      expect([for (var c = 0; c < 6; c++) f.entryStep(c, null)], everyElement(0));
      expect([for (var c = 0; c < 6; c++) f.entryStep(c, [0, 0, 0])], everyElement(0));
    });

    test('a chunk read in full is read again in full', () {
      final f = flow();
      expect(f.entryStep(1, [4, 4, 3]), 0, reason: 'verse 2 was read three times');
      expect(f.entryStep(3, [4, 4, 3]), 2, reason: 'verse 4 was read twice');
      expect(f.entryStep(4, [4, 4, 3]), 0, reason: 'verse 5 was not read');
    });

    test('never past a reading that was un-marked on its own', () {
      expect(flow().entryStep(2, [0, 6, 0]), 0);
    });

    test('by section, and with Rashi after the Targum', () {
      final sections = flow(method: ReadingMethod.sectionBySection);
      expect(sections.entryStep(1, [6, 6, 2]), 2);
      expect(sections.entryStep(1, [4, 4, 2]), 0, reason: 'the section is not yet read through');
      final both = flow(second: SecondReading.onkelosAndRashi);
      expect(both.entryStep(0, [6, 6, 0]), both.stepsFor(0).indexOf(StepKind.targum));
    });
  });

  test('resume after switching from verse to section mode', () {
    final f = flow(method: ReadingMethod.sectionBySection);
    expect(f.resumeFrom([3, 3, 3]), (1, 0), reason: 'restart the section containing the next verse');
  });

  group('the whole parsha', () {
    // Seven aliyot of two verses; the last repeats its final verse.
    List<ReaderFlow> aliyot({SecondReading second = SecondReading.onkelos, List<bool> rashiIn = const [true, true, true, true, true, true, true]}) => [
          for (var a = 0; a < 7; a++)
            flow(
              method: ReadingMethod.wholeParsha,
              second: second,
              refs: [VerseRef(a + 1, 1), VerseRef(a + 1, 2)],
              rashi: [rashiIn[a], false],
              repeatLast: a == 6,
            ),
        ];
    ParshaOrder order(List<ReaderFlow> flows) => ParshaOrder([for (final f in flows) f.stepsFor(0)]);

    test('each aliyah is one chunk, read as aliyah by aliyah reads it', () {
      final flows = aliyot();
      expect(flows.first.chunks.single.length, 2);
      expect(flows.first.stepsFor(0), [StepKind.mikrah1, StepKind.mikrah2, StepKind.targum]);
      expect(flows.last.stepsFor(0), [StepKind.mikrah1, StepKind.mikrah2, StepKind.targum, StepKind.repeatLast]);
    });

    test('the Hebrew of every aliyah, again, then every second reading, then the last verse', () {
      final o = order(aliyot());
      expect(o.sequence, [
        for (var a = 0; a < 7; a++) (a, 0),
        for (var a = 0; a < 7; a++) (a, 1),
        for (var a = 0; a < 7; a++) (a, 2),
        (6, 3),
      ]);
      expect(o.next(6, 0), (0, 1));
      expect(o.next(6, 1), (0, 2));
      expect(o.next(6, 2), (6, 3));
      expect(o.next(6, 3), isNull);
      expect(o.back(0, 1), (6, 0));
      expect(o.back(0, 0), isNull);
    });

    test('Onkelos and Rashi: each aliyah\'s Targum, then its Rashi where he comments on it', () {
      final rashiIn = [true, false, true, true, true, true, true];
      final o = order(aliyot(second: SecondReading.onkelosAndRashi, rashiIn: rashiIn));
      final third = o.sequence.skip(14).toList();
      expect(third, [(0, 2), (0, 3), (1, 2), (2, 2), (2, 3), (3, 2), (3, 3), (4, 2), (4, 3), (5, 2), (5, 3), (6, 2), (6, 3), (6, 4)]);
    });

    test('it resumes at the first aliyah not yet read in the earliest round not finished', () {
      final flows = aliyot();
      final o = order(flows);
      final counts = [for (final _ in flows) 2];
      List<List<int>> positions(List<int> Function(int a) of) => [for (var a = 0; a < 7; a++) of(a)];
      expect(o.resume(positions((_) => [0, 0, 0]), counts), (0, 0));
      expect(o.resume(positions((a) => a < 3 ? [2, 0, 0] : [0, 0, 0]), counts), (3, 0));
      expect(o.resume(positions((a) => a < 5 ? [2, 2, 0] : [2, 0, 0]), counts), (5, 1));
      expect(o.resume(positions((a) => a == 0 ? [2, 2, 2] : [2, 2, 0]), counts), (1, 2));
      // Read in full: from the beginning again.
      expect(o.resume(positions((_) => [2, 2, 2]), counts), (0, 0));
      // An aliyah read by another method earlier counts as read.
      expect(o.resume(positions((a) => a == 0 ? [2, 2, 2] : [0, 0, 0]), counts), (1, 0));
    });

    test('a step\'s pass, and where each round starts in an aliyah', () {
      final o = order(aliyot());
      expect(o.passOf(6, 3), ReadingPass.targum);
      expect(o.passOf(2, 1), ReadingPass.mikrah2);
      expect(o.roundStep(4, ReadingPass.targum), 2);
      expect(o.roundStep(4, ReadingPass.mikrah1), 0);
    });
  });
}
