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
    this.acceptedTerms = false,
  });

  final String id;
  final String displayName;
  final bool isModerator;
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

  /// Orders threads as the forum lists them: newest activity first, then
  /// the higher id.
  static int byLatestActivity(ThreadSummary a, ThreadSummary b) {
    final byTime = b.lastPostAt.compareTo(a.lastPostAt);
    return byTime != 0 ? byTime : compareIds(b.id, a.id);
  }

  ThreadSummary copyWith({int? postCount, DateTime? lastPostAt, bool? pinned, bool? locked}) => ThreadSummary(
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
      );
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

  /// "Todah" (thanks) reactions.
  final int todah;
  final bool myTodah;

  /// Orders posts as a thread reads: oldest first, then the lower id.
  static int chronological(Post a, Post b) {
    final byTime = a.createdAt.compareTo(b.createdAt);
    return byTime != 0 ? byTime : compareIds(a.id, b.id);
  }

  Post copyWith({int? todah, bool? myTodah, String? body, DateTime? editedAt}) => Post(
        id: id,
        threadId: threadId,
        authorId: authorId,
        authorName: authorName,
        body: body ?? this.body,
        createdAt: createdAt,
        editedAt: editedAt ?? this.editedAt,
        hidden: hidden,
        replyToId: replyToId,
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
