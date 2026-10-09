import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../services/feedback.dart';
import '../../../ui/l10n.dart';
import '../../../ui/widgets/common.dart';
import '../data/backend.dart';
import '../data/community_providers.dart';
import '../data/models.dart';
import 'community_ui.dart';

/// A discussion: posts in chronological order (flat, which reads more
/// predictably with screen readers than deep nesting), and a reply box.
class ThreadScreen extends ConsumerStatefulWidget {
  const ThreadScreen({super.key, required this.threadId});
  final String threadId;

  @override
  ConsumerState<ThreadScreen> createState() => _ThreadScreenState();
}

class _ThreadScreenState extends ConsumerState<ThreadScreen> {
  final _reply = TextEditingController();
  final _focus = FocusNode();
  Post? _replyTo;
  bool _sending = false;
  Timer? _draftTimer;

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
    super.dispose();
  }

  Future<void> _send() async {
    final l = context.l10n;
    if (!await ensureSignedIn(context, ref) || !mounted) return;
    if (!await ensureGuidelines(context, ref) || !mounted) return;
    setState(() => _sending = true);
    try {
      await ref.read(forumRepositoryProvider).reply(widget.threadId, _reply.text, replyToId: _replyTo?.id);
      _reply.clear();
      await ref.read(sharedPreferencesProvider).remove(_draftKey);
      setState(() => _replyTo = null);
      ref.invalidate(postsProvider(widget.threadId));
      ref.invalidate(threadProvider(widget.threadId));
      if (mounted) showStatus(context, l.posted);
    } catch (e) {
      if (mounted) showStatus(context, communityError(l, e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _moderate(String action) async {
    try {
      await ref.read(forumRepositoryProvider).moderate(action, widget.threadId);
      ref.invalidate(threadProvider(widget.threadId));
    } catch (e) {
      if (mounted) showStatus(context, communityError(context.l10n, e));
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

    return Scaffold(
      appBar: AppBar(
        title: Text(t?.title ?? '', overflow: TextOverflow.ellipsis),
        actions: [
          if (isMod && t != null)
            PopupMenuButton<String>(
              tooltip: l.actionMore,
              onSelected: _moderate,
              itemBuilder: (context) => [
                PopupMenuItem(value: t.pinned ? 'unpin_thread' : 'pin_thread', child: Text(t.pinned ? l.unpinThread : l.pinThread)),
                PopupMenuItem(value: t.locked ? 'unlock_thread' : 'lock_thread', child: Text(t.locked ? l.unlockThread : l.lockThread)),
              ],
            ),
        ],
      ),
      body: Column(
        children: [
          const DemoBanner(),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(postsProvider(widget.threadId));
                ref.invalidate(threadProvider(widget.threadId));
              },
              child: posts.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ListView(children: [Padding(padding: const EdgeInsets.all(24), child: Text(communityError(l, e)))]),
                data: (list) => PageBody(
                  children: [
                    if (t != null) ...[
                      Semantics(
                        header: true,
                        headingLevel: 1,
                        child: Text(t.title, textDirection: autoDirection(t.title), style: Theme.of(context).textTheme.headlineSmall),
                      ),
                      const Gap(4),
                      Text(l.postsCount(list.length), style: Theme.of(context).textTheme.bodySmall),
                      if (t.locked) ...[const Gap(8), NoticeBanner(icon: Icons.lock_outline, text: l.lockedThread)],
                      const Gap(12),
                    ],
                    if (list.isEmpty) Padding(padding: const EdgeInsets.all(24), child: Text(l.noThreads, textAlign: TextAlign.center)),
                    for (var i = 0; i < list.length; i++)
                      PostCard(
                        post: list[i],
                        index: i,
                        total: list.length,
                        replyTo: list.where((p) => p.id == list[i].replyToId).firstOrNull,
                        isMine: user != null && list[i].authorId == user.id,
                        isModerator: isMod,
                        onReply: () {
                          setState(() => _replyTo = list[i]);
                          _focus.requestFocus();
                        },
                      ),
                  ],
                ),
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
    );
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
    required this.index,
    required this.total,
    required this.isMine,
    required this.isModerator,
    required this.onReply,
    this.replyTo,
  });

  final Post post;
  final int index;
  final int total;
  final Post? replyTo;
  final bool isMine;
  final bool isModerator;
  final VoidCallback onReply;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final repo = ref.read(forumRepositoryProvider);
    final name = post.authorName.isEmpty ? l.anonymousMember : post.authorName;

    void refresh() => ref.invalidate(postsProvider(post.threadId));

    Future<void> run(Future<void> Function() f, {String? success}) async {
      try {
        await f();
        refresh();
        if (success != null && context.mounted) showStatus(context, success);
      } catch (e) {
        if (context.mounted) showStatus(context, communityError(l, e));
      }
    }

    Future<void> onMenu(String v) async {
      switch (v) {
        case 'reply':
          onReply();
        case 'edit':
          final controller = TextEditingController(text: post.body);
          final ok = await showDialog<bool>(
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
          final ok = await _confirm(context, l.deletePostConfirm, l.actionDelete);
          if (ok) await run(() => repo.deletePost(post.id), success: l.postDeleted);
        case 'report':
          if (!await ensureSignedIn(context, ref) || !context.mounted) return;
          final result = await showReportDialog(context);
          if (result != null) {
            await run(() => repo.report(postId: post.id, reason: result.$1, details: result.$2), success: l.reportSent);
          }
        case 'block':
          if (!await ensureSignedIn(context, ref) || !context.mounted) return;
          final ok = await _confirm(context, l.blockConfirm(name), l.blockUser(name));
          if (ok && post.authorId != null) {
            await run(() => repo.block(post.authorId!), success: l.blockedDone);
            ref.invalidate(blockedUsersProvider);
          }
        case 'hide':
          await run(() => repo.moderate('hide_post', post.id));
      }
    }

    final time = relativeTime(context, post.createdAt);
    final header = '${l.postedBy(name, time)}${post.editedAt != null ? ' · ${l.edited}' : ''}';

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Semantics(
        container: true,
        label: '${index + 1}/$total',
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
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
                    tooltip: l.actionMore,
                    onSelected: onMenu,
                    itemBuilder: (context) => [
                      PopupMenuItem(value: 'reply', child: Text(l.replyAction)),
                      if (isMine) PopupMenuItem(value: 'edit', child: Text(l.actionEdit)),
                      if (isMine || isModerator) PopupMenuItem(value: 'delete', child: Text(l.actionDelete)),
                      if (!isMine) PopupMenuItem(value: 'report', child: Text(l.actionReport)),
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
              if (replyTo != null)
                Container(
                  margin: const EdgeInsetsDirectional.only(end: 12, bottom: 8),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    border: BorderDirectional(start: BorderSide(color: theme.colorScheme.primary, width: 3)),
                    color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                  ),
                  child: Text(
                    '${replyTo!.authorName}: ${replyTo!.body}',
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    textDirection: autoDirection(replyTo!.body),
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
                child: TextButton.icon(
                  onPressed: isMine
                      ? null
                      : () async {
                          if (!await ensureSignedIn(context, ref)) return;
                          await run(() => repo.setTodah(post.id, !post.myTodah));
                        },
                  icon: Icon(post.myTodah ? Icons.favorite : Icons.favorite_border, size: 20),
                  label: Semantics(
                    label: '${l.todahSemantics(name)}. ${l.todahCount(post.todah)}',
                    excludeSemantics: true,
                    child: Text(l.todahCount(post.todah)),
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

Future<bool> _confirm(BuildContext context, String message, String action) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.l10n.actionCancel)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(action)),
        ],
      ),
    ) ??
    false;

/// Asks why a post is being reported.
Future<(ReportReason, String?)?> showReportDialog(BuildContext context) {
  final l = context.l10n;
  var reason = ReportReason.spam;
  final details = TextEditingController();
  return showDialog<(ReportReason, String?)>(
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
                onChanged: (v) => setState(() => reason = v ?? reason),
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
          FilledButton(onPressed: () => Navigator.pop(context, (reason, details.text)), child: Text(l.actionReport)),
        ],
      ),
    ),
  );
}
