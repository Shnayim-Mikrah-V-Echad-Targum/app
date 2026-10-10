import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/core/calendar/jewish_holidays.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/features/community/data/demo_forum_repository.dart';
import 'package:shnayim_mikra/features/community/data/models.dart';

final _hebrew = RegExp('[א-ת]');

/// Every thread of [repo], and every post of each, oldest first.
Future<Map<ThreadSummary, List<Post>>> _everything(DemoForumRepository repo) async => {
      for (final t in await repo.threads()) t: await repo.posts(t.id),
    };

/// The demo community (§9 Community): sample discussions in every forum, and
/// this week's discussion started as it is first opened.
void main() {
  test('starts every forum with two or three discussions, in Hebrew and in English', () async {
    final repo = DemoForumRepository();
    for (final forum in await repo.forums()) {
      expect((await repo.threads(forumId: forum.id)).length, inInclusiveRange(2, 3), reason: forum.slug);
    }
    final titles = [for (final t in await repo.threads()) t.title];
    expect(titles.where(_hebrew.hasMatch), isNotEmpty);
    expect(titles.where((t) => !_hebrew.hasMatch(t)), isNotEmpty);
  });

  test('shows a pinned and a locked discussion, replies, many members, and thanks from none to a dozen', () async {
    final all = await _everything(DemoForumRepository());
    expect(all.keys.where((t) => t.pinned), hasLength(1));
    expect(all.keys.where((t) => t.locked), hasLength(1));
    final posts = all.values.expand((p) => p).toList();
    expect(posts.map((p) => p.todah).reduce(min), 0);
    expect(posts.map((p) => p.todah).reduce(max), 12);
    expect(posts.where((p) => p.quote != null), isNotEmpty, reason: 'replies quote what they answer');
    expect(
      {for (final p in posts) p.authorName},
      containsAll(['Avraham', 'Rivka', 'Yosef', 'Miriam', 'Chana', 'שירה', 'דוד']),
    );
    for (final MapEntry(key: thread, value: posts) in all.entries) {
      expect(posts, hasLength(thread.postCount), reason: thread.title);
      expect(thread.authorName, posts.first.authorName, reason: 'started by its first post');
      expect(thread.lastPostAt, posts.last.createdAt);
    }
  });

  test('dates its posts in order, in the past, and never on Shabbat or Yom Tov or the afternoon before', () async {
    final all = await _everything(DemoForumRepository());
    final now = DateTime.now();
    bool rest(LocalDate day) => JewishHolidays.isRestDay(day, israel: false);
    // The samples reach back almost two weeks, over at least one Shabbat.
    for (final posts in all.values) {
      for (final (i, post) in posts.indexed) {
        final at = post.createdAt;
        final day = LocalDate.fromDateTime(at);
        expect(at.isAfter(now), isFalse);
        if (i > 0) expect(at.isBefore(posts[i - 1].createdAt), isFalse, reason: post.body);
        expect(rest(day), isFalse, reason: '$at');
        if (at.hour >= 14) expect(rest(day.addDays(1)), isFalse, reason: '$at');
      }
    }
  });

  test('without samples, holds only the question that tests read and reply to', () async {
    final repo = DemoForumRepository(samples: false);
    expect([for (final t in await repo.threads()) t.id], ['1']);
    expect(await repo.forums(), hasLength(5));
  });

  test("starts this week's discussion with a few posts as it is first opened, and no other week's", () async {
    // Friday of Bereshit 5787.
    final repo = DemoForumRepository(clock: () => DateTime(2026, 10, 9, 11))
      ..isCurrentWeek = (parsha, year) => parsha == 1 && year == 5787;
    final noach = await repo.weeklyThread(parshaNumber: 2, hebrewYear: 5787, title: 'Noach · נח · 5787');
    expect(await repo.posts(noach), isEmpty);

    final bereshit = await repo.weeklyThread(parshaNumber: 1, hebrewYear: 5787, title: 'Bereshit · בראשית · 5787');
    final posts = await repo.posts(bereshit);
    expect(posts, hasLength(3));
    expect((await repo.thread(bereshit)).postCount, 3);
    expect(posts.map((p) => p.body).where(_hebrew.hasMatch), isNotEmpty);
    expect(posts.last.quote?.authorName, posts.first.authorName, reason: 'the last replies to the first');

    // Opened again, it is the same discussion, with nothing added.
    expect(await repo.weeklyThread(parshaNumber: 1, hebrewYear: 5787, title: 'Bereshit · בראשית · 5787'), bereshit);
    expect(await repo.posts(bereshit), hasLength(3));
  });

  test("dates this week's discussion within the week, however early in it it is opened", () async {
    // Sunday morning after Shabbat Noach, 18 October 2026: since midnight, 9
    // hours to post in.
    final sunday = DateTime(2026, 10, 18);
    final now = sunday.add(const Duration(hours: 9));
    final repo = DemoForumRepository(clock: () => now)..isCurrentWeek = (parsha, year) => parsha == 3 && year == 5787;
    final id = await repo.weeklyThread(parshaNumber: 3, hebrewYear: 5787, title: 'Lech-Lecha · לך לך · 5787');
    final posts = await repo.posts(id);
    expect(posts, hasLength(3));
    for (final post in posts) {
      expect(post.createdAt.isBefore(sunday), isFalse, reason: '${post.createdAt}, in last week');
      expect(post.createdAt.isAfter(now), isFalse);
    }
    expect((await repo.thread(id)).createdAt.isBefore(sunday), isFalse);
    // Still in order, the reply last.
    expect(posts.map((p) => p.createdAt).toList(), orderedEquals([...posts.map((p) => p.createdAt)]..sort()));
  });

  test('starts this week\'s discussion empty on a Yom Tov that begins the week', () async {
    // Simchat Torah, Sunday 4 October 2026, in the Diaspora: no one has
    // posted since Shabbat.
    final repo = DemoForumRepository(clock: () => DateTime(2026, 10, 4, 10))
      ..isCurrentWeek = (parsha, year) => parsha == 54 && year == 5786;
    final id = await repo.weeklyThread(parshaNumber: 54, hebrewYear: 5786, title: 'Vezot HaBerakhah · וזאת הברכה · 5786');
    expect(await repo.posts(id), isEmpty);
  });

  test('starts no weekly discussion until the app says which week is this one', () async {
    final repo = DemoForumRepository();
    final id = await repo.weeklyThread(parshaNumber: 1, hebrewYear: 5787, title: 'Bereshit · בראשית · 5787');
    expect(await repo.posts(id), isEmpty);
  });
}
