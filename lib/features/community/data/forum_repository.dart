import 'models.dart';

/// Everything the community UI needs. Implemented by Supabase in production
/// and by an on-device demo when no backend is configured.
abstract class ForumRepository {
  /// Whether this is the on-device demo (nothing leaves the device).
  bool get isDemo;

  // --- Auth ------------------------------------------------------------------
  CommunityUser? get currentUser;
  Stream<CommunityUser?> get userChanges;

  /// Emails a 6-digit sign-in code (no deep links needed on any platform).
  Future<void> sendCode(String email);
  Future<void> verifyCode(String email, String code);
  Future<void> signOut();

  /// Permanently deletes the account and everything the user posted.
  Future<void> deleteAccount();

  // --- Profile ---------------------------------------------------------------
  Future<Profile?> myProfile();
  Future<void> updateDisplayName(String name);
  Future<void> acceptGuidelines();

  // --- Reading ---------------------------------------------------------------
  Future<List<Forum>> forums();

  /// Threads in a forum (or across all forums), pinned first, newest
  /// activity first. Pass [before] to page.
  Future<List<ThreadSummary>> threads({int? forumId, int? parshaNumber, DateTime? before, int limit = 30});

  Future<ThreadSummary> thread(String id);

  /// Posts in a thread, oldest first.
  Future<List<Post>> posts(String threadId, {int limit = 200});

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
}
