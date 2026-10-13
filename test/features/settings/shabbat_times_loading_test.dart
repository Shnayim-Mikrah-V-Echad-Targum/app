import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikrah/app/city_providers.dart';
import 'package:shnayim_mikrah/app/router.dart';
import 'package:shnayim_mikrah/core/calendar/local_date.dart';
import 'package:shnayim_mikrah/core/calendar/tz_database.dart';
import 'package:shnayim_mikrah/data/city_directory.dart';
import 'package:shnayim_mikrah/features/settings/app_settings.dart';

import '../../helpers.dart';

// Reading & customs as it first shows after launch, before the time-zone
// database is in: in a file of its own, since nothing unloads the database
// once a test has loaded it.
void main() {
  testWidgets('Reading & customs shows the city alone until the time-zone database is in, then its times',
      (tester) async {
    final directory = CityDirectory.parse(File('assets/data/cities.json').readAsStringSync());
    final jerusalem = directory.cities.firstWhere((c) => c.nameEn == 'Jerusalem');
    final database = Completer<void>();
    final c = await pumpApp(
      tester,
      settings: AppSettings(onboardingComplete: true, joinDate: LocalDate(2026, 9, 1), city: jerusalem),
      // Tuesday of Noach 5787: this week's Shabbat is 16–17 October.
      now: DateTime(2026, 10, 13, 10),
      overrides: [
        cityDirectoryProvider.overrideWith((ref) => directory),
        timeZoneDatabaseProvider.overrideWith((ref) => database.future),
      ],
    );
    c.read(routerProvider).go('/settings/reading');
    await tester.pumpAndSettle();
    expect(timeZonesLoaded, isFalse);
    expect(find.text('Jerusalem'), findsOneWidget);
    expect(find.textContaining('Candle-lighting '), findsNothing);
    // Not that the device can't tell the time there, which it can.
    expect(find.textContaining('can’t tell the time'), findsNothing);

    await tester.runAsync(ensureTimeZones);
    database.complete();
    await tester.pumpAndSettle();
    // Hebcal: candles 5:26 PM; Shabbat ends 6:41 PM (rounded up here).
    expect(
      find.byWidgetPredicate((w) =>
          w is Text && w.data?.replaceAll(RegExp('[  ]'), ' ') == 'Candle-lighting 5:26 PM\nShabbat ends 6:42 PM'),
      findsOneWidget,
    );
  });
}
