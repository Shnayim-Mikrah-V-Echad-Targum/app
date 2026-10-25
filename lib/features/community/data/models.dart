/// Community data types, independent of the backend.
library;

class CommunityUser {
  const CommunityUser({required this.id, required this.email});
  final String id;
  final String? email;

  // Value equality, so the same account announced again (as on every token
  // refresh) is not a change that refetches everything keyed on the user.
  @override
  bool operator ==(Object other) => other is CommunityUser && other.id == id && other.email == email;

  @override
  int get hashCode => Object.hash(id, email);
}

class Profile {
  const Profile({
    required this.id,
    required this.displayName,
    this.isModerator = false,
    this.isAdmin = false,
    this.acceptedTerms = false,
  });

  final String id;
  final String displayName;
  final bool isModerator;

  /// The site's owner or one of its administrators, who have the website's
  /// admin panel.
  final bool isAdmin;
  final bool acceptedTerms;

  /// Auto-generated names look like "user_1a2b3c4d" until the user picks one.
  bool get hasChosenName => !RegExp(r'^user_[0-9a-f]{8,32}$').hasMatch(displayName);
}

class Forum {
  const Forum({
    required this.id,
    required this.slug,
    required this.nameEn,
    required this.nameHe,
    this.descriptionEn = '',
    this.descriptionHe = '',
    this.locked = false,
  });

  final int id;
  final String slug;
  final String nameEn;
  final String nameHe;
  final String descriptionEn;
  final String descriptionHe;

  /// Only moderators may start threads here.
  final bool locked;

  String name(bool he) => he ? nameHe : nameEn;
  String description(bool he) => he ? descriptionHe : descriptionEn;
}

/// How busy a forum is, as the Community page lists it.
class ForumStats {
  const ForumStats({required this.threadCount, this.lastPostAt});

  /// The discussions the forum lists.
  final int threadCount;

  /// When one of them was last posted in; null while none has been (a
  /// weekly thread opened, but not yet posted in, is no sign of activity).
  final DateTime? lastPostAt;

  @override
  bool operator ==(Object other) =>
      other is ForumStats && other.threadCount == threadCount && other.lastPostAt == lastPostAt;

  @override
  int get hashCode => Object.hash(threadCount, lastPostAt);
}

/// Orders ids as the backend does: by number, as they are numbers in text.
int compareIds(String a, String b) {
  final (x, y) = (int.tryParse(a), int.tryParse(b));
  return x != null && y != null ? x.compareTo(y) : a.compareTo(b);
}

enum ThreadKind { discussion, weekly, question, announcement }

class ThreadSummary {
  const ThreadSummary({
    required this.id,
    required this.forumId,
    required this.title,
    required this.kind,
    required this.authorName,
    required this.postCount,
    required this.lastPostAt,
    required this.createdAt,
    this.authorId,
    this.parshaNumber,
    this.hebrewYear,
    this.pinned = false,
    this.locked = false,
    this.excerpt,
    this.todahTotal = 0,
  });

  final String id;
  final int forumId;
  final String title;
  final ThreadKind kind;
  final String? authorId;
  final String authorName;
  final int postCount;
  final DateTime lastPostAt;
  final DateTime createdAt;
  final int? parshaNumber;
  final int? hebrewYear;
  final bool pinned;
  final bool locked;

  /// The opening of the thread's first post, as [threadExcerpt] cuts it;
  /// null where there is none, or the reader may not see it (its author is
  /// blocked, or it is hidden pending review).
  final String? excerpt;

  /// The todah given to the thread's posts that the reader can see.
  final int todahTotal;

  /// Orders threads as the forum lists them: newest activity first, then
  /// the higher id.
  static int byLatestActivity(ThreadSummary a, ThreadSummary b) {
    final byTime = b.lastPostAt.compareTo(a.lastPostAt);
    return byTime != 0 ? byTime : compareIds(b.id, a.id);
  }

  ThreadSummary copyWith({
    int? postCount,
    DateTime? lastPostAt,
    bool? pinned,
    bool? locked,
    Object? excerpt = _keep,
    int? todahTotal,
  }) =>
      ThreadSummary(
        id: id,
        forumId: forumId,
        title: title,
        kind: kind,
        authorId: authorId,
        authorName: authorName,
        postCount: postCount ?? this.postCount,
        lastPostAt: lastPostAt ?? this.lastPostAt,
        createdAt: createdAt,
        parshaNumber: parshaNumber,
        hebrewYear: hebrewYear,
        pinned: pinned ?? this.pinned,
        locked: locked ?? this.locked,
        excerpt: identical(excerpt, _keep) ? this.excerpt : excerpt as String?,
        todahTotal: todahTotal ?? this.todahTotal,
      );

  static const _keep = Object();
}

/// [message] after [verse], quoted as a question about a verse begins
/// ("Ask about this verse"): "> " and the verse's Hebrew, a blank line, then
/// the question. With [leftToRight], for a question written in English, say,
/// a left-to-right mark comes first, so that the post as plain text runs
/// from the left, as its question does, rather than taking its direction
/// from the Hebrew quoted first. [splitVerseQuote] parts it again.
String withVerseQuote(String verse, String message, {required bool leftToRight}) =>
    '${leftToRight ? '\u200E' : ''}> $verse\n\n$message';

