import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/features/community/data/backend.dart';
import 'package:shnayim_mikra/features/community/data/community_providers.dart';
import 'package:shnayim_mikra/features/community/data/demo_forum_repository.dart';
import 'package:shnayim_mikra/features/community/data/forum_repository.dart';
import 'package:shnayim_mikra/features/community/data/models.dart';

final _start = DateTime.utc(2026, 9, 1, 12);

/// A thread in the Divrei Torah forum (3) whose last post was [minutes]
/// after [_start].
ThreadSummary _thread(int id, {required int minutes, bool pinned = false}) => ThreadSummary(
      id: '$id',
      forumId: 3,
      title: 'Thread $id',
      kind: ThreadKind.discussion,
      authorName: 'Avraham',
      postCount: 1,
      lastPostAt: _start.add(Duration(minutes: minutes)),
      createdAt: _start,
      pinned: pinned,
    );

/// A post in thread 5000, written [minutes] after [_start].
Post _post(int id, {required int minutes}) => Post(
      id: '$id',
      threadId: '5000',
      authorId: 'demo-$id',
      authorName: 'Rivka',
      body: 'Post $id',
      createdAt: _start.add(Duration(minutes: minutes)),
    );

/// The demo with 40 pinned and 40 unpinned threads in an empty forum.
/// Several share a last post time, and their ids run from three digits to
/// two (101 and 98 among them), so that ties are broken by id as a number.
DemoForumRepository _manyThreads() => DemoForumRepository()
  ..seed(threads: [
    for (var i = 0; i < 40; i++) _thread(300 + i, minutes: i ~/ 3, pinned: true),
    for (var i = 0; i < 40; i++) _thread(200 - i * 3, minutes: i ~/ 4),
  ]);

/// A thread of 250 posts, several written in the same minute.
DemoForumRepository _longThread() => DemoForumRepository()
  ..seed(
    threads: [_thread(5000, minutes: 250).copyWith(postCount: 250)],
    posts: [for (var i = 0; i < 250; i++) _post(i + 1, minutes: i ~/ 3)],
  );

/// Counts the posts asked for in each request ([limits]).
class _CountingPosts extends DemoForumRepository {
  final limits = <int>[];

  @override
  Future<List<Post>> posts(String threadId, {(DateTime, String)? before, int limit = ForumRepository.postsPageSize}) {
    limits.add(limit);
    return super.posts(threadId, before: before, limit: limit);
  }
}

ProviderContainer _container(ForumRepository repo) {
  final c = ProviderContainer(overrides: [backendProvider.overrideWithValue(Backend(repo))]);
  addTearDown(c.dispose);
  return c;
}

