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
    // Loads the list while the page is open, so that it opens at once.
    ref.watch(cityDirectoryProvider);
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
                onTap: () => context.go(route),
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
  final candles = friday.candleLighting;
  if (candles == null) return l.shabbatNoSunset;
  final ends = shabbat.havdalah;
  return ends == null
      ? l.shabbatCandlesOnly(clockTime(context, candles))
      : l.shabbatTimesSummary(clockTime(context, candles), clockTime(context, ends));
}

/// [time] as the UI writes a time of day, on the clock of its own place. In
/// Hebrew it is isolated as a left-to-right run.
String clockTime(BuildContext context, tz.TZDateTime time) {
  final text = Names(context).time(time.hour * 60 + time.minute);
  return context.isHebrewUi ? '\u2066$text\u2069' : text;
}
