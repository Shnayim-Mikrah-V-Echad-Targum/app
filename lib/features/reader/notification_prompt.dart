import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../services/notifications.dart';
import '../../ui/l10n.dart';
import '../../ui/widgets/common.dart';

/// After the first aliyah: celebrate, and — only now, never on first launch —
/// offer a gentle daily reminder before the OS permission prompt.
Future<void> maybeOfferReminders(BuildContext context, WidgetRef ref, {required String celebration}) async {
  final l = context.l10n;
  final service = ref.read(notificationServiceProvider);
  final settings = ref.read(settingsProvider);
  ref.read(settingsProvider.notifier).update((s) => s.copyWith(notificationPromptShown: true));
  final time = Names(context).time(settings.dailyReminderMinutes);

  final yes = await showAppDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      icon: const Icon(Icons.celebration_outlined),
      title: Text(celebration),
      content: service.supported ? Text('${l.primingTitle}\n\n${l.primingBody(time)}') : null,
      actions: service.supported
          ? [
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.actionNotNow)),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l.primingYes)),
            ]
          : [FilledButton(onPressed: () => Navigator.pop(context, false), child: Text(l.actionOk))],
    ),
  );
  if (yes != true) return;
  final granted = await service.requestPermission();
  ref.read(settingsProvider.notifier).update((s) => s.copyWith(
        dailyReminder: granted,
        fridayReminder: granted,
        checkInReminder: granted,
      ));
}
