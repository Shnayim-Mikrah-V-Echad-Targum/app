import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/feedback.dart';
import '../../../ui/l10n.dart';
import '../../../ui/theme/app_theme.dart';
import '../../../ui/widgets/common.dart';
import '../../../ui/widgets/lang.dart';
import '../data/backend.dart';
import '../data/community_providers.dart';
import '../data/models.dart';
import 'community_ui.dart';

/// A discussion: posts in chronological order (flat, which reads more
/// predictably with screen readers than deep nesting), and a reply box. A
/// long thread opens on its latest posts, with earlier ones a tap away.
class ThreadScreen extends ConsumerStatefulWidget {
  const ThreadScreen({super.key, required this.threadId});
  final String threadId;

  @override
  ConsumerState<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends ConsumerState<ThreadScreen> {
  final _reply = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  Post? _replyTo;
  bool _sending = false;
  bool _loadingEarlier = false;
  Timer? _draftTimer;

  // Show earlier posts keeps the keyboard focus while it loads, and, once
  // the earliest are in and it goes, the first post takes it.
  final _earlierFocus = FocusNode();
  final _firstPostFocus = FocusNode(skipTraversal: true);
  String? _firstPostFocused;

  String get _draftKey => 'draft.thread.${widget.threadId}';

  @override
  void initState() {
    super.initState();
    final draft = ref.read(sharedPreferencesProvider).getString(_draftKey);
    if (draft != null && draft.isNotEmpty) {
      _reply.text = draft;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showStatus(context, context.l10n.draftRestored);
      });
    }
    _reply.addListener(() {
      _draftTimer?.cancel();
      _draftTimer = Timer(const Duration(milliseconds: 600), () {
        ref.read(sharedPreferencesProvider).setString(_draftKey, _reply.text);
      });
      setState(() {});
    });
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _reply.dispose();
    _focus.dispose();
    _scroll.dispose();
    _earlierFocus.dispose();
    _firstPostFocus.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final l = context.l10n;
    final threadId = widget.threadId;
    final draftKey = _draftKey;
    // This page may close while the reply is sent, and its ref with it.
    final prefs = ref.read(sharedPreferencesProvider);
    final container = ProviderScope.containerOf(context, listen: false);
    final repo = ref.read(forumRepositoryProvider);
    try {
      if (!await ensureSignedIn(context, ref, named: true) || !mounted) return;
      if (!await ensureGuidelines(context, ref) || !mounted) return;
      setState(() => _sending = true);
      await repo.reply(threadId, _reply.text, replyToId: _replyTo?.id);
      if (mounted) {
        _reply.clear();
        setState(() => _replyTo = null);
      }
      // Sent: whatever happens to this page, the draft must not come back.
      _draftTimer?.cancel();
      await prefs.remove(draftKey);
      container
        ..invalidate(postsProvider(threadId))
        ..invalidate(threadProvider(threadId))
        ..invalidate(threadsProvider);
      if (mounted) {
        showStatus(context, l.posted);
        unawaited(_scrollToLatest());
      }
    } catch (e) {
      if (mounted) showStatus(context, communityError(l, e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  /// Scrolls to the end of the thread, where a reply just sent appears once
  /// the posts are fetched again.
  Future<void> _scrollToLatest() async {
    try {
      await ref.read(postsProvider(widget.threadId).future);
    } catch (_) {
      return;
    }
    // A lazily built list learns its full extent only as it scrolls there.
    for (var i = 0; i < 8; i++) {
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted || !_scroll.hasClients) return;
      final p = _scroll.position;
      if (p.pixels >= p.maxScrollExtent) return;
      p.jumpTo(p.maxScrollExtent);
    }
  }

  Future<void> _moderate(String action) async {
    final l = context.l10n;
    final threadId = widget.threadId;
    // This page may close while the change is made, and its ref with it.
    final container = ProviderScope.containerOf(context, listen: false);
    final repo = ref.read(forumRepositoryProvider);
    try {
      await repo.moderate(action, threadId);
      container
        ..invalidate(threadProvider(threadId))
        // Pinned or not, locked or not, as its forum lists it.
        ..invalidate(threadsProvider);
    } catch (e) {
      if (mounted) showStatus(context, communityError(l, e));
    }
  }

  /// Fetches the thread and its latest posts again. Fails as the backend does.
  Future<void> _refresh() async {
    ref
      ..invalidate(threadProvider(widget.threadId))
      ..invalidate(postsProvider(widget.threadId));
    await ref.read(postsProvider(widget.threadId).future);
  }

  Future<void> _loadEarlier() async {
    if (_loadingEarlier) return;
    final l = context.l10n;
    final posts = postsProvider(widget.threadId);
    final hadFocus = _earlierFocus.hasFocus;
    setState(() => _loadingEarlier = true);
    try {
      await ref.read(posts.notifier).loadEarlier();
      // Once the earliest posts are in, the button goes, and the first of
      // them, at the top in its place, takes the focus it had.
      final page = ref.read(posts).value;
      if (!mounted || !hadFocus || page == null || page.hasEarlier || page.posts.isEmpty) return;
      setState(() => _firstPostFocused = page.posts.first.id);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _firstPostFocus.context == null) return;
        _firstPostFocus.requestFocus();
        _firstPostFocus.context!.findRenderObject()?.showOnScreen();
      });
    } catch (e) {
      if (mounted) showStatus(context, communityError(l, e));
    } finally {
      if (mounted) setState(() => _loadingEarlier = false);
    }
  }

  /// The tag beside the name of the member who started [t] on their posts:
  /// Asked in a question, and Author in any other discussion. None in a
  /// weekly thread, which is the community's.
  static String? _authorTag(AppLocalizations l, ThreadSummary? t, Post post) {
    final author = t?.authorId;
    if (t == null || t.kind == ThreadKind.weekly || author == null || post.authorId != author) return null;
    return t.kind == ThreadKind.question ? l.askedTag : l.authorTag;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final thread = ref.watch(threadProvider(widget.threadId));
    final posts = ref.watch(postsProvider(widget.threadId));
    final user = ref.watch(communityUserProvider).value;
    final profile = ref.watch(myProfileProvider).value;
    final isMod = profile?.isModerator ?? false;
    final t = thread.value;
    final title = t == null ? '' : threadDisplayTitle(context, ref, t);
    final titleDirection = autoDirection(title);
    // The app bar names the forum, above the thread's own title: Community
    // where the forum can't be found, and nothing while the forums load.
    final forums = ref.watch(forumsProvider);
    final forum = t == null ? null : forums.value?.where((f) => f.id == t.forumId).firstOrNull;
    final forumName = forum?.name(context.isHebrewUi) ?? (forums.isLoading || t == null ? null : l.communityTitle);
    final canReply = t != null && (!t.locked || isMod);

    // Posts reach into the gutter at their end, where their menu buttons end
    // (see PostCard.menuBleed); everything else keeps to the column.
    final g = Gutter.of(context);
    Widget inColumn(Widget child) =>
        Padding(padding: const EdgeInsetsDirectional.only(end: PostCard.menuBleed), child: child);

    final content = RefreshablePage(
      refresh: _refresh,
      builder: (context, refreshButton) => PageScaffold(
        // The browser's tab is named for the thread, and so is the page, by
        // its heading below: the forum's name over it is no heading.
        titleText: title,
        title: AppBarTitle(forumName ?? ''),
        showTitle: forumName != null,
        titleNamesPage: false,
        actions: [
          const DemoTag(),
          refreshButton,
          if (isMod && t != null)
            PopupMenuButton<String>(
              tooltip: l.actionMore,
              popUpAnimationStyle: Motion.of(context).style,
              onSelected: _moderate,
              itemBuilder: (context) => [
                PopupMenuItem(value: t.pinned ? 'unpin_thread' : 'pin_thread', child: Text(t.pinned ? l.unpinThread : l.pinThread)),
                PopupMenuItem(value: t.locked ? 'unlock_thread' : 'lock_thread', child: Text(t.locked ? l.unlockThread : l.lockThread)),
              ],
            ),
        ],
        body: Column(
          children: [
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  try {
                    await _refresh();
                  } catch (e) {
                    if (context.mounted) showStatus(context, communityError(l, e));
                  }
                },
                child: posts.when(
                  // Fetched again, the posts shown stay until the new ones come.
                  skipError: posts.hasValue,
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text(communityError(l, e)))]),
                  data: (page) {
                    final list = page.posts;
                    final byId = {for (final p in list) p.id: p};
                    // With earlier posts not yet loaded, the thread's own
                    // count, and each post numbered within the whole thread.
                    // Loaded in full, the count of those shown: the server's
                    // counts posts the reader can't see, such as a blocked
                    // member's.
                    final total = page.hasEarlier ? max(t?.postCount ?? 0, list.length) : list.length;
                    final offset = total - list.length;
                    // The post that opened the thread, once it is loaded: the
                    // first shown, if its member began the thread as it was
                    // begun. A weekly thread opens with none of its own; nor
                    // does a thread whose opening post is hidden (deleted, or
                    // its member blocked).
                    final first = list.firstOrNull;
                    final opening = offset == 0 &&
                            t != null &&
                            t.kind != ThreadKind.weekly &&
                            first != null &&
                            first.authorId != null &&
                            first.authorId == t.authorId &&
                            first.createdAt.difference(t.createdAt).abs() < const Duration(minutes: 1)
                        ? first.id
                        : null;
                    return PageBody.builder(
                      controller: _scroll,
                      padding: EdgeInsetsDirectional.fromSTEB(g, Space.sm, g - PostCard.menuBleed, Space.s40),
                      header: <Widget>[
                        if (t != null) ...[
                          // The page's one heading of level 1, which names it,
                          // in its own language.
                          Lang(
                            Locale(titleDirection == TextDirection.rtl ? 'he' : 'en'),
                            child: Semantics(
                              header: true,
                              headingLevel: 1,
                              namesRoute: true,
                              child: Text(
                                title,
                                textDirection: titleDirection,
                                // In its own direction, from the page's start
                                // edge, as its forum lists it.
                                textAlign: Directionality.of(context) == TextDirection.rtl ? TextAlign.right : TextAlign.left,
                                style: theme.textTheme.headlineSmall,
                              ),
                            ),
                          ),
                          // An empty thread says so below.
                          if (list.isNotEmpty) ...[
                            const Gap(Space.xs),
                            Text(
                              l.postsCount(total),
                              style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                            ),
                          ],
                          if (t.locked) ...[const Gap(Space.md), NoticeBanner(icon: Icons.lock_outline, text: l.lockedThread)],
                          const Gap(Space.lg),
                        ],
                        // The reply box beneath is its action.
                        if (list.isEmpty && t != null) EmptyState(message: emptyThreadMessage(context, ref, t)),
                        if (page.hasEarlier)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: Center(
                              child: TextButton.icon(
                                // Enabled while it loads, so that it keeps the keyboard focus.
                                focusNode: _earlierFocus,
                                onPressed: _loadEarlier,
                                icon: _loadingEarlier
                                    ? SizedBox.square(
                                        dimension: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2, semanticsLabel: l.loading),
                                      )
                                    : const Icon(Icons.expand_less),
                                label: Text(l.showEarlierPosts),
                              ),
                            ),
                          ),
                      ].map(inColumn).toList(),
                      itemCount: list.length,
                      // Each post under a hairline, the first under the
                      // thread's title.
                      itemBuilder: (context, i) => Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          inColumn(const _Hairline()),
                          PostCard(
                            key: ValueKey(list[i].id),
                            post: list[i],
                            number: offset + i + 1,
                            total: total,
                            opening: list[i].id == opening,
                            tag: _authorTag(l, t, list[i]),
                            focusNode: list[i].id == _firstPostFocused ? _firstPostFocus : null,
                            // As loaded, or else as fetched with the reply.
                            quote: switch (byId[list[i].replyToId]) {
                              final p? => QuotedPost(authorName: p.authorName, body: p.body),
                              null => list[i].quote,
                            },
                            isMine: user != null && list[i].authorId == user.id,
                            isModerator: isMod,
                            onReply: canReply
                                ? () {
                                    setState(() => _replyTo = list[i]);
                                    _focus.requestFocus();
                                  }
                                : null,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ),
            if (canReply)
              _Composer(
                controller: _reply,
                focusNode: _focus,
                replyTo: _replyTo,
                sending: _sending,
                onCancelReply: () => setState(() => _replyTo = null),
                onSend: _reply.text.trim().length >= 2 && !_sending ? _send : null,
              ),
          ],
        ),
      ),
    );
    // The thread's list, which a tap on the iOS status bar scrolls to the
    // top. No other list takes it up by itself.
    return PrimaryScrollController(controller: _scroll, automaticallyInheritForPlatforms: const {}, child: content);
  }
}

