import 'dart:async';

import 'forum_repository.dart';
import 'models.dart';

/// An on-device stand-in for the community backend, used when no Supabase
/// project is configured (development, screenshots, tests). Nothing leaves
/// the device and content resets when the app restarts. Any 6-digit code
/// signs in.
class DemoForumRepository implements ForumRepository {
  DemoForumRepository() {
    _seed();
  }

  @override
  bool get isDemo => true;

  final _users = StreamController<CommunityUser?>.broadcast();
  CommunityUser? _user;
  Profile? _profile;
  final _forums = <Forum>[];
  final _threads = <ThreadSummary>[];
  final _posts = <Post>[];
  final _todah = <String, Set<String>>{};
  final _blocked = <String>{};
  final _reports = <Report>[];

  /// The posts each member has reported, once each as on the server.
  final _reported = <(String, String)>{};
  final _progress = <String, Map<String, dynamic>>{};
  int _nextId = 1000;
  DateTime? _lastPost;

  static const _sampleAuthor = 'demo-author';

  void _seed() {
    _forums.addAll(const [
      Forum(
        id: 1,
        slug: 'parsha',
        nameEn: 'Parshat HaShavua',
        nameHe: 'פרשת השבוע',
        descriptionEn: 'A discussion thread for every week\'s parsha.',
        descriptionHe: 'שרשור דיון לכל פרשת שבוע.',
      ),
      Forum(
        id: 2,
        slug: 'questions',
        nameEn: 'Questions & answers',
        nameHe: 'שאלות ותשובות',
        descriptionEn: 'Ask about a verse, a Targum or a Rashi.',
        descriptionHe: 'שאלות על פסוק, תרגום או רש״י.',
      ),
      Forum(
        id: 3,
        slug: 'divrei-torah',
        nameEn: 'Divrei Torah',
        nameHe: 'דברי תורה',
        descriptionEn: 'Share an insight on the parsha.',
        descriptionHe: 'שיתוף חידוש על הפרשה.',
      ),
      Forum(
        id: 4,
        slug: 'chavruta',
        nameEn: 'Chavruta & encouragement',
        nameHe: 'חברותא ועידוד',
        descriptionEn: 'Find a learning partner and keep each other going.',
        descriptionHe: 'מציאת חברותא ועידוד הדדי.',
      ),
      Forum(
        id: 5,
        slug: 'feedback',
        nameEn: 'App feedback',
        nameHe: 'משוב על האפליקציה',
        descriptionEn: 'Ideas, bugs and accessibility feedback.',
        descriptionHe: 'רעיונות, תקלות ומשוב על נגישות.',
      ),
    ]);
    final now = DateTime.now();
    final t = ThreadSummary(
      id: '1',
      forumId: 2,
      title: 'Why read the Targum rather than a translation?',
      kind: ThreadKind.question,
      authorId: _sampleAuthor,
      authorName: 'Avraham',
      postCount: 2,
      lastPostAt: now.subtract(const Duration(hours: 3)),
      createdAt: now.subtract(const Duration(days: 1)),
    );
    _threads.add(t);
    _posts.addAll([
      Post(
        id: '1',
        threadId: '1',
        authorId: _sampleAuthor,
        authorName: 'Avraham',
        body: 'I read English more easily than Aramaic. Why does the Shulchan Aruch insist on Targum Onkelos?',
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      Post(
        id: '2',
        threadId: '1',
        authorId: 'demo-2',
        authorName: 'Rivka',
        body: 'The Shulchan Aruch (OC 285:2) allows Rashi in place of Targum because Rashi also explains the text. '
            'Many poskim hold a plain translation is a study aid but does not replace the Targum — worth asking your rav.',
        createdAt: now.subtract(const Duration(hours: 3)),
        todah: 4,
      ),
    ]);
  }

  CommunityUser _requireUser() => _user ?? (throw const CommunityException('not_signed_in'));

  // --- Auth -------------------------------------------------------------------

  @override
  CommunityUser? get currentUser => _user;

  @override
  Stream<CommunityUser?> get userChanges => _users.stream;

  @override
  Future<void> sendCode(String email) async {
    if (!email.contains('@')) throw const CommunityException('invalid_email');
  }

  @override
  Future<void> verifyCode(String email, String code) async {
    if (!RegExp(r'^\d{6}$').hasMatch(code.trim())) throw const CommunityException('invalid_code');
    _user = CommunityUser(id: 'me', email: email);
    _profile = Profile(id: 'me', displayName: 'user_${email.hashCode.toUnsigned(32).toRadixString(16).padLeft(8, '0')}', isModerator: true);
    _users.add(_user);
  }

  @override
  Future<void> signOut() async {
    _user = null;
    _profile = null;
    _users.add(null);
  }

  @override
  Future<void> deleteAccount() async {
    _posts.removeWhere((p) => p.authorId == 'me');
    _threads.removeWhere((t) => t.authorId == 'me' && !_posts.any((p) => p.threadId == t.id));
    for (final givers in _todah.values) {
      givers.remove('me');
    }
    _reported.removeWhere((r) => r.$1 == 'me');
    _progress.remove('me');
    await signOut();
  }

  // --- Profile ----------------------------------------------------------------

  @override
  Future<Profile?> myProfile() async => _profile;

  @override
  Future<void> updateDisplayName(String name) async {
    _requireUser();
    final n = name.trim();
    if (n.length < 2 || n.length > 40) throw const CommunityException('invalid_name');
    _profile = Profile(id: 'me', displayName: n, isModerator: _profile!.isModerator, acceptedTerms: _profile!.acceptedTerms);
  }

  @override
  Future<void> acceptGuidelines() async {
    _requireUser();
    _profile = Profile(id: 'me', displayName: _profile!.displayName, isModerator: _profile!.isModerator, acceptedTerms: true);
  }

  // --- Reading ----------------------------------------------------------------

  @override
  Future<List<Forum>> forums() async => List.of(_forums);

  @override
  Future<List<ThreadSummary>> threads({int? forumId, int? parshaNumber, DateTime? before, int limit = 30}) async {
    final list = _threads
        .where((t) => forumId == null || t.forumId == forumId)
        .where((t) => parshaNumber == null || t.parshaNumber == parshaNumber)
        .where((t) => before == null || t.lastPostAt.isBefore(before))
        .toList()
      ..sort((a, b) {
        if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
        return b.lastPostAt.compareTo(a.lastPostAt);
      });
    return list.take(limit).toList();
  }

  @override
  Future<ThreadSummary> thread(String id) async =>
      _threads.firstWhere((t) => t.id == id, orElse: () => throw const CommunityException('thread_not_found'));

  @override
  Future<List<Post>> posts(String threadId, {int limit = 200}) async => [
        for (final p in _posts.where((p) => p.threadId == threadId && !_blocked.contains(p.authorId)))
          p.copyWith(
            todah: p.todah + (_todah[p.id]?.length ?? 0),
            myTodah: _user != null && (_todah[p.id]?.contains(_user!.id) ?? false),
          ),
      ].take(limit).toList();

  @override
  Future<String> weeklyThread({required int parshaNumber, required int hebrewYear, required String title}) async {
    final existing = _threads.where((t) => t.kind == ThreadKind.weekly && t.parshaNumber == parshaNumber && t.hebrewYear == hebrewYear);
    if (existing.isNotEmpty) return existing.first.id;
    final now = DateTime.now();
    final t = ThreadSummary(
      id: '${_nextId++}',
      forumId: 1,
      title: title,
      kind: ThreadKind.weekly,
      authorName: '',
      postCount: 0,
      lastPostAt: now,
      createdAt: now,
      parshaNumber: parshaNumber,
      hebrewYear: hebrewYear,
      pinned: true,
    );
    _threads.add(t);
    return t.id;
  }

  // --- Writing ----------------------------------------------------------------

  void _checkCanPost(String body) {
    _requireUser();
    if (!(_profile?.acceptedTerms ?? false)) throw const CommunityException('terms_not_accepted');
    final now = DateTime.now();
    if (_lastPost != null && now.difference(_lastPost!) < const Duration(seconds: 5)) {
      throw const CommunityException('rate_limited');
    }
    if (body.trim().length < 2) throw const CommunityException('too_short');
    _lastPost = now;
  }

  @override
  Future<String> createThread({required int forumId, required String title, required String body, int? parshaNumber}) async {
    _checkCanPost(body);
    if (title.trim().length < 5) throw const CommunityException('title_too_short');
    final now = DateTime.now();
    final id = '${_nextId++}';
    _threads.add(ThreadSummary(
      id: id,
      forumId: forumId,
      title: title.trim(),
      kind: ThreadKind.discussion,
      authorId: 'me',
      authorName: _profile!.displayName,
      postCount: 1,
      lastPostAt: now,
      createdAt: now,
      parshaNumber: parshaNumber,
    ));
    _posts.add(Post(id: '${_nextId++}', threadId: id, authorId: 'me', authorName: _profile!.displayName, body: body.trim(), createdAt: now));
    return id;
  }

  @override
  Future<Post> reply(String threadId, String body, {String? replyToId}) async {
    final t = await thread(threadId);
    if (t.locked && !(_profile?.isModerator ?? false)) throw const CommunityException('thread_locked');
    _checkCanPost(body);
    final now = DateTime.now();
    final post = Post(
      id: '${_nextId++}',
      threadId: threadId,
      authorId: 'me',
      authorName: _profile!.displayName,
      body: body.trim(),
      createdAt: now,
      replyToId: replyToId,
    );
    _posts.add(post);
    final i = _threads.indexWhere((x) => x.id == threadId);
    _threads[i] = ThreadSummary(
      id: t.id,
      forumId: t.forumId,
      title: t.title,
      kind: t.kind,
      authorId: t.authorId,
      authorName: t.authorName,
      postCount: t.postCount + 1,
      lastPostAt: now,
      createdAt: t.createdAt,
      parshaNumber: t.parshaNumber,
      hebrewYear: t.hebrewYear,
      pinned: t.pinned,
      locked: t.locked,
    );
    return post;
  }

  @override
  Future<void> editPost(String postId, String body) async {
    final i = _posts.indexWhere((p) => p.id == postId && p.authorId == 'me');
    if (i < 0) throw const CommunityException('forbidden');
    _posts[i] = _posts[i].copyWith(body: body.trim(), editedAt: DateTime.now());
  }

  @override
  Future<void> deletePost(String postId) async {
    final p = _posts.where((p) => p.id == postId).firstOrNull;
    if (p == null) throw const CommunityException('not_found');
    if (p.authorId != 'me' && !(_profile?.isModerator ?? false)) throw const CommunityException('forbidden');
    _posts.remove(p);
  }

  @override
  Future<void> setTodah(String postId, bool on) async {
    final user = _requireUser().id;
    final set = _todah.putIfAbsent(postId, () => {});
    on ? set.add(user) : set.remove(user);
  }

  // --- Safety -----------------------------------------------------------------

  @override
  Future<void> report({String? postId, String? threadId, required ReportReason reason, String? details}) async {
    final user = _requireUser().id;
    if (postId != null && !_reported.add((user, postId))) throw const CommunityException('already_reported');
    _reports.add(Report(
      id: '${_nextId++}',
      postId: postId,
      reason: reason,
      details: details,
      createdAt: DateTime.now(),
      postBody: _posts.where((p) => p.id == postId).firstOrNull?.body,
    ));
  }

  @override
  Future<void> block(String userId) async => _blocked.add(userId);

  @override
  Future<void> unblock(String userId) async => _blocked.remove(userId);

  @override
  Future<Set<String>> blockedUsers() async => Set.of(_blocked);

  @override
  Future<List<(String, String)>> blockedMembers() async => [
        for (final id in _blocked) (id, _posts.where((p) => p.authorId == id).firstOrNull?.authorName ?? id),
      ];

  // --- Moderation -------------------------------------------------------------

  @override
  Future<List<Report>> openReports() async => List.of(_reports);

  @override
  Future<void> moderate(String action, String targetId, {String? reason}) async {
    if (!(_profile?.isModerator ?? false)) throw const CommunityException('forbidden');
    switch (action) {
      case 'resolve_report' || 'dismiss_report':
        _reports.removeWhere((r) => r.id == targetId);
      case 'hide_post':
        _posts.removeWhere((p) => p.id == targetId);
      case 'lock_thread' || 'unlock_thread' || 'pin_thread' || 'unpin_thread':
        final i = _threads.indexWhere((t) => t.id == targetId);
        if (i < 0) return;
        final t = _threads[i];
        _threads[i] = ThreadSummary(
          id: t.id,
          forumId: t.forumId,
          title: t.title,
          kind: t.kind,
          authorId: t.authorId,
          authorName: t.authorName,
          postCount: t.postCount,
          lastPostAt: t.lastPostAt,
          createdAt: t.createdAt,
          parshaNumber: t.parshaNumber,
          hebrewYear: t.hebrewYear,
          pinned: action == 'pin_thread' ? true : (action == 'unpin_thread' ? false : t.pinned),
          locked: action == 'lock_thread' ? true : (action == 'unlock_thread' ? false : t.locked),
        );
    }
  }

  // --- Progress sync ----------------------------------------------------------

  @override
  Future<Map<String, dynamic>?> loadProgress() async => _progress[_requireUser().id];

  @override
  Future<void> saveProgress(Map<String, dynamic> data) async => _progress[_requireUser().id] = data;
}
