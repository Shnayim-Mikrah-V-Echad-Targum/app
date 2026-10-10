import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../services/feedback.dart';
import '../../../ui/l10n.dart';
import '../../../ui/widgets/common.dart';
import '../data/backend.dart';
import '../data/community_providers.dart';
import 'community_ui.dart';

/// Start a new discussion, in the forum [forumSlug] if given.
class ComposeScreen extends ConsumerStatefulWidget {
  const ComposeScreen({super.key, this.forumSlug});

  final String? forumSlug;

  @override
  ConsumerState<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends ConsumerState<ComposeScreen> {
  final _title = TextEditingController();
  final _body = TextEditingController();
  int? _forumId;
  bool _sending = false;
  Timer? _draftTimer;
  static const _draftKey = 'draft.newThread';

  @override
  void initState() {
    super.initState();
    final raw = ref.read(sharedPreferencesProvider).getString(_draftKey);
    if (raw != null) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        _title.text = j['title'] as String? ?? '';
        _body.text = j['body'] as String? ?? '';
      } catch (_) {}
    }
    void save() {
      _draftTimer?.cancel();
      _draftTimer = Timer(const Duration(milliseconds: 600), () {
        ref.read(sharedPreferencesProvider).setString(_draftKey, jsonEncode({'title': _title.text, 'body': _body.text}));
      });
      setState(() {});
    }

    _title.addListener(save);
    _body.addListener(save);
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    final l = context.l10n;
    // This page may close while the post is sent, and its ref with it.
    final prefs = ref.read(sharedPreferencesProvider);
    final container = ProviderScope.containerOf(context, listen: false);
    final repo = ref.read(forumRepositoryProvider);
    if (!await ensureSignedIn(context, ref) || !mounted) return;
    try {
      if (!await ensureGuidelines(context, ref) || !mounted) return;
      setState(() => _sending = true);
      final id = await repo.createThread(forumId: _forumId!, title: _title.text, body: _body.text);
      // Sent: whatever happens to this page, the draft must not come back.
      _draftTimer?.cancel();
      await prefs.remove(_draftKey);
      container.invalidate(threadsProvider);
      if (mounted) {
        showStatus(context, l.posted);
        context.pushReplacement('/community/thread/$id');
      }
    } catch (e) {
      if (mounted) showStatus(context, communityError(l, e));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final he = context.isHebrewUi;
    final forums = ref.watch(forumsProvider).value ?? const [];
    final profile = ref.watch(myProfileProvider).value;
    final available = forums.where((f) => !f.locked || (profile?.isModerator ?? false)).toList();
    _forumId ??= available.where((f) => f.slug == widget.forumSlug).firstOrNull?.id ?? available.firstOrNull?.id;
    final canPost = _forumId != null && _title.text.trim().length >= 5 && _body.text.trim().length >= 2 && !_sending;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.newThread),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: FilledButton(onPressed: canPost ? _post : null, child: Text(l.postAction)),
          ),
        ],
      ),
      body: Column(
        children: [
          const DemoBanner(),
          Expanded(
            child: AutofillGroup(
              child: PageBody(
                children: [
                  DropdownButtonFormField<int>(
                    initialValue: _forumId,
                    // As wide as the field, rather than its longest forum's
                    // name, which can be wider than a phone.
                    isExpanded: true,
                    decoration: InputDecoration(labelText: l.forumLabel),
                    items: [for (final f in available) DropdownMenuItem(value: f.id, child: Text(f.name(he)))],
                    onChanged: (v) => setState(() => _forumId = v),
                  ),
                  const Gap(16),
                  TextField(
                    controller: _title,
                    maxLength: 150,
                    textDirection: autoDirection(_title.text),
                    decoration: InputDecoration(
                      labelText: l.threadTitleLabel,
                      errorText: _title.text.isNotEmpty && _title.text.trim().length < 5 ? l.errTitleTooShort : null,
                    ),
                  ),
                  const Gap(8),
                  TextField(
                    controller: _body,
                    minLines: 6,
                    maxLines: 16,
                    maxLength: 10000,
                    textDirection: autoDirection(_body.text),
                    keyboardType: TextInputType.multiline,
                    decoration: InputDecoration(labelText: l.threadBodyLabel, alignLabelWithHint: true),
                  ),
                  const Gap(8),
                  Text(l.guidelinesPrompt, style: Theme.of(context).textTheme.bodySmall),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton(
                      onPressed: () => context.push('/legal/guidelines'),
                      child: Text(l.readGuidelines),
                    ),
                  ),
                  if (_title.text.isNotEmpty || _body.text.isNotEmpty)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        icon: const Icon(Icons.delete_outline),
                        label: Text(l.discardDraft),
                        onPressed: () {
                          _title.clear();
                          _body.clear();
                          ref.read(sharedPreferencesProvider).remove(_draftKey);
                        },
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
}
