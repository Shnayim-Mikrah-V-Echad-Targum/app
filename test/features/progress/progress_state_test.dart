import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_merge.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';

void main() {
  final d1 = LocalDate(2026, 10, 11);
  final d2 = LocalDate(2026, 10, 12);
  final d3 = LocalDate(2026, 10, 20);

  // Ids of different lengths, so that string order and jsonb order differ.
  const vayakhel = '5787:22-23';
  const noach = '5787:2';
  WeekProgress vayakhelWeek() => WeekProgress(weekId: vayakhel)
      .withAliyah(0, d1)
      .withPosition(4, const [2, 1, 0])
      .withPosition(1, const [5, 5, 3]);
  WeekProgress noachWeek() => WeekProgress(weekId: noach).withUnit(3, ReadingPass.targum, d2).withHaftarah(d2);
  ProgressState sample({List<Pause>? pauses}) =>
      ProgressState(weeks: {vayakhel: vayakhelWeek(), noach: noachWeek()}, pauses: pauses ?? [Pause(d1, d2)]);

  group('ProgressState equality', () {
    test('ignores the order of weeks, positions and pauses', () {
      final a = sample(pauses: [Pause(d1, d2), Pause(d3, d3)]);
      final reordered = WeekProgress(weekId: vayakhel)
          .withAliyah(0, d1)
          .withPosition(1, const [5, 5, 3])
          .withPosition(4, const [2, 1, 0]);
      final b = ProgressState(weeks: {noach: noachWeek(), vayakhel: reordered}, pauses: [Pause(d3, d3), Pause(d1, d2)]);
      expect(b, a);
      expect(b.hashCode, a.hashCode);
    });

    test('survives merging and a server round trip that reorders keys', () {
      final a = sample();
      // Postgres jsonb stores object keys shortest first, then bytewise.
      Object? jsonb(Object? v) => switch (v) {
            Map() => {
                for (final k in v.keys.cast<String>().toList()
                  ..sort((x, y) => x.length != y.length ? x.length - y.length : x.compareTo(y)))
                  k: jsonb(v[k]),
              },
            List() => [for (final e in v) jsonb(e)],
            _ => v,
          };
      final back = ProgressState.fromJson(jsonb(jsonDecode(jsonEncode(a.toJson()))) as Map<String, dynamic>);
      expect(back.weeks.keys, [noach, vayakhel], reason: 'the round trip should reorder weeks');
      expect(back, a);
      expect(back.hashCode, a.hashCode);
      expect(mergeProgress(a, back), a);
      expect(mergeProgress(back, a), a);
    });

    test('tells different progress apart', () {
      final a = ProgressState(weeks: {vayakhel: vayakhelWeek()}, pauses: [Pause(d1, d2)]);
      ProgressState withWeek(WeekProgress w) => ProgressState(weeks: {vayakhel: w}, pauses: [Pause(d1, d2)]);
      expect(a, isNot(withWeek(vayakhelWeek().withUnit(6, ReadingPass.mikra1, d3))));
      expect(a, isNot(withWeek(vayakhelWeek().withHaftarah(d3))));
      expect(a, isNot(withWeek(vayakhelWeek().withPosition(4, const [3, 1, 0]))));
      expect(a, isNot(ProgressState(weeks: {vayakhel: vayakhelWeek()}, pauses: [Pause(d1, d3)])));
      expect(a, isNot(ProgressState(weeks: {vayakhel: vayakhelWeek()})));
      // A cleared week is still a recorded week.
      expect(const ProgressState(), isNot(ProgressState(weeks: {vayakhel: WeekProgress(weekId: vayakhel)})));
    });
  });

  group('ProgressController.replaceAll', () {
    late ProviderContainer container;
    late SharedPreferences prefs;
    late int notifications;

    setUp(() async {
      SharedPreferences.setMockInitialValues({ProgressController.storageKey: jsonEncode(sample().toJson())});
      prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
      addTearDown(container.dispose);
      notifications = 0;
      container.listen(progressProvider, (_, _) => notifications++);
    });

    test('ignores equal progress', () async {
      final before = container.read(progressProvider);
      await prefs.remove(ProgressController.storageKey);
      container
          .read(progressProvider.notifier)
          .replaceAll(ProgressState(weeks: {noach: noachWeek(), vayakhel: vayakhelWeek()}, pauses: [Pause(d1, d2)]));
      expect(notifications, 0);
      expect(identical(container.read(progressProvider), before), isTrue);
      expect(prefs.getString(ProgressController.storageKey), isNull, reason: 'nothing should be rewritten');
    });

    test('applies and saves different progress', () {
      final next = ProgressState(weeks: {vayakhel: vayakhelWeek().withAll(d3)});
      container.read(progressProvider.notifier).replaceAll(next);
      expect(notifications, 1);
      expect(container.read(progressProvider), next);
      expect(prefs.getString(ProgressController.storageKey), jsonEncode(next.toJson()));
    });
  });
}
