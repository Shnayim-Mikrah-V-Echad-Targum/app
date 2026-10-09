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

final postsProvider = FutureProvider.family<List<Post>, String>(
  (ref, threadId) => ref.watch(forumRepositoryProvider).posts(threadId),
);

final blockedUsersProvider = FutureProvider<Set<String>>((ref) async {
  final user = await ref.watch(communityUserProvider.future);
  if (user == null) return <String>{};
  return ref.watch(forumRepositoryProvider).blockedUsers();
});

/// Keeps reading progress backed up to the user's account (when they have
/// opted in): pulls and merges on sign-in, pushes a few seconds after any
/// change. Merging never loses reading logged on either device.
///
/// The state is the time of the last successful sync.
class ProgressSync extends Notifier<DateTime?> {
  /// How long progress must rest unchanged before it is pushed.
  static const pushDelay = Duration(seconds: 5);

  Timer? _debounce;
  Future<bool>? _inFlight;
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
  /// signed out. Calls made while a sync is running share its result.
  Future<bool> syncNow() => _inFlight ??= _sync().whenComplete(() => _inFlight = null);

  Future<bool> _sync() async {
    try {
      if (!ref.mounted) return false;
      final repo = ref.read(forumRepositoryProvider);
      if (repo.currentUser == null) return false;
      final remoteJson = await repo.loadProgress();
      if (!ref.mounted) return false;
      // A newer version of the app has backed up progress in a format this
      // one can't fully read: merging and pushing could lose some of it.
      final blocked = remoteJson != null && ProgressState.formatOf(remoteJson) > kProgressFormat;
      ref.read(syncBlockedByNewerFormatProvider.notifier).set(blocked);
      if (blocked) return false;
      final remote = remoteJson == null ? null : ProgressState.fromJson(remoteJson);
      final local = ref.read(progressProvider);
      final merged = remote == null ? local : mergeProgress(local, remote);
      // Apply and upload only real changes: a no-op that looked like a change
      // would wake the progress listener above and sync again, forever.
      if (merged != local) {
        _applyingMerge = true;
        try {
          ref.read(progressProvider.notifier).replaceAll(merged);
        } finally {
          _applyingMerge = false;
        }
      }
      if (remote == null || merged != remote) {
        await repo.saveProgress(merged.toJson());
        if (!ref.mounted) return false;
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
