import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikrah/app/providers.dart';
import 'package:shnayim_mikrah/app/window_title_bar.dart';
import 'package:shnayim_mikrah/features/settings/app_settings.dart';

import '../helpers.dart';
import 'native_source.dart';

/// On Windows, the title bar follows the app's theme rather than the
/// system's, and the window's title the app's language.
void main() {
  final windows = TargetPlatformVariant.only(TargetPlatform.windows);

  /// What the app asks of the runner's window: the title bar dark (true) or
  /// light, and the window's title.
  ({List<bool> dark, List<String> titles}) listen(WidgetTester tester) {
    final dark = <bool>[];
    final titles = <String>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(windowChannel, (call) async {
      switch (call.method) {
        case 'setDarkTitleBar':
          dark.add(call.arguments as bool);
        case 'setTitle':
          titles.add(call.arguments as String);
        default:
          fail('The runner has no ${call.method}');
      }
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(windowChannel, null));
    return (dark: dark, titles: titles);
  }

  void setTheme(ProviderContainer container, AppThemeMode theme) =>
      container.read(settingsProvider.notifier).update((s) => s.copyWith(theme: theme));

  void setLanguage(ProviderContainer container, AppLanguage language) =>
      container.read(settingsProvider.notifier).update((s) => s.copyWith(language: language));

  testWidgets('choosing Dark in the app darkens the title bar, and Light lightens it', (tester) async {
    final sent = listen(tester).dark;
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
    final sent = listen(tester).dark;
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await pumpApp(tester, settings: const AppSettings(onboardingComplete: true, theme: AppThemeMode.light));
    await tester.pumpAndSettle();
    expect(sent, [false]);
  }, variant: windows);

  testWidgets('following the system, the title bar follows it too', (tester) async {
    final sent = listen(tester).dark;
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    await pumpApp(tester);
    await tester.pumpAndSettle();
    expect(sent, [true]);

    tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
    await tester.pumpAndSettle();
    expect(sent, [true, false]);
  }, variant: windows);

  testWidgets("the window's title is the app's name in its language", (tester) async {
    final titles = listen(tester).titles;
    final container = await pumpApp(tester, settings: const AppSettings(onboardingComplete: true, language: AppLanguage.english));
    await tester.pumpAndSettle();
    expect(titles, ['Shnayim Mikrah']);

    setLanguage(container, AppLanguage.hebrew);
    await tester.pumpAndSettle();
    expect(titles, ['Shnayim Mikrah', 'שניים מקרא']);

    // The runner hears only of a new title.
    setTheme(container, AppThemeMode.dark);
    await tester.pumpAndSettle();
    expect(titles, ['Shnayim Mikrah', 'שניים מקרא']);

    setLanguage(container, AppLanguage.english);
    await tester.pumpAndSettle();
    expect(titles, ['Shnayim Mikrah', 'שניים מקרא', 'Shnayim Mikrah']);
  }, variant: windows);

  testWidgets("following the system's language, the title follows it too", (tester) async {
    final titles = listen(tester).titles;
    tester.platformDispatcher.localesTestValue = const [Locale('he', 'IL')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await pumpApp(tester);
    await tester.pumpAndSettle();
    expect(titles, ['שניים מקרא']);

    tester.platformDispatcher.localesTestValue = const [Locale('en', 'US')];
    await tester.pumpAndSettle();
    expect(titles, ['שניים מקרא', 'Shnayim Mikrah']);
  }, variant: windows);

  testWidgets('a runner without the channel is no error', (tester) async {
    await pumpApp(tester, settings: const AppSettings(onboardingComplete: true, theme: AppThemeMode.dark));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  }, variant: windows);

  testWidgets('other platforms leave it alone', (tester) async {
    final sent = listen(tester);
    await pumpApp(tester, settings: const AppSettings(onboardingComplete: true, theme: AppThemeMode.dark, language: AppLanguage.hebrew));
    await tester.pumpAndSettle();
    expect(sent.dark, isEmpty);
    expect(sent.titles, isEmpty);
  },
      variant: const TargetPlatformVariant({
        TargetPlatform.android,
        TargetPlatform.iOS,
        TargetPlatform.macOS,
        TargetPlatform.linux,
      }));

  // For a click on one of the app's notifications (lib/services/notifications.dart).
  test('bringing the window forward asks the runner, which may lack the channel', () async {
    final calls = <MethodCall>[];
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(windowChannel, (call) async {
      calls.add(call);
      return null;
    });
    addTearDown(() => messenger.setMockMethodCallHandler(windowChannel, null));
    await bringWindowForward();
    expect(calls.map((c) => (c.method, c.arguments)), [('activate', null)]);

    messenger.setMockMethodCallHandler(windowChannel, null);
    await bringWindowForward();
    messenger.setMockMethodCallHandler(windowChannel, (call) async => throw PlatformException(code: 'error'));
    await bringWindowForward();
  });

  // The runner's half: windows/runner/flutter_window.cpp.
  test('the Windows runner answers on the same channel', () {
    final runner = File('windows/runner/flutter_window.cpp').readAsStringSync();
    expect(runner, contains('"${windowChannel.name}"'));
    expect(runner, contains('call.method_name() == "setDarkTitleBar"'));
    expect(runner, contains('std::get_if<bool>(call.arguments())'));
    expect(runner, contains('call.method_name() == "setTitle"'));
    expect(runner, contains('std::get_if<std::string>(call.arguments())'));
    expect(runner, contains('SetWindowTextW('));
  });

  // Windows lets the app take the foreground as one of its notifications is
  // clicked, but brings nothing forward itself.
  test('the Windows runner brings its window forward, restored, once it is shown', () {
    final runner = File('windows/runner/flutter_window.cpp').readAsStringSync();
    final activate = cppBody(runner, 'call.method_name() == "activate"');
    // Shown before its first frame, it would be blank.
    expect(activate, contains('if (window != nullptr && shown_) {\n            BringToFront(window);\n          }'));
    expect(activate, contains('result->Success();'));

    expect(File('windows/runner/win32_window.h').readAsStringSync(), contains('void BringToFront(HWND window);'));
    final bring = cppBody(File('windows/runner/win32_window.cpp').readAsStringSync(), 'void BringToFront(HWND window)');
    expect(bring, contains('if (IsIconic(window)) {\n    ShowWindow(window, SW_RESTORE);\n  }'));
    expect(bring.indexOf('SW_RESTORE'), lessThan(bring.indexOf('SetForegroundWindow(window);')));
  });
}
