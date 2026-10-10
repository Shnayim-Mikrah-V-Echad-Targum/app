import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/features/community/data/models.dart';
import 'package:shnayim_mikra/features/community/data/supabase_forum_repository.dart';
import 'package:shnayim_mikra/features/community/ui/community_ui.dart';
import 'package:shnayim_mikra/l10n/app_localizations.dart';

void main() {
  group('a unique violation', () {
    String code(String index) =>
        SupabaseForumRepository.codeOf('duplicate key value violates unique constraint "$index"', '23505');

    test('of the display names means the name is taken', () {
      expect(code('profiles_display_name_ci'), 'name_taken');
    });

    test('of the reports means the post was reported already', () {
      expect(code('reports_one_per_reporter_post'), 'already_reported');
    });

    test('of anything else means the change was there already', () {
      expect(code('reactions_pkey'), 'duplicate');
      expect(code('user_blocks_pkey'), 'duplicate');
    });
  });

  test('other database errors keep their codes', () {
    expect(SupabaseForumRepository.codeOf('permission denied for table posts', '42501'), 'forbidden');
    expect(SupabaseForumRepository.codeOf('rate_limited: slow down', 'P0001'), 'rate_limited');
  });

  group('the message', () {
    final l = lookupAppLocalizations(const Locale('en'));

    test('for a post reported already says so, and nothing about names', () {
      expect(communityError(l, const CommunityException('already_reported')), "You've already reported this post.");
      expect(communityError(l, const CommunityException('name_taken')), 'That name is taken.');
    });

    test('is not needed when the change was there already', () {
      expect(alreadyDone(const CommunityException('duplicate')), isTrue);
      expect(alreadyDone(const CommunityException('name_taken')), isFalse);
      expect(alreadyDone(Exception('offline')), isFalse);
    });
  });
}
