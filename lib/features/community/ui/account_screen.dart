import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../services/feedback.dart';
import '../../../ui/l10n.dart';
import '../../../ui/theme/app_theme.dart';
import '../../../ui/widgets/app_mark.dart';
import '../../../ui/widgets/common.dart';
import '../../../ui/widgets/paper_group.dart';
import '../data/backend.dart';
import '../data/community_providers.dart';
import '../data/models.dart';
import 'community_ui.dart';

/// Sign in with a 6-digit email code, choose the name posts are signed with,
/// and manage the profile, backup and account (§9 Account).
///
/// Signing in takes three steps in one centred column: the email, the code,
/// and, for an account that still has a machine's name, a display name. A
/// page opened to sign in before an action ([returnWhenSignedIn]) goes back
/// to it only once the account has a name of its own, so that no post is
/// signed "user_1a2b3c4d".
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key, this.returnWhenSignedIn = false});

  /// Opened to sign in before an action (e.g. posting): go back to it once
  /// signed in.
  final bool returnWhenSignedIn;

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  /// How long the code must be waited for before it can be sent again.
  static const resendDelay = 30;

  final _email = TextEditingController();
  final _code = TextEditingController();
  final _name = TextEditingController();
  // Each step's field takes the keyboard focus as the step appears, and
  // again with its error.
  final _emailFocus = FocusNode();
  final _codeFocus = FocusNode();
  final _nameFocus = FocusNode();
  bool _codeSent = false;
  bool _busy = false;

  /// From the code's check until the account's profile has come: the code
  /// step stays meanwhile, rather than the signed-in page flashing past.
  bool _verifying = false;

  /// Signed in on this page: the name step follows if the account has no
  /// name of its own yet.
  bool _justSignedIn = false;

  /// Whether the name step is on show, whose field takes the focus as it
  /// appears, however the page came to it.
  bool _onNameStep = false;

  bool _syncing = false;
  String? _emailError;
  String? _codeError;
  String? _nameError;

  /// Seconds left before the code can be sent again.
  int _resendIn = 0;
  Timer? _resendTimer;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _email.dispose();
    _code.dispose();
    _name.dispose();
    _emailFocus.dispose();
    _codeFocus.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  /// Gives [node] the focus once the frame that builds its field is done.
  void _focusAfterFrame(FocusNode node) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && node.context != null) node.requestFocus();
    });
  }

  /// [name] as it goes into a sentence: isolated when it runs the other way.
  String _inLine(String name) =>
      autoDirection(name, fallback: Directionality.of(context)) == Directionality.of(context) ? name : isolate(name);

  /// Shows [e] under the field it is about, which takes the focus, or else
  /// (a rate limit, or no connection) in a status message.
  void _showError(Object e) {
    final message = communityError(context.l10n, e);
    final field = fieldOf(e);
    final node = switch (field) {
      CommunityField.email => _emailFocus,
      CommunityField.code => _codeFocus,
      CommunityField.name => _nameFocus,
      _ => null,
    };
    if (node == null || node.context == null) {
      showStatus(context, message);
      return;
    }
    setState(() {
      switch (field) {
        case CommunityField.email:
          _emailError = message;
        case CommunityField.code:
          _codeError = message;
          // Typing replaces the code that didn't work.
          _code.selection = TextSelection(baseOffset: 0, extentOffset: _code.text.length);
        case _:
          _nameError = message;
      }
    });
    node.requestFocus();
    announceFieldError(context, message);
  }

  Future<void> _run(Future<void> Function() f, {String? success}) async {
    setState(() => _busy = true);
    try {
      await f();
      if (success != null && mounted) showStatus(context, success);
    } catch (e) {
      if (mounted) _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final repo = ref.watch(forumRepositoryProvider);
    final user = ref.watch(communityUserProvider).value;
    final profileState = ref.watch(myProfileProvider);
    final profile = profileState.value;
    final signingIn = user == null || _verifying;
    final List<Widget> children;
    if (signingIn) {
      children = _codeSent ? _codeStep(context, repo.isDemo) : _emailStep(context);
    } else if (profile == null && profileState.isLoading) {
      children = [
        Padding(
          padding: const EdgeInsets.only(top: Space.s40),
          child: Center(child: CircularProgressIndicator(semanticsLabel: l.loading)),
        ),
      ];
    } else if (profile != null && !profile.hasChosenName && (_justSignedIn || widget.returnWhenSignedIn)) {
      children = _nameStep(context);
    } else {
      children = _signedIn(context, user, profile);
    }
    // The name step's field takes the focus as the step appears: after the
    // code, or as the page opens on it, for a member signed in already but
    // never named who is about to post.
    final onNameStep = !signingIn && profile != null && !profile.hasChosenName && (_justSignedIn || widget.returnWhenSignedIn);
    if (onNameStep && !_onNameStep) _focusAfterFrame(_nameFocus);
    _onNameStep = onNameStep;
    return PageScaffold(
      titleText: l.settingsAccount,
      contentMaxWidth: ContentWidth.account,
      actions: const [DemoTag()],
      body: PageBody(maxWidth: ContentWidth.account, children: children),
    );
  }

  // --- Signing in ------------------------------------------------------------

  /// The app's mark, a heading and a line of marginalia over a step.
  List<Widget> _stepHead(BuildContext context, {required Widget mark, required String title, String? body}) {
    final theme = Theme.of(context);
    return [
      const Gap(Space.xxl),
      Center(child: mark),
      const Gap(Space.lg),
      Semantics(
        header: true,
        headingLevel: 2,
        child: Text(title, style: theme.textTheme.headlineSmall, textAlign: TextAlign.center),
      ),
      if (body != null) ...[
        const Gap(Space.sm),
        Text(body, style: SeferType.of(context).marginalia, textAlign: TextAlign.center),
      ],
    ];
  }

  List<Widget> _emailStep(BuildContext context) {
    final l = context.l10n;
    return [
      ..._stepHead(context, mark: const AppMark(size: 56), title: l.signInTitle, body: l.signInBody),
      const Gap(Space.xxl),
      AutofillGroup(
        child: TextField(
          controller: _email,
          focusNode: _emailFocus,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          textDirection: TextDirection.ltr,
          decoration: InputDecoration(labelText: l.emailLabel, errorText: _emailError, errorMaxLines: 3),
          onChanged: (_) {
            if (_emailError != null) setState(() => _emailError = null);
          },
          onSubmitted: (_) => _sendCode(),
        ),
      ),
      const Gap(Space.lg),
      FilledButton(onPressed: _busy ? null : _sendCode, child: Text(l.sendCodeAction)),
      const Gap(Space.xl),
      LinkedText(
        text: l.signInPrivacy,
        link: l.privacyTitle,
        textAlign: TextAlign.center,
        onTap: () => context.push('/legal/privacy'),
      ),
    ];
  }

  List<Widget> _codeStep(BuildContext context, bool demo) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return [
      ..._stepHead(
        context,
        mark: const AppMark(size: 56),
        title: l.signInTitle,
        body: l.codeSentTo(context.ltrRun(_email.text.trim())),
      ),
      if (demo) ...[
        const Gap(Space.xs),
        Text(
          l.demoCodeHint,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
      ],
      const Gap(Space.xxl),
      _CodeBoxes(
        controller: _code,
        focusNode: _codeFocus,
        error: _codeError,
        onChanged: (code) {
          if (_codeError != null) setState(() => _codeError = null);
          if (code.length == _CodeBoxes.length && !_busy) _verify();
        },
        onSubmitted: (_) => _verify(),
      ),
      const Gap(Space.xxl),
      FilledButton(onPressed: _busy ? null : _verify, child: Text(l.verifyAction)),
      const Gap(Space.sm),
      Wrap(
        alignment: WrapAlignment.center,
        spacing: Space.sm,
        children: [
          TextButton(
            onPressed: _resendIn > 0 || _busy ? null : _sendCode,
            child: Text(_resendIn > 0 ? l.resendCodeIn(_resendIn) : l.resendCode),
          ),
          TextButton(onPressed: _useDifferentEmail, child: Text(l.useDifferentEmail)),
        ],
      ),
    ];
  }

  void _useDifferentEmail() {
    _resendTimer?.cancel();
    setState(() {
      _codeSent = false;
      _resendIn = 0;
      _codeError = null;
      _code.clear();
    });
    _focusAfterFrame(_emailFocus);
  }

  void _startResendCountdown() {
    _resendTimer?.cancel();
    _resendIn = resendDelay;
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _resendIn--);
      if (_resendIn <= 0) timer.cancel();
    });
  }

  /// Sends the code (again, from the code step), and moves on to the code's
  /// boxes, saying where the code went.
  Future<void> _sendCode() async {
    if (_busy) return;
    final l = context.l10n;
    final email = _email.text.trim();
    // Plainly no address: said at once, without asking the server.
    if (!email.contains('@')) {
      _showError(const CommunityException('invalid_email'));
      return;
    }
    final sent = l.codeSentTo(context.ltrRun(email));
    await _run(() async {
      await ref.read(forumRepositoryProvider).sendCode(email);
      if (!mounted) return;
      setState(() {
        _codeSent = true;
        _codeError = null;
        _code.clear();
        _startResendCountdown();
      });
      _focusAfterFrame(_codeFocus);
    }, success: sent);
  }

  /// Signs in, and says as whom; then asks for a name if the account has
  /// none of its own yet, or else goes back to what it was opened for.
  Future<void> _verify() async {
    if (_busy) return;
    final l = context.l10n;
    final email = _email.text.trim();
    setState(() {
      _busy = true;
      _verifying = true;
      _codeError = null;
    });
    try {
      await ref.read(forumRepositoryProvider).verifyCode(email, _code.text.trim());
      ref.invalidate(myProfileProvider);
      // Whether it has a name decides what follows. Should the profile not
      // come, the caller asks for it again (see ensureSignedIn).
      Profile? profile;
      try {
        profile = await ref.read(myProfileProvider.future);
      } catch (_) {}
      if (!mounted) return;
      _resendTimer?.cancel();
      _code.clear();
      _codeSent = false;
      _resendIn = 0;
      if (profile != null && !profile.hasChosenName) {
        _justSignedIn = true;
        _name.clear();
        showStatus(context, l.signedInAs(context.ltrRun(email)));
        _focusAfterFrame(_nameFocus);
        return;
      }
      _finishSigningIn(l.signedInAs(_inLine(profile?.displayName ?? email)));
    } catch (e) {
      if (mounted) _showError(e);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _verifying = false;
        });
      }
    }
  }

  /// Says [message], and goes back to what the page was opened for, if it
  /// was, with nothing over it.
  void _finishSigningIn(String message) {
    if (widget.returnWhenSignedIn && context.canPop()) {
      announceStatus(context, message);
      context.pop();
    } else {
      showStatus(context, message);
    }
  }

  List<Widget> _nameStep(BuildContext context) {
    final l = context.l10n;
    return [
      ..._stepHead(
        context,
        // The initial the name will be shown with, as it is typed.
        mark: ListenableBuilder(listenable: _name, builder: (context, _) => InitialDisc(_name.text, size: 56)),
        title: l.displayNameLabel,
      ),
      const Gap(Space.xxl),
      _NameField(
        controller: _name,
        focusNode: _nameFocus,
        error: _nameError,
        onChanged: () {
          if (_nameError != null) setState(() => _nameError = null);
        },
        onSubmitted: _saveName,
      ),
      const Gap(Space.lg),
      FilledButton(onPressed: _busy ? null : _saveName, child: Text(l.saveName)),
    ];
  }

  /// Saves the name chosen after signing in, then goes back to what the page
  /// was opened for, if it was.
  Future<void> _saveName() async {
    if (_busy) return;
    final l = context.l10n;
    final name = _name.text.trim();
    if (name.length < 2) {
      _showError(const CommunityException('invalid_name'));
      return;
    }
    await _run(() async {
      await ref.read(forumRepositoryProvider).updateDisplayName(name);
      ref.invalidate(myProfileProvider);
      final saved = await ref.read(myProfileProvider.future);
      if (!mounted) return;
      _justSignedIn = false;
      if (widget.returnWhenSignedIn) {
        _finishSigningIn(l.signedInAs(_inLine(saved?.displayName ?? name)));
      } else {
        showStatus(context, l.nameSaved);
      }
    });
  }

  // --- Signed in ---------------------------------------------------------------

  List<Widget> _signedIn(BuildContext context, CommunityUser user, Profile? profile) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final repo = ref.read(forumRepositoryProvider);
    final settings = ref.watch(settingsProvider);
    final lastSync = ref.watch(progressSyncProvider);
    final syncBlocked = ref.watch(syncBlockedByNewerFormatProvider);
    // Counted once known: while they load, or can't, the row says no number,
    // and still opens the list, which says why.
    final blocked = ref.watch(blockedUsersProvider).value?.length;
    final sync = settings.cloudSync;
    void setSync(bool on) => ref.read(settingsProvider.notifier).update((s) => s.copyWith(cloudSync: on));
    return [
      _ProfileCard(
        // A machine's name is no name: until one is chosen, the email.
        name: profile != null && profile.hasChosenName ? profile.displayName : null,
        email: user.email,
        moderator: profile?.isModerator ?? false,
        onEdit: profile == null ? null : () => _editName(profile),
      ),
      GroupHeader(l.cloudBackupTitle),
      PaperGroup(
        children: [
          // One item for screen readers, a switch in its state, which the
          // row's tap toggles; Sync now is an item of its own. The switch
          // can't merge into the row with Sync now beside it, so it is left
          // out of the semantics and the focus order, and the row says its
          // state.
          PaperRow(
            title: l.syncProgress,
            subtitle: sync && lastSync != null ? l.lastSynced(relativeTime(context, lastSync)) : null,
            onTap: () => setSync(!sync),
            toggled: sync,
            chevron: false,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (sync)
                  IconButton(
                    tooltip: l.syncNow,
                    onPressed: _syncNow,
                    icon: _syncing
                        ? SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2, semanticsLabel: l.loading),
                          )
                        : const Icon(Icons.sync),
                  ),
                ExcludeFocus(child: ExcludeSemantics(child: Switch(value: sync, onChanged: setSync))),
              ],
            ),
          ),
        ],
      ),
      // What backing up does, under it as the list of cities is noted:
      // the row's subtitle would cut it short beside the switch.
      Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(Space.xs, Space.sm, Space.xs, 0),
        child: Text(l.syncProgressDesc, style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
      ),
      if (sync && syncBlocked) ...[
        const Gap(Rhythm.cardGap),
        NoticeBanner(icon: Icons.system_update_outlined, text: l.syncNeedsUpdate),
      ],
      GroupHeader(l.privacySafetyTitle),
      PaperGroup(
        children: [
          PaperRow(
            icon: Icons.block,
            title: blocked == null ? l.blockedUsersTitle : l.blockedMembersCount(blocked),
            subtitle: blocked == 0 ? l.noBlockedMembers : null,
            onTap: blocked == 0 ? null : _showBlocked,
          ),
          if (profile?.isModerator ?? false)
            PaperRow(
              icon: Icons.shield_outlined,
              title: l.moderationQueue,
              onTap: () => context.push('/community/moderation'),
            ),
        ],
      ),
      GroupHeader(l.accountGroupTitle),
      PaperGroup(
        children: [
          PaperRow(
            icon: Icons.logout,
            title: l.actionSignOut,
            chevron: false,
            onTap: () => _run(() async {
              await repo.signOut();
              ref.invalidate(myProfileProvider);
            }),
          ),
          PaperRow(
            icon: Icons.delete_forever_outlined,
            iconColor: scheme.error,
            title: l.deleteAccount,
            titleStyle: theme.textTheme.bodyLarge?.copyWith(color: scheme.error),
            chevron: false,
            onTap: _deleteAccount,
          ),
        ],
      ),
    ];
  }

  Future<void> _syncNow() async {
    if (_syncing) return;
    final l = context.l10n;
    setState(() => _syncing = true);
    final ok = await ref.read(progressSyncProvider.notifier).syncNow();
    if (!mounted) return;
    setState(() => _syncing = false);
    final blocked = ref.read(syncBlockedByNewerFormatProvider);
    showStatus(context, ok ? l.syncDone : (blocked ? l.syncNeedsUpdate : l.syncFailed));
  }

  Future<void> _editName(Profile profile) async {
    final l = context.l10n;
    final repo = ref.read(forumRepositoryProvider);
    final saved = await showAppDialog<bool>(
      context: context,
      builder: (context) => _NameDialog(
        initial: profile.hasChosenName ? profile.displayName : '',
        save: repo.updateDisplayName,
      ),
    );
    if (saved != true || !mounted) return;
    ref.invalidate(myProfileProvider);
    showStatus(context, l.nameSaved);
  }

  Future<void> _deleteAccount() async {
    final l = context.l10n;
    final repo = ref.read(forumRepositoryProvider);
    final ok = await showAppDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.deleteAccount),
        content: Text(l.deleteAccountConfirm),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.actionCancel)),
          FilledButton(
            style: AppButtons.destructive(context),
            onPressed: () => Navigator.pop(context, true),
            child: Text(l.deleteAccount),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(() async {
      await repo.deleteAccount();
      ref.read(settingsProvider.notifier).update((s) => s.copyWith(cloudSync: false));
      ref.invalidate(myProfileProvider);
    }, success: l.accountDeleted);
  }

  void _showBlocked() => showAppSheet<void>(
        context: context,
        isScrollControlled: true,
        builder: (context) => const _BlockedMembersSheet(),
      );
}

