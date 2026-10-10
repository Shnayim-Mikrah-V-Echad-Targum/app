import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/providers.dart';
import 'package:shnayim_mikra/app/window_title_bar.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';

import '../helpers.dart';

/// On Windows, the title bar follows the app's theme rather than the
/// system's.
void main() {
  final windows = TargetPlatformVariant.only(TargetPlatform.windows);

  /// What the app asks of the runner's window: true for a dark title bar.
  List<bool> listen(WidgetTester tester) {
    final sent = <bool>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(windowChannel, (call) async {
      expect(call.method, 'setDarkTitleBar');
      sent.add(call.arguments as bool);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(windowChannel, null));
    return sent;
  }

  void setTheme(ProviderContainer container, AppThemeMode theme) =>
      container.read(settingsProvider.notifier).update((s) => s.copyWith(theme: theme));

  testWidgets('choosing Dark in the app darkens the title bar, and Light lightens it', (tester) async {
    final sent = listen(tester);
    final container = await pumpApp(tester, settings: const AppSettings(onboardingComplete: true, theme: AppThemeMode.light));
    await tester.pumpAndSettle();
    expect(sent, [false]);

    setTheme(container, AppThemeMode.dark);
    await tester.pumpAndSettle();
    expect(sent, [false, true]);

    // The runner hears only of changes in brightness.
    setTheme(container, AppThemeMode.highContrastDark);
    await tester.pumpAndSettle();
    expect(sent, [false, true]);

    setTheme(container, AppThemeMode.sepia);
    await tester.pumpAndSettle();
    expect(sent, [false, true, false]);
  }, variant: windows);

  testWidgets('an app theme other than the system theme wins', (tester) async {
    final sent = listen(tester);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await pumpApp(tester, settings: const AppSettings(onboardingComplete: true, theme: AppThemeMode.light));
    await tester.pumpAndSettle();
    expect(sent, [false]);
  }, variant: windows);

  testWidgets('following the system, the title bar follows it too', (tester) async {
    final sent = listen(tester);
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await pumpApp(tester);
    await tester.pumpAndSettle();
    expect(sent, [true]);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpAndSettle();
    expect(sent, [true, false]);
  }, variant: windows);

  testWidgets('a runner without the channel is no error', (tester) async {
    await pumpApp(tester, settings: const AppSettings(onboardingComplete: true, theme: AppThemeMode.dark));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }, variant: windows);

  testWidgets('other platforms leave it alone', (tester) async {
    final sent = listen(tester);
    await pumpApp(tester, settings: const AppSettings(onboardingComplete: true, theme: AppThemeMode.dark));
    await tester.pumpAndSettle();
    expect(sent, isEmpty);
  },
      variant: const TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
        TargetPlatform.linux,
      }));

  // The runner's half: windows/runner/flutter_window.cpp.
  test('the Windows runner answers on the same channel', () {
    final runner = File('windows/runner/flutter_window.cpp').readAsStringSync();
    expect(runner, contains('"${windowChannel.name}"'));
    expect(runner, contains('call.method_name() == "setDarkTitleBar"'));
    expect(runner, contains('std::get_if<bool>(call.arguments())'));
  });
}