class _Composer extends StatelessWidget {
  const _Composer({
    required this.controller,
    required this.focusNode,
    required this.replyTo,
    required this.sending,
    required this.onCancelReply,
    required this.onSend,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final Post? replyTo;
  final bool sending;
  final VoidCallback onCancelReply;
  final VoidCallback? onSend;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final sefer = SeferColors.of(context);
    final replyTo = this.replyTo;
    // Docked on the page's own paper under a hairline, apart from the
    // navigation bar's cooler band below it, and as wide as the column of
    // posts above it, with the same gutters.
    return Material(
      color: scheme.surface,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Divider(height: sefer.hairlineWidth, thickness: sefer.hairlineWidth, color: sefer.hairline),
          SafeArea(
            top: false,
            child: Center(
              heightFactor: 1,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: ContentWidth.list),
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: Gutter.of(context), vertical: Space.md),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (replyTo != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: Space.sm),
                          child: _ReplyingTo(
                            name: replyTo.authorName.isEmpty ? l.anonymousMember : replyTo.authorName,
                            onCancel: onCancelReply,
                          ),
                        ),
                      Row(
                        // The button stays by the last line as the field grows.
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Expanded(
                            child: TextField(
                              controller: controller,
                              focusNode: focusNode,
                              minLines: 1,
                              maxLines: 5,
                              maxLength: 10000,
                              buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                              // Empty, the cursor waits at the interface's start.
                              textDirection: autoDirection(controller.text, fallback: Directionality.of(context)),
                              keyboardType: TextInputType.multiline,
                              decoration: InputDecoration(labelText: l.replyLabel),
                            ),
                          ),
                          const Gap(Space.md),
                          Padding(
                            // Level with a one-line field, 56 high.
                            padding: const EdgeInsets.only(bottom: Space.xs),
                            child: FilledButton(
                              onPressed: onSend,
                              child: sending
                                  ? SizedBox.square(
                                      dimension: 20,
                                      child: CircularProgressIndicator(strokeWidth: 2, semanticsLabel: l.sending),
                                    )
                                  : Text(l.replyAction),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Above the reply box, the post being answered: a strip ruled at its start,
/// as the post that opened the thread is, with a button that lets it go.
class _ReplyingTo extends StatelessWidget {
  const _ReplyingTo({required this.name, required this.onCancel});

  final String name;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final muted = scheme.onSurfaceVariant;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: BorderDirectional(start: BorderSide(color: scheme.primary, width: 3)),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.only(start: Space.md),
        child: Row(
          children: [
            Icon(Icons.reply, size: 18, color: muted),
            const Gap(Space.sm),
            Expanded(
              child: Text(
                // The name in its own direction, inside a line in the other.
                l.replyingTo(isolate(name)),
                style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            IconButton(tooltip: l.actionCancel, icon: const Icon(Icons.close), color: muted, onPressed: onCancel),
          ],
        ),
      ),
    );
  }
}

/// One post of a thread, set as a letter (§6.21): no card, but the writer's
/// initial, name and time over the text, and beneath it Todah and Reply. The
/// thread rules each post off from the next with a hairline. The post that
/// opened the thread is ruled at its start in techelet.
class PostCard extends ConsumerWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.number,
    required this.total,
    required this.isMine,
    required this.isModerator,
    required this.onReply,
    this.opening = false,
    this.tag,
    this.quote,
    this.focusNode,
  });

  final Post post;

  /// Its place in the thread, from 1, of [total].
  final int number;
  final int total;

  /// Whether this is the post that opened the thread.
  final bool opening;

  /// A tag beside the writer's name: Asked, say, on the posts of the member
  /// who asked the question.
  final String? tag;

  /// The post it replies to.
  final QuotedPost? quote;
  final bool isMine;
  final bool isModerator;

  /// Answers this post in the reply box. Null where no reply can be sent, as
  /// in a locked thread: the post then offers none.
  final VoidCallback? onReply;

  /// Makes the post itself take the keyboard focus when it is given to it,
  /// though it is no stop of its own for Tab.
  final FocusNode? focusNode;

  /// How far the text sits from the start: past the initial and its gap, in
  /// line with the name.
  static const double textInset = _discSize + Space.md;
  static const double _discSize = 32;

  /// The start padding of the footer's text buttons, set whatever the text
  /// size, which the footer pulls back so that their icons stand in line
  /// with the text.
  static const double _buttonInset = 12;

  /// How far a post reaches past the column into the gutter at its end: its
  /// menu button's 48 dp box ends there, so that the glyph within it lines
  /// up with the column's edge, as the app bar's do with the screen's. The
  /// box is wholly within the post, so the whole of it takes a tap; the rest
  /// of the post keeps to the column.
  static const double menuBleed = 12;

  /// The width of the opening post's rule, and the gap after it.
  static const double _ruleWidth = 3;
  static const double _ruleGap = Space.md;

  /// The footer's text buttons: their padding fixed, where Material's own
  /// would shrink as the text grows and move their icons off the text's
  /// line.
  static final footerButtonStyle = TextButton.styleFrom(
    padding: const EdgeInsetsDirectional.fromSTEB(_buttonInset, 8, 16, 8),
  );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final text = theme.textTheme;
    final muted = scheme.onSurfaceVariant;
    final repo = ref.read(forumRepositoryProvider);
    // This post may be gone (its thread closed, say) by the time an action
    // ends, and its ref with it.
    final container = ProviderScope.containerOf(context, listen: false);
    final name = post.authorName.isEmpty ? l.anonymousMember : post.authorName;
    final reported = ref.watch(reportedPostIdsProvider).contains(post.id);

    /// Runs [f], then fetches the posts again, and with [recount] the
    /// thread's count too, here and in its forum.
    Future<void> run(Future<void> Function() f, {String? success, bool recount = false}) async {
      try {
        await f();
      } catch (e) {
        if (!alreadyDone(e)) {
          if (context.mounted) showStatus(context, communityError(l, e));
          return;
        }
      }
      container.invalidate(postsProvider(post.threadId));
      if (recount) {
        container
          ..invalidate(threadProvider(post.threadId))
          ..invalidate(threadsProvider);
      }
      if (success != null && context.mounted) showStatus(context, success);
    }

    Future<void> onMenu(String v) async {
      switch (v) {
        case 'edit':
          final ok = await _editPost(context, post);
          if (ok != null) await run(() => repo.editPost(post.id, ok));
        case 'delete':
          final ok = await _confirm(context, title: l.deletePostConfirm, action: l.actionDelete);
          if (ok) await run(() => repo.deletePost(post.id), success: l.postDeleted, recount: true);
        case 'report':
          if (!await ensureSignedIn(context, ref) || !context.mounted) return;
          final result = await showReportDialog(context);
          if (result == null) return;
          final reportedIds = container.read(reportedPostIdsProvider.notifier);
          await run(() async {
            try {
              await repo.report(postId: post.id, reason: result.$1, details: result.$2);
            } on CommunityException catch (e) {
              // Reported before, in another session say: nothing more to do.
              if (e.code == 'already_reported') reportedIds.add(post.id);
              rethrow;
            }
            reportedIds.add(post.id);
          }, success: l.reportSent);
        case 'block':
          if (!await ensureSignedIn(context, ref) || !context.mounted) return;
          final ok = await _confirm(context, title: l.blockUser(name), message: l.blockConfirm(name), action: l.blockUser(name));
          if (ok && post.authorId != null) {
            await run(() => repo.block(post.authorId!), success: l.blockedDone);
            container.invalidate(blockedUsersProvider);
          }
        case 'hide':
          await run(() => repo.moderate('hide_post', post.id), recount: true);
      }
    }

    final edited = post.editedAt != null;
    final time = '${relativeTime(context, post.createdAt)}${edited ? ' · ${l.edited}' : ''}';
    final when = absoluteTime(context, post.createdAt);
    final tag = this.tag;
    final bodyDirection = autoDirection(post.body);
    // A post you can do nothing more with, such as a former member's that
    // you have reported, has no menu.
    final menu = <PopupMenuEntry<String>>[
      if (isMine) PopupMenuItem(value: 'edit', child: Text(l.actionEdit)),
      if (isMine || isModerator) PopupMenuItem(value: 'delete', child: Text(l.actionDelete)),
      if (!isMine && !reported) PopupMenuItem(value: 'report', child: Text(l.actionReport)),
      if (!isMine && post.authorId != null) PopupMenuItem(value: 'block', child: Text(l.blockUser(name))),
      if (isModerator && !isMine) PopupMenuItem(value: 'hide', child: Text(l.hidePost)),
    ];

    // The header's first line is the name's: the initial is centred on it,
    // and the menu on the 48 dp row it shares, however large the text.
    final scaler = MediaQuery.textScalerOf(context);
    final nameStyle = text.titleSmall!;
    final nameLine = scaler.scale(nameStyle.fontSize!) * (nameStyle.height ?? 1.4);
    final firstLine = max(kMinInteractiveDimension / 2, nameLine / 2);
    final discTop = firstLine - _discSize / 2;

    final header = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(padding: EdgeInsets.only(top: discTop), child: InitialDisc(post.authorName, size: _discSize)),
        const Gap(Space.md),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: firstLine - nameLine / 2),
            child: Semantics(
              label: '${l.postedBy(tag == null ? name : '$name, $tag', when)}${edited ? ', ${l.edited}' : ''}',
              excludeSemantics: true,
              child: _Byline(name: name, tag: tag, time: time, when: when),
            ),
          ),
        ),
        if (menu.isNotEmpty)
          PopupMenuButton<String>(
            tooltip: l.moreOptionsFor(name),
            popUpAnimationStyle: Motion.of(context).style,
            onSelected: onMenu,
            itemBuilder: (context) => menu,
          )
        else
          // As high as the button would be, so every header is.
          const SizedBox(height: kMinInteractiveDimension),
      ],
    );

    final onReply = this.onReply;
    // Nothing beneath your own post until it is thanked, nor in a locked
    // thread; and under your own, Reply first until it is.
    final showTodah = !isMine || post.todah > 0;
    final hasFooter = showTodah || onReply != null;
    final footer = Padding(
      padding: const EdgeInsetsDirectional.only(start: textInset - _buttonInset, end: menuBleed),
      child: Wrap(
        spacing: Space.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          if (showTodah) _TodahButton(post: post, authorName: name, isMine: isMine),
          if (onReply != null)
            TextButton.icon(
              style: footerButtonStyle,
              onPressed: onReply,
              icon: const Icon(Icons.reply, size: 18),
              // Merged into the button's node, which names whom it answers.
              label: Semantics(label: l.replyToName(name), excludeSemantics: true, child: Text(l.replyAction)),
            ),
        ],
      ),
    );
    // The room a footer button leaves under its label: 14 in a 48 dp row,
    // less once large text makes the button taller than that.
    final label = scaler.scale(text.labelLarge!.fontSize!) * (text.labelLarge!.height ?? 1.4);
    final footerSlack = (max(kMinInteractiveDimension, label + 16) - label) / 2;

    Widget letter = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        header,
        Padding(
          padding: const EdgeInsetsDirectional.only(start: textInset, end: menuBleed),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (post.hidden)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.sm),
                  child: Row(
                    children: [
                      Icon(Icons.visibility_off_outlined, size: 16, color: muted),
                      const Gap(Space.sm),
                      Expanded(child: Text(l.pendingReview, style: text.bodySmall?.copyWith(color: muted))),
                    ],
                  ),
                ),
              if (quote case final quote?) Padding(padding: const EdgeInsets.only(bottom: Space.md), child: _Quote(quote)),
              Lang(
                Locale(bodyDirection == TextDirection.rtl ? 'he' : 'en'),
                child: SelectableText(
                  post.body,
                  textDirection: bodyDirection,
                  // 16/26 in either interface: room between the lines of a
                  // letter, and for a Hebrew post's points.
                  style: text.bodyLarge?.copyWith(height: 26 / 16),
                ),
              ),
            ],
          ),
        ),
        if (hasFooter) footer,
      ],
    );
    if (opening) {
      // The rule hangs in the gutter at the start, so that the opening post's
      // text keeps the column every letter shares. It runs from the top of
      // the initial to the foot of the last line, so that it stands as far
      // from the hairline above as below.
      letter = Stack(
        clipBehavior: Clip.none,
        children: [
          letter,
          PositionedDirectional(
            start: -(_ruleWidth + _ruleGap),
            top: discTop,
            bottom: hasFooter ? footerSlack : 0,
            width: _ruleWidth,
            child: ColoredBox(color: scheme.primary),
          ),
        ],
      );
    }

    final postWidget = Semantics(
      container: true,
      label: l.postNofM(number, total),
      // 20 of air above the initial and below the last line, counting what
      // the header's and footer's rows leave around their text.
      child: Padding(
        padding: EdgeInsets.only(top: Space.md, bottom: hasFooter ? Space.xl - footerSlack : Space.lg),
        child: letter,
      ),
    );
    final focusNode = this.focusNode;
    if (focusNode == null) return postWidget;
    // Ringed while it has the focus, as a SeferInkWell is (§6.1): the focus
    // colour, 3 px outside the post.
    return Focus(
      focusNode: focusNode,
      child: ListenableBuilder(
        listenable: focusNode,
        builder: (context, child) => DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: focusNode.hasFocus
              ? ShapeDecoration(
                  shape: RoundedRectangleBorder(
                    borderRadius: const BorderRadius.all(Radius.circular(8)),
                    side: BorderSide(
                      color: SeferColors.of(context).focus,
                      width: 3,
                      strokeAlign: BorderSide.strokeAlignOutside,
                    ),
                  ),
                )
              : const BoxDecoration(),
          child: child,
        ),
        child: postWidget,
      ),
    );
  }
}

