import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../ui/l10n.dart';
import '../../../ui/widgets/common.dart';
import '../data/backend.dart';
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
  final _extra = <ThreadSummary>[];
  bool _loadingMore = false;
  bool _exhausted = false;

  Future<void> _loadMore(Forum forum, List<ThreadSummary> current) async {
    if (current.isEmpty) return;
    setState(() => _loadingMore = true);
    try {
      final more = await ref.read(forumRepositoryProvider).threads(forumId: forum.id, before: current.last.lastPostAt);
      setState(() {
        _extra.addAll(more);
        _exhausted = more.isEmpty;
      });
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final he = context.isHebrewUi;
    final forums = ref.watch(forumsProvider).value ?? const [];
    final forum = forums.where((f) => f.slug == widget.slug).firstOrNull;
    if (forum == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    }
    final threads = ref.watch(threadsProvider(forum.id));
    final profile = ref.watch(myProfileProvider).value;
    final canStart = !forum.locked || (profile?.isModerator ?? false);

    return Scaffold(
      appBar: AppBar(title: Text(forum.name(he))),
      floatingActionButton: canStart
          ? FloatingActionButton.extended(
              onPressed: () => context.go('/community/new?forum=${forum.slug}'),
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
                _extra.clear();
                _exhausted = false;
                ref.invalidate(threadsProvider(forum.id));
              },
              child: threads.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text(communityError(l, e)))]),
                data: (list) {
                  final all = [...list, ..._extra];
                  return PageBody(
                    children: [
                      if (forum.description(he).isNotEmpty)
                        Padding(padding: const EdgeInsets.only(bottom: 12), child: Text(forum.description(he))),
                      if (all.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Text(l.noThreads, textAlign: TextAlign.center)),
                      for (final t in all) ThreadTile(thread: t),
                      if (all.length >= 30 && !_exhausted)
                        Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 72),
                          child: OutlinedButton(
                            onPressed: _loadingMore ? null : () => _loadMore(forum, all),
                            child: Text(l.loadMore),
                          ),
                        )
                      else
                        const Gap(72),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ThreadTile extends StatelessWidget {
  const ThreadTile({super.key, required this.thread});
  final ThreadSummary thread;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
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
        title: Text(thread.title, textDirection: autoDirection(thread.title)),
        subtitle: Text(meta, style: theme.textTheme.bodySmall),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.go('/community/thread/${thread.id}'),
      ),
    );
  }
}