/// The sign-in code as six boxes (§6.7): 48×56, radius 10, each digit in
/// the sans at titleLarge's size with tabular figures.
///
/// One field lies under the boxes, so typing moves on box by box, a
/// backspace goes back, a pasted code fills all six, and the platform can
/// fill in a code it has read. A screen reader meets that one field, "6-digit
/// code", and what is typed in it. The box the next digit goes in shows the
/// field's focus.
class _CodeBoxes extends StatelessWidget {
  const _CodeBoxes({
    required this.controller,
    required this.focusNode,
    required this.error,
    required this.onChanged,
    required this.onSubmitted,
  });

  static const length = 6;

  final TextEditingController controller;
  final FocusNode focusNode;
  final String? error;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final highContrast = SeferColors.of(context).isHighContrast;
    final error = this.error;
    final digit = theme.textTheme.titleMedium!.copyWith(
      fontSize: 22,
      height: 28 / 22,
      color: scheme.onSurface,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    // Taller with enlarged text, so a digit never fills its box.
    final height = math.max(56.0, MediaQuery.textScalerOf(context).scale(22) * 28 / 22 + Space.lg);
    const corners = BorderRadius.all(Radius.circular(10));
    const none = InputBorder.none;
    final field = TextSelectionTheme(
      // Only the boxes show the code: the field's own text, caret and
      // selection are never seen.
      data: const TextSelectionThemeData(selectionColor: Colors.transparent, selectionHandleColor: Colors.transparent),
      child: Semantics(
        label: l.codeLabel,
        hint: error,
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(length)],
          showCursor: false,
          style: digit.copyWith(color: Colors.transparent),
          decoration: const InputDecoration(
            isCollapsed: true,
            contentPadding: EdgeInsets.zero,
            border: none,
            enabledBorder: none,
            focusedBorder: none,
            errorBorder: none,
            focusedErrorBorder: none,
            disabledBorder: none,
          ),
          onChanged: onChanged,
          onSubmitted: onSubmitted,
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = Space.sm;
            final width = math.min(48.0, (constraints.maxWidth - gap * (length - 1)) / length);
            return ListenableBuilder(
              listenable: Listenable.merge([controller, focusNode]),
              builder: (context, _) {
                final code = controller.text;
                final next = math.min(code.length, length - 1);
                BorderSide side(int i) {
                  final focused = focusNode.hasFocus && i == next;
                  if (error != null) return BorderSide(color: scheme.error, width: focused && highContrast ? 3 : 2);
                  if (focused) return BorderSide(color: scheme.primary, width: highContrast ? 3 : 2);
                  return BorderSide(color: scheme.outline, width: highContrast ? 2 : 1);
                }

                return Directionality(
                  // A code reads left to right in either language.
                  textDirection: TextDirection.ltr,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      ExcludeSemantics(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var i = 0; i < length; i++) ...[
                              if (i > 0) const SizedBox(width: gap),
                              Container(
                                width: width,
                                height: height,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  borderRadius: corners,
                                  border: Border.fromBorderSide(side(i)),
                                ),
                                child: Text(i < code.length ? code[i] : '', style: digit),
                              ),
                            ],
                          ],
                        ),
                      ),
                      Positioned.fill(child: field),
                    ],
                  ),
                );
              },
            );
          },
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: Space.sm),
            // Said as it appears where the platform takes no announcements,
            // as a text field's error is.
            child: Semantics(
              container: true,
              liveRegion: !MediaQuery.supportsAnnounceOf(context),
              child: Text(
                error,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(color: scheme.error),
              ),
            ),
          ),
      ],
    );
  }
}

