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

  // Equal progress needs equal stamps, so the clock only moves when a test
  // moves it.
  final wallClock = ProgressClock.nowMs;
  late int now;
  setUp(() {
    now = DateTime.utc(2026, 10, 12, 9).millisecondsSinceEpoch;
    ProgressClock.nowMs = () => now;
  });
  tearDown(() => ProgressClock.nowMs = wallClock);

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

  group('WeekProgress', () {
    test('un-marking a reading forgets how far into it the reader got', () {
      final read = WeekProgress(weekId: noach).withAliyah(2, d1).withPosition(2, const [9, 9, 9]);
      expect(read.withUnit(2, ReadingPass.mikra2, null).positions[2], [9, 0, 9]);
      expect(read.withAliyah(2, null).positions[2], [0, 0, 0]);
      expect(read.withAliyah(2, null).isStarted, isFalse);
      expect(read.withUnit(2, ReadingPass.targum, d2).positions[2], [9, 9, 9], reason: 'marking keeps it');
      final short = WeekProgress(weekId: noach, positions: {4: const [5]});
      expect(short.withUnit(4, ReadingPass.targum, null).positions[4], [5, 0, 0]);
    });

    test('a week has started once anything is read or begun', () {
      expect(WeekProgress(weekId: noach).isStarted, isFalse);
      expect(WeekProgress(weekId: noach).withPosition(0, const [1, 0, 0]).isStarted, isTrue);
      expect(WeekProgress(weekId: noach).withUnit(6, ReadingPass.targum, d1).isStarted, isTrue);
    });

    test('every change is stamped, whether it marks or un-marks, and nothing else is', () {
      final t0 = now;
      final read = WeekProgress(weekId: noach).withUnit(2, ReadingPass.mikra2, d1).withHaftarah(d1);
      expect(read.stamps[2], [0, t0, 0]);
      expect(read.haftarahStamp, t0);
      expect(read.isBlank, isFalse);

      now += 1000;
      expect(identical(read.withUnit(2, ReadingPass.mikra2, d2), read), isTrue, reason: 'already read');
      expect(identical(read.withUnit(2, ReadingPass.targum, null), read), isTrue, reason: 'already not read');
      expect(identical(read.withHaftarah(d1), read), isTrue);
      expect(read.withUnit(2, ReadingPass.mikra2, d2).units[2][1], d1, reason: 'the first day is kept');

      final unread = read.withUnit(2, ReadingPass.mikra2, null).withHaftarah(null);
      expect(unread.units[2], [null, null, null]);
      expect(unread.stamps[2], [0, t0 + 1000, 0], reason: 'a removal keeps a stamp');
      expect(unread.haftarahStamp, t0 + 1000);
      expect(unread.isBlank, isFalse);

      final placed = unread.withPosition(4, const [3, 0, 0]);
      expect(placed.positionStamps, {4: t0 + 1000});
      expect(identical(placed.withPosition(4, const [3, 0, 0]), placed), isTrue);
      expect(placed.latestStamp, t0 + 1000);
    });

    test('a change is stamped after what it replaces, even if the clock is behind', () {
      final read = WeekProgress(weekId: noach).withAliyah(0, d1).withPosition(0, const [2, 2, 2]);
      now -= 60000;
      final unread = read.withAliyah(0, null);
      expect(unread.stamps[0], [for (final t in read.stamps[0]) t + 1]);
      expect(unread.positionStamps[0], greaterThan(read.positionStamps[0]!));
      expect(ProgressClock.above(read.latestStamp + 5, () => read.withHaftarah(d1)).haftarahStamp, read.latestStamp + 6);
    });

    test('clearing a week leaves removals behind, stamped now', () {
      final read = WeekProgress(weekId: noach).withAliyah(1, d1).withHaftarah(d1).withPosition(1, const [4, 4, 4]);
      now += 1000;
      final cleared = read.cleared();
      expect(cleared.isStarted, isFalse);
      expect(cleared.haftarah, isNull);
      expect(cleared.positions, isEmpty);
      expect(cleared.stamps[1], [now, now, now]);
      expect(cleared.stamps[0], [0, 0, 0], reason: 'only what changed is stamped');
      expect(cleared.haftarahStamp, now);
      expect(cleared.positionStamps, {1: now});
      expect(identical(cleared.cleared(), cleared), isTrue);
    });

    test('restoring a week stamps only what differs', () {
      final before = WeekProgress(weekId: noach).withAliyah(1, d1).withAliyah(2, d2).withPosition(1, const [4, 4, 4]);
      now += 1000;
      final changed = before.withAliyah(2, null).withPosition(3, const [1, 0, 0]);
      now += 1000;
      final restored = changed.restoredTo(before);
      expect(restored.units, before.units);
      expect(restored.positions, before.positions);
      expect(restored.stamps[1], before.stamps[1], reason: 'unchanged');
      expect(restored.stamps[2], [now, now, now]);
      expect(restored.positionStamps[3], now, reason: 'the place saved since is removed');
    });
  });

  group('Pause', () {
    test('is identified by its dates when saved without an id', () {
      expect(Pause(d1, d2).id, '${d1.rd}-${d2.rd}');
      expect(Pause(d1, d2, id: '17').id, '17');
    });

    test('changes keep its id and are stamped', () {
      final p = Pause(d1, d3, id: '17', updatedAt: now);
      now += 1000;
      final ended = p.endingOn(d2);
      expect((ended.id, ended.end, ended.updatedAt, ended.deleted), ('17', d2, now, false));
      final cancelled = p.cancelled();
      expect((cancelled.id, cancelled.deleted), ('17', true));
      expect(cancelled.contains(d2), isFalse, reason: 'a cancelled pause covers no days');
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

  group('ProgressController', () {
    late ProviderContainer container;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({ProgressController.storageKey: jsonEncode(sample().toJson())});
      prefs = await SharedPreferences.getInstance();
      container = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
      addTearDown(container.dispose);
    });

    ProgressController progress() => container.read(progressProvider.notifier);
    ProgressState state() => container.read(progressProvider);

    test('a change that changes nothing saves nothing', () async {
      final before = state();
      await prefs.remove(ProgressController.storageKey);
      progress().markUnit(noach, 3, ReadingPass.targum, d3);
      progress().markUnit('5787:9', 0, ReadingPass.mikra1, null);
      progress().savePosition(vayakhel, 4, const [2, 1, 0]);
      expect(identical(state(), before), isTrue);
      expect(state().weeks.keys, isNot(contains('5787:9')), reason: 'no empty week is added');
      expect(prefs.getString(ProgressController.storageKey), isNull);
    });

    test('clearing a week leaves it unread, and undoing that restores it', () {
      final before = state().week(vayakhel);
      now += 1000;
      progress().clearWeek(vayakhel);
      expect(state().week(vayakhel).isStarted, isFalse);
      expect(state().weeks.keys, contains(vayakhel), reason: 'the removals are kept');

      now += 1000;
      progress().restoreWeek(vayakhel, before);
      final restored = state().week(vayakhel);
      expect(restored.units, before.units);
      expect(restored.positions, before.positions);
      expect(restored.stamps[0], [now, now, now], reason: 'a new change, which a sync will not undo');
    });

    test('new pauses get distinct ids from the time they were made', () {
      progress().addPause(d1, d2);
      progress().addPause(d3, d3);
      final added = state().pauses.skip(1).toList();
      expect(added.map((p) => p.id), ['$now', '${now + 1}']);
      expect(added.map((p) => p.updatedAt), [now, now]);
    });

    test('ending a pause changes it in place, and cancels one that has not begun', () {
      progress().replaceAll(ProgressState(pauses: [
        Pause(d1, d3, id: 'a', updatedAt: now),
        Pause(d2, d3, id: 'b', updatedAt: now),
        Pause(d3, d3, id: 'c', updatedAt: now),
      ]));
      now += 1000;
      progress().endPause(d2);
      final pauses = {for (final p in state().pauses) p.id: p};
      expect(pauses, hasLength(3), reason: 'no pause is added or dropped');
      expect((pauses['a']!.end, pauses['a']!.deleted, pauses['a']!.updatedAt), (d1, false, now));
      expect((pauses['b']!.deleted, pauses['b']!.updatedAt), (true, now));
      expect(pauses['c']!.updatedAt, now - 1000, reason: 'not covering today');
      expect(state().pauses.any((p) => p.contains(d2)), isFalse, reason: 'today is no longer paused');
    });

    test('a reset stays on this device unless it is to reach everywhere', () {
      final latest = state().latestStamp;
      progress().reset();
      expect(state(), const ProgressState(), reason: 'nothing marks it for other devices');

      progress().replaceAll(sample());
      now -= 60000;
      progress().reset(everywhere: true);
      expect(state().weeks, isEmpty);
      expect(state().pauses, isEmpty);
      expect(state().resetAt, latest + 1, reason: 'after everything it erased, though the clock is behind');

      progress().markUnit(noach, 0, ReadingPass.mikra1, d1);
      expect(state().week(noach).stamps[0][0], latest + 2, reason: 'stamped after the reset');
      expect(ProgressState.fromJson(jsonDecode(prefs.getString(ProgressController.storageKey)!)).resetAt, latest + 1);
    });
  });
}
