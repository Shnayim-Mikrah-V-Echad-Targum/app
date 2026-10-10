import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/city_providers.dart';
import '../../app/providers.dart';
import '../../core/calendar/jewish_holidays.dart';
import '../../core/calendar/local_date.dart';
import '../../core/calendar/zmanim.dart';

/// Whether the reading day has reached midday on the device's clock: from
/// then on a Friday is Erev Shabbat proper. It turns at noon, and is checked
/// again whenever the app resumes, as the reading day is.
class MiddayController extends Notifier<bool> {
  Timer? _timer;
  AppLifecycleListener? _lifecycle;

  @override
  bool build() {
    final today = ref.watch(todayProvider);
    _lifecycle ??= AppLifecycleListener(onResume: _refresh);
    ref.onDispose(() {
      _timer?.cancel();
      _lifecycle?.dispose();
      _lifecycle = null;
    });
    return _check(today);
  }

  /// Whether [today] has passed midday, setting a timer for midday if not.
  bool _check(LocalDate today) {
    _timer?.cancel();
    final now = TodayController.now();
    final noon = DateTime(today.year, today.month, today.day, 12);
    final past = !now.isBefore(noon);
    // Tests turn the timers off, as they do the reading day's.
    if (!past && TodayController.autoRollover) _timer = Timer(noon.difference(now), _refresh);
    return past;
  }

  void _refresh() {
    final past = _check(ref.read(todayProvider));
    if (past != state) state = past;
  }
}

final pastMiddayProvider = NotifierProvider<MiddayController, bool>(MiddayController.new);

/// The Shabbat or Yom Tov under way, by the reader's days of Yom Tov, until
/// it ends; null on any other day. The reading day ([todayProvider]) is
/// never one, so Today rests by this instead (docs/DESIGN_SYSTEM.md §9
/// Today, 8).
///
/// The day is the device's date, which turns at 3 a.m. as the reading day
/// does. With a city chosen for Shabbat times, on a day the device keeps the
/// city's clock, the last day of rest ends at nightfall there instead
/// ([Zmanim.havdalah]): Motzaei Shabbat is for logging what was read, as the
/// check-in reminder that comes then expects. Without one, nothing says when
/// Shabbat ends, and it lasts until 3 a.m., as the reminders without a city
/// wait for the morning.
class RestDayController extends Notifier<LocalDate?> {
  Timer? _timer;
  AppLifecycleListener? _lifecycle;

  @override
  LocalDate? build() {
    // Again as the reading day turns, or the app resumes.
    ref.watch(todayProvider);
    final (oneDayYomTov, city) = ref.watch(settingsProvider.select((s) => (s.oneDayYomTov, s.city)));
    final clock = ref.watch(deviceClockProvider);
    final citysTimes = city != null && timeZonesReady(ref);
    _lifecycle ??= AppLifecycleListener(onResume: ref.invalidateSelf);
    ref.onDispose(() {
      _timer?.cancel();
      _lifecycle?.dispose();
      _lifecycle = null;
    });

    final now = TodayController.now();
    final date = rolloverDate(now);
    // The day turns at 3 a.m. (five seconds after, as the reading day's).
    var next = DateTime(now.year, now.month, now.day, 3, 0, 5);
    if (!next.isAfter(now)) next = next.add(const Duration(days: 1));
    LocalDate? rest;
    if (JewishHolidays.isRestDay(date, israel: oneDayYomTov)) {
      rest = date;
      final last = !JewishHolidays.isRestDay(date.addDays(1), israel: oneDayYomTov);
      if (last && citysTimes && Zmanim.keepsClock(city, date, clock(date))) {
        final times = Zmanim.of(city, date);
        if (times.minutesOf(times.havdalah) case final minutes?) {
          // On the device's clock, which is the city's.
          final nightfall = DateTime(date.year, date.month, date.day, 0, minutes);
          if (!now.isBefore(nightfall)) {
            rest = null;
          } else if (nightfall.isBefore(next)) {
            next = nightfall;
          }
        }
      }
    }
    // Tests turn the timers off, as they do the reading day's.
    if (TodayController.autoRollover) _timer = Timer(next.difference(now), ref.invalidateSelf);
    return rest;
  }

  @override
  bool updateShouldNotify(LocalDate? previous, LocalDate? next) => previous != next;
}

final restDayProvider = NotifierProvider<RestDayController, LocalDate?>(RestDayController.new);