/// The display name's field, under a heading that names it ("Display
/// name"), so the field shows no label of its own and screen readers hear
/// the name from it all the same. Its counter appears near the 40
/// characters it takes.
class _NameField extends StatelessWidget {
  const _NameField({
    required this.controller,
    required this.focusNode,
    required this.error,
    required this.onChanged,
    required this.onSubmitted,
    this.autofocus = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final String? error;
  final VoidCallback onChanged;
  final VoidCallback onSubmitted;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return ValueListenableBuilder(
      valueListenable: controller,
      builder: (context, value, _) => Semantics(
        label: l.displayNameLabel,
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          autofocus: autofocus,
          maxLength: 40,
          buildCounter: quietCounter,
          textInputAction: TextInputAction.done,
          textDirection: autoDirection(value.text, fallback: Directionality.of(context)),
          autofillHints: const [AutofillHints.nickname],
          decoration: InputDecoration(
            helperText: l.displayNameHelp,
            errorText: error,
            helperMaxLines: 3,
            errorMaxLines: 3,
          ),
          onChanged: (_) => onChanged(),
          onSubmitted: (_) => onSubmitted(),
        ),
      ),
    );
  }
}

/// Edits the display name in a dialog titled "Display name", with Save.
/// It closes with true once [save] has saved the name. Every error shows
/// under the field, which keeps the focus: a status message would sit
/// behind the dialog.
class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.initial, required this.save});

  final String initial;
  final Future<void> Function(String name) save;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _name = TextEditingController(text: widget.initial);
  final _focus = FocusNode();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _name.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _showError(String message) {
    setState(() => _error = message);
    _focus.requestFocus();
    announceFieldError(context, message);
  }

  Future<void> _save() async {
    if (_busy) return;
    final l = context.l10n;
    final name = _name.text.trim();
    if (name.length < 2) {
      _showError(l.errInvalidName);
      return;
    }
    setState(() => _busy = true);
    try {
      await widget.save(name);
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) _showError(communityError(l, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(l.displayNameLabel),
      content: SizedBox(
        width: 360,
        child: _NameField(
          controller: _name,
          focusNode: _focus,
          error: _error,
          autofocus: true,
          onChanged: () {
            if (_error != null) setState(() => _error = null);
          },
          onSubmitted: _save,
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.actionCancel)),
        FilledButton(onPressed: _busy ? null : _save, child: Text(l.actionSave)),
      ],
    );
  }
}