/// Who wrote a post, the tag beside their name, and when (§6.21): each a
/// text of its own, so that each runs in its own direction, a Hebrew name
/// keeping its place in an English line and an English one in a Hebrew line.
/// The time follows the name after " · " while the three fit on one line;
/// once they don't (large text, a long name), it goes on a line of its own
/// under the name, without the separator, rather than squeeze it.
class _Byline extends StatelessWidget {
  const _Byline({required this.name, required this.tag, required this.time, required this.when});

  final String name;
  final String? tag;
  final String time;

  /// The full date and time, for the time's tooltip.
  final String when;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final text = theme.textTheme;
    final muted = text.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final scaler = MediaQuery.textScalerOf(context);
    final tag = this.tag;
    return LayoutBuilder(
      builder: (context, constraints) {
        double width(String s, TextStyle? style) {
          final painter = TextPainter(
            text: TextSpan(text: s, style: style),
            textDirection: autoDirection(s),
            textScaler: scaler,
            maxLines: 1,
          )..layout();
          final w = painter.width;
          painter.dispose();
          return w;
        }

        // The tag's gap, padding and outline, about its text.
        final tagWidth = tag == null ? 0.0 : Space.sm + 2 * 6 + 4 + width(tag, text.labelSmall);
        final oneLine = width(name, text.titleSmall) + tagWidth + width(' · $time', muted) <= constraints.maxWidth;
        Widget timeText(String shown) =>
            Tooltip(message: when, excludeFromSemantics: true, child: Text(shown, style: muted));
        final nameAndTag = Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(name, textDirection: autoDirection(name), style: text.titleSmall),
            if (tag != null) Padding(padding: const EdgeInsetsDirectional.only(start: Space.sm), child: _Tag(tag)),
            if (oneLine) timeText(' · $time'),
          ],
        );
        if (oneLine) return nameAndTag;
        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [nameAndTag, timeText(time)]);
      },
    );
  }
}

