import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show toBeginningOfSentenceCase;

import '../../../services/feedback.dart';
import '../../../ui/l10n.dart';
import '../../../ui/theme/app_theme.dart';
import '../../../ui/widgets/common.dart';
import '../../../ui/widgets/fallbacks.dart';
import '../../../ui/widgets/lang.dart';
import '../../../ui/widgets/paper_group.dart';
import '../data/community_providers.dart';
import '../data/models.dart';
import 'community_ui.dart';

/// Threads in one forum (§9 Community): the pinned ones, then the rest,
/// newest activity first, with explicit "Load more" paging (no
/// infinite-scroll trap for keyboard and screen reader users). The Parshat
/// HaShavua forum opens on this week's discussion.
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
      return PageScaffold(
        // No title while the forums load, or can't.
        titleText: missing ? l.notFoundTitle : l.communityTitle,
        showTitle: missing,
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
    final theme = Theme.of(context);
    final description = forum.description(he);
    // The Parsha forum opens on this week's discussion, so it is never empty.
    final weekly = forum.slug == 'parsha';
    void compose() => context.push('/community/new?forum=${forum.slug}');

    Future<void> refresh() async {
      ref.invalidate(threadsProvider(forum.id));
      await ref.read(threadsProvider(forum.id).future);
    }

    return RefreshablePage(
      refresh: refresh,
      builder: (context, refreshButton) => PageScaffold(
        titleText: forum.name(he),
        actions: [const DemoTag(), refreshButton],
        floatingActionButton: canStart
            ? FloatingActionButton.extended(
                onPressed: compose,
                icon: const Icon(Icons.edit_outlined),
                label: Text(l.newThread),
              )
            : null,
        body: RefreshIndicator(
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
              // The pinned threads, then the rest, each group as rows of one
              // sheet of paper, built only as they scroll into view: a forum
              // paged through holds hundreds.
              final items = <Widget Function()>[];
              void group(String heading, List<(int, ThreadSummary)> threads) {
                if (threads.isEmpty) return;
                items.add(() => GroupHeader(heading));
                for (final (n, (i, t)) in threads.indexed) {
                  items.add(() => PaperGroupRow(
                        first: n == 0,
                        last: n == threads.length - 1,
                        child: ThreadTile(
                          key: ValueKey(t.id),
                          thread: t,
                          focusNode: i == _firstLoaded ? _firstLoadedFocus : null,
                        ),
                      ));
                }
              }

              group(l.pinnedHeading, [for (final (i, t) in page.threads.indexed) if (t.pinned) (i, t)]);
              group(l.recentHeading, [for (final (i, t) in page.threads.indexed) if (!t.pinned) (i, t)]);
              if (page.threads.isEmpty && !weekly) {
                // An invitation only to one who may begin a discussion here.
                items.add(() => EmptyState(
                      message: canStart ? l.emptyForum : l.emptyLockedForum,
                      actionLabel: canStart ? l.newThread : null,
                      onAction: canStart ? compose : null,
                    ));
              }
              if (page.hasMore) {
                items.add(() => Padding(
                      padding: const EdgeInsets.only(top: Space.lg),
                      child: Center(
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
                      ),
                    ));
              }
              // Room at the end for the button over it.
              if (canStart) items.add(() => const Gap(72));
              return PageBody.builder(
                header: [
                  if (description.isNotEmpty)
                    Text(description, style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  if (weekly) ...[
                    if (description.isNotEmpty) const Gap(Rhythm.cardGap),
                    const ThisWeekCard(),
                  ],
                ],
                itemCount: items.length,
                itemBuilder: (context, i) => items[i](),
              );
            },
          ),
        ),
      ),
    );
  }
}

/// A thread in a forum's list (§9 Community): its title, run in the direction
/// of its own language, under a Pinned or Locked tag if it is pinned or
/// locked; then who started it, when it was last active, and how many replies
/// it has had. One item for screen readers, which opens the thread, and says
/// each tag too.
class ThreadTile extends ConsumerWidget {
  const ThreadTile({super.key, required this.thread, this.focusNode});
  final ThreadSummary thread;
  final FocusNode? focusNode;

  /// Every post but the one that opened the thread. A weekly thread opens
  /// with none of its own, so all of its posts are replies.
  int get _replies => thread.kind == ThreadKind.weekly ? thread.postCount : max(0, thread.postCount - 1);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final muted = theme.colorScheme.onSurfaceVariant;
    final title = threadDisplayTitle(context, ref, thread);
    final direction = autoDirection(title);
    // Each title runs its own way, but starts on the same edge as the rest.
    final edge = Directionality.of(context) == TextDirection.rtl ? TextAlign.right : TextAlign.left;
    // Never cut short once the text is enlarged (WCAG 1.4.4).
    final enlarged = MediaQuery.textScalerOf(context).scale(1) > 1;
    // Starting with the time, as a weekly thread's does, it starts with a
    // capital: "Just now".
    Widget tag(IconData icon, String label) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: muted),
            const Gap(Space.xs),
            Flexible(child: Text(label, style: text.labelSmall?.copyWith(color: muted))),
          ],
        );
    final meta = toBeginningOfSentenceCase(
      [
        // A weekly thread is the community's, started by no one.
        if (thread.authorName.isNotEmpty) isolate(thread.authorName),
        relativeTime(context, thread.lastPostAt),
        l.repliesCount(_replies),
      ].join(' · '),
      context.localeName,
    );
    return Semantics(
      container: true,
      button: true,
      child: SeferInkWell(
        focusNode: focusNode,
        borderRadius: PaperGroup.rowCorners(context),
        onTap: () => context.push('/community/thread/${thread.id}'),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.lg, vertical: Space.md),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (thread.pinned || thread.locked)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Wrap(
                      spacing: Space.md,
                      children: [
                        if (thread.pinned) tag(Icons.push_pin_outlined, l.pinnedLabel),
                        if (thread.locked) tag(Icons.lock_outline, l.lockedLabel),
                      ],
                    ),
                  ),
                Lang(
                  Locale(direction == TextDirection.rtl ? 'he' : 'en'),
                  child: Text(
                    title,
                    style: text.titleMedium,
                    textDirection: direction,
                    textAlign: edge,
                    maxLines: enlarged ? null : 2,
                    overflow: enlarged ? null : TextOverflow.ellipsis,
                  ),
                ),
                const Gap(2),
                Text(meta, style: text.bodySmall?.copyWith(color: muted)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
