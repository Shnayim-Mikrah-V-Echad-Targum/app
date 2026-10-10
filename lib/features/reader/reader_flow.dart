import 'dart:math' as math;

import '../../data/models/scripture.dart';
import '../../data/models/verse_ref.dart';
import '../progress/domain/progress_models.dart';
import '../settings/app_settings.dart';

/// What the reader is asked to read at one step.
enum StepKind {
  /// The Hebrew text, first time.
  mikra1,

  /// The Hebrew text, second time.
  mikra2,

  /// Targum Onkelos.
  targum,

  /// Rashi (in place of, or in addition to, the Targum).
  rashi,

  /// The Hebrew a third time, as a step of its own, for a single verse: one
  /// listed in [kThirdReadingVerses], or one Rashi is silent on when Rashi is
  /// the second reading.
  thirdHebrew,

  /// The final verse once more, to end with Mikra.
  repeatLast,
}

/// A contiguous run of verses read together: one verse, one section, or
/// the whole aliyah, depending on the reading method.
class Chunk {
  const Chunk(this.start, this.end);

  /// Index of the first verse (inclusive).
  final int start;

  /// Index after the last verse (exclusive).
  final int end;

  int get length => end - start;

  @override
  String toString() => 'Chunk($start-$end)';
}

/// Verses many also read a third time in Hebrew after the Targum, whose
/// Onkelos is mostly place names (SA OC 285:1; Rashi, Berakhot 8b).
const kThirdReadingVerses = {'Numbers 32:3'};

/// The guided reading sequence for one aliyah.
///
/// Positions are persisted as three counts — verses completed in the first
/// reading, the second reading and the Targum — which works for every
/// reading method and survives switching between them.
class ReaderFlow {
  ReaderFlow({
    required this.book,
    required this.verses,
    required this.method,
    required this.second,
    required this.hasRashi,
    this.breaks = const {},
    this.thirdReadingPrompts = true,
    this.repeatLastVerse = false,
  }) {
    chunks = _buildChunks();
  }

  final String book;
  final List<VerseRef> verses;
  final ReadingMethod method;
  final SecondReading second;

  /// Whether Rashi comments on each verse (parallel to [verses]).
  final List<bool> hasRashi;

  /// Section breaks after verses (from the Masoretic text).
  final Map<VerseRef, SectionBreak> breaks;
  final bool thirdReadingPrompts;

  /// Whether this is the last aliyah and the reader repeats its final verse.
  final bool repeatLastVerse;

  late final List<Chunk> chunks;

  List<Chunk> _buildChunks() {
    switch (method) {
      case ReadingMethod.verseByVerse:
        return [for (var i = 0; i < verses.length; i++) Chunk(i, i + 1)];
      case ReadingMethod.aliyahByAliyah:
        return [Chunk(0, verses.length)];
      case ReadingMethod.sectionBySection:
        // Only breaks between verses count: a pasuk is never split, so a
        // PisqaGap inside a verse does not end a section.
        final out = <Chunk>[];
        var start = 0;
        for (var i = 0; i < verses.length; i++) {
          final isLast = i == verses.length - 1;
          if (isLast || breaks.containsKey(verses[i])) {
            out.add(Chunk(start, i + 1));
            start = i + 1;
          }
        }
        return out;
    }
  }

  bool get _readsTargum => second == SecondReading.onkelos || second == SecondReading.onkelosAndRashi;

  /// The verses of [c] listed in [kThirdReadingVerses].
  List<VerseRef> thirdReadingRefs(Chunk c) => [
        for (final r in verses.sublist(c.start, c.end))
          if (kThirdReadingVerses.contains('$book $r')) r,
      ];

  /// Whether [r] is read a third time in Hebrew after its Targum. A verse
  /// read on its own gets a [StepKind.thirdHebrew] step; in a longer chunk the
  /// Targum step shows it again inline, after its Onkelos.
  bool needsThirdHebrewAfterTargum(VerseRef r) =>
      _readsTargum && thirdReadingPrompts && kThirdReadingVerses.contains('$book $r');

