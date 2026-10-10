import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  City named(String name) => directory.cities.firstWhere((c) => c.nameEn == name);

  Future<ProviderContainer> open(
    WidgetTester tester,
    String route, {
    City? city,
    String? timeZone,
    bool hebrew = false,
    bool loadForReal = false,
    DateTime? now,
  }) async {
    final c = await pumpApp(
      tester,
      settings: AppSettings(
        onboardingComplete: true,
        joinDate: LocalDate(2026, 9, 1),
        city: city,
        language: hebrew ? AppLanguage.hebrew : AppLanguage.system,
      ),
      now: now ?? _now,
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

    // Far north in summer the sky never gets dark enough for Shabbat to end.
    testWidgets('gives only candle-lighting where Shabbat has no nightfall', (tester) async {
      await open(tester, '/settings/reading', city: named('Stockholm'), now: DateTime(2026, 6, 16, 10));
      final summary = find.textContaining('Candle-lighting');
      expect(summary, findsOneWidget);
      expect(tester.widget<Text>(summary).data, startsWith('Candle-lighting '));
      expect(tester.widget<Text>(summary).data, isNot(contains('\n')));
    });

    // In the polar night the sun neither sets nor rises.
    testWidgets('says when there is no sunset at all', (tester) async {
      await open(tester, '/settings/reading', city: named('Murmansk'), now: DateTime(2026, 12, 15, 10));
      expect(find.text('There is no sunset there this Shabbat. Ask your rav about the times.'), findsOneWidget);
      expect(find.textContaining('Candle-lighting'), findsNothing);
    });

    testWidgets("says so when the device doesn't know the city's time zone", (tester) async {
      const nowhere = City(
        id: 1,
        nameEn: 'Nowhere',
        countryCode: 'IL',
        latitude: 31.8,
        longitude: 35.2,
        timeZone: 'Mars/Olympus_Mons',
      );
      await open(tester, '/settings/reading', city: nowhere);
      expect(find.text("This device can't tell the time in that city, so its times can't be shown."), findsOneWidget);
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
      await c.read(settingsProvider.notifier).flush();
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

    for (final hebrew in [false, true]) {
      testWidgets('types a Latin name left to right and a Hebrew one right to left${hebrew ? ', in Hebrew' : ''}',
          (tester) async {
        await open(tester, '/settings/reading/city', hebrew: hebrew);
        TextDirection? direction() => tester.widget<TextField>(find.byType(TextField)).textDirection;
        expect(direction(), isNull, reason: "the page's own while empty");
        await tester.enterText(find.byType(TextField), 'York');
        await tester.pump();
        expect(direction(), TextDirection.ltr);
        await tester.enterText(find.byType(TextField), 'בני ברק');
        await tester.pump();
        expect(direction(), TextDirection.rtl);
      });
    }

    testWidgets('suggests the cities in the device\'s time zone, with the chosen one first', (tester) async {
      final semantics = tester.ensureSemantics();
      await open(tester, '/settings/reading/city', city: jerusalem, timeZone: 'Asia/Jerusalem');
      expect(find.text('Your city'), findsOneWidget);
      expect(find.text('In your time zone'), findsOneWidget);
      expect(find.text('Tel Aviv'), findsOneWidget);
      // Jerusalem is chosen, so it is listed once, at the top, as selected.
      expect(find.text('Jerusalem'), findsOneWidget);
      final row = find.ancestor(of: find.text('Jerusalem'), matching: find.byType(PaperRow));
      expect(
        tester.getSemantics(row),
        isSemantics(label: 'Jerusalem\nIsrael', isButton: true, hasTapAction: true, hasSelectedState: true, isSelected: true),
      );
      expect(
        tester.getSemantics(find.ancestor(of: find.text('Tel Aviv'), matching: find.byType(PaperRow))),
        isSemantics(label: 'Tel Aviv\nIsrael', isButton: true, hasTapAction: true, hasSelectedState: true, isSelected: false),
      );
      // Every row, the check and No city among them, is a target of its own.
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    });

    for (final hebrew in [false, true]) {
      testWidgets('search results are targets of their own${hebrew ? ', in Hebrew' : ''}', (tester) async {
        final semantics = tester.ensureSemantics();
        await open(tester, '/settings/reading/city', city: jerusalem, hebrew: hebrew);
        await tester.enterText(find.byType(TextField), hebrew ? 'קרית' : 'kiryat');
        await tester.pumpAndSettle();
        expect(find.byType(PaperRow), findsAtLeastNWidgets(3));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(iOSTapTargetGuideline));
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        semantics.dispose();
      });
    }

    // ו and י are left out of Hebrew search, so the first letter of ירושלים
    // is no search at all yet.
    testWidgets('treats a lone י as no search yet', (tester) async {
      await open(tester, '/settings/reading/city', city: jerusalem, timeZone: 'Asia/Jerusalem', hebrew: true);
      await tester.enterText(find.byType(TextField), 'י');
      await tester.pumpAndSettle();
      expect(find.textContaining('לא נמצאה עיר'), findsNothing);
      expect(find.text('העיר שלך'), findsOneWidget);
    });

    testWidgets('finds the usual Hebrew spellings, with or without א', (tester) async {
      await open(tester, '/settings/reading/city', hebrew: true);
      for (final (query, city) in [('שאנגחאי', 'שאנגחאי'), ('פאריז', 'פריז'), ('שיקאגו', 'שיקגו')]) {
        await tester.enterText(find.byType(TextField), query);
        await tester.pumpAndSettle();
        expect(find.descendant(of: find.byType(PaperRow), matching: find.text(city)), findsWidgets, reason: query);
      }
    });

    testWidgets('says when a search finds more than it lists, and how many it found', (tester) async {
      final announced = <String>[];
      tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler<dynamic>(SystemChannels.accessibility, (m) async {
        final data = (m as Map)['data'] as Map;
        if (data['message'] case final String message) announced.add(message);
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger.setMockDecodedMessageHandler(SystemChannels.accessibility, null));
      await open(tester, '/settings/reading/city');
      await tester.enterText(find.byType(TextField), 'an');
      await tester.pumpAndSettle();
      final all = directory.count('an');
      expect(all, greaterThan(50));
      expect(find.byType(PaperRow), findsNWidgets(50));
      await tester.scrollUntilVisible(
        find.textContaining('The first 50 of $all matches'),
        500,
        scrollable: find.ancestor(of: find.byType(PaperGroup), matching: find.byType(Scrollable)).first,
      );
      expect(find.text('The first 50 of $all matches are listed. Type more of the name to find the others.'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(announced, ['$all cities found']);
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
