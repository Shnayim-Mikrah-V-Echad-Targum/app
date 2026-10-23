import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'forum_repository.dart';
import 'models.dart';

/// The community on the site's own server: the Worker's API under /api/
/// (tool/cloudflare/src/api.js), its accounts and its D1 database. Every rule
/// that matters (who may post, the limits, blocking, moderation) is kept
/// there (tool/cloudflare/src/community.js), not here.
///
/// The app signs in with a code sent by email, and keeps the session's token
/// to send with each request. On the web, which runs on the site's own
/// address, the session is the site's cookie instead, which the page can't
/// read: only the account (its id and email) is kept, so that it shows at
/// once on opening, and the server says whether the session still holds.
class WorkerForumRepository implements ForumRepository {
  WorkerForumRepository({
    required Uri server,
    required this._prefs,
    http.Client? client,
    this._keepsToken = !kIsWeb,
  })  : _api = server.resolve('api/'),
        _client = client ?? http.Client() {
    _restore();
  }

  final Uri _api;
  final SharedPreferences _prefs;
  final http.Client _client;

  /// Whether the session's token is kept and sent, as it is everywhere but
  /// the web.
  final bool _keepsToken;

  /// Where the signed-in account is kept between runs.
  @visibleForTesting
  static const sessionKey = 'community.session.v1';

  static const _timeout = Duration(seconds: 20);

  CommunityUser? _user;
  String? _token;
  final _changes = StreamController<CommunityUser?>.broadcast();

  @override
  bool get isDemo => false;

  void _restore() {
    final stored = _prefs.getString(sessionKey);
    if (stored == null) return;
    try {
      final m = jsonDecode(stored) as Map<String, dynamic>;
      _user = CommunityUser(id: m['id'] as String, email: m['email'] as String?);
      _token = m['token'] as String?;
    } catch (_) {
      unawaited(_prefs.remove(sessionKey));
    }
  }

  /// Asks the server who is signed in, once the app is up: a session that has
  /// ended there ends here, and on the web, an account signed in on the
  /// site's own pages is signed in here too. Offline, nothing changes.
  Future<void> refreshSession() async {
    if (_user == null && _keepsToken) return;
    try {
      final body = await _send('GET', 'me') as Map<String, dynamic>;
      final u = body['user'] as Map<String, dynamic>;
      final user = CommunityUser(id: u['id'] as String, email: u['email'] as String?);
      if (user != _user) await _signedIn(user, _token);
    } on CommunityException {
      // Not signed in (the server's answer has ended the session already).
    } catch (_) {
      // Offline: the session stands until the server can say.
    }
  }

  Future<void> _signedIn(CommunityUser user, String? token) async {
    _user = user;
    _token = _keepsToken ? token : null;
    await _prefs.setString(sessionKey, jsonEncode({'id': user.id, 'email': user.email, 'token': ?_token}));
    _changes.add(user);
  }

  Future<void> _signedOut() async {
    final was = _user;
    _user = null;
    _token = null;
    await _prefs.remove(sessionKey);
    if (was != null) _changes.add(null);
  }

  /// Sends a request and returns its JSON, or null for an answer with none.
  /// An error the server names is a [CommunityException] with its code; one
  /// that says the session is over signs out here too. A network failure is
  /// thrown as it is, for the page to say it is offline.
  Future<Object?> _send(String method, String path, {Object? body, Map<String, String>? query}) async {
    final request = http.Request(method, _api.resolve(path).replace(queryParameters: query));
    request.headers['Accept'] = 'application/json';
    if (_token case final token?) request.headers['Authorization'] = 'Bearer $token';
    if (body != null) {
      request.headers['Content-Type'] = 'application/json';
      request.body = jsonEncode(body);
    }
    final response = await http.Response.fromStream(await _client.send(request).timeout(_timeout)).timeout(_timeout);
    final text = utf8.decode(response.bodyBytes);
    final Object? json = text.isEmpty ? null : jsonDecode(text);
    if (response.statusCode >= 200 && response.statusCode < 300) return json;
    final code = json is Map<String, dynamic> ? json['error'] as String? ?? 'unknown' : 'unknown';
    if (response.statusCode == 401 && code == 'not_signed_in' && _user != null) await _signedOut();
    throw CommunityException(code);
  }

  // --- Auth -------------------------------------------------------------------

  @override
  CommunityUser? get currentUser => _user;

  @override
  Stream<CommunityUser?> get userChanges => _changes.stream;

  @override
  Future<void> sendCode(String email) => _send('POST', 'auth/code', body: {'email': email.trim()});

