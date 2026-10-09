import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/app/router.dart';
import 'package:shnayim_mikra/core/calendar/local_date.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_merge.dart';
import 'package:shnayim_mikra/features/progress/domain/progress_models.dart';

import '../../helpers.dart';

final _d1 = LocalDate(2026, 10, 11);
final _d2 = LocalDate(2026, 10, 12);

/// A complete, well-formed unit grid with Rishon fully read on [_d1].
String _grid() => jsonEncode([
      [_d1.rd, _d1.rd, _d1.rd],
      for (var a = 1; a < kAliyot; a++) [null, null, null],
    ]);

/// Stored progress, as raw JSON text.
String _stored(String weeks, {String pauses = '[]', int version = 1}) =>
    '{"version": $version, "weeks": $weeks, "pauses": $pauses}';

ProgressState _parse(String raw, {bool strict = false}) =>
    ProgressState.fromJson(jsonDecode(raw) as Map<String, dynamic>, strict: strict);

Map<String, dynamic> _roundTrip(ProgressState s) => jsonDecode(jsonEncode(s.toJson())) as Map<String, dynamic>;

/// Fixtures that a strict read (importing a backup) must reject.
final _bad = {
  'a short unit grid': _stored('{"5787:2": {"u": [[${_d1.rd}, null], [null, null, ${_d2.rd}]]}}'),
  'a string inside a position': _stored('{"5787:2": {"u": ${_grid()}, "p": {"0": [1, "2", 3]}}}'),
  'an unknown week shape': _stored('{"5787:2": {"u": "done"}}'),
  'an unknown pause shape': _stored('{}', pauses: '[{"start": "2026-10-11"}]'),
  'a newer format': _stored('{"5787:2": {"u": ${_grid()}}}', version: 99),
};

