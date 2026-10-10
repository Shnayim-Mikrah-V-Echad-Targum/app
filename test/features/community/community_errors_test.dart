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

    test('for an error about a field is shown under that field', () {
      expect(fieldFor('title_too_short'), CommunityField.title);
      for (final code in ['too_short', 'too_many_links', 'content_rejected', 'duplicate_post']) {
        expect(fieldFor(code), CommunityField.body, reason: code);
      }
      expect(fieldFor('invalid_email'), CommunityField.email);
      expect(fieldFor('email_address_invalid'), CommunityField.email);
      expect(fieldFor('invalid_code'), CommunityField.code);
      expect(fieldFor('otp_expired'), CommunityField.code);
      expect(fieldFor('invalid_name'), CommunityField.name);
      expect(fieldFor('name_taken'), CommunityField.name);
    });

    test('for a rate limit, or anything else about no one field, is a status message', () {
      for (final code in ['rate_limited', 'slow_mode', 'banned', 'shabbat_closed', 'forbidden', 'nonsense']) {
        expect(fieldFor(code), isNull, reason: code);
      }
      expect(fieldOf(Exception('offline')), isNull);
      expect(fieldOf(const CommunityException('too_short')), CommunityField.body);
    });

    test('is not needed when the change was there already', () {
      expect(alreadyDone(const CommunityException('duplicate')), isTrue);
      expect(alreadyDone(const CommunityException('name_taken')), isFalse);
      expect(alreadyDone(Exception('offline')), isFalse);
    });
  });
}
