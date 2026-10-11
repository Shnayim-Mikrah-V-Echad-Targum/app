import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/features/community/data/demo_forum_repository.dart';
import 'package:shnayim_mikra/features/community/data/models.dart';

/// A forum's discussions listed with an excerpt and their thanks, and each
/// forum with how busy it is (supabase/migrations/20261011000000_thread_stats.sql),
/// as the demo gives them.
void main() {
  group('an excerpt', () {
    // The cases supabase/tests/behavior.sql checks the server's listing with.
    test('runs the lines of a long post together, and cuts it after a whole word', () {
      const body = 'Is anyone reading the Targum aloud each evening?\n\nI would love a partner for the second half of the '
          'week, by phone or in person, and I am happy to go slowly through the harder verses.';
      expect(
        threadExcerpt(body),
        'Is anyone reading the Targum aloud each evening? I would love a partner for the second half of the week, by '
        'phone or in person, and I am…',
      );
    });

    test('cuts a long link short rather than drop it', () {
      expect(threadExcerpt('Notes: https://example.org/${'a' * 200}'), 'Notes: https://example.org/${'a' * 112}…');
    });

    test('is the whole of a short post', () {
      expect(threadExcerpt('  Is anyone reading the Targum aloud each evening?\n'), 'Is anyone reading the Targum aloud each evening?');
      expect(threadExcerpt('a' * threadExcerptLength), 'a' * threadExcerptLength);
    });

    test('keeps a word that ends just at the limit', () {
      final words = '${'word ' * 27}abcd'; // 139 characters
      expect(threadExcerpt('$words, and more'), '$words,…');
    });

    test('counts characters, as the server does, not UTF-16 units', () {
      final faces = '😀' * threadExcerptLength;
      expect(threadExcerpt(faces), faces);
      expect(threadExcerpt('$faces😀'), '${'😀' * (threadExcerptLength - 1)}…');
    });

    test('is none for a post of nothing but spaces', () {
      expect(threadExcerpt(' \n\t '), isNull);
    });
  });

  group('the demo', () {
    // Thread 1, in Questions & answers: Avraham asks, Rivka answers and is
    // thanked four times.
    const question = 'I read English more easily than Aramaic. Why does the Shulchan Aruch insist on Targum Onkelos?';
    const answer = 'The Shulchan Aruch (OC 285:2) allows Rashi';

    Future<ThreadSummary> listed(DemoForumRepository repo, String id) async =>
        (await repo.threads(forumId: 2)).firstWhere((t) => t.id == id);

    test("lists a discussion with its first post's opening and every todah on its posts", () async {
      final repo = DemoForumRepository();
      final thread = await listed(repo, '1');
      expect((thread.excerpt, thread.todahTotal), (question, 4));
      expect((await repo.thread('1')).excerpt, question, reason: 'opened, as listed');

      await repo.verifyCode('reader@example.org', '123456');
      await repo.setTodah('2', true);
      expect((await listed(repo, '1')).todahTotal, 5);
    });

    test("hides a blocked member's excerpt, and the thanks on their posts", () async {
      final repo = DemoForumRepository();
      await repo.verifyCode('reader@example.org', '123456');
      await repo.setTodah('2', true);
      await repo.block('demo-2');
      expect(await listed(repo, '1'), isA<ThreadSummary>().having((t) => t.excerpt, 'excerpt', question).having((t) => t.todahTotal, 'todah', 0));
      await repo.block('demo-author');
      expect((await listed(repo, '1')).excerpt, isNull, reason: 'rather than the answer in its place');
      await repo.unblock('demo-author');
      expect((await listed(repo, '1')).excerpt, question);
    });

    test('gives the next post the excerpt once the first is deleted', () async {
      final repo = DemoForumRepository();
      await repo.verifyCode('moderator@example.org', '123456');
      await repo.deletePost('1');
      expect((await listed(repo, '1')).excerpt, startsWith(answer));
    });

    test("counts each forum's discussions, and dates its latest post", () async {
      final repo = DemoForumRepository();
      final stats = await repo.forumStats();
      final forums = await repo.forums();
      expect(stats.keys, unorderedEquals([for (final f in forums) f.id]));
      for (final f in forums) {
        final threads = await repo.threads(forumId: f.id);
        final latest = threads.map((t) => t.lastPostAt).reduce((a, b) => a.isAfter(b) ? a : b);
        expect(stats[f.id], ForumStats(threadCount: threads.length, lastPostAt: latest), reason: f.slug);
      }
    });

    test('counts a weekly thread not yet posted in as a discussion, but not as activity', () async {
      final repo = DemoForumRepository(samples: false);
      expect((await repo.forumStats())[1], const ForumStats(threadCount: 0));
      await repo.weeklyThread(parshaNumber: 2, hebrewYear: 5787, title: 'Noach · נח · 5787');
      expect((await repo.forumStats())[1], const ForumStats(threadCount: 1));
      final question = await repo.thread('1');
      expect((await repo.forumStats())[2], ForumStats(threadCount: 1, lastPostAt: question.lastPostAt));
    });

    test('dates a forum by a reply just sent', () async {
      final repo = DemoForumRepository();
      await repo.verifyCode('reader@example.org', '123456');
      await repo.acceptGuidelines();
      final before = DateTime.now();
      await repo.reply('1', 'Thank you, that settles it.');
      expect((await repo.forumStats())[2]!.lastPostAt!.isBefore(before), isFalse);
    });
  });
}
