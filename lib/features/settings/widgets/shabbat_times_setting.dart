import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:timezone/timezone.dart' as tz;

import '../../../app/city_providers.dart';
import '../../../app/providers.dart';
import '../../../core/calendar/zmanim.dart';
import '../../../ui/l10n.dart';
import '../../../ui/widgets/common.dart';
import '../../../ui/widgets/paper_group.dart';

/// The city for Shabbat times, in Settings → Reading & customs: the city,
/// and this week's candle-lighting and the end of Shabbat there. It opens
/// the list of cities.
class ShabbatTimesSetting extends ConsumerWidget {
  const ShabbatTimesSetting({super.key});

  static const route = '/settings/reading/city';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final city = ref.watch(settingsProvider.select((s) => s.city));
    final times = ref.watch(shabbatTimesProvider);
    // Loads the list, off the UI's isolate, and keeps it while the page is
    // open, so that the list of cities opens at once.
    ref.listen(cityDirectoryProvider, (_, _) {});
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionHeader(
          l.shabbatTimesLabel,
          level: 3,
          padding: const EdgeInsetsDirectional.only(top: 16, bottom: 4, start: 16, end: 16),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Text(l.shabbatTimesHelp, style: Theme.of(context).textTheme.bodySmall),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: PaperGroup(
            children: [
              PaperRow(
                icon: Icons.place_outlined,
                title: l.cityLabel,
                value: city?.name(hebrew: context.isHebrewUi) ?? l.cityNotSet,
                subtitle: times == null ? null : shabbatTimesSummary(context, times.friday, times.shabbat),
                onTap: () => context.push(route),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// "Candle-lighting 6:07 PM", and on a second line "Shabbat ends 7:05 PM",
/// from Friday's times and Shabbat's.
String shabbatTimesSummary(BuildContext context, Zmanim friday, Zmanim shabbat) {
  final l = context.l10n;
  if (!friday.timeZoneKnown) return l.shabbatTimesUnavailable;
  final candles = friday.candleLighting;
  // Near the poles: the midnight sun, or the polar night.
  if (candles == null) return l.shabbatNoSunset;
  final ends = shabbat.havdalah;
  return ends == null
      ? l.shabbatCandlesOnly(clockTime(context, candles))
      : l.shabbatTimesSummary(clockTime(context, candles), clockTime(context, ends));
}

/// [time] as the UI writes a time of day, on the clock of its own place. In
/// Hebrew it is isolated as a left-to-right run.
String clockTime(BuildContext context, tz.TZDateTime time) =>
    context.ltrRun(Names(context).time(time.hour * 60 + time.minute));
