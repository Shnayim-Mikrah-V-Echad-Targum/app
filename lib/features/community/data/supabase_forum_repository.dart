import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'forum_repository.dart';
import 'models.dart';

/// Production backend: Supabase (Postgres + row-level security). Every rule
/// that matters — who may post, rate limits, blocking, moderation — is
/// enforced in the database (see supabase/migrations), not just here.
class SupabaseForumRepository implements ForumRepository {
  SupabaseForumRepository(this._db);

  final SupabaseClient _db;

  @override
  bool get isDemo => false;

  String get _uid {
    final id = _db.auth.currentUser?.id;
    if (id == null) throw const CommunityException('not_signed_in');
    return id;
  }

  Future<T> _call<T>(Future<T> Function() f) async {
    try {
      return await f();
    } on PostgrestException catch (e) {
      throw CommunityException(codeOf(e.message, e.code), e.message);
    } on AuthException catch (e) {
      throw CommunityException(e.code ?? 'auth_error', e.message);
    }
  }

  /// The stable code of a database error. A unique violation names the
  /// index it broke: only the display names' index means the name is taken.
  /// Any other means the change was there already ('duplicate').
  @visibleForTesting
  static String codeOf(String message, String? sqlCode) {
    if (sqlCode == '23505') {
      if (message.contains('profiles_display_name_ci')) return 'name_taken';
      if (message.contains('reports_one_per_reporter_post')) return 'already_reported';
      return 'duplicate';
    }
    if (sqlCode == '42501') return 'forbidden';
    final m = RegExp(r'^[a-z_]+').firstMatch(message);
    return m?.group(0) ?? 'unknown';
  }

  // --- Auth -------------------------------------------------------------------

  @override
  CommunityUser? get currentUser {
    final u = _db.auth.currentUser;
    return u == null ? null : CommunityUser(id: u.id, email: u.email);
  }

  @override
  Stream<CommunityUser?> get userChanges => _db.auth.onAuthStateChange.map((s) {
        final u = s.session?.user;
        return u == null ? null : CommunityUser(id: u.id, email: u.email);
      });

  @override
  Future<void> sendCode(String email) => _call(() => _db.auth.signInWithOtp(email: email, shouldCreateUser: true));

  @override
  Future<void> verifyCode(String email, String code) =>
      _call(() => _db.auth.verifyOTP(email: email, token: code, type: OtpType.email));

  @override
  Future<void> signOut() => _call(() => _db.auth.signOut());

  @override
  Future<void> deleteAccount() => _call(() async {
        await _db.rpc('delete_my_account');
        await _db.auth.signOut();
      });

  // --- Profile ----------------------------------------------------------------

  @override
  Future<Profile?> myProfile() => _call(() async {
        if (_db.auth.currentUser == null) return null;
        final row = await _db.rpc('my_profile') as Map<String, dynamic>?;
        if (row == null) return null;
        return Profile(
          id: row['id'] as String,
          displayName: row['display_name'] as String,
          isModerator: row['is_moderator'] as bool? ?? false,
          acceptedTerms: row['accepted_terms'] as bool? ?? false,
        );
      });

  @override
  Future<void> updateDisplayName(String name) =>
      _call(() => _db.from('profiles').update({'display_name': name.trim()}).eq('id', _uid));

  @override
  Future<void> acceptGuidelines() => _call(() => _db.rpc('accept_terms'));

  // --- Reading ----------------------------------------------------------------

  @override
  Future<List<Forum>> forums() => _call(() async {
        final rows = await _db.from('categories').select().order('sort_order');
        return [
          for (final r in rows)
            Forum(
              id: r['id'] as int,
              slug: r['slug'] as String,
              nameEn: r['name_en'] as String,
              nameHe: r['name_he'] as String,
              descriptionEn: r['description_en'] as String? ?? '',
              descriptionHe: r['description_he'] as String? ?? '',
              locked: r['is_locked'] as bool? ?? false,
            ),
        ];
      });

  static const _threadColumns =
      'id, category_id, parasha_id, hebrew_year, kind, title, author_id, is_pinned, is_locked, post_count, '
      'last_post_at, created_at, author:profiles(display_name)';

  static ThreadSummary _thread(Map<String, dynamic> r) => ThreadSummary(
        id: '${r['id']}',
        forumId: r['category_id'] as int,
        title: r['title'] as String,
        kind: ThreadKind.values.firstWhere((k) => k.name == r['kind'], orElse: () => ThreadKind.discussion),
        authorId: r['author_id'] as String?,
        authorName: (r['author'] as Map<String, dynamic>?)?['display_name'] as String? ?? '',
        postCount: r['post_count'] as int? ?? 0,
        lastPostAt: DateTime.parse(r['last_post_at'] as String),
        createdAt: DateTime.parse(r['created_at'] as String),
        parshaNumber: r['parasha_id'] as int?,
        hebrewYear: r['hebrew_year'] as int?,
        pinned: r['is_pinned'] as bool? ?? false,
        locked: r['is_locked'] as bool? ?? false,
      );

