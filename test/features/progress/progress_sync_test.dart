import 'dart:async';
import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shnayim_mikrah/app/app.dart';
import 'package:shnayim_mikrah/app/providers.dart';
import 'package:shnayim_mikrah/app/router.dart';
import 'package:shnayim_mikrah/core/calendar/local_date.dart';
import 'package:shnayim_mikrah/data/models/verse_ref.dart';
import 'package:shnayim_mikrah/features/community/data/backend.dart';
import 'package:shnayim_mikrah/features/community/data/community_providers.dart';
import 'package:shnayim_mikrah/features/community/data/demo_forum_repository.dart';
import 'package:shnayim_mikrah/features/community/data/forum_repository.dart';
import 'package:shnayim_mikrah/features/community/data/models.dart';
import 'package:shnayim_mikrah/features/notes/domain/annotations.dart';
import 'package:shnayim_mikrah/features/progress/domain/progress_merge.dart';
import 'package:shnayim_mikrah/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikrah/features/progress/domain/streak_engine.dart';
import 'package:shnayim_mikrah/features/settings/app_settings.dart';

import '../../helpers.dart';

const _me = CommunityUser(id: 'me', email: 'me@example.com');
const _week = '5787:1';
final _d1 = LocalDate(2026, 10, 11);
final _d2 = LocalDate(2026, 10, 12);

/// Accounts whose progress backups live in memory, reordered the way
/// Postgres jsonb stores them, and which count every round trip.
class _CountingRepo extends Fake implements ForumRepository {
  _CountingRepo({this.user, Map<String, dynamic>? remote}) {
    this.remote = remote;
  }

  CommunityUser? user;
  final _users = StreamController<CommunityUser?>.broadcast();

  /// Each account's backed-up progress JSON, by user id.
  final backups = <String, Map<String, dynamic>>{};

  /// [_me]'s backed-up progress JSON.
  Map<String, dynamic>? get remote => backups[_me.id];
  set remote(Map<String, dynamic>? json) {
    if (json == null) {
      backups.remove(_me.id);
    } else {
      backups[_me.id] = json;
    }
  }

  /// When set, [loadProgress] waits for it, to hold a sync in flight.
  Completer<void>? gate;

  /// When set, [saveProgress] waits for it before storing anything.
  Completer<void>? saveGate;

  int loads = 0;
  int saves = 0;

  /// When each [loadProgress] was called, by the clock the test controls.
  final loadTimes = <DateTime>[];
  int profileLoads = 0;

  /// Signs in or out, or (with the same user) mimics a token refresh.
  void announce(CommunityUser? next) {
    user = next;
    _users.add(next);
  }

  @override
  bool get isDemo => false;

  @override
  CommunityUser? get currentUser => user;

  @override
  Stream<CommunityUser?> get userChanges => _users.stream;

  @override
  Future<Profile?> myProfile() async {
    profileLoads++;
    return Profile(id: user!.id, displayName: 'Reader');
  }

  // Like the real backend, each call is for whoever is signed in when it is
  // made.

  @override
  Future<Map<String, dynamic>?> loadProgress() async {
    loads++;
    loadTimes.add(clock.now());
    final id = user!.id;
    await gate?.future;
    final json = backups[id];
    return json == null ? null : _jsonb(json) as Map<String, dynamic>;
  }

  @override
  Future<void> saveProgress(Map<String, dynamic> data) async {
    saves++;
    final id = user!.id;
    final json = _jsonb(jsonDecode(jsonEncode(data))) as Map<String, dynamic>;
    await saveGate?.future;
    backups[id] = json;
  }

  /// Postgres jsonb keeps object keys shortest first, then bytewise.
  static Object? _jsonb(Object? v) => switch (v) {
        Map() => <String, dynamic>{
            for (final k in v.keys.cast<String>().toList()
              ..sort((x, y) => x.length != y.length ? x.length - y.length : x.compareTo(y)))
              k: _jsonb(v[k]),
          },
        List() => [for (final e in v) _jsonb(e)],
        _ => v,
      };
}

class _FixedToday extends TodayController {
  _FixedToday(this.day);
  final LocalDate day;

  @override
  LocalDate build() => day;
}

/// Progress logged on another device, which joined on the day of it, and
/// already backed up.
Map<String, dynamic> _otherDevice() => syncPayload(
      ProgressState(weeks: {
        _week: WeekProgress(weekId: _week).withUnit(0, ReadingPass.mikrah1, _d1),
      }),
      _d1,
    );

/// A reader who joined on Simchat Torah 5787 (Sunday 4 October 2026) and
/// read every portion on its Friday, Bereshit to Chayei Sara: a parsha
/// streak of 5 on the Wednesday of Toldot, [_toldotWednesday].
ProgressState _fiveWeeks() => ProgressState(weeks: {
      for (final (i, friday) in [9, 16, 23, 30, 37].indexed)
        '5787:${i + 1}': WeekProgress(weekId: '5787:${i + 1}').withAll(LocalDate(2026, 10, 1).addDays(friday - 1)),
    });
final _simchatTorah = LocalDate(2026, 10, 4);
final _toldotWednesday = LocalDate(2026, 11, 11);

