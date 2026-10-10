import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_merge.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';

void main() {
  final d1 = LocalDate(2026, 10, 11);
  final d2 = LocalDate(2026, 10, 12);
  const id = '5787:2';

  // A clock that only moves when a test moves it, and a cloud backup.
  final wallClock = ProgressClock.nowMs;
  late int now;
  late ProgressState cloud;
  setUp(() {
    now = DateTime.utc(2026, 10, 12, 9).millisecondsSinceEpoch;
    ProgressClock.nowMs = () => now;
    cloud = const ProgressState();
  });
  tearDown(() => ProgressClock.nowMs = wallClock);

  void later() => now += const Duration(minutes: 1).inMilliseconds;

  /// Syncs a device the way ProgressSync does (pull, merge, push) and
  /// returns the device's progress afterwards.
  ProgressState sync(ProgressState device) => cloud = mergeProgress(device, cloud);

  ProgressState edit(ProgressState s, WeekProgress Function(WeekProgress w) change) =>
      s.copyWith(weeks: {...s.weeks, id: change(s.week(id))});

  /// What ProgressController.reset(everywhere: true) leaves.
  ProgressState resetEverywhere(ProgressState s) => ProgressState(resetAt: ProgressClock.after(s.latestStamp));

  String j(ProgressState s) => jsonEncode(s.toJson());

  test('the earliest completion of each reading wins and nothing is lost', () {
    final a = ProgressState(weeks: {
      '5787:2': WeekProgress(weekId: '5787:2').withAliyah(0, d2).withUnit(1, ReadingPass.mikra1, d1),
    });
    final b = ProgressState(weeks: {
      '5787:2': WeekProgress(weekId: '5787:2').withAliyah(0, d1).withHaftarah(d2),
      '5787:3': WeekProgress(weekId: '5787:3').withAliyah(3, d2),
    }, pauses: [Pause(d1, d2)]);
    final m = mergeProgress(a, b);
    expect(m.week('5787:2').units[0], [d1, d1, d1]);
    expect(m.week('5787:2').units[1][0], d1);
    expect(m.week('5787:2').haftarah, d2);
    expect(m.week('5787:3').isAliyahDone(3), isTrue);
    expect(m.pauses, hasLength(1));
  });

  test('merge is commutative and idempotent', () {
    final a = ProgressState(weeks: {'5787:2': WeekProgress(weekId: '5787:2').withAliyah(0, d2).withPosition(1, const [3, 2, 1])});
    final b = ProgressState(weeks: {'5787:2': WeekProgress(weekId: '5787:2').withAliyah(0, d1).withPosition(1, const [1, 2, 4])});
    expect(j(mergeProgress(a, b)), j(mergeProgress(b, a)));
    final m = mergeProgress(a, b);
    expect(j(mergeProgress(m, m)), j(m));
    expect(m.week('5787:2').positions[1], [3, 2, 4], reason: 'saved at the same moment: the furthest of each');
  });

  test('progress survives a JSON round trip', () {
    final s = ProgressState(
      weeks: {'5787:22-23': WeekProgress(weekId: '5787:22-23').withAll(d1).withPosition(6, const [9, 9, 9])},
      pauses: [Pause(d1, d2)],
    );
    final back = ProgressState.fromJson(s.toJson());
    expect(back.week('5787:22-23').isComplete, isTrue);
    expect(back.week('5787:22-23').positions[6], [9, 9, 9]);
    expect(back.pauses.single.end, d2);
    expect(back, s);
  });

  group('a removal stays removed after syncing:', () {
    test('a reading marked as not read', () {
      var phone = sync(edit(const ProgressState(), (w) => w.withAliyah(0, d1).withAliyah(1, d1)));
      var tablet = sync(const ProgressState());
      expect(tablet.week(id).isAliyahDone(0), isTrue);

      later();
      tablet = sync(edit(tablet, (w) => w.withAliyah(0, null)));
      expect(tablet.week(id).units[0], [null, null, null]);
      phone = sync(phone);
      expect(phone.week(id).units[0], [null, null, null], reason: 'the other device hears of it');
      expect(phone.week(id).isAliyahDone(1), isTrue, reason: 'the rest is untouched');
      expect(sync(tablet), phone);
    });

    test('a cleared week', () {
      var phone = sync(edit(
        const ProgressState(),
        (w) => w.withAll(d1).withHaftarah(d2).withPosition(3, const [4, 4, 4]),
      ));
      var tablet = sync(const ProgressState());

      later();
      phone = sync(edit(phone, (w) => w.cleared()));
      tablet = sync(tablet);
      for (final s in [phone, tablet]) {
        expect(s.week(id).isStarted, isFalse);
        expect(s.week(id).haftarah, isNull);
        expect(s.week(id).positions, isEmpty);
      }
    });

    test('the haftarah marked as not read', () {
      var phone = sync(edit(const ProgressState(), (w) => w.withHaftarah(d1)));
      var tablet = sync(const ProgressState());
      expect(tablet.week(id).haftarah, d1);

      later();
      tablet = sync(edit(tablet, (w) => w.withHaftarah(null)));
      phone = sync(phone);
      expect(tablet.week(id).haftarah, isNull);
      expect(phone.week(id).haftarah, isNull);
    });

    test('a reset, everywhere, except what was logged after it', () {
      var phone = sync(ProgressState(
        weeks: {id: WeekProgress(weekId: id).withAll(d1).withPosition(0, const [2, 2, 2])},
        pauses: [Pause(d1, d2, id: '1', updatedAt: now)],
      ));
      var tablet = sync(const ProgressState());
      expect(tablet.week(id).isComplete, isTrue);

      later();
      phone = sync(resetEverywhere(phone));
      expect(phone.weeks, isEmpty);
      // Logged on the tablet after the reset, before it heard of it.
      later();
      tablet = sync(edit(tablet, (w) => w.withHaftarah(d2)));
      expect(tablet.week(id).isStarted, isFalse);
      expect(tablet.week(id).positions, isEmpty);
      expect(tablet.pauses, isEmpty);
      expect(tablet.week(id).haftarah, d2, reason: 'logged after the reset');
      expect(tablet.resetAt, phone.resetAt);
      expect(sync(phone), tablet);
    });

    test('a pause ended early, or cancelled', () {
      var phone = sync(ProgressState(pauses: [
        Pause(d1, d1.addDays(9), id: '1', updatedAt: now),
        Pause(d1.addDays(20), d1.addDays(29), id: '2', updatedAt: now),
      ]));
      var tablet = sync(const ProgressState());

      later();
      phone = sync(phone.copyWith(pauses: [phone.pauses[0].endingOn(d2), phone.pauses[1].cancelled()]));
      tablet = sync(tablet);
      expect(tablet.pauses, hasLength(2), reason: 'changed in place, not added');
      expect(tablet.pauses[0].end, d2);
      expect(tablet.pauses[1].deleted, isTrue);
      expect(tablet.pauses.any((p) => p.contains(d1.addDays(5))), isFalse);
      expect(tablet.pauses.any((p) => p.contains(d1.addDays(25))), isFalse);
      expect(tablet, phone);
    });
  });

  test('readings logged on two devices are all kept, with the earliest day', () {
    var phone = edit(const ProgressState(), (w) => w.withAliyah(0, d2));
    later();
    var tablet = edit(const ProgressState(), (w) => w.withUnit(0, ReadingPass.mikra1, d1).withAliyah(1, d2));
    phone = sync(phone);
    tablet = sync(tablet);
    phone = sync(phone);
    for (final s in [phone, tablet]) {
      expect(s.week(id).units[0], [d1, d2, d2]);
      expect(s.week(id).isAliyahDone(1), isTrue);
    }
    expect(phone, tablet);
  });

  test('a reading and its removal elsewhere: the later one wins, and a tie keeps it read', () {
    final read = edit(const ProgressState(), (w) => w.withAliyah(0, d1));
    later();
    final unread = edit(read, (w) => w.withAliyah(0, null));
    later();
    final readAgain = edit(unread, (w) => w.withAliyah(0, d2));
    expect(mergeProgress(read, unread).week(id).units[0], [null, null, null]);
    expect(mergeProgress(unread, readAgain).week(id).units[0], [d2, d2, d2]);

    // Removed on one device and logged on another at the same moment.
    final removed = WeekProgress(weekId: id, stamps: List.generate(kAliyot, (_) => [now, now, now]));
    final logged = WeekProgress(
      weekId: id,
      units: List.generate(kAliyot, (_) => [d1, null, null]),
      stamps: List.generate(kAliyot, (_) => [now, now, now]),
    );
    final m = mergeProgress(ProgressState(weeks: {id: removed}), ProgressState(weeks: {id: logged}));
    expect(m.week(id).units[0], [d1, null, null]);
  });

  group('a reading marked again on a later day keeps that day', () {
    late ProgressState read, readAgain;
    setUp(() {
      read = edit(const ProgressState(), (w) => w.withAliyah(2, d1).withHaftarah(d1));
      later();
      final unread = edit(read, (w) => w.withAliyah(2, null).withHaftarah(null));
      later();
      readAgain = edit(unread, (w) => w.withAliyah(2, d2).withHaftarah(d2));
    });

    test('against a copy that still has the first day, in either order', () {
      for (final m in [mergeProgress(read, readAgain), mergeProgress(readAgain, read)]) {
        expect(m.week(id).units[2], [d2, d2, d2]);
        expect(m.week(id).haftarah, d2);
      }
      expect(j(mergeProgress(read, readAgain)), j(mergeProgress(readAgain, read)));
    });

    test('through the cloud, when the other device syncs next', () {
      var phone = sync(read);
      var tablet = sync(const ProgressState());
      expect(tablet.week(id).units[2], [d1, d1, d1]);

      // Corrected on the phone, then synced; the tablet still has Sunday.
      later();
      phone = sync(edit(phone, (w) => w.withAliyah(2, null).withHaftarah(null)));
      later();
      phone = sync(edit(phone, (w) => w.withAliyah(2, d2).withHaftarah(d2)));
      tablet = sync(tablet);
      phone = sync(phone);
      for (final s in [phone, tablet]) {
        expect(s.week(id).units[2], [d2, d2, d2]);
        expect(s.week(id).haftarah, d2);
      }
    });

    test('when both changes reach the cloud together, still holding the first day', () {
      var phone = sync(read);
      later();
      phone = edit(phone, (w) => w.withAliyah(2, null).withHaftarah(null));
      later();
      phone = sync(edit(phone, (w) => w.withAliyah(2, d2).withHaftarah(d2)));
      expect(phone.week(id).units[2], [d2, d2, d2]);
      expect(phone.week(id).haftarah, d2);
    });

    test("and a restored backup's day replaces the day there was", () {
      final restored = edit(read, (w) => w.restoredTo(WeekProgress(weekId: id).withAliyah(2, d2)));
      expect(mergeProgress(read, restored).week(id).units[2], [d2, d2, d2]);
    });
  });

  test('readings logged independently stay logged when one copy is marked as not read', () {
    // The phone logs Rishon on Sunday, and the tablet, not having heard,
    // logs it on Monday. A third copy (another device) that had heard only
    // of Sunday's then marks it as not read, before Monday's mark was made.
    final sunday = edit(const ProgressState(), (w) => w.withAliyah(0, d1));
    later();
    final removed = edit(sunday, (w) => w.withAliyah(0, null));
    later();
    final monday = edit(const ProgressState(), (w) => w.withAliyah(0, d2));

    final all = [sunday, removed, monday];
    for (final (x, y, z) in [
      (sunday, removed, monday),
      (sunday, monday, removed),
      (monday, removed, sunday),
      (removed, monday, sunday),
    ]) {
      final m = mergeProgress(mergeProgress(x, y), z);
      expect(m.week(id).units[0], [d2, d2, d2], reason: "Monday's mark came after the removal");
      expect(m, mergeProgress(x, mergeProgress(y, z)));
    }
    // Before the removal is heard of, Sunday's still wins over Monday's.
    expect(mergeProgress(sunday, monday).week(id).units[0], [d1, d1, d1]);
    expect(all.reduce(mergeProgress).week(id).units[0], [d2, d2, d2]);
  });

  test('merging readings is associative, commutative and idempotent', () {
    // Random histories of one reading: marks and removals on several
    // devices, at times that often collide.
    final random = Random(5787);
    ReadingRecord history() {
      var r = ReadingRecord.blank;
      for (var i = random.nextInt(4); i > 0; i--) {
        if (random.nextInt(3) == 0) {
          r = ReadingRecord.of(r.marks, clearedAt: max(r.clearedAt, random.nextInt(8)));
        } else {
          r = ReadingRecord.of([...r.marks, ReadingMark(d1.addDays(random.nextInt(4)), random.nextInt(8))],
              clearedAt: r.clearedAt);
        }
      }
      return r;
    }

    String key(ReadingRecord r) => '${r.clearedAt} ${[for (final m in r.marks) '${m.day.rd}@${m.at}']}';
    for (var i = 0; i < 2000; i++) {
      final (a, b, c) = (history(), history(), history());
      final cut = random.nextInt(3) == 0 ? random.nextInt(8) : 0;
      ReadingRecord merge(ReadingRecord x, ReadingRecord y) => x.merge(y, cut: cut);
      expect(key(merge(merge(a, b), c)), key(merge(a, merge(b, c))), reason: '${key(a)} | ${key(b)} | ${key(c)}');
      expect(key(merge(a, b)), key(merge(b, a)));
      expect(key(merge(merge(a, b), b)), key(merge(a, b)));
    }
  });

  test('a change outranks what it replaces, even on a device whose clock is behind', () {
    final start = now;
    now = start + const Duration(hours: 1).inMilliseconds;
    var phone = sync(edit(const ProgressState(), (w) => w.withAliyah(0, d1)));

    // The tablet's clock is an hour behind the phone's.
    now = start;
    var tablet = sync(const ProgressState());
    tablet = sync(edit(tablet, (w) => w.withAliyah(0, null)));
    expect(tablet.week(id).units[0], [null, null, null]);
    phone = sync(phone);
    expect(phone.week(id).units[0], [null, null, null]);

    // Nor does a reset made on the phone swallow what the tablet logs after
    // hearing of it.
    now = start + const Duration(hours: 2).inMilliseconds;
    phone = sync(resetEverywhere(phone));
    now = start + const Duration(minutes: 5).inMilliseconds;
    tablet = sync(tablet);
    final heard = tablet;
    tablet = sync(edit(heard, (w) => ProgressClock.above(heard.resetAt, () => w.withAliyah(2, d2))));
    expect(tablet.week(id).isAliyahDone(2), isTrue);
    expect(sync(phone).week(id).isAliyahDone(2), isTrue);
  });

  test('the later saved place in an aliyah wins', () {
    final phone = edit(const ProgressState(), (w) => w.withPosition(1, const [5, 0, 0]));
    later();
    final tablet = edit(const ProgressState(), (w) => w.withPosition(1, const [2, 3, 0]));
    expect(mergeProgress(phone, tablet).week(id).positions[1], [2, 3, 0]);
    expect(mergeProgress(tablet, phone).week(id).positions[1], [2, 3, 0]);
  });

  test('pauses: a tie goes to the cancellation, and cancellations are forgotten after 60 days', () {
    final a = ProgressState(pauses: [Pause(d1, d2, id: '7', updatedAt: now)]);
    final b = ProgressState(pauses: [
      Pause(d1, d2, id: '7', updatedAt: now, deleted: true),
      Pause(d1.addDays(40), d1.addDays(41), id: '8', updatedAt: now),
    ]);
    expect(mergeProgress(a, b).pauses.first.deleted, isTrue);
    expect(mergeProgress(b, a).pauses.first.deleted, isTrue);

    now += const Duration(days: 61).inMilliseconds;
    expect(mergeProgress(a, b).pauses.map((p) => p.id), ['8'], reason: 'only the cancellation is forgotten');
  });

  test('merge is commutative, idempotent and absorbing with removals, resets and pauses', () {
    final base = ProgressState(
      weeks: {
        id: WeekProgress(weekId: id).withAll(d2).withHaftarah(d2).withPosition(2, const [1, 1, 1]),
        '5787:3': WeekProgress(weekId: '5787:3').withAliyah(4, d1),
      },
      pauses: [Pause(d1, d2), Pause(d1.addDays(30), d1.addDays(31), id: '5', updatedAt: now)],
    );
    later();
    var a = edit(base, (w) => w.withAliyah(0, null).withPosition(2, const [3, 0, 0]));
    a = a.copyWith(pauses: [a.pauses[0], a.pauses[1].cancelled()]);
    later();
    var b = edit(base, (w) => w.cleared().withUnit(6, ReadingPass.targum, d1));
    b = b.copyWith(pauses: [...b.pauses, Pause(d2, d2.addDays(3), id: '6', updatedAt: now)]);
    later();
    final c = resetEverywhere(base);
    later();
    final d = edit(c, (w) => w.withAliyah(5, d2));

    for (final (x, y) in [(a, b), (a, c), (b, d), (a, d), (base, b)]) {
      final m = mergeProgress(x, y);
      expect(j(m), j(mergeProgress(y, x)));
      expect(m, mergeProgress(y, x));
      expect(mergeProgress(m, m), m);
      expect(mergeProgress(m, x), m, reason: 'merging in a copy already included changes nothing');
    }
  });

  group('the join date syncs with the progress:', () {
    final oct4 = LocalDate(2026, 10, 4);
    final oct20 = LocalDate(2026, 10, 20);
    // Noach, read on its Friday.
    final noach = ProgressState(weeks: {id: WeekProgress(weekId: id).withAll(LocalDate(2026, 10, 16))});

    test('the earlier one wins, on either side', () {
      // A new phone, set up on the 20th, and the backup of a reader who
      // joined on the 4th.
      expect(mergeSyncPayload(noach, oct20, syncPayload(noach, oct4)).joinDate, oct4);
      expect(mergeSyncPayload(noach, oct4, syncPayload(noach, oct20)).joinDate, oct4);
    });

    test("a backup without one keeps this device's", () {
      expect(mergeSyncPayload(noach, oct4, syncPayload(noach, null)).joinDate, oct4);
      expect(mergeSyncPayload(const ProgressState(), oct20, syncPayload(const ProgressState(), null)).joinDate, oct20);
      expect(mergeSyncPayload(const ProgressState(), null, syncPayload(const ProgressState(), null)).joinDate, isNull);
    });

    test('a backup saved by an earlier version, without one, counts from its earliest reading', () {
      final history = ProgressState(weeks: {
        '5787:1': WeekProgress(weekId: '5787:1').withAliyah(0, LocalDate(2026, 10, 5)),
        id: noach.week(id),
      });
      final merged = mergeSyncPayload(const ProgressState(), oct20, history.toJson());
      expect(merged.joinDate, LocalDate(2026, 10, 5));
      expect(merged.progress, history);
      // A reading this device logged for a day before it joined, never yet
      // backed up, is no reason to move its join date.
      final backfilled = edit(const ProgressState(), (w) => w.withAliyah(0, LocalDate(2026, 10, 11)));
      expect(mergeSyncPayload(backfilled, oct20, noach.toJson()).joinDate, LocalDate(2026, 10, 16));
    });

    test("an earlier version's backup of this device's own readings doesn't move its join date", () {
      // Joined on Monday the 12th, and marked Rishon read on Sunday, the
      // week's first day: backed up by an earlier version, without the join
      // date.
      final oct12 = LocalDate(2026, 10, 12);
      final here = edit(const ProgressState(), (w) => w.withAliyah(0, d1));
      expect(mergeSyncPayload(here, oct12, here.toJson()).joinDate, oct12);
      // Nor does a reading the backup holds for another day than this
      // device's, when this device's has replaced it.
      later();
      final moved = edit(here, (w) => w.withAliyah(0, oct12));
      expect(mergeSyncPayload(moved, oct12, here.toJson()).joinDate, oct12);
      // What the backup brings from another device still counts.
      final elsewhere = here.copyWith(weeks: {
        ...here.weeks,
        '5787:1': WeekProgress(weekId: '5787:1').withAliyah(0, LocalDate(2026, 10, 5)),
      });
      expect(mergeSyncPayload(here, oct12, elsewhere.toJson()).joinDate, LocalDate(2026, 10, 5));
    });

    test('the earliest reading includes the haftarah, and can be limited to the days from one on', () {
      expect(earliestReadDate(const ProgressState()), isNull);
      final p = ProgressState(weeks: {
        '5787:1': WeekProgress(weekId: '5787:1').withUnit(3, ReadingPass.targum, LocalDate(2026, 10, 8)),
        id: WeekProgress(weekId: id).withAliyah(0, LocalDate(2026, 10, 12)).withHaftarah(LocalDate(2026, 10, 6)),
      });
      expect(earliestReadDate(p), LocalDate(2026, 10, 6));
      expect(earliestReadDate(p, from: LocalDate(2026, 10, 7)), LocalDate(2026, 10, 8));
      expect(earliestReadDate(p, from: LocalDate(2026, 10, 13)), isNull);
      // Leaving out what another copy holds done on the same day.
      final held = ProgressState(weeks: {
        id: WeekProgress(weekId: id).withHaftarah(LocalDate(2026, 10, 6)),
        '5787:1': WeekProgress(weekId: '5787:1').withUnit(3, ReadingPass.targum, LocalDate(2026, 10, 9)),
      });
      expect(earliestReadDate(p, except: held), LocalDate(2026, 10, 8));
      expect(earliestReadDate(p, except: p), isNull);
    });

    test('after a reset everywhere, a join date from before it has no say', () {
      final before = edit(const ProgressState(), (w) => w.withAliyah(0, d1));
      later();
      // On the 12th (the clock's day).
      final reset = resetEverywhere(before);
      final restart = LocalDate(2026, 10, 12);
      later();
      expect(mergeSyncPayload(before, oct4, syncPayload(reset, restart)).joinDate, restart);
      expect(mergeSyncPayload(reset, restart, syncPayload(before, oct4)).joinDate, restart);

      // Reset by an earlier version, which synced no join date, and read
      // there since: once for a day before the reset, and once after.
      final since = reset.copyWith(weeks: {
        id: WeekProgress(weekId: id).withAliyah(1, LocalDate(2026, 10, 5)).withAliyah(2, oct20),
      });
      expect(mergeSyncPayload(before, oct4, since.toJson()).joinDate, oct20);
    });

    test('the payload holds the progress as earlier versions read it, and the join date beside it', () {
      final payload = syncPayload(noach, oct4);
      expect(syncPayloadJoinDate(payload), oct4);
      expect(ProgressState.fromJson(payload), noach);
      expect(syncPayload(noach, null).containsKey('joinDate'), isFalse);
      expect(syncPayloadJoinDate(noach.toJson()), isNull);
    });
  });
}
