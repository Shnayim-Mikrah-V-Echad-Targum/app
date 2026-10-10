import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/features/community/ui/community_ui.dart';

void main() {
  test('a text runs the way of its first strong character', () {
    expect(autoDirection('שלום לכולם'), TextDirection.rtl);
    expect(autoDirection('Shalom'), TextDirection.ltr);
    expect(autoDirection('12, "Shalom" לכולם'), TextDirection.ltr);
    expect(autoDirection('3 שאלות on Rashi'), TextDirection.rtl);
    expect(autoDirection('Shalom', fallback: TextDirection.rtl), TextDirection.ltr, reason: 'a strong character wins');
  });

  test('a text with no strong character, an empty one included, takes the fallback', () {
    for (final text in ['', '   ', '123', '?! 🙂']) {
      expect(autoDirection(text), TextDirection.ltr, reason: '"$text"');
      expect(autoDirection(text, fallback: TextDirection.rtl), TextDirection.rtl, reason: '"$text"');
    }
  });
}
