import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shnayim_mikra/app/city_providers.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/core/calendar/city.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/data/city_directory.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/features/settings/screens/city_picker_screen.dart';
import 'package:shnayim_mikra/ui/widgets/paper_group.dart';

import '../../helpers.dart';

/// Tuesday of Noach 5787: this week's Shabbat is 16–17 October.
final _now = DateTime(2026, 10, 13, 10);

void main() {
  late CityDirectory directory;
  late City jerusalem;

  setUpAll(() {
    directory = CityDirectory.parse(File('assets/data/cities.json').readAsStringSync());
    jerusalem = directory.cities.firstWhere((c) => c.nameEn == 'Jerusalem');
  });

  Future<ProviderContainer> open(
    WidgetTester tester,
    String route, {
    City? city,
    String? timeZone,
    bool hebrew = false,
    bool loadForReal = false,
  }) async {
    final c = await pumpApp(
      tester,
      settings: AppSettings(
        onboardingComplete: true,
        joinDate: LocalDate(2026, 9, 1),
        city: city,
        language: hebrew ? AppLanguage.hebrew : AppLanguage.system,
      ),
      now: _now,
      overrides: <Override>[
        if (!loadForReal) cityDirectoryProvider.overrideWith((ref) => directory),
        deviceTimeZoneProvider.overrideWith((ref) => timeZone),
      ],
    );
    c.read(routerProvider).go(route);
    await tester.pumpAndSettle();
    return c;
  }

  /// The text [data], whatever spaces the time format puts before "PM".
  Finder text(String data) => find.byWidgetPredicate(
        (w) => w is Text && w.data?.replaceAll(RegExp('[\u00A0\u202F]'), ' ') == data,
      );

  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text).last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  group('Reading & customs', () {
    testWidgets('says no city is set, and opens the list of cities', (tester) async {
      await open(tester, '/settings/reading');
      expect(find.text('Shabbat times'), findsOneWidget);
      expect(find.text('Not set'), findsOneWidget);
      expect(find.textContaining('Candle-lighting'), findsNothing);

      await tapText(tester, 'City');
      expect(find.byType(CityPickerScreen), findsOneWidget);
    });

    testWidgets('shows the city and this week\'s Shabbat times there, on its own clock', (tester) async {
      await open(tester, '/settings/reading', city: jerusalem);
      expect(find.text('Jerusalem'), findsOneWidget);
      // Hebcal: candles 5:26 PM; Shabbat ends 6:41 PM (rounded up here).
      expect(text('Candle-lighting 5:26 PM\nShabbat ends 6:42 PM'), findsOneWidget);
    });

    testWidgets('in Hebrew, with the times isolated from the sentence around them', (tester) async {
      await open(tester, '/settings/reading', city: jerusalem, hebrew: true);
      expect(find.text('ירושלים'), findsOneWidget);
      expect(find.text('הדלקת נרות \u206617:26\u2069\nצאת השבת \u206618:42\u2069'), findsOneWidget);
    });
  });

  group('the list of cities', () {
    testWidgets('finds a city by name and chooses it', (tester) async {
      final c = await open(tester, '/settings/reading');
      await tapText(tester, 'City');
      await tester.enterText(find.byType(TextField), 'new york');
      await tester.pumpAndSettle();
      expect(find.text('New York City'), findsOneWidget);
      expect(find.text('New York, United States'), findsWidgets);

      await tapText(tester, 'New York City');

      expect(find.byType(CityPickerScreen), findsNothing);
      expect(c.read(settingsProvider).city?.nameEn, 'New York City');
      expect(find.text('New York City'), findsOneWidget);
      // Hebcal: 5:56 PM and 6:53 PM.
      expect(text('Candle-lighting 5:56 PM\nShabbat ends 6:54 PM'), findsOneWidget);
      // Saved, whole.
      final prefs = await SharedPreferences.getInstance();
      final saved = AppSettings.fromJson(
        jsonDecode(prefs.getString(SettingsController.storageKey)!) as Map<String, dynamic>,
      );
      expect(saved.city, c.read(settingsProvider).city);
    });

    testWidgets('finds a city by its Hebrew name', (tester) async {
      await open(tester, '/settings/reading/city', hebrew: true);
      await tester.enterText(find.byType(TextField), 'בני ברק');
      await tester.pumpAndSettle();
      expect(find.text('בני ברק'), findsWidgets);
      expect(find.text('ישראל'), findsWidgets);
    });

    testWidgets('suggests the cities in the device\'s time zone, with the chosen one first', (tester) async {
      final semantics = tester.ensureSemantics();
      await open(tester, '/settings/reading/city', city: jerusalem, timeZone: 'Asia/Jerusalem');
      expect(find.text('Your city'), findsOneWidget);
      expect(find.text('In your time zone'), findsOneWidget);
      expect(find.text('Tel Aviv'), findsOneWidget);
      // Jerusalem is chosen, so it is listed once, at the top, as selected.
      expect(find.text('Jerusalem'), findsOneWidget);
      expect(
        tester.getSemantics(find.ancestor(of: find.text('Jerusalem'), matching: find.byType(PaperRow))),
        isSemantics(label: 'Jerusalem\nIsrael\nSelected', isButton: true, hasTapAction: true),
      );
      semantics.dispose();
    });

    testWidgets('suggests nothing when the device doesn\'t say its time zone', (tester) async {
      await open(tester, '/settings/reading/city');
      expect(find.text('In your time zone'), findsNothing);
      expect(find.textContaining('every place of 100,000 people'), findsOneWidget);
    });

    testWidgets('can go back to no city', (tester) async {
      final c = await open(tester, '/settings/reading', city: jerusalem);
      await tapText(tester, 'City');
      await tapText(tester, 'No city');
      expect(c.read(settingsProvider).city, isNull);
      expect(find.text('Not set'), findsOneWidget);
    });

    testWidgets('says when nothing matches', (tester) async {
      await open(tester, '/settings/reading/city');
      await tester.enterText(find.byType(TextField), 'Atlantis');
      await tester.pumpAndSettle();
      // The query is isolated, so its own direction holds in a Hebrew sentence.
      expect(find.text('No city matches “\u2068Atlantis\u2069”.'), findsOneWidget);

      await tester.tap(find.byTooltip('Clear search'));
      await tester.pumpAndSettle();
      expect(find.textContaining('No city matches'), findsNothing);
    });

    testWidgets('loads the list from the app\'s assets', (tester) async {
      await open(tester, '/settings/reading/city', loadForReal: true, timeZone: 'Asia/Jerusalem');
      for (var i = 0; i < 100 && find.text('Jerusalem').evaluate().isEmpty; i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
      }
      expect(find.text('Jerusalem'), findsOneWidget);
    });
  });
}
