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
import 'package:shnayim_mikra/features/settings/screens/data_settings_screen.dart';

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
  'a pause id that is not text': _stored('{}', pauses: '[{"id": 7, "s": ${_d1.rd}, "e": ${_d2.rd}}]'),
  'a short stamp grid': _stored('{"5787:2": {"u": ${_grid()}, "t": [[1, 2, 3]]}}', version: 2),
  'a reset time that is not a time': '{"version": 2, "resetAt": "yesterday", "weeks": {}, "pauses": []}',
  'a newer format': _stored('{"5787:2": {"u": ${_grid()}}}', version: 99),
  'a further mark that is not a day and a time':
      _stored('{"5787:2": {"u": ${_grid()}, "t": ${_stampGrid()}, "x": [[0, 0, "x", 9]]}}', version: 2),
  'a further mark on a reading that is not read':
      _stored('{"5787:2": {"u": ${_grid()}, "t": ${_stampGrid()}, "x": [[1, 0, ${_d2.rd}, 9]]}}', version: 2),
  'a mark from before the reading was marked as not read': _stored(
      '{"5787:2": {"u": ${_grid()}, "t": ${_stampGrid()}, "c": ${_stampGrid(at: 7)}}}',
      version: 2),
  'a week without a unit grid': _stored('{"5787:2": {"units": ${_grid()}}}', version: 2),
  'a key this version does not know': _stored('{"5787:2": {"u": ${_grid()}, "note": 1}}', version: 2),
};

/// A stamp grid with Rishon's readings marked at [at].
String _stampGrid({int at = 5}) => jsonEncode([
      [at, at, at],
      for (var a = 1; a < kAliyot; a++) [0, 0, 0],
    ]);

