import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/data/models/scripture.dart';
import 'package:shnayim_mikra/data/models/verse_ref.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikra/features/reader/reader_flow.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';

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

  test('steps: twice Mikra then the chosen second reading', () {
    expect(flow().stepsFor(0), [StepKind.mikra1, StepKind.mikra2, StepKind.targum]);
    expect(flow(second: SecondReading.rashi).stepsFor(0), [StepKind.mikra1, StepKind.mikra2, StepKind.rashi]);
    expect(flow(second: SecondReading.onkelosAndRashi).stepsFor(0),
        [StepKind.mikra1, StepKind.mikra2, StepKind.targum, StepKind.rashi]);
  });

  test('a verse without Rashi gets a third Hebrew reading in Rashi mode', () {
    final f = flow(second: SecondReading.rashi, rashi: [true, false, true, true, true, true]);
    expect(f.stepsFor(1), [StepKind.mikra1, StepKind.mikra2, StepKind.thirdHebrew]);
    expect(f.stepVerses(1, StepKind.thirdHebrew), [const VerseRef(1, 2)]);
  });

  test('with third-reading prompts off, a verse without Rashi is read in the Rashi step', () {
    final f = flow(
      second: SecondReading.rashi,
      rashi: [true, false, true, true, true, true],
      thirdReadingPrompts: false,
    );
    expect(f.stepsFor(1), [StepKind.mikra1, StepKind.mikra2, StepKind.rashi]);
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
      expect(f.stepsFor(1), [StepKind.mikra1, StepKind.mikra2, StepKind.targum]);
      expect(f.stepsFor(2), [StepKind.mikra1, StepKind.mikra2, StepKind.targum, StepKind.thirdHebrew]);
      expect(f.stepVerses(2, StepKind.thirdHebrew), [const VerseRef(32, 3)]);
      expect(f.thirdHebrewInTargum(2, const VerseRef(32, 3)), isFalse, reason: 'it has its own step');
    });

    test('with Rashi too, the third reading comes last', () {
      expect(numbers(second: SecondReading.onkelosAndRashi).stepsFor(2),
          [StepKind.mikra1, StepKind.mikra2, StepKind.targum, StepKind.rashi, StepKind.thirdHebrew]);
    });

    test('read by section, the Targum step shows it again after its Onkelos', () {
      final f = numbers(method: ReadingMethod.sectionBySection);
      expect(f.chunks.map((c) => (c.start, c.end)), [(0, 4), (4, 5)]);
      expect(f.stepsFor(0), [StepKind.mikra1, StepKind.mikra2, StepKind.targum]);
      expect(f.needsThirdHebrewAfterTargum(const VerseRef(32, 3)), isTrue);
      expect(f.needsThirdHebrewAfterTargum(const VerseRef(32, 2)), isFalse);
      expect(f.thirdReadingRefs(f.chunks[0]), [const VerseRef(32, 3)]);
      expect(f.thirdHebrewInTargum(0, const VerseRef(32, 3)), isTrue);
      expect(f.thirdHebrewInTargum(0, const VerseRef(32, 2)), isFalse);
      expect(f.thirdReadingRefs(f.chunks[1]), isEmpty);
    });

    test('read by aliyah, the Targum step shows it again after its Onkelos', () {
      final f = numbers(method: ReadingMethod.aliyahByAliyah);
      expect(f.stepsFor(0), [StepKind.mikra1, StepKind.mikra2, StepKind.targum]);
      expect(f.thirdHebrewInTargum(0, const VerseRef(32, 3)), isTrue);
    });

    test('with third-reading prompts off, it is read like any other verse', () {
      final verse = numbers(thirdReadingPrompts: false);
      expect(verse.stepsFor(2), [StepKind.mikra1, StepKind.mikra2, StepKind.targum]);
      final section = numbers(method: ReadingMethod.sectionBySection, thirdReadingPrompts: false);
      expect(section.needsThirdHebrewAfterTargum(const VerseRef(32, 3)), isFalse);
      expect(section.thirdHebrewInTargum(0, const VerseRef(32, 3)), isFalse);
    });

    test('with Rashi in place of the Targum, there is no third reading', () {
      expect(numbers(second: SecondReading.rashi).stepsFor(2), [StepKind.mikra1, StepKind.mikra2, StepKind.rashi]);
      final section = numbers(method: ReadingMethod.sectionBySection, second: SecondReading.rashi);
      expect(section.needsThirdHebrewAfterTargum(const VerseRef(32, 3)), isFalse);
    });
  });

  test('the final repeat shows only the last verse', () {
    final f = flow(method: ReadingMethod.sectionBySection, repeatLast: true);
    expect(f.stepVerses(2, StepKind.repeatLast), [const VerseRef(1, 6)]);
    expect(f.stepVerses(1, StepKind.mikra1), [const VerseRef(1, 3), const VerseRef(1, 4), const VerseRef(1, 5)]);
  });

  test('end with Mikra adds a final repeat step', () {
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

  test('resume after switching from verse to section mode', () {
    final f = flow(method: ReadingMethod.sectionBySection);
    expect(f.resumeFrom([3, 3, 3]), (1, 0), reason: 'restart the section containing the next verse');
  });
}