  bool _needsThirdHebrewStep(Chunk c) => c.length == 1 && needsThirdHebrewAfterTargum(verses[c.start]);

  /// Whether the Targum step of chunk [chunkIndex] shows the Hebrew of [r]
  /// again after its Onkelos, since the chunk has no step of its own for it.
  bool thirdHebrewInTargum(int chunkIndex, VerseRef r) =>
      chunks[chunkIndex].length > 1 && needsThirdHebrewAfterTargum(r);

  /// The verses shown at [kind] of chunk [chunkIndex].
  List<VerseRef> stepVerses(int chunkIndex, StepKind kind) {
    final c = chunks[chunkIndex];
    return switch (kind) {
      StepKind.repeatLast => [verses.last],
      // After the Targum, only the verses listed for a third reading. In
      // Rashi's place, the one verse of the chunk that Rashi is silent on.
      StepKind.thirdHebrew when _readsTargum => thirdReadingRefs(c),
      _ => verses.sublist(c.start, c.end),
    };
  }

  /// The steps for a chunk, in order.
  List<StepKind> stepsFor(int chunkIndex) {
    final c = chunks[chunkIndex];
    final steps = <StepKind>[StepKind.mikra1, StepKind.mikra2];
    final noRashi = !hasRashi.sublist(c.start, c.end).any((x) => x);
    switch (second) {
      case SecondReading.onkelos:
        steps.add(StepKind.targum);
        if (_needsThirdHebrewStep(c)) steps.add(StepKind.thirdHebrew);
      case SecondReading.rashi:
      case SecondReading.rashiEnglish:
        steps.add(noRashi && c.length == 1 && thirdReadingPrompts ? StepKind.thirdHebrew : StepKind.rashi);
      case SecondReading.onkelosAndRashi:
        steps.add(StepKind.targum);
        if (!noRashi) steps.add(StepKind.rashi);
        if (_needsThirdHebrewStep(c)) steps.add(StepKind.thirdHebrew);
    }
    if (repeatLastVerse && chunkIndex == chunks.length - 1) steps.add(StepKind.repeatLast);
    return steps;
  }

  /// The pass that is complete once [step] of a chunk is done, if any.
  ReadingPass? passCompletedBy(int chunkIndex, int stepIndex) {
    final steps = stepsFor(chunkIndex);
    final kind = steps[stepIndex];
    if (kind == StepKind.mikra1) return ReadingPass.mikra1;
    if (kind == StepKind.mikra2) return ReadingPass.mikra2;
    if (kind == StepKind.repeatLast) return null;
    // The second-reading pass completes after the last of its steps.
    final lastSecond = steps.lastIndexWhere((k) => k != StepKind.repeatLast);
    return stepIndex == lastSecond ? ReadingPass.targum : null;
  }

  /// Updated position counts after finishing [stepIndex] of [chunkIndex].
  List<int> positionsAfter(int chunkIndex, int stepIndex, List<int> current) {
    final pass = passCompletedBy(chunkIndex, stepIndex);
    final out = [...current];
    while (out.length < 3) {
      out.add(0);
    }
    if (pass != null) out[pass.index] = math.max(out[pass.index], chunks[chunkIndex].end);
    return out;
  }

  /// Where to resume, given saved position counts. Returns (chunk, step).
  (int, int) resumeFrom(List<int>? positions) {
    if (positions == null || positions.length < 3) return (0, 0);
    final t = positions[2];
    if (t >= verses.length) return (0, 0);
    var ci = chunks.indexWhere((c) => c.end > t);
    if (ci < 0) ci = 0;
    final c = chunks[ci];
    final steps = stepsFor(ci);
    // A reading can be un-marked on its own, so check that the earlier ones
    // really are done.
    if (positions[0] >= c.end && positions[1] >= c.end) {
      final i = steps.indexOf(StepKind.mikra2) + 1;
      return (ci, math.min(i, steps.length - 1));
    }
    if (positions[0] >= c.end) return (ci, steps.indexOf(StepKind.mikra2));
    return (ci, 0);
  }

  int get totalSteps => [for (var i = 0; i < chunks.length; i++) stepsFor(i).length].fold(0, (a, b) => a + b);
}