/// A small tag beside a writer's name, as the Demo tag is set (§6.20):
/// labelSmall on gold-ink paper.
class _Tag extends StatelessWidget {
  const _Tag(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: const BorderRadius.all(Radius.circular(6)),
        // The pale fill alone barely shows in high contrast.
        border: SeferColors.of(context).isHighContrast ? Border.all(color: scheme.outline, width: 2) : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        child: Text(text, style: theme.textTheme.labelSmall?.copyWith(color: scheme.onSecondaryContainer)),
      ),
    );
  }
}

/// The post a reply answers, quoted above it: who wrote it and how it began,
/// ruled in gold ink at its start.
class _Quote extends StatelessWidget {
  const _Quote(this.quote);

  final QuotedPost quote;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final direction = autoDirection(quote.body);
    final name = quote.authorName.isEmpty ? l.anonymousMember : quote.authorName;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: BorderDirectional(start: BorderSide(color: scheme.secondary, width: 2)),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.md, Space.sm, Space.md, Space.sm),
        child: Text(
          // A name in the other direction from the text keeps its own order.
          '${autoDirection(name) == direction ? name : isolate(name)}: ${quote.body}',
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          textDirection: direction,
          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
      ),
    );
  }
}

/// Edits [post] in a dialog. Returns the text to save, or null if it is
/// left as it was.
Future<String?> _editPost(BuildContext context, Post post) =>
    showAppDialog<String>(context: context, builder: (context) => _EditPostDialog(body: post.body));

