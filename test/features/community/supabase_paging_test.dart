import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shnayim_mikra/features/community/data/supabase_forum_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// A thread row as PostgREST returns it.
Map<String, dynamic> _threadRow(int id, {bool pinned = false}) => {
      'id': id,
      'category_id': 1,
      'parasha_id': null,
      'hebrew_year': null,
      'kind': 'discussion',
      'title': 'Thread $id',
      'author_id': null,
      'is_pinned': pinned,
      'is_locked': false,
      'post_count': 1,
      'last_post_at': '2026-10-0${id % 9 + 1}T12:00:00.123456+00:00',
      'created_at': '2026-10-01T12:00:00+00:00',
      'author': null,
    };

/// A post row as PostgREST returns it.
Map<String, dynamic> _postRow(int id) => {
      'id': id,
      'thread_id': 7,
      'author_id': null,
      'reply_to_post_id': null,
      'body': 'Post $id',
      'created_at': '2026-10-01T12:00:${id.toString().padLeft(2, '0')}+00:00',
      'edited_at': null,
      'hidden_at': null,
      'author': null,
    };

void main() {
  late List<Uri> requests;
  late SupabaseClient client;
  late SupabaseForumRepository repo;

  /// Answers each request with [respond]'s rows.
  void serve(List<Map<String, dynamic>> Function(Uri url) respond) {
    client = SupabaseClient(
      'https://example.supabase.co',
      'public-key',
      authOptions: const AuthClientOptions(autoRefreshToken: false),
      httpClient: MockClient((request) async {
        requests.add(request.url);
        return http.Response(
          jsonEncode(respond(request.url)),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      }),
    );
    repo = SupabaseForumRepository(client);
  }

  setUp(() => requests = []);
  tearDown(() => client.dispose());

  List<Uri> to(String table) => [for (final r in requests) if (r.path == '/rest/v1/$table') r];

  group('threads', () {
    test('page 1 asks for every pinned thread, then a page of the others', () async {
      serve((url) => url.queryParameters['is_pinned'] == 'eq.true'
          ? [_threadRow(1, pinned: true), _threadRow(2, pinned: true)]
          : [_threadRow(9), _threadRow(8)]);
      final threads = await repo.threads(forumId: 1);
      expect([for (final t in threads) t.id], ['1', '2', '9', '8']);

      final asked = to('threads');
      expect(asked, hasLength(2));
      final pinned = asked.firstWhere((u) => u.queryParameters['is_pinned'] == 'eq.true');
      final others = asked.firstWhere((u) => u.queryParameters['is_pinned'] == 'eq.false');
      expect(pinned.queryParameters['category_id'], 'eq.1');
      expect(pinned.queryParameters.containsKey('limit'), isFalse);
      expect(others.queryParameters['category_id'], 'eq.1');
      expect(others.queryParameters['order'], startsWith('last_post_at.desc'));
      expect(others.queryParameters['order'], contains(',id.desc'));
      expect(others.queryParameters['limit'], '30');
      expect(others.queryParameters.containsKey('or'), isFalse);
    });

    test('a later page asks only for the unpinned threads after the cursor', () async {
      serve((_) => [_threadRow(3)]);
      final at = DateTime.utc(2026, 10, 9, 12, 0, 0, 123, 456);
      final threads = await repo.threads(forumId: 1, after: (at, '42'), limit: 31);
      expect([for (final t in threads) t.id], ['3']);

      final asked = to('threads').single;
      expect(asked.queryParameters['is_pinned'], 'eq.false');
      expect(
        asked.queryParameters['or'],
        '(last_post_at.lt.2026-10-09T12:00:00.123456Z,and(last_post_at.eq.2026-10-09T12:00:00.123456Z,id.lt.42))',
      );
      expect(asked.queryParameters['limit'], '31');
    });

    test('a later page follows on from the exact time the server gave, which a DateTime on the web cuts short', () async {
      serve((url) => url.queryParameters['is_pinned'] == 'eq.true' ? [] : [_threadRow(9), _threadRow(8)]);
      final last = (await repo.threads(forumId: 1)).last;
      requests.clear();
      await repo.threads(forumId: 1, after: (last.lastPostAt, last.id));
      expect(
        to('threads').single.queryParameters['or'],
        '(last_post_at.lt.2026-10-09T12:00:00.123456+00:00,and(last_post_at.eq.2026-10-09T12:00:00.123456+00:00,id.lt.8))',
      );
    });
  });

  group('posts', () {
    test('are asked for newest first, and read oldest first', () async {
      serve((url) => url.path.endsWith('/posts') ? [_postRow(30), _postRow(29), _postRow(28)] : []);
      final posts = await repo.posts('7', limit: 3);
      expect([for (final p in posts) p.id], ['28', '29', '30']);

      final asked = to('posts').single;
      expect(asked.queryParameters['thread_id'], 'eq.7');
      expect(asked.queryParameters['order'], startsWith('created_at.desc'));
      expect(asked.queryParameters['order'], contains(',id.desc'));
      expect(asked.queryParameters['limit'], '3');
      expect(asked.queryParameters.containsKey('or'), isFalse);
    });

    test('come with the post each one answers, where it may be seen', () async {
      serve((url) => url.path.endsWith('/posts')
          ? [
              {
                ..._postRow(30),
                'reply_to_post_id': 3,
                'reply_to': {'body': 'Post 3', 'deleted_at': null, 'author': {'display_name': 'Rivka'}},
              },
              {
                ..._postRow(31),
                'reply_to_post_id': 4,
                'reply_to': {'body': 'Post 4', 'deleted_at': '2026-10-01T13:00:00+00:00', 'author': null},
              },
              {..._postRow(32), 'reply_to_post_id': 5, 'reply_to': null},
            ].reversed.toList()
          : []);
      final posts = await repo.posts('7');
      expect(to('posts').single.queryParameters['select'], contains('reply_to:reply_to_post_id(body,deleted_at,author:profiles(display_name))'));
      expect([for (final p in posts) p.replyToId], ['3', '4', '5']);
      expect((posts[0].quote?.authorName, posts[0].quote?.body), ('Rivka', 'Post 3'));
      expect(posts[1].quote, isNull, reason: 'deleted, as a moderator may still see it');
      expect(posts[2].quote, isNull, reason: 'hidden from the reader');
    });

    test('before a post, are those just before it', () async {
      serve((url) => url.path.endsWith('/posts') ? [_postRow(27)] : []);
      final posts = await repo.posts('7', before: (DateTime.utc(2026, 10, 1, 12, 0, 28), '28'));
      expect([for (final p in posts) p.id], ['27']);
      expect(
        to('posts').single.queryParameters['or'],
        '(created_at.lt.2026-10-01T12:00:28.000Z,and(created_at.eq.2026-10-01T12:00:28.000Z,id.lt.28))',
      );
    });
  });
}
