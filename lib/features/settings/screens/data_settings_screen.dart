import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/providers.dart';
import '../../../services/feedback.dart';
import '../../../ui/l10n.dart';
import '../../../ui/theme/app_theme.dart';
import '../../../ui/widgets/common.dart';
import '../app_settings.dart';
import '../widgets/settings_widgets.dart';

/// A backup contains both progress and settings, as JSON.
String exportBackup(WidgetRef ref) => const JsonEncoder.withIndent('  ').convert({
      'app': 'shnayim_mikra',
      'exportedAt': DateTime.now().toUtc().toIso8601String(),
      'progress': ref.read(progressProvider).toJson(),
      'settings': ref.read(settingsProvider).toJson(),
    });

bool importBackup(WidgetRef ref, String raw) {
  try {
    final j = jsonDecode(raw.trim()) as Map<String, dynamic>;
    if (j['app'] != 'shnayim_mikra') return false;
    final progress = ProgressState.fromJson(j['progress'] as Map<String, dynamic>);
    ref.read(progressProvider.notifier).replaceAll(progress);
    if (j['settings'] is Map<String, dynamic>) {
      final imported = AppSettings.fromJson(j['settings'] as Map<String, dynamic>);
      ref.read(settingsProvider.notifier).replace(imported.copyWith(onboardingComplete: true));
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
            final ok = await showAppDialog<bool>(
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
            final ok = await showAppDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(l.resetProgress),
                content: Text(l.resetProgressConfirm),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.actionCancel)),
                  FilledButton(
                    style: AppButtons.destructive(context),
                    onPressed: () => Navigator.pop(context, true),
                    child: Text(l.resetProgress),
                  ),
                ],
              ),
            );
            if (ok != true || !context.mounted) return;
            ref.read(progressProvider.notifier).reset();
            showStatus(context, l.resetDone);
          },
        ),
      ],
    );
  }
}
