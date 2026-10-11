import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../../core/calendar/jewish_holidays.dart';
import '../../../core/calendar/local_date.dart';
import 'forum_repository.dart';
import 'models.dart';

/// An on-device stand-in for the community backend, used when no Supabase
/// project is configured (development, screenshots, tests). Nothing leaves
/// the device and content resets when the app restarts. Any 6-digit code
/// signs in.
///
/// Every forum starts with a few sample discussions in Hebrew and English,
/// dated back from now ([clock], for tests). With [samples] false, the
/// forums start empty but for the question in Questions & answers (thread
/// 1).
class DemoForumRepository implements ForumRepository {
  DemoForumRepository({bool samples = true, DateTime Function()? clock}) : _clock = clock ?? DateTime.now {
    _seed(samples: samples);
  }

  /// The time the samples are dated back from.
  final DateTime Function() _clock;

  @override
  bool get isDemo => true;

  /// Whether the weekly thread of a parsha's number, in the cycle that began
  /// in a Hebrew year, is this week's: that discussion starts with a few posts
  /// when it is first opened. The app sets it, as only the app knows the
  /// reader's schedule and clock; while it is null, no weekly thread is.
  bool Function(int parshaNumber, int hebrewYear)? isCurrentWeek;

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

  /// Shabbat and Yom Tov, by day, as [_postable] asks about them.
  final _restDays = <LocalDate, bool>{};

  void _seed({required bool samples}) {
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
    final now = _clock();
    for (final sample in samples ? _samples : _samples.where((s) => s.id == '1')) {
      _addSample(sample, now);
    }
  }

  void _addSample(_SampleThread sample, DateTime now) {
    final posts = [for (final p in sample.posts) p.post(sample.id, _sampleTime(now, p.ago))];
    _threads.add(ThreadSummary(
      id: sample.id,
      forumId: sample.forumId,
      title: sample.title,
      kind: sample.kind,
      authorId: posts.first.authorId,
      authorName: posts.first.authorName,
      postCount: posts.length,
      lastPostAt: posts.last.createdAt,
      createdAt: posts.first.createdAt,
      parshaNumber: sample.parshaNumber,
      pinned: sample.pinned,
      locked: sample.locked,
    ));
    _posts.addAll(posts);
  }

  /// [ago] before [now], counting only the time when one may post: never on
  /// Shabbat or Yom Tov, nor from 2 p.m. on the day before one, earlier than
  /// candle-lighting even in a northern winter. So no sample is dated when its
  /// author would have been keeping Shabbat.
  DateTime _sampleTime(DateTime now, Duration ago) {
    var t = now;
    var left = ago.inMinutes;
    // Back an hour at a time, each hour wholly postable or not: the limits
    // fall on the hour.
    while (left > 0 || !_postable(t)) {
      var start = DateTime(t.year, t.month, t.day, t.hour);
      // On the hour, the hour before; so too where a change of the clocks
      // leaves no start of the hour before [t].
      if (!start.isBefore(t)) start = t.subtract(const Duration(hours: 1));
      final span = t.difference(start).inMinutes;
      if (_postable(start)) {
        if (left <= span) return t.subtract(Duration(minutes: left));
        left -= span;
      }
      t = start;
    }
    return t;
  }

  bool _postable(DateTime t) {
    // Two days of Yom Tov, as the Diaspora keeps, so that a sample suits
    // either.
    bool rest(LocalDate day) => _restDays[day] ??= JewishHolidays.isRestDay(day, israel: false);
    final day = LocalDate.fromDateTime(t);
    return !rest(day) && (t.hour < 14 || !rest(day.addDays(1)));
  }

  /// Adds [threads] and [posts] as they are, for tests and screenshots.
  @visibleForTesting
  void seed({Iterable<ThreadSummary> threads = const [], Iterable<Post> posts = const []}) {
    _threads.addAll(threads);
    _posts.addAll(posts);
  }

