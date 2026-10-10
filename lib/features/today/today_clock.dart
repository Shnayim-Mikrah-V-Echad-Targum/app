import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../core/calendar/local_date.dart';

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
