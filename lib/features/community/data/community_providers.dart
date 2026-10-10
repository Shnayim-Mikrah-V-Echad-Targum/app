import 'dart:async';
import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../progress/domain/progress_merge.dart';
import '../../progress/domain/progress_models.dart';
import 'backend.dart';
import 'forum_repository.dart';
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

/// Whether the demo's notice on the Community page has been dismissed. It
/// stays dismissed for the rest of the session; the other pages still say,
/// with their Demo tag, that the community is a demo.
class DemoBannerDismissed extends Notifier<bool> {
  @override
  bool build() => false;

  void dismiss() => state = true;
}

final demoBannerDismissedProvider = NotifierProvider<DemoBannerDismissed, bool>(DemoBannerDismissed.new);

/// A forum's threads as far as the reader has paged: every pinned thread,
/// then the others, newest activity first.
class ThreadsPage {
  const ThreadsPage(this.threads, {required this.hasMore});
  final List<ThreadSummary> threads;

  /// Whether more threads may follow the last of [threads].
  final bool hasMore;
}

/// The threads of a forum (or of every forum, for null): a page at first,
/// and the next as the reader asks ([loadMore]).
///
/// Fetched again (when invalidated, after a reply say), it shows as many
/// threads as before, so that none the reader had paged to drops out.
class ForumThreads extends AsyncNotifier<ThreadsPage> {
  ForumThreads(this.forumId);
  final int? forumId;

  /// How many unpinned threads are shown.
  int _unpinned = 0;
  Future<void>? _loadingMore;

  @override
  Future<ThreadsPage> build() async {
    final limit = max(ForumRepository.threadsPageSize, _unpinned);
    final list = await ref.watch(forumRepositoryProvider).threads(forumId: forumId, limit: limit + 1);
    return _shown(const [], list, limit);
  }

  /// [shown] and then [fetched], which holds up to [limit] unpinned threads
  /// and one more, fetched to learn whether any follow.
  ThreadsPage _shown(List<ThreadSummary> shown, List<ThreadSummary> fetched, int limit) {
    final more = fetched.where((t) => !t.pinned).length > limit;
    final ids = {for (final t in shown) t.id};
    final threads = [...shown, ...fetched.take(more ? fetched.length - 1 : fetched.length).where((t) => ids.add(t.id))];
    _unpinned = threads.where((t) => !t.pinned).length;
    return ThreadsPage(threads, hasMore: more);
  }

  /// Appends the next page of threads. Fails as the backend does (offline,
  /// say), for the caller to report.
  Future<void> loadMore() => _loadingMore ??= _loadMore().whenComplete(() => _loadingMore = null);

  Future<void> _loadMore() async {
    final current = state.value;
    // Pinned threads all come first: the page after is the last unpinned one's.
    final last = current?.threads.where((t) => !t.pinned).lastOrNull;
    if (state.isLoading || current == null || !current.hasMore || last == null) return;
    final pageRef = ref;
    const size = ForumRepository.threadsPageSize;
    final more = await pageRef
        .read(forumRepositoryProvider)
        .threads(forumId: forumId, after: (last.lastPostAt, last.id), limit: size + 1);
    // Fetched again meanwhile, from the start.
    if (!pageRef.mounted) return;
    state = AsyncData(_shown(current.threads, more, size));
  }
}

final threadsProvider = AsyncNotifierProvider.family<ForumThreads, ThreadsPage, int?>(ForumThreads.new);

final threadProvider = FutureProvider.family<ThreadSummary, String>(
  (ref, id) => ref.watch(forumRepositoryProvider).thread(id),
);

/// A thread's posts as far back as the reader has loaded, oldest first.
class ThreadPosts {
  const ThreadPosts(this.posts, {required this.hasEarlier});
  final List<Post> posts;

  /// Whether posts before the first of [posts] remain to be loaded.
  final bool hasEarlier;
}