  CommunityUser _requireUser() => _user ?? (throw const CommunityException('not_signed_in'));

  /// Counts again the posts in each of [threadIds], as the server does when
  /// a post is deleted.
  void _recount(Iterable<String> threadIds) {
    for (final id in threadIds.toSet()) {
      final i = _threads.indexWhere((t) => t.id == id);
      if (i >= 0) _threads[i] = _threads[i].copyWith(postCount: _posts.where((p) => p.threadId == id).length);
    }
  }

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
    final touched = {for (final p in _posts.where((p) => p.authorId == 'me')) p.threadId};
    _posts.removeWhere((p) => p.authorId == 'me');
    _threads.removeWhere((t) => t.authorId == 'me' && !_posts.any((p) => p.threadId == t.id));
    _recount(touched);
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
  Future<List<ThreadSummary>> threads({
    int? forumId,
    int? parshaNumber,
    (DateTime, String)? after,
    int limit = ForumRepository.threadsPageSize,
  }) async {
    final list = _threads
        .where((t) => forumId == null || t.forumId == forumId)
        .where((t) => parshaNumber == null || t.parshaNumber == parshaNumber)
        .toList()
      ..sort(ThreadSummary.byLatestActivity);
    return [
      if (after == null) ...list.where((t) => t.pinned),
      ...list.where((t) => !t.pinned && (after == null || _isBefore(t.lastPostAt, t.id, after))).take(limit),
    ];
  }

  /// Whether ([time], [id]) comes before [cursor], as the server compares
  /// them: by time, then by id.
  static bool _isBefore(DateTime time, String id, (DateTime, String) cursor) {
    final byTime = time.compareTo(cursor.$1);
    return byTime < 0 || (byTime == 0 && compareIds(id, cursor.$2) < 0);
  }

  @override
  Future<ThreadSummary> thread(String id) async =>
      _threads.firstWhere((t) => t.id == id, orElse: () => throw const CommunityException('thread_not_found'));

  @override
  Future<List<Post>> posts(String threadId, {(DateTime, String)? before, int limit = ForumRepository.postsPageSize}) async {
    final shown = _posts
        .where((p) => p.threadId == threadId && !_blocked.contains(p.authorId))
        .where((p) => before == null || _isBefore(p.createdAt, p.id, before))
        .toList()
      ..sort(Post.chronological);
    return [
      for (final p in shown.skip(max(0, shown.length - limit)))
        p.copyWith(
          todah: p.todah + (_todah[p.id]?.length ?? 0),
          myTodah: _user != null && (_todah[p.id]?.contains(_user!.id) ?? false),
          quote: _quote(p.replyToId),
        ),
    ];
  }

  /// The post [id] as a reply quotes it, unless it is gone or its author
  /// blocked, as the server's policies hide it.
  QuotedPost? _quote(String? id) {
    final p = id == null ? null : _posts.where((p) => p.id == id).firstOrNull;
    if (p == null || _blocked.contains(p.authorId)) return null;
    return QuotedPost(authorName: p.authorName, body: p.body);
  }

  @override
  Future<String> weeklyThread({required int parshaNumber, required int hebrewYear, required String title}) async {
    final existing = _threads.where((t) => t.kind == ThreadKind.weekly && t.parshaNumber == parshaNumber && t.hebrewYear == hebrewYear);
    if (existing.isNotEmpty) return existing.first.id;
    final now = _clock();
    final id = '${_nextId++}';
    // This week's starts with a few posts; any other is empty.
    final posts = (isCurrentWeek?.call(parshaNumber, hebrewYear) ?? false) ? _weeklyPosts(id, now) : const <Post>[];
    _threads.add(ThreadSummary(
      id: id,
      forumId: 1,
      title: title,
      kind: ThreadKind.weekly,
      authorName: '',
      postCount: posts.length,
      lastPostAt: posts.lastOrNull?.createdAt ?? now,
      createdAt: posts.firstOrNull?.createdAt ?? now,
      parshaNumber: parshaNumber,
      hebrewYear: hebrewYear,
    ));
    _posts.addAll(posts);
    return id;
  }