/// [body] parted into the verse it quotes, as a question about a verse
/// begins ([withVerseQuote]), and the rest, the question. A body quotes a
/// verse where it begins with "> " (after a left-to-right mark, perhaps) and
/// Hebrew: the verse runs to the first blank line, or to the end where there
/// is none (the question edited away, or an excerpt cut short within the
/// verse), leaving no rest. Any other body, a quote of English words among
/// them, quotes none: verse is null, and the rest is the body.
({String? verse, String rest}) splitVerseQuote(String body) {
  final quote = _verseQuoteStart.matchAsPrefix(body);
  if (quote == null) return (verse: null, rest: body);
  final end = body.indexOf('\n\n', quote.end);
  return end < 0
      ? (verse: body.substring(quote.end), rest: '')
      : (verse: body.substring(quote.end, end), rest: body.substring(end + 2));
}

/// How a body that quotes a verse begins, up to the verse's first letter.
/// The server's listing reads it so too
/// (excerptOf, tool/cloudflare/src/community.js).
final _verseQuoteStart = RegExp('\u200E?> (?=[\u0590-\u05FF])');

/// The excerpt of a thread whose first post is [body], as the server's
/// listing (excerptOf, tool/cloudflare/src/community.js) gives it:
/// the post with its spaces and line breaks run together, and past
/// [threadExcerptLength] characters cut after the last whole word that fits
/// (or one short of the length, where that would lose more than 40, as in a
/// long link), with an ellipsis. A question about a verse is taken from
/// after the verse it quotes ([splitVerseQuote]), so that its excerpt is the
/// question. Null for a post of nothing but spaces, or but the verse.
String? threadExcerpt(String body) {
  final text = splitVerseQuote(body).rest.trim().replaceAll(_spaces, ' ');
  if (text.isEmpty) return null;
  if (text.runes.length <= threadExcerptLength) return text;
  // Counted in characters, as Postgres counts them, not UTF-16 units.
  String take(int n) => String.fromCharCodes(text.runes.take(n));
  final cut = RegExp(r'^(.*\S)\s', dotAll: true).firstMatch(take(threadExcerptLength + 1))?.group(1);
  final word = cut != null && cut.runes.length >= threadExcerptLength - 40 ? cut : take(threadExcerptLength - 1);
  return '$word…';
}

/// The most characters of a post a thread's excerpt holds, before its
/// ellipsis.
const threadExcerptLength = 140;

final _spaces = RegExp(r'\s+');

/// The post a reply answers, as quoted above the reply: fetched with it, so
/// that it shows even when that post is on an earlier page, not loaded.
class QuotedPost {
  const QuotedPost({required this.authorName, required this.body});
  final String authorName;
  final String body;
}

class Post {
  const Post({
    required this.id,
    required this.threadId,
    required this.authorName,
    required this.body,
    required this.createdAt,
    this.authorId,
    this.editedAt,
    this.hidden = false,
    this.replyToId,
    this.quote,
    this.todah = 0,
    this.myTodah = false,
  });

  final String id;
  final String threadId;
  final String? authorId;
  final String authorName;
  final String body;
  final DateTime createdAt;
  final DateTime? editedAt;

  /// Hidden pending moderator review (visible to the author and moderators).
  final bool hidden;
  final String? replyToId;

  /// The post [replyToId] names, if the reader may see it.
  final QuotedPost? quote;

  /// "Todah" (thanks) reactions.
  final int todah;
  final bool myTodah;

  /// Orders posts as a thread reads: oldest first, then the lower id.
  static int chronological(Post a, Post b) {
    final byTime = a.createdAt.compareTo(b.createdAt);
    return byTime != 0 ? byTime : compareIds(a.id, b.id);
  }

  Post copyWith({int? todah, bool? myTodah, String? body, DateTime? editedAt, QuotedPost? quote}) => Post(
        id: id,
        threadId: threadId,
        authorId: authorId,
        authorName: authorName,
        body: body ?? this.body,
        createdAt: createdAt,
        editedAt: editedAt ?? this.editedAt,
        hidden: hidden,
        replyToId: replyToId,
        quote: quote ?? this.quote,
        todah: todah ?? this.todah,
        myTodah: myTodah ?? this.myTodah,
      );
}

enum ReportReason { spam, lashonHara, disrespect, misinformation, offTopic, other }

extension ReportReasonDb on ReportReason {
  String get db => switch (this) {
        ReportReason.spam => 'spam',
        ReportReason.lashonHara => 'lashon_hara',
        ReportReason.disrespect => 'disrespect',
        ReportReason.misinformation => 'misinformation',
        ReportReason.offTopic => 'off_topic',
        ReportReason.other => 'other',
      };
}

class Report {
  const Report({required this.id, required this.reason, required this.createdAt, this.postId, this.details, this.postBody});
  final String id;
  final ReportReason reason;
  final DateTime createdAt;
  final String? postId;
  final String? details;
  final String? postBody;
}

/// A problem reported by the backend, with a stable code for localized
/// messages (e.g. "rate_limited", "thread_locked").
class CommunityException implements Exception {
  const CommunityException(this.code, [this.message]);
  final String code;
  final String? message;

  @override
  String toString() => 'CommunityException($code${message == null ? '' : ': $message'})';
}
