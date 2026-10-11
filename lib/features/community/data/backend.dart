import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../app/config.dart';
import '../../../app/providers.dart';
import '../../progress/domain/progress_models.dart';
import 'demo_forum_repository.dart';
import 'forum_repository.dart';
import 'supabase_forum_repository.dart';

/// The community backend: Supabase when configured, otherwise an on-device demo.
class Backend {
  const Backend(this.forums);

  final ForumRepository forums;

  static Future<Backend> initialize() async {
    if (AppConfig.hasBackend) {
      try {
        await Supabase.initialize(url: AppConfig.supabaseUrl, publishableKey: AppConfig.supabaseKey);
        return Backend(SupabaseForumRepository(Supabase.instance.client));
      } catch (e) {
        debugPrint('Supabase unavailable, using demo community: $e');
      }
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