  /// The posts this week's discussion starts with, in thread [threadId]:
  /// all written this week, since the Sunday before [now], in the time when
  /// one may post. Opened early in the week, they are drawn closer together;
  /// opened before there has been any such time (on a Yom Tov that begins
  /// the week), the discussion starts empty.
  List<Post> _weeklyPosts(String threadId, DateTime now) {
    final sunday = LocalDate.fromDateTime(now).onOrBefore(0);
    final available = _postableMinutes(DateTime(sunday.year, sunday.month, sunday.day), now);
    if (available == 0) return const [];
    final oldest = _weeklySamples.map((p) => p.ago.inMinutes).reduce(max);
    // A little short of the week's start, so that none is dated on it.
    final share = min(1.0, available * 0.95 / oldest);
    final ids = {for (final p in _weeklySamples) p.id: '${_nextId++}'};
    return [
      for (final p in _weeklySamples)
        p.post(
          threadId,
          _sampleTime(now, Duration(minutes: (p.ago.inMinutes * share).round())),
          id: ids[p.id],
          replyTo: ids[p.replyTo],
        ),
    ];
  }

  /// The minutes from [from] to [to] when one may post, as [_sampleTime]
  /// counts them.
  int _postableMinutes(DateTime from, DateTime to) {
    var minutes = 0;
    for (var t = from; t.isBefore(to);) {
      var next = DateTime(t.year, t.month, t.day, t.hour + 1);
      // A change of the clocks can leave no next hour on the hour.
      if (!next.isAfter(t)) next = t.add(const Duration(hours: 1));
      if (next.isAfter(to)) next = to;
      if (_postable(t)) minutes += next.difference(t).inMinutes;
      t = next;
    }
    return minutes;
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
    _threads[i] = t.copyWith(postCount: t.postCount + 1, lastPostAt: now);
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
    _recount([p.threadId]);
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
        final hidden = _posts.where((p) => p.id == targetId).toList();
        _posts.removeWhere((p) => p.id == targetId);
        _recount([for (final p in hidden) p.threadId]);
      case 'lock_thread' || 'unlock_thread' || 'pin_thread' || 'unpin_thread':
        final i = _threads.indexWhere((t) => t.id == targetId);
        if (i < 0) return;
        final t = _threads[i];
        _threads[i] = t.copyWith(
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

/// A sample discussion of the demo: its posts in order, the first starting
/// it.
class _SampleThread {
  const _SampleThread({
    required this.id,
    required this.forumId,
    required this.title,
    required this.posts,
    this.kind = ThreadKind.discussion,
    this.parshaNumber,
    this.pinned = false,
    this.locked = false,
  });

  final String id;
  final int forumId;
  final String title;
  final List<_SamplePost> posts;
  final ThreadKind kind;
  final int? parshaNumber;
  final bool pinned;
  final bool locked;
}

/// A sample post by [author], written [ago] before the demo starts, perhaps
/// in reply to the post [replyTo].
class _SamplePost {
  const _SamplePost(this.id, this.author, this.ago, this.body, {this.todah = 0, this.replyTo});

  final String id;
  final String author;
  final Duration ago;
  final String body;
  final int todah;
  final String? replyTo;

  Post post(String threadId, DateTime createdAt, {String? id, String? replyTo}) => Post(
        id: id ?? this.id,
        threadId: threadId,
        authorId: _sampleAuthors[author],
        authorName: author,
        body: body,
        createdAt: createdAt,
        todah: todah,
        replyToId: replyTo ?? this.replyTo,
      );
}

/// The members who wrote the samples, by name.
const _sampleAuthors = {
  'Avraham': 'demo-author',
  'Rivka': 'demo-2',
  'Yosef': 'demo-yosef',
  'Miriam': 'demo-miriam',
  'Chana': 'demo-chana',
  'שירה': 'demo-shira',
  'דוד': 'demo-david',
};

/// The demo's discussions, two or three in each forum. Their post ids are
/// apart from those tests give their own posts (up to 250, and 9000 on).
const _samples = [
  // Parshat HaShavua: a pinned welcome from a moderator, then two
  // discussions. This week's thread starts as it is first opened.
  _SampleThread(
    id: '11',
    forumId: 1,
    kind: ThreadKind.announcement,
    pinned: true,
    title: 'Welcome: how the weekly discussions work',
    posts: [
      _SamplePost(
        '701',
        'Chana',
        Duration(days: 12),
        'Welcome! Every parsha has one shared discussion, which the “This week” card opens. Share a thought on '
            'the reading, a question on a Targum or a Rashi, or how you fit Shnayim Mikra into your week. Please '
            'keep to the community guidelines, and bring a source where you can.',
        todah: 8,
      ),
      _SamplePost('702', 'Yosef', Duration(days: 11, hours: 20), 'Thank you! Is it all right to write in Hebrew?',
          todah: 2, replyTo: '701'),
      _SamplePost('703', 'Chana', Duration(days: 11, hours: 18), 'Of course. Hebrew and English are both welcome here.',
          todah: 4, replyTo: '702'),
    ],
  ),
  _SampleThread(
    id: '12',
    forumId: 1,
    parshaNumber: 1,
    title: '״בקדמין״: איך אונקלוס מתרגם ׳בראשית׳',
    posts: [
      _SamplePost(
        '704',
        'דוד',
        Duration(days: 2),
        'רש״י כותב שלפי פשוטו המילה ׳בראשית׳ סמוכה למה שאחריה: ׳בראשית בריאת שמים וארץ׳. ואילו אונקלוס מתרגם '
            '׳בקדמין׳, כלומר ׳בתחילה׳. מישהו עמד על ההבדל?',
        todah: 5,
      ),
      _SamplePost(
        '705',
        'שירה',
        Duration(days: 1, hours: 20),
        'שמתי לב לזה כשקראתי את התרגום. רש״י מדייק שבכל המקרא ׳ראשית׳ דבוקה למילה שאחריה. כדאי לראות גם את '
            'הרמב״ן שם, שמאריך בזה.',
        todah: 3,
        replyTo: '704',
      ),
      _SamplePost('706', 'Avraham', Duration(days: 1, hours: 4),
          'Thank you both. I read the Targum of that verse twice after seeing this.',
          todah: 1),
    ],
  ),
  _SampleThread(
    id: '13',
    forumId: 1,
    parshaNumber: 35,
    title: 'Pacing the longest parsha',
    posts: [
      _SamplePost('707', 'Rivka', Duration(days: 5),
          'Naso is the longest parsha in the Torah, 176 verses. How do you pace yourselves in its week?',
          todah: 2),
      _SamplePost(
        '708',
        'Yosef',
        Duration(days: 4, hours: 20),
        'An aliyah a day works for me. The last three aliyot are mostly the offerings of the twelve Nesi’im, '
            'nearly the same passage each time, so they go faster than you’d expect.',
        todah: 7,
      ),
      _SamplePost('709', 'Rivka', Duration(days: 4, hours: 18), 'That’s encouraging. Thank you!', replyTo: '708'),
    ],
  ),

  // Questions & answers. Thread 1 is the one tests read and reply to: keep
  // its posts as they are.
  _SampleThread(
    id: '1',
    forumId: 2,
    kind: ThreadKind.question,
    title: 'Why read the Targum rather than a translation?',
    posts: [
      _SamplePost('1', 'Avraham', Duration(days: 1),
          'I read English more easily than Aramaic. Why does the Shulchan Aruch insist on Targum Onkelos?'),
      _SamplePost(
        '2',
        'Rivka',
        Duration(hours: 3),
        'The Shulchan Aruch (OC 285:2) allows Rashi in place of Targum because Rashi also explains the text. '
            'Many poskim hold a plain translation is a study aid but does not replace the Targum — worth asking '
            'your rav.',
        todah: 4,
      ),
    ],
  ),
  _SampleThread(
    id: '21',
    forumId: 2,
    kind: ThreadKind.question,
    title: 'עד מתי אפשר להשלים את הקריאה?',
    posts: [
      _SamplePost('710', 'שירה', Duration(days: 3),
          'קרה לי שלא הספקתי לסיים שניים מקרא לפני שבת. עד מתי אפשר עוד להשלים?',
          todah: 1),
      _SamplePost(
        '711',
        'Yosef',
        Duration(days: 2, hours: 22),
        'בשולחן ערוך (אורח חיים רפה, ד) כתוב שמצוה להשלים לפני הסעודה ביום השבת, ואם לא, אחרי הסעודה עד מנחה. '
            'יש אומרים שאפשר להשלים עד יום רביעי, ויש אומרים עד שמיני עצרת. המשנה ברורה (רפה, יב) כותב שזה רק '
            'בדיעבד, ולכתחילה קוראים את הפרשה בשבוע שלה. למעשה כדאי לשאול את הרב.',
        todah: 12,
        replyTo: '710',
      ),
      _SamplePost('712', 'שירה', Duration(days: 2, hours: 20), 'תודה רבה, זה מאוד עוזר!', replyTo: '711'),
    ],
  ),
  _SampleThread(
    id: '22',
    forumId: 2,
    kind: ThreadKind.question,
    title: 'Why read Numbers 32:3 a third time?',
    posts: [
      _SamplePost('713', 'Chana', Duration(days: 6),
          'The reader suggests reading Numbers 32:3 a third time, after the Targum. Where does that come from?',
          todah: 1),
      _SamplePost(
        '714',
        'Miriam',
        Duration(days: 5, hours: 20),
        'The Gemara (Berakhot 8a) says to complete the parsha twice in Mikra and once in Targum “even Atarot and '
            'Divon”, a verse that is almost all place names. For a verse with no Targum, Rashi holds that it is read '
            'three times in Hebrew, while Tosafot suggest reading another Targum instead. Your rav can tell you '
            'which practice to follow.',
        todah: 7,
        replyTo: '713',
      ),
    ],
  ),

  // Divrei Torah.
  _SampleThread(
    id: '31',
    forumId: 3,
    parshaNumber: 1,
    title: '“A speaking spirit” (Genesis 2:7)',
    posts: [
      _SamplePost(
        '715',
        'Rivka',
        Duration(days: 4),
        'Onkelos renders “and man became a living soul” (Genesis 2:7) as “a speaking spirit”, לרוח ממללא. In his '
            'reading, what makes us human is speech. A lovely thought for anyone who reads the parsha aloud each week.',
        todah: 9,
      ),
      _SamplePost(
        '716',
        'Chana',
        Duration(days: 3, hours: 18),
        'Rashi there says something close: animals are also called “a living soul”, but man’s is the most alive of '
            'all, since knowledge and speech were added to it.',
        todah: 6,
        replyTo: '715',
      ),
    ],
  ),
  _SampleThread(
    id: '32',
    forumId: 3,
    parshaNumber: 4,
    title: '״ואתגלי ליה״: איך אונקלוס מתרגם ׳וירא אליו׳',
    posts: [
      _SamplePost(
        '717',
        'דוד',
        Duration(days: 3),
        'אונקלוס מתרגם ״וירא אליו ה׳״ (בראשית יח, א) ״ואתגלי ליה ה׳״, כלומר ׳ונגלה אליו׳. בכל מקום הוא מרחיק '
            'מהכתוב תיאורים גשמיים, כך שקריאת התרגום מלמדת גם אמונה, לא רק מילים.',
        todah: 4,
      ),
      _SamplePost('718', 'Miriam', Duration(days: 2, hours: 6),
          'That’s why I love reading the Targum straight after the verse: it’s a commentary in a single line.',
          todah: 2, replyTo: '717'),
    ],
  ),

  // Chavruta & encouragement.
  _SampleThread(
    id: '41',
    forumId: 4,
    title: 'Shnayim Mikra with children',
    posts: [
      _SamplePost(
        '719',
        'Miriam',
        Duration(days: 2, hours: 3),
        'My children, 8 and 11, read the verses with me on Friday night, and I read the Targum. Any tips for keeping '
            'it a pleasure rather than a chore?',
        todah: 3,
      ),
      _SamplePost(
        '720',
        'Rivka',
        Duration(days: 1, hours: 22),
        'We read one aliyah at dinner each night, and each child picks one Rashi to read out loud. Short and every '
            'day works better for us than long and once.',
        todah: 5,
      ),
      _SamplePost('721', 'Chana', Duration(days: 1, hours: 8), 'Love the Rashi idea. We’re trying it this week!',
          replyTo: '720'),
    ],
  ),
  _SampleThread(
    id: '42',
    forumId: 4,
    title: 'מחפשת חברותא לקריאת התרגום',
    posts: [
      _SamplePost('722', 'שירה', Duration(hours: 9),
          'אני קוראת עלייה ביום, אבל את התרגום קשה לי לקרוא לבד. מישהי רוצה לקרוא איתי בטלפון, פעם בשבוע בערב?',
          todah: 1),
      _SamplePost('723', 'Miriam', Duration(hours: 2), 'אשמח! ימי רביעי בערב מתאימים לי.', todah: 2, replyTo: '722'),
    ],
  ),

  // App feedback: a request done, and locked by a moderator.
  _SampleThread(
    id: '51',
    forumId: 5,
    locked: true,
    title: 'A warmer theme for reading at night?',
    posts: [
      _SamplePost('724', 'Avraham', Duration(days: 9),
          'Could there be a warmer theme for reading at night? White is harsh on my eyes before bed.',
          todah: 3),
      _SamplePost(
        '725',
        'Chana',
        Duration(days: 7),
        'Thank you for the idea! The Display settings now have a Sepia theme, and a dark one. I’m locking this '
            'discussion now that it’s done.',
        todah: 10,
        replyTo: '724',
      ),
    ],
  ),
  _SampleThread(
    id: '52',
    forumId: 5,
    title: 'תודה על כתב רש״י',
    posts: [
      _SamplePost('726', 'דוד', Duration(days: 1, hours: 2),
          'רק רציתי לומר תודה. פירוש רש״י בכתב רש״י נראה בדיוק כמו בחומש שלי בבית.',
          todah: 6),
      _SamplePost('727', 'Yosef', Duration(hours: 20),
          'Agreed! And with the large text, my father can read along with us now.',
          todah: 4),
    ],
  ),
];

/// This week's discussion as the demo starts it, in words that suit any
/// parsha. Its ids are given as the thread is made.
const _weeklySamples = [
  _SamplePost('w1', 'Yosef', Duration(hours: 20),
      'Rishon and Sheni done on my commute. Reading the Targum aloud slows me down, in the best way.',
      todah: 3),
  _SamplePost('w2', 'שירה', Duration(hours: 6),
      'השבוע אני קוראת לפי הפרשיות הפתוחות והסתומות: כל פרשה פעמיים ואחר כך התרגום שלה. כך רואים את הסיפור כולו.',
      todah: 5),
  _SamplePost('w3', 'Miriam', Duration(minutes: 40), 'Same here! My children now ask what the Aramaic words mean.',
      todah: 1, replyTo: 'w1'),
];
