import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikrah/features/community/data/models.dart';
import 'package:shnayim_mikrah/features/community/ui/community_ui.dart';
import 'package:shnayim_mikrah/l10n/app_localizations.dart';

void main() {
  group('the message', () {
    final l = lookupAppLocalizations(const Locale('en'));

    test('for a post reported already says so, and nothing about names', () {
      expect(communityError(l, const CommunityException('already_reported')), 'You’ve already reported this post.');
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
      expect(fieldFor('code_incomplete'), CommunityField.code);
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

    test('for a code cut short says how many digits it takes, in either language', () {
      expect(communityError(l, const CommunityException('code_incomplete')), 'Enter all 6 digits of the code.');
      final he = lookupAppLocalizations(const Locale('he'));
      expect(communityError(he, const CommunityException('code_incomplete')), 'יש להזין את כל 6 הספרות של הקוד.');
    });

    test('is not needed when the change was there already', () {
      expect(alreadyDone(const CommunityException('duplicate')), isTrue);
      expect(alreadyDone(const CommunityException('name_taken')), isFalse);
      expect(alreadyDone(Exception('offline')), isFalse);
    });
  });
}
