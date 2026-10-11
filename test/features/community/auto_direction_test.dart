import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/features/community/ui/community_ui.dart';

void main() {
  const ltr = TextDirection.ltr;
  const rtl = TextDirection.rtl;

  test('a text runs the way of its first strong character', () {
    for (final fallback in TextDirection.values) {
      expect(autoDirection('שלום לכולם', fallback: fallback), rtl);
      expect(autoDirection('Shalom', fallback: fallback), ltr);
      expect(autoDirection('12, "Shalom" לכולם', fallback: fallback), ltr);
      expect(autoDirection('3 שאלות on Rashi', fallback: fallback), rtl);
      // Quotation marks and numbers before the first letter count for nothing.
      expect(autoDirection('“בקדמין”: Onkelos', fallback: fallback), rtl);
      expect(autoDirection('3 פעמים: three times', fallback: fallback), rtl);
    }
  });

  test('every script is recognised, not only Latin and Hebrew', () {
    for (final text in ['Привет, мир!', 'Καλημέρα', '你好', 'こんにちは', 'Ça va?', '¿Qué tal?', '«Élan»']) {
      expect(autoDirection(text, fallback: rtl), ltr, reason: text);
    }
    for (final text in ['مرحبا', 'ﬠﬡ', 'ﭐﭑ', 'ﹰﹱ', 'ܫܠܡܐ']) {
      expect(autoDirection(text, fallback: ltr), rtl, reason: text);
    }
    expect(autoDirection('‏123', fallback: ltr), rtl, reason: 'the right-to-left mark');
    expect(autoDirection('‎123', fallback: rtl), ltr, reason: 'the left-to-right mark');
  });

  test('a text with no strong character, an empty one included, takes the fallback', () {
    for (final text in ['', '   ', '123', '?! 🙂', '+1', '🙏', '5787', '—…', '285:2', ' 285:2 ']) {
      expect(autoDirection(text, fallback: ltr), ltr, reason: '"$text"');
      expect(autoDirection(text, fallback: rtl), rtl, reason: '"$text"');
    }
  });
}