void main() {
  group('WeekProgress.fromJson', () {
    test('a short unit grid is padded to 7 × 3', () {
      final week = _parse(_bad['a short unit grid']!).week('5787:2');
      expect(week.units, hasLength(kAliyot));
      expect(week.units.every((row) => row.length == 3), isTrue);
      expect(week.units[0], [_d1, null, null]);
      expect(week.units[1], [null, null, _d2]);
      expect(week.completedUnits, 2);
      expect(week.isAliyahDone(6), isFalse, reason: 'a missing row reads as not done, not as a RangeError');
    });

    test('extra rows and cells are dropped, and a cell that is not a day reads as not done', () {
      final rows = [
        [_d1.rd, '2026-10-12', _d2.rd, _d2.rd],
        'read',
        for (var a = 2; a < 9; a++) [_d1.rd, _d1.rd, _d1.rd],
      ];
      final week = WeekProgress.fromJson('5787:2', {'u': rows, 'h': 'yes'});
      expect(week.units, hasLength(kAliyot));
      expect(week.units[0], [_d1, null, _d2]);
      expect(week.units[1], [null, null, null]);
      expect(week.units[6], [_d1, _d1, _d1]);
      expect(week.haftarah, isNull);
      expect(() => WeekProgress.fromJson('5787:2', {'u': rows}, strict: true), throwsFormatException);
    });

    test('a string inside a position drops only that entry', () {
      const positions = '{"0": [1, "2", 3], "1": [4, 5], "2": [1, 2, 3, 4], "3": [7, 7, 7], '
          '"9": [1, 1, 1], "x": [1, 1, 1], "4": 3}';
      final week = _parse(_stored('{"5787:2": {"u": ${_grid()}, "p": $positions}}')).week('5787:2');
      expect(week.positions, {1: [4, 5, 0], 2: [1, 2, 3], 3: [7, 7, 7]});
      expect(week.units[0], [_d1, _d1, _d1], reason: 'the rest of the week is kept');
      // Copied eagerly into real lists of ints, not lazy casts that fail later.
      for (final p in week.positions.values) {
        expect(p, isA<List<int>>());
        expect(() => p.add(0), throwsUnsupportedError);
      }
    });

    test('a well-formed week reads back exactly, even strictly', () {
      final week = WeekProgress(weekId: '5787:2')
          .withAliyah(0, _d1)
          .withUnit(1, ReadingPass.mikra1, _d2)
          .withHaftarah(_d2)
          .withPosition(1, const [3, 0, 0]);
      final json = jsonDecode(jsonEncode(week.toJson())) as Map<String, dynamic>;
      final back = WeekProgress.fromJson('5787:2', json, strict: true);
      expect(jsonEncode(back.toJson()), jsonEncode(week.toJson()));
    });
  });

  group('ProgressState.fromJson', () {
    const unknownWeek = '{"u": "done", "note": {"b": 1, "a": [2, null]}}';
    const unknownPause = '{"start": "2026-10-11"}';
    String withUnknowns() => _stored(
          '{"5787:1": {"u": ${_grid()}}, "5787:2": [1, 2, 3], "5787:3": $unknownWeek}',
          pauses: '[{"s": ${_d1.rd}, "e": ${_d2.rd}}, $unknownPause]',
        );

    test('an unknown week shape round-trips untouched', () {
      final s = _parse(withUnknowns());
      expect(s.weeks.keys, ['5787:1']);
      expect(s.week('5787:1').isAliyahDone(0), isTrue);
      expect(s.pauses.single.end, _d2);
      expect(s.unknownWeeks.keys, ['5787:2', '5787:3']);

      final json = _roundTrip(s);
      final weeks = json['weeks'] as Map<String, dynamic>;
      expect(jsonEncode(weeks['5787:2']), '[1,2,3]');
      expect(jsonEncode(weeks['5787:3']), jsonEncode(jsonDecode(unknownWeek)));
      expect(jsonEncode((json['pauses'] as List).last), jsonEncode(jsonDecode(unknownPause)));
      expect(ProgressState.fromJson(json), s);
    });

    test('unknown entries count toward equality and survive merging', () {
      final s = _parse(withUnknowns());
      expect(s, isNot(s.readable));
      final other = ProgressState(weeks: {'5787:4': WeekProgress(weekId: '5787:4').withAliyah(2, _d2)});
      final m = mergeProgress(s, other);
      expect(m, mergeProgress(other, s));
      expect(mergeProgress(m, m), m);
      expect(m.unknownWeeks.keys, unorderedEquals(['5787:2', '5787:3']));
      expect(m.unknownPauses, hasLength(1));
      expect(m.week('5787:4').isAliyahDone(2), isTrue);
    });

    test('a readable copy leaves out what could not be read', () {
      final readable = _parse(withUnknowns()).readable;
      expect(readable.unknownWeeks, isEmpty);
      expect(readable.unknownPauses, isEmpty);
      expect(ProgressState.fromJson(_roundTrip(readable), strict: true), readable);
    });

    test('a newer format is read leniently', () {
      final s = _parse(_bad['a newer format']!);
      expect(ProgressState.formatOf(jsonDecode(_bad['a newer format']!) as Map<String, dynamic>), 99);
      expect(s.week('5787:2').isAliyahDone(0), isTrue);
    });

    test('a wrong overall shape throws', () {
      expect(() => _parse('{"weeks": []}'), throwsFormatException);
      expect(() => _parse('{"weeks": {}, "pauses": {}}'), throwsFormatException);
      expect(() => _parse('{"version": "2", "weeks": {}}'), throwsFormatException);
    });

    for (final MapEntry(key: name, value: raw) in _bad.entries) {
      test('strict reading rejects $name', () {
        expect(() => _parse(raw, strict: true), throwsFormatException);
      });
    }
  });

  group('ProgressController', () {
    late SharedPreferences prefs;

    /// A fresh start of the app on the same storage.
    ProviderContainer reopen() {
      final c = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
      addTearDown(c.dispose);
      return c;
    }

    Future<ProviderContainer> load(String raw) async {
      SharedPreferences.setMockInitialValues({ProgressController.storageKey: raw});
      prefs = await SharedPreferences.getInstance();
      return reopen();
    }

    Map<String, String> backups(String prefix) => {
          for (final k in prefs.getKeys().where((k) => k.startsWith(prefix))) k: prefs.getString(k)!,
        };

    Map<String, dynamic> stored() =>
        jsonDecode(prefs.getString(ProgressController.storageKey)!) as Map<String, dynamic>;

    test('progress from a newer version is backed up before anything is saved', () async {
      final raw = _stored('{"5787:2": {"u": ${_grid()}, "t": [[1, 2, 3]]}}', version: 99);
      final c = await load(raw);
      expect(c.read(progressProvider).week('5787:2').isAliyahDone(0), isTrue);
      expect(backups(ProgressController.newerBackupPrefix).values, [raw]);

      // Opening it again before anything changed makes no second copy.
      reopen().read(progressProvider);
      expect(backups(ProgressController.newerBackupPrefix), hasLength(1));

      c.read(progressProvider.notifier).markUnit('5787:2', 1, ReadingPass.mikra1, _d2);
      expect(stored()['version'], kProgressFormat);
      expect(backups(ProgressController.newerBackupPrefix).values, [raw]);
      expect(backups(ProgressController.corruptBackupPrefix), isEmpty);
    });

    test('unreadable progress is backed up instead of being lost at the next save', () async {
      const raw = '{"version": 1, "weeks": [';
      final c = await load(raw);
      expect(c.read(progressProvider), const ProgressState());
      expect(backups(ProgressController.corruptBackupPrefix).values, [raw]);

      c.read(progressProvider.notifier).markUnit('5787:2', 0, ReadingPass.mikra1, _d1);
      expect(backups(ProgressController.corruptBackupPrefix).values, [raw]);
      expect(reopen().read(progressProvider).week('5787:2').isUnitDone(0, ReadingPass.mikra1), isTrue);
    });

    test('an unknown week is kept through saves, and copied before a readable week replaces it', () async {
      const unknown = '{"u":"done"}';
      final c = await load(_stored('{"5787:1": {"u": ${_grid()}}, "5787:2": {"u": "done"}}'));
      final progress = c.read(progressProvider.notifier);

      progress.markUnit('5787:1', 1, ReadingPass.mikra1, _d2);
      progress.addPause(Pause(_d1, _d2));
      expect(jsonEncode((stored()['weeks'] as Map)['5787:2']), unknown);
      expect(backups(ProgressController.corruptBackupPrefix), isEmpty, reason: 'nothing was at risk yet');

      // Reading in that week replaces the entry this version couldn't read.
      progress.markUnit('5787:2', 0, ReadingPass.mikra1, _d2);
      expect(backups(ProgressController.corruptBackupPrefix).values, ['{"weeks":{"5787:2":$unknown}}']);
      expect(c.read(progressProvider).unknownWeeks, isEmpty);
      expect(reopen().read(progressProvider).week('5787:2').isUnitDone(0, ReadingPass.mikra1), isTrue);
    });
  });

  group('importing a backup', () {
    Future<ProviderContainer> import(WidgetTester tester, Map<String, dynamic> progress) async {
      tester.view.physicalSize = const Size(412, 915);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final mine = ProgressState(weeks: {'5787:1': WeekProgress(weekId: '5787:1').withAliyah(3, _d1)});
      final c = await pumpApp(tester, progress: mine, now: DateTime(2026, 10, 12, 10));
      c.read(routerProvider).go('/settings/data');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Import progress'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), jsonEncode({'app': 'shnayim_mikra', 'progress': progress}));
      await tester.tap(find.widgetWithText(FilledButton, 'Import progress'));
      await tester.pumpAndSettle();
      return c;
    }

    for (final MapEntry(key: name, value: raw) in _bad.entries) {
      testWidgets('a file with $name is rejected whole', (tester) async {
        final c = await import(tester, jsonDecode(raw) as Map<String, dynamic>);
        expect(find.text("That backup couldn't be read."), findsOneWidget);
        expect(c.read(progressProvider).weeks.keys, ['5787:1'], reason: 'nothing was imported');
        expect(c.read(progressProvider).week('5787:1').isAliyahDone(3), isTrue);
      });
    }

    testWidgets('a good file is imported', (tester) async {
      final theirs = ProgressState(
        weeks: {'5787:2': WeekProgress(weekId: '5787:2').withAll(_d2)},
        pauses: [Pause(_d1, _d1)],
      );
      final c = await import(tester, _roundTrip(theirs));
      expect(find.text('Progress imported.'), findsOneWidget);
      expect(c.read(progressProvider), theirs);
    });
  });
}
