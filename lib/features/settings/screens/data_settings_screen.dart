import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/providers.dart';
import '../../../services/feedback.dart';
import '../../community/data/backend.dart';
import '../../../ui/l10n.dart';
import '../app_settings.dart';
import '../widgets/settings_widgets.dart';

/// A backup contains both progress and settings, as JSON. Progress this
/// version couldn't read is kept apart, as `unreadableProgress`, so that the
/// rest can always be imported again, and that part restored with it.
String exportBackup(WidgetRef ref) {
  final progress = ref.read(progressProvider);
  return const JsonEncoder.withIndent('  ').convert({
    'app': 'shnayim_mikra',
    'exportedAt': DateTime.now().toUtc().toIso8601String(),
    'progress': progress.readable.toJson(),
    'unreadableProgress': ?progress.unknownMissingFrom(progress.readable),
    'settings': ref.read(settingsProvider).toJson(),
  });
}

/// Restores a backup made by [exportBackup]. A file with anything this
/// version can't read exactly is rejected whole, rather than half imported.
bool importBackup(WidgetRef ref, String raw) {
  try {
    final j = jsonDecode(raw.trim()) as Map<String, dynamic>;
    if (j['app'] != 'shnayim_mikra') return false;
    final progress = ProgressState.fromJson(j['progress'] as Map<String, dynamic>, strict: true);
    final unreadable = (j['unreadableProgress'] ?? const <String, dynamic>{}) as Map<String, dynamic>;
    final settings = j['settings'] is Map<String, dynamic>
        ? AppSettings.fromJson(j['settings'] as Map<String, dynamic>)
        : null;
    ref.read(progressProvider.notifier).restore(
          progress,
          unknownWeeks: (unreadable['weeks'] ?? const <String, dynamic>{}) as Map<String, dynamic>,
          unknownPauses: (unreadable['pauses'] ?? const []) as List,
        );
    if (settings != null) {
      ref.read(settingsProvider.notifier).replace(settings.copyWith(onboardingComplete: true));
    }
    return true;
  } catch (_) {
    return false;
  }
}

class DataSettingsScreen extends ConsumerWidget {
  const DataSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    return SettingsPage(
      title: l.settingsData,
      children: [
        ListTile(
          leading: const Icon(Icons.upload_file),
          title: Text(l.exportData),
          subtitle: Text(l.exportDataDesc),
          onTap: () async {
            final data = exportBackup(ref);
            await Clipboard.setData(ClipboardData(text: data));
            if (!context.mounted) return;
            showStatus(context, l.exportCopied);
            try {
              await SharePlus.instance.share(ShareParams(text: data, subject: l.appTitleFull));
            } catch (_) {
              // Sharing isn't available everywhere; the clipboard copy suffices.
            }
          },
        ),
        ListTile(
          leading: const Icon(Icons.download),
          title: Text(l.importData),
          subtitle: Text(l.importDataDesc),
          onTap: () async {
            final controller = TextEditingController();
            final ok = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(l.importData),
                content: TextField(
                  controller: controller,
                  maxLines: 8,
                  decoration: InputDecoration(labelText: l.importPrompt, alignLabelWithHint: true),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.actionCancel)),
                  FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l.importData)),
                ],
              ),
            );
            if (ok != true || !context.mounted) return;
            showStatus(context, importBackup(ref, controller.text) ? l.importSuccess : l.importFailed);
          },
        ),
        const Divider(height: 32),
        ListTile(
          leading: Icon(Icons.delete_forever_outlined, color: Theme.of(context).colorScheme.error),
          title: Text(l.resetProgress),
          onTap: () async {
            // With backup on, the reset reaches the backup and other devices,
            // but only for the account signed in now: a reset made signed out
            // must not erase the backup of whoever signs in next.
            final everywhere =
                ref.read(settingsProvider).cloudSync && ref.read(forumRepositoryProvider).currentUser != null;
            final ok = await showDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(l.resetProgress),
                content: Text(everywhere ? l.resetProgressConfirmSynced : l.resetProgressConfirm),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.actionCancel)),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.error,
                      foregroundColor: Theme.of(context).colorScheme.onError,
                    ),
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(l.resetProgress),
                  ),
                ],
              ),
            );
            if (ok != true || !context.mounted) return;
            ref.read(progressProvider.notifier).resetAll(ref.read(todayProvider), everywhere: everywhere);
            showStatus(context, l.resetDone);
          },
        ),
      ],
    );
  }
}
