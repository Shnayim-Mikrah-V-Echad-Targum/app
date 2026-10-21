import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shnayim_mikrah/services/preferences_file_io.dart';
import 'package:shnayim_mikrah/services/preferences_recovery.dart';

/// The preferences on Windows, as shared_preferences_windows keeps them: one
/// JSON file in the support directory, read once (an error is not cached)
/// and rewritten whole on each change.
class _FileStore extends SharedPreferencesStorePlatform {
  _FileStore(this.directory);

  final Directory directory;
  Map<String, Object>? _cached;
  int reads = 0;

  File get file => File('${directory.path}/$preferencesFileName');

  @override
  Future<Map<String, Object>> getAll() async {
    if (_cached == null) {
      reads++;
      var data = <String, Object>{};
      if (file.existsSync()) {
        final text = file.readAsStringSync();
        if (text.isNotEmpty) data = (json.decode(text) as Map).cast<String, Object>();
      }
      _cached = data;
    }
    return Map.of(_cached!);
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async {
    (_cached ??= {})[key] = value;
    file.writeAsStringSync(json.encode(_cached));
    return true;
  }

  @override
  Future<bool> remove(String key) async => throw UnimplementedError();

  @override
  Future<bool> clear() async => throw UnimplementedError();
}

/// A store that fails to read [failures] times (every time, unless given),
/// as localStorage does in a browser that blocks the site's storage.
class _FailingStore extends SharedPreferencesStorePlatform {
  _FailingStore({this.failures});

  final int? failures;
  int reads = 0;

  @override
  Future<Map<String, Object>> getAll() async {
    reads++;
    if (failures == null || reads <= failures!) throw StateError('SecurityError: storage is blocked');
    return {'flutter.kept': true};
  }

  @override
  Future<bool> setValue(String valueType, String key, Object value) async => throw StateError('blocked');

  @override
  Future<bool> remove(String key) async => throw StateError('blocked');

  @override
  Future<bool> clear() async => throw StateError('blocked');
}

void main() {
  late Directory directory;
  late List<FlutterErrorDetails> reported;
  late FlutterExceptionHandler? onError;

  File file(String name) => File('${directory.path}/$name');
  Future<String> supportPath() async => directory.path;

  setUp(() {
    directory = Directory.systemTemp.createTempSync('preferences');
    SharedPreferences.setMockInitialValues({});
    reported = [];
    onError = FlutterError.onError;
    FlutterError.onError = reported.add;
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    FlutterError.onError = onError;
    directory.deleteSync(recursive: true);
  });

  group('preferencesReadable', () {
    test('reads what the plugins can read', () {
      expect(preferencesReadable(utf8.encode('{"flutter.settings.v1":"{}","flutter.n":3}')), isTrue);
      expect(preferencesReadable(utf8.encode('{}')), isTrue);
      // An empty file holds no preferences, and a JSON that isn't an object
      // none they read: neither stops them.
      expect(preferencesReadable(const []), isTrue);
      expect(preferencesReadable(utf8.encode('[1, 2]')), isTrue);
    });

    test('refuses what a write cut short leaves', () {
      expect(preferencesReadable(utf8.encode('{"flutter.settings.v1":"{\\"theme\\":')), isFalse);
      expect(preferencesReadable(List.filled(512, 0)), isFalse, reason: 'NULs, as NTFS can leave after a power cut');
      expect(preferencesReadable(const [0x7B, 0xC3, 0x28, 0x7D]), isFalse, reason: 'not UTF-8');
      expect(preferencesReadable(utf8.encode('{"flutter.a": null}')), isFalse, reason: 'a null the plugins can’t cast');
    });
  });

  group('setAsideUnreadablePreferences', () {
    test('renames a damaged file beside it, replacing one set aside before', () async {
      file(preferencesFileName).writeAsStringSync('{"flutter.progress.v1":"{\\"we');
      file(setAsideFileName).writeAsStringSync('older');
      expect(await setAsideUnreadablePreferences(supportPath: supportPath), setAsideFileName);
      expect(file(preferencesFileName).existsSync(), isFalse);
      expect(file(setAsideFileName).readAsStringSync(), '{"flutter.progress.v1":"{\\"we');
    });

    test('leaves a file the plugins can read, and finds nothing where there is none', () async {
      file(preferencesFileName).writeAsStringSync('{"flutter.n":1}');
      expect(await setAsideUnreadablePreferences(supportPath: supportPath), isNull);
      expect(file(preferencesFileName).readAsStringSync(), '{"flutter.n":1}');
      file(preferencesFileName).deleteSync();
      expect(await setAsideUnreadablePreferences(supportPath: supportPath), isNull);
    });

    test('on Linux too, but nowhere the preferences are not a file of the app’s', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      file(preferencesFileName).writeAsBytesSync(List.filled(64, 0));
      expect(await setAsideUnreadablePreferences(supportPath: supportPath), setAsideFileName);
      for (final platform in [TargetPlatform.android, TargetPlatform.iOS, TargetPlatform.macOS]) {
        debugDefaultTargetPlatformOverride = platform;
        file(preferencesFileName).writeAsBytesSync(List.filled(64, 0));
        expect(await setAsideUnreadablePreferences(supportPath: supportPath), isNull, reason: '$platform');
        expect(file(preferencesFileName).existsSync(), isTrue, reason: '$platform');
      }
    });

    test('never throws', () async {
      expect(await setAsideUnreadablePreferences(supportPath: () async => throw StateError('no directory')), isNull);
    });
  });

