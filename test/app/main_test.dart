import 'dart:convert';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_platform_interface.dart';
import 'package:shnayim_mikrah/app/app.dart';
import 'package:shnayim_mikrah/app/start_failure.dart';
import 'package:shnayim_mikrah/features/onboarding/onboarding_screen.dart';
import 'package:shnayim_mikrah/l10n/app_localizations_en.dart';
import 'package:shnayim_mikrah/main.dart' as app;
import 'package:shnayim_mikrah/services/optional_fonts.dart';
import 'package:shnayim_mikrah/services/recent_errors.dart';

/// The app's own start, main(), as a release build runs it: every service it
/// waits for, the fonts the settings choose, and the first screen. The other
/// tests build the app from its parts, so a fault in main() itself, before
/// runApp, reaches none of them; a native build would then draw no frame at
/// all: Windows would keep its window hidden, and the web its loading screen.
void main() {
  /// Runs main() with [stored] as the device's preferences, or with [store]
  /// as their platform's store, pumps the first frame, and returns what went
  /// wrong meanwhile. main() sets the app's error handlers, which are put
  /// back before the test ends, as the binding checks.
  Future<List<String>> start(WidgetTester tester, Map<String, Object> stored, {SharedPreferencesStorePlatform? store}) async {
    SharedPreferences.setMockInitialValues(stored);
    if (store != null) SharedPreferencesStorePlatform.instance = store;
    OptionalFonts.reset();
    final flutterOnError = FlutterError.onError;
    final platformOnError = PlatformDispatcher.instance.onError;
    final errorWidget = ErrorWidget.builder;
    try {
      // Assets and preferences are read for real, outside the fake clock.
      await tester.runAsync(app.main);
      await tester.pump();
      return [for (final e in recentErrors.errors) e.summary];
    } finally {
      FlutterError.onError = flutterOnError;
      PlatformDispatcher.instance.onError = platformOnError;
      ErrorWidget.builder = errorWidget;
      recentErrors.clear();
    }
  }

  /// The home-screen widget's plugin, as a phone has it.
  void homeWidgetPlugin(WidgetTester tester) {
    tester.binding.defaultBinaryMessenger
      ..setMockMethodCallHandler(const MethodChannel('home_widget'), (_) async => null)
      ..setMockStreamHandler(const EventChannel('home_widget/updates'), MockStreamHandler.inline(onListen: (_, _) {}));
    addTearDown(() => tester.binding.defaultBinaryMessenger
      ..setMockMethodCallHandler(const MethodChannel('home_widget'), null)
      ..setMockStreamHandler(const EventChannel('home_widget/updates'), null));
  }

  const platforms = TargetPlatformVariant({TargetPlatform.android, TargetPlatform.iOS, TargetPlatform.windows});

  testWidgets('starts on a first launch, and opens on onboarding', (tester) async {
    homeWidgetPlugin(tester);
    expect(await start(tester, {}), isEmpty);
    expect(find.byType(ShnayimMikrahApp), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsOneWidget);
  }, variant: platforms);

  // On Windows a power cut can leave the preferences file cut short, which
  // the plugin then fails to read on every start; a browser that blocks the
  // site's storage throws as the app reads it. lib/services/
  // preferences_recovery.dart; test/services/preferences_recovery_test.dart
  // sets a damaged file aside.
  testWidgets('starts, on onboarding, when the stored preferences can’t be read', (tester) async {
    homeWidgetPlugin(tester);
    final errors = await start(tester, {}, store: _UnreadableStore());
    expect(find.byType(ShnayimMikrahApp), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsOneWidget);
    // Reported, and kept for About to copy.
    expect(tester.takeException(), isFormatException);
    expect(errors, ['FormatException: Unexpected character (at character 1)']);
    expect(SharedPreferencesStorePlatform.instance, isA<InMemorySharedPreferencesStore>());
  }, variant: platforms);

  testWidgets('says it couldn’t open, rather than draw nothing, when what it needs fails to load', (tester) async {
    // The parshiyot's data, as a first visit to the web app loses it to a
    // dropped connection.
    const parshiyot = 'assets/data/parshiyot.json';
    final messenger = tester.binding.defaultBinaryMessenger;
    void assets({required bool failing}) => messenger.setMockMessageHandler('flutter/assets', (message) async {
          final key = utf8.decode(message!.buffer.asUint8List());
          if (failing && key == parshiyot) return null;
          // As flutter_test serves them.
          final file = File('${Platform.environment['UNIT_TEST_ASSETS']}/$key');
          return file.existsSync() ? ByteData.sublistView(file.readAsBytesSync()) : null;
        });
    rootBundle.evict(parshiyot);
    assets(failing: true);
    addTearDown(() {
      assets(failing: false);
      rootBundle.evict(parshiyot);
    });
    homeWidgetPlugin(tester);
    final errors = await start(tester, {});
    expect(find.byType(ShnayimMikrahApp), findsNothing);
    expect(find.byType(StartFailureApp), findsOneWidget);
    final l = AppLocalizationsEn();
    expect(find.text(l.startFailedTitle), findsOneWidget);
    expect(find.text(l.copySupportDetails), findsOneWidget);
    // What failed, with what the app was doing, for the page to copy.
    expect(tester.takeException(), isFlutterError);
    expect(errors, ['Unable to load asset: "$parshiyot".']);
    expect(find.textContaining('Unable to load asset: "$parshiyot".'), findsOneWidget);
  });

  test('the opt-in fonts can be waited for with a time limit, as main() does', () async {
    OptionalFonts.reset();
    // The callbacks a caller passes must suit the future's own type, which
    // is checked as the app runs: a Future<List<void>> would refuse these.
    await expectLater(OptionalFonts.ensureAll(const []).timeout(const Duration(seconds: 1), onTimeout: () {}), completes);
    await expectLater(OptionalFonts.ensureSamples(const []).catchError((Object _) {}), completes);
  });
}

/// A store whose file can't be read, as shared_preferences_windows finds one
/// that a power cut left full of NULs.
class _UnreadableStore extends SharedPreferencesStorePlatform {
  @override
  Future<Map<String, Object>> getAll() async => json.decode('\u0000\u0000') as Map<String, Object>;

  @override
  Future<bool> setValue(String valueType, String key, Object value) async => false;

  @override
  Future<bool> remove(String key) async => false;

  @override
  Future<bool> clear() async => false;
}