/// The posts of a thread: the latest page at first, so that the newest reply
/// is never left out, and each earlier page as the reader asks
/// ([loadEarlier]).
///
/// Fetched again (when invalidated, after a reply say), it reaches back as
/// far as before, in as few requests as it can. It is fetched again too when
/// the account changes: what the reader has given todah to, and whom they
/// have blocked, are their own.
class ThreadPostsNotifier extends AsyncNotifier<ThreadPosts> {
  ThreadPostsNotifier(this.threadId);
  final String threadId;

  /// The most posts asked for in one request when fetching again: one less
  /// than the rows the server returns at most (max_rows in
  /// supabase/config.toml), for the one more fetched to learn whether any
  /// remain.
  static const refetchChunk = 400;

  /// The earliest post shown, and how many are.
  Post? _earliest;
  int _count = 0;
  Future<void>? _loadingEarlier;

  @override
  Future<ThreadPosts> build() async {
    ref.watch(communityUserProvider.select((v) => v.value?.id));
    final repo = ref.watch(forumRepositoryProvider);
    final earliest = _earliest;
    // The latest page, or as many posts as were shown, at once if it can.
    var page = await _page(repo, size: max(ForumRepository.postsPageSize, min(_count, refetchChunk)));
    final posts = [...page.posts];
    // Replies since may push the earliest shown further back.
    while (page.hasEarlier && earliest != null && Post.chronological(posts.first, earliest) > 0) {
      page = await _page(repo, before: posts.first, size: refetchChunk);
      posts.insertAll(0, page.posts);
    }
    var hasEarlier = page.hasEarlier;
    // No further back than before, though.
    final from = earliest == null ? -1 : posts.indexWhere((p) => Post.chronological(p, earliest) >= 0);
    if (from > 0) {
      posts.removeRange(0, from);
      hasEarlier = true;
    }
    return _shown(posts, hasEarlier: hasEarlier);
  }

  /// A page of [size] posts: those just before [before], or the latest. One
  /// more is fetched, to learn whether any remain before them.
  Future<ThreadPosts> _page(ForumRepository repo, {Post? before, int size = ForumRepository.postsPageSize}) async {
    final posts = await repo.posts(
      threadId,
      before: before == null ? null : (before.createdAt, before.id),
      limit: size + 1,
    );
    return posts.length > size ? ThreadPosts(posts.sublist(1), hasEarlier: true) : ThreadPosts(posts, hasEarlier: false);
  }

  ThreadPosts _shown(List<Post> posts, {required bool hasEarlier}) {
    _earliest = posts.firstOrNull;
    _count = posts.length;
    return ThreadPosts(posts, hasEarlier: hasEarlier);
  }

  /// Puts the page of posts before the first shown above it. Fails as the
  /// backend does (offline, say), for the caller to report.
  Future<void> loadEarlier() => _loadingEarlier ??= _loadEarlier().whenComplete(() => _loadingEarlier = null);

  Future<void> _loadEarlier() async {
    final current = state.value;
    final first = current?.posts.firstOrNull;
    if (state.isLoading || current == null || !current.hasEarlier || first == null) return;
    final pageRef = ref;
    final page = await _page(pageRef.read(forumRepositoryProvider), before: first);
    // Fetched again meanwhile.
    if (!pageRef.mounted) return;
    final shown = {for (final p in current.posts) p.id};
    state = AsyncData(_shown([...page.posts.where((p) => shown.add(p.id)), ...current.posts], hasEarlier: page.hasEarlier));
  }
}

final postsProvider = AsyncNotifierProvider.family<ThreadPostsNotifier, ThreadPosts, String>(ThreadPostsNotifier.new);

final blockedUsersProvider = FutureProvider<Set<String>>((ref) async {
  final user = await ref.watch(communityUserProvider.future);
  if (user == null) return <String>{};
  return ref.watch(forumRepositoryProvider).blockedUsers();
});

/// The members the reader has blocked, with their names, for managing the
/// list. Fetched again with [blockedUsersProvider].
final blockedMembersProvider = FutureProvider<List<(String id, String name)>>((ref) async {
  final blocked = await ref.watch(blockedUsersProvider.future);
  if (blocked.isEmpty) return const [];
  return ref.watch(forumRepositoryProvider).blockedMembers();
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
