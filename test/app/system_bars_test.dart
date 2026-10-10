import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shnayim_mikra/app/system_bars.dart';
import 'package:shnayim_mikra/features/settings/app_settings.dart';
import 'package:shnayim_mikra/ui/theme/app_theme.dart';
import 'package:shnayim_mikra/ui/theme/palette.dart';

import '../helpers.dart';

/// Edge to edge: transparent system bars over the app's surface, with icons
/// that contrast with it, from the launch theme to the running app.
void main() {
  ThemeData theme(AppThemeMode mode) =>
      AppTheme.build(mode: mode, uiFont: UiFont.standard, hebrewUi: false, reduceMotion: false);

  group('systemBarsStyle', () {
    test('a light theme has transparent bars with dark icons', () {
      final style = systemBarsStyle(theme(AppThemeMode.light), behindNavigationBar: true);
      expect(style.statusBarColor, Colors.transparent);
      expect(style.statusBarIconBrightness, Brightness.dark);
      expect(style.statusBarBrightness, Brightness.light, reason: 'iOS: what lies behind the status bar');
      expect(style.systemStatusBarContrastEnforced, isFalse);
      expect(style.systemNavigationBarColor, Colors.transparent);
      expect(style.systemNavigationBarDividerColor, Colors.transparent);
      expect(style.systemNavigationBarIconBrightness, Brightness.dark);
      expect(style.systemNavigationBarContrastEnforced, isFalse);
    });

    test('a dark theme has light icons', () {
      for (final mode in [AppThemeMode.dark, AppThemeMode.highContrastDark]) {
        final style = systemBarsStyle(theme(mode), behindNavigationBar: true);
        expect(style.statusBarIconBrightness, Brightness.light, reason: '$mode');
        expect(style.statusBarBrightness, Brightness.dark, reason: '$mode');
        expect(style.systemNavigationBarIconBrightness, Brightness.light, reason: '$mode');
      }
    });

    test('sepia and high-contrast light have dark icons', () {
      for (final mode in [AppThemeMode.sepia, AppThemeMode.highContrastLight]) {
        final style = systemBarsStyle(theme(mode), behindNavigationBar: true);
        expect(style.statusBarIconBrightness, Brightness.dark, reason: '$mode');
        expect(style.systemNavigationBarIconBrightness, Brightness.dark, reason: '$mode');
      }
    });

    // Android 9 and earlier can't draw the app beneath the navigation bar.
    test('a navigation bar the app is not beneath takes its surface colour', () {
      for (final (mode, surface) in [
        (AppThemeMode.light, Palettes.light.surface),
        (AppThemeMode.dark, Palettes.dark.surface),
        (AppThemeMode.sepia, Palettes.sepia.surface),
      ]) {
        final style = systemBarsStyle(theme(mode), behindNavigationBar: false);
        expect(style.systemNavigationBarColor, surface, reason: '$mode');
        expect(style.statusBarColor, Colors.transparent, reason: '$mode');
      }
    });

    // There the status bar's colour is the page's theme-color: the browser's
    // toolbar, or the installed app's title bar. Transparent would be black.
    test('on the web, the status bar takes the surface colour', () {
      for (final mode in AppThemeMode.values.where((m) => m != AppThemeMode.system)) {
        final t = theme(mode);
        final style = systemBarsStyle(t, behindNavigationBar: true, web: true);
        expect(style.statusBarColor, t.colorScheme.surface, reason: '$mode');
      }
    });

    // An app bar sets the status bar's style beneath it, so on the web its
    // own must be the surface too.
    test("on the web, an app bar's status bar takes the surface colour", () {
      for (final mode in AppThemeMode.values.where((m) => m != AppThemeMode.system)) {
        final web = AppTheme.build(mode: mode, uiFont: UiFont.standard, hebrewUi: false, reduceMotion: false, web: true);
        expect(web.appBarTheme.systemOverlayStyle?.statusBarColor, web.colorScheme.surface, reason: '$mode');
        // Elsewhere the app bar leaves the bars to Material: transparent.
        final native =
            AppTheme.build(mode: mode, uiFont: UiFont.standard, hebrewUi: false, reduceMotion: false, web: false);
        expect(native.appBarTheme.systemOverlayStyle, isNull, reason: '$mode');
      }
    });
  });

  // MaterialApp's color is what the platform shows for the app: the web's
  // theme-color after the first frame, and Android's recents. It is the
  // surface of the theme on screen.
  group("the app's colour", () {
    Color colour(WidgetTester tester) => tester.widget<Title>(find.byType(Title).first).color;

    testWidgets("is the chosen theme's surface", (tester) async {
      for (final (mode, surface) in [
        (AppThemeMode.light, Palettes.light.surface),
        (AppThemeMode.dark, Palettes.dark.surface),
        (AppThemeMode.sepia, Palettes.sepia.surface),
        (AppThemeMode.highContrastLight, Palettes.hcLight.surface),
        (AppThemeMode.highContrastDark, Palettes.hcDark.surface),
      ]) {
        await pumpApp(tester, settings: AppSettings(onboardingComplete: true, theme: mode));
        expect(colour(tester), surface, reason: '$mode');
      }
    });

    testWidgets("follows the system's brightness and contrast", (tester) async {
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await pumpApp(tester);
      expect(colour(tester), Palettes.light.surface);

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pump();
      expect(colour(tester), Palettes.dark.surface);

      tester.platformDispatcher.accessibilityFeaturesTestValue = const FakeAccessibilityFeatures(highContrast: true);
      await tester.pump();
      expect(colour(tester), Palettes.hcDark.surface);

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.light;
      await tester.pump();
      expect(colour(tester), Palettes.hcLight.surface);
    });
  });

  group('the app', () {
    final android = TargetPlatformVariant.only(TargetPlatform.android);

    /// A phone whose status bar is 24 dp tall and whose navigation bar, 48 dp,
    /// lies over the app (Android 10 and later), or beside it.
    void phone(WidgetTester tester, {bool behindNavigationBar = true}) {
      final inset = FakeViewPadding(top: 24, bottom: behindNavigationBar ? 48 : 0);
      tester.view
        ..physicalSize = const Size(412, 915)
        ..devicePixelRatio = 1
        ..padding = inset
        ..viewPadding = inset;
      addTearDown(tester.view.reset);
    }

    // The status bar's style comes from what lies under it, and Android's
    // navigation bar's from what lies under that.
    testWidgets('Welcome, which has no app bar, has dark icons on cream', (tester) async {
      phone(tester);
      await pumpApp(tester, settings: const AppSettings());
      await tester.pumpAndSettle();
      expect(find.text("Start this week's parsha"), findsOneWidget);
      final style = SystemChrome.latestStyle!;
      expect(style.statusBarColor, Colors.transparent);
      expect(style.statusBarIconBrightness, Brightness.dark);
      expect(style.systemNavigationBarColor, Colors.transparent);
      expect(style.systemNavigationBarIconBrightness, Brightness.dark);
      expect(style.systemNavigationBarContrastEnforced, isFalse);
    }, variant: android);

    testWidgets('a dark theme turns the icons light', (tester) async {
      phone(tester);
      await pumpApp(tester, settings: const AppSettings(theme: AppThemeMode.dark));
      await tester.pumpAndSettle();
      final style = SystemChrome.latestStyle!;
      expect(style.statusBarIconBrightness, Brightness.light);
      expect(style.systemNavigationBarColor, Colors.transparent);
      expect(style.systemNavigationBarIconBrightness, Brightness.light);
    }, variant: android);

    testWidgets('under an app bar, the navigation bar stays transparent', (tester) async {
      phone(tester);
      await pumpApp(tester);
      await tester.pumpAndSettle();
      expect(find.byType(AppBar), findsWidgets);
      final style = SystemChrome.latestStyle!;
      expect(style.statusBarColor, Colors.transparent);
      expect(style.statusBarIconBrightness, Brightness.dark);
      expect(style.systemNavigationBarColor, Colors.transparent);
      expect(style.systemNavigationBarIconBrightness, Brightness.dark);
    }, variant: android);

    // Android 9 and earlier: the bar takes the colour of what lies above it.
    testWidgets("a navigation bar beside a tab is painted the app's navigation bar colour", (tester) async {
      for (final (mode, container) in [
        (AppThemeMode.light, Palettes.light.surfaceContainer),
        (AppThemeMode.dark, Palettes.dark.surfaceContainer),
      ]) {
        phone(tester, behindNavigationBar: false);
        await pumpApp(tester, settings: AppSettings(onboardingComplete: true, theme: mode));
        await tester.pumpAndSettle();
        expect(find.byType(NavigationBar), findsOneWidget);
        final style = SystemChrome.latestStyle!;
        expect(style.systemNavigationBarColor, container, reason: '$mode');
        expect(style.systemNavigationBarIconBrightness, mode == AppThemeMode.dark ? Brightness.light : Brightness.dark);
        // The status bar still follows the app bar at the top.
        expect(style.statusBarColor, Colors.transparent);
      }
    }, variant: android);

    testWidgets('a navigation bar beside a page without one is painted the surface colour', (tester) async {
      phone(tester, behindNavigationBar: false);
      await pumpApp(tester, settings: const AppSettings(theme: AppThemeMode.dark));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsNothing, reason: 'Welcome');
      final style = SystemChrome.latestStyle!;
      expect(style.systemNavigationBarColor, Palettes.dark.surface);
      expect(style.systemNavigationBarIconBrightness, Brightness.light);
    }, variant: android);

    testWidgets("over the app, the navigation bar stays transparent beside the app's own", (tester) async {
      phone(tester);
      await pumpApp(tester, settings: const AppSettings(onboardingComplete: true));
      await tester.pumpAndSettle();
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(SystemChrome.latestStyle!.systemNavigationBarColor, Colors.transparent);
    }, variant: android);
  });

  // The native half: the bars look the same from the launch screen on.
  group('Android themes', () {
    final light = _styles('values');
    final dark = _styles('values-night');

    test('the launch and normal themes inherit the edge-to-edge bars', () {
      for (final dir in ['values', 'values-night', 'values-v31', 'values-night-v31']) {
        final styles = _styles(dir);
        for (final name in ['LaunchTheme', 'NormalTheme']) {
          expect(styles[name]?.parent, 'EdgeToEdge.V29', reason: '$dir: $name');
        }
        expect(styles['NormalTheme']!.items['android:windowBackground'], '@color/app_bg', reason: dir);
        // flutter_native_splash writes false here; make_icon.py --post fixes it.
        expect(styles['LaunchTheme']!.items['android:windowDrawsSystemBarBackgrounds'], 'true',
            reason: '$dir: run python3 tool/branding/make_icon.py --post after flutter_native_splash');
      }
    });

    test('the bars are transparent, with icons for the theme', () {
      expect(light['EdgeToEdge']!.parent, '@android:style/Theme.Material.Light.NoActionBar');
      expect(light['EdgeToEdge']!.items, {
        'android:statusBarColor': '@android:color/transparent',
        'android:windowLightStatusBar': 'true',
      }, reason: 'the navigation bar stays dark until it can have dark icons (8.1)');
      expect(dark['EdgeToEdge']!.parent, '@android:style/Theme.Material.NoActionBar');
      expect(dark['EdgeToEdge']!.items, {
        'android:statusBarColor': '@android:color/transparent',
        'android:navigationBarColor': '@android:color/transparent',
        'android:windowLightStatusBar': 'false',
      });

      expect(light['EdgeToEdge.V27']!.parent, 'EdgeToEdge');
      expect(light['EdgeToEdge.V29']!.parent, 'EdgeToEdge.V27');
      final v27 = _styles('values-v27')['EdgeToEdge.V27']!;
      expect(v27.parent, 'EdgeToEdge');
      expect(v27.items, {
        'android:navigationBarColor': '@android:color/transparent',
        'android:windowLightNavigationBar': '?android:attr/windowLightStatusBar',
      });
      final v29 = _styles('values-v29')['EdgeToEdge.V29']!;
      expect(v29.parent, 'EdgeToEdge.V27');
      expect(v29.items, {
        'android:enforceNavigationBarContrast': 'false',
        'android:enforceStatusBarContrast': 'false',
        'android:forceDarkAllowed': 'false',
      });
    });
  });
}

typedef _Style = ({String? parent, Map<String, String> items});

/// The styles in android/app/src/main/res/[dir]/styles.xml.
Map<String, _Style> _styles(String dir) {
  final xml = File('android/app/src/main/res/$dir/styles.xml')
      .readAsStringSync()
      .replaceAll(RegExp(r'<!--.*?-->', dotAll: true), '');
  final styles = <String, _Style>{};
  final style = RegExp(r'<style name="([^"]+)"(?: parent="([^"]+)")?\s*(?:/>|>(.*?)</style>)', dotAll: true);
  final item = RegExp(r'<item name="([^"]+)">([^<]*)</item>');
  for (final match in style.allMatches(xml)) {
    styles[match[1]!] = (
      parent: match[2],
      items: {for (final i in item.allMatches(match[3] ?? '')) i[1]!: i[2]!.trim()},
    );
  }
  return styles;
}