  /// A filter for the rows that come after [cursor] (a time in [column], and
  /// an id) when ordered newest first, then by the higher id: those earlier
  /// than it, or as early with a lower id.
  static String _olderThan(String column, (DateTime, String) cursor) {
    final (time, id) = cursor;
    final ts = time.toUtc().toIso8601String();
    final n = int.parse(id);
    return '$column.lt.$ts,and($column.eq.$ts,id.lt.$n)';
  }

  @override
  Future<List<ThreadSummary>> threads({
    int? forumId,
    int? parshaNumber,
    (DateTime, String)? after,
    int limit = ForumRepository.threadsPageSize,
  }) =>
      _call(() async {
        PostgrestTransformBuilder<PostgrestList> query({required bool pinned, String? after}) {
          var q = _db.from('threads').select(_threadColumns).eq('is_pinned', pinned);
          if (forumId != null) q = q.eq('category_id', forumId);
          if (parshaNumber != null) q = q.eq('parasha_id', parshaNumber);
          if (after != null) q = q.or(after);
          return q.order('last_post_at', ascending: false).order('id', ascending: false);
        }

        final pages = await Future.wait([
          // Pinned threads come once, on the first page, however many there are.
          if (after == null) query(pinned: true),
          query(pinned: false, after: after == null ? null : _olderThan('last_post_at', after)).limit(limit),
        ]);
        return [for (final r in pages.expand((rows) => rows)) _thread(r)];
      });

  @override
  Future<ThreadSummary> thread(String id) => _call(() async {
        final r = await _db.from('threads').select(_threadColumns).eq('id', int.parse(id)).single();
        return _thread(r);
      });

  @override
  Future<List<Post>> posts(String threadId, {(DateTime, String)? before, int limit = ForumRepository.postsPageSize}) =>
      _call(() async {
        var q = _db
            .from('posts')
            .select('id, thread_id, author_id, reply_to_post_id, body, created_at, edited_at, hidden_at, '
                'author:profiles(display_name)')
            .eq('thread_id', int.parse(threadId))
            .isFilter('deleted_at', null);
        if (before != null) q = q.or(_olderThan('created_at', before));
        final latest = await q.order('created_at', ascending: false).order('id', ascending: false).limit(limit);
        final rows = latest.reversed.toList();
        final ids = [for (final r in rows) r['id'] as int];
        final todah = <int, int>{};
        final mine = <int>{};
        if (ids.isNotEmpty) {
          final reactions = await _db.from('reactions').select('post_id, user_id').inFilter('post_id', ids).eq('kind', 'todah');
          final me = _db.auth.currentUser?.id;
          for (final r in reactions) {
            final id = r['post_id'] as int;
            todah[id] = (todah[id] ?? 0) + 1;
            if (r['user_id'] == me) mine.add(id);
          }
        }
        return [
          for (final r in rows)
            Post(
              id: '${r['id']}',
              threadId: '${r['thread_id']}',
              authorId: r['author_id'] as String?,
              authorName: (r['author'] as Map<String, dynamic>?)?['display_name'] as String? ?? '',
              body: r['body'] as String,
              createdAt: DateTime.parse(r['created_at'] as String),
              editedAt: r['edited_at'] == null ? null : DateTime.parse(r['edited_at'] as String),
              hidden: r['hidden_at'] != null,
              replyToId: r['reply_to_post_id'] == null ? null : '${r['reply_to_post_id']}',
              todah: todah[r['id']] ?? 0,
              myTodah: mine.contains(r['id']),
            ),
        ];
      });

  @override
  Future<String> weeklyThread({required int parshaNumber, required int hebrewYear, required String title}) =>
      _call(() async {
        // The server builds the title from its own reference data.
        final id = await _db.rpc('ensure_weekly_thread', params: {
          'p_parasha_id': parshaNumber,
          'p_hebrew_year': hebrewYear,
        });
        return '$id';
      });

  // --- Writing ----------------------------------------------------------------

  @override
  Future<String> createThread({required int forumId, required String title, required String body, int? parshaNumber}) =>
      _call(() async {
        final id = await _db.rpc('create_thread', params: {
          'p_category_id': forumId,
          'p_title': title.trim(),
          'p_body': body.trim(),
          'p_parasha_id': parshaNumber,
        });
        return '$id';
      });

