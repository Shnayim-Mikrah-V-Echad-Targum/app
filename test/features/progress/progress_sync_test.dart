import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shnayim_mikra/app/app.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/features/community/data/backend.dart';
import 'package:shnayim_mikra/features/community/data/community_providers.dart';
import 'package:shnayim_mikra/features/community/data/demo_forum_repository.dart';
import 'package:shnayim_mikra/features/community/data/forum_repository.dart';
import 'package:shnayim_mikra/features/community/data/models.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';

import '../../helpers.dart';

const _me = CommunityUser(id: 'me', email: 'me@example.com');
const _week = '5787:1';
final _d1 = LocalDate(2026, 10, 11);
final _d2 = LocalDate(2026, 10, 12);

/// An account whose progress backup lives in memory, reordered the way
/// Postgres jsonb stores it, and which counts every round trip.
class _CountingRepo extends Fake implements ForumRepository {
  _CountingRepo({this.user, this.remote});

  CommunityUser? user;
  final _users = StreamController<CommunityUser?>.broadcast();

  /// The backed-up progress JSON.
  Map<String, dynamic>? remote;

  /// When set, [loadProgress] waits for it, to hold a sync in flight.
  Completer<void>? gate;

  int loads = 0;
  int saves = 0;
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

  @override
  Future<Map<String, dynamic>?> loadProgress() async {
    loads++;
    await gate?.future;
    return remote == null ? null : _jsonb(remote) as Map<String, dynamic>;
  }

  @override
  Future<void> saveProgress(Map<String, dynamic> data) async {
    saves++;
    remote = _jsonb(jsonDecode(jsonEncode(data))) as Map<String, dynamic>;
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

/// Progress logged on another device and already backed up.
Map<String, dynamic> _otherDevice() => ProgressState(weeks: {
      _week: WeekProgress(weekId: _week).withUnit(0, ReadingPass.mikra1, _d1),
    }).toJson();

void main() {
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
      container.read(progressProvider.notifier).markUnit(_week, 1, ReadingPass.mikra2, _d2);
      async.elapse(const Duration(seconds: 120));

      // One pull and one push merge the two devices, and nothing repeats.
      expect(repo.loads, 1);
      expect(repo.saves, 1);
      final local = container.read(progressProvider);
      expect(local.week(_week).isUnitDone(0, ReadingPass.mikra1), isTrue, reason: 'pulled from the other device');
      expect(local.week(_week).isUnitDone(1, ReadingPass.mikra2), isTrue, reason: 'kept from this device');
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

      progress.markUnit(_week, 2, ReadingPass.mikra1, _d2);
      async.elapse(const Duration(seconds: 3));
      progress.markUnit(_week, 2, ReadingPass.mikra2, _d2);
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
      expect(container.read(progressProvider).week(_week).isUnitDone(0, ReadingPass.mikra1), isTrue);

      for (var i = 0; i < 3; i++) {
        // A fresh but equal user, as each refreshed session reports.
        repo.announce(CommunityUser(id: _me.id, email: _me.email));
        async.elapse(const Duration(minutes: 30));
      }
      expect(repo.loads, 1);
      expect(repo.saves, 0, reason: 'the cloud already held everything');
      expect(repo.profileLoads, 1);
      container.dispose();
    });
  });

  test('calls made during a sync share it', () {
    final repo = _CountingRepo(user: _me, remote: _otherDevice());
    fakeAsync((async) {
      final container = containerFor(repo);
      async.elapse(const Duration(seconds: 120));
      final loads = repo.loads;
      final sync = container.read(progressSyncProvider.notifier);

      repo.gate = Completer<void>();
      final first = sync.syncNow();
      final second = sync.syncNow();
      expect(identical(first, second), isTrue);
      async.flushMicrotasks();
      expect(repo.loads, loads + 1);

      final results = <bool>[];
      first.then(results.add);
      repo.gate!.complete();
      async.flushMicrotasks();
      expect(results, [true]);

      // Once it is done, the next call starts a fresh sync.
      sync.syncNow();
      async.flushMicrotasks();
      expect(repo.loads, loads + 2);
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

  test('a week this version cannot read survives a sync untouched', () {
    final remote = _otherDevice();
    remote['weeks'] = {...remote['weeks'] as Map<String, dynamic>, '5787:9': {'u': 'done'}};
    final repo = _CountingRepo(user: _me, remote: remote);
    fakeAsync((async) {
      final container = containerFor(repo);
      container.read(progressProvider.notifier).markUnit(_week, 1, ReadingPass.mikra2, _d2);
      async.elapse(const Duration(seconds: 120));

      expect(repo.loads, 1);
      expect(repo.saves, 1);
      expect((repo.remote!['weeks'] as Map)['5787:9'], {'u': 'done'});
      final local = container.read(progressProvider);
      expect(local.unknownWeeks, {'5787:9': {'u': 'done'}});
      expect(local.week(_week).isUnitDone(0, ReadingPass.mikra1), isTrue);
      expect(remoteOf(repo), local);
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
      container.read(progressProvider.notifier).markUnit(_week, 1, ReadingPass.mikra2, _d2);
      async.elapse(const Duration(seconds: 120));
      expect(repo.loads, 2);
      bool? result;
      container.read(progressSyncProvider.notifier).syncNow().then((ok) => result = ok);
      async.flushMicrotasks();
      expect(result, isFalse);
      expect(repo.saves, 0);
      expect(jsonEncode(repo.remote), original);
      expect(container.read(progressProvider).week(_week).isUnitDone(1, ReadingPass.mikra2), isTrue);

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

    await tester.tap(find.text('Sync now'));
    await tester.pumpAndSettle();
    expect(find.text(message), findsNWidgets(2), reason: 'the notice, and the reply to Sync now');
    expect(c.read(progressProvider), const ProgressState());
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
      if (element.widget is ShnayimMikraApp) rebuilds++;
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
