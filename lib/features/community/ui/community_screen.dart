import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/l10n.dart';
import '../../../ui/theme/app_theme.dart';
import '../../../ui/widgets/common.dart';
import '../../../ui/widgets/paper_group.dart';
import '../data/community_providers.dart';
import 'community_ui.dart';

/// The community's front page (§9 Community): the demo's notice, this
/// week's discussion, a way to sign in, and the forums.
class CommunityScreen extends ConsumerWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final he = context.isHebrewUi;
    final text = Theme.of(context).textTheme;
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final user = ref.watch(communityUserProvider).value;
    final profile = ref.watch(myProfileProvider).value;
    final forums = ref.watch(forumsProvider);

    Future<void> refresh() async {
      ref.invalidate(forumsProvider);
      await ref.read(forumsProvider.future);
    }

    return RefreshablePage(
      refresh: refresh,
      builder: (context, refreshButton) => PageScaffold(
        titleText: l.communityTitle,
        actions: [
          refreshButton,
          IconButton(
            tooltip: user == null ? l.signInTitle : l.settingsAccount,
            // Signed in, the member's initial; until their profile comes, a
            // person on the same disc.
            icon: user == null ? const Icon(Icons.person_outline) : InitialDisc(profile?.displayName ?? ''),
            onPressed: () => context.push('/community/account'),
          ),
        ],
        body: RefreshIndicator(
          // A failure shows in place of the forums.
          onRefresh: () => refresh().catchError((Object _) {}),
          child: PageBody(
            children: [
              const DemoBanner(),
              const ThisWeekCard(),
              if (user == null) ...[
                const Gap(Rhythm.cardGap),
                PaperGroup(
                  children: [
                    PaperRow(
                      icon: Icons.info_outline,
                      title: l.signInPrompt,
                      trailing: TextButton(onPressed: () => context.push('/community/account'), child: Text(l.signInTitle)),
                    ),
                  ],
                ),
              ],
              if (profile?.isModerator ?? false) ...[
                const Gap(Rhythm.cardGap),
                PaperGroup(
                  children: [
                    PaperRow(
                      icon: Icons.shield_outlined,
                      title: l.moderationQueue,
                      onTap: () => context.push('/community/moderation'),
                    ),
                  ],
                ),
              ],
              GroupHeader(l.forumsHeading),
              forums.when(
                loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
                error: (e, _) => _Retry(message: communityError(l, e), onRetry: () => ref.invalidate(forumsProvider)),
                data: (list) => list.isEmpty
                    ? const SizedBox.shrink()
                    : PaperGroup(
                        children: [
                          for (final f in list)
                            PaperRow(
                              icon: iconFor(f.slug),
                              title: f.name(he),
                              titleStyle: text.titleMedium,
                              subtitle: f.description(he).isEmpty ? null : f.description(he),
                              subtitleStyle: text.bodySmall?.copyWith(color: muted),
                              onTap: () => context.push('/community/forum/${f.slug}'),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The icon of the forum [slug], here and where a new discussion picks
  /// its forum.
  static IconData iconFor(String slug) => switch (slug) {
        'parsha' => Icons.menu_book_outlined,
        'questions' => Icons.help_outline,
        'divrei-torah' => Icons.lightbulb_outline,
        'chavruta' => Icons.people_outline,
        'feedback' => Icons.feedback_outlined,
        'announcements' => Icons.campaign_outlined,
        _ => Icons.forum_outlined,
      };
}

class _Retry extends StatelessWidget {
  const _Retry({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(message, textAlign: TextAlign.center),
            const Gap(8),
            OutlinedButton(onPressed: onRetry, child: Text(context.l10n.actionRetry)),
          ],
        ),
      );
}