  @override
  Future<Post> reply(String threadId, String body, {String? replyToId}) => _call(() async {
        final r = await _db
            .from('posts')
            .insert({
              'thread_id': int.parse(threadId),
              'body': body.trim(),
              if (replyToId != null) 'reply_to_post_id': int.parse(replyToId),
            })
            .select('id, thread_id, author_id, body, created_at, hidden_at')
            .single();
        return Post(
          id: '${r['id']}',
          threadId: '${r['thread_id']}',
          authorId: r['author_id'] as String?,
          authorName: '',
          body: r['body'] as String,
          createdAt: DateTime.parse(r['created_at'] as String),
          hidden: r['hidden_at'] != null,
          replyToId: replyToId,
        );
      });

  @override
  Future<void> editPost(String postId, String body) =>
      _call(() => _db.from('posts').update({'body': body.trim()}).eq('id', int.parse(postId)));

  @override
  Future<void> deletePost(String postId) =>
      _call(() => _db.rpc('soft_delete_post', params: {'p_post_id': int.parse(postId)}));

  @override
  Future<void> setTodah(String postId, bool on) => _call(() async {
        if (on) {
          // Given already (a second tap, or another device) is given.
          await _db.from('reactions').upsert(
            {'post_id': int.parse(postId), 'user_id': _uid, 'kind': 'todah'},
            onConflict: 'post_id,user_id,kind',
            ignoreDuplicates: true,
          );
        } else {
          await _db.from('reactions').delete().eq('post_id', int.parse(postId)).eq('user_id', _uid).eq('kind', 'todah');
        }
      });

  // --- Safety -----------------------------------------------------------------

  @override
  Future<void> report({String? postId, String? threadId, required ReportReason reason, String? details}) =>
      _call(() => _db.from('reports').insert({
            if (postId != null) 'post_id': int.parse(postId),
            if (threadId != null) 'thread_id': int.parse(threadId),
            'reason': reason.db,
            if (details != null && details.trim().isNotEmpty) 'details': details.trim(),
          }));

  @override
  Future<void> block(String userId) => _call(() => _db.from('user_blocks').upsert(
        {'blocker_id': _uid, 'blocked_id': userId},
        onConflict: 'blocker_id,blocked_id',
        ignoreDuplicates: true,
      ));

  @override
  Future<void> unblock(String userId) =>
      _call(() => _db.from('user_blocks').delete().eq('blocker_id', _uid).eq('blocked_id', userId));

  @override
  Future<Set<String>> blockedUsers() => _call(() async {
        if (_db.auth.currentUser == null) return <String>{};
        final rows = await _db.from('user_blocks').select('blocked_id').eq('blocker_id', _uid);
        return {for (final r in rows) r['blocked_id'] as String};
      });

  @override
  Future<List<(String, String)>> blockedMembers() => _call(() async {
        if (_db.auth.currentUser == null) return <(String, String)>[];
        final rows = await _db
            .from('user_blocks')
            .select('blocked_id, blocked:profiles!user_blocks_blocked_id_fkey(display_name)')
            .eq('blocker_id', _uid);
        return [
          for (final r in rows)
            (r['blocked_id'] as String, (r['blocked'] as Map<String, dynamic>?)?['display_name'] as String? ?? ''),
        ];
      });

  // --- Moderation -------------------------------------------------------------

  @override
  Future<List<Report>> openReports() => _call(() async {
        final rows = await _db
            .from('reports')
            .select('id, post_id, reason, details, created_at, post:posts(body)')
            .eq('status', 'open')
            .order('created_at');
        return [
          for (final r in rows)
            Report(
              id: '${r['id']}',
              postId: r['post_id'] == null ? null : '${r['post_id']}',
              reason: ReportReason.values.firstWhere((x) => x.db == r['reason'], orElse: () => ReportReason.other),
              details: r['details'] as String?,
              createdAt: DateTime.parse(r['created_at'] as String),
              postBody: (r['post'] as Map<String, dynamic>?)?['body'] as String?,
            ),
        ];
      });

  @override
  Future<void> moderate(String action, String targetId, {String? reason}) => _call(
        () => _db.rpc('moderate', params: {'p_action': action, 'p_target_id': targetId, 'p_reason': reason}),
      );

  // --- Progress sync ----------------------------------------------------------

  @override
  Future<Map<String, dynamic>?> loadProgress() => _call(() async {
        final r = await _db.from('user_progress').select('data').eq('user_id', _uid).maybeSingle();
        return r?['data'] as Map<String, dynamic>?;
      });

  @override
  Future<void> saveProgress(Map<String, dynamic> data) =>
      _call(() => _db.from('user_progress').upsert({'user_id': _uid, 'data': data}));
}
