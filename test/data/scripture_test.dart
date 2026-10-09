import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/data/models/scripture.dart';
import 'package:shnayim_mikra/data/models/verse_ref.dart';

void main() {
  group('PisqaGap', () {
    test('parses petuchah and setumah gaps', () {
      expect((Segment.fromJson({'gap': 'P'}) as PisqaGap).kind, SectionBreak.open);
      expect((Segment.fromJson({'gap': 'S'}) as PisqaGap).kind, SectionBreak.closed);
      expect(() => Segment.fromJson({'gap': 'X'}), throwsFormatException);
    });

    test('reads as a single word space', () {
      final verse = Verse.fromJson(const VerseRef(20, 13), [
        'לא תרצח׃',
        {'gap': 'S'},
        'לא תנאף׃',
        {'gap': 'P'},
        'לא תגנב׃',
      ]);
      expect(verse.readText, 'לא תרצח׃ לא תנאף׃ לא תגנב׃');
    });
  });
}
