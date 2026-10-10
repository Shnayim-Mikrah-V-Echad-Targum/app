import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/calendar/local_date.dart';
import '../../../l10n/app_localizations.dart';
import '../../../services/backup_files.dart';
import '../../../services/feedback.dart';
import '../../../services/notifications.dart';
import '../../../ui/l10n.dart';
import '../../../ui/theme/app_theme.dart';
import '../../../ui/widgets/common.dart';
import '../../community/data/backend.dart';
import '../../progress/domain/progress_merge.dart';
import '../backup.dart';
import '../widgets/settings_widgets.dart';

/// A backup of all progress and settings, made at [now] (see
/// [encodeBackup]).
String exportBackup(WidgetRef ref, {DateTime? now}) =>
    encodeBackup(ref.read(progressProvider), ref.read(settingsProvider), now: now ?? TodayController.now());

/// Saves a backup as a file, the platform's way (see [BackupFiles.save]).
/// [context] is the control's own, where the iPad anchors the share sheet.
/// If the file can't be saved, the backup is copied to the clipboard.
Future<void> exportBackupFile(BuildContext context, WidgetRef ref) async {
  final l = context.l10n;
  final now = TodayController.now();
  final data = exportBackup(ref, now: now);
  final files = ref.read(backupFilesProvider);
  final box = context.findRenderObject();
  final origin = box is RenderBox && box.hasSize ? box.localToGlobal(Offset.zero) & box.size : null;
  try {
    final saved = await files.save(data, backupFileName(now), subject: l.appTitleFull, origin: origin);
    if (saved && context.mounted) showStatus(context, l.exportSaved);
  } catch (_) {
    await Clipboard.setData(ClipboardData(text: data));
    if (context.mounted) showStatus(context, l.exportCopied);
  }
}

/// How restoring a backup went, for the caller to say (see
/// [backupImportStatus]).
enum BackupImport {
  restored,

  /// Restored, but with the reminders its settings had on turned off: this
  /// device doesn't allow the app's notifications.
  remindersOff,

  /// Not a backup this version can read. Nothing changed.
  unreadable,
}

/// What to say once a backup is restored as [result]: [restored] if it was.
String backupImportStatus(AppLocalizations l, BackupImport result, {required String restored}) => switch (result) {
      BackupImport.restored => restored,
      BackupImport.remindersOff => '$restored ${l.importRemindersOff}',
      BackupImport.unreadable => l.importFailed,
    };

/// Restores [backup], merged with the progress here (see [mergeBackup]), or
/// with [replace], in its place. Either way it counts as a new change, which
/// the next sync keeps (see [ProgressController.restore]).
///
/// The join date is the earlier of this device's and the backup's (see
/// [Backup.joinDate]), so that the history from both counts; replacing, it
/// is the one saved with the backup, if any.
///
/// Its settings come too only [withSettings], keeping this device's record
/// of having offered reminders. Reminders they turn on need the OS's
/// permission here, as they did on the device that saved them, so it is
/// asked for; refused, they are turned off ([BackupImport.remindersOff]).
Future<BackupImport> importBackup(
  WidgetRef ref,
  Backup backup, {
  bool replace = false,
  bool withSettings = false,
}) async {
  // All read now: the page may close while the OS asks.
  final progress = ref.read(progressProvider.notifier);
  final settings = ref.read(settingsProvider.notifier);
  final notifications = ref.read(notificationServiceProvider);
  final current = ref.read(settingsProvider);
  final savedJoin = backup.settings?.joinDate;
  final joinDate = replace && savedJoin != null ? savedJoin : [current.joinDate, backup.joinDate].nonNulls.minOrNull;
  progress.restore(
    replace ? backup.progress : mergeBackup(ref.read(progressProvider), backup.progress),
    unknownWeeks: backup.unknownWeeks,
    unknownPauses: backup.unknownPauses,
  );
  final restored = withSettings ? backup.settings : null;
  if (restored == null) {
    if (joinDate != current.joinDate) settings.update((s) => s.copyWith(joinDate: joinDate));
    return BackupImport.restored;
  }
  var next = restored.copyWith(
    onboardingComplete: true,
    notificationPromptShown: current.notificationPromptShown,
    joinDate: joinDate,
  );
  var result = BackupImport.restored;
  if (notifications.supported && anyReminderOn(next)) {
    final allowed = await notifications.requestPermission();
    // Asked now, they aren't offered again after the first aliyah.
    next = next.copyWith(notificationPromptShown: true);
    if (!allowed) {
      next = next.copyWith(dailyReminder: false, fridayReminder: false, checkInReminder: false);
      result = BackupImport.remindersOff;
    }
  }
  settings.replace(next);
  return result;
}

/// Asks for a backup file, shows what it holds, and restores it as the
/// reader chooses (see [importBackup]). Null if the reader cancels;
/// otherwise how it went, for the caller to say.
Future<BackupImport?> askToImportBackup(BuildContext context, WidgetRef ref) async {
  final String? raw;
  try {
    raw = await ref.read(backupFilesProvider).open();
  } catch (_) {
    return BackupImport.unreadable;
  }
  if (raw == null || !context.mounted) return null;
  final backup = parseBackup(raw);
  if (backup == null) return BackupImport.unreadable;
  return _confirmImport(context, ref, backup);
}

/// As [askToImportBackup], for a backup pasted as text: an earlier version
/// shared its backups that way.
Future<BackupImport?> askToPasteBackup(BuildContext context, WidgetRef ref) async {
  final backup = await showAppDialog<Backup>(context: context, builder: (_) => const _PasteDialog());
  if (backup == null || !context.mounted) return null;
  return _confirmImport(context, ref, backup);
}

