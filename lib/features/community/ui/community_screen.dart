import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/retry.dart';
import '../../../ui/l10n.dart';
import '../../../ui/theme/app_theme.dart';
import '../../../ui/widgets/common.dart';
import '../../../ui/widgets/fallbacks.dart';
import '../../../ui/widgets/paper_group.dart';
import '../data/community_providers.dart';
import '../data/models.dart';
import 'community_ui.dart';

/// The community's front page (§9 Community): the demo's notice, this
/// week's discussion, a way to sign in, and the forums.
class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  /// How busy a forum is: "12 discussions · active 3 hours ago", or with
  /// nothing posted in it yet, only how many discussions it has.
  static String activity(BuildContext context, ForumStats stats) {
    final l = context.l10n;
    return metaLine([
      l.forumDiscussionsCount(stats.threadCount),
      if (stats.lastPostAt case final at?) l.forumActive(relativeTime(context, at)),
    ]);
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

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen> with FetchAgainIfFailed {
  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final he = context.isHebrewUi;
    final text = Theme.of(context).textTheme;
    // A forum's description is ink, as a thread's excerpt is in its list,
    // over the muted line of how busy it is.
    final ink = Theme.of(context).colorScheme.onSurface;
    final user = ref.watch(communityUserProvider).value;
    final profile = ref.watch(myProfileProvider).value;
    final forums = watchFresh(forumsProvider);
    // How busy each forum is, once it comes (see _Forums).
    final stats = ref.watch(forumStatsProvider);

    Future<void> refresh() async {
      ref
        ..invalidate(forumsProvider)
        ..invalidate(forumStatsProvider);
      await ref.read(forumsProvider.future);
    }

    return RefreshablePage(
      refresh: refresh,
      failureShown: forums.hasError && !forums.hasValue,
      builder: (context, refreshButton) => PageScaffold(
        titleText: l.communityTitle,
        actions: [
          refreshButton,
          IconButton(
            tooltip: user == null ? l.signInTitle : l.settingsAccount,
            // Signed in, the member's initial; a person on the same disc until
            // their profile comes, and while it has a machine's name
            // ("user_1a2b3c4d"), whose initial would be no one's.
            icon: user == null
                ? const Icon(Icons.person_outline)
                : InitialDisc(profile != null && profile.hasChosenName ? profile.displayName : ''),
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
                loading: () => const _Loading(),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.only(top: Space.lg),
                  child: ErrorMessage(
                    message: communityError(l, e),
                    // The forums' activity too, which may have failed with
                    // them.
                    onRetry: () => unawaited(refresh().catchError((Object _) {})),
                    retrying: forums.isLoading,
                  ),
                ),
                data: (list) => list.isEmpty
                    ? const SizedBox.shrink()
                    : _Forums(
                        stats: stats,
                        builder: (stats) => PaperGroup(
                          children: [
                            for (final f in list)
                              PaperRow(
                                icon: CommunityScreen.iconFor(f.slug),
                                title: f.name(he),
                                titleStyle: text.titleMedium,
                                subtitle: f.description(he).isEmpty ? null : f.description(he),
                                subtitleStyle: text.bodySmall?.copyWith(color: ink),
                                detail: switch (stats?[f.id]) {
                                  final s? => CommunityScreen.activity(context, s),
                                  null => null,
                                },
                                onTap: () => context.push('/community/forum/${f.slug}'),
                              ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();

  @override
  Widget build(BuildContext context) =>
      const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()));
}

/// The forums, built by [builder] with each one's activity once [stats]
/// come. While they are first fetched, the forums wait for them a moment
/// ([grace]), still loading, so that each row doesn't grow by a line, and
/// the group move down, under a finger or a screen reader's cursor as they
/// arrive. Past that, or where they can't be had, the forums are listed
/// without them.
class _Forums extends StatefulWidget {
  const _Forums({required this.stats, required this.builder});

  final AsyncValue<Map<int, ForumStats>> stats;
  final Widget Function(Map<int, ForumStats>? stats) builder;

  static const grace = Duration(milliseconds: 1500);

  @override
  State<_Forums> createState() => _ForumsState();
}

class _ForumsState extends State<_Forums> {
  Timer? _grace;
  bool _waited = false;

  bool get _waiting => !_waited && widget.stats.isLoading && !widget.stats.hasValue && !widget.stats.hasError;

  @override
  void initState() {
    super.initState();
    if (_waiting) _grace = Timer(_Forums.grace, () => setState(() => _waited = true));
  }

  @override
  void didUpdateWidget(_Forums old) {
    super.didUpdateWidget(old);
    if (!_waiting) _grace?.cancel();
  }

  @override
  void dispose() {
    _grace?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _waiting ? const _Loading() : widget.builder(widget.stats.value);
}
