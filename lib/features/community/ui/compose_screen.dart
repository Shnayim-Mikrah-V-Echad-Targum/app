import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../services/feedback.dart';
import '../../../ui/l10n.dart';
import '../../../ui/theme/app_theme.dart';
import '../../../ui/widgets/app_icon.dart';
import '../../../ui/widgets/common.dart';
import '../../../ui/widgets/sefer_choice_chip.dart';
import '../data/backend.dart';
import '../data/community_providers.dart';
import '../data/models.dart';
import 'community_screen.dart';
import 'community_ui.dart';

/// Start a new discussion, in the forum [forumSlug] if given (§9 Compose):
/// the forum, then the title and message on a sheet of paper, signed with the
/// member's name once they have one.
///
/// Post is there whenever a forum is chosen. Pressed too soon, it says under
/// each field what it still needs and gives the first such field the focus,
/// where a screen reader hears why. An error from the server about a field
/// is shown the same way. Ctrl+Enter (⌘Enter) posts too.
class ComposeScreen extends ConsumerStatefulWidget {
  const ComposeScreen({super.key, this.forumSlug});

  final String? forumSlug;

  @override
  ConsumerState<ComposeScreen> createState() => _ComposeScreenState();
}

class _ComposeScreenState extends ConsumerState<ComposeScreen> {
  static const _titleMin = 5;
  static const _bodyMin = 2;
  static const _draftKey = 'draft.newThread';

  final _title = TextEditingController();
  final _body = TextEditingController();
  final _titleFocus = FocusNode();
  final _bodyFocus = FocusNode();
  int? _forumId;
  bool _sending = false;
  Timer? _draftTimer;

  /// What each field still needs, once Post has been pressed ([_checked]).
  /// They follow the text from then on, so each goes as soon as its field is
  /// long enough.
  String? _titleError;
  String? _bodyError;
  bool _checked = false;

  /// What the server said of a field (too many links, say), shown in place
  /// of its length's error until that field's own text changes.
  String? _titleServerError;
  String? _bodyServerError;

  /// Each field's text as last seen, so that only a change to its text (not
  /// to the other field's, nor to the selection) lets its server error go.
  String _titleSeen = '';
  String _bodySeen = '';

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
    _titleSeen = _title.text;
    _bodySeen = _body.text;
    void save() {
      _draftTimer?.cancel();
      _draftTimer = Timer(const Duration(milliseconds: 600), () {
        ref.read(sharedPreferencesProvider).setString(_draftKey, jsonEncode({'title': _title.text, 'body': _body.text}));
      });
      setState(() {
        if (_title.text != _titleSeen) _titleServerError = null;
        if (_body.text != _bodySeen) _bodyServerError = null;
        _titleSeen = _title.text;
        _bodySeen = _body.text;
        if (_checked) _check();
      });
    }