void main() {
  group('threads', () {
    test('page 1 and 2 hold every thread once: pinned first, then newest activity', () async {
      final repo = _manyThreads();
      final first = await repo.threads(forumId: 3);
      expect(first.where((t) => t.pinned), hasLength(40));
      expect(first.where((t) => !t.pinned), hasLength(ForumRepository.threadsPageSize));
      expect(first.take(40).every((t) => t.pinned), isTrue);

      final last = first.last;
      final second = await repo.threads(forumId: 3, after: (last.lastPostAt, last.id));
      expect(second, hasLength(10));
      expect(second.every((t) => !t.pinned), isTrue);

      final all = [...first, ...second];
      expect({for (final t in all) t.id}, hasLength(80));
      expect(all, hasLength(80));
      final unpinned = all.where((t) => !t.pinned).toList();
      for (var i = 1; i < unpinned.length; i++) {
        final (a, b) = (unpinned[i - 1], unpinned[i]);
        expect(
          a.lastPostAt.isAfter(b.lastPostAt) || (a.lastPostAt == b.lastPostAt && int.parse(a.id) > int.parse(b.id)),
          isTrue,
          reason: '${a.id} before ${b.id}',
        );
      }

      expect(await repo.threads(forumId: 3, after: (second.last.lastPostAt, second.last.id)), isEmpty);
    });

    test('a new weekly thread is not pinned', () async {
      final repo = DemoForumRepository();
      final id = await repo.weeklyThread(parshaNumber: 1, hebrewYear: 5787, title: 'Bereshit · בראשית · 5787');
      expect((await repo.thread(id)).pinned, isFalse);
    });

    test('pages on as asked, and fetched again shows as many', () async {
      final c = _container(_manyThreads());
      final provider = threadsProvider(3);
      var page = await c.read(provider.future);
      expect(page.threads, hasLength(70));
      expect(page.hasMore, isTrue);

      await c.read(provider.notifier).loadMore();
      page = c.read(provider).requireValue;
      expect(page.threads, hasLength(80));
      expect(page.hasMore, isFalse);

      c.invalidate(provider);
      page = await c.read(provider.future);
      expect(page.threads, hasLength(80));
      expect({for (final t in page.threads) t.id}, hasLength(80));
      expect(page.hasMore, isFalse);
    });
  });

  group('posts', () {
    test('the latest page reads oldest first, and earlier pages lead up to it', () async {
      final repo = _longThread();
      final latest = await repo.posts('5000');
      expect(latest, hasLength(ForumRepository.postsPageSize));
      expect(latest.first.id, '151');
      expect(latest.last.id, '250');

      final earlier = await repo.posts('5000', before: (latest.first.createdAt, latest.first.id));
      expect([earlier.first.id, earlier.last.id], ['51', '150']);
      final earliest = await repo.posts('5000', before: (earlier.first.createdAt, earlier.first.id));
      expect([earliest.first.id, earliest.last.id], ['1', '50']);
      expect(await repo.posts('5000', before: (earliest.first.createdAt, earliest.first.id)), isEmpty);

      expect([for (final p in [...earliest, ...earlier, ...latest]) p.id], [for (var i = 1; i <= 250; i++) '$i']);
    });

    test('open on the latest, load earlier on request, and reach as far back when fetched again', () async {
      final repo = _longThread();
      final c = _container(repo);
      final provider = postsProvider('5000');
      var page = await c.read(provider.future);
      expect(page.posts.last.id, '250');
      expect(page.posts, hasLength(100));
      expect(page.hasEarlier, isTrue);

      await c.read(provider.notifier).loadEarlier();
      await c.read(provider.notifier).loadEarlier();
      page = c.read(provider).requireValue;
      expect([for (final p in page.posts) p.id], [for (var i = 1; i <= 250; i++) '$i']);
      expect(page.hasEarlier, isFalse);

      await repo.verifyCode('reader@example.org', '123456');
      await repo.acceptGuidelines();
      await repo.reply('5000', 'The latest word.');
      c.invalidate(provider);
      page = await c.read(provider.future);
      expect(page.posts, hasLength(251));
      expect(page.posts.first.id, '1');
      expect(page.posts.last.body, 'The latest word.');
      expect(page.hasEarlier, isFalse);
    });

    test('fetched again, reach as far back in one request, and no further', () async {
      final repo = _CountingPosts()
        ..seed(
          threads: [_thread(5000, minutes: 250).copyWith(postCount: 250)],
          posts: [for (var i = 0; i < 250; i++) _post(i + 1, minutes: i ~/ 3)],
        );
      final c = _container(repo);
      final provider = postsProvider('5000');
      await c.read(provider.future);
      await c.read(provider.notifier).loadEarlier();
      var page = c.read(provider).requireValue;
      expect(page.posts.first.id, '51');
      expect(page.hasEarlier, isTrue);

      repo.limits.clear();
      c.invalidate(provider);
      page = await c.read(provider.future);
      expect(repo.limits, [201], reason: 'the 200 shown, and one more');
      expect(page.posts.first.id, '51');
      expect(page.posts, hasLength(200));
      expect(page.hasEarlier, isTrue);

      // Replies since push the earliest shown back: still no further.
      await repo.verifyCode('reader@example.org', '123456');
      await repo.acceptGuidelines();
      await repo.reply('5000', 'The latest word.');
      c.invalidate(provider);
      page = await c.read(provider.future);
      expect(page.posts.first.id, '51');
      expect(page.posts.last.body, 'The latest word.');
      expect(page.hasEarlier, isTrue);
    });

    test('a page that is exactly full has nothing before it', () async {
      final repo = DemoForumRepository()
        ..seed(posts: [for (var i = 0; i < ForumRepository.postsPageSize; i++) _post(i + 1, minutes: i)]);
      final page = await _container(repo).read(postsProvider('5000').future);
      expect(page.posts, hasLength(ForumRepository.postsPageSize));
      expect(page.hasEarlier, isFalse);
    });

    test("a deleted post leaves its thread's count", () async {
      final repo = DemoForumRepository();
      await repo.verifyCode('reader@example.org', '123456');
      await repo.acceptGuidelines();
      final post = await repo.reply('1', 'Thank you, this helped me.');
      expect((await repo.thread('1')).postCount, 3);
      await repo.deletePost(post.id);
      expect((await repo.thread('1')).postCount, 2);
    });
  });
}