/// The dialog that edits a post: its text in a labelled field, which takes
/// the focus, and Save, which waits for a change of 2 characters at least,
/// as a reply does. It closes with the new text, or with nothing.
class _EditPostDialog extends StatefulWidget {
  const _EditPostDialog({required this.body});

  final String body;

  @override
  State<_EditPostDialog> createState() => _EditPostDialogState();
}

class _EditPostDialogState extends State<_EditPostDialog> {
  late final _controller = TextEditingController(text: widget.body);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool _changed(String text) => text.trim().length >= 2 && text.trim() != widget.body.trim();

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ValueListenableBuilder(
      valueListenable: _controller,
      builder: (context, value, _) => AlertDialog(
        title: Text(l.editPostTitle),
        content: TextField(
          controller: _controller,
          autofocus: true,
          minLines: 3,
          maxLines: 8,
          maxLength: 10000,
          keyboardType: TextInputType.multiline,
          textDirection: autoDirection(value.text, fallback: Directionality.of(context)),
          decoration: InputDecoration(labelText: l.threadBodyLabel, alignLabelWithHint: true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l.actionCancel)),
          FilledButton(
            onPressed: _changed(value.text) ? () => Navigator.pop(context, value.text) : null,
            child: Text(l.actionSave),
          ),
        ],
      ),
    );
  }
}

