import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';

import '../core/calendar/zmanim.dart';
import '../data/city_directory.dart';
import 'providers.dart';

/// The places a reader can choose for Shabbat times, loaded on first use.
final cityDirectoryProvider = FutureProvider<CityDirectory>((ref) => CityDirectory.load());

/// The device's IANA time zone, which suggests places to choose; null where
/// the platform doesn't say.
final deviceTimeZoneProvider = FutureProvider<String?>((ref) async {
  try {
    return (await FlutterTimezone.getLocalTimezone()).identifier;
  } catch (_) {
    return null;
  }
});

/// This week's Shabbat in the reader's city: Friday's times, for lighting
/// candles, and Shabbat's, for when it ends. Null until a city is chosen.
final shabbatTimesProvider = Provider<({Zmanim friday, Zmanim shabbat})?>((ref) {
  final city = ref.watch(settingsProvider.select((s) => s.city));
  if (city == null) return null;
  // The reading day is never Shabbat itself, so this is the coming Friday,
  // or today.
  final friday = ref.watch(todayProvider).onOrAfter(5);
  return (friday: Zmanim.of(city, friday), shabbat: Zmanim.of(city, friday.addDays(1)));
});
