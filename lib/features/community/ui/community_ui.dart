import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/text/hebrew_text.dart';
import '../../../data/models/parsha.dart';
import '../../../l10n/app_localizations.dart';
import '../../../ui/l10n.dart';
import '../data/backend.dart';
import '../data/community_providers.dart';
import '../data/models.dart';

/// A localized message for a community error.
String communityError(AppLocalizations l, Object e) {
  if (e is! CommunityException) return l.errNetwork;
  return switch (e.code) {
    'rate_limited' || 'slow_mode' => l.errRateLimited,
    'thread_locked' => l.errThreadLocked,
    'terms_not_accepted' => l.errTerms,
    'banned' => l.errBanned,
    'silenced_until' => l.errSilenced,
    'content_rejected' => l.errContent,
    'duplicate_post' => l.errDuplicate,
    'too_many_links' => l.errLinks,
    'daily_limit_new_user' || 'daily_thread_limit_new_user' => l.errDailyLimit,
    'name_taken' => l.errNameTaken,
    'invalid_name' => l.errInvalidName,
    'invalid_code' || 'otp_expired' => l.errInvalidCode,
    'invalid_email' || 'email_address_invalid' => l.errInvalidEmail,
    'not_signed_in' => l.errNotSignedIn,
    'forbidden' || 'category_restricted' || 'kind_not_allowed' => l.errForbidden,
    'shabbat_closed' => l.errShabbat,
    'too_short' => l.errTooShort,
    'title_too_short' => l.errTitleTooShort,
    _ => l.errorGeneric,
  };
}

/// "5 minutes ago", or a date for older times.
String relativeTime(BuildContext context, DateTime time) {
  final l = context.l10n;
  final diff = DateTime.now().difference(time);
  if (diff.inMinutes < 1) return l.timeJustNow;
  if (diff.inMinutes < 60) return l.timeMinutesAgo(diff.inMinutes);
  if (diff.inHours < 24) return l.timeHoursAgo(diff.inHours);
  return MaterialLocalizations.of(context).formatMediumDate(time.toLocal());
}

/// Absolute date and time, for screen readers and tooltips.
String absoluteTime(BuildContext context, DateTime time) {
  final m = MaterialLocalizations.of(context);
  final t = time.toLocal();
  return '${m.formatFullDate(t)}, ${m.formatTimeOfDay(TimeOfDay.fromDateTime(t))}';
}

/// Text direction from the first strong character, so Hebrew and English
/// posts each display correctly.
TextDirection autoDirection(String text) {
  for (final rune in text.runes) {
    if (rune >= 0x0590 && rune <= 0x08FF) return TextDirection.rtl;
    if ((rune >= 0x41 && rune <= 0x5A) || (rune >= 0x61 && rune <= 0x7A)) return TextDirection.ltr;
  }
  return TextDirection.ltr;
}

/// Sends the user to sign in if needed. Returns whether they are signed in.
Future<bool> ensureSignedIn(BuildContext context, WidgetRef ref) async {
  if (ref.read(forumRepositoryProvider).currentUser != null) return true;
  await context.push('/community/account?then=back');
  return ref.read(forumRepositoryProvider).currentUser != null;
}

/// Before a first post: the community guidelines. Returns whether accepted.
Future<bool> ensureGuidelines(BuildContext context, WidgetRef ref) async {
  final profile = await ref.read(myProfileProvider.future);
  if (profile == null) return false;
  if (profile.acceptedTerms) return true;
  if (!context.mounted) return false;
  final l = context.l10n;
  var checked = false;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(l.guidelinesTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.guidelinesPrompt),
            TextButton(
              onPressed: () => context.push('/settings/about/legal/guidelines'),
              child: Text(l.readGuidelines),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: checked,
              onChanged: (v) => setState(() => checked = v ?? false),
              title: Text(l.guidelinesAccept),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.actionCancel)),
          FilledButton(onPressed: checked ? () => Navigator.pop(context, true) : null, child: Text(l.actionContinue)),
        ],
      ),
    ),
  );
  if (ok != true) return false;
  await ref.read(forumRepositoryProvider).acceptGuidelines();
  ref.invalidate(myProfileProvider);
  return true;
}

/// Opens (creating if needed) the shared discussion for a parsha.
Future<void> openWeeklyThread(BuildContext context, WidgetRef ref, PortionInfo portion, int hebrewYear,
    {bool replace = false}) async {
  final l = context.l10n;
  final title = '${portion.key} · ${HebrewText.stripNikud(portion.nameHe)} · $hebrewYear';
  try {
    final id = await ref.read(forumRepositoryProvider).weeklyThread(
          parshaNumber: portion.id.number,
          hebrewYear: hebrewYear,
          title: title,
        );
    if (!context.mounted) return;
    replace ? context.pushReplacement('/community/thread/$id') : context.push('/community/thread/$id');
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(communityError(l, e))));
    }
  }
}

class DemoBanner extends ConsumerWidget {
  const DemoBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(forumRepositoryProvider).isDemo) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      color: scheme.tertiaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.science_outlined, color: scheme.onTertiaryContainer),
          const SizedBox(width: 12),
          Expanded(child: Text(context.l10n.demoModeBanner, style: TextStyle(color: scheme.onTertiaryContainer))),
        ],
      ),
    );
  }
}
