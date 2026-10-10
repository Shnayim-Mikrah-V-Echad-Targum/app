import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/core/calendar/zmanim.dart';
import 'package:shnayim_mikra/data/city_directory.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late CityDirectory directory;
  late Map<String, dynamic> raw;

  setUpAll(() async {
    final json = await rootBundle.loadString('assets/data/cities.json');
    raw = jsonDecode(json) as Map<String, dynamic>;
    directory = CityDirectory.parse(json);
  });

  List<String> names(Iterable<dynamic> cities) => [for (final c in cities) c.nameEn as String];

  group('cities.json', () {
    test('every place of 100,000 people, once, in a time zone the device knows', () {
      final cities = directory.cities;
      expect(cities.length, greaterThan(6000));
      expect(cities.map((c) => c.id).toSet(), hasLength(cities.length));
      final zones = cities.map((c) => c.timeZone).toSet();
      expect([for (final z in zones) if (Zmanim.timeZone(z) == null) z], isEmpty);
      for (final c in cities) {
        expect(directory.placeOf(c, hebrew: false), isNotEmpty, reason: c.nameEn);
        expect(directory.placeOf(c, hebrew: true), isNotEmpty, reason: c.nameEn);
      }
    });

    test('says where it comes from', () {
      expect(raw['source'], contains('GeoNames'));
      expect(raw['source'], contains('CC BY 4.0'));
    });

    test('largest first', () {
      final order = names(directory.cities);
      expect(order.indexOf('New York City'), lessThan(order.indexOf('Philadelphia')));
      expect(order.indexOf('Jerusalem'), lessThan(order.indexOf('Tel Aviv')));
    });

    test('every Israeli city, named in Hebrew, on Israel time', () {
      final israel = directory.cities.where((c) => c.countryCode == 'IL').toList();
      expect(israel.length, greaterThan(120));
      for (final c in israel) {
        expect(c.nameHe, isNotNull, reason: c.nameEn);
        expect(c.timeZone, 'Asia/Jerusalem', reason: c.nameEn);
      }
      expect(
        names(israel),
        containsAll([
          'Jerusalem', 'Bnei Brak', 'Beit Shemesh', "Modi'in Illit", 'Beitar Illit', "Ma'ale Adumim", 'Elad',
          'Safed', 'Tiberias', 'Eilat', 'Nazareth', 'Rahat', 'Kfar Chabad', "Kiryat Ye'arim (Telz-Stone)",
        ]),
      );
      // Sections of a city aren't places of their own.
      expect(names(directory.cities), isNot(anyOf(contains('West Jerusalem'), contains('East Jerusalem'))));
    });

    // Their nearest place would otherwise be Hebron or Nablus, whose clock
    // differs from Israel's one Friday a year, and whose candles are lit 18
    // minutes before sunset rather than 20.
    test("Israeli localities beyond the Green Line, on Israel's time and custom", () {
      final israel = {for (final c in directory.cities.where((c) => c.countryCode == 'IL')) c.nameEn: c};
      for (final name in [
        "Ma'ale Adumim", 'Beitar Illit', 'Efrat', "Givat Ze'ev", 'Beit El', 'Karnei Shomron', 'Kochav Yaakov',
        'Kedumim', 'Alon Shvut', 'Ofra', 'Elkana', 'Tekoa', 'Kfar Adumim', 'Oranit',
      ]) {
        expect(israel[name]?.timeZone, 'Asia/Jerusalem', reason: name);
        expect(israel[name]?.candleMinutes, 20, reason: name);
      }
      expect(names(directory.search('בית אל')).first, 'Beit El');
      expect(names(directory.search('Adam')), contains('Geva Binyamin (Adam)'));
    });

    test("leaves out sections of the cities abroad that GeoNames lists apart", () {
      final all = names(directory.cities).toSet();
      for (final district in [
        'Kalininskiy', 'Krasnogvargeisky', 'Centralniy', 'Admiralteisky', 'Petrogradka', // Saint Petersburg
        'Hamburg-Mitte', 'Wandsbek', 'Altona', 'Eimsbüttel', 'Charlottenburg', 'Neukölln', 'Kreuzberg',
        'East Helsinki', 'Södermalm', 'Lasnamäe', 'New South Memphis', 'City of Port Phillip',
        'Paris 15 Vaugirard', 'Upper West Side', 'Borough Park', 'Iztapalapa', 'Etobicoke',
      ]) {
        expect(all, isNot(contains(district)));
      }
      // The cities themselves, and New York's boroughs, stay.
      expect(all, containsAll(['Saint Petersburg', 'Hamburg', 'Berlin', 'Memphis', 'Melbourne', 'Brooklyn']));
      expect(names(directory.inTimeZone('Australia/Melbourne', limit: 3)), ['Melbourne', 'Geelong', 'Ballarat']);
      // A city of the same name that a district shadowed is back.
      expect(directory.cities.where((c) => c.nameEn == 'Salamanca' && c.countryCode == 'ES'), hasLength(1));
    });

    test('candles are lit 18 minutes before sunset, 20 in Israel, 40 in Jerusalem and 30 in Haifa', () {
      final minutes = {for (final c in directory.cities) c.nameEn: c.candleMinutes};
      expect(minutes['Jerusalem'], 40);
      expect(minutes['Haifa'], 30);
      expect(minutes["Zikhron Ya'akov"], 30);
      expect(minutes['Tel Aviv'], 20);
      expect(minutes['London'], 18);
      for (final c in directory.cities) {
        if (c.countryCode != 'IL') expect(c.candleMinutes, 18, reason: c.nameEn);
      }
    });

    test('Hebrew names are plain Hebrew, with a geresh rather than an apostrophe', () {
      final plain = RegExp(r'^[א-ת][א-ת ׳״\-()]*$');
      for (final c in directory.cities) {
        if (c.nameHe case final he?) expect(plain.hasMatch(he), isTrue, reason: '${c.nameEn}: $he');
      }
    });

    test('American places say their state', () {
      final springfields = directory.cities.where((c) => c.nameEn == 'Springfield').toList();
      expect(springfields.length, greaterThan(1));
      expect(
        springfields.map((c) => directory.placeOf(c, hebrew: false)),
        containsAll(['Massachusetts, United States', 'Missouri, United States']),
      );
      expect(directory.placeOf(springfields.first, hebrew: true), endsWith(', ארצות הברית'));
    });
  });

  group('search', () {
    test('finds a place by its name in either language', () {
      expect(names(directory.search('Jerusalem')).first, 'Jerusalem');
      expect(names(directory.search('ירושלים')).first, 'Jerusalem');
      expect(names(directory.search('לונדון')).first, 'London');
    });

    test('ignores case, accents, punctuation and spaces', () {
      expect(names(directory.search('sao paulo')).first, 'São Paulo');
      expect(names(directory.search('RAANANA')).first, "Ra'anana");
      expect(names(directory.search('telaviv')).first, 'Tel Aviv');
      expect(names(directory.search('Zurich')).first, 'Zürich');
    });

    test('finds the usual other spellings', () {
      expect(names(directory.search('Petach Tikva')).first, 'Petah Tikva');
      expect(names(directory.search('Qiryat Gat')).first, 'Kiryat Gat');
      expect(names(directory.search('Tzfat')).first, 'Safed');
      expect(names(directory.search('Jaffa')).first, 'Tel Aviv');
      expect(names(directory.search('Yerushalayim')).first, 'Jerusalem');
      // Hebrew spelled with fewer or more vowel letters.
      expect(names(directory.search('קרית גת')).first, 'Kiryat Gat');
      expect(names(directory.search('פתח תקוה')).first, 'Petah Tikva');
    });

    test('ranks a whole name, then a beginning, then a word, then any part', () {
      final york = names(directory.search('york'));
      expect(york.first, 'York');
      expect(york, contains('New York City'));
      expect(york.indexOf('York'), lessThan(york.indexOf('New York City')));
      // Of places with a name that begins so, the largest first.
      final lake = directory.search('Lakewood');
      expect(lake.map((c) => directory.placeOf(c, hebrew: false)), contains('New Jersey, United States'));
    });

    test('a name never loses to another spelling of a different place', () {
      // "Ariel" is among Jerusalem's alternate names in GeoNames.
      expect(names(directory.search('Ariel')).first, 'Ariel');
    });

    test('nothing for an empty query, or one of nothing but punctuation', () {
      expect(directory.search(''), isEmpty);
      expect(directory.search(' - ’ '), isEmpty);
      expect(CityDirectory.isQuery(' - ’ '), isFalse);
    });

    // ו and י are left out of Hebrew, so they alone are no query either.
    test('nothing for a query of nothing but ו and י', () {
      for (final q in ['י', 'ו', 'יו', ' י ']) {
        expect(CityDirectory.isQuery(q), isFalse, reason: q);
        expect(directory.search(q), isEmpty, reason: q);
        expect(directory.count(q), 0, reason: q);
      }
      expect(CityDirectory.isQuery('יר'), isTrue);
      expect(names(directory.search('יר')), contains('Jerusalem'));
    });

    test('finds Hebrew spelled with or without א after the first letter', () {
      expect(names(directory.search('שאנגחאי')).first, 'Shanghai');
      expect(names(directory.search('שנגחאי')).first, 'Shanghai');
      expect(names(directory.search('פאריז')).first, 'Paris');
      expect(names(directory.search('שיקאגו')).first, 'Chicago');
      // An א that begins the name is kept: אשדוד isn't שדוד.
      expect(foldForSearch('אשדוד'), startsWith('א'));
      expect(names(directory.search('אשדוד')).first, 'Ashdod');
      expect(names(directory.search('תל אביב')).first, 'Tel Aviv');
      expect(names(directory.search('אביב')), contains('Tel Aviv'));
    });

    test('stops at the limit, and counts everything it found', () {
      expect(directory.search('a', limit: 10), hasLength(10));
      final all = directory.count('a');
      expect(all, greaterThan(1000));
      expect(directory.search('a', limit: 100000), hasLength(all));
    });
  });

  group('suggestions by time zone', () {
    test('the largest places on the device\'s clock', () {
      expect(names(directory.inTimeZone('Asia/Jerusalem', limit: 3)), ['Jerusalem', 'Tel Aviv', 'Haifa']);
      expect(names(directory.inTimeZone('America/New_York')).first, 'New York City');
    });

    test('an old name for a zone finds the places keeping its time', () {
      expect(names(directory.inTimeZone('US/Eastern')), contains('New York City'));
    });

    test('none for UTC itself, or a zone the device doesn\'t know', () {
      expect(directory.inTimeZone('UTC'), isEmpty);
      expect(directory.inTimeZone('Etc/UTC'), isEmpty);
      expect(directory.inTimeZone('Mars/Olympus_Mons'), isEmpty);
    });
  });
}
