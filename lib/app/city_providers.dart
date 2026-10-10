import 'package:flutter/scheduler.dart' show Priority, SchedulerBinding;
import 'package:flutter/widgets.dart' show WidgetsBinding;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../core/calendar/jewish_holidays.dart';
import '../core/calendar/local_date.dart';
import '../core/calendar/zmanim.dart';
import '../data/city_directory.dart';
import 'providers.dart';

/// The places a reader can choose for Shabbat times, loaded on first use and
/// kept while a page that uses them is open (Reading & customs, or the list
/// of cities).
final cityDirectoryProvider = FutureProvider.autoDispose<CityDirectory>((ref) => CityDirectory.load());

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

/// The time-zone database, which a city's times need, for what works them
/// out at launch (Today, the reminders): loaded once the first frame is up
/// and nothing is animating, as the notification service loads it, since
/// decoding it blocks the UI for a while. Otherwise the first page to show a
/// city's times loads it at once.
final timeZoneDatabaseProvider = FutureProvider<void>((ref) async {
  if (tz.timeZoneDatabase.isInitialized) return;
  await WidgetsBinding.instance.waitUntilFirstFrameRasterized;
  if (!tz.timeZoneDatabase.isInitialized) {
    await SchedulerBinding.instance.scheduleTask(tzdata.initializeTimeZones, Priority.idle);
  }
});

/// Whether a city's times can be worked out without holding up a frame,
/// watching [timeZoneDatabaseProvider] until they can.
bool timeZonesReady(Ref ref) => tz.timeZoneDatabase.isInitialized || ref.watch(timeZoneDatabaseProvider).hasValue;

/// The device clock's offset from UTC at noon on a day, which tells whether
/// it keeps the reader's city's clock that day (see [Zmanim.keepsClock]).
/// Tests, whose clock is UTC, put a city's clock in its place.
final deviceClockProvider = Provider<Duration Function(LocalDate date)>((ref) => deviceNoonOffset);

/// Candle-lighting today in the reader's city, for Today, when today is the
/// eve of Shabbat or Yom Tov by the reader's own days of Yom Tov. Null on
/// other days, without a city, where it can't be given (the sun doesn't
/// set), and until the time-zone database is in. Null too when the device
/// doesn't keep the city's clock that day, as for a traveller who has left
/// the city behind: the line doesn't name the city, and its time there
/// would read as the local one. The reminders then keep to their rules
/// without a city, for the same reason.
final candleLightingTodayProvider = Provider<tz.TZDateTime?>((ref) {
  final city = ref.watch(settingsProvider.select((s) => s.city));
  if (city == null) return null;
  final oneDayYomTov = ref.watch(settingsProvider.select((s) => s.oneDayYomTov));
  // The reading day is never Shabbat or Yom Tov itself.
  final today = ref.watch(todayProvider);
  if (!JewishHolidays.isRestDay(today.addDays(1), israel: oneDayYomTov)) return null;
  if (!timeZonesReady(ref)) return null;
  if (!Zmanim.keepsClock(city, today, ref.watch(deviceClockProvider)(today))) return null;
  return Zmanim.of(city, today).candleLighting;
});