/// A hairline across the column of posts, between one post and the next.
class _Hairline extends StatelessWidget {
  const _Hairline();

  @override
  Widget build(BuildContext context) {
    final sefer = SeferColors.of(context);
    return Divider(height: sefer.hairlineWidth, thickness: sefer.hairlineWidth, color: sefer.hairline);
  }
}

/// "Todah" (thanks) for a post, and how many have given it. A tap shows at
/// once, and is undone if it fails; further taps wait for it. The button
/// stays enabled meanwhile, so that it keeps the keyboard focus. Your own
/// post can take no thanks from you: under it, only the count, once there is
/// one.
class _TodahButton extends ConsumerStatefulWidget {
  const _TodahButton({required this.post, required this.authorName, required this.isMine});

  final Post post;
  final String authorName;
  final bool isMine;

  @override
  ConsumerState<_TodahButton> createState() => _TodahButtonState();
}

class _TodahButtonState extends ConsumerState<_TodahButton> {
  late bool _given = widget.post.myTodah;
  late int _count = widget.post.todah;
  bool _busy = false;

  @override
  void didUpdateWidget(_TodahButton old) {
    super.didUpdateWidget(old);
    // Fetched again: the server's count is the truth, once ours is sent.
    if (!_busy && !identical(old.post, widget.post)) {
      _given = widget.post.myTodah;
      _count = widget.post.todah;
    }
  }