  @override
  Future<void> verifyCode(String email, String code) async {
    final body = await _send('POST', 'auth/verify', body: {'email': email.trim(), 'code': code.trim()}) as Map<String, dynamic>;
    final u = body['user'] as Map<String, dynamic>;
    await _signedIn(CommunityUser(id: u['id'] as String, email: u['email'] as String?), body['token'] as String?);
  }

  @override
  Future<void> signOut() async {
    try {
      await _send('POST', 'auth/sign-out');
    } catch (_) {
      // Offline, or over already: signed out here all the same.
    }
    await _signedOut();
  }

  @override
  Future<void> deleteAccount() async {
    await _send('DELETE', 'me');
    await _signedOut();
  }

  // --- Profile ----------------------------------------------------------------

  @override
  Future<Profile?> myProfile() async {
    if (_user == null) return null;
    final r = await _send('GET', 'profile') as Map<String, dynamic>?;
    if (r == null) return null;
    return Profile(
      id: r['id'] as String,
      displayName: r['display_name'] as String,
      isModerator: r['is_moderator'] as bool? ?? false,
      acceptedTerms: r['accepted_terms'] as bool? ?? false,
    );
  }

  @override
  Future<void> updateDisplayName(String name) => _send('PUT', 'profile', body: {'display_name': name.trim()});

  @override
  Future<void> acceptGuidelines() => _send('POST', 'profile/guidelines');

  // --- Reading ----------------------------------------------------------------

  @override
  Future<List<Forum>> forums() async {
    final rows = await _send('GET', 'forums') as List<dynamic>;
    return [
      for (final r in rows.cast<Map<String, dynamic>>())
        Forum(
          id: r['id'] as int,
          slug: r['slug'] as String,
          nameEn: r['name_en'] as String,
          nameHe: r['name_he'] as String,
          descriptionEn: r['description_en'] as String? ?? '',
          descriptionHe: r['description_he'] as String? ?? '',
          locked: r['locked'] as bool? ?? false,
        ),
    ];
  }

  @override
  Future<Map<int, ForumStats>> forumStats() async {
    final rows = await _send('GET', 'forum-stats') as List<dynamic>;
    return {
      for (final r in rows.cast<Map<String, dynamic>>())
        r['forum_id'] as int: ForumStats(
          threadCount: r['thread_count'] as int? ?? 0,
          lastPostAt: _time(r['last_post_at']),
        ),
    };
  }

  static DateTime? _time(Object? value) => value == null ? null : DateTime.parse(value as String);

  /// A page's cursor as the server reads it: the time in milliseconds, which
  /// it keeps exactly, and the id.
  static String _cursor((DateTime, String) c) => '${c.$1.millisecondsSinceEpoch}:${c.$2}';

  static ThreadSummary _thread(Map<String, dynamic> r) => ThreadSummary(
        id: '${r['id']}',
        forumId: r['forum_id'] as int,
        title: r['title'] as String,
        kind: ThreadKind.values.firstWhere((k) => k.name == r['kind'], orElse: () => ThreadKind.discussion),
        authorId: r['author_id'] as String?,
        authorName: r['author_name'] as String? ?? '',
        postCount: r['post_count'] as int? ?? 0,
        lastPostAt: DateTime.parse(r['last_post_at'] as String),
        createdAt: DateTime.parse(r['created_at'] as String),
        parshaNumber: r['parsha_id'] as int?,
        hebrewYear: r['hebrew_year'] as int?,
        pinned: r['pinned'] as bool? ?? false,
        locked: r['locked'] as bool? ?? false,
        excerpt: switch (r['excerpt']) {
          final String e when e.isNotEmpty => e,
          _ => null,
        },
        todahTotal: r['todah_total'] as int? ?? 0,
      );

  @override
  Future<List<ThreadSummary>> threads({
    int? forumId,
    int? parshaNumber,
    (DateTime, String)? after,
    int limit = ForumRepository.threadsPageSize,
  }) async {
    final rows = await _send('GET', 'threads', query: {
      'forum': ?forumId?.toString(),
      'parsha': ?parshaNumber?.toString(),
      if (after != null) 'after': _cursor(after),
      'limit': '$limit',
    }) as List<dynamic>;
    return [for (final r in rows.cast<Map<String, dynamic>>()) _thread(r)];
  }

  @override
  Future<ThreadSummary> thread(String id) async {
    if (int.tryParse(id) == null) throw const CommunityException(ForumRepository.threadNotFound);
    return _thread(await _send('GET', 'threads/$id') as Map<String, dynamic>);
  }

