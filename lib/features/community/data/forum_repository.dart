import 'models.dart';

/// Everything the community UI needs. Implemented by the site's server in production
/// and by an on-device demo when no backend is configured.
abstract class ForumRepository {
  /// Whether this is the on-device demo (nothing leaves the device).
  bool get isDemo;

  // --- Auth ------------------------------------------------------------------
  CommunityUser? get currentUser;
  Stream<CommunityUser?> get userChanges;

  /// Emails a 6-digit sign-in code (no deep links needed on any platform).
  Future<void> sendCode(String email);
  /// Signs in with the emailed [code]. An account with an authenticator app
  /// asks for its code too ([secondStep], or one of its recovery codes): without
  /// it, this fails with `totp_required`, and the emailed code stays good to
  /// send again with it; a wrong one fails with `invalid_totp`.
  Future<void> verifyCode(String email, String code, {String? secondStep});
  Future<void> signOut();

  /// Permanently deletes the account and everything the user posted.
  Future<void> deleteAccount();

  // --- Profile ---------------------------------------------------------------
  Future<Profile?> myProfile();
  Future<void> updateDisplayName(String name);
  Future<void> acceptGuidelines();

  // --- Reading ---------------------------------------------------------------
  Future<List<Forum>> forums();

  /// How many discussions each forum lists, and when one was last posted
  /// in, by forum id.
  Future<Map<int, ForumStats>> forumStats();

  /// How many unpinned threads [threads] returns at most, by default.
  static const threadsPageSize = 30;

  /// How many posts [posts] returns at most, by default.
  static const postsPageSize = 100;

  /// Threads in a forum (or across all forums), newest activity first, each
  /// with its excerpt and the todah given to its posts, as the reader may see
  /// them.
  ///
  /// The first page (no [after]) holds every pinned thread, then at most
  /// [limit] others. Each later page holds the next [limit] unpinned threads
  /// after [after], the last activity and id of the last unpinned thread
  /// shown. Threads with the same last activity are ordered by id, so no
  /// page repeats or skips one.
  Future<List<ThreadSummary>> threads({
    int? forumId,
    int? parshaNumber,
    (DateTime, String)? after,
    int limit = threadsPageSize,
  });

  /// The thread [id]. Fails with [threadNotFound] where there is none the
  /// reader may see: a link to one deleted, say.
  Future<ThreadSummary> thread(String id);

  /// The code of the [CommunityException] that [thread] fails with for a
  /// thread that isn't there.
  static const threadNotFound = 'thread_not_found';

  /// The latest [limit] posts in a thread, or with [before] (the time and id
  /// of the earliest post shown) the [limit] posts just before it. Either
  /// way they are returned oldest first, to be read in order.
  Future<List<Post>> posts(String threadId, {(DateTime, String)? before, int limit = postsPageSize});

  /// The shared discussion thread for a parsha in a given year, created on
  /// first use.
  Future<String> weeklyThread({required int parshaNumber, required int hebrewYear, required String title});

  // --- Writing ---------------------------------------------------------------
  Future<String> createThread({required int forumId, required String title, required String body, int? parshaNumber});
  Future<Post> reply(String threadId, String body, {String? replyToId});
  Future<void> editPost(String postId, String body);
  Future<void> deletePost(String postId);
  Future<void> setTodah(String postId, bool on);

  // --- Safety ----------------------------------------------------------------
  Future<void> report({String? postId, String? threadId, required ReportReason reason, String? details});
  Future<void> block(String userId);
  Future<void> unblock(String userId);
  Future<Set<String>> blockedUsers();

  /// Blocked members with their display names, for managing the list.
  Future<List<(String id, String name)>> blockedMembers();

  // --- Moderation ------------------------------------------------------------
  Future<List<Report>> openReports();
  Future<void> moderate(String action, String targetId, {String? reason});

  // --- Progress sync ---------------------------------------------------------
  Future<Map<String, dynamic>?> loadProgress();
  Future<void> saveProgress(Map<String, dynamic> data);

  // --- The website -------------------------------------------------------------

  /// A link that opens [page] of the website signed in as the app is, or null
  /// where there is no website (the demo).
  Future<Uri?> siteLink(SitePage page);
}

/// The website's pages the account page opens: the account's own (its
/// password, passkeys and authenticator app), and for an admin the admin
/// panel.
enum SitePage {
  account('/account'),
  admin('/account/admin');

  const SitePage(this.path);
  final String path;
}