void main() {
  // For the app's lifecycle, which the sync follows.
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      SettingsController.storageKey: jsonEncode(const AppSettings(cloudSync: true).toJson()),
    });
    prefs = await SharedPreferences.getInstance();
  });

  /// A container with backup on, kept alive the way the app keeps it.
  ProviderContainer containerFor(_CountingRepo repo) {
    final c = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      backendProvider.overrideWithValue(Backend(repo)),
    ]);
    c.listen(progressSyncProvider, (_, _) {});
    return c;
  }

  ProgressState remoteOf(_CountingRepo repo) => ProgressState.fromJson(repo.remote!);

  test('a merge settles instead of syncing again every few seconds', () {
    final repo = _CountingRepo(user: _me, remote: _otherDevice());
    fakeAsync((async) {
      final container = containerFor(repo);
      container.read(progressProvider.notifier).markUnit(_week, 1, ReadingPass.mikrah2, _d2);
      async.elapse(const Duration(seconds: 120));

      // One pull and one push merge the two devices, and nothing repeats.
      expect(repo.loads, 1);
      expect(repo.saves, 1);
      final local = container.read(progressProvider);
      expect(local.week(_week).isUnitDone(0, ReadingPass.mikrah1), isTrue, reason: 'pulled from the other device');
      expect(local.week(_week).isUnitDone(1, ReadingPass.mikrah2), isTrue, reason: 'kept from this device');
      expect(remoteOf(repo), local);
      expect(container.read(progressSyncProvider), isNotNull);
      container.dispose();
    });
  });

  test('a later change is pushed once, after it has rested', () {
    final repo = _CountingRepo(user: _me, remote: _otherDevice());
    fakeAsync((async) {
      final container = containerFor(repo);
      async.elapse(const Duration(seconds: 120));
      final (loads, saves) = (repo.loads, repo.saves);
      final progress = container.read(progressProvider.notifier);

      progress.markUnit(_week, 2, ReadingPass.mikrah1, _d2);
      async.elapse(const Duration(seconds: 3));
      progress.markUnit(_week, 2, ReadingPass.mikrah2, _d2);
      async.elapse(ProgressSync.pushDelay - const Duration(seconds: 1));
      expect(repo.loads, loads, reason: 'still waiting for the changes to rest');

      async.elapse(const Duration(seconds: 120));
      expect(repo.loads, loads + 1);
      expect(repo.saves, saves + 1);
      expect(remoteOf(repo), container.read(progressProvider));
      container.dispose();
    });
  });

  test('signing in pulls exactly once; token refreshes neither pull nor refetch', () {
    final repo = _CountingRepo(remote: _otherDevice());
    fakeAsync((async) {
      final container = containerFor(repo);
      container.listen(myProfileProvider, (_, _) {});
      bool? signedOutResult;
      container.read(progressSyncProvider.notifier).syncNow().then((ok) => signedOutResult = ok);
      async.elapse(const Duration(seconds: 10));
      expect(signedOutResult, isFalse);
      expect(repo.loads, 0);

      repo.announce(_me);
      async.elapse(const Duration(seconds: 120));
      expect(repo.loads, 1);
      expect(repo.profileLoads, 1);
      expect(container.read(progressProvider).week(_week).isUnitDone(0, ReadingPass.mikrah1), isTrue);

      for (var i = 0; i < 3; i++) {
        // A fresh but equal user, as each refreshed session reports.
        repo.announce(CommunityUser(id: _me.id, email: _me.email));
        async.elapse(const Duration(minutes: 30));
      }
      expect(repo.loads, 1);
      expect(repo.saves, 1, reason: 'the streak alone, which the backup lacked');
      expect(repo.remote!['streak'], isA<Map<String, dynamic>>());
      expect(repo.profileLoads, 1);
      container.dispose();
    });
  });

  test('calls made during a sync share one more sync after it', () {
    final repo = _CountingRepo(user: _me, remote: _otherDevice());
    fakeAsync((async) {
      final container = containerFor(repo);
      async.elapse(const Duration(seconds: 120));
      final loads = repo.loads;
      final sync = container.read(progressSyncProvider.notifier);

      repo.gate = Completer<void>();
      final first = sync.syncNow();
      final second = sync.syncNow();
      final third = sync.syncNow();
      expect(identical(second, third), isTrue);
      expect(identical(first, second), isFalse);
      async.flushMicrotasks();
      expect(repo.loads, loads + 1, reason: 'one sync at a time');

      final results = <bool>[];
      first.then(results.add);
      second.then(results.add);
      repo.gate!.complete();
      async.flushMicrotasks();
      expect(results, [true, true]);
      expect(repo.loads, loads + 2, reason: 'the calls made during the first sync ran one more');

      // Once both are done, the next call starts a fresh sync.
      sync.syncNow();
      async.flushMicrotasks();
      expect(repo.loads, loads + 3);
      container.dispose();
    });
  });

  group('coming back to the foreground', () {
    /// The app going to the background and coming back, as each platform
    /// reports it on the way.
    void leaveAndReturn() {
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    }

    test('pulls what another device has logged meanwhile', () {
      final repo = _CountingRepo(user: _me, remote: _otherDevice());
      fakeAsync((async) {
        final container = containerFor(repo);
        async.elapse(const Duration(seconds: 120));
        final (loads, saves) = (repo.loads, repo.saves);
        // Sheni, read on the other device while this one was in the background,
        // which backed up the streak it counted then.
        final before = {
          ...syncPayload(ProgressState(weeks: {_week: remoteOf(repo).week(_week).withAliyah(1, _d2)}), _d1),
          'streak': repo.remote!['streak'],
        };
        repo.remote = before;

        binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
        async.flushMicrotasks();
        expect(repo.loads, loads, reason: 'only coming back pulls');
        binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
        async.flushMicrotasks();
        expect(repo.loads, loads + 1);
        final local = container.read(progressProvider);
        expect(local.week(_week).isAliyahDone(1), isTrue, reason: 'pulled from the other device');
        expect(local, remoteOf(repo));
        // Saved again only if the streak this device now counts is not the one
        // backed up.
        final streak = syncStreak(container.read(streakSummaryProvider), container.read(todayProvider));
        expect(repo.saves, saves + (syncPayloadHasStreak(before, streak) ? 0 : 1), reason: 'the cloud held all but the streak');
        expect(syncPayloadHasStreak(repo.remote!, streak), isTrue);
        container.dispose();
      });
    });

    test('pulls nothing within a minute of a sync, and pulls after that', () {
      expect(ProgressSync.resumeQuietPeriod, const Duration(minutes: 1));
      final repo = _CountingRepo(user: _me, remote: _otherDevice());
      fakeAsync((async) {
        final container = containerFor(repo);
        async.elapse(const Duration(seconds: 1));
        expect(repo.loads, 1, reason: 'the sync the app starts with');
        // To 59 s after it started.
        async.elapse(const Duration(seconds: 59) - clock.now().difference(repo.loadTimes.single));
        leaveAndReturn();
        async.flushMicrotasks();
        expect(repo.loads, 1, reason: '59 s after it');

        async.elapse(const Duration(seconds: 2));
        leaveAndReturn();
        async.flushMicrotasks();
        expect(repo.loads, 2, reason: '61 s after it');
        container.dispose();
      });
    });

    test('lets a sync just started finish alone, and has one that started over a minute ago followed by another', () {
      final repo = _CountingRepo(user: _me, remote: _otherDevice());
      fakeAsync((async) {
        // The app comes to the foreground as its first sync is under way.
        repo.gate = Completer<void>();
        final container = containerFor(repo);
        async.elapse(const Duration(seconds: 59));
        expect(repo.loads, 1, reason: 'the first pull is in flight');
        leaveAndReturn();
        repo.gate!.complete();
        async.elapse(const Duration(seconds: 120));
        expect(repo.loads, 1, reason: 'that pull was new enough');
        expect(container.read(progressSyncProvider), isNotNull);

        // One under way for longer than that, a sync that stalled in the
        // background say, may have pulled before the other device saved:
        // another follows it, once.
        repo.gate = Completer<void>();
        container.read(progressSyncProvider.notifier).syncNow();
        async.flushMicrotasks();
        expect(repo.loads, 2);
        async.elapse(const Duration(seconds: 61));
        leaveAndReturn();
        leaveAndReturn();
        repo.gate!.complete();
        async.elapse(const Duration(seconds: 120));
        expect(repo.loads, 3);
        container.dispose();
      });
    });

    test('pulls nothing within a minute of a sync that stopped, with a backup too new or too large', () {
      for (final tooLarge in [false, true]) {
        final repo = _CountingRepo(
          user: _me,
          remote: tooLarge ? _otherDevice() : {..._otherDevice(), 'version': kProgressFormat + 1},
        );
        fakeAsync((async) {
          final container = containerFor(repo);
          async.elapse(const Duration(seconds: 1));
          // The first sync backs up the streak the backup lacked, where it can.
          final saves = repo.saves;
          if (tooLarge) {
            // Hundreds of long notes: more than the server takes, until the
            // reader shortens them.
            for (var verse = 1; verse <= 250; verse++) {
              container
                  .read(annotationsProvider.notifier)
                  .setNote(BookVerse('Genesis', VerseRef(1 + verse ~/ 30, 1 + verse % 30)), '${'א' * 2000} $verse');
            }
            async.elapse(ProgressSync.pushDelay);
            expect(container.read(syncTooLargeProvider), isTrue);
          } else {
            expect(container.read(syncBlockedByNewerFormatProvider), isTrue);
          }
          async.elapse(const Duration(minutes: 2));
          final loads = repo.loads;

          // Switching to another window and back, again and again.
          for (var i = 0; i < 20; i++) {
            leaveAndReturn();
            async.elapse(const Duration(seconds: 2));
          }
          expect(repo.loads, loads + 1, reason: 'one pull, then none within the minute (too large: $tooLarge)');
          expect(repo.saves, saves, reason: 'nothing is saved over the backup');

          async.elapse(const Duration(minutes: 1));
          leaveAndReturn();
          async.flushMicrotasks();
          expect(repo.loads, loads + 2, reason: 'a minute later it tries again (too large: $tooLarge)');
          container.dispose();
        });
      }
    });

    test('pulls nothing with backup turned off', () {
      final repo = _CountingRepo(user: _me, remote: _otherDevice());
      fakeAsync((async) {
        final container = containerFor(repo);
        async.elapse(const Duration(seconds: 120));
        final loads = repo.loads;
        container.read(settingsProvider.notifier).update((s) => s.copyWith(cloudSync: false));
        async.flushMicrotasks();

        leaveAndReturn();
        async.elapse(const Duration(seconds: 120));
        expect(repo.loads, loads);
        container.dispose();
      });
    });
  });

  test('a change is pushed at once as the app goes to the background', () {
    addTearDown(() {
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    });
    final repo = _CountingRepo(user: _me, remote: _otherDevice());
    fakeAsync((async) {
      final container = containerFor(repo);
      async.elapse(const Duration(seconds: 120));
      final saves = repo.saves;

      // Marked on a phone that is locked straight away: suspended in the
      // background, it would push nothing until it is next opened.
      container.read(progressProvider.notifier).markUnit(_week, 1, ReadingPass.mikrah1, _d2);
      async.elapse(const Duration(seconds: 1));
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      async.flushMicrotasks();
      expect(repo.saves, saves, reason: 'not yet hidden');
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      async.flushMicrotasks();
      expect(repo.saves, saves + 1, reason: 'pushed as the app is hidden');
      expect(remoteOf(repo).week(_week).isUnitDone(1, ReadingPass.mikrah1), isTrue);

      // Nothing more is pushed for it, and with nothing waiting, hiding
      // again pushes nothing.
      async.elapse(const Duration(seconds: 10));
      binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      async.elapse(const Duration(seconds: 10));
      expect(repo.saves, saves + 1);
      container.dispose();
    });
  });

  test('a change made while a sync is saving is pushed after it', () {
    final repo = _CountingRepo(user: _me, remote: _otherDevice());
    fakeAsync((async) {
      final container = containerFor(repo);
      final progress = container.read(progressProvider.notifier);
      async.elapse(const Duration(seconds: 120));
      final saves = repo.saves;

      // On a slow network, the sync for this change stalls while saving...
      repo.saveGate = Completer<void>();
      progress.markUnit(_week, 2, ReadingPass.mikrah1, _d2);
      async.elapse(ProgressSync.pushDelay + const Duration(seconds: 1));
      expect(repo.saves, saves + 1);

      // ...and this one rests and asks to be pushed before that sync ends.
      progress.markUnit(_week, 3, ReadingPass.mikrah1, _d2);
      async.elapse(ProgressSync.pushDelay + const Duration(seconds: 1));
      repo.saveGate!.complete();
      async.elapse(const Duration(seconds: 120));

      expect(repo.saves, saves + 2);
      expect(remoteOf(repo).week(_week).isUnitDone(3, ReadingPass.mikrah1), isTrue);
      expect(remoteOf(repo), container.read(progressProvider));
      container.dispose();
    });
  });

  test('another account signing in during a sync gets its own pull, and its backup is kept', () async {
    const other = CommunityUser(id: 'other', email: 'other@example.com');
    final otherBackup = ProgressState(weeks: {
      _week: WeekProgress(weekId: _week).withUnit(3, ReadingPass.targum, _d2),
    }).toJson();
    await prefs.setString(
      ProgressController.storageKey,
      jsonEncode(ProgressState(weeks: {_week: WeekProgress(weekId: _week).withUnit(1, ReadingPass.mikrah2, _d2)})
          .toJson()),
    );
    final mine = _otherDevice();
    final repo = _CountingRepo(user: _me, remote: mine)..backups[other.id] = otherBackup;
    fakeAsync((async) {
      repo.gate = Completer<void>();
      final container = containerFor(repo);
      async.elapse(const Duration(seconds: 1));
      expect(repo.loads, 1, reason: "the first account's pull is in flight");

      repo.announce(other);
      async.elapse(const Duration(seconds: 1));
      repo.gate!.complete();
      async.elapse(const Duration(seconds: 120));

      final local = container.read(progressProvider);
      expect(local.week(_week).isUnitDone(1, ReadingPass.mikrah2), isTrue, reason: 'kept from this device');
      expect(local.week(_week).isUnitDone(3, ReadingPass.targum), isTrue, reason: "pulled from the new account");
      expect(local.week(_week).isUnitDone(0, ReadingPass.mikrah1), isFalse, reason: "the first account's stays out");
      expect(ProgressState.fromJson(repo.backups[other.id]!), local, reason: 'merged into its own backup');
      expect(remoteOf(repo), ProgressState.fromJson(mine), reason: "the first account's is untouched");
      container.dispose();
    });
  });

  test("an account's first backup uploads this device's progress", () {
    final repo = _CountingRepo(user: _me);
    fakeAsync((async) {
      final container = containerFor(repo);
      container.read(progressProvider.notifier).markUnit(_week, 1, ReadingPass.mikrah2, _d2);
      async.elapse(const Duration(seconds: 120));

      expect(repo.saves, 1);
      expect(remoteOf(repo), container.read(progressProvider));
      expect(remoteOf(repo).week(_week).isUnitDone(1, ReadingPass.mikrah2), isTrue);
      container.dispose();
    });
  });

  test('turning backup off and on again pulls once more, and pushes what changed meanwhile', () {
    final repo = _CountingRepo(user: _me, remote: _otherDevice());
    fakeAsync((async) {
      final container = containerFor(repo);
      async.elapse(const Duration(seconds: 120));
      final (loads, saves) = (repo.loads, repo.saves);
      final settings = container.read(settingsProvider.notifier);

      settings.update((s) => s.copyWith(cloudSync: false));
      container.read(progressProvider.notifier).markUnit(_week, 4, ReadingPass.targum, _d2);
      async.elapse(const Duration(seconds: 120));
      expect((repo.loads, repo.saves), (loads, saves), reason: 'backup is off');

      settings.update((s) => s.copyWith(cloudSync: true));
      async.elapse(const Duration(seconds: 120));
      expect(repo.loads, loads + 1);
      expect(repo.saves, saves + 1);
      expect(remoteOf(repo).week(_week).isUnitDone(4, ReadingPass.targum), isTrue);
      container.dispose();
    });
  });

  test('a sync cut short by disposal stops quietly', () {
    final repo = _CountingRepo(user: _me, remote: _otherDevice());
    fakeAsync((async) {
      repo.gate = Completer<void>();
      final container = containerFor(repo);
      async.elapse(const Duration(seconds: 1));
      expect(repo.loads, 1, reason: 'the sign-in pull is in flight');
      bool? result;
      container.read(progressSyncProvider.notifier).syncNow().then((ok) => result = ok);
      container.dispose();
      repo.gate!.complete();
      async.elapse(const Duration(seconds: 120));
      expect(result, isFalse);
      expect(repo.saves, 0);
    });
  });

  test('removals stay removed through syncing', () {
    final repo = _CountingRepo(user: _me, remote: _otherDevice());
    fakeAsync((async) {
      final container = containerFor(repo);
      final progress = container.read(progressProvider.notifier);
      ProgressState local() => container.read(progressProvider);
      WeekProgress week() => local().week(_week);
      void settle() {
        async.elapse(const Duration(seconds: 10));
        expect(remoteOf(repo), local(), reason: 'synced');
      }

      settle();
      expect(week().isUnitDone(0, ReadingPass.mikrah1), isTrue, reason: 'pulled from the other device');

      progress.markUnit(_week, 0, ReadingPass.mikrah1, null);
      settle();
      expect(week().isUnitDone(0, ReadingPass.mikrah1), isFalse, reason: 'marked as not read');

      progress.markHaftarah(_week, _d1);
      settle();
      progress.markHaftarah(_week, null);
      settle();
      expect(week().haftarah, isNull, reason: 'the haftarah marked as not read');

      progress.markAliyah(_week, 2, _d2);
      settle();
      final before = week();
      progress.clearWeek(_week);
      settle();
      expect(week().isStarted, isFalse, reason: 'cleared');
      progress.restoreWeek(_week, before);
      settle();
      expect(week().isAliyahDone(2), isTrue, reason: 'the clear undone, after it had synced');

      progress.addPause(_d1, _d1.addDays(9));
      settle();
      progress.endPause(_d2);
      settle();
      expect(local().pauses.single.end, _d1, reason: 'ended early');

      progress.reset(everywhere: true);
      settle();
      expect(local().weeks, isEmpty, reason: 'reset');
      expect(local().pauses, isEmpty);
      container.dispose();
    });
  });

  test('a reading given a new day keeps it through syncing, against a device with the old day', () {
    final tablet = _otherDevice();
    final repo = _CountingRepo(user: _me, remote: tablet);
    fakeAsync((async) {
      final container = containerFor(repo);
      final progress = container.read(progressProvider.notifier);
      WeekProgress week() => container.read(progressProvider).week(_week);
      async.elapse(const Duration(seconds: 10));
      expect(week().units[0][0], _d1, reason: 'pulled from the tablet');

      // Corrected here before the change was pushed: the cloud still had
      // the first day when the two met.
      async.elapse(const Duration(seconds: 1));
      progress.markUnit(_week, 0, ReadingPass.mikrah1, null);
      async.elapse(const Duration(seconds: 1));
      progress.markUnit(_week, 0, ReadingPass.mikrah1, _d2);
      async.elapse(const Duration(seconds: 10));
      expect(week().units[0][0], _d2);
      expect(remoteOf(repo).week(_week).units[0][0], _d2);

      // The tablet, still holding the first day, syncs next, and then this
      // device again.
      repo.remote = mergeProgress(ProgressState.fromJson(tablet), remoteOf(repo)).toJson();
      expect(remoteOf(repo).week(_week).units[0][0], _d2, reason: 'the tablet takes the new day');
      container.read(progressSyncProvider.notifier).syncNow();
      async.elapse(const Duration(seconds: 10));
      expect(week().units[0][0], _d2);
      container.dispose();
    });
  });

  test('a reset made on another device restarts the join date here', () async {
    final joined = _d1.addDays(-90);
    final reset = DateTime(2026, 10, 12, 9);
    await prefs.setString(
      SettingsController.storageKey,
      jsonEncode(AppSettings(onboardingComplete: true, cloudSync: true, joinDate: joined).toJson()),
    );
    final wallClock = ProgressClock.nowMs;
    addTearDown(() => ProgressClock.nowMs = wallClock);
    // Read here in the summer, before the reset.
    ProgressClock.nowMs = () => DateTime(2026, 7, 20).millisecondsSinceEpoch;
    await prefs.setString(
      ProgressController.storageKey,
      jsonEncode(ProgressState(weeks: {'5786:44': WeekProgress(weekId: '5786:44').withAll(joined)}).toJson()),
    );
    ProgressClock.nowMs = () => reset.add(const Duration(days: 2)).millisecondsSinceEpoch;
    final repo = _CountingRepo(user: _me, remote: ProgressState(resetAt: reset.millisecondsSinceEpoch).toJson());
    fakeAsync((async) {
      final container = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        backendProvider.overrideWithValue(Backend(repo)),
        todayProvider.overrideWith(() => _FixedToday(LocalDate(2026, 10, 14))),
      ]);
      container.listen(progressSyncProvider, (_, _) {});
      async.elapse(const Duration(seconds: 120));

      expect(container.read(progressProvider).weeks, isEmpty, reason: 'the reset reached this device');
      expect(container.read(settingsProvider).joinDate, LocalDate(2026, 10, 12));
      final summary = container.read(streakSummaryProvider);
      expect(summary.weeks, hasLength(1));
      expect(summary.weeks.where((w) => w.status == WeekStatus.missed), isEmpty);
      container.dispose();
    });
  });

  group('the join date', () {
    /// Settings with backup on, for a reader who joined on [joined].
    Future<void> joinedOn(LocalDate? joined) => prefs.setString(
          SettingsController.storageKey,
          jsonEncode(AppSettings(onboardingComplete: joined != null, cloudSync: true, joinDate: joined).toJson()),
        );

    /// The device, on [_toldotWednesday].
    ProviderContainer device(_CountingRepo repo) {
      final c = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        backendProvider.overrideWithValue(Backend(repo)),
        todayProvider.overrideWith(() => _FixedToday(_toldotWednesday)),
      ]);
      c.listen(progressSyncProvider, (_, _) {});
      return c;
    }

    test('comes with the backup to a new device, and the streak with it', () async {
      final backup = _fiveWeeks();
      final repo = _CountingRepo(user: _me, remote: syncPayload(backup, _simchatTorah));
      // Set up on Monday.
      await joinedOn(LocalDate(2026, 11, 9));
      fakeAsync((async) {
        final container = device(repo);
        expect(container.read(streakSummaryProvider).parshaStreak, 0, reason: 'nothing read since Monday');
        async.elapse(const Duration(seconds: 120));
        expect(container.read(progressProvider), backup);
        expect(container.read(settingsProvider).joinDate, _simchatTorah);
        expect(container.read(streakSummaryProvider).parshaStreak, 5);
        expect(repo.saves, 1, reason: 'the streak alone, which the backup lacked');
        expect((repo.remote!['streak'] as Map)['weeks'], 5);
        expect(remoteOf(repo), backup);
        container.dispose();
      });
    });

    test('the backup carries the streak shown, saved again when only the streak changes', () async {
      final repo = _CountingRepo(user: _me, remote: syncPayload(_fiveWeeks(), _simchatTorah));
      await joinedOn(_simchatTorah);
      ProviderContainer on(LocalDate day) {
        final c = ProviderContainer(overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          backendProvider.overrideWithValue(Backend(repo)),
          todayProvider.overrideWith(() => _FixedToday(day)),
        ]);
        c.listen(progressSyncProvider, (_, _) {});
        return c;
      }

      fakeAsync((async) {
        final wednesday = on(_toldotWednesday);
        async.elapse(const Duration(seconds: 120));
        expect(repo.saves, 1);
        expect(repo.remote!['streak'], {
          'days': wednesday.read(streakSummaryProvider).daysOnTrack,
          'weeks': 5,
          'longestDays': wednesday.read(streakSummaryProvider).longestDaysOnTrack,
          'longestWeeks': 5,
          'asOf': '2026-11-11',
        });
        wednesday.dispose();

        // The same day, on opening again: nothing new to save.
        final again = on(_toldotWednesday);
        async.elapse(const Duration(seconds: 120));
        expect(repo.saves, 1);
        again.dispose();

        // A week on, with nothing read since: the streak is counted again,
        // as of that day, and backed up, though nothing else changed.
        final later = on(_toldotWednesday.addDays(7));
        async.elapse(const Duration(seconds: 120));
        expect(repo.saves, 2);
        expect(repo.remote!['streak'], syncStreak(later.read(streakSummaryProvider), later.read(todayProvider)));
        expect((repo.remote!['streak'] as Map)['asOf'], '2026-11-18');
        expect(remoteOf(repo), later.read(progressProvider));
        later.dispose();
      });
    });

    test('is added to a backup saved by an earlier version, from its earliest reading', () async {
      final repo = _CountingRepo(user: _me, remote: _fiveWeeks().toJson());
      await joinedOn(LocalDate(2026, 11, 9));
      fakeAsync((async) {
        final container = device(repo);
        async.elapse(const Duration(seconds: 120));
        final bereshitFriday = LocalDate(2026, 10, 9);
        expect(container.read(settingsProvider).joinDate, bereshitFriday);
        expect(container.read(streakSummaryProvider).parshaStreak, 5);
        expect(repo.saves, 1);
        expect(syncPayloadJoinDate(repo.remote!), bereshitFriday);
        expect(remoteOf(repo), container.read(progressProvider));
        container.dispose();
      });
    });

    test("isn't moved by this device's own readings, backed up by an earlier version", () async {
      // Joined on the Monday of Toldot, and marked Rishon read on Sunday, the
      // week's first day; an earlier version backed that up, without the
      // join date.
      final monday = LocalDate(2026, 11, 9);
      final here = ProgressState(weeks: {
        '5787:6': WeekProgress(weekId: '5787:6').withAliyah(0, LocalDate(2026, 11, 8)),
      });
      await prefs.setString(ProgressController.storageKey, jsonEncode(here.toJson()));
      final repo = _CountingRepo(user: _me, remote: here.toJson());
      await joinedOn(monday);
      fakeAsync((async) {
        final container = device(repo);
        async.elapse(const Duration(seconds: 120));
        expect(container.read(settingsProvider).joinDate, monday);
        expect(syncPayloadJoinDate(repo.remote!), monday, reason: "this device's, backed up");
        expect(remoteOf(repo), here);
        container.dispose();
      });
    });

    test('is backed up when it is first set, as onboarding ends', () async {
      final repo = _CountingRepo(user: _me);
      await joinedOn(null);
      fakeAsync((async) {
        final container = device(repo);
        async.elapse(const Duration(seconds: 120));
        expect(repo.saves, 1, reason: 'the first backup');
        expect(syncPayloadJoinDate(repo.remote!), isNull);

        container.read(settingsProvider.notifier).update((s) => s.copyWith(joinDate: _toldotWednesday));
        async.elapse(const Duration(seconds: 120));
        expect(repo.saves, 2);
        expect(syncPayloadJoinDate(repo.remote!), _toldotWednesday);
        container.dispose();
      });
    });

    test("from another device doesn't move this one's when it is later", () async {
      final repo = _CountingRepo(user: _me, remote: syncPayload(_fiveWeeks(), LocalDate(2026, 11, 9)));
      await joinedOn(_simchatTorah);
      fakeAsync((async) {
        final container = device(repo);
        async.elapse(const Duration(seconds: 120));
        expect(container.read(settingsProvider).joinDate, _simchatTorah);
        expect(syncPayloadJoinDate(repo.remote!), _simchatTorah, reason: 'the earlier one, backed up');
        container.dispose();
      });
    });
  });

  testWidgets('with the demo backend, a cleared week stays cleared, and so does its undo', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final demo = DemoForumRepository();
    await demo.verifyCode(_me.email!, '123456');
    final c = await pumpApp(
      tester,
      settings: const AppSettings(onboardingComplete: true, cloudSync: true),
      progress: ProgressState(weeks: {_week: WeekProgress(weekId: _week).withAliyah(0, _d1).withAliyah(1, _d2)}),
      now: DateTime(2026, 10, 12, 10),
      forums: demo,
    );
    c.read(routerProvider).go('/week/$_week');
    await tester.pumpAndSettle();
    WeekProgress week() => c.read(progressProvider).week(_week);
    Future<WeekProgress> backedUp() async => ProgressState.fromJson((await demo.loadProgress())!).week(_week);
    expect((await backedUp()).isAliyahDone(1), isTrue, reason: 'backed up when the app started');

    Future<void> clearWeek() async {
      await tester.tap(find.descendant(of: find.byType(AppBar), matching: find.byTooltip('More options')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Clear this week’s progress'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Clear'));
      await tester.pumpAndSettle();
    }

    await clearWeek();
    expect(week().isStarted, isFalse);
    await tester.tap(find.widgetWithText(SnackBarAction, 'Undo'));
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(week().isAliyahDone(1), isTrue, reason: 'undone');
    expect((await backedUp()).isAliyahDone(1), isTrue);

    await clearWeek();
    await tester.pump(const Duration(seconds: 10));
    await tester.pumpAndSettle();
    expect(week().isStarted, isFalse, reason: 'still cleared after syncing');
    expect((await backedUp()).isStarted, isFalse);
  });

  for (final (backup, signedIn) in [(true, true), (false, true), (true, false)]) {
    final everywhere = backup && signedIn;
    final setup = !backup ? 'off' : (signedIn ? 'on' : 'on but signed out');
    testWidgets('resetting all progress with backup $setup ${everywhere ? 'reaches the backup' : 'stays on this device'}',
        (tester) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final demo = DemoForumRepository();
      await demo.verifyCode(_me.email!, '123456');
      await demo.saveProgress(_otherDevice());
      if (!signedIn) await demo.signOut();
      final c = await pumpApp(
        tester,
        settings: AppSettings(onboardingComplete: true, cloudSync: backup, joinDate: _d1.addDays(-90)),
        progress: ProgressState(weeks: {_week: WeekProgress(weekId: _week).withAliyah(1, _d2)}),
        now: DateTime(2026, 10, 12, 10),
        forums: demo,
      );
      expect(c.read(streakSummaryProvider).weeks.where((w) => w.status == WeekStatus.missed), isNotEmpty);
      c.read(routerProvider).go('/settings/data');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reset all progress'));
      await tester.pumpAndSettle();
      expect(
        find.text(everywhere
            ? 'This erases your reading history and streaks on this device, in your backup, and on your other '
                'devices when they next sync. It can’t be undone.'
            : 'This erases your reading history and streaks on this device. It can’t be undone.'),
        findsOneWidget,
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Reset all progress'));
      await tester.pump(const Duration(seconds: 10));
      await tester.pumpAndSettle();

      final local = c.read(progressProvider);
      expect(local.weeks, isEmpty);
      expect(c.read(settingsProvider).joinDate, _d2, reason: 'starting afresh today');
      expect(c.read(streakSummaryProvider).weeks, hasLength(1));
      expect(c.read(streakSummaryProvider).weeks.single.status, WeekStatus.inProgress);
      if (!signedIn) {
        expect(local.resetAt, 0, reason: "the reset can't reach a backup no one is signed in to");
        await demo.verifyCode(_me.email!, '123456');
      }
      final backedUp = ProgressState.fromJson((await demo.loadProgress())!);
      if (everywhere) {
        expect(local.resetAt, greaterThan(0));
        expect(backedUp, local);
      } else {
        expect(local.resetAt, 0, reason: 'nothing marks the reset for other devices');
        expect(backedUp.week(_week).isUnitDone(0, ReadingPass.mikrah1), isTrue, reason: 'the backup is untouched');
      }
    });
  }

  test('a week this version cannot read survives a sync untouched', () {
    final remote = _otherDevice();
    remote['weeks'] = {...remote['weeks'] as Map<String, dynamic>, '5787:9': {'u': 'done'}};
    final repo = _CountingRepo(user: _me, remote: remote);
    fakeAsync((async) {
      final container = containerFor(repo);
      container.read(progressProvider.notifier).markUnit(_week, 1, ReadingPass.mikrah2, _d2);
      async.elapse(const Duration(seconds: 120));

      expect(repo.loads, 1);
      expect(repo.saves, 1);
      expect((repo.remote!['weeks'] as Map)['5787:9'], {'u': 'done'});
      final local = container.read(progressProvider);
      expect(local.unknownWeeks, {'5787:9': {'u': 'done'}});
      expect(local.week(_week).isUnitDone(0, ReadingPass.mikrah1), isTrue);
      expect(remoteOf(repo), local);
      container.dispose();
    });
  });

  Map<String, String> corruptBackups() => {
        for (final k in prefs.getKeys().where((k) => k.startsWith(ProgressController.corruptBackupPrefix)))
          k: prefs.getString(k)!,
      };

  test('a week this version cannot read is copied before a readable one from the backup replaces it', () async {
    await prefs.setString(
      ProgressController.storageKey,
      jsonEncode(const ProgressState(unknownWeeks: {
        _week: {'u': 'x'},
      }).toJson()),
    );
    final repo = _CountingRepo(user: _me, remote: _otherDevice());
    fakeAsync((async) {
      final container = containerFor(repo);
      async.elapse(const Duration(seconds: 120));
      final local = container.read(progressProvider);
      expect(local.week(_week).isUnitDone(0, ReadingPass.mikrah1), isTrue);
      expect(local.unknownWeeks, isEmpty);
      expect(corruptBackups().values, ['{"weeks":{"$_week":{"u":"x"}}}']);
      container.dispose();
    });
  });

  test('of two different unreadable copies of one week, the one left out is copied', () async {
    await prefs.setString(
      ProgressController.storageKey,
      jsonEncode(const ProgressState(unknownWeeks: {
        '5787:3': {'u': 'x'},
      }).toJson()),
    );
    final remote = _otherDevice();
    remote['weeks'] = {
      ...remote['weeks'] as Map<String, dynamic>,
      '5787:3': {'u': 'a'},
    };
    final repo = _CountingRepo(user: _me, remote: remote);
    fakeAsync((async) {
      final container = containerFor(repo);
      async.elapse(const Duration(seconds: 120));
      expect(container.read(progressProvider).unknownWeeks, {
        '5787:3': {'u': 'a'},
      });
      expect(corruptBackups().values, ['{"weeks":{"5787:3":{"u":"x"}}}']);
      expect(remoteOf(repo), container.read(progressProvider));
      container.dispose();
    });
  });

  test('a backup from a newer version is neither merged nor overwritten', () {
    final newer = {..._otherDevice(), 'version': kProgressFormat + 1};
    final original = jsonEncode(newer);
    final repo = _CountingRepo(user: _me, remote: newer);
    fakeAsync((async) {
      final container = containerFor(repo);
      async.elapse(const Duration(seconds: 120));
      expect(repo.loads, 1);
      expect(repo.saves, 0);
      expect(container.read(progressProvider), const ProgressState(), reason: 'nothing was merged');
      expect(container.read(syncBlockedByNewerFormatProvider), isTrue);
      expect(container.read(progressSyncProvider), isNull, reason: 'it never synced');

      // Changes made here are kept here, and not pushed over the backup.
      container.read(progressProvider.notifier).markUnit(_week, 1, ReadingPass.mikrah2, _d2);
      async.elapse(const Duration(seconds: 120));
      expect(repo.loads, 2);
      bool? result;
      container.read(progressSyncProvider.notifier).syncNow().then((ok) => result = ok);
      async.flushMicrotasks();
      expect(result, isFalse);
      expect(repo.saves, 0);
      expect(jsonEncode(repo.remote), original);
      expect(container.read(progressProvider).week(_week).isUnitDone(1, ReadingPass.mikrah2), isTrue);

      // Once the backup is in a format this version reads, syncing resumes.
      repo.remote = _otherDevice();
      container.read(progressSyncProvider.notifier).syncNow().then((ok) => result = ok);
      async.flushMicrotasks();
      expect(result, isTrue);
      expect(container.read(syncBlockedByNewerFormatProvider), isFalse);
      expect(repo.saves, 1);
      container.dispose();
    });
  });

  test('notes too long for the server are not sent, and the reader is told why', () {
    final repo = _CountingRepo(user: _me, remote: _otherDevice());
    fakeAsync((async) {
      final container = containerFor(repo);
      async.elapse(const Duration(seconds: 120));
      final saves = repo.saves;
      // Hundreds of long notes: more than the server takes.
      final long = 'א' * 2000;
      for (var verse = 1; verse <= 250; verse++) {
        container.read(annotationsProvider.notifier).setNote(BookVerse('Genesis', VerseRef(1 + verse ~/ 30, 1 + verse % 30)), '$long $verse');
      }
      bool? result;
      container.read(progressSyncProvider.notifier).syncNow().then((ok) => result = ok);
      async.flushMicrotasks();
      expect(result, isFalse);
      expect(repo.saves, saves, reason: 'every save would fail');
      expect(container.read(syncTooLargeProvider), isTrue);
      expect(syncPayloadAnnotations(repo.remote!).inTorah, isEmpty, reason: 'the backup is as it was');

      // Shortened, it is backed up again.
      for (var verse = 1; verse <= 250; verse++) {
        container.read(annotationsProvider.notifier).setNote(BookVerse('Genesis', VerseRef(1 + verse ~/ 30, 1 + verse % 30)), 'Short $verse');
      }
      container.read(progressSyncProvider.notifier).syncNow().then((ok) => result = ok);
      async.flushMicrotasks();
      expect(result, isTrue);
      expect(container.read(syncTooLargeProvider), isFalse);
      expect(syncPayloadAnnotations(repo.remote!).inTorah, hasLength(250));
      container.dispose();
    });
  });

  test('a payload is too large by its encoded size', () {
    expect(syncPayloadTooLarge(syncPayload(const ProgressState(), null)), isFalse);
    final notes = Annotations.fromJson({
      for (var i = 1; i <= 230; i++) 'Genesis 1:$i': {'b': false, 'n': 'א' * 2000, 'u': i},
    });
    // 230 notes of 2,000 Hebrew letters, two bytes each in UTF-8.
    expect(syncPayloadTooLarge(syncPayload(const ProgressState(), null, annotations: notes)), isTrue);
  });

  testWidgets('the account screen asks for an update when the backup is newer', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const message = 'Your backup was saved by a newer version of the app. Update the app to keep syncing.';
    final demo = DemoForumRepository();
    await demo.verifyCode(_me.email!, '123456');
    await demo.saveProgress({..._otherDevice(), 'version': kProgressFormat + 1});
    final c = await pumpApp(
      tester,
      settings: const AppSettings(onboardingComplete: true, cloudSync: true),
      forums: demo,
    );
    c.read(routerProvider).go('/community/account');
    await tester.pumpAndSettle();
    expect(find.text(message), findsOneWidget);

    await tester.tap(find.byTooltip('Sync now'));
    await tester.pumpAndSettle();
    expect(find.text(message), findsNWidgets(2), reason: 'the notice, and the reply to Sync now');
    expect(c.read(progressProvider), const ProgressState());
  });

  testWidgets('the account screen says why notes too long for the server are not backed up', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const message = 'Your notes are too long to back up to your account, so nothing new is backed up. '
        'Shorten or delete some of them; a backup file, from Your data, keeps them all.';
    final demo = DemoForumRepository();
    await demo.verifyCode(_me.email!, '123456');
    final c = await pumpApp(
      tester,
      settings: const AppSettings(onboardingComplete: true, cloudSync: true),
      forums: demo,
      stored: {
        AnnotationsController.storageKey: jsonEncode({
          for (var i = 1; i <= 230; i++) 'Genesis 1:$i': {'b': false, 'n': 'א' * 2000, 'u': i},
        }),
      },
    );
    c.read(routerProvider).go('/community/account');
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Sync now'));
    await tester.pumpAndSettle();
    expect(find.text(message), findsNWidgets(2), reason: 'the notice, and the reply to Sync now');
    expect(await demo.loadProgress(), isNull, reason: 'nothing was sent');
  });

  testWidgets('a sync does not rebuild the app', (tester) async {
    final repo = _CountingRepo(user: _me, remote: _otherDevice());
    final container = await pumpApp(
      tester,
      settings: const AppSettings(onboardingComplete: true, cloudSync: true),
      forums: repo,
    );
    expect(repo.loads, 1);
    expect(container.read(progressSyncProvider), isNotNull);

    var rebuilds = 0;
    debugOnRebuildDirtyWidget = (element, _) {
      if (element.widget is ShnayimMikrahApp) rebuilds++;
    };
    addTearDown(() => debugOnRebuildDirtyWidget = null);
    var syncs = 0;
    container.listen(progressSyncProvider, (_, _) => syncs++);
    expect(await container.read(progressSyncProvider.notifier).syncNow(), isTrue);
    await tester.pump();
    expect(repo.loads, 2);
    expect(syncs, 1);
    expect(rebuilds, 0);
  });
}
