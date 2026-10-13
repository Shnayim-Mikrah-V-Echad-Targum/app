import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/city_providers.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/core/calendar/tz_database.dart';
import 'package:shnayim_mikra/data/city_directory.dart';
import 'package:shnayim_mikra/ui/widgets/paper_group.dart';

import '../../helpers.dart';

/// The list of cities before the time-zone database is in: the app loads it
/// once the first frame is up, at idle priority, and on the web downloads it
/// first. Nothing in this file loads it before the last test, which does.
void main() {
  testWidgets('loads the list without waiting for the time-zone database', (tester) async {
    final c = await pumpApp(tester, overrides: [
      deviceTimeZoneProvider.overrideWith((ref) => 'Asia/Jerusalem'),
      // A database that never comes, as on the web offline before its part
      // was cached.
      timeZoneDatabaseProvider.overrideWith((ref) => Completer<void>().future),
    ]);
    c.read(routerProvider).go('/settings/reading/city');
    await tester.pumpAndSettle();
    for (var i = 0; i < 100 && find.widgetWithText(PaperRow, 'Jerusalem').evaluate().isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }
    // Suggested by the zone's name alone.
    expect(find.widgetWithText(PaperRow, 'Jerusalem'), findsOneWidget);
    expect(timeZonesLoaded, isFalse);
  });

  testWidgets('works before the time-zone database is in, and suggests by the clock once it is', (tester) async {
    expect(timeZonesLoaded, isFalse, reason: 'nothing in this file has loaded it');
    final directory = CityDirectory.parse(File('assets/data/cities.json').readAsStringSync());
    final database = Completer<void>();
    final c = await pumpApp(tester, overrides: [
      cityDirectoryProvider.overrideWith((ref) => directory),
      // An old name for New York's zone, which no place in the list uses.
      deviceTimeZoneProvider.overrideWith((ref) => 'US/Eastern'),
      timeZoneDatabaseProvider.overrideWith((ref) async {
        await database.future;
        await ensureTimeZones();
      }),
    ]);
    c.read(routerProvider).go('/settings/reading/city');
    await tester.pumpAndSettle();

    // Searching needs no time zones.
    await tester.enterText(find.byType(TextField), 'Jerusalem');
    await tester.pumpAndSettle();
    expect(find.widgetWithText(PaperRow, 'Jerusalem'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '');
    await tester.pumpAndSettle();
    // Nothing suggested yet: no place is in US/Eastern by name.
    expect(find.text('In your time zone'), findsNothing);
    expect(find.text('New York City'), findsNothing);

    database.complete();
    await tester.runAsync(() => Future<void>.delayed(Duration.zero));
    await tester.pumpAndSettle();
    expect(timeZonesLoaded, isTrue);
    expect(find.text('In your time zone'), findsOneWidget);
    expect(find.text('New York City'), findsOneWidget);
  });
}
