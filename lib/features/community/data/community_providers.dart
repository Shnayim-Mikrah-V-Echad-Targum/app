import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../progress/domain/progress_merge.dart';
import '../../progress/domain/progress_models.dart';
import 'backend.dart';
import 'models.dart';

/// The signed-in community user, if any.
final communityUserProvider = StreamProvider<CommunityUser?>((ref) async* {
  final repo = ref.watch(forumRepositoryProvider);
  yield repo.currentUser;
  yield* repo.userChanges;
});

final myProfileProvider = FutureProvider<Profile?>((ref) async {
  final user = await ref.watch(communityUserProvider.future);
  if (user == null) return null;
  return ref.watch(forumRepositoryProvider).myProfile();
});

final forumsProvider = FutureProvider<List<Forum>>((ref) => ref.watch(forumRepositoryProvider).forums());

final threadsProvider = FutureProvider.family<List<ThreadSummary>, int?>(
  (ref, forumId) => ref.watch(forumRepositoryProvider).threads(forumId: forumId),
);

final threadProvider = FutureProvider.family<ThreadSummary, String>(
  (ref, id) => ref.watch(forumRepositoryProvider).thread(id),
);

/// Posts in a thread, fetched again when the account changes: what the
/// reader has given todah to, and whom they have blocked, are their own.
final postsProvider = FutureProvider.family<List<Post>, String>((ref, threadId) {
  ref.watch(communityUserProvider.select((v) => v.value?.id));
  return ref.watch(forumRepositoryProvider).posts(threadId);
});

final blockedUsersProvider = FutureProvider<Set<String>>((ref) async {
  final user = await ref.watch(communityUserProvider.future);
  if (user == null) return <String>{};
  return ref.watch(forumRepositoryProvider).blockedUsers();
});

/// Posts reported in this session, whose Report action is hidden. They are
/// the account's own, so another account starts afresh.
class ReportedPostIds extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    ref.watch(communityUserProvider.select((v) => v.value?.id));
    return const {};
  }

  void add(String postId) => state = {...state, postId};
}

final reportedPostIdsProvider = NotifierProvider<ReportedPostIds, Set<String>>(ReportedPostIds.new);

/// Keeps reading progress backed up to the user's account (when they have
/// opted in): pulls and merges on sign-in, pushes a few seconds after any
/// change. Merging keeps every change made on either device, removals
/// included (see [mergeProgress]).
///
/// The state is the time of the last successful sync.
class ProgressSync extends Notifier<DateTime?> {
  /// How long progress must rest unchanged before it is pushed.
  static const pushDelay = Duration(seconds: 5);

  Timer? _debounce;

  /// The sync running now, and the one queued to run after it.
  Future<bool>? _inFlight;
  Future<bool>? _followUp;
  bool _applyingMerge = false;

  @override
  DateTime? build() {
    ref.onDispose(() => _debounce?.cancel());
    final enabled = ref.watch(settingsProvider.select((s) => s.cloudSync));
    // Only the account matters: a token refresh announces the same user again
    // and must not trigger another pull.
    final userId = ref.watch(communityUserProvider.select((u) => u.value?.id));
    if (!enabled || userId == null) return null;
    Future.microtask(syncNow);
    ref.listen(progressProvider, (_, _) {
      // The sync's own merge is pushed by that same sync.
      if (_applyingMerge) return;
      _debounce?.cancel();
      _debounce = Timer(pushDelay, syncNow);
    });
    return null;
  }

  /// Pulls, merges and pushes. Returns normally (with false) when offline or
  /// signed out.
  ///
  /// A call made while a sync is running may come too late for it: the sync
  /// may already have read this device's progress, or have started for
  /// another account. So one more sync runs when it ends, and every call made
  /// meanwhile shares that one.
  Future<bool> syncNow() {
    final running = _inFlight;
    if (running == null) return _start();
    return _followUp ??= running.then((_) {
      _followUp = null;
      // Anything started since the last one ended is recent enough.
      return _inFlight ?? _start();
    });
  }

  Future<bool> _start() => _inFlight = _sync().whenComplete(() => _inFlight = null);

  Future<bool> _sync() async {
    // The provider rebuilds with a new ref when backup is turned off or the
    // account changes, and that ends this sync. So does another account
    // signing in before the provider has heard of it: the repository saves
    // to whoever is signed in.
    final syncRef = ref;
    try {
      if (!syncRef.mounted) return false;
      final repo = syncRef.read(forumRepositoryProvider);
      final user = repo.currentUser?.id;
      if (user == null) return false;
      bool stale() => !syncRef.mounted || repo.currentUser?.id != user;

      final remoteJson = await repo.loadProgress();
      if (stale()) return false;
      // A newer version of the app has backed up progress in a format this
      // one can't fully read: merging and pushing could lose some of it.
      final blocked = remoteJson != null && ProgressState.formatOf(remoteJson) > kProgressFormat;
      syncRef.read(syncBlockedByNewerFormatProvider.notifier).set(blocked);
      if (blocked) return false;
      final remote = remoteJson == null ? null : ProgressState.fromJson(remoteJson);
      final local = syncRef.read(progressProvider);
      final merged = remote == null ? local : mergeProgress(local, remote);
      // Apply and upload only real changes: a no-op that looked like a change
      // would wake the progress listener above and sync again, forever.
      if (merged != local) {
        _applyingMerge = true;
        try {
          syncRef.read(progressProvider.notifier).replaceAll(merged);
        } finally {
          _applyingMerge = false;
        }
      }
      if (remote == null || merged != remote) {
        await repo.saveProgress(merged.toJson());
        if (stale()) return false;
      }
      state = DateTime.now();
      return true;
    } catch (_) {
      return false;
    }
  }
}

final progressSyncProvider = NotifierProvider<ProgressSync, DateTime?>(ProgressSync.new);

/// Whether syncing has stopped because the account's backup was written by a
/// newer version of the app. It clears when the setting or the account
/// changes, or when a later sync finds a backup this version can read.
class SyncBlockedByNewerFormat extends Notifier<bool> {
  @override
  bool build() {
    ref.watch(settingsProvider.select((s) => s.cloudSync));
    ref.watch(communityUserProvider.select((u) => u.value?.id));
    return false;
  }

  void set(bool blocked) => state = blocked;
}

final syncBlockedByNewerFormatProvider =
    NotifierProvider<SyncBlockedByNewerFormat, bool>(SyncBlockedByNewerFormat.new);
