import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/android_night_mode.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';

import '../helpers.dart';

/// On Android, the app holds the system's night mode for itself to its theme,
/// so that from Android 12 the launch screen of a cold start is the theme's
/// rather than the system's (docs/DESIGN_SYSTEM.md §3.6).
void main() {
  final android = TargetPlatformVariant.only(TargetPlatform.android);

  /// What the app asks of the activity: the night mode of each call.
  List<String> listen(WidgetTester tester) {
    final sent = <String>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(uiModeChannel, (call) async {
      expect(call.method, 'setNightMode');
      sent.add(call.arguments as String);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(uiModeChannel, null));
    return sent;
  }

  void setTheme(ProviderContainer container, AppThemeMode theme) =>
      container.read(settingsProvider.notifier).update((s) => s.copyWith(theme: theme));

  test('dark themes are night, light ones not, and following the system is its own', () {
    expect({for (final theme in AppThemeMode.values) theme: androidNightMode(theme)}, {
      AppThemeMode.system: 'auto',
      AppThemeMode.light: 'no',
      AppThemeMode.dark: 'yes',
      AppThemeMode.sepia: 'no',
      AppThemeMode.highContrastLight: 'no',
      AppThemeMode.highContrastDark: 'yes',
    });
  });

  testWidgets("the theme's night mode is sent at start, and again as the theme changes", (tester) async {
    final sent = listen(tester);
    final container = await pumpApp(tester, settings: const AppSettings(onboardingComplete: true, theme: AppThemeMode.dark));
    await tester.pumpAndSettle();
    expect(sent, ['yes']);

    setTheme(container, AppThemeMode.light);
    await tester.pumpAndSettle();
    expect(sent, ['yes', 'no']);

    // The activity hears only of a change in the mode.
    setTheme(container, AppThemeMode.sepia);
    await tester.pumpAndSettle();
    setTheme(container, AppThemeMode.highContrastLight);
    await tester.pumpAndSettle();
    expect(sent, ['yes', 'no']);

    setTheme(container, AppThemeMode.highContrastDark);
    await tester.pumpAndSettle();
    expect(sent, ['yes', 'no', 'yes']);

    setTheme(container, AppThemeMode.system);
    await tester.pumpAndSettle();
    expect(sent, ['yes', 'no', 'yes', 'auto']);
  }, variant: android);

  testWidgets("following the system from the start sends the system's own", (tester) async {
    final sent = listen(tester);
    await pumpApp(tester);
    await tester.pumpAndSettle();
    expect(sent, ['auto']);
  }, variant: android);

  testWidgets('an activity without the channel is no error', (tester) async {
    final container = await pumpApp(tester, settings: const AppSettings(onboardingComplete: true, theme: AppThemeMode.dark));
    await tester.pumpAndSettle();
    setTheme(container, AppThemeMode.light);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }, variant: android);

  testWidgets('other platforms leave it alone', (tester) async {
    final sent = listen(tester);
    final container = await pumpApp(tester, settings: const AppSettings(onboardingComplete: true, theme: AppThemeMode.dark));
    await tester.pumpAndSettle();
    setTheme(container, AppThemeMode.light);
    await tester.pumpAndSettle();
    expect(sent, isEmpty);
  },
      variant: const TargetPlatformVariant({
        TargetPlatform.iOS,
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux,
      }));

  // The activity's half.
  test('MainActivity answers on the same channel, from Android 12', () {
    final activity =
        File('android/app/src/main/kotlin/org/shnayimmikra/shnayim_mikra/MainActivity.kt').readAsStringSync();
    expect(activity, contains('MethodChannel(messenger, "${uiModeChannel.name}")'));
    expect(activity, contains('call.method == "setNightMode"'));
    for (final (mode, constant) in [('yes', 'MODE_NIGHT_YES'), ('no', 'MODE_NIGHT_NO'), ('auto', 'MODE_NIGHT_AUTO')]) {
      expect(activity, contains('"$mode" -> UiModeManager.$constant'));
    }
    expect(
      activity,
      matches(RegExp(r'if \(Build\.VERSION\.SDK_INT >= Build\.VERSION_CODES\.S\) \{\s+'
          r'getSystemService\(UiModeManager::class\.java\)\?\.setApplicationNightMode\(nightMode\)')),
    );
  });
}
