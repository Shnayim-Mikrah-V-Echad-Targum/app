import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../ui/l10n.dart';
import '../../../ui/widgets/common.dart';
import '../../parsha/week_context.dart';
import '../../progress/domain/progress_models.dart';
import '../data/community_providers.dart';
import 'community_ui.dart';

class CommunityScreen extends ConsumerWidget {
  const CommunityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final names = Names(context);
    final he = context.isHebrewUi;
    final user = ref.watch(communityUserProvider).value;
    final profile = ref.watch(myProfileProvider).value;
    final forums = ref.watch(forumsProvider);
    final week = ref.watch(currentWeekContextProvider);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.communityTitle),
        actions: [
          IconButton(
            tooltip: user == null ? l.signInTitle : l.settingsAccount,
            icon: Icon(user == null ? Icons.login : Icons.account_circle_outlined),
            onPressed: () => context.go('/community/account'),
          ),
        ],
      ),
      body: Column(
        children: [
          const DemoBanner(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(forumsProvider),
              child: PageBody(
                children: [
                  InfoCard(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    onTap: () => openWeeklyThread(
                      context,
                      ref,
                      week.portion,
                      cycleYearOf(week.week.portion, week.week.occasion),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.local_library_outlined),
                        const Gap(12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                l.thisWeeksThread(names.portion(week.portion, ashkenazi: settings.ashkenaziNames)),
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(l.openDiscussion),
                            ],
                          ),
                        ),
                        const Icon(Icons.chevron_right),
                      ],
                    ),
                  ),
                  if (user == null) ...[
                    const Gap(12),
                    InfoCard(
                      child: Row(
                        children: [
                          const Icon(Icons.info_outline),
                          const Gap(12),
                          Expanded(child: Text(l.signInPrompt)),
                          TextButton(onPressed: () => context.go('/community/account'), child: Text(l.signInTitle)),
                        ],
                      ),
                    ),
                  ],
                  if (profile?.isModerator ?? false) ...[
                    const Gap(12),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.shield_outlined),
                      label: Text(l.moderationQueue),
                      onPressed: () => context.go('/community/moderation'),
                    ),
                  ],
                  SectionHeader(l.forumsHeading),
                  forums.when(
                    loading: () => const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
                    error: (e, _) => _Retry(message: communityError(l, e), onRetry: () => ref.invalidate(forumsProvider)),
                    data: (list) => Column(
                      children: [
                        for (final f in list)
                          Card(
                            margin: const EdgeInsets.only(bottom: 8),
                            child: ListTile(
                              leading: Icon(_iconFor(f.slug)),
                              title: Text(f.name(he)),
                              subtitle: f.description(he).isEmpty ? null : Text(f.description(he)),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () => context.go('/community/forum/${f.slug}'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static IconData _iconFor(String slug) => switch (slug) {
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