  Future<void> _toggle() async {
    if (_busy) return;
    final l = context.l10n;
    final container = ProviderScope.containerOf(context, listen: false);
    final repo = ref.read(forumRepositoryProvider);
    // What the tap asks for, as it was shown. Signing in fetches the posts
    // again, as the member sees them: thanks they gave before stay given,
    // and their own post takes none.
    final want = !_given;
    if (!await ensureSignedIn(context, ref) || !mounted || _busy || _given == want) return;
    final author = widget.post.authorId;
    if (widget.isMine || (author != null && repo.currentUser?.id == author)) return;
    final (given, count) = (_given, _count);
    setState(() {
      _busy = true;
      _given = want;
      _count = count + (want ? 1 : -1);
    });
    try {
      await repo.setTodah(widget.post.id, want);
    } catch (e) {
      if (!alreadyDone(e)) {
        if (mounted) {
          setState(() {
            _given = given;
            _count = count;
            _busy = false;
          });
          showStatus(context, communityError(l, e));
        }
        return;
      }
    }
    if (mounted) setState(() => _busy = false);
    container.invalidate(postsProvider(widget.post.threadId));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurfaceVariant;
    if (widget.isMine) {
      final figures = theme.textTheme.labelLarge?.copyWith(color: muted, fontFeatures: const [FontFeature.tabularFigures()]);
      if (_count == 0) return const SizedBox.shrink();
      // Where the button's icon would be, in line with the text, and as high.
      return Semantics(
        label: l.todahCount(_count),
        excludeSemantics: true,
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: PostCard._buttonInset, end: Space.sm),
          child: SizedBox(
            height: 48,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.volunteer_activism_outlined, size: 18, color: muted),
                const Gap(Space.sm),
                Text('$_count', style: figures),
              ],
            ),
          ),
        ),
      );
    }
    final action = _given ? l.todahRemove(widget.authorName) : l.todahSemantics(widget.authorName);
    return TextButton.icon(
      style: PostCard.footerButtonStyle,
      onPressed: _toggle,
      icon: Icon(_given ? Icons.volunteer_activism : Icons.volunteer_activism_outlined, size: 18),
      // Merged into the button's node: a toggle, on once thanks are given.
      label: Semantics(
        toggled: _given,
        label: _count == 0 ? action : '$action. ${l.todahCount(_count)}',
        excludeSemantics: true,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.todahAction),
            if (_count > 0) ...[
              const Gap(Space.sm),
              // In the button's own ink.
              Text('$_count', style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
            ],
          ],
        ),
      ),
    );
  }
}