  static Post _post(Map<String, dynamic> r) => Post(
        id: '${r['id']}',
        threadId: '${r['thread_id']}',
        authorId: r['author_id'] as String?,
        authorName: r['author_name'] as String? ?? '',
        body: r['body'] as String,
        createdAt: DateTime.parse(r['created_at'] as String),
        editedAt: _time(r['edited_at']),
        hidden: r['hidden'] as bool? ?? false,
        replyToId: r['reply_to_id'] == null ? null : '${r['reply_to_id']}',
        quote: switch (r['quote']) {
          final Map<String, dynamic> q => QuotedPost(authorName: q['author_name'] as String? ?? '', body: q['body'] as String),
          _ => null,
        },
        todah: r['todah'] as int? ?? 0,
        myTodah: r['my_todah'] as bool? ?? false,
      );

  @override
  Future<List<Post>> posts(String threadId, {(DateTime, String)? before, int limit = ForumRepository.postsPageSize}) async {
    final rows = await _send('GET', 'threads/$threadId/posts', query: {
      if (before != null) 'before': _cursor(before),
      'limit': '$limit',
    }) as List<dynamic>;
    return [for (final r in rows.cast<Map<String, dynamic>>()) _post(r)];
  }

  @override
  Future<String> weeklyThread({required int parshaNumber, required int hebrewYear, required String title}) async {
    // The server builds the title from its own reference data.
    final r = await _send('POST', 'weekly', body: {'parsha': parshaNumber, 'year': hebrewYear}) as Map<String, dynamic>;
    return '${r['id']}';
  }

  // --- Writing ----------------------------------------------------------------

  @override
  Future<String> createThread({required int forumId, required String title, required String body, int? parshaNumber}) async {
    final r = await _send('POST', 'threads', body: {
      'forum_id': forumId,
      'title': title.trim(),
      'body': body.trim(),
      'parsha': ?parshaNumber,
    }) as Map<String, dynamic>;
    return '${r['id']}';
  }

  @override
  Future<Post> reply(String threadId, String body, {String? replyToId}) async => _post(await _send(
        'POST',
        'threads/$threadId/posts',
        body: {'body': body.trim(), 'reply_to_id': ?replyToId},
      ) as Map<String, dynamic>);

  @override
  Future<void> editPost(String postId, String body) => _send('PATCH', 'posts/$postId', body: {'body': body.trim()});

  @override
  Future<void> deletePost(String postId) => _send('DELETE', 'posts/$postId');

  @override
  Future<void> setTodah(String postId, bool on) => _send(on ? 'PUT' : 'DELETE', 'posts/$postId/todah');

  // --- Safety -----------------------------------------------------------------

  @override
  Future<void> report({String? postId, String? threadId, required ReportReason reason, String? details}) =>
      _send('POST', 'reports', body: {
        'post_id': ?postId,
        'thread_id': ?threadId,
        'reason': reason.db,
        if (details != null && details.trim().isNotEmpty) 'details': details.trim(),
      });

  @override
  Future<void> block(String userId) => _send('PUT', 'blocks/$userId');

  @override
  Future<void> unblock(String userId) => _send('DELETE', 'blocks/$userId');

  @override
  Future<Set<String>> blockedUsers() async => {for (final (id, _) in await blockedMembers()) id};

  @override
  Future<List<(String, String)>> blockedMembers() async {
    if (_user == null) return const [];
    final rows = await _send('GET', 'blocks') as List<dynamic>;
    return [for (final r in rows.cast<Map<String, dynamic>>()) (r['id'] as String, r['name'] as String? ?? '')];
  }

  // --- Moderation -------------------------------------------------------------

  @override
  Future<List<Report>> openReports() async {
    final rows = await _send('GET', 'reports') as List<dynamic>;
    return [
      for (final r in rows.cast<Map<String, dynamic>>())
        Report(
          id: r['id'] as String,
          postId: r['post_id'] as String?,
          reason: ReportReason.values.firstWhere((x) => x.db == r['reason'], orElse: () => ReportReason.other),
          details: r['details'] as String?,
          createdAt: DateTime.parse(r['created_at'] as String),
          postBody: r['post_body'] as String?,
        ),
    ];
  }

  @override
  Future<void> moderate(String action, String targetId, {String? reason}) =>
      _send('POST', 'moderate', body: {'action': action, 'target_id': targetId, 'reason': ?reason});

  // --- Progress sync ----------------------------------------------------------

  @override
  Future<Map<String, dynamic>?> loadProgress() async {
    final r = await _send('GET', 'progress') as Map<String, dynamic>;
    return r['data'] as Map<String, dynamic>?;
  }

  @override
  Future<void> saveProgress(Map<String, dynamic> data) => _send('PUT', 'progress', body: {'data': data});
}
