import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/providers.dart';
import '../../services/feedback.dart';
import '../../services/notifications.dart';
import '../../ui/l10n.dart';
import '../../ui/widgets/common.dart';
import '../settings/app_settings.dart';
import '../settings/screens/reminder_settings_screen.dart';
import '../settings/widgets/habit_anchor_chips.dart';

/// After the first aliyah: celebrate, and — only now, never on first launch —
/// offer a gentle daily reminder before the OS permission prompt. The offer
/// asks after which routine the reader will read, and when to remind them;
/// saying yes keeps both. The time follows the routine chosen until the
/// reader picks one. Once reminders are on without a city for Shabbat
/// times, a status message offers the list of cities, as Reminders does.
Future<void> maybeOfferReminders(BuildContext context, WidgetRef ref, {required String celebration}) async {
  final l = context.l10n;
  final service = ref.read(notificationServiceProvider);
  final settings = ref.read(settingsProvider);
  ref.read(settingsProvider.notifier).update((s) => s.copyWith(notificationPromptShown: true));
  var anchor = settings.habitAnchor;
  var minutes = settings.dailyReminderMinutes;
  var timePicked = false;
  var timeMoved = false;

  final yes = await showAppDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      // The routines and the time may not fit at large text sizes.
      scrollable: true,
      icon: const Icon(Icons.notifications_outlined),
      title: Text(celebration),
      content: service.supported
          ? StatefulBuilder(
              builder: (context, setState) => Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.primingTitle, style: Theme.of(context).textTheme.titleMedium),
                  const Gap(4),
                  Text(l.primingBody),
                  const Gap(16),
                  HabitAnchorChips(
                    selected: anchor,
                    onChanged: (a) => setState(() {
                      final moved = timePicked ? minutes : HabitAnchor.reminderMinutes(minutes, previous: anchor, next: a);
                      timeMoved |= moved != minutes;
                      minutes = moved;
                      anchor = a;
                    }),
                  ),
                  const Gap(8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule),
                    // Read out once choosing a routine has changed it.
                    title: Semantics(
                      liveRegion: timeMoved,
                      child: Text(l.reminderAtTime(context.ltrRun(Names(context).time(minutes)))),
                    ),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: () async {
                      final picked = await pickReminderTime(context, minutes);
                      if (picked != null && context.mounted) {
                        setState(() {
                          minutes = picked;
                          timePicked = true;
                        });
                      }
                    },
                  ),
                ],
              ),
            )
          : null,
      // Stacked at large text sizes, the main action comes first.
      actionsOverflowDirection: VerticalDirection.up,
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
  // The routine and the time are kept even if the OS refuses, for when the
  // reader turns reminders on in Settings.
  ref.read(settingsProvider.notifier).update((s) => s.copyWith(
        habitAnchor: anchor,
        dailyReminderMinutes: minutes,
        dailyReminder: granted,
        fridayReminder: granted,
        checkInReminder: granted,
      ));
  // Without a city, reminders keep to the cautious rule of midday on Friday.
  final saved = ref.read(settingsProvider);
  if (granted && saved.city == null && !saved.cityOfferAnswered && context.mounted) {
    final router = GoRouter.of(context);
    showStatus(
      context,
      l.remindersOnCityOffer,
      action: SnackBarAction(label: l.reminderCityChoose, onPressed: () => router.push('/city')),
    );
  }
}
