import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/features/community/ui/community_ui.dart';

void main() {
  test('a text runs the way its first letter does', () {
    expect(autoDirection('Shalom'), TextDirection.ltr);
    expect(autoDirection('שלום'), TextDirection.rtl);
    expect(autoDirection('“בקדמין”: Onkelos'), TextDirection.rtl);
    expect(autoDirection('3 פעמים: three times'), TextDirection.rtl);
  });

  test('a text without letters takes the fallback, or else runs left to right', () {
    expect(autoDirection(''), TextDirection.ltr);
    expect(autoDirection('285:2'), TextDirection.ltr);
    expect(autoDirection('', fallback: TextDirection.rtl), TextDirection.rtl);
    expect(autoDirection(' 285:2 ', fallback: TextDirection.rtl), TextDirection.rtl);
    expect(autoDirection('Shalom', fallback: TextDirection.rtl), TextDirection.ltr);
  });
}
