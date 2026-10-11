import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/config.dart';
import '../../../app/providers.dart';
import '../../../services/notifications.dart';
import '../../../services/reminder_planner.dart';
import '../../../ui/l10n.dart';
import '../../../ui/theme/app_theme.dart';
import '../../../ui/widgets/common.dart';
import '../../../ui/widgets/paper_group.dart';
import '../../../ui/widgets/progress_widgets.dart' show ShabbatCandlesIcon;
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

/// Whether Reminders offers the list of cities under [s]: while any reminder
/// is on without a city, until the offer is answered.
bool _offersCity(AppSettings s) => anyReminderOn(s) && s.city == null && !s.cityOfferAnswered;

/// The reminders, in Settings: a sheet of paper for each, under a note that
/// none comes on Shabbat or Yom Tov. With a city chosen for Shabbat times
/// they follow its times. While any is on without one, however it was turned
/// on, the list of cities is offered until the offer is answered. Where
/// reminders can't be sent (the web), one notice says they need the
/// installed app, over the reminders it would send, disabled.
class ReminderSettingsScreen extends ConsumerStatefulWidget {
  const ReminderSettingsScreen({super.key});

  /// The list of cities, opened from here.
  static const cityRoute = '/settings/reminders/city';

  @override
  ConsumerState<ReminderSettingsScreen> createState() => _ReminderSettingsScreenState();
}

class _ReminderSettingsScreenState extends ConsumerState<ReminderSettingsScreen> {
  final _offerKey = GlobalKey();

  /// Whether the offer of a city was made by turning a reminder on here:
  /// then it is announced, but not when the page opens with it.
  bool _offerMade = false;

  /// Whether choosing a routine has moved the daily reminder's time here:
  /// from then on the time is read out as it changes.
  bool _timeMoved = false;

