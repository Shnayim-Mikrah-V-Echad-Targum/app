import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../services/feedback.dart';
import '../../../ui/l10n.dart';
import '../../../ui/theme/app_theme.dart';
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

  // Load more keeps the keyboard focus while it loads. Then it moves down
  // past the threads loaded, out of view, and the first of them, in its
  // place, takes the focus.
  final _loadMoreFocus = FocusNode();
  final _firstLoadedFocus = FocusNode();
  int? _firstLoaded;

  @override
  void dispose() {
    _loadMoreFocus.dispose();
    _firstLoadedFocus.dispose();
    super.dispose();
  }

  Future<void> _loadMore(Forum forum) async {
    if (_loadingMore) return;
    final l = context.l10n;
    final threads = threadsProvider(forum.id);
    final before = ref.read(threads).value?.threads.length ?? 0;
    setState(() => _loadingMore = true);
    try {
      await ref.read(threads.notifier).loadMore();
      final loaded = (ref.read(threads).value?.threads.length ?? before) - before;
      if (!mounted || loaded <= 0) return;
      if (_loadMoreFocus.hasFocus) {
        setState(() => _firstLoaded = before);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted || _firstLoadedFocus.context == null) return;
          _firstLoadedFocus.requestFocus();
          _firstLoadedFocus.context!.findRenderObject()?.showOnScreen();
        });
      }
      showStatus(context, l.loadedMore(loaded));
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
      // Spin only while the forums first load: a link to a forum that
      // doesn't exist says so, and so do forums that can't load, at once,
      // while they are tried again.
      final missing = forums.hasValue;
      final error = missing ? null : forums.error;
      return Scaffold(
        appBar: AppBar(title: missing ? Text(l.notFoundTitle) : null),
        body: !missing && error == null
            ? const Center(child: CircularProgressIndicator())
            : CenteredMessage(
                text: error != null ? communityError(l, error) : l.forumNotFound,
                actions: [
                  FilledButton.tonal(
                    style: AppButtons.tonal(context),
                    onPressed: () => context.go('/community'),
                    child: Text(l.allForums),
                  ),
                  if (error != null)
                    TextButton(onPressed: () => ref.invalidate(forumsProvider), child: Text(l.actionRetry)),
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
                        if (i < list.length) {
                          return ThreadTile(
                            key: ValueKey(list[i].id),
                            thread: list[i],
                            focusNode: i == _firstLoaded ? _firstLoadedFocus : null,
                          );
                        }
                        if (!page.hasMore) return const Gap(72);
                        return Padding(
                          padding: const EdgeInsets.only(top: 8, bottom: 72),
                          child: OutlinedButton(
                            // Enabled while it loads, so that it keeps the
                            // keyboard focus; presses meanwhile do nothing.
                            focusNode: _loadMoreFocus,
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
  const ThreadTile({super.key, required this.thread, this.focusNode});
  final ThreadSummary thread;
  final FocusNode? focusNode;

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
        focusNode: focusNode,
        leading: Icon(thread.pinned ? Icons.push_pin_outlined : (thread.locked ? Icons.lock_outline : Icons.chat_bubble_outline)),
        title: Text(title, textDirection: autoDirection(title)),
        subtitle: Text(meta, style: theme.textTheme.bodySmall),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push('/community/thread/${thread.id}'),
      ),
    );
  }
}