Future<bool> _confirm(BuildContext context, {required String title, String? message, required String action}) async =>
    await showAppDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: message == null ? null : Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.l10n.actionCancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(action)),
        ],
      ),
    ) ??
    false;

/// Asks why a post is being reported. No reason is chosen at first: the
/// reporter picks one.
Future<(ReportReason, String?)?> showReportDialog(BuildContext context) {
  final l = context.l10n;
  ReportReason? reason;
  final details = TextEditingController();
  return showAppDialog<(ReportReason, String?)>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(l.reportTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.reportReasonLabel, style: Theme.of(context).textTheme.titleSmall),
              RadioGroup<ReportReason>(
                groupValue: reason,
                onChanged: (v) => setState(() => reason = v),
                child: Column(
                  children: [
                    for (final (r, label) in [
                      (ReportReason.spam, l.reasonSpam),
                      (ReportReason.lashonHara, l.reasonLashonHara),
                      (ReportReason.disrespect, l.reasonDisrespect),
                      (ReportReason.misinformation, l.reasonMisinformation),
                      (ReportReason.offTopic, l.reasonOffTopic),
                      (ReportReason.other, l.reasonOther),
                    ])
                      RadioListTile<ReportReason>(value: r, title: Text(label), contentPadding: EdgeInsets.zero),
                  ],
                ),
              ),
              TextField(controller: details, maxLines: 3, maxLength: 1000, decoration: InputDecoration(labelText: l.reportDetails)),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l.actionCancel)),
          FilledButton(
            onPressed: switch (reason) {
              final r? => () => Navigator.pop(context, (r, details.text)),
              null => null,
            },
            child: Text(l.actionReport),
          ),
        ],
      ),
    ),
  );
}