  /// Scrolls the offer of a city, just made, into view if it is below the
  /// screen, as it is at large text sizes once the daily reminder's rows
  /// open above it: its end to the screen's end or, when it is taller than
  /// the screen, its start to the screen's start, to be read from there.
  /// Where it already shows, nothing moves.
  void _revealOffer() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final offer = _offerKey.currentContext;
      if (!mounted || offer == null || !offer.mounted) return;
      final banner = offer.findRenderObject();
      final screen = Scrollable.maybeOf(offer)?.context.findRenderObject();
      if (banner is! RenderBox || screen is! RenderBox) return;
      final tall = banner.size.height > screen.size.height;
      Scrollable.ensureVisible(
        offer,
        duration: Motion.of(context).d(Motion.medium),
        curve: Motion.standard,
        alignmentPolicy: tall ? ScrollPositionAlignmentPolicy.explicit : ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final names = Names(context);
    final s = ref.watch(settingsProvider);
    final service = ref.watch(notificationServiceProvider);
    void update(AppSettings Function(AppSettings) f) => ref.read(settingsProvider.notifier).update(f);
    final city = s.city?.name(hebrew: context.isHebrewUi);
    // Without a city, the Erev Shabbat reminder comes before midday,
    // whatever time was chosen while there was one.
    final fridayMinutes = city == null
        ? math.min(s.fridayReminderMinutes, kErevShabbatLatestMinutes)
        : s.fridayReminderMinutes;
    // The routines' prompt reads as a subtitle does (DESIGN_SYSTEM.md §6.3),
    // rather than in small print.
    final theme = Theme.of(context);
    final secondary = theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    // Where reminders can't be sent (the web), they show what they would do,
    // disabled.
    final supported = service.supported;

    Future<void> enable(AppSettings Function(AppSettings) f) async {
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
      final offered = _offersCity(ref.read(settingsProvider));
      update((s) => f(s).copyWith(notificationPromptShown: true));
      if (!offered && _offersCity(ref.read(settingsProvider)) && mounted) {
        setState(() => _offerMade = true);
        _revealOffer();
      }
    }

    Future<void> pickTime(int current, void Function(int) onPicked) async {
      final minutes = await pickReminderTime(context, current);
      if (minutes != null) onPicked(minutes);
    }

    return SettingsPage(
      title: l.settingsReminders,
      paper: true,
      children: [
        if (supported)
          NoticeBanner(
            leading: const ShabbatCandlesIcon(size: 20),
            // A name in either script keeps its own direction in the sentence.
            text: city == null ? l.remindersShabbatNote : l.remindersShabbatNoteCity('\u2068$city\u2069'),
          )
        else
          NoticeBanner(
            icon: Icons.install_mobile,
            text: l.notificationsUnsupported,
            actionBelow: AppConfig.installUrl.isNotEmpty,
            action: AppConfig.installUrl.isEmpty
                ? null
                : TextButton(
                    onPressed: () => launchUrl(Uri.parse(AppConfig.installUrl)),
                    child: Text(l.getTheApp),
                  ),
          ),
        const Gap(Space.lg),
        // A sheet for each reminder: its switch, and once it is on, when it
        // comes. Where reminders can't be sent, each is off, whatever a
        // backup from a phone brought with it.
        PaperGroup(
          children: [
            SwitchRow(
              title: l.dailyReminder,
              subtitle: city == null ? l.dailyReminderDesc : l.dailyReminderDescCity,
              value: supported && s.dailyReminder,
              onChanged: !supported
                  ? null
                  : (v) => v ? enable((s) => s.copyWith(dailyReminder: true)) : update((s) => s.copyWith(dailyReminder: false)),
            ),
            if (supported && s.dailyReminder) ...[
              PaperRow(
                title: l.dailyReminderTime,
                value: names.time(s.dailyReminderMinutes),
                liveRegion: _timeMoved,
                onTap: () => pickTime(s.dailyReminderMinutes, (m) => update((s) => s.copyWith(dailyReminderMinutes: m))),
              ),
              Padding(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l.habitAnchorPrompt, style: secondary),
                    const Gap(8),
                    HabitAnchorChips(
                      selected: s.habitAnchor,
                      // A time that is still only a suggestion follows the
                      // routine, so that the reminder never names a morning
                      // routine in the evening.
                      onChanged: (a) {
                        final minutes =
                            HabitAnchor.reminderMinutes(s.dailyReminderMinutes, previous: s.habitAnchor, next: a);
                        if (minutes != s.dailyReminderMinutes) setState(() => _timeMoved = true);
                        update((s) => s.copyWith(habitAnchor: a, dailyReminderMinutes: minutes));
                      },
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        const Gap(Rhythm.cardGap),
        PaperGroup(
          children: [
            SwitchRow(
              title: l.fridayReminder,
              subtitle: city == null ? l.fridayReminderDesc : l.fridayReminderDescCity,
              value: supported && s.fridayReminder,
              onChanged: !supported
                  ? null
                  : (v) =>
                      v ? enable((s) => s.copyWith(fridayReminder: true)) : update((s) => s.copyWith(fridayReminder: false)),
            ),
            if (supported && s.fridayReminder)
              PaperRow(
                title: l.fridayReminderTime,
                value: names.time(fridayMinutes),
                // With a city, any time: the reminder comes three hours before
                // candle-lighting at the latest.
                onTap: () => pickTime(
                  fridayMinutes,
                  (m) => update((s) => s.copyWith(
                      fridayReminderMinutes: s.city == null ? math.min(m, kErevShabbatLatestMinutes) : m)),
                ),
              ),
          ],
        ),
        const Gap(Rhythm.cardGap),
        PaperGroup(
          children: [
            SwitchRow(
              title: l.checkInReminder,
              subtitle: city == null ? l.checkInReminderDesc : l.checkInReminderDescCity,
              value: supported && s.checkInReminder,
              onChanged: !supported
                  ? null
                  : (v) => v
                      ? enable((s) => s.copyWith(checkInReminder: true))
                      : update((s) => s.copyWith(checkInReminder: false)),
            ),
          ],
        ),
        // Below the switches, so that nothing moves under the one tapped.
        if (supported && _offersCity(s))
          Padding(
            padding: const EdgeInsets.only(top: Rhythm.sectionGap),
            child: NoticeBanner(
              key: _offerKey,
              icon: Icons.place_outlined,
              text: l.reminderCityOffer,
              actionBelow: true,
              liveRegion: _offerMade,
              // Stacked at large text sizes, the main action comes
              // first, as in a dialog.
              action: OverflowBar(
                alignment: MainAxisAlignment.end,
                spacing: 8,
                overflowAlignment: OverflowBarAlignment.end,
                overflowDirection: VerticalDirection.up,
                children: [
                  TextButton(
                    onPressed: () => update((s) => s.copyWith(cityOfferAnswered: true)),
                    child: Text(l.actionNotNow),
                  ),
                  TextButton(
                    onPressed: () => context.push(ReminderSettingsScreen.cityRoute),
                    child: Text(l.reminderCityChoose),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
