import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/providers.dart';
import '../../../services/notifications.dart';
import '../../../ui/l10n.dart';
import '../../../ui/widgets/common.dart';
import '../app_settings.dart';
import '../widgets/settings_widgets.dart';

class ReminderSettingsScreen extends ConsumerWidget {
  const ReminderSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final names = Names(context);
    final s = ref.watch(settingsProvider);
    final service = ref.watch(notificationServiceProvider);
    void update(AppSettings Function(AppSettings) f) => ref.read(settingsProvider.notifier).update(f);

    Future<void> enable(AppSettings Function(AppSettings) f) async {
      final granted = await service.requestPermission();
      if (!granted) {
        if (context.mounted) {
          await showDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              content: Text(l.notificationsDenied),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(l.actionOk))],
            ),
          );
        }
        return;
      }
      update((s) => f(s).copyWith(notificationPromptShown: true));
    }

    Future<void> pickTime(int current, void Function(int) onPicked) async {
      final t = await showTimePicker(
        context: context,
        initialTime: TimeOfDay(hour: current ~/ 60, minute: current % 60),
        initialEntryMode: TimePickerEntryMode.inputOnly,
      );
      if (t != null) onPicked(t.hour * 60 + t.minute);
    }

    final anchors = [l.anchorShacharit, l.anchorBreakfast, l.anchorCommute, l.anchorDinner, l.anchorBed];

    return SettingsPage(
      title: l.settingsReminders,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: NoticeBanner(icon: Icons.nights_stay_outlined, text: l.remindersShabbatNote),
        ),
        if (!service.supported)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: NoticeBanner(icon: Icons.info_outline, text: l.notificationsUnsupported),
          )
        else ...[
          SwitchListTile(
            title: Text(l.dailyReminder),
            subtitle: Text(l.dailyReminderDesc),
            value: s.dailyReminder,
            onChanged: (v) => v ? enable((s) => s.copyWith(dailyReminder: true)) : update((s) => s.copyWith(dailyReminder: false)),
          ),
          if (s.dailyReminder) ...[
            ListTile(
              contentPadding: const EdgeInsetsDirectional.only(start: 32, end: 16),
              title: Text(l.reminderTime),
              trailing: Text(names.time(s.dailyReminderMinutes)),
              onTap: () => pickTime(s.dailyReminderMinutes, (m) => update((s) => s.copyWith(dailyReminderMinutes: m))),
            ),
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 32, end: 16, bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.habitAnchorPrompt, style: Theme.of(context).textTheme.bodySmall),
                  const Gap(6),
                  Text(l.habitAnchorLabel, style: Theme.of(context).textTheme.titleSmall),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final a in anchors)
                        ChoiceChip(
                          label: Text(a),
                          selected: s.habitAnchor == a,
                          onSelected: (sel) => update((s) => s.copyWith(habitAnchor: sel ? a : null)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          SwitchListTile(
            title: Text(l.fridayReminder),
            subtitle: Text(l.fridayReminderDesc),
            value: s.fridayReminder,
            onChanged: (v) => v ? enable((s) => s.copyWith(fridayReminder: true)) : update((s) => s.copyWith(fridayReminder: false)),
          ),
          if (s.fridayReminder)
            ListTile(
              contentPadding: const EdgeInsetsDirectional.only(start: 32, end: 16),
              title: Text(l.reminderTime),
              trailing: Text(names.time(s.fridayReminderMinutes)),
              onTap: () => pickTime(s.fridayReminderMinutes, (m) => update((s) => s.copyWith(fridayReminderMinutes: m.clamp(0, 11 * 60 + 30)))),
            ),
          SwitchListTile(
            title: Text(l.checkInReminder),
            subtitle: Text(l.checkInReminderDesc),
            value: s.checkInReminder,
            onChanged: (v) => v ? enable((s) => s.copyWith(checkInReminder: true)) : update((s) => s.copyWith(checkInReminder: false)),
          ),
        ],
      ],
    );
  }
}
