import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../services/feedback.dart';
import '../../../ui/l10n.dart';
import '../../../ui/theme/app_theme.dart';
import '../../../ui/widgets/common.dart';
import '../data/backend.dart';
import '../data/community_providers.dart';
import '../data/models.dart';
import 'community_ui.dart';

/// Sign in with a 6-digit email code; manage profile, backup and account.
class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key, this.returnWhenSignedIn = false});

  /// Opened to sign in before an action (e.g. posting): go back to it once
  /// signed in.
  final bool returnWhenSignedIn;

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  final _email = TextEditingController();
  final _code = TextEditingController();
  final _name = TextEditingController();
  bool _codeSent = false;
  bool _busy = false;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() f, {String? success}) async {
    setState(() => _busy = true);
    try {
      await f();
      if (success != null && mounted) showStatus(context, success);
    } catch (e) {
      if (mounted) showStatus(context, communityError(context.l10n, e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final repo = ref.watch(forumRepositoryProvider);
    final user = ref.watch(communityUserProvider).value;
    final profile = ref.watch(myProfileProvider).value;
    return Scaffold(
      appBar: AppBar(title: Text(user == null ? l.signInTitle : l.settingsAccount)),
      body: Column(
        children: [
          const DemoBanner(),
          Expanded(
            child: PageBody(
              children: user == null ? _signIn(context, repo.isDemo) : _signedIn(context, profile),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _signIn(BuildContext context, bool demo) {
    final l = context.l10n;
    return [
      Text(l.signInBody, style: Theme.of(context).textTheme.bodyLarge),
      const Gap(16),
      if (!_codeSent) ...[
        AutofillGroup(
          child: TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            textDirection: TextDirection.ltr,
            decoration: InputDecoration(labelText: l.emailLabel),
            onSubmitted: (_) => _sendCode(),
          ),
        ),
        const Gap(16),
        FilledButton(onPressed: _busy ? null : _sendCode, child: Text(l.sendCodeAction)),
      ] else ...[
        Text(l.codeSentTo(_email.text.trim())),
        if (demo) Text(l.demoCodeHint, style: Theme.of(context).textTheme.bodySmall),
        const Gap(12),
        TextField(
          controller: _code,
          keyboardType: TextInputType.number,
          autofillHints: const [AutofillHints.oneTimeCode],
          inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
          textDirection: TextDirection.ltr,
          decoration: InputDecoration(labelText: l.codeLabel),
          onSubmitted: (_) => _verify(),
        ),
        const Gap(16),
        FilledButton(onPressed: _busy ? null : _verify, child: Text(l.verifyAction)),
        TextButton(onPressed: () => setState(() => _codeSent = false), child: Text(l.useDifferentEmail)),
      ],
      const Gap(24),
      TextButton(onPressed: () => context.push('/settings/about/legal/privacy'), child: Text(l.privacyTitle)),
    ];
  }

  Future<void> _sendCode() => _run(() async {
        await ref.read(forumRepositoryProvider).sendCode(_email.text.trim());
        setState(() => _codeSent = true);
      });

  Future<void> _verify() => _run(() async {
        await ref.read(forumRepositoryProvider).verifyCode(_email.text.trim(), _code.text.trim());
        ref.invalidate(myProfileProvider);
        _code.clear();
        _codeSent = false;
        if (mounted && widget.returnWhenSignedIn && context.canPop()) context.pop();
      });

  List<Widget> _signedIn(BuildContext context, Profile? profile) {
    final l = context.l10n;
    final repo = ref.read(forumRepositoryProvider);
    final settings = ref.watch(settingsProvider);
    final lastSync = ref.watch(progressSyncProvider);
    if (profile != null && _name.text.isEmpty && profile.hasChosenName) _name.text = profile.displayName;
    return [
      if (profile != null) ...[
        Text(l.signedInAs(profile.displayName), style: Theme.of(context).textTheme.titleMedium),
        if (profile.isModerator) Chip(avatar: const Icon(Icons.shield_outlined, size: 18), label: Text(l.moderatorBadge)),
      ],
      SectionHeader(l.displayNameLabel),
      TextField(
        controller: _name,
        maxLength: 40,
        textDirection: autoDirection(_name.text),
        autofillHints: const [AutofillHints.nickname],
        decoration: InputDecoration(labelText: l.displayNameLabel, helperText: l.displayNameHelp),
      ),
      Align(
        alignment: AlignmentDirectional.centerStart,
        child: FilledButton.tonal(
          style: AppButtons.tonal(context),
          onPressed: _busy
              ? null
              : () => _run(() async {
                    await repo.updateDisplayName(_name.text);
                    ref.invalidate(myProfileProvider);
                  }, success: l.nameSaved),
          child: Text(l.saveName),
        ),
      ),
      SectionHeader(l.syncProgress),
      SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(l.syncProgress),
        subtitle: Text(l.syncProgressDesc),
        value: settings.cloudSync,
        onChanged: (v) => ref.read(settingsProvider.notifier).update((s) => s.copyWith(cloudSync: v)),
      ),
      if (settings.cloudSync)
        Row(
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.sync),
              label: Text(l.syncNow),
              onPressed: () async {
                final ok = await ref.read(progressSyncProvider.notifier).syncNow();
                if (context.mounted) showStatus(context, ok ? l.syncDone : l.syncFailed);
              },
            ),
            const Gap(12),
            if (lastSync != null) Expanded(child: Text(l.lastSynced(relativeTime(context, lastSync)))),
          ],
        ),
      SectionHeader(l.blockedUsersTitle),
      const _BlockedList(),
      const Divider(height: 40),
      if (profile?.isModerator ?? false)
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.shield_outlined),
          title: Text(l.moderationQueue),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go('/community/moderation'),
        ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const Icon(Icons.logout),
        title: Text(l.actionSignOut),
        onTap: () => _run(() async {
          await repo.signOut();
          ref.invalidate(myProfileProvider);
        }),
      ),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(Icons.delete_forever_outlined, color: Theme.of(context).colorScheme.error),
        title: Text(l.deleteAccount),
        onTap: () async {
          final ok = await showDialog<bool>(
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
          if (ok == true) {
            await _run(() async {
              await repo.deleteAccount();
              ref.read(settingsProvider.notifier).update((s) => s.copyWith(cloudSync: false));
              ref.invalidate(myProfileProvider);
            }, success: l.accountDeleted);
          }
        },
      ),
    ];
  }
}

class _BlockedList extends ConsumerWidget {
  const _BlockedList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final repo = ref.watch(forumRepositoryProvider);
    ref.watch(blockedUsersProvider);
    return FutureBuilder<List<(String, String)>>(
      future: repo.blockedMembers(),
      builder: (context, snap) {
        final list = snap.data ?? const [];
        if (list.isEmpty) return const Text('—');
        return Column(
          children: [
            for (final (id, name) in list)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(name),
                trailing: TextButton(
                  onPressed: () async {
                    await repo.unblock(id);
                    ref.invalidate(blockedUsersProvider);
                  },
                  child: Text(l.unblock),
                ),
              ),
          ],
        );
      },
    );
  }
}
