import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shnayim_mikrah/app/app.dart';
import 'package:shnayim_mikrah/features/onboarding/onboarding_screen.dart';
import 'package:shnayim_mikrah/main.dart' as app;
import 'package:shnayim_mikrah/services/optional_fonts.dart';
import 'package:shnayim_mikrah/services/recent_errors.dart';

/// The app's own start, main(), as a release build runs it: every service it
/// waits for, the fonts the settings choose, and the first screen. The other
/// tests build the app from its parts, so a fault in main() itself, before
/// runApp, reaches none of them; a native build would then show nothing at
/// all, its window open and blank.
void main() {
  /// Runs main() with [stored] as the device's preferences, pumps the first
  /// frame, and returns what went wrong meanwhile. main() sets the app's
  /// error handlers, which are put back before the test ends, as the binding
  /// checks.
  Future<List<String>> start(WidgetTester tester, Map<String, Object> stored) async {
    SharedPreferences.setMockInitialValues(stored);
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

  testWidgets('starts on a first launch, and opens on onboarding', (tester) async {
    // The home-screen widget's plugin, as a phone has it.
    tester.binding.defaultBinaryMessenger
      ..setMockMethodCallHandler(const MethodChannel('home_widget'), (_) async => null)
      ..setMockStreamHandler(const EventChannel('home_widget/updates'), MockStreamHandler.inline(onListen: (_, _) {}));
    addTearDown(() => tester.binding.defaultBinaryMessenger
      ..setMockMethodCallHandler(const MethodChannel('home_widget'), null)
      ..setMockStreamHandler(const EventChannel('home_widget/updates'), null));
    expect(await start(tester, {}), isEmpty);
    expect(find.byType(ShnayimMikrahApp), findsOneWidget);
    expect(find.byType(OnboardingScreen), findsOneWidget);
  }, variant: const TargetPlatformVariant({TargetPlatform.android, TargetPlatform.iOS, TargetPlatform.windows}));

  test('the opt-in fonts can be waited for with a time limit, as main() does', () async {
    OptionalFonts.reset();
    // The callbacks a caller passes must suit the future's own type, which
    // is checked as the app runs: a Future<List<void>> would refuse these.
    await expectLater(OptionalFonts.ensureAll(const []).timeout(const Duration(seconds: 1), onTimeout: () {}), completes);
    await expectLater(OptionalFonts.ensureSamples(const []).catchError((Object _) {}), completes);
  });
}