    _title.addListener(save);
    _body.addListener(save);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // In the language shown, should it change meanwhile.
    if (_checked) _check();
  }

  @override
  void dispose() {
    _draftTimer?.cancel();
    _title.dispose();
    _body.dispose();
    _titleFocus.dispose();
    _bodyFocus.dispose();
    super.dispose();
  }

  /// Sets what each field still needs. Returns whether both are ready.
  bool _check() {
    final l = context.l10n;
    _titleError = _title.text.trim().length < _titleMin ? l.errTitleTooShort : null;
    _bodyError = _body.text.trim().length < _bodyMin ? l.errBodyTooShort : null;
    return _titleError == null && _bodyError == null;
  }

  /// Shows [message] under [field], which takes the focus: what it still
  /// needs, or else what the [server] said of it.
  void _showFieldError(CommunityField field, String message, {bool server = false}) {
    final title = field == CommunityField.title;
    setState(() {
      switch ((title, server)) {
        case (true, false):
          _titleError = message;
        case (false, false):
          _bodyError = message;
        case (true, true):
          _titleServerError = message;
        case (false, true):
          _bodyServerError = message;
      }
    });
    (title ? _titleFocus : _bodyFocus).requestFocus();
    announceFieldError(context, message);
  }

  Future<void> _post() async {
    if (_forumId == null || _sending) return;
    final l = context.l10n;
    _checked = true;
    if (!_check()) {
      final title = _titleError != null;
      _showFieldError(title ? CommunityField.title : CommunityField.body, (title ? _titleError : _bodyError)!);
      return;
    }
    setState(() {});
    // This page may close while the post is sent, and its ref with it.
    final prefs = ref.read(sharedPreferencesProvider);
    final container = ProviderScope.containerOf(context, listen: false);
    final repo = ref.read(forumRepositoryProvider);
    try {
      if (!await ensureSignedIn(context, ref, named: true) || !mounted) return;
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
      if (!mounted) return;
      final message = communityError(l, e);
      switch (fieldOf(e)) {
        case final field? when field == CommunityField.title || field == CommunityField.body:
          _showFieldError(field, message, server: true);
        case _:
          showStatus(context, message);
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _discardDraft() {
    _title.clear();
    _body.clear();
    ref.read(sharedPreferencesProvider).remove(_draftKey);
    setState(() {
      _checked = false;
      _titleError = _bodyError = _titleServerError = _bodyServerError = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final direction = Directionality.of(context);
    final forums = ref.watch(forumsProvider).value ?? const [];
    final profile = ref.watch(myProfileProvider).value;
    final available = forums.where((f) => !f.locked || (profile?.isModerator ?? false)).toList();
    _forumId ??= available.where((f) => f.slug == widget.forumSlug).firstOrNull?.id ?? available.firstOrNull?.id;
    final post = _forumId != null && !_sending ? _post : null;
    final g = Gutter.of(context);
    Widget postLabel() => _sending
        ? SizedBox.square(
            dimension: 20,
            child: CircularProgressIndicator(strokeWidth: 2, semanticsLabel: l.sending),
          )
        : Text(l.postAction);
    final apple = defaultTargetPlatform == TargetPlatform.macOS || defaultTargetPlatform == TargetPlatform.iOS;

    return PageScaffold(
      titleText: l.newThread,
      leading: const CloseButton(),
      actions: [
        const DemoTag(),
        Padding(
          // Its end on the column's edge.
          padding: EdgeInsetsDirectional.only(end: g),
          child: FilledButton(
            // Compact in the app bar (§9 Compose), still a whole 48 to tap.
            style: const ButtonStyle(minimumSize: WidgetStatePropertyAll(Size(64, 40))),
            onPressed: post,
            child: postLabel(),
          ),
        ),
      ],
      body: CallbackShortcuts(
        bindings: {
          for (final key in [LogicalKeyboardKey.enter, LogicalKeyboardKey.numpadEnter])
            SingleActivator(key, control: !apple, meta: apple): () => post?.call(),
        },
        child: AutofillGroup(
          child: PageBody(
            // The forums scroll sideways out to the column's edges;
            // everything else keeps within the gutters.
            padding: const EdgeInsets.fromLTRB(0, Space.sm, 0, Space.s40),
            children: [
              _ForumPicker(
                forums: available,
                selected: _forumId,
                gutter: g,
                onSelected: (id) => setState(() => _forumId = id),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: g),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Gap(Space.lg),
                    InfoCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (profile != null && profile.hasChosenName) ...[
                            _PostingAs(profile.displayName),
                            const Gap(Space.lg),
                          ],
                          TextField(
                            controller: _title,
                            focusNode: _titleFocus,
                            maxLength: 150,
                            buildCounter: quietCounter,
                            textInputAction: TextInputAction.next,
                            textDirection: autoDirection(_title.text, fallback: direction),
                            decoration: InputDecoration(
                              labelText: l.threadTitleLabel,
                              helperText: l.titleMinHelp,
                              errorText: _titleServerError ?? _titleError,
                              helperMaxLines: 3,
                              errorMaxLines: 3,
                            ),
                          ),
                          const Gap(Space.md),
                          TextField(
                            controller: _body,
                            focusNode: _bodyFocus,
                            minLines: 6,
                            maxLines: 16,
                            maxLength: 10000,
                            buildCounter: quietCounter,
                            textDirection: autoDirection(_body.text, fallback: direction),
                            keyboardType: TextInputType.multiline,
                            decoration: InputDecoration(
                              labelText: l.threadBodyLabel,
                              alignLabelWithHint: true,
                              helperText: l.bodyMinHelp,
                              errorText: _bodyServerError ?? _bodyError,
                              helperMaxLines: 3,
                              errorMaxLines: 3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (profile?.acceptedTerms != true) ...[
                      const Gap(Space.md),
                      LinkedText(
                        text: l.guidelinesPrompt,
                        link: l.readGuidelines,
                        onTap: () => context.push('/legal/guidelines'),
                      ),
                    ],
                    const Gap(Space.xxl),
                    FilledButton(onPressed: post, child: postLabel()),
                    if (_title.text.isNotEmpty || _body.text.isNotEmpty) ...[
                      const Gap(Space.sm),
                      Center(
                        child: TextButton.icon(
                          icon: const Icon(Icons.delete_outline),
                          label: Text(l.discardDraft),
                          onPressed: _discardDraft,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The forums a discussion can begin in, under the label "Forum": a row of
/// chips with the forums' icons, which scrolls sideways out to the column's
/// edges, starting at its content's edge, [gutter] in. On a wide window,
/// where they fit in a line or two, they wrap instead.
class _ForumPicker extends StatefulWidget {
  const _ForumPicker({required this.forums, required this.selected, required this.gutter, required this.onSelected});

  final List<Forum> forums;
  final int? selected;
  final double gutter;
  final ValueChanged<int> onSelected;

  @override
  State<_ForumPicker> createState() => _ForumPickerState();
}

class _ForumPickerState extends State<_ForumPicker> {
  /// A key for each forum's chip, which stays with it: a key that moved to
  /// whichever chip is chosen would carry the chosen chip's element to the
  /// new one, and take the chip just pressed, with its focus, from the tree.
  final _keys = <int, GlobalKey>{};
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    _revealSelected();
  }

  @override
  void didUpdateWidget(_ForumPicker old) {
    super.didUpdateWidget(old);
    _revealSelected();
  }

  /// Once the forums have come, scrolls the row to the forum chosen as the
  /// page opens, which may lie past the screen's edge.
  void _revealSelected() {
    if (_revealed || widget.forums.isEmpty) return;
    _revealed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final chip = _keys[widget.selected]?.currentContext;
      final box = chip?.findRenderObject();
      if (!mounted || chip == null || box == null) return;
      // The row alone, where it scrolls: the page stays where it is.
      Scrollable.maybeOf(chip, axis: Axis.horizontal)?.position.ensureVisible(box, alignment: 0.5);
    });
  }

  @override
  Widget build(BuildContext context) {
    final he = context.isHebrewUi;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final chips = [
      for (final f in widget.forums)
        SeferChoiceChip(
          key: _keys.putIfAbsent(f.id, GlobalKey.new),
          avatar: AppIcon(
            CommunityScreen.iconFor(f.slug),
            size: 18,
            color: f.id == widget.selected ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
          ),
          label: Text(f.name(he)),
          selected: f.id == widget.selected,
          onSelected: (_) => widget.onSelected(f.id),
        ),
    ];
    final side = EdgeInsets.symmetric(horizontal: widget.gutter);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: side.copyWith(bottom: Space.xs),
          child: Text(
            context.l10n.forumLabel,
            style: theme.textTheme.titleSmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
        ),
        // A wide window has room for every forum, and a mouse can't drag a
        // row sideways: there they wrap.
        if (MediaQuery.sizeOf(context).width >= Breakpoints.medium)
          Padding(
            padding: side,
            child: Wrap(spacing: Space.sm, runSpacing: Space.sm, children: chips),
          )
        else
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: side,
            child: Row(
              children: [
                for (final (i, chip) in chips.indexed) ...[
                  if (i > 0) const Gap(Space.sm),
                  chip,
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// "Posting as Rivka", after the member's initial on a 24 px disc: the name
/// the discussion will be signed with.
class _PostingAs extends StatelessWidget {
  const _PostingAs(this.name);

  final String name;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final direction = Directionality.of(context);
    // A name in the other language keeps its own order in the line.
    final shown = autoDirection(name, fallback: direction) == direction ? name : isolate(name);
    return Row(
      children: [
        InitialDisc(name, size: 24),
        const Gap(Space.sm),
        Expanded(
          child: Text(
            context.l10n.postingAs(shown),
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ),
      ],
    );
  }
}