/// What the reader sees of [s]: the readings, saved places and pauses, but
/// not when they changed.
String _visible(ProgressState s) => jsonEncode({
      for (final id in s.weeks.keys.toList()..sort())
        if (s.weeks[id]!.isStarted || s.weeks[id]!.haftarah != null)
          id: {for (final k in const ['u', 'h', 'p']) k: s.weeks[id]!.toJson()[k]},
      'pauses': [
        for (final p in s.pauses)
          if (!p.deleted) [p.start.rd, p.end.rd],
      ],
    });

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

    test('stamps that are not times read as 0, and a short stamp grid is padded', () {
      final json = {
        'u': jsonDecode(_grid()),
        't': [
          [5, -1, 'x'],
          [7],
        ],
        'ht': 'later',
        'pt': {'0': 9, '1': -3, '8': 4, 'x': 1, '2': 0},
      };
      final week = WeekProgress.fromJson('5787:2', json);
      expect(week.stamps, hasLength(kAliyot));
      expect(week.stamps[0], [5, 0, 0]);
      expect(week.stamps[1], [7, 0, 0]);
      expect(week.stamps[6], [0, 0, 0]);
      expect(week.haftarahStamp, 0);
      expect(week.positionStamps, {0: 9});
      expect(week.units[0], [_d1, _d1, _d1], reason: 'the readings are kept');
      expect(() => WeekProgress.fromJson('5787:2', json, strict: true), throwsFormatException);
      expect(() => WeekProgress.fromJson('5787:2', {'u': jsonDecode(_grid()), 't': 'now'}), throwsFormatException);
      expect(() => WeekProgress.fromJson('5787:2', {'u': jsonDecode(_grid()), 'pt': [1]}), throwsFormatException);
    });

    test('a week without a unit grid, or with a key this version does not know, is not read', () {
      expect(() => WeekProgress.fromJson('5787:2', {'units': jsonDecode(_grid())}), throwsFormatException);
      expect(() => WeekProgress.fromJson('5787:2', {'x': 1}), throwsFormatException);
      expect(() => WeekProgress.fromJson('5787:2', {'u': jsonDecode(_grid()), 'note': 1}), throwsFormatException);
      expect(WeekProgress.fromJson('5787:2', const {}, strict: true).isBlank, isTrue);
    });

    test('every mark and removal reads back exactly, even strictly', () {
      final wallClock = ProgressClock.nowMs;
      addTearDown(() => ProgressClock.nowMs = wallClock);
      var now = 1000;
      ProgressClock.nowMs = () => now;
      // Rishon logged independently on two devices, a day apart; Sheni and
      // the haftarah marked as not read, then read again on another day.
      final phone = WeekProgress(weekId: '5787:2').withAliyah(0, _d1).withAliyah(1, _d1).withHaftarah(_d1);
      now += 1000;
      final tablet = WeekProgress(weekId: '5787:2').withAliyah(0, _d2);
      now += 1000;
      final corrected = phone.withAliyah(1, null).withHaftarah(null);
      now += 1000;
      final week = mergeProgress(
        ProgressState(weeks: {'5787:2': corrected.withAliyah(1, _d2).withHaftarah(_d2)}),
        ProgressState(weeks: {'5787:2': tablet}),
      ).week('5787:2');
      expect(week.records[0][0].marks.map((m) => m.day), [_d1, _d2], reason: 'either could decide the day');
      expect(week.units[0], [_d1, _d1, _d1]);
      expect(week.units[1], [_d2, _d2, _d2]);
      expect(week.haftarah, _d2);

      final json = jsonDecode(jsonEncode(week.toJson())) as Map<String, dynamic>;
      expect(json.keys, containsAll(['x', 'c', 'hc']));
      final back = WeekProgress.fromJson('5787:2', json, strict: true);
      expect(jsonEncode(back.toJson()), jsonEncode(week.toJson()));
      expect(back.records[0][0].marks.map((m) => (m.day, m.at)), week.records[0][0].marks.map((m) => (m.day, m.at)));
      expect(back.records[1][0].clearedAt, week.records[1][0].clearedAt);
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
    test('version 1 progress reads as version 2, stamped at time 0', () {
      final v1 = _stored(
        '{"5787:2": {"u": ${_grid()}, "h": ${_d2.rd}, "p": {"0": [3, 3, 3]}}}',
        pauses: '[{"s": ${_d1.rd}, "e": ${_d2.rd}}]',
      );
      final s = _parse(v1, strict: true);
      final week = s.week('5787:2');
      expect(week.isAliyahDone(0), isTrue);
      expect(week.stamps.expand((row) => row), everyElement(0));
      expect(week.haftarahStamp, 0);
      expect(week.positionStamps, isEmpty);
      expect(s.resetAt, 0);
      expect((s.pauses.single.id, s.pauses.single.updatedAt), ('${_d1.rd}-${_d2.rd}', 0));

      final json = _roundTrip(s);
      expect(json['version'], 2);
      expect(json.containsKey('resetAt'), isFalse);
      expect((json['weeks'] as Map)['5787:2'], {
        'u': jsonDecode(_grid()),
        'h': _d2.rd,
        'p': {
          '0': [3, 3, 3],
        },
      });
      expect(json['pauses'], [
        {'id': '${_d1.rd}-${_d2.rd}', 's': _d1.rd, 'e': _d2.rd},
      ]);
      expect(ProgressState.fromJson(json, strict: true), s);
    });

    test('a reset time that is not a time is ignored', () {
      expect(_parse('{"resetAt": -5, "weeks": {}}').resetAt, 0);
      expect(_parse('{"resetAt": "yesterday", "weeks": {}}').resetAt, 0);
      expect(_parse('{"version": 2, "resetAt": 1234, "weeks": {}}', strict: true).resetAt, 1234);
    });

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
    final open = <ProviderContainer>[];

    /// Writes the progress each app opened so far is waiting to save, as it
    /// does before it can be closed.
    Future<void> saved() async {
      for (final c in open) {
        await c.read(progressProvider.notifier).flush();
      }
    }

    ProviderContainer start() {
      final c = ProviderContainer(overrides: [sharedPreferencesProvider.overrideWithValue(prefs)]);
      open.add(c);
      addTearDown(() {
        open.remove(c);
        c.dispose();
      });
      return c;
    }

    /// A fresh start of the app on the same storage, once what the last one
    /// was waiting to save is saved.
    Future<ProviderContainer> reopen() async {
      await saved();
      return start();
    }

    Future<ProviderContainer> load(String raw) async {
      SharedPreferences.setMockInitialValues({ProgressController.storageKey: raw});
      prefs = await SharedPreferences.getInstance();
      return start();
    }

    Map<String, String> backups(String prefix) => {
          for (final k in prefs.getKeys().where((k) => k.startsWith(prefix))) k: prefs.getString(k)!,
        };

    /// The progress in storage, once what is waiting to be saved is.
    Future<Map<String, dynamic>> stored() async {
      await saved();
      return jsonDecode(prefs.getString(ProgressController.storageKey)!) as Map<String, dynamic>;
    }

    test('progress from a newer version is backed up before anything is saved', () async {
      final raw = _stored('{"5787:2": {"u": ${_grid()}, "t": [[1, 2, 3]]}}', version: 99);
      final c = await load(raw);
      expect(c.read(progressProvider).week('5787:2').isAliyahDone(0), isTrue);
      expect(backups(ProgressController.newerBackupPrefix).values, [raw]);

      // Opening it again before anything changed makes no second copy.
      (await reopen()).read(progressProvider);
      expect(backups(ProgressController.newerBackupPrefix), hasLength(1));

      c.read(progressProvider.notifier).markUnit('5787:2', 1, ReadingPass.mikra1, _d2);
      expect((await stored())['version'], kProgressFormat);
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
      expect((await reopen()).read(progressProvider).week('5787:2').isUnitDone(0, ReadingPass.mikra1), isTrue);
    });

    test('a week without a unit grid is kept aside untouched, not read as empty and overwritten', () async {
      final units = [
        for (var a = 0; a < kAliyot; a++) [_d1.rd, _d1.rd, _d1.rd],
      ];
      final c = await load(_stored('{"5787:1": {"units": ${jsonEncode(units)}}, "5787:2": {"u": ${_grid()}}}', version: 2));
      expect(c.read(progressProvider).unknownWeeks.keys, ['5787:1']);
      c.read(progressProvider.notifier).markUnit('5787:2', 1, ReadingPass.mikra1, _d2);
      expect(((await stored())['weeks'] as Map)['5787:1'], {'units': units});
      expect(backups(ProgressController.corruptBackupPrefix), isEmpty, reason: 'nothing was lost');
    });

    test('progress read only by fixing part of it is backed up before the fix is saved', () async {
      final raw = _stored(
        '{"5787:1": {"u": [[${_d1.rd}, "2026-10-11", ${_d1.rd}]], "h": "yes"}, "5787:2": {"u": ${_grid()}}}',
        version: 2,
      );
      final c = await load(raw);
      expect(c.read(progressProvider).week('5787:1').units[0], [_d1, null, _d1]);
      expect(backups(ProgressController.corruptBackupPrefix).values, [raw]);

      c.read(progressProvider.notifier).markUnit('5787:2', 1, ReadingPass.mikra1, _d2);
      expect(((await stored())['weeks'] as Map)['5787:1']['u'][0], [_d1.rd, null, _d1.rd], reason: 'saved fixed');
      expect(backups(ProgressController.corruptBackupPrefix).values, [raw]);
      (await reopen()).read(progressProvider);
      expect(backups(ProgressController.corruptBackupPrefix), hasLength(1), reason: 'it reads exactly now');
    });

    test('progress with a reset time or a part this version does not know is backed up too', () async {
      for (final raw in [
        '{"version": 2, "resetAt": "yesterday", "weeks": {}, "pauses": []}',
        '{"version": 2, "weeks": {}, "pauses": [], "goals": [1]}',
      ]) {
        await load(raw);
        (await reopen()).read(progressProvider);
        expect(backups(ProgressController.corruptBackupPrefix).values, [raw]);
      }
    });

    test('an unknown week is kept through saves, and copied before a readable week replaces it', () async {
      const unknown = '{"u":"done"}';
      final c = await load(_stored('{"5787:1": {"u": ${_grid()}}, "5787:2": {"u": "done"}}'));
      final progress = c.read(progressProvider.notifier);

      progress.markUnit('5787:1', 1, ReadingPass.mikra1, _d2);
      progress.addPause(_d1, _d2);
      expect(jsonEncode(((await stored())['weeks'] as Map)['5787:2']), unknown);
      expect(backups(ProgressController.corruptBackupPrefix), isEmpty, reason: 'nothing was at risk yet');

      // Reading in that week replaces the entry this version couldn't read.
      progress.markUnit('5787:2', 0, ReadingPass.mikra1, _d2);
      expect(backups(ProgressController.corruptBackupPrefix).values, ['{"weeks":{"5787:2":$unknown}}']);
      expect(c.read(progressProvider).unknownWeeks, isEmpty);
      expect((await reopen()).read(progressProvider).week('5787:2').isUnitDone(0, ReadingPass.mikra1), isTrue);
    });

    test('resetting all progress erases what could not be read too, as asked', () async {
      final c = await load(_stored('{"5787:2": {"u": "done"}}', pauses: '[{"start": "2026-10-11"}]'));
      c.read(progressProvider.notifier).reset();
      expect(c.read(progressProvider), const ProgressState());
      expect(backups(ProgressController.corruptBackupPrefix), isEmpty);
    });
  });

  testWidgets('what this version cannot read is exported apart, and imported again with the rest', (tester) async {
    tester.view.physicalSize = const Size(412, 915);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    const unknownWeeks = {
      '5787:9': {'u': 'done'},
    };
    const unknownPauses = [
      {'start': '2026-10-11'},
    ];
    final mine = ProgressState(
      weeks: {'5787:1': WeekProgress(weekId: '5787:1').withAliyah(3, _d1)},
      unknownWeeks: unknownWeeks,
      unknownPauses: unknownPauses,
    );
    var c = await pumpApp(tester, progress: mine, now: DateTime(2026, 10, 12, 10));
    c.read(routerProvider).go('/settings/data');
    await tester.pumpAndSettle();
    WidgetRef ref() => tester.element(find.byType(DataSettingsScreen)) as WidgetRef;
    final file = exportBackup(ref());
    final json = jsonDecode(file) as Map<String, dynamic>;
    expect(ProgressState.fromJson(json['progress'] as Map<String, dynamic>, strict: true), mine.readable);
    expect(json['unreadableProgress'], {'weeks': unknownWeeks, 'pauses': unknownPauses});

    // On a fresh install.
    c = await pumpApp(tester, now: DateTime(2026, 10, 12, 10));
    c.read(routerProvider).go('/settings/data');
    await tester.pumpAndSettle();
    expect(importBackup(ref(), file), isTrue);
    final imported = c.read(progressProvider);
    expect(imported.week('5787:1').isAliyahDone(3), isTrue);
    expect(imported.unknownWeeks, unknownWeeks);
    expect(imported.unknownPauses, unknownPauses);
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

    testWidgets('a good file is imported, as a change that a sync keeps', (tester) async {
      final wallClock = ProgressClock.nowMs;
      addTearDown(() => ProgressClock.nowMs = wallClock);
      var now = DateTime.utc(2026, 10, 1).millisecondsSinceEpoch;
      ProgressClock.nowMs = () => now;

      final theirs = ProgressState(
        weeks: {'5787:2': WeekProgress(weekId: '5787:2').withAll(_d2)},
        pauses: [Pause(_d1, _d1)],
      );
      // Since the file was saved, progress was reset everywhere, and then
      // Revi'i of Bereshit read and backed up.
      now += 1000;
      final resetAt = now;
      now += 1000;
      final c = await import(tester, _roundTrip(theirs));
      final backup = ProgressState(
        weeks: {'5787:1': WeekProgress(weekId: '5787:1').withAliyah(3, _d1)},
        resetAt: resetAt,
      );
      expect(find.text('Progress imported.'), findsOneWidget);
      final imported = c.read(progressProvider);
      expect(_visible(imported), _visible(theirs));
      expect(imported.week('5787:1').isStarted, isFalse, reason: 'what the file lacks is removed');
      expect(_visible(mergeProgress(imported, backup)), _visible(theirs), reason: 'syncing keeps the import');
    });
  });
}
