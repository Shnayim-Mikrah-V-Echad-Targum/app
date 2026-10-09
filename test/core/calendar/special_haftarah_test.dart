import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/core/calendar/parsha_schedule.dart';
import 'package:shnayim_mikra/core/calendar/special_haftarah.dart';

import 'fixtures.dart';

void main() {
  final fixture = loadFixture('special_haftarot.json') as Map<String, dynamic>;

  for (final israel in [false, true]) {
    test('special haftarot 2000-2100 match the reference (${israel ? 'Israel' : 'Diaspora'})', () {
      final data = fixture[israel ? 'il' : 'diaspora'] as Map<String, dynamic>;
      final expected = (data['special'] as Map<String, dynamic>).cast<String, String>();
      final schedule = ParshaSchedule(israel: israel);
      final mismatches = <String>[];
      var count = 0;
      for (var d = LocalDate.parse(data['from'] as String);
          d <= LocalDate.parse(data['to'] as String);
          d = d.addDays(7)) {
        final portion = schedule.portionOnShabbat(d);
        if (portion == null) continue;
        count++;
        final actual = specialHaftarahKey(d, portion);
        if (actual != expected[d.toIso()]) {
          mismatches.add('$d ${portion.key}: expected ${expected[d.toIso()]}, got $actual');
        }
      }
      expect(count, greaterThan(4800));
      expect(mismatches, isEmpty, reason: mismatches.take(25).join('\n'));
    });
  }
}
