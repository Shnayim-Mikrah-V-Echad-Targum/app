import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../services/feedback.dart';
import '../../../ui/l10n.dart';
import '../../../ui/theme/app_theme.dart';
import '../../../ui/widgets/common.dart';
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
    if (!await ensureSignedIn(context, ref) || !mounted) return;
    try {
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

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final thread = ref.watch(threadProvider(widget.threadId));
    final posts = ref.watch(postsProvider(widget.threadId));
    final user = ref.watch(communityUserProvider).value;
    final profile = ref.watch(myProfileProvider).value;
    final isMod = profile?.isModerator ?? false;
    final t = thread.value;
    final title = t == null ? '' : threadDisplayTitle(context, ref, t);

    final content = RefreshablePage(
      refresh: _refresh,
      builder: (context, refreshButton) => PageScaffold(
        titleText: title,
        // An English title in Hebrew UI, or the reverse, is cut at its own end.
        title: Text(title, textDirection: autoDirection(title), overflow: TextOverflow.ellipsis),
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
                    return PageBody.builder(
                      controller: _scroll,
                      header: [
                        if (t != null) ...[
                          Semantics(
                            header: true,
                            headingLevel: 1,
                            child: Text(title, textDirection: autoDirection(title), style: Theme.of(context).textTheme.headlineSmall),
                          ),
                          // An empty thread says so below.
                          if (list.isNotEmpty) ...[
                            const Gap(4),
                            Text(l.postsCount(total), style: Theme.of(context).textTheme.bodySmall),
                          ],
                          if (t.locked) ...[const Gap(8), NoticeBanner(icon: Icons.lock_outline, text: l.lockedThread)],
                          const Gap(12),
                        ],
                        if (list.isEmpty && t != null)
                          Padding(
                            padding: const EdgeInsets.all(24),
                            child: Text(emptyThreadMessage(context, ref, t), textAlign: TextAlign.center),
                          ),
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
                      ],
                      itemCount: list.length,
                      itemBuilder: (context, i) => PostCard(
                        key: ValueKey(list[i].id),
                        post: list[i],
                        number: offset + i + 1,
                        total: total,
                        focusNode: list[i].id == _firstPostFocused ? _firstPostFocus : null,
                        // As loaded, or else as fetched with the reply.
                        quote: switch (byId[list[i].replyToId]) {
                          final p? => QuotedPost(authorName: p.authorName, body: p.body),
                          null => list[i].quote,
                        },
                        isMine: user != null && list[i].authorId == user.id,
                        isModerator: isMod,
                        onReply: () {
                          setState(() => _replyTo = list[i]);
                          _focus.requestFocus();
                        },
                      ),
                    );
                  },
                ),
              ),
            ),
            if (t != null && (!t.locked || isMod))
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
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainer,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (replyTo != null)
                Row(
                  children: [
                    const Icon(Icons.reply, size: 18),
                    const Gap(6),
                    Expanded(child: Text(l.replyingTo(replyTo!.authorName), overflow: TextOverflow.ellipsis)),
                    IconButton(tooltip: l.actionCancel, icon: const Icon(Icons.close), onPressed: onCancelReply),
                  ],
                ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: controller,
                      focusNode: focusNode,
                      minLines: 1,
                      maxLines: 6,
                      maxLength: 10000,
                      buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
                      textDirection: autoDirection(controller.text),
                      keyboardType: TextInputType.multiline,
                      decoration: InputDecoration(labelText: l.replyLabel),
                    ),
                  ),
                  const Gap(8),
                  FilledButton(
                    onPressed: onSend,
                    child: sending
                        ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(l.replyAction),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PostCard extends ConsumerWidget {
  const PostCard({
    super.key,
    required this.post,
    required this.number,
    required this.total,
    required this.isMine,
    required this.isModerator,
    required this.onReply,
    this.quote,
    this.focusNode,
  });

  final Post post;

  /// Its place in the thread, from 1, of [total].
  final int number;
  final int total;

  /// The post it replies to.
  final QuotedPost? quote;
  final bool isMine;
  final bool isModerator;
  final VoidCallback onReply;

  /// Makes the post itself take the keyboard focus when it is given to it,
  /// though it is no stop of its own for Tab.
  final FocusNode? focusNode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final repo = ref.read(forumRepositoryProvider);
    // This card may be gone (its thread closed, say) by the time an action
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
        case 'reply':
          onReply();
        case 'edit':
          final controller = TextEditingController(text: post.body);
          final ok = await showAppDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(l.editPostTitle),
              content: TextField(controller: controller, maxLines: 8, minLines: 3, textDirection: autoDirection(post.body)),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.actionCancel)),
                FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l.actionSave)),
              ],
            ),
          );
          if (ok == true) await run(() => repo.editPost(post.id, controller.text));
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

    final time = relativeTime(context, post.createdAt);
    final header = '${l.postedBy(name, time)}${post.editedAt != null ? ' · ${l.edited}' : ''}';

    final card = Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        container: true,
        label: l.postNofM(number, total),
        child: Padding(
          // Room at the end for the menu button's focus ring: the card clips.
          padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 8, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Tooltip(
                      message: absoluteTime(context, post.createdAt),
                      child: Semantics(
                        label: '${l.postedBy(name, absoluteTime(context, post.createdAt))}${post.editedAt != null ? ', ${l.edited}' : ''}',
                        excludeSemantics: true,
                        child: Text(header, style: theme.textTheme.labelLarge),
                      ),
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: l.moreOptionsFor(name),
                    popUpAnimationStyle: Motion.of(context).style,
                    onSelected: onMenu,
                    itemBuilder: (context) => [
                      PopupMenuItem(value: 'reply', child: Text(l.replyAction)),
                      if (isMine) PopupMenuItem(value: 'edit', child: Text(l.actionEdit)),
                      if (isMine || isModerator) PopupMenuItem(value: 'delete', child: Text(l.actionDelete)),
                      if (!isMine && !reported) PopupMenuItem(value: 'report', child: Text(l.actionReport)),
                      if (!isMine && post.authorId != null) PopupMenuItem(value: 'block', child: Text(l.blockUser(name))),
                      if (isModerator && !isMine) PopupMenuItem(value: 'hide', child: Text(l.hidePost)),
                    ],
                  ),
                ],
              ),
              if (post.hidden)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(l.pendingReview, style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
                ),
              if (quote case final quote?)
                Container(
                  margin: const EdgeInsetsDirectional.only(end: 12, bottom: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: BorderDirectional(start: BorderSide(color: theme.colorScheme.primary, width: 3)),
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  ),
                  child: Text(
                    '${quote.authorName.isEmpty ? l.anonymousMember : quote.authorName}: ${quote.body}',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    textDirection: autoDirection(quote.body),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              Padding(
                padding: const EdgeInsetsDirectional.only(end: 12),
                child: SelectableText(
                  post.body,
                  textDirection: autoDirection(post.body),
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                ),
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: _TodahButton(post: post, authorName: name, isMine: isMine),
              ),
            ],
          ),
        ),
      ),
    );
    final focusNode = this.focusNode;
    if (focusNode == null) return card;
    // Ringed while it has the focus, as a SeferInkWell is (§6.1): the focus
    // colour, 3 px outside the card's corners.
    final radius = switch (theme.cardTheme.shape) {
      RoundedRectangleBorder(:final borderRadius) => borderRadius,
      _ => const BorderRadius.all(Radius.circular(12)),
    };
    return Focus(
      focusNode: focusNode,
      child: ListenableBuilder(
        listenable: focusNode,
        builder: (context, child) => DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: focusNode.hasFocus
              ? ShapeDecoration(
                  shape: RoundedRectangleBorder(
                    borderRadius: radius,
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
        child: card,
      ),
    );
  }
}

/// "Todah" (thanks) for a post. A tap shows at once, and is undone if it
/// fails; further taps wait for it. The button stays enabled meanwhile, so
/// that it keeps the keyboard focus.
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
    final action = _given ? l.todahRemove(widget.authorName) : l.todahSemantics(widget.authorName);
    return TextButton.icon(
      onPressed: widget.isMine ? null : _toggle,
      icon: Icon(_given ? Icons.favorite : Icons.favorite_border, size: 20),
      // Merged into the button's node: a toggle, on once thanks are given.
      label: Semantics(
        toggled: widget.isMine ? null : _given,
        label: '$action. ${l.todahCount(_count)}',
        excludeSemantics: true,
        child: Text(l.todahCount(_count)),
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
