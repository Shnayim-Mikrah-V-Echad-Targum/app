import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../progress/domain/progress_merge.dart';
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
class ProgressSync extends Notifier<DateTime?> {
  Timer? _debounce;
  String? _syncedUser;
  DateTime? _lastSync;

  @override
  DateTime? build() {
    ref.onDispose(() => _debounce?.cancel());
    final enabled = ref.watch(settingsProvider.select((s) => s.cloudSync));
    final user = ref.watch(communityUserProvider).value;
    if (!enabled || user == null) return null;
    if (_syncedUser != user.id) {
      _syncedUser = user.id;
      Future.microtask(syncNow);
    }
    ref.listen(progressProvider, (_, _) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(seconds: 5), syncNow);
    });
    return _lastSync;
  }

  /// Pulls, merges and pushes. Returns normally even when offline.
  Future<bool> syncNow() async {
    final repo = ref.read(forumRepositoryProvider);
    if (repo.currentUser == null) return false;
    try {
      final remote = await repo.loadProgress();
      final local = ref.read(progressProvider);
      final merged = remote == null ? local : mergeProgress(local, ProgressState.fromJson(remote));
      if (remote != null) ref.read(progressProvider.notifier).replaceAll(merged);
      await repo.saveProgress(merged.toJson());
      state = _lastSync = DateTime.now();
      return true;
    } catch (_) {
      return false;
    }
  }
}

final progressSyncProvider = NotifierProvider<ProgressSync, DateTime?>(ProgressSync.new);
