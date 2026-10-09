/// Community data types, independent of the backend.
library;

class CommunityUser {
  const CommunityUser({required this.id, required this.email});
  final String id;
  final String? email;
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