  group('openPreferences', () {
    test('opens the preferences as they are, and reports nothing', () async {
      file(preferencesFileName).writeAsStringSync('{"flutter.n":7}');
      SharedPreferencesStorePlatform.instance = _FileStore(directory);
      final prefs = await openPreferences(supportPath: supportPath);
      expect(prefs.getInt('n'), 7);
      expect(reported, isEmpty);
    });

    test('sets aside a file that a power cut left full of NULs, and starts afresh, saving again', () async {
      file(preferencesFileName).writeAsBytesSync(List.filled(4096, 0));
      final store = _FileStore(directory);
      SharedPreferencesStorePlatform.instance = store;
      final prefs = await openPreferences(supportPath: supportPath);
      expect(prefs.getKeys(), isEmpty);
      expect(store.reads, 2, reason: 'read again once the file was set aside');
      expect(file(setAsideFileName).lengthSync(), 4096);
      // The app's changes are kept again, in a new file.
      await prefs.setInt('n', 1);
      expect(json.decode(file(preferencesFileName).readAsStringSync()), {'flutter.n': 1});
      expect(SharedPreferencesStorePlatform.instance, same(store));
      // Kept for support, with what became of them.
      expect(reported.single.exception, isA<FormatException>());
      expect(reported.single.library, 'preferences');
      expect(
        reported.single.context?.toDescription(),
        'while reading the stored preferences; they were set aside as $setAsideFileName, and the app started afresh',
      );
    });

    test('reads them at a second try, after a failure that passes', () async {
      final store = _FailingStore(failures: 1);
      SharedPreferencesStorePlatform.instance = store;
      final prefs = await openPreferences(supportPath: supportPath);
      expect(prefs.getBool('kept'), isTrue);
      expect(SharedPreferencesStorePlatform.instance, same(store));
      expect(reported.single.context?.toDescription(), 'while reading the stored preferences; they were read at the second try');
    });

    test('runs on preferences kept in memory where none can be read, as when a browser blocks storage', () async {
      for (final platform in [TargetPlatform.windows, TargetPlatform.android]) {
        debugDefaultTargetPlatformOverride = platform;
        SharedPreferences.setMockInitialValues({});
        reported.clear();
        SharedPreferencesStorePlatform.instance = _FailingStore();
        final prefs = await openPreferences(supportPath: supportPath);
        expect(prefs.getKeys(), isEmpty, reason: '$platform');
        // Changes hold for the session.
        await prefs.setString('settings.v1', '{}');
        expect(prefs.getString('settings.v1'), '{}', reason: '$platform');
        expect(SharedPreferencesStorePlatform.instance, isA<InMemorySharedPreferencesStore>(), reason: '$platform');
        expect((reported.single.exception as StateError).message, 'SecurityError: storage is blocked');
        expect(
          reported.single.context?.toDescription(),
          'while reading the stored preferences; the app runs on preferences kept in memory, which are lost when it closes',
        );
      }
    });

    test('keeps a file that could be read, and runs in memory, when what failed was not the file', () async {
      file(preferencesFileName).writeAsStringSync('{"flutter.n":7}');
      SharedPreferencesStorePlatform.instance = _FailingStore();
      await openPreferences(supportPath: supportPath);
      expect(file(preferencesFileName).readAsStringSync(), '{"flutter.n":7}');
      expect(file(setAsideFileName).existsSync(), isFalse);
      expect(SharedPreferencesStorePlatform.instance, isA<InMemorySharedPreferencesStore>());
    });
  });
}