/// The member signed in, on a card: their initial on a 56 px disc, their
/// name, the email they sign in with, a moderator's chip, and a button that
/// edits the name.
class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.name, required this.email, required this.moderator, required this.onEdit});

  final String? name;
  final String? email;
  final bool moderator;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final direction = Directionality.of(context);
    // The name runs its own way, from the card's start edge.
    final edge = direction == TextDirection.rtl ? TextAlign.right : TextAlign.left;
    final name = this.name;
    final email = this.email;
    final title = name ?? email ?? '';
    return InfoCard(
      child: Row(
        children: [
          InitialDisc(name ?? '', size: 56),
          const Gap(Space.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleLarge,
                  textAlign: edge,
                  textDirection: name == null ? TextDirection.ltr : autoDirection(name, fallback: direction),
                ),
                if (name != null && email != null)
                  Text(
                    email,
                    style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                    textAlign: edge,
                    textDirection: TextDirection.ltr,
                  ),
                if (moderator) ...[
                  const Gap(Space.sm),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: Chip(
                      avatar: Icon(Icons.shield_outlined, size: 18, color: scheme.onSurfaceVariant),
                      label: Text(l.moderatorBadge),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Gap(Space.sm),
          IconButton(tooltip: l.editDisplayName, icon: const Icon(Icons.edit_outlined), onPressed: onEdit),
        ],
      ),
    );
  }
}

