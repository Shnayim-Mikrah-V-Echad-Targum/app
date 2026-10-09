import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../services/feedback.dart';
import '../../../ui/l10n.dart';
import '../../../ui/widgets/common.dart';
import '../../progress/domain/progress_models.dart';
import '../data/backend.dart';
import '../data/community_providers.dart';
import 'community_ui.dart';

/// Start a new discussion. With `?parsha=<key>` (from a week's page), opens
/// that parsha's shared discussion instead.
class ComposeScreen extends ConsumerStatefulWidget {
  const ComposeScreen({super.key, this.forumSlug, this.parshaKey});

  final String? forumSlug;
  final String? parshaKey;

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
    if (widget.parshaKey != null && widget.forumSlug == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _openParshaThread());
    }
  }

  Future<void> _openParshaThread() async {
    final repo = ref.read(parshaRepositoryProvider);
    final portion = repo.all.where((p) => p.key == widget.parshaKey).firstOrNull;
    final week = ref.read(currentWeekProvider);
    if (portion == null) return;
    await openWeeklyThread(context, ref, portion, cycleYearOf(week.portion, week.occasion), replace: true);
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
    if (!await ensureSignedIn(context, ref) || !mounted) return;
    if (!await ensureGuidelines(context, ref) || !mounted) return;
    setState(() => _sending = true);
    try {
      final id = await ref.read(forumRepositoryProvider).createThread(
            forumId: _forumId!,
            title: _title.text,
            body: _body.text,
          );
      await ref.read(sharedPreferencesProvider).remove(_draftKey);
      ref.invalidate(threadsProvider);
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

    if (widget.parshaKey != null && widget.forumSlug == null) {
      return Scaffold(appBar: AppBar(), body: const Center(child: CircularProgressIndicator()));
    }

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
                      onPressed: () => context.push('/settings/about/legal/guidelines'),
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
