import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../app/city_providers.dart';
import '../../../app/providers.dart';
import '../../../core/calendar/zmanim.dart';
import '../../../l10n/app_localizations.dart';
import '../../../ui/l10n.dart';
import '../../../ui/widgets/paper_group.dart';
import 'settings_widgets.dart';

/// The city for Shabbat times, in Settings → Reading & customs: a setting of
/// its section (a level-3 heading), with the city and this week's
/// candle-lighting and the end of Shabbat there. It opens the list of
/// cities. Once a city is chosen, two rows under it set the times as the
/// reader's luach has them: how long before sunset candles are lit, and
/// when Shabbat ends, each chosen in a sheet.
class ShabbatTimesSetting extends ConsumerWidget {
  const ShabbatTimesSetting({super.key});

  static const route = '/settings/reading/city';

  /// The minutes before sunset offered for candle-lighting, besides the
  /// city's own: those most luachs use.
  static const candleMinuteChoices = [15, 18, 20, 22, 30, 40];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final place = ref.watch(settingsProvider.select((s) => s.shabbatCity));
    final times = ref.watch(shabbatTimesProvider);
    // Loads the list, off the UI's isolate, and keeps it while the page is
    // open, so that the list of cities opens at once.
    ref.listen(cityDirectoryProvider, (_, _) {});
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingHeading(l.shabbatTimesLabel, help: l.shabbatTimesHelp, level: 3),
        PaperGroup(
          children: [
            PaperRow(
              icon: Icons.place_outlined,
              title: l.cityLabel,
              value: place?.city.name(hebrew: context.isHebrewUi) ?? l.cityNotSet,
              subtitle: times == null
                  ? null
                  : shabbatTimesSummary(context, times.friday, times.shabbat, yomTovFollows: times.yomTovFollows),
              onTap: () => context.push(route),
            ),
            // Each choice under its title, in full: as a value at the end of
            // the title's line, one would fit there and the other not.
            if (place != null) ...[
              PaperRow(
                icon: Icons.wb_twilight_outlined,
                title: l.candleLightingSetting,
                subtitle: candleMinutesLabel(l, place),
                subtitleMaxLines: null,
                onTap: () => _chooseCandleMinutes(context, ref, place),
              ),
              PaperRow(
                icon: Icons.bedtime_outlined,
                title: l.shabbatEndsSetting,
                subtitle: havdalahLabel(l, place.havdalah),
                subtitleMaxLines: null,
                onTap: () => _chooseHavdalah(context, ref, place),
              ),
            ],
          ],
        ),
      ],
    );
  }

  /// How long before sunset candles are lit: the city's own minutes, or
  /// those the reader's luach gives (one of [candleMinuteChoices], or any
  /// other a backup brought, listed among them).
  static Future<void> _chooseCandleMinutes(BuildContext context, WidgetRef ref, ShabbatCity place) {
    final l = context.l10n;
    final chosen = place.candleMinutes;
    final minutes = {...candleMinuteChoices, ?chosen}.toList()..sort();
    return showChoiceSheet<int?>(
      context: context,
      title: l.candleLightingSetting,
      value: chosen,
      choices: [
        Choice(null, l.candleMinutesCityDefault(place.city.candleMinutes)),
        for (final m in minutes) Choice(m, l.candleMinutesBeforeSunset(m)),
      ],
      onChanged: (m) => ref.read(settingsProvider.notifier).update((s) => s.copyWith(candleMinutesOverride: m)),
    );
  }

  /// When Shabbat ends: at nightfall, or a fixed time after sunset.
  static Future<void> _chooseHavdalah(BuildContext context, WidgetRef ref, ShabbatCity place) {
    final l = context.l10n;
    return showChoiceSheet<HavdalahRule>(
      context: context,
      title: l.shabbatEndsSetting,
      value: place.havdalah,
      choices: [for (final rule in HavdalahRule.values) Choice(rule, havdalahLabel(l, rule))],
      onChanged: (rule) => ref.read(settingsProvider.notifier).update((s) => s.copyWith(havdalah: rule)),
    );
  }
}

/// The candle-lighting minutes [place] follows, as its row and its sheet
/// name them: "City default (40 min)", or "22 minutes before sunset".
String candleMinutesLabel(AppLocalizations l, ShabbatCity place) => switch (place.candleMinutes) {
      null => l.candleMinutesCityDefault(place.city.candleMinutes),
      final minutes => l.candleMinutesBeforeSunset(minutes),
    };

/// [rule], as the row for the end of Shabbat and its sheet name it.
String havdalahLabel(AppLocalizations l, HavdalahRule rule) => switch (rule) {
      HavdalahRule.degrees85 => l.havdalahNightfall,
      HavdalahRule.min42 || HavdalahRule.min50 => l.havdalahMinutesAfterSunset(rule.minutes!),
      HavdalahRule.min72 => l.havdalahRabbeinuTam,
    };

/// "Candle-lighting 6:07 PM", and on a second line "Shabbat ends 7:05 PM",
/// from Friday's times and Shabbat's; or, where Yom Tov follows Shabbat
/// straight after ([yomTovFollows]), "Yom Tov candles after 7:05 PM", as its
/// candles are lit only once Shabbat ends.
String shabbatTimesSummary(BuildContext context, Zmanim friday, Zmanim shabbat, {bool yomTovFollows = false}) {
  final l = context.l10n;
  if (!friday.timeZoneKnown) return l.shabbatTimesUnavailable;
  final candles = friday.candleLighting;
  // Near the poles: the midnight sun, or the polar night.
  if (candles == null) return l.shabbatNoSunset;
  final ends = shabbat.havdalah;
  if (ends == null) return l.shabbatCandlesOnly(clockTime(context, candles));
  return yomTovFollows
      ? l.shabbatTimesSummaryYomTov(clockTime(context, candles), clockTime(context, ends))
      : l.shabbatTimesSummary(clockTime(context, candles), clockTime(context, ends));
}

/// [time] as the UI writes a time of day, on the clock of its own place. In
/// Hebrew it is isolated as a left-to-right run.
String clockTime(BuildContext context, tz.TZDateTime time) =>
    context.ltrRun(Names(context).time(time.hour * 60 + time.minute));