/// The members the reader has blocked, each with Unblock; or, once there
/// are none, a sentence saying so. An Unblock that fails says why under its
/// member, in the sheet, where a status message would sit unseen behind it;
/// while one is sent, its button waits.
class _BlockedMembersSheet extends ConsumerStatefulWidget {
  const _BlockedMembersSheet();

  @override
  ConsumerState<_BlockedMembersSheet> createState() => _BlockedMembersSheetState();
}

class _BlockedMembersSheetState extends ConsumerState<_BlockedMembersSheet> {
  /// The members whose Unblock is being sent.
  final _busy = <String>{};

  /// Why a member's Unblock failed, by member.
  final _errors = <String, String>{};

  Future<void> _unblock(String id) async {
    if (_busy.contains(id)) return;
    final l = context.l10n;
    setState(() {
      _busy.add(id);
      _errors.remove(id);
    });
    try {
      await ref.read(forumRepositoryProvider).unblock(id);
      ref.invalidate(blockedUsersProvider);
    } catch (e) {
      if (mounted) setState(() => _errors[id] = communityError(l, e));
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final padding = sheetPadding(context);
    final members = ref.watch(blockedMembersProvider);
    Widget note(String text) => Padding(
          padding: EdgeInsets.fromLTRB(padding, Space.sm, padding, Space.sm),
          child: Text(text, style: theme.textTheme.bodyLarge?.copyWith(color: scheme.onSurfaceVariant)),
        );

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: Space.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SheetTitle(l.blockedUsersTitle),
            members.when(
              loading: () => Padding(
                padding: const EdgeInsets.all(Space.xxl),
                child: Center(child: CircularProgressIndicator(semanticsLabel: l.loading)),
              ),
              error: (e, _) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  note(communityError(l, e)),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: padding - Space.sm),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton(
                        onPressed: () => ref.invalidate(blockedUsersProvider),
                        child: Text(l.actionRetry),
                      ),
                    ),
                  ),
                ],
              ),
              data: (list) => list.isEmpty
                  ? note(l.noBlockedMembers)
                  : Column(
                      children: [
                        for (final (id, name) in list)
                          ListTile(
                            title: Text(name, textDirection: autoDirection(name, fallback: Directionality.of(context))),
                            subtitle: switch (_errors[id]) {
                              final error? => Semantics(
                                  liveRegion: !MediaQuery.supportsAnnounceOf(context),
                                  child: Text(error, style: theme.textTheme.bodySmall?.copyWith(color: scheme.error)),
                                ),
                              null => null,
                            },
                            trailing: TextButton(
                              onPressed: _busy.contains(id) ? null : () => _unblock(id),
                              child: Text(l.unblock),
                            ),
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
