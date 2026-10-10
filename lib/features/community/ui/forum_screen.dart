import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../services/feedback.dart';
import '../../../ui/l10n.dart';
import '../../../ui/widgets/common.dart';
import '../../../ui/widgets/fallbacks.dart';
import '../data/community_providers.dart';
import '../data/models.dart';
import 'community_ui.dart';

/// Threads in one forum, pinned first, with explicit "Load more" paging
/// (no infinite-scroll trap for keyboard and screen reader users).
class ForumScreen extends ConsumerStatefulWidget {
  const ForumScreen({super.key, required this.slug});
  final String slug;

  @override
  ConsumerState<ForumScreen> createState() => _ForumScreenState();
}

class _ForumScreenState extends ConsumerState<ForumScreen> {
  bool _loadingMore = false;

  Future<void> _loadMore(Forum forum) async {
    if (_loadingMore) return;
    final l = context.l10n;
    setState(() => _loadingMore = true);
    try {
      await ref.read(threadsProvider(forum.id).notifier).loadMore();
    } catch (e) {
      if (mounted) showStatus(context, communityError(l, e));
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final he = context.isHebrewUi;
    final forums = ref.watch(forumsProvider);
    final forum = (forums.value ?? const []).where((f) => f.slug == widget.slug).firstOrNull;
    if (forum == null) {
      // Spin only while the forums load: a link to a forum that doesn't
      // exist, or one that can't load, says so.
      final error = forums.error;
      final missing = !forums.isLoading && error == null;
      return Scaffold(
        appBar: AppBar(title: missing ? Text(l.notFoundTitle) : null),
        body: forums.isLoading
            ? const Center(child: CircularProgressIndicator())
            : CenteredMessage(
                text: error != null ? communityError(l, error) : l.forumNotFound,
                actions: [
                  if (error != null)
                    TextButton(onPressed: () => ref.invalidate(forumsProvider), child: Text(l.actionRetry)),
                  TextButton(onPressed: () => context.go('/community'), child: Text(l.allForums)),
                ],
              ),
      );
    }
    final threads = ref.watch(threadsProvider(forum.id));
    final profile = ref.watch(myProfileProvider).value;
    final canStart = !forum.locked || (profile?.isModerator ?? false);

    Future<void> refresh() async {
      ref.invalidate(threadsProvider(forum.id));
      await ref.read(threadsProvider(forum.id).future);
    }

    return RefreshablePage(
      refresh: refresh,
      builder: (context, refreshButton) => Scaffold(
        appBar: AppBar(title: Text(forum.name(he)), actions: [refreshButton]),
        floatingActionButton: canStart
            ? FloatingActionButton.extended(
                onPressed: () => context.push('/community/new?forum=${forum.slug}'),
                icon: const Icon(Icons.edit_outlined),
                label: Text(l.newThread),
              )
            : null,
        body: Column(
          children: [
            const DemoBanner(),
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  try {
                    await refresh();
                  } catch (e) {
                    if (context.mounted) showStatus(context, communityError(l, e));
                  }
                },
                child: threads.when(
                  // Fetched again, the threads shown stay until the new ones come.
                  skipError: threads.hasValue,
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text(communityError(l, e)))]),
                  data: (page) {
                    final list = page.threads;
                    return PageBody.builder(
                      header: [
                        if (forum.description(he).isNotEmpty)
                          Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(forum.description(he))),
                        if (list.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Text(l.noThreads, textAlign: TextAlign.center)),
                      ],
                      // The last item makes room for the button over it.
                      itemCount: list.length + 1,
                      itemBuilder: (context, i) {
                        if (i < list.length) return ThreadTile(key: ValueKey(list[i].id), thread: list[i]);
                        if (!page.hasMore) return const Gap(72);
                        return Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 72),
                          child: OutlinedButton(
                            // Enabled while it loads, so that it keeps the keyboard focus.
                            onPressed: () => _loadMore(forum),
                            child: _loadingMore
                                ? SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, semanticsLabel: l.loading),
                                  )
                                : Text(l.loadMore),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class ThreadTile extends ConsumerWidget {
  const ThreadTile({super.key, required this.thread});
  final ThreadSummary thread;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final title = threadDisplayTitle(context, ref, thread);
    final meta = [
      if (thread.pinned) l.pinnedLabel,
      if (thread.locked) l.lockedLabel,
      l.postsCount(thread.postCount),
      relativeTime(context, thread.lastPostAt),
    ].join(' · ');
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(thread.pinned ? Icons.push_pin_outlined : (thread.locked ? Icons.lock_outline : Icons.chat_bubble_outline)),
        title: Text(title, textDirection: autoDirection(title)),
        subtitle: Text(meta, style: theme.textTheme.bodySmall),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/community/thread/${thread.id}'),
      ),
    );
  }
}
