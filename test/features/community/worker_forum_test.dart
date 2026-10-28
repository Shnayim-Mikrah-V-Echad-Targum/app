import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shnayim_mikrah/app/config.dart';
import 'package:shnayim_mikrah/features/community/data/forum_repository.dart';
import 'package:shnayim_mikrah/features/community/data/models.dart';
import 'package:shnayim_mikrah/features/community/data/worker_forum_repository.dart';

/// The site's API, as far as each test needs it: [answer] gives the status
/// and JSON for a request, and every request is kept.
class _Server {
  _Server(this.answer);

  final (int, Object?) Function(http.Request request) answer;
  final requests = <http.Request>[];

  late final client = MockClient((request) async {
    requests.add(request);
    final (status, body) = answer(request);
    return http.Response.bytes(body == null ? const [] : utf8.encode(jsonEncode(body)), status,
        headers: {'content-type': 'application/json; charset=utf-8'});
  });
}

final _site = Uri.parse('https://shnayimmikrah.org/');

Future<WorkerForumRepository> _repo(_Server server, {bool keepsToken = true}) async =>
    WorkerForumRepository(server: _site, prefs: await SharedPreferences.getInstance(), client: server.client, keepsToken: keepsToken);

const _thread = {
  'id': 7,
  'forum_id': 2,
  'parsha_id': 3,
  'hebrew_year': null,
  'kind': 'question',
  'title': 'A question on Rashi',
  'author_id': '4',
  'author_name': 'Rivka',
  'pinned': false,
  'locked': true,
  'post_count': 2,
  'last_post_at': '2026-10-20T12:00:00.123Z',
  'created_at': '2026-10-19T08:00:00.000Z',
  'excerpt': 'What does Rashi mean here?',
  'todah_total': 3,
};

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('signing in keeps the account and its token, which each request then carries', () async {
    final server = _Server((r) => switch (r.url.path) {
          '/api/auth/code' => (204, null),
          '/api/auth/verify' => (200, {'token': 'secret-token', 'user': {'id': '4', 'email': 'reader@example.com'}}),
          _ => (200, {'id': '4', 'display_name': 'Rivka', 'accepted_terms': true, 'is_moderator': false}),
        });
    final repo = await _repo(server);
    final changes = <CommunityUser?>[];
    repo.userChanges.listen(changes.add);

    await repo.sendCode(' reader@example.com ');
    expect(jsonDecode(server.requests.last.body), {'email': 'reader@example.com'});
    await repo.verifyCode('reader@example.com', '123456');
    expect(jsonDecode(server.requests.last.body), {'email': 'reader@example.com', 'code': '123456'});
    expect(repo.currentUser, const CommunityUser(id: '4', email: 'reader@example.com'));
    await pumpEventQueue();
    expect(changes, [const CommunityUser(id: '4', email: 'reader@example.com')]);

    final profile = await repo.myProfile();
    expect(profile?.displayName, 'Rivka');
    expect(server.requests.last.headers['Authorization'], 'Bearer secret-token');

    // Opened again, the app is still signed in.
    final again = await _repo(server);
    expect(again.currentUser?.id, '4');
    await again.myProfile();
    expect(server.requests.last.headers['Authorization'], 'Bearer secret-token');
  });

  test('the authenticator\'s code goes with the emailed one, where the account asks for it', () async {
    final server = _Server((_) => (200, {'token': 't', 'user': {'id': '4', 'email': 'reader@example.com'}}));
    final repo = await _repo(server);
    await repo.verifyCode('reader@example.com', '123456', secondStep: ' 424242 ');
    expect(jsonDecode(server.requests.single.body), {'email': 'reader@example.com', 'code': '123456', 'totp': '424242'});
  });

  test('signing in with the password sends it as typed, and keeps the account and its token', () async {
    final server = _Server((r) => switch (r.url.path) {
          '/api/auth/password' => (200, {'token': 'secret-token', 'user': {'id': '4', 'email': 'reader@example.com'}}),
          _ => (200, {'id': '4', 'display_name': 'Rivka', 'accepted_terms': true, 'is_moderator': false}),
        });
    final repo = await _repo(server);
    await repo.signInWithPassword(' reader@example.com ', ' a long password ', secondStep: ' 123456 ');
    final sent = server.requests.firstWhere((r) => r.url.path == '/api/auth/password');
    expect(sent.method, 'POST');
    expect(jsonDecode(sent.body), {'email': 'reader@example.com', 'password': ' a long password ', 'totp': '123456'});
    expect(repo.currentUser, const CommunityUser(id: '4', email: 'reader@example.com'));
    await repo.myProfile();
    expect(server.requests.last.headers['Authorization'], 'Bearer secret-token');

    SharedPreferences.setMockInitialValues({});
    final refused = await _repo(_Server((r) => (401, {'error': 'invalid_credentials'})));
    await expectLater(
      refused.signInWithPassword('reader@example.com', 'wrong'),
      throwsA(isA<CommunityException>().having((e) => e.code, 'code', 'invalid_credentials')),
    );
    expect(refused.currentUser, isNull);
  });

  test('on the web the session is the site\'s cookie: no token is kept or sent', () async {
    final server = _Server((r) => switch (r.url.path) {
          '/api/auth/verify' => (200, {'token': 'secret-token', 'user': {'id': '4', 'email': 'reader@example.com'}}),
          _ => (200, {'id': '4', 'display_name': 'Rivka', 'accepted_terms': true, 'is_moderator': false}),
        });
    final repo = await _repo(server, keepsToken: false);
    await repo.verifyCode('reader@example.com', '123456');
    await repo.myProfile();
    expect(server.requests.last.headers.containsKey('Authorization'), isFalse);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString(WorkerForumRepository.sessionKey), isNot(contains('secret-token')));
  });

  test('on the web, an account signed in on the site\'s pages is signed in here', () async {
    final server = _Server((_) => (200, {'user': {'id': '9', 'email': 'site@example.com'}}));
    final repo = await _repo(server, keepsToken: false);
    expect(repo.currentUser, isNull);
    await repo.refreshSession();
    expect(repo.currentUser, const CommunityUser(id: '9', email: 'site@example.com'));
  });

  test('a session the server has ended ends here too', () async {
    SharedPreferences.setMockInitialValues({
      WorkerForumRepository.sessionKey: jsonEncode({'id': '4', 'email': 'reader@example.com', 'token': 'old'}),
    });
    final server = _Server((_) => (401, {'error': 'not_signed_in'}));
    final repo = await _repo(server);
    expect(repo.currentUser?.id, '4');
    final changes = <CommunityUser?>[];
    repo.userChanges.listen(changes.add);
    await repo.refreshSession();
    expect(repo.currentUser, isNull);
    await pumpEventQueue();
    expect(changes, [null]);
    expect((await SharedPreferences.getInstance()).getString(WorkerForumRepository.sessionKey), isNull);
  });

  test('offline, the session stands', () async {
    SharedPreferences.setMockInitialValues({
      WorkerForumRepository.sessionKey: jsonEncode({'id': '4', 'email': 'reader@example.com', 'token': 'old'}),
    });
    final repo = WorkerForumRepository(
      server: _site,
      prefs: await SharedPreferences.getInstance(),
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    await repo.refreshSession();
    expect(repo.currentUser?.id, '4');
    await expectLater(repo.forums(), throwsA(isA<http.ClientException>()));
  });

  test('an error the server names comes as its code', () async {
    final server = _Server((_) => (429, {'error': 'rate_limited'}));
    final repo = await _repo(server);
    await expectLater(
      repo.reply('7', 'Too soon'),
      throwsA(isA<CommunityException>().having((e) => e.code, 'code', 'rate_limited')),
    );
    expect(jsonDecode(server.requests.last.body), {'body': 'Too soon'});
    expect(server.requests.last.url.path, '/api/threads/7/posts');
  });

  test('a page of threads follows the last one shown, to the millisecond', () async {
    final server = _Server((_) => (200, [_thread]));
    final repo = await _repo(server);
    final threads = await repo.threads(
      forumId: 2,
      after: (DateTime.parse('2026-10-20T12:00:00.123Z'), '9'),
      limit: 31,
    );
    final url = server.requests.single.url;
    expect(url.path, '/api/threads');
    expect(url.queryParameters, {'forum': '2', 'after': '${DateTime.parse('2026-10-20T12:00:00.123Z').millisecondsSinceEpoch}:9', 'limit': '31'});
    final t = threads.single;
    expect(t.id, '7');
    expect(t.kind, ThreadKind.question);
    expect(t.authorName, 'Rivka');
    expect(t.locked, isTrue);
    expect(t.parshaNumber, 3);
    expect(t.excerpt, 'What does Rashi mean here?');
    expect(t.todahTotal, 3);
    expect(t.lastPostAt, DateTime.parse('2026-10-20T12:00:00.123Z'));
  });

  test('a thread that is not there is threadNotFound', () async {
    final server = _Server((_) => (404, {'error': ForumRepository.threadNotFound}));
    final repo = await _repo(server);
    for (final id in ['12', 'not-a-number']) {
      await expectLater(
        repo.thread(id),
        throwsA(isA<CommunityException>().having((e) => e.code, 'code', ForumRepository.threadNotFound)),
      );
    }
    expect(server.requests, hasLength(1), reason: 'an id that is no number is not asked for');
  });

  test('posts come with the post each answers, and their thanks', () async {
    final server = _Server((_) => (200, [
          {
            'id': 11,
            'thread_id': 7,
            'author_id': '4',
            'author_name': 'Rivka',
            'body': 'An answer',
            'created_at': '2026-10-20T12:00:00.000Z',
            'edited_at': null,
            'hidden': true,
            'reply_to_id': 10,
            'quote': {'author_name': 'Moshe', 'body': 'The question'},
            'todah': 2,
            'my_todah': true,
          },
        ]));
    final repo = await _repo(server);
    final posts = await repo.posts('7', before: (DateTime.utc(2026, 10, 21), '12'), limit: 50);
    expect(server.requests.single.url.queryParameters['before'], '${DateTime.utc(2026, 10, 21).millisecondsSinceEpoch}:12');
    final p = posts.single;
    expect(p.id, '11');
    expect(p.replyToId, '10');
    expect(p.quote?.authorName, 'Moshe');
    expect(p.hidden, isTrue);
    expect(p.todah, 2);
    expect(p.myTodah, isTrue);
  });

  test('writing sends what the server reads', () async {
    final server = _Server((r) => switch ((r.method, r.url.path)) {
          ('POST', '/api/threads') => (201, {'id': 21}),
          ('POST', '/api/weekly') => (200, {'id': 22}),
          _ => (204, null),
        });
    final repo = await _repo(server);
    expect(await repo.createThread(forumId: 2, title: ' A question ', body: ' Why? ', parshaNumber: 3), '21');
    expect(jsonDecode(server.requests.last.body), {'forum_id': 2, 'title': 'A question', 'body': 'Why?', 'parsha': 3});
    expect(await repo.weeklyThread(parshaNumber: 3, hebrewYear: 5787, title: 'ignored'), '22');
    expect(jsonDecode(server.requests.last.body), {'parsha': 3, 'year': 5787});
    await repo.setTodah('11', true);
    expect((server.requests.last.method, server.requests.last.url.path), ('PUT', '/api/posts/11/todah'));
    await repo.setTodah('11', false);
    expect(server.requests.last.method, 'DELETE');
    await repo.report(postId: '11', reason: ReportReason.lashonHara, details: '  ');
    expect(jsonDecode(server.requests.last.body), {'post_id': '11', 'reason': 'lashon_hara'});
    await repo.moderate('lock_thread', '7');
    expect(jsonDecode(server.requests.last.body), {'action': 'lock_thread', 'target_id': '7'});
    await repo.saveProgress({'version': 2});
    expect(server.requests.last.method, 'PUT');
    expect(jsonDecode(server.requests.last.body), {'data': {'version': 2}});
  });

  test('signing out and deleting the account end the session here, offline too', () async {
    SharedPreferences.setMockInitialValues({
      WorkerForumRepository.sessionKey: jsonEncode({'id': '4', 'email': 'reader@example.com', 'token': 'old'}),
    });
    final offline = WorkerForumRepository(
      server: _site,
      prefs: await SharedPreferences.getInstance(),
      client: MockClient((_) async => throw http.ClientException('offline')),
    );
    await offline.signOut();
    expect(offline.currentUser, isNull);

    SharedPreferences.setMockInitialValues({
      WorkerForumRepository.sessionKey: jsonEncode({'id': '4', 'email': 'reader@example.com', 'token': 'old'}),
    });
    final server = _Server((_) => (204, null));
    final repo = await _repo(server);
    await repo.deleteAccount();
    expect((server.requests.single.method, server.requests.single.url.path), ('DELETE', '/api/me'));
    expect(repo.currentUser, isNull);
  });

  test('the website opens signed in: by a one-time link in the app, by the cookie it has on the web', () async {
    SharedPreferences.setMockInitialValues({
      WorkerForumRepository.sessionKey: jsonEncode({'id': '4', 'email': 'admin@example.com', 'token': 'secret-token'}),
    });
    final server = _Server((r) => (200, {'url': 'https://shnayimmikrah.org/account/handoff?t=one-time'}));
    final repo = await _repo(server);
    expect(await repo.siteLink(SitePage.admin), Uri.parse('https://shnayimmikrah.org/account/handoff?t=one-time'));
    final asked = server.requests.single;
    expect((asked.method, asked.url.path), ('POST', '/api/handoff'));
    expect(jsonDecode(asked.body), {'next': '/account/admin'});
    expect(asked.headers['Authorization'], 'Bearer secret-token');
    // The account page's list of devices names this one.
    expect(asked.headers['X-App-Platform'], isNotEmpty);

    final web = await _repo(_Server((r) => (500, null)), keepsToken: false);
    // The site's account page; /account is the app's own Account tab.
    expect(await web.siteLink(SitePage.account), Uri.parse('https://shnayimmikrah.org/account/security'));
    expect(await web.siteLink(SitePage.admin), Uri.parse('https://shnayimmikrah.org/account/admin'));
  });

  test("on the web, the app signs in on the site's page, which comes back to it", () async {
    SharedPreferences.setMockInitialValues({});
    final web = await _repo(_Server((r) => (500, null)), keepsToken: false);
    expect(
      web.signInPage(next: '/community/account', lang: 'he'),
      Uri.parse('https://shnayimmikrah.org/account/sign-in?next=%2Fcommunity%2Faccount&lang=he'),
    );
    expect(web.signInPage(next: '/settings/account', lang: 'fr'), Uri.parse('https://shnayimmikrah.org/account/sign-in?next=%2Fsettings%2Faccount'));
    // In the apps, which sign in themselves, none.
    final app = await _repo(_Server((r) => (500, null)));
    expect(app.signInPage(next: '/community/account'), isNull);
  });

  test("the website opens in the app's language", () async {
    SharedPreferences.setMockInitialValues({
      WorkerForumRepository.sessionKey: jsonEncode({'id': '4', 'email': 'reader@example.com', 'token': 'secret-token'}),
    });
    final server = _Server((r) => (200, {'url': 'https://shnayimmikrah.org/account/handoff?t=one-time&lang=he'}));
    final repo = await _repo(server);
    await repo.siteLink(SitePage.account, lang: 'he');
    expect(jsonDecode(server.requests.single.body), {'next': '/account/security', 'lang': 'he'});
    await repo.siteLink(SitePage.account, lang: 'fr');
    expect(jsonDecode(server.requests.last.body), {'next': '/account/security'}, reason: 'a language the site lacks is left out');

    final web = await _repo(_Server((r) => (500, null)), keepsToken: false);
    expect(await web.siteLink(SitePage.account, lang: 'he'), Uri.parse('https://shnayimmikrah.org/account/security?lang=he'));
  });

  test('an owner or an admin has the admin panel; a moderator has the reports', () async {
    for (final (role, admin, moderator) in [('owner', true, true), ('admin', true, true), ('moderator', false, true), (null, false, false)]) {
      final server = _Server((r) => (200, {'id': '4', 'display_name': 'Rivka', 'is_moderator': moderator, 'role': role}));
      SharedPreferences.setMockInitialValues({
        WorkerForumRepository.sessionKey: jsonEncode({'id': '4', 'email': 'reader@example.com', 'token': 't'}),
      });
      final profile = await (await _repo(server)).myProfile();
      expect((profile?.isAdmin, profile?.isModerator), (admin, moderator), reason: role);
    }
  });

  test("the community's server is the root of the site's address, and none without one", () {
    addTearDown(() => AppConfig.debugWebUrl = null);
    AppConfig.debugWebUrl = '';
    expect(AppConfig.communityServer, isNull);
    AppConfig.debugWebUrl = 'https://example.org/app/';
    expect(AppConfig.communityServer, Uri.parse('https://example.org/'));
  });
}
