import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../app/config.dart';
import '../../../app/providers.dart';
import '../../progress/domain/progress_models.dart';
import 'demo_forum_repository.dart';
import 'forum_repository.dart';
import 'worker_forum_repository.dart';

/// The community backend: the site's own server ([WorkerForumRepository])
/// where the build knows the site ([AppConfig.communityServer]), and
/// otherwise an on-device demo. Without
/// the community ([AppConfig.communityEnabled]) it is the demo whatever the
/// build configures, which nothing shows: the app reaches no server for it,
/// and nobody can be signed in to back progress up.
class Backend {
  const Backend(this.forums);

  final ForumRepository forums;

  /// The backend, once [preferences], where the site's server keeps the
  /// signed-in account, are open.
  static Future<Backend> initialize({required Future<SharedPreferences> preferences}) async {
    if (!AppConfig.communityEnabled) return Backend(DemoForumRepository());
    if (AppConfig.communityServer case final server?) {
      final forums = WorkerForumRepository(server: server, prefs: await preferences);
      unawaited(forums.refreshSession());
      return Backend(forums);
    }
    return Backend(DemoForumRepository());
  }
}

final backendProvider = Provider<Backend>((ref) => Backend(DemoForumRepository()));

final forumRepositoryProvider = Provider<ForumRepository>((ref) {
  final forums = ref.watch(backendProvider).forums;
  if (forums is DemoForumRepository) {
    // The demo starts this week's discussion with a few posts, and only the
    // app knows which week that is, by the reader's schedule and clock.
    bool current(int parshaNumber, int hebrewYear) {
      final week = ref.read(currentWeekProvider);
      return week.portion.number == parshaNumber && cycleYearOf(week.portion, week.occasion) == hebrewYear;
    }

    forums.isCurrentWeek = current;
    ref.onDispose(() {
      if (forums.isCurrentWeek == current) forums.isCurrentWeek = null;
    });
  }
  return forums;
});
