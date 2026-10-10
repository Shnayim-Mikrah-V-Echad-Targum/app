import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../services/notifications.dart';
import '../../../services/reminder_planner.dart';
import '../../../ui/l10n.dart';
import '../../../ui/widgets/common.dart';
import '../app_settings.dart';
import '../widgets/habit_anchor_chips.dart';
import '../widgets/settings_widgets.dart';

/// Asks for a reminder's time of day, starting from [minutes] after
/// midnight, and returns the chosen one the same way, or null if the reader
/// cancels. It is showTimePicker's dialog, shown the app's way (instantly
/// under Reduce Motion), and typed rather than dialled.
Future<int?> pickReminderTime(BuildContext context, int minutes) async {
  final time = await showAppDialog<TimeOfDay>(
    context: context,
    builder: (_) => TimePickerDialog(
      initialTime: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
      initialEntryMode: TimePickerEntryMode.inputOnly,
    ),
  );
  return time == null ? null : time.hour * 60 + time.minute;
}

/// The reminders, in Settings. With a city chosen for Shabbat times they
/// follow its times, and turning the first of them on without one offers
/// the list of cities.
class ReminderSettingsScreen extends ConsumerStatefulWidget {
  const ReminderSettingsScreen({super.key});

  /// The list of cities, opened from here.
  static const cityRoute = '/settings/reminders/city';

  @override
  ConsumerState<ReminderSettingsScreen> createState() => _ReminderSettingsScreenState();
}

class _ReminderSettingsScreenState extends ConsumerState<ReminderSettingsScreen> {
  /// Whether to offer the list of cities: once the first reminder is turned
  /// on without a city, until one is chosen or the offer is put aside.
  bool _offerCity = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final names = Names(context);
    final s = ref.watch(settingsProvider);
    final service = ref.watch(notificationServiceProvider);
    void update(AppSettings Function(AppSettings) f) => ref.read(settingsProvider.notifier).update(f);
    final city = s.city?.name(hebrew: context.isHebrewUi);
    // Once a city is chosen, the offer is answered.
    ref.listen(settingsProvider.select((s) => s.city), (_, chosen) {
      if (chosen != null && _offerCity) setState(() => _offerCity = false);
    });
    // Without a city, the Erev Shabbat reminder comes before midday,
    // whatever time was chosen while there was one.
    final fridayMinutes = city == null
        ? math.min(s.fridayReminderMinutes, kErevShabbatLatestMinutes)
        : s.fridayReminderMinutes;

    Future<void> enable(AppSettings Function(AppSettings) f) async {
      final first = !anyReminderOn(ref.read(settingsProvider));
      final granted = await service.requestPermission();
      if (!granted) {
        if (context.mounted) {
          await showAppDialog<void>(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(l.notificationsDeniedTitle),
              content: Text(l.notificationsDenied),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: Text(l.actionOk)),
                // Where notifications once refused can be allowed again.
                if (service.canOpenSystemSettings)
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      service.openSystemSettings();
                    },
                    child: Text(l.openSystemSettings),
                  ),
              ],
            ),
          );
        }
        return;
      }
      update((s) => f(s).copyWith(notificationPromptShown: true));
      if (first && ref.read(settingsProvider).city == null && mounted) setState(() => _offerCity = true);
    }

    Future<void> pickTime(int current, void Function(int) onPicked) async {
      final minutes = await pickReminderTime(context, current);
      if (minutes != null) onPicked(minutes);
    }

    return SettingsPage(
      title: l.settingsReminders,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: NoticeBanner(
            icon: Icons.nights_stay_outlined,
            // A name in either script keeps its own direction in the sentence.
            text: city == null ? l.remindersShabbatNote : l.remindersShabbatNoteCity('\u2068$city\u2069'),
          ),
        ),
        if (!service.supported)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: NoticeBanner(icon: Icons.info_outline, text: l.notificationsUnsupported),
          )
        else ...[
          SwitchListTile(
            title: Text(l.dailyReminder),
            subtitle: Text(city == null ? l.dailyReminderDesc : l.dailyReminderDescCity),
            value: s.dailyReminder,
            onChanged: (v) => v ? enable((s) => s.copyWith(dailyReminder: true)) : update((s) => s.copyWith(dailyReminder: false)),
          ),
          if (s.dailyReminder) ...[
            ListTile(
              contentPadding: const EdgeInsetsDirectional.only(start: 32, end: 16),
              title: Text(l.dailyReminderTime),
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
                  HabitAnchorChips(
                    selected: s.habitAnchor,
                    onChanged: (a) => update((s) => s.copyWith(habitAnchor: a)),
                  ),
                ],
              ),
            ),
          ],
          SwitchListTile(
            title: Text(l.fridayReminder),
            subtitle: Text(city == null ? l.fridayReminderDesc : l.fridayReminderDescCity),
            value: s.fridayReminder,
            onChanged: (v) => v ? enable((s) => s.copyWith(fridayReminder: true)) : update((s) => s.copyWith(fridayReminder: false)),
          ),
          if (s.fridayReminder)
            ListTile(
              contentPadding: const EdgeInsetsDirectional.only(start: 32, end: 16),
              title: Text(l.fridayReminderTime),
              trailing: Text(names.time(fridayMinutes)),
              // With a city, any time: the reminder comes three hours before
              // candle-lighting at the latest.
              onTap: () => pickTime(
                fridayMinutes,
                (m) => update((s) => s.copyWith(
                    fridayReminderMinutes: s.city == null ? math.min(m, kErevShabbatLatestMinutes) : m)),
              ),
            ),
          SwitchListTile(
            title: Text(l.checkInReminder),
            subtitle: Text(city == null ? l.checkInReminderDesc : l.checkInReminderDescCity),
            value: s.checkInReminder,
            onChanged: (v) => v ? enable((s) => s.copyWith(checkInReminder: true)) : update((s) => s.copyWith(checkInReminder: false)),
          ),
          // Below the switches, so that nothing moves under the one tapped.
          if (_offerCity && city == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Semantics(
                liveRegion: true,
                child: NoticeBanner(
                  icon: Icons.place_outlined,
                  text: l.reminderCityOffer,
                  actionBelow: true,
                  // Stacked at large text sizes, the main action comes
                  // first, as in a dialog.
                  action: OverflowBar(
                    alignment: MainAxisAlignment.end,
                    spacing: 8,
                    overflowAlignment: OverflowBarAlignment.end,
                    overflowDirection: VerticalDirection.up,
                    children: [
                      TextButton(onPressed: () => setState(() => _offerCity = false), child: Text(l.actionNotNow)),
                      TextButton(
                        onPressed: () => context.push(ReminderSettingsScreen.cityRoute),
                        child: Text(l.reminderCityChoose),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ],
    );
  }
}