typedef _ImportChoice = ({bool replace, bool withSettings});

Future<BackupImport?> _confirmImport(BuildContext context, WidgetRef ref, Backup backup) async {
  final choice = await showAppDialog<_ImportChoice>(
    context: context,
    builder: (_) => _ImportDialog(
      backup: backup,
      merge: holdsProgress(ref.read(progressProvider)),
      // A reader still setting up has no settings of their own to keep.
      withSettings: !ref.read(settingsProvider).onboardingComplete,
    ),
  );
  if (choice == null || !context.mounted) return null;
  return importBackup(ref, backup, replace: choice.replace, withSettings: choice.withSettings);
}

/// What a backup holds, and how to restore it: merged with the progress
/// here, or in its place, and whether with its settings.
class _ImportDialog extends StatefulWidget {
  const _ImportDialog({required this.backup, required this.merge, required this.withSettings});

  final Backup backup;

  /// Whether there is progress here to merge with. Without any, the backup
  /// simply comes in.
  final bool merge;

  /// Whether its settings come too, until the reader says.
  final bool withSettings;

  @override
  State<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends State<_ImportDialog> {
  late bool _withSettings = widget.withSettings;

  void _choose({required bool replace}) => Navigator.pop<_ImportChoice>(
        context,
        (replace: replace, withSettings: _withSettings && widget.backup.settings != null),
      );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final backup = widget.backup;
    final made = backup.exportedAt;
    final (weeks, pauses) = (backup.weeksLogged, backup.pauses);
    return AlertDialog(
      scrollable: true,
      title: Text(l.importData),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(made == null
              ? l.importCounts(weeks, pauses)
              : l.importSummary(Names(context).dateWithYear(LocalDate.fromDateTime(made)), weeks, pauses)),
          if (widget.merge) ...[const SizedBox(height: 12), Text(l.importMergeBody)],
          if (backup.settings != null) ...[
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _withSettings,
              onChanged: (v) => setState(() => _withSettings = v ?? false),
              title: Text(l.importAlsoSettings),
            ),
          ],
        ],
      ),
      // Stacked on a narrow screen, the main action comes first.
      actionsOverflowDirection: VerticalDirection.up,
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.actionCancel)),
        if (widget.merge) TextButton(onPressed: () => _choose(replace: true), child: Text(l.importReplace)),
        FilledButton(
          onPressed: () => _choose(replace: !widget.merge),
          child: Text(widget.merge ? l.importMerge : l.importData),
        ),
      ],
    );
  }
}

/// Takes a backup pasted as text, and returns it once it reads as one.
class _PasteDialog extends StatefulWidget {
  const _PasteDialog();

  @override
  State<_PasteDialog> createState() => _PasteDialogState();
}

class _PasteDialogState extends State<_PasteDialog> {
  final _text = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
    if (text == null || text.trim().isEmpty || !mounted) return;
    setState(() {
      _text.text = text;
      _error = null;
    });
  }

  void _continue() {
    final backup = parseBackup(_text.text);
    if (backup == null) {
      setState(() => _error = context.l10n.importFailed);
    } else {
      Navigator.pop(context, backup);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      scrollable: true,
      title: Text(l.importPaste),
      // As wide as the dialog can be, for the text.
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _text,
              maxLines: 8,
              onChanged: (_) {
                if (_error != null) setState(() => _error = null);
              },
              // A hint rather than a label, which would be cut short.
              decoration: InputDecoration(
                hintText: l.importPrompt,
                hintMaxLines: 3,
                errorText: _error,
                errorMaxLines: 3,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: _paste,
              icon: const Icon(Icons.content_paste),
              label: Text(l.pasteFromClipboard),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.actionCancel)),
        FilledButton(onPressed: _continue, child: Text(l.actionContinue)),
      ],
    );
  }
}

class DataSettingsScreen extends ConsumerWidget {
  const DataSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;

    Future<void> import(Future<BackupImport?> Function(BuildContext, WidgetRef) ask) async {
      final result = await ask(context, ref);
      if (result == null || !context.mounted) return;
      showStatus(context, backupImportStatus(l, result, restored: l.importSuccess));
    }

    return SettingsPage(
      title: l.settingsData,
      children: [
        ListTile(
          leading: const Icon(Icons.cloud_outlined),
          title: Text(l.cloudBackup),
          subtitle: Text(l.syncProgressDesc),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/settings/account'),
        ),
        Builder(
          // The row's own context, where the iPad anchors the share sheet.
          builder: (context) => ListTile(
            leading: const Icon(Icons.upload_file),
            title: Text(l.exportData),
            subtitle: Text(l.exportDataDesc),
            onTap: () => exportBackupFile(context, ref),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.download),
          title: Text(l.importData),
          subtitle: Text(l.importDataDesc),
          onTap: () => import(askToImportBackup),
        ),
        ListTile(
          leading: const Icon(Icons.content_paste),
          title: Text(l.importPaste),
          subtitle: Text(l.importPasteDesc),
          onTap: () => import(askToPasteBackup),
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
            final ok = await showAppDialog<bool>(
              context: context,
              builder: (context) => AlertDialog(
                title: Text(l.resetProgress),
                content: Text(everywhere ? l.resetProgressConfirmSynced : l.resetProgressConfirm),
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
            ref.read(progressProvider.notifier).resetAll(ref.read(todayProvider), everywhere: everywhere);
            showStatus(context, l.resetDone);
          },
        ),
      ],
    );
  }
}
